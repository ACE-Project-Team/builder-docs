-- The Ask Bob panel: chip bar + search box, then home / results / article views.
-- Used both as a spawnmenu tab and inside the standalone window (AskBob.Open).
local C = AskBob.Colors
local API = AskBob.API

-- Below this top score, with no quick answer, Bob says he isn't sure.
local LOW_SCORE = 30

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

-- Search filters shown as toggles under the search box. None selected = everything.
local FILTERS = {
	{ token = "ace", label = "ACE",      icon = "icon16/shield.png" },
	{ token = "acf", label = "ACF",      icon = "icon16/bomb.png" },
	{ token = "e2",  label = "E2",       icon = "icon16/chip.png" },
	{ token = "sf",  label = "Starfall", icon = "icon16/star.png" },
	{ token = "tpg", label = "TPG",      icon = "icon16/flag_red.png" },
}

-- Content column never grows past this, so the layout stays centered on wide screens.
local MAX_WIDTH = 820

local function toggle(parent, text, icon, isOn, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText(text)
	if icon then b:SetIcon(icon) end
	b:SizeToContentsX(30)
	b:SetTall(24)
	b:Dock(LEFT)
	b:DockMargin(0, 0, 4, 0)
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

	self.FilterBar = vgui.Create("DPanel", self)
	self.FilterBar:Dock(TOP)
	self.FilterBar:SetTall(24)
	self.FilterBar:DockMargin(0, 0, 0, 10)
	self.FilterBar:SetPaintBackground(false)
	self:RebuildFilters()

	self.Body = vgui.Create("DScrollPanel", self)
	self.Body:Dock(FILL)

	self:ShowHome()
end

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, C.bg)
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

	toggle(bar, "Everything", "icon16/world.png", function() return next(self.Filters) == nil end, function()
		self.Filters = {}
		self:RebuildFilters()
		if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
	end)

	local known = {}
	for _, f in ipairs(FILTERS) do
		known[f.token] = true
		toggle(bar, f.label, f.icon, function() return self.Filters[f.token] end, function() self:ToggleFilter(f.token) end)
	end

	-- Org wikis picked through "Org wiki..." stay visible as their own toggles.
	for token in SortedPairs(self.Filters) do
		if not known[token] then
			toggle(bar, token, "icon16/group.png", function() return self.Filters[token] end, function() self:ToggleFilter(token) end)
		end
	end

	local org = vgui.Create("DButton", bar)
	org:SetText("Org wiki...")
	org:SetIcon("icon16/group_add.png")
	org:SizeToContentsX(30)
	org:Dock(LEFT)
	org:SetTooltip("Search one organization's wiki, e.g. pac3")
	org.DoClick = function()
		Derma_StringRequest("Ask Bob", "Organization name or short name (e.g. pac3):", "", function(text)
			local token = string.lower(string.Trim(text or ""))
			token = string.gsub(token, "[^%w%-_]", "")
			if token == "" then return end
			self.Filters[token] = true
			self:RebuildFilters()
			if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
		end)
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
	self.ChipBar:SetTall(#self.Chips > 0 and 26 or 0)
	self.ChipBar:DockMargin(0, 0, 0, #self.Chips > 0 and 6 or 0)

	for i, chip in ipairs(self.Chips) do
		local b = vgui.Create("DButton", self.ChipBar)
		b:SetText(chip.label .. "   x")
		b:SetTooltip("Bob will ask about this. Click to remove.")
		b:SetIcon(chip.icon or "icon16/brick.png")
		b:SizeToContentsX(30)
		b:Dock(LEFT)
		b:DockMargin(0, 0, 6, 0)
		b.DoClick = function() self:RemoveChip(i) end
	end
end

-- Views --------------------------------------------------------------------------

function PANEL:Clear()
	self.RequestId = self.RequestId + 1
	self.Body:Clear()
	self.Body:GetVBar():SetScroll(0)
	return self.Body
end

function PANEL:ShowHome()
	local body = self:Clear()

	local hi = AskBob.Label(body, "Hi, I'm Bob.", "AskBob.Title")
	hi:SetContentAlignment(5)
	hi:DockMargin(0, 24, 0, 4)
	local intro = AskBob.Label(body, "Ask me about building, wiring, E2, Starfall, ACF and anything in the ACE wikis. "
		.. "I look things up on acegmod.com and show you the best page I can find.", "AskBob.Body", C.muted)
	intro:SetContentAlignment(5)
	intro:DockMargin(40, 0, 40, 20)

	card(body, {
		title = "Tips",
		body = "•  Right-click any entity in the C menu and pick \"Ask Bob about this\".\n"
			.. "•  Use the buttons under the search box to only search E2, Starfall, ACF or an org wiki.\n"
			.. "•  In the E2 or Starfall editor, select a function and press \"Ask Bob\".\n"
			.. "•  Chat: " .. table.concat(AskBob.SplitList(GetConVar("askbob_chat_triggers"):GetString()), " or ") .. " <question>",
	})

	local scope = GetConVar("askbob_scope"):GetString()
	if scope ~= "" then
		AskBob.Label(body, "This server limits Bob to: " .. scope, "AskBob.Small", C.muted):DockMargin(0, 0, 0, 8)
	end

	local tutorials = AskBob.Ponder.All()
	if #tutorials > 0 then
		AskBob.Label(body, "Tutorials you can watch", "AskBob.Heading"):DockMargin(0, 8, 0, 6)
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

	local loading = AskBob.Label(body, "Bob is reading...", "AskBob.Body", C.muted)

	API.Article(slug, function(ok, article)
		if not IsValid(self) or self.RequestId ~= id then return end
		loading:Remove()
		if not ok then
			card(body, { title = "Hmm.", body = article, color = C.warn })
			return
		end

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
	AskBob.Label(body, "Bob is looking...", "AskBob.Body", C.muted)

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
		AskBob.Label(body, "Bob doesn't know the filter: " .. table.concat(data.scope.unknown, ", "), "AskBob.Small", C.warn)
			:DockMargin(0, 0, 0, 6)
	end

	local qa = data.quickAnswer
	if istable(qa) then
		card(body, {
			title = qa.heading,
			subtitle = "From " .. tostring(qa.sourceTitle),
			body = qa.answer .. (qa.truncated and " ..." or ""),
			color = C.accent,
			onClick = function() self:OpenResult(qa.sourceUrl) end,
		})
	end

	local results = data.results or {}
	local top = results[1] and tonumber(results[1].score) or 0

	if #results == 0 and not istable(qa) then
		card(body, {
			title = "Bob isn't sure.",
			body = (istable(data.hint) and data.hint.text) or "Nothing matched that question.",
			color = C.warn,
		})
		local row = buttonRow(body)
		button(row, "Search the website", "icon16/world.png", function()
			gui.OpenURL(API.Base() .. "/search?q=" .. API.urlencode(query))
		end)
		button(row, "Write this page", "icon16/page_white_edit.png", function() gui.OpenURL(API.Base() .. "/wiki") end)
	elseif not istable(qa) and top < LOW_SCORE then
		AskBob.Label(body, "Bob isn't sure these are right, but they're the closest he found.", "AskBob.Small", C.muted)
			:DockMargin(0, 0, 0, 6)
	end

	for _, r in ipairs(results) do
		local sub = string.upper(string.sub(r.type or "", 1, 1)) .. string.sub(r.type or "", 2)
		if r.meta and r.meta ~= "" then sub = sub .. "  ·  " .. r.meta end
		card(body, {
			title = r.title,
			subtitle = sub,
			body = r.description,
			onClick = function() self:OpenResult(r.url) end,
		})
	end

	if #weak > 0 then
		AskBob.Label(body, "Related tutorials", "AskBob.Heading"):DockMargin(0, 8, 0, 6)
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
