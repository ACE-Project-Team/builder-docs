-- The filter row under the search box, and which filter an AI question goes to.
local API = AskBob.API
local UI = AskBob.UI
local toggle, aiToggle = UI.Toggle, UI.AIToggle

AskBob.BobPanel = AskBob.BobPanel or {}
local PANEL = AskBob.BobPanel

-- Search filters come from the website (/api/public/search-scopes), so they follow
-- whatever knowledge it actually holds. Until that answers, only ACE is offered.
local KNOWN = {
	filters = { { token = "ace", label = "ACE", kind = "ace" } },
	orgs = {},
}
local ICONS = { ace = "icon16/shield.png", library = "icon16/book.png", org = "icon16/group.png", gmod = "icon16/script_code.png" }

-- Swaps the ACE-only default for the website's list once it answers.
function PANEL:LoadFilters()
	API.Scopes(function(ok, data)
		if not ok or not istable(data.filters) then return end
		KNOWN.filters = data.filters
		KNOWN.orgs = istable(data.orgs) and data.orgs or {}
		KNOWN.ai = data.ai == true
		if IsValid(self) then self:RebuildFilters() end
	end)
end

function PANEL:ToggleFilter(token)
	self.Filters[token] = not self.Filters[token] or nil
	self:RebuildFilters()
	if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
end

-- The one scope token an AI question would go to ("ace" with no filter), or nil
-- when the filters don't point at a single AI-enabled scope. DeepWiki reads one
-- repo, so two filters at once have no AI answer.
function PANEL:AIScope()
	if not KNOWN.ai then return nil end
	local tokens = table.GetKeys(self.Filters)
	if #tokens > 1 then return nil end
	local token = tokens[1] or "ace"
	for _, f in ipairs(KNOWN.filters) do
		if f.token == token then return f.ai == true and token or nil end
	end
	for _, o in ipairs(KNOWN.orgs) do
		if o.token == token then return o.ai == true and token or nil end
	end
	return nil
end

function PANEL:RebuildFilters()
	local bar = self.FilterBar
	bar:Clear()
	bar:InvalidateLayout()

	toggle(bar, "Everything", "icon16/world.png", function() return next(self.Filters) == nil end, function()
		self.Filters = {}
		self:RebuildFilters()
		if string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
	end)

	local known = {}
	for _, f in ipairs(KNOWN.filters) do
		if isstring(f.token) and isstring(f.label) then
			known[f.token] = true
			toggle(bar, f.label, ICONS[f.kind] or ICONS.library, function() return self.Filters[f.token] end,
				function() self:ToggleFilter(f.token) end)
		end
	end

	-- Wikis picked from the "Other" menu stay visible as their own toggles.
	local orgLabel = {}
	for _, o in ipairs(KNOWN.orgs) do orgLabel[o.token] = o.label end
	for token in SortedPairs(self.Filters) do
		if not known[token] then
			toggle(bar, orgLabel[token] or token, "icon16/group.png", function() return self.Filters[token] end,
				function() self:ToggleFilter(token) end)
		end
	end

	-- Only offered while the filters point at something with AI answers turned on.
	if self:AIScope() then
		aiToggle(bar, function() return self.AIMode end, function()
			self.AIMode = not self.AIMode or nil
			self:RebuildFilters()
			if self.AIMode and string.Trim(self.Entry:GetValue() or "") ~= "" then self:Search() end
		end)
	else
		self.AIMode = nil
	end

	if #KNOWN.orgs == 0 then return end
	local org = vgui.Create("DButton", bar)
	org:SetText("Other")
	org:SetIcon("icon16/group_add.png")
	org:SizeToContentsX(30)
	org:SetTall(24)
	org:SetTooltip("Search one organization's wiki")
	org.DoClick = function()
		local menu = DermaMenu()
		for _, o in ipairs(KNOWN.orgs) do
			if isstring(o.token) and isstring(o.label) then
				local opt = menu:AddOption(o.label, function() self:ToggleFilter(o.token) end)
				if self.Filters[o.token] then opt:SetIcon("icon16/tick.png") end
			end
		end
		menu:Open()
	end
end
