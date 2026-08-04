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
		if not scroll.Parent or not handle.frame.Parent then
			return
		end

		local offset = handle.frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		scroll.CanvasPosition = Vector2.new(0, math.max(offset - Theme.space.xxxl, 0))

		local row = handle.frame

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
