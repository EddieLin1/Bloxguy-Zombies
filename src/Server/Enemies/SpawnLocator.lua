--!strict
-- Picks where a new enemy appears: a designer-placed spawn point if the map has any,
-- otherwise open ground in a ring around a random living player.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)

local LEGACY_SPAWN_FOLDER = "ZombieSpawns" -- parts in Workspace.ZombieSpawns also count as spawn points
local SPAWN_HEIGHT = 3
local ATTEMPTS = 25
local RAY_START_HEIGHT = 200
local RAY_LENGTH = 500
local MIN_GROUND_NORMAL_Y = 0.7 -- reject steep slopes
local MAX_HEIGHT_ABOVE_PLAYER = 6 -- reject roofs
local TOO_CLOSE_FACTOR = 0.7 -- of SpawnDistanceMin
local FALLBACK_RADIUS = 60
local FALLBACK_HEIGHT = 5

local SpawnLocator = {}

local rng = Random.new()

local function getSpawnPoints(): { BasePart }
	local points = {}
	for _, instance in CollectionService:GetTagged(Constants.Tags.EnemySpawn) do
		if instance:IsA("BasePart") then
			table.insert(points, instance)
		end
	end
	local legacy = workspace:FindFirstChild(LEGACY_SPAWN_FOLDER)
	if legacy then
		for _, child in legacy:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(points, child)
			end
		end
	end
	return points
end

local function isTooClose(position: Vector3, targets: { BasePart }, minDistance: number): boolean
	local minDistanceSq = minDistance * minDistance
	for _, target in targets do
		local offset = target.Position - position
		if offset:Dot(offset) < minDistanceSq then
			return true
		end
	end
	return false
end

function SpawnLocator.Find(targets: { BasePart }, mapParams: RaycastParams): Vector3
	local points = getSpawnPoints()
	if #points > 0 then
		return points[rng:NextInteger(1, #points)].Position + Vector3.new(0, SPAWN_HEIGHT, 0)
	end

	for _ = 1, ATTEMPTS do
		local center = if #targets > 0 then targets[rng:NextInteger(1, #targets)].Position else Vector3.zero
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(GameRules.SpawnDistanceMin, GameRules.SpawnDistanceMax)
		local x = center.X + math.cos(angle) * distance
		local z = center.Z + math.sin(angle) * distance
		local result =
			workspace:Raycast(Vector3.new(x, center.Y + RAY_START_HEIGHT, z), Vector3.new(0, -RAY_LENGTH, 0), mapParams)
		if
			result
			and result.Normal.Y > MIN_GROUND_NORMAL_Y
			and result.Position.Y < center.Y + MAX_HEIGHT_ABOVE_PLAYER
			and not isTooClose(result.Position, targets, GameRules.SpawnDistanceMin * TOO_CLOSE_FACTOR)
		then
			return result.Position + Vector3.new(0, SPAWN_HEIGHT, 0)
		end
	end

	return Vector3.new(
		rng:NextNumber(-FALLBACK_RADIUS, FALLBACK_RADIUS),
		FALLBACK_HEIGHT,
		rng:NextNumber(-FALLBACK_RADIUS, FALLBACK_RADIUS)
	)
end

return SpawnLocator
