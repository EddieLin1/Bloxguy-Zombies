--!strict
-- One notification at a time (new weapon, refills, pickups). A new toast replaces the current one.

local FadingText = require(script.Parent.FadingText)
local Text = require(script.Parent.Text)

local HOLD_TIME = 2.5
local FADE_TIME = 0.5

local Toast = {}
Toast.__index = Toast

export type Toast = typeof(setmetatable({} :: {
	_label: TextLabel,
	_text: FadingText.FadingText,
}, Toast))

function Toast.new(parent: Instance): Toast
	local label = Text.Label({
		Name = "Toast",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.5, 0.05),
		MaxTextSize = 36,
	})
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	return setmetatable({ _label = label, _text = FadingText.new(label) }, Toast)
end

function Toast.Show(self: Toast, text: string, color: Color3)
	self._text:Show(text, color, HOLD_TIME, FADE_TIME)
end

function Toast.Destroy(self: Toast)
	self._text:Destroy()
	self._label:Destroy()
end

return Toast
