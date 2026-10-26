--!strict
-- Fast zombie: twice as fast as Zombie A, and the widest flanker. It walks straight at you until it
-- is within StartDistance, then makes its attack run from 90 degrees (straight from the side),
-- and charges in once it is close.
-- Same health as Zombie A.
-- Health and speed come from the wave (Definitions/Waves); everything else is here.

local Types = require(script.Parent.Parent.Parent.Types)

local FastZombie: Types.EnemyDefinition = {
	Id = "FastZombie",
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
		Skin = Color3.fromRGB(165, 105, 85), -- reddish, for testing
		Shirt = Color3.fromRGB(140, 40, 40),
		Pants = Color3.fromRGB(70, 30, 30),
	},
	WalkAnimationId = "rbxassetid://180426354", -- classic R6 walk
	SpeedMultiplier = 2,
	Behaviour = "Flank",
	Flank = {
		StartDistance = 40,
		Angle = 90,
		EngageDistance = 14,
		GoalDistanceFactor = 0.75,
	},
}

return FastZombie
