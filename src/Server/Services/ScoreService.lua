--!strict
-- Kills, points and the kill combo, granted only from server events. Combo milestones unlock or refill weapons.
-- Stats are per match (not saved); they replicate through Player attributes and leaderstats for display.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)
local Net = require(Shared.Net)
local WeaponDefinitions = require(Shared.Definitions.Weapons)
local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)

local Attributes = Constants.Attributes

type Stats = {
	Points: number,
	Kills: number,
	Combo: number,
	ComboExpire: number, -- workspace:GetServerTimeNow() when the combo starts counting down
	BestCombo: number,
	ComboDecay: thread?,
	KillsValue: IntValue,
	PointsValue: IntValue,
}

local ScoreService = {}

local stats: { [Player]: Stats } = {}
local weaponUnlocked = Net.Event("WeaponUnlocked")
local weaponRefilled = Net.Event("WeaponRefilled")

local function publish(player: Player, s: Stats)
	player:SetAttribute(Attributes.Points, s.Points)
	player:SetAttribute(Attributes.Kills, s.Kills)
	player:SetAttribute(Attributes.Combo, s.Combo)
	player:SetAttribute(Attributes.ComboExpire, s.ComboExpire)
	s.KillsValue.Value = s.Kills
	s.PointsValue.Value = s.Points
end

local function cancelComboDecay(s: Stats)
	local thread = s.ComboDecay
	if thread then
		task.cancel(thread)
		s.ComboDecay = nil
	end
end

-- After ComboTimeout without a kill, the combo counts down one point per ComboDecayInterval.
-- A kill cancels this and the combo carries on from wherever it had dropped to.
local function scheduleComboDecay(player: Player, s: Stats)
	cancelComboDecay(s)
	s.ComboDecay = task.delay(GameRules.ComboTimeout, function()
		while s.Combo > 0 do
			s.Combo -= 1
			publish(player, s)
			task.wait(GameRules.ComboDecayInterval)
		end
		s.ComboDecay = nil
	end)
end

local function createStats(player: Player): Stats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = leaderstats
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Parent = leaderstats
	leaderstats.Parent = player

	return {
		Points = 0,
		Kills = 0,
		Combo = 0,
		ComboExpire = 0,
		BestCombo = 0,
		ComboDecay = nil,
		KillsValue = kills,
		PointsValue = points,
	}
end

local function resetStats(s: Stats)
	cancelComboDecay(s)
	s.Points = 0
	s.Kills = 0
	s.Combo = 0
	s.ComboExpire = 0
	s.BestCombo = 0
end

-- Each weapon has a combo milestone: the first time it unlocks it, later times refill it.
local function checkMilestones(player: Player, combo: number)
	for _, definition in WeaponDefinitions.All() do
		if definition.UnlockCombo > 0 and definition.UnlockCombo == combo then
			if WeaponService.Unlock(player, definition.Id) then
				weaponUnlocked:FireClient(player, definition.Id)
			else
				WeaponService.Refill(player, definition.Id)
				weaponRefilled:FireClient(player, definition.Id)
			end
		end
	end
end

local function onEnemyDied(_enemy: any, killer: Player?, _position: Vector3)
	local s = killer and stats[killer]
	if not killer or not s then
		return
	end
	local now = workspace:GetServerTimeNow()
	s.Combo += 1 -- continues from the current value, even mid-countdown
	s.BestCombo = math.max(s.BestCombo, s.Combo)
	s.ComboExpire = now + GameRules.ComboTimeout
	s.Kills += 1
	s.Points += GameRules.PointsPerKill * s.Combo
	scheduleComboDecay(killer, s)
	publish(killer, s)
	checkMilestones(killer, s.Combo)
end

function ScoreService.ResetAll()
	for player, s in stats do
		resetStats(s)
		publish(player, s)
	end
end

function ScoreService.Init()
	PlayerService.PlayerJoined:Connect(function(player: Player)
		local s = createStats(player)
		stats[player] = s
		publish(player, s)
	end)
	PlayerService.PlayerLeft:Connect(function(player: Player)
		local s = stats[player]
		if s then
			cancelComboDecay(s)
			stats[player] = nil
		end
	end)
	EnemyService.EnemyDied:Connect(onEnemyDied)
end

return ScoreService
