--!strict
-- Plays a weapon's optional shot sound from its handle, and the dry-fire click when it is empty.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameRules = require(Shared.Definitions.GameRules)
local Types = require(Shared.Types)

local VOLUME = 0.3 -- gunshot volume
local LIFETIME = 2

local ShotSound = {}

local function play(soundId: string, volume: number, parent: Instance)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

function ShotSound.Play(definition: Types.WeaponDefinition, handle: Instance?)
	local soundId = definition.Effects.Sound
	if not soundId or soundId == "" or not handle then
		return
	end
	play(soundId, VOLUME, handle)
end

function ShotSound.PlayEmpty(handle: Instance?)
	if handle then
		play(GameRules.EmptyFireSound, GameRules.EmptyFireSoundVolume, handle)
	end
end

return ShotSound
