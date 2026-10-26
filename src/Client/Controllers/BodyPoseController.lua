--!strict
-- Procedural body poses for zombies and players, drawn locally by tilting the root-to-torso joint and
-- the neck (nothing replicates; the server only sets attributes):
-- * Hit flinch (Flinch / FlinchDirection, see Server/Util/Flinch): the upper body snaps away from the
--   hit and the head whips back, then both recover.
-- * Crawl (CrawlPitch, set by Enemy while climbing a pile or after losing a leg): the body leans
--   forward into a crawl at the angle of the climb, with the head lifted to look ahead. Flinches
--   play on top of the crawl.
-- * Crawl stroke (Legless, or down in a climbing crawl): the arms reach ahead and drag back in turn,
--   left then right, like a caterpillar pulling itself along; faster while moving. Zombies climbing
--   a pile claw their way up with it.
-- (Roblox has no built-in R6 hit or crawl animation; to use uploaded ones instead, play them here.)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)

local BODY_ANGLE = 40 -- degrees the upper body snaps away from a hit
local HEAD_ANGLE = 30 -- extra degrees the head whips back on top of that
local HEAD_CRAWL_SHARE = -0.45 -- while crawling the head tilts back by this share of the lean, to look ahead
local SNAP_TIME = 0.05
local RECOVER_TIME = 0.35
local CRAWL_BLEND_TIME = 0.25
local ARM_REACH = 140 -- degrees the arms are raised past their rest pose, so they point ahead of a lying body
local ARM_SWING = 40 -- degrees each arm sweeps either side of that as it reaches and pulls
local STROKES_MOVING = 1.4 -- arm strokes per second while crawling along
local STROKES_IDLE = 0.35 -- slow pawing while not moving
local MOVING_SPEED = 0.5 -- studs/s that counts as moving
local STROKE_MIN_PITCH = math.rad(30) -- a crawl lean this deep (climbing) also gets the arm stroke

local snapInfo = TweenInfo.new(SNAP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local recoverInfo = TweenInfo.new(RECOVER_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local crawlInfo = TweenInfo.new(CRAWL_BLEND_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

type PoseJoint = {
	Joint: Motor6D,
	Rest: CFrame, -- the joint's normal C0
	FlinchAngle: number, -- radians
	CrawlShare: number, -- how much of the crawl lean this joint takes (negative = tilts back)
}

type ArmJoint = {
	Joint: Motor6D,
	Rest: CFrame,
	Side: number, -- 1 = right, -1 = left (the shoulders raise in opposite directions)
}

type Posed = {
	Joints: { PoseJoint }?, -- found on first use
	Arms: { ArmJoint }?, -- found when the model first needs the crawl stroke
	CrawlPitch: number, -- radians, current crawl lean
	Legless: boolean,
	Stroking: boolean, -- arms are in the crawl stroke (put back to rest when it stops)
	StrokePhase: number, -- radians, advances as the arms crawl
	Tweens: { Tween },
	Token: number,
	Maid: Maid.Maid,
}

local BodyPoseController = {}

local models: { [Model]: Posed } = {}

-- R6 shoulders. (R15 rigs have no "Right Shoulder" Motor6D under these names, so they are skipped.)
local function findArms(model: Model): { ArmJoint }
	local arms: { ArmJoint } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if descendant.Name == "Right Shoulder" then
				table.insert(arms, { Joint = descendant, Rest = descendant.C0, Side = 1 })
			elseif descendant.Name == "Left Shoulder" then
				table.insert(arms, { Joint = descendant, Rest = descendant.C0, Side = -1 })
			end
		end
	end
	return arms
end

-- Back to the normal arm pose once a climber is off the pile.
local function restArms(entry: Posed)
	local arms = entry.Arms
	if not arms then
		return
	end
	for _, arm in arms do
		if arm.Joint.Parent and arm.Joint.Enabled then
			arm.Joint.C0 = arm.Rest
		end
	end
end

-- One frame of the crawl stroke: each arm sweeps forward and back, the two half a stroke apart.
local function strokeArms(model: Model, entry: Posed, dt: number)
	local arms: { ArmJoint } = entry.Arms or findArms(model)
	entry.Arms = arms
	local root = model:FindFirstChild("HumanoidRootPart")
	local velocity = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
	entry.StrokePhase = (entry.StrokePhase + dt * math.pi * 2 * (if moving then STROKES_MOVING else STROKES_IDLE))
		% (math.pi * 2)
	for _, arm in arms do
		if arm.Joint.Parent and arm.Joint.Enabled then
			local phase = entry.StrokePhase + (if arm.Side > 0 then 0 else math.pi)
			local angle = math.rad(ARM_REACH + ARM_SWING * math.sin(phase))
			arm.Joint.C0 = arm.Rest * CFrame.Angles(0, 0, angle * arm.Side)
		end
	end
end

-- The root-to-torso joint ("RootJoint" in R6, "Root" in R15) and the neck.
local function findJoints(model: Model): { PoseJoint }
	local joints: { PoseJoint } = {}
	local root = model:FindFirstChild("HumanoidRootPart")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if root and descendant.Part0 == root then
				table.insert(joints, {
					Joint = descendant,
					Rest = descendant.C0,
					FlinchAngle = math.rad(BODY_ANGLE),
					CrawlShare = 1,
				})
			elseif descendant.Name == "Neck" then
				table.insert(joints, {
					Joint = descendant,
					Rest = descendant.C0,
					FlinchAngle = math.rad(HEAD_ANGLE),
					CrawlShare = HEAD_CRAWL_SHARE,
				})
			end
		end
	end
	return joints
end

-- Rotates a joint's C0 by `rotation` (in the joint's Part0 space), pivoting at the joint itself.
local function rotateAtJoint(poseJoint: PoseJoint, rotation: CFrame, c0: CFrame): CFrame
	local pivot = CFrame.new(poseJoint.Rest.Position)
	return pivot * rotation * pivot:Inverse() * c0
end

-- The joint's pose with no flinch: its rest pose leaned forward by the current crawl.
local function basePose(poseJoint: PoseJoint, crawlPitch: number): CFrame
	return rotateAtJoint(poseJoint, CFrame.Angles(-crawlPitch * poseJoint.CrawlShare, 0, 0), poseJoint.Rest)
end

local function getJoints(model: Model, entry: Posed): { PoseJoint }
	local joints: { PoseJoint } = entry.Joints or findJoints(model)
	entry.Joints = joints
	return joints
end

local function stopTweens(entry: Posed)
	for _, tween in entry.Tweens do
		tween:Cancel()
	end
	table.clear(entry.Tweens)
end

local function playTween(entry: Posed, joint: Motor6D, info: TweenInfo, c0: CFrame): Tween
	local tween = TweenService:Create(joint, info, { C0 = c0 })
	table.insert(entry.Tweens, tween)
	tween:Play()
	return tween
end

local function isPosable(joint: Motor6D): boolean
	return joint.Parent ~= nil and joint.Enabled -- disabled = ragdolled
end

local function playFlinch(model: Model, entry: Posed)
	local direction = model:GetAttribute(Constants.Attributes.FlinchDirection)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return
	end
	stopTweens(entry)
	entry.Token += 1
	local token = entry.Token
	local unit = direction.Unit
	for _, poseJoint in getJoints(model, entry) do
		local joint = poseJoint.Joint
		local part0 = joint.Part0
		if isPosable(joint) and part0 then
			-- Tilt toward where the hit pushed, in the joint's Part0 space, on top of any crawl
			local push = part0.CFrame:VectorToObjectSpace(unit)
			local angle = poseJoint.FlinchAngle
			local tilt = CFrame.Angles(push.Z * angle, 0, -push.X * angle)
			local snap = playTween(entry, joint, snapInfo, rotateAtJoint(poseJoint, tilt, basePose(poseJoint, entry.CrawlPitch)))
			snap.Completed:Once(function(state: Enum.PlaybackState)
				if state == Enum.PlaybackState.Completed and entry.Token == token then
					playTween(entry, joint, recoverInfo, basePose(poseJoint, entry.CrawlPitch))
				end
			end)
		end
	end
end

local function blendCrawl(model: Model, entry: Posed)
	local pitch = tonumber(model:GetAttribute(Constants.Attributes.CrawlPitch)) or 0
	entry.CrawlPitch = math.rad(pitch)
	stopTweens(entry)
	entry.Token += 1
	for _, poseJoint in getJoints(model, entry) do
		if isPosable(poseJoint.Joint) then
			playTween(entry, poseJoint.Joint, crawlInfo, basePose(poseJoint, entry.CrawlPitch))
		end
	end
end

local function onAdded(instance: Instance)
	if not instance:IsA("Model") or models[instance] then
		return
	end
	local entry: Posed = {
		Joints = nil,
		Arms = nil,
		CrawlPitch = 0,
		Legless = false,
		Stroking = false,
		StrokePhase = 0,
		Tweens = {},
		Token = 0,
		Maid = Maid.new(),
	}
	models[instance] = entry
	local function refreshLegless()
		entry.Legless = instance:GetAttribute(Constants.Attributes.Legless) == true
	end
	entry.Maid:GiveTask(instance:GetAttributeChangedSignal(Constants.Attributes.Legless):Connect(refreshLegless))
	refreshLegless()
	entry.Maid:GiveTask(instance:GetAttributeChangedSignal(Constants.Attributes.Flinch):Connect(function()
		playFlinch(instance, entry)
	end))
	entry.Maid:GiveTask(instance:GetAttributeChangedSignal(Constants.Attributes.CrawlPitch):Connect(function()
		blendCrawl(instance, entry)
	end))
end

local function onRemoved(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = models[instance]
	if entry then
		stopTweens(entry)
		entry.Maid:Destroy()
		models[instance] = nil
	end
end

function BodyPoseController.Start()
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Flinchable):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.Flinchable):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(Constants.Tags.Flinchable) do
		onAdded(instance)
	end
	RunService.RenderStepped:Connect(function(dt: number)
		for model, entry in models do
			local crawling = entry.Legless or entry.CrawlPitch >= STROKE_MIN_PITCH
			if crawling then
				strokeArms(model, entry, dt)
			elseif entry.Stroking then
				restArms(entry)
			end
			entry.Stroking = crawling
		end
	end)
end

return BodyPoseController
