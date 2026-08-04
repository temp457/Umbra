local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local Theme = require("Theme")
local Create = require("Create")

local Watermark = {}

local SAMPLE = 0.25

local function ping(): number
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		return math.floor(value + 0.5)
	end
	return 0
end

local function clock(): string
	local total = math.floor(os.time() % 86400)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local seconds = total % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function Watermark.attach(window, opts)
	local settings = opts or {}

	if window.watermark then
		window.watermark:Update(settings)
		return window.watermark
	end

	local trove = window.trove:Extend()

	local bar = Create.new("Frame", {
		Name = "Watermark",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(Theme.space.xl, Theme.space.xl),
		BackgroundColor3 = Theme.surface[2],
		BorderSizePixel = 0,
		ZIndex = Theme.zone.watermark,
		Parent = window.gui,
	})
	Create.corner(Theme.radius.control).Parent = bar
	Create.stroke(Theme.line.control).Parent = bar
	Create.pad(0, Theme.space.lg, 0, Theme.space.lg).Parent = bar
	Create.list({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.space.md),
	}).Parent = bar

	trove:Add(bar)

	local label = Create.text({
		Name = "Label",
		Text = tostring(settings.Text or window.name),
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[0],
		Weight = "medium",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = Theme.zone.overlay,
		Parent = bar,
	})

	local readout = Create.text({
		Name = "Stats",
		Text = "",
		TextSize = Theme.size.tiny,
		TextColor3 = Theme.text[2],
		Font = Theme.font.mono,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = Theme.zone.overlay,
		Parent = bar,
	})

	local dragging = false
	local origin, startPos

	trove:Connect(bar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			origin = input.Position
			startPos = bar.Position
		end
	end)

	trove:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - origin
		local camera = workspace.CurrentCamera
		local bounds = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local size = bar.AbsoluteSize
		local margin = 24

		bar.Position = UDim2.fromOffset(
			math.clamp(startPos.X.Offset + delta.X, margin - size.X, bounds.X - margin),
			math.clamp(startPos.Y.Offset + delta.Y, 0, bounds.Y - margin)
		)
	end)

	trove:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local frames = 0
	local elapsed = 0
	local fps = 0
	local config = settings

	trove:Connect(RunService.Heartbeat, function(delta)
		frames += 1
		elapsed += delta

		if elapsed < SAMPLE then
			return
		end

		fps = math.floor(frames / elapsed + 0.5)
		frames = 0
		elapsed = 0

		local parts = {}

		if config.Fps ~= false then
			table.insert(parts, tostring(fps) .. " fps")
		end
		if config.Ping then
			table.insert(parts, tostring(ping()) .. " ms")
		end
		if config.Clock then
			table.insert(parts, clock())
		end

		readout.Text = table.concat(parts, "  ")
		readout.Visible = #parts > 0
	end)

	window.watermark = {
		frame = bar,
		Update = function(_, changes)
			if type(changes) == "table" then
				for key, value in changes do
					config[key] = value
				end
			end
			if config.Text then
				label.Text = tostring(config.Text)
			end
			bar.Visible = true
		end,
		SetVisible = function(_, visible)
			bar.Visible = visible ~= false
		end,
		Destroy = function()
			trove:Clean()
			window.watermark = nil
		end,
	}

	return window.watermark
end

return Watermark
