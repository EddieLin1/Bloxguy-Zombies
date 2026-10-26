--!strict
local Types = require(script.Parent.Parent.Parent.Types)

local Shotgun: Types.WeaponDefinition = {
	Id = "Shotgun",
	DisplayName = "Shotgun",
	Damage = 16,
	FireInterval = 0.75,
	MaxAmmo = 50,
	UnlockCombo = 12,
	HandleLength = 2.25,
	Firing = { Type = "Hitscan", Range = 80, Pellets = 8, SpreadDegrees = 9, Pierce = 1 },
	Impact = { StoppingPower = 0.9, Knockback = 14, RagdollForce = 70 },
	Effects = { Color = Color3.fromRGB(255, 160, 80), Sound = "rbxassetid://132711300701696" },
}

return Shotgun
