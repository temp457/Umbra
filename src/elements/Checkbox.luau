local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Checkbox = {}

function Checkbox.build(section, opts)
	local handle = Element.new(section, opts, { kind = "checkbox" })
	local size = Theme.metrics.checkbox

	local box = Create.new("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.fill,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	Create.corner(Theme.radius.small).Parent = box

	local border = Create.stroke(Theme.line.control)
	border.Parent = box

	local mark = Create.new("Frame", {
		Name = "Mark",
		Size = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.onFill,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = box,
	})
	Create.corner(2).Parent = mark

	handle._apply = function(value)
		local on = value == true

		Motion.tween(box, Motion.curve.snap, {
			BackgroundTransparency = if on then 0 else 1,
		}, handle.trove)

		Motion.tween(border, Motion.curve.color, {
			Color = if on then Theme.fill else Theme.line.control,
		}, handle.trove)

		Motion.tween(mark, Motion.curve.state, {
			Size = if on then UDim2.fromOffset(6, 6) else UDim2.fromScale(0, 0),
		}, handle.trove)

		return on
	end

	handle._onEnabled = function(enabled)
		if enabled then
			handle._apply(handle.value)
			return
		end

		Motion.set(border, { Color = Theme.line.disabled })
		Motion.set(box, { BackgroundColor3 = Theme.line.disabled })
		Motion.set(mark, { BackgroundColor3 = Theme.surface[2] })
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			handle:Set(not handle.value)
		end
	end)

	handle:Set(opts.Default == true, true)

	return handle
end

return Checkbox
