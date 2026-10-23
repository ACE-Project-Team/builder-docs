-- Fonts, colours and a small plain-text/markdown renderer for article bodies.
-- Text only: headings, paragraphs, bullet lists and code blocks.

surface.CreateFont("AskBob.Title", { font = "Roboto", size = 22, weight = 700 })
surface.CreateFont("AskBob.Heading", { font = "Roboto", size = 18, weight = 700 })
surface.CreateFont("AskBob.Body", { font = "Roboto", size = 15, weight = 400 })
surface.CreateFont("AskBob.Small", { font = "Roboto", size = 13, weight = 400 })
surface.CreateFont("AskBob.Code", { font = "Consolas", size = 14, weight = 400 })

AskBob.Colors = {
	bg      = Color(30, 32, 38),
	card    = Color(42, 45, 53),
	hover   = Color(52, 56, 66),
	accent  = Color(86, 156, 214),
	ponder  = Color(120, 190, 120),
	warn    = Color(225, 170, 70),
	text    = Color(235, 235, 240),
	muted   = Color(160, 165, 175),
	code    = Color(22, 23, 27),
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

-- Renders `text` into `parent` (expected to be a DScrollPanel canvas or panel).
function AskBob.RenderText(parent, text)
	local paragraph, code, inCode = {}, {}, false

	local function flush()
		if #paragraph > 0 then
			AskBob.Label(parent, table.concat(paragraph, " ")):DockMargin(0, 0, 0, 8)
			paragraph = {}
		end
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
			local heading = string.match(line, "^#+%s+(.+)$")
			local bullet = string.match(line, "^%s*[%-%*]%s+(.+)$")
			if heading then
				flush()
				AskBob.Label(parent, heading, "AskBob.Heading"):DockMargin(0, 6, 0, 4)
			elseif bullet then
				flush()
				AskBob.Label(parent, "•  " .. bullet):DockMargin(8, 0, 0, 2)
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
