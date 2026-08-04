local Env = require("Env")
local Signal = require("Signal")
local Window = require("Window")
local Notify = require("Notify")
local Dialog = require("Dialog")
local Keybinds = require("Keybinds")
local Watermark = require("Watermark")

local Umbra = {}

Umbra.version = "1.0.0"
Umbra.window = nil
Umbra.unloaded = false
Umbra.unloading = Signal.new()

local function firstLine(message: string): string
	local line = string.split(tostring(message), "\n")[1]
	if #line > 120 then
		return string.sub(line, 1, 117) .. "..."
	end
	return line
end

Signal.onError = function(message)
	warn("[Umbra] " .. tostring(message))

	local window = Umbra.window
	if window and window.gui and window.gui.Parent then
		Notify.push(window, {
			Title = "Script error",
			Text = firstLine(message),
			Duration = 8,
		})
	end
end

function Umbra:Window(opts)
	if self.window then
		self.window:Destroy()
		self.window = nil
	end

	self.unloaded = false
	self.window = Window.new(opts or {})

	return self.window
end

function Umbra:Notify(opts)
	if not self.window then
		warn("[Umbra] Notify called before a window exists")
		return nil
	end
	return Notify.push(self.window, opts or {})
end

function Umbra:Dialog(opts)
	if not self.window then
		warn("[Umbra] Dialog called before a window exists")
		return nil
	end
	return Dialog.confirm(self.window, opts or {})
end

function Umbra:Watermark(opts)
	if not self.window then
		warn("[Umbra] Watermark called before a window exists")
		return nil
	end
	return Watermark.attach(self.window, opts or {})
end

function Umbra:Keybinds(visible: boolean?)
	if not self.window then
		warn("[Umbra] Keybinds called before a window exists")
		return nil
	end
	return Keybinds.show(self.window, visible ~= false)
end

function Umbra:OnUnload(callback)
	return self.unloading:Connect(callback)
end

function Umbra:Unload()
	if self.unloaded then
		return
	end
	self.unloaded = true

	self.unloading:Fire()

	if self.window then
		self.window:Destroy()
		self.window = nil
	end

	self.unloading:Destroy()
	self.unloading = Signal.new()

	Env.remember("__UMBRA", nil)
end

do
	local previous = Env.recall("__UMBRA")
	if type(previous) == "table" and type(previous.Unload) == "function" and previous ~= Umbra then
		pcall(function()
			previous:Unload()
		end)
	end
	if not Env.remember("__UMBRA", Umbra) then
		warn(
			"[Umbra] could not install the reload guard on this executor ("
				.. tostring(Env.executor)
				.. "). Re-running the loader may leave two menus open — call Umbra:Unload() first."
		)
	end
end

return Umbra
