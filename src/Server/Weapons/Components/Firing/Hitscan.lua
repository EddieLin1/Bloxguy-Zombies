--!strict
-- Instant raycast bullets, with pellets (shotguns) and pierce (rifles, railguns).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
local WeaponTypes = require(script.Parent.Parent.Parent.WeaponTypes)

local HEAD_PART_NAME = "Head"

local Hitscan = {}
Hitscan.__index = Hitscan

export type Hitscan = typeof(setmetatable({} :: {
	_context: WeaponTypes.FiringContext,
	_definition: Types.WeaponDefinition,
	_params: RaycastParams,
	_rng: Random,
}, Hitscan))

function Hitscan.new(context: WeaponTypes.FiringContext, definition: Types.WeaponDefinition): Hitscan
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.CollisionGroup = Constants.CollisionGroups.Shots -- passes through zombie bumpers to the body
	return setmetatable({
		_context = context,
		_definition = definition,
		_params = params,
		_rng = Random.new(),
	}, Hitscan)
end

-- Casts one ray, damaging living enemies until it hits a wall, runs out of range or pierce.
-- Returns where the ray ended. Each damaging hit's position is appended to `headHits` if it
-- struck a head, otherwise to `hits`.
function Hitscan._castRay(
	self: Hitscan,
	origin: Vector3,
	direction: Vector3,
	hits: { Vector3 },
	headHits: { Vector3 }
): Vector3
	local firing = self._definition.Firing
	local context = self._context
	local exclude = context.GetIgnoreList()
	local position = origin
	local remaining = firing.Range
	local pierced = 0

	while remaining > 0 do
		self._params.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(position, direction * remaining, self._params)
		if not result then
			return position + direction * remaining
		end

		local model = context.Enemies.GetModelFromPart(result.Instance)
		if not model then
			return result.Position -- hit the map
		end

		local isHead = result.Instance.Name == HEAD_PART_NAME
		local damage = self._definition.Damage
		if isHead then
			damage *= context.HeadshotMultiplier
		end
		local hit: WeaponTypes.Hit = {
			Position = result.Position,
			Direction = direction,
			Part = result.Instance :: BasePart,
			Impact = self._definition.Impact,
		}
		if context.Enemies.DamageModel(model, damage, context.Owner, hit) then
			table.insert(if isHead then headHits else hits, result.Position)
			pierced += 1
			if pierced >= firing.Pierce then
				return result.Position
			end
		end

		-- Pass through this enemy (or corpse) and keep going
		table.insert(exclude, model)
		remaining -= (result.Position - position).Magnitude
		position = result.Position
	end
	return position
end

function Hitscan.Fire(self: Hitscan, origin: Vector3, direction: Vector3): WeaponTypes.FireResult
	local firing = self._definition.Firing
	local endpoints = table.create(firing.Pellets)
	local hits = {}
	local headHits = {}
	for _ = 1, firing.Pellets do
		local pelletDirection = Spread.Apply(direction, firing.SpreadDegrees, self._rng)
		table.insert(endpoints, self:_castRay(origin, pelletDirection, hits, headHits))
	end
	return { Endpoints = endpoints, Hits = hits, HeadHits = headHits }
end

function Hitscan.Destroy(_self: Hitscan) end

return Hitscan
