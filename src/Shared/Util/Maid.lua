--!strict
-- Collects connections, instances, threads, functions and objects with Destroy, and cleans them all up at once.

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { any } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid.GiveTask(self: Maid, item: any): any
	table.insert(self._tasks, item)
	return item
end

-- Cleans up everything given so far. The maid can be reused afterwards.
function Maid.Destroy(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for _, item in tasks do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		elseif kind == "thread" then
			if coroutine.status(item) ~= "dead" then
				task.cancel(item)
			end
		elseif kind == "table" and typeof(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

return Maid
