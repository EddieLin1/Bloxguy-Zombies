--!strict
-- Crosshair in the exact screen centre. Its ScreenGui ignores the top bar inset so it lines up
-- with the camera ray the client aims along. Fixed pixel size on purpose: it should not scale.

local CROSSHAIR_SIZE = 22
local LINE_LENGTH = 8
local LINE_THICKNESS = 2
local LINE_COLOR = Color3.new(1, 1, 1)

local Crosshair = {}
Crosshair.__index = Crosshair

export type Crosshair = typeof(setmetatable({} :: { _frame: Frame }, Crosshair))

function Crosshair.new(parent: Instance): Crosshair
	local frame = Instance.new("Frame")
	frame.Name = "Crosshair"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
	frame.BackgroundTransparency = 1
	frame.Visible = false

	local lines = {
		{ UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH), UDim2.fromScale(0.5, 0) }, -- top
		{ UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH), UDim2.fromScale(0.5, 1) }, -- bottom
		{ UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS), UDim2.fromScale(0, 0.5) }, -- left
		{ UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS), UDim2.fromScale(1, 0.5) }, -- right
	}
	for _, spec in lines do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = spec[1]
		line.Position = spec[2]
		line.BackgroundColor3 = LINE_COLOR
		line.BorderSizePixel = 0
		line.Parent = frame
	end

	frame.Parent = parent
	return setmetatable({ _frame = frame }, Crosshair)
end

function Crosshair.SetVisible(self: Crosshair, visible: boolean)
	self._frame.Visible = visible
end

function Crosshair.Destroy(self: Crosshair)
	self._frame:Destroy()
end

return Crosshair
