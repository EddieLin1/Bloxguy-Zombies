--!strict
-- Random bullet spread, shared so the client's predicted tracers match the server's rays in style.

local Spread = {}

function Spread.Apply(direction: Vector3, degrees: number, rng: Random): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees)
	local aim = CFrame.lookAt(Vector3.zero, direction)
	return (aim * CFrame.Angles(rng:NextNumber(-angle, angle), rng:NextNumber(-angle, angle), 0)).LookVector
end

return Spread
