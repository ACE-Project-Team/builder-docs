-- "Search docs" buttons in the Expression 2, Starfall and PAC3 editors.
-- All three editors are other people's code, so every lookup is guarded: if an
-- internal changes, the button degrades to "open the search with the right filter"
-- instead of erroring inside their editor.

local LABEL = "Search docs"

local function trim(s)
	if not isstring(s) then return nil end
	s = string.Trim(s)
	if s == "" or #s > 120 then return nil end
	return s
end

-- Word under the caret in a Wire TextEditor panel.
local function wireCaretWord(ed)
	local ok, word = pcall(function()
		local caret = ed.Caret
		local row = ed.Rows and ed.Rows[caret[1]]
		if not isstring(row) then return nil end

		local col = caret[2]
		local before = string.match(string.sub(row, 1, col - 1), "[%w_%.:]*$") or ""
		local after = string.match(string.sub(row, col), "^[%w_]*") or ""
		return before .. after
	end)
	return ok and trim(word) or nil
end

local function wireSelection(ed)
	if not isfunction(ed.HasSelection) or not isfunction(ed.GetSelection) then return nil end
	local ok, sel = pcall(function() return ed:HasSelection() and ed:GetSelection() or nil end)
	return ok and trim(sel) or nil
end

local function textOf(panel)
	if not IsValid(panel) then return nil end
	local getter = panel.GetValue or panel.GetText
	if not isfunction(getter) then return nil end
	local ok, text = pcall(getter, panel)
	return ok and trim(text) or nil
end

-- One menu for both editors: selection, caret word, current error, or just open.
local HINT = {
	e2 = "Best for how-to questions the wiki covers, like \"how do I make a turret\". "
		.. "For what a single function does, E2Helper is quicker.",
	sf = "Best for how-to questions the wiki covers, like \"how do I draw a HUD\". "
		.. "For what a single function does, SFHelper is quicker.",
	pac3 = "Best for how-to questions the PAC3 wiki covers, like \"how do I make wings flap\". "
		.. "For what one part's settings do, PAC3's own part help (F1) is quicker.",
}

-- The editor's library becomes a filter, not a chip: a chip would search on its own.
local FILTER = { e2 = "wiremod", sf = "sf", pac3 = "pac3" }

-- "ents.Create", "hook.Add", "Entity:GetPos": GMod's Lua API capitalises members,
-- while E2 has no dots and Starfall's libraries are lowercase (render.drawRect).
local function looksLikeGmodApi(s)
	return isstring(s) and string.match(s, "^[%a_][%w_]*[%.:]%u[%w_]*$") ~= nil
end

local function openMenu(scope, selection, word, err)
	local filter = FILTER[scope]
	local function ask(q) AskBob.Open(q, nil, { filter = looksLikeGmodApi(q) and "gmod" or filter }) end
	local function plain() AskBob.Open("", nil, { filter = filter, hint = HINT[scope] }) end

	local menu = DermaMenu()
	local any = false
	if selection then
		any = true
		menu:AddOption("Ask about \"" .. selection .. "\"", function() ask(selection) end):SetIcon("icon16/text_allcaps.png")
	end
	if word and word ~= selection then
		any = true
		menu:AddOption("Ask about \"" .. word .. "\"", function() ask(word) end):SetIcon("icon16/text_allcaps.png")
	end
	if err then
		any = true
		-- Strip line/column noise; the message is what's searchable.
		local message = string.gsub(err, "[Ll]ine %d+,?%s*[Cc]har %d+:?", "")
		menu:AddOption("Ask about this error", function() ask(string.Trim(message)) end):SetIcon("icon16/error.png")
	end

	-- Nothing to offer but "open": skip the menu.
	if not any then return plain() end
	menu:AddOption("Just open the search", plain):SetIcon("icon16/help.png")
	menu:Open()
end

-- Expression 2 --------------------------------------------------------------------

local function addE2Button(editor)
	if not IsValid(editor) or not IsValid(editor.C and editor.C.Menu) or IsValid(editor.AskBobButton) then return end

	local b = vgui.Create("DButton", editor.C.Menu)
	b:SetText(LABEL)
	b:SetIcon("icon16/help.png")
	b:SetSize(100, 20)
	b:Dock(RIGHT)
	b:DockMargin(4, 0, 0, 0)
	b.DoClick = function()
		local ed = isfunction(editor.GetCurrentEditor) and editor:GetCurrentEditor()
		local selection = IsValid(ed) and wireSelection(ed) or nil
		local word = IsValid(ed) and wireCaretWord(ed) or nil

		-- The validation bar (Wire.IssueViewer) holds the last compile result;
		-- its idle and success texts are not errors.
		local err = textOf(editor.C.Val)
		if err then
			local lower = err:lower()
			if string.find(lower, "success", 1, true) or string.find(lower, "click to validate", 1, true) then
				err = nil
			end
		end

		openMenu("e2", selection, word, err)
	end
	editor.AskBobButton = b
end

hook.Add("WireEditorOpen", "AskBob.E2", function(editor)
	-- The bar is laid out on open; add after it settles.
	timer.Simple(0, function() addE2Button(editor) end)
end)

-- Starfall -------------------------------------------------------------------------

local function addSFButton()
	local editor = SF and SF.Editor and SF.Editor.editor
	if not IsValid(editor) or not IsValid(editor.C and editor.C.ButtonHolder) or IsValid(editor.AskBobButton) then return end

	local holder = editor.C.ButtonHolder
	-- Use SF's own button class so it matches SFHelper, and copy a sibling's
	-- height and margins instead of guessing them.
	local class = vgui.GetControlTable("StarfallButton") and "StarfallButton" or "DButton"
	local b = vgui.Create(class, holder)
	b:SetText(LABEL)
	local sibling
	for _, child in ipairs(holder:GetChildren()) do
		if child ~= b and IsValid(child) and child:IsVisible() then sibling = child break end
	end
	surface.SetFont(isfunction(b.GetFont) and b:GetFont() or "DermaDefault")
	local w = surface.GetTextSize(LABEL)
	b:SetSize(w + 20, IsValid(sibling) and sibling:GetTall() or 22)
	b:Dock(RIGHT)
	if IsValid(sibling) then b:DockMargin(sibling:GetDockMargin()) else b:DockMargin(4, 0, 0, 0) end

	-- The holder is a fixed 400px box anchored to the right edge that SF's own
	-- buttons already fill; widen it leftwards by our button so nothing squeezes.
	local bounds = holder.Bounds
	if istable(bounds) and isnumber(bounds.x) and isnumber(bounds.w) then
		local extra = b:GetWide() + 4
		bounds.x = bounds.x - extra
		bounds.w = bounds.w + extra
		editor:InvalidateLayout()
	end
	b.DoClick = function()
		local selection, word
		local tab = isfunction(editor.GetActiveTab) and editor:GetActiveTab()
		local content = IsValid(tab) and isfunction(tab.GetPanel) and tab:GetPanel()
		-- Only the classic (wire-style) tab exposes selection synchronously; the
		-- Monaco tab is a browser panel, so there Bob opens with the SF filter.
		if IsValid(content) then
			selection = wireSelection(content)
			word = wireCaretWord(content)
		end
		openMenu("sf", selection, word, nil)
	end
	editor.AskBobButton = b
end

hook.Add("StarfallEditorOpen", "AskBob.SF", function()
	timer.Simple(0, addSFButton)
end)

-- PAC3 -------------------------------------------------------------------------
-- PAC3 runs hook "pace_On<Event>" before its own pace.On<Event>, and a hook that
-- returns false cancels PAC's handler. So these hooks must never return a value.

-- "model2" / "entity2" are the current versions of model / entity.
local function pacClassName(part)
	return isstring(part.ClassName) and (string.gsub(part.ClassName, "%d+$", "")) or nil
end

-- Suggestions from the part selected in the editor tree, read when the menu opens.
local function pacSuggestions()
	local part = pace and pace.current_part
	local ok, valid = pcall(function() return part and part:IsValid() end)
	if not ok or not valid then return {} end

	local out = {}
	local class = pacClassName(part)
	if class then
		out[#out + 1] = { "Ask about the \"" .. class .. "\" part", class .. " part", "icon16/brick.png" }
	end
	if part.ClassName == "event" and isfunction(part.GetEvent) then
		local okEvent, event = pcall(part.GetEvent, part)
		event = okEvent and trim(event) or nil
		if event then
			out[#out + 1] = { "Ask about the \"" .. event .. "\" event", event .. " event", "icon16/clock.png" }
		end
	end
	return out
end

local function pacAsk(q)
	AskBob.Open(q, nil, { filter = FILTER.pac3, hint = q == "" and HINT.pac3 or nil, avoid = pace and pace.Editor })
end

-- Refilled every time it opens, so the suggestions follow the selected part.
local function fillPACMenu(menu)
	menu:Clear()
	for _, s in ipairs(pacSuggestions()) do
		menu:AddOption(s[1], function() pacAsk(s[2]) end):SetIcon(s[3])
	end
	menu:AddOption(LABEL .. "...", function() pacAsk("") end):SetIcon("icon16/magnifier.png")
end

-- PAC rebuilds its menu bar from scratch (removing every menu first), so add
-- ours after it has finished. The menu is our own DMenu, never one of PAC's.
hook.Add("pace_OnMenuBarPopulate", "AskBob.PAC3", function(bar)
	timer.Simple(0, function()
		if not IsValid(bar) or not isfunction(bar.AddMenu) or IsValid(bar.AskBobMenu) then return end
		local menu = bar:AddMenu("docs")
		if not IsValid(menu) then return end
		local open = menu.Open
		menu.Open = function(m, ...)
			fillPACMenu(m)
			return open(m, ...)
		end
		bar.AskBobMenu = menu
	end)
end)
