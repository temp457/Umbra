local Umbra = loadstring(game:HttpGet("https://raw.githubusercontent.com/temp457/Umbra/main/dist/umbra.luau"))()

local Window = Umbra:Window({
	Name = "Umbra Hub",
	Version = "1.0.0",
	Toggle = Enum.KeyCode.RightControl,
	Home = {
		Changelog = {
			{ Version = "1.0.0", Notes = { "First release", "Every element" } },
			{ Version = "0.9.0", Notes = { "Config manager" } },
		},
		Links = {
			{ Text = "Discord", Url = "https://discord.gg/example" },
			{ Text = "Get key", Url = "https://example.com/key" },
		},
		Credits = { "Built with Umbra", "UI by Umbra" },
	},
})

local Combat = Window:Tab("Combat")
local Visuals = Window:Tab("Visuals")
local Misc = Window:Tab("Misc")
local Settings = Window:Tab("Settings")

local Targeting = Combat:Section("Targeting")

Targeting:Toggle({
	Flag = "silent_aim",
	Text = "Silent aim",
	Default = false,
	Callback = function(on)
		print("silent aim:", on)
	end,
})
	:Bind({ Flag = "silent_key", Text = "Silent aim", Default = "MB2", Mode = "Hold" })
	:Tip("Redirects shots")

Targeting:Toggle({ Flag = "auto_fire", Text = "Auto fire", Default = false })

Targeting:Slider({
	Flag = "fov",
	Text = "FOV",
	Min = 0,
	Max = 360,
	Default = 124,
	Suffix = "deg",
})

Targeting:Slider({
	Flag = "smoothing",
	Text = "Smoothing",
	Min = 0,
	Max = 1,
	Default = 0.35,
	Rounding = 2,
})

Targeting:Dropdown({
	Flag = "hitbox",
	Text = "Hitbox",
	Options = { "Head", "Torso", "Nearest" },
	Default = "Head",
})

local Filters = Combat:Section("Filters")

Filters:Checkbox({ Flag = "wall_check", Text = "Wall check", Default = true })
Filters:Checkbox({ Flag = "team_check", Text = "Team check", Default = true })

Filters:Dropdown({
	Flag = "targets",
	Text = "Targets",
	Source = "Players",
	Multi = true,
	ExcludeLocal = true,
})

Filters:Keybind({
	Flag = "panic",
	Text = "Panic",
	Default = "F4",
	Mode = "Press",
	Callback = function()
		Umbra:Notify({ Title = "Panic", Text = "Everything off", Duration = 3 })
	end,
})

local Esp = Visuals:Section("ESP")

Esp:Toggle({ Flag = "box_esp", Text = "Boxes", Default = true })
	:Color({ Flag = "box_color", Text = "Boxes", Default = Color3.fromRGB(255, 59, 48) })

Esp:Toggle({ Flag = "name_esp", Text = "Names", Default = false })
	:Color({ Flag = "name_color", Text = "Names", Default = Color3.fromRGB(48, 209, 88) })

Esp:Slider({ Flag = "thickness", Text = "Thickness", Min = 0.5, Max = 5, Default = 1.4, Rounding = 1 })

local Tracers = Esp:Toggle({ Flag = "tracer_esp", Text = "Tracers", Default = false })
	:Menu({ Title = "Tracer options" })

Tracers:Dropdown({
	Flag = "tracer_origin",
	Text = "Origin",
	Options = { "Bottom", "Centre", "Mouse" },
	Default = "Bottom",
})

Tracers:Slider({ Flag = "tracer_width", Text = "Width", Min = 0.5, Max = 5, Default = 1, Rounding = 1 })

Tracers:Toggle({ Flag = "tracer_fade", Text = "Fade by distance", Default = true })
	:Menu({ Title = "Fade" })
	:Slider({ Flag = "tracer_fade_max", Text = "Max studs", Min = 50, Max = 2000, Default = 500 })

Tracers:Divider({})

Tracers:Button({
	Text = "Reset tracers",
	Confirm = true,
	Callback = function()
		Umbra:Notify({ Title = "Tracers reset", Duration = 3 })
	end,
})

local Look = Visuals:Section("Look")

Look:Color({ Flag = "accent", Text = "Highlight", Default = Color3.fromRGB(255, 255, 255) })
Look:Divider({})
Look:Label({ Text = "Colours apply to your own drawings only.", Wrap = true })

local Tools = Misc:Section("Tools")

Tools:Input({
	Flag = "webhook",
	Text = "Webhook",
	Placeholder = "https://",
	MaxLength = 120,
})

Tools:Input({ Flag = "count", Text = "Count", Numeric = true, Default = "10" })

Tools:Button({
	Text = "Copy job id",
	Callback = function()
		Umbra:Notify({ Title = "Copied", Text = tostring(game.JobId), Duration = 4 })
	end,
})

Tools:Button({
	Text = "Rejoin",
	Confirm = true,
	Callback = function()
		Umbra:Notify({ Title = "Rejoining", Duration = 3 })
	end,
})

local Media = Misc:Section("Media")
local Players = game:GetService("Players")

local gotThumb, thumb = pcall(function()
	return Players:GetUserThumbnailAsync(
		Players.LocalPlayer.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size150x150
	)
end)

Media:Image({ Image = if gotThumb then thumb else nil, Height = 90 })
Media:Viewport({ Model = Players.LocalPlayer.Character, Height = 110 })

local Interface = Settings:Section("Interface")

Interface:Toggle({
	Flag = "watermark",
	Text = "Watermark",
	Default = true,
	Callback = function(on)
		Umbra:Watermark({ Text = "Umbra Hub", Fps = true, Ping = true, Clock = true })
		if Window.watermark then
			Window.watermark:SetVisible(on)
		end
	end,
})

Interface:Toggle({
	Flag = "keybind_list",
	Text = "Keybind list",
	Default = true,
	Callback = function(on)
		Umbra:Keybinds(on)
	end,
})

Interface:Button({
	Text = "Unload",
	Confirm = true,
	Callback = function()
		Umbra:Unload()
	end,
})

Window:Config({ Folder = "ExampleHub", Autoload = true })
Settings:ConfigSection()

Umbra:Watermark({ Text = "Umbra Hub", Fps = true, Ping = true })
Umbra:Keybinds(true)

Umbra:OnUnload(function()
	print("hub unloaded")
end)

Window:Element("fov"):OnChanged(function(value)
	print("fov is now", value)
end)

print("flags:", Window.Flags.silent_aim, Window.Flags.fov)
