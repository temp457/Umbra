local Element = require("Element")

local Label = {}

function Label.build(section, opts)
	local handle = Element.new(section, opts, {
		interactive = false,
		wrap = opts.Wrap == true,
		kind = "label",
	})

	handle.value = opts.Text or ""

	handle._apply = function(value)
		local text = tostring(value)
		handle:SetText(text)
		return text
	end

	return handle
end

return Label
