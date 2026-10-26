# Bloxguy Zombies

Boxhead-style top-down zombie shooter for Roblox, written in Luau and synced with Rojo (`default.project.json`).

## Before writing any code

Read `roblox-skills/roblox-dev-index/SKILL.md` first. It sets the project conventions and says which other `roblox-skills/*/SKILL.md` files to load for the task. Load the respective skills according to the task before you write or change any code.

If you update code, update the README.md as well.

## Layout

Source lives in `src/`, mapped into the place by `default.project.json`:

- `src/Shared` -> `ReplicatedStorage.Shared`: `Definitions/` (weapons, enemies, waves, pickups, game rules: pure data), `Types`, `Constants`, `Net` (every remote), `Util/` (Maid, Signal, Pool, Spread).
- `src/Server` -> `ServerScriptService.Server`: bootstrap Script, `Services/` (Player, Enemy, Weapon, Score, Pickup, Health, Game), `Weapons/` (GunController, firing components), `Enemies/` (Enemy class, rig, spawn locator), `Util/`.
- `src/Client` -> `StarterPlayerScripts.Client`: bootstrap LocalScript, `Controllers/` (Camera, Weapon, Crate, HealthFeedback, BodyPose, Gore, Spectate, UI), `UI/` (one module per HUD component), `Effects/`.
- `src/Character/Health.server.lua` -> `StarterCharacterScripts.Health`: empty override that disables Roblox's instant regen (HealthService handles delayed regen).
- `roblox-skills/` holds the development guides described above.
- `Bloxguy Zombies (Playable).rbxlx` is the place file.
