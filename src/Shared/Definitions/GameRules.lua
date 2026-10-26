--!strict
-- Match-wide tunables. Weapon, enemy, wave and pickup numbers live in their own definition modules.

return {
	-- Round flow (seconds)
	Intermission = 10,
	WaveBreak = 6,
	GameOverTime = 8,
	MatchStartDelay = 2, -- after everyone spawns, before wave 1

	-- Enemies
	MaxEnemiesAlive = 30,
	SpawnDistanceMin = 50, -- ring around a player, used when the map has no spawn points
	SpawnDistanceMax = 90,

	-- Player health
	HealthRegenDelay = 5, -- seconds without taking damage before healing starts
	HealthRegenPerSecond = 5,

	-- Combat and scoring
	HeadshotMultiplier = 1.5,
	HeadshotSound = "rbxassetid://128633263668964", -- played only to the shooter on a headshot
	HeadshotSoundVolume = 1,
	ComboTimeout = 3, -- seconds after a kill before the combo starts counting down
	ComboDecayInterval = 0.15, -- once counting down, seconds per combo point lost
	PointsPerKill = 10, -- points per kill = PointsPerKill * current combo
}
