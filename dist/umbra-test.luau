local __modules = {}
local __cache = {}

local function require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end

	local factory = __modules[name]
	if not factory then
		error("Umbra: unknown module '" .. tostring(name) .. "'", 2)
	end

	local result = factory()
	if result == nil then
		result = true
	end

	__cache[name] = result
	return result
end

__modules["Button"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Button = {}

function Button.build(section, opts)
	local handle = Element.new(section, opts, { kind = "button" })

	local marker = Create.text({
		Name = "Marker",
		Text = ">",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(10, 16),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	handle:track(marker)

	handle.armed = false
	handle.value = false

	local function disarm()
		if not handle.armed then
			return
		end
		handle.armed = false
		handle:SetText(handle.text or "")
		handle:rebase(handle.label, Theme.text[1])
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if not handle.enabled then
			return
		end

		Motion.tween(handle.frame, Motion.curve.hover, { BackgroundTransparency = 0 }, handle.trove)
		Motion.after(0.08, function()
			if handle.frame.Parent then
				Motion.tween(handle.frame, Motion.curve.hover, {
					BackgroundTransparency = if handle.hovered then 0 else 1,
				}, handle.trove)
			end
		end, handle.trove)

		if opts.Confirm and not handle.armed then
			handle.armed = true
			handle.label.Text = opts.ConfirmText or "Confirm?"
			handle:rebase(handle.label, Theme.text[0])
			Motion.after(3, disarm, handle.trove)
			return
		end

		disarm()
		Element.guard(handle, opts.Callback or opts.Func)
	end)

	handle._apply = function()
		return false
	end

	return handle
end

return Button
end

__modules["Checkbox"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Checkbox = {}

function Checkbox.build(section, opts)
	local handle = Element.new(section, opts, { kind = "checkbox" })
	local size = Theme.metrics.checkbox

	local box = Create.new("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.fill,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	Create.corner(Theme.radius.small).Parent = box

	local border = Create.stroke(Theme.line.control)
	border.Parent = box

	local mark = Create.new("Frame", {
		Name = "Mark",
		Size = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.onFill,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = box,
	})
	Create.corner(2).Parent = mark

	handle._apply = function(value)
		local on = value == true

		Motion.tween(box, Motion.curve.snap, {
			BackgroundTransparency = if on then 0 else 1,
		}, handle.trove)

		Motion.tween(border, Motion.curve.color, {
			Color = if on then Theme.fill else Theme.line.control,
		}, handle.trove)

		Motion.tween(mark, Motion.curve.state, {
			Size = if on then UDim2.fromOffset(6, 6) else UDim2.fromScale(0, 0),
		}, handle.trove)

		return on
	end

	handle._onEnabled = function(enabled)
		if enabled then
			handle._apply(handle.value)
			return
		end

		Motion.set(border, { Color = Theme.line.disabled })
		Motion.set(box, { BackgroundColor3 = Theme.line.disabled })
		Motion.set(mark, { BackgroundColor3 = Theme.surface[2] })
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			handle:Set(not handle.value)
		end
	end)

	handle:Set(opts.Default == true, true)

	return handle
end

return Checkbox
end

__modules["ColorPicker"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Signal = require("Signal")
local Element = require("Element")

local ColorPicker = {}

local HUE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})

local function toHex(color: Color3): string
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function fromHex(text: string): Color3?
	local cleaned = string.upper(string.gsub(text, "[^%x]", ""))
	if #cleaned ~= 6 then
		return nil
	end

	local red = tonumber(string.sub(cleaned, 1, 2), 16)
	local green = tonumber(string.sub(cleaned, 3, 4), 16)
	local blue = tonumber(string.sub(cleaned, 5, 6), 16)

	if not red or not green or not blue then
		return nil
	end

	return Color3.fromRGB(red, green, blue)
end

local function mount(owner, container: Instance, opts, order: number, shouldRegister: boolean)
	local metrics = Theme.metrics
	local window = owner.window

	local state = {
		window = window,
		trove = owner.trove:Extend(),
		changed = Signal.new(),
		flag = opts.Flag,
		text = opts.Text or owner.text,
		callback = opts.Callback,
		value = if typeof(opts.Default) == "Color3" then opts.Default else Color3.fromRGB(255, 255, 255),
	}

	state.trove:Add(state.changed)

	local hue, saturation, brightness = state.value:ToHSV()
	local panel: CanvasGroup? = nil
	local panelTrove = nil
	local squareRef: GuiObject? = nil
	local stripRef: GuiObject? = nil
	local draggingSquare = false
	local draggingHue = false

	local hex = Create.text({
		Name = "Hex",
		Text = toHex(state.value),
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Font = Theme.font.mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(48, 16),
		LayoutOrder = order,
		ZIndex = 3,
		Parent = container,
	})

	if owner.track then
		owner:track(hex)
	end

	local swatch = Create.button({
		Name = "Swatch",
		Text = "",
		Size = UDim2.fromOffset(
			if Theme.isTouch then metrics.swatchTouch else metrics.swatch,
			if Theme.isTouch then metrics.swatchTouch else metrics.swatch
		),
		BackgroundColor3 = state.value,
		BackgroundTransparency = 0,
		LayoutOrder = order + 1,
		ZIndex = 3,
		Parent = container,
	})
	Create.corner(Theme.radius.small).Parent = swatch

	local edge = Create.stroke(Theme.line.focus)
	edge.Parent = swatch

	state.swatch = swatch
	state.edge = edge

	local function paintChip()
		hex.Text = toHex(state.value)
		swatch.BackgroundColor3 = state.value
	end

	local dragOrigin: Vector2? = nil
	local dragSaturation = 0
	local dragBrightness = 0

	local function applySquare(point: Vector2, initial: boolean?)
		local target = squareRef
		if not target then
			return
		end

		local size = target.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end

		if initial then
			local origin = target.AbsolutePosition
			saturation = math.clamp((point.X - origin.X) / size.X, 0, 1)
			brightness = 1 - math.clamp((point.Y - origin.Y) / size.Y, 0, 1)
			dragOrigin = point
			dragSaturation = saturation
			dragBrightness = brightness
		elseif dragOrigin then
			local delta = point - dragOrigin
			saturation = math.clamp(dragSaturation + delta.X / size.X, 0, 1)
			brightness = math.clamp(dragBrightness - delta.Y / size.Y, 0, 1)
		else
			return
		end

		state:Set(Color3.fromHSV(hue, saturation, brightness))
	end

	local function applyHue(point: Vector2)
		local target = stripRef
		if not target then
			return
		end

		local origin = target.AbsolutePosition
		local size = target.AbsoluteSize
		if size.X <= 0 then
			return
		end

		hue = math.clamp((point.X - origin.X) / size.X, 0, 1)
		state:Set(Color3.fromHSV(hue, saturation, brightness))
	end

	state.trove:Connect(UserInputService.InputChanged, function(input)
		if not panel then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)
		if draggingSquare then
			applySquare(point)
		elseif draggingHue then
			applyHue(point)
		end
	end)

	state.trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSquare = false
			draggingHue = false
			dragOrigin = nil
		end
	end)

	local function closePanel()
		if not panel then
			return
		end

		local doomed = panel
		local doomedTrove = panelTrove

		panel = nil
		panelTrove = nil
		squareRef = nil
		stripRef = nil
		draggingSquare = false
		draggingHue = false
		state.repaint = nil

		local function finish()
			if doomedTrove then
				state.trove:Remove(doomedTrove)
				doomedTrove:Destroy()
			end
		end

		local fade = Motion.tween(doomed, Motion.curve.exit, { GroupTransparency = 1 }, state.trove)
		if fade then
			fade.Completed:Once(finish)
		else
			finish()
		end
	end

	function state:Get()
		return self.value
	end

	function state:Set(value, silent)
		if typeof(value) ~= "Color3" then
			return self
		end

		self.value = value
		hue, saturation, brightness = value:ToHSV()
		paintChip()

		if self.repaint then
			self.repaint()
		end

		if not silent then
			self.changed:Fire(value)
			Element.guard(self, self.callback, value)
		end

		return self
	end

	function state:OnChanged(callback)
		local disconnect = self.changed:Connect(callback)
		self.trove:Add(disconnect)
		return disconnect
	end

	function state:Destroy()
		if self.flag and window.registry then
			window.registry:unregister(self.flag, self)
		end
		closePanel()
		self.trove:Clean()
	end

	local function buildPanel()
		panelTrove = state.trove:Extend()

		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)

		local width = metrics.pickerWidth
		local height = metrics.pickerSquare + metrics.pickerStrip + 22 + Theme.space.md * 4

		local anchorPos = swatch.AbsolutePosition
		local anchorSize = swatch.AbsoluteSize

		local x = math.clamp(anchorPos.X + anchorSize.X - width, Theme.space.md, math.max(bounds.X - width - Theme.space.md, Theme.space.md))
		local y = anchorPos.Y + anchorSize.Y + Theme.space.xs
		if y + height > bounds.Y then
			y = math.max(anchorPos.Y - height - Theme.space.xs, Theme.space.md)
		end

		local root = Create.new("CanvasGroup", {
			Name = "Picker",
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = Theme.surface[2],
			BorderSizePixel = 0,
			GroupTransparency = 1,
			ZIndex = Theme.zone.popup,
		})
		Create.corner(Theme.radius.control).Parent = root
		Create.stroke(Theme.line.control).Parent = root
		Create.pad(Theme.space.md).Parent = root
		Create.list({ Padding = UDim.new(0, Theme.space.md) }).Parent = root

		local square = Create.button({
			Name = "Square",
			Text = "",
			Size = UDim2.new(1, 0, 0, metrics.pickerSquare),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BackgroundTransparency = 0,
			LayoutOrder = 1,
			ZIndex = Theme.zone.popup,
			Parent = root,
		})
		Create.corner(Theme.radius.small).Parent = square

		local white = Create.new("Frame", {
			Name = "Saturation",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Theme.zone.popup,
			Parent = square,
		})
		Create.corner(Theme.radius.small).Parent = white
		Create.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 0,
			Parent = white,
		})

		local black = Create.new("Frame", {
			Name = "Value",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = Theme.zone.popup,
			Parent = square,
		})
		Create.corner(Theme.radius.small).Parent = black
		Create.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(0, 0, 0)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Rotation = 90,
			Parent = black,
		})

		local cursor = Create.new("Frame", {
			Name = "Cursor",
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = Theme.zone.popup + 1,
			Parent = square,
		})
		Create.corner(6).Parent = cursor
		Create.stroke(Color3.new(0, 0, 0), 3).Parent = cursor

		local cursorInner = Create.new("Frame", {
			Name = "Inner",
			Size = UDim2.fromOffset(9, 9),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = Theme.zone.popup + 2,
			Parent = cursor,
		})
		Create.corner(5).Parent = cursorInner
		Create.stroke(Color3.new(1, 1, 1), 2).Parent = cursorInner

		local strip = Create.button({
			Name = "Hue",
			Text = "",
			Size = UDim2.new(1, 0, 0, metrics.pickerStrip),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			LayoutOrder = 2,
			ZIndex = Theme.zone.popup,
			Parent = root,
		})
		Create.corner(Theme.radius.small).Parent = strip
		Create.new("UIGradient", {
			Color = HUE,
			Rotation = 0,
			Parent = strip,
		})

		local hueMark = Create.new("Frame", {
			Name = "Mark",
			Size = UDim2.fromOffset(2, metrics.pickerStrip + 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Theme.zone.popup + 1,
			Parent = strip,
		})
		Create.stroke(Theme.surface[0], 1).Parent = hueMark

		local entry = Create.surface(3, Theme.radius.small, {
			Name = "HexField",
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 3,
			ZIndex = Theme.zone.popup,
			Parent = root,
		})
		Create.stroke(Theme.line.control).Parent = entry
		Create.pad(0, Theme.space.md, 0, Theme.space.md).Parent = entry

		local hexBox = Create.input({
			Name = "Box",
			Text = toHex(state.value),
			TextSize = Theme.size.small,
			Font = Theme.font.mono,
			Size = UDim2.fromScale(1, 1),
			ZIndex = Theme.zone.popup,
			Parent = entry,
		})

		local function repaint()
			square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			cursor.Position = UDim2.fromScale(saturation, 1 - brightness)
			hueMark.Position = UDim2.fromScale(hue, 0.5)
			if not hexBox:IsFocused() then
				hexBox.Text = toHex(state.value)
			end
		end

		state.repaint = repaint
		repaint()

		squareRef = square
		stripRef = strip

		panelTrove:Connect(square.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingSquare = true
				applySquare(Vector2.new(input.Position.X, input.Position.Y), true)
			end
		end)

		panelTrove:Connect(strip.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingHue = true
				applyHue(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		panelTrove:Connect(hexBox.FocusLost, function()
			local parsed = fromHex(hexBox.Text)
			if parsed then
				state:Set(parsed)
			else
				hexBox.Text = toHex(state.value)
			end
		end)

		panel = root
		panelTrove:Add(root)
		window:openPopup(root, closePanel)

		Motion.tween(root, Motion.curve.reveal, { GroupTransparency = 0 }, state.trove)
	end

	state.trove:Connect(swatch.Activated, function()
		if owner and owner.enabled == false then
			return
		end
		if panel then
			window:closePopup()
		else
			buildPanel()
		end
	end)

	paintChip()

	if shouldRegister and state.flag then
		window.registry:register(state.flag, state)
	else
		state.flag = nil
	end

	return state
end

function ColorPicker.build(section, opts)
	local handle = Element.new(section, opts, { kind = "color" })
	local state = mount(handle, handle.slot, opts, 1, false)

	handle.picker = state
	handle.trove:Add(state)

	handle._apply = function(value)
		state:Set(value, true)
		return state.value
	end

	handle._onEnabled = function(enabled)
		state.swatch.BackgroundTransparency = if enabled then 0 else 0.6
		state.edge.Color = if enabled then Theme.line.focus else Theme.line.disabled
	end

	state:OnChanged(function(value)
		handle.value = value
		handle.changed:Fire(value)
	end)

	handle.value = state.value

	return handle
end

function ColorPicker.attach(owner, opts)
	local state = mount(owner, owner.slot, opts, 2, true)
	owner.picker = state
	owner.trove:Add(state)
	return state
end

return ColorPicker
end

__modules["Config"] = function()
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
end

__modules["Create"] = function()
local Theme = require("Theme")

local Create = {}

local function copy(source: { [string]: any }?): { [string]: any }
	local result = {}
	if source then
		for key, value in source do
			result[key] = value
		end
	end
	return result
end

local function take(props: { [string]: any }, key: string, fallback: any): any
	local value = props[key]
	if value == nil then
		return fallback
	end
	props[key] = nil
	return value
end

local function fill(props: { [string]: any }, defaults: { [string]: any })
	for key, value in defaults do
		if props[key] == nil then
			props[key] = value
		end
	end
end

function Create.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

function Create.corner(radius: number): UICorner
	return Create.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Create.new("UIStroke", {
		Color = color or Theme.line.soft,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.pad(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local up = top
	local side = right or top
	local down = bottom or top
	local other = left or side

	return Create.new("UIPadding", {
		PaddingTop = UDim.new(0, up),
		PaddingRight = UDim.new(0, side),
		PaddingBottom = UDim.new(0, down),
		PaddingLeft = UDim.new(0, other),
	})
end

function Create.list(props: { [string]: any }?): UIListLayout
	local options = copy(props)
	fill(options, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 0),
	})
	return Create.new("UIListLayout", options)
end

function Create.frame(props: { [string]: any }?, children: { Instance }?): Frame
	local options = copy(props)
	fill(options, {
		BackgroundColor3 = Theme.surface[1],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	return Create.new("Frame", options, children)
end

function Create.text(props: { [string]: any }?, children: { Instance }?): TextLabel
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.font[weight] or Theme.font.regular,
		TextSize = Theme.size.body,
		TextColor3 = Theme.text[1],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextLabel", options, children)
end

function Create.button(props: { [string]: any }?, children: { Instance }?): TextButton
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.surface[3],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.font[weight] or Theme.font.regular,
		Text = "",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextButton", options, children)
end

function Create.input(props: { [string]: any }?, children: { Instance }?): TextBox
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Theme.font[weight] or Theme.font.regular,
		Text = "",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		PlaceholderColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextBox", options, children)
end

function Create.image(props: { [string]: any }?, children: { Instance }?): ImageLabel
	local options = copy(props)
	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = Theme.text[2],
	})
	return Create.new("ImageLabel", options, children)
end

function Create.scroll(props: { [string]: any }?, children: { Instance }?): ScrollingFrame
	local options = copy(props)
	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = Theme.metrics.scrollBar,
		ScrollBarImageColor3 = Theme.line.control,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ClipsDescendants = true,
	})
	return Create.new("ScrollingFrame", options, children)
end

function Create.surface(level: number, radius: number?, props: { [string]: any }?, children: { Instance }?): Frame
	local options = copy(props)
	fill(options, {
		BackgroundColor3 = Theme.surface[level],
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	})

	local frame = Create.new("Frame", options, children)
	if radius then
		Create.corner(radius).Parent = frame
	end
	return frame
end

function Create.caret(props: { [string]: any }?): Frame
	local options = copy(props)
	local color = take(options, "Color", Theme.text[2])
	local flip = take(options, "Flip", false)

	fill(options, {
		Name = "Caret",
		Size = UDim2.fromOffset(7, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})

	local holder = Create.new("Frame", options)

	for index = 1, 4 do
		local width = 9 - index * 2
		local row = if flip then 4 - index else index - 1

		Create.new("Frame", {
			Name = "Bar",
			Size = UDim2.fromOffset(width, 1),
			Position = UDim2.new(0.5, 0, 0, row),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = options.ZIndex or 1,
			Parent = holder,
		})
	end

	return holder
end

function Create.paintCaret(caret: Frame, color: Color3)
	for _, bar in caret:GetChildren() do
		if bar:IsA("Frame") then
			bar.BackgroundColor3 = color
		end
	end
end

function Create.measure(text: string, size: number, font: Enum.Font): number
	local ok, bounds = pcall(function()
		return game:GetService("TextService"):GetTextSize(text, size, font, Vector2.new(10000, 100))
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end

	local count = #text
	local counted, length = pcall(utf8.len, text)
	if counted and type(length) == "number" then
		count = length
	end

	return count * (size * 0.55)
end

return Create
end

__modules["Dialog"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Dialog = {}

function Dialog.confirm(window, opts)
	local trove = window.trove:Extend()

	window.modal = (window.modal or 0) + 1

	local scrim = Create.button({
		Name = "Scrim",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.scrim,
		BackgroundTransparency = 1,
		Modal = true,
		ZIndex = Theme.zone.dialog,
		Parent = window.gui,
	})
	trove:Add(scrim)

	local card = Create.new("CanvasGroup", {
		Name = "Dialog",
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = Theme.zone.dialog + 1,
		Parent = scrim,
	})
	Create.corner(Theme.radius.section).Parent = card
	Create.stroke(Theme.line.control).Parent = card
	Create.pad(Theme.space.xl).Parent = card
	Create.list({ Padding = UDim.new(0, Theme.space.lg) }).Parent = card

	local scale = Create.new("UIScale", { Scale = 0.94, Parent = card })

	Create.text({
		Name = "Title",
		Text = tostring(opts.Title or "Are you sure?"),
		TextSize = Theme.size.title,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		ZIndex = Theme.zone.dialog + 1,
		Parent = card,
	})

	if opts.Text then
		Create.text({
			Name = "Text",
			Text = tostring(opts.Text),
			TextSize = Theme.size.small,
			TextColor3 = Theme.text[2],
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			LineHeight = 1.25,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			ZIndex = Theme.zone.dialog + 1,
			Parent = card,
		})
	end

	local actions = Create.frame({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = 3,
		ZIndex = Theme.zone.dialog + 1,
		Parent = card,
	})
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.space.md),
	}).Parent = actions

	local closing = false

	local function close()
		if closing then
			return
		end
		closing = true
		window.modal = math.max((window.modal or 1) - 1, 0)

		Motion.tween(scale, Motion.curve.exit, { Scale = 0.94 }, trove)
		local fade = Motion.tween(card, Motion.curve.exit, { GroupTransparency = 1 }, trove)
		Motion.tween(scrim, Motion.curve.exit, { BackgroundTransparency = 1 }, trove)

		if fade then
			fade.Completed:Once(function()
				window.trove:Remove(trove)
				trove:Destroy()
			end)
		else
			window.trove:Remove(trove)
			trove:Destroy()
		end
	end

	local buttons = opts.Buttons
		or {
			{ Text = opts.Cancel or "Cancel" },
			{ Text = opts.Confirm or "Confirm", Primary = true, Callback = opts.Callback },
		}

	for index, spec in buttons do
		local primary = spec.Primary == true

		local button = Create.button({
			Name = "Action",
			Text = tostring(spec.Text or "OK"),
			TextSize = Theme.size.small,
			TextColor3 = if primary then Theme.onFill else Theme.text[0],
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, Theme.metrics.buttonHeight),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if primary then Theme.fill else Theme.surface[3],
			BackgroundTransparency = 0,
			LayoutOrder = index,
			ZIndex = Theme.zone.dialog + 1,
			Parent = actions,
		})
		Create.corner(Theme.radius.control).Parent = button
		Create.pad(0, Theme.space.xl, 0, Theme.space.xl).Parent = button

		if not primary then
			Create.stroke(Theme.line.control).Parent = button
		end

		trove:Connect(button.MouseEnter, function()
			Motion.tween(button, Motion.curve.hover, {
				BackgroundColor3 = if primary then Theme.text[1] else Theme.surface[4],
			}, trove)
		end)

		trove:Connect(button.MouseLeave, function()
			Motion.tween(button, Motion.curve.hover, {
				BackgroundColor3 = if primary then Theme.fill else Theme.surface[3],
			}, trove)
		end)

		trove:Connect(button.Activated, function()
			close()
			if spec.Callback then
				Element.guard({ flag = "dialog" }, spec.Callback)
			end
		end)
	end

	trove:Connect(scrim.Activated, close)

	trove:Connect(UserInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	Motion.tween(scrim, Motion.curve.reveal, { BackgroundTransparency = Theme.scrimTransparency }, trove)
	Motion.tween(card, Motion.curve.reveal, { GroupTransparency = 0 }, trove)
	Motion.tween(scale, Motion.curve.enter, { Scale = 1 }, trove)

	return { close = close }
end

return Dialog
end

__modules["Divider"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Element = require("Element")

local Divider = {}

function Divider.build(section, opts)
	local handle = Element.new(section, opts, {
		interactive = false,
		label = false,
		height = Theme.space.lg,
		kind = "divider",
	})

	handle.noDivider = true
	handle.divider.Visible = false
	section:restripe()

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, 1),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = handle.frame,
	})

	return handle
end

return Divider
end

__modules["Dropdown"] = function()
local Players = game:GetService("Players")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Dropdown = {}

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

function Dropdown.build(section, opts)
	local handle = Element.new(section, opts, { kind = "dropdown" })
	local metrics = Theme.metrics
	local window = handle.window

	local multi = opts.Multi == true
	local placeholder = tostring(opts.Placeholder or "None")
	local options: { string } = {}
	local menu: Frame? = nil
	local menuTrove = nil

	local field = Create.surface(3, Theme.radius.control, {
		Name = "Field",
		Size = UDim2.fromOffset(metrics.controlMax, Theme.field()),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	local border = Create.stroke(Theme.line.control)
	border.Parent = field
	Create.pad(0, Theme.space.md, 0, Theme.space.md).Parent = field

	local caret = Create.caret({
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Theme.text[2],
		ZIndex = 4,
		Parent = field,
	})

	local display = Create.text({
		Name = "Value",
		Text = placeholder,
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[2],
		Size = UDim2.new(1, -(7 + Theme.space.sm), 1, 0),
		ZIndex = 4,
		Parent = field,
	})
	handle:track(display)

	local trigger = Create.button({
		Name = "Trigger",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = field,
	})

	local function selection(): { string }
		if multi then
			return handle.value or {}
		end
		return if handle.value then { handle.value } else {}
	end

	local function describe(): string
		local chosen = selection()

		if #chosen == 0 then
			return placeholder
		end

		if not multi then
			return chosen[1]
		end

		if #chosen == #options and #options > 0 then
			return "All"
		end

		return tostring(#chosen) .. " selected"
	end

	local function paint()
		local chosen = selection()
		display.Text = describe()
		handle:rebase(display, if #chosen == 0 then Theme.text[2] else Theme.text[0])

		if not opts.Tip then
			local measured = Create.measure(display.Text, display.TextSize, display.Font)
			handle.tip = if measured > display.AbsoluteSize.X and display.AbsoluteSize.X > 0
				then display.Text
				else nil
		end
	end

	local function closeMenu()
		if not menu then
			return
		end
		local doomed = menu
		local doomedTrove = menuTrove

		menu = nil
		menuTrove = nil

		Create.paintCaret(caret, Theme.text[2])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.control }, handle.trove)

		local function finish()
			if doomedTrove then
				handle.trove:Remove(doomedTrove)
				doomedTrove:Destroy()
			end
		end

		local fade = Motion.tween(doomed, Motion.curve.exit, { GroupTransparency = 1 }, handle.trove)
		if fade then
			fade.Completed:Once(finish)
		else
			finish()
		end
	end

	local function buildMenu()
		menuTrove = handle.trove:Extend()

		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)

		local fieldPos = field.AbsolutePosition
		local fieldSize = field.AbsoluteSize

		local rows = math.max(math.min(#options, metrics.dropdownMaxRows), 1)
		local wanted = rows * metrics.dropdownRow + math.max(rows - 1, 0) + Theme.space.md
		local below = bounds.Y - (fieldPos.Y + fieldSize.Y) - Theme.space.lg
		local above = fieldPos.Y - Theme.space.lg

		local flip = below < wanted and above > below
		local available = if flip then above else below
		local height = math.max(math.min(wanted, available), metrics.dropdownRow + Theme.space.md)

		local menuWidth = math.max(fieldSize.X, 220)
		local rightEdge = fieldPos.X + fieldSize.X

		local panel = Create.new("CanvasGroup", {
			Name = "Menu",
			Size = UDim2.fromOffset(menuWidth, height),
			Position = UDim2.fromOffset(
				math.clamp(rightEdge - menuWidth, Theme.space.md, math.max(bounds.X - menuWidth - Theme.space.md, Theme.space.md)),
				if flip then fieldPos.Y - height - Theme.space.xs else fieldPos.Y + fieldSize.Y + Theme.space.xs
			),
			BackgroundColor3 = Theme.surface[2],
			BorderSizePixel = 0,
			GroupTransparency = 1,
			ZIndex = Theme.zone.popup,
		})
		Create.corner(Theme.radius.control).Parent = panel
		Create.stroke(Theme.line.control).Parent = panel

		local scroll = Create.scroll({
			Name = "List",
			Size = UDim2.fromScale(1, 1),
			ZIndex = Theme.zone.popup,
			Parent = panel,
		})
		Create.pad(Theme.space.xs, Theme.space.xs, Theme.space.xs, Theme.space.xs).Parent = scroll
		Create.list({ Padding = UDim.new(0, 1) }).Parent = scroll

		for index, option in options do
			local chosen = contains(selection(), option)

			local entry = Create.button({
				Name = "Option",
				Text = "",
				Size = UDim2.new(1, 0, 0, metrics.dropdownRow),
				BackgroundColor3 = Theme.surface[4],
				BackgroundTransparency = 1,
				LayoutOrder = index,
				ZIndex = Theme.zone.popup,
				Parent = scroll,
			})
			Create.corner(Theme.radius.small).Parent = entry

			local text = Create.text({
				Name = "Text",
				Text = option,
				TextSize = Theme.size.small,
				TextColor3 = if chosen then Theme.text[0] else Theme.text[1],
				Position = UDim2.new(0, Theme.space.md, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(1, -(Theme.space.md * 2 + 12), 1, 0),
				ZIndex = Theme.zone.popup,
				Parent = entry,
			})

			local tick = Create.new("Frame", {
				Name = "Tick",
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.new(1, -Theme.space.md, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme.fill,
				BorderSizePixel = 0,
				Visible = chosen,
				ZIndex = Theme.zone.popup,
				Parent = entry,
			})
			Create.corner(3).Parent = tick

			menuTrove:Connect(entry.MouseEnter, function()
				Motion.tween(entry, Motion.curve.hover, { BackgroundTransparency = 0 }, handle.trove)
				Motion.tween(text, Motion.curve.hover, { TextColor3 = Theme.text[0] }, handle.trove)
			end)

			menuTrove:Connect(entry.MouseLeave, function()
				Motion.tween(entry, Motion.curve.hover, { BackgroundTransparency = 1 }, handle.trove)
				Motion.tween(text, Motion.curve.hover, {
					TextColor3 = if tick.Visible then Theme.text[0] else Theme.text[1],
				}, handle.trove)
			end)

			menuTrove:Connect(entry.Activated, function()
				if multi then
					local chosenNow = table.clone(selection())
					local at = table.find(chosenNow, option)
					if at then
						table.remove(chosenNow, at)
					else
						table.insert(chosenNow, option)
					end
					handle:Set(chosenNow)
					tick.Visible = contains(selection(), option)
					text.TextColor3 = if tick.Visible then Theme.text[0] else Theme.text[1]
				else
					handle:Set(option)
					window:closePopup()
				end
			end)
		end

		if #options == 0 then
			Create.text({
				Name = "Empty",
				Text = "No options",
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[2],
				Position = UDim2.fromOffset(Theme.space.md, 0),
				Size = UDim2.new(1, -Theme.space.lg, 0, metrics.dropdownRow),
				LayoutOrder = 1,
				ZIndex = Theme.zone.popup,
				Parent = scroll,
			})
		end

		menu = panel
		menuTrove:Add(panel)
		window:openPopup(panel, closeMenu)

		Create.paintCaret(caret, Theme.text[0])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.focus }, handle.trove)
		Motion.tween(panel, Motion.curve.reveal, { GroupTransparency = 0 }, handle.trove)
	end

	handle.trove:Connect(trigger.Activated, function()
		if not handle.enabled then
			return
		end
		if menu then
			window:closePopup()
		else
			buildMenu()
		end
	end)

	handle._apply = function(value)
		local resolved

		if multi then
			local list = {}
			if type(value) == "table" then
				for _, option in options do
					if contains(value, option) then
						table.insert(list, option)
					end
				end
			end
			resolved = list
		else
			resolved = if type(value) == "string" and contains(options, value) then value else nil
		end

		handle.value = resolved
		paint()
		return resolved
	end

	handle._onEnabled = function(enabled)
		trigger.Active = enabled
		Motion.set(border, { Color = if enabled then Theme.line.control else Theme.line.disabled })
		Create.paintCaret(caret, if enabled then Theme.text[2] else Theme.text[3])
	end

	function handle:SetOptions(list: { string })
		options = {}

		if type(list) == "table" then
			local seen = {}
			for _, option in list do
				local text = tostring(option)
				if not seen[text] then
					seen[text] = true
					table.insert(options, text)
				end
			end
		end

		if menu then
			window:closePopup()
		end

		local before = if multi then table.concat(selection(), "\0") else tostring(self.value)
		self:Set(self.value, true)
		local after = if multi then table.concat(selection(), "\0") else tostring(self.value)

		if before ~= after then
			self.changed:Fire(self.value)
			Element.guard(self, self.callback, self.value)
		end

		return self
	end

	function handle:GetOptions(): { string }
		return table.clone(options)
	end

	local source = opts.Source

	if source == "Players" or source == "Teams" then
		local function refresh()
			local list = {}

			if source == "Players" then
				for _, player in Players:GetPlayers() do
					if not (opts.ExcludeLocal and player == Players.LocalPlayer) then
						table.insert(list, player.Name)
					end
				end
			else
				local teams = game:GetService("Teams")
				for _, team in teams:GetChildren() do
					if team:IsA("Team") then
						table.insert(list, team.Name)
					end
				end
			end

			table.sort(list)
			handle:SetOptions(list)
		end

		handle.trove:Connect(Players.PlayerAdded, refresh)
		handle.trove:Connect(Players.PlayerRemoving, function()
			task.defer(refresh)
		end)

		refresh()
	else
		handle:SetOptions(opts.Options or {})
	end

	if opts.Default ~= nil then
		handle:Set(opts.Default, true)
	else
		handle:Set(if multi then {} else nil, true)
	end

	return handle
end

return Dropdown
end

__modules["Element"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Signal = require("Signal")
local Env = require("Env")

local Element = {}
Element.__index = Element

function Element.guard(handle, callback, ...)
	if type(callback) ~= "function" then
		return
	end

	local ok, err = xpcall(callback, function(message)
		return tostring(message) .. "\n" .. debug.traceback(nil, 2)
	end, ...)

	if not ok then
		local name = handle and (handle.flag or handle.text) or "element"
		Signal.onError("callback for '" .. tostring(name) .. "' failed: " .. tostring(err))
	end
end

function Element.new(section, opts, config)
	local settings = config or {}
	local metrics = Theme.metrics

	if opts.Flag ~= nil then
		section.window.registry:assertFree(opts.Flag)
	end
	local height = settings.height or (if Env.isTouch then metrics.rowTouch else metrics.row)

	local handle = setmetatable({}, Element)
	handle.window = section.window
	handle.section = section
	handle.trove = section.trove:Extend()
	handle.changed = Signal.new()
	handle.text = opts.Text
	handle.flag = opts.Flag
	handle.callback = opts.Callback
	handle.tip = opts.Tip
	handle.enabled = true
	handle.hovered = false
	handle.textNodes = {}
	handle.kind = settings.kind or "element"

	handle.trove:Add(handle.changed)

	local row = Create.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.surface[4],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	})
	Create.corner(Theme.radius.control).Parent = row
	handle.frame = row
	handle.trove:Add(row)

	local divider = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -(metrics.rowPad * 2), 0, 1),
		Position = UDim2.new(0, metrics.rowPad, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = row,
	})
	handle.divider = divider

	local label
	if settings.label ~= false then
		label = Create.text({
			Name = "Label",
			Text = opts.Text or "",
			TextColor3 = Theme.text[1],
			TextSize = Theme.size.body,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, metrics.rowPad, 0.5, 0),
			Size = UDim2.new(1, -(metrics.rowPad * 2), 1, 0),
			ZIndex = 2,
			Parent = row,
		})
		handle.label = label
		handle:track(label)
	end

	if settings.wrap and label then
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)

		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.fromOffset(metrics.rowPad, Theme.space.md)
		label.Size = UDim2.new(1, -(metrics.rowPad * 2), 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.TextYAlignment = Enum.TextYAlignment.Top

		Create.new("UIPadding", {
			PaddingBottom = UDim.new(0, Theme.space.md),
			Parent = row,
		})
	end

	local slot = Create.new("Frame", {
		Name = "Slot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -metrics.rowPad, 0.5, 0),
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = if settings.wrap or settings.label == false
			then Enum.AutomaticSize.X
			else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
		Parent = row,
	})
	local slotLayout = Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.space.sm),
	})
	slotLayout.Parent = slot

	handle.slot = slot
	handle.slotLayout = slotLayout

	if label and not settings.wrap then
		local function syncLabel()
			if row.Parent == nil then
				return
			end

			local rowWidth = row.AbsoluteSize.X
			if rowWidth <= 0 then
				return
			end

			local budget = rowWidth - (metrics.rowPad * 2) - metrics.rowGap - metrics.labelMin
			local wanted = slotLayout.AbsoluteContentSize.X

			if wanted > budget then
				handle.stacked = true
				slot.ClipsDescendants = true

				row.Size = UDim2.new(1, 0, 0, height * 2 - Theme.space.xs)

				label.AnchorPoint = Vector2.new(0, 0)
				label.Position = UDim2.fromOffset(metrics.rowPad, math.max(math.floor(height / 2) - 8, 0))
				label.Size = UDim2.new(1, -(metrics.rowPad * 2), 0, 16)

				slot.AnchorPoint = Vector2.new(1, 1)
				slot.Position = UDim2.new(1, -metrics.rowPad, 1, -Theme.space.xs)
				slot.Size = UDim2.fromOffset(math.min(wanted, rowWidth - metrics.rowPad * 2), height)
				return
			end

			handle.stacked = false
			slot.ClipsDescendants = false
			local given = math.max(math.min(wanted, budget), 0)

			row.Size = UDim2.new(1, 0, 0, height)

			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Position = UDim2.new(0, metrics.rowPad, 0.5, 0)
			label.Size = UDim2.new(0, math.max(rowWidth - (metrics.rowPad * 2) - metrics.rowGap - given, 0), 1, 0)

			slot.AnchorPoint = Vector2.new(1, 0.5)
			slot.Position = UDim2.new(1, -metrics.rowPad, 0.5, 0)
			slot.Size = UDim2.fromOffset(given, height)
		end

		handle.trove:Connect(slotLayout:GetPropertyChangedSignal("AbsoluteContentSize"), syncLabel)
		handle.trove:Connect(row:GetPropertyChangedSignal("AbsoluteSize"), syncLabel)
		handle.trove:Add(task.defer(syncLabel))
	end

	if settings.interactive ~= false then
		local hit = Create.button({
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = row,
		})
		handle.hit = hit
	end

	if settings.interactive ~= false or opts.Tip then
		handle.trove:Connect(row.MouseEnter, function()
			handle:setHover(true)
		end)
		handle.trove:Connect(row.MouseLeave, function()
			handle:setHover(false)
		end)
	end

	if Env.isTouch and handle.hit then
		local press

		local function cancelPress()
			if press then
				pcall(task.cancel, press)
				handle.trove:Remove(press)
				press = nil
			end
		end

		handle.trove:Connect(handle.hit.InputBegan, function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			cancelPress()
			press = task.delay(0.45, function()
				press = nil
				handle:showTip()
			end)
			handle.trove:Add(press)
		end)

		handle.trove:Connect(handle.hit.InputEnded, function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			cancelPress()
			handle:hideTip()
		end)
	end

	section:addRow(handle)
	row.Parent = section.body

	if handle.flag then
		handle.window.registry:register(handle.flag, handle)
	end

	return handle
end

function Element:track(instance: TextLabel | TextButton | TextBox)
	table.insert(self.textNodes, {
		instance = instance,
		base = instance.TextColor3,
	})
end

function Element:untrack(instance)
	for index, node in self.textNodes do
		if node.instance == instance then
			table.remove(self.textNodes, index)
			return
		end
	end
end

function Element:rebase(instance, color: Color3)
	for _, node in self.textNodes do
		if node.instance == instance then
			node.base = color

			local target = color
			if not self.enabled then
				target = Theme.text[3]
			elseif self.hovered then
				target = Theme.lifted(color)
			end

			Motion.set(instance, { TextColor3 = target })
			return
		end
	end
end

function Element:setHover(hovered: boolean)
	if hovered and self.window:isBlocked() then
		return
	end

	if self.hovered == hovered then
		return
	end
	self.hovered = hovered

	if not self.enabled then
		return
	end

	Motion.tween(self.frame, Motion.curve.hover, {
		BackgroundTransparency = if hovered then 0 else 1,
	}, self.trove)

	for _, node in self.textNodes do
		Motion.tween(node.instance, Motion.curve.hover, {
			TextColor3 = if hovered then Theme.lifted(node.base) else node.base,
		}, self.trove)
	end

	if hovered then
		self:showTip()
	else
		self:hideTip()
	end
end

function Element:showTip()
	local text = self.tip

	if not text and self.label then
		local measured = Create.measure(self.label.Text, self.label.TextSize, self.label.Font)
		if measured > self.label.AbsoluteSize.X then
			text = self.label.Text
		end
	end

	if not text or text == "" then
		return
	end

	self.window:showTooltip(text, self.frame)
end

function Element:hideTip()
	self.window:hideTooltip()
end

function Element:Tip(text: string)
	self.tip = text
	return self
end

function Element:Get()
	return self.value
end

function Element:Set(value, silent: boolean?)
	if self._apply then
		self.value = self._apply(value)
	else
		self.value = value
	end

	if not silent then
		self.changed:Fire(self.value)
		Element.guard(self, self.callback, self.value)
	end

	return self
end

function Element:Restore(value)
	if self.kind == "button" then
		return self
	end

	self:Set(value, true)
	self.changed:Fire(self.value)
	Element.guard(self, self.callback, self.value)

	return self
end

function Element:OnChanged(callback)
	local disconnect = self.changed:Connect(callback)
	self.trove:Add(disconnect)
	return disconnect
end

function Element:SetText(text: string)
	self.text = text
	if self.label then
		self.label.Text = text
	end
	return self
end

function Element:SetVisible(visible: boolean)
	self.frame.Visible = visible ~= false
	return self
end

function Element:SetEnabled(enabled: boolean)
	local target = enabled ~= false
	if self.enabled == target then
		return self
	end
	self.enabled = target

	if self.hit then
		self.hit.Active = target
		self.hit.AutoButtonColor = false
	end

	if not target then
		Motion.tween(self.frame, Motion.curve.hover, { BackgroundTransparency = 1 }, self.trove)
	end

	for _, node in self.textNodes do
		Motion.tween(node.instance, Motion.curve.hover, {
			TextColor3 = if target then node.base else Theme.text[3],
		}, self.trove)
	end

	if self._onEnabled then
		self._onEnabled(target)
	end

	return self
end

function Element:Bind(opts)
	local Keybind = require("Keybind")
	Keybind.attach(self, opts or {})
	return self
end

function Element:Color(opts)
	local ColorPicker = require("ColorPicker")
	ColorPicker.attach(self, opts or {})
	return self
end

function Element:Menu(opts)
	if self.menu then
		return self.menu
	end
	return require("SubMenu").attach(self, opts or {})
end

function Element:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	if self.flag and self.window and self.window.registry then
		self.window.registry:unregister(self.flag, self)
	end
	if self.section then
		self.section:removeRow(self)
	end
	self:hideTip()
	self.trove:Destroy()
end

return Element
end

__modules["Env"] = function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Env = {}

local globals: { [string]: any }
do
	local fromEnv, environment = pcall(getfenv, 0)
	if fromEnv and type(environment) == "table" then
		globals = environment
	else
		globals = (_G :: any)
	end

	local shared = rawget(globals, "getgenv")
	if type(shared) == "function" then
		local ok, table_ = pcall(shared)
		if ok and type(table_) == "table" then
			globals = table_
		end
	end
end

local function grab(name: string): any
	local ok, value = pcall(function()
		return globals[name]
	end)
	if ok then
		return value
	end
	return nil
end

local function grabFunction(name: string)
	local value = grab(name)
	return if type(value) == "function" then value else nil
end

local writeFile = grabFunction("writefile")
local readFile = grabFunction("readfile")
local isFile = grabFunction("isfile")
local isFolder = grabFunction("isfolder")
local makeFolder = grabFunction("makefolder")
local listFiles = grabFunction("listfiles")
local delFile = grabFunction("delfile")
local getHui = grabFunction("gethui")
local clipboard = grabFunction("setclipboard")

local protectGui = grabFunction("protect_gui")
if not protectGui then
	local syn = grab("syn")
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		protectGui = syn.protect_gui
	end
end

local identify = grabFunction("identifyexecutor") or grabFunction("getexecutorname")

Env.hasFiles = writeFile ~= nil and readFile ~= nil and isFile ~= nil
Env.hasFolders = Env.hasFiles and isFolder ~= nil and makeFolder ~= nil
Env.hasListing = Env.hasFiles and listFiles ~= nil
Env.hasDelete = Env.hasFiles and delFile ~= nil
Env.isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

do
	local ok, name = pcall(function()
		return if identify then identify() else "unknown"
	end)
	Env.executor = if ok and type(name) == "string" then name else "unknown"
end

function Env.player(): Player?
	return Players.LocalPlayer
end

function Env.mount(gui: ScreenGui): string
	if getHui then
		local ok, hidden = pcall(getHui)
		if ok and typeof(hidden) == "Instance" then
			local parented = pcall(function()
				gui.Parent = hidden
			end)
			if parented then
				return "gethui"
			end
		end
	end

	if protectGui then
		pcall(protectGui, gui)
	end

	local mounted = pcall(function()
		gui.Parent = CoreGui
	end)
	if mounted then
		return "coregui"
	end

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local fallback = pcall(function()
			gui.Parent = playerGui
		end)
		if fallback then
			return "playergui"
		end
	end

	return "none"
end

function Env.ensureFolder(path: string): boolean
	if not Env.hasFolders then
		return false
	end

	local built: string? = nil

	for _, segment in string.split(path, "/") do
		if segment ~= "" then
			built = if built then built .. "/" .. segment else segment

			local ok, exists = pcall(isFolder, built)
			if not ok or exists ~= true then
				local created = pcall(makeFolder, built)
				if not created then
					return false
				end
			end
		end
	end

	return true
end

function Env.exists(path: string): boolean
	if not Env.hasFiles then
		return false
	end
	local ok, result = pcall(isFile, path)
	return ok and result == true
end

function Env.read(path: string): string?
	if not Env.exists(path) then
		return nil
	end
	local ok, contents = pcall(readFile, path)
	if ok and type(contents) == "string" then
		return contents
	end
	return nil
end

function Env.write(path: string, contents: string): (boolean, string?)
	if not Env.hasFiles then
		return false, "no file access"
	end
	local ok, err = pcall(writeFile, path, contents)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

function Env.list(path: string): { string }
	if not Env.hasListing then
		return {}
	end
	local ok, entries = pcall(listFiles, path)
	if ok and type(entries) == "table" then
		return entries
	end
	return {}
end

function Env.delete(path: string): boolean
	if not Env.hasDelete then
		return false
	end
	return (pcall(delFile, path))
end

function Env.remember(key: string, value: any): boolean
	local ok = pcall(function()
		globals[key] = value
	end)

	if not ok then
		return false
	end

	return rawequal(Env.recall(key), value)
end

function Env.recall(key: string): any
	return grab(key)
end

function Env.copy(text: string): boolean
	if not clipboard then
		return false
	end
	return (pcall(clipboard, text))
end

return Env
end

__modules["Home"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Env = require("Env")

local Home = {}

local function wrapped(props): TextLabel
	local options = props
	options.TextWrapped = true
	options.TextTruncate = Enum.TextTruncate.None
	options.AutomaticSize = Enum.AutomaticSize.Y
	options.Size = options.Size or UDim2.new(1, 0, 0, 0)
	return Create.text(options)
end

local function block(section, order: number): Frame
	local frame = Create.frame({
		Name = "Block",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = section.body,
	})
	Create.pad(Theme.space.lg).Parent = frame
	Create.list({ Padding = UDim.new(0, Theme.space.sm) }).Parent = frame
	return frame
end

function Home.build(window, config)
	local page = window:Tab(config.Tab or "Home", config.Icon)

	local hero = Create.frame({
		Name = "Hero",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 0,
		Parent = page.left,
	})
	Create.pad(Theme.space.xs, 0, Theme.space.md, 0).Parent = hero
	Create.list({ Padding = UDim.new(0, Theme.space.sm) }).Parent = hero

	wrapped({
		Name = "Name",
		Text = window.name,
		TextSize = Theme.size.hero,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		LayoutOrder = 1,
		Parent = hero,
	})

	if config.Description then
		wrapped({
			Name = "Description",
			Text = tostring(config.Description),
			TextSize = Theme.size.small,
			TextColor3 = Theme.text[2],
			LineHeight = 1.25,
			LayoutOrder = 2,
			Parent = hero,
		})
	end

	if type(config.Changelog) == "table" and #config.Changelog > 0 then
		local section = page:Section(config.ChangelogTitle or "Changelog", { Column = "left" })
		local body = block(section, 1)

		for index, entry in config.Changelog do
			local row = Create.frame({
				Name = "Entry",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
				Parent = body,
			})
			Create.list({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, Theme.space.md),
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}).Parent = row

			Create.text({
				Name = "Version",
				Text = tostring(entry.Version or "-"),
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[2],
				Font = Theme.font.mono,
				Size = UDim2.fromOffset(44, 18),
				LayoutOrder = 1,
				Parent = row,
			})

			local notes = entry.Notes
			local text

			if type(notes) == "table" then
				text = table.concat(notes, ", ")
			else
				text = tostring(notes or "")
			end

			wrapped({
				Name = "Notes",
				Text = text,
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[1],
				LineHeight = 1.25,
				Size = UDim2.new(1, -(44 + Theme.space.md), 0, 0),
				LayoutOrder = 2,
				Parent = row,
			})
		end
	end

	if type(config.Links) == "table" and #config.Links > 0 then
		local section = page:Section(config.LinksTitle or "Links", { Column = "right" })
		local body = block(section, 1)

		for index, link in config.Links do
			local button = Create.button({
				Name = "Link",
				Text = tostring(link.Text or "Open"),
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[0],
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, if Env.isTouch then Theme.metrics.touchTarget else Theme.metrics.buttonHeight),
				BackgroundColor3 = Theme.surface[3],
				BackgroundTransparency = 0,
				LayoutOrder = index,
				Parent = body,
			})
			Create.corner(Theme.radius.control).Parent = button
			Create.stroke(Theme.line.soft).Parent = button
			Create.pad(0, Theme.space.lg, 0, Theme.space.lg).Parent = button

			window.trove:Connect(button.MouseEnter, function()
				Motion.tween(button, Motion.curve.hover, { BackgroundColor3 = Theme.surface[4] }, window.trove)
			end)
			window.trove:Connect(button.MouseLeave, function()
				Motion.tween(button, Motion.curve.hover, { BackgroundColor3 = Theme.surface[3] }, window.trove)
			end)

			window.trove:Connect(button.Activated, function()
				if link.Callback then
					local ok, err = pcall(link.Callback)
					if not ok then
						warn("[Umbra] link callback failed: " .. tostring(err))
					end
					return
				end

				if link.Url then
					local copied = Env.copy(tostring(link.Url))
					require("Notify").push(window, {
						Title = if copied then "Link copied" else "Copy failed",
						Text = tostring(link.Url),
						Duration = 4,
					})
				end
			end)
		end
	end

	if type(config.Credits) == "table" and #config.Credits > 0 then
		local section = page:Section(config.CreditsTitle or "Credits", { Column = "right" })
		local body = block(section, 1)

		for index, line in config.Credits do
			wrapped({
				Name = "Line",
				Text = tostring(line),
				TextSize = Theme.size.small,
				TextColor3 = if index == 1 then Theme.text[1] else Theme.text[2],
				LineHeight = 1.3,
				LayoutOrder = index,
				Parent = body,
			})
		end
	end

	local hint = Create.frame({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = 900,
		Parent = page.left,
	})
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, Theme.space.md),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent = hint

	Create.text({
		Name = "Label",
		Text = "Toggle menu",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Size = UDim2.fromOffset(70, 16),
		LayoutOrder = 1,
		Parent = hint,
	})

	local chip = Create.surface(3, Theme.radius.small, {
		Name = "Chip",
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = hint,
	})
	Create.stroke(Theme.line.soft).Parent = chip
	Create.pad(0, Theme.space.md, 0, Theme.space.md).Parent = chip

	local chipText = Create.text({
		Name = "Key",
		Text = window.toggleKey and window.toggleKey.Name or "RightControl",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[1],
		Font = Theme.font.mono,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = chip,
	})

	return {
		page = page,
		hero = hero,
		chip = chipText,
	}
end

return Home
end

__modules["Icons"] = function()
local Icons = {}

function Icons.resolve(icon: any): string?
	if type(icon) == "number" and icon > 0 then
		return "rbxassetid://" .. tostring(math.floor(icon))
	end

	if type(icon) == "string" then
		local assetId = string.match(icon, "^rbxassetid://(%d+)$")
		if assetId then
			return if (tonumber(assetId) or 0) > 0 then icon else nil
		end
		if string.match(icon, "^rbxasset://") then
			return icon
		end
		if string.match(icon, "^http://www%.roblox%.com/asset") then
			return icon
		end
		if string.match(icon, "^%d+$") then
			return if (tonumber(icon) or 0) > 0 then "rbxassetid://" .. icon else nil
		end
	end

	return nil
end

function Icons.letter(source: any): string
	if type(source) ~= "string" then
		return "?"
	end

	local trimmed = string.gsub(source, "^%s+", "")
	if trimmed == "" then
		return "?"
	end

	local ok, offset = pcall(utf8.offset, trimmed, 2)
	if ok and offset then
		return string.upper(string.sub(trimmed, 1, offset - 1))
	end

	return string.upper(string.sub(trimmed, 1, 1))
end

return Icons
end

__modules["Image"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Icons = require("Icons")
local Element = require("Element")

local Image = {}

function Image.build(section, opts)
	local height = tonumber(opts.Height) or 120

	local handle = Element.new(section, opts, {
		interactive = opts.Callback ~= nil,
		label = false,
		height = height + Theme.space.md * 2,
		kind = "image",
	})

	local asset = Icons.resolve(opts.Image or opts.Asset)

	local holder = Create.surface(3, Theme.radius.control, {
		Name = "Holder",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, height),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0, Theme.space.md),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = handle.frame,
	})
	Create.stroke(Theme.line.soft).Parent = holder

	local picture = Create.image({
		Name = "Picture",
		Image = asset or "",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = Color3.new(1, 1, 1),
		ScaleType = if opts.Fill then Enum.ScaleType.Crop else Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = holder,
	})

	local missing = Create.text({
		Name = "Missing",
		Text = "No image",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Visible = asset == nil,
		ZIndex = 3,
		Parent = holder,
	})

	if opts.Ratio then
		Create.new("UIAspectRatioConstraint", {
			AspectRatio = tonumber(opts.Ratio) or 1,
			DominantAxis = Enum.DominantAxis.Width,
			Parent = picture,
		})
	end

	handle.picture = picture

	handle._apply = function(value)
		local resolved = Icons.resolve(value)
		picture.Image = resolved or ""
		missing.Visible = resolved == nil
		return value
	end

	if handle.hit and opts.Callback then
		handle.trove:Connect(handle.hit.Activated, function()
			if handle.enabled then
				Element.guard(handle, opts.Callback)
			end
		end)
	end

	handle.value = opts.Image or opts.Asset

	return handle
end

return Image
end

__modules["Input"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Input = {}

function Input.build(section, opts)
	local handle = Element.new(section, opts, { kind = "input" })
	local metrics = Theme.metrics

	local field = Create.surface(3, Theme.radius.control, {
		Name = "Field",
		Size = UDim2.fromOffset(metrics.controlMax, Theme.field()),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})

	local border = Create.stroke(Theme.line.control)
	border.Parent = field
	Create.pad(0, Theme.space.md, 0, Theme.space.md).Parent = field

	local box = Create.input({
		Name = "Box",
		Text = tostring(opts.Default or ""),
		PlaceholderText = tostring(opts.Placeholder or ""),
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = opts.ClearOnFocus == true,
		ZIndex = 3,
		Parent = field,
	})

	local maxLength = tonumber(opts.MaxLength)
	local numeric = opts.Numeric == true

	local function sanitise(text: string): string
		local result = text

		if numeric then
			result = string.gsub(result, "[^%-%d%.]", "")
		end

		if maxLength and #result > maxLength then
			result = string.sub(result, 1, maxLength)
		end

		return result
	end

	handle._apply = function(value)
		local text = sanitise(tostring(value or ""))
		if box.Text ~= text then
			box.Text = text
		end
		return text
	end

	handle._onEnabled = function(enabled)
		box.TextEditable = enabled
		Motion.set(box, { TextColor3 = if enabled then Theme.text[0] else Theme.text[3] })
		Motion.set(border, { Color = if enabled then Theme.line.control else Theme.line.disabled })
	end

	handle.trove:Connect(box.Focused, function()
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.focus }, handle.trove)
	end)

	handle.trove:Connect(box.FocusLost, function(enterPressed)
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.control }, handle.trove)

		local text = sanitise(box.Text)
		box.Text = text

		if text ~= handle.value then
			handle:Set(text)
		end

		if enterPressed and opts.Submit then
			Element.guard(handle, opts.Submit, text)
		end
	end)

	handle.trove:Connect(box:GetPropertyChangedSignal("Text"), function()
		local text = sanitise(box.Text)
		if box.Text ~= text then
			box.Text = text
		end
	end)

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			box:CaptureFocus()
		end
	end)

	handle:Set(tostring(opts.Default or ""), true)

	return handle
end

return Input
end

__modules["Keybind"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Signal = require("Signal")
local Element = require("Element")

local Keybind = {}

local MOUSE = {
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

local BLOCKED = {
	[Enum.KeyCode.Unknown] = true,
	[Enum.KeyCode.Escape] = true,
	[Enum.KeyCode.Backspace] = true,
	[Enum.KeyCode.Delete] = true,
}

local function nameFor(input: InputObject): string?
	local mouse = MOUSE[input.UserInputType]
	if mouse then
		return mouse
	end

	if input.UserInputType == Enum.UserInputType.Keyboard and not BLOCKED[input.KeyCode] then
		return input.KeyCode.Name
	end

	return nil
end

local function matches(input: InputObject, key: string?): boolean
	if not key then
		return false
	end
	return nameFor(input) == key
end

local function mount(owner, container: Instance, opts, order: number, shouldRegister: boolean)
	local state = {
		window = owner.window,
		trove = owner.trove:Extend(),
		changed = Signal.new(),
		flag = opts.Flag,
		text = opts.Text or owner.text,
		mode = opts.Mode or "Toggle",
		callback = opts.Callback,
		value = nil,
		active = false,
		listening = false,
	}

	state.trove:Add(state.changed)

	state.owner = owner

	local chip = Create.surface(3, Theme.radius.small, {
		Name = "Keybind",
		Size = UDim2.fromOffset(Theme.metrics.chipWidth, Theme.chip()),
		LayoutOrder = order,
		ZIndex = 3,
		Parent = container,
	})
	local border = Create.stroke(Theme.line.control)
	border.Parent = chip
	Create.pad(0, Theme.space.sm, 0, Theme.space.sm).Parent = chip

	local label = Create.text({
		Name = "Key",
		Text = "None",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Font = Theme.font.mono,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = chip,
	})

	local button = Create.button({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = chip,
	})

	state.chip = chip
	state.border = border
	state.label = label

	local function paint()
		if state.listening then
			label.Text = "..."
			chip.BackgroundColor3 = Theme.fill
			label.TextColor3 = Theme.onFill
			border.Color = Theme.fill
			return
		end

		local bound = state.value ~= nil
		label.Text = state.value or "None"
		chip.BackgroundColor3 = if bound then Theme.fill else Theme.surface[3]
		label.TextColor3 = if bound then Theme.onFill else Theme.text[2]
		border.Color = if bound then Theme.fill else Theme.line.control
	end

	function state:Get()
		return self.value
	end

	function state:Set(value, silent)
		self.value = if type(value) == "string" and value ~= "" and value ~= "None" then value else nil
		paint()

		if not silent then
			self.changed:Fire(self.value)
		end

		if self.window.onBindChanged then
			self.window.onBindChanged()
		end

		return self
	end

	function state:OnChanged(callback)
		local disconnect = self.changed:Connect(callback)
		self.trove:Add(disconnect)
		return disconnect
	end

	function state:GetState(): boolean
		return self.active
	end

	function state:Destroy()
		if self.flag and self.window.registry then
			self.window.registry:unregister(self.flag, self)
		end

		local index = table.find(self.window.binds, self)
		if index then
			table.remove(self.window.binds, index)
		end

		if self.window.onBindChanged then
			self.window.onBindChanged()
		end

		self.trove:Clean()
	end

	state.trove:Connect(button.Activated, function()
		if state.owner and state.owner.enabled == false then
			return
		end
		state.listening = true
		state.window.capturing = state
		paint()
	end)

	state.trove:Connect(UserInputService.InputBegan, function(input, processed)
		if state.owner and state.owner.enabled == false then
			return
		end

		if state.listening then
			if input.KeyCode == Enum.KeyCode.Escape then
				state.listening = false
				state.window.capturing = nil
				paint()
				return
			end

			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				state.listening = false
				state.window.capturing = nil
				state:Set(nil)
				return
			end

			local reserved = state.window.toggleKey
			if reserved and input.KeyCode == reserved then
				return
			end

			local resolved = nameFor(input)
			if resolved then
				state.listening = false
				state.window.capturing = nil
				state:Set(resolved)
			end
			return
		end

		if processed or not matches(input, state.value) then
			return
		end

		if state.mode == "Toggle" then
			state.active = not state.active
			Element.guard(state, state.callback, state.active)
			if state.window.onBindChanged then
				state.window.onBindChanged()
			end
		elseif state.mode == "Hold" then
			state.active = true
			Element.guard(state, state.callback, true)
			if state.window.onBindChanged then
				state.window.onBindChanged()
			end
		else
			Element.guard(state, state.callback)
		end
	end)

	state.trove:Connect(UserInputService.InputEnded, function(input)
		if state.mode ~= "Hold" or not state.active then
			return
		end
		if matches(input, state.value) then
			state.active = false
			Element.guard(state, state.callback, false)
			if state.window.onBindChanged then
				state.window.onBindChanged()
			end
		end
	end)

	state:Set(opts.Default, true)

	if shouldRegister and state.flag then
		state.window.registry:register(state.flag, state)
	else
		state.flag = nil
	end

	table.insert(state.window.binds, state)

	if state.window.onBindChanged then
		state.window.onBindChanged()
	end

	return state
end

function Keybind.build(section, opts)
	local handle = Element.new(section, opts, { kind = "keybind" })
	local state = mount(handle, handle.slot, opts, 1, false)

	handle.bind = state
	handle.trove:Add(state)
	handle.callback = opts.Changed

	handle._apply = function(value)
		state:Set(value, true)
		return state.value
	end

	handle._onEnabled = function(enabled)
		state.chip.BackgroundTransparency = if enabled then 0 else 0.4
		state.border.Color = if enabled then Theme.line.control else Theme.line.disabled
		state.label.TextColor3 = if enabled then state.label.TextColor3 else Theme.text[3]
	end

	state:OnChanged(function(value)
		handle.value = value
		handle.changed:Fire(value)
		Element.guard(handle, handle.callback, value)
	end)

	handle.value = state.value

	return handle
end

function Keybind.attach(owner, opts)
	local state = mount(owner, owner.slot, opts, 0, true)
	owner.bind = state
	owner.trove:Add(state)
	return state
end

return Keybind
end

__modules["Keybinds"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")

local Keybinds = {}

local function drag(window, frame: GuiObject, grip: GuiObject, trove)
	local dragging = false
	local origin, startPos

	trove:Connect(grip.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			origin = input.Position
			startPos = frame.Position
		end
	end)

	trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - origin
		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local size = frame.AbsoluteSize
		local margin = 24

		frame.Position = UDim2.fromOffset(
			math.clamp(startPos.X.Offset + delta.X, margin - size.X, bounds.X - margin),
			math.clamp(startPos.Y.Offset + delta.Y, 0, bounds.Y - margin)
		)
	end)

	trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

function Keybinds.attach(window)
	if window.keybindPanel then
		return window.keybindPanel
	end

	local trove = window.trove:Extend()

	local panel = Create.new("CanvasGroup", {
		Name = "Keybinds",
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(Theme.space.xl, Theme.metrics.notificationTop),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 0,
		Visible = false,
		ZIndex = Theme.zone.keybinds,
		Parent = window.gui,
	})
	Create.corner(Theme.radius.section).Parent = panel
	Create.stroke(Theme.line.control).Parent = panel
	Create.list({ Padding = UDim.new(0, 0) }).Parent = panel

	trove:Add(panel)

	local header = Create.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		ZIndex = Theme.zone.keybinds,
		Parent = panel,
	})
	Create.pad(0, Theme.space.lg, 0, Theme.space.lg).Parent = header

	Create.text({
		Name = "Title",
		Text = "Keybinds",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Weight = "medium",
		Size = UDim2.fromScale(1, 1),
		ZIndex = Theme.zone.keybinds,
		Parent = header,
	})

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.keybinds,
		Parent = header,
	})

	local list = Create.frame({
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		ZIndex = Theme.zone.keybinds,
		Parent = panel,
	})
	Create.pad(Theme.space.md, Theme.space.lg, Theme.space.md, Theme.space.lg).Parent = list
	Create.list({ Padding = UDim.new(0, Theme.space.sm) }).Parent = list

	local empty = Create.text({
		Name = "Empty",
		Text = "Nothing bound",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		ZIndex = Theme.zone.keybinds,
		Parent = list,
	})

	drag(window, panel, header, trove)

	local rows = {}

	local function rebuild()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)

		local bound = {}
		for _, bind in window.binds do
			if bind.value then
				table.insert(bound, bind)
			end
		end

		empty.Visible = #bound == 0

		for index, bind in bound do
			local row = Create.new("Frame", {
				Name = "Bind",
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				LayoutOrder = index + 1,
				ZIndex = Theme.zone.keybinds,
				Parent = list,
			})

			local dot = Create.new("Frame", {
				Name = "State",
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = if bind.active then Theme.fill else Theme.line.control,
				BorderSizePixel = 0,
				ZIndex = Theme.zone.keybinds,
				Parent = row,
			})
			Create.corner(3).Parent = dot

			Create.text({
				Name = "Label",
				Text = tostring(bind.text or bind.flag or "Bind"),
				TextSize = Theme.size.tiny,
				TextColor3 = if bind.active then Theme.text[0] else Theme.text[1],
				Position = UDim2.new(0, 14, 0, 0),
				Size = UDim2.new(1, -(14 + 80 + Theme.space.md), 1, 0),
				ZIndex = Theme.zone.keybinds,
				Parent = row,
			})

			Create.text({
				Name = "Key",
				Text = tostring(bind.value),
				TextSize = Theme.size.tiny,
				TextColor3 = Theme.text[2],
				Font = Theme.font.mono,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.fromOffset(80, 18),
				ZIndex = Theme.zone.keybinds,
				Parent = row,
			})

			table.insert(rows, row)
		end
	end

	window.onBindChanged = rebuild
	rebuild()

	window.keybindPanel = {
		frame = panel,
		rebuild = rebuild,
		SetVisible = function(_, visible)
			panel.Visible = visible ~= false
			if visible then
				rebuild()
			end
		end,
	}

	return window.keybindPanel
end

function Keybinds.show(window, visible: boolean)
	local panel = Keybinds.attach(window)
	panel:SetVisible(visible ~= false)
	return panel
end

return Keybinds
end

__modules["Label"] = function()
local Element = require("Element")

local Label = {}

function Label.build(section, opts)
	local handle = Element.new(section, opts, {
		interactive = false,
		wrap = opts.Wrap == true,
		kind = "label",
	})

	handle.value = opts.Text or ""

	handle._apply = function(value)
		local text = tostring(value)
		handle:SetText(text)
		return text
	end

	return handle
end

return Label
end

__modules["Motion"] = function()
local TweenService = game:GetService("TweenService")

local Motion = {}

Motion.curve = {
	state = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	reveal = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	hover = TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	color = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	snap = TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	slide = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

Motion.staggerStep = 0.02
Motion.staggerCap = 8
Motion.revealLift = 8

local active = setmetatable({}, { __mode = "k" })

function Motion.cancel(instance: Instance)
	local record = active[instance]
	if not record then
		return
	end
	for property, tween in record do
		pcall(function()
			tween:Cancel()
		end)
		record[property] = nil
	end
end

function Motion.set(instance: Instance, props: { [string]: any })
	if typeof(instance) ~= "Instance" then
		return
	end
	Motion.cancel(instance)
	for property, value in props do
		pcall(function()
			(instance :: any)[property] = value
		end)
	end
end

function Motion.tween(instance: Instance, curve: TweenInfo, props: { [string]: any }, trove): Tween?
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local record = active[instance]
	if not record then
		record = {}
		active[instance] = record
	end

	for property in props do
		local existing = record[property]
		if existing then
			pcall(function()
				existing:Cancel()
			end)
		end
	end

	local ok, tween = pcall(TweenService.Create, TweenService, instance, curve, props)
	if not ok or typeof(tween) ~= "Instance" then
		return nil
	end

	for property in props do
		record[property] = tween
	end

	tween.Completed:Once(function()
		for property, stored in record do
			if stored == tween then
				record[property] = nil
			end
		end
		if trove then
			trove:Remove(tween)
		end
		pcall(function()
			tween:Destroy()
		end)
	end)

	if trove then
		trove:Add(tween)
	end

	tween:Play()
	return tween
end

function Motion.stagger(items: { Instance }, curve: TweenInfo, propsFor, step: number?, trove)
	local gap = step or Motion.staggerStep

	local capped = math.min(#items, Motion.staggerCap)

	for index, item in items do
		local wait = (math.min(index, capped) - 1) * gap

		if wait <= 0 then
			Motion.tween(item, curve, propsFor(item, index), trove)
		else
			local thread
			thread = task.delay(wait, function()
				if trove and thread then
					trove:Remove(thread)
				end
				if typeof(item) ~= "Instance" or item.Parent == nil then
					return
				end
				Motion.tween(item, curve, propsFor(item, index), trove)
			end)
			if trove then
				trove:Add(thread)
			end
		end
	end
end

function Motion.after(seconds: number, callback: () -> (), trove)
	local thread
	thread = task.delay(seconds, function()
		if trove and thread then
			trove:Remove(thread)
		end
		callback()
	end)

	if trove then
		trove:Add(thread)
	end

	return thread
end

return Motion
end

__modules["Notify"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")

local Notify = {}

local function container(window): Frame
	if window.notifyLayer and window.notifyLayer.Parent then
		return window.notifyLayer
	end

	local layer = Create.new("Frame", {
		Name = "Notifications",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = Theme.zone.notification,
		Parent = window.gui,
	})

	window.notifyLayer = layer
	window.notifications = window.notifications or {}
	window.trove:Add(layer)

	return layer
end

local function restack(window)
	local metrics = Theme.metrics
	local top = metrics.notificationTop

	for _, card in window.notifications do
		if card.frame.Parent then
			Motion.tween(card.frame, Motion.curve.slide, {
				Position = UDim2.new(1, -Theme.space.xl, 0, top),
			}, card.trove)
			top += card.frame.AbsoluteSize.Y + metrics.notificationGap
		end
	end
end

function Notify.push(window, opts)
	local metrics = Theme.metrics
	local layer = container(window)

	window.notifications = window.notifications or {}

	while #window.notifications >= metrics.notificationCap do
		local oldest = window.notifications[1]
		if oldest then
			oldest:Dismiss()
		else
			break
		end
	end

	local card = {
		window = window,
		trove = window.trove:Extend(),
		duration = tonumber(opts.Duration) or 5,
		dismissed = false,
	}

	local frame = Create.new("CanvasGroup", {
		Name = "Notification",
		Size = UDim2.fromOffset(metrics.notification, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, metrics.notification + Theme.space.xl, 0, metrics.notificationTop),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = Theme.zone.notification,
		Parent = layer,
	})
	Create.corner(Theme.radius.section).Parent = frame
	Create.stroke(Theme.line.control).Parent = frame

	card.frame = frame
	card.trove:Add(frame)

	Create.new("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 2, 1, -(Theme.space.lg * 2)),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 1,
		Parent = frame,
	})

	local body = Create.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = Theme.zone.notification,
		Parent = frame,
	})
	Create.pad(Theme.space.lg, Theme.space.lg, Theme.space.lg, Theme.space.lg + Theme.space.md).Parent = body
	Create.list({ Padding = UDim.new(0, Theme.space.xs) }).Parent = body

	local title = Create.text({
		Name = "Title",
		Text = tostring(opts.Title or "Notice"),
		TextSize = Theme.size.body,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		ZIndex = Theme.zone.notification,
		Parent = body,
	})

	local text
	if opts.Text and opts.Text ~= "" then
		text = Create.text({
			Name = "Text",
			Text = tostring(opts.Text),
			TextSize = Theme.size.small,
			TextColor3 = Theme.text[2],
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.2,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			ZIndex = Theme.zone.notification,
			Parent = body,
		})

		Create.new("UISizeConstraint", {
			MaxSize = Vector2.new(math.huge, Theme.size.small * 1.2 * metrics.notificationLines),
			Parent = text,
		})
	end

	local rail = Create.new("Frame", {
		Name = "Progress",
		Size = UDim2.new(1, -(Theme.space.lg * 2), 0, 2),
		Position = UDim2.new(0, Theme.space.lg, 1, -Theme.space.md),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.line.control,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 1,
		Parent = frame,
	})
	Create.corner(1).Parent = rail

	local fillBar = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 2,
		Parent = rail,
	})
	Create.corner(1).Parent = fillBar

	local hit = Create.button({
		Name = "Dismiss",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.zone.notification + 3,
		Parent = frame,
	})

	table.insert(window.notifications, card)

	function card:Dismiss()
		if self.dismissed then
			return
		end
		self.dismissed = true

		local index = table.find(window.notifications, self)
		if index then
			table.remove(window.notifications, index)
		end

		Motion.tween(frame, Motion.curve.exit, {
			Position = UDim2.new(1, metrics.notification + Theme.space.xl, 0, frame.Position.Y.Offset),
			GroupTransparency = 1,
		}, self.trove)

		Motion.after(0.24, function()
			window.trove:Remove(self.trove)
			self.trove:Destroy()
			restack(window)
		end, self.trove)

		restack(window)
	end

	function card:Update(changes)
		if changes.Title then
			title.Text = tostring(changes.Title)
		end
		if changes.Text and text then
			text.Text = tostring(changes.Text)
		end
		if changes.Progress then
			local alpha = math.clamp(tonumber(changes.Progress) or 0, 0, 1)
			Motion.tween(fillBar, Motion.curve.slide, { Size = UDim2.fromScale(alpha, 1) }, self.trove)
		end
		return self
	end

	card.trove:Connect(hit.Activated, function()
		card:Dismiss()
	end)

	card.trove:Connect(frame:GetPropertyChangedSignal("AbsoluteSize"), function()
		restack(window)
	end)

	card.trove:Add(task.defer(function()
		if frame.Parent == nil then
			return
		end
		restack(window)
		Motion.tween(frame, Motion.curve.reveal, { GroupTransparency = 0 }, card.trove)
	end))

	if card.duration > 0 then
		Motion.tween(fillBar, TweenInfo.new(card.duration, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(0, 1),
		}, card.trove)

		Motion.after(card.duration, function()
			card:Dismiss()
		end, card.trove)
	else
		rail.Visible = false
	end

	return card
end

return Notify
end

__modules["Page"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Section = require("Section")

local Page = {}
Page.__index = Page

function Page.new(window, name: string)
	local self = setmetatable({}, Page)
	self.window = window
	self.name = name
	self.trove = window.trove:Extend()
	self.sections = {}
	self.single = false
	self.revealed = false

	local scroll = Create.scroll({
		Name = "Page",
		Size = UDim2.new(1, -Theme.space.md, 1, -Theme.space.md),
		Visible = false,
	})
	Create.pad(Theme.space.xl).Parent = scroll

	local holder = Create.frame({
		Name = "Columns",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, Theme.metrics.columnGap),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}).Parent = holder

	local function column(order: number)
		local frame = Create.frame({
			Name = "Column",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = holder,
		})
		Create.list({ Padding = UDim.new(0, Theme.metrics.columnGap) }).Parent = frame
		return frame
	end

	self.scroll = scroll
	self.holder = holder
	self.left = column(1)
	self.right = column(2)

	self.trove:Add(scroll)

	self.trove:Connect(scroll:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:measure()
	end)

	self.trove:Add(task.defer(function()
		if scroll.Parent then
			self:measure()
		end
	end))

	return self
end

function Page:measure()
	local usable = self.scroll.AbsoluteSize.X
		- (Theme.space.xl * 2)
		- Theme.metrics.scrollBar

	if usable <= 0 then
		return
	end

	self.holder.Size = UDim2.fromOffset(usable, 0)

	if self.single then
		self.left.Size = UDim2.fromOffset(usable, 0)
		self.right.Size = UDim2.fromOffset(usable, 0)
	else
		local each = math.floor((usable - Theme.metrics.columnGap) / 2)
		self.left.Size = UDim2.fromOffset(each, 0)
		self.right.Size = UDim2.fromOffset(each, 0)
	end
end

function Page:Section(title: string?, opts: { [string]: any }?)
	return Section.new(self, title, opts)
end

function Page:ConfigSection(opts: { [string]: any }?)
	return require("Config").section(self, opts)
end

function Page:place(section)
	table.insert(self.sections, section)
	self:assign(section, #self.sections)
end

function Page:unplace(section)
	local index = table.find(self.sections, section)
	if not index then
		return
	end

	table.remove(self.sections, index)

	for ordinal = index, #self.sections do
		self:assign(self.sections[ordinal], ordinal)
	end
end

function Page:assign(section, ordinal: number)
	local target

	if self.single then
		target = self.left
	elseif section.column == "left" then
		target = self.left
	elseif section.column == "right" then
		target = self.right
	elseif ordinal % 2 == 1 then
		target = self.left
	else
		target = self.right
	end

	section.frame.LayoutOrder = ordinal
	section.frame.Parent = target
end

function Page:reflow(width: number)
	local single = width < Theme.metrics.twoColumnAt
	if single == self.single then
		return
	end

	self.single = single
	self.right.Visible = not single

	self:measure()

	for ordinal, section in self.sections do
		self:assign(section, ordinal)
	end
end

function Page:rows(): { Instance }
	local collected = {}
	for _, section in self.sections do
		if section.frame.Visible then
			table.insert(collected, section.frame)
		end
	end
	return collected
end

function Page:Show()
	self.scroll.Visible = true

	local targets = self:rows()
	if #targets == 0 then
		return
	end

	for _, frame in targets do
		Motion.cancel(frame)
		frame.GroupTransparency = 1
	end

	Motion.stagger(targets, Motion.curve.reveal, function()
		return { GroupTransparency = 0 }
	end, Motion.staggerStep, self.trove)

	self.revealed = true
end

function Page:Hide()
	self.scroll.Visible = false
end

function Page:Destroy()
	for _, section in table.clone(self.sections) do
		section:Destroy()
	end
	self.sections = {}
	self.trove:Destroy()
end

return Page
end

__modules["Rail"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Icons = require("Icons")
local Env = require("Env")

local Rail = {}
Rail.__index = Rail

function Rail.new(window)
	local metrics = Theme.metrics
	local cell = if Env.isTouch then metrics.railIconTouch else metrics.railIcon

	local self = setmetatable({}, Rail)
	self.window = window
	self.trove = window.trove:Extend()
	self.items = {}
	self.cell = cell
	self.gap = Theme.space.sm
	self.active = nil

	local frame = Create.new("Frame", {
		Name = "Rail",
		Size = UDim2.new(0, metrics.rail, 1, -metrics.titleBar),
		Position = UDim2.fromOffset(0, metrics.titleBar),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	})
	Create.corner(Theme.radius.window).Parent = frame

	Create.new("Frame", {
		Name = "TopFill",
		Size = UDim2.new(1, 0, 0, Theme.radius.window),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})

	Create.new("Frame", {
		Name = "EdgeFill",
		Size = UDim2.new(0, Theme.radius.window, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = frame,
	})

	local list = Create.scroll({
		Name = "Items",
		Size = UDim2.new(1, 0, 1, -(metrics.cornerClear * 2)),
		Position = UDim2.fromOffset(0, metrics.cornerClear),
		ScrollBarThickness = 2,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ZIndex = 3,
		Parent = frame,
	})
	Create.list({
		Padding = UDim.new(0, self.gap),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}).Parent = list

	local indicator = Create.new("Frame", {
		Name = "Indicator",
		Size = UDim2.fromOffset(metrics.railIndicator.X, cell),
		Position = UDim2.fromOffset(0, metrics.cornerClear),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = frame,
	})
	Create.corner(Theme.radius.small).Parent = indicator

	self.frame = frame
	self.list = list
	self.indicator = indicator
	self.trove:Add(frame)

	self.trove:Connect(list:GetPropertyChangedSignal("CanvasPosition"), function()
		if self.active then
			self:place(self.active, true)
		end
	end)

	return self
end

function Rail:place(item, instant: boolean?)
	local offset = Theme.metrics.cornerClear
		+ (item.ordinal - 1) * (self.cell + self.gap)
		- self.list.CanvasPosition.Y

	local target = UDim2.fromOffset(0, offset)

	if instant or not self.indicator.Visible then
		Motion.cancel(self.indicator)
		self.indicator.Position = target
		self.indicator.Visible = true
	else
		Motion.tween(self.indicator, Motion.curve.slide, { Position = target }, self.trove)
	end
end

function Rail:add(name: string, icon: any, onSelect)
	local metrics = Theme.metrics
	local ordinal = #self.items + 1

	local button = Create.button({
		Name = "Tab",
		Size = UDim2.fromOffset(self.cell, self.cell),
		BackgroundTransparency = 1,
		LayoutOrder = ordinal,
		ZIndex = 3,
		Parent = self.list,
	})

	local asset = Icons.resolve(icon)
	local glyph

	if asset then
		glyph = Create.image({
			Name = "Glyph",
			Image = asset,
			Size = UDim2.fromOffset(metrics.railGlyph, metrics.railGlyph),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Theme.text[2],
			ZIndex = 3,
			Parent = button,
		})
	else
		glyph = Create.text({
			Name = "Mark",
			Text = Icons.letter(name),
			TextSize = Theme.size.hero,
			TextColor3 = Theme.text[2],
			Weight = "medium",
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = button,
		})
	end

	local item = {
		name = name,
		button = button,
		glyph = glyph,
		isImage = asset ~= nil,
		ordinal = ordinal,
	}

	table.insert(self.items, item)

	self.trove:Connect(button.MouseEnter, function()
		if self.active ~= item then
			self:paint(item, Theme.text[1])
		end
		self.window:showTooltip(name, button)
	end)

	self.trove:Connect(button.MouseLeave, function()
		if self.active ~= item then
			self:paint(item, Theme.text[2])
		end
		self.window:hideTooltip()
	end)

	self.trove:Connect(button.Activated, function()
		onSelect()
	end)

	return item
end

function Rail:paint(item, color: Color3)
	if item.isImage then
		Motion.tween(item.glyph, Motion.curve.hover, { ImageColor3 = color }, self.trove)
	else
		Motion.tween(item.glyph, Motion.curve.hover, { TextColor3 = color }, self.trove)
	end
end

function Rail:select(item)
	if self.active == item then
		return
	end

	if self.active then
		self:paint(self.active, Theme.text[2])
	end

	self.active = item
	self:paint(item, Theme.text[0])
	self:place(item)
end

function Rail:Destroy()
	self.trove:Clean()
	table.clear(self.items)
end

return Rail
end

__modules["Registry"] = function()
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
end

__modules["Search"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")

local Search = {}

local MAX_RESULTS = 8

local function score(needle: string, hay: string): number
	if needle == "" then
		return 0
	end

	local target = string.lower(hay)
	local query = string.lower(needle)

	local exact = string.find(target, query, 1, true)
	if exact then
		return 1000 - exact * 2 - #target
	end

	local index = 1
	local hits = 0
	local streak = 0
	local best = 0

	for position = 1, #target do
		if index > #query then
			break
		end
		if string.sub(target, position, position) == string.sub(query, index, index) then
			index += 1
			hits += 1
			streak += 1
			best = math.max(best, streak)
		else
			streak = 0
		end
	end

	if index <= #query then
		return -1
	end

	return 400 + best * 20 - #target
end

local function locate(window, handle)
	local page = handle.section and handle.section.page
	if not page then
		return nil
	end

	for _, tab in window.tabs do
		if tab.page == page then
			return tab
		end
	end

	return nil
end

local function jump(window, handle)
	local tab = locate(window, handle)
	if not tab then
		return
	end

	window:closePopup()
	window:select(tab)

	task.defer(function()
		local scroll = tab.page.scroll
		local anchor = handle.section and handle.section.anchorRow

		if not scroll.Parent then
			return
		end

		local row = if anchor then anchor.frame else handle.frame
		if not row.Parent then
			return
		end

		local offset = row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		scroll.CanvasPosition = Vector2.new(0, math.max(offset - Theme.space.xxxl, 0))

		if handle.section and handle.section.openMenu then
			handle.section.openMenu()
		end

		Motion.tween(row, Motion.curve.reveal, { BackgroundTransparency = 0 }, handle.trove)
		Motion.after(0.3, function()
			if row.Parent then
				Motion.tween(row, Motion.curve.reveal, { BackgroundTransparency = 1 }, handle.trove)
			end
		end, handle.trove)
	end)
end

function Search.open(window)
	if window.searchOpen then
		window:closePopup()
		return
	end

	local trove = window.trove:Extend()
	window.searchOpen = true

	local panel = Create.new("CanvasGroup", {
		Name = "Search",
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0.5, 0, 0, Theme.metrics.notificationTop),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = Theme.zone.popup,
	})
	Create.corner(Theme.radius.section).Parent = panel
	Create.stroke(Theme.line.control).Parent = panel
	Create.list({ Padding = UDim.new(0, 0) }).Parent = panel

	trove:Add(panel)

	local head = Create.new("Frame", {
		Name = "Head",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = Theme.zone.popup,
		Parent = panel,
	})
	Create.pad(0, Theme.space.lg, 0, Theme.space.lg).Parent = head

	local box = Create.input({
		Name = "Query",
		PlaceholderText = "Search settings",
		TextSize = Theme.size.body,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Theme.zone.popup,
		Parent = head,
	})

	local rule = Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = Theme.zone.popup,
		Parent = panel,
	})

	local list = Create.frame({
		Name = "Results",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = Theme.zone.popup,
		Parent = panel,
	})
	Create.pad(Theme.space.xs).Parent = list
	Create.list({ Padding = UDim.new(0, 1) }).Parent = list

	local hint = Create.text({
		Name = "Hint",
		Text = "Type to find any setting",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[2],
		Position = UDim2.fromOffset(Theme.space.md, 0),
		Size = UDim2.new(1, -Theme.space.lg, 0, 30),
		LayoutOrder = 1,
		ZIndex = Theme.zone.popup,
		Parent = list,
	})

	local rows = {}
	local rowsTrove = trove:Extend()

	local function clear()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)

		trove:Remove(rowsTrove)
		rowsTrove:Destroy()
		rowsTrove = trove:Extend()
	end

	local function refresh()
		clear()

		local query = box.Text
		if query == "" then
			hint.Visible = true
			rule.Visible = false
			return
		end

		hint.Visible = false

		local matches = {}

		for flag, handle in window.registry:each() do
			local label = handle.text or flag
			if type(label) == "string" and handle.frame then
				local sectionName = handle.section and handle.section.title or ""
				local rank = math.max(score(query, label), score(query, tostring(sectionName)) - 100)
				if rank > 0 then
					table.insert(matches, { handle = handle, label = label, rank = rank, section = sectionName })
				end
			end
		end

		table.sort(matches, function(left, right)
			return left.rank > right.rank
		end)

		rule.Visible = #matches > 0

		if #matches == 0 then
			local none = Create.text({
				Name = "None",
				Text = "No matches",
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[2],
				Position = UDim2.fromOffset(Theme.space.md, 0),
				Size = UDim2.new(1, -Theme.space.lg, 0, 30),
				LayoutOrder = 2,
				ZIndex = Theme.zone.popup,
				Parent = list,
			})
			table.insert(rows, none)
			return
		end

		for index = 1, math.min(#matches, MAX_RESULTS) do
			local match = matches[index]

			local row = Create.button({
				Name = "Result",
				Text = "",
				Size = UDim2.new(1, 0, 0, Theme.metrics.buttonHeight),
				BackgroundColor3 = Theme.surface[4],
				BackgroundTransparency = 1,
				LayoutOrder = index + 1,
				ZIndex = Theme.zone.popup,
				Parent = list,
			})
			Create.corner(Theme.radius.small).Parent = row

			Create.text({
				Name = "Label",
				Text = match.label,
				TextSize = Theme.size.small,
				TextColor3 = Theme.text[0],
				Position = UDim2.new(0, Theme.space.md, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0.6, -Theme.space.md, 1, 0),
				ZIndex = Theme.zone.popup,
				Parent = row,
			})

			local where = Create.text({
				Name = "Where",
				Text = tostring(match.section or ""),
				TextSize = Theme.size.tiny,
				TextColor3 = Theme.text[2],
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -Theme.space.md, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.new(0.4, -Theme.space.md, 1, 0),
				ZIndex = Theme.zone.popup,
				Parent = row,
			})

			rowsTrove:Connect(row.MouseEnter, function()
				Motion.tween(row, Motion.curve.hover, { BackgroundTransparency = 0 }, trove)
				Motion.tween(where, Motion.curve.hover, { TextColor3 = Theme.lifted(Theme.text[2]) }, trove)
			end)
			rowsTrove:Connect(row.MouseLeave, function()
				Motion.tween(row, Motion.curve.hover, { BackgroundTransparency = 1 }, trove)
				Motion.tween(where, Motion.curve.hover, { TextColor3 = Theme.text[2] }, trove)
			end)
			rowsTrove:Connect(row.Activated, function()
				jump(window, match.handle)
			end)

			table.insert(rows, row)
		end
	end

	trove:Connect(box:GetPropertyChangedSignal("Text"), refresh)
	refresh()

	window:openPopup(panel, function()
		window.searchOpen = false
		local fade = Motion.tween(panel, Motion.curve.exit, { GroupTransparency = 1 }, trove)
		if fade then
			fade.Completed:Once(function()
				window.trove:Remove(trove)
				trove:Destroy()
			end)
		else
			trove:Clean()
		end
	end)

	Motion.tween(panel, Motion.curve.reveal, { GroupTransparency = 0 }, trove)
	box:CaptureFocus()

	return panel
end

return Search
end

__modules["Section"] = function()
local Theme = require("Theme")
local Create = require("Create")

local Section = {}
Section.__index = Section

local ELEMENTS = {
	Label = "Label",
	Divider = "Divider",
	Button = "Button",
	Toggle = "Toggle",
	Checkbox = "Checkbox",
	Slider = "Slider",
	Input = "Input",
	Dropdown = "Dropdown",
	Keybind = "Keybind",
	Color = "ColorPicker",
	Viewport = "Viewport",
	Image = "Image",
}

function Section.new(page, title: string?, opts: { [string]: any }?)
	local options = opts or {}

	local self = setmetatable({}, Section)
	self.window = page.window
	self.page = page
	self.trove = page.trove:Extend()
	self.rows = {}
	self.title = title
	self.column = options.Column

	local frame = Create.new("CanvasGroup", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 0,
	})
	Create.corner(Theme.radius.section).Parent = frame
	Create.stroke(Theme.line.soft).Parent = frame
	Create.list({ Padding = UDim.new(0, 0) }).Parent = frame

	self.frame = frame
	self.trove:Add(frame)

	if title then
		local header = Create.frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 0,
			Parent = frame,
		})
		Create.pad(Theme.space.md, Theme.space.lg, Theme.space.md, Theme.space.lg).Parent = header

		Create.text({
			Name = "Title",
			Text = title,
			TextSize = Theme.size.tiny,
			TextColor3 = Theme.text[2],
			Weight = "medium",
			Size = UDim2.new(1, 0, 0, 13),
			Parent = header,
		})

		Create.new("Frame", {
			Name = "Rule",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.line.soft,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = frame,
		})
	end

	self.body = Create.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.list({ Padding = UDim.new(0, 0) }).Parent = self.body

	if options.Parent then
		self.detached = true
		frame.Parent = options.Parent
	else
		page:place(self)
	end

	return self
end

function Section:addRow(row)
	table.insert(self.rows, row)
	self:restripe()
	return row
end

function Section:restripe()
	local last = #self.rows

	for index, entry in self.rows do
		entry.frame.LayoutOrder = index
		if entry.divider then
			entry.divider.Visible = index < last and not entry.noDivider
		end
	end
end

function Section:removeRow(row)
	local index = table.find(self.rows, row)
	if index then
		table.remove(self.rows, index)
	end

	self:restripe()
end

function Section:SetVisible(visible: boolean)
	self.frame.Visible = visible ~= false
end

function Section:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	for _, row in table.clone(self.rows) do
		if row.Destroy then
			row:Destroy()
		end
	end
	self.rows = {}

	if self.page then
		self.page:unplace(self)
	end

	self.trove:Destroy()
end

for method, module in ELEMENTS do
	Section[method] = function(self, opts)
		return require(module).build(self, opts or {})
	end
end

return Section
end

__modules["Signal"] = function()
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
end

__modules["Slider"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Env = require("Env")
local Element = require("Element")

local Slider = {}

local function roundTo(value: number, decimals: number): number
	local factor = 10 ^ math.max(decimals, 0)
	return math.floor(value * factor + 0.5) / factor
end

function Slider.build(section, opts)
	local minimum = tonumber(opts.Min) or 0
	local maximum = tonumber(opts.Max) or 100

	if not (maximum > minimum) then
		error(
			"Umbra: slider '"
				.. tostring(opts.Flag or opts.Text or "?")
				.. "' has Max ("
				.. tostring(maximum)
				.. ") not greater than Min ("
				.. tostring(minimum)
				.. ")",
			0
		)
	end

	local decimals = math.max(math.floor(tonumber(opts.Rounding) or 0), 0)
	local step = tonumber(opts.Step)
	local suffix = opts.Suffix and tostring(opts.Suffix) or ""

	local handle = Element.new(section, opts, { kind = "slider" })

	local metrics = Theme.metrics
	local height = if Env.isTouch then metrics.rowTouch else metrics.row

	local formatWarned = false

	local function format(value: number): string
		if type(opts.Format) == "function" then
			local ok, text = pcall(opts.Format, value)
			if ok and type(text) == "string" then
				return text
			end
			if not formatWarned then
				formatWarned = true
				local Signal = require("Signal")
				Signal.onError(
					"slider '" .. tostring(opts.Flag or opts.Text or "?") .. "' Format failed: " .. tostring(text)
				)
			end
		end
		return string.format("%." .. math.max(decimals, 0) .. "f", value) .. suffix
	end

	local widest = math.max(
		Create.measure(format(minimum), Theme.size.small, Theme.font.mono),
		Create.measure(format(maximum), Theme.size.small, Theme.font.mono)
	)

	local valueWidth = math.clamp(math.ceil(widest) + 2, metrics.sliderValueMin, metrics.sliderValueMax)
	local trackWidth = math.max(metrics.controlMax - Theme.space.sm - valueWidth, metrics.sliderTrackMin)

	local pad = Create.button({
		Name = "TrackPad",
		Size = UDim2.fromOffset(trackWidth, height),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})

	local track = Create.new("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, metrics.sliderTrack),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.line.control,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = pad,
	})
	Create.corner(2).Parent = track

	local filled = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	})
	Create.corner(2).Parent = filled

	local knob = Create.new("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(metrics.sliderKnob, metrics.sliderKnob),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	Create.corner(metrics.sliderKnob / 2).Parent = knob

	local readout = Create.text({
		Name = "Value",
		Text = format(minimum),
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		Font = Theme.font.mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromOffset(valueWidth, 16),
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = handle.slot,
	})
	handle:track(readout)

	local dragging = false

	local function quantise(value: number): number
		local clamped = math.clamp(value, minimum, maximum)
		if step and step > 0 then
			clamped = minimum + math.floor((clamped - minimum) / step + 0.5) * step
		end
		return math.clamp(roundTo(clamped, decimals), minimum, maximum)
	end

	handle._apply = function(value)
		local resolved = quantise(tonumber(value) or minimum)
		local alpha = (resolved - minimum) / (maximum - minimum)

		if dragging then
			Motion.set(filled, { Size = UDim2.fromScale(alpha, 1) })
			Motion.set(knob, { Position = UDim2.fromScale(alpha, 0.5) })
		else
			Motion.tween(filled, Motion.curve.slide, { Size = UDim2.fromScale(alpha, 1) }, handle.trove)
			Motion.tween(knob, Motion.curve.slide, { Position = UDim2.fromScale(alpha, 0.5) }, handle.trove)
		end

		readout.Text = format(resolved)

		return resolved
	end

	handle._onEnabled = function(enabled)
		pad.Active = enabled
		Motion.set(filled, { BackgroundColor3 = if enabled then Theme.fill else Theme.line.control })
		Motion.set(knob, { BackgroundColor3 = if enabled then Theme.fill else Theme.line.control })
		Motion.set(track, { BackgroundColor3 = if enabled then Theme.line.control else Theme.line.disabled })
	end

	local function applyFrom(x: number)
		local origin = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - origin) / width, 0, 1)
		handle:Set(minimum + alpha * (maximum - minimum))
	end

	handle.trove:Connect(pad.InputBegan, function(input)
		if not handle.enabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		Motion.tween(knob, Motion.curve.state, {
			Size = UDim2.fromOffset(metrics.sliderKnobDrag, metrics.sliderKnobDrag),
		}, handle.trove)
		applyFrom(input.Position.X)
	end)

	handle.trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		applyFrom(input.Position.X)
	end)

	handle.trove:Connect(UserInputService.InputEnded, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = false
		Motion.tween(knob, Motion.curve.state, {
			Size = UDim2.fromOffset(metrics.sliderKnob, metrics.sliderKnob),
		}, handle.trove)
	end)

	handle:Set(if opts.Default ~= nil then opts.Default else minimum, true)

	return handle
end

return Slider
end

__modules["SubMenu"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Icons = require("Icons")
local Section = require("Section")

local SubMenu = {}

local function marks(button: TextButton, asset: string?)
	if asset then
		local picture = Create.image({
			Name = "Glyph",
			Image = asset,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Theme.text[2],
			ZIndex = 4,
			Parent = button,
		})
		return { picture }
	end

	local dots = {}

	for index = 1, 3 do
		local dot = Create.new("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(2, 2),
			Position = UDim2.new(0.5, (index - 2) * 5, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.text[2],
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = button,
		})
		Create.corner(1).Parent = dot
		table.insert(dots, dot)
	end

	return dots
end

local function paint(parts, colour: Color3)
	for _, part in parts do
		if part:IsA("ImageLabel") then
			part.ImageColor3 = colour
		else
			part.BackgroundColor3 = colour
		end
	end
end

function SubMenu.attach(owner, opts)
	local settings = opts or {}
	local window = owner.window
	local metrics = Theme.metrics

	local trove = owner.trove:Extend()
	local size = if Theme.isTouch then metrics.menuButtonTouch else metrics.menuButton
	local open = false

	local button = Create.button({
		Name = "Menu",
		Text = "",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.surface[3],
		BackgroundTransparency = 0,
		LayoutOrder = settings.Order or 8,
		ZIndex = 3,
		Parent = owner.slot,
	})
	Create.corner(Theme.radius.small).Parent = button

	local border = Create.stroke(Theme.line.control)
	border.Parent = button

	local glyphs = marks(button, Icons.resolve(settings.Icon))

	local panel = Create.new("CanvasGroup", {
		Name = "SubMenu",
		Size = UDim2.fromOffset(metrics.menuWidth, 0),
		BackgroundColor3 = Theme.surface[1],
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = Theme.zone.popup,
	})
	Create.corner(Theme.radius.section).Parent = panel
	Create.stroke(Theme.line.control).Parent = panel
	trove:Add(panel)

	local scroll = Create.scroll({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		ZIndex = Theme.zone.popup,
		Parent = panel,
	})
	Create.pad(Theme.space.md).Parent = scroll

	local proxy = {
		window = window,
		trove = trove,
	}

	function proxy:place() end
	function proxy:unplace() end

	local section = Section.new(proxy, settings.Title or owner.text, { Parent = scroll })

	section.page = owner.section and owner.section.page or nil
	section.anchorRow = owner

	local function resize()
		local content = section.frame.AbsoluteSize.Y
		if content <= 0 then
			return
		end
		local height = math.clamp(content + Theme.space.md * 2, 48, metrics.menuMaxHeight)
		panel.Size = UDim2.fromOffset(metrics.menuWidth, math.floor(height))
	end

	trove:Connect(section.frame:GetPropertyChangedSignal("AbsoluteSize"), resize)

	local function close()
		if not open then
			return
		end
		open = false

		paint(glyphs, Theme.text[2])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.control }, trove)

		local fade = Motion.tween(panel, Motion.curve.exit, { GroupTransparency = 1 }, trove)
		local function finish()
			panel.Parent = nil
		end

		if fade then
			fade.Completed:Once(finish)
		else
			finish()
		end
	end

	local function show()
		if open then
			return
		end
		open = true

		resize()

		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)

		local anchor = button.AbsolutePosition
		local anchorSize = button.AbsoluteSize
		local height = panel.AbsoluteSize.Y
		if height <= 0 then
			height = metrics.menuMaxHeight
		end

		local x = math.clamp(
			anchor.X + anchorSize.X - metrics.menuWidth,
			Theme.space.md,
			math.max(bounds.X - metrics.menuWidth - Theme.space.md, Theme.space.md)
		)

		local y = anchor.Y + anchorSize.Y + Theme.space.xs
		if y + height > bounds.Y then
			y = math.max(anchor.Y - height - Theme.space.xs, Theme.space.md)
		end

		panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		panel.GroupTransparency = 1

		paint(glyphs, Theme.text[0])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.focus }, trove)

		window:openPopup(panel, close)
		Motion.tween(panel, Motion.curve.reveal, { GroupTransparency = 0 }, trove)

		task.defer(resize)
	end

	trove:Connect(button.Activated, function()
		if owner.enabled == false then
			return
		end
		if open then
			window:closePopup()
		else
			show()
		end
	end)

	trove:Connect(button.MouseEnter, function()
		Motion.tween(button, Motion.curve.hover, { BackgroundColor3 = Theme.surface[4] }, trove)
	end)

	trove:Connect(button.MouseLeave, function()
		Motion.tween(button, Motion.curve.hover, { BackgroundColor3 = Theme.surface[3] }, trove)
	end)

	section.openMenu = show
	section.closeMenu = close
	section.owner = owner
	section.button = button

	owner.menu = section

	return section
end

return SubMenu
end

__modules["Theme"] = function()
local Env = require("Env")

local Theme = {}

Theme.isTouch = Env.isTouch

Theme.surface = {
	[0] = Color3.fromRGB(8, 8, 8),
	[1] = Color3.fromRGB(18, 18, 18),
	[2] = Color3.fromRGB(30, 30, 30),
	[3] = Color3.fromRGB(42, 42, 42),
	[4] = Color3.fromRGB(58, 58, 58),
}

Theme.line = {
	soft = Color3.fromRGB(63, 63, 63),
	control = Color3.fromRGB(110, 110, 110),
	focus = Color3.fromRGB(160, 160, 160),
	disabled = Color3.fromRGB(63, 63, 63),
}

Theme.text = {
	[0] = Color3.fromRGB(255, 255, 255),
	[1] = Color3.fromRGB(180, 180, 180),
	[2] = Color3.fromRGB(148, 148, 148),
	[3] = Color3.fromRGB(110, 110, 110),
}

Theme.fill = Color3.fromRGB(255, 255, 255)
Theme.onFill = Color3.fromRGB(8, 8, 8)
Theme.knobOff = Color3.fromRGB(148, 148, 148)
Theme.scrim = Color3.fromRGB(0, 0, 0)
Theme.scrimTransparency = 0.45

Theme.size = {
	hero = 18,
	title = 14,
	body = 13,
	small = 12,
	tiny = 11,
}

Theme.radius = {
	window = 10,
	section = 8,
	control = 6,
	small = 4,
	hair = 2,
}

Theme.space = {
	xs = 4,
	sm = 6,
	md = 8,
	lg = 12,
	xl = 16,
	xxl = 20,
	xxxl = 24,
}

Theme.metrics = {
	windowDefault = Vector2.new(620, 420),
	windowMin = Vector2.new(480, 340),

	titleBar = 40,
	rail = 52,
	railIcon = 32,
	railIconTouch = 44,
	railGlyph = 18,
	railIndicator = Vector2.new(2, 32),
	cornerClear = 12,

	row = 32,
	rowTouch = 44,
	rowPad = 12,
	rowGap = 8,
	labelMin = 88,
	controlMax = 112,

	twoColumnAt = 600,
	columnGap = 12,
	columnMin = 232,
	scrollBar = 4,

	fieldHeight = 24,
	fieldHeightTouch = 32,
	chipHeight = 18,
	chipHeightTouch = 24,
	buttonHeight = 32,
	chipWidth = 76,
	hexWidth = 48,

	toggleTrack = Vector2.new(32, 16),
	toggleKnob = 12,
	toggleInset = 2,
	checkbox = 16,
	swatch = 16,
	swatchTouch = 26,
	sliderTrack = 3,
	sliderKnob = 10,
	sliderKnobDrag = 12,
	sliderValueMin = 20,
	sliderValueMax = 56,
	sliderTrackMin = 40,
	chevron = 12,

	touchTarget = 44,

	menuButton = 20,
	menuButtonTouch = 32,
	menuWidth = 250,
	menuMaxHeight = 320,

	dropdownRow = 28,
	dropdownMaxRows = 8,
	pickerWidth = 200,
	pickerSquare = 120,
	pickerStrip = 10,
	tooltipMax = 200,

	notification = 230,
	notificationTop = 48,
	notificationGap = 8,
	notificationCap = 5,
	notificationLines = 4,

	staggerCap = 8,
}

Theme.zone = {
	body = 1,
	watermark = 5,
	keybinds = 6,
	overlay = 20,
	popup = 21,
	notification = 30,
	tooltip = 40,
	dialog = 50,
}

Theme.font = {
	regular = Enum.Font.GothamMedium,
	medium = Enum.Font.GothamBold,
	mono = Enum.Font.RobotoMono,
}

function Theme.field(): number
	return if Theme.isTouch then Theme.metrics.fieldHeightTouch else Theme.metrics.fieldHeight
end

function Theme.chip(): number
	return if Theme.isTouch then Theme.metrics.chipHeightTouch else Theme.metrics.chipHeight
end

function Theme.lifted(color: Color3): Color3
	if color == Theme.text[2] then
		return Theme.text[1]
	end
	if color == Theme.text[1] then
		return Theme.text[0]
	end
	return color
end

return Theme
end

__modules["Toggle"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Toggle = {}

function Toggle.build(section, opts)
	local handle = Element.new(section, opts, { kind = "toggle" })

	local metrics = Theme.metrics
	local track = metrics.toggleTrack
	local knobSize = metrics.toggleKnob
	local inset = metrics.toggleInset
	local travel = track.X - (inset * 2) - knobSize

	local body = Create.new("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(track.X, track.Y),
		BackgroundColor3 = Theme.surface[3],
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	Create.corner(track.Y / 2).Parent = body

	local edge = Create.stroke(Theme.line.control)
	edge.Parent = body

	local knob = Create.new("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(knobSize, knobSize),
		Position = UDim2.new(0, inset, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.knobOff,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	})
	Create.corner(knobSize / 2).Parent = knob

	handle._apply = function(value)
		local on = value == true

		Motion.tween(body, Motion.curve.color, {
			BackgroundColor3 = if on then Theme.fill else Theme.surface[3],
		}, handle.trove)

		Motion.tween(edge, Motion.curve.color, {
			Color = if on then Theme.fill else Theme.line.control,
		}, handle.trove)

		Motion.tween(knob, Motion.curve.state, {
			Position = UDim2.new(0, if on then inset + travel else inset, 0.5, 0),
		}, handle.trove)

		Motion.tween(knob, Motion.curve.snap, {
			BackgroundColor3 = if on then Theme.onFill else Theme.knobOff,
		}, handle.trove)

		return on
	end

	handle._onEnabled = function(enabled)
		if enabled then
			handle._apply(handle.value)
			return
		end

		Motion.set(body, { BackgroundColor3 = Theme.surface[3] })
		Motion.set(edge, { Color = Theme.line.disabled })
		Motion.set(knob, { BackgroundColor3 = Theme.text[3] })
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			handle:Set(not handle.value)
		end
	end)

	handle:Set(opts.Default == true, true)

	return handle
end

return Toggle
end

__modules["Trove"] = function()
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
end

__modules["Umbra"] = function()
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
end

__modules["Viewport"] = function()
local Theme = require("Theme")
local Create = require("Create")
local Element = require("Element")

local Viewport = {}

function Viewport.build(section, opts)
	local height = tonumber(opts.Height) or 120

	local handle = Element.new(section, opts, {
		interactive = false,
		label = false,
		height = height + Theme.space.md * 2,
		kind = "viewport",
	})

	local frame = Create.new("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, height),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0, Theme.space.md),
		BackgroundColor3 = Theme.surface[3],
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ZIndex = 2,
		Parent = handle.frame,
	})
	Create.corner(Theme.radius.control).Parent = frame
	Create.stroke(Theme.line.soft).Parent = frame

	local world = Create.new("WorldModel", { Name = "World", Parent = frame })

	local missing = Create.text({
		Name = "Missing",
		Text = "No model",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = frame,
	})

	local camera = Create.new("Camera", {
		Name = "Camera",
		FieldOfView = tonumber(opts.FieldOfView) or 40,
		Parent = frame,
	})
	frame.CurrentCamera = camera

	handle.viewport = frame
	handle.world = world
	handle.camera = camera

	function handle:SetModel(model: Instance?)
		for _, child in world:GetChildren() do
			child:Destroy()
		end

		missing.Visible = true

		if not model then
			return self
		end

		local ok, clone = pcall(function()
			return model:Clone()
		end)

		if not ok or not clone then
			return self
		end

		missing.Visible = false

		clone.Parent = world

		local pivot, extent

		local sized = pcall(function()
			if clone:IsA("Model") then
				pivot = clone:GetPivot()
				extent = clone:GetExtentsSize()
			elseif clone:IsA("BasePart") then
				pivot = clone.CFrame
				extent = clone.Size
			end
		end)

		if not sized or not pivot or not extent then
			return self
		end

		local radius = math.max(extent.X, extent.Y, extent.Z)
		if radius <= 0 then
			radius = 1
		end
		local distance = (radius / math.tan(math.rad(camera.FieldOfView / 2))) * (tonumber(opts.Zoom) or 0.85)
		local direction = Vector3.new(1, 0.55, 1).Unit

		camera.CFrame = CFrame.lookAt(pivot.Position + direction * distance, pivot.Position)

		return self
	end

	handle._apply = function(value)
		handle:SetModel(if typeof(value) == "Instance" then value else nil)
		return value
	end

	if opts.Model then
		handle:SetModel(opts.Model)
	end

	return handle
end

return Viewport
end

__modules["Watermark"] = function()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local Theme = require("Theme")
local Create = require("Create")

local Watermark = {}

local SAMPLE = 0.25

local function ping(): number
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		return math.floor(value + 0.5)
	end
	return 0
end

local function clock(): string
	local total = math.floor(os.time() % 86400)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local seconds = total % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function Watermark.attach(window, opts)
	local settings = opts or {}

	if window.watermark then
		window.watermark:Update(settings)
		return window.watermark
	end

	local trove = window.trove:Extend()

	local bar = Create.new("Frame", {
		Name = "Watermark",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(Theme.space.xl, Theme.space.xl),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		ZIndex = Theme.zone.watermark,
		Parent = window.gui,
	})
	Create.corner(Theme.radius.control).Parent = bar
	Create.stroke(Theme.line.control).Parent = bar
	Create.pad(0, Theme.space.lg, 0, Theme.space.lg).Parent = bar
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.space.md),
	}).Parent = bar

	trove:Add(bar)

	local label = Create.text({
		Name = "Label",
		Text = tostring(settings.Text or window.name),
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = Theme.zone.overlay,
		Parent = bar,
	})

	local readout = Create.text({
		Name = "Stats",
		Text = "",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Font = Theme.font.mono,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = Theme.zone.overlay,
		Parent = bar,
	})

	local dragging = false
	local origin, startPos

	trove:Connect(bar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			origin = input.Position
			startPos = bar.Position
		end
	end)

	trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - origin
		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local size = bar.AbsoluteSize
		local margin = 24

		bar.Position = UDim2.fromOffset(
			math.clamp(startPos.X.Offset + delta.X, margin - size.X, bounds.X - margin),
			math.clamp(startPos.Y.Offset + delta.Y, 0, bounds.Y - margin)
		)
	end)

	trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local frames = 0
	local elapsed = 0
	local fps = 0
	local config = settings

	trove:Connect(RunService.Heartbeat, function(delta)
		frames += 1
		elapsed += delta

		if elapsed < SAMPLE then
			return
		end

		fps = math.floor(frames / elapsed + 0.5)
		frames = 0
		elapsed = 0

		local parts = {}

		if config.Fps ~= false then
			table.insert(parts, tostring(fps) .. " fps")
		end
		if config.Ping then
			table.insert(parts, tostring(ping()) .. " ms")
		end
		if config.Clock then
			table.insert(parts, clock())
		end

		readout.Text = table.concat(parts, "  ")
		readout.Visible = #parts > 0
	end)

	window.watermark = {
		frame = bar,
		Update = function(_, changes)
			if type(changes) == "table" then
				for key, value in changes do
					config[key] = value
				end
			end
			if config.Text then
				label.Text = tostring(config.Text)
			end
			bar.Visible = true
		end,
		SetVisible = function(_, visible)
			bar.Visible = visible ~= false
		end,
		Destroy = function()
			trove:Clean()
			window.watermark = nil
		end,
	}

	return window.watermark
end

return Watermark
end

__modules["Window"] = function()
local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Trove = require("Trove")
local Signal = require("Signal")
local Env = require("Env")
local Registry = require("Registry")
local Rail = require("Rail")
local Page = require("Page")
local Home = require("Home")

local Window = {}
Window.__index = Window

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

function Window.new(opts)
	local metrics = Theme.metrics

	if opts.Size ~= nil and typeof(opts.Size) ~= "Vector2" then
		error("Umbra: Size must be a Vector2, got " .. typeof(opts.Size), 0)
	end

	local requested = opts.Size or metrics.windowDefault
	local size = Vector2.new(
		math.max(requested.X, metrics.windowMin.X),
		math.max(requested.Y, metrics.windowMin.Y)
	)

	local self = setmetatable({}, Window)
	self.trove = Trove.new()
	self.registry = Registry.new()
	self.tabs = {}
	self.binds = {}
	self.name = opts.Name or "Umbra"
	self.version = opts.Version
	self.visible = true
	self.popups = {}
	self.modal = 0
	self.closed = Signal.new()

	self.Flags = setmetatable({}, {
		__index = function(_, flag)
			local handle = self.registry:get(flag)
			if handle then
				return handle:Get()
			end
			return nil
		end,
		__newindex = function(_, flag, value)
			local handle = self.registry:get(flag)
			if handle then
				handle:Set(value)
			else
				warn("[Umbra] no element with Flag '" .. tostring(flag) .. "' — assignment ignored")
			end
		end,
	})

	local gui = Create.new("ScreenGui", {
		Name = "Umbra",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 999,
		Enabled = true,
	})
	self.gui = gui
	self.trove:Add(gui)

	local start = viewport()
	local root = Create.new("CanvasGroup", {
		Name = "Root",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(
			math.floor((start.X - size.X) / 2),
			math.floor((start.Y - size.Y) / 2)
		),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Theme.surface[1],
		BorderSizePixel = 0,
		GroupTransparency = 0,
		ZIndex = Theme.zone.body,
		Parent = gui,
	})
	Create.corner(Theme.radius.window).Parent = root
	Create.stroke(Theme.line.soft).Parent = root
	self.root = root


	self.overlay = Create.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = Theme.zone.overlay,
		Parent = gui,
	})

	self.restore = Create.button({
		Name = "Restore",
		Text = "U",
		Weight = "medium",
		TextSize = Theme.size.title,
		TextColor3 = Theme.onFill,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(metrics.touchTarget, metrics.touchTarget),
		Position = UDim2.new(0, Theme.space.xl, 0.5, -(metrics.touchTarget / 2)),
		BackgroundColor3 = Theme.fill,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = Theme.zone.notification,
		Parent = gui,
	})
	Create.corner(Theme.radius.control).Parent = self.restore

	self.trove:Connect(self.restore.Activated, function()
		self:show()
	end)

	self.tipLayer = Create.new("Frame", {
		Name = "Tooltips",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = Theme.zone.tooltip,
		Parent = gui,
	})

	self:buildTitleBar()

	self.rail = Rail.new(self)
	self.rail.frame.Parent = root

	self.content = Create.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(metrics.rail, metrics.titleBar),
		Size = UDim2.new(1, -metrics.rail, 1, -metrics.titleBar),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 1,
		Parent = root,
	})

	self:buildResizeGrip()
	self:bindDrag()
	self:bindToggle(opts.Toggle)

	self.trove:Connect(root:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:closePopups()
		for _, tab in self.tabs do
			tab.page:reflow(root.AbsoluteSize.X)
		end
	end)

	local mounted = Env.mount(gui)
	if mounted == "none" then
		error(
			"Umbra: could not mount the interface. gethui, CoreGui and PlayerGui were all unavailable (executor: "
				.. tostring(Env.executor)
				.. ")",
			0
		)
	end
	self.mountedTo = mounted

	if opts.Home ~= false then
		self.home = Home.build(self, if type(opts.Home) == "table" then opts.Home else {})
	end

	self:open()

	return self
end

function Window:buildTitleBar()
	local metrics = Theme.metrics

	local bar = Create.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, metrics.titleBar),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 4,
		Parent = self.root,
	})
	Create.corner(Theme.radius.window).Parent = bar

	Create.new("Frame", {
		Name = "BottomFill",
		Size = UDim2.new(1, 0, 0, Theme.radius.window),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = bar,
	})

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = bar,
	})

	self.dragArea = Create.new("Frame", {
		Name = "DragArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = bar,
	})

	local title = Create.text({
		Name = "Title",
		Text = self.name,
		TextSize = Theme.size.title,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		Position = UDim2.new(0, Theme.space.lg, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5,
		Parent = bar,
	})

	Create.new("UISizeConstraint", {
		MaxSize = Vector2.new(200, math.huge),
		Parent = title,
	})

	if self.version then
		local pill = Create.surface(3, Theme.radius.small, {
			Name = "Version",
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 5,
			Parent = bar,
		})
		Create.stroke(Theme.line.soft).Parent = pill
		Create.pad(0, Theme.space.md, 0, Theme.space.md).Parent = pill

		Create.text({
			Name = "Label",
			Text = tostring(self.version),
			TextSize = Theme.size.tiny,
			TextColor3 = Theme.text[2],
			Font = Theme.font.mono,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 5,
			Parent = pill,
		})

		self.trove:Connect(title:GetPropertyChangedSignal("AbsoluteSize"), function()
			pill.Position = UDim2.new(0, Theme.space.lg + title.AbsoluteSize.X + Theme.space.md, 0.5, 0)
		end)
		pill.Position = UDim2.new(0, Theme.space.lg + title.AbsoluteSize.X + Theme.space.md, 0.5, 0)
	end

	local actions = Create.new("Frame", {
		Name = "Actions",
		Position = UDim2.new(1, -Theme.space.lg, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = bar,
	})
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.space.xs),
	}).Parent = actions

	local hitSize = if Theme.isTouch then Theme.metrics.touchTarget else 24

	local function action(name: string, order: number, draw, callback)
		local button = Create.button({
			Name = name,
			Text = "",
			Size = UDim2.fromOffset(hitSize, hitSize),
			LayoutOrder = order,
			BackgroundColor3 = Theme.surface[3],
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = actions,
		})
		Create.corner(Theme.radius.small).Parent = button

		local parts = draw(button)

		local function paint(color: Color3)
			for _, part in parts do
				local property = "BackgroundColor3"
				if part:IsA("UIStroke") then
					property = "Color"
				elseif part:IsA("TextLabel") or part:IsA("TextButton") then
					property = "TextColor3"
				end
				Motion.tween(part, Motion.curve.hover, { [property] = color }, self.trove)
			end
		end

		self.trove:Connect(button.MouseEnter, function()
			Motion.tween(button, Motion.curve.hover, { BackgroundTransparency = 0 }, self.trove)
			paint(Theme.text[0])
		end)
		self.trove:Connect(button.MouseLeave, function()
			Motion.tween(button, Motion.curve.hover, { BackgroundTransparency = 1 }, self.trove)
			paint(Theme.text[2])
		end)
		self.trove:Connect(button.Activated, callback)

		return button
	end

	local function bar1(button, props)
		local piece = Create.new("Frame", {
			Name = "Piece",
			BackgroundColor3 = Theme.text[2],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 6,
			Parent = button,
		})
		for key, value in props do
			(piece :: any)[key] = value
		end
		return piece
	end

	action("Search", 1, function(button)
		local ring = bar1(button, {
			Size = UDim2.fromOffset(11, 11),
			Position = UDim2.new(0.5, -2, 0.5, -2),
			BackgroundTransparency = 1,
		})
		Create.corner(6).Parent = ring

		local edge = Create.stroke(Theme.text[2], 1.5)
		edge.Parent = ring

		local grip = bar1(button, {
			Size = UDim2.fromOffset(2, 7),
			Position = UDim2.new(0.5, 4, 0.5, 4),
			Rotation = 45,
		})
		Create.corner(1).Parent = grip

		return { grip, edge }
	end, function()
		require("Search").open(self)
	end)

	action("Minimise", 2, function(button)
		local line = bar1(button, {
			Size = UDim2.fromOffset(11, 1),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		return { line }
	end, function()
		self:hide()
	end)

	action("Close", 3, function(button)
		local glyph = Create.text({
			Name = "Glyph",
			Text = "X",
			TextSize = Theme.size.small,
			TextColor3 = Theme.text[2],
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = button,
		})
		return { glyph }
	end, function()
		require("Dialog").confirm(self, {
			Title = "Unload " .. self.name .. "?",
			Text = "Every feature stops and the menu is removed.",
			Confirm = "Unload",
			Callback = function()
				require("Umbra"):Unload()
			end,
		})
	end)

	self.titleBar = bar
end

function Window:buildResizeGrip()
	local grip = Create.button({
		Name = "Resize",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -2, 1, -2),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
		Parent = self.root,
	})

	for index = 1, 3 do
		Create.new("Frame", {
			Name = "Notch",
			Size = UDim2.fromOffset(2, 2),
			Position = UDim2.fromOffset(12 - (index - 1) * 4, 12),
			BackgroundColor3 = Theme.line.control,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = grip,
		})
	end

	local resizing = false
	local origin, startSize

	self.trove:Connect(grip.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			origin = input.Position
			startSize = self.root.AbsoluteSize
			self:closePopups()
		end
	end)

	self.trove:Connect(UserInputService.InputChanged, function(input)
		if not resizing then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - origin
		local bounds = viewport()
		local minimum = Theme.metrics.windowMin

		local width = math.clamp(math.round(startSize.X + delta.X), minimum.X, bounds.X)
		local height = math.clamp(math.round(startSize.Y + delta.Y), minimum.Y, bounds.Y)

		self.root.Size = UDim2.fromOffset(width, height)
	end)

	self.trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)
end

function Window:bindDrag()
	local dragging = false
	local origin, startPos

	self.trove:Connect(self.dragArea.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			origin = input.Position
			startPos = self.root.Position
			self:closePopups()
			self:hideTooltip()
		end
	end)

	self.trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - origin
		local bounds = viewport()
		local size = self.root.AbsoluteSize
		local margin = 60

		local x = math.clamp(startPos.X.Offset + delta.X, margin - size.X, bounds.X - margin)
		local y = math.clamp(startPos.Y.Offset + delta.Y, 0, bounds.Y - margin)

		self.root.Position = UDim2.fromOffset(math.round(x), math.round(y))
	end)

	self.trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

function Window:bindToggle(key)
	if key ~= nil and typeof(key) ~= "EnumItem" then
		error("Umbra: Toggle must be an Enum.KeyCode, got " .. typeof(key), 0)
	end

	self.toggleKey = key or Enum.KeyCode.RightControl

	self.trove:Connect(UserInputService.InputBegan, function(input, processed)
		if processed or self.capturing then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == self.toggleKey then
			self:toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.popup then
			self:closePopup()
		end
	end)
end

function Window:Tab(name: string, icon: any?)
	local page = Page.new(self, name)
	page.scroll.Parent = self.content

	local tab = { name = name, page = page }

	tab.item = self.rail:add(name, icon, function()
		self:select(tab)
	end)

	table.insert(self.tabs, tab)

	page:reflow(self.root.AbsoluteSize.X)

	if #self.tabs == 1 then
		self:select(tab)
	end

	return page
end

function Window:select(tab)
	if self.activeTab == tab then
		return
	end

	self:closePopups()

	if self.activeTab then
		self.activeTab.page:Hide()
	end

	self.activeTab = tab
	tab.page.scroll.CanvasPosition = Vector2.new(0, 0)
	tab.page:Show()
	self.rail:select(tab.item)
end

function Window:Element(flag: string)
	return self.registry:get(flag)
end

function Window:Config(opts)
	return require("Config").attach(self, opts or {})
end

function Window:isBlocked(): boolean
	return #self.popups > 0 or self.modal > 0
end

function Window:openPopup(frame: GuiObject, onClose)
	local depth = #self.popups

	local catcher = Create.button({
		Name = "Catcher",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.zone.overlay + depth * 2,
		Parent = self.overlay,
	})

	frame.Parent = self.overlay
	frame.ZIndex = Theme.zone.popup + depth * 2

	local connection = catcher.Activated:Connect(function()
		self:closePopup()
	end)

	table.insert(self.popups, {
		frame = frame,
		onClose = onClose,
		catcher = catcher,
		connection = connection,
	})
end

function Window:closePopups()
	while #self.popups > 0 do
		self:closePopup()
	end
end

function Window:closePopup()
	local popup = table.remove(self.popups)
	if not popup then
		return
	end

	if popup.connection then
		popup.connection:Disconnect()
	end
	if popup.catcher then
		popup.catcher:Destroy()
	end

	if popup.onClose then
		local ok, err = pcall(popup.onClose)
		if not ok then
			Signal.onError("popup close failed: " .. tostring(err))
		end
	end
end

function Window:showTooltip(text: string, anchor: GuiObject)
	if not text or text == "" then
		return
	end

	self:hideTooltip()

	local tip = Create.surface(3, Theme.radius.small, {
		Name = "Tooltip",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = Theme.zone.tooltip,
		Parent = self.tipLayer,
	})
	Create.stroke(Theme.line.control).Parent = tip
	Create.pad(Theme.space.sm, Theme.space.md, Theme.space.sm, Theme.space.md).Parent = tip

	local label = Create.text({
		Name = "Text",
		Text = text,
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[1],
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = Theme.zone.tooltip,
		Parent = tip,
	})
	Create.new("UISizeConstraint", {
		MaxSize = Vector2.new(Theme.metrics.tooltipMax, math.huge),
		Parent = label,
	})

	self.tooltip = tip

	local bounds = viewport()
	local anchorPos = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize

	tip.Position = UDim2.fromOffset(anchorPos.X, anchorPos.Y + anchorSize.Y + Theme.space.md)

	local thread
	thread = task.defer(function()
		if thread then
			self.trove:Remove(thread)
		end
		if tip.Parent == nil then
			return
		end

		local width = tip.AbsoluteSize.X
		local height = tip.AbsoluteSize.Y

		local x = math.min(anchorPos.X, bounds.X - width - Theme.space.md)
		local y = anchorPos.Y + anchorSize.Y + Theme.space.md

		if y + height > bounds.Y then
			y = anchorPos.Y - height - Theme.space.md
		end

		tip.Position = UDim2.fromOffset(math.max(x, Theme.space.md), math.max(y, Theme.space.md))
	end)

	self.trove:Add(thread)
end

function Window:hideTooltip()
	if self.tooltip then
		self.tooltip:Destroy()
		self.tooltip = nil
	end
end

function Window:open()
	self.visible = true
	self.gui.Enabled = true
	self.root.Visible = true
	self.root.GroupTransparency = 1

	Motion.tween(self.root, Motion.curve.reveal, { GroupTransparency = 0 }, self.trove)
end

function Window:hide()
	if not self.visible then
		return
	end
	self.visible = false
	self:closePopups()
	self:hideTooltip()
	self.restore.Visible = Env.isTouch

	local fade = Motion.tween(self.root, Motion.curve.exit, { GroupTransparency = 1 }, self.trove)

	if fade then
		fade.Completed:Once(function()
			if not self.visible then
				self.root.Visible = false
			end
		end)
	else
		self.root.Visible = false
	end

	self.closed:Fire()
end

function Window:show()
	if self.visible then
		return
	end
	self.restore.Visible = false
	self.root.Visible = true
	self:open()
end

function Window:toggle()
	if self.visible then
		self:hide()
	else
		self:show()
	end
end

function Window:Destroy()
	self:closePopups()
	self:hideTooltip()

	for _, tab in table.clone(self.tabs) do
		tab.page:Destroy()
	end
	table.clear(self.tabs)

	self.registry:Destroy()
	self.closed:Destroy()
	self.trove:Destroy()
end

return Window
end

local Umbra = require("Umbra")

local Window = Umbra:Window({
	Name = "Umbra Hub",
	Version = "1.0.0",
	Toggle = Enum.KeyCode.RightControl,
	Home = {
		Changelog = {
			{ Version = "1.0.0", Notes = { "First release", "Every element" } },
			{ Version = "0.9.0", Notes = { "Config manager" } },
		},
		Links = {
			{ Text = "Discord", Url = "https://discord.gg/example" },
			{ Text = "Get key", Url = "https://example.com/key" },
		},
		Credits = { "Built with Umbra", "UI by Umbra" },
	},
})

local Combat = Window:Tab("Combat")
local Visuals = Window:Tab("Visuals")
local Misc = Window:Tab("Misc")
local Settings = Window:Tab("Settings")

local Targeting = Combat:Section("Targeting")

Targeting:Toggle({
	Flag = "silent_aim",
	Text = "Silent aim",
	Default = false,
	Callback = function(on)
		print("silent aim:", on)
	end,
})
	:Bind({ Flag = "silent_key", Text = "Silent aim", Default = "MB2", Mode = "Hold" })
	:Tip("Redirects shots")

Targeting:Toggle({ Flag = "auto_fire", Text = "Auto fire", Default = false })

Targeting:Slider({
	Flag = "fov",
	Text = "FOV",
	Min = 0,
	Max = 360,
	Default = 124,
	Suffix = "deg",
})

Targeting:Slider({
	Flag = "smoothing",
	Text = "Smoothing",
	Min = 0,
	Max = 1,
	Default = 0.35,
	Rounding = 2,
})

Targeting:Dropdown({
	Flag = "hitbox",
	Text = "Hitbox",
	Options = { "Head", "Torso", "Nearest" },
	Default = "Head",
})

local Filters = Combat:Section("Filters")

Filters:Checkbox({ Flag = "wall_check", Text = "Wall check", Default = true })
Filters:Checkbox({ Flag = "team_check", Text = "Team check", Default = true })

Filters:Dropdown({
	Flag = "targets",
	Text = "Targets",
	Source = "Players",
	Multi = true,
	ExcludeLocal = true,
})

Filters:Keybind({
	Flag = "panic",
	Text = "Panic",
	Default = "F4",
	Mode = "Press",
	Callback = function()
		Umbra:Notify({ Title = "Panic", Text = "Everything off", Duration = 3 })
	end,
})

local Esp = Visuals:Section("ESP")

Esp:Toggle({ Flag = "box_esp", Text = "Boxes", Default = true })
	:Color({ Flag = "box_color", Text = "Boxes", Default = Color3.fromRGB(255, 59, 48) })

Esp:Toggle({ Flag = "name_esp", Text = "Names", Default = false })
	:Color({ Flag = "name_color", Text = "Names", Default = Color3.fromRGB(48, 209, 88) })

Esp:Slider({ Flag = "thickness", Text = "Thickness", Min = 0.5, Max = 5, Default = 1.4, Rounding = 1 })

local Tracers = Esp:Toggle({ Flag = "tracer_esp", Text = "Tracers", Default = false })
	:Menu({ Title = "Tracer options" })

Tracers:Dropdown({
	Flag = "tracer_origin",
	Text = "Origin",
	Options = { "Bottom", "Centre", "Mouse" },
	Default = "Bottom",
})

Tracers:Slider({ Flag = "tracer_width", Text = "Width", Min = 0.5, Max = 5, Default = 1, Rounding = 1 })

Tracers:Toggle({ Flag = "tracer_fade", Text = "Fade by distance", Default = true })
	:Menu({ Title = "Fade" })
	:Slider({ Flag = "tracer_fade_max", Text = "Max studs", Min = 50, Max = 2000, Default = 500 })

Tracers:Divider({})

Tracers:Button({
	Text = "Reset tracers",
	Confirm = true,
	Callback = function()
		Umbra:Notify({ Title = "Tracers reset", Duration = 3 })
	end,
})

local Look = Visuals:Section("Look")

Look:Color({ Flag = "accent", Text = "Highlight", Default = Color3.fromRGB(255, 255, 255) })
Look:Divider({})
Look:Label({ Text = "Colours apply to your own drawings only.", Wrap = true })

local Tools = Misc:Section("Tools")

Tools:Input({
	Flag = "webhook",
	Text = "Webhook",
	Placeholder = "https://",
	MaxLength = 120,
})

Tools:Input({ Flag = "count", Text = "Count", Numeric = true, Default = "10" })

Tools:Button({
	Text = "Copy job id",
	Callback = function()
		Umbra:Notify({ Title = "Copied", Text = tostring(game.JobId), Duration = 4 })
	end,
})

Tools:Button({
	Text = "Rejoin",
	Confirm = true,
	Callback = function()
		Umbra:Notify({ Title = "Rejoining", Duration = 3 })
	end,
})

local Media = Misc:Section("Media")
local Players = game:GetService("Players")

local gotThumb, thumb = pcall(function()
	return Players:GetUserThumbnailAsync(
		Players.LocalPlayer.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size150x150
	)
end)

Media:Image({ Image = if gotThumb then thumb else nil, Height = 90 })
Media:Viewport({ Model = Players.LocalPlayer.Character, Height = 110 })

local Interface = Settings:Section("Interface")

Interface:Toggle({
	Flag = "watermark",
	Text = "Watermark",
	Default = true,
	Callback = function(on)
		Umbra:Watermark({ Text = "Umbra Hub", Fps = true, Ping = true, Clock = true })
		if Window.watermark then
			Window.watermark:SetVisible(on)
		end
	end,
})

Interface:Toggle({
	Flag = "keybind_list",
	Text = "Keybind list",
	Default = true,
	Callback = function(on)
		Umbra:Keybinds(on)
	end,
})

Interface:Button({
	Text = "Unload",
	Confirm = true,
	Callback = function()
		Umbra:Unload()
	end,
})

Window:Config({ Folder = "ExampleHub", Autoload = true })
Settings:ConfigSection()

Umbra:Watermark({ Text = "Umbra Hub", Fps = true, Ping = true })
Umbra:Keybinds(true)

Umbra:OnUnload(function()
	print("hub unloaded")
end)

Window:Element("fov"):OnChanged(function(value)
	print("fov is now", value)
end)

print("flags:", Window.Flags.silent_aim, Window.Flags.fov)
