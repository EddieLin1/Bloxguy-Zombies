--!strict
-- Fire input (mouse, gamepad, touch button), local tracer and sound prediction, and sending the aim
-- direction to the server. Also draws other players' shots when the server reports them.
-- The client never decides hits, damage or ammo; it only reads the Ammo attribute to skip empty shots.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
local WeaponDefinitions = require(Shared.Definitions.Weapons)

local Effects = script.Parent.Parent.Effects
local BloodSplash = require(Effects.BloodSplash)
local HitSound = require(Effects.HitSound)
local ShotSound = require(Effects.ShotSound)
local Tracer = require(Effects.Tracer)
local CameraController = require(script.Parent.CameraController)

local ACTION_FIRE = "Fire"
local AIM_DISTANCE = 1000
local MIN_SHOT_DISTANCE = 0.1

local player = Players.LocalPlayer
local weaponFire = Net.Event("WeaponFire")
local weaponFired = Net.Event("WeaponFired")
local headshot = Net.Event("Headshot")
local rng = Random.new()
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.CollisionGroup = Constants.CollisionGroups.Shots -- aim at the zombie's body, not its invisible bumper

local WeaponClientController = {}

WeaponClientController.EquippedChanged = Signal.new() -- (tool: Tool?, definition: WeaponDefinition?)

local equippedTool: Tool? = nil
local equippedDefinition: Types.WeaponDefinition? = nil
local fireHeld = false
local lastShot = 0
local characterMaid = Maid.new()

-- Whatever is under the centre crosshair.
local function getAimPosition(): Vector3
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local exclude: { Instance } = { camera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local pickups = workspace:FindFirstChild(Constants.Folders.Pickups)
	if pickups then
		table.insert(exclude, pickups)
	end
	aimParams.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

local function onFireAction(_actionName: string, inputState: Enum.UserInputState, _input: InputObject)
	if inputState == Enum.UserInputState.Begin then
		fireHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		fireHeld = false
	end
	return Enum.ContextActionResult.Sink
end

-- Fire is only bound while a weapon is out and the player is focused (Shift Lock on); in free cam, clicks do nothing.
local function refreshFireBinding()
	fireHeld = false
	if equippedDefinition and CameraController.IsAimLocked() then
		ContextActionService:BindAction(
			ACTION_FIRE,
			onFireAction,
			true,
			Enum.UserInputType.MouseButton1,
			Enum.KeyCode.ButtonR2
		)
		ContextActionService:SetTitle(ACTION_FIRE, "Fire")
	else
		ContextActionService:UnbindAction(ACTION_FIRE)
	end
end

local function setEquipped(tool: Tool?, definition: Types.WeaponDefinition?)
	if tool == equippedTool then
		return
	end
	equippedTool = tool
	equippedDefinition = definition
	refreshFireBinding()
	WeaponClientController.EquippedChanged:Fire(tool, definition)
end

local function refreshEquipped(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local weaponId = child:GetAttribute(Constants.Attributes.WeaponId)
			local definition = if typeof(weaponId) == "string" then WeaponDefinitions.Find(weaponId) else nil
			if definition then
				setEquipped(child, definition)
				return
			end
		end
	end
	setEquipped(nil, nil)
end

local function onCharacterAdded(character: Model)
	characterMaid:Destroy()
	setEquipped(nil, nil)
	local function onChildChanged(child: Instance)
		if child:IsA("Tool") then
			refreshEquipped(character)
		end
	end
	characterMaid:GiveTask(character.ChildAdded:Connect(onChildChanged))
	characterMaid:GiveTask(character.ChildRemoved:Connect(onChildChanged))
	refreshEquipped(character)

	local humanoid = character:WaitForChild("Humanoid")
	if humanoid:IsA("Humanoid") then
		characterMaid:GiveTask(humanoid.Died:Connect(function()
			characterMaid:Destroy()
			setEquipped(nil, nil)
		end))
	end
end

local function drawShot(definition: Types.WeaponDefinition, origin: Vector3, direction: Vector3, length: number)
	for _ = 1, definition.Firing.Pellets do
		local pelletDirection = Spread.Apply(direction, definition.Firing.SpreadDegrees, rng)
		Tracer.Draw(origin, origin + pelletDirection * length, definition.Effects.Color)
	end
end

-- Hold-to-fire loop: every weapon keeps firing at its FireInterval while the button is held.
-- The server enforces the real fire rate and ammo; this is for responsiveness.
local function tryFire()
	local tool, definition = equippedTool, equippedDefinition
	if not fireHeld or not tool or not definition or not CameraController.IsAimLocked() then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if now - lastShot < definition.FireInterval then
		return
	end
	lastShot = now
	local handle = tool:FindFirstChild("Handle")
	if tool:GetAttribute(Constants.Attributes.Ammo) == 0 then
		-- Out of ammo: click on the weapon's own fire rhythm, and send nothing to the server
		ShotSound.PlayEmpty(handle)
		return
	end

	local origin = if handle and handle:IsA("BasePart") then handle.Position else root.Position
	local toAim = getAimPosition() - origin
	if toAim.Magnitude < MIN_SHOT_DISTANCE then
		return
	end
	local direction = toAim.Unit
	weaponFire:FireServer(direction)

	drawShot(definition, origin, direction, math.min(toAim.Magnitude, definition.Firing.Range))
	ShotSound.Play(definition, handle)
end

local function playBlood(positions: unknown, origin: Vector3, style: BloodSplash.SplashStyle)
	if typeof(positions) ~= "table" then
		return
	end
	for _, position in positions :: { any } do
		if typeof(position) == "Vector3" then
			BloodSplash.Play(position, origin, style)
		end
	end
end

local function onWeaponFired(
	shooter: unknown,
	weaponId: unknown,
	origin: unknown,
	endpoints: unknown,
	hits: unknown,
	headHits: unknown
)
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(endpoints) ~= "table" then
		return
	end
	local definition = WeaponDefinitions.Find(weaponId)
	if not definition then
		return
	end

	-- Blood only appears once the server confirms a hit, for everyone including the shooter
	playBlood(hits, origin, "Body")
	playBlood(headHits, origin, "Headshot")

	if shooter == player then
		return -- tracers and sound were already played locally when firing
	end
	for _, endpoint in endpoints :: { any } do
		if typeof(endpoint) == "Vector3" then
			Tracer.Draw(origin, endpoint, definition.Effects.Color)
		end
	end
	if typeof(shooter) == "Instance" and shooter:IsA("Player") then
		local character = shooter.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		ShotSound.Play(definition, tool and tool:FindFirstChild("Handle"))
	end
end

function WeaponClientController.GetEquipped(): (Tool?, Types.WeaponDefinition?)
	return equippedTool, equippedDefinition
end

function WeaponClientController.Start()
	weaponFired.OnClientEvent:Connect(onWeaponFired)
	headshot.OnClientEvent:Connect(HitSound.PlayHeadshot)
	CameraController.AimLockChanged:Connect(refreshFireBinding)
	RunService.Heartbeat:Connect(tryFire)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return WeaponClientController
