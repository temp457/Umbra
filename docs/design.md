# Umbra — Roblox GUI library design

Date: 2026-08-04
Status: approved, implementation authorised

## What this is

A GUI library for Roblox executor script hubs. A hub author loads one file and
gets a window, tabs, sections, form elements, notifications, dialogs, saved
configs, a keybind overlay, a watermark and search — without writing any layout
or animation code.

It is not an in-game UI framework. It targets `gethui()`/CoreGui, assumes
executor globals may or may not exist, and ships as a single `loadstring`-able
file.

## Goals

- One `loadstring` gives a complete, finished-looking menu.
- A hub author cannot easily make it ugly. Layout, spacing, colour and motion
  are the library's decisions, not theirs.
- Nothing runs per frame while idle.
- Unloading leaves zero connections, threads, tweens or instances behind.
- Every source file stays small enough to edit precisely.

## Non-goals

- Theme customisation. There is one theme.
- API compatibility with Obsidian, Linoria or any other library.
- In-game (non-executor) support.

## Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Target | Executor hubs only | Matches the intended consumers; lets the library assume CoreGui and executor globals |
| Palette | Dark only, pure monochrome, no accent | Strongest identity; no drift; smallest code |
| Motion | Expressive — 360ms with overshoot, staggered reveals | Author's explicit choice; centralised so it is a constant-change away from quieter |
| Elements | Full set, 12 types | All needed by real hubs |
| API | Original, chainable attachments | Cleaner than flat global state; chaining models attachment, not sequencing |
| Source | Multi-module, bundled to one file | Small files; each closure gets its own 200-local budget |
| Systems | Config, keybind overlay, mobile, watermark, search | All shipped in v1 |
| Home screen | Info panel from a config table | Author supplies data, library owns layout |

## Architecture

Strict layering. A module may only require modules in a layer below it.

### Foundation

| Module | Responsibility |
|---|---|
| `Env` | Executor capability detection. Resolves the UI parent (`gethui()` → `CoreGui` → `PlayerGui`) and applies `protect_gui`/`syn.protect_gui` when present. Wraps every filesystem global behind a presence check so a missing file API degrades to "configs unavailable" instead of erroring. Exposes `Env.hasFiles`, `Env.hasFolders`, `Env.hasListing`, `Env.hasDelete`, `Env.isTouch`, `Env.executor`, and `Env.mount(gui)`. |
| `Signal` | Minimal signal. `:Connect(fn)` returns a disconnect function, not a connection object. `:Fire(...)` iterates a snapshot so a handler may disconnect during dispatch. `:Destroy()` drops all. |
| `Trove` | Cleanup collector. Accepts Instances, RBXScriptConnections, Tweens, threads, functions and other Troves. `:Clean()` reverses insertion order. Every window, page, section, element and notification owns one. |
| `Theme` | The only file containing a `Color3`. Surface, line, text and fill tokens plus type, spacing and radius scales. |
| `Motion` | The only file containing a tween curve. Named curves, `tween`, `stagger`, `sequence`, and cancellation bookkeeping so a second tween on the same property cancels the first. |
| `Create` | `new(class, props, children)` plus primitives: corner, stroke, padding, list, text, button. Resolves the font once at load with a fallback chain. |
| `Icons` | Name → asset resolution, with a letter-mark fallback. |

### Structure

`Window` → `Rail` → `Page` → `Section`. Elements attach to a `Section`.

- `Window` owns the root ScreenGui, title bar, drag, resize, toggle keybind,
  open/close animation, the root Trove and the flag registry.
- `Rail` owns the icon column, the active indicator and tab switching.
- `Page` owns one tab's scrolling content, the two-column flow and the reveal
  animation on activation.
- `Section` owns a titled container and the rows within it.

### Elements

Twelve modules behind one contract. See "Element contract" below.

### Systems

`Registry`, `Notify`, `Dialog`, `Keybinds`, `Watermark`, `Search`, `Config`.

## Design system

### Colour

All surfaces are truly neutral, R=G=B. No cool or warm cast — a tint is what
makes most "black" menus read muddy.

| Token | Hex |
|---|---|
| `surface[0]` | `#080808` title bar, rail |
| `surface[1]` | `#121212` window body |
| `surface[2]` | `#1E1E1E` section, notification, dialog |
| `surface[3]` | `#2A2A2A` field, secondary button, pill |
| `surface[4]` | `#3A3A3A` row hover |
| `line.soft` | `#3F3F3F` hairline divider, container border |
| `line.control` | `#6E6E6E` control boundary (toggle track, checkbox, slider) |
| `line.focus` | `#A0A0A0` focus border, swatch border |
| `line.disabled` | `#3F3F3F` disabled control boundary |
| `text[0]` | `#FFFFFF` primary, active, values |
| `text[1]` | `#B4B4B4` row labels, body |
| `text[2]` | `#949494` section headers, secondary |
| `text[3]` | `#6E6E6E` disabled only |
| `fill` | `#FFFFFF` active toggle, checked box, primary button |
| `onFill` | `#080808` content on top of `fill` |
| `knobOff` | `#949494` toggle knob in its off state |

`line.control` is separate from `line.soft` because a control's boundary must
clear 3:1 against its background (WCAG 1.4.11) while a decorative divider need
not. Collapsing them makes off-toggles and unchecked boxes invisible.

Contrast is verified against every surface each token can land on, not just one.
Row labels sit on `surface[2]` at rest and `surface[4]` on hover; both must clear
4.5:1. Any token failing on any reachable surface is corrected at the token, not
worked around at the call site.

### Type

Gotham enums, not `Font.new` — a missing font family degrades silently rather
than erroring, so a certain enum beats a nicer gamble. `Theme.font.regular` is
`GothamMedium` and `Theme.font.medium` is `GothamBold`; the whole scale sits one
weight heavier than nominal because thin strokes alias badly at 11-13px.
RobotoMono for live-updating
numerics (FPS, ping, slider values, hex codes, keybind chips) so digit width
does not shift layout as values change.

Scale: 18 hero, 14 window/page title, 13 row label and body, 12 secondary and
field, 11 section header and chip. Nothing below 11.

Roblox exposes no letter-spacing property, so there is no tracked uppercase
anywhere in the design. Faking it by inserting spaces breaks text measurement
and truncation.

### Geometry

Radius 10 window, 8 section, 6 control, 5 chip, 4 swatch, full-round toggle.
Spacing scale 4, 6, 8, 12, 16, 20, 24. Borders 1px `UIStroke`.

Window 620×420 default, 480×340 minimum, resizable and draggable. Rail 52px.
Rows 32px desktop, 44px touch.

### Layout

A `Page` flows its sections into two columns above 560px of window width and one
column below, which is also the mobile answer. Each new section is assigned to
whichever column is currently shorter, so the two sides stay balanced. Sections
accept `Column = "left" | "right"` to override.

Rows are transparent at rest and separated by hairlines, filling `surface[4]` on
hover. A stack of individually filled cards is the main reason menus of this kind
read as busy.

### Text overflow

Every row is a label and a control competing for one fixed width. The rule is:
**the control gets its natural width, the label takes the remainder and
truncates**. Controls never shrink, labels never wrap, and no row ever grows
past its column. Any label that can be author- or user-supplied is truncated
with an ellipsis and carries a tooltip with the full string.

## Motion

Expressive, and entirely `TweenService` — no per-frame work while idle.

| Moment | Motion |
|---|---|
| State change (toggle, check, slider knob) | 360ms overshoot |
| Tab switch | Rows fade in with an 8px upward lift, staggered 20ms per row |
| Notification in | Slide from right with overshoot |
| Notification out | Ease out, no overshoot |
| Window open | Scale from 0.96 with fade, 360ms |
| Hover | 120ms linear — hover must never lag the cursor |

Every curve is a named constant in `Motion`. No element constructs its own
`TweenInfo`. Any tween on a property that already has one in flight cancels the
first, and every tween is registered to the owning Trove so a destroyed element
cannot be animated.

## Public API

```lua
local Umbra = loadstring(game:HttpGet("https://.../umbra.luau"))()

local Window = Umbra:Window({
    Name = "Overkill Hub",
    Version = "1.4.0",
    Toggle = Enum.KeyCode.RightControl,
    Home = {
        Description = "Combat and movement suite for Overkill.",
        Changelog = { { Version = "1.4.0", Notes = { "Spinbot" } } },
        Links = { { Text = "Discord", Url = "https://..." } },
        Credits = { "Built by killr" },
    },
})

local Combat = Window:Tab("Combat", "crosshair")
local Targeting = Combat:Section("Targeting")

Targeting:Toggle({ Flag = "silent_aim", Text = "Silent aim", Default = false })
    :Bind({ Flag = "silent_key", Default = "MB2", Mode = "Hold" })
    :Tip("Redirects shots")

Targeting:Slider({ Flag = "fov", Text = "FOV", Min = 0, Max = 360, Default = 124 })
Targeting:Dropdown({ Flag = "targets", Text = "Targets", Source = "Players", Multi = true })
```

Three rules govern the surface:

**Chaining is attachment, not sequencing.** An element constructor returns that
element's handle, so `:Bind{}`, `:Color{}` and `:Tip()` chain onto the row they
belong to. Chaining siblings would return the wrong object for `:OnChanged`, so
it is not supported.

**`Flag` is the only identity.** Flagged elements are saved by Config and found
by Search. Unflagged elements are ephemeral. A duplicate flag throws at build
time rather than silently overwriting — the failure mode where an element becomes
permanently unsaveable and nobody notices.

**Values read live, handles control.** `Window.Flags.silent_aim` returns the
current value through an `__index` proxy. `Window:Element("silent_aim")` returns
the handle for `:Set`, `:Get`, `:OnChanged`, `:SetText`, `:SetVisible`,
`:SetEnabled` and `:Destroy`. `:OnChanged` returns a disconnect function so a
caller cannot leak by forgetting which field to disconnect.

Remaining surface:

```lua
Umbra:Notify({ Title = "Config saved", Text = "default.json", Icon = "check", Duration = 4 })
Umbra:Dialog({ Title = "Unload?", Buttons = { { Text = "Cancel" }, { Text = "Unload", Primary = true, Callback = f } } })
Umbra:Watermark({ Text = "Overkill Hub", Fps = true, Ping = true })
Umbra:Keybinds(true)
Window:Config({ Folder = "OverkillHub", Autoload = true })
Window:Tab("Settings", "settings"):ConfigSection()
Umbra:OnUnload(f)
Umbra:Unload()
```

`Notify` returns a handle with `:Update{}` and `:Dismiss()` so a long-running
action owns one notification instead of emitting four.

## Sub-menus

Any row can carry a `⋯` button that opens a floating panel of further options.
`Element:Menu(opts)` returns the panel, which **is a detached `Section`** — so
every element type works inside it with no per-element support, including
another `:Menu{}`. Menus nest arbitrarily.

Three mechanics make that work:

- **The panel is built once at attach time** and parented to `nil` while closed,
  reparented to the overlay on open. Building it lazily would mean flags
  registering late, so duplicate detection, config saving and search would all
  miss its contents until the first open.
- **Popups are a stack, not a single slot.** A dropdown opened *inside* a
  sub-menu pushes a third popup; each level gets its own click-catcher at
  `zone.overlay + depth*2` and panel at `zone.popup + depth*2`. `closePopup`
  pops one level (so Escape backs out), `closePopups` drains — the latter is
  what window drag, resize, tab switch, hide and destroy call.
- **`section.anchorRow`** points at the owning row, because a sub-menu element
  has no meaningful `AbsolutePosition` while its panel is unparented. Search
  scrolls to the anchor row and then calls `section.openMenu()`.

## Element contract

Every element module exports:

```lua
build(section, opts) -> handle
```

`Element` supplies the shared scaffold so no element module implements layout:
the row frame, hover and press states, the truncating label, the tooltip, the
right-aligned control slot, disabled rendering, flag registration and Trove
parenting. An element module is responsible only for its control's visual and
its value semantics.

Every handle exposes `Get`, `Set`, `OnChanged`, `SetText`, `SetVisible`,
`SetEnabled`, `Destroy`, and the attachment methods `Bind`, `Color` and `Tip`
where applicable.

The twelve: `Label`, `Divider`, `Button`, `Toggle`, `Checkbox`, `Slider`,
`Input`, `Dropdown`, `Keybind`, `ColorPicker`, `Viewport`, `Image`.

## Systems

**Registry** — flag → handle, owned by the window. The single source Config and
Search both read. Duplicate flags throw.

**Config** — walks the registry, serialises every flagged value to JSON, writes
under `<Folder>/<place or global>/<name>.json`. Named configs, list, load, save,
delete, and autoload on start. Values are validated on load: wrong type, out of
range, or an option that no longer exists is skipped with a notification rather
than applied. When `Env.hasFiles` is false the whole system disables itself and
says so once.

**Notify** — a top-right stack, newest on top, each with an independent timer and
progress bar. Capped; beyond the cap the oldest is dismissed early rather than
letting the stack run off-screen.

**Dialog** — modal with a scrim that blocks input to the window beneath.

**Keybinds** — a draggable overlay listing every bound key and its live state,
independent of whether the window is open.

**Watermark** — a draggable bar with the hub name and optional FPS, ping and
clock. Samples at 4Hz off a single `Heartbeat` accumulator — the one permitted
per-frame consumer, and only while the watermark exists.

**Search** — fuzzy-matches every registered element by label and section, and
jumps to it: switches tab, scrolls it into view, and flashes the row.

## Lifecycle

One root ScreenGui per window. Every Instance, connection, thread and tween is
registered to the nearest Trove at creation, and Troves nest so destroying a
section destroys its rows' subscriptions.

Deferred work is the known leak: a connection made after a yield can outlive a
cleanup that ran before it existed. Every deferred connect is guarded by both a
parent-existence check *after* the yield (`if inst.Parent == nil then return end`),
and the thread is registered to a Trove so cleanup cancels it. `Trove:Add` on an
already-dead Trove disposes the item immediately, which closes the
add-after-cleanup race.

Re-running the loadstring detects an existing global and unloads the previous
instance first, so iterating on a hub never leaves two menus or a doubled input
handler behind.

## Build and distribution

`build/build.py` walks `src/`, wraps each module in its own closure with a small
require shim, and emits `dist/umbra.luau` — one file, each module keeping its own
200-local budget. The build then runs `luau-compile` on the output and fails the
build on a parse error, so a broken bundle cannot ship.

## Error handling

The library never crashes a hub. Every author-supplied callback is invoked inside
a `pcall`; a failing callback is reported through a notification and logged with
the element's flag, and the element keeps working. Errors are never silently
swallowed — a discarded error is treated as a defect.

Author mistakes that are unrecoverable (duplicate flag, a slider with `Min` equal
to `Max`, a dropdown with no options) throw immediately at build time with a
message naming the flag, because failing at construction is far cheaper to
diagnose than failing at interaction.

## Verification

- `luau-compile` parse-checks the emitted bundle. This is a hard gate — the
  build writes to a staging file, compiles it, and only promotes it to
  `dist/umbra.luau` on exit 0. **Caveat:** the compiler path is hardcoded to
  `~/.rokit/bin/luau-compile.exe`; if that binary is absent the check is skipped
  and the bundle ships unverified.
- `luau-analyze` type- and lint-checks the source. Run it yourself — it is not
  wired into the build scripts.
- Review passes over the design system and the source, covering overflow,
  contrast, clipping, scale, touch targets, leaked connections and cleanup.
- `Example.luau` exercises every element and doubles as the smoke test.

Runtime behaviour cannot be verified outside Roblox. Anything claimed as working
rests on the checks above, and that limit is stated rather than glossed.

## Notable decisions

**Icons are letter-marks by default.** Shipping a table of unverified
`rbxassetid` values would render blank boxes in production. The rail draws the
tab's first letter as an 18px medium mark when no icon is supplied, which reads
as deliberate in a monochrome design. `Icon` accepts an explicit
`rbxassetid://` string or numeric id for authors with their own set.

**Fonts resolve defensively.** `Font.new` availability and the presence of the
BuilderSans family both vary by client, and a missing family degrades silently
rather than erroring — so the library uses Gotham enums, which are certain to
exist.

**Columns are assigned alternately, not by height.** Sections are created in a
burst before any layout pass, so measured heights would all read zero and every
section would land in the left column. Alternating is deterministic and gives
the same result for the common case.

**Sections fade in rather than lifting.** `UIListLayout` owns child position, so
a positional reveal would fight the layout. Sections are `CanvasGroup`s and
stagger their `GroupTransparency` instead.
