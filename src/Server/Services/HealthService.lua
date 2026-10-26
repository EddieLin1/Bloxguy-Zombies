--!strict
-- Out-of-combat healing: after HealthRegenDelay seconds without taking damage, players heal over time.
-- Roblox's default regen is disabled (src/Character/Health.server.lua) so the delay is controlled here.
-- Taking damage also staggers the player: they walk slower for PlayerStaggerDuration seconds.
-- Heal and hurt visuals/sounds are client-side (HealthFeedbackController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameRules = require(Shared.Definitions.GameRules)
local Maid = require(Shared.Util.Maid)
local PlayerService = require(script.Parent.PlayerService)

local TICK = 0.25

type Tracked = {
	Humanoid: Humanoid,
	LastDamage: number,
	LastHealth: number,
	BaseWalkSpeed: number,
	StaggerThread: thread?, -- restores walk speed when the current stagger ends
	Maid: Maid.Maid,
}

local HealthService = {}

local tracked: { [Player]: Tracked } = {}

local function cancelStagger(entry: Tracked)
	local thread = entry.StaggerThread
	if thread and coroutine.status(thread) ~= "dead" then
		task.cancel(thread)
	end
	entry.StaggerThread = nil
end

local function stopTracking(player: Player)
	local entry = tracked[player]
	if entry then
		cancelStagger(entry)
		entry.Maid:Destroy()
		tracked[player] = nil
	end
end

-- Slows the player briefly. A new hit restarts the timer instead of stacking the slow.
local function stagger(entry: Tracked)
	cancelStagger(entry)
	local humanoid = entry.Humanoid
	humanoid.WalkSpeed = entry.BaseWalkSpeed * (1 - math.clamp(GameRules.PlayerStaggerSlow, 0, 1))
	entry.StaggerThread = task.delay(GameRules.PlayerStaggerDuration, function()
		entry.StaggerThread = nil
		humanoid.WalkSpeed = entry.BaseWalkSpeed
	end)
end

local function onCharacterSpawned(player: Player, character: Model)
	stopTracking(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local entry: Tracked = {
		Humanoid = humanoid,
		LastDamage = 0,
		LastHealth = humanoid.Health,
		BaseWalkSpeed = humanoid.WalkSpeed,
		StaggerThread = nil,
		Maid = Maid.new(),
	}
	-- Any drop in health counts as damage, whatever caused it
	entry.Maid:GiveTask(humanoid.HealthChanged:Connect(function(health: number)
		if health < entry.LastHealth then
			entry.LastDamage = os.clock()
			if health > 0 then
				stagger(entry)
			end
		end
		entry.LastHealth = health
	end))
	tracked[player] = entry
end

local function step(dt: number)
	local now = os.clock()
	for _, entry in tracked do
		local humanoid = entry.Humanoid
		if
			humanoid.Health > 0
			and humanoid.Health < humanoid.MaxHealth
			and now - entry.LastDamage >= GameRules.HealthRegenDelay
		then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + GameRules.HealthRegenPerSecond * dt)
		end
	end
end

function HealthService.Init()
	PlayerService.CharacterSpawned:Connect(onCharacterSpawned)
	PlayerService.CharacterRemoving:Connect(stopTracking)
	PlayerService.PlayerLeft:Connect(stopTracking)
end

function HealthService.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		step(accumulator)
		accumulator = 0
	end)
end

return HealthService
