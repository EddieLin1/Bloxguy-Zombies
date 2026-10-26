--!strict
-- Plays a weapon's optional shot sound from its handle.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local VOLUME = 0.6
local LIFETIME = 2

local ShotSound = {}

function ShotSound.Play(definition: Types.WeaponDefinition, handle: Instance?)
	local soundId = definition.Effects.Sound
	if not soundId or soundId == "" or not handle then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = VOLUME
	sound.Parent = handle
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

return ShotSound
