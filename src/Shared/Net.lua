--!strict
-- Every remote in the game. The server creates them all in ReplicatedStorage.Remotes on first use;
-- the client waits for them. Client -> server remotes are validated and rate limited by their Service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"WeaponFire", -- client -> server: (direction: Vector3)
	"WeaponFired", -- server -> all: (shooter, weaponId, origin, endpoints, hits, headHits); positions are Vector3s
	"Headshot", -- server -> shooter: () after a shot that damaged a living enemy's head
	"LimbSevered", -- server -> all: (body: BasePart, c0: CFrame, limb: BasePart, c1: CFrame) for blood
	"WeaponUnlocked", -- server -> client: (weaponId: string)
	"WeaponRefilled", -- server -> client: (weaponId: string)
	"PickupCollected", -- server -> client: (heal: number)
}

local Net = {}

local folder: Instance? = nil

local function createFolder(): Instance
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = created
	end
	created.Parent = ReplicatedStorage
	return created
end

local function getFolder(): Instance
	local existing = folder
	if existing then
		return existing
	end
	local found = if RunService:IsServer() then createFolder() else ReplicatedStorage:WaitForChild(FOLDER_NAME)
	folder = found
	return found
end

function Net.Event(name: string): RemoteEvent
	local remote = getFolder():WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `Remote {name} is not a RemoteEvent`)
	return remote
end

return Net
