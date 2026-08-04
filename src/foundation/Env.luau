local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Env = {}

local globals: { [string]: any }
do
	local fromEnv, environment = pcall(getfenv, 0)
	if fromEnv and type(environment) == "table" then
		globals = environment
	else
		globals = (_G :: any)
	end

	local shared = rawget(globals, "getgenv")
	if type(shared) == "function" then
		local ok, table_ = pcall(shared)
		if ok and type(table_) == "table" then
			globals = table_
		end
	end
end

local function grab(name: string): any
	local ok, value = pcall(function()
		return globals[name]
	end)
	if ok then
		return value
	end
	return nil
end

local function grabFunction(name: string)
	local value = grab(name)
	return if type(value) == "function" then value else nil
end

local writeFile = grabFunction("writefile")
local readFile = grabFunction("readfile")
local isFile = grabFunction("isfile")
local isFolder = grabFunction("isfolder")
local makeFolder = grabFunction("makefolder")
local listFiles = grabFunction("listfiles")
local delFile = grabFunction("delfile")
local getHui = grabFunction("gethui")
local clipboard = grabFunction("setclipboard")

local protectGui = grabFunction("protect_gui")
if not protectGui then
	local syn = grab("syn")
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		protectGui = syn.protect_gui
	end
end

local identify = grabFunction("identifyexecutor") or grabFunction("getexecutorname")

Env.hasFiles = writeFile ~= nil and readFile ~= nil and isFile ~= nil
Env.hasFolders = Env.hasFiles and isFolder ~= nil and makeFolder ~= nil
Env.hasListing = Env.hasFiles and listFiles ~= nil
Env.hasDelete = Env.hasFiles and delFile ~= nil
Env.isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

do
	local ok, name = pcall(function()
		return if identify then identify() else "unknown"
	end)
	Env.executor = if ok and type(name) == "string" then name else "unknown"
end

function Env.player(): Player?
	return Players.LocalPlayer
end

function Env.mount(gui: ScreenGui): string
	if getHui then
		local ok, hidden = pcall(getHui)
		if ok and typeof(hidden) == "Instance" then
			local parented = pcall(function()
				gui.Parent = hidden
			end)
			if parented then
				return "gethui"
			end
		end
	end

	if protectGui then
		pcall(protectGui, gui)
	end

	local mounted = pcall(function()
		gui.Parent = CoreGui
	end)
	if mounted then
		return "coregui"
	end

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local fallback = pcall(function()
			gui.Parent = playerGui
		end)
		if fallback then
			return "playergui"
		end
	end

	return "none"
end

function Env.ensureFolder(path: string): boolean
	if not Env.hasFolders then
		return false
	end

	local built: string? = nil

	for _, segment in string.split(path, "/") do
		if segment ~= "" then
			built = if built then built .. "/" .. segment else segment

			local ok, exists = pcall(isFolder, built)
			if not ok or exists ~= true then
				local created = pcall(makeFolder, built)
				if not created then
					return false
				end
			end
		end
	end

	return true
end

function Env.exists(path: string): boolean
	if not Env.hasFiles then
		return false
	end
	local ok, result = pcall(isFile, path)
	return ok and result == true
end

function Env.read(path: string): string?
	if not Env.exists(path) then
		return nil
	end
	local ok, contents = pcall(readFile, path)
	if ok and type(contents) == "string" then
		return contents
	end
	return nil
end

function Env.write(path: string, contents: string): (boolean, string?)
	if not Env.hasFiles then
		return false, "no file access"
	end
	local ok, err = pcall(writeFile, path, contents)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

function Env.list(path: string): { string }
	if not Env.hasListing then
		return {}
	end
	local ok, entries = pcall(listFiles, path)
	if ok and type(entries) == "table" then
		return entries
	end
	return {}
end

function Env.delete(path: string): boolean
	if not Env.hasDelete then
		return false
	end
	return (pcall(delFile, path))
end

function Env.remember(key: string, value: any): boolean
	local ok = pcall(function()
		globals[key] = value
	end)

	if not ok then
		return false
	end

	return rawequal(Env.recall(key), value)
end

function Env.recall(key: string): any
	return grab(key)
end

function Env.copy(text: string): boolean
	if not clipboard then
		return false
	end
	return (pcall(clipboard, text))
end

return Env
