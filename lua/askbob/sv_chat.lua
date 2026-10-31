util.AddNetworkString("askbob_open")
util.AddNetworkString("askbob_admin_set")

-- Is this say-command already owned by ULX/ULib? We step aside rather than
-- both addons reacting to the same message.
local function ownedByULib(cmd)
	if not ULib then return false end
	if ULib.sayCmds and (ULib.sayCmds[cmd] or ULib.sayCmds[cmd .. " "]) then return true end
	return false
end

local triggers = {}

local function rebuildTriggers()
	triggers = {}
	for _, cmd in ipairs(AskBob.SplitList(GetConVar("askbob_chat_triggers"):GetString())) do
		-- "!bob" also answers to "/bob", the other common chat-command prefix.
		local variants = { cmd }
		local prefix, word = cmd:match("^([!/])(.+)$")
		if prefix then variants[2] = (prefix == "!" and "/" or "!") .. word end

		for _, v in ipairs(variants) do
			if ownedByULib(v) then
				MsgC(Color(255, 180, 0), "[" .. AskBob.Name .. "] '" .. v .. "' is a ULX/ULib command, skipping it.\n")
			else
				triggers[v] = true
			end
		end
	end
end

cvars.AddChangeCallback("askbob_chat_triggers", rebuildTriggers, "AskBob")
-- ULX registers its say commands during load, so wait until everything is in.
hook.Add("InitPostEntity", "AskBob.Triggers", rebuildTriggers)
if GAMEMODE then rebuildTriggers() end -- lua refresh

hook.Add("PlayerSay", "AskBob.Chat", function(ply, text)
	local cmd, rest = string.match(text, "^(%S+)%s*(.*)$")
	if not cmd or not triggers[cmd:lower()] then return end

	net.Start("askbob_open")
	net.WriteString(string.sub(rest, 1, 200))
	net.Send(ply)
	return ""
end)

-- Superadmins edit the server settings from the Q-menu page.
local ALLOWED = { askbob_chat_triggers = true, askbob_scope = true }

net.Receive("askbob_admin_set", function(_, ply)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end
	local name, value = net.ReadString(), net.ReadString()
	if not ALLOWED[name] then return end

	-- Only command/token characters; this ends up in a convar and in chat matching.
	value = string.sub(string.gsub(value, "[^%w!/,%._%-]", ""), 1, 200)
	GetConVar(name):SetString(value)
	ply:ChatPrint("[" .. AskBob.Name .. "] " .. name .. " = " .. value)
end)
