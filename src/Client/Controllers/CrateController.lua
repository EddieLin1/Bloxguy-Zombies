--!strict
-- Makes supply crates float up and down. Purely visual: the server places each crate at its resting
-- height, and this moves the local copy only, so the server's pickup check is unaffected.
-- One render loop animates every crate; crates are found by the Pickup tag.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Pickups = require(Shared.Definitions.Pickups)

local definition = Pickups.SupplyCrate

type Bobbing = {
	Rest: CFrame, -- the position the server placed the crate at
	Phase: number, -- random offset so nearby crates do not bob in sync
}

local CrateController = {}

local crates: { [BasePart]: Bobbing } = {}
local rng = Random.new()

local function onAdded(instance: Instance)
	if instance:IsA("BasePart") and not crates[instance] then
		crates[instance] = { Rest = instance.CFrame, Phase = rng:NextNumber(0, math.pi * 2) }
	end
end

local function onRemoved(instance: Instance)
	if instance:IsA("BasePart") then
		crates[instance] = nil
	end
end

local function update()
	if next(crates) == nil then
		return
	end
	local angle = os.clock() * definition.BobSpeed * math.pi * 2
	for part, bobbing in crates do
		local offset = math.sin(angle + bobbing.Phase) * definition.BobHeight
		part.CFrame = bobbing.Rest + Vector3.new(0, offset, 0)
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
