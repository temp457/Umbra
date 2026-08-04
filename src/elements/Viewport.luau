local Theme = require("Theme")
local Create = require("Create")
local Element = require("Element")

local Viewport = {}

function Viewport.build(section, opts)
	local height = tonumber(opts.Height) or 120

	local handle = Element.new(section, opts, {
		interactive = false,
		label = false,
		height = height + Theme.space.md * 2,
		kind = "viewport",
	})

	local frame = Create.new("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.new(1, -(Theme.metrics.rowPad * 2), 0, height),
		Position = UDim2.new(0, Theme.metrics.rowPad, 0, Theme.space.md),
		BackgroundColor3 = Theme.surface[3],
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ZIndex = 2,
		Parent = handle.frame,
	})
	Create.corner(Theme.radius.control).Parent = frame
	Create.stroke(Theme.line.soft).Parent = frame

	local world = Create.new("WorldModel", { Name = "World", Parent = frame })

	local missing = Create.text({
		Name = "Missing",
		Text = "No model",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = frame,
	})

	local camera = Create.new("Camera", {
		Name = "Camera",
		FieldOfView = tonumber(opts.FieldOfView) or 40,
		Parent = frame,
	})
	frame.CurrentCamera = camera

	handle.viewport = frame
	handle.world = world
	handle.camera = camera

	function handle:SetModel(model: Instance?)
		for _, child in world:GetChildren() do
			child:Destroy()
		end

		missing.Visible = true

		if not model then
			return self
		end

		local ok, clone = pcall(function()
			return model:Clone()
		end)

		if not ok or not clone then
			return self
		end

		missing.Visible = false

		clone.Parent = world

		local pivot, extent

		local sized = pcall(function()
			if clone:IsA("Model") then
				pivot = clone:GetPivot()
				extent = clone:GetExtentsSize()
			elseif clone:IsA("BasePart") then
				pivot = clone.CFrame
				extent = clone.Size
			end
		end)

		if not sized or not pivot or not extent then
			return self
		end

		local radius = math.max(extent.X, extent.Y, extent.Z)
		if radius <= 0 then
			radius = 1
		end
		local distance = (radius / math.tan(math.rad(camera.FieldOfView / 2))) * (tonumber(opts.Zoom) or 0.85)
		local direction = Vector3.new(1, 0.55, 1).Unit

		camera.CFrame = CFrame.lookAt(pivot.Position + direction * distance, pivot.Position)

		return self
	end

	handle._apply = function(value)
		handle:SetModel(if typeof(value) == "Instance" then value else nil)
		return value
	end

	if opts.Model then
		handle:SetModel(opts.Model)
	end

	return handle
end

return Viewport
