-- Built-in plugin for ACE (Armored Combat Extended). It uses only the public
-- AskBob.Describe hook, so it doubles as the reference for other addons.
--
-- ACE networks each entity's exact type as "WireName" ("120mm Cannon"), and its
-- definitions (ACF.Weapons.*) are shared, so the client can look up the stats
-- without asking the server anything.

local function round(n, places)
	local m = 10 ^ (places or 0)
	return math.floor(n * m + 0.5) / m
end

-- Gearboxes and engines only network their display name, so index by it.
local byName
local function lookupByName(name)
	if not byName then
		byName = {}
		local W = ACF and ACF.Weapons
		for _, list in ipairs({ W and W.Engines, W and W.Gearboxes }) do
			for _, def in pairs(list or {}) do
				if isstring(def.name) then byName[def.name] = def end
			end
		end
	end
	-- Scalable parts append their size: "CVT, Inline (size 1.00)".
	return byName[name] or byName[string.gsub(name, "%s*%(size [%d%.]+%)$", "")]
end

local DESCRIBE = {}

DESCRIBE.acf_gun = function(ent, chip, add)
	local def = ACF.Weapons.Guns and ACF.Weapons.Guns[ent:GetNWString("ID", "")]
	if def and def.caliber then add("Caliber", round(def.caliber * 10) .. " mm") end -- defined in cm
	if def and def.gunclass then add("Class", def.gunclass) end
	if def and def.magsize then add("Magazine", def.magsize .. " rounds") end
	if def then chip.description = def.desc end
	if def and def.weight then add("Mass", def.weight .. " kg") end
	local rof = ent:GetNWFloat("FireRate", 0)
	if rof > 0 then add("Rate of fire", round(rof, 1) .. " rpm") end
	local ammo = ent:GetNWString("Type", "")
	if ammo ~= "" then add("Loaded", ammo) end
end

DESCRIBE.acf_engine = function(_, chip, add)
	local def = lookupByName(chip.name or "")
	if not def then return end
	chip.description = def.desc
	if def.peakpower then add("Power", round(def.peakpower) .. " kW") end
	if def.torque then add("Torque", def.torque .. " Nm") end
	if def.idlerpm and def.limitrpm then add("RPM", def.idlerpm .. " to " .. def.limitrpm) end
	if def.fuel then add("Fuel", def.fuel) end
	if def.weight then add("Mass", def.weight .. " kg") end
end

DESCRIBE.acf_gearbox = function(_, chip, add)
	local def = lookupByName(chip.name or "")
	if not def then return end
	chip.description = def.desc
	if def.category then add("Type", def.category) end
	if def.gears then add("Gears", tostring(def.gears)) end
	if def.maxtq then add("Max torque", def.maxtq .. " Nm") end
	if def.weight then add("Mass", def.weight .. " kg") end
end

DESCRIBE.acf_ammo = function(ent, _, add)
	local ammo = ent:GetNWString("Ammo", "")
	if ammo ~= "" then add("Rounds", ammo) end
end

hook.Add("AskBob.Describe", "AskBob.ACE", function(ent, chip)
	local class = chip.class
	if not (string.match(class, "^acf_") or string.match(class, "^ace_")) then return end

	chip.scope = "ace"
	local wireName = ent:GetNWString("WireName", "")
	if wireName ~= "" then
		chip.name = wireName
		-- Search without the size suffix; no page is about "size 1.00".
		chip.query = string.gsub(wireName, "%s*%(size [%d%.]+%)$", "")
	end

	local fn = DESCRIBE[class]
	if fn and ACF and ACF.Weapons then
		-- Definitions vary between ACE versions; a missing field must never break the chip.
		pcall(fn, ent, chip, function(label, value)
			chip.facts[#chip.facts + 1] = { label, value }
		end)
	end
end)
