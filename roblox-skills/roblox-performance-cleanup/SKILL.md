---
name: roblox-performance-cleanup
description: Use when a Roblox game lags, its memory grows over time, or when writing any code that creates connections, instances, tweens, threads or timers. Covers Maid/Janitor cleanup, preventing connection leaks, object pooling, throttled loops, StreamingEnabled, and profiling with the MicroProfiler and Developer Console.
---

# Performance and cleanup

## Leaks: the usual cause of "the server gets slower the longer it runs"
Luau's garbage collector cannot free anything that is still referenced. The most common leak is an event connection whose callback closes over objects: if you never `:Disconnect()` it, everything the closure holds stays alive. Destroying an Instance cleans up connections to that Instance's own events, but connections to services (`Heartbeat`, `RenderStepped`, `Players.PlayerAdded`, a RemoteEvent) or to other still-living objects persist.

Rules:
1. Every `:Connect` is either (a) tied to the lifetime of an Instance that will be destroyed, or (b) stored and disconnected, usually through a Maid.
2. Use `:Once` for connections that should fire a single time.
3. Destroy Instances you create (including Tweens you keep, and clones), and drop table references to them.
4. Clean up per-player tables on `PlayerRemoving`.
5. Do not `GetDescendants()` or `GetChildren()` in hot loops; cache results, listen to added/removed signals instead.
6. Cancel threads you no longer need (`task.cancel`) and make waiting code check a "still alive" flag.
7. Characters respawn: connections made per character belong to a per-character Maid destroyed on death/removal.

## A minimal Maid
Use an existing community module (Maid, Janitor, Trove) if the project already has one; otherwise this is enough:

```lua
--!strict
local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { any } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid.GiveTask(self: Maid, task: any): any
	table.insert(self._tasks, task)
	return task
end

function Maid.Destroy(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for _, item in tasks do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		elseif kind == "thread" then
			task.cancel(item)
		elseif kind == "table" and typeof(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

return Maid
```
Each class that owns connections creates a Maid in `new`, gives it every connection/instance/thread, and calls `maid:Destroy()` in its own `Destroy`. Composition: a weapon controller's maid also holds its components.

## Object pooling
Spawning and destroying many identical objects (bullets, enemies, damage numbers, particles) causes churn. Reuse them.
```lua
--!strict
local Pool = {}
Pool.__index = Pool

function Pool.new(factory: () -> Instance, reset: (Instance) -> ())
	return setmetatable({ _free = {} :: { Instance }, _factory = factory, _reset = reset }, Pool)
end

function Pool.Get(self: any): Instance
	local obj = table.remove(self._free) or self._factory()
	return obj
end

function Pool.Release(self: any, obj: Instance)
	self._reset(obj)           -- stop effects, clear state, move far away or parent to nil
	table.insert(self._free, obj)
end

return Pool
```
Pool when churn is high and objects are expensive to create (enemy models, projectile visuals). Always reset all state on release. Cap pool sizes.

For fire-and-forget visuals use `Debris:AddItem` or `task.delay` + `Destroy`, preferably from a pool.

## Loops and scheduling
- Use `task.wait`, `task.spawn`, `task.defer`, `task.delay`. Never `wait()` / `spawn()`.
- One `Heartbeat` connection per system with an accumulator and a tick interval, not one loop per object. Stagger work across ticks (see `roblox-enemies-and-game-objects`).
- Prefer event-driven code (signals, `GetAttributeChangedSignal`, `Changed`) to polling.
- Never run heavy work in `RenderStepped` unless it must happen before rendering (camera, character rotation).
- Move expensive, independent computation to Parallel Luau with Actors only after profiling shows it is needed.

## Replication and world size
- Enable `StreamingEnabled` for large maps so far-away content is not replicated to every client. Test gameplay code against streaming (parts may not exist yet: use `WaitForChild` with timeouts or `ModelStreamingMode` Persistent on important models).
- Reduce part count and union/mesh complexity; use `MeshPart`s; set `CanCollide`, `CanTouch`, `CanQuery` off for decoration. Mobile is the budget target.
- Keep enemies simple (few parts), despawn promptly, and keep the number of replicated, simulated physics objects low.
- Anchor everything that does not need physics. Set network ownership deliberately.

## Measuring
- **MicroProfiler** (Ctrl+F6 in the client): per-frame timing for scripts, physics, rendering. Find the frame-time culprit before optimising.
- **Developer Console** (F9): memory, script activity, network, and the action bindings tab.
- **Log memory over time** on live servers: a periodic `Stats:GetTotalMemoryUsageMb()` log that grows without bound indicates a leak. Playtest in the Roblox player rather than Studio, because Studio adds overhead that skews memory numbers.
- Test with realistic load: maximum enemies and players, low-end mobile device or emulator throttling.

## Code-level habits
- Cache service and instance references outside loops.
- Avoid creating tables or closures every frame in hot paths; reuse them.
- Use `string.format` / interpolation sparingly in per-frame code.
- Compare squared distances to avoid `Magnitude` square roots in big loops.
- Weak tables (`setmetatable({}, { __mode = "k" })`) can hold per-instance caches without keeping instances alive; use them only when you understand them, they are not a substitute for cleanup.

## Review checklist
- [ ] Every connection, thread and created instance has an owner and a cleanup path.
- [ ] Per-player and per-character state is cleaned on leave/death.
- [ ] No per-object loops or scripts where one manager loop would do.
- [ ] Churned objects are pooled or debris-managed.
- [ ] Performance was measured, not guessed, before optimising.

## Based on
DevForum: "Help with memory leaks", "Tips on avoiding memory leaks", "Should you disconnect character connections when they die?", "How do I fix memory leaks again", "How to fully optimize zombies?", "How handle a lot of NPC?", community articles on Luau memory leaks and MicroProfiler use.
