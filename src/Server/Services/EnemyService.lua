--!strict
-- Owns every enemy: spawning, one throttled and staggered AI loop, the damage pipeline,
-- and the death/removal events that score, pickups and the wave loop subscribe to.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local EnemyDefinitions = require(Shared.Definitions.Enemies)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Server = script.Parent.Parent
local Enemy = require(Server.Enemies.Enemy)
local SpawnLocator = require(Server.Enemies.SpawnLocator)
local ZombieRig = require(Server.Enemies.ZombieRig)
local WorldFolders = require(Server.Util.WorldFolders)
local PlayerService = require(script.Parent.PlayerService)

local TICK = 0.1 -- AI step interval in seconds
local STAGGER = 2 -- each enemy thinks once every STAGGER ticks (every 0.2 s)
local FALL_MARGIN = 50 -- enemies below FallenPartsDestroyHeight + this are moved back to a spawn point

local EnemyService = {}

EnemyService.EnemyDied = Signal.new() -- (enemy: Enemy, killer: Player?, position: Vector3)
EnemyService.EnemyRemoved = Signal.new() -- (enemy: Enemy), once per enemy whether killed or destroyed

local enemyFolder = WorldFolders.Get(Constants.Folders.Enemies)
local pickupFolder = WorldFolders.Get(Constants.Folders.Pickups)

local active: { Enemy.Enemy } = {}
local byModel: { [Model]: Enemy.Enemy } = {}
local templates: { [string]: Model } = {}
local rng = Random.new()
local tickCount = 0

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Exclude

local function findRespawn(): Vector3
	return SpawnLocator.Find(PlayerService.GetAliveRoots(), mapParams)
end

local world: Enemy.World = {
	Targets = {},
	MapParams = mapParams,
	FallLimitY = workspace.FallenPartsDestroyHeight + FALL_MARGIN,
	FindRespawn = findRespawn,
}

-- Targets and the map-only raycast filter are rebuilt once per tick, not once per enemy.
local function refreshWorld()
	world.Targets = PlayerService.GetAliveRoots()
	local ignore = PlayerService.GetCharacters()
	table.insert(ignore, enemyFolder)
	table.insert(ignore, pickupFolder)
	mapParams.FilterDescendantsInstances = ignore
end

local function getTemplate(definition: Types.EnemyDefinition): Model
	local existing = templates[definition.Id]
	if existing then
		return existing
	end
	local built = ZombieRig.Build(definition)
	templates[definition.Id] = built
	return built
end

local function removeFromActive(enemy: Enemy.Enemy)
	local index = table.find(active, enemy)
	if index then
		active[index] = active[#active]
		active[#active] = nil
	end
end

local function onEnemyRemoved(enemy: Enemy.Enemy, killed: boolean)
	if byModel[enemy.Model] ~= enemy then
		return
	end
	byModel[enemy.Model] = nil
	removeFromActive(enemy)
	local position = enemy.Root.Position
	enemy:Destroy()

	if killed then
		-- The corpse is no longer an enemy; it only stays briefly for the death ragdoll.
		Debris:AddItem(enemy.Model, enemy.Definition.CorpseTime)
		EnemyService.EnemyDied:Fire(enemy, enemy.LastAttacker, position)
	end
	EnemyService.EnemyRemoved:Fire(enemy)
end

local function step()
	tickCount += 1
	if #active == 0 then
		return
	end
	refreshWorld()
	for index, enemy in active do
		if (index + tickCount) % STAGGER == 0 then
			enemy:Think(world)
		end
	end
end

function EnemyService.Spawn(enemyId: string, wave: Types.WaveDefinition): Enemy.Enemy
	local definition = EnemyDefinitions.Get(enemyId)
	local model = getTemplate(definition):Clone()
	refreshWorld()
	local position = SpawnLocator.Find(world.Targets, mapParams)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = enemyFolder

	local variance = definition.SpeedVariance
	local speed = wave.EnemySpeed * rng:NextNumber(1 - variance, 1 + variance)
	local enemy = Enemy.new(model, definition, wave.EnemyHealth, speed)
	-- Server-owned physics: no stutter from ownership hand-offs, and clients cannot steer enemies.
	pcall(function()
		enemy.Root:SetNetworkOwner(nil)
	end)

	byModel[model] = enemy
	table.insert(active, enemy)
	enemy.Removed:Connect(function(killed: boolean)
		onEnemyRemoved(enemy, killed)
	end)
	return enemy
end

-- The single entry point for damaging enemies.
function EnemyService.Damage(enemy: Enemy.Enemy, amount: number, source: Player?)
	enemy:TakeDamage(amount, source)
end

-- The enemy model (living or corpse) that contains this part, if any.
function EnemyService.GetModelFromPart(part: Instance): Model?
	local current: Instance? = part
	while current and current.Parent ~= enemyFolder do
		current = current.Parent
	end
	if current and current:IsA("Model") then
		return current
	end
	return nil
end

-- Damages the living enemy that owns this model. Returns false for corpses and unknown models.
function EnemyService.DamageModel(model: Model, amount: number, source: Player?): boolean
	local enemy = byModel[model]
	if not enemy or enemy.Health <= 0 then
		return false
	end
	EnemyService.Damage(enemy, amount, source)
	return true
end

function EnemyService.AliveCount(): number
	return #active
end

-- Removes every enemy and corpse without firing any events (used between rounds).
function EnemyService.ClearAll()
	local enemies = active
	active = {}
	table.clear(byModel)
	for _, enemy in enemies do
		enemy:Destroy()
	end
	enemyFolder:ClearAllChildren()
end

function EnemyService.Start()
	for _, definition in EnemyDefinitions.All() do
		getTemplate(definition)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0
		step()
	end)
end

return EnemyService
