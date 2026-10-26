--!strict
-- Match-wide tunables. Weapon, enemy, wave and pickup numbers live in their own definition modules.

return {
	-- Round flow (seconds)
	Intermission = 10,
	WaveBreak = 6,
	GameOverTime = 8,
	MatchStartDelay = 2, -- after everyone spawns, before wave 1

	-- Enemies
	ClimbRiseSpeed = 1.5, -- studs/s a zombie claws its way up a pile it is allowed to climb (no hopping)
	ZombieHopChance = 0.05, -- chance per AI update (5 a second) that a chasing zombie does a tiny hop, just for looks
	ZombieStuckHopChance = 0.25, -- same, while pinned against a wall or jammed in the crowd (about every 0.8 s)
	ZombieBumperDiameter = 3, -- studs: invisible collision cylinder round each zombie, so a horde packs out wider
	ZombieBumperHeight = 4, -- studs, centred on the torso (stops short of the feet so it never scrapes the floor)
	ZombieHopHeight = 2.2, -- studs of that hop (players jump ~3.6)
	ClimbSpeedMultiplier = 0.2, -- zombies climbing or crawling over other zombies or corpses move at this share of their speed
	CorpseFreezeDelay = 1.5, -- seconds after death a ragdoll locks in place as an obstacle (CorpseTime is per zombie)
	SpawnDistanceMin = 50, -- ring around a player, used when the map has no spawn points
	SpawnDistanceMax = 90,

	-- Movement (players and zombies)
	JumpHeightMultiplier = 0.5, -- share of Roblox's default jump height (0.5 = half, about 3.6 studs)

	-- Player health
	HealthRegenDelay = 5, -- seconds without taking damage before healing starts
	HealthRegenPerSecond = 5,
	PlayerStaggerSlow = 0.5, -- 0..1: fraction of walk speed lost briefly when you take damage
	PlayerStaggerDuration = 0.35, -- seconds that slow lasts
	HurtSound = "rbxasset://sounds/ouch.ogg", -- built-in Roblox sound, played when you take damage
	HurtSoundVolume = 0.6,

	-- Combat and scoring
	HeadshotMultiplier = 1.5,
	HeadExplodeChance = 0.5, -- on a headshot kill: head explodes, blood pours from the neck
	HeadPopChance = 0.5, -- on a headshot kill: head pops off, blood pours from head and neck (else a normal death)
	HeadPopForce = 45, -- studs/s the popped head flies in the shot's direction
	HeadPopLift = 25, -- studs/s upward on top of that
	BloodPourTime = 3, -- seconds blood keeps pouring from a neck, head, stump or severed limb, tapering off
	LimbHealthFraction = 0.35, -- an arm or leg is blown off after taking this share of the zombie's max health
	LimbPopForce = 30, -- studs/s a severed limb flies along the shot
	LimbPopLift = 15, -- studs/s upward on top of that
	LeglessSpeedMultiplier = 0.4, -- a zombie missing a leg crawls at this share of its speed
	LeglessCrawlPitch = 80, -- degrees it lies forward while crawling (90 = flat)
	LeglessHipHeight = -1.8, -- how far its body drops toward the ground (R6 hip offset, studs)
	-- Upload the images in assets/ to Roblox and put their image ids here, e.g. "rbxassetid://123".
	-- Any left empty are built from a few red ovals in a random splatter shape instead.
	BloodSplatterImages = {
		Small = "", -- assets/BloodSplatterSmall.png: drips, small hits
		Medium = "", -- assets/BloodSplatterMedium.png: bullet hits, trails, paint
		Large = "", -- assets/BloodSplatterLarge.png: exploding heads, heavily painted ground
		Pool = "", -- assets/BloodPool.png: where a zombie died
	},
	StainLifetime = 5, -- seconds a fresh blood stain stays wet before drying into paint
	BloodStainLimit = 20, -- dried stains it takes to turn a patch of ground fully dark red (paint is permanent and spreads)
	StaggerDuration = 0.45, -- seconds a hit zombie stays slowed by the weapon's StoppingPower
	HeadshotSound = "rbxassetid://128633263668964", -- played only to the shooter on a headshot
	HeadshotSoundVolume = 1,
	EmptyFireSound = "rbxassetid://139337377661709", -- dry-fire click when holding fire with no ammo
	EmptyFireSoundVolume = 0.8,
	ComboTimeout = 3, -- seconds after a kill before the combo starts counting down
	ComboDecayInterval = 0.15, -- once counting down, seconds per combo point lost
	PointsPerKill = 10, -- points per kill = PointsPerKill * current combo
}
