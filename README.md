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
├── assets/                       Blood images to upload to Roblox (see BloodSplatterImages)
│   ├── BloodSplatterSmall.png
│   ├── BloodSplatterMedium.png
│   ├── BloodSplatterLarge.png
│   └── BloodPool.png
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
    │   │   ├── Enemies/          init.lua (index) + Zombie.lua (A), ZombieB.lua (B), FastZombie.lua
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
    │       ├── Ragdoll.lua
    │       ├── Flinch.lua
    │       ├── Dismember.lua
    │       └── Jump.lua
    └── Client/                   → StarterPlayerScripts.Client
        ├── init.client.lua       Client bootstrap
        ├── Controllers/
        │   ├── CameraController.lua
        │   ├── WeaponClientController.lua
        │   ├── CrateController.lua
        │   ├── HealthFeedbackController.lua
        │   ├── BodyPoseController.lua
        │   ├── GoreController.lua
        │   ├── SpectateController.lua
        │   └── UIController.lua
        ├── Effects/
        │   ├── Tracer.lua
        │   ├── ShotSound.lua
        │   ├── HitSound.lua
        │   ├── BloodSplash.lua
        │   ├── BloodPour.lua
        │   ├── BloodStains.lua
        │   └── HealCrosses.lua
        └── UI/                   One module per HUD piece
            ├── Text.lua
            ├── FadingText.lua
            ├── StatusBanner.lua
            ├── StatsPanel.lua
            ├── ComboMeter.lua
            ├── WeaponDisplay.lua
            ├── Crosshair.lua
            ├── RegenOverlay.lua
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
| [`GameRules.lua`](src/Shared/Definitions/GameRules.lua) | Match-wide tunables: intermission/wave-break/game-over times, zombie climbing and corpses, spawn distances, health regen delay and rate, headshot multiplier, combo timeout and countdown speed, points per kill. | `GameService`, `ScoreService`, `HealthService`, `WeaponService`, `SpawnLocator`, `ComboMeter` |
| [`Waves.lua`](src/Shared/Definitions/Waves.lua) | Formulas that turn a wave number into zombie count, health, speed and spawn interval. Waves are endless. | `GameService` (each wave), `EnemyService.Spawn` (reads health and speed) |
| [`Pickups.lua`](src/Shared/Definitions/Pickups.lua) | The **supply crate** that zombies can drop: drop chance, how much it heals, how much ammo it refills, how long it lasts, pickup radius, size and colours. | `PickupService` |
| [`Enemies/init.lua`](src/Shared/Definitions/Enemies/init.lua) | Index that loads every enemy file in the folder. `Enemies.Get(id)` and `Enemies.All()`. | `EnemyService` |
| [`Enemies/Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua) | **Zombie A**, the standard zombie (`Behaviour = "Direct"`): walks straight at you. Damage, attack range and cooldown, speed variance, corpse time, pathfinding settings, colours, walk animation. (Health and speed come from the wave.) | Read through the index by `EnemyService`, `Enemy`, `ZombieRig` |
| [`Enemies/ZombieB.lua`](src/Shared/Definitions/Enemies/ZombieB.lua) | **Zombie B** (`Behaviour = "Flank"`): walks straight at you until about 35 studs away, then makes its attack run from about 45° to one side, and charges once close. Same speed as Zombie A. Tinted yellow for testing. | Same as above |
| [`Enemies/FastZombie.lua`](src/Shared/Definitions/Enemies/FastZombie.lua) | **Fast zombie** (`Behaviour = "Flank"`): 2× Zombie A's speed. Walks straight at you until about 40 studs away, then makes its attack run from 90° (straight from the side), and charges once close. Tinted red for testing. | Same as above |
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
| [`Services/HealthService.lua`](src/Server/Services/HealthService.lua) | Out-of-combat healing: after `HealthRegenDelay` seconds without damage, players heal `HealthRegenPerSecond`. Taking damage also **staggers** you: you walk slower for `PlayerStaggerDuration`. (Heal and hurt visuals/sounds are client-side; see `HealthFeedbackController`.) | `PlayerService` |
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
| [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | One zombie: its health and AI state (Idle / Chase / Attack / Dead). Heads for the nearest player: straight at them (`"Direct"`), or straight until a medium range and then an attack run that closes in from the side (`"Flank"`). Uses pathfinding when a wall is in the way, when the player is well above it (roof, ledge, stairs), or when it keeps getting stuck. Attacks in range. Each arm and leg soaks up damage and is **blown off** once it has taken `LimbHealthFraction` of max health; losing a leg drops it onto the ground **crawling**, pulling itself along with its arms, slowly, unable to jump, trailing blood. Climbs and crawls over other zombies and corpses. It can always claw its way up over corpses and severed limbs, and onto living zombies once it has been **jammed** against them for about a second without getting anywhere. **World War Z piles:** a zombie standing on the pile and pressed against a wall claws its way up the wall, but only while there is pile under it, so each one that gets up becomes the next step for the ones behind and the pile builds up the wall until the top zombies reach the edge and spill over. A zombie on its own never climbs or jumps a wall: stuck on the map, it pathfinds round instead (the pile only forms where there is no way round). The zombies at the bottom of a pile stay standing; once a climber's feet leave the floor it is down in a **crawl** (leaning 70°, tilting a little with the climb), clawing with the same caterpillar arm stroke as legless zombies, so a pile is a heap of crawlers that needs enough of them stacked up to reach the top of a wall; while standing on or pushing into one it moves at 20% speed (`ClimbSpeedMultiplier`). Its climb checks run at chest and shin height, so it keeps clawing up until its legs clear the top of what it is climbing. Now and then it does a tiny hop, far more often while pinned against a wall or jammed in the crowd; hops never help it climb. Zombies do not walk in a line: each one approaches along its own **lane**, aimed off to one side of the player and closing in as it gets near, so a crowd arrives as a wide front. Blocked by a living zombie it cannot climb yet, it looks left and right for a gap and edges into it, so the horde spreads out round the player, each zombie getting as close as it can; if it stays jammed it climbs over the zombie in front. Stuck on a wall with no path round it, it **slides left or right along the wall**. What is "in front" is always checked towards where it is trying to go, so turning aside does not make it lose track of what blocked it. When shot it **flinches**, is **staggered** (slowed by the weapon's stopping power, with its arm-swinging walk animation paused) and **knocked back** by strong weapons; when killed it ragdolls and the killing shot pushes the body at the spot it hit. Fires `Removed` when it dies or its model is destroyed. | `EnemyService` |
| [`ZombieRig.lua`](src/Server/Enemies/ZombieRig.lua) | Builds the zombie model once (R6 rig, colours, arms hanging slightly forward) for `EnemyService` to clone. | `EnemyService` |
| [`SpawnLocator.lua`](src/Server/Enemies/SpawnLocator.lua) | Picks spawn positions: parts tagged `EnemySpawn` (or in a `Workspace.ZombieSpawns` folder) if the map has any, otherwise open ground in a ring around a random player. | `EnemyService` |

### Server utilities (`src/Server/Util`)

| File | What it does | Used by |
|---|---|---|
| [`RemoteGuard.lua`](src/Server/Util/RemoteGuard.lua) | Rate-limits client requests and logs players who keep sending invalid ones. | `WeaponService` |
| [`WorldFolders.lua`](src/Server/Util/WorldFolders.lua) | Finds or creates the `Workspace.Enemies` and `Workspace.Pickups` folders. | `EnemyService`, `PickupService`, `WeaponService` |
| [`Flinch.lua`](src/Server/Util/Flinch.lua) | Marks zombies and characters as flinchable and stamps a hit (time + direction) on them; clients draw the flinch. | `Enemy` (zombie shot, player hit), `PlayerService` |
| [`Dismember.lua`](src/Server/Util/Dismember.lua) | Blows a limb off a living or ragdolled zombie: cuts its joint, turns it into its own `Gib` model (bullets pass through, cleaned up like a corpse), flings it along the shot, and tells clients to pour blood (`LimbSevered` remote). | `Enemy` |
| [`Jump.lua`](src/Server/Util/Jump.lua) | Scales a Humanoid's jump height by `JumpHeightMultiplier` (half, by default), whether it uses `JumpHeight` or `JumpPower`. | `PlayerService` (players), `Enemy` (zombies) |
| [`Ragdoll.lua`](src/Server/Util/Ragdoll.lua) | Makes dead zombies and players collapse as ragdolls: on death, every joint becomes a loose ball socket with swing/twist limits. Works for R6 and R15. `Freeze` then locks a settled zombie corpse in place as an obstacle. | `Enemy` (zombies), `PlayerService` (players) |

### Client (`src/Client`)

| File | What it does | Used by |
|---|---|---|
| [`init.client.lua`](src/Client/init.client.lua) | Waits for the game to load, then loads every Controller and runs `Init()` then `Start()`. | |
| [`Controllers/CameraController.lua`](src/Client/Controllers/CameraController.lua) | Tracks **aim focus**: on mouse and keyboard you are focused only while Shift Lock is on (mouse locked to the centre). Touch and gamepad always count as focused. Fires `AimLockChanged`. | `WeaponClientController`, `UIController` |
| [`Controllers/WeaponClientController.lua`](src/Client/Controllers/WeaponClientController.lua) | Fire input (mouse, gamepad R2, on-screen button on mobile). Hold to keep firing, only while focused. Sends the aim direction to the server, and draws your tracers and sound immediately. Also draws other players' shots. | `UIController` (`EquippedChanged`) |
| [`Controllers/CrateController.lua`](src/Client/Controllers/CrateController.lua) | Makes supply crates float up and down, and flash faster and faster in their last seconds before disappearing (from the crate's `ExpiresAt` attribute). Visual only: it changes your local copy, finding crates by the `Pickup` tag the server sets. Timings come from [`Pickups.lua`](src/Shared/Definitions/Pickups.lua). | |
| [`Controllers/HealthFeedbackController.lua`](src/Client/Controllers/HealthFeedbackController.lua) | Watches every character's health. **Any** gain (regen, supply crate, anything else) spawns green crosses on that character, more for bigger heals (1 per 5 HP, up to 6), and fires `LocalHealed` for your own character. When **you** take damage it plays the hurt sound. | `UIController` (`LocalHealed` → green border) |
| [`Controllers/BodyPoseController.lua`](src/Client/Controllers/BodyPoseController.lua) | Procedural body poses on zombies and players: the **hit flinch** (upper body snaps away from the hit, head whips back, then recovers; from the `Flinch` attribute, see [`Flinch.lua`](src/Server/Util/Flinch.lua)) the **crawl** (a zombie climbing a pile, or legless, leans forward at the angle of the climb with its head up; from the `CrawlPitch` attribute), and the **legless crawl stroke** (arms reach ahead and drag back in turn, left then right, like a caterpillar; from the `Legless` attribute). Flinches play on top of the crawl. | |
| [`Controllers/GoreController.lua`](src/Client/Controllers/GoreController.lua) | All zombie gore: headshot deaths (`HeadshotDeath` attribute: exploded or popped-off head with blood pouring), severed limbs (`LimbSevered` remote: blood pouring from stump and limb), blood trails behind legless zombies (`Legless` attribute), and a faint pool where every zombie dies. Wipes all blood off the ground when a new game starts (the Intermission after Game Over). | |
| [`Controllers/SpectateController.lua`](src/Client/Controllers/SpectateController.lua) | After you die, points your camera at a living teammate. | |
| [`Controllers/UIController.lua`](src/Client/Controllers/UIController.lua) | Builds the HUD screens and connects them to the equipped weapon, aim focus and server notifications (new weapon, refills, pickups). | All `UI/` modules |
| [`Effects/Tracer.lua`](src/Client/Effects/Tracer.lua) | Neon bullet tracers from a reusable pool. | `WeaponClientController` |
| [`Effects/ShotSound.lua`](src/Client/Effects/ShotSound.lua) | Plays a weapon's shot sound from its handle, and the dry-fire click when you hold fire with no ammo (at the weapon's fire rate). | `WeaponClientController` |
| [`Effects/BloodSplash.lua`](src/Client/Effects/BloodSplash.lua) | A pooled burst of blood where a bullet hit a zombie, spraying back toward the shooter; headshots get a bigger, faster burst, and an exploding head a huge one. Shown for every player once the server confirms the hit. | `WeaponClientController` (on `WeaponFired` hits) |
| [`Effects/BloodPour.lua`](src/Client/Effects/BloodPour.lua) | A stream of blood from a neck or head that follows the ragdoll and tapers off over `BloodPourTime`. | `GoreController` |
| [`Effects/BloodStains.lua`](src/Client/Effects/BloodStains.lua) | Blood on the ground. **Fresh stains**: every splash, drip, trail and death lays down a wet splatter that stays `StainLifetime` seconds, then dries. **Paint (permanent)**: the ground is split into ~5-stud patches. Each patch that gets blood has a flat square **blood coat** filling it edge to edge (so neighbouring coats join into one even sheet of red, not stacked circles), cut off where a wall crosses the patch so the red stops at the wall. It darkens with every stain drying there, and a quarter of each stain seeps into the 4 neighbouring patches (never through a wall), so over the waves the red spreads until the fought-over floor is solid dark red. On top, the first 3 stains to dry in a patch keep their exact splatter shape. Paint stays for the whole game and is wiped when a new game starts (`ClearAll`, called by `GoreController`); its part count grows with bloodied floor area (one coat + up to 3 splatters per patch), not shots fired, so it stays light on the GPU. Each splatter is one decal part if its image is uploaded (`BloodSplatterImages`), otherwise a few flattened ovals in a random splatter layout. | `BloodSplash`, `BloodPour`, `GoreController` |
| [`Effects/HealCrosses.lua`](src/Client/Effects/HealCrosses.lua) | Small green "+" signs that rise and fade around a healing character, from a pool. | `HealthFeedbackController` |
| [`Effects/HitSound.lua`](src/Client/Effects/HitSound.lua) | 2D sounds for you only: the headshot "crunch" when the server confirms a headshot, and the hurt sound when you take damage. Sounds are set in [`GameRules.lua`](src/Shared/Definitions/GameRules.lua). | `WeaponClientController` (`Headshot` remote), `HealthFeedbackController` |

### HUD (`src/Client/UI`)

| File | Shows | Reads |
|---|---|---|
| [`Text.lua`](src/Client/UI/Text.lua) | Shared label style (scales with screen size, with min/max text size). | |
| [`FadingText.lua`](src/Client/UI/FadingText.lua) | A label that shows a message and fades it out. | |
| [`StatusBanner.lua`](src/Client/UI/StatusBanner.lua) | Top centre: wave number, zombies left, and big messages ("Game starts in 5", "WAVE 3", "GAME OVER"). | `GameState`, `Wave`, `Countdown`, `EnemiesRemaining` attributes on ReplicatedStorage |
| [`StatsPanel.lua`](src/Client/UI/StatsPanel.lua) | Top left: points and kills. | `Points`, `Kills` attributes on your Player |
| [`ComboMeter.lua`](src/Client/UI/ComboMeter.lua) | Combo count, the draining bar, and the next unlock. Turns red while the combo counts down. | `Combo`, `ComboExpire` attributes on your Player |
| [`WeaponDisplay.lua`](src/Client/UI/WeaponDisplay.lua) | Bottom centre: equipped weapon and ammo (∞ for the Pistol). | The Tool's `Ammo` attribute |
| [`Crosshair.lua`](src/Client/UI/Crosshair.lua) | Centre crosshair, only while a weapon is out and you are focused. On a headshot it gives a quick, subtle flash: slightly bigger and red, with a small fan of 3 yellow spikes in each diagonal (the middle one longest). | The `Headshot` remote (via `UIController`) |
| [`RegenOverlay.lua`](src/Client/UI/RegenOverlay.lua) | A soft green glow around the screen edges whenever you heal. Steady regen keeps it lit; a single heal gives a short flash. | `HealthFeedbackController.LocalHealed` (via `UIController`) |
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
| `ClimbRiseSpeed` | `1.5` | Studs/s a zombie slowly claws its way up a pile it is allowed to climb (no hopping) |
| `ZombieHopChance`, `ZombieHopHeight` | `0.05`, `2.2` | Now and then (5% per AI update, about every 4 s) a chasing zombie does a tiny hop, just for looks; it never helps it climb |
| `ZombieStuckHopChance` | `0.25` | Hop chance per AI update while a zombie is pinned against a wall or jammed in the crowd (about every 0.8 s), so a stuck horde hops as it strains towards the player |
| `ZombieBumperDiameter`, `ZombieBumperHeight` | `3`, `4` | Size of the invisible collision cylinder round each zombie's torso, so hordes pack out wider and fill more space. Bullets and the aim ray pass through it (it is in the `ZombieBumper` collision group, which never collides with the `Shots` group used by those rays; see `Constants.CollisionGroups`), so headshots and limb hits land on the visible body; it switches off when the zombie dies or loses a leg |
| `ClimbSpeedMultiplier` | `0.2` | Zombies climbing or crawling over other zombies or corpses move at this share of their speed (stacks with bullet stagger) |
| `CorpseFreezeDelay` | `1.5` | Seconds after death a ragdoll locks in place, becoming a solid obstacle |
| `SpawnDistanceMin` / `SpawnDistanceMax` | `50` / `90` | Ring around a player where zombies spawn, when the map has no `EnemySpawn` parts |
| `JumpHeightMultiplier` | `0.5` | Jump height for players and zombies, as a share of Roblox's default (0.5 = half, about 3.6 studs) |
| `HealthRegenDelay` | `5` | Seconds without taking damage before you start healing |
| `HealthRegenPerSecond` | `5` | Health healed per second once regen starts |
| `PlayerStaggerSlow` | `0.5` | When you take damage, the fraction of walk speed you lose briefly |
| `PlayerStaggerDuration` | `0.35` | Seconds that slow lasts |
| `HurtSound` | `rbxasset://sounds/ouch.ogg` | Sound you hear when you take damage (built into Roblox) |
| `HurtSoundVolume` | `0.6` | Volume of that sound |
| `HeadshotMultiplier` | `1.5` | Damage multiplier for hitting a zombie's head |
| `HeadExplodeChance` | `0.5` | On a headshot kill, chance the head explodes (blood pours from the neck) |
| `HeadPopChance` | `0.5` | On a headshot kill, chance the head pops off (blood pours from head and neck). Whatever is left of 100% is a normal death (currently 0%) |
| `HeadPopForce`, `HeadPopLift` | `45`, `25` | How hard a popped head flies along the shot, and upward |
| `BloodPourTime` | `3` | Seconds blood pours from a neck or head, tapering off |
| `LimbHealthFraction` | `0.35` | An arm or leg is blown off after taking this share of the zombie's max health |
| `LimbPopForce`, `LimbPopLift` | `30`, `15` | How hard a severed limb flies along the shot, and upward |
| `LeglessSpeedMultiplier` | `0.4` | A zombie missing a leg crawls at this share of its speed |
| `LeglessCrawlPitch` | `80` | Degrees a legless zombie lies forward while crawling (90 = flat) |
| `LeglessHipHeight` | `-1.8` | How far a legless zombie's body drops onto the ground (R6 hip offset, studs) |
| `BloodSplatterImages` | all `""` | Image ids (e.g. `"rbxassetid://123"`) of the four uploaded images in `assets/`: `Small` (drips, small hits), `Medium` (hits, trails, paint), `Large` (exploding heads, paint), `Pool` (where a zombie died). Any left empty are built from ovals in a random splatter shape instead (works without uploading, uses a few more parts) |
| `StainLifetime` | `5` | Seconds a fresh blood stain stays wet before soaking into the permanent paint on the ground |
| `BloodStainLimit` | `20` | Dried stains it takes to turn a patch of ground fully dark red. Paint is permanent and spreads into neighbouring patches, so over the waves the fought-over floor turns solid red |
| `StaggerDuration` | `0.45` | Seconds a hit zombie stays slowed by the weapon's `StoppingPower` |
| `HeadshotSound` | `rbxassetid://128633263668964` | Sound the shooter hears on a headshot |
| `HeadshotSoundVolume` | `1` | Volume of that sound |
| `EmptyFireSound` | `rbxassetid://139337377661709` | Dry-fire click when you hold fire with no ammo |
| `EmptyFireSoundVolume` | `0.8` | Volume of that click |
| `ComboTimeout` | `3` | Seconds after a kill before the combo starts counting down |
| `ComboDecayInterval` | `0.15` | While counting down, seconds per combo point lost |
| `PointsPerKill` | `10` | Points per kill, multiplied by your current combo |

### Waves: [`Waves.lua`](src/Shared/Definitions/Waves.lua)

Waves are endless. Each value is `BASE + wave number × PER_WAVE`, clamped by the min/max (the zombie count starts counting from wave 1, so wave 1 gets exactly `BASE_COUNT`).

| Setting | Current | Result |
|---|---|---|
| `BASE_COUNT`, `COUNT_PER_WAVE` | `30`, `15` | Zombies per wave: 30 in wave 1, then 15 more each wave (wave 2 = 45, wave 5 = 90). Count = `BASE_COUNT + (wave - 1) × COUNT_PER_WAVE` |
| `BASE_HEALTH`, `HEALTH_PER_WAVE` | `60`, `15` | Zombie health (wave 1 = 75, wave 10 = 210) |
| `BASE_SPEED`, `SPEED_PER_WAVE`, `MAX_SPEED` | `9`, `0.7`, `18` | Zombie walk speed (capped at 18) |
| `BASE_SPAWN_INTERVAL`, `SPAWN_INTERVAL_PER_WAVE`, `MIN_SPAWN_INTERVAL` | `1.2`, `0.06`, `0.3` | Seconds between zombie spawns (gets faster, never below 0.3) |
| `ENEMY_MIX` | Zombie A `3`, Zombie B `1`, fast zombie `1` | Which zombies waves spawn, with relative weights. Each of Zombie B and the fast zombie spawns a third as often as Zombie A (on average 3 in 5 spawns are Zombie A) |

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
| `Impact.StoppingPower` | `0`–`1`: how much a hit slows the zombie for `StaggerDuration` (`1` = stops it dead) |
| `Impact.Knockback` | How hard a hit shoves the zombie away from you (studs/s); `0` = no shove |
| `Impact.RagdollForce` | How hard the killing shot pushes the ragdoll, strongest on the body part it hit |
| `Effects.Color` | Tracer and stripe colour |
| `Effects.Sound` | Shot sound (`rbxassetid://…`) |
| `DisplayName`, `HandleLength` | Name in the hotbar and HUD, length of the gun model |

| Weapon | Damage | FireInterval | MaxAmmo | UnlockCombo | Range | Pellets | Spread | Pierce | Stopping | Knockback | Ragdoll |
|---|---|---|---|---|---|---|---|---|---|---|---|
| [Pistol](src/Shared/Definitions/Weapons/Pistol.lua) | 25 | 0.3 | ∞ | 0 | 250 | 1 | 1 | 1 | 0.6 | 4 | 35 |
| [Uzi](src/Shared/Definitions/Weapons/Uzi.lua) | 14 | 0.08 | 250 | 5 | 200 | 1 | 4 | 1 | 0.4 | 2 | 25 |
| [Shotgun](src/Shared/Definitions/Weapons/Shotgun.lua) | 16 | 0.75 | 50 | 12 | 80 | 8 | 9 | 1 | 0.9 | 14 (per pellet) | 70 |
| [Assault Rifle](src/Shared/Definitions/Weapons/AssaultRifle.lua) | 30 | 0.11 | 200 | 20 | 300 | 1 | 2 | 2 | 0.6 | 5 | 40 |
| [Railgun](src/Shared/Definitions/Weapons/Railgun.lua) | 150 | 1.2 | 25 | 35 | 400 | 1 | 0 | 15 | 1 | 60 | 110 |

### Zombies: [`Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua) (A), [`ZombieB.lua`](src/Shared/Definitions/Enemies/ZombieB.lua) (B), [`FastZombie.lua`](src/Shared/Definitions/Enemies/FastZombie.lua) (fast)

Health and speed come from the wave; everything else is in each zombie's file. All three files have the same settings. These differ between them:

| Setting | Zombie A | Zombie B | Fast zombie | What it controls |
|---|---|---|---|---|
| `Behaviour` | `"Direct"` | `"Flank"` | `"Flank"` | AI style: walk straight at you, or arc in from the side |
| `SpeedMultiplier` | `1` | `1` | `2` | Speed on top of the wave's zombie speed |
| `Flank.StartDistance` | – | `35` | `40` | Walks straight at you until this close, then starts its attack run |
| `Flank.Angle` | – | `45` | `90` | Degrees off to the side its attack run comes at you from (90 = straight from the side) |
| `Flank.EngageDistance` | – | `14` | `14` | Inside this distance it stops arcing and charges straight in |
| `Flank.GoalDistanceFactor` | – | `0.75` | `0.75` | How far along the arc it aims each step (lower = tighter curve) |
| `Colors` | green | green | green | Zombie colours (all the same for now) |

These are the same for all three:

| Setting | Current | What it controls |
|---|---|---|
| `Damage` | `10` | Damage per hit on a player |
| `AttackCooldown` | `1` | Seconds between hits |
| `AttackRange` | `4.5` | How close a zombie must be to hit you (studs) |
| `SpeedVariance` | `0.15` | Each zombie's speed is randomly ±15% of the wave speed |
| `CorpseTime` | `30` | Seconds a dead body stays before it is removed. Bodies are solid obstacles you and zombies must climb over |
| `DirectChaseDistance` | `10` | Inside this distance zombies always walk straight at you |
| `PathRecomputeInterval` | `1.5` | Seconds between pathfinding updates when a wall is in the way |
| `WaypointReachedDistance` | `3` | How close counts as reaching a path waypoint |
| `Agent` | radius 2, height 5 | Size used for pathfinding (paths never include jumps: zombies never jump walls, only a pile of them can scale one) |
| `WalkAnimationId` | `rbxassetid://180426354` | Walk animation |

### Supply crates: [`Pickups.lua`](src/Shared/Definitions/Pickups.lua)

| Setting | Current | What it controls |
|---|---|---|
| `DropChance` | `0.12` | Chance a killed zombie drops a crate (12%) |
| `Heal` | `25` | Health restored on pickup |
| `AmmoFraction` | `0.5` | Fraction of each gun's `MaxAmmo` refilled |
| `Lifetime` | `8` | Seconds before an untouched crate disappears |
| `BlinkTime` | `3` | Seconds before disappearing that the crate starts flashing (so at 5 s) |
| `BlinkStartRate`, `BlinkEndRate` | `2`, `10` | Flashes per second when flashing starts, and just before it disappears |
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
| `ARM_REACH`, `ARM_SWING`, `STROKES_MOVING`, `STROKES_IDLE`, `STROKE_MIN_PITCH` | [`BodyPoseController.lua`](src/Client/Controllers/BodyPoseController.lua) | Crawl stroke (legless zombies, and climbers leaning at least `STROKE_MIN_PITCH` = 30° into their crawl): how far ahead the arms reach, how far each sweeps, and how fast they stroke while moving / idle |
| `BODY_ANGLE`, `HEAD_ANGLE`, `SNAP_TIME`, `RECOVER_TIME`, `HEAD_CRAWL_SHARE`, `CRAWL_BLEND_TIME` | [`BodyPoseController.lua`](src/Client/Controllers/BodyPoseController.lua) | How far and how fast hit zombies and players flinch; how much the head lifts while crawling and how fast the crawl pose blends in |
| `ARM_RAISE` | [`ZombieRig.lua`](src/Server/Enemies/ZombieRig.lua) | Zombie arm pose: degrees lifted forward from the sides (0 = hanging down, 90 = classic arms-out) |
| `SIDESTEP_PROBE`, `SIDESTEP_ANGLE`, `SIDESTEP_TIME` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | How far (bumper + 1 studs) and at what angle (60° off its heading) a zombie blocked by another looks for a gap to each side, and how long (0.6 s) it keeps edging one way before looking again |
| `WALL_SIDESTEP_ANGLE`, `WALL_SIDESTEP_TIME` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | A zombie stuck on a wall (with no path round it) slides along it at this angle (90°, straight along) and keeps to one side for this long (1.5 s) before looking again |
| `JAMMED_THINKS_TO_CLIMB` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | AI updates (0.2 s each, so 4 = 0.8 s) a zombie must stay jammed against living zombies, getting nowhere, before it climbs on top of them. Lower = piles start sooner |
| `LANE_SHARE`, `LANE_MAX` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | Approach lanes: each zombie aims at a point off to one side of the player, up to 70% of its distance and at most 20 studs (lanes are weighted towards the edges, so few share the middle), which closes in as it gets near, so a crowd arrives as a wide front instead of a line. Raise for a wider fan |
| `BLOCK_CHECK_RADIUS` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | Width (studs) of the "what is in front of me" checks |
| `WALL_FOOT_DROP`, `WALL_STEEPNESS` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | Pile wall-scaling: the second wall check runs this far below the root (about the feet, so a zombie keeps clawing until its feet clear the top edge), and how upright a surface must be to count as a wall |
| `CLIMB_LIFT_FORCE`, `CLIMB_CHECK_DOWN`, `CLIMB_CHECK_AHEAD` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | How strong the climb lift is, and how far a zombie looks down/ahead to tell it is on or against a pile (ahead reaches past the bumper: `ZombieBumperDiameter + 0.5`) |
| `CRAWL_PITCH`, `CRAWL_SLOPE_LIMIT`, `CRAWL_SLOPE_FOLLOW`, `CRAWL_PITCH_STEP` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | How far a climbing zombie leans into its crawl, how much the climb angle changes that, and how often it is re-sent |
| `PATH_HEIGHT_GAP`, `STUCK_THINKS_BEFORE_PATH`, `FORCE_PATH_TIME` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | When a zombie switches to pathfinding: player this far above it, or stuck this many AI updates (then it paths for this many seconds) |
| `STUCK_DISTANCE`, `WALK_ANIMATION_FADE` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | When a zombie counts as stuck and jumps; how far it looks down/ahead to decide it is climbing over zombies or corpses; how fast the walk animation stops/starts around a stagger |
| `KNOCKBACK_LIFT`, `RAGDOLL_BODY_SHARE` | [`Enemy.lua`](src/Server/Enemies/Enemy.lua) | Upward share of knockback; how much of the ragdoll push goes to the whole body vs. the hit part |
| `BODY`, `HEADSHOT`, `EXPLOSION`, `COLOR`, `LIFETIME` | [`BloodSplash.lua`](src/Client/Effects/BloodSplash.lua) | Particle count, size, speed and spread of body, headshot and exploding-head blood; colour and duration |
| `START_RATE`, `COLOR`, `DRIP_INTERVAL` | [`BloodPour.lua`](src/Client/Effects/BloodPour.lua) | How heavily blood pours at first, its colour, and how often it drips a stain |
| `STYLES`, `PAINT_SPLATTERS_PER_PATCH`, `PAINT_MIN_SHARE`, `COAT_MAX_OPACITY`, `NEIGHBOUR_SHARE`, `WALL_PROBE_HEIGHT`, `SEEP_REACH`, `CORE_BLOBS`, `DROPLETS`, `STREAKS`, `STRETCH_MIN`, `FRESH_TINT`, `PAINT_TINT`, `SPLATTER_SCALE`, `DRY_TIME`, `PAINT_PATCH_SIZE`, `PAINT_MAX_OPACITY` | [`BloodStains.lua`](src/Client/Effects/BloodStains.lua) | Size, wet opacity and dried-paint opacity of each kind of stain (hit splash, drip, trail, death pool); wet and dried colours; how long drying takes |
| `TRAIL_INTERVAL`, `DEATH_POOL_DELAY` | [`GoreController.lua`](src/Client/Controllers/GoreController.lua) | How often legless zombies leave a trail stain; how long after death the pool is painted |
| `HEADSHOT_COLOR`, `SPIKE_COLOR`, `MIDDLE_SPIKE_LENGTH`, `SIDE_SPIKE_LENGTH`, `SPIKE_FAN`, `FLASH_SCALE`, `FLASH_HOLD`, `FLASH_RECOVER` | [`Crosshair.lua`](src/Client/UI/Crosshair.lua) | Look and timing of the headshot crosshair flash |
| `GLOW_COLOR`, `EDGE_DEPTH`, `EDGE_TRANSPARENCY`, `HOLD` | [`RegenOverlay.lua`](src/Client/UI/RegenOverlay.lua) | Colour, width and strength of the green heal border; how long it stays after a heal |
| `CROSS_COLOR`, `CROSS_SIZE`, `LIFETIME` / `HEALTH_PER_CROSS`, `MAX_CROSSES`, `HURT_SOUND_MIN_INTERVAL` | [`HealCrosses.lua`](src/Client/Effects/HealCrosses.lua) / [`HealthFeedbackController.lua`](src/Client/Controllers/HealthFeedbackController.lua) | Look of the heal crosses / how many appear per heal |
| Colours and sizes | [`src/Client/UI/`](src/Client/UI/) | HUD colours, positions and text sizes, at the top of each UI file |

---

## What happens when you shoot a zombie

1. **Client** ([`WeaponClientController`](src/Client/Controllers/WeaponClientController.lua)): you hold Fire while focused. Each fire interval it aims at whatever is under the crosshair, sends **only the direction** over `WeaponFire`, and draws a tracer and plays the sound right away.
2. **Server** ([`WeaponService`](src/Server/Services/WeaponService.lua)): checks the request (valid unit vector, rate limit, player alive, holding one of their own guns).
3. [`GunController`](src/Server/Weapons/GunController.lua) checks ammo and fire rate, takes one ammo, and fires from the server's own muzzle position.
4. [`Hitscan`](src/Server/Weapons/Components/Firing/Hitscan.lua) raycasts and calls `EnemyService.DamageModel` for each zombie hit.
5. [`Enemy`](src/Server/Enemies/Enemy.lua) loses health. If it survives, it is staggered by the weapon's stopping power and shoved by its knockback. If any bullet hit a head, the server sends `Headshot` to the shooter, who hears the crunch and sees the crosshair flash. At 0 health the zombie ragdolls ([`Ragdoll`](src/Server/Util/Ragdoll.lua)), the killing shot pushes the body where it hit, a headshot kill may explode or pop off the head (currently 50% each), and `EnemyService` fires `EnemyDied`.
6. Listeners react on their own:
   - [`ScoreService`](src/Server/Services/ScoreService.lua) adds the kill, combo and points, and checks weapon unlocks.
   - [`PickupService`](src/Server/Services/PickupService.lua) may drop a supply crate.
   - [`GameService`](src/Server/Services/GameService.lua) lowers "zombies left" and ends the wave at 0.
7. The server sends `WeaponFired` to everyone with the tracer endpoints and the hit positions. Other players draw the tracers, and everyone, including the shooter, sees blood at each hit, bigger for headshots ([`BloodSplash`](src/Client/Effects/BloodSplash.lua)). The HUD updates from attributes.

---

## Remotes

All are defined in [`Net.lua`](src/Shared/Net.lua).

| Remote | Direction | Payload | Handled in |
|---|---|---|---|
| `WeaponFire` | client → server | `direction: Vector3` | `WeaponService` (validated, rate-limited) |
| `WeaponFired` | server → all clients | shooter, weapon id, origin, tracer endpoints, body hit positions, head hit positions | `WeaponClientController` (tracers, sound, blood) |
| `LimbSevered` | server → all clients | body part, its joint offset, severed limb, its joint offset | `GoreController` (blood from stump and limb) |
| `Headshot` | server → shooter | nothing | `WeaponClientController` (sound), `UIController` (crosshair flash) |
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
| Change zombie damage or attack range | Edit [`Enemies/Zombie.lua`](src/Shared/Definitions/Enemies/Zombie.lua), [`Enemies/ZombieB.lua`](src/Shared/Definitions/Enemies/ZombieB.lua) or [`Enemies/FastZombie.lua`](src/Shared/Definitions/Enemies/FastZombie.lua). |
| Change how often each zombie type spawns | Edit the weights in `ENEMY_MIX` in [`Waves.lua`](src/Shared/Definitions/Waves.lua). |
| Add a zombie type | Copy an enemy file with a new `Id`, pick its `Behaviour`, and add it to `ENEMY_MIX`. |
| Change crate drop chance or heal | Edit [`Pickups.lua`](src/Shared/Definitions/Pickups.lua). |
| Change round timers, combo timing or health regen | Edit [`GameRules.lua`](src/Shared/Definitions/GameRules.lua). |
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
