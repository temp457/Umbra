local UserInputService = game:GetService("UserInputService")

local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Env = require("Env")
local Element = require("Element")

local Slider = {}

local function roundTo(value: number, decimals: number): number
	local factor = 10 ^ math.max(decimals, 0)
	return math.floor(value * factor + 0.5) / factor
end

function Slider.build(section, opts)
	local minimum = tonumber(opts.Min) or 0
	local maximum = tonumber(opts.Max) or 100

	if maximum <= minimum then
		error(
			"Umbra: slider '"
				.. tostring(opts.Flag or opts.Text or "?")
				.. "' has Max ("
				.. tostring(maximum)
				.. ") not greater than Min ("
				.. tostring(minimum)
				.. ")",
			0
		)
	end

	local decimals = tonumber(opts.Rounding) or 0
	local step = tonumber(opts.Step)
	local suffix = opts.Suffix and tostring(opts.Suffix) or ""

	local handle = Element.new(section, opts, { kind = "slider" })

	local metrics = Theme.metrics
	local height = if Env.isTouch then metrics.rowTouch else metrics.row

	local formatWarned = false

	local function format(value: number): string
		if type(opts.Format) == "function" then
			local ok, text = pcall(opts.Format, value)
			if ok and type(text) == "string" then
				return text
			end
			if not formatWarned then
				formatWarned = true
				local Signal = require("Signal")
				Signal.onError(
					"slider '" .. tostring(opts.Flag or opts.Text or "?") .. "' Format failed: " .. tostring(text)
				)
			end
		end
		return string.format("%." .. math.max(decimals, 0) .. "f", value) .. suffix
	end

	local widest = math.max(
		Create.measure(format(minimum), Theme.size.small, Theme.font.mono),
		Create.measure(format(maximum), Theme.size.small, Theme.font.mono)
	)

	local valueWidth = math.clamp(math.ceil(widest) + 2, metrics.sliderValueMin, metrics.sliderValueMax)
	local trackWidth = math.max(metrics.controlMax - Theme.space.sm - valueWidth, metrics.sliderTrackMin)

	local pad = Create.button({
		Name = "TrackPad",
		Size = UDim2.fromOffset(trackWidth, height),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})

	local track = Create.new("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, metrics.sliderTrack),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.line.control,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = pad,
	})
	Create.corner(2).Parent = track

	local filled = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	})
	Create.corner(2).Parent = filled

	local knob = Create.new("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(metrics.sliderKnob, metrics.sliderKnob),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.fill,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	})
	Create.corner(metrics.sliderKnob / 2).Parent = knob

	local readout = Create.text({
		Name = "Value",
		Text = format(minimum),
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		Font = Theme.font.mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromOffset(valueWidth, 16),
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = handle.slot,
	})
	handle:track(readout)

	local dragging = false

	local function quantise(value: number): number
		local clamped = math.clamp(value, minimum, maximum)
		if step and step > 0 then
			clamped = minimum + math.floor((clamped - minimum) / step + 0.5) * step
		end
		return math.clamp(roundTo(clamped, decimals), minimum, maximum)
	end

	handle._apply = function(value)
		local resolved = quantise(tonumber(value) or minimum)
		local alpha = (resolved - minimum) / (maximum - minimum)

		if dragging then
			Motion.set(filled, { Size = UDim2.fromScale(alpha, 1) })
			Motion.set(knob, { Position = UDim2.fromScale(alpha, 0.5) })
		else
			Motion.tween(filled, Motion.curve.slide, { Size = UDim2.fromScale(alpha, 1) }, handle.trove)
			Motion.tween(knob, Motion.curve.slide, { Position = UDim2.fromScale(alpha, 0.5) }, handle.trove)
		end

		readout.Text = format(resolved)

		return resolved
	end

	handle._onEnabled = function(enabled)
		pad.Active = enabled
		Motion.set(filled, { BackgroundColor3 = if enabled then Theme.fill else Theme.line.control })
		Motion.set(knob, { BackgroundColor3 = if enabled then Theme.fill else Theme.line.control })
		Motion.set(track, { BackgroundColor3 = if enabled then Theme.line.control else Theme.line.disabled })
	end

	local function applyFrom(x: number)
		local origin = track.AbsolutePosition.X
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - origin) / width, 0, 1)
		handle:Set(minimum + alpha * (maximum - minimum))
	end

	handle.trove:Connect(pad.InputBegan, function(input)
		if not handle.enabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		Motion.tween(knob, Motion.curve.state, {
			Size = UDim2.fromOffset(metrics.sliderKnobDrag, metrics.sliderKnobDrag),
		}, handle.trove)
		applyFrom(input.Position.X)
	end)

	handle.trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		applyFrom(input.Position.X)
	end)

	handle.trove:Connect(UserInputService.InputEnded, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = false
		Motion.tween(knob, Motion.curve.state, {
			Size = UDim2.fromOffset(metrics.sliderKnob, metrics.sliderKnob),
		}, handle.trove)
	end)

	handle:Set(if opts.Default ~= nil then opts.Default else minimum, true)

	return handle
end

return Slider
