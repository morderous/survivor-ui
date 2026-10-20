-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a thin white outline around whatever piece of the interface the
-- mouse is on, a button, a bar, a frame, so it is always clear what a click
-- or a tooltip belongs to. The world itself, the nameplates over it, the chat
-- and the large windows get none. /sui hover switches it off.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local MAX_WIDTH, MAX_HEIGHT = 520, 420  -- larger than this is a window, not an item

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.hover == nil then
		SurvivorUIDB.hover = true
	end
	return SurvivorUIDB
end

local outline = CreateFrame("Frame", "SurvivorUIHover", UIParent)
outline:SetFrameStrata("TOOLTIP")
outline:Hide()

for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
	local line = outline:CreateTexture(nil, "OVERLAY")
	line:SetTexture(FLAT)
	line:SetVertexColor(1, 1, 1, 0.9)
	if side == "TOP" or side == "BOTTOM" then
		line:SetHeight(1)
		line:SetPoint(side.."LEFT", outline, side.."LEFT", 0, 0)
		line:SetPoint(side.."RIGHT", outline, side.."RIGHT", 0, 0)
	else
		line:SetWidth(1)
		line:SetPoint("TOP"..side, outline, "TOP"..side, 0, 0)
		line:SetPoint("BOTTOM"..side, outline, "BOTTOM"..side, 0, 0)
	end
end

local SKIP = {}                 -- frames that are the background, not an item

-- The addon's panels themselves: their lines get the outline, the whole box
-- does not.
local PANELS = {
	SurvivorUILoot = true, SurvivorUIMeter = true, SurvivorUIRun = true,
	SurvivorUICrits = true, SurvivorUIBosses = true, SurvivorUIBuild = true, SurvivorUIOptions = true,
}

local function Wanted(frame)
	if not frame or SKIP[frame] or not frame:IsVisible() then
		return false
	end
	-- A 3D model (the hero in the character pane) is a picture, not an item.
	local kind = frame.GetObjectType and frame:GetObjectType()
	if kind == "PlayerModel" or kind == "Model" or kind == "DressUpModel" then
		return false
	end
	local ownName = frame.GetName and frame:GetName()
	if ownName and PANELS[ownName] then
		return false
	end
	-- A piece with a hover look of its own (the meter's view menu).
	if frame.noHoverOutline then
		return false
	end
	-- Nameplates hang from the world, not the interface; the chat (its window,
	-- tabs, edit box and buttons) is text to read; and the minimap, its zone
	-- name and the buttons around it are a map, and so is the run tracker
	-- under it. None gets one.
	local node, inPane = frame, false
	while node do
		if node == WorldFrame then
			return false
		end
		local name = node.GetName and node:GetName()
		if name and (string.find(name, "^ChatFrame") or string.find(name, "^Mini[Mm]ap")
			or name == "SurvivorUITracker") then
			return false
		end
		inPane = inPane or name == "CharacterFrame"
		node = node.GetParent and node:GetParent()
	end
	-- In the character pane, only what answers the mouse (an item's slot, a
	-- stat): its frames that only hold the rest are its background.
	if inPane and not (frame.GetScript and frame:GetScript("OnEnter")) then
		return false
	end
	local width, height = frame:GetWidth(), frame:GetHeight()
	if not width or not height or width <= 0 or height <= 0 then
		return false
	end
	return width <= MAX_WIDTH and height <= MAX_HEIGHT
end

local current
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local focus = Settings().hover and GetMouseFocus and GetMouseFocus()
	if not Wanted(focus) then
		focus = nil
	end
	if focus == current then
		return
	end
	current = focus
	if focus then
		-- One pixel outside the item, all round.
		outline:ClearAllPoints()
		outline:SetPoint("TOPLEFT", focus, "TOPLEFT", -1, 1)
		outline:SetPoint("BOTTOMRIGHT", focus, "BOTTOMRIGHT", 1, -1)
		outline:Show()
	else
		outline:Hide()
	end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	SKIP[WorldFrame] = true
	SKIP[UIParent] = true
end)

function SurvivorUI_ToggleHover()
	local settings = Settings()
	settings.hover = not settings.hover
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: hover outline "..(settings.hover and "on." or "off."))
end
