--!strict
-- One enemy. Holds its authoritative health and AI state; EnemyService calls Think() from its single loop.
-- The class knows nothing about waves, score or UI; it only reports when it is removed.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Util.Maid)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local Ragdoll = require(script.Parent.Parent.Util.Ragdoll)

local DISABLED_STATES = {
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Climbing,
}
local WALK_ANIMATION_MIN_SPEED = 0.5
local FIRST_WAYPOINT = 2 -- waypoint 1 is the start position

export type EnemyState = "Idle" | "Chase" | "Attack" | "Dead"

-- What EnemyService hands every enemy on each AI tick.
export type World = {
	Targets: { BasePart }, -- root parts of living players
	MapParams: RaycastParams, -- ignores characters, enemies and pickups
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
	_path: Path,
	_waypoints: { PathWaypoint }?,
	_waypointIndex: number,
	_lastPathTime: number,
	_computingPath: boolean,
	_lastAttack: number,
	_maid: Maid.Maid,
}, Enemy))

local animations: { [string]: Animation } = {}

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
	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end

	local maid = Maid.new()
	local agent = definition.Agent
	local path = maid:GiveTask(PathfindingService:CreatePath({
		AgentRadius = agent.Radius,
		AgentHeight = agent.Height,
		AgentCanJump = agent.CanJump,
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
		_path = path,
		_waypoints = nil :: { PathWaypoint }?,
		_waypointIndex = 0,
		_lastPathTime = 0,
		_computingPath = false,
		_lastAttack = 0,
		_maid = maid,
	}, Enemy)

	maid:GiveTask(humanoid.Died:Connect(function()
		Ragdoll.Enable(model)
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
	self._maid:GiveTask(self.Humanoid.Running:Connect(function(speed: number)
		if speed > WALK_ANIMATION_MIN_SPEED and not track.IsPlaying then
			track:Play()
		elseif speed <= WALK_ANIMATION_MIN_SPEED and track.IsPlaying then
			track:Stop()
		end
	end))
end

-- Only EnemyService.Damage should call this. Reaching 0 kills the Humanoid, which fires Removed.
function Enemy.TakeDamage(self: Enemy, amount: number, source: Player?)
	if self.State == "Dead" or self.Health <= 0 then
		return
	end
	self.Health = math.max(0, self.Health - amount)
	self.LastAttacker = source
	self.Humanoid.Health = self.Health
end

function Enemy.Think(self: Enemy, world: World)
	if self.State == "Dead" then
		return
	end
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
		self.Humanoid:MoveTo(target.Position)
		self:_tryAttack(target)
	else
		self.State = "Chase"
		self:_chase(target, distanceSq, world.MapParams)
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
	if humanoid then
		humanoid:TakeDamage(self.Definition.Damage)
	end
end

-- Walk straight at the target unless a wall is in the way; only then use (rate-limited) pathfinding.
function Enemy._chase(self: Enemy, target: BasePart, distanceSq: number, mapParams: RaycastParams)
	local position = self.Root.Position
	local direct = self.Definition.DirectChaseDistance
	local blocked = workspace:Raycast(position, target.Position - position, mapParams)
	if not blocked or distanceSq < direct * direct then
		self._waypoints = nil
		self.Humanoid:MoveTo(target.Position)
		return
	end

	if not self._waypoints or os.clock() - self._lastPathTime > self.Definition.PathRecomputeInterval then
		self:_requestPath(target.Position)
	end
	self:_followPath(target)
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

function Enemy._followPath(self: Enemy, target: BasePart)
	local waypoints = self._waypoints
	local waypoint = waypoints and waypoints[self._waypointIndex]
	if not waypoint then
		self.Humanoid:MoveTo(target.Position)
		return
	end
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self.Humanoid.Jump = true
	end
	self.Humanoid:MoveTo(waypoint.Position)

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
