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
