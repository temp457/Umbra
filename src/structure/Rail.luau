local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Icons = require("Icons")
local Env = require("Env")

local Rail = {}
Rail.__index = Rail

function Rail.new(window)
	local metrics = Theme.metrics
	local cell = if Env.isTouch then metrics.railIconTouch else metrics.railIcon

	local self = setmetatable({}, Rail)
	self.window = window
	self.trove = window.trove:Extend()
	self.items = {}
	self.cell = cell
	self.gap = Theme.space.sm
	self.active = nil

	local frame = Create.new("Frame", {
		Name = "Rail",
		Size = UDim2.new(0, metrics.rail, 1, -metrics.titleBar),
		Position = UDim2.fromOffset(0, metrics.titleBar),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	})
	Create.corner(Theme.radius.window).Parent = frame

	Create.new("Frame", {
		Name = "TopFill",
		Size = UDim2.new(1, 0, 0, Theme.radius.window),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})

	Create.new("Frame", {
		Name = "EdgeFill",
		Size = UDim2.new(0, Theme.radius.window, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.surface[0],
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = frame,
	})

	local list = Create.scroll({
		Name = "Items",
		Size = UDim2.new(1, 0, 1, -(metrics.cornerClear * 2)),
		Position = UDim2.fromOffset(0, metrics.cornerClear),
		ScrollBarThickness = 2,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ZIndex = 3,
		Parent = frame,
	})
	Create.list({
		Padding = UDim.new(0, self.gap),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}).Parent = list

	local indicator = Create.new("Frame", {
		Name = "Indicator",
		Size = UDim2.fromOffset(metrics.railIndicator.X, cell),
		Position = UDim2.fromOffset(0, metrics.cornerClear),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = frame,
	})
	Create.corner(Theme.radius.small).Parent = indicator

	self.frame = frame
	self.list = list
	self.indicator = indicator
	self.trove:Add(frame)

	self.trove:Connect(list:GetPropertyChangedSignal("CanvasPosition"), function()
		if self.active then
			self:place(self.active, true)
		end
	end)

	return self
end

function Rail:place(item, instant: boolean?)
	local offset = Theme.metrics.cornerClear
		+ (item.ordinal - 1) * (self.cell + self.gap)
		- self.list.CanvasPosition.Y

	local target = UDim2.fromOffset(0, offset)

	if instant or not self.indicator.Visible then
		Motion.cancel(self.indicator)
		self.indicator.Position = target
		self.indicator.Visible = true
	else
		Motion.tween(self.indicator, Motion.curve.slide, { Position = target }, self.trove)
	end
end

function Rail:add(name: string, icon: any, onSelect)
	local metrics = Theme.metrics
	local ordinal = #self.items + 1

	local button = Create.button({
		Name = "Tab",
		Size = UDim2.fromOffset(self.cell, self.cell),
		BackgroundTransparency = 1,
		LayoutOrder = ordinal,
		ZIndex = 3,
		Parent = self.list,
	})

	local asset = Icons.resolve(icon)
	local glyph

	if asset then
		glyph = Create.image({
			Name = "Glyph",
			Image = asset,
			Size = UDim2.fromOffset(metrics.railGlyph, metrics.railGlyph),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageColor3 = Theme.text[2],
			ZIndex = 3,
			Parent = button,
		})
	else
		glyph = Create.text({
			Name = "Mark",
			Text = Icons.letter(name),
			TextSize = Theme.size.hero,
			TextColor3 = Theme.text[2],
			Weight = "medium",
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = button,
		})
	end

	local item = {
		name = name,
		button = button,
		glyph = glyph,
		isImage = asset ~= nil,
		ordinal = ordinal,
	}

	table.insert(self.items, item)

	self.trove:Connect(button.MouseEnter, function()
		if self.active ~= item then
			self:paint(item, Theme.text[1])
		end
		self.window:showTooltip(name, button)
	end)

	self.trove:Connect(button.MouseLeave, function()
		if self.active ~= item then
			self:paint(item, Theme.text[2])
		end
		self.window:hideTooltip()
	end)

	self.trove:Connect(button.Activated, function()
		onSelect()
	end)

	return item
end

function Rail:paint(item, color: Color3)
	if item.isImage then
		Motion.tween(item.glyph, Motion.curve.hover, { ImageColor3 = color }, self.trove)
	else
		Motion.tween(item.glyph, Motion.curve.hover, { TextColor3 = color }, self.trove)
	end
end

function Rail:select(item)
	if self.active == item then
		return
	end

	if self.active then
		self:paint(self.active, Theme.text[2])
	end

	self.active = item
	self:paint(item, Theme.text[0])
	self:place(item)
end

function Rail:Destroy()
	self.trove:Clean()
	table.clear(self.items)
end

return Rail
