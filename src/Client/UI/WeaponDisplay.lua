--!strict
-- Bottom-centre equipped weapon name and ammo (from the Tool's server-set Ammo attribute).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)
local Text = require(script.Parent.Text)

local NORMAL_COLOR = Color3.new(1, 1, 1)
local EMPTY_COLOR = Color3.fromRGB(255, 80, 80)
local INFINITE_SYMBOL = "∞"

local WeaponDisplay = {}
WeaponDisplay.__index = WeaponDisplay

export type WeaponDisplay = typeof(setmetatable({} :: {
	_label: TextLabel,
	_toolMaid: Maid.Maid,
	_maid: Maid.Maid,
}, WeaponDisplay))

function WeaponDisplay.new(parent: Instance): WeaponDisplay
	local maid = Maid.new()
	return setmetatable({
		_label = maid:GiveTask(Text.Label({
			Name = "Weapon",
			Parent = parent,
			AnchorPoint = Vector2.new(0.5, 1),
			-- Sits above the Roblox hotbar
			Position = UDim2.fromScale(0.5, 0.87),
			Size = UDim2.fromScale(0.4, 0.045),
			MaxTextSize = 34,
		})),
		_toolMaid = maid:GiveTask(Maid.new()),
		_maid = maid,
	}, WeaponDisplay)
end

function WeaponDisplay.SetWeapon(self: WeaponDisplay, tool: Tool?, definition: Types.WeaponDefinition?)
	self._toolMaid:Destroy()
	if not tool or not definition then
		self._label.Text = ""
		return
	end
	local activeTool: Tool = tool
	local activeDefinition: Types.WeaponDefinition = definition

	local function refresh()
		local ammo = tonumber(activeTool:GetAttribute(Constants.Attributes.Ammo)) or 0
		local ammoText = if ammo == Constants.INFINITE_AMMO then INFINITE_SYMBOL else tostring(ammo)
		self._label.Text = `{activeDefinition.DisplayName}   {ammoText}`
		self._label.TextColor3 = if ammo == 0 then EMPTY_COLOR else NORMAL_COLOR
	end
	self._toolMaid:GiveTask(activeTool:GetAttributeChangedSignal(Constants.Attributes.Ammo):Connect(refresh))
	refresh()
end

function WeaponDisplay.Destroy(self: WeaponDisplay)
	self._maid:Destroy()
end

return WeaponDisplay
