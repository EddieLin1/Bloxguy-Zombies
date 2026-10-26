---
name: roblox-enemies-and-game-objects
description: Use when creating zombies or other enemy NPCs, enemy AI and pathfinding, spawners, pickups, doors, traps, or any world object in a Roblox game. Covers a single manager loop instead of per-NPC scripts, CollectionService tags and component binding, Attributes vs tags vs module state, network ownership, and performance for large enemy counts.
---

# Enemies and game objects

## Principles
- No script per enemy. One `EnemyService` owns every enemy object and updates them in a single throttled loop.
- Enemy data lives in definitions (`Shared/Definitions/Enemies/Walker`): health, speed, damage, attack range, reward, model name, behaviour type.
- Truth lives in the server-side class object. Mirror to Attributes only what clients or other systems need to see (e.g. `Health`, `MaxHealth` for health bars).

## Choosing where state and identity live

| Need | Use |
|---|---|
| Group instances so a system can find them and react when they appear/disappear | CollectionService tag (`"Enemy"`, `"Pickup"`, `"Door"`) |
| Per-instance data that designers tweak or UI reads | Attributes (cheaper than Value objects; replicate automatically) |
| Server-only authoritative state or logic | Fields on the module class object |
| Many module scripts already tracking objects they spawned themselves | A plain table in the module (no need for tags) |

Attributes can be read and changed by exploiters on their own client but those changes do not replicate to the server, so the server must never read gameplay truth from an Attribute that a client could influence. Tags are replicated to clients too; treat them as labels, not secrets.

## Tag-driven components (works for pickups, doors, spawners, traps)
Design each world object type as a class constructed from an Instance. A binder instantiates the class when the tag appears and destroys it when the tag is removed, so designers just tag parts in Studio.

```lua
--!strict
local CollectionService = game:GetService("CollectionService")

local ComponentBinder = {}

function ComponentBinder.Bind(tag: string, class: any)
	local objects: { [Instance]: any } = {}

	local function onAdded(instance: Instance)
		if objects[instance] then return end
		objects[instance] = class.new(instance)
	end
	local function onRemoved(instance: Instance)
		local object = objects[instance]
		if object then
			object:Destroy()
			objects[instance] = nil
		end
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(tag) do
		onAdded(instance)
	end
end

return ComponentBinder
```
Each component reads its config from the instance's Attributes (`Damage`, `RespawnTime`) with defaults, and owns a Maid for its connections.

## Enemy class
```lua
--!strict
local Enemy = {}
Enemy.__index = Enemy

export type Enemy = typeof(setmetatable({} :: {
	Model: Model,
	Definition: any,
	Health: number,
	State: string,
	Target: BasePart?,
	_maid: any,
}, Enemy))

function Enemy.Think(self: Enemy, dt: number)
	-- state machine: Idle / Chase / Attack / Dead
end

function Enemy.TakeDamage(self: Enemy, amount: number, source: Player?)
	-- reduce health, update the Health attribute, fire Died signal when <= 0
end

function Enemy.Destroy(self: Enemy)
	-- maid cleanup, remove tag, Model:Destroy() or return to pool
end

return Enemy
```
Use an explicit finite state machine for behaviours (idle, chase, attack, stunned, dead) rather than nested ifs.

## EnemyService: one throttled, staggered loop
```lua
--!strict
local RunService = game:GetService("RunService")

local TICK = 0.1       -- AI step interval in seconds
local STAGGER = 4      -- each enemy thinks once every STAGGER ticks

local active: { any } = {}
local accumulator = 0
local tickCount = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < TICK then return end
	accumulator = 0
	tickCount += 1
	for i, enemy in active do
		if (i + tickCount) % STAGGER == 0 then
			enemy:Think(TICK * STAGGER)
		end
	end
end)
```
Remove dead enemies with swap-remove or rebuild the list, never `table.remove` while iterating forward.

## Movement and AI cost control
- Roblox `PathfindingService` is expensive. Many popular zombie games skip it for chasers. Default to: move straight at the target (Humanoid `MoveTo`, or custom steering), use a cheap raycast to detect a blocking wall, and run pathfinding only when blocked, rate-limited and with a cached path. For very large crowds on an open map, consider flow-field style approaches that compute one field for all enemies.
- Raycasts and `.Magnitude` distance checks are far cheaper than pathfinding; compare squared distances when you can.
- Choose targets on a slow tick (every few ticks), not every frame; cache the nearest player and revalidate occasionally.
- Disable Humanoid states enemies do not need (flying, seated, swimming, climbing) with `Humanoid:SetStateEnabled(..., false)` to save work.
- Do not use `.Touched` for melee or hit detection at scale. Use distance checks or short raycasts / `GetPartBoundsInRadius` inside the manager loop.
- Parallel Luau with Actors can offload AI math; note that built-in pathfinding historically required `task.synchronize()` before computing a path (verify against current docs before relying on this).

## Network ownership
Call `part:SetNetworkOwner(nil)` on enemy parts (usually just the root) so the server owns the physics. This avoids stutter and ownership hand-offs, and prevents clients from steering enemies. Handing ownership to clients cuts server load but lets exploiters move enemies; only consider it for single-player or cosmetic-only situations.

## Replication cost
- With many enemies, replication bandwidth and client physics matter as much as server CPU. Keep enemy models simple (few parts, no unneeded accessories or Humanoid features), or use a minimal server-side proxy (a single root part driven by the server) and let clients render the full-detail model.
- Enable `StreamingEnabled` for large maps so distant objects are not replicated.
- Despawn enemies the moment they die (or return them to a pool); dead bodies are enemies the server still pays for. Use a client-side effect for corpses and gibs.

## Spawning and pooling
- Spawn through `EnemyService.Spawn(definitionId, cframe)`; it clones the prefab from ServerStorage, creates the Enemy object, tags the model, appends to `active`.
- Pool or reuse models for high-churn enemies: reset health, state, position, and re-enable instead of cloning and destroying every time (see `roblox-performance-cleanup`).
- Cap simultaneous enemies per wave; spawn in batches over several frames rather than all at once.

## Kill flow
`Enemy:TakeDamage` -> health <= 0 -> fire `EnemyService.EnemyDied(enemy, killer)` -> reward service grants currency/score -> gameplay loop decrements the remaining count -> enemy `Destroy`s. Everything downstream subscribes to the signal; the enemy class knows nothing about waves or UI.

## Pickups, doors, traps
Same pattern: tag, class per type, Attributes for tunables, server-side checks. A pickup validates proximity on the server before granting; a trap damages via the same damage pipeline as weapons; a door toggles via a server-owned state with the visual driven by an Attribute change.

## Checklist
- [ ] No per-enemy or per-object Scripts.
- [ ] Definitions hold stats; classes hold behaviour.
- [ ] AI runs in one throttled loop; pathfinding is the exception, not the default.
- [ ] Network owner set to nil on enemy parts.
- [ ] Enemies and objects clean up all connections and instances on death/removal.
- [ ] Damage goes through one function.

## Based on
DevForum: "How handle a lot of NPC?", "How to fully optimize zombies?", "NPC Logic on Client vs Server", "Attributes vs CollectionService", "Which tagging method should I use?", "Need tips for gun system" (CollectionService iteration), "PathfindingModule | State-Driven AI Movement System".
