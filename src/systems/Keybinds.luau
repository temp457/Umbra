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
