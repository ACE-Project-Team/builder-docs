-- Ask Bob: in-game help backed by the ACE wiki, org wikis, docs and Ponder.
AskBob = AskBob or {}

local function shared(path)
	if SERVER then AddCSLuaFile(path) end
	include(path)
end

local function client(path)
	if SERVER then AddCSLuaFile(path) else include(path) end
end

shared("askbob/sh_config.lua")

if SERVER then
	include("askbob/sv_chat.lua")
end

client("askbob/cl_api.lua")
client("askbob/cl_ponder.lua")
client("askbob/cl_render.lua")
client("askbob/cl_mascot.lua")
client("askbob/cl_ui_widgets.lua")
client("askbob/cl_ui_filters.lua")
client("askbob/cl_ui_reader.lua")
client("askbob/cl_ui_results.lua")
client("askbob/cl_ui.lua")
client("askbob/cl_spawnmenu.lua")
client("askbob/cl_options.lua")
if SERVER then
	for _, f in ipairs(file.Find("askbob/plugins/*.lua", "LUA")) do AddCSLuaFile("askbob/plugins/" .. f) end
end
client("askbob/cl_context.lua")
client("askbob/cl_editors.lua")

MsgC(Color(120, 200, 255), "[Ask Bob] ", color_white, "loaded v" .. AskBob.Version .. (SERVER and " (server)\n" or " (client)\n"))
