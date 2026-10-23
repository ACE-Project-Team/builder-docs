-- Local search over installed Ponder storyboards (ACF-Team/Ponder). Nothing
-- here touches the network; if Ponder isn't installed it all quietly no-ops.
local P = {}
AskBob.Ponder = P

-- A match at or above this share of query words is shown as a "Show me" card.
P.STRONG = 0.6

function P.Available()
	return GetConVar("askbob_ponder"):GetBool()
		and istable(Ponder) and isfunction(Ponder.Open)
		and istable(Ponder.API) and istable(Ponder.API.RegisteredStoryboards)
end

local function phrase(s)
	if not isstring(s) then return "" end
	return language.GetPhrase(s)
end

local function describe(uuid, sb)
	local addon = Ponder.API.RegisteredAddons and Ponder.API.RegisteredAddons[sb.AddonName]
	local title = phrase(sb.Name)
	local addonName = addon and phrase(addon.Name) or tostring(sb.AddonName or "")
	local category = phrase(sb.CategoryName)
	return {
		uuid = uuid,
		title = title,
		addon = addonName,
		category = category,
		haystack = string.lower(table.concat({ title, addonName, category, tostring(sb.AddonName) }, " ")),
	}
end

function P.All()
	if not P.Available() then return {} end
	local out = {}
	for uuid, sb in pairs(Ponder.API.RegisteredStoryboards) do
		out[#out + 1] = describe(uuid, sb)
	end
	table.sort(out, function(a, b)
		if a.addon ~= b.addon then return a.addon < b.addon end
		return a.title < b.title
	end)
	return out
end

local function words(text)
	local out = {}
	for w in string.gmatch(string.lower(text or ""), "[%w]+") do
		if #w >= 2 then out[#out + 1] = w end
	end
	return out
end

-- Returns storyboards sorted by score (share of query words found, 0..1).
function P.Search(text)
	local q = words(text)
	if #q == 0 then return {} end

	local out = {}
	for _, sb in ipairs(P.All()) do
		local hits = 0
		for _, w in ipairs(q) do
			if string.find(sb.haystack, w, 1, true) then hits = hits + 1 end
		end
		if hits > 0 then
			sb.score = hits / #q
			out[#out + 1] = sb
		end
	end
	table.sort(out, function(a, b) return a.score > b.score end)
	return out
end

function P.Open(uuid)
	if P.Available() then Ponder.Open(uuid) end
end
