--!strict
-- Server-side rate limiting and abuse tracking for client -> server remotes.
-- Failed validation is a silent return for the client; repeated failures are logged here.

local Players = game:GetService("Players")

local STRIKE_LOG_EVERY = 20 -- log once per this many rejected requests from one player

local RemoteGuard = {}

local lastCall: { [Player]: { [string]: number } } = {}
local strikes: { [Player]: number } = {}

local function getCalls(player: Player): { [string]: number }
	local existing = lastCall[player]
	if existing then
		return existing
	end
	local created = {}
	lastCall[player] = created
	return created
end

-- True if at least minInterval seconds passed since this player's last allowed call with this key.
function RemoteGuard.Allow(player: Player, key: string, minInterval: number): boolean
	local now = os.clock()
	local calls = getCalls(player)
	local last = calls[key]
	if last and now - last < minInterval then
		return false
	end
	calls[key] = now
	return true
end

-- Records a request that failed validation.
function RemoteGuard.Reject(player: Player, reason: string)
	local count = (strikes[player] or 0) + 1
	strikes[player] = count
	if count % STRIKE_LOG_EVERY == 0 then
		warn(`[RemoteGuard] {player.Name} ({player.UserId}) sent {count} invalid requests. Latest: {reason}`)
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastCall[player] = nil
	strikes[player] = nil
end)

return RemoteGuard
