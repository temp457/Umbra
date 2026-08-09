local Theme = require("Theme")
local Create = require("Create")

local Section = {}
Section.__index = Section

local ELEMENTS = {
	Label = "Label",
	Divider = "Divider",
	Button = "Button",
	Toggle = "Toggle",
	Checkbox = "Checkbox",
	Slider = "Slider",
	Input = "Input",
	Dropdown = "Dropdown",
	Keybind = "Keybind",
	Color = "ColorPicker",
	Viewport = "Viewport",
	Image = "Image",
}

function Section.new(page, title: string?, opts: { [string]: any }?)
	local options = opts or {}

	local self = setmetatable({}, Section)
	self.window = page.window
	self.page = page
	self.trove = page.trove:Extend()
	self.rows = {}
	self.title = title
	self.column = options.Column

	local frame = Create.new("CanvasGroup", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		GroupTransparency = 0,
	})
	Create.corner(Theme.radius.section).Parent = frame
	Create.stroke(Theme.line.soft).Parent = frame
	Create.list({ Padding = UDim.new(0, 0) }).Parent = frame

	self.frame = frame
	self.trove:Add(frame)

	if title then
		local header = Create.frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 0,
			Parent = frame,
		})
		Create.pad(Theme.space.md, Theme.space.lg, Theme.space.md, Theme.space.lg).Parent = header

		Create.text({
			Name = "Title",
			Text = title,
			TextSize = Theme.size.tiny,
			TextColor3 = Theme.text[2],
			Weight = "medium",
			Size = UDim2.new(1, 0, 0, 13),
			Parent = header,
		})

		Create.new("Frame", {
			Name = "Rule",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.line.soft,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = frame,
		})
	end

	self.body = Create.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.list({ Padding = UDim.new(0, 0) }).Parent = self.body

	if options.Parent then
		self.detached = true
		frame.Parent = options.Parent
	else
		page:place(self)
	end

	return self
end

function Section:addRow(row)
	table.insert(self.rows, row)
	self:restripe()
	return row
end

function Section:restripe()
	local last = #self.rows

	for index, entry in self.rows do
		entry.frame.LayoutOrder = index
		if entry.divider then
			entry.divider.Visible = index < last and not entry.noDivider
		end
	end
end

function Section:removeRow(row)
	local index = table.find(self.rows, row)
	if index then
		table.remove(self.rows, index)
	end

	self:restripe()
end

function Section:SetVisible(visible: boolean)
	self.frame.Visible = visible ~= false
end

function Section:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	for _, row in table.clone(self.rows) do
		if row.Destroy then
			row:Destroy()
		end
	end
	self.rows = {}

	if self.page then
		self.page:unplace(self)
	end

	self.trove:Destroy()
end

for method, module in ELEMENTS do
	Section[method] = function(self, opts)
		return require(module).build(self, opts or {})
	end
end

return Section
