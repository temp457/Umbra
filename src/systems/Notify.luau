local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")

local Notify = {}

local function container(window): Frame
	if window.notifyLayer and window.notifyLayer.Parent then
		return window.notifyLayer
	end

	local layer = Create.new("Frame", {
		Name = "Notifications",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = Theme.zone.notification,
		Parent = window.gui,
	})

	window.notifyLayer = layer
	window.notifications = window.notifications or {}
	window.trove:Add(layer)

	return layer
end

local function restack(window)
	local metrics = Theme.metrics
	local top = metrics.notificationTop

	for _, card in window.notifications do
		if card.frame.Parent then
			Motion.tween(card.frame, Motion.curve.slide, {
				Position = UDim2.new(1, -Theme.space.xl, 0, top),
			}, card.trove)
			top += card.frame.AbsoluteSize.Y + metrics.notificationGap
		end
	end
end

function Notify.push(window, opts)
	local metrics = Theme.metrics
	local layer = container(window)

	window.notifications = window.notifications or {}

	while #window.notifications >= metrics.notificationCap do
		local oldest = window.notifications[1]
		if oldest then
			oldest:Dismiss()
		else
			break
		end
	end

	local card = {
		window = window,
		trove = window.trove:Extend(),
		duration = tonumber(opts.Duration) or 5,
		dismissed = false,
	}

	local frame = Create.new("CanvasGroup", {
		Name = "Notification",
		Size = UDim2.fromOffset(metrics.notification, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, metrics.notification + Theme.space.xl, 0, metrics.notificationTop),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = Theme.zone.notification,
		Parent = layer,
	})
	Create.corner(Theme.radius.section).Parent = frame
	Create.stroke(Theme.line.control).Parent = frame

	card.frame = frame
	card.trove:Add(frame)

	Create.new("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 2, 1, -(Theme.space.lg * 2)),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 1,
		Parent = frame,
	})

	local body = Create.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = Theme.zone.notification,
		Parent = frame,
	})
	Create.pad(Theme.space.lg, Theme.space.lg, Theme.space.lg, Theme.space.lg + Theme.space.md).Parent = body
	Create.list({ Padding = UDim.new(0, Theme.space.xs) }).Parent = body

	local title = Create.text({
		Name = "Title",
		Text = tostring(opts.Title or "Notice"),
		TextSize = Theme.size.body,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		ZIndex = Theme.zone.notification,
		Parent = body,
	})

	local text
	if opts.Text and opts.Text ~= "" then
		text = Create.text({
			Name = "Text",
			Text = tostring(opts.Text),
			TextSize = Theme.size.small,
			TextColor3 = Theme.text[2],
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.2,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			ZIndex = Theme.zone.notification,
			Parent = body,
		})

		Create.new("UISizeConstraint", {
			MaxSize = Vector2.new(math.huge, Theme.size.small * 1.2 * metrics.notificationLines),
			Parent = text,
		})
	end

	local rail = Create.new("Frame", {
		Name = "Progress",
		Size = UDim2.new(1, -(Theme.space.lg * 2), 0, 2),
		Position = UDim2.new(0, Theme.space.lg, 1, -Theme.space.md),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.line.control,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 1,
		Parent = frame,
	})
	Create.corner(1).Parent = rail

	local fillBar = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = Theme.zone.notification + 2,
		Parent = rail,
	})
	Create.corner(1).Parent = fillBar

	local hit = Create.button({
		Name = "Dismiss",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.zone.notification + 3,
		Parent = frame,
	})

	table.insert(window.notifications, card)

	function card:Dismiss()
		if self.dismissed then
			return
		end
		self.dismissed = true

		local index = table.find(window.notifications, self)
		if index then
			table.remove(window.notifications, index)
		end

		Motion.tween(frame, Motion.curve.exit, {
			Position = UDim2.new(1, metrics.notification + Theme.space.xl, 0, frame.Position.Y.Offset),
			GroupTransparency = 1,
		}, self.trove)

		Motion.after(0.24, function()
			window.trove:Remove(self.trove)
			self.trove:Destroy()
			restack(window)
		end, self.trove)

		restack(window)
	end

	function card:Update(changes)
		if changes.Title then
			title.Text = tostring(changes.Title)
		end
		if changes.Text and text then
			text.Text = tostring(changes.Text)
		end
		if changes.Progress then
			local alpha = math.clamp(tonumber(changes.Progress) or 0, 0, 1)
			Motion.tween(fillBar, Motion.curve.slide, { Size = UDim2.fromScale(alpha, 1) }, self.trove)
		end
		return self
	end

	card.trove:Connect(hit.Activated, function()
		card:Dismiss()
	end)

	card.trove:Connect(frame:GetPropertyChangedSignal("AbsoluteSize"), function()
		restack(window)
	end)

	card.trove:Add(task.defer(function()
		if frame.Parent == nil then
			return
		end
		restack(window)
		Motion.tween(frame, Motion.curve.reveal, { GroupTransparency = 0 }, card.trove)
	end))

	if card.duration > 0 then
		Motion.tween(fillBar, TweenInfo.new(card.duration, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(0, 1),
		}, card.trove)

		Motion.after(card.duration, function()
			card:Dismiss()
		end, card.trove)
	else
		rail.Visible = false
	end

	return card
end

return Notify
