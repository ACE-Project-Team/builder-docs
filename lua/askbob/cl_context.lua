-- Context chips: turn "this entity" or "this tool" into something to search
-- for, so players can ask "how do I reload" without knowing what the thing is
-- called. Only reads what the player can already see on their own client.

local function prettyClass(class)
	return (string.gsub(class, "_", " "))
end

function AskBob.ChipFromEntity(ent)
	if not IsValid(ent) then return nil end
	local class = ent:GetClass()

	local name
	local stored = scripted_ents.GetStored(class)
	if stored and stored.t and isstring(stored.t.PrintName) and stored.t.PrintName ~= "" then
		name = language.GetPhrase(stored.t.PrintName)
	elseif isstring(ent.PrintName) and ent.PrintName ~= "" then
		name = language.GetPhrase(ent.PrintName)
	end

	-- Props are all prop_physics; the model is the useful part.
	if class == "prop_physics" or class == "prop_dynamic" then
		name = string.match(ent:GetModel() or "", "([^/]+)%.mdl$") or "prop"
		return { label = name, query = "prop " .. name, icon = "icon16/brick.png" }
	end

	local scope
	if string.find(class, "expression2", 1, true) then scope = "e2" end
	if string.find(class, "starfall", 1, true) then scope = "sf" end

	local chip = {
		name = name,
		query = name or prettyClass(class),
		scope = scope,
		class = class,
		icon = "icon16/bricks.png",
		facts = {},
	}

	-- Addons fill in what only they know: the real name, their wiki scope, stats.
	-- See README "For addon developers". A hook returning false hides the chip.
	if hook.Run("AskBob.Describe", ent, chip) == false then return nil end

	chip.label = chip.label or (chip.name and (chip.name .. "  ·  " .. class) or class)
	if #chip.facts == 0 then chip.facts = nil end
	return chip
end

function AskBob.ChipFromTool()
	local ply = LocalPlayer()
	local wep = IsValid(ply) and ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return nil end
	local tool = ply:GetTool()
	if not tool then return nil end

	local mode = tool.Mode or "tool"
	local name = isstring(tool.Name) and language.GetPhrase(tool.Name) or mode
	return { label = name .. " tool", query = name .. " tool", icon = "icon16/wrench.png" }
end

-- Plugins for addons supported out of the box. Each one only uses the public
-- hook above, exactly like a third-party addon would.
for _, f in ipairs(file.Find("askbob/plugins/*.lua", "LUA")) do
	include("askbob/plugins/" .. f)
end

-- C menu (right-click an entity) ----------------------------------------------

properties.Add("askbob", {
	MenuLabel = "Look this up",
	MenuIcon = "icon16/help.png",
	Order = 2000,
	Filter = function(_, ent)
		return IsValid(ent) and not ent:IsPlayer()
	end,
	Action = function(_, ent)
		local chip = AskBob.ChipFromEntity(ent)
		AskBob.Open(nil, chip and { chip } or nil)
	end,
})

-- "What is this?" key ----------------------------------------------------------

local function whatIsThis()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local chip = AskBob.ChipFromEntity(ply:GetEyeTrace().Entity) or AskBob.ChipFromTool()
	AskBob.Open(nil, chip and { chip } or nil)
end

concommand.Add("askbob_whatisthis", whatIsThis, nil, "Look up what you are looking at.")

local wasDown = false
hook.Add("Think", "AskBob.Key", function()
	local key = GetConVar("askbob_key"):GetInt()
	if key <= 0 then return end

	local down = input.IsButtonDown(key)
	if down and not wasDown and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
		whatIsThis()
	end
	wasDown = down
end)
