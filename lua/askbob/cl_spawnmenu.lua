spawnmenu.AddCreationTab("Ask Bob", function()
	local panel = vgui.Create("AskBobPanel")
	panel:EnableMascot()
	return panel
end, "icon16/help.png", 900, "Ask Bob about anything in the ACE wikis and docs")
