--!strict
-- Builds the Roblox Tool (a simple gun model) for a weapon definition. Tools carry no scripts;
-- WeaponService and the client's WeaponClientController handle every weapon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Types = require(Shared.Types)

local BODY_COLOR = Color3.fromRGB(35, 35, 40)
local HANDLE_WIDTH = 0.4
local HANDLE_HEIGHT = 0.7
local STRIPE_HEIGHT = 0.15
local STRIPE_LENGTH_FACTOR = 0.6
local STRIPE_OFFSET = CFrame.new(0, 0.3, 0)

local ToolFactory = {}

local function makePart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CanCollide = false
	part.Massless = true
	return part
end

function ToolFactory.Build(definition: Types.WeaponDefinition): Tool
	local tool = Instance.new("Tool")
	tool.Name = definition.DisplayName
	tool.ToolTip = definition.DisplayName
	tool.CanBeDropped = false
	tool:SetAttribute(Constants.Attributes.WeaponId, definition.Id)

	local handle = makePart("Handle", Vector3.new(HANDLE_WIDTH, HANDLE_HEIGHT, definition.HandleLength))
	handle.Color = BODY_COLOR
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	local stripe = makePart(
		"Stripe",
		Vector3.new(HANDLE_WIDTH + 0.02, STRIPE_HEIGHT, definition.HandleLength * STRIPE_LENGTH_FACTOR)
	)
	stripe.Color = definition.Effects.Color
	stripe.Material = Enum.Material.Neon
	stripe.CFrame = handle.CFrame * STRIPE_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = stripe
	weld.Parent = stripe
	stripe.Parent = tool

	return tool
end

return ToolFactory
