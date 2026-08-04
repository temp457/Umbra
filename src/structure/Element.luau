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
			if not (self.hovered and self.enabled) then
				instance.TextColor3 = color
			else
				instance.TextColor3 = Theme.lifted(color)
			end
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
