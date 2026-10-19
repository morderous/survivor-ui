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
