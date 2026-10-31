-- Q menu → Options → Utilities → (AskBob.Name): settings, how-to, contribute, donate.
local function link(cp, text, icon, path)
	local b = cp:Button(text)
	b:SetIcon(icon)
	b.DoClick = function() gui.OpenURL(AskBob.API.Base() .. path) end
	return b
end

local function adminSetting(cp, label, convar)
	local entry = cp:TextEntry(label)
	entry:SetValue(GetConVar(convar):GetString())
	local apply = cp:Button("Apply (superadmin)")
	apply.DoClick = function()
		net.Start("askbob_admin_set")
		net.WriteString(convar)
		net.WriteString(entry:GetValue())
		net.SendToServer()
	end
end

-- Bold section title with a gap above it; replaces blank Help("") spacers.
local function section(cp, title)
	local lbl = cp:Help(title)
	lbl:SetFont("DermaDefaultBold")
	lbl:DockMargin(0, 8, 0, 0)
	return lbl
end

local function buildSettings(cp)
	cp:Help("Searches the ACE wiki, partner org wikis and docs on acegmod.com, plus any Ponder tutorials you have installed. "
		.. "Results are pages written by players; nothing is generated unless you press AI.")
	local open = cp:Button("Open search")
	open:SetIcon("icon16/help.png")
	open.DoClick = function() AskBob.Open() end

	section(cp, "Ways to search")
	cp:Help("- The " .. AskBob.Name .. " tab in this menu\n"
		.. "- C menu: right-click an entity, \"Look this up\"\n"
		.. "- Your \"What is this?\" key while looking at something\n"
		.. "- The \"Search docs\" button in the E2, Starfall and PAC3 editors\n"
		.. "- Chat: " .. AskBob.ShownTriggers())

	section(cp, "Your settings")
	cp:CheckBox("Show Ponder tutorials", "askbob_ponder")
	local binder = vgui.Create("DBinder", cp)
	binder:SetValue(GetConVar("askbob_key"):GetInt())
	binder.OnChange = function(_, key) RunConsoleCommand("askbob_key", tostring(key)) end
	cp:AddItem(Label("\"What is this?\" key"), binder)

	if LocalPlayer():IsSuperAdmin() then
		section(cp, "Server settings")
		adminSetting(cp, "Chat commands", "askbob_chat_triggers")
		cp:ControlHelp("Comma separated. Commands ULX already uses are skipped.")
		adminSetting(cp, "Default filter", "askbob_scope")
		cp:ControlHelp("e.g. ace,sf. Empty searches everything.")
	end

	section(cp, "No good result?")
	cp:Help("Every page is written by players, so it may not exist yet.")
	link(cp, "Write for the wiki", "icon16/page_white_edit.png", "/wiki")
	link(cp, "Donate to ACE", "icon16/heart.png", "/funding")

	section(cp, "Privacy")
	cp:Help("Only your question is sent, to acegmod.com. No SteamID, name or server address, "
		.. "and answers are shown as text, never run.")
	cp:ControlHelp(AskBob.Name .. " v" .. AskBob.Version)
end

hook.Add("PopulateToolMenu", "AskBob.Options", function()
	spawnmenu.AddToolMenuOption("Utilities", AskBob.Name, "askbob_settings", AskBob.Name, "", "", buildSettings)
end)
