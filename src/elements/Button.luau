local Theme = require("Theme")
local Create = require("Create")
local Motion = require("Motion")
local Element = require("Element")

local Button = {}

function Button.build(section, opts)
	local handle = Element.new(section, opts, { kind = "button" })

	local marker = Create.text({
		Name = "Marker",
		Text = ">",
		TextSize = Theme.size.small,
		TextColor3 = Theme.text[2],
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(10, 16),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = handle.slot,
	})
	handle:track(marker)

	handle.armed = false
	handle.value = false

	local function disarm()
		if not handle.armed then
			return
		end
		handle.armed = false
		handle:SetText(handle.text or "")
		handle:rebase(handle.label, Theme.text[1])
	end

	handle.trove:Connect(handle.hit.Activated, function()
		if not handle.enabled then
			return
		end

		Motion.tween(handle.frame, Motion.curve.hover, { BackgroundTransparency = 0 }, handle.trove)
		Motion.after(0.08, function()
			if handle.frame.Parent then
				Motion.tween(handle.frame, Motion.curve.hover, {
					BackgroundTransparency = if handle.hovered then 0 else 1,
				}, handle.trove)
			end
		end, handle.trove)

		if opts.Confirm and not handle.armed then
			handle.armed = true
			handle.label.Text = opts.ConfirmText or "Confirm?"
			handle:rebase(handle.label, Theme.text[0])
			Motion.after(3, disarm, handle.trove)
			return
		end

		disarm()
		Element.guard(handle, opts.Callback or opts.Func)
	end)

	handle._apply = function()
		return false
	end

	return handle
end

return Button
