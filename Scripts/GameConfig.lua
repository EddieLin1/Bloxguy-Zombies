-- GameConfig (ModuleScript in ReplicatedStorage)
-- Tweak these numbers to balance the game. Shared by server and client.

local Config = {}

-- Weapons, in hotbar order. UnlockCombo = kill combo needed to unlock it.
-- Ammo = -1 means infinite. Pierce = how many zombies one bullet can pass through.
-- Sound = optional sound asset id, e.g. "rbxassetid://123456" (leave "" for none).
Config.Weapons = {
	{ Name = "Pistol",        Damage = 25,  FireRate = 0.30, Ammo = -1,  Pellets = 1, Spread = 1.0, Range = 250, Pierce = 1,  UnlockCombo = 0,  Auto = false, Color = Color3.fromRGB(255, 230, 120), Sound = "" },
	{ Name = "Uzi",           Damage = 14,  FireRate = 0.08, Ammo = 250, Pellets = 1, Spread = 4.0, Range = 200, Pierce = 1,  UnlockCombo = 5,  Auto = true,  Color = Color3.fromRGB(255, 200, 90),  Sound = "" },
	{ Name = "Shotgun",       Damage = 16,  FireRate = 0.75, Ammo = 50,  Pellets = 8, Spread = 9.0, Range = 80,  Pierce = 1,  UnlockCombo = 12, Auto = false, Color = Color3.fromRGB(255, 160, 80),  Sound = "" },
	{ Name = "Assault Rifle", Damage = 30,  FireRate = 0.11, Ammo = 200, Pellets = 1, Spread = 2.0, Range = 300, Pierce = 2,  UnlockCombo = 20, Auto = true,  Color = Color3.fromRGB(255, 120, 70),  Sound = "" },
	{ Name = "Railgun",       Damage = 150, FireRate = 1.20, Ammo = 25,  Pellets = 1, Spread = 0.0, Range = 400, Pierce = 15, UnlockCombo = 35, Auto = false, Color = Color3.fromRGB(120, 220, 255), Sound = "" },
}

Config.HeadshotMultiplier = 1.5

-- Combo / scoring
Config.ComboTimeout = 3        -- seconds you have to get the next kill to keep the combo
Config.PointsPerKill = 10      -- points per kill = PointsPerKill * current combo

-- Round flow (seconds)
Config.Intermission = 10
Config.WaveBreak = 6
Config.GameOverTime = 8

-- Zombies
Config.MaxZombiesAlive = 30
Config.ZombieDamage = 10
Config.ZombieAttackCooldown = 1
Config.ZombieAttackRange = 4.5
Config.SpawnDistanceMin = 50   -- used when there is no Workspace.ZombieSpawns folder
Config.SpawnDistanceMax = 90

-- Pickups dropped by zombies
Config.PickupDropChance = 0.12
Config.PickupHeal = 25
Config.PickupAmmoFraction = 0.5  -- refills this fraction of each weapon's max ammo

-- Wave scaling
function Config.Wave(n)
	return {
		Count = 6 + n * 4,
		Health = 60 + n * 15,
		Speed = math.min(9 + n * 0.7, 18),
		SpawnInterval = math.max(0.3, 1.2 - n * 0.06),
	}
end

return Config
