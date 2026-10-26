--!strict
-- Lightweight Lua signal for events between modules on the same side.
-- Unlike BindableEvent it passes tables (class objects) through untouched.
-- Each handler runs in its own thread, so a yielding handler does not block the others.

type Handler = (...any) -> ()

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable({} :: {
	Connected: boolean,
	_handler: Handler,
	_list: { any },
}, Connection))

function Connection.Disconnect(self: Connection)
	if not self.Connected then
		return
	end
	self.Connected = false
	local index = table.find(self._list, self)
	if index then
		table.remove(self._list, index)
	end
end

Connection.Destroy = Connection.Disconnect

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _connections: { Connection } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _connections = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: Handler): Connection
	local connection = setmetatable({
		Connected = true,
		_handler = handler,
		_list = self._connections,
	}, Connection)
	table.insert(self._connections, connection)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

-- Yields until the next Fire and returns its arguments.
function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	local connection: Connection? = nil
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: Signal)
	for _, connection in table.clone(self._connections) do
		connection:Disconnect()
	end
end

Signal.Destroy = Signal.DisconnectAll

return Signal
