--!strict
-- Owns the match flow as an explicit state machine:
--   Waiting -> Intermission -> WaveActive -> WaveComplete -> WaveActive ... -> GameOver -> Waiting
-- Waves end on events (last enemy removed, last player dead or gone), not by polling.
-- State replicates through attributes on ReplicatedStorage; clients only display it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)
local Signal = require(Shared.Util.Signal)
local Waves = require(Shared.Definitions.Waves)
local Types = require(Shared.Types)
local EnemyService = require(script.Parent.EnemyService)
local PickupService = require(script.Parent.PickupService)
local PlayerService = require(script.Parent.PlayerService)
local ScoreService = require(script.Parent.ScoreService)
local WeaponService = require(script.Parent.WeaponService)

local States = Constants.GameStates
local Attributes = Constants.Attributes

local LOBBY_POLL_INTERVAL = 1

type WaveOutcome = "Cleared" | "Defeat"

local GameService = {}

local rng = Random.new()
local state = States.Waiting
local waveRunning = false
local enemiesRemaining = 0
local waveEnded = Signal.new() -- (outcome: WaveOutcome)

local function setState(newState: string)
	state = newState
	ReplicatedStorage:SetAttribute(Attributes.GameState, newState)
end

local function setEnemiesRemaining(count: number)
	enemiesRemaining = math.max(0, count)
	ReplicatedStorage:SetAttribute(Attributes.EnemiesRemaining, enemiesRemaining)
end

-- Sets the countdown before the state so the HUD never shows a stale number.
local function runCountdown(stateName: string, seconds: number, eachSecond: (() -> ())?)
	for remaining = seconds, 1, -1 do
		ReplicatedStorage:SetAttribute(Attributes.Countdown, remaining)
		if state ~= stateName then
			setState(stateName)
		end
		if eachSecond then
			eachSecond()
		end
		task.wait(1)
	end
end

local function endWave(outcome: WaveOutcome)
	if not waveRunning then
		return
	end
	waveRunning = false
	waveEnded:Fire(outcome)
end

local function checkDefeat(leaving: Player?)
	if waveRunning and #PlayerService.GetAlivePlayers(leaving) == 0 then
		endWave("Defeat")
	end
end

local function clearRound()
	waveRunning = false
	EnemyService.ClearAll()
	PickupService.ClearAll()
	setEnemiesRemaining(0)
end

-- Spawns the whole wave over time, one every SpawnInterval. There is no cap on zombies alive at once.
local function spawnWaveEnemies(wave: Types.WaveDefinition)
	for _ = 1, wave.Count do
		EnemyService.Spawn(Waves.PickEnemyId(wave, rng), wave)
		task.wait(wave.SpawnInterval)
	end
end

local function runWaiting()
	setState(States.Waiting)
	while #Players:GetPlayers() == 0 do
		task.wait(LOBBY_POLL_INTERVAL)
	end
end

local function runIntermission()
	-- Anyone who joined during Game Over spawns now and can run around
	runCountdown(States.Intermission, GameRules.Intermission, PlayerService.RespawnDead)
end

local function startMatch()
	clearRound()
	ScoreService.ResetAll()
	WeaponService.ResetAll()
	PlayerService.SpawnAll()
	task.wait(GameRules.MatchStartDelay)
end

local function runWave(number: number): WaveOutcome
	local wave = Waves.Get(number)
	ReplicatedStorage:SetAttribute(Attributes.Wave, number)
	setEnemiesRemaining(wave.Count)
	setState(States.WaveActive)
	if #PlayerService.GetAlivePlayers() == 0 then
		return "Defeat"
	end

	waveRunning = true
	local spawner = task.spawn(spawnWaveEnemies, wave)
	local outcome: WaveOutcome = waveEnded:Wait()
	if coroutine.status(spawner) ~= "dead" then
		task.cancel(spawner)
	end
	return outcome
end

-- Plays waves until everyone is dead. The Wave attribute keeps the wave reached for the Game Over screen.
local function runMatch()
	local number = 0
	while true do
		number += 1
		if runWave(number) == "Defeat" then
			return
		end
		runCountdown(States.WaveComplete, GameRules.WaveBreak)
	end
end

local function runGameOver()
	setState(States.GameOver)
	task.wait(GameRules.GameOverTime)
	clearRound()
end

function GameService.Init()
	ReplicatedStorage:SetAttribute(Attributes.GameState, state)
	ReplicatedStorage:SetAttribute(Attributes.Wave, 0)
	ReplicatedStorage:SetAttribute(Attributes.Countdown, 0)
	setEnemiesRemaining(0)

	EnemyService.EnemyRemoved:Connect(function()
		if not waveRunning then
			return
		end
		setEnemiesRemaining(enemiesRemaining - 1)
		if enemiesRemaining <= 0 then
			endWave("Cleared")
		end
	end)
	PlayerService.PlayerDied:Connect(function()
		checkDefeat(nil)
	end)
	PlayerService.PlayerLeft:Connect(function(player: Player)
		checkDefeat(player)
	end)
	-- Joining mid-match or during intermission: spawn right away. During Game Over, wait for intermission.
	PlayerService.PlayerJoined:Connect(function(player: Player)
		if state ~= States.GameOver then
			PlayerService.Spawn(player)
		end
	end)
end

function GameService.Start()
	while true do
		runWaiting()
		runIntermission()
		startMatch()
		runMatch()
		runGameOver()
	end
end

return GameService
