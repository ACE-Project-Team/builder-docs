AskBob.Version    = "0.1.0"
AskBob.DefaultAPI = "https://acegmod.com"
-- Display name in titles, menus and console prefixes. Internal names (AskBob, askbob_*) stay.
AskBob.Name       = "Builder Docs"

-- Hosts the client will ever send a request to. The API URL is a client-only
-- convar, and this list stops it, or anything that sets it, from pointing a
-- player's Bob at some other host. It can't stop a server that replaces this
-- addon's clientside Lua: in GMod a server can send any client code it likes.
AskBob.AllowedHosts = {
	["acegmod.com"] = true,
	["www.acegmod.com"] = true,
	["localhost"] = true,
	["127.0.0.1"] = true,
}

-- Server-owned, replicated so the client UI can show them.
CreateConVar("askbob_scope", "", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Default scope tokens for this server, comma separated (e.g. ace,sf,pac3). Empty = everything.")
-- The first three triggers are shown to players; any after that still work.
CreateConVar("askbob_chat_triggers", "!docs,!ask,!search,!bob", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Chat commands that open the search, comma separated. Commands owned by ULX/ULib are skipped.")

if CLIENT then
	-- FCVAR_ARCHIVE only, never replicated. A server can still run ply:ConCommand,
	-- so AllowedHosts above is what keeps this on acegmod.com or localhost.
	CreateClientConVar("askbob_api_url", AskBob.DefaultAPI, true, false, "Search API base URL (ACE domain or localhost only).")
	CreateClientConVar("askbob_ponder", "1", true, false, "Include installed Ponder tutorials in search results.")
	CreateClientConVar("askbob_key", "0", true, false, "Key that looks up what you are looking at (0 = unbound).")
end

-- Shared helpers ------------------------------------------------------------

function AskBob.SplitList(str)
	local out, seen = {}, {}
	for part in string.gmatch(str or "", "[^,]+") do
		part = string.Trim(part):lower()
		if part ~= "" and not seen[part] then
			seen[part] = true
			out[#out + 1] = part
		end
	end
	return out
end

-- The chat commands to show players: the first three configured triggers, e.g. "!docs, !ask or !search".
function AskBob.ShownTriggers()
	local list = AskBob.SplitList(GetConVar("askbob_chat_triggers"):GetString())
	local shown = { unpack(list, 1, math.min(#list, 3)) }
	if #shown == 0 then return "!docs" end
	if #shown == 1 then return shown[1] end
	return table.concat(shown, ", ", 1, #shown - 1) .. " or " .. shown[#shown]
end
