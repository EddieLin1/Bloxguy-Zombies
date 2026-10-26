--!strict
local Types = require(script.Parent.Parent.Parent.Types)

local Railgun: Types.WeaponDefinition = {
	Id = "Railgun",
	DisplayName = "Railgun",
	Damage = 150,
	FireInterval = 1.2,
	MaxAmmo = 25,
	UnlockCombo = 35,
	HandleLength = 2.95,
	Firing = { Type = "Hitscan", Range = 400, Pellets = 1, SpreadDegrees = 0, Pierce = 15 },
	Impact = { StoppingPower = 1, Knockback = 60, RagdollForce = 110 },
	Effects = { Color = Color3.fromRGB(120, 220, 255), Sound = "rbxassetid://104211574669495" },
}

return Railgun
