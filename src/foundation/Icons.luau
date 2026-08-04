local Icons = {}

function Icons.resolve(icon: any): string?
	if type(icon) == "number" and icon > 0 then
		return "rbxassetid://" .. tostring(math.floor(icon))
	end

	if type(icon) == "string" then
		local assetId = string.match(icon, "^rbxassetid://(%d+)$")
		if assetId then
			return if (tonumber(assetId) or 0) > 0 then icon else nil
		end
		if string.match(icon, "^rbxasset://") then
			return icon
		end
		if string.match(icon, "^http://www%.roblox%.com/asset") then
			return icon
		end
		if string.match(icon, "^%d+$") then
			return if (tonumber(icon) or 0) > 0 then "rbxassetid://" .. icon else nil
		end
	end

	return nil
end

function Icons.letter(source: any): string
	if type(source) ~= "string" then
		return "?"
	end

	local trimmed = string.gsub(source, "^%s+", "")
	if trimmed == "" then
		return "?"
	end

	local ok, offset = pcall(utf8.offset, trimmed, 2)
	if ok and offset then
		return string.upper(string.sub(trimmed, 1, offset - 1))
	end

	return string.upper(string.sub(trimmed, 1, 1))
end

return Icons
