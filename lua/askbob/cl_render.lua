-- Fonts, colours and a small plain-text/markdown renderer for article bodies.
-- Text only: headings, paragraphs, bullet lists and code blocks.

surface.CreateFont("AskBob.Hero", { font = "Roboto", size = 42, weight = 800 })
surface.CreateFont("AskBob.Title", { font = "Roboto", size = 22, weight = 700 })
surface.CreateFont("AskBob.H1", { font = "Roboto", size = 24, weight = 700 })
surface.CreateFont("AskBob.H2", { font = "Roboto", size = 20, weight = 700 })
surface.CreateFont("AskBob.Heading", { font = "Roboto", size = 18, weight = 700 })
-- Small text uses Tahoma (Derma's own font): Roboto at 13-15px renders thin
-- and runs letters together in GMod's rasterizer.
surface.CreateFont("AskBob.Link", { font = "Tahoma", size = 15, weight = 500, underline = true, extended = true })
surface.CreateFont("AskBob.Body", { font = "Tahoma", size = 15, weight = 500, extended = true })
surface.CreateFont("AskBob.Small", { font = "Tahoma", size = 13, weight = 500, extended = true })
surface.CreateFont("AskBob.Code", { font = "Consolas", size = 14, weight = 400 })

AskBob.Colors = {
	-- Matches the default Derma skin so Bob sits next to the Tools tab without clashing.
	bg      = Color(228, 228, 228), -- standalone window only; the tab is see-through
	card    = Color(255, 255, 255, 245),
	hover   = Color(229, 241, 255),
	border  = Color(190, 190, 190),
	accent  = Color(52, 132, 214),
	ponder  = Color(56, 150, 56),
	warn    = Color(205, 125, 20),
	text    = Color(40, 40, 40),
	muted   = Color(115, 115, 115),
	code    = Color(242, 242, 242),
}
local C = AskBob.Colors

function AskBob.Label(parent, text, font, color)
	local lbl = vgui.Create("DLabel", parent)
	lbl:SetFont(font or "AskBob.Body")
	lbl:SetTextColor(color or C.text)
	lbl:SetText(text or "")
	lbl:SetWrap(true)
	lbl:SetAutoStretchVertical(true)
	lbl:Dock(TOP)
	return lbl
end

local function codeBlock(parent, lines)
	local box = vgui.Create("DPanel", parent)
	box:Dock(TOP)
	box:DockMargin(0, 4, 0, 8)
	box:DockPadding(8, 6, 8, 6)
	box.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, C.code) end
	local lbl = AskBob.Label(box, table.concat(lines, "\n"), "AskBob.Code", C.text)
	lbl:SetWrap(false)
	lbl:SizeToContents()
	box.PerformLayout = function(self) self:SizeToChildren(false, true) end
	return box
end

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = "\"", apos = "'", nbsp = " " }

-- Plain text for a label: entities decoded, images dropped, [text](url) → text.
local function inline(s)
	s = string.gsub(s, "&#(%d+);", function(n)
		n = tonumber(n)
		return n and n < 128 and string.char(n) or ""
	end)
	s = string.gsub(s, "&(%a+);", function(name) return ENTITIES[name] end)
	s = string.gsub(s, "!%[[^%]]*%]%([^%)]*%)", "")
	-- The site writes <img alt> as "[image: alt]". Wiki type icons carry the
	-- type name ("Entity", "Vector"), so keep a short alt as text, drop the rest.
	s = string.gsub(s, "%[image:%s*([^%]]*)%]", function(alt)
		alt = string.Trim(alt)
		return (#alt > 0 and #alt <= 24 and not string.find(alt, "%s")) and alt or ""
	end)
	s = string.gsub(s, "%[([^%]]*)%]%([^%)]*%)", "%1")
	s = string.gsub(s, "%*%*(.-)%*%*", "%1")
	s = string.gsub(s, "`([^`]+)`", "%1")
	return string.Trim(s)
end

local HEADING_FONT = { "AskBob.H1", "AskBob.H2", "AskBob.Heading" }

-- Renders `text` into `parent` (expected to be a DScrollPanel canvas or panel).
-- onLink(url), when given, makes lines that are a single link clickable.
function AskBob.RenderText(parent, text, onLink)
	local paragraph, code, inCode = {}, {}, false

	local function flush()
		if #paragraph > 0 then
			local s = inline(table.concat(paragraph, " "))
			if s ~= "" then AskBob.Label(parent, s):DockMargin(0, 0, 0, 8) end
			paragraph = {}
		end
	end

	local function linkLine(label, url, indent)
		local lbl = AskBob.Label(parent, label, "AskBob.Link", C.accent)
		lbl:DockMargin(indent, 0, 0, 2)
		lbl:SetMouseInputEnabled(true)
		lbl:SetCursor("hand")
		lbl.DoClick = function() onLink(url) end
	end

	for line in string.gmatch((text or "") .. "\n", "([^\n]*)\n") do
		if string.match(line, "^%s*```") then
			if inCode then
				codeBlock(parent, code)
				code = {}
			else
				flush()
			end
			inCode = not inCode
		elseif inCode then
			code[#code + 1] = line
		else
			local hashes, heading = string.match(line, "^(#+)%s+(.+)$")
			local bullet = string.match(line, "^%s*[%-%*]%s+(.+)$")
			local onlyLink = onLink and string.match(line, "^%s*[%-%*]?%s*%[([^%]]+)%]%(([^%)]+)%)%s*$")
			if heading then
				flush()
				local font = HEADING_FONT[math.min(#hashes, 3)]
				AskBob.Label(parent, inline(heading), font):DockMargin(0, #hashes == 1 and 10 or 6, 0, 4)
			elseif onlyLink then
				flush()
				local label, url = string.match(line, "%[([^%]]+)%]%(([^%)]+)%)")
				linkLine((bullet and "•  " or "") .. inline(label), url, bullet and 8 or 0)
			elseif bullet then
				flush()
				local s = inline(bullet)
				if s ~= "" then AskBob.Label(parent, "•  " .. s):DockMargin(8, 0, 0, 2) end
			elseif string.match(line, "^%s*[%-%*_]+%s*$") then
				flush() -- lone "-" or a horizontal rule: nothing to show
			elseif string.Trim(line) == "" then
				flush()
			else
				paragraph[#paragraph + 1] = string.Trim(line)
			end
		end
	end
	if inCode and #code > 0 then codeBlock(parent, code) end
	flush()
end
