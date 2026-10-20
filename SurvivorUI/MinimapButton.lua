-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a square button outside the minimap's bottom left corner, with
-- the addon's own icon in the class's color (Art\SurvivorIconWhite.tga,
-- tinted), that opens the options (each tab's pieces movable while it is
-- open); a right click moves the whole UI (the grid laid out, every piece
-- unlocked). Over it, Run History's, in the same square: an hourglass. Other
-- minimap buttons stack over them, upward, in the same square look: the
-- game's battleground button (the crossed swords).

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIconWhite"
local SIZE = 16              -- the stock 22, smaller
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }   -- the addon's own color, the class's

-- A square, flat frame around an icon: a black edge, the addon's color under
-- the mouse.
local function Square(frame, icon)
	frame:SetWidth(SIZE)
	frame:SetHeight(SIZE)
	if not frame.squareEdge then
		frame.squareEdge = frame:CreateTexture(nil, "BACKGROUND")
		frame.squareEdge:SetTexture(FLAT)
		frame.squareEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
		frame.squareEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
		frame.squareEdge:SetVertexColor(0, 0, 0, 1)
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(frame)
		-- A game icon has a rim to crop; ours is drawn to the edge.
		if icon ~= frame.ownIcon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	end
end

local function Lit(frame, lit)
	if frame.squareEdge then
		if lit then
			frame.squareEdge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		else
			frame.squareEdge:SetVertexColor(0, 0, 0, 1)
		end
	end
end

------------------------------------------------------------------------------
-- Ours.

local button = CreateFrame("Button", "SurvivorUIMinimapButton", Minimap or UIParent)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
-- Outside the minimap, its bottom left corner; the stack grows upward. Moved
-- (the Frames & bar tab, or Move UI), it keeps its place against the minimap's
-- middle, so it follows the minimap.
local function PlaceButton()
	button:ClearAllPoints()
	local db = SurvivorUIDB
	if Minimap and db and db.mapButtonX and db.mapButtonY then
		button:SetPoint("CENTER", Minimap, "CENTER", db.mapButtonX, db.mapButtonY)
	elseif Minimap then
		button:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -5, 0)
	else
		button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
	end
end
PlaceButton()
button:SetMovable(true)

local function SaveButton()
	local x, y = button:GetCenter()
	local mx, my
	if Minimap then
		mx, my = Minimap:GetCenter()
	end
	if not (x and mx) then
		return
	end
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.mapButtonX = math.floor(x - mx + 0.5)
	SurvivorUIDB.mapButtonY = math.floor(y - my + 0.5)
	PlaceButton()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(button, "Minimap button", SaveButton, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.mapButtonX, SurvivorUIDB.mapButtonY = nil, nil
		end
		PlaceButton()
	end)
end
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(ICON)
button.ownIcon = button.icon
Square(button, button.icon)
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function() button.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
end

button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetScript("OnClick", function()
	local options = getglobal("SurvivorUIOptions")
	local mini = getglobal("SurvivorUIOptionsMini")
	if mini and mini:IsShown() and arg1 ~= "RightButton" then
		SurvivorUI_ToggleOptions()
	elseif options and options:IsShown() then
		options:Hide()
	elseif arg1 == "RightButton" then
		if SurvivorUI_OpenOptionsMoving then
			SurvivorUI_OpenOptionsMoving()
		end
	elseif SurvivorUI_ToggleOptions then
		SurvivorUI_ToggleOptions()
	end
end)
button:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Survivor UI", ACCENT[1], ACCENT[2], ACCENT[3])
	GameTooltip:AddLine("Click: options", 1, 1, 1)
	GameTooltip:AddLine("Right click: move the whole UI", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- Run History's: the same square over ours, an hourglass in its frame
-- (Art\HistoryIconWhite, ours with the S taken out, tinted as ours); a click
-- opens Run History. Off with "Run History button" (the options' Minimap tab).

local historyButton = CreateFrame("Button", "SurvivorUIHistoryButton", Minimap or UIParent)
historyButton:SetFrameStrata("MEDIUM")
historyButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
historyButton:SetPoint("BOTTOM", button, "TOP", 0, 5)
historyButton.icon = historyButton:CreateTexture(nil, "ARTWORK")
historyButton.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\HistoryIconWhite")
historyButton.ownIcon = historyButton.icon
Square(historyButton, historyButton.icon)
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function() historyButton.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
end
historyButton:SetScript("OnClick", function()
	if SurvivorUI_ShowLastRuns then
		SurvivorUI_ShowLastRuns()
	end
end)
historyButton:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Run History", ACCENT[1], ACCENT[2], ACCENT[3])
	GameTooltip:AddLine("Click: your runs, each as it ended", 1, 1, 1)
	GameTooltip:Show()
end)
historyButton:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

-- Shown or not by its option; what stacks over it then sits over it.
local function HistoryShown()
	return not (SurvivorUIDB and SurvivorUIDB.historyMapButton == false)
end

-- The top of the stack: Run History's when it shows, else ours.
local function StackTop()
	return HistoryShown() and historyButton or button
end

------------------------------------------------------------------------------
-- The game's battleground button: square, beside ours. The stock code shows it
-- and hides it as queues come and go; only its look and place change.

local function RestyleBattlefield()
	local frame = getglobal("MiniMapBattlefieldFrame")
	if not frame then
		return
	end
	local border = getglobal("MiniMapBattlefieldBorder")
	if border then
		border:Hide()
		border:SetAlpha(0)
	end
	Square(frame, getglobal("MiniMapBattlefieldIcon"))
	-- Over ours (and Run History's), in the stack outside the minimap.
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", StackTop(), "TOP", 0, 5)
	if not frame.squareHooked then
		frame.squareHooked = true
		local stockEnter, stockLeave = frame:GetScript("OnEnter"), frame:GetScript("OnLeave")
		frame:SetScript("OnEnter", function()
			Lit(this, true)
			if stockEnter then
				stockEnter()
			end
		end)
		frame:SetScript("OnLeave", function()
			Lit(this, false)
			if stockLeave then
				stockLeave()
			end
		end)
	end
end

-- The stack laid out again: Run History's shown or not, the battleground's over
-- the top. For the options' Minimap tab too.
function SurvivorUI_PlaceMapButtons()
	if HistoryShown() then
		historyButton:Show()
	else
		historyButton:Hide()
	end
	RestyleBattlefield()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
loader:SetScript("OnEvent", function()
	PlaceButton()
	SurvivorUI_PlaceMapButtons()
end)

------------------------------------------------------------------------------
-- A note beside Run History's button as a run begins, when the last run kept
-- was won or went on in endless mode: "Last run summary is available!", and
-- the zone (green), its time (white) and the result (its color). The whole note is the result's box as Run
-- History has it (RunHistory.lua's), alive: its color, its breathing glow, its
-- sparks (Victory green, sparks rising and a shine; Endless purple, sparks
-- circling). Level with Run History's button at its foot. A click opens Run
-- History on it; it goes by itself after a while, and comes once for each
-- run kept.

local NOTICE_SECONDS = 25
-- Each result's word color: its box's edge.
local RESULT_COLORS = { victory = { 0.62, 1.00, 0.66 }, endless = { 0.86, 0.66, 1.00 }, left = { 0.62, 0.82, 1.00 },
	dead = { 1.00, 0.55, 0.48 } }
local RESULT_WORDS = { victory = "VICTORY", endless = "ENDLESS", left = "LEFT", dead = "FALLEN" }
-- The results that bring the note (an endless run's always does).
local NOTICE_RESULTS = { victory = true }

local notice = CreateFrame("Button", "SurvivorUIHistoryNotice", UIParent)
notice:SetFrameStrata("HIGH")
notice:SetWidth(120)
notice:SetHeight(32)
notice:Hide()

-- The box and the words over it, made the first time: the box is Run
-- History's, which loads after this file.
local function NoticeParts()
	if notice.face then
		return
	end
	if SurvivorUI_ResultBadge then
		notice.look = SurvivorUI_ResultBadge(notice)
		notice.look:SetAllPoints(notice)
		notice.look.text:Hide()
		notice.look.time:Hide()
	else
		notice:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		notice:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
	end
	local face = CreateFrame("Frame", nil, notice)
	face:SetAllPoints(notice)
	face:SetFrameLevel(notice:GetFrameLevel() + 10)
	notice.face = face
	notice.title = face:CreateFontString(nil, "OVERLAY")
	notice.title:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	notice.title:SetPoint("TOPLEFT", face, "TOPLEFT", 7, -5)
	notice.title:SetTextColor(1, 1, 1)
	notice.title:SetText("Last run summary is available!")
	notice.line = face:CreateFontString(nil, "OVERLAY")
	notice.line:SetFont(SurvivorUI_FONT, 7 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	notice.line:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -3)
	notice.line:SetTextColor(0.95, 0.95, 1)
	local close = CreateFrame("Button", nil, face)
	close:SetWidth(12)
	close:SetHeight(12)
	close:SetPoint("TOPRIGHT", face, "TOPRIGHT", -1, -1)
	close.text = close:CreateFontString(nil, "OVERLAY")
	close.text:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.text:SetText("x")
	close.text:SetTextColor(0.85, 0.85, 0.9)
	close:SetScript("OnClick", function() notice:Hide() end)
	close:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	close:SetScript("OnLeave", function() this.text:SetTextColor(0.85, 0.85, 0.9) end)
end

notice:SetScript("OnClick", function()
	this:Hide()
	local history = getglobal("SurvivorUILastRuns")
	if SurvivorUI_ShowLastRuns and not (history and history:IsShown()) then
		SurvivorUI_ShowLastRuns()
	end
end)
-- Under the mouse the box glows brighter, as Run History's does.
notice:SetScript("OnEnter", function()
	if this.look then
		this.look.hot = true
	end
end)
notice:SetScript("OnLeave", function()
	if this.look then
		this.look.hot = nil
	end
end)
-- In over a third of a second, out the same way after its time.
notice:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local left = NOTICE_SECONDS - this.age
	if left <= 0 then
		this:Hide()
	else
		this:SetAlpha(math.min(1, this.age * 3, left * 3))
	end
end)

local function MinSec(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

-- The note for the newest run kept, when it was won or went endless: once
-- each (or always, asked by hand: /script SurvivorUI_HistoryNotice(true)).
-- A look of a result to see it in (victory, endless, left, dead): with the
-- newest run's zone and time, the run not marked as seen.
function SurvivorUI_HistoryNotice(force, look)
	local run = SurvivorUI_NewestRun and SurvivorUI_NewestRun()
	if not run then
		return
	end
	local kind = look or (run.endless and "endless" or (NOTICE_RESULTS[run.result] and run.result or nil))
	SurvivorUIDB = SurvivorUIDB or {}
	if not kind or not RESULT_WORDS[kind] or (not force and SurvivorUIDB.historyNoticed == run.at) then
		return
	end
	if not look then
		SurvivorUIDB.historyNoticed = run.at
	end
	NoticeParts()
	local color = RESULT_COLORS[kind]
	local seconds = kind == "endless" and run.endless and run.endless.time or run.time
	if notice.look then
		SurvivorUI_SetResultBadge(notice.look, kind, nil)
	end
	-- "Elwynn Forest 20:50 - ENDLESS": the zone green, the time white, the result its color.
	notice.line:SetText(string.format("|cff4dff70%s|r  |cffffffff%s|r  -  |cff%02x%02x%02x%s|r",
		run.zone or "", MinSec(seconds),
		math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), RESULT_WORDS[kind]))
	notice:SetWidth(math.max(notice.title:GetStringWidth() + 24, notice.line:GetStringWidth() + 16))
	-- Level with Run History's button at its foot, growing up: apart from ours.
	notice:ClearAllPoints()
	notice:SetPoint("BOTTOMRIGHT", StackTop(), "BOTTOMLEFT", -6, 0)
	notice.age = 0
	notice:SetAlpha(0)
	notice:Show()
end

-- As a run begins: playing, its clock in its first seconds, after no run.
local noticePhase
local noticeWatch = CreateFrame("Frame")
local noticeWait = 0
noticeWatch:SetScript("OnUpdate", function()
	noticeWait = noticeWait + arg1
	if noticeWait < 0.5 then
		return
	end
	noticeWait = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	local now = AZS_GetRunTime and AZS_GetRunTime()
	if phase == "playing" and noticePhase ~= "playing" and noticePhase ~= "choosing" and noticePhase ~= "paused"
		and now and now < 15 then
		SurvivorUI_HistoryNotice()
	end
	noticePhase = phase
end)
