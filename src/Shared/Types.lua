--!strict
-- Shapes of the data modules in Definitions/. Strict mode checks every definition against these.

export type FiringConfig = {
	Type: string, -- key into the server's Firing component registry
	Range: number, -- studs
	Pellets: number, -- rays per shot
	SpreadDegrees: number, -- random cone per pellet
	Pierce: number, -- living enemies one ray can pass through
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
	Agent: { Radius: number, Height: number, CanJump: boolean },
	Colors: { Skin: Color3, Shirt: Color3, Pants: Color3 },
	WalkAnimationId: string,
}

export type WaveDefinition = {
	Number: number,
	EnemyId: string,
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
	Lifetime: number,
	CollectRadius: number,
	HoverHeight: number, -- studs from the ground to the crate's centre
	BobHeight: number, -- studs the crate floats up and down (client-side visual)
	BobSpeed: number, -- bobs per second
	Size: number,
	Color: Color3,
	LightColor: Color3,
}

return {}
