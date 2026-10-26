--!strict
-- Pickups dropped by zombies.

local Types = require(script.Parent.Parent.Types)

local SupplyCrate: Types.PickupDefinition = {
	Id = "SupplyCrate",
	DropChance = 0.12,
	Heal = 25,
	AmmoFraction = 0.5,
	Lifetime = 8,
	BlinkTime = 3, -- flashing starts 5 s after it drops
	BlinkStartRate = 2,
	BlinkEndRate = 10,
	CollectRadius = 4,
	HoverHeight = 2.5,
	BobHeight = 0.4,
	BobSpeed = 0.6,
	Size = 2,
	Color = Color3.fromRGB(150, 110, 60),
	LightColor = Color3.fromRGB(120, 255, 120),
}

return {
	SupplyCrate = SupplyCrate,
}
