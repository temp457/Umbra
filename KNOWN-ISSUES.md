# Known issues

Things that are deliberately unfixed, or fixed in a way worth explaining.

## Not fixed

**Not every size is on a scale.** Control heights follow an 18/24/32 scale and
radii follow 2/4/6/8/10, but a handful of one-off widths remain — the changelog
version column, the keybind-list key column, the colour picker panel. They look
fine; they're just not derived from a token.

**Notification bodies truncate rather than expand.** Capped at four lines with
an ellipsis. Long text belongs in a dialog.

**Rail scrolling past ~9 tabs.** It works and the scrollbar shows, but there's
no other affordance hinting that more tabs exist below.

## Worth knowing

**Popup dismissal doesn't use coordinate maths.** A full-screen invisible button
sits behind any open popup, so a click that isn't on the popup lands on the
catcher. This avoids the `InputObject.Position` versus `AbsolutePosition` GUI
inset problem entirely. The colour square's drag is delta-based for the same
reason, so it tracks the cursor exactly regardless of how the first click maps.

**Rows that can't fit their controls split onto two lines.** Chaining `:Bind{}`
and `:Color{}` onto one toggle needs more width than a two-column layout gives
it, so the label moves above and the controls right-align beneath. Nothing
clips and nothing overlaps.

**The window is anchored top-left at integer offsets.** The root is a
`CanvasGroup`, which rasterises its children into an offscreen buffer. Anchored
centrally it could land on a half-pixel and resample the whole window, which
made text look soft. Integer positioning keeps every glyph on the pixel grid;
drag and resize round accordingly.

## Reporting a bug

The most useful report is the error text plus what you clicked, or a screenshot
if it's visual. Runtime behaviour is the part that can't be checked without the
engine, so real-world reports are genuinely the best signal available.
