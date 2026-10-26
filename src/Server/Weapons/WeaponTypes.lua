--!strict
-- Types shared by GunController and its components.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

-- One bullet striking a zombie: where, which way, which body part, and the weapon's impact stats.
export type Hit = {
	Position: Vector3,
	Direction: Vector3,
	Part: BasePart,
	Impact: Types.ImpactConfig,
}

-- The slice of EnemyService that weapons may use. Damage always goes through it.
export type EnemyHitApi = {
	GetModelFromPart: (part: Instance) -> Model?,
	DamageModel: (model: Model, amount: number, source: Player?, hit: Hit?) -> boolean,
}

-- Everything a component needs, handed over by WeaponService so components never read global state.
export type FiringContext = {
	Owner: Player,
	Enemies: EnemyHitApi,
	HeadshotMultiplier: number,
	GetIgnoreList: () -> { Instance },
}

export type FireResult = {
	Endpoints: { Vector3 }, -- where each ray ended, for client tracers
	Hits: { Vector3 }, -- where rays damaged living enemies (body), for client blood effects
	HeadHits: { Vector3 }, -- where rays damaged living enemies' heads; non-empty = headshot
}

export type FiringComponent = {
	Fire: (self: any, origin: Vector3, direction: Vector3) -> FireResult,
	Destroy: (self: any) -> (),
}

export type FiringComponentClass = {
	new: (context: FiringContext, definition: Types.WeaponDefinition) -> FiringComponent,
}

return {}
