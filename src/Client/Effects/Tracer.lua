--!strict
-- Short-lived neon bullet tracers, drawn from a pool so rapid fire does not churn Parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Pool = require(ReplicatedStorage.Shared.Util.Pool)

local WIDTH = 0.12
local START_TRANSPARENCY = 0.2
local FADE_TIME = 0.1
local LIFETIME = 0.12
local MIN_LENGTH = 0.1
local POOL_SIZE = 64

local fadeInfo = TweenInfo.new(FADE_TIME)

local Tracer = {}

local pool = Pool.new(function(): Instance
	local part = Instance.new("Part")
	part.Name = "Tracer"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end, function(object: Instance)
	object.Parent = nil
end, POOL_SIZE)

-- Tracers live under the camera, which the aim raycast ignores.
function Tracer.Draw(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < MIN_LENGTH then
		return
	end
	local part = pool:Get() :: Part
	part.Color = color
	part.Size = Vector3.new(WIDTH, WIDTH, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Transparency = START_TRANSPARENCY
	part.Parent = workspace.CurrentCamera
	TweenService:Create(part, fadeInfo, { Transparency = 1 }):Play()
	task.delay(LIFETIME, function()
		pool:Release(part)
	end)
end

return Tracer
