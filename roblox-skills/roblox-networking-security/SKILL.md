---
name: roblox-networking-security
description: Use whenever writing or reviewing RemoteEvents, RemoteFunctions, or any server code that reacts to client input in a Roblox game. Covers server-authoritative design, argument validation, rate limiting, per-action remotes, and anti-exploit sanity checks.
---

# Networking and security

## Mental model
Never trust the client. An exploiter can fire any remote they can see, with any arguments, as fast as they like. Remote names and "secret keys" are not security. Real security is the server checking that the request is legal. If the server holds the true state (ammo, health, cash, position), a forged request changes nothing.

## Rules
1. **One remote per action.** `WeaponFire`, `WeaponReload`, `ShopBuy`. Do not multiplex many message types through one remote with a "type" string; it makes validation harder.
2. **Client sends intent, not results.** Send an aim direction, not "I hit enemy X for 50 damage". Never accept damage values, currency amounts, cooldown states or health from the client.
3. **Server derives context itself.** Origin position, equipped weapon, ammo, owned items all come from server state, not arguments.
4. **Validate every argument** on every call, in this order:
   - Count and type (`typeof(arg) == "Vector3"`).
   - Value sanity: NaN (`x ~= x`), finite, within range (direction magnitude near 1, string length, enum membership, integer bounds).
   - Context/permission: is the player alive, is the weapon equipped, is the shop in range, do they own it.
   - State: not reloading, not stunned, enough ammo or currency.
5. **Rate limit on the server.** Client-side limits only stop honest players. Every remote has a minimum interval or a token bucket. Be especially strict on anything expensive (spawning, cloning, DataStore calls, purchases).
6. **Prefer RemoteEvents.** RemoteFunction invocations from the server to the client can hang forever if the client disconnects or misbehaves; keep two-way calls client to server only, and wrap in `pcall` / timeouts if you must.
7. **Replicate results back** with events or Attributes (hit confirmed, ammo updated, wave started) so clients can show UI. Visual-only effects (sparks, sounds, tracers) can be client-side without server involvement.
8. **Failed validation = silent return**, not an error. Count repeated failures per player and kick or log if abuse is clear.

## Rate limiter sketch (server)
```lua
--!strict
local Players = game:GetService("Players")

local RateLimiter = {}
local lastCall: { [Player]: { [string]: number } } = {}

function RateLimiter.Allow(player: Player, key: string, minInterval: number): boolean
	local now = os.clock()
	local perPlayer = lastCall[player]
	if not perPlayer then
		perPlayer = {}
		lastCall[player] = perPlayer
	end
	local last = perPlayer[key]
	if last and now - last < minInterval then
		return false
	end
	perPlayer[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

return RateLimiter
```

## Handler template
```lua
--!strict
WeaponFire.OnServerEvent:Connect(function(player: Player, direction: unknown)
	if not RateLimiter.Allow(player, "WeaponFire", 0.04) then return end
	if typeof(direction) ~= "Vector3" then return end
	if direction ~= direction then return end                       -- NaN
	local mag = direction.Magnitude
	if mag < 0.5 or mag > 1.5 then return end

	local controller = WeaponService.GetController(player)           -- server state
	if not controller then return end
	controller:TryFire(direction.Unit)                               -- checks ammo, cooldown, reloading, alive
end)
```
(`unknown` forces you to narrow the type before use under `--!strict`.)

## Combat-specific
- Server stores weapon and player state and refuses to fire while reloading, dead or switching. Roblox's docs call this out explicitly for weapon targeting.
- Fire rate is checked with the server clock (`os.clock()`), never a client timestamp.
- Hit detection approaches (pick one per game, document it):
  1. **Server raycast (safest).** Client sends direction; server casts from a server-known origin. Needed for a zombie shooter where enemies are server-owned.
  2. **Client raycast + server verification.** More responsive but needs distance/line-of-sight/fire-rate checks and a rollback or tolerance for latency. Only if responsiveness demands it.
  3. Lag-compensated rollback hitboxes exist but add complexity and their own exploit surface (cap rollback time).
- Server raycast cost scales with fire rate and players; keep rays short-lived and filter with `RaycastParams`.

## Economy and progression
- Purchases: server checks the player owns enough currency and the item exists, then deducts. Never send "give me item" without a server price lookup.
- Rewards (kill money, wave bonuses) are granted by the server from its own events, never by a remote.
- Touched or proximity triggers: still verify distance server-side, since exploiters can teleport.

## Remotes folder hygiene
- All remotes live in `ReplicatedStorage/Remotes`, created once, named for the action.
- Wrap them in a small `Net` module (get-by-name, typed signature comments) so handlers stay consistent.
- Remotes that hit DataStores or spawn objects need the strictest limits; Roblox services like DataStore and Badge have their own rate limits that fail requests when exceeded.

## Review checklist
- [ ] Each remote handler validates type, range, context and state.
- [ ] Each remote has a server-side rate limit and per-player cleanup.
- [ ] No client-supplied damage, currency or state is ever trusted.
- [ ] Origin and ownership come from server state.
- [ ] Repeated failed validation is logged or acted on.

## Based on
Roblox Creator Hub "Securing the client-server boundary"; DevForum: "Roblox Cheaters Mass Kicking" (validate params, don't multiplex remotes, rate limit expensive remotes), "Rate limiter module for Remotes", "Help on creating anti-exploits", "Server side hit detection", "How to implement lag compensation".
