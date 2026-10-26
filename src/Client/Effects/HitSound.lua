--!strict
-- The headshot confirmation sound. Plays as 2D (same volume wherever the zombie was), only for the
-- player who landed the shot.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameRules = require(ReplicatedStorage.Shared.Definitions.GameRules)

local LIFETIME = 3 -- seconds before a played copy is cleaned up

local HitSound = {}

local headshotTemplate = Instance.new("Sound")
headshotTemplate.Name = "HeadshotSound"
headshotTemplate.SoundId = GameRules.HeadshotSound
headshotTemplate.Volume = GameRules.HeadshotSoundVolume

-- A fresh copy each time, so quick headshots overlap instead of cutting each other off.
function HitSound.PlayHeadshot()
	local sound = headshotTemplate:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

return HitSound
