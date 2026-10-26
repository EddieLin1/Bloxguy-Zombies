--!strict
-- Hit flinches for zombies and players. The server only stamps when and which way a model was hit;
-- every client draws the flinch itself (BodyPoseController), so it is smooth and costs no physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Flinch = {}

-- Marks a zombie or character as one that clients should play flinches on.
function Flinch.Enable(model: Model)
	model:AddTag(Constants.Tags.Flinchable)
end

-- `direction` is the way the hit pushed (for example the bullet's direction).
function Flinch.Trigger(model: Model, direction: Vector3)
	model:SetAttribute(Constants.Attributes.FlinchDirection, direction)
	model:SetAttribute(Constants.Attributes.Flinch, workspace:GetServerTimeNow())
end

return Flinch
