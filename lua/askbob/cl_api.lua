-- Talks to the ACE public API. Everything that comes back is treated as data:
-- it is shown as text and never compiled or run.
local API = {}
AskBob.API = API

local CACHE_SECONDS = 300
local MAX_BODY = 512 * 1024
local cache = {}

local function urlencode(s)
	return (string.gsub(s, "[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function hostOf(url)
	return string.match(url, "^https?://([^/:]+)")
end

function API.Base()
	local url = string.gsub(string.Trim(GetConVar("askbob_api_url"):GetString()), "/+$", "")
	-- The console eats everything after "//" unless the value is quoted, so
	-- `askbob_api_url localhost:3000` (no scheme) is accepted too.
	if url ~= "" and not string.match(url, "^https?://") then
		local bare = string.gsub(url, "^https?:?/*", "")
		local h = string.match(bare, "^([^/:]+)")
		local isLocal = h == "localhost" or h == "127.0.0.1"
		url = (isLocal and "http://" or "https://") .. bare
	end
	local host = hostOf(url)
	host = host and host:lower()
	if host and AskBob.AllowedHosts[host] then
		-- Plain http only for local dev; the real site must be https.
		local local_ = host == "localhost" or host == "127.0.0.1"
		if local_ or string.match(url, "^https://") then return url end
	end
	return AskBob.DefaultAPI
end

function API.Absolute(url)
	if not isstring(url) or url == "" then return API.Base() end
	if string.sub(url, 1, 1) == "/" and string.sub(url, 2, 2) ~= "/" then return API.Base() .. url end
	-- Only plain web links leave the game; steam://, file:// and the like never do.
	if string.match(url, "^https?://[^%s]+$") then return url end
	return API.Base()
end

API.urlencode = urlencode

concommand.Add("askbob_status", function()
	local raw = GetConVar("askbob_api_url"):GetString()
	print("[" .. AskBob.Name .. "] askbob_api_url = \"" .. raw .. "\"  ->  using " .. API.Base())
	if raw ~= "" and API.Base() == AskBob.DefaultAPI and not string.find(raw, "acegmod.com", 1, true) then
		print("[" .. AskBob.Name .. "] That address isn't allowed (ACE domain or localhost only), so the live site is used.")
	end
end, nil, "Show which website the search is talking to.")

-- "/wiki/foo" or ".../org/x/wiki/foo" → "foo", so Bob can read it in-game.
function API.WikiSlug(url)
	if not isstring(url) then return nil end
	return string.match(url, "/wiki/([%w%-_]+)/?$")
end

local ERRORS = {
	[400] = "The site couldn't read that question.",
	[404] = "That page doesn't exist.",
	[429] = "Too many searches right now. Try again in a minute.",
	[502] = "The AI couldn't answer that right now.",
	[503] = "Search is switched off on the site right now.",
}

local function get(path, params, callback, retried)
	local parts = {}
	for k, v in SortedPairs(params or {}) do
		if v ~= nil and v ~= "" then parts[#parts + 1] = k .. "=" .. urlencode(tostring(v)) end
	end
	local url = API.Base() .. path .. (#parts > 0 and ("?" .. table.concat(parts, "&")) or "")

	local hit = cache[url]
	if hit and hit.expires > SysTime() then
		callback(true, hit.data)
		return
	end

	HTTP({
		url = url,
		method = "GET",
		-- GMod refuses to override User-Agent, so the version rides in its own header.
		headers = { ["X-AskBob-Version"] = AskBob.Version },
		success = function(code, body)
			if code ~= 200 then
				callback(false, ERRORS[code] or ("Unexpected answer from the site (" .. code .. ")."))
				return
			end
			-- Real answers are a few KB; refuse anything big enough to stall the client.
			if not body or #body > MAX_BODY then
				callback(false, "The site's answer couldn't be read.")
				return
			end
			local data = util.JSONToTable(body)
			if not istable(data) then
				callback(false, "The site's answer couldn't be read.")
				return
			end
			cache[url] = { data = data, expires = SysTime() + CACHE_SECONDS }
			callback(true, data)
		end,
		failed = function(reason)
			-- One quiet retry: a site restart or a dropped connection is usually gone a second later.
			if not retried then
				timer.Simple(1.5, function() get(path, params, callback, true) end)
				return
			end
			callback(false, "Can't reach " .. API.Base() .. " right now (" .. tostring(reason or "no response") .. ").")
		end,
	})
end

-- opts: { scope = "ace,sf", types = "wiki,docs" }
function API.Search(query, opts, callback)
	opts = opts or {}
	get("/api/public/search", { q = query, scope = opts.scope, types = opts.types }, callback)
end

-- { filters = { {token, label, kind}, ... }, orgs = { {token, label}, ... } }
function API.Scopes(callback)
	get("/api/public/search-scopes", nil, callback)
end

-- AI answer (DeepWiki) for one scope token, or ACE's when scope is nil.
-- { aiGenerated, answerer, label, repo, answer, sourceUrl }. Slow (10-30s) and
-- metered hard on the site, so only call it when the player turned AI on.
function API.AskAI(question, scope, callback)
	get("/api/public/ask", { q = question, scope = scope }, callback)
end

function API.Article(slug, callback)
	get("/api/public/wiki/articles/" .. urlencode(slug), nil, callback)
end
