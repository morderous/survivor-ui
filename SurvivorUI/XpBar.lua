-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the experience, and how soon the next level comes.
--
-- The game shares the hero's level and experience in its run (AZS_RUN: lvl,
-- xp the experience into the level, xpn the level's whole). Their pace is
-- measured over the last WINDOW seconds of the run's own clock (t, which
-- stops while paused or choosing a card), the levels gained counted across,
-- and the time to the next level told from it once LEAST seconds are in: an
-- estimate that follows the run as the kills speed up or slow down.
--
-- Shown two ways, each on its own: at the run tracker's foot (Tracker.lua,
-- the time beside the level; Run tracker tab), and as an XP bar of its own,
-- movable (XP bar tab): the level, the bar with the experience and its share,
-- marked at every 20%, and under it the time to the next level and the
-- experience a minute. No backing: it sits on the world.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WINDOW = 45               -- seconds of the run the pace is measured over
local LEAST = 10                -- seconds of it before a pace is told
local PURPLE = { 0.58, 0.30, 0.85 }
local MUTED = "|cff9a9a9a"

------------------------------------------------------------------------------
-- The pace.

local samples = {}              -- { t = run time, gained = experience gained so far }
local last                      -- the run's last reading: t, lvl, xp, xpn
local gained = 0                -- experience gained this run, across its levels
local levelSince                -- the run time the current level began, once seen

local function Sample()
	local run = AZS_RUN
	if not run then
		return
	end
	local t, lvl, xp, xpn = tonumber(run.t), tonumber(run.lvl), tonumber(run.xp), tonumber(run.xpn)
	if not (t and lvl and xp) then
		return
	end
	-- A new run: its clock or its level went back.
	if last and (t < last.t or lvl < last.lvl) then
		samples, last, gained, levelSince = {}, nil, 0, nil
	end
	if last then
		if t == last.t and lvl == last.lvl and xp == last.xp then
			return
		end
		if lvl > last.lvl then
			-- What was left of the last level, and what is in the new one.
			gained = gained + math.max(0, (last.xpn or last.xp) - last.xp) + xp
			levelSince = t
		else
			gained = gained + math.max(0, xp - last.xp)
		end
	end
	last = { t = t, lvl = lvl, xp = xp, xpn = xpn }
	table.insert(samples, { t = t, gained = gained })
	-- The oldest kept is the last one past the window, so the span fills it.
	while samples[2] and t - samples[2].t >= WINDOW do
		table.remove(samples, 1)
	end
end

-- The run's experience now: lvl, xp, xpn, share (0 to 1), perMinute and eta
-- (seconds to the next level) once a pace is known, inLevel once a level up
-- was seen. Nil before the run tells any.
function SurvivorUI_XpEstimate()
	if not last then
		return nil
	end
	local estimate = { lvl = last.lvl, xp = last.xp, xpn = last.xpn }
	estimate.share = (last.xpn and last.xpn > 0) and math.min(1, last.xp / last.xpn) or 0
	local first = samples[1]
	local span = first and (last.t - first.t) or 0
	if span >= LEAST then
		local perSecond = (gained - first.gained) / span
		estimate.perMinute = perSecond * 60
		if perSecond > 0 and last.xpn then
			estimate.eta = math.max(0, last.xpn - last.xp) / perSecond
		end
	end
	if levelSince then
		estimate.inLevel = last.t - levelSince
	end
	return estimate
end

local function Clock(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 3600 then
		return math.floor(seconds / 3600).."h "..math.floor(math.mod(seconds, 3600) / 60).."m"
	end
	return math.floor(seconds / 60)..":"..string.format("%02d", math.mod(seconds, 60))
end

local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(math.floor(value + 0.5))
	end
	return tostring(math.floor(value + 0.5))
end

-- "next in 0:42", for the tracker's level line; "…" while the pace is young.
function SurvivorUI_XpNextText()
	local estimate = SurvivorUI_XpEstimate()
	if not estimate then
		return nil
	end
	if estimate.eta then
		return "next in "..Clock(estimate.eta)
	end
	return "next in ..."
end

local function Running()
	if not (AZS_GetPhase and AZS_RUN) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

------------------------------------------------------------------------------
-- The XP bar of its own (XP bar tab): on for a new install (v3.0.12), off
-- until chosen before.

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local WIDTH = 260

local panel = CreateFrame("Frame", "SurvivorUIXpBar", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(42)
panel:SetMovable(true)
panel:Hide()

local function Line(size, point)
	local text = panel:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, panel, point, 0, 0)
	return text
end

panel.level = Line(11, "TOPLEFT")
panel.amount = Line(10, "TOPRIGHT")

panel.track = panel:CreateTexture(nil, "BORDER")
panel.track:SetTexture(FLAT)
panel.track:SetVertexColor(0.12, 0.10, 0.16, 0.9)
panel.track:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -16)
panel.track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -16)
panel.track:SetHeight(8)

panel.fill = CreateFrame("StatusBar", nil, panel)
panel.fill:SetStatusBarTexture(FLAT)
panel.fill:SetStatusBarColor(PURPLE[1], PURPLE[2], PURPLE[3], 1)
panel.fill:SetMinMaxValues(0, 1)
panel.fill:SetAllPoints(panel.track)

-- A mark at every 20%, over the fill, so it reads past them too.
for step = 1, 4 do
	local mark = panel.fill:CreateTexture(nil, "OVERLAY")
	mark:SetTexture(FLAT)
	mark:SetVertexColor(0, 0, 0, 0.7)
	mark:SetWidth(1)
	mark:SetPoint("TOP", panel.fill, "TOPLEFT", WIDTH * step / 5, 0)
	mark:SetPoint("BOTTOM", panel.fill, "BOTTOMLEFT", WIDTH * step / 5, 0)
end

panel.next = Line(10, "BOTTOMLEFT")
panel.rate = Line(10, "BOTTOMRIGHT")

local function PanelOn()
	return Settings().xpBar == true
end

local function EtaOn()
	return Settings().xpBarEta ~= false
end

local function Fill()
	local estimate = SurvivorUI_XpEstimate()
	if not estimate then
		panel:Hide()
		return
	end
	-- The levels waiting (Store Level-Ups, LevelUp.lua): "Lv. 12 +3".
	local stored = SurvivorUI_StoredLevels and SurvivorUI_StoredLevels() or 0
	panel.level:SetText("|cffbf8cffLv. "..estimate.lvl.."|r"..(stored > 0 and " |cffffd100+"..stored.."|r" or ""))
	local amount = Short(estimate.xp)
	if estimate.xpn and estimate.xpn > 0 then
		amount = amount.." / "..Short(estimate.xpn).."  "..MUTED..math.floor(estimate.share * 100 + 0.5).."%|r"
	end
	panel.amount:SetText(amount)
	panel.fill:SetValue(estimate.share)
	if EtaOn() then
		if estimate.eta then
			panel.next:SetText(MUTED.."Next lv. in|r "..Clock(estimate.eta))
		else
			panel.next:SetText(MUTED.."Next lv. in ...|r")
		end
		panel.rate:SetText(estimate.perMinute and (Short(estimate.perMinute)..MUTED.." XP/min|r") or "")
		panel.next:Show()
		panel.rate:Show()
		panel:SetHeight(42)
	else
		panel.next:Hide()
		panel.rate:Hide()
		panel:SetHeight(26)
	end
	panel:Show()
end

-- The pace is measured all the run long, whatever shows it.
local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	if not Running() then
		panel:Hide()
		return
	end
	Sample()
	if PanelOn() then
		Fill()
	else
		panel:Hide()
	end
end)

function SurvivorUI_ToggleXpBar()
	local settings = Settings()
	settings.xpBar = not settings.xpBar
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the XP bar "..(settings.xpBar and "shows." or "is put away."))
end

-- Its place: the top of the screen, in the middle, until moved; once moved,
-- kept by the middle of its top.
local function DefaultPlace()
	panel:SetPoint("TOP", UIParent, "TOP", 0, -24)
end

local function RestorePlace()
	panel:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.xpBarX and db.xpBarTop then
		panel:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.xpBarX, db.xpBarTop)
	else
		DefaultPlace()
	end
end

local function SavePlace()
	local db = Settings()
	db.xpBarX = math.floor(panel:GetLeft() + panel:GetWidth() / 2 + 0.5)
	db.xpBarTop = math.floor(panel:GetTop() + 0.5)
	RestorePlace()
end

DefaultPlace()
if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(panel, "XP bar", SavePlace, nil, function()
		local db = Settings()
		db.xpBarX, db.xpBarTop = nil, nil
		RestorePlace()
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", RestorePlace)
