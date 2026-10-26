--!strict
-- Names shared by server and client: attributes, game states, workspace folders and tags.

return {
	Attributes = {
		-- On ReplicatedStorage (match state)
		GameState = "GameState",
		Wave = "Wave",
		Countdown = "Countdown",
		EnemiesRemaining = "EnemiesRemaining",
		-- On each Player
		Points = "Points",
		Kills = "Kills",
		Combo = "Combo",
		ComboExpire = "ComboExpire",		-- On each zombie model and player character (see Server/Util/Flinch)
		Flinch = "Flinch", -- workspace:GetServerTimeNow() of the latest hit; changes trigger the flinch
		FlinchDirection = "FlinchDirection", -- Vector3: which way the hit pushed
		CrawlPitch = "CrawlPitch", -- degrees a zombie leans forward while crawling over a pile (0 = upright)
		Legless = "Legless", -- true once a zombie has lost a leg; it crawls and leaves a blood trail
		-- On a zombie killed by a headshot that rolled a gore death
		HeadshotDeath = "HeadshotDeath", -- "Explode" or "PopOff"
		HeadshotDeathPosition = "HeadshotDeathPosition", -- Vector3: where the head was
		-- On each supply crate
		ExpiresAt = "ExpiresAt", -- workspace:GetServerTimeNow() when the crate disappears
		-- On each weapon Tool
		WeaponId = "WeaponId",
		Ammo = "Ammo",
	},

	GameStates = {
		Waiting = "Waiting",
		Intermission = "Intermission",
		WaveActive = "WaveActive",
		WaveComplete = "WaveComplete",
		GameOver = "GameOver",
	},

	Folders = {
		Enemies = "Enemies",
		Pickups = "Pickups",
	},

	-- Registered by EnemyService. Shots ignore zombie bumpers (the invisible collision cylinder round
	-- each zombie), so bullets and the aim ray hit the visible body: heads and limbs.
	CollisionGroups = {
		Bumper = "ZombieBumper",
		Shots = "Shots",
	},

	Tags = {
		EnemySpawn = "EnemySpawn", -- tag parts in Studio to make them zombie spawn points
		Pickup = "Pickup", -- set by the server on every crate; clients animate tagged parts
		Flinchable = "Flinchable", -- zombies and characters that clients play hit flinches on
		Enemy = "Enemy", -- every zombie model (living or corpse); clients play gore effects on these
	},

	INFINITE_AMMO = -1, -- value of the Ammo attribute for weapons with no MaxAmmo
}
