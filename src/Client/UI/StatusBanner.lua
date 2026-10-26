--!strict
-- Top-centre match status: wave number, zombies left, and the big state message.
-- Reads only replicated attributes on ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local FadingText = require(script.Parent.FadingText)
local Text = require(script.Parent.Text)

local States = Constants.GameStates
local Attributes = Constants.Attributes

local NORMAL_COLOR = Color3.new(1, 1, 1)
local GAME_OVER_COLOR = Color3.fromRGB(255, 70, 70)
local WAVE_BANNER_HOLD = 2.5
local WAVE_BANNER_FADE = 0.6

local StatusBanner = {}
StatusBanner.__index = StatusBanner

export type StatusBanner = typeof(setmetatable({} :: {
	_waveLabel: TextLabel,
	_remainingLabel: TextLabel,
	_message: FadingText.FadingText,
	_maid: Maid.Maid,
}, StatusBanner))

local function getNumber(name: string): number
	return tonumber(ReplicatedStorage:GetAttribute(name)) or 0
end

function StatusBanner.new(parent: Instance): StatusBanner
	local maid = Maid.new()
	local waveLabel = maid:GiveTask(Text.Label({
		Name = "Wave",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.01),
		Size = UDim2.fromScale(0.4, 0.055),
		MaxTextSize = 36,
	}))
	local remainingLabel = maid:GiveTask(Text.Label({
		Name = "ZombiesLeft",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.065),
		Size = UDim2.fromScale(0.4, 0.03),
		Font = Enum.Font.GothamBold,
		MaxTextSize = 22,
	}))
	local messageLabel = maid:GiveTask(Text.Label({
		Name = "Message",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromScale(0.7, 0.08),
		MaxTextSize = 56,
	}))

	local self = setmetatable({
		_waveLabel = waveLabel,
		_remainingLabel = remainingLabel,
		_message = maid:GiveTask(FadingText.new(messageLabel)),
		_maid = maid,
	}, StatusBanner)

	local function refreshCounters()
		self:_refreshCounters()
	end
	local function refreshAll()
		self:_refreshCounters()
		self:_refreshMessage()
	end
	maid:GiveTask(ReplicatedStorage:GetAttributeChangedSignal(Attributes.GameState):Connect(refreshAll))
	maid:GiveTask(ReplicatedStorage:GetAttributeChangedSignal(Attributes.Countdown):Connect(refreshAll))
	maid:GiveTask(ReplicatedStorage:GetAttributeChangedSignal(Attributes.Wave):Connect(refreshCounters))
	maid:GiveTask(ReplicatedStorage:GetAttributeChangedSignal(Attributes.EnemiesRemaining):Connect(refreshCounters))
	refreshAll()
	return self
end

function StatusBanner._refreshCounters(self: StatusBanner)
	local state = ReplicatedStorage:GetAttribute(Attributes.GameState)
	local inWave = state == States.WaveActive or state == States.WaveComplete
	self._waveLabel.Text = if inWave then `WAVE {getNumber(Attributes.Wave)}` else ""
	self._remainingLabel.Text = if state == States.WaveActive
		then `Zombies left: {getNumber(Attributes.EnemiesRemaining)}`
		else ""
end

function StatusBanner._refreshMessage(self: StatusBanner)
	local state = ReplicatedStorage:GetAttribute(Attributes.GameState)
	local wave = getNumber(Attributes.Wave)
	local countdown = getNumber(Attributes.Countdown)
	if state == States.Waiting then
		self._message:Show("Waiting for players...", NORMAL_COLOR)
	elseif state == States.Intermission then
		self._message:Show(`Game starts in {countdown}`, NORMAL_COLOR)
	elseif state == States.WaveActive then
		self._message:Show(`WAVE {wave}`, NORMAL_COLOR, WAVE_BANNER_HOLD, WAVE_BANNER_FADE)
	elseif state == States.WaveComplete then
		self._message:Show(`Wave {wave} cleared! Next wave in {countdown}`, NORMAL_COLOR)
	elseif state == States.GameOver then
		self._message:Show(`GAME OVER  -  You reached wave {wave}`, GAME_OVER_COLOR)
	else
		self._message:Show("", NORMAL_COLOR)
	end
end

function StatusBanner.Destroy(self: StatusBanner)
	self._maid:Destroy()
end

return StatusBanner
