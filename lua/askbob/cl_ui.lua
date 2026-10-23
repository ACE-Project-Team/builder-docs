-- The Ask Bob panel: chip bar + search box, then home / results / article views.
-- Used both as a spawnmenu tab and inside the standalone window (AskBob.Open).
local C = AskBob.Colors
local API = AskBob.API

-- Below this top score, with no quick answer, Bob says he isn't sure.
local LOW_SCORE = 30
local DISCORD = "https://discord.gg/Y8aEYU6"

local function card(parent, opts)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:DockMargin(0, 0, 0, 6)
	p:DockPadding(12, 8, 10, 8)
	if opts.onClick then p:SetCursor("hand") end

	p.Paint = function(s, w, h)
		local hovered = opts.onClick and (s:IsHovered() or s:IsChildHovered())
		draw.RoundedBox(4, 0, 0, w, h, hovered and (opts.color or C.accent) or C.border)
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, hovered and C.hover or C.card)
		if opts.color then draw.RoundedBoxEx(4, 0, 0, 4, h, opts.color, true, false, true, false) end
	end

	local function add(text, font, color)
		if not text or text == "" then return end
		local lbl = AskBob.Label(p, text, font, color)
		lbl:SetMouseInputEnabled(false)
	end
	add(opts.title, "AskBob.Heading", opts.color or C.text)
	add(opts.subtitle, "AskBob.Small", C.muted)
	add(opts.body, "AskBob.Body", C.text)

	p.PerformLayout = function(s)
		local h = 0
		for _, child in ipairs(s:GetChildren()) do
			local _, y = child:GetPos()
			h = math.max(h, y + child:GetTall())
		end
		s:SetTall(h + 8)
	end
	p.OnMousePressed = function(_, code)
		if code == MOUSE_LEFT and opts.onClick then opts.onClick() end
	end
	return p
end
AskBob.Card = card

-- Text drawn straight over the game world (the spawnmenu tab is see-through, like Dupes).
-- Text drawn straight on the background: white over the world in the
-- spawnmenu, dark on the solid standalone window.
local function glass(parent, text, font)
	local p = parent
	while IsValid(p) and not p.IsAskBob do p = p:GetParent() end
	if IsValid(p) and p.Solid then return AskBob.Label(parent, text, font, C.text) end
	local lbl = AskBob.Label(parent, text, font, color_white)
	lbl:SetExpensiveShadow(2, Color(0, 0, 0, 230))
	return lbl
end

local CROSS = Material("icon16/cross.png")

-- A solid white sheet that grows with its children, for long text such as articles.
local function sheet(parent)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:DockPadding(14, 12, 14, 12)
	p.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, C.border)
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, C.card)
	end
	p.PerformLayout = function(s)
		local h = 0
		for _, child in ipairs(s:GetChildren()) do
			local _, y = child:GetPos()
			h = math.max(h, y + child:GetTall())
		end
		s:SetTall(h + 12)
	end
	return p
end

local function button(parent, text, icon, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText(text)
	if icon then b:SetIcon(icon) end
	b:SizeToContentsX(28)
	b:SetTall(24)
	b:Dock(LEFT)
	b:DockMargin(0, 0, 6, 0)
	b.DoClick = onClick
	return b
end

local function buttonRow(parent)
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:SetTall(24)
	row:DockMargin(0, 2, 0, 10)
	row:SetPaintBackground(false)
	return row
end

-- Search filters come from the website (/api/public/search-scopes), so they follow
-- whatever knowledge it actually holds. Until that answers, only ACE is offered.
local KNOWN = {
	filters = { { token = "ace", label = "ACE", kind = "ace" } },
	orgs = {},
}
local ICONS = { ace = "icon16/shield.png", library = "icon16/book.png" }

-- Content column never grows past this, so the layout stays centered on wide screens.
local MAX_WIDTH = 820

local function toggle(parent, text, icon, isOn, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText(text)
	if icon then b:SetIcon(icon) end
	b:SizeToContentsX(30)
	b:SetTall(24)
	b.Paint = function(s, w, h)
		local on = isOn()
		draw.RoundedBox(4, 0, 0, w, h, on and C.accent or (s:IsHovered() and C.accent or C.border))
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, on and C.accent or (s:IsHovered() and C.hover or C.card))
		s:SetTextColor(on and color_white or C.text)
	end
	b.DoClick = onClick
	return b
end

-- Panel ----------------------------------------------------------------------

local PANEL = {}

function PANEL:Init()
	self.IsAskBob = true
	self.Chips = {}
	self.Filters = {}
	self.RequestId = 0
	self:DockPadding(8, 8, 8, 8)

	self.ChipBar = vgui.Create("DPanel", self)
	self.ChipBar:Dock(TOP)
	self.ChipBar:SetTall(0)
	self.ChipBar:SetPaintBackground(false)

	local bar = vgui.Create("DPanel", self)
	bar:Dock(TOP)
	bar:SetTall(30)
	bar:DockMargin(0, 0, 0, 8)
	bar:SetPaintBackground(false)

	self.Go = vgui.Create("DButton", bar)
	self.Go:Dock(RIGHT)
	self.Go:SetWide(90)
	self.Go:SetText("Ask Bob")
	self.Go:SetIcon("icon16/magnifier.png")
	self.Go.DoClick = function() self:Search() end

	self.Home = vgui.Create("DButton", bar)
	self.Home:Dock(LEFT)
	self.Home:SetWide(30)
	self.Home:SetText("")
	self.Home:SetIcon("icon16/house.png")
	self.Home:SetTooltip("Home")
	self.Home.DoClick = function() self:ShowHome() end

	self.Entry = vgui.Create("DTextEntry", bar)
	self.Entry:Dock(FILL)
	self.Entry:DockMargin(4, 0, 4, 0)
	self.Entry:SetFont("AskBob.Body")
	self.Entry:SetPlaceholderText("Ask Bob anything, e.g. \"how do I make a hologram\"")
	self.Entry.OnEnter = function() self:Search() end

	-- Wraps onto a second row instead of running off the edge.
	self.FilterBar = vgui.Create("DIconLayout", self)
	self.FilterBar:Dock(TOP)
	self.FilterBar:DockMargin(0, 0, 0, 10)
	self.FilterBar:SetSpaceX(4)
	self.FilterBar:SetSpaceY(4)
	self:RebuildFilters()
	API.Scopes(function(ok, data)
		if not ok or not istable(data.filters) then return end
		KNOWN.filters = data.filters
		KNOWN.orgs = istable(data.orgs) and data.orgs or {}
		if IsValid(self) then self:RebuildFilters() end
	end)

	self.Body = vgui.Create("DScrollPanel", self)
	self.Body:Dock(FILL)

	self:ShowHome()
end

-- See-through in the spawnmenu; the standalone window sets Solid.
function PANEL:Paint(w, h)
	if self.Solid then draw.RoundedBox(0, 0, 0, w, h, C.bg) end
end

function PANEL:PerformLayout(w)
	local side = math.max(8, math.floor((w - MAX_WIDTH) / 2))
	local l, t, r, b = self:GetDockPadding()
	if l ~= side then self:DockPadding(side, t, side, b) end
end

-- Filters ----------------------------------------------------------------------

function PANEL:ToggleFilter(token)
	self.Filters[token] = not self.Filters[token] or nil
	self:RebuildFilters()
	if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
end

function PANEL:RebuildFilters()
	local bar = self.FilterBar
	bar:Clear()
	bar:InvalidateLayout()

	toggle(bar, "Everything", "icon16/world.png", function() return next(self.Filters) == nil end, function()
		self.Filters = {}
		self:RebuildFilters()
		if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
	end)

	local known = {}
	for _, f in ipairs(KNOWN.filters) do
		if isstring(f.token) and isstring(f.label) then
			known[f.token] = true
			toggle(bar, f.label, ICONS[f.kind] or ICONS.library, function() return self.Filters[f.token] end,
				function() self:ToggleFilter(f.token) end)
		end
	end

	-- Org wikis picked from the menu stay visible as their own toggles.
	local orgLabel = {}
	for _, o in ipairs(KNOWN.orgs) do orgLabel[o.token] = o.label end
	for token in SortedPairs(self.Filters) do
		if not known[token] then
			toggle(bar, orgLabel[token] or token, "icon16/group.png", function() return self.Filters[token] end,
				function() self:ToggleFilter(token) end)
		end
	end

	if #KNOWN.orgs == 0 then return end
	local org = vgui.Create("DButton", bar)
	org:SetText("Org wikis")
	org:SetIcon("icon16/group_add.png")
	org:SizeToContentsX(30)
	org:SetTall(24)
	org:SetTooltip("Search one organization's wiki")
	org.DoClick = function()
		local menu = DermaMenu()
		for _, o in ipairs(KNOWN.orgs) do
			if isstring(o.token) and isstring(o.label) then
				local opt = menu:AddOption(o.label, function() self:ToggleFilter(o.token) end)
				if self.Filters[o.token] then opt:SetIcon("icon16/tick.png") end
			end
		end
		menu:Open()
	end
end

-- Chips ------------------------------------------------------------------------

-- chip = { label = "...", query = "...", scope = "e2" (optional) }
function PANEL:AddChip(chip)
	for _, c in ipairs(self.Chips) do
		if c.label == chip.label then return end
	end
	self.Chips[#self.Chips + 1] = chip
	self:RebuildChips()
end

function PANEL:RemoveChip(index)
	table.remove(self.Chips, index)
	self:RebuildChips()
end

function PANEL:RebuildChips()
	self.ChipBar:Clear()
	self.ChipBar:SetTall(#self.Chips > 0 and 28 or 0)
	self.ChipBar:DockMargin(0, 0, 0, #self.Chips > 0 and 6 or 0)

	-- "Asking about" pill: what Bob will combine with the typed question.
	for i, chip in ipairs(self.Chips) do
		local b = vgui.Create("DButton", self.ChipBar)
		b:SetText(chip.label)
		b:SetTooltip("Bob will ask about this. Click to remove.")
		b:SetIcon(chip.icon or "icon16/brick.png")
		b:SizeToContentsX(52)
		b:Dock(LEFT)
		b:DockMargin(0, 0, 6, 0)
		b:SetTextInset(0, 0)
		b.Paint = function(s, w, h)
			local hov = s:IsHovered()
			draw.RoundedBox(h / 2, 0, 0, w, h, C.accent)
			draw.RoundedBox(h / 2, 1, 1, w - 2, h - 2, hov and C.hover or C.card)
			s:SetTextColor(C.text)
			surface.SetMaterial(CROSS)
			surface.SetDrawColor(255, 255, 255, hov and 255 or 140)
			surface.DrawTexturedRect(w - 22, h / 2 - 8, 16, 16)
		end
		b.DoClick = function() self:RemoveChip(i) end
	end
end

-- Views --------------------------------------------------------------------------

-- While a request is out the Ask button is locked, so one click = one request.
function PANEL:SetBusy(busy)
	self.Busy = busy
	self.Go:SetEnabled(not busy)
	self.Go:SetText(busy and "Asking..." or "Ask Bob")
end

-- White card with a spinner and a seconds counter, so a slow answer doesn't look broken.
function PANEL:Loading(body, text)
	self:SetBusy(true)
	local started = SysTime()
	local p = vgui.Create("DPanel", body)
	p:Dock(TOP)
	p:SetTall(44)
	p.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, C.border)
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, C.card)

		local t = SysTime() - started
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2 + t * 4
			local alpha = 40 + 215 * ((i / 8 + t * 4 / (math.pi * 2)) % 1)
			draw.RoundedBox(2, 22 + math.cos(a) * 9 - 2, h / 2 + math.sin(a) * 9 - 2, 4, 4,
				Color(C.accent.r, C.accent.g, C.accent.b, alpha))
		end

		local secs = math.floor(t)
		local line = text .. (secs > 0 and ("  " .. secs .. "s") or "")
		if t > 8 then line = line .. "  -  still waiting for " .. API.Base() end
		draw.SimpleText(line, "AskBob.Body", 44, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	return p
end

function PANEL:Clear()
	self.RequestId = self.RequestId + 1
	if self.Busy then self:SetBusy(false) end
	self.Body:Clear()
	self.Body:GetVBar():SetScroll(0)
	return self.Body
end

function PANEL:ShowHome()
	local body = self:Clear()

	local hi = glass(body, "Hi, I'm Bob.", "AskBob.Hero")
	hi:SetContentAlignment(5)
	hi:DockMargin(0, 24, 0, 4)
	local intro = glass(body, "Ask me about building, wiring, E2, Starfall and anything in the ACE wikis. "
		.. "I look things up on acegmod.com and show you the best page I can find.", "AskBob.Body")
	intro:SetContentAlignment(5)
	intro:DockMargin(40, 0, 40, 20)

	card(body, {
		title = "Tips",
		body = "•  Right-click any entity in the C menu and pick \"Ask Bob about this\".\n"
			.. "•  Use the buttons under the search box to only search one library or an org wiki.\n"
			.. "•  In the E2 or Starfall editor, select a function and press \"Ask Bob\".\n"
			.. "•  Chat: " .. table.concat(AskBob.SplitList(GetConVar("askbob_chat_triggers"):GetString()), " or ") .. " <question>",
	})

	local scope = GetConVar("askbob_scope"):GetString()
	if scope ~= "" then
		glass(body, "This server limits Bob to: " .. scope, "AskBob.Small"):DockMargin(0, 0, 0, 8)
	end

	local tutorials = AskBob.Ponder.All()
	if #tutorials > 0 then
		glass(body, "Tutorials you can watch", "AskBob.Heading"):DockMargin(0, 8, 0, 6)
		for _, sb in ipairs(tutorials) do
			card(body, {
				title = sb.title,
				subtitle = sb.addon .. "  ·  " .. sb.category,
				color = C.ponder,
				onClick = function() AskBob.Ponder.Open(sb.uuid) end,
			})
		end
	end
end

function PANEL:ShowError(message)
	local body = self:Clear()
	card(body, { title = "Hmm.", body = message, color = C.warn })
end

-- Opens a result: wiki pages are read in-game, everything else on the website.
function PANEL:OpenResult(url)
	local slug = API.WikiSlug(url)
	if slug then
		self:ShowArticle(slug, url)
	else
		gui.OpenURL(API.Absolute(url))
	end
end

function PANEL:ShowArticle(slug, url)
	local body = self:Clear()
	local id = self.RequestId
	local back = self.LastResults

	local row = buttonRow(body)
	if back then button(row, "Back", "icon16/arrow_left.png", function() self:RenderResults(unpack(back)) end) end
	button(row, "Open on website", "icon16/world_go.png", function() gui.OpenURL(API.Absolute(url)) end)

	local loading = self:Loading(body, "Bob is reading...")

	API.Article(slug, function(ok, article)
		if not IsValid(self) or self.RequestId ~= id then return end
		loading:Remove()
		self:SetBusy(false)
		if not ok then
			card(body, { title = "Hmm.", body = article, color = C.warn })
			return
		end

		body = sheet(body)
		AskBob.Label(body, article.title or slug, "AskBob.Title"):DockMargin(0, 0, 0, 2)
		local meta = {}
		if article.organization then meta[#meta + 1] = article.organization end
		if article.category then meta[#meta + 1] = article.category end
		if article.author then meta[#meta + 1] = "by " .. article.author end
		AskBob.Label(body, table.concat(meta, "  ·  "), "AskBob.Small", C.muted):DockMargin(0, 0, 0, 10)

		if article.body then
			AskBob.RenderText(body, article.body)
			if article.truncated then
				AskBob.Label(body, "This page is longer than Bob can show. Open it on the website for the rest.", "AskBob.Small", C.muted)
			end
		else
			AskBob.Label(body, "This page can only be read on the website.", "AskBob.Body", C.muted)
		end
	end)
end

-- Search ---------------------------------------------------------------------

function PANEL:SetQuery(text)
	self.Entry:SetValue(text or "")
end

function PANEL:Search()
	if self.Busy then return end
	local text = string.Trim(self.Entry:GetValue() or "")

	-- "+sf draw line" → scope token "sf", query "draw line".
	local scope = AskBob.SplitList(GetConVar("askbob_scope"):GetString())
	text = string.gsub(text, "%+(%w+)", function(token)
		scope[#scope + 1] = token:lower()
		return ""
	end)

	for token in pairs(self.Filters) do scope[#scope + 1] = token end

	local parts = { string.Trim(text) }
	for _, chip in ipairs(self.Chips) do
		parts[#parts + 1] = chip.query
		if chip.scope then scope[#scope + 1] = chip.scope end
	end
	local query = string.Trim(table.concat(parts, " "))

	if #query < 2 then
		self:ShowHome()
		return
	end

	local body = self:Clear()
	local id = self.RequestId
	self:Loading(body, "Bob is looking...")

	local ponder = AskBob.Ponder.Search(query)
	local scopeStr = table.concat(AskBob.SplitList(table.concat(scope, ",")), ",")

	API.Search(query, { scope = scopeStr }, function(ok, data)
		if not IsValid(self) or self.RequestId ~= id then return end
		self:RenderResults(query, ok, data, ponder)
	end)
end

function PANEL:RenderResults(query, ok, data, ponder)
	self.LastResults = { query, ok, data, ponder }
	local body = self:Clear()

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

	if not ok then
		card(body, { title = "Hmm.", body = data, color = C.warn })
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
		local kind = string.upper(string.sub(r.type or "", 1, 1)) .. string.sub(r.type or "", 2)
		local sub = kind
		if r.meta and r.meta ~= "" and string.lower(r.meta) ~= string.lower(kind) then sub = sub .. "  ·  " .. r.meta end
		return card(body, {
			title = r.title,
			subtitle = sub,
			body = r.description,
			onClick = function() self:OpenResult(r.url) end,
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

vgui.Register("AskBobPanel", PANEL, "DPanel")

-- Standalone window ------------------------------------------------------------

-- AskBob.Open("how do I wire", { chip, ... }) — used by chat, C menu, editors, key.
function AskBob.Open(query, chips)
	local frame = AskBob.Frame
	if not IsValid(frame) then
		frame = vgui.Create("DFrame")
		frame:SetTitle("Ask Bob")
		frame:SetSize(math.min(760, ScrW() - 40), math.min(600, ScrH() - 40))
		frame:Center()
		frame:SetSizable(true)
		frame:SetDeleteOnClose(false)
		frame.Bob = vgui.Create("AskBobPanel", frame)
		frame.Bob:Dock(FILL)
		frame.Bob.Solid = true
		frame.Bob:ShowHome() -- redraw with dark text now that it is solid
		AskBob.Frame = frame
	end

	frame:SetVisible(true)
	frame:MakePopup()

	local bob = frame.Bob
	if chips then
		bob.Chips = {}
		for _, chip in ipairs(chips) do bob:AddChip(chip) end
		bob:RebuildChips()
	end
	if query then bob:SetQuery(query) end
	if (query and query ~= "") or (chips and #chips > 0) then
		bob:Search()
	end
	bob.Entry:RequestFocus()
	return bob
end

concommand.Add("askbob", function(_, _, _, argStr)
	AskBob.Open(argStr ~= "" and argStr or nil)
end, nil, "Open Ask Bob, optionally with a question.")

net.Receive("askbob_open", function()
	local q = net.ReadString()
	AskBob.Open(q ~= "" and q or nil)
end)
