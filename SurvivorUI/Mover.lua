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
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
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
local editing = false           -- configuration mode: everything unlocked, the grid on

------------------------------------------------------------------------------
-- The grid of configuration mode: a line every GRID units, the screen's middle
-- lines brighter, and a piece let go there snaps to the nearest step.

local GRID = 32
local SNAP = 8

local grid = CreateFrame("Frame", "SurvivorUIGrid", UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("BACKGROUND")
grid:Hide()
grid.lines = {}

local function GridLine(vertical, offset, bright)
	local line = grid:CreateTexture(nil, "ARTWORK")
	line:SetTexture(FLAT)
	if bright then
		line:SetVertexColor(1, 0.82, 0, 0.45)
	else
		line:SetVertexColor(1, 1, 1, 0.08)
	end
	if vertical then
		line:SetWidth(1)
		line:SetPoint("TOP", grid, "TOP", offset, 0)
		line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
	else
		line:SetHeight(1)
		line:SetPoint("LEFT", grid, "LEFT", 0, offset)
		line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
	end
	table.insert(grid.lines, line)
end

-- Lines from the middle out, so the middle lines fall on the screen's center.
local function BuildGrid()
	if grid.built then
		return
	end
	grid.built = true
	local halfWidth, halfHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
	for x = 0, halfWidth, GRID do
		GridLine(true, x, x == 0)
		if x > 0 then
			GridLine(true, -x, false)
		end
	end
	for y = 0, halfHeight, GRID do
		GridLine(false, y, y == 0)
		if y > 0 then
			GridLine(false, -y, false)
		end
	end
end

-- A piece let go in configuration mode lands on the nearest SNAP step, its top
-- left corner counted from the screen's corner, in the screen's own units.
local function Snap(frame)
	if not editing then
		return
	end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then
		return
	end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local x = math.floor(left * ratio / SNAP + 0.5) * SNAP
	local y = math.floor(top * ratio / SNAP + 0.5) * SNAP
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ratio, y / ratio)
end

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
	handle.label:SetFont(FONT, 11 + FONT_BUMP, "OUTLINE")
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
		Snap(mover)
		if save then
			save()
		end
	end)
	return handle
end

-- The action bar: the buttons and the experience bar under them. The player
-- and target frames, the buffs and the kills and gold line move on their own,
-- below; left where they are, they follow the bar.
local middle = MakeHandle("Action bar  -  /sui center puts it back")
middle:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 4)
middle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 4, -12)
middle.label:ClearAllPoints()
middle.label:SetPoint("BOTTOM", middle, "TOP", 0, 3)
middle:SetScript("OnDragStart", function()
	dragging = this
	row:StartMoving()
end)
middle:SetScript("OnDragStop", function()
	dragging = nil
	row:StopMovingOrSizing()
	Snap(row)
	Save()
end)

-- The buffs and the kills and gold line: their own handles. Left where they
-- are, they follow the middle block; once moved, they stay put.
local function KeepPiece(frame, label, xKey, yKey, point, default)
	if not frame then
		return
	end
	frame:SetMovable(true)
	if frame.SetClampedToScreen then
		frame:SetClampedToScreen(true)
	end
	local function SavePiece()
		SurvivorUIDB = SurvivorUIDB or {}
		local x = point == "BOTTOMLEFT" and frame:GetLeft() or frame:GetLeft()
		local y = point == "BOTTOMLEFT" and frame:GetBottom() or frame:GetTop()
		SurvivorUIDB[xKey] = math.floor(x + 0.5)
		SurvivorUIDB[yKey] = math.floor(y + 0.5)
	end
	local function RestorePiece()
		frame:ClearAllPoints()
		if SurvivorUIDB and SurvivorUIDB[xKey] and SurvivorUIDB[yKey] then
			frame:SetPoint(point, UIParent, "BOTTOMLEFT", SurvivorUIDB[xKey], SurvivorUIDB[yKey])
		else
			default()
		end
	end
	local handle = SurvivorUI_RegisterMover(frame, label, SavePiece, nil, RestorePiece)
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("PLAYER_ENTERING_WORLD")
	loader:SetScript("OnEvent", RestorePiece)
	return handle
end

local GAP = 6                    -- between a unit frame and the buttons, as SurvivorUI.lua sets it
local playerHandle = KeepPiece(player, "Player frame", "playerLeft", "playerTop", "TOPLEFT", function()
	player:SetPoint("RIGHT", row, "LEFT", -GAP, 0)
end)
local targetHandle = KeepPiece(target, "Target frame", "targetLeft", "targetTop", "TOPLEFT", function()
	target:SetPoint("LEFT", row, "RIGHT", GAP, 0)
end)

-- The option to keep the two frames joined to the bar: back at its sides,
-- moved with it as one piece, their own handles put away.
local function Linked()
	return SurvivorUIDB and SurvivorUIDB.linkFrames == true
end

local function ApplyLink()
	local linked = Linked()
	if linked then
		SurvivorUIDB.playerLeft, SurvivorUIDB.playerTop = nil, nil
		SurvivorUIDB.targetLeft, SurvivorUIDB.targetTop = nil, nil
		player:ClearAllPoints()
		player:SetPoint("RIGHT", row, "LEFT", -GAP, 0)
		target:ClearAllPoints()
		target:SetPoint("LEFT", row, "RIGHT", GAP, 0)
	end
	if playerHandle then
		playerHandle.disabled = linked
	end
	if targetHandle then
		targetHandle.disabled = linked
	end
	middle:ClearAllPoints()
	if linked then
		middle:SetPoint("TOPLEFT", player, "TOPLEFT", -4, 4)
		middle:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -12)
		middle.label:SetText("Action bar and frames  -  /sui center puts it back")
	else
		middle:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 4)
		middle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 4, -12)
		middle.label:SetText("Action bar  -  /sui center puts it back")
	end
	-- Handles already up follow at once.
	for _, handle in pairs({ playerHandle, targetHandle }) do
		if handle and handle.disabled then
			handle:EnableMouse(false)
			handle:Hide()
		end
	end
end

function SurvivorUI_SetLinkFrames(on)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.linkFrames = on and true or false
	ApplyLink()
end

function SurvivorUI_LinkFrames()
	return Linked()
end

local linker = CreateFrame("Frame")
linker:RegisterEvent("PLAYER_ENTERING_WORLD")
linker:SetScript("OnEvent", ApplyLink)
KeepPiece(getglobal("SurvivorUIBuffs"), "Buffs", "buffsLeft", "buffsBottom", "BOTTOMLEFT", function()
	SurvivorUIBuffs:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 5)
end)

-- Shown with Alt held, in configuration mode, or while a drag is still going.
local shown = false
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local wanted = IsAltKeyDown() or editing or dragging ~= nil
	if wanted == shown then
		return
	end
	shown = wanted
	for index = 1, table.getn(handles) do
		local handle = handles[index]
		if wanted and not handle.disabled then
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
-- /sui scale: the size of the addon's panels, for screens where they crowd
-- each other (a small resolution, or a large interface scale).

local SCALED = {
	"SurvivorUITracker", "SurvivorUIRun", "SurvivorUIMeter", "SurvivorUIBosses",
	"SurvivorUILoot", "SurvivorUICritTip", "SurvivorUICrits", "SurvivorUIBuild",
}

-- A moved panel keeps its place as a point in its own scale's units: the same
-- numbers under another scale would put it elsewhere, off the screen even.
-- So a change of scale converts each saved place, keeping the panel where it
-- stands, and no panel may leave the screen.
local SAVED = {
	SurvivorUITracker = { "trackerRight", "trackerTop", "TOPRIGHT" },
	SurvivorUIRun = { "runLeft", "runTop", "TOPLEFT" },
	SurvivorUIMeter = { "meterRight", "meterBottom", "BOTTOMRIGHT" },
	SurvivorUIBosses = { "bossLeft", "bossTop", "TOPLEFT" },
	SurvivorUILoot = { "lootLeft", "lootTop", "TOPLEFT" },
	SurvivorUICrits = { "critsLeft", "critsTop", "TOPLEFT" },
	SurvivorUIBuild = { "buildLeft", "buildTop", "TOPLEFT" },
}

local function ApplyScale(from)
	SurvivorUIDB = SurvivorUIDB or {}
	local scale = SurvivorUIDB.panelScale or 1
	from = from or scale
	for index = 1, table.getn(SCALED) do
		local name = SCALED[index]
		local frame = getglobal(name)
		if frame then
			if frame.SetClampedToScreen then
				frame:SetClampedToScreen(true)
			end
			frame:SetScale(scale)
			local spec = SAVED[name]
			local x, y = spec and SurvivorUIDB[spec[1]], spec and SurvivorUIDB[spec[2]]
			if x and y then
				if from ~= scale then
					x = math.floor(x * from / scale + 0.5)
					y = math.floor(y * from / scale + 0.5)
					SurvivorUIDB[spec[1]], SurvivorUIDB[spec[2]] = x, y
				end
				frame:ClearAllPoints()
				frame:SetPoint(spec[3], UIParent, "BOTTOMLEFT", x, y)
			end
		end
	end
end

function SurvivorUI_SetScale(value)
	SurvivorUIDB = SurvivorUIDB or {}
	value = tonumber(value)
	if not value then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: panels at "..((SurvivorUIDB.panelScale) or 1).."; /sui scale 0.85 sets it, 0.6 to 1.4.")
		return
	end
	local from = SurvivorUIDB.panelScale or 1
	SurvivorUIDB.panelScale = math.max(0.6, math.min(1.4, value))
	ApplyScale(from)
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: panels at "..SurvivorUIDB.panelScale..".")
end
local scaler = CreateFrame("Frame")
scaler:RegisterEvent("PLAYER_ENTERING_WORLD")
scaler:SetScript("OnEvent", function() ApplyScale() end)

------------------------------------------------------------------------------
-- /sui layout: every piece back in its first place.

-- Configuration mode on or off: every piece unlocked, without Alt, over a grid.
function SurvivorUI_SetEditMode(on)
	editing = on and true or false
	if editing then
		BuildGrid()
		grid:Show()
	else
		grid:Hide()
	end
end

function SurvivorUI_EditMode()
	return editing
end

local PLACES = {
	"rowX", "rowY", "runLeft", "runTop", "runBottom", "trackerRight", "trackerTop",
	"meterRight", "meterBottom", "bossLeft", "bossTop", "lootLeft", "lootTop",
	"chatLeft", "chatBottom", "mapRight", "mapTop", "tipRight", "tipBottom", "critsLeft", "critsBottom", "critsTop", "buildLeft", "buildTop",
	"buffsLeft", "buffsBottom", "tallyLeft", "tallyTop", "playerLeft", "playerTop", "targetLeft", "targetTop",
}

-- A new layout starts everyone from the first places once: the pieces moved
-- around in v2.0, and an old saved place would leave one stranded. Runs when
-- the saved settings arrive, before any piece puts itself back.
local LAYOUT_VERSION = 3          -- 3: the build list joins the right column
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