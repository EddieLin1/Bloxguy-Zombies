---
name: roblox-game-architecture
description: Use when creating or reorganising scripts, ModuleScripts, folders or services in a Roblox game, deciding whether code belongs on the server, client or shared, writing a new Luau class or module, or setting up the bootstrap Script and LocalScript. Covers project layout, single-script architecture, Services and Controllers, and Luau strict-mode style.
---

# Roblox game architecture

## Core pattern: few scripts, many modules
Roblox's own docs recommend writing most code in ModuleScripts and `require`-ing them all from exactly one server Script and one client LocalScript. DevForum veterans agree: fewer entry points make load order predictable and debugging easier. It is not absolute (a mix is fine), but never put a Script inside every enemy, weapon or GUI.

## Where code lives

| Location | Put here |
|---|---|
| `ServerScriptService` | Server bootstrap Script + server-only modules (Services). Clients cannot see this. |
| `ServerStorage` | Server-only assets (enemy models, maps, prefabs). |
| `ReplicatedStorage` | Code and data shared by both sides: definitions, Types, Constants, utility modules, Remotes folder. Anything here is readable by exploiters, so no secrets. |
| `StarterPlayerScripts` | Client bootstrap LocalScript. Does not reset on respawn, unlike StarterGui / StarterCharacterScripts. |
| `StarterGui` | UI instances only. Keep logic out of LocalScripts inside GUIs. |

## Recommended layout
```
ServerScriptService/
  Server (Script)            -- bootstrap
  Services/                  -- DataService, WeaponService, EnemyService, GameService...
  Weapons/  Enemies/         -- server classes and components
ReplicatedStorage/
  Shared/
    Types, Constants
    Definitions/             -- Weapons/, Enemies/, Waves/ (pure data)
    Util/                    -- Signal, Maid, Net, etc.
  Remotes/                   -- RemoteEvents, one per action
StarterPlayer/StarterPlayerScripts/
  Client (LocalScript)       -- bootstrap
  Controllers/               -- InputController, WeaponController, UIController...
  UI/                        -- one module per screen or component
```
If the project uses Rojo, mirror this as `src/Server`, `src/Client`, `src/Shared`.

## Services and Controllers
- Server modules are Services (`DataService`, `EnemyService`). Client modules are Controllers (`InputController`).
- Each exposes optional `Init()` (wire references, no yielding) and `Start()` (begin running). The bootstrap calls all `Init`s, then all `Start`s, so modules can depend on each other safely.

```lua
--!strict
-- ServerScriptService/Server (Script)
local ServerScriptService = game:GetService("ServerScriptService")

local loaded: { [string]: any } = {}
for _, module in ServerScriptService.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		loaded[module.Name] = require(module)
	end
end
for _, service in loaded do
	if service.Init then service.Init() end
end
for _, service in loaded do
	if service.Start then task.spawn(service.Start) end
end
```
Mirror this in the client LocalScript with Controllers.

## Luau style (strict, typed, consistent)
- First line `--!strict`. Type function parameters and returns. Narrow any external input (remote args, `FindFirstChild` results) with type checks.
- All `require` calls at the top of the file so dependencies are static. Avoid circular requires; if two modules need each other, pass one in through `Init` or use a signal.
- PascalCase for modules, classes, types and public functions; camelCase or snake_case for locals and private members, but be consistent across the project. Prefix private members with `_`.
- Constants in UPPER_SNAKE at top of file, or shared ones in `Shared/Constants`.
- Cache services once: `local Players = game:GetService("Players")`.

## Class template (strict-mode friendly)
Luau's inference struggles with metatable classes, so declare the shape explicitly and define methods with dot syntax and a typed `self`. Callers still use colon syntax.

```lua
--!strict
local Zombie = {}
Zombie.__index = Zombie

export type Zombie = typeof(setmetatable({} :: {
	_health: number,
	_model: Model,
}, Zombie))

function Zombie.new(model: Model, health: number): Zombie
	return setmetatable({ _health = health, _model = model }, Zombie)
end

function Zombie.TakeDamage(self: Zombie, amount: number)
	self._health = math.max(0, self._health - amount)
end

return Zombie
```
For inheritance, `setmetatable(Child, { __index = Base })` and call `Base.new` from `Child.new`. Prefer composition (components) over deep inheritance; see `roblox-weapons-oop`.

## Data vs behaviour
- Tunable numbers and per-type config go in definition ModuleScripts (`Definitions/Weapons/Pistol`), one small file per item or one dictionary for tiny sets.
- Per-instance state: Attributes (cheap, replicate automatically) or fields on the server-side class object.
- Grouping instances so a system can find them: CollectionService tags.

## Checklist for a new feature
1. Which side owns the truth? (Almost always server.)
2. What definition module holds its numbers?
3. Which Service or Controller owns its lifecycle?
4. What remotes does it need, and how are they validated?
5. How is everything it creates cleaned up?

## Based on
Roblox Creator Hub "Script locations"; DevForum: "How do you architect a Single-Script Architecture?", "Do I start over or continue like this? (weapon system)"; Quenty's Luau conventions and the Roblox Lua style guide (strict mode, typed self, requires at top).
