-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a square button outside the minimap's bottom left corner, with
-- the addon's own icon (Art\SurvivorIcon.tga), that opens the options with
-- configuration mode on (the grid laid out, every piece unlocked); right click
-- opens them without it. Other minimap buttons stack over it, upward, in the
-- same square look: the game's battleground button (the crossed swords).

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local SIZE = 16              -- the stock 22, smaller

-- A square, flat frame around an icon: a black edge, gold under the mouse.
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
			frame.squareEdge:SetVertexColor(1, 0.82, 0, 1)
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
-- Outside the minimap, its bottom left corner; the stack grows upward.
if Minimap then
	button:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -5, 0)
else
	button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
end
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(ICON)
button.ownIcon = button.icon
Square(button, button.icon)

button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetScript("OnClick", function()
	local options = getglobal("SurvivorUIOptions")
	if options and options:IsShown() then
		options:Hide()
	elseif arg1 == "RightButton" then
		if SurvivorUI_ToggleOptions then
			SurvivorUI_ToggleOptions()
		end
	elseif SurvivorUI_OpenOptionsMoving then
		SurvivorUI_OpenOptionsMoving()
	end
end)
button:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Survivor UI", 1, 0.82, 0)
	GameTooltip:AddLine("Click: options, with the grid to move things", 1, 1, 1)
	GameTooltip:AddLine("Right click: options only", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

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
	-- Over ours, in the stack outside the minimap.
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", button, "TOP", 0, 5)
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
loader:SetScript("OnEvent", RestyleBattlefield)
