--!strict
-- Authoritative state for one weapon owned by one player: ammo, fire rate, its Tool and its firing component.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Maid = require(Shared.Util.Maid)
local Types = require(Shared.Types)
local FiringComponents = require(script.Parent.Components.Firing)
local ToolFactory = require(script.Parent.ToolFactory)
local WeaponTypes = require(script.Parent.WeaponTypes)

local FIRE_TOLERANCE = 0.8 -- forgive network jitter, still blocks fire-rate hacks
local MAX_MUZZLE_OFFSET = 8 -- studs the handle may be from the root before the root is used instead

local GunController = {}
GunController.__index = GunController

export type ShotResult = {
	Origin: Vector3,
	Endpoints: { Vector3 },
	Headshot: boolean,
}

export type GunController = typeof(setmetatable({} :: {
	Owner: Player,
	Definition: Types.WeaponDefinition,
	Tool: Tool,
	Ammo: number,
	LastFire: number,
	_firing: WeaponTypes.FiringComponent,
	_maid: Maid.Maid,
}, GunController))

function GunController.new(
	owner: Player,
	definition: Types.WeaponDefinition,
	context: WeaponTypes.FiringContext,
	backpack: Instance
): GunController
	local componentClass = FiringComponents[definition.Firing.Type]
	assert(componentClass, `Weapon "{definition.Id}" uses unknown firing type "{definition.Firing.Type}"`)

	local maid = Maid.new()
	local tool: Tool = maid:GiveTask(ToolFactory.Build(definition))
	local self = setmetatable({
		Owner = owner,
		Definition = definition,
		Tool = tool,
		Ammo = definition.MaxAmmo or 0,
		LastFire = 0,
		_firing = maid:GiveTask(componentClass.new(context, definition)),
		_maid = maid,
	}, GunController)

	self:_publishAmmo()
	tool.Parent = backpack
	return self
end

function GunController.IsInfinite(self: GunController): boolean
	return self.Definition.MaxAmmo == nil
end

function GunController.CanFire(self: GunController, now: number): boolean
	if not self:IsInfinite() and self.Ammo <= 0 then
		return false
	end
	return now - self.LastFire >= self.Definition.FireInterval * FIRE_TOLERANCE
end

-- Fires from a server-derived muzzle position. Returns nil when the shot is not allowed.
function GunController.TryFire(self: GunController, direction: Vector3, root: BasePart): ShotResult?
	local now = os.clock()
	if not self:CanFire(now) then
		return nil
	end
	self.LastFire = now
	if not self:IsInfinite() then
		self.Ammo -= 1
		self:_publishAmmo()
	end

	local origin = self:_getMuzzle(root)
	local result = self._firing:Fire(origin, direction)
	return {
		Origin = origin,
		Endpoints = result.Endpoints,
		Headshot = result.Headshot,
	}
end

function GunController.Refill(self: GunController)
	local maxAmmo = self.Definition.MaxAmmo
	if maxAmmo then
		self.Ammo = maxAmmo
		self:_publishAmmo()
	end
end

function GunController.AddAmmoFraction(self: GunController, fraction: number)
	local maxAmmo = self.Definition.MaxAmmo
	if maxAmmo then
		self.Ammo = math.min(maxAmmo, self.Ammo + math.ceil(maxAmmo * fraction))
		self:_publishAmmo()
	end
end

-- The Tool attribute is display-only for the client's HUD; the server never reads it back.
function GunController._publishAmmo(self: GunController)
	local value = if self:IsInfinite() then Constants.INFINITE_AMMO else self.Ammo
	self.Tool:SetAttribute(Constants.Attributes.Ammo, value)
end

function GunController._getMuzzle(self: GunController, root: BasePart): Vector3
	local handle = self.Tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") and (handle.Position - root.Position).Magnitude <= MAX_MUZZLE_OFFSET then
		return handle.Position
	end
	return root.Position
end

function GunController.Destroy(self: GunController)
	self._maid:Destroy()
end

return GunController
