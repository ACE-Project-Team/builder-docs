-- Reading a wiki page in-game, with a way back to the results.
local C = AskBob.Colors
local API = AskBob.API
local UI = AskBob.UI
local card, sheet, button, buttonRow = UI.Card, UI.Sheet, UI.Button, UI.ButtonRow

AskBob.BobPanel = AskBob.BobPanel or {}
local PANEL = AskBob.BobPanel

-- Opens a result: wiki pages are read in-game, everything else on the website.
function PANEL:OpenResult(url)
	local slug = API.WikiSlug(url)
	if slug then
		self:ShowArticle(slug, url)
	else
		gui.OpenURL(API.Absolute(url))
	end
end

function PANEL:ShowArticle(slug, url)
	local body = self:Clear()
	local id = self.RequestId
	local back = self.LastResults

	local row = buttonRow(body)
	if back then button(row, "Back", "icon16/arrow_left.png", function() self:RenderResults(unpack(back)) end) end
	button(row, "Open on website", "icon16/world_go.png", function() gui.OpenURL(API.Absolute(url)) end)

	local loading = self:Loading(body, "Loading page...")

	API.Article(slug, function(ok, article)
		if not IsValid(self) or self.RequestId ~= id then return end
		loading:Remove()
		self:SetBusy(false)
		if not ok then
			card(body, { title = "Something went wrong", body = article, color = C.warn })
			return
		end

		body = sheet(body)
		AskBob.Label(body, article.title or slug, "AskBob.Title"):DockMargin(0, 0, 0, 2)
		local meta = {}
		if article.organization then meta[#meta + 1] = article.organization end
		if article.category then meta[#meta + 1] = article.category end
		if article.author then meta[#meta + 1] = "by " .. article.author end
		AskBob.Label(body, table.concat(meta, "  ·  "), "AskBob.Small", C.muted):DockMargin(0, 0, 0, 10)

		if article.body then
			AskBob.RenderText(body, article.body, function(link) self:OpenResult(link) end)
			if article.truncated then
				AskBob.Label(body, "This page is too long to show here. Open it on the website for the rest.", "AskBob.Small", C.muted)
			end
		else
			AskBob.Label(body, "This page can only be read on the website.", "AskBob.Body", C.muted)
		end
	end)
end
