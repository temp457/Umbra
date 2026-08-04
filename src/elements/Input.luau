local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Input = {}

function Input.build(section, opts)
	local handle = Element.new(section, opts, { kind = "input" })
	local metrics = Theme.metrics

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

	local box = Create.input({
		Name = "Box",
		Text = tostring(opts.Default or ""),
		PlaceholderText = tostring(opts.Placeholder or ""),
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = opts.ClearOnFocus == true,
		ZIndex = 3,
		Parent = field,
	})

	local maxLength = tonumber(opts.MaxLength)
	local numeric = opts.Numeric == true

	local function sanitise(text: string): string
		local result = text

		if numeric then
			result = string.gsub(result, "[^%-%d%.]", "")
		end

		if maxLength and #result > maxLength then
			result = string.sub(result, 1, maxLength)
		end

		return result
	end

	handle._apply = function(value)
		local text = sanitise(tostring(value or ""))
		if box.Text ~= text then
			box.Text = text
		end
		return text
	end

	handle._onEnabled = function(enabled)
		box.TextEditable = enabled
		Motion.set(box, { TextColor3 = if enabled then Theme.text[0] else Theme.text[3] })
		Motion.set(border, { Color = if enabled then Theme.line.control else Theme.line.disabled })
	end

	handle.trove:Connect(box.Focused, function()
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.focus }, handle.trove)
	end)

	handle.trove:Connect(box.FocusLost, function(enterPressed)
		Motion.tween(border, Motion.curve.color, { Color = Theme.line.control }, handle.trove)

		local text = sanitise(box.Text)
		box.Text = text

		if text ~= handle.value then
			handle:Set(text)
		end

		if enterPressed and opts.Submit then
			Element.guard(handle, opts.Submit, text)
		end
	end)

	handle.trove:Connect(box:GetPropertyChangedSignal("Text"), function()
		local text = sanitise(box.Text)
		if box.Text ~= text then
			box.Text = text
		end
	end)

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			box:CaptureFocus()
		end
	end)

	handle:Set(tostring(opts.Default or ""), true)

	return handle
end

return Input
