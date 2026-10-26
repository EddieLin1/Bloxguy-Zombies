--!strict
-- Small green "+" crosses that rise and fade around a healing character. Billboards come from a pool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Pool = require(ReplicatedStorage.Shared.Util.Pool)

local CROSS_COLOR = Color3.fromRGB(90, 255, 120)
local CROSS_SIZE = 0.9 -- studs
local SPREAD_RADIUS = 1.6 -- studs around the root part
local HEIGHT_MIN, HEIGHT_MAX = -1.5, 1.5 -- studs relative to the root part
local RISE = 2 -- studs a cross floats up over its life
local LIFETIME = 0.9
local POOL_SIZE = 24

local riseInfo = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeInfo = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local HealCrosses = {}

local rng = Random.new()
local container: Folder? = nil

-- Billboards live in a folder in PlayerGui so they do not belong to (or replicate with) the character.
local function getContainer(): Folder
	local existing = container
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "HealCrosses"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	container = folder
	return folder
end

local pool = Pool.new(function(): Instance
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealCross"
	billboard.Size = UDim2.fromScale(CROSS_SIZE, CROSS_SIZE)
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "+"
	label.TextScaled = true
	label.TextColor3 = CROSS_COLOR
	label.TextStrokeColor3 = Color3.fromRGB(0, 70, 20)
	label.Parent = billboard
	return billboard
end, function(object: Instance)
	if object:IsA("BillboardGui") then
		-- Drop the reference so a pooled billboard does not keep an old character alive
		-- (the type definitions do not allow nil here, but the engine does)
		(object :: any).Adornee = nil
	end
	object.Parent = nil
end, POOL_SIZE)

function HealCrosses.Spawn(root: BasePart)
	local billboard = pool:Get() :: BillboardGui
	local label = billboard:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(0.4, SPREAD_RADIUS)
	local start = Vector3.new(math.cos(angle) * radius, rng:NextNumber(HEIGHT_MIN, HEIGHT_MAX), math.sin(angle) * radius)

	billboard.Adornee = root
	billboard.StudsOffsetWorldSpace = start
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.5
	billboard.Parent = getContainer()

	TweenService:Create(billboard, riseInfo, { StudsOffsetWorldSpace = start + Vector3.new(0, RISE, 0) }):Play()
	TweenService:Create(label, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(LIFETIME, function()
		pool:Release(billboard)
	end)
end

return HealCrosses
