-- Bob himself: the red speech bubble with two eyes, drawn live so he stays sharp
-- at any size and can react. Same geometry as the video's BobMark (100-unit grid):
-- a rounded square from 10 to 90 with radius 18, its bottom-left corner left sharp
-- as the bubble's tail, and two 8x22 pill eyes at x 50 +/- 11, y 50.
-- Only the Q-menu tab uses him; the standalone window and editors don't.

local RED = Color(200, 30, 30)
local EYE = Color(10, 6, 6)
local SHADOW = Color(0, 0, 0, 110)

-- How far the eyes may move from centre, in grid units.
local REACH = 9
-- A blink closes and reopens the eyes over this long; closed is 15% height.
local BLINK = 0.2

local function easeOut(p)
	p = math.Clamp(p, 0, 1)
	return 1 - (1 - p) ^ 3
end

local PANEL = {}

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self.Mood = "idle"
	self.Blinks = {}
	self.LookX, self.LookY = 0, 0
	self.Height, self.Drop = 1, 0
	local now = SysTime()
	self.Last = now
	self.NextBlink = now + math.Rand(1.5, 4)
	self.NextGlance = now + math.Rand(3, 7)
end

-- "idle", "think" (a search is out) or "unsure" (Bob found nothing good).
function PANEL:SetMood(mood)
	self.Mood = mood or "idle"
end

-- A quick double blink, for when an answer lands.
function PANEL:Happy()
	local now = SysTime()
	self.Blinks = { now, now + 0.24 }
end

-- 0 = open, 1 = closed, from the queued blink start times.
function PANEL:BlinkAmount(now)
	if now >= self.NextBlink then
		self.Blinks[#self.Blinks + 1] = now
		-- Now and then a double blink, like the avatar.
		if math.random() < 0.2 then self.Blinks[#self.Blinks + 1] = now + 0.25 end
		self.NextBlink = now + math.Rand(2.5, 6)
	end

	local amount = 0
	for i = #self.Blinks, 1, -1 do
		local e = now - self.Blinks[i]
		if e > BLINK then
			table.remove(self.Blinks, i)
		elseif e >= 0 then
			amount = math.max(amount, 1 - math.abs(e / (BLINK / 2) - 1))
		end
	end
	return amount
end

-- A glance out to one side: 0.2s out, a short hold, then eased back.
function PANEL:GlanceOffset(now)
	local g = self.Glance
	if not g then
		if now < self.NextGlance then return 0, 0 end
		g = { start = now, dir = math.random() < 0.5 and -1 or 1, hold = math.Rand(0.5, 1.1), y = math.random() < 0.4 and 4 or 0 }
		self.Glance = g
	end

	local e = now - g.start
	local a
	if e < 0.2 then
		a = easeOut(e / 0.2)
	elseif e < 0.2 + g.hold then
		a = 1
	else
		a = 1 - easeOut((e - 0.2 - g.hold) / 0.25)
		if a <= 0 then
			self.Glance = nil
			self.NextGlance = now + math.Rand(4, 9)
			return 0, 0
		end
	end
	return g.dir * REACH * a, g.y * a
end

-- Where the eyes want to be this frame, in grid units.
function PANEL:Target(now, size)
	if self.Mood == "think" then
		return 0, -3 + math.sin(now * 3.5) * 6
	end

	-- Cursor over the panel: follow it.
	local mx, my = self:LocalCursorPos()
	local w, h = self:GetSize()
	if mx >= 0 and my >= 0 and mx <= w and my <= h then
		local half = size / 2
		return math.Clamp((mx - w / 2) / half * REACH, -REACH, REACH),
			math.Clamp((my - h / 2) / half * REACH, -REACH, REACH)
	end

	local gx, gy = self:GlanceOffset(now)
	if self.Mood == "unsure" then gy = gy + 3 end
	return gx, gy
end

function PANEL:Paint(w, h)
	local now = SysTime()
	local size = math.min(w, h)
	local k = size / 100
	local ox, oy = (w - size) / 2, (h - size) / 2

	-- Ease toward the target; capped so a long pause doesn't snap.
	local dt = math.min(now - self.Last, 0.1)
	self.Last = now
	local f = 1 - math.exp(-dt * 14)
	local tx, ty = self:Target(now, size)
	local unsure = self.Mood == "unsure"
	self.LookX = self.LookX + (tx - self.LookX) * f
	self.LookY = self.LookY + (ty - self.LookY) * f
	-- Unsure: the eyes droop, shorter and lower.
	self.Height = self.Height + ((unsure and 0.6 or 1) - self.Height) * f
	self.Drop = self.Drop + ((unsure and 5 or 0) - self.Drop) * f

	local radius = math.Round(18 * k)
	if self.Shadow ~= false then
		local off = math.max(1, math.Round(3 * k))
		draw.RoundedBoxEx(radius, ox + 10 * k + off, oy + 10 * k + off, 80 * k, 80 * k, SHADOW, true, true, false, true)
	end
	draw.RoundedBoxEx(radius, ox + 10 * k, oy + 10 * k, 80 * k, 80 * k, RED, true, true, false, true)

	local eh = 22 * self.Height * (1 - 0.85 * self:BlinkAmount(now))
	local r = math.min(4, eh / 2) * k
	local ey = 50 + self.LookY + self.Drop - eh / 2
	for _, cx in ipairs({ 39, 61 }) do
		draw.RoundedBox(r, ox + (cx + self.LookX - 4) * k, oy + ey * k, 8 * k, eh * k, EYE)
	end
end

vgui.Register("AskBobMascot", PANEL, "DPanel")
