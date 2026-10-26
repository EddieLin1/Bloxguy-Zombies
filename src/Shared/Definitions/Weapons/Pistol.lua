--!strict
local Types = require(script.Parent.Parent.Parent.Types)

local Pistol: Types.WeaponDefinition = {
	Id = "Pistol",
	DisplayName = "Pistol",
	Damage = 25,
	FireInterval = 0.3,
	MaxAmmo = nil,
	UnlockCombo = 0,
	HandleLength = 1.55,
	Firing = { Type = "Hitscan", Range = 250, Pellets = 1, SpreadDegrees = 1, Pierce = 1 },
	Effects = { Color = Color3.fromRGB(255, 230, 120), Sound = "rbxassetid://4502821590" },
}

return Pistol
