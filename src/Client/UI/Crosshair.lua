--!strict
-- Crosshair in the exact screen centre. Its ScreenGui ignores the top bar inset so it lines up
-- with the camera ray the client aims along. Fixed pixel size on purpose: it should not scale.
-- On a headshot it flashes: briefly bigger, red, with a small fan of 3 yellow spikes in each diagonal.

local TweenService = game:GetService("TweenService")

local CROSSHAIR_SIZE = 22
local LINE_LENGTH = 8
local LINE_THICKNESS = 2
local LINE_COLOR = Color3.new(1, 1, 1)

local HEADSHOT_COLOR = Color3.fromRGB(255, 80, 70)
local SPIKE_COLOR = Color3.fromRGB(255, 215, 70)
local SPIKE_TRANSPARENCY = 0.25 -- spikes never show fully opaque
local SPIKE_THICKNESS = 1
local SPIKE_INNER_RADIUS = 10 -- pixels from the centre to where each spike starts
local SPIKE_FAN = 18 -- degrees between the middle spike and each side spike
local MIDDLE_SPIKE_LENGTH = 6
local SIDE_SPIKE_LENGTH = 3
local QUADRANT_ANGLES = { 45, 135, 225, 315 } -- degrees clockwise from straight up
local FLASH_SCALE = 1.15
local FLASH_HOLD = 0.05 -- seconds at full flash
local FLASH_RECOVER = 0.15 -- seconds back to normal

local recoverInfo = TweenInfo.new(FLASH_RECOVER, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Crosshair = {}
Crosshair.__index = Crosshair

export type Crosshair = typeof(setmetatable({} :: {
	_frame: Frame,
	_scale: UIScale,
	_lines: { Frame },
	_spikes: { Frame },
	_tweens: { Tween },
	_token: number,
}, Crosshair))

local function makeBar(parent: Instance, size: UDim2, position: UDim2, color: Color3, rotation: number): Frame
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = size
	bar.Position = position
	bar.Rotation = rotation
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = parent
	return bar
end

function Crosshair.new(parent: Instance): Crosshair
	local frame = Instance.new("Frame")
	frame.Name = "Crosshair"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local vertical = UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH)
	local horizontal = UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS)
	local lines = {
		makeBar(frame, vertical, UDim2.fromScale(0.5, 0), LINE_COLOR, 0), -- top
		makeBar(frame, vertical, UDim2.fromScale(0.5, 1), LINE_COLOR, 0), -- bottom
		makeBar(frame, horizontal, UDim2.fromScale(0, 0.5), LINE_COLOR, 0), -- left
		makeBar(frame, horizontal, UDim2.fromScale(1, 0.5), LINE_COLOR, 0), -- right
	}

	-- A fan of 3 spikes pointing outward in each diagonal, hidden until a headshot
	local spikes = {}
	for _, quadrant in QUADRANT_ANGLES do
		for _, spec in { { -SPIKE_FAN, SIDE_SPIKE_LENGTH }, { 0, MIDDLE_SPIKE_LENGTH }, { SPIKE_FAN, SIDE_SPIKE_LENGTH } } do
			local angle = quadrant + spec[1]
			local length = spec[2]
			local radians = math.rad(angle)
			local distance = SPIKE_INNER_RADIUS + length / 2 -- to the spike's centre
			local position = UDim2.new(0.5, math.sin(radians) * distance, 0.5, -math.cos(radians) * distance)
			local spike = makeBar(frame, UDim2.fromOffset(SPIKE_THICKNESS, length), position, SPIKE_COLOR, angle)
			spike.BackgroundTransparency = 1
			table.insert(spikes, spike)
		end
	end

	frame.Parent = parent
	return setmetatable({
		_frame = frame,
		_scale = scale,
		_lines = lines,
		_spikes = spikes,
		_tweens = {},
		_token = 0,
	}, Crosshair)
end

function Crosshair._stopTweens(self: Crosshair)
	for _, tween in self._tweens do
		tween:Cancel()
	end
	table.clear(self._tweens)
end

function Crosshair._tween(self: Crosshair, object: Instance, goal: { [string]: any })
	local tween = TweenService:Create(object, recoverInfo, goal)
	table.insert(self._tweens, tween)
	tween:Play()
end

function Crosshair.SetVisible(self: Crosshair, visible: boolean)
	self._frame.Visible = visible
end

function Crosshair.FlashHeadshot(self: Crosshair)
	self._token += 1
	local token = self._token
	self:_stopTweens()
	self._scale.Scale = FLASH_SCALE
	for _, line in self._lines do
		line.BackgroundColor3 = HEADSHOT_COLOR
	end
	for _, spike in self._spikes do
		spike.BackgroundTransparency = SPIKE_TRANSPARENCY
	end

	task.delay(FLASH_HOLD, function()
		if self._token ~= token then
			return -- a newer headshot restarted the flash
		end
		self:_tween(self._scale, { Scale = 1 })
		for _, line in self._lines do
			self:_tween(line, { BackgroundColor3 = LINE_COLOR })
		end
		for _, spike in self._spikes do
			self:_tween(spike, { BackgroundTransparency = 1 })
		end
	end)
end

function Crosshair.Destroy(self: Crosshair)
	self._token += 1
	self:_stopTweens()
	self._frame:Destroy()
end

return Crosshair
