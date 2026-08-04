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
