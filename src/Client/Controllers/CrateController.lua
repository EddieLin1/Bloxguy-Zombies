--!strict
-- Supply crate visuals: they float up and down, and in their last BlinkTime seconds they flash,
-- faster and faster until they disappear. Purely visual: this changes the local copy only, so the
-- server's pickup check and expiry are unaffected. One render loop animates every crate; crates are
-- found by the Pickup tag, and their ExpiresAt attribute says when the server will remove them.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Pickups = require(Shared.Definitions.Pickups)

local definition = Pickups.SupplyCrate

local HIDDEN_TRANSPARENCY = 0.85 -- how see-through a crate gets on the "off" beat of a flash

type CrateVisual = {
	Rest: CFrame, -- the position the server placed the crate at
	BobPhase: number, -- random offset so nearby crates do not bob in sync
	BlinkPhase: number, -- advances faster as the crate nears expiry
	Light: PointLight?,
}

local CrateController = {}

local crates: { [BasePart]: CrateVisual } = {}
local rng = Random.new()

local function onAdded(instance: Instance)
	if instance:IsA("BasePart") and not crates[instance] then
		crates[instance] = {
			Rest = instance.CFrame,
			BobPhase = rng:NextNumber(0, math.pi * 2),
			BlinkPhase = 0,
			Light = instance:FindFirstChildOfClass("PointLight"),
		}
	end
end

local function onRemoved(instance: Instance)
	if instance:IsA("BasePart") then
		crates[instance] = nil
	end
end

-- 0 before flashing starts, rising to 1 at the moment the crate disappears.
local function blinkProgress(part: BasePart, now: number): number
	local expiresAt = tonumber(part:GetAttribute(Constants.Attributes.ExpiresAt))
	if not expiresAt then
		return 0
	end
	local remaining = expiresAt - now
	return math.clamp(1 - remaining / definition.BlinkTime, 0, 1)
end

local function update(dt: number)
	if next(crates) == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	local bobAngle = os.clock() * definition.BobSpeed * math.pi * 2
	for part, visual in crates do
		local offset = math.sin(bobAngle + visual.BobPhase) * definition.BobHeight
		part.CFrame = visual.Rest + Vector3.new(0, offset, 0)

		local progress = blinkProgress(part, now)
		local visible = true
		if progress > 0 then
			-- Integrate the rate so speeding up stays smooth instead of jumping between frames
			local rate = definition.BlinkStartRate + (definition.BlinkEndRate - definition.BlinkStartRate) * progress
			visual.BlinkPhase = (visual.BlinkPhase + rate * dt) % 1
			visible = visual.BlinkPhase < 0.5
		end
		part.LocalTransparencyModifier = if visible then 0 else HIDDEN_TRANSPARENCY
		local light = visual.Light
		if light then
			light.Enabled = visible
		end
	end
end

function CrateController.Start()
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Pickup):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.Pickup):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(Constants.Tags.Pickup) do
		onAdded(instance)
	end
	RunService.RenderStepped:Connect(update)
end

return CrateController
