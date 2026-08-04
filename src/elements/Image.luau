local Theme = require("Theme")
local Create = require("Create")
local Icons = require("Icons")
local Element = require("Element")

local Image = {}

function Image.build(section, opts)
	local height = tonumber(opts.Height) or 120

	local handle = Element.new(section, opts, {
		interactive = opts.Callback ~= nil,
		label = false,
		height = height + Theme.space.md * 2,
		kind = "image",
	})

	local asset = Icons.resolve(opts.Image or opts.Asset)

	local holder = Create.surface(3, Theme.radius.control, {
		Name = "Holder",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, height),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0, Theme.space.md),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = handle.frame,
	})
	Create.stroke(Theme.line.soft).Parent = holder

	local picture = Create.image({
		Name = "Picture",
		Image = asset or "",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = Color3.new(1, 1, 1),
		ScaleType = if opts.Fill then Enum.ScaleType.Crop else Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = holder,
	})

	local missing = Create.text({
		Name = "Missing",
		Text = "No image",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Visible = asset == nil,
		ZIndex = 3,
		Parent = holder,
	})

	if opts.Ratio then
		Create.new("UIAspectRatioConstraint", {
			AspectRatio = tonumber(opts.Ratio) or 1,
			DominantAxis = Enum.DominantAxis.Width,
			Parent = picture,
		})
	end

	handle.picture = picture

	handle._apply = function(value)
		local resolved = Icons.resolve(value)
		picture.Image = resolved or ""
		missing.Visible = resolved == nil
		return value
	end

	if handle.hit and opts.Callback then
		handle.trove:Connect(handle.hit.Activated, function()
			if handle.enabled then
				Element.guard(handle, opts.Callback)
			end
		end)
	end

	handle.value = opts.Image or opts.Asset

	return handle
end

return Image
