--!strict
-- Top-left points and kills, read from the local player's replicated attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local Text = require(script.Parent.Text)

local Attributes = Constants.Attributes

local StatsPanel = {}
StatsPanel.__index = StatsPanel

export type StatsPanel = typeof(setmetatable({} :: {
	_pointsLabel: TextLabel,
	_killsLabel: TextLabel,
	_maid: Maid.Maid,
}, StatsPanel))

function StatsPanel.new(parent: Instance): StatsPanel
	local maid = Maid.new()
	local self = setmetatable({
		_pointsLabel = maid:GiveTask(Text.Label({
			Name = "Points",
			Parent = parent,
			Position = UDim2.fromScale(0.015, 0.02),
			Size = UDim2.fromScale(0.25, 0.045),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 32,
		})),
		_killsLabel = maid:GiveTask(Text.Label({
			Name = "Kills",
			Parent = parent,
			Position = UDim2.fromScale(0.015, 0.068),
			Size = UDim2.fromScale(0.25, 0.03),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
		})),
		_maid = maid,
	}, StatsPanel)

	local player = Players.LocalPlayer
	local function refresh()
		self:_refresh(player)
	end
	maid:GiveTask(player:GetAttributeChangedSignal(Attributes.Points):Connect(refresh))
	maid:GiveTask(player:GetAttributeChangedSignal(Attributes.Kills):Connect(refresh))
	refresh()
	return self
end

function StatsPanel._refresh(self: StatsPanel, player: Player)
	self._pointsLabel.Text = `{tonumber(player:GetAttribute(Attributes.Points)) or 0} pts`
	self._killsLabel.Text = `Kills: {tonumber(player:GetAttribute(Attributes.Kills)) or 0}`
end

function StatsPanel.Destroy(self: StatsPanel)
	self._maid:Destroy()
end

return StatsPanel
