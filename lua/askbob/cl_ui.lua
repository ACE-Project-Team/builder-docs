-- The Ask Bob panel: chip bar + search box, then home / results / article views.
-- Used both as a spawnmenu tab and inside the standalone window (AskBob.Open).
-- The rest of its methods live in cl_ui_filters, cl_ui_reader and cl_ui_results,
-- which load first; this file registers the panel.
local C = AskBob.Colors
local API = AskBob.API
local UI = AskBob.UI
local card, glass = UI.Card, UI.Glass

-- Content column never grows past this, so the layout stays centered on wide screens.
local MAX_WIDTH = 820
-- Longest question /api/public/search accepts.
local MAX_QUERY = 200

local CROSS = Material("icon16/cross.png")

-- Panel ----------------------------------------------------------------------

AskBob.BobPanel = AskBob.BobPanel or {}
local PANEL = AskBob.BobPanel

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

	-- Far right: support ACE, the same /funding page as the Options panel's donate link.
	self.Heart = vgui.Create("DButton", bar)
	self.Heart:Dock(RIGHT)
	self.Heart:DockMargin(4, 0, 0, 0)
	self.Heart:SetWide(30)
	self.Heart:SetText("")
	self.Heart:SetIcon("icon16/heart.png")
	self.Heart:SetTooltip("Support ACE")
	self.Heart.DoClick = function() gui.OpenURL(API.Base() .. "/funding") end

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
	-- The site refuses questions over 200 characters; stop typing there.
	if isfunction(self.Entry.SetMaximumCharCount) then self.Entry:SetMaximumCharCount(MAX_QUERY) end

	-- Wraps onto a second row instead of running off the edge.
	self.FilterBar = vgui.Create("DIconLayout", self)
	self.FilterBar:Dock(TOP)
	self.FilterBar:DockMargin(0, 0, 0, 10)
	self.FilterBar:SetSpaceX(4)
	self.FilterBar:SetSpaceY(4)
	self:RebuildFilters()
	self:LoadFilters()

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
	self:BobMood(busy and "think" or "idle")
end

-- Bob the mascot, Q-menu tab only (the standalone window never calls this):
-- a big one greets on the home view, a small one sits by the search box elsewhere.
function PANEL:EnableMascot()
	self.MiniBob = vgui.Create("AskBobMascot", self.Home:GetParent())
	self.MiniBob:Dock(LEFT)
	self.MiniBob:DockMargin(0, 0, 4, 0)
	self.MiniBob:SetWide(32)
	self.MiniBob:MoveToBack()
	self:ShowHome()
end

function PANEL:BobMood(mood)
	if IsValid(self.MiniBob) then self.MiniBob:SetMood(mood) end
end

function PANEL:ShowMiniBob(show)
	if not IsValid(self.MiniBob) or self.MiniBob:IsVisible() == show then return end
	self.MiniBob:SetVisible(show)
	self.MiniBob:GetParent():InvalidateLayout()
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
	self.OnResults = nil
	if self.Busy then self:SetBusy(false) end
	self:BobMood("idle")
	self:ShowMiniBob(true)
	self.Body:Clear()
	self.Body:GetVBar():SetScroll(0)
	return self.Body
end

function PANEL:ShowHome(hint)
	local body = self:Clear()

	if hint then
		card(body, { title = "What to ask Bob", body = hint, color = C.accent })
	end

	local bob = IsValid(self.MiniBob)
	if bob then
		self:ShowMiniBob(false)
		local big = vgui.Create("AskBobMascot", body)
		big:Dock(TOP)
		big:SetTall(112)
		big:DockMargin(0, 16, 0, 0)
	end

	local hi = glass(body, "Hi, I'm Bob.", "AskBob.Hero")
	hi:SetContentAlignment(5)
	hi:DockMargin(0, bob and 4 or 24, 0, 4)
	local intro = glass(body, "Ask me about building, wiring, E2, Starfall and anything in the ACE wikis. "
		.. "I look things up on acegmod.com and show you the best page I can find.", "AskBob.Body")
	intro:SetContentAlignment(5)
	intro:DockMargin(40, 0, 40, 20)

	card(body, {
		title = "Tips",
		body = "•  Right-click any entity in the C menu and pick \"Ask Bob about this\".\n"
			.. "•  Use the buttons under the search box to only search one library or an org wiki.\n"
			.. "•  In the E2 or Starfall editor, press \"Ask Bob\" for how-to questions about your chip.\n"
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

-- Search ---------------------------------------------------------------------

function PANEL:SetQuery(text)
	self.Entry:SetValue(text or "")
end

function PANEL:Search()
	if self.Busy then return end
	local text = string.Trim(self.Entry:GetValue() or "")

	-- "+sf draw line" → scope token "sf", query "draw line".
	-- Typed "+ai" is a fallback for the AI button: same effect, only where AI is offered.
	local typedAI
	text = string.gsub(text, "%+[aA][iI]%f[%W]", function() typedAI = true return "" end)
	if typedAI then
		self.Entry:SetValue(string.Trim((string.gsub(self.Entry:GetValue() or "", "%+[aA][iI]%f[%W]", ""))))
		if self:AIScope() and not self.AIMode then
			self.AIMode = true
			self:RebuildFilters()
		end
	end

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
	-- A paste can still get past the box's limit, and chips add to the query.
	if #query > MAX_QUERY then
		self:RenderResults(query, false, "That's too long for Bob (" .. #query .. " characters, the limit is "
			.. MAX_QUERY .. "). Shorten it to the question itself, like \"how do I link ammo to a gun\".", {})
		return
	end

	local body = self:Clear()
	local id = self.RequestId
	self:Loading(body, "Bob is looking...")

	local ponder = AskBob.Ponder.Search(query)
	local scopeStr = table.concat(AskBob.SplitList(table.concat(scope, ",")), ",")

	-- AI runs alongside the index search; when it lands, the results redraw with it.
	self.AskSeq = (self.AskSeq or 0) + 1
	local seq = self.AskSeq
	local aiScope = self.AIMode and self:AIScope()
	self.AI = aiScope and { pending = true } or nil
	if aiScope then
		API.AskAI(query, aiScope ~= "ace" and aiScope or nil, function(ok, data)
			if not IsValid(self) or self.AskSeq ~= seq then return end
			self.AI = { ok = ok, data = data }
			-- Only redraw if the player is still looking at these results.
			if self.OnResults == seq then
				self:RenderResults(unpack(self.LastResults))
				self.OnResults = seq
			end
		end)
	end

	API.Search(query, { scope = scopeStr }, function(ok, data)
		if not IsValid(self) or self.RequestId ~= id then return end
		self:RenderResults(query, ok, data, ponder)
		self.OnResults = seq
	end)
end

vgui.Register("AskBobPanel", PANEL, "DPanel")

-- Standalone window ------------------------------------------------------------

-- AskBob.Open("how do I wire", { chip, ... }) — used by chat, C menu, editors, key.
-- opts: { filter = "wiremod", hint = "shown on the home view" }
function AskBob.Open(query, chips, opts)
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
		AskBob.Frame = frame
	end

	frame:SetVisible(true)
	frame:MakePopup()

	-- Each open is a fresh question: last time's text and chips would otherwise
	-- be searched again before the player has typed anything.
	local bob = frame.Bob
	opts = opts or {}
	bob.Chips = {}
	for _, chip in ipairs(chips or {}) do bob:AddChip(chip) end
	bob:RebuildChips()
	bob:SetQuery(query or "")
	if opts.filter then
		bob.Filters = { [opts.filter] = true }
		bob:RebuildFilters()
	end

	if (query and query ~= "") or (chips and #chips > 0) then
		bob:Search()
	else
		bob:ShowHome(opts.hint)
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
