--!strict
-- A soft green glow around the screen edges when the local player heals. Each Pulse() keeps it lit
-- for a moment, so steady regen keeps it on and a single crate pickup gives a short flash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.Shared.Util.Maid)

local GLOW_COLOR = Color3.fromRGB(80, 255, 110)
local EDGE_DEPTH = 0.12 -- how far the glow reaches in from each edge, as a fraction of the screen
local EDGE_TRANSPARENCY = 0.65 -- at the very edge; fades to invisible inward
local HOLD = 0.6 -- seconds the glow stays after the last heal
local FADE_IN = 0.25
local FADE_OUT = 0.6

local RegenOverlay = {}
RegenOverlay.__index = RegenOverlay

export type RegenOverlay = typeof(setmetatable({} :: {
	_group: CanvasGroup,
	_tween: Tween?,
	_lit: boolean,
	_token: number,
	_maid: Maid.Maid,
}, RegenOverlay))

-- One edge strip. `rotation` points the gradient inward (0 = left edge, 90 = top, 180 = right, 270 = bottom).
local function makeEdge(parent: Instance, position: UDim2, size: UDim2, rotation: number)
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = GLOW_COLOR
	edge.BorderSizePixel = 0
	edge.Position = position
	edge.Size = size
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new(EDGE_TRANSPARENCY, 1)
	gradient.Parent = edge
	edge.Parent = parent
end

function RegenOverlay.new(parent: Instance): RegenOverlay
	local maid = Maid.new()
	local group = maid:GiveTask(Instance.new("CanvasGroup"))
	group.Name = "RegenOverlay"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 1
	group.Visible = false

	makeEdge(group, UDim2.fromScale(0, 0), UDim2.fromScale(EDGE_DEPTH, 1), 0)
	makeEdge(group, UDim2.fromScale(1 - EDGE_DEPTH, 0), UDim2.fromScale(EDGE_DEPTH, 1), 180)
	makeEdge(group, UDim2.fromScale(0, 0), UDim2.fromScale(1, EDGE_DEPTH), 90)
	makeEdge(group, UDim2.fromScale(0, 1 - EDGE_DEPTH), UDim2.fromScale(1, EDGE_DEPTH), 270)
	group.Parent = parent

	local self = setmetatable({
		_group = group,
		_tween = nil :: Tween?,
		_lit = false,
		_token = 0,
		_maid = maid,
	}, RegenOverlay)
	maid:GiveTask(function()
		self._token += 1
		self:_stopTween()
	end)
	return self
end

function RegenOverlay._stopTween(self: RegenOverlay)
	local tween = self._tween
	if tween then
		tween:Cancel()
		self._tween = nil
	end
end

function RegenOverlay._fade(self: RegenOverlay, lit: boolean)
	self:_stopTween()
	self._lit = lit
	local group = self._group
	group.Visible = true
	local tween = TweenService:Create(
		group,
		TweenInfo.new(if lit then FADE_IN else FADE_OUT),
		{ GroupTransparency = if lit then 0 else 1 }
	)
	self._tween = tween
	tween.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not lit then
			group.Visible = false -- hidden CanvasGroups cost nothing to render
		end
	end)
	tween:Play()
end

-- Call on every heal. The glow fades in if needed and fades out HOLD seconds after the last call.
function RegenOverlay.Pulse(self: RegenOverlay)
	self._token += 1
	local token = self._token
	if not self._lit then
		self:_fade(true)
	end
	task.delay(HOLD, function()
		if self._token == token then
			self:_fade(false)
		end
	end)
end

function RegenOverlay.Destroy(self: RegenOverlay)
	self._maid:Destroy()
end

return RegenOverlay
