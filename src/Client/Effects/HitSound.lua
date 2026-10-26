--!strict
-- 2D feedback sounds for the local player only (same volume wherever the action happened):
-- the headshot confirmation crunch, and the hurt sound when you take damage.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameRules = require(ReplicatedStorage.Shared.Definitions.GameRules)

local LIFETIME = 3 -- seconds before a played copy is cleaned up

local HitSound = {}

local function makeTemplate(name: string, soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	return sound
end

local headshotTemplate = makeTemplate("HeadshotSound", GameRules.HeadshotSound, GameRules.HeadshotSoundVolume)
local hurtTemplate = makeTemplate("HurtSound", GameRules.HurtSound, GameRules.HurtSoundVolume)

-- A fresh copy each time, so quick repeats overlap instead of cutting each other off.
local function play(template: Sound)
	local sound = template:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

function HitSound.PlayHeadshot()
	play(headshotTemplate)
end

function HitSound.PlayHurt()
	play(hurtTemplate)
end

return HitSound
