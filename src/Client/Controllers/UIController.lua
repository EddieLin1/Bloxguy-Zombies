--!strict
-- Builds the HUD and connects it to the equipped weapon and the server's notifications.
-- HUD components read replicated attributes themselves; nothing here decides game outcomes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local WeaponDefinitions = require(Shared.Definitions.Weapons)

local UI = script.Parent.Parent.UI
local ComboMeter = require(UI.ComboMeter)
local Crosshair = require(UI.Crosshair)
local StatsPanel = require(UI.StatsPanel)
local StatusBanner = require(UI.StatusBanner)
local Toast = require(UI.Toast)
local WeaponDisplay = require(UI.WeaponDisplay)
local CameraController = require(script.Parent.CameraController)
local WeaponClientController = require(script.Parent.WeaponClientController)

local PICKUP_COLOR = Color3.fromRGB(120, 255, 120)

local player = Players.LocalPlayer

local UIController = {}

local function makeScreenGui(name: string, displayOrder: number, ignoreGuiInset: boolean, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = ignoreGuiInset
	gui.Parent = parent
	return gui
end

local function onWeaponNotice(toast: Toast.Toast, format: (Types.WeaponDefinition) -> string)
	return function(weaponId: unknown)
		local definition = if typeof(weaponId) == "string" then WeaponDefinitions.Find(weaponId) else nil
		if definition then
			toast:Show(format(definition), definition.Effects.Color)
		end
	end
end

function UIController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hudGui = makeScreenGui("HUD", 1, false, playerGui)
	local crosshairGui = makeScreenGui("Crosshair", 1, true, playerGui)
	local notificationGui = makeScreenGui("Notifications", 2, false, playerGui)

	StatusBanner.new(hudGui)
	StatsPanel.new(hudGui)
	ComboMeter.new(hudGui)
	local weaponDisplay = WeaponDisplay.new(hudGui)
	local crosshair = Crosshair.new(crosshairGui)
	local toast = Toast.new(notificationGui)

	-- The crosshair only shows when shooting is possible: weapon out and aim lock on.
	local function refreshCrosshair()
		local _, definition = WeaponClientController.GetEquipped()
		crosshair:SetVisible(definition ~= nil and CameraController.IsAimLocked())
	end
	local function onEquippedChanged(tool: Tool?, definition: Types.WeaponDefinition?)
		weaponDisplay:SetWeapon(tool, definition)
		refreshCrosshair()
	end
	WeaponClientController.EquippedChanged:Connect(onEquippedChanged)
	CameraController.AimLockChanged:Connect(refreshCrosshair)
	onEquippedChanged(WeaponClientController.GetEquipped())

	Net.Event("WeaponUnlocked").OnClientEvent:Connect(onWeaponNotice(toast, function(definition)
		return `NEW WEAPON: {definition.DisplayName}!`
	end))
	Net.Event("WeaponRefilled").OnClientEvent:Connect(onWeaponNotice(toast, function(definition)
		return `{definition.DisplayName} ammo refilled!`
	end))
	Net.Event("PickupCollected").OnClientEvent:Connect(function(heal: unknown)
		toast:Show(`+{tonumber(heal) or 0} Health  +Ammo`, PICKUP_COLOR)
	end)
end

return UIController
