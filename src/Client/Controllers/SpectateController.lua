--!strict
-- After dying, watch a living teammate until the next spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Shared.Util.Maid)

local SPECTATE_DELAY = 2

local player = Players.LocalPlayer

local SpectateController = {}

local characterMaid = Maid.new()

local function spectateTeammate(character: Model)
	if player.Character ~= character then
		return -- already respawned
	end
	for _, other in Players:GetPlayers() do
		local otherCharacter = other ~= player and other.Character
		local humanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			workspace.CurrentCamera.CameraSubject = humanoid
			return
		end
	end
end

local function onCharacterAdded(character: Model)
	characterMaid:Destroy()
	local humanoid = character:WaitForChild("Humanoid")
	if not humanoid:IsA("Humanoid") then
		return
	end
	characterMaid:GiveTask(humanoid.Died:Connect(function()
		characterMaid:GiveTask(task.delay(SPECTATE_DELAY, spectateTeammate, character))
	end))
end

function SpectateController.Start()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return SpectateController
