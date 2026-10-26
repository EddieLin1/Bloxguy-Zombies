--!strict
-- A stream of blood pouring from a body part (a neck or limb stump, a popped-off head, a severed
-- limb). It sprays out, falls under gravity, follows the part as it moves, drips stains onto the
-- ground below, and tapers off over BloodPourTime. Everything is parented to the part, so it is
-- cleaned up with the corpse.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameRules = require(ReplicatedStorage.Shared.Definitions.GameRules)
local BloodStains = require(script.Parent.BloodStains)

local START_RATE = 45 -- particles per second at first; tweens down to 0
local DRIP_INTERVAL = 0.6 -- seconds between ground stains under a pour
local MIN_DRIP_RATE = 8 -- once the pour is this thin it stops staining
local LIFETIME_MAX = 0.9
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local COLOR = ColorSequence.new(Color3.fromRGB(150, 0, 0), Color3.fromRGB(80, 0, 0))

local BloodPour = {}

-- `localCFrame` is where on the part the blood comes out, with its +Y axis pointing the way it sprays.
function BloodPour.Start(part: BasePart, localCFrame: CFrame)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BloodPour"
	attachment.CFrame = localCFrame
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = TEXTURE
	emitter.Color = COLOR
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = START_RATE
	emitter.Lifetime = NumberRange.new(0.5, LIFETIME_MAX)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.4, 0)
	emitter.Drag = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.12) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = attachment

	local duration = GameRules.BloodPourTime
	TweenService:Create(emitter, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rate = 0 })
		:Play()
	Debris:AddItem(attachment, duration + LIFETIME_MAX)

	-- Drip stains under the pour while it is still flowing
	task.spawn(function()
		for _ = 1, math.floor(duration / DRIP_INTERVAL) do
			task.wait(DRIP_INTERVAL)
			if attachment.Parent == nil or emitter.Rate < MIN_DRIP_RATE then
				return
			end
			BloodStains.Paint(attachment.WorldPosition, "Drip")
		end
	end)
end

return BloodPour
