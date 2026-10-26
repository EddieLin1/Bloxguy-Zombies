--!strict
-- Scales how high a Humanoid can jump. Used for both players and zombies so they stay in step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRules = require(ReplicatedStorage.Shared.Definitions.GameRules)

local Jump = {}

-- Applies GameRules.JumpHeightMultiplier once to a freshly spawned Humanoid.
function Jump.Apply(humanoid: Humanoid)
	local multiplier = GameRules.JumpHeightMultiplier
	if humanoid.UseJumpPower then
		-- Jump height grows with the square of JumpPower, so scale the power by the square root
		humanoid.JumpPower *= math.sqrt(multiplier)
	else
		humanoid.JumpHeight *= multiplier
	end
end

return Jump
