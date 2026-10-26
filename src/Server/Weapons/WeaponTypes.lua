--!strict
-- Types shared by GunController and its components.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

-- The slice of EnemyService that weapons may use. Damage always goes through it.
export type EnemyHitApi = {
	GetModelFromPart: (part: Instance) -> Model?,
	DamageModel: (model: Model, amount: number, source: Player?) -> boolean,
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
	Headshot: boolean, -- at least one ray damaged a living enemy's head
}

export type FiringComponent = {
	Fire: (self: any, origin: Vector3, direction: Vector3) -> FireResult,
	Destroy: (self: any) -> (),
}

export type FiringComponentClass = {
	new: (context: FiringContext, definition: Types.WeaponDefinition) -> FiringComponent,
}

return {}
