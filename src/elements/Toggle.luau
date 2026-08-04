local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Toggle = {}

function Toggle.build(section, opts)
	local handle = Element.new(section, opts, { kind = "toggle" })

	local metrics = Theme.metrics
	local track = metrics.toggleTrack
	local knobSize = metrics.toggleKnob
	local inset = metrics.toggleInset
	local travel = track.X - (inset * 2) - knobSize

	local body = Create.new("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(track.X, track.Y),
		BackgroundColor3 = Theme.surface[3],
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	Create.corner(track.Y / 2).Parent = body

	local edge = Create.stroke(Theme.line.control)
	edge.Parent = body

	local knob = Create.new("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(knobSize, knobSize),
		Position = UDim2.new(0, inset, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.knobOff,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = body,
	})
	Create.corner(knobSize / 2).Parent = knob

	handle._apply = function(value)
		local on = value == true

		Motion.tween(body, Motion.curve.color, {
			BackgroundColor3 = if on then Theme.fill else Theme.surface[3],
		}, handle.trove)

		Motion.tween(edge, Motion.curve.color, {
			Color = if on then Theme.fill else Theme.line.control,
		}, handle.trove)

		Motion.tween(knob, Motion.curve.state, {
			Position = UDim2.new(0, if on then inset + travel else inset, 0.5, 0),
		}, handle.trove)

		Motion.tween(knob, Motion.curve.snap, {
			BackgroundColor3 = if on then Theme.onFill else Theme.knobOff,
		}, handle.trove)

		return on
	end

	handle._onEnabled = function(enabled)
		if enabled then
			handle._apply(handle.value)
			return
		end

		Motion.set(body, { BackgroundColor3 = Theme.surface[3] })
		Motion.set(edge, { Color = Theme.line.disabled })
		Motion.set(knob, { BackgroundColor3 = Theme.text[3] })
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if handle.enabled then
			handle:Set(not handle.value)
		end
	end)

	handle:Set(opts.Default == true, true)

	return handle
end

return Toggle
