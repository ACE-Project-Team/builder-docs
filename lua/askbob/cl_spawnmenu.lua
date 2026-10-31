spawnmenu.AddCreationTab(AskBob.Name, function()
	local panel = vgui.Create("AskBobPanel")
	panel:EnableMascot()
	return panel
end, "icon16/help.png", 900, "Search the ACE and partner wikis and docs")
