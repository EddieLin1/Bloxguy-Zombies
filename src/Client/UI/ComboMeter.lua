--!strict
-- Kill combo counter, a bar that drains until the combo starts counting down, and the next weapon unlock.
-- The bar is tweened once per change instead of being updated every frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)
local WeaponDefinitions = require(Shared.Definitions.Weapons)
local Text = require(script.Parent.Text)

local Attributes = Constants.Attributes

local COMBO_COLOR = Color3.fromRGB(255, 210, 60)
local DECAY_COLOR = Color3.fromRGB(255, 90, 70) -- combo counting down
local BAR_BACK_COLOR = Color3.fromRGB(30, 30, 30)
local MIN_SIZE = Vector2.new(160, 60)
local MAX_SIZE = Vector2.new(320, 110)

local ComboMeter = {}
ComboMeter.__index = ComboMeter

export type ComboMeter = typeof(setmetatable({} :: {
	_frame: Frame,
	_comboLabel: TextLabel,
	_barFill: Frame,
	_nextLabel: TextLabel,
	_tween: Tween?,
	_maid: Maid.Maid,
}, ComboMeter))

local function nextUnlock(combo: number): Types.WeaponDefinition?
	for _, definition in WeaponDefinitions.All() do
		if definition.UnlockCombo > combo then
			return definition
		end
	end
	return nil
end

function ComboMeter.new(parent: Instance): ComboMeter
	local maid = Maid.new()

	local frame = maid:GiveTask(Instance.new("Frame"))
	frame.Name = "Combo"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromScale(0.015, 0.11)
	frame.Size = UDim2.fromScale(0.2, 0.09)
	frame.Visible = false
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = MIN_SIZE
	sizeConstraint.MaxSize = MAX_SIZE
	sizeConstraint.Parent = frame
	frame.Parent = parent

	local comboLabel = Text.Label({
		Name = "Count",
		Parent = frame,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.55),
		TextColor3 = COMBO_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 40,
	})

	local barBack = Instance.new("Frame")
	barBack.Name = "Bar"
	barBack.BackgroundColor3 = BAR_BACK_COLOR
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromScale(0, 0.62)
	barBack.Size = UDim2.fromScale(1, 0.1)
	barBack.Parent = frame
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.BackgroundColor3 = COMBO_COLOR
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = barBack

	local nextLabel = Text.Label({
		Name = "Next",
		Parent = frame,
		Position = UDim2.fromScale(0, 0.77),
		Size = UDim2.fromScale(1, 0.23),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
	})

	local self = setmetatable({
		_frame = frame,
		_comboLabel = comboLabel,
		_barFill = barFill,
		_nextLabel = nextLabel,
		_tween = nil :: Tween?,
		_maid = maid,
	}, ComboMeter)

	local player = Players.LocalPlayer
	local function refresh()
		self:_refresh(player)
	end
	maid:GiveTask(player:GetAttributeChangedSignal(Attributes.Combo):Connect(refresh))
	maid:GiveTask(player:GetAttributeChangedSignal(Attributes.ComboExpire):Connect(refresh))
	maid:GiveTask(function()
		self:_stopTween()
	end)
	refresh()
	return self
end

function ComboMeter._stopTween(self: ComboMeter)
	local tween = self._tween
	if tween then
		tween:Cancel()
		self._tween = nil
	end
end

function ComboMeter._refresh(self: ComboMeter, player: Player)
	self:_stopTween()
	local combo = tonumber(player:GetAttribute(Attributes.Combo)) or 0
	local expire = tonumber(player:GetAttribute(Attributes.ComboExpire)) or 0
	local remaining = expire - workspace:GetServerTimeNow()
	if combo <= 0 then
		self._frame.Visible = false
		return
	end

	local counting = remaining <= 0
	self._frame.Visible = true
	self._comboLabel.Text = `x{combo} COMBO`
	self._comboLabel.TextColor3 = if counting then DECAY_COLOR else COMBO_COLOR
	local nextWeapon = nextUnlock(combo)
	self._nextLabel.Text = if nextWeapon
		then `Next: {nextWeapon.DisplayName} at x{nextWeapon.UnlockCombo}`
		else ""

	-- Counting down: the server lowers Combo step by step; the bar stays empty until the next kill
	if counting then
		self._barFill.Size = UDim2.fromScale(0, 1)
		return
	end
	self._barFill.Size = UDim2.fromScale(math.clamp(remaining / GameRules.ComboTimeout, 0, 1), 1)
	local tween = TweenService:Create(
		self._barFill,
		TweenInfo.new(remaining, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	self._tween = tween
	tween:Play()
end

function ComboMeter.Destroy(self: ComboMeter)
	self._maid:Destroy()
end

return ComboMeter
