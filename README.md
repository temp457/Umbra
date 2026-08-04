# Umbra

A GUI library for Roblox executor script hubs. One `loadstring` gives you a
window, tabs, sections, twelve element types, notifications, dialogs, saved
configs, a keybind overlay, a watermark and search.

Pure monochrome, dark only. There is no theme system and no accent colour —
that is deliberate. Every hub built on Umbra looks like Umbra.

---

## Quick start

```lua
local Umbra = loadstring(game:HttpGet("https://raw.githubusercontent.com/temp457/Umbra/main/dist/umbra.luau"))()

local Window = Umbra:Window({
    Name = "My Hub",
    Version = "1.0.0",
    Toggle = Enum.KeyCode.RightControl,
})

local Combat = Window:Tab("Combat")
local Aim = Combat:Section("Aimbot")

Aim:Toggle({ Flag = "aimbot", Text = "Enabled", Default = false })
Aim:Slider({ Flag = "fov", Text = "FOV", Min = 0, Max = 360, Default = 120 })
```

That is a complete, working menu. `Example.luau` in this repo exercises every
element and is the best reference.

---

## How the pieces fit

```
Window  ->  Tab  ->  Section  ->  Element
```

- **Window** is the whole menu. One per hub.
- **Tab** is an entry in the left rail.
- **Section** is a titled box. Sections flow into two columns automatically and
  collapse to one on a narrow window or a phone.
- **Element** is a row: a toggle, a slider, a dropdown, and so on.

---

## Window

```lua
local Window = Umbra:Window({
    Name = "My Hub",
    Version = "1.0.0",
    Toggle = Enum.KeyCode.RightControl,
    Size = Vector2.new(620, 420),
    Home = {
        Description = "What this hub does.",
        Changelog = {
            { Version = "1.1.0", Notes = { "Added ESP", "Fixed aimbot" } },
        },
        Links = {
            { Text = "Discord", Url = "https://discord.gg/..." },
        },
        Credits = { "Built by you" },
    },
})
```

`Home` builds the landing page for you — hub name, description, changelog,
link buttons, credits and the toggle-key hint. Pass `Home = false` to skip it.

Link buttons copy the URL to the clipboard and show a notification, because
Roblox cannot open a browser from a script.

---

## Elements

Every element takes one table. `Flag` is optional — but an element **with** a
flag gets saved in configs and found by search, and one without does not.

Two flags with the same name **throw an error on purpose**. Silently
overwriting would make the first element permanently unsaveable.

```lua
Section:Label({ Text = "Some text", Wrap = true })
Section:Divider({})

Section:Button({
    Text = "Do the thing",
    Confirm = true,
    Callback = function() end,
})

Section:Toggle({ Flag = "f", Text = "Toggle", Default = false, Callback = function(on) end })
Section:Checkbox({ Flag = "f", Text = "Checkbox", Default = true })

Section:Slider({
    Flag = "f",
    Text = "Slider",
    Min = 0, Max = 100, Default = 50,
    Step = 5,
    Rounding = 1,
    Suffix = " m",
    Format = function(value) return value .. "%" end,
})

Section:Input({
    Flag = "f",
    Text = "Input",
    Placeholder = "type here",
    Default = "",
    Numeric = false,
    MaxLength = 64,
    Submit = function(text) end,
})

Section:Dropdown({
    Flag = "f",
    Text = "Dropdown",
    Options = { "One", "Two" },
    Default = "One",
    Multi = false,
    Placeholder = "None",
})

Section:Dropdown({ Flag = "f", Text = "Players", Source = "Players", Multi = true, ExcludeLocal = true })
Section:Dropdown({ Flag = "f", Text = "Teams", Source = "Teams" })

Section:Keybind({ Flag = "f", Text = "Bind", Default = "MB2", Mode = "Toggle", Callback = function(state) end })
Section:Color({ Flag = "f", Text = "Colour", Default = Color3.new(1, 0, 0) })

Section:Viewport({ Model = someModel, Height = 120 })
Section:Image({ Image = "rbxassetid://123", Height = 120, Fill = false })
```

Keybind `Mode` is `"Toggle"` (flips a state), `"Hold"` (true while held) or
`"Press"` (fires once).

### Chaining

A keybind, a colour picker and a tooltip can attach to the row they belong to:

```lua
Section:Toggle({ Flag = "esp", Text = "Box ESP" })
    :Bind({ Flag = "esp_key", Default = "F" })
    :Color({ Flag = "esp_colour", Default = Color3.new(1, 0, 0) })
    :Tip("Draws boxes")
```

Chaining only attaches things to that row. To add the next element, call the
section again.

---

## Reading and changing values

```lua
Window.Flags.aimbot        -- current value, live
Window.Flags.fov = 90      -- set it

local handle = Window:Element("fov")
handle:Get()
handle:Set(90)
handle:OnChanged(function(value) end)
handle:SetText("New label")
handle:SetVisible(false)
handle:SetEnabled(false)
handle:Destroy()
```

`OnChanged` returns a function that disconnects it. Call that function to stop
listening.

---

## Notifications, dialogs and the rest

```lua
local note = Umbra:Notify({
    Title = "Saved",
    Text = "default.json",
    Duration = 4,
})

note:Update({ Title = "Uploading", Progress = 0.5 })
note:Dismiss()

Umbra:Dialog({
    Title = "Unload?",
    Text = "Everything stops.",
    Confirm = "Unload",
    Cancel = "Keep it",
    Callback = function() Umbra:Unload() end,
})

Umbra:Watermark({ Text = "My Hub", Fps = true, Ping = true, Clock = true })
Umbra:Keybinds(true)

Umbra:OnUnload(function() end)
Umbra:Unload()
```

`Duration = 0` makes a notification stay until dismissed — useful with
`:Update({ Progress = n })` for long jobs.

Search is the `?` button in the title bar. It finds any element by name and
jumps to it.

---

## Configs

```lua
Window:Config({ Folder = "MyHub", Autoload = true })
Window:Tab("Settings"):ConfigSection()
```

That is the whole setup. `ConfigSection()` builds the save / load / delete /
autoload UI for you.

Configs are stored per game by default. Pass `Global = true` to share one set
across every game.

If the executor has no file access, the config system disables itself and says
so in the UI instead of erroring.

---

## Building from source

The library is written as 33 small modules in `src/` and bundled into one file.

```bash
python build/build.py
```

That writes `dist/umbra.luau`. The build **parse-checks the result with
`luau-compile` and refuses to write the file if it fails**, so a broken bundle
cannot ship. You need `luau-compile` from [rokit](https://github.com/rojo-rbx/rokit);
without it the build still works but skips the check.

Each module is wrapped in its own closure, which is why the library does not
run into Luau's 200-local-variables-per-scope limit.

---

## Design notes

**Icons are letters by default.** The rail draws each tab's first letter unless
you pass `Icon = "rbxassetid://123"` to `Window:Tab`. Shipping a table of asset
IDs that could not be verified would mean blank boxes in production, so the
letter mark is the default.

**Motion is expressive and centralised.** Every animation curve lives in
`src/foundation/Motion.luau`. Changing the feel of the whole library is a few
constants, not a search through 33 files.

**Colour lives in one file.** `src/foundation/Theme.luau` holds every `Color3`.
Nothing else in the library is allowed to contain one.

**Nothing runs per frame while idle.** The only exception is the watermark's
frame counter, and only while the watermark is on.

---

## Honest limitations

- **This is young code.** Every file is parse-checked with `luau-compile` and
  type-checked with `luau-analyze` on each build, and it has been through
  several rounds of review, but there is no automated runtime test suite —
  Roblox can't be driven from outside the engine. Expect rough edges and
  please report them. `KNOWN-ISSUES.md` lists what is deliberately unfixed.
- **Fonts are Gotham, not BuilderSans.** BuilderSans would look nicer, but
  `Font.new` degrades silently to something worse when the family is missing
  on a client, and Gotham is certain to exist everywhere.
- There is no theme system. That is a design decision, not an omission.

---

## Licence

MIT. Use it in anything, including closed-source and commercial hubs; just
keep the copyright notice. See [LICENSE](LICENSE).

Issues and pull requests are welcome. If you hit a runtime bug, the most
useful report is the error text plus what you clicked.
