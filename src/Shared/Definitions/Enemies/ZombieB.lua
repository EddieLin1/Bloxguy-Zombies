--!strict
-- Zombie B: a mild flanker. It walks straight at you until it is within StartDistance, then makes
-- its attack run from about 45 degrees to one side (a gentler angle than the fast zombie's 90),
-- and charges in once it is close.
-- Same health and speed as Zombie A.
-- Health and speed come from the wave (Definitions/Waves); everything else is here.

local Types = require(script.Parent.Parent.Parent.Types)

local ZombieB: Types.EnemyDefinition = {
	Id = "ZombieB",
	Damage = 10,
	AttackCooldown = 1,
	AttackRange = 4.5,
	SpeedVariance = 0.15,
	CorpseTime = 30,
	DirectChaseDistance = 10,
	PathRecomputeInterval = 1.5,
	WaypointReachedDistance = 3,
	Agent = { Radius = 2, Height = 5 },
	Colors = {
		Skin = Color3.fromRGB(170, 170, 90), -- yellowish, for testing
		Shirt = Color3.fromRGB(150, 135, 55),
		Pants = Color3.fromRGB(75, 70, 40),
	},
	WalkAnimationId = "rbxassetid://180426354", -- classic R6 walk
	SpeedMultiplier = 1,
	Behaviour = "Flank",
	Flank = {
		StartDistance = 35,
		Angle = 45,
		EngageDistance = 14,
		GoalDistanceFactor = 0.75,
	},
}

return ZombieB
