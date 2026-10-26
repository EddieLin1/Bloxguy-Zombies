--!strict
-- Reuses Instances that are created and thrown away often (bullet tracers, effects).

local Pool = {}
Pool.__index = Pool

export type Pool = typeof(setmetatable({} :: {
	_free: { Instance },
	_factory: () -> Instance,
	_reset: (Instance) -> (),
	_maxSize: number,
}, Pool))

function Pool.new(factory: () -> Instance, reset: (Instance) -> (), maxSize: number): Pool
	return setmetatable({
		_free = {},
		_factory = factory,
		_reset = reset,
		_maxSize = maxSize,
	}, Pool)
end

function Pool.Get(self: Pool): Instance
	return table.remove(self._free) or self._factory()
end

-- Resets the object and keeps it for reuse, or destroys it when the pool is full.
function Pool.Release(self: Pool, object: Instance)
	self._reset(object)
	if #self._free < self._maxSize then
		table.insert(self._free, object)
	else
		object:Destroy()
	end
end

return Pool
