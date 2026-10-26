--!strict
-- Supply crates dropped by zombies. One throttled loop checks every crate against every living player
-- on the server, so there is no .Touched handler and no client can claim a crate from far away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Pickups = require(Shared.Definitions.Pickups)

local Server = script.Parent.Parent
local WorldFolders = require(Server.Util.WorldFolders)
local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)

local CHECK_INTERVAL = 0.1
local GROUND_RAY_START = 3 -- start the ground ray this far above the zombie's root
local GROUND_RAY_LENGTH = 50
local NO_GROUND_DROP = 1.5 -- if no ground is found, drop this far below the zombie's root
local LIGHT_RANGE = 8
local LIGHT_BRIGHTNESS = 2

type Crate = {
	Part: BasePart,
	ExpiresAt: number,
}

local PickupService = {}

local definition = Pickups.SupplyCrate
local pickupCollected = Net.Event("PickupCollected")
local folder = WorldFolders.Get(Constants.Folders.Pickups)
local enemyFolder = WorldFolders.Get(Constants.Folders.Enemies)
local crates: { Crate } = {}
local rng = Random.new()
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- The crate's resting position: HoverHeight above the ground under where the zombie died.
local function findRestPosition(deathPosition: Vector3): Vector3
	local ignore = PlayerService.GetCharacters()
	table.insert(ignore, enemyFolder)
	table.insert(ignore, folder)
	groundParams.FilterDescendantsInstances = ignore
	local start = deathPosition + Vector3.new(0, GROUND_RAY_START, 0)
	local result = workspace:Raycast(start, Vector3.new(0, -GROUND_RAY_LENGTH, 0), groundParams)
	if result then
		return result.Position + Vector3.new(0, definition.HoverHeight, 0)
	end
	return deathPosition - Vector3.new(0, NO_GROUND_DROP, 0)
end

-- The server places the crate at rest; clients animate the bobbing (CrateController).
local function spawnCrate(deathPosition: Vector3)
	local position = findRestPosition(deathPosition)
	local part = Instance.new("Part")
	part.Name = definition.Id
	part.Size = Vector3.one * definition.Size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.WoodPlanks
	part.Color = definition.Color
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)

	local light = Instance.new("PointLight")
	light.Color = definition.LightColor
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Parent = part
	part:AddTag(Constants.Tags.Pickup)
	part.Parent = folder

	local crate: Crate = { Part = part, ExpiresAt = os.clock() + definition.Lifetime }
	table.insert(crates, crate)
end

local function removeCrate(index: number)
	local crate = crates[index]
	crates[index] = crates[#crates]
	crates[#crates] = nil
	crate.Part:Destroy()
end

local function collect(player: Player, humanoid: Humanoid)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + definition.Heal)
	WeaponService.AddAmmoFraction(player, definition.AmmoFraction)
	pickupCollected:FireClient(player, definition.Heal)
end

-- Returns true if a living player was close enough to take this crate.
local function tryCollect(crate: Crate, players: { Player }, radiusSq: number): boolean
	for _, player in players do
		local humanoid, root = PlayerService.GetAliveCharacter(player)
		if humanoid and root then
			local offset = root.Position - crate.Part.Position
			if offset:Dot(offset) <= radiusSq then
				collect(player, humanoid)
				return true
			end
		end
	end
	return false
end

local function step()
	if #crates == 0 then
		return
	end
	local now = os.clock()
	local players = PlayerService.GetAlivePlayers()
	local radiusSq = definition.CollectRadius * definition.CollectRadius
	-- Backwards, because removeCrate swaps the last crate into the removed slot
	for index = #crates, 1, -1 do
		local crate = crates[index]
		if now >= crate.ExpiresAt or tryCollect(crate, players, radiusSq) then
			removeCrate(index)
		end
	end
end

function PickupService.ClearAll()
	for _, crate in crates do
		crate.Part:Destroy()
	end
	table.clear(crates)
	folder:ClearAllChildren()
end

function PickupService.Init()
	EnemyService.EnemyDied:Connect(function(_enemy: any, _killer: Player?, position: Vector3)
		if rng:NextNumber() < definition.DropChance then
			spawnCrate(position)
		end
	end)
end

function PickupService.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		step()
	end)
end

return PickupService
