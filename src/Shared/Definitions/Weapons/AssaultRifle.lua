--!strict
local Types = require(script.Parent.Parent.Parent.Types)

local AssaultRifle: Types.WeaponDefinition = {
	Id = "AssaultRifle",
	DisplayName = "Assault Rifle",
	Damage = 30,
	FireInterval = 0.11,
	MaxAmmo = 200,
	UnlockCombo = 20,
	HandleLength = 2.6,
	Firing = { Type = "Hitscan", Range = 300, Pellets = 1, SpreadDegrees = 2, Pierce = 2 },
	Effects = { Color = Color3.fromRGB(255, 120, 70), Sound = "rbxassetid://113879008765178" },
}

return AssaultRifle
