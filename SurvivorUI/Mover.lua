-- Survivor UI: the middle of the screen moves as one.
--
-- The player frame, the action buttons, the target frame, the experience bar,
-- the kills and gold line, the hero's buffs and the target's debuffs all hang from one row
-- (SurvivorUIRow). Holding Alt lays a handle over the whole block, outlined so
-- it shows: drag it and everything goes along. The place is kept between
-- sessions; /sui center puts the block back under the hero.
--
-- Every other movable piece registers here too (SurvivorUI_RegisterMover), so
-- Alt outlines them all at once. /sui layout puts everything back.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local DEFAULT_Y = -150          -- the row's place under the screen's center

local row = getglobal("SurvivorUIRow")
local player = getglobal("SurvivorUIPlayer")
local target = getglobal("SurvivorUITarget")
if not (row and player and target) then
	return
end

local function Place(x, y)
	row:ClearAllPoints()
	row:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- Keeps the row's offset from the screen's center.
local function Save()
	local x, y = row:GetCenter()
	local cx, cy = UIParent:GetCenter()
	if not (x and cx) then
		return
	end
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.rowX = math.floor(x - cx + 0.5)
	SurvivorUIDB.rowY = math.floor(y - cy + 0.5)
	Place(SurvivorUIDB.rowX, SurvivorUIDB.rowY)
end

local function Restore()
	if SurvivorUIDB and SurvivorUIDB.rowX then
		Place(SurvivorUIDB.rowX, SurvivorUIDB.rowY)
	end
end

function SurvivorUI_CenterRow()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.rowX, SurvivorUIDB.rowY = nil, nil
	Place(0, DEFAULT_Y)
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the middle of the screen is back under the hero.")
end

------------------------------------------------------------------------------
-- Handles: an outline over a movable piece, shown with Alt held, so holding
-- Alt shows at once everything that can be moved. A handle takes the mouse
-- only while shown, so clicks and spells go through untouched the rest of the
-- time.

local handles = {}
local dragging                  -- the handle being dragged, until it is let go

local function MakeHandle(label)
	local handle = CreateFrame("Frame", nil, UIParent)
	handle:SetFrameStrata("DIALOG")
	handle:EnableMouse(false)
	handle:RegisterForDrag("LeftButton")
	handle:Hide()

	handle.fill = handle:CreateTexture(nil, "BACKGROUND")
	handle.fill:SetTexture(FLAT)
	handle.fill:SetAllPoints(handle)
	handle.fill:SetVertexColor(1, 0.82, 0, 0.08)

	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = handle:CreateTexture(nil, "BORDER")
		line:SetTexture(FLAT)
		line:SetVertexColor(1, 0.82, 0, 0.7)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", handle, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", handle, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, handle, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, handle, "BOTTOM"..side, 0, 0)
		end
	end

	handle.label = handle:CreateFontString(nil, "OVERLAY")
	handle.label:SetFont(FONT, 11, "OUTLINE")
	handle.label:SetPoint("TOP", handle, "TOP", 0, -4)
	handle.label:SetTextColor(1, 0.82, 0)
	handle.label:SetText(label)

	table.insert(handles, handle)
	return handle
end

-- Any piece of the interface: the outline covers frame, the drag moves mover
-- (frame itself unless given), which must be movable; save keeps its place,
-- default puts it back in its first one (for /sui layout).
function SurvivorUI_RegisterMover(frame, label, save, mover, default)
	mover = mover or frame
	local handle = MakeHandle(label)
	handle.default = default
	handle:SetAllPoints(frame)
	handle:SetScript("OnDragStart", function()
		dragging = this
		mover:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		dragging = nil
		mover:StopMovingOrSizing()
		if save then
			save()
		end
	end)
	return handle
end

-- The middle block: from the buffs above the player frame to the kills and
-- gold line under the row.
local middle = MakeHandle("Middle block  -  /sui center puts it back")
middle:SetPoint("TOPLEFT", player, "TOPLEFT", -4, 34)
middle:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -32)
middle.label:ClearAllPoints()
middle.label:SetPoint("BOTTOM", middle, "TOP", 0, 3)
middle:SetScript("OnDragStart", function()
	dragging = this
	row:StartMoving()
end)
middle:SetScript("OnDragStop", function()
	dragging = nil
	row:StopMovingOrSizing()
	Save()
end)

-- Shown with Alt held, or while a drag that began with it is still going.
local shown = false
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local wanted = IsAltKeyDown() or dragging ~= nil
	if wanted == shown then
		return
	end
	shown = wanted
	for index = 1, table.getn(handles) do
		local handle = handles[index]
		if wanted then
			handle:Show()
			handle:EnableMouse(true)
		else
			handle:EnableMouse(false)
			handle:Hide()
		end
	end
end)

------------------------------------------------------------------------------
-- The game's own pieces: the chat window and the minimap (with its zone name).
-- The run tracker hangs from the minimap, so the right column follows it.

local function Keep(frame, leftKey, edgeKey, edge)
	frame:SetMovable(true)
	if frame.SetClampedToScreen then
		frame:SetClampedToScreen(true)
	end
	local function SaveIt()
		SurvivorUIDB = SurvivorUIDB or {}
		SurvivorUIDB[leftKey] = math.floor((edge == "TOP" and frame:GetRight() or frame:GetLeft()) + 0.5)
		SurvivorUIDB[edgeKey] = math.floor((edge == "TOP" and frame:GetTop() or frame:GetBottom()) + 0.5)
	end
	local function RestoreIt()
		if not (SurvivorUIDB and SurvivorUIDB[leftKey]) then
			return
		end
		frame:ClearAllPoints()
		if edge == "TOP" then
			frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", SurvivorUIDB[leftKey], SurvivorUIDB[edgeKey])
		else
			frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB[leftKey], SurvivorUIDB[edgeKey])
		end
	end
	return SaveIt, RestoreIt
end

local gameRestores = {}
if ChatFrame1 then
	local save, restore = Keep(ChatFrame1, "chatLeft", "chatBottom", "BOTTOM")
	SurvivorUI_RegisterMover(ChatFrame1, "Chat", save, nil, function()
		-- The stock chat's first place.
		ChatFrame1:ClearAllPoints()
		ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
	end)
	table.insert(gameRestores, restore)
end
if MinimapCluster then
	local save, restore = Keep(MinimapCluster, "mapRight", "mapTop", "TOP")
	SurvivorUI_RegisterMover(Minimap or MinimapCluster, "Minimap", save, MinimapCluster, function()
		MinimapCluster:ClearAllPoints()
		MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	end)
	table.insert(gameRestores, restore)
end

-- The stock interface can seat them again as the world loads: put them back
-- then, and once more a moment later.
local restoreAt
local gameLoader = CreateFrame("Frame")
gameLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
gameLoader:SetScript("OnEvent", function()
	for index = 1, table.getn(gameRestores) do
		gameRestores[index]()
	end
	restoreAt = GetTime() + 1
end)
gameLoader:SetScript("OnUpdate", function()
	if restoreAt and GetTime() >= restoreAt then
		restoreAt = nil
		for index = 1, table.getn(gameRestores) do
			gameRestores[index]()
		end
	end
end)

------------------------------------------------------------------------------
-- /sui layout: every piece back in its first place.

local PLACES = {
	"rowX", "rowY", "runLeft", "runTop", "runBottom", "trackerRight", "trackerTop",
	"meterRight", "meterBottom", "bossLeft", "bossTop", "lootLeft", "lootTop",
	"chatLeft", "chatBottom", "mapRight", "mapTop",
}

-- A new layout starts everyone from the first places once: the pieces moved
-- around in v2.0, and an old saved place would leave one stranded. Runs when
-- the saved settings arrive, before any piece puts itself back.
local LAYOUT_VERSION = 2
local migrator = CreateFrame("Frame")
migrator:RegisterEvent("ADDON_LOADED")
migrator:SetScript("OnEvent", function()
	if arg1 ~= "SurvivorUI" then
		return
	end
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.layoutVersion ~= LAYOUT_VERSION then
		for index = 1, table.getn(PLACES) do
			SurvivorUIDB[PLACES[index]] = nil
		end
		SurvivorUIDB.layoutVersion = LAYOUT_VERSION
	end
end)

-- Puts everything back at once, no reload: the saved places go, and each piece
-- takes its first place again. The minimap goes first, as the right column
-- hangs from it.
function SurvivorUI_ResetLayout()
	SurvivorUIDB = SurvivorUIDB or {}
	for index = 1, table.getn(PLACES) do
		SurvivorUIDB[PLACES[index]] = nil
	end
	Place(0, DEFAULT_Y)
	for pass = 1, 2 do
		for index = 1, table.getn(handles) do
			local default = handles[index].default
			if default then
				default()
			end
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: every piece is back in its first place.")
end

-- The saved place comes back once the saved settings have.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Restore)