local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({
		byFlag = {},
		order = {},
	}, Registry)
end

function Registry:assertFree(flag: string)
	if type(flag) ~= "string" or flag == "" then
		error("Umbra: Flag must be a non-empty string, got " .. typeof(flag), 0)
	end

	if self.byFlag[flag] then
		error(
			"Umbra: duplicate Flag '"
				.. flag
				.. "'. Every Flag must be unique within a window, otherwise the earlier element becomes unreachable and unsaveable.",
			0
		)
	end
end

function Registry:register(flag: string, handle)
	self:assertFree(flag)

	self.byFlag[flag] = handle
	table.insert(self.order, flag)
end

function Registry:unregister(flag: string, handle)
	if self.byFlag[flag] ~= handle then
		return
	end

	self.byFlag[flag] = nil

	local index = table.find(self.order, flag)
	if index then
		table.remove(self.order, index)
	end
end

function Registry:get(flag: string)
	return self.byFlag[flag]
end

function Registry:each()
	local flags = table.clone(self.order)
	local index = 0

	local function step()
		index += 1

		local flag = flags[index]
		if not flag then
			return nil
		end

		local handle = self.byFlag[flag]
		if handle == nil then
			return step()
		end

		return flag, handle
	end

	return step
end

function Registry:values(): { [string]: any }
	local snapshot = {}
	for flag, handle in self.byFlag do
		snapshot[flag] = handle:Get()
	end
	return snapshot
end

function Registry:count(): number
	return #self.order
end

function Registry:Destroy()
	table.clear(self.byFlag)
	table.clear(self.order)
end

return Registry
