--!strict
-- Health and speed come from the wave (Definitions/Waves); everything else is here.

local Types = require(script.Parent.Parent.Parent.Types)

local Zombie: Types.EnemyDefinition = {
	Id = "Zombie",
	Damage = 10,
	AttackCooldown = 1,
	AttackRange = 4.5,
	SpeedVariance = 0.15,
	CorpseTime = 3,
	DirectChaseDistance = 10,
	PathRecomputeInterval = 1.5,
	WaypointReachedDistance = 3,
	Agent = { Radius = 2, Height = 5, CanJump = true },
	Colors = {
		Skin = Color3.fromRGB(110, 160, 80),
		Shirt = Color3.fromRGB(95, 75, 55),
		Pants = Color3.fromRGB(50, 60, 90),
	},
	WalkAnimationId = "rbxassetid://180426354", -- classic R6 walk
}

return Zombie
