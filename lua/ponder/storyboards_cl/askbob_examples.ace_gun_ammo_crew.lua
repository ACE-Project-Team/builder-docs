-- Linking an ACE gun to its ammo and crew with the ACE Menu tool.
-- Named so Bob finds it for "link gun ammo crew", "loader", "gunner" etc.
local sb = Ponder.API.NewStoryboard("askbob_examples", "ace", "gun-ammo-crew")
sb:WithMenuName("Link a gun to ammo and crew")
sb:WithPlaybackName("ACE: link a gun to ammo and crew")
sb:WithModelIcon("models/tankgun/tankgun_75mm.mdl")
sb:WithDescription("Right-click the gun, then right-click the crate or crew seat, with the ACE Menu tool.")
sb:SetPrimaryLanguage("en")

local GUN, CRATE, LOADER, GUNNER = "gun", "crate", "loader", "gunner"
local LINKED = Color(80, 200, 120)

-- How long Ponder's Caption macro keeps a line up: reading time at 200 words a
-- minute plus 0.5s fades in and out. The macro doesn't hold the chapter's
-- clock, so without waiting this long the next caption lands on top of it.
local function captionTime(text)
	return #string.Explode(" ", text) / 200 * 60 + 1
end

local function caption(c, text)
	c:AddInstruction("Caption", { Text = text })
	c:AddDelay(captionTime(text))
end

-- One link: aim at the gun, right-click, aim at the target, right-click, flash both.
-- The caption stays up while the toolgun moves; the rest of its time is waited out after.
local LINK_TIME = 0.4 + 0.8 + 0.6
local function link(c, target, text)
	c:AddInstruction("Caption", { Text = text })
	c:AddInstruction("MoveToolgunTo", { Target = GUN, Length = 0.6 })
	c:AddInstruction("ClickToolgun", { Target = GUN })
	c:AddInstruction("AddHalo", { Target = GUN, Color = Color(255, 220, 0), Length = 0.2 })
	c:AddDelay(0.4)
	c:AddInstruction("MoveToolgunTo", { Target = target, Length = 0.8 })
	c:AddInstruction("ClickToolgun", { Target = target })
	c:AddInstruction("RemoveHalo", { Target = GUN, Length = 0.2 })
	c:AddInstruction("FlashModel", { Models = { GUN, target }, FillColor = LINKED, Length = 1, Reps = 2 })
	c:AddDelay(0.6)
	c:AddDelay(math.max(0.5, captionTime(text) - LINK_TIME))
end

-- 1. The parts
local c = sb:Chapter("The parts")
c:AddInstruction("MoveCameraLookAt", { Target = Vector(0, 0, 20), Distance = 900, Angle = 40, Height = 220, Length = 0 })
c:AddInstruction("FadeCameraIn", { Length = 0.5 })
c:AddInstruction("PlaceModel", { Name = GUN, Model = "models/tankgun/tankgun_75mm.mdl", Position = Vector(40, 0, 30) })
c:AddInstruction("PlaceModel", { Name = CRATE, Model = "models/ammocrate_small.mdl", Position = Vector(-60, 40, 10) })
c:AddInstruction("PlaceModel", { Name = LOADER, Model = "models/chairs_playerstart/standingpose.mdl", Position = Vector(-50, -40, 0), Angles = Angle(0, -90, 0) })
c:AddInstruction("PlaceModel", { Name = GUNNER, Model = "models/chairs_playerstart/sitpose.mdl", Position = Vector(0, -70, 0), Angles = Angle(0, -90, 0) })
caption(c, "A gun needs an ammo crate to fire. A loader and a gunner make it reload and aim better.")

-- 2. Ammo
c = sb:Chapter("Ammo")
c:AddInstruction("ShowToolgun", { Length = 0.4 })
link(c, CRATE, "With the ACE Menu tool, right-click the gun, then right-click the ammo crate.")
caption(c, "Link more crates the same way. The gun feeds from them in turn.")

-- 3. Crew
c = sb:Chapter("Crew")
link(c, LOADER, "Link a loader seat the same way. Its stamina shortens the reload.")
link(c, GUNNER, "Then the gunner seat.")
caption(c, "Crew seats must stay within about 200 units of the gun, or the link is dropped.")

-- 4. Unlinking
c = sb:Chapter("Unlinking")
caption(c, "To unlink, hold E on the second right-click. Press R to clear the selection.")
c:AddInstruction("HideToolgun", { Length = 0.4 })
