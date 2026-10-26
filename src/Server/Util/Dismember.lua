--!strict
-- Blows a limb off a zombie, living or ragdolled. The joint is cut, the limb becomes its own "Gib"
-- model in the enemy folder (so bullets pass through it and it is cleaned up like a corpse), it is
-- flung along the shot, and every client is told where to pour blood (stump and limb).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameRules = require(Shared.Definitions.GameRules)
local Net = require(Shared.Net)
local Ragdoll = require(script.Parent.Ragdoll)

local GIB_NAME = "Gib"

local Dismember = {}

local limbSevered = Net.Event("LimbSevered")

-- Finds and removes whatever holds `limb` on: a Motor6D while alive, or the ragdoll's ball socket
-- once dead. Returns the body part it was attached to and the joint offsets on each side.
local function cutJoint(model: Model, limb: BasePart): (BasePart?, CFrame, CFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 == limb then
			local body, c0, c1 = descendant.Part0, descendant.C0, descendant.C1
			descendant:Destroy()
			return body, c0, c1
		end
	end
	local body: BasePart? = nil
	local c0, c1 = CFrame.new(), CFrame.new()
	for _, child in limb:GetChildren() do
		if child:IsA("BallSocketConstraint") then
			local attachment0, attachment1 = child.Attachment0, child.Attachment1
			if attachment0 and attachment1 then
				local parent = attachment0.Parent
				body = if parent and parent:IsA("BasePart") then parent else nil
				c0, c1 = attachment0.CFrame, attachment1.CFrame
			end
			child:Destroy()
		elseif child:IsA("NoCollisionConstraint") then
			child:Destroy()
		end
	end
	return body, c0, c1
end

-- Returns true if the limb was severed.
function Dismember.Sever(model: Model, limb: BasePart, direction: Vector3, corpseTime: number): boolean
	if not limb:IsDescendantOf(model) then
		return false
	end
	local body, c0, c1 = cutJoint(model, limb)
	if not body then
		return false
	end

	local gib = Instance.new("Model")
	gib.Name = GIB_NAME
	limb.Parent = gib
	gib.Parent = model.Parent
	limb.Anchored = false
	limb.CanCollide = true
	pcall(function()
		limb:SetNetworkOwner(nil)
	end)
	local fling = direction.Unit * GameRules.LimbPopForce + Vector3.new(0, GameRules.LimbPopLift, 0)
	limb:ApplyImpulse(fling * limb:GetMass())

	task.delay(GameRules.CorpseFreezeDelay, function()
		if gib.Parent then
			Ragdoll.Freeze(gib)
		end
	end)
	Debris:AddItem(gib, corpseTime)
	limbSevered:FireAllClients(body, c0, limb, c1)
	return true
end

return Dismember
