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
	self.popup = nil
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
		Position = UDim2.fromOffset(Theme.space.xl, metrics.notificationTop),
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
		self:closePopup()
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
			self:closePopup()
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
			self:closePopup()
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

	self:closePopup()

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
	return self.popup ~= nil or self.modal > 0
end

function Window:openPopup(frame: GuiObject, onClose)
	self:closePopup()

	local catcher = Create.button({
		Name = "Catcher",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.zone.overlay,
		Parent = self.overlay,
	})

	frame.Parent = self.overlay

	local connection = catcher.Activated:Connect(function()
		self:closePopup()
	end)

	self.popup = {
		frame = frame,
		onClose = onClose,
		catcher = catcher,
		connection = connection,
	}
end

function Window:closePopup()
	local popup = self.popup
	if not popup then
		return
	end
	self.popup = nil

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
	self:closePopup()
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
	self:closePopup()
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
