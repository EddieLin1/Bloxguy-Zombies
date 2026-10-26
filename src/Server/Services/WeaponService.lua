--!strict
-- Owns every player's weapons: which are unlocked, one GunController per owned weapon, and the WeaponFire remote.
-- The client only sends an aim direction; the equipped weapon, ammo, fire rate and muzzle are all server state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local WeaponDefinitions = require(Shared.Definitions.Weapons)

local Server = script.Parent.Parent
local GunController = require(Server.Weapons.GunController)
local WeaponTypes = require(Server.Weapons.WeaponTypes)
local RemoteGuard = require(Server.Util.RemoteGuard)
local WorldFolders = require(Server.Util.WorldFolders)
local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)

local FIRE_MIN_INTERVAL = 0.05 -- below every weapon's FireInterval; each controller enforces its own rate
local DIRECTION_MIN_MAGNITUDE = 0.5
local DIRECTION_MAX_MAGNITUDE = 1.5
local BACKPACK_TIMEOUT = 5

type Loadout = {
	Unlocked: { [string]: boolean },
	Controllers: { [string]: GunController.GunController },
	Context: WeaponTypes.FiringContext,
}

local WeaponService = {}

local loadouts: { [Player]: Loadout } = {}
local weaponFire = Net.Event("WeaponFire")
local weaponFired = Net.Event("WeaponFired")
local headshot = Net.Event("Headshot")
local pickupFolder = WorldFolders.Get(Constants.Folders.Pickups)

local enemyHits: WeaponTypes.EnemyHitApi = {
	GetModelFromPart = EnemyService.GetModelFromPart,
	DamageModel = EnemyService.DamageModel,
}

-- Bullets pass through players and pickups.
local function getIgnoreList(): { Instance }
	local ignore = PlayerService.GetCharacters()
	table.insert(ignore, pickupFolder)
	return ignore
end

local function startingUnlocks(): { [string]: boolean }
	local unlocked = {}
	for _, definition in WeaponDefinitions.All() do
		if definition.UnlockCombo == 0 then
			unlocked[definition.Id] = true
		end
	end
	return unlocked
end

local function getLoadout(player: Player): Loadout
	local existing = loadouts[player]
	if existing then
		return existing
	end
	local created: Loadout = {
		Unlocked = startingUnlocks(),
		Controllers = {},
		Context = {
			Owner = player,
			Enemies = enemyHits,
			HeadshotMultiplier = GameRules.HeadshotMultiplier,
			GetIgnoreList = getIgnoreList,
		},
	}
	loadouts[player] = created
	return created
end

local function destroyControllers(loadout: Loadout)
	for _, controller in loadout.Controllers do
		controller:Destroy()
	end
	table.clear(loadout.Controllers)
end

-- Gives the weapon's Tool, or refills it if the player already holds it.
local function giveWeapon(player: Player, loadout: Loadout, definition: Types.WeaponDefinition)
	local existing = loadout.Controllers[definition.Id]
	if existing then
		existing:Refill()
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or not PlayerService.IsAlive(player) then
		return
	end
	loadout.Controllers[definition.Id] = GunController.new(player, definition, loadout.Context, backpack)
end

local function onCharacterSpawned(player: Player, _character: Model)
	local loadout = getLoadout(player)
	destroyControllers(loadout)
	player:WaitForChild("Backpack", BACKPACK_TIMEOUT)
	for _, definition in WeaponDefinitions.All() do
		if loadout.Unlocked[definition.Id] then
			giveWeapon(player, loadout, definition)
		end
	end
end

local function onCharacterRemoving(player: Player, _character: Model)
	local loadout = loadouts[player]
	if loadout then
		destroyControllers(loadout)
	end
end

local function onPlayerLeft(player: Player)
	local loadout = loadouts[player]
	if loadout then
		destroyControllers(loadout)
		loadouts[player] = nil
	end
end

-- The controller for the Tool the player is holding, if it is one of their weapons.
local function findEquippedController(player: Player): GunController.GunController?
	local loadout = loadouts[player]
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not loadout or not tool then
		return nil
	end
	local weaponId = tool:GetAttribute(Constants.Attributes.WeaponId)
	local controller = if typeof(weaponId) == "string" then loadout.Controllers[weaponId] else nil
	if controller and controller.Tool == tool then
		return controller
	end
	return nil
end

local function onWeaponFire(player: Player, direction: unknown)
	if not RemoteGuard.Allow(player, "WeaponFire", FIRE_MIN_INTERVAL) then
		return
	end
	if typeof(direction) ~= "Vector3" or direction ~= direction then -- type, then NaN
		RemoteGuard.Reject(player, "WeaponFire: direction is not a valid Vector3")
		return
	end
	local magnitude = direction.Magnitude
	if magnitude < DIRECTION_MIN_MAGNITUDE or magnitude > DIRECTION_MAX_MAGNITUDE then
		RemoteGuard.Reject(player, "WeaponFire: direction is not a unit vector")
		return
	end

	local _, root = PlayerService.GetAliveCharacter(player)
	if not root then
		return
	end
	local controller = findEquippedController(player)
	if not controller then
		return
	end
	local shot = controller:TryFire(direction.Unit, root)
	if shot then
		weaponFired:FireAllClients(player, controller.Definition.Id, shot.Origin, shot.Endpoints)
		if shot.Headshot then
			headshot:FireClient(player) -- once per shot, even if several pellets hit heads
		end
	end
end

-- Back to the starting weapons. Tools are rebuilt when the player next spawns.
function WeaponService.ResetAll()
	for _, loadout in loadouts do
		loadout.Unlocked = startingUnlocks()
	end
end

-- Returns true if the weapon was newly unlocked (and given), false if the player already had it.
function WeaponService.Unlock(player: Player, weaponId: string): boolean
	local loadout = getLoadout(player)
	if loadout.Unlocked[weaponId] then
		return false
	end
	loadout.Unlocked[weaponId] = true
	giveWeapon(player, loadout, WeaponDefinitions.Get(weaponId))
	return true
end

function WeaponService.Refill(player: Player, weaponId: string)
	local loadout = loadouts[player]
	local controller = loadout and loadout.Controllers[weaponId]
	if controller then
		controller:Refill()
	end
end

function WeaponService.AddAmmoFraction(player: Player, fraction: number)
	local loadout = loadouts[player]
	if not loadout then
		return
	end
	for _, controller in loadout.Controllers do
		controller:AddAmmoFraction(fraction)
	end
end

function WeaponService.Init()
	PlayerService.CharacterSpawned:Connect(onCharacterSpawned)
	PlayerService.CharacterRemoving:Connect(onCharacterRemoving)
	PlayerService.PlayerLeft:Connect(onPlayerLeft)
	weaponFire.OnServerEvent:Connect(onWeaponFire)
end

return WeaponService
