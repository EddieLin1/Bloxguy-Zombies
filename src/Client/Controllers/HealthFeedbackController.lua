--!strict
-- Feedback for health changes on every character:
-- * Any health gain (regen, supply crates, anything else): green crosses rise from the healed
--   character (yours and teammates'), more for bigger heals. Fires LocalHealed when your own
--   character heals so the UI can pulse the green screen border.
-- * Your own character taking damage: a hurt sound (throttled so a crowd of zombies is not a din).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Util.Maid)
local Signal = require(Shared.Util.Signal)
local Effects = script.Parent.Parent.Effects
local HealCrosses = require(Effects.HealCrosses)
local HitSound = require(Effects.HitSound)

local MIN_CHANGE = 0.5 -- ignore tiny rounding changes
local HEALTH_PER_CROSS = 5 -- a +25 crate gives 5 crosses; a regen tick gives 1
local MAX_CROSSES = 6
local HURT_SOUND_MIN_INTERVAL = 0.2 -- seconds between hurt sounds

local player = Players.LocalPlayer

local HealthFeedbackController = {}

HealthFeedbackController.LocalHealed = Signal.new() -- (amount: number)

local playerMaids: { [Player]: Maid.Maid } = {}
local lastHurtSound = 0

local function onHealed(owner: Player, root: BasePart, amount: number)
	local crosses = math.clamp(math.ceil(amount / HEALTH_PER_CROSS), 1, MAX_CROSSES)
	for _ = 1, crosses do
		HealCrosses.Spawn(root)
	end
	if owner == player then
		HealthFeedbackController.LocalHealed:Fire(amount)
	end
end

local function onDamaged(owner: Player)
	if owner ~= player then
		return
	end
	local now = os.clock()
	if now - lastHurtSound >= HURT_SOUND_MIN_INTERVAL then
		lastHurtSound = now
		HitSound.PlayHurt()
	end
end

local function watchCharacter(owner: Player, character: Model, maid: Maid.Maid)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if owner.Character ~= character then
		return -- respawned while waiting
	end
	if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
		return
	end
	local lastHealth = humanoid.Health
	maid:GiveTask(humanoid.HealthChanged:Connect(function(health: number)
		local change = health - lastHealth
		lastHealth = health
		if change >= MIN_CHANGE and health > 0 then
			onHealed(owner, root, change)
		elseif change <= -MIN_CHANGE then
			onDamaged(owner)
		end
	end))
end

local function onPlayerAdded(owner: Player)
	local playerMaid = Maid.new()
	playerMaids[owner] = playerMaid
	local characterMaid = playerMaid:GiveTask(Maid.new())
	local function onCharacterAdded(character: Model)
		characterMaid:Destroy()
		watchCharacter(owner, character, characterMaid)
	end
	playerMaid:GiveTask(owner.CharacterAdded:Connect(onCharacterAdded))
	if owner.Character then
		task.spawn(onCharacterAdded, owner.Character)
	end
end

local function onPlayerRemoving(owner: Player)
	local playerMaid = playerMaids[owner]
	if playerMaid then
		playerMaid:Destroy()
		playerMaids[owner] = nil
	end
end

function HealthFeedbackController.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, owner in Players:GetPlayers() do
		onPlayerAdded(owner)
	end
end

return HealthFeedbackController
