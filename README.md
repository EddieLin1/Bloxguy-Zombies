# Bloxguy Zombies

A Boxhead-style wave-survival zombie shooter for Roblox, written in strict Luau and synced into Studio with [Rojo](https://rojo.space).

Zombies come in endless waves. Kills build a **combo**, and combo milestones unlock stronger weapons (Pistol → Uzi → Shotgun → Assault Rifle → Railgun). The match ends when every player is dead.

**Want to balance the game?** Every tunable value is listed in [Settable values (balancing)](#settable-values-balancing).

---

## Getting started

1. Install [Rojo](https://github.com/rojo-rbx/rojo/releases) and the Rojo plugin for Studio (`rojo plugin install`).
2. Open `Bloxguy Zombies (Playable).rbxlx` in Studio.
3. In a terminal in this folder, run `rojo serve`.
4. In Studio, go to **Plugins → Rojo → Connect**.
5. Press **Play**. After changing code, save the file, then press **Stop** and **Play** again in Studio.

Edit code in `src/` only. Rojo overwrites synced scripts, so edits made in Studio are lost. Build the map in Studio and save it with **File → Save**.

---

## How it fits together

```
VS Code (src/*.lua) ──save──► rojo serve ──► Studio (open place) ──Play──► playtest
                                                    │
                                          File → Save writes the .rbxlx
```

[`default.project.json`](default.project.json) tells Rojo where each folder goes:

| Folder | Becomes in the game | Runs on |
|---|---|---|
| `src/Shared` | `ReplicatedStorage.Shared` | Both (data, types, utilities) |
| `src/Server` | `ServerScriptService.Server` | Server only |
| `src/Client` | `StarterPlayer.StarterPlayerScripts.Client` | Each player's client |
| `src/Character/Health.server.lua` | `StarterPlayer.StarterCharacterScripts.Health` | Each character |

Rojo also turns on Roblox's Shift Lock (`EnableMouseLockOption`). It owns `ServerScriptService` and `StarterPlayerScripts` outright, so anything added there by hand in Studio is removed on sync.

### Architecture in one paragraph

There is **one server Script** ([`src/Server/init.server.lua`](src/Server/init.server.lua)) and **one client LocalScript** ([`src/Client/init.client.lua`](src/Client/init.client.lua)). Each one requires every module in its `Services/` or `Controllers/` folder, calls `Init()` on all of them (wiring only), then `Start()` on all of them (begin running). All game logic lives in those modules. **The server owns the truth** (health, ammo, damage, score, waves), and the client only sends intent ("I fired in this direction") and draws the results. Every tunable number lives in a data file under [`src/Shared/Definitions/`](src/Shared/Definitions/).

---

## Project structure

```
Bloxguy Zombies/
├── default.project.json          Rojo map: which folder goes where in the game
├── Bloxguy Zombies (Playable).rbxlx   The place file (map, lighting, settings)
├── CLAUDE.md                     Instructions for the AI assistant working on this repo
├── README.md                     This file
├── roblox-skills/                Development guides (conventions this code follows)
└── src/
    ├── Character/
    │   └── Health.server.lua     Disables Roblox's built-in instant health regen
    ├── Shared/                   → ReplicatedStorage.Shared (server + client)
    │   ├── Constants.lua         Attribute names, game states, folder names, tags
    │   ├── Net.lua               Every RemoteEvent in the game
    │   ├── Types.lua             Type shapes for all definition data
    │   ├── Definitions/          Pure data: change numbers here to balance the game
    │   │   ├── GameRules.lua     Round timings, caps, combo, health regen
    │   │   ├── Waves.lua         Wave size / health / speed formulas
    │   │   ├── Pickups.lua       Supply crate settings
    │   │   ├── Enemies/          init.lua (index) + Zombie.lua
    │   │   └── Weapons/          init.lua (index) + Pistol, Uzi, Shotgun, AssaultRifle, Railgun
    │   └── Util/
    │       ├── Maid.lua          Cleans up connections/instances/threads in one call
    │       ├── Signal.lua        Events between modules
    │       ├── Pool.lua          Reuses Instances instead of create/destroy
    │       ├── Spread.lua        Random bullet spread
    │       └── DefinitionIndex.lua  Loads every definition file in a folder
    ├── Server/                   → ServerScriptService.Server
    │   ├── init.server.lua       Server bootstrap
    │   ├── Services/             One module per game system
    │   │   ├── PlayerService.lua
    │   │   ├── EnemyService.lua
    │   │   ├── WeaponService.lua
    │   │   ├── ScoreService.lua
    │   │   ├── PickupService.lua
    │   │   ├── HealthService.lua
    │   │   └── GameService.lua
    │   ├── Weapons/
    │   │   ├── GunController.lua
    │   │   ├── ToolFactory.lua
    │   │   ├── WeaponTypes.lua
    │   │   └── Components/Firing/   init.lua (registry) + Hitscan.lua
    │   ├── Enemies/
    │   │   ├── Enemy.lua
    │   │   ├── ZombieRig.lua
    │   │   └── SpawnLocator.lua
    │   └── Util/
    │       ├── RemoteGuard.lua
    │       ├── WorldFolders.lua
    │       └── Ragdoll.lua
    └── Client/                   → StarterPlayerScripts.Client
        ├── init.client.lua       Client bootstrap
        ├── Controllers/
        │   ├── CameraController.lua
        │   ├── WeaponClientController.lua
        │   ├── CrateController.lua
        │   ├── SpectateController.lua
        │   └── UIController.lua
        ├── Effects/
        │   ├── Tracer.lua
        │   ├── ShotSound.lua
        │   └── HitSound.lua
        └── UI/                   One module per HUD piece
            ├── Text.lua
            ├── FadingText.lua
            ├── StatusBanner.lua
            ├── StatsPanel.lua
            ├── ComboMeter.lua
            ├── WeaponDisplay.lua
            ├── Crosshair.lua
            └── Toast.lua
```

---

## File reference

### Shared (`src/Shared`): used by both server and client

| File | What it is | Used by |
|---|---|---|
| [`Constants.lua`](src/Shared/Constants.lua) | Names shared by both sides: attribute names (`Points`, `Combo`, `Ammo`, `GameState`…), game state names (`Waiting`, `Intermission`, `WaveActive`, `WaveComplete`, `GameOver`), workspace folder names (`Enemies`, `Pickups`), the `EnemySpawn` and `Pickup` tags, and `INFINITE_AMMO`. | Almost every service, `GunController`, `ToolFactory`, `SpawnLocator`, and the HUD modules |
| [`Net.lua`](src/Shared/Net.lua) | The list of every remote. The server creates them in `ReplicatedStorage.Remotes`; the client waits for them. See [Remotes](#remotes). | `WeaponService`, `ScoreService`, `PickupService`, `WeaponClientController`, `UIController` |
| [`Types.lua`](src/Shared/Types.lua) | Type definitions (`WeaponDefinition`, `EnemyDefinition`, `WaveDefinition`, `PickupDefinition`). Strict mode checks every definition file against these. | Every definition file, plus most modules that handle weapons or enemies |

### Definitions (`src/Shared/Definitions`): the numbers you balance

| File | What it is | Used by |
|---|---|---|
| [`GameRules.lua`](src/Shared/Definitions/GameRules.lua) | Match-wide tunables: intermission/wave-break/game-over times, max zombies alive, spawn distances, health regen delay and rate, headshot multiplier, combo timeout and countdown speed, points per kill. | `GameService`, `ScoreService`, `HealthService`, `WeaponService`, `SpawnLocator`, `ComboMeter` |
| [`Waves.lua`](src/Shared/Definitions/Waves.lua) | Formulas that turn a wave number into zombie count, health, speed and spawn interval. Waves are endless. | `GameService` (each wave), `EnemyService.Spawn` (reads health and speed) |
| [`Pickups.lua`](src/Shared/Definitions/Pickups.lua) | The **supply crate** that zombies can drop: drop chance, how much it heals, how much ammo it refills, how long it lasts, pickup radius, size and colours. | `PickupService` |
| [`Enemies/init.lua`](src/Shared/Definitions/Enemies/init.lua) | Index that loads every enemy file in the folder. `Enemies.Get(id)` and `Enemies.All()`. | `EnemyService` |
| [`Enemies/Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua) | The zombie: damage, attack range and cooldown, speed variance, corpse time, pathfinding settings, colours, walk animation. (Health and speed come from the wave.) | Read through the index by `EnemyService`, `Enemy`, `ZombieRig` |
| [`Weapons/init.lua`](src/Shared/Definitions/Weapons/init.lua) | Index that loads every weapon file, sorted by unlock combo (that is also the hotbar order). `Weapons.Get(id)`, `Weapons.Find(id)`, `Weapons.All()`. | `WeaponService`, `ScoreService`, `WeaponClientController`, `UIController`, `ComboMeter` |
| [`Weapons/Pistol.lua`](src/Shared/Definitions/Weapons/Pistol.lua), [`Uzi.lua`](src/Shared/Definitions/Weapons/Uzi.lua), [`Shotgun.lua`](src/Shared/Definitions/Weapons/Shotgun.lua), [`AssaultRifle.lua`](src/Shared/Definitions/Weapons/AssaultRifle.lua), [`Railgun.lua`](src/Shared/Definitions/Weapons/Railgun.lua) | One file per gun: damage, fire interval, max ammo (`nil` = infinite), unlock combo, range, pellets, spread, pierce, tracer colour, shot sound. | Read through the index |

### Shared utilities (`src/Shared/Util`)

| File | What it is | Used by |
|---|---|---|
| [`Maid.lua`](src/Shared/Util/Maid.lua) | Collects connections, instances, threads and objects, and cleans them all up with one `Destroy()`. Prevents memory leaks. | `PlayerService`, `HealthService`, `Enemy`, `GunController`, client controllers and HUD modules |
| [`Signal.lua`](src/Shared/Util/Signal.lua) | Lightweight events between modules (e.g. `EnemyService.EnemyDied`). Unlike `BindableEvent`, it passes objects through unchanged. | `PlayerService`, `EnemyService`, `GameService`, `Enemy`, `CameraController`, `WeaponClientController` |
| [`Pool.lua`](src/Shared/Util/Pool.lua) | Reuses Instances that are created and thrown away often. | `Tracer` |
| [`Spread.lua`](src/Shared/Util/Spread.lua) | Random cone spread for bullets. | `Hitscan` (real shots), `WeaponClientController` (predicted tracers) |
| [`DefinitionIndex.lua`](src/Shared/Util/DefinitionIndex.lua) | Requires every ModuleScript in a folder, so adding a weapon or enemy is just adding a file. | `Definitions/Weapons/init.lua`, `Definitions/Enemies/init.lua` |

### Server bootstrap and services (`src/Server`)

| File | What it does | Talks to |
|---|---|---|
| [`init.server.lua`](src/Server/init.server.lua) | Loads every Service, runs `Init()` then `Start()`. Also warns in Output if the old pre-refactor scripts (`GameManager`, `ClientMain`, `GameConfig`) are still in the place. | All Services |
| [`Services/PlayerService.lua`](src/Server/Services/PlayerService.lua) | Player join/leave, spawning characters (auto-spawn is off; the game decides when), "who is alive" queries. Fires `PlayerJoined`, `PlayerLeft`, `CharacterSpawned`, `CharacterRemoving`, `PlayerDied`. | Used by every other service |
| [`Services/EnemyService.lua`](src/Server/Services/EnemyService.lua) | Owns every zombie: spawns them, runs **one** AI loop for all of them (10 times a second, staggered), the single damage function, and the `EnemyDied` / `EnemyRemoved` events. | `Enemy`, `ZombieRig`, `SpawnLocator`, `PlayerService`; listened to by `GameService`, `ScoreService`, `PickupService` |
| [`Services/WeaponService.lua`](src/Server/Services/WeaponService.lua) | Each player's weapons: what is unlocked, one `GunController` per gun, handling the `WeaponFire` remote (validated and rate-limited), and broadcasting `WeaponFired`. | `GunController`, `EnemyService`, `PlayerService`, `RemoteGuard` |
| [`Services/ScoreService.lua`](src/Server/Services/ScoreService.lua) | Kills, points and the **combo**. Each kill adds 1 to the combo; after `ComboTimeout` the combo counts down quickly to 0 unless you kill again. Hitting a weapon's combo milestone unlocks it (or refills it). Also creates the leaderboard (`leaderstats`). | `EnemyService.EnemyDied`, `WeaponService.Unlock/Refill` |
| [`Services/PickupService.lua`](src/Server/Services/PickupService.lua) | Spawns supply crates (from [`Pickups.lua`](src/Shared/Definitions/Pickups.lua)) when zombies die, always `HoverHeight` above the ground under the zombie, and checks every crate against nearby players in one loop. Collecting heals and refills ammo. | `EnemyService.EnemyDied`, `WeaponService.AddAmmoFraction` |
| [`Services/HealthService.lua`](src/Server/Services/HealthService.lua) | Out-of-combat healing: after `HealthRegenDelay` seconds without damage, players heal `HealthRegenPerSecond`. | `PlayerService` |
| [`Services/GameService.lua`](src/Server/Services/GameService.lua) | The match flow as a state machine: `Waiting → Intermission → WaveActive → WaveComplete → … → GameOver`. Waves end on events (last zombie removed, last player dead). Publishes state for the HUD as attributes on `ReplicatedStorage`. | `Waves`, `EnemyService`, `PickupService`, `PlayerService`, `ScoreService`, `WeaponService` |

### Server weapons (`src/Server/Weapons`)

| File | What it does | Used by |
|---|---|---|
| [`GunController.lua`](src/Server/Weapons/GunController.lua) | The server's record of one gun for one player: ammo, fire rate, its Tool, its firing component. Decides whether a shot is allowed and where the muzzle is. Writes the Tool's `Ammo` attribute for the HUD. | `WeaponService` |
| [`ToolFactory.lua`](src/Server/Weapons/ToolFactory.lua) | Builds the simple gun model (a Tool with a handle and coloured stripe). Tools contain no scripts. | `GunController` |
| [`WeaponTypes.lua`](src/Server/Weapons/WeaponTypes.lua) | Types for the firing context and components. | `GunController`, `WeaponService`, firing components |
| [`Components/Firing/init.lua`](src/Server/Weapons/Components/Firing/init.lua) | Registry mapping a weapon's `Firing.Type` (e.g. `"Hitscan"`) to its component. | `GunController` |
| [`Components/Firing/Hitscan.lua`](src/Server/Weapons/Components/Firing/Hitscan.lua) | Instant raycast bullets with pellets (shotgun), pierce (rifle, railgun) and headshots. Damages zombies only through `EnemyService`, and reports whether the shot landed a headshot. | Every current weapon |

### Server enemies (`src/Server/Enemies`)

| File | What it does | Used by |
|---|---|---|
| [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | One zombie: its health and AI state (Idle / Chase / Attack / Dead). Walks straight at the nearest player and only uses pathfinding when a wall is in the way. Attacks in range. Fires `Removed` when it dies or its model is destroyed. | `EnemyService` |
| [`ZombieRig.lua`](src/Server/Enemies/ZombieRig.lua) | Builds the zombie model once (R6 rig, colours, arms forward) for `EnemyService` to clone. | `EnemyService` |
| [`SpawnLocator.lua`](src/Server/Enemies/SpawnLocator.lua) | Picks spawn positions: parts tagged `EnemySpawn` (or in a `Workspace.ZombieSpawns` folder) if the map has any, otherwise open ground in a ring around a random player. | `EnemyService` |

### Server utilities (`src/Server/Util`)

| File | What it does | Used by |
|---|---|---|
| [`RemoteGuard.lua`](src/Server/Util/RemoteGuard.lua) | Rate-limits client requests and logs players who keep sending invalid ones. | `WeaponService` |
| [`WorldFolders.lua`](src/Server/Util/WorldFolders.lua) | Finds or creates the `Workspace.Enemies` and `Workspace.Pickups` folders. | `EnemyService`, `PickupService`, `WeaponService` |
| [`Ragdoll.lua`](src/Server/Util/Ragdoll.lua) | Makes dead zombies and players collapse as ragdolls: on death, every joint becomes a loose ball socket with swing/twist limits. Works for R6 and R15. | `Enemy` (zombies), `PlayerService` (players) |

### Client (`src/Client`)

| File | What it does | Used by |
|---|---|---|
| [`init.client.lua`](src/Client/init.client.lua) | Waits for the game to load, then loads every Controller and runs `Init()` then `Start()`. | |
| [`Controllers/CameraController.lua`](src/Client/Controllers/CameraController.lua) | Tracks **aim focus**: on mouse and keyboard you are focused only while Shift Lock is on (mouse locked to the centre). Touch and gamepad always count as focused. Fires `AimLockChanged`. | `WeaponClientController`, `UIController` |
| [`Controllers/WeaponClientController.lua`](src/Client/Controllers/WeaponClientController.lua) | Fire input (mouse, gamepad R2, on-screen button on mobile). Hold to keep firing, only while focused. Sends the aim direction to the server, and draws your tracers and sound immediately. Also draws other players' shots. | `UIController` (`EquippedChanged`) |
| [`Controllers/CrateController.lua`](src/Client/Controllers/CrateController.lua) | Makes supply crates float up and down. Visual only: it moves your local copy, finding crates by the `Pickup` tag the server sets. Bob height and speed come from [`Pickups.lua`](src/Shared/Definitions/Pickups.lua). | |
| [`Controllers/SpectateController.lua`](src/Client/Controllers/SpectateController.lua) | After you die, points your camera at a living teammate. | |
| [`Controllers/UIController.lua`](src/Client/Controllers/UIController.lua) | Builds the HUD screens and connects them to the equipped weapon, aim focus and server notifications (new weapon, refills, pickups). | All `UI/` modules |
| [`Effects/Tracer.lua`](src/Client/Effects/Tracer.lua) | Neon bullet tracers from a reusable pool. | `WeaponClientController` |
| [`Effects/ShotSound.lua`](src/Client/Effects/ShotSound.lua) | Plays a weapon's shot sound from its handle. | `WeaponClientController` |
| [`Effects/HitSound.lua`](src/Client/Effects/HitSound.lua) | The headshot "crunch", played only to the shooter when the server confirms a headshot. The sound is set in [`GameRules.lua`](src/Shared/Definitions/GameRules.lua). | `WeaponClientController` (on the `Headshot` remote) |

### HUD (`src/Client/UI`)

| File | Shows | Reads |
|---|---|---|
| [`Text.lua`](src/Client/UI/Text.lua) | Shared label style (scales with screen size, with min/max text size). | |
| [`FadingText.lua`](src/Client/UI/FadingText.lua) | A label that shows a message and fades it out. | |
| [`StatusBanner.lua`](src/Client/UI/StatusBanner.lua) | Top centre: wave number, zombies left, and big messages ("Game starts in 5", "WAVE 3", "GAME OVER"). | `GameState`, `Wave`, `Countdown`, `EnemiesRemaining` attributes on ReplicatedStorage |
| [`StatsPanel.lua`](src/Client/UI/StatsPanel.lua) | Top left: points and kills. | `Points`, `Kills` attributes on your Player |
| [`ComboMeter.lua`](src/Client/UI/ComboMeter.lua) | Combo count, the draining bar, and the next unlock. Turns red while the combo counts down. | `Combo`, `ComboExpire` attributes on your Player |
| [`WeaponDisplay.lua`](src/Client/UI/WeaponDisplay.lua) | Bottom centre: equipped weapon and ammo (∞ for the Pistol). | The Tool's `Ammo` attribute |
| [`Crosshair.lua`](src/Client/UI/Crosshair.lua) | Centre crosshair, only while a weapon is out and you are focused. | |
| [`Toast.lua`](src/Client/UI/Toast.lua) | One-line notifications ("NEW WEAPON: Uzi!", "+25 Health +Ammo"). | |

### Character (`src/Character`)

| File | What it does |
|---|---|
| [`Health.server.lua`](src/Character/Health.server.lua) | An intentionally empty script named `Health`. Roblox replaces its default instant-regen script with this one, so healing only comes from `HealthService` and supply crates. |

---

## Settable values (balancing)

Every number you would want to tweak lives in a **definition file** under [`src/Shared/Definitions/`](src/Shared/Definitions/). These files hold data only and contain no logic. Change a value, save, then press Stop and Play in Studio. Strict mode checks each file against [`Types.lua`](src/Shared/Types.lua), so a typo or wrong type shows up as an error.

### Match rules: [`GameRules.lua`](src/Shared/Definitions/GameRules.lua)

| Setting | Current | What it controls |
|---|---|---|
| `Intermission` | `10` | Seconds of countdown before a match starts |
| `WaveBreak` | `6` | Seconds between waves |
| `GameOverTime` | `8` | Seconds the Game Over screen shows before the next round |
| `MatchStartDelay` | `2` | Seconds after everyone spawns before wave 1 |
| `MaxEnemiesAlive` | `30` | Cap on zombies alive at once (extra ones wait to spawn) |
| `SpawnDistanceMin` / `SpawnDistanceMax` | `50` / `90` | Ring around a player where zombies spawn, when the map has no `EnemySpawn` parts |
| `HealthRegenDelay` | `5` | Seconds without taking damage before you start healing |
| `HealthRegenPerSecond` | `5` | Health healed per second once regen starts |
| `HeadshotMultiplier` | `1.5` | Damage multiplier for hitting a zombie's head |
| `HeadshotSound` | `rbxassetid://128633263668964` | Sound the shooter hears on a headshot |
| `HeadshotSoundVolume` | `1` | Volume of that sound |
| `ComboTimeout` | `3` | Seconds after a kill before the combo starts counting down |
| `ComboDecayInterval` | `0.15` | While counting down, seconds per combo point lost |
| `PointsPerKill` | `10` | Points per kill, multiplied by your current combo |

### Waves: [`Waves.lua`](src/Shared/Definitions/Waves.lua)

Waves are endless. Each value is `BASE + wave number × PER_WAVE`, clamped by the min/max.

| Setting | Current | Result |
|---|---|---|
| `BASE_COUNT`, `COUNT_PER_WAVE` | `6`, `4` | Zombies per wave (wave 1 = 10, wave 5 = 26) |
| `BASE_HEALTH`, `HEALTH_PER_WAVE` | `60`, `15` | Zombie health (wave 1 = 75, wave 10 = 210) |
| `BASE_SPEED`, `SPEED_PER_WAVE`, `MAX_SPEED` | `9`, `0.7`, `18` | Zombie walk speed (capped at 18) |
| `BASE_SPAWN_INTERVAL`, `SPAWN_INTERVAL_PER_WAVE`, `MIN_SPAWN_INTERVAL` | `1.2`, `0.06`, `0.3` | Seconds between zombie spawns (gets faster, never below 0.3) |
| `ENEMY_ID` | `"Zombie"` | Which enemy definition waves spawn |

### Weapons: [`Definitions/Weapons/`](src/Shared/Definitions/Weapons/) (one file per gun)

| Setting | What it controls |
|---|---|
| `Damage` | Damage per bullet (per pellet for the shotgun) |
| `FireInterval` | Seconds between shots while holding fire (lower = faster) |
| `MaxAmmo` | Ammo when given or refilled; `nil` = infinite |
| `UnlockCombo` | Combo needed to unlock it; `0` = starting weapon. Also sets hotbar order |
| `Firing.Range` | How far bullets travel (studs) |
| `Firing.Pellets` | Bullets per shot |
| `Firing.SpreadDegrees` | Random inaccuracy per bullet |
| `Firing.Pierce` | How many zombies one bullet can pass through |
| `Effects.Color` | Tracer and stripe colour |
| `Effects.Sound` | Shot sound (`rbxassetid://…`) |
| `DisplayName`, `HandleLength` | Name in the hotbar and HUD, length of the gun model |

| Weapon | Damage | FireInterval | MaxAmmo | UnlockCombo | Range | Pellets | Spread | Pierce |
|---|---|---|---|---|---|---|---|---|
| [Pistol](src/Shared/Definitions/Weapons/Pistol.lua) | 25 | 0.3 | ∞ | 0 | 250 | 1 | 1 | 1 |
| [Uzi](src/Shared/Definitions/Weapons/Uzi.lua) | 14 | 0.08 | 250 | 5 | 200 | 1 | 4 | 1 |
| [Shotgun](src/Shared/Definitions/Weapons/Shotgun.lua) | 16 | 0.75 | 50 | 12 | 80 | 8 | 9 | 1 |
| [Assault Rifle](src/Shared/Definitions/Weapons/AssaultRifle.lua) | 30 | 0.11 | 200 | 20 | 300 | 1 | 2 | 2 |
| [Railgun](src/Shared/Definitions/Weapons/Railgun.lua) | 150 | 1.2 | 25 | 35 | 400 | 1 | 0 | 15 |

### Zombies: [`Enemies/Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua)

Health and speed come from the wave; everything else is here.

| Setting | Current | What it controls |
|---|---|---|
| `Damage` | `10` | Damage per hit on a player |
| `AttackCooldown` | `1` | Seconds between hits |
| `AttackRange` | `4.5` | How close a zombie must be to hit you (studs) |
| `SpeedVariance` | `0.15` | Each zombie's speed is randomly ±15% of the wave speed |
| `CorpseTime` | `3` | Seconds a dead body stays before it is removed |
| `DirectChaseDistance` | `10` | Inside this distance zombies always walk straight at you |
| `PathRecomputeInterval` | `1.5` | Seconds between pathfinding updates when a wall is in the way |
| `WaypointReachedDistance` | `3` | How close counts as reaching a path waypoint |
| `Agent` | radius 2, height 5, can jump | Size used for pathfinding |
| `Colors` | skin / shirt / pants | Zombie colours |
| `WalkAnimationId` | `rbxassetid://180426354` | Walk animation |

### Supply crates: [`Pickups.lua`](src/Shared/Definitions/Pickups.lua)

| Setting | Current | What it controls |
|---|---|---|
| `DropChance` | `0.12` | Chance a killed zombie drops a crate (12%) |
| `Heal` | `25` | Health restored on pickup |
| `AmmoFraction` | `0.5` | Fraction of each gun's `MaxAmmo` refilled |
| `Lifetime` | `30` | Seconds before an untouched crate disappears |
| `CollectRadius` | `4` | How close you must walk to pick it up (studs) |
| `HoverHeight` | `2.5` | Studs from the ground to the crate's centre |
| `BobHeight` | `0.4` | How far the crate floats up and down (studs) |
| `BobSpeed` | `0.6` | Bobs per second |
| `Size`, `Color`, `LightColor` | `2`, brown, green | Crate look |

### Engine-level constants (advanced)

These sit as `UPPER_CASE` constants at the top of the code files that use them. They control how the systems run rather than game balance, so they usually don't need changing.

| Constant | File | What it controls |
|---|---|---|
| `TICK`, `STAGGER` | [`EnemyService.lua`](src/Server/Services/EnemyService.lua) | Zombie AI update rate (each zombie thinks every `TICK × STAGGER` = 0.2 s) |
| `FIRE_TOLERANCE` | [`GunController.lua`](src/Server/Weapons/GunController.lua) | How much faster than `FireInterval` the server accepts shots (network jitter) |
| `FIRE_MIN_INTERVAL` | [`WeaponService.lua`](src/Server/Services/WeaponService.lua) | Hard rate limit on the fire remote |
| `CHECK_INTERVAL` | [`PickupService.lua`](src/Server/Services/PickupService.lua) | How often crates check for nearby players |
| `MIN_ZOOM_DISTANCE` | [`CameraController.lua`](src/Client/Controllers/CameraController.lua) | Closest the camera can zoom in |
| `SWING_LIMIT`, `TWIST_LIMIT` | [`Ragdoll.lua`](src/Server/Util/Ragdoll.lua) | How floppy ragdolls are (degrees a limb can swing and twist) |
| Colours and sizes | [`src/Client/UI/`](src/Client/UI/) | HUD colours, positions and text sizes, at the top of each UI file |

---

## What happens when you shoot a zombie

1. **Client** ([`WeaponClientController`](src/Client/Controllers/WeaponClientController.lua)): you hold Fire while focused. Each fire interval it aims at whatever is under the crosshair, sends **only the direction** over `WeaponFire`, and draws a tracer and plays the sound right away.
2. **Server** ([`WeaponService`](src/Server/Services/WeaponService.lua)): checks the request (valid unit vector, rate limit, player alive, holding one of their own guns).
3. [`GunController`](src/Server/Weapons/GunController.lua) checks ammo and fire rate, takes one ammo, and fires from the server's own muzzle position.
4. [`Hitscan`](src/Server/Weapons/Components/Firing/Hitscan.lua) raycasts and calls `EnemyService.DamageModel` for each zombie hit.
5. [`Enemy`](src/Server/Enemies/Enemy.lua) loses health. If any bullet hit a head, the server sends `Headshot` to the shooter, who hears the crunch. At 0 health the zombie ragdolls ([`Ragdoll`](src/Server/Util/Ragdoll.lua)) and `EnemyService` fires `EnemyDied`.
6. Listeners react on their own:
   - [`ScoreService`](src/Server/Services/ScoreService.lua) adds the kill, combo and points, and checks weapon unlocks.
   - [`PickupService`](src/Server/Services/PickupService.lua) may drop a supply crate.
   - [`GameService`](src/Server/Services/GameService.lua) lowers "zombies left" and ends the wave at 0.
7. The server sends `WeaponFired` to everyone so other players see the tracers, and updates attributes that the HUD shows.

---

## Remotes

All are defined in [`Net.lua`](src/Shared/Net.lua).

| Remote | Direction | Payload | Handled in |
|---|---|---|---|
| `WeaponFire` | client → server | `direction: Vector3` | `WeaponService` (validated, rate-limited) |
| `WeaponFired` | server → all clients | shooter, weapon id, origin, hit points | `WeaponClientController` (tracers, sound) |
| `Headshot` | server → shooter | nothing | `WeaponClientController` (headshot sound) |
| `WeaponUnlocked` | server → client | weapon id | `UIController` (toast) |
| `WeaponRefilled` | server → client | weapon id | `UIController` (toast) |
| `PickupCollected` | server → client | heal amount | `UIController` (toast) |

Continuously displayed values (wave, countdown, points, combo, ammo) are not sent as remotes. They are **attributes** that replicate automatically; the names are in [`Constants.lua`](src/Shared/Constants.lua).

---

## Common changes

For the full list of numbers, see [Settable values (balancing)](#settable-values-balancing).

| I want to… | Do this |
|---|---|
| Rebalance a gun | Edit its file in [`Definitions/Weapons/`](src/Shared/Definitions/Weapons/). |
| Add a gun | Copy a weapon file, give it a new `Id`, `DisplayName` and `UnlockCombo`. It is picked up automatically. |
| Change a shot sound | Set `Effects.Sound` in the weapon file to an `rbxassetid://` audio id. |
| Make waves harder/easier | Edit the constants in [`Waves.lua`](src/Shared/Definitions/Waves.lua). |
| Change zombie damage or attack range | Edit [`Enemies/Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua). |
| Change crate drop chance or heal | Edit [`Pickups.lua`](src/Shared/Definitions/Pickups.lua). |
| Change round timers, max zombies, combo timing or health regen | Edit [`GameRules.lua`](src/Shared/Definitions/GameRules.lua). |
| Choose where zombies spawn | In Studio, tag parts `EnemySpawn` (or put them in a `Workspace.ZombieSpawns` folder). |
| Add a new kind of shooting (e.g. rockets) | Add a module next to [`Hitscan.lua`](src/Server/Weapons/Components/Firing/Hitscan.lua), register it in [`Firing/init.lua`](src/Server/Weapons/Components/Firing/init.lua), and set `Firing.Type` in the weapon file. |

---

## Conventions

The full guides are in [`roblox-skills/`](roblox-skills/); start with [`roblox-dev-index/SKILL.md`](roblox-skills/roblox-dev-index/SKILL.md). The short version:

- Every file starts with `--!strict`.
- The server owns game state; the client sends intent and draws results.
- Every remote is validated and rate-limited on the server.
- No scripts inside individual zombies, weapons or GUIs: one system manages them all.
- Every connection and spawned object is cleaned up by an owner (usually a `Maid`).
- Tunable numbers go in `Definitions/`, not in logic.
- Use `task.wait` / `task.spawn` / `task.delay`, never the old `wait` / `spawn` / `delay`.
