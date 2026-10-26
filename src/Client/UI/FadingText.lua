--!strict
-- A label that shows a message and can fade it out after a while. A newer message cancels a pending fade.

local TweenService = game:GetService("TweenService")

local Text = require(script.Parent.Text)

local DEFAULT_FADE_TIME = 0.5

local FadingText = {}
FadingText.__index = FadingText

export type FadingText = typeof(setmetatable({} :: {
	Label: TextLabel,
	_token: number,
	_tween: Tween?,
}, FadingText))

function FadingText.new(label: TextLabel): FadingText
	return setmetatable({ Label = label, _token = 0, _tween = nil :: Tween? }, FadingText)
end

-- With holdSeconds the text fades after that long; without it the text stays until the next Show.
function FadingText.Show(self: FadingText, text: string, color: Color3, holdSeconds: number?, fadeSeconds: number?)
	self:_cancel()
	local token = self._token
	local label = self.Label
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = Text.STROKE_TRANSPARENCY
	if not holdSeconds then
		return
	end
	task.delay(holdSeconds, function()
		if self._token ~= token then
			return
		end
		local tween = TweenService:Create(
			label,
			TweenInfo.new(fadeSeconds or DEFAULT_FADE_TIME),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		self._tween = tween
		tween:Play()
	end)
end

function FadingText._cancel(self: FadingText)
	self._token += 1
	local tween = self._tween
	if tween then
		tween:Cancel()
		self._tween = nil
	end
end

function FadingText.Destroy(self: FadingText)
	self:_cancel()
end

return FadingText
