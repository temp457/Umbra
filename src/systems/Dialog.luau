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
