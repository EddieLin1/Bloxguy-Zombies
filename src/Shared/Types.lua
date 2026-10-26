--!strict
-- Shapes of the data modules in Definitions/. Strict mode checks every definition against these.

export type FiringConfig = {
	Type: string, -- key into the server's Firing component registry
	Range: number, -- studs
	Pellets: number, -- rays per shot
	SpreadDegrees: number, -- random cone per pellet
	Pierce: number, -- living enemies one ray can pass through
}

-- What one bullet does to a zombie besides damage (per pellet for shotguns).
export type ImpactConfig = {
	StoppingPower: number, -- 0..1: fraction of walk speed the zombie loses while staggered (1 = stops)
	Knockback: number, -- studs/s shove away from the shooter; 0 = none
	RagdollForce: number, -- studs/s push on the body part hit by the killing shot
}

export type WeaponEffects = {
	Color: Color3, -- tracer and notification colour
	Sound: string?, -- optional sound asset id, e.g. "rbxassetid://123456"
}

export type WeaponDefinition = {
	Id: string,
	DisplayName: string,
	Damage: number,
	FireInterval: number, -- seconds between shots
	MaxAmmo: number?, -- nil means infinite
	UnlockCombo: number, -- kill combo that unlocks it; 0 = starting weapon
	HandleLength: number, -- length of the generated gun model
	Firing: FiringConfig,
	Impact: ImpactConfig,
	Effects: WeaponEffects,
}

export type EnemyDefinition = {
	Id: string,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
	SpeedVariance: number, -- each spawn's speed is scaled by a random 1 +/- this
	CorpseTime: number, -- seconds a body stays before it is removed
	DirectChaseDistance: number, -- always walk straight at the target inside this distance
	PathRecomputeInterval: number,
	WaypointReachedDistance: number,
	Agent: { Radius: number, Height: number }, -- size used for pathfinding (zombies never path with jumps)
	Colors: { Skin: Color3, Shirt: Color3, Pants: Color3 },
	WalkAnimationId: string,
	SpeedMultiplier: number, -- on top of the wave's speed
	Behaviour: EnemyBehaviour,
	Flank: FlankConfig?, -- required when Behaviour is "Flank"
}

-- "Direct": walk straight at the nearest player. "Flank": swing out to one side and arc in.
export type EnemyBehaviour = "Direct" | "Flank"

export type FlankConfig = {
	StartDistance: number, -- walks straight at you until this close, then starts its attack run
	Angle: number, -- degrees off to the side the attack run comes at you from (90 = straight from the side)
	EngageDistance: number, -- inside this distance it stops arcing and charges straight in
	GoalDistanceFactor: number, -- 0..1: how far along the arc it aims each step (lower = tighter curve)
}

export type WaveEnemy = {
	Id: string,
	Weight: number, -- relative spawn chance within the wave
}

export type WaveDefinition = {
	Number: number,
	Enemies: { WaveEnemy },
	Count: number,
	EnemyHealth: number,
	EnemySpeed: number,
	SpawnInterval: number,
}

export type PickupDefinition = {
	Id: string,
	DropChance: number, -- per zombie kill
	Heal: number,
	AmmoFraction: number, -- refills this fraction of each weapon's max ammo
	Lifetime: number, -- seconds before an untouched crate disappears
	BlinkTime: number, -- seconds before disappearing that the crate starts flashing
	BlinkStartRate: number, -- flashes per second when flashing starts
	BlinkEndRate: number, -- flashes per second just before it disappears
	CollectRadius: number,
	HoverHeight: number, -- studs from the ground to the crate's centre
	BobHeight: number, -- studs the crate floats up and down (client-side visual)
	BobSpeed: number, -- bobs per second
	Size: number,
	Color: Color3,
	LightColor: Color3,
}

return {}
