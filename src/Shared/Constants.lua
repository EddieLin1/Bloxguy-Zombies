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
		ComboExpire = "ComboExpire",
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

	Tags = {
		EnemySpawn = "EnemySpawn", -- tag parts in Studio to make them zombie spawn points
		Pickup = "Pickup", -- set by the server on every crate; clients animate tagged parts
	},

	INFINITE_AMMO = -1, -- value of the Ammo attribute for weapons with no MaxAmmo
}
