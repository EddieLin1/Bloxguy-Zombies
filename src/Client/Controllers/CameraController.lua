--!strict
-- Aim focus. On mouse and keyboard the player is focused (and can shoot) only while Roblox's Shift Lock
-- is on, i.e. the mouse is locked to the centre of the screen. In free cam they cannot shoot
-- (see WeaponClientController). Touch and gamepad have no Shift Lock, so they always count as focused.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local MIN_ZOOM_DISTANCE = 6
local GAMEPAD_PREFIX = "Gamepad"

local player = Players.LocalPlayer

local CameraController = {}

CameraController.AimLockChanged = Signal.new() -- (focused: boolean)

local aimLocked = false

local function usingMouse(): boolean
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch or string.sub(lastInput.Name, 1, #GAMEPAD_PREFIX) == GAMEPAD_PREFIX then
		return false
	end
	return UserInputService.MouseEnabled
end

local function refresh()
	local mouseLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	-- Shift Lock shows Roblox's own crosshair cursor in the centre; hide it so only ours shows
	UserInputService.MouseIconEnabled = not mouseLocked
	local locked = not usingMouse() or mouseLocked
	if locked ~= aimLocked then
		aimLocked = locked
		CameraController.AimLockChanged:Fire(locked)
	end
end

-- True when the player is focused: Shift Lock on (mouse), or using touch or a gamepad.
function CameraController.IsAimLocked(): boolean
	return aimLocked
end

function CameraController.Start()
	player.CameraMinZoomDistance = MIN_ZOOM_DISTANCE
	UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(refresh)
	refresh()
end

return CameraController
