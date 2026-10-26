---
name: roblox-weapons-oop
description: Use when building or modifying weapons in a Roblox game, including guns, melee, ammo, reloading, fire rate, projectiles, damage, and weapon switching. Implements an OOP, component-based design (WeaponService, Controller, Components, Definitions) with server authority.
---

# Weapons: OOP, component-based

Do not put a Script and LocalScript in every weapon. One system handles all weapons. Data lives in definitions; behaviour lives in reusable components; a controller composes them per equipped weapon.

## Hierarchy
```
WeaponService (server)           creates and stores one Controller per player, owns the remotes
  GunController                  runtime state + composes components for one player's weapon
    Components/
      Firing/   Hitscan, Projectile, Shotgun, Melee, Beam
      Reload/   Magazine, ShellByShell, None
      Effects/  (client) Muzzle flash, tracer, sound, camera shake
    Definitions/                 pure data: Pistol, Shotgun, Rifle...
```
Files:
```
ReplicatedStorage/Shared/Weapons/Definitions/   (ModuleScripts, data only, plus an index)
ReplicatedStorage/Shared/Weapons/Types
ServerScriptService/Services/WeaponService
ServerScriptService/Weapons/GunController
ServerScriptService/Weapons/Components/Firing/{Hitscan,Projectile,...}
ServerScriptService/Weapons/Components/Reload/{Magazine,ShellByShell}
StarterPlayerScripts/Controllers/WeaponClientController   (input, prediction, effects)
StarterPlayerScripts/Weapons/Effects/...
```

## Definition (data only)
A definition names the components to use and gives their parameters. Adding a variant weapon should mean adding one file and zero new logic.
```lua
--!strict
-- Shared/Weapons/Definitions/Pistol
return {
	Id = "Pistol",
	DisplayName = "Pistol",
	Damage = 18,
	FireInterval = 0.25,      -- seconds between shots
	MagazineSize = 12,
	StartingReserve = 96,
	ReloadTime = 1.4,
	Firing = { Type = "Hitscan", Range = 120, Pellets = 1, SpreadDegrees = 1 },
	Reload = { Type = "Magazine" },
	Effects = { Muzzle = "SmallFlash", Sound = "PistolShot" },
}
```
Type it in `Shared/Weapons/Types` (`export type WeaponDefinition = { ... }`) so strict mode checks every definition.

Provide an index module that requires every definition in the folder and returns `Definitions.Get(id)`; error loudly on an unknown id.

## Component contract
A component is a small class created with `.new(context, config)`. Keep contracts uniform:
- Firing component: `Fire(self, origin: Vector3, direction: Vector3)` returns what it hit (or nothing). Applies damage through the enemy/health service, never by touching humanoids directly from many places.
- Reload component: `Begin(self, controller)`, `Cancel(self)`, finishes by calling back into the controller to refill ammo.
- Components never read global state; the controller hands them what they need (owner, character, definition).
- Map the `Type` string to a module via a registry table:
```lua
--!strict
return {
	Hitscan = require(script.Hitscan),
	Projectile = require(script.Projectile),
	Shotgun = require(script.Shotgun),
}
```
New behaviour (charge-up railgun, flamethrower) = a new component plus a definition that references it. Do not edit the controller for special cases.

## Controller (server, authoritative state)
```lua
--!strict
local GunController = {}
GunController.__index = GunController

export type GunController = typeof(setmetatable({} :: {
	Owner: Player,
	Definition: any,          -- typed as WeaponDefinition in the project
	Ammo: number,
	Reserve: number,
	Reloading: boolean,
	LastFire: number,
	_firing: any,
	_reload: any,
	_maid: any,
}, GunController))

local FIRE_TOLERANCE = 0.9    -- forgive network jitter, still blocks speed hacks

function GunController.CanFire(self: GunController, now: number): boolean
	if self.Reloading or self.Ammo <= 0 then return false end
	return now - self.LastFire >= self.Definition.FireInterval * FIRE_TOLERANCE
end

function GunController.TryFire(self: GunController, direction: Vector3): boolean
	local character = self.Owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return false end

	local now = os.clock()
	if not self:CanFire(now) then return false end
	self.LastFire = now
	self.Ammo -= 1

	local origin = root.Position + Vector3.new(0, 1.5, 0)   -- server-derived, never from the client
	self._firing:Fire(origin, direction)
	-- notify clients: ammo changed, play effects (fire remote back, or set an Attribute)
	return true
end

function GunController.Destroy(self: GunController)
	self._maid:Destroy()
end

return GunController
```
Also implement `StartReload`, `Equip`, `Unequip`, `AddAmmo`. Reload and switching cancel each other correctly (cancelling a reload on switch must not leave `Reloading = true`).

## WeaponService
- On `PlayerAdded`, build a controller for the starting weapon; on weapon change, `Destroy` the old controller and create the new one. On `PlayerRemoving`, destroy and drop the reference.
- If the game uses Roblox `Tool`s, listen for tools added to the character (or tag them with CollectionService and iterate the tag) instead of a script inside each tool. If the game keeps its own inventory (common for top-down shooters), key controllers by player and active weapon id.
- Remotes: `WeaponFire(direction)`, `WeaponReload()`, `WeaponSwitch(weaponId)`. Validate per `roblox-networking-security`: type and range, rate limit, ownership of the weapon id.

## Client side
- Handle input in a controller (see `roblox-input-camera`), send direction to the server, and predict harmless things locally: muzzle flash, sound, tracer, local ammo display. Reconcile when the server's ammo update arrives.
- Never let the client decide hits or damage. Hit sparks and blood can be spawned client-side when the server confirms a hit.
- Auto-fire: hold-to-fire is a client loop that sends fire requests at the weapon's interval; the server still enforces the interval.

## Projectiles
- Hitscan = one server raycast per shot per pellet. Cheap, good default for a shooter with many enemies.
- Visible slow projectiles (rockets, grenades): simulate on the server with a stepped raycast (e.g. a FastCast-style caster) and render a cosmetic projectile on clients. Do not give each bullet its own Script; one manager updates all live projectiles. Pool or `Debris` cosmetic bullets.
- Explosions: `workspace:GetPartBoundsInRadius` (or a spatial query over tagged enemies), apply damage by distance falloff, server-side only.

## Damage pipeline
Weapons call `EnemyService.Damage(enemy, amount, source)` (or `HealthService`). That function handles armour, multipliers, kill credit, events. Components never mutate health directly. Kills emit an event the Gameplay loop and UI subscribe to.

## Lifecycle and cleanup
Each controller owns a Maid/Janitor (see `roblox-performance-cleanup`) holding its connections, timers and spawned instances. `Destroy` it when the weapon is unequipped, the player dies or leaves.

## Checklist for a new weapon
1. Add a definition file (and its type fits `WeaponDefinition`).
2. Reuse existing components if possible; otherwise add one component and register it.
3. Add an effects entry for the client.
4. Confirm the server blocks: firing while reloading, firing faster than the interval, firing with 0 ammo, using an unowned weapon id.
5. Confirm switching/death/leaving cleans up (no leaked connections or threads).

## Based on
DevForum: "Creating a tool handler" (GunService, GunController, components, definitions), "Inefficient gun system" (framework module with `.new`, data dictionary, listener instead of per-tool scripts), "Need tips for gun system" (CollectionService tag + config modules), "Roblox OOP" tutorial (base Gun class with subclasses), Creator Hub client-server boundary (weapon state on the server).
