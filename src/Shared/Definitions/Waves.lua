--!strict
-- Endless waves. Every number is a formula of the wave number, so all difficulty balancing happens here.

local Types = require(script.Parent.Parent.Types)

-- Which zombies a wave is made of. Weights are relative: Zombie A 3, Zombie B 1, fast zombie 1 means
-- each of the other two spawns a third as often as Zombie A (on average 3 in 5 spawns are Zombie A).
local ENEMY_MIX: { Types.WaveEnemy } = {
	{ Id = "Zombie", Weight = 3 },
	{ Id = "ZombieB", Weight = 1 },
	{ Id = "FastZombie", Weight = 1 },
}

local BASE_COUNT = 30 -- zombies in wave 1
local COUNT_PER_WAVE = 15 -- extra zombies each wave after that
local BASE_HEALTH = 60
local HEALTH_PER_WAVE = 15
local BASE_SPEED = 9
local SPEED_PER_WAVE = 0.7
local MAX_SPEED = 18
local BASE_SPAWN_INTERVAL = 1.2
local SPAWN_INTERVAL_PER_WAVE = 0.06
local MIN_SPAWN_INTERVAL = 0.3

local Waves = {}

function Waves.Get(number: number): Types.WaveDefinition
	return {
		Number = number,
		Enemies = ENEMY_MIX,
		Count = BASE_COUNT + (number - 1) * COUNT_PER_WAVE,
		EnemyHealth = BASE_HEALTH + number * HEALTH_PER_WAVE,
		EnemySpeed = math.min(BASE_SPEED + number * SPEED_PER_WAVE, MAX_SPEED),
		SpawnInterval = math.max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - number * SPAWN_INTERVAL_PER_WAVE),
	}
end

-- Picks which enemy to spawn next, weighted by the wave's mix.
function Waves.PickEnemyId(wave: Types.WaveDefinition, rng: Random): string
	local total = 0
	for _, entry in wave.Enemies do
		total += entry.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in wave.Enemies do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Id
		end
	end
	return wave.Enemies[#wave.Enemies].Id
end

return Waves
