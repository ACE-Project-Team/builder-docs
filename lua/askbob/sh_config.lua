AskBob.Version    = "0.1.0"
AskBob.DefaultAPI = "https://acegmod.com"

-- Hosts the client will ever send a request to. The API URL is a client-only
-- convar, but this list is the real guard: no server, map or other addon can
-- point a player's Bob at a host that would collect their IP.
AskBob.AllowedHosts = {
	["acegmod.com"] = true,
	["www.acegmod.com"] = true,
	["localhost"] = true,
	["127.0.0.1"] = true,
}

-- Server-owned, replicated so the client UI can show them.
CreateConVar("askbob_scope", "", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Default scope tokens for this server, comma separated (e.g. ace,sf,pac3). Empty = everything.")
CreateConVar("askbob_chat_triggers", "!bob,!ask", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Chat commands that open Ask Bob, comma separated. Commands owned by ULX/ULib are skipped.")

if CLIENT then
	-- FCVAR_ARCHIVE only: never replicated, never settable by a server.
	CreateClientConVar("askbob_api_url", AskBob.DefaultAPI, true, false, "Ask Bob API base URL (ACE domain or localhost only).")
	CreateClientConVar("askbob_ponder", "1", true, false, "Include installed Ponder tutorials in Ask Bob results.")
	CreateClientConVar("askbob_key", "0", true, false, "Key that asks Bob about what you are looking at (0 = unbound).")
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
