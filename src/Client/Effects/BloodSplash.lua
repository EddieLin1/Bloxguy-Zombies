--!strict
-- A burst of blood where a bullet hit a zombie, spraying back toward the shooter. Headshots get a
-- bigger, faster burst, and an exploding head gets a huge one in every direction. Emitters come
-- from a pool, so rapid fire does not create and destroy instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local BloodStains = require(script.Parent.BloodStains)

export type SplashStyle = "Body" | "Headshot" | "Explosion"

type Style = {
	Particles: number,
	Size: NumberSequence,
	Speed: NumberRange,
	Spread: Vector2,
}

local BODY: Style = {
	Particles = 8,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) }),
	Speed = NumberRange.new(6, 14),
	Spread = Vector2.new(35, 35),
}
local HEADSHOT: Style = {
	Particles = 22,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) }),
	Speed = NumberRange.new(10, 22),
	Spread = Vector2.new(55, 55),
}
local EXPLOSION: Style = {
	Particles = 45,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) }),
	Speed = NumberRange.new(12, 30),
	Spread = Vector2.new(180, 180), -- every direction
}
local STYLES: { [SplashStyle]: Style } = { Body = BODY, Headshot = HEADSHOT, Explosion = EXPLOSION }

local LIFETIME = 0.6 -- longest particle life; the emitter returns to the pool after this
local POOL_SIZE = 32
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local COLOR = ColorSequence.new(Color3.fromRGB(140, 0, 0), Color3.fromRGB(70, 0, 0))

local BloodSplash = {}

local pool = Pool.new(function(): Instance
	local part = Instance.new("Part")
	part.Name = "BloodSplash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Texture = TEXTURE
	emitter.Color = COLOR
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.3, LIFETIME)
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.3, 0)
	emitter.Drag = 3
	emitter.Parent = part
	return part
end, function(object: Instance)
	object.Parent = nil
end, POOL_SIZE)

-- `from` is where the shot came from; the spray points back toward it.
function BloodSplash.Play(position: Vector3, from: Vector3, styleName: SplashStyle)
	local style = STYLES[styleName]
	local part = pool:Get() :: Part
	local back = from - position
	part.CFrame = if back.Magnitude > 0.01 then CFrame.lookAt(position, from) else CFrame.new(position)
	part.Parent = workspace.CurrentCamera
	local emitter = part:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Size = style.Size
		emitter.Speed = style.Speed
		emitter.SpreadAngle = style.Spread
		emitter:Emit(style.Particles)
	end
	task.delay(LIFETIME, function()
		pool:Release(part)
	end)
	-- The spray lands: paint the ground below (an exploding head paints a bigger mess)
	BloodStains.Paint(position, if styleName == "Explosion" then "Burst" else "Splash")
end

return BloodSplash
