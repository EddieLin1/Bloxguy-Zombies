--!strict
-- Owns player join/leave, character spawning and the "who is alive" queries.
-- Characters do not auto-load; GameService decides when players spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Util.Maid)
local Signal = require(Shared.Util.Signal)
local Flinch = require(script.Parent.Parent.Util.Flinch)
local Jump = require(script.Parent.Parent.Util.Jump)
local Ragdoll = require(script.Parent.Parent.Util.Ragdoll)

local HUMANOID_TIMEOUT = 10

local PlayerService = {}

PlayerService.PlayerJoined = Signal.new() -- (player: Player)
PlayerService.PlayerLeft = Signal.new() -- (player: Player), fired while the player is still in Players
PlayerService.CharacterSpawned = Signal.new() -- (player: Player, character: Model)
PlayerService.CharacterRemoving = Signal.new() -- (player: Player, character: Model)
PlayerService.PlayerDied = Signal.new() -- (player: Player)

local playerMaids: { [Player]: Maid.Maid } = {}
local characterMaids: { [Player]: Maid.Maid } = {}

-- The living character's Humanoid and root part, or nil if the player is dead or has no character.
function PlayerService.GetAliveCharacter(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

function PlayerService.IsAlive(player: Player): boolean
	local humanoid = PlayerService.GetAliveCharacter(player)
	return humanoid ~= nil
end

function PlayerService.GetAlivePlayers(excluding: Player?): { Player }
	local alive = {}
	for _, player in Players:GetPlayers() do
		if player ~= excluding and PlayerService.IsAlive(player) then
			table.insert(alive, player)
		end
	end
	return alive
end

function PlayerService.GetAliveRoots(): { BasePart }
	local roots = {}
	for _, player in Players:GetPlayers() do
		local _, root = PlayerService.GetAliveCharacter(player)
		if root then
			table.insert(roots, root)
		end
	end
	return roots
end

-- Every character model, alive or not; used to build raycast ignore lists.
function PlayerService.GetCharacters(): { Instance }
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	return characters
end

function PlayerService.Spawn(player: Player)
	task.spawn(function()
		if player.Parent == Players then
			player:LoadCharacterAsync()
		end
	end)
end

function PlayerService.SpawnAll()
	for _, player in Players:GetPlayers() do
		PlayerService.Spawn(player)
	end
end

function PlayerService.RespawnDead()
	for _, player in Players:GetPlayers() do
		if not PlayerService.IsAlive(player) then
			PlayerService.Spawn(player)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local previous = characterMaids[player]
	if previous then
		previous:Destroy()
	end
	local maid = Maid.new()
	characterMaids[player] = maid

	local humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
	if not rawequal(characterMaids[player], maid) then
		return -- respawned again while waiting
	end
	if humanoid and humanoid:IsA("Humanoid") then
		Ragdoll.Prepare(humanoid)
		Flinch.Enable(character)
		Jump.Apply(humanoid)
		maid:GiveTask(humanoid.Died:Connect(function()
			Ragdoll.Enable(character)
			PlayerService.PlayerDied:Fire(player)
		end))
	end
	PlayerService.CharacterSpawned:Fire(player, character)
end

local function onCharacterRemoving(player: Player, character: Model)
	local maid = characterMaids[player]
	if maid then
		maid:Destroy()
		characterMaids[player] = nil
	end
	PlayerService.CharacterRemoving:Fire(player, character)
end

local function onPlayerAdded(player: Player)
	if playerMaids[player] then
		return
	end
	local maid = Maid.new()
	playerMaids[player] = maid
	maid:GiveTask(player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end))
	maid:GiveTask(player.CharacterRemoving:Connect(function(character: Model)
		onCharacterRemoving(player, character)
	end))
	PlayerService.PlayerJoined:Fire(player)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	PlayerService.PlayerLeft:Fire(player)
	for _, maids in { playerMaids, characterMaids } do
		local maid = maids[player]
		if maid then
			maid:Destroy()
			maids[player] = nil
		end
	end
end

function PlayerService.Init()
	Players.CharacterAutoLoads = false
end

function PlayerService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
