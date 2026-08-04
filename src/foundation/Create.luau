local Theme = require("Theme")

local Create = {}

local function copy(source: { [string]: any }?): { [string]: any }
	local result = {}
	if source then
		for key, value in source do
			result[key] = value
		end
	end
	return result
end

local function take(props: { [string]: any }, key: string, fallback: any): any
	local value = props[key]
	if value == nil then
		return fallback
	end
	props[key] = nil
	return value
end

local function fill(props: { [string]: any }, defaults: { [string]: any })
	for key, value in defaults do
		if props[key] == nil then
			props[key] = value
		end
	end
end

function Create.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

function Create.corner(radius: number): UICorner
	return Create.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Create.new("UIStroke", {
		Color = color or Theme.line.soft,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.pad(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local up = top
	local side = right or top
	local down = bottom or top
	local other = left or side

	return Create.new("UIPadding", {
		PaddingTop = UDim.new(0, up),
		PaddingRight = UDim.new(0, side),
		PaddingBottom = UDim.new(0, down),
		PaddingLeft = UDim.new(0, other),
	})
end

function Create.list(props: { [string]: any }?): UIListLayout
	local options = copy(props)
	fill(options, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 0),
	})
	return Create.new("UIListLayout", options)
end

function Create.frame(props: { [string]: any }?, children: { Instance }?): Frame
	local options = copy(props)
	fill(options, {
		BackgroundColor3 = Theme.surface[1],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	return Create.new("Frame", options, children)
end

function Create.text(props: { [string]: any }?, children: { Instance }?): TextLabel
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.font[weight] or Theme.font.regular,
		TextSize = Theme.size.body,
		TextColor3 = Theme.text[1],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextLabel", options, children)
end

function Create.button(props: { [string]: any }?, children: { Instance }?): TextButton
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.surface[3],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.font[weight] or Theme.font.regular,
		Text = "",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextButton", options, children)
end

function Create.input(props: { [string]: any }?, children: { Instance }?): TextBox
	local options = copy(props)
	local weight = take(options, "Weight", "regular")

	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Theme.font[weight] or Theme.font.regular,
		Text = "",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[0],
		PlaceholderColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		RichText = false,
	})

	return Create.new("TextBox", options, children)
end

function Create.image(props: { [string]: any }?, children: { Instance }?): ImageLabel
	local options = copy(props)
	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = Theme.text[2],
	})
	return Create.new("ImageLabel", options, children)
end

function Create.scroll(props: { [string]: any }?, children: { Instance }?): ScrollingFrame
	local options = copy(props)
	fill(options, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = Theme.metrics.scrollBar,
		ScrollBarImageColor3 = Theme.line.control,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ClipsDescendants = true,
	})
	return Create.new("ScrollingFrame", options, children)
end

function Create.surface(level: number, radius: number?, props: { [string]: any }?, children: { Instance }?): Frame
	local options = copy(props)
	fill(options, {
		BackgroundColor3 = Theme.surface[level],
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	})

	local frame = Create.new("Frame", options, children)
	if radius then
		Create.corner(radius).Parent = frame
	end
	return frame
end

function Create.caret(props: { [string]: any }?): Frame
	local options = copy(props)
	local color = take(options, "Color", Theme.text[2])
	local flip = take(options, "Flip", false)

	fill(options, {
		Name = "Caret",
		Size = UDim2.fromOffset(7, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})

	local holder = Create.new("Frame", options)

	for index = 1, 4 do
		local width = 9 - index * 2
		local row = if flip then 4 - index else index - 1

		Create.new("Frame", {
			Name = "Bar",
			Size = UDim2.fromOffset(width, 1),
			Position = UDim2.new(0.5, 0, 0, row),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = options.ZIndex or 1,
			Parent = holder,
		})
	end

	return holder
end

function Create.paintCaret(caret: Frame, color: Color3)
	for _, bar in caret:GetChildren() do
		if bar:IsA("Frame") then
			bar.BackgroundColor3 = color
		end
	end
end

function Create.measure(text: string, size: number, font: Enum.Font): number
	local ok, bounds = pcall(function()
		return game:GetService("TextService"):GetTextSize(text, size, font, Vector2.new(10000, 100))
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end

	local count = #text
	local counted, length = pcall(utf8.len, text)
	if counted and type(length) == "number" then
		count = length
	end

	return count * (size * 0.55)
end

return Create
