--!strict
local Types = require(script.Parent.Parent.Parent.Types)

local Uzi: Types.WeaponDefinition = {
	Id = "Uzi",
	DisplayName = "Uzi",
	Damage = 14,
	FireInterval = 0.08,
	MaxAmmo = 250,
	UnlockCombo = 5,
	HandleLength = 1.9,
	Firing = { Type = "Hitscan", Range = 200, Pellets = 1, SpreadDegrees = 4, Pierce = 1 },
	Effects = { Color = Color3.fromRGB(255, 200, 90), Sound = "rbxassetid://7131411690" },
}

return Uzi
