--!strict
-- Blood and gore on zombies, all drawn locally from what the server reports:
-- * Headshot deaths (HeadshotDeath attribute, see Enemy._applyHeadshotDeath):
--   "Explode": a huge burst where the head was, and blood pouring from the neck;
--   "PopOff": a burst, and blood pouring from both the neck and the flying head.
-- * Severed limbs (LimbSevered remote, see Server/Util/Dismember): a burst, and blood pouring from
--   the stump and from the limb itself.
-- * Legless zombies (Legless attribute) leave a trail of blood stains while they crawl.
-- * Every zombie that dies leaves a faint pool of blood where it fell.
-- * When a new game starts (the Intermission after Game Over), all blood is wiped off the ground.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local Net = require(Shared.Net)
local Effects = script.Parent.Parent.Effects
local BloodPour = require(Effects.BloodPour)
local BloodSplash = require(Effects.BloodSplash)
local BloodStains = require(Effects.BloodStains)

local TORSO_NAMES = { "Torso", "UpperTorso" } -- R6, R15
local DOWN = CFrame.Angles(math.pi, 0, 0)
local TRAIL_INTERVAL = 0.4 -- seconds between trail stains under a crawling zombie
local TRAIL_MIN_SPEED = 1 -- only leave a trail while actually moving
local DEATH_POOL_DELAY = 1 -- seconds after death, so the pool lands where the body settled
local HUMANOID_TIMEOUT = 5

local GoreController = {}

type Tracked = {
	Maid: Maid.Maid,
	Legless: boolean,
	Alive: boolean,
}

local tracked: { [Model]: Tracked } = {}

local function findTorso(model: Model): BasePart?
	for _, name in TORSO_NAMES do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- A frame at `position` (in a part's space) whose +Y points away from the part's centre,
-- which is the way blood sprays out of a stump.
local function outwardFrame(position: Vector3): CFrame
	if position.Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position * 2) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function playHeadshotDeath(model: Model)
	local outcome = model:GetAttribute(Constants.Attributes.HeadshotDeath)
	local position = model:GetAttribute(Constants.Attributes.HeadshotDeathPosition)
	if typeof(position) ~= "Vector3" then
		return
	end

	-- Blood spurts up out of the top of the torso, where the neck was
	local torso = findTorso(model)
	if torso then
		BloodPour.Start(torso, CFrame.new(0, torso.Size.Y / 2, 0))
	end

	local above = position + Vector3.yAxis
	if outcome == "Explode" then
		BloodSplash.Play(position, above, "Explosion")
	elseif outcome == "PopOff" then
		BloodSplash.Play(position, above, "Headshot")
		-- ...and drips out of the bottom of the head as it flies
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			BloodPour.Start(head, CFrame.new(0, -head.Size.Y / 2, 0) * DOWN)
		end
	end
end

local function onLimbSevered(body: unknown, c0: unknown, limb: unknown, c1: unknown)
	if typeof(c0) ~= "CFrame" or typeof(c1) ~= "CFrame" then
		return
	end
	if typeof(body) == "Instance" and body:IsA("BasePart") then
		BloodPour.Start(body, outwardFrame(c0.Position)) -- the stump
	end
	if typeof(limb) == "Instance" and limb:IsA("BasePart") then
		BloodPour.Start(limb, outwardFrame(c1.Position)) -- the torn end of the limb
		BloodSplash.Play(limb.Position, limb.Position + Vector3.yAxis, "Headshot")
	end
end

local function watchDeath(model: Model, entry: Tracked)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
	if not humanoid or not humanoid:IsA("Humanoid") or not tracked[model] then
		return
	end
	entry.Maid:GiveTask(humanoid.Died:Connect(function()
		entry.Alive = false
		entry.Maid:GiveTask(task.delay(DEATH_POOL_DELAY, function()
			local torso = findTorso(model)
			if torso then
				BloodStains.Paint(torso.Position, "Pool")
			end
		end))
	end))
end

local function onAdded(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local entry: Tracked = { Maid = Maid.new(), Legless = false, Alive = true }
	tracked[instance] = entry
	local function refreshLegless()
		entry.Legless = instance:GetAttribute(Constants.Attributes.Legless) == true
	end
	entry.Maid:GiveTask(instance:GetAttributeChangedSignal(Constants.Attributes.HeadshotDeath):Connect(function()
		playHeadshotDeath(instance)
	end))
	entry.Maid:GiveTask(instance:GetAttributeChangedSignal(Constants.Attributes.Legless):Connect(refreshLegless))
	refreshLegless()
	task.spawn(watchDeath, instance, entry)
end

local function onRemoved(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	if entry then
		entry.Maid:Destroy()
		tracked[instance] = nil
	end
end

-- Legless zombies drag themselves along, leaving a trail of stains.
local function paintTrails()
	for model, entry in tracked do
		if entry.Legless and entry.Alive then
			local torso = findTorso(model)
			if torso then
				local velocity = torso.AssemblyLinearVelocity
				if Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= TRAIL_MIN_SPEED then
					BloodStains.Paint(torso.Position, "Trail")
				end
			end
		end
	end
end

function GoreController.Start()
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Enemy):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.Enemy):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(Constants.Tags.Enemy) do
		onAdded(instance)
	end
	Net.Event("LimbSevered").OnClientEvent:Connect(onLimbSevered)

	-- A new game starts with a clean floor: wipe the blood when the next intermission begins
	ReplicatedStorage:GetAttributeChangedSignal(Constants.Attributes.GameState):Connect(function()
		if ReplicatedStorage:GetAttribute(Constants.Attributes.GameState) == Constants.GameStates.Intermission then
			BloodStains.ClearAll()
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < TRAIL_INTERVAL then
			return
		end
		accumulator = 0
		paintTrails()
	end)
end

return GoreController
