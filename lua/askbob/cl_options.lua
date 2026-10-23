-- Q menu → Options → Utilities → Ask Bob: settings, how-to, contribute, donate.
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

local function buildSettings(cp)
	cp:Help("Ask Bob looks things up in the ACE wiki, organization wikis and docs, "
		.. "and shows installed Ponder tutorials.")
	local open = cp:Button("Open Ask Bob")
	open:SetIcon("icon16/help.png")
	open.DoClick = function() AskBob.Open() end

	cp:Help("")
	cp:Help("How to use")
	cp:ControlHelp("•  Type a question in the Ask Bob tab or window.\n"
		.. "•  C menu: right-click an entity → \"Ask Bob about this\".\n"
		.. "•  Press your Ask Bob key while looking at something.\n"
		.. "•  E2 / Starfall editor: select a function → \"Ask Bob\".\n"
		.. "•  Filters: +e2, +sf, +acf, +ace or an organization like +pac3.")

	cp:Help("")
	cp:Help("Your settings")
	cp:CheckBox("Show Ponder tutorials", "askbob_ponder")

	local binder = vgui.Create("DBinder", cp)
	binder:SetValue(GetConVar("askbob_key"):GetInt())
	binder.OnChange = function(_, key) RunConsoleCommand("askbob_key", tostring(key)) end
	cp:AddItem(Label("\"What is this?\" key"), binder)

	if LocalPlayer():IsSuperAdmin() then
		cp:Help("")
		cp:Help("Server settings")
		cp:ControlHelp("Chat commands that open Bob. Commands already used by ULX are skipped automatically.")
		adminSetting(cp, "Chat commands", "askbob_chat_triggers")
		cp:ControlHelp("Limit Bob to some wikis/libraries on this server (e.g. ace,sf). Empty = everything.")
		adminSetting(cp, "Default scope", "askbob_scope")
	end

	cp:Help("")
	cp:Help("Bob doesn't know something?")
	cp:ControlHelp("Everything Bob knows is written by players. If he couldn't answer you, "
		.. "the page probably doesn't exist yet. You can write it.")
	link(cp, "Write for the wiki", "icon16/page_white_edit.png", "/wiki")
	link(cp, "Organization wikis", "icon16/group.png", "/org")

	cp:Help("")
	cp:Help("Support ACE")
	cp:ControlHelp("ACE runs the website and the search Bob uses. Donations keep it online.")
	link(cp, "Donate", "icon16/heart.png", "/funding")

	cp:Help("")
	cp:Help("Privacy")
	cp:ControlHelp("Bob sends only your question to acegmod.com. Like any web request, the site sees your IP, "
		.. "but your SteamID, name and the server you are on are not sent, and questions are stored without "
		.. "who asked them. Bob only ever talks to acegmod.com, never to a server-chosen address, and pages "
		.. "are shown as text, never run as code.")
	cp:ControlHelp("Ask Bob v" .. AskBob.Version)
end

hook.Add("PopulateToolMenu", "AskBob.Options", function()
	spawnmenu.AddToolMenuOption("Utilities", "Ask Bob", "askbob_settings", "Ask Bob", "", "", buildSettings)
end)
