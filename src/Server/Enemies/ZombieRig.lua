--!strict
-- Builds the zombie model that EnemyService clones for every spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

-- How far the arms are lifted forward from hanging at the sides (0 = straight down, 90 = straight out)
local ARM_RAISE = math.rad(20)
local FACE_TEXTURE = "rbxasset://textures/face.png"

local ZombieRig = {}

-- Fallback if CreateHumanoidModelFromDescription fails (e.g. offline Studio).
local function buildManualRig(): Model
	local model = Instance.new("Model")

	local function part(name: string, size: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.Transparency = 1
	root.CanCollide = false
	local torso = part("Torso", Vector3.new(2, 2, 1))
	local head = part("Head", Vector3.new(2, 1, 1))
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = FACE_TEXTURE
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1))
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1))
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1))
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1))

	local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = c0
		m.C1 = c1
		m.Parent = part0
	end

	-- Standard R6 joint offsets
	local rootCFrame = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", root, torso, rootCFrame, rootCFrame)
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildBaseRig(): Model
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if ok and result then
		return result
	end
	warn("[ZombieRig] Using fallback zombie rig:", result)
	return buildManualRig()
end

-- Accessories, clothing and scripts cost replication and simulation for every zombie.
local function stripExtras(model: Model)
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("BodyColors")
			or descendant:IsA("Clothing")
			or descendant:IsA("ShirtGraphic")
			or descendant:IsA("Accessory")
			or descendant:IsA("LuaSourceContainer")
		then
			descendant:Destroy()
		end
	end
end

local function paint(model: Model, colors: { Skin: Color3, Shirt: Color3, Pants: Color3 })
	local partColors: { [string]: Color3 } = {
		Head = colors.Skin,
		["Left Arm"] = colors.Skin,
		["Right Arm"] = colors.Skin,
		Torso = colors.Shirt,
		["Left Leg"] = colors.Pants,
		["Right Leg"] = colors.Pants,
	}
	for name, color in partColors do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

local function raiseArms(model: Model)
	local torso = model:FindFirstChild("Torso")
	if not torso then
		return
	end
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	if rightShoulder and rightShoulder:IsA("Motor6D") then
		rightShoulder.C0 *= CFrame.Angles(0, 0, ARM_RAISE)
	end
	if leftShoulder and leftShoulder:IsA("Motor6D") then
		leftShoulder.C0 *= CFrame.Angles(0, 0, -ARM_RAISE)
	end
end

function ZombieRig.Build(definition: Types.EnemyDefinition): Model
	local model = buildBaseRig()
	model.Name = definition.Id
	stripExtras(model)
	paint(model, definition.Colors)
	raiseArms(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "Zombie rig has no Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	return model
end

return ZombieRig
