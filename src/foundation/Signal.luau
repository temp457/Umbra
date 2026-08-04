local Signal = {}
Signal.__index = Signal

Signal.onError = function(message: string)
	warn("[Umbra] " .. message)
end

function Signal.new()
	return setmetatable({
		_handlers = {},
		_dead = false,
	}, Signal)
end

function Signal:Connect(handler)
	if type(handler) ~= "function" then
		error("Umbra: Signal:Connect expects a function, got " .. typeof(handler), 2)
	end

	if self._dead then
		return function() end
	end

	local entry = { fn = handler }
	table.insert(self._handlers, entry)

	local disconnected = false
	return function()
		if disconnected then
			return
		end
		disconnected = true
		entry.fn = nil
		local index = table.find(self._handlers, entry)
		if index then
			table.remove(self._handlers, index)
		end
	end
end

function Signal:Fire(...)
	if self._dead then
		return
	end

	local snapshot = table.clone(self._handlers)
	for _, entry in snapshot do
		local handler = entry.fn
		if handler then
			local ok, err = xpcall(handler, function(message)
				return tostring(message) .. "\n" .. debug.traceback(nil, 2)
			end, ...)
			if not ok then
				Signal.onError(err)
			end
		end
	end
end

function Signal:Count(): number
	return #self._handlers
end

function Signal:Destroy()
	self._dead = true
	table.clear(self._handlers)
end

return Signal
