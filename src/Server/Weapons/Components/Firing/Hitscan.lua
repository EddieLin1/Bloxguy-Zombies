--!strict
-- Instant raycast bullets, with pellets (shotguns) and pierce (rifles, railguns).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
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
	return setmetatable({
		_context = context,
		_definition = definition,
		_params = params,
		_rng = Random.new(),
	}, Hitscan)
end

-- Casts one ray, damaging living enemies until it hits a wall, runs out of range or pierce.
-- Returns where the ray ended and whether it damaged any living enemy's head.
function Hitscan._castRay(self: Hitscan, origin: Vector3, direction: Vector3): (Vector3, boolean)
	local firing = self._definition.Firing
	local context = self._context
	local exclude = context.GetIgnoreList()
	local position = origin
	local remaining = firing.Range
	local pierced = 0
	local headshot = false

	while remaining > 0 do
		self._params.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(position, direction * remaining, self._params)
		if not result then
			return position + direction * remaining, headshot
		end

		local model = context.Enemies.GetModelFromPart(result.Instance)
		if not model then
			return result.Position, headshot -- hit the map
		end

		local isHead = result.Instance.Name == HEAD_PART_NAME
		local damage = self._definition.Damage
		if isHead then
			damage *= context.HeadshotMultiplier
		end
		if context.Enemies.DamageModel(model, damage, context.Owner) then
			headshot = headshot or isHead
			pierced += 1
			if pierced >= firing.Pierce then
				return result.Position, headshot
			end
		end

		-- Pass through this enemy (or corpse) and keep going
		table.insert(exclude, model)
		remaining -= (result.Position - position).Magnitude
		position = result.Position
	end
	return position, headshot
end

function Hitscan.Fire(self: Hitscan, origin: Vector3, direction: Vector3): WeaponTypes.FireResult
	local firing = self._definition.Firing
	local endpoints = table.create(firing.Pellets)
	local headshot = false
	for _ = 1, firing.Pellets do
		local endpoint, pelletHeadshot =
			self:_castRay(origin, Spread.Apply(direction, firing.SpreadDegrees, self._rng))
		table.insert(endpoints, endpoint)
		headshot = headshot or pelletHeadshot
	end
	return { Endpoints = endpoints, Headshot = headshot }
end

function Hitscan.Destroy(_self: Hitscan) end

return Hitscan
