local Env = require("Env")

local Theme = {}

Theme.isTouch = Env.isTouch

Theme.surface = {
	[0] = Color3.fromRGB(8, 8, 8),
	[1] = Color3.fromRGB(18, 18, 18),
	[2] = Color3.fromRGB(30, 30, 30),
	[3] = Color3.fromRGB(42, 42, 42),
	[4] = Color3.fromRGB(58, 58, 58),
}

Theme.line = {
	soft = Color3.fromRGB(63, 63, 63),
	control = Color3.fromRGB(110, 110, 110),
	focus = Color3.fromRGB(160, 160, 160),
	disabled = Color3.fromRGB(63, 63, 63),
}

Theme.text = {
	[0] = Color3.fromRGB(255, 255, 255),
	[1] = Color3.fromRGB(180, 180, 180),
	[2] = Color3.fromRGB(148, 148, 148),
	[3] = Color3.fromRGB(110, 110, 110),
}

Theme.fill = Color3.fromRGB(255, 255, 255)
Theme.onFill = Color3.fromRGB(8, 8, 8)
Theme.knobOff = Color3.fromRGB(148, 148, 148)
Theme.scrim = Color3.fromRGB(0, 0, 0)
Theme.scrimTransparency = 0.45

Theme.size = {
	hero = 18,
	title = 14,
	body = 13,
	small = 12,
	tiny = 11,
}

Theme.radius = {
	window = 10,
	section = 8,
	control = 6,
	small = 4,
	hair = 2,
}

Theme.space = {
	xs = 4,
	sm = 6,
	md = 8,
	lg = 12,
	xl = 16,
	xxl = 20,
	xxxl = 24,
}

Theme.metrics = {
	windowDefault = Vector2.new(620, 420),
	windowMin = Vector2.new(480, 340),

	titleBar = 40,
	rail = 52,
	railIcon = 32,
	railIconTouch = 44,
	railGlyph = 18,
	railIndicator = Vector2.new(2, 32),
	cornerClear = 12,

	row = 32,
	rowTouch = 44,
	rowPad = 12,
	rowGap = 8,
	labelMin = 88,
	controlMax = 112,

	twoColumnAt = 600,
	columnGap = 12,
	columnMin = 232,
	scrollBar = 4,

	fieldHeight = 24,
	fieldHeightTouch = 32,
	chipHeight = 18,
	chipHeightTouch = 24,
	buttonHeight = 32,
	chipWidth = 76,
	hexWidth = 48,

	toggleTrack = Vector2.new(32, 16),
	toggleKnob = 12,
	toggleInset = 2,
	checkbox = 16,
	swatch = 16,
	swatchTouch = 26,
	sliderTrack = 3,
	sliderKnob = 10,
	sliderKnobDrag = 12,
	sliderValueMin = 20,
	sliderValueMax = 56,
	sliderTrackMin = 40,
	chevron = 12,

	touchTarget = 44,

	dropdownRow = 28,
	dropdownMaxRows = 8,
	pickerWidth = 200,
	pickerSquare = 120,
	pickerStrip = 10,
	tooltipMax = 200,

	notification = 230,
	notificationTop = 48,
	notificationGap = 8,
	notificationCap = 5,
	notificationLines = 4,

	staggerCap = 8,
}

Theme.zone = {
	body = 1,
	watermark = 5,
	keybinds = 6,
	overlay = 20,
	popup = 21,
	notification = 30,
	tooltip = 40,
	dialog = 50,
}

Theme.font = {
	regular = Enum.Font.GothamMedium,
	medium = Enum.Font.GothamBold,
	mono = Enum.Font.RobotoMono,
}

function Theme.field(): number
	return if Theme.isTouch then Theme.metrics.fieldHeightTouch else Theme.metrics.fieldHeight
end

function Theme.chip(): number
	return if Theme.isTouch then Theme.metrics.chipHeightTouch else Theme.metrics.chipHeight
end

function Theme.lifted(color: Color3): Color3
	if color == Theme.text[2] then
		return Theme.text[1]
	end
	if color == Theme.text[1] then
		return Theme.text[0]
	end
	return color
end

return Theme
