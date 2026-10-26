---
name: roblox-gameplay-loop
description: Use when building the round, wave, lobby, win/lose, scoring or reward flow of a Roblox game. Covers a server-side GameService state machine, data-driven wave definitions, event-based wave completion instead of polling, cancellation, replication of game state to clients, and cleanup between rounds.
---

# Gameplay loop (waves and rounds)

## Principles
- One server-side `GameService` owns the match flow. Clients never start, skip or end rounds on their own; at most they request "ready" or "skip" through validated remotes.
- Wave content is data (`Shared/Definitions/Waves`), not code. The loop reads the data; designers change numbers.
- Wait on events, not on tight polling loops. Where polling is unavoidable, poll at a low rate (0.25 to 0.5 s) with `task.wait`.
- Everything created during a round is owned by that round and torn down when it ends.

## States
`Lobby -> Intermission -> WaveActive -> WaveComplete -> (Intermission | Victory | Defeat) -> Lobby`

Model it as an explicit state variable plus one function per state. Keep each state function short and delegate to helpers; a 1000-line loop body is a sign the logic needs to be split. Put the main run function at the bottom of the file so helpers read top to bottom.

## Wave definitions
```lua
--!strict
-- Shared/Definitions/Waves
return {
	{ Enemies = { { Id = "Walker", Count = 10 } }, SpawnInterval = 0.8, Bonus = 100 },
	{ Enemies = { { Id = "Walker", Count = 14 }, { Id = "Runner", Count = 4 } }, SpawnInterval = 0.6, Bonus = 150 },
	-- generate later waves with a formula in a helper if the list gets long
}
```
Keep difficulty scaling (count, health multiplier, spawn rate) as a function of wave number in one module so balancing happens in one place.

## GameService skeleton
```lua
--!strict
local Players = game:GetService("Players")

local GameService = {}

local INTERMISSION = 10
local MIN_PLAYERS = 1

local state = "Lobby"
local currentWave = 0
local remaining = 0
local aborted = false

local waveFinished = Instance.new("BindableEvent")

local function setState(newState: string)
	state = newState
	workspace:SetAttribute("GameState", newState)   -- clients read/listen to this for UI
end

local function runWave(waveNumber: number)
	local def = WaveDefinitions.Get(waveNumber)
	remaining = EnemySpawner.Total(def)
	workspace:SetAttribute("EnemiesRemaining", remaining)
	setState("WaveActive")
	EnemySpawner.Run(def)                 -- spawns over time, respecting caps
	if remaining > 0 and not aborted then
		waveFinished.Event:Wait()         -- fired by the EnemyDied handler when remaining hits 0 or on abort
	end
end

function GameService.Init()
	EnemyService.EnemyDied:Connect(function(_enemy, killer)
		RewardService.OnKill(killer)
		remaining -= 1
		workspace:SetAttribute("EnemiesRemaining", remaining)
		if remaining <= 0 then
			waveFinished:Fire()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if #Players:GetPlayers() <= 1 then   -- the leaving player is still counted at this point
			aborted = true
			waveFinished:Fire()
		end
	end)
end

function GameService.Start()
	while true do
		setState("Lobby")
		repeat task.wait(1) until #Players:GetPlayers() >= MIN_PLAYERS
		aborted = false
		currentWave = 0
		MapService.Load()
		while not aborted do
			currentWave += 1
			workspace:SetAttribute("Wave", currentWave)
			setState("Intermission")
			for t = INTERMISSION, 1, -1 do
				workspace:SetAttribute("Countdown", t)
				if aborted then break end
				task.wait(1)
			end
			if aborted then break end
			runWave(currentWave)
			if aborted then break end
			RewardService.WaveBonus(WaveDefinitions.Get(currentWave).Bonus)
			if currentWave >= WaveDefinitions.Count() then
				setState("Victory")
				break
			end
		end
		EnemyService.ClearAll()
		MapService.Unload()
		task.wait(5)
	end
end

return GameService
```
Adapt the loop for the game: co-op loss conditions (all players dead) fire `aborted` and set `Defeat`; a Boxhead-style endless mode simply never reaches `Victory`.

## Skipping and cancelling
- Use a flag or token the waiting code checks (`aborted`, `skipRequested`) and fire the wait event to wake it; do not rely on destroying scripts.
- If a wave runs in a coroutine/thread, keep its handle so `task.cancel(thread)` can stop it, and make sure cleanup runs afterwards.
- Loops that count down should check the cancel flag each step (`for t = N, 1, -1`), so aborting is immediate.

## Replicating state to clients
- Put current state in Attributes on a stable instance (e.g. `workspace` or a `GameState` folder in ReplicatedStorage): `GameState`, `Wave`, `Countdown`, `EnemiesRemaining`. Clients use `GetAttributeChangedSignal` to update HUD. No remote needed for values that just need to be displayed.
- Use RemoteEvents for one-off notifications (e.g. "wave cleared" banner, "boss incoming"), and for the few client requests (`ReadyUp`, `SkipIntermission`), validated on the server.

## Rewards and progression
- Currency, score and XP are granted by the server in response to server events (`EnemyDied`, wave complete). Never from a remote.
- Accumulate per-player stats in the player's data object (see `roblox-player-data`) and persist at wave end or session end, not every kill.

## Spawning inside the loop
- `EnemySpawner.Run` spawns in batches with `task.wait(def.SpawnInterval)` between them, respects a global alive cap, and picks spawn points from tagged parts (`"EnemySpawn"`), preferably far from players.
- Do not spawn more than the cap even if the wave definition says so; queue the remainder.

## Cleanup between rounds
- Clear all enemies, projectiles, pickups and effects through their services' `ClearAll()`.
- Reset per-round player state (health, ammo, temporary buffs) deliberately.
- Destroy the cloned map and anything the round parented to `workspace`. Round-scoped connections live in a round Maid destroyed at the end.

## Edge cases to handle
- Player joins mid-wave (spawn them in, give starting loadout).
- Player dies mid-wave (respawn rules, spectator, or revive).
- Last player leaves mid-wave.
- Server shutting down mid-round (save data in `BindToClose`, see `roblox-player-data`).

## Based on
DevForum: "Best Game-Round System", "Best Way To Do A Round System", "Tower Defense Round System" (module per wave, server-side flow, remotes only for ready/skip), "Round system structure issue", "Round system feedback" (`task.wait`, avoid busy polling).
