--!strict
-- Endless waves. Every number is a formula of the wave number, so all difficulty balancing happens here.

local Types = require(script.Parent.Parent.Types)

local ENEMY_ID = "Zombie"

local BASE_COUNT = 6
local COUNT_PER_WAVE = 4
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
		EnemyId = ENEMY_ID,
		Count = BASE_COUNT + number * COUNT_PER_WAVE,
		EnemyHealth = BASE_HEALTH + number * HEALTH_PER_WAVE,
		EnemySpeed = math.min(BASE_SPEED + number * SPEED_PER_WAVE, MAX_SPEED),
		SpawnInterval = math.max(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - number * SPAWN_INTERVAL_PER_WAVE),
	}
end

return Waves
