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
