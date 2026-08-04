local HttpService = game:GetService("HttpService")

local Env = require("Env")

local Config = {}
Config.__index = Config

local MAX_NAME = 24

local function clean(name: string): string?
	local trimmed = string.gsub(tostring(name or ""), "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	trimmed = string.gsub(trimmed, "[^%w%-_ ]", "")

	if trimmed == "" then
		return nil
	end

	return string.sub(trimmed, 1, MAX_NAME)
end

local function encode(value: any): any
	if typeof(value) == "Color3" then
		return { __umbra = "Color3", r = value.R, g = value.G, b = value.B }
	end

	if typeof(value) == "EnumItem" then
		return { __umbra = "Enum", name = value.Name }
	end

	if type(value) == "table" then
		local copy = {}
		for index, item in value do
			copy[index] = encode(item)
		end
		return copy
	end

	return value
end

local function decode(value: any): any
	if type(value) == "table" then
		if value.__umbra == "Color3" then
			local red = tonumber(value.r) or 0
			local green = tonumber(value.g) or 0
			local blue = tonumber(value.b) or 0
			return Color3.new(
				math.clamp(red, 0, 1),
				math.clamp(green, 0, 1),
				math.clamp(blue, 0, 1)
			)
		end

		if value.__umbra == "Enum" then
			return tostring(value.name)
		end

		local copy = {}
		for index, item in value do
			copy[index] = decode(item)
		end
		return copy
	end

	return value
end

function Config.attach(window, opts)
	local settings = opts or {}

	if window.config then
		return window.config
	end

	local self = setmetatable({}, Config)
	self.window = window
	self.folder = tostring(settings.Folder or "Umbra")
	self.scope = if settings.Global then "global" else "place_" .. tostring(game.PlaceId)
	self.root = self.folder .. "/" .. self.scope
	self.available = Env.hasFiles
	self.changed = {}

	if self.available then
		Env.ensureFolder(self.root)
	end

	window.config = self

	if settings.Autoload then
		window.trove:Add(task.defer(function()
			if not window.gui or window.gui.Parent == nil then
				return
			end
			self:LoadAutoload()
		end))
	end

	return self
end

function Config:path(name: string): string
	return self.root .. "/" .. name .. ".json"
end

function Config:Available(): boolean
	return self.available
end

function Config:List(): { string }
	if not self.available then
		return {}
	end

	local names = {}

	for _, entry in Env.list(self.root) do
		local file = string.match(tostring(entry), "([^/\\]+)%.json$")
		if file and file ~= "autoload" then
			table.insert(names, file)
		end
	end

	table.sort(names)
	return names
end

function Config:Save(rawName: string): (boolean, string?)
	if not self.available then
		return false, "no file access"
	end

	local name = clean(rawName)
	if not name then
		return false, "invalid name"
	end

	local payload = {}

	for flag, handle in self.window.registry:each() do
		if handle.kind ~= "button" then
			local ok, value = pcall(function()
				return handle:Get()
			end)
			if ok and value ~= nil then
				payload[flag] = encode(value)
			end
		end
	end

	local encoded
	local ok, err = pcall(function()
		encoded = HttpService:JSONEncode({ version = 1, values = payload })
	end)

	if not ok or not encoded then
		return false, "encode failed: " .. tostring(err)
	end

	Env.ensureFolder(self.root)
	local written, writeErr = Env.write(self:path(name), encoded)

	if not written then
		return false, writeErr
	end

	return true, name
end

function Config:Load(rawName: string): (boolean, string?, number?)
	if not self.available then
		return false, "no file access"
	end

	local name = clean(rawName)
	if not name then
		return false, "invalid name"
	end

	local contents = Env.read(self:path(name))
	if not contents then
		return false, "not found"
	end

	local decoded
	local ok = pcall(function()
		decoded = HttpService:JSONDecode(contents)
	end)

	if not ok or type(decoded) ~= "table" or type(decoded.values) ~= "table" then
		return false, "corrupt file"
	end

	local skipped = 0

	for flag, stored in decoded.values do
		local handle = self.window.registry:get(flag)

		if handle and handle.kind ~= "button" then
			local applied, err = pcall(function()
				if handle.Restore then
					handle:Restore(decode(stored))
				else
					handle:Set(decode(stored), true)
					if handle.changed then
						handle.changed:Fire(handle.value)
					end
					if type(handle.callback) == "function" then
						local fired, callErr = pcall(handle.callback, handle.value)
						if not fired then
							warn("[Umbra] callback for '" .. tostring(flag) .. "' failed: " .. tostring(callErr))
						end
					end
				end
			end)

			if not applied then
				skipped += 1
				warn("[Umbra] config value for '" .. tostring(flag) .. "' was rejected: " .. tostring(err))
			end
		else
			skipped += 1
		end
	end

	return true, name, skipped
end

function Config:Delete(rawName: string): boolean
	if not self.available then
		return false
	end

	local name = clean(rawName)
	if not name then
		return false
	end

	return Env.delete(self:path(name))
end

function Config:SetAutoload(rawName: string?): boolean
	if not self.available then
		return false
	end

	local path = self.root .. "/autoload.txt"

	if rawName == nil then
		return Env.delete(path)
	end

	local name = clean(rawName)
	if not name then
		return false
	end

	return (Env.write(path, name))
end

function Config:GetAutoload(): string?
	if not self.available then
		return nil
	end
	local contents = Env.read(self.root .. "/autoload.txt")
	if not contents then
		return nil
	end
	return clean(contents)
end

function Config:LoadAutoload(): boolean
	local name = self:GetAutoload()
	if not name then
		return false
	end
	return (self:Load(name))
end

function Config.section(page, opts)
	local window = page.window
	local settings = opts or {}
	local config = window.config or Config.attach(window, settings)

	local section = page:Section(settings.Title or "Configs", settings)
	local Notify = require("Notify")

	if not config:Available() then
		section:Label({
			Text = "Your executor has no file access, so configs are unavailable.",
			Wrap = true,
		})
		return section
	end

	local name = section:Input({
		Text = "Name",
		Placeholder = "default",
		MaxLength = MAX_NAME,
	})

	local saved = section:Dropdown({
		Text = "Saved",
		Options = config:List(),
	})

	local function refresh()
		saved:SetOptions(config:List())
	end

	section:Button({
		Text = "Save",
		Callback = function()
			local ok, result = config:Save(name:Get())
			refresh()
			Notify.push(window, {
				Title = if ok then "Config saved" else "Save failed",
				Text = tostring(result),
				Duration = 4,
			})
		end,
	})

	section:Button({
		Text = "Load",
		Callback = function()
			local target = saved:Get() or name:Get()
			local ok, result, skipped = config:Load(target)
			Notify.push(window, {
				Title = if ok then "Config loaded" else "Load failed",
				Text = if ok and skipped and skipped > 0
					then tostring(result) .. " (" .. tostring(skipped) .. " skipped)"
					else tostring(result),
				Duration = 4,
			})
		end,
	})

	section:Button({
		Text = "Delete",
		Confirm = true,
		Callback = function()
			local target = saved:Get()
			if not target then
				Notify.push(window, { Title = "Pick a config first", Duration = 3 })
				return
			end
			local ok = config:Delete(target)
			refresh()
			Notify.push(window, {
				Title = if ok then "Config deleted" else "Delete failed",
				Text = tostring(target),
				Duration = 4,
			})
		end,
	})

	section:Button({
		Text = "Refresh list",
		Callback = refresh,
	})

	section:Toggle({
		Text = "Autoload selected",
		Default = config:GetAutoload() ~= nil,
		Callback = function(on)
			if on then
				local target = saved:Get()
				if not target then
					Notify.push(window, { Title = "Pick a config first", Duration = 3 })
					return
				end
				local stored = config:SetAutoload(target)
				Notify.push(window, {
					Title = if stored then "Autoload set" else "Autoload failed",
					Text = target,
					Duration = 3,
				})
			else
				local cleared = config:SetAutoload(nil)
				Notify.push(window, {
					Title = if cleared then "Autoload cleared" else "Could not clear autoload",
					Duration = 3,
				})
			end
		end,
	})

	return section
end

return Config
