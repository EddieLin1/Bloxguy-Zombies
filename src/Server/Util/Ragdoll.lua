--!strict
-- Makes dead characters (zombies and players) collapse as ragdolls instead of falling apart or tipping
-- over stiffly. Each Motor6D joint is swapped for a limited BallSocketConstraint at the same spot.
-- Works for R6 and R15. Call Prepare on spawn, then Enable when the Humanoid dies.

local KEEP_JOINTS = { RootJoint = true, Root = true } -- keep HumanoidRootPart fixed to the torso
local SWING_LIMIT = 50 -- degrees a limb can swing from its joint
local TWIST_LIMIT = 30 -- degrees a limb can twist around its joint

local Ragdoll = {}

-- Without this, Roblox breaks every joint on death and the body falls into loose pieces.
function Ragdoll.Prepare(humanoid: Humanoid)
	humanoid.BreakJointsOnDeath = false
end

local function makeAttachment(parent: BasePart, cframe: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "RagdollAttachment"
	attachment.CFrame = cframe
	attachment.Parent = parent
	return attachment
end

local function ragdollJoint(joint: Motor6D)
	local part0, part1 = joint.Part0, joint.Part1
	if not part0 or not part1 then
		return
	end

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = makeAttachment(part0, joint.C0)
	socket.Attachment1 = makeAttachment(part1, joint.C1)
	socket.LimitsEnabled = true
	socket.UpperAngle = SWING_LIMIT
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -TWIST_LIMIT
	socket.TwistUpperAngle = TWIST_LIMIT
	socket.Parent = part1

	-- Limbs need collision to land on the floor, but connected parts must not push each other apart
	local noCollide = Instance.new("NoCollisionConstraint")
	noCollide.Part0 = part0
	noCollide.Part1 = part1
	noCollide.Parent = part1
	part1.CanCollide = true

	joint.Enabled = false
end

function Ragdoll.Enable(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and not KEEP_JOINTS[descendant.Name] then
			ragdollJoint(descendant)
		end
	end
end

return Ragdoll
