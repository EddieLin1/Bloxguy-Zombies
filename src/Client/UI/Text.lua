--!strict
-- The shared look of HUD text. Sizes are Scale-based; UITextSizeConstraint keeps text readable
-- on phones without becoming huge on large monitors.

local DEFAULT_FONT = Enum.Font.GothamBlack
local DEFAULT_MAX_TEXT_SIZE = 48
local MIN_TEXT_SIZE = 12
local STROKE_TRANSPARENCY = 0.4

export type LabelProps = {
	Name: string,
	Parent: Instance,
	Position: UDim2,
	Size: UDim2,
	AnchorPoint: Vector2?,
	Text: string?,
	Font: Enum.Font?,
	TextColor3: Color3?,
	TextXAlignment: Enum.TextXAlignment?,
	MaxTextSize: number?,
}

local Text = {}

Text.STROKE_TRANSPARENCY = STROKE_TRANSPARENCY

function Text.Label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name
	label.BackgroundTransparency = 1
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.Position = props.Position
	label.Size = props.Size
	label.Font = props.Font or DEFAULT_FONT
	label.Text = props.Text or ""
	label.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = STROKE_TRANSPARENCY
	label.TextScaled = true
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = MIN_TEXT_SIZE
	constraint.MaxTextSize = props.MaxTextSize or DEFAULT_MAX_TEXT_SIZE
	constraint.Parent = label

	label.Parent = props.Parent
	return label
end

return Text
