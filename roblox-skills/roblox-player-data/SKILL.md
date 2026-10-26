---
name: roblox-player-data
description: Use when saving or loading player data in a Roblox game: DataStoreService, ProfileService or ProfileStore, session locking, retries, autosave, BindToClose, data templates and schema migration, leaderstats, settings, inventories. Covers safe data lifecycle and replicating data to clients.
---

# Player data

## Principles
- Use a proven session-locking module (ProfileService, or its successor ProfileStore; verify the current recommended module and API before coding) rather than hand-rolled `GetAsync`/`SetAsync`. Hand-rolled versions typically lack session locking, which lets two servers write the same key and enables item duplication.
- Data is loaded when the player joins, held in memory on the server, mutated by server code only, and saved periodically, on leave and on shutdown.
- Never trust the client with data. The client receives a read-only replica and requests changes through validated remotes.

## What a good setup must have
1. **Session locking:** only one server owns a player's data at a time; others wait or reject the load. Prevents duplication exploits.
2. **Retries with exponential backoff** (for example 1 s, 2 s, 4 s, 8 s, then give up and handle failure).
3. **Atomic updates** (`UpdateAsync`, or a library that wraps it) instead of read-modify-write with `GetAsync` + `SetAsync`.
4. **Template reconciliation:** new fields added to the template are filled in for existing players; never wipe data to "reset" structure.
5. **Schema versioning and migrations:** a `Version` number in the data and migration functions as the structure evolves.
6. **Autosave** on an interval (around 60 to 120 seconds), staggered, plus save on `PlayerRemoving`.
7. **`BindToClose`** saves everyone before shutdown. Roblox grants a bounded grace period (about 30 seconds), so save all players **concurrently** (`task.spawn` per player, then wait for all) rather than one at a time.
8. **Failure handling:** if data fails to load, kick the player with a message (or put them in a no-save mode that is clearly flagged); never let them play on a blank profile that overwrites the real one.
9. **Respect budgets:** DataStore requests have rate limits; do not save on every kill or coin pickup. Save at natural boundaries (wave end, leave, autosave).
10. **Versioning/rollback:** keep DataStore versions available (`GetVersionAtTimeAsync`) so a bad deployment or exploit can be rolled back.

## Data template (server module)
```lua
--!strict
-- ServerScriptService/Data/Template
return {
	Version = 1,
	Currency = { Coins = 0 },
	Stats = { Kills = 0, BestWave = 0, GamesPlayed = 0 },
	Unlocks = { Weapons = { Pistol = true } },
	Settings = { CameraShake = true, MusicVolume = 0.7 },
}
```
Keep values plain (numbers, strings, booleans, nested tables of those) so they serialise. Do not store Instances, Vector3 or functions directly.

## DataService pattern (ProfileService-style API; confirm against the module version you install)
```lua
--!strict
local Players = game:GetService("Players")
local ProfileService = require(game.ServerScriptService.Packages.ProfileService)
local Template = require(script.Parent.Template)

local DataService = {}

local profileStore = ProfileService.GetProfileStore("PlayerData_v1", Template)
local profiles: { [Player]: any } = {}

local function onPlayerAdded(player: Player)
	local profile = profileStore:LoadProfileAsync(`Player_{player.UserId}`, "ForceLoad")
	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)   -- data-deletion/GDPR support
	profile:Reconcile()                -- fill in missing template fields
	profile:ListenToRelease(function()
		profiles[player] = nil
		player:Kick("Your data was loaded on another server.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
		DataService.Loaded:Fire(player, profile.Data)   -- create a Signal; other services react
	else
		profile:Release()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Release()
	end
end

function DataService.Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return DataService
```
ProfileService releases and saves on `Release()` and autosaves internally, and its release/shutdown handling covers `BindToClose`; verify these behaviours in the version you use. If you write your own wrapper, you must implement the items in the list above yourself.

## Mutating data safely
- Expose narrow methods (`DataService.AddCoins(player, amount)`, `DataService.Unlock(player, id)`) that validate and then change `profile.Data`. Other services call these; no one reaches into the table ad hoc.
- Keep a server-side "is loaded" check; operations on players whose data has not loaded must queue or fail, not crash.
- Leaderstats are display only: mirror the saved value into them (or into Attributes), never read truth back from them.

## Replicating to the client
- Send a snapshot once after load (RemoteEvent, or Attributes for flat values) and send deltas on change. UI listens as in `roblox-ui`.
- Do not replicate the whole data table every change; replicate only what the UI needs.

## Studio vs live
Test data flows in a live test server (multiple joins and leaves, shutdown), not only Studio: session locks and `BindToClose` timing problems are mostly invisible in Studio. Guard Studio-only shortcuts with `RunService:IsStudio()` and use a separate test DataStore name.

## Checklist
- [ ] Session-locked, retrying, reconciled, versioned.
- [ ] Failed load never overwrites existing data.
- [ ] Save on leave, on interval, and at shutdown concurrently.
- [ ] Mutations go through validated DataService methods.
- [ ] Nothing in memory keeps references to players after they leave.

## Based on
DevForum: "DataStore best practices" (ProfileService, session locking, `BindToClose` pitfalls), "DataStore with SessionLocking", Creator Hub DataStore best practices and error codes/limits, community patterns for retry/backoff and concurrent `BindToClose` saves.
