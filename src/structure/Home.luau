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
