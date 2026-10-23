-- Building blocks shared by the Ask Bob panel files: cards, sheets, buttons and
-- the filter toggles. Exported on AskBob.UI.
local C = AskBob.Colors

local UI = {}
AskBob.UI = UI

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

local GRADIENT = Material("gui/gradient")
-- ACE's brand red (the website's --accent) and a deeper shade for the gradient.
local AI_TINT = Color(200, 30, 30)
local AI_DEEP = Color(120, 14, 14)

-- The AI toggle: a toggle with a slow light sweep every few seconds and a soft
-- red pulse on the edge; ACE red-to-dark fill when on. Different, not loud.
local function aiToggle(parent, isOn, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText("AI")
	b:SetIcon("icon16/wand.png")
	b:SizeToContentsX(30)
	b:SetTall(24)
	b:SetTooltip("Also ask an AI that reads the source code. Slower, and it can be wrong.")
	b.Paint = function(s, w, h)
		local on = isOn()
		local t = SysTime()
		local pulse = (math.sin(t * 2) + 1) / 2
		local edge = on and AI_TINT or Color(Lerp(pulse, C.border.r, AI_TINT.r),
			Lerp(pulse, C.border.g, AI_TINT.g), Lerp(pulse, C.border.b, AI_TINT.b))
		draw.RoundedBox(4, 0, 0, w, h, edge)
		draw.RoundedBox(4, 1, 1, w - 2, h - 2, on and AI_TINT or (s:IsHovered() and C.hover or C.card))
		if on then
			surface.SetMaterial(GRADIENT)
			surface.SetDrawColor(AI_DEEP.r, AI_DEEP.g, AI_DEEP.b, 255)
			-- gui/gradient fades out left to right; flip it so the dark red sits on the right.
			surface.DrawTexturedRectUV(1, 1, w - 2, h - 2, 1, 0, 0, 1)
		end

		-- A soft band crosses in 0.8s, then rests for the rest of 3s. Strips past
		-- either edge are skipped, not clamped: clamping stacked them into a bright
		-- box on the right edge as the band left.
		local phase = (t % 3) / 0.8
		if phase < 1 then
			local x = -16 + phase * (w + 32)
			for i = -6, 6 do
				local sx = math.floor(x + i * 2)
				if sx >= 2 and sx <= w - 4 then
					surface.SetDrawColor(255, 255, 255, (on and 70 or 45) * (1 - math.abs(i) / 7))
					surface.DrawRect(sx, 2, 2, h - 4)
				end
			end
		end
		s:SetTextColor(on and color_white or C.text)
	end
	b.DoClick = onClick
	return b
end

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

UI.Card, UI.Glass, UI.Sheet, UI.Button, UI.ButtonRow = card, glass, sheet, button, buttonRow
UI.Toggle, UI.AIToggle = toggle, aiToggle
UI.AI_TINT = AI_TINT
