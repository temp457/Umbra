local Trove = {}
Trove.__index = Trove

local function dispose(item)
	local kind = typeof(item)

	if kind == "Instance" then
		if item:IsA("TweenBase") then
			pcall(function()
				item:Cancel()
			end)
		end
		pcall(function()
			item:Destroy()
		end)
		return
	end

	if kind == "RBXScriptConnection" then
		pcall(function()
			item:Disconnect()
		end)
		return
	end

	if kind == "function" then
		local ok, err = pcall(item)
		if not ok then
			warn("[Umbra] cleanup function errored: " .. tostring(err))
		end
		return
	end

	if kind == "thread" then
		if item ~= coroutine.running() then
			pcall(task.cancel, item)
		end
		return
	end

	if kind == "table" then
		local cleaner = rawget(item, "Destroy") or rawget(item, "Clean")
		if type(cleaner) ~= "function" and getmetatable(item) then
			cleaner = item.Destroy or item.Clean
		end
		if type(cleaner) == "function" then
			local ok, err = pcall(cleaner, item)
			if not ok then
				warn("[Umbra] cleanup method errored: " .. tostring(err))
			end
		end
		return
	end
end

function Trove.new()
	return setmetatable({
		_items = {},
		_cleaning = false,
		_dead = false,
	}, Trove)
end

function Trove:Add(item)
	if item == nil then
		return nil
	end
	if self._dead then
		dispose(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

function Trove:Connect(event, handler)
	return self:Add(event:Connect(handler))
end

function Trove:Extend()
	return self:Add(Trove.new())
end

function Trove:Remove(item): boolean
	local index = table.find(self._items, item)
	if not index then
		return false
	end
	table.remove(self._items, index)
	return true
end

function Trove:Clean()
	if self._cleaning then
		return
	end
	self._cleaning = true

	local items = self._items
	self._items = {}

	for index = #items, 1, -1 do
		dispose(items[index])
	end

	self._cleaning = false
end

function Trove:Destroy()
	self._dead = true
	self:Clean()
end

return Trove
