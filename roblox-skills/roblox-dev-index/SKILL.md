---
name: roblox-dev-index
description: Start here for any Roblox (Luau) game-development task. Explains the project conventions and tells you which specialised roblox-* skill to load for architecture, networking and security, weapons, enemies and game objects, gameplay loop, UI, input and camera, player data, or performance and cleanup.
---

# Roblox game dev: index and ground rules

These skills were distilled from Roblox Creator Hub docs and DevForum discussions. They encode defaults, not laws. When a skill and the user's explicit request conflict, follow the user and mention the tradeoff in one sentence.

## Project context
- Game: "Bloxguy Zombies", a Boxhead-style top-down zombie shooter. Expect many enemies on screen, many weapon types, wave-based play, and a short loop.
- Language: Luau. Every new script starts with `--!strict`.
- Style: OOP with ModuleScripts. Code lives in modules; there is one bootstrap Script (server) and one bootstrap LocalScript (client).

## Which skill to load

| If the task involves... | Load |
|---|---|
| Creating scripts, folders, modules, deciding server/client/shared | `roblox-game-architecture` |
| RemoteEvents, RemoteFunctions, anything a client can trigger | `roblox-networking-security` |
| Guns, melee, ammo, reload, damage, projectiles | `roblox-weapons-oop` |
| Zombies, NPC AI, pickups, doors, spawners, tagged world objects | `roblox-enemies-and-game-objects` |
| Waves, rounds, lobby, win/lose, rewards | `roblox-gameplay-loop` |
| ScreenGuis, HUD, menus, shop, health bars | `roblox-ui` |
| Keyboard, mouse, touch, gamepad, aiming, camera | `roblox-input-camera` |
| Saving or loading anything per player | `roblox-player-data` |
| Lag, memory growth, connection leaks, pooling | `roblox-performance-cleanup` |

Load more than one when a task crosses areas. For example, a new weapon touches architecture, networking, weapons and usually UI.

## Non-negotiables (apply everywhere)
1. The server owns game state: health, ammo, currency, inventory, wave progress, damage. The client sends intent and renders results.
2. Every RemoteEvent handler validates its arguments and rate-limits (see `roblox-networking-security`).
3. No per-object scripts. One system script manages many objects (many zombies, many weapons).
4. Every connection and every spawned object has an owner that cleans it up (see `roblox-performance-cleanup`).
5. Data and tunables (damage, speed, costs, wave sizes) live in definition modules, not inside logic.
6. Use `task.wait`, `task.spawn`, `task.delay`, never the legacy `wait`, `spawn`, `delay`.

## Before finishing any task
- Re-read the new code for: missing `--!strict`, unvalidated remote input, undisconnected connections, hard-coded numbers that belong in a definition module.
- State which skills you applied and anything you could not verify in Studio.
