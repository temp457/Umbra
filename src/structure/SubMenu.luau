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

	section.frame.Size = UDim2.fromOffset(
		metrics.menuWidth - Theme.space.md * 2 - metrics.scrollBar,
		0
	)

	section.page = owner.section and owner.section.page or nil
	section.anchorRow = owner

	trove:Add(section)

	local generation = 0
	local height = 48
	local token = nil

	local function place()
		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)

		local anchor = button.AbsolutePosition
		local anchorSize = button.AbsoluteSize

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
	end

	local function resize()
		local content = section.frame.AbsoluteSize.Y
		if content <= 0 then
			return
		end

		height = math.floor(math.clamp(content + Theme.space.md * 2, 48, metrics.menuMaxHeight))
		panel.Size = UDim2.fromOffset(metrics.menuWidth, height)

		if open then
			place()
		end
	end

	trove:Connect(section.frame:GetPropertyChangedSignal("AbsoluteSize"), resize)

	local function close()
		if not open then
			return
		end

		open = false
		token = nil
		generation += 1

		local mine = generation

		paint(glyphs, Theme.text[2])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.control }, trove)

		local function finish()
			if mine ~= generation then
				return
			end
			pcall(function()
				panel.Parent = nil
			end)
		end

		local fade = Motion.tween(panel, Motion.curve.exit, { GroupTransparency = 1 }, trove)
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
		generation += 1

		panel.Size = UDim2.fromOffset(metrics.menuWidth, height)
		place()
		panel.GroupTransparency = 1

		paint(glyphs, Theme.text[0])
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.focus }, trove)

		token = window:openPopup(panel, close)
		Motion.tween(panel, Motion.curve.reveal, { GroupTransparency = 0 }, trove)

		trove:Add(task.defer(function()
			if open then
				resize()
			end
		end))
	end

	trove:Connect(button.Activated, function()
		if owner.enabled == false then
			return
		end
		if open then
			window:closePopup(token)
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

	trove:Add(function()
		if open and token then
			window:closePopup(token)
		end
	end)

	return section
end

return SubMenu
