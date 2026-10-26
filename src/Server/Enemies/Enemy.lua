--!strict
-- One enemy. Holds its authoritative health and AI state; EnemyService calls Think() from its single loop.
-- The class knows nothing about waves, score or UI; it only reports when it is removed.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Util.Maid)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)
local Server = script.Parent.Parent
local Dismember = require(Server.Util.Dismember)
local Flinch = require(Server.Util.Flinch)
local Jump = require(Server.Util.Jump)
local Ragdoll = require(Server.Util.Ragdoll)
local WeaponTypes = require(Server.Weapons.WeaponTypes)

local DISABLED_STATES = {
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Climbing,
}
local HEAD_PART_NAME = "Head"
local LEG_NAMES = { ["Left Leg"] = true, ["Right Leg"] = true }
local LIMB_NAMES = { ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }
local WALK_ANIMATION_MIN_SPEED = 0.5
local WALK_ANIMATION_FADE = 0.08 -- seconds to blend the walk out on stagger and back in after
local STUCK_DISTANCE = 0.5 -- moved less than this since the last think while chasing = blocked
local STUCK_THINKS_BEFORE_PATH = 3 -- stuck this many thinks (not in a crowd) = switch to pathfinding
local CLIMB_CHECK_DOWN = 4.5 -- studs below the root: what the zombie is standing on (feet are ~3 down)
-- studs in front of the root: what the zombie is walking into (reaches past its bumper to the next body)
local CLIMB_CHECK_AHEAD = GameRules.ZombieBumperDiameter + 0.5
local CLIMB_LIFT_FORCE = 3 -- the climb lift can hold this many times the zombie's weight
local WALL_FOOT_DROP = 1.8 -- studs below the root of the second wall check (its shins: just clear of the floor)
local WALL_STEEPNESS = 0.5 -- a surface whose normal is flatter than this (|Y|) counts as a wall
local SIDESTEP_PROBE = GameRules.ZombieBumperDiameter + 1 -- studs a blocked zombie looks to each side for a gap
local SIDESTEP_ANGLE = math.rad(60) -- how far off its heading it looks and edges (90 = straight sideways)
local SIDESTEP_TIME = 0.6 -- seconds it keeps edging one way before looking again
local WALL_SIDESTEP_ANGLE = math.rad(90) -- stuck on a wall, it slides straight along it
local WALL_SIDESTEP_TIME = 1.5 -- seconds it keeps sliding one way along a wall before looking again
local BLOCK_CHECK_RADIUS = 1 -- studs: width of the "what is in front of me" checks (a ray would slip past)
local JAMMED_THINKS_TO_CLIMB = 4 -- thinks (0.2 s each) jammed against living zombies before it climbs them
local LANE_SHARE = 0.7 -- a zombie's approach lane is offset by up to this share of its distance...
local LANE_MAX = 20 -- ...and at most this many studs, to one side of the player
local CRAWL_PITCH = 70 -- degrees a climbing zombie leans forward into a crawl on a flat pile
local CRAWL_SLOPE_LIMIT = 45 -- degrees: steepest climb/descent the crawl posture follows
local CRAWL_SLOPE_FOLLOW = 0.3 -- share of that slope it tilts with (low = stays down crawling even going up a wall)
local CRAWL_PITCH_STEP = 5 -- degrees of change before the posture is re-sent to clients
local PATH_HEIGHT_GAP = 4 -- player this many studs above the zombie = it cannot walk straight there
local FORCE_PATH_TIME = 4 -- seconds it keeps pathfinding after getting stuck
local FIRST_WAYPOINT = 2 -- waypoint 1 is the start position
local KNOCKBACK_LIFT = 0.25 -- share of knockback that also pushes upward, so the shove is not eaten by ground friction
local RAGDOLL_BODY_SHARE = 0.4 -- share of RagdollForce applied to the whole body; the hit part gets the full force

export type EnemyState = "Idle" | "Chase" | "Attack" | "Dead"

-- What EnemyService hands every enemy on each AI tick.
export type World = {
	Targets: { BasePart }, -- root parts of living players
	MapParams: RaycastParams, -- ignores characters, enemies and pickups
	EnemyFolder: Instance, -- living zombies and corpses, for the climbing check
	IsLivingEnemyPart: (part: Instance) -> boolean, -- true for living zombies, false for corpses and limbs
	FallLimitY: number,
	FindRespawn: () -> Vector3,
}

local Enemy = {}
Enemy.__index = Enemy

export type Enemy = typeof(setmetatable({} :: {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Definition: Types.EnemyDefinition,
	Health: number,
	State: EnemyState,
	LastAttacker: Player?,
	Removed: Signal.Signal, -- (killed: boolean), fires once when the enemy dies or its model is destroyed
	_baseSpeed: number,
	_staggerUntil: number,
	_staggerPower: number,
	_lastHit: WeaponTypes.Hit?,
	_flankSide: number, -- 1 or -1: which side a flanker swings out to
	_path: Path,
	_waypoints: { PathWaypoint }?,
	_waypointIndex: number,
	_lastPathTime: number,
	_computingPath: boolean,
	_lastAttack: number,
	_walkTrack: AnimationTrack?,
	_lastThinkPosition: Vector3,
	_stuckThinks: number,
	_pinned: boolean, -- barely moved since the last think while chasing (against a wall or jammed in the crowd)
	_forcePathUntil: number,
	_selfParams: RaycastParams, -- hits everything except this zombie's own body
	_climbLift: LinearVelocity, -- raises the zombie slowly while it claws its way up a pile
	_bumper: Part, -- invisible collision cylinder that makes the zombie take up more room in a crowd
	_climbing: boolean,
	_canClimb: boolean, -- blocked by a corpse, or by a queue deep enough to climb onto
	_crawlPitch: number, -- degrees last sent to clients
	_limbDamage: { [string]: number }, -- damage taken by each arm and leg
	_legless: boolean, -- lost a leg: crawls, slower, cannot jump
	_standingOnCrowd: boolean,
	_blockedByCrowd: boolean,
	_blockedByLiving: boolean, -- a living zombie (not a corpse) is right in front of it
	_sidestepSide: number, -- 1 = edging left, -1 = right, 0 = not sidestepping
	_sidestepUntil: number,
	_jammedThinks: number, -- thinks in a row pressed into the crowd without getting anywhere
	_wallAhead: boolean, -- a wall right in front of it, towards its goal
	_heading: Vector3, -- flat unit direction towards where it is trying to go
	_lane: number, -- -1..1: which side of the player it approaches along (spreads the crowd out)
	_maid: Maid.Maid,
}, Enemy))

local animations: { [string]: Animation } = {}
local rng = Random.new()

local function getAnimation(id: string): Animation
	local existing = animations[id]
	if existing then
		return existing
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	animations[id] = animation
	return animation
end

local function findNearest(targets: { BasePart }, position: Vector3): (BasePart?, number)
	local best: BasePart? = nil
	local bestDistanceSq = math.huge
	for _, target in targets do
		local offset = target.Position - position
		local distanceSq = offset:Dot(offset)
		if distanceSq < bestDistanceSq then
			best, bestDistanceSq = target, distanceSq
		end
	end
	return best, bestDistanceSq
end

function Enemy.new(model: Model, definition: Types.EnemyDefinition, health: number, walkSpeed: number): Enemy
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid, `{model.Name} has no Humanoid`)
	assert(root and root:IsA("BasePart"), `{model.Name} has no HumanoidRootPart`)

	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = walkSpeed
	Ragdoll.Prepare(humanoid)
	Flinch.Enable(model)
	model:AddTag(Constants.Tags.Enemy)
	Jump.Apply(humanoid)
	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end

	local maid = Maid.new()
	-- Climbing is a slow, steady lift (only along the vertical; horizontal movement stays free),
	-- switched on while the zombie presses into a pile it is allowed to climb
	local liftAttachment = maid:GiveTask(Instance.new("Attachment"))
	liftAttachment.Name = "ClimbLift"
	liftAttachment.Parent = root
	local climbLift = maid:GiveTask(Instance.new("LinearVelocity"))
	climbLift.Attachment0 = liftAttachment
	climbLift.RelativeTo = Enum.ActuatorRelativeTo.World
	climbLift.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	climbLift.LineDirection = Vector3.yAxis
	climbLift.LineVelocity = GameRules.ClimbRiseSpeed
	climbLift.MaxForce = root.AssemblyMass * workspace.Gravity * CLIMB_LIFT_FORCE
	climbLift.Enabled = false
	climbLift.Parent = root

	-- A wider invisible body so zombies pack out and fill more space. It adds no weight, and its
	-- collision group lets shots pass through it (CanQuery cannot be turned off on a colliding
	-- part), so the visible head and limbs still take the hits.
	local bumper = maid:GiveTask(Instance.new("Part"))
	bumper.Name = "Bumper"
	bumper.Shape = Enum.PartType.Cylinder
	bumper.Size = Vector3.new(GameRules.ZombieBumperHeight, GameRules.ZombieBumperDiameter, GameRules.ZombieBumperDiameter)
	bumper.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X; stand it upright
	bumper.Transparency = 1
	bumper.Massless = true
	bumper.CollisionGroup = Constants.CollisionGroups.Bumper
	bumper.CanTouch = false
	bumper.CastShadow = false
	local bumperWeld = Instance.new("WeldConstraint")
	bumperWeld.Part0 = root
	bumperWeld.Part1 = bumper
	bumperWeld.Parent = bumper
	bumper.Parent = model

	local selfParams = RaycastParams.new()
	selfParams.FilterType = Enum.RaycastFilterType.Exclude
	selfParams.FilterDescendantsInstances = { model }
	local agent = definition.Agent
	local path = maid:GiveTask(PathfindingService:CreatePath({
		AgentRadius = agent.Radius,
		AgentHeight = agent.Height,
		AgentCanJump = false, -- zombies never jump walls; only a pile of them can scale one
	}))

	local self = setmetatable({
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Definition = definition,
		Health = health,
		State = "Idle" :: EnemyState,
		LastAttacker = nil :: Player?,
		Removed = maid:GiveTask(Signal.new()),
		_baseSpeed = walkSpeed,
		_staggerUntil = 0,
		_staggerPower = 0,
		_lastHit = nil :: WeaponTypes.Hit?,
		_flankSide = if rng:NextNumber() < 0.5 then -1 else 1,
		_path = path,
		_waypoints = nil :: { PathWaypoint }?,
		_waypointIndex = 0,
		_lastPathTime = 0,
		_computingPath = false,
		_lastAttack = 0,
		_walkTrack = nil :: AnimationTrack?,
		_lastThinkPosition = root.Position,
		_stuckThinks = 0,
		_pinned = false,
		_forcePathUntil = 0,
		_selfParams = selfParams,
		_climbLift = climbLift,
		_bumper = bumper,
		_climbing = false,
		_canClimb = false,
		_crawlPitch = 0,
		_limbDamage = {},
		_legless = false,
		_standingOnCrowd = false,
		_blockedByCrowd = false,
		_blockedByLiving = false,
		_sidestepSide = 0,
		_sidestepUntil = 0,
		_jammedThinks = 0,
		_wallAhead = false,
		_heading = Vector3.zAxis,
		-- Square root pushes lanes out towards the edges, so few zombies share the middle lane
		_lane = (if rng:NextNumber() < 0.5 then -1 else 1) * math.sqrt(rng:NextNumber()),
		_maid = maid,
	}, Enemy)

	maid:GiveTask(humanoid.Died:Connect(function()
		self._climbLift.Enabled = false -- a body must not be held up mid-climb
		self._bumper.CanCollide = false -- the ragdoll's own limbs are the corpse's shape
		Ragdoll.Enable(model)
		self:_applyDeathForce()
		self:_applyHeadshotDeath()
		self:_markRemoved(true)
	end))
	maid:GiveTask(model.Destroying:Connect(function()
		self:_markRemoved(false)
	end))
	self:_startWalkAnimation()
	return self
end

function Enemy._markRemoved(self: Enemy, killed: boolean)
	if self.State == "Dead" then
		return
	end
	self.State = "Dead"
	self.Removed:Fire(killed)
end

function Enemy._startWalkAnimation(self: Enemy)
	local animator = self.Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(getAnimation(self.Definition.WalkAnimationId))
	end)
	if not ok or not track then
		return
	end
	self._maid:GiveTask(track)
	self._walkTrack = track
	self._maid:GiveTask(self.Humanoid.Running:Connect(function(speed: number)
		if
			speed > WALK_ANIMATION_MIN_SPEED
			and not track.IsPlaying
			and not self:_isStaggered()
			and not self._legless
			and self._crawlPitch == 0
		then
			track:Play()
		elseif speed <= WALK_ANIMATION_MIN_SPEED and track.IsPlaying then
			track:Stop()
		end
	end))
end

function Enemy._isStaggered(self: Enemy): boolean
	return os.clock() < self._staggerUntil
end

-- The walk animation is what swings the arms; it is paused while staggered so a hit zombie
-- holds still in its arms-out pose, and resumes once it is moving normally again. A legless
-- zombie never walks again.
function Enemy._updateWalkAnimation(self: Enemy)
	local track = self._walkTrack
	if not track then
		return
	end
	if self:_isStaggered() or self._legless or self._crawlPitch ~= 0 then
		if track.IsPlaying then
			track:Stop(WALK_ANIMATION_FADE)
		end
	elseif not track.IsPlaying and self.Humanoid.MoveDirection.Magnitude > 0 then
		track:Play(WALK_ANIMATION_FADE)
	end
end

-- Only EnemyService.Damage should call this. Reaching 0 kills the Humanoid, which fires Removed.
-- `hit` is remembered for the death push; a survivor is staggered and knocked back by it.
function Enemy.TakeDamage(self: Enemy, amount: number, source: Player?, hit: WeaponTypes.Hit?)
	if self.State == "Dead" or self.Health <= 0 then
		return
	end
	self.Health = math.max(0, self.Health - amount)
	self.LastAttacker = source
	if hit then
		self._lastHit = hit
		self:_damageLimb(hit, amount)
		if self.Health > 0 then
			self:_applyImpact(hit)
		end
	end
	self.Humanoid.Health = self.Health
end

-- Arms and legs each soak up damage; once one has taken LimbHealthFraction of the zombie's max
-- health it is blown off (on the killing shot too). Losing a leg leaves the zombie crawling.
function Enemy._damageLimb(self: Enemy, hit: WeaponTypes.Hit, amount: number)
	local limb = hit.Part
	local limbName = limb.Name
	if not LIMB_NAMES[limbName] or not limb:IsDescendantOf(self.Model) then
		return
	end
	local total = (self._limbDamage[limbName] or 0) + amount
	self._limbDamage[limbName] = total
	if total < self.Humanoid.MaxHealth * GameRules.LimbHealthFraction then
		return
	end
	if Dismember.Sever(self.Model, limb, hit.Direction, self.Definition.CorpseTime) and LEG_NAMES[limbName] then
		self:_loseLeg()
	end
end

function Enemy._loseLeg(self: Enemy)
	if self._legless then
		return
	end
	self._legless = true
	-- R6 treats HipHeight as an offset from standing on its legs, so a negative value drops the
	-- body onto the ground instead of it standing on the leg it has left
	self.Humanoid.HipHeight = GameRules.LeglessHipHeight
	self._bumper.CanCollide = false -- lying low, it would drag along the ground
	self.Model:SetAttribute(Constants.Attributes.Legless, true)
	self:_updateWalkAnimation()
	self:_refreshWalkSpeed()
	self:_updateCrawlPose()
end

-- Stopping power slows the zombie for StaggerDuration (the strongest recent hit wins);
-- knockback shoves it away from the shooter.
function Enemy._applyImpact(self: Enemy, hit: WeaponTypes.Hit)
	local impact = hit.Impact
	local now = os.clock()
	if now >= self._staggerUntil then
		self._staggerPower = 0
	end
	self._staggerPower = math.max(self._staggerPower, impact.StoppingPower)
	self._staggerUntil = now + GameRules.StaggerDuration
	self:_refreshWalkSpeed()
	self:_updateWalkAnimation() -- stop the arm swing
	Flinch.Trigger(self.Model, hit.Direction) -- clients play the "hit" body snap

	if impact.Knockback > 0 then
		local flat = Vector3.new(hit.Direction.X, 0, hit.Direction.Z)
		if flat.Magnitude > 0 then
			local push = flat.Unit * impact.Knockback + Vector3.new(0, impact.Knockback * KNOCKBACK_LIFT, 0)
			self.Root.AssemblyLinearVelocity += push
		end
	end
end

-- Called after the ragdoll is enabled. A headshot kill rolls a gore death: the head explodes
-- (removed), pops off (neck joint broken, head flung along the shot), or nothing happens. The
-- server does the physical part; clients play the blood from the HeadshotDeath attribute.
function Enemy._applyHeadshotDeath(self: Enemy)
	local hit = self._lastHit
	local head = self.Model:FindFirstChild(HEAD_PART_NAME)
	if not hit or hit.Part ~= head or not head or not head:IsA("BasePart") then
		return
	end
	local roll = rng:NextNumber()
	local outcome = if roll < GameRules.HeadExplodeChance
		then "Explode"
		elseif roll < GameRules.HeadExplodeChance + GameRules.HeadPopChance then "PopOff"
		else nil
	if not outcome then
		return
	end

	self.Model:SetAttribute(Constants.Attributes.HeadshotDeathPosition, head.Position)
	if outcome == "Explode" then
		head:Destroy()
	else
		-- Ragdoll.Enable parented the neck's ball socket (and its no-collide) to the head
		for _, child in head:GetChildren() do
			if child:IsA("BallSocketConstraint") or child:IsA("NoCollisionConstraint") then
				child:Destroy()
			end
		end
		local fling = hit.Direction.Unit * GameRules.HeadPopForce + Vector3.new(0, GameRules.HeadPopLift, 0)
		head:ApplyImpulse(fling * head:GetMass())
	end
	self.Model:SetAttribute(Constants.Attributes.HeadshotDeath, outcome)
end

-- Called after the ragdoll is enabled: the killing shot pushes the body, hardest on the part it hit.
function Enemy._applyDeathForce(self: Enemy)
	local hit = self._lastHit
	if not hit then
		return
	end
	local force = hit.Impact.RagdollForce
	local direction = hit.Direction.Unit
	for _, part in self.Model:GetDescendants() do
		if part:IsA("BasePart") then
			-- Ragdolled limbs are separate physics bodies; the server must own them to push them
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
			part:ApplyImpulse(direction * force * RAGDOLL_BODY_SHARE * part:GetMass())
		end
	end
	if hit.Part:IsDescendantOf(self.Model) then
		hit.Part:ApplyImpulseAtPosition(direction * force * hit.Part:GetMass(), hit.Position)
	end
end

function Enemy.Think(self: Enemy, world: World)
	if self.State == "Dead" then
		return
	end
	if self._staggerPower > 0 and not self:_isStaggered() then
		self._staggerPower = 0
	end
	self:_updateClimbing(world)
	self:_refreshWalkSpeed()
	self:_updateWalkAnimation()
	if self.Root.Position.Y < world.FallLimitY then
		self.Model:PivotTo(CFrame.new(world.FindRespawn()))
		return
	end

	local target, distanceSq = findNearest(world.Targets, self.Root.Position)
	if not target then
		self.State = "Idle"
		return
	end

	local range = self.Definition.AttackRange
	if distanceSq <= range * range then
		self.State = "Attack"
		self._stuckThinks = 0
		self.Humanoid:MoveTo(target.Position)
		self:_tryAttack(target)
	else
		self.State = "Chase"
		self:_checkStuck()
		self:_maybeHop()
		self:_chase(target, distanceSq, world.MapParams)
	end
	self._lastThinkPosition = self.Root.Position
end

-- Walk speed = base speed, cut by any bullet stagger, and halved (ClimbSpeedMultiplier) while climbing.
function Enemy._refreshWalkSpeed(self: Enemy)
	local speed = self._baseSpeed * (1 - math.clamp(self._staggerPower, 0, 1))
	if self._climbing then
		speed *= GameRules.ClimbSpeedMultiplier
	end
	if self._legless then
		speed *= GameRules.LeglessSpeedMultiplier
	end
	if self.Humanoid.WalkSpeed ~= speed then
		self.Humanoid.WalkSpeed = speed
	end
end

-- A zombie is climbing while it stands on another zombie or a corpse, or has one right in front of it.
-- It may always climb over corpses and severed limbs. Onto living zombies it climbs once it has been
-- jammed against them for JAMMED_THINKS_TO_CLIMB thinks, so a crowd first spreads out to fill the
-- space (see _steer), then the ones with nowhere left to go climb on top of the ones in front.
-- World War Z piles: a zombie standing on the pile and pressed against a wall claws its way up the
-- wall, but only while there is pile under it (a zombie on its own never climbs a wall). Each one
-- that gets up gains a little height and becomes the next step for the ones behind, so the pile
-- builds up the wall until the top zombies reach the edge and spill over it.
function Enemy._updateClimbing(self: Enemy, world: World)
	local root = self.Root
	local crowd = world.EnemyFolder
	local below = workspace:Raycast(root.Position, Vector3.new(0, -CLIMB_CHECK_DOWN, 0), self._selfParams)
	-- Look the way it is trying to go (towards its goal), not the way it faces, so turning aside to
	-- sidestep does not make it forget what is blocking it
	-- Checked at chest and shin height, so a climber keeps rising until its legs clear the top of
	-- whatever it is climbing, not just its chest (or it would slide back down every time)
	local reach = self._heading * CLIMB_CHECK_AHEAD
	local shins = root.Position - Vector3.new(0, WALL_FOOT_DROP, 0)
	local ahead = workspace:Spherecast(root.Position, BLOCK_CHECK_RADIUS, reach, self._selfParams)
		or workspace:Spherecast(shins, BLOCK_CHECK_RADIUS, reach, self._selfParams)

	self._standingOnCrowd = below ~= nil and below.Instance:IsDescendantOf(crowd)
	self._blockedByCrowd = ahead ~= nil and ahead.Instance:IsDescendantOf(crowd)
	self._blockedByLiving = ahead ~= nil and world.IsLivingEnemyPart(ahead.Instance)
	-- Corpses: always. Living zombies: once it has been jammed against them for a while (sidestepping
	-- found no way through)
	self._canClimb = self._blockedByCrowd and (not self._blockedByLiving or self._jammedThinks >= JAMMED_THINKS_TO_CLIMB)

	-- Against a wall at chest or foot height (so it keeps going until its feet clear the top edge)
	local wall = workspace:Spherecast(root.Position, BLOCK_CHECK_RADIUS, reach, world.MapParams)
		or workspace:Spherecast(shins, BLOCK_CHECK_RADIUS, reach, world.MapParams)
	self._wallAhead = wall ~= nil and math.abs(wall.Normal.Y) < WALL_STEEPNESS
	local scalingWall = self._standingOnCrowd and self._wallAhead

	self._climbing = self._standingOnCrowd or self._blockedByCrowd
	-- Claw upward only while pressing into a climbable pile or up a wall from the pile; on top it
	-- just crawls across
	self._climbLift.Enabled = (self._canClimb or scalingWall) and not self:_isStaggered() and not self._legless
	self:_updateCrawlPose()
end

-- Once it is off the floor and climbing (clawing up, or up on the pile) the body is down in a crawl,
-- clawing with its arms, tilting a little with the slope it is climbing (a bit less lean going up,
-- more going down). The zombies at the bottom stay standing, holding up a heap of crawlers that
-- slowly bubble up over them. A legless zombie lies almost flat all the time.
-- Clients draw it from the CrawlPitch attribute.
function Enemy._updateCrawlPose(self: Enemy)
	local pitch = 0
	if self._legless then
		pitch = GameRules.LeglessCrawlPitch
	elseif
		self._standingOnCrowd
		or (self._climbLift.Enabled and self.Humanoid.FloorMaterial == Enum.Material.Air)
	then
		local velocity = self.Root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local slope = math.clamp(math.deg(math.atan2(velocity.Y, math.max(horizontal, 1))), -CRAWL_SLOPE_LIMIT, CRAWL_SLOPE_LIMIT)
		pitch = CRAWL_PITCH - slope * CRAWL_SLOPE_FOLLOW
	end
	if math.abs(pitch - self._crawlPitch) >= CRAWL_PITCH_STEP or (pitch == 0 and self._crawlPitch ~= 0) then
		self._crawlPitch = pitch
		self.Model:SetAttribute(Constants.Attributes.CrawlPitch, pitch)
	end
end

-- Now and then a chasing zombie does a tiny hop (GameRules.ZombieHopHeight, much smaller than a player's
-- jump). It hops far more often while pinned against a wall or jammed in the crowd, straining to reach
-- the player. Hops never help it climb: that is the slow lift in _updateClimbing.
function Enemy._maybeHop(self: Enemy)
	if self._climbLift.Enabled or self._standingOnCrowd or self._legless or self:_isStaggered() then
		return
	end
	local chance = if self._pinned then GameRules.ZombieStuckHopChance else GameRules.ZombieHopChance
	if self.Humanoid.FloorMaterial == Enum.Material.Air or rng:NextNumber() >= chance then
		return
	end
	local root = self.Root
	local upSpeed = math.sqrt(2 * workspace.Gravity * GameRules.ZombieHopHeight)
	root.AssemblyLinearVelocity += Vector3.new(0, upSpeed, 0)
end

-- Corpses and other zombies do not block the "is there a wall" check, so a zombie walks into them
-- (and climbs them if allowed, see _updateClimbing). Pushing in a crowd is not being stuck. Zombies
-- never jump walls (only a pile of them can scale one); stuck on the map, it switches to
-- pathfinding to find a way round.
function Enemy._checkStuck(self: Enemy)
	if self:_isStaggered() or self._legless then
		self._pinned = false
		self._stuckThinks = 0 -- being slowed by bullets is not being stuck
		return
	end
	local moved = self.Root.Position - self._lastThinkPosition
	self._pinned = moved.X * moved.X + moved.Z * moved.Z < STUCK_DISTANCE * STUCK_DISTANCE
	-- Jammed: pressed into the crowd and getting nowhere (counts towards climbing over it)
	if self._blockedByCrowd and self._pinned then
		self._jammedThinks += 1
	elseif not self._blockedByCrowd then
		self._jammedThinks = 0
	end
	if self._pinned then
		self._stuckThinks += 1
		if self._blockedByCrowd then
			self._stuckThinks = 0
		elseif self._stuckThinks >= STUCK_THINKS_BEFORE_PATH then
			self._stuckThinks = 0
			self._forcePathUntil = os.clock() + FORCE_PATH_TIME
		end
	else
		self._stuckThinks = 0
	end
end

function Enemy._tryAttack(self: Enemy, target: BasePart)
	local now = os.clock()
	if now - self._lastAttack < self.Definition.AttackCooldown then
		return
	end
	self._lastAttack = now
	local character = target.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character and character:IsA("Model") then
		humanoid:TakeDamage(self.Definition.Damage)
		-- The player flinches away from the zombie (HealthService also slows them briefly)
		Flinch.Trigger(character, target.Position - self.Root.Position)
	end
end

-- Where this enemy is heading this tick. Direct enemies head for the player, each along its own lane:
-- a point off to one side of the player (by its random _lane share of up to LANE_MAX studs) that
-- closes in on the player as the zombie gets nearer, so a crowd comes in as a wide front, not a line.
-- Flankers also head straight for the player until they are within StartDistance; then, for their
-- attack run, they head for a point swung Angle degrees out to one side, a fraction of the way in.
-- Re-aiming every tick turns that into a curve that closes in from the side, until EngageDistance
-- where they charge.
function Enemy._getChaseGoal(self: Enemy, target: BasePart, distanceSq: number): Vector3
	local away = self.Root.Position - target.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude < 0.1 then
		return target.Position
	end
	local flank = self.Definition.Flank
	if
		self.Definition.Behaviour ~= "Flank"
		or not flank
		or distanceSq > flank.StartDistance ^ 2
		or distanceSq <= flank.EngageDistance ^ 2
	then
		local side = Vector3.yAxis:Cross(flat.Unit)
		local spread = math.min(flat.Magnitude * LANE_SHARE, LANE_MAX)
		return target.Position + side * (self._lane * spread)
	end
	local swung = CFrame.Angles(0, math.rad(flank.Angle) * self._flankSide, 0):VectorToWorldSpace(flat)
	return target.Position + swung * flank.GoalDistanceFactor
end

-- Walk straight at the goal when nothing is in the way. Use (rate-limited) pathfinding when a wall
-- blocks the way, when the player is well above the zombie (on a roof, ledge or stairs), or when it
-- has kept getting stuck. If no path exists, it still walks straight at the goal. Either way it is
-- steered round whatever is right in front of it (see _steer).
function Enemy._chase(self: Enemy, target: BasePart, distanceSq: number, mapParams: RaycastParams)
	local position = self.Root.Position
	local unreachable = os.clock() < self._forcePathUntil or target.Position.Y - position.Y > PATH_HEIGHT_GAP
	-- When it cannot reach the player directly, path to the player rather than to a flank point
	local goal = if unreachable then target.Position else self:_getChaseGoal(target, distanceSq)
	local direct = self.Definition.DirectChaseDistance
	if not unreachable then
		local blocked = workspace:Raycast(position, goal - position, mapParams)
		if not blocked or distanceSq < direct * direct then
			self._waypoints = nil
			self:_steer(goal, true)
			return
		end
	end

	-- Rate-limited even after a failed attempt, so a crowd under an unreachable player stays cheap
	if os.clock() - self._lastPathTime > self.Definition.PathRecomputeInterval then
		self:_requestPath(goal)
	end
	self:_followPath(goal)
end

local function turnedToSide(forward: Vector3, side: number, angle: number): Vector3
	return CFrame.fromAxisAngle(Vector3.yAxis, angle * side):VectorToWorldSpace(forward)
end

-- Nothing (zombie, corpse or wall) within SIDESTEP_PROBE studs, `angle` off to that side of `forward`.
function Enemy._isGapAt(self: Enemy, forward: Vector3, side: number, angle: number): boolean
	local direction = turnedToSide(forward, side, angle) * SIDESTEP_PROBE
	return workspace:Spherecast(self.Root.Position, BLOCK_CHECK_RADIUS, direction, self._selfParams) == nil
end

-- Walks towards `goal`, steering round what is right in front of it instead of pushing into it:
-- * Another living zombie it may not climb yet: it edges left or right (SIDESTEP_ANGLE) into a gap,
--   so the horde spreads out and fills the space, every zombie getting as close as it can. If it
--   stays jammed, _updateClimbing lets it climb over instead.
-- * A wall (and no pile under it to scale it from), when `slideAlongWalls`: it slides along the wall
--   (WALL_SIDESTEP_ANGLE), keeping to one side for WALL_SIDESTEP_TIME, so it works its way round to
--   the end of the wall.
-- * Corpses, climbable zombies and walls it is scaling from the pile: straight on, it climbs them.
-- What counts as "in front" is measured towards the goal, so turning aside does not lose track of it.
function Enemy._steer(self: Enemy, goal: Vector3, slideAlongWalls: boolean)
	local position = self.Root.Position
	local toGoal = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	if toGoal.Magnitude < 0.01 then
		self.Humanoid:MoveTo(goal)
		return
	end
	local forward = toGoal.Unit
	self._heading = forward

	local angle, holdTime = 0, 0
	if self._legless then
		angle = 0
	elseif self._blockedByLiving and not self._canClimb then
		angle, holdTime = SIDESTEP_ANGLE, SIDESTEP_TIME
	elseif slideAlongWalls and self._wallAhead and not self._standingOnCrowd and not self._blockedByCrowd then
		angle, holdTime = WALL_SIDESTEP_ANGLE, WALL_SIDESTEP_TIME
	end
	if angle == 0 then
		self._sidestepSide = 0
		self.Humanoid:MoveTo(goal)
		return
	end

	local now = os.clock()
	if self._sidestepSide == 0 or now >= self._sidestepUntil then
		local leftFree, rightFree = self:_isGapAt(forward, 1, angle), self:_isGapAt(forward, -1, angle)
		if leftFree and rightFree then
			-- Both open: keep going the way it was, or pick one
			if self._sidestepSide == 0 then
				self._sidestepSide = if rng:NextNumber() < 0.5 then 1 else -1
			end
		elseif leftFree then
			self._sidestepSide = 1
		elseif rightFree then
			self._sidestepSide = -1
		else
			self._sidestepSide = 0 -- boxed in: keep pushing (and climb once jammed long enough)
		end
		self._sidestepUntil = now + holdTime
	end
	if self._sidestepSide == 0 then
		self.Humanoid:MoveTo(goal)
	else
		self.Humanoid:MoveTo(position + turnedToSide(forward, self._sidestepSide, angle) * SIDESTEP_PROBE)
	end
end

-- ComputeAsync yields, so it runs on its own thread while the enemy keeps following its previous path.
function Enemy._requestPath(self: Enemy, goal: Vector3)
	if self._computingPath then
		return
	end
	self._computingPath = true
	self._lastPathTime = os.clock()
	task.spawn(function()
		local ok = pcall(function()
			self._path:ComputeAsync(self.Root.Position, goal)
		end)
		self._computingPath = false
		if self.State == "Dead" then
			return
		end
		if ok and self._path.Status == Enum.PathStatus.Success then
			self._waypoints = self._path:GetWaypoints()
			self._waypointIndex = FIRST_WAYPOINT
		else
			self._waypoints = nil
		end
	end)
end

function Enemy._followPath(self: Enemy, goal: Vector3)
	local waypoints = self._waypoints
	local waypoint = waypoints and waypoints[self._waypointIndex]
	if not waypoint then
		self:_steer(goal, true) -- no path: straight at the goal, sliding along any wall in the way
		return
	end
	-- Jump waypoints are ignored: zombies never jump walls. The path already goes round walls, so it
	-- only steers round other zombies here.
	self:_steer(waypoint.Position, false)

	local offset = waypoint.Position - self.Root.Position
	local reach = self.Definition.WaypointReachedDistance
	if offset.X * offset.X + offset.Z * offset.Z < reach * reach then
		self._waypointIndex += 1
	end
end

-- Stops the AI and disconnects everything. The model itself is left to EnemyService (corpse or cleanup).
function Enemy.Destroy(self: Enemy)
	self.State = "Dead"
	self._maid:Destroy()
end

return Enemy
