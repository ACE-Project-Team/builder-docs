-- The results view: entity facts, Ponder matches, the AI card, the quick answer
-- and the result list.
local C = AskBob.Colors
local API = AskBob.API
local UI = AskBob.UI
local card, glass, sheet, button, buttonRow = UI.Card, UI.Glass, UI.Sheet, UI.Button, UI.ButtonRow
local AI_TINT = UI.AI_TINT

-- Below this top score, with no quick answer, Bob says he isn't sure.
local LOW_SCORE = 30
local DISCORD = "https://discord.gg/Y8aEYU6"
-- Result types whose name doesn't read well capitalised.
local TYPE_LABELS = { gmodwiki = "GMod wiki" }

AskBob.BobPanel = AskBob.BobPanel or {}
local PANEL = AskBob.BobPanel

-- Its own card, labelled as AI, so it is never mistaken for a written page.
function PANEL:AICard(body)
	local ai = self.AI
	local s = sheet(body)
	s:DockMargin(0, 0, 0, 10)
	local inner = s.Paint
	s.Paint = function(p, w, h)
		inner(p, w, h)
		draw.RoundedBoxEx(4, 0, 0, 4, h, AI_TINT, true, false, true, false)
	end

	AskBob.Label(s, "AI-GENERATED ANSWER", "AskBob.Small", AI_TINT)
	if ai.pending then
		local started = SysTime()
		local lbl = AskBob.Label(s, "The AI is reading the source code...", "AskBob.Body", C.muted)
		lbl.Think = function(l)
			local secs = math.floor(SysTime() - started)
			l:SetText("The AI is reading the source code..." .. (secs > 0 and ("  " .. secs .. "s") or ""))
		end
		return
	end
	local d = ai.data
	if not ai.ok or not istable(d) or not isstring(d.answer) then
		AskBob.Label(s, isstring(d) and d or "The AI couldn't answer that.", "AskBob.Body", C.muted)
		return
	end

	AskBob.Label(s, "Written by " .. tostring(d.answerer or "an AI") .. " from the " .. tostring(d.repo or d.label)
		.. " source code. It can be wrong, so check before you rely on it.", "AskBob.Small", C.muted)
		:DockMargin(0, 0, 0, 6)
	AskBob.RenderText(s, d.answer, function(url)
		if isstring(url) and string.match(url, "^https://") then gui.OpenURL(url) end
	end)
	-- Source link: only ever DeepWiki's own permalink.
	if isstring(d.sourceUrl) and string.match(d.sourceUrl, "^https://deepwiki%.com/") then
		local row = buttonRow(s)
		row:DockMargin(0, 6, 0, 0)
		button(row, "Open source", "icon16/world_go.png", function() gui.OpenURL(d.sourceUrl) end)
		AskBob.Label(row, "on deepwiki.com", "AskBob.Small", C.muted):Dock(FILL)
	end
end

function PANEL:FactsCard(body, chip)
	local s = sheet(body)
	s:DockMargin(0, 0, 0, 10)
	AskBob.Label(s, chip.name or chip.class, "AskBob.Title")
	AskBob.Label(s, chip.class, "AskBob.Small", C.muted):DockMargin(0, 0, 0, 6)
	if isstring(chip.description) and chip.description ~= "" then
		AskBob.Label(s, chip.description):DockMargin(0, 0, 0, 6)
	end
	for _, fact in ipairs(chip.facts or {}) do
		local row = vgui.Create("DPanel", s)
		row:Dock(TOP)
		row:SetTall(18)
		row:SetPaintBackground(false)
		local k = vgui.Create("DLabel", row)
		k:Dock(LEFT)
		k:SetWide(120)
		k:SetFont("AskBob.Body")
		k:SetTextColor(C.muted)
		k:SetText(tostring(fact[1]))
		local v = vgui.Create("DLabel", row)
		v:Dock(FILL)
		v:SetFont("AskBob.Body")
		v:SetTextColor(C.text)
		v:SetText(tostring(fact[2]))
	end
end

function PANEL:RenderResults(query, ok, data, ponder)
	self.LastResults = { query, ok, data, ponder }
	local body = self:Clear()

	-- What the entity is, straight from the addon: works even when the site is down.
	for _, chip in ipairs(self.Chips) do
		if chip.facts or chip.description then self:FactsCard(body, chip) end
	end

	-- Strong Ponder matches first: watching beats reading for a beginner.
	local weak, strong = {}, 0
	for _, sb in ipairs(ponder or {}) do
		if sb.score >= AskBob.Ponder.STRONG and strong < 2 then
			strong = strong + 1
			card(body, {
				title = "Show me: " .. sb.title,
				subtitle = "Tutorial  ·  " .. sb.addon .. "  ·  " .. sb.category,
				color = C.ponder,
				onClick = function() AskBob.Ponder.Open(sb.uuid) end,
			})
		else
			weak[#weak + 1] = sb
		end
	end

	if self.AI then self:AICard(body) end

	if not ok then
		card(body, { title = "Hmm.", body = data, color = C.warn })
		return
	end

	-- Small talk ("hi", "thanks", "help"): the site answers from the same table
	-- as the Discord bot, and there is nothing to search.
	if isstring(data.reply) and data.reply ~= "" then
		local s = sheet(body)
		s:DockMargin(0, 0, 0, 8)
		AskBob.Label(s, "BOB", "AskBob.Small", C.accent)
		AskBob.RenderText(s, data.reply)
		return
	end

	if data.scope and data.scope.unknown and #data.scope.unknown > 0 then
		glass(body, "Bob doesn't know the filter: " .. table.concat(data.scope.unknown, ", "), "AskBob.Small")
			:DockMargin(0, 0, 0, 6)
	end

	local qa = istable(data.quickAnswer) and data.quickAnswer or nil
	local results = data.results or {}
	local top = results[1] and tonumber(results[1].score) or 0

	-- Drop results that are the quick answer's own page, and repeats of the same page.
	local seen, list = {}, {}
	if qa and isstring(qa.sourceUrl) then seen[qa.sourceUrl] = true end
	for _, r in ipairs(results) do
		if isstring(r.url) and not seen[r.url] then
			seen[r.url] = true
			list[#list + 1] = r
		end
	end

	-- Nothing useful: lead with where a person can actually help.
	if not qa and (#list == 0 or top < LOW_SCORE) then
		self:BobMood("unsure")
		local s = sheet(body)
		s:DockMargin(0, 0, 0, 8)
		AskBob.Label(s, "Bob doesn't know this one yet.", "AskBob.Title", C.warn):DockMargin(0, 0, 0, 4)
		AskBob.Label(s, (istable(data.hint) and data.hint.text)
			or "Nobody has written a page about it. Someone on the ACE Discord probably knows, and once they "
			.. "answer, writing it down means the next player gets the answer from Bob.", "AskBob.Body", C.muted)
			:DockMargin(0, 0, 0, 10)
		local row = buttonRow(s)
		row:DockMargin(0, 0, 0, 0)
		button(row, "Ask on Discord", "icon16/comments.png", function() gui.OpenURL(DISCORD) end)
		button(row, "Write this page", "icon16/page_white_edit.png", function() gui.OpenURL(API.Base() .. "/wiki") end)
		button(row, "Search the website", "icon16/world.png", function()
			gui.OpenURL(API.Base() .. "/search?q=" .. API.urlencode(query))
		end)
		if #list > 0 then glass(body, "Closest matches, probably not what you want:", "AskBob.Small"):DockMargin(0, 4, 0, 6) end
	else
		glass(body, "Here's what Bob found for \"" .. query .. "\"", "AskBob.Heading"):DockMargin(0, 0, 0, 8)
	end

	if qa then
		if IsValid(self.MiniBob) then self.MiniBob:Happy() end
		local s = sheet(body)
		s:DockMargin(0, 0, 0, 10)
		local inner = s.Paint
		s.Paint = function(p, w, h)
			inner(p, w, h)
			draw.RoundedBoxEx(4, 0, 0, 4, h, C.accent, true, false, true, false)
		end
		AskBob.Label(s, "ANSWER", "AskBob.Small", C.accent)
		AskBob.Label(s, qa.heading, "AskBob.Title"):DockMargin(0, 0, 0, 4)
		AskBob.Label(s, qa.answer .. (qa.truncated and " ..." or ""), "AskBob.Body"):DockMargin(0, 0, 0, 8)
		local row = buttonRow(s)
		row:DockMargin(0, 0, 0, 0)
		button(row, "Read it here", "icon16/book_open.png", function() self:OpenResult(qa.sourceUrl) end)
		AskBob.Label(row, "from " .. tostring(qa.sourceTitle), "AskBob.Small", C.muted):Dock(FILL)
	end

	local function resultCard(r)
		local kind = TYPE_LABELS[r.type] or (string.upper(string.sub(r.type or "", 1, 1)) .. string.sub(r.type or "", 2))
		local sub = kind
		-- For GMod wiki hits the meta is the page kind: function, hook, enum, ...
		if isstring(r.meta) and r.meta ~= "" and string.lower(r.meta) ~= string.lower(kind) then sub = sub .. "  ·  " .. r.meta end
		return card(body, {
			title = r.title,
			subtitle = sub,
			body = r.description,
			onClick = function()
				-- gmodwiki.com pages can't be read in-game; they open in the Steam browser.
				if r.type == "gmodwiki" and isstring(r.url) and string.match(r.url, "^https://gmodwiki%.com/") then
					gui.OpenURL(r.url)
				else
					self:OpenResult(r.url)
				end
			end,
		})
	end

	-- The rest are built now but hidden, so "Show more" keeps them above the tutorials.
	local shown = qa and 3 or 4
	if #list > 0 and qa then glass(body, "More pages", "AskBob.Heading"):DockMargin(0, 4, 0, 6) end
	local hidden = {}
	for i, r in ipairs(list) do
		local c = resultCard(r)
		if i > shown then
			c:SetVisible(false)
			hidden[#hidden + 1] = c
		end
	end

	if #hidden > 0 then
		local more = vgui.Create("DButton", body)
		more:Dock(TOP)
		more:SetTall(26)
		more:DockMargin(0, 0, 0, 8)
		more:SetText("Show " .. #hidden .. " more")
		more:SetIcon("icon16/arrow_down.png")
		more.DoClick = function()
			for _, c in ipairs(hidden) do c:SetVisible(true) end
			more:Remove()
			body:InvalidateLayout()
		end
	end

	if #weak > 0 then
		glass(body, "Related tutorials", "AskBob.Heading"):DockMargin(0, 8, 0, 6)
		for i = 1, math.min(#weak, 5) do
			local sb = weak[i]
			card(body, {
				title = sb.title,
				subtitle = sb.addon .. "  ·  " .. sb.category,
				color = C.ponder,
				onClick = function() AskBob.Ponder.Open(sb.uuid) end,
			})
		end
	end
end
