local Theme = require("Theme")
local Create = require("Create")
local Element = require("Element")

local Divider = {}

function Divider.build(section, opts)
	local handle = Element.new(section, opts, {
		interactive = false,
		label = false,
		height = Theme.space.lg,
		kind = "divider",
	})

	handle.noDivider = true
	handle.divider.Visible = false
	section:restripe()

	Create.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, 1),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.line.soft,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = handle.frame,
	})

	return handle
end

return Divider
