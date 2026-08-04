local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Section = require("Section")

local Page = {}
Page.__index = Page

function Page.new(window, name: string)
	local self = setmetatable({}, Page)
	self.window = window
	self.name = name
	self.trove = window.trove:Extend()
	self.sections = {}
	self.single = false
	self.revealed = false

	local scroll = Create.scroll({
		Name = "Page",
		Size = UDim2.new(1, -Theme.space.md, 1, -Theme.space.md),
		Visible = false,
	})
	Create.pad(Theme.space.xl).Parent = scroll

	local holder = Create.frame({
		Name = "Columns",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, Theme.metrics.columnGap),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}).Parent = holder

	local function column(order: number)
		local frame = Create.frame({
			Name = "Column",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = holder,
		})
		Create.list({ Padding = UDim.new(0, Theme.metrics.columnGap) }).Parent = frame
		return frame
	end

	self.scroll = scroll
	self.holder = holder
	self.left = column(1)
	self.right = column(2)

	self.trove:Add(scroll)

	self.trove:Connect(scroll:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:measure()
	end)

	self.trove:Add(task.defer(function()
		if scroll.Parent then
			self:measure()
		end
	end))

	return self
end

function Page:measure()
	local usable = self.scroll.AbsoluteSize.X
		- (Theme.space.xl * 2)
		- Theme.metrics.scrollBar

	if usable <= 0 then
		return
	end

	self.holder.Size = UDim2.fromOffset(usable, 0)

	if self.single then
		self.left.Size = UDim2.fromOffset(usable, 0)
		self.right.Size = UDim2.fromOffset(usable, 0)
	else
		local each = math.floor((usable - Theme.metrics.columnGap) / 2)
		self.left.Size = UDim2.fromOffset(each, 0)
		self.right.Size = UDim2.fromOffset(each, 0)
	end
end

function Page:Section(title: string?, opts: { [string]: any }?)
	return Section.new(self, title, opts)
end

function Page:ConfigSection(opts: { [string]: any }?)
	return require("Config").section(self, opts)
end

function Page:place(section)
	table.insert(self.sections, section)
	self:assign(section, #self.sections)
end

function Page:unplace(section)
	local index = table.find(self.sections, section)
	if not index then
		return
	end

	table.remove(self.sections, index)

	for ordinal = index, #self.sections do
		self:assign(self.sections[ordinal], ordinal)
	end
end

function Page:assign(section, ordinal: number)
	local target

	if self.single then
		target = self.left
	elseif section.column == "left" then
		target = self.left
	elseif section.column == "right" then
		target = self.right
	elseif ordinal % 2 == 1 then
		target = self.left
	else
		target = self.right
	end

	section.frame.LayoutOrder = ordinal
	section.frame.Parent = target
end

function Page:reflow(width: number)
	local single = width < Theme.metrics.twoColumnAt
	if single == self.single then
		return
	end

	self.single = single
	self.right.Visible = not single

	self:measure()

	for ordinal, section in self.sections do
		self:assign(section, ordinal)
	end
end

function Page:rows(): { Instance }
	local collected = {}
	for _, section in self.sections do
		if section.frame.Visible then
			table.insert(collected, section.frame)
		end
	end
	return collected
end

function Page:Show()
	self.scroll.Visible = true

	local targets = self:rows()
	if #targets == 0 then
		return
	end

	for _, frame in targets do
		Motion.cancel(frame)
		frame.GroupTransparency = 1
	end

	Motion.stagger(targets, Motion.curve.reveal, function()
		return { GroupTransparency = 0 }
	end, Motion.staggerStep, self.trove)

	self.revealed = true
end

function Page:Hide()
	self.scroll.Visible = false
end

function Page:Destroy()
	for _, section in table.clone(self.sections) do
		section:Destroy()
	end
	self.sections = {}
	self.trove:Destroy()
end

return Page
