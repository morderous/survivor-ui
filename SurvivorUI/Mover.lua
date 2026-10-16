-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
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
	-- The bar's center is in its own size's units; the screen's, made the same.
	local ratio = UIParent:GetEffectiveScale() / row:GetEffectiveScale()
	cx, cy = cx * ratio, cy * ratio
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
-- Sizes: one for the whole interface (/sui scale, the options' "All" slider)
-- and one for each part, the two multiplied. A part is one or more frames,
-- and the saved places that belong to them.

local SCALE_MIN, SCALE_MAX = 0.5, 2
local PARTS = {
	{ key = "tracker", label = "Run tracker", frames = { "SurvivorUITracker" },
		places = { { "trackerRight", "trackerTop", "TOPRIGHT" } } },
	{ key = "build", label = "Build list", frames = { "SurvivorUIBuild" },
		places = { { "buildLeft", "buildTop", "TOPLEFT" } } },
	{ key = "meter", label = "Damage meter", frames = { "SurvivorUIMeter", "SurvivorUICritTip" },
		places = { { "meterRight", "meterBottom", "BOTTOMRIGHT" } } },
	{ key = "run", label = "This Run", frames = { "SurvivorUIRun" },
		places = { { "runLeft", "runTop", "TOPLEFT" } }, extra = { "runBottom" } },
	{ key = "crits", label = "Biggest Crits", frames = { "SurvivorUICrits" },
		places = { { "critsLeft", "critsTop", "TOPLEFT" } }, extra = { "critsBottom" } },
	{ key = "bosses", label = "Boss bars", frames = { "SurvivorUIBosses" },
		places = { { "bossLeft", "bossTop", "TOPLEFT" } } },
	{ key = "loot", label = "Loot list", frames = { "SurvivorUILoot" },
		places = { { "lootLeft", "lootTop", "TOPLEFT" } } },
	-- The whole center at once: the bar, the frames, the buffs and the kills
	-- line, each still with its own size on top.
	{ key = "middle", label = "Whole center bar", frames = {}, places = {}, members = "middle" },
	-- The buttons belong to the game's bar, hung on the row: sized with it.
	{ key = "bar", label = "Action bar", group = "middle", frames = { "SurvivorUIRow", "MainMenuExpBar",
		"ActionButton1", "ActionButton2", "ActionButton3", "ActionButton4", "ActionButton5", "ActionButton6",
		"ActionButton7", "ActionButton8", "ActionButton9", "ActionButton10", "ActionButton11", "ActionButton12",
		"BonusActionButton1", "BonusActionButton2", "BonusActionButton3", "BonusActionButton4", "BonusActionButton5", "BonusActionButton6",
		"BonusActionButton7", "BonusActionButton8", "BonusActionButton9", "BonusActionButton10", "BonusActionButton11", "BonusActionButton12" },
		places = {}, extra = { "rowX", "rowY" }, restore = function() Restore() end },
	{ key = "frames", label = "Player and target", group = "middle", frames = { "SurvivorUIPlayer", "SurvivorUITarget" },
		places = { { "playerLeft", "playerTop", "TOPLEFT", "SurvivorUIPlayer" }, { "targetLeft", "targetTop", "TOPLEFT", "SurvivorUITarget" } } },
	{ key = "buffs", label = "Buffs", group = "middle", frames = { "SurvivorUIBuffs" },
		places = { { "buffsLeft", "buffsBottom", "BOTTOMLEFT" } } },
	{ key = "tally", label = "Kills and gold", group = "middle", frames = { "SurvivorUITallyFrame" },
		places = { { "tallyLeft", "tallyTop", "TOPLEFT" } } },
	-- The minimap with all it holds: the zone's name, the pins and the buttons.
	{ key = "minimap", label = "Minimap", frames = { "MinimapCluster" },
		places = { { "mapRight", "mapTop", "TOPRIGHT" } } },
	-- A little smaller than the game made it, to leave room beside it.
	{ key = "character", label = "Character pane", frames = { "CharacterFrame" }, places = {}, default = 0.85 },
	-- The numbers on their own (CharacterPane.lua): sized and placed there, as
	-- inside the character pane they take its size.
	{ key = "stats", label = "Stats on their own", frames = {}, places = {}, extra = { "statsLeft", "statsTop" },
		apply = function(scale) if SurvivorUI_StatsScale then SurvivorUI_StatsScale(scale) end end },
}

local function Clamp(value)
	return math.max(SCALE_MIN, math.min(SCALE_MAX, value))
end

local function PartScales()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.partScale = SurvivorUIDB.partScale or {}
	return SurvivorUIDB.partScale
end

-- A part's size on screen: the whole interface's times its group's (the
-- whole center bar) times its own.
local function Effective(part)
	local group = part.group and (PartScales()[part.group] or 1) or 1
	return Clamp((SurvivorUIDB and SurvivorUIDB.panelScale or 1) * group * (PartScales()[part.key] or part.default or 1))
end

-- A moved piece keeps its place as a point in its own size's units: the same
-- numbers at another size would put it elsewhere, off the screen even. So a
-- change of size converts the part's saved places, keeping it where it
-- stands, and no piece may leave the screen.
local function ApplyPart(part, from)
	-- A group's size is only its members'.
	if part.members then
		return
	end
	local scale = Effective(part)
	from = from or scale
	local db = SurvivorUIDB
	if from ~= scale then
		local keys = {}
		for _, place in pairs(part.places) do
			table.insert(keys, place[1])
			table.insert(keys, place[2])
		end
		for _, key in pairs(part.extra or {}) do
			table.insert(keys, key)
		end
		for _, key in pairs(keys) do
			if db[key] then
				db[key] = math.floor(db[key] * from / scale + 0.5)
			end
		end
	end
	-- Kept on the screen: the part's own frames, the ones it moves by. Not the
	-- action buttons: the ones put away wait below the screen's edge.
	local kept = {}
	if part.frames[1] then
		kept[part.frames[1]] = true
	end
	for _, place in pairs(part.places) do
		kept[place[4] or part.frames[1]] = true
	end
	for _, name in pairs(part.frames) do
		local frame = getglobal(name)
		if frame then
			if kept[name] and frame.SetClampedToScreen then
				frame:SetClampedToScreen(true)
			end
			frame:SetScale(scale)
		end
	end
	for _, place in pairs(part.places) do
		local frame = getglobal(place[4] or part.frames[1])
		if frame and db[place[1]] and db[place[2]] then
			frame:ClearAllPoints()
			frame:SetPoint(place[3], UIParent, "BOTTOMLEFT", db[place[1]], db[place[2]])
		end
	end
	if part.restore then
		part.restore()
	end
	if part.apply then
		part.apply(scale)
	end
end

local function ApplyScale()
	SurvivorUIDB = SurvivorUIDB or {}
	for _, part in pairs(PARTS) do
		ApplyPart(part)
	end
end

local function FindPart(key)
	for _, part in pairs(PARTS) do
		if part.key == key then
			return part
		end
	end
end

-- The parts, for the options: { key, label } each.
function SurvivorUI_ScaleParts()
	local list = {}
	for index = 1, table.getn(PARTS) do
		table.insert(list, { key = PARTS[index].key, label = PARTS[index].label })
	end
	return list
end

-- A part's own size (key), or the whole interface's (key nil).
function SurvivorUI_GetScale(key)
	SurvivorUIDB = SurvivorUIDB or {}
	if key then
		local part = FindPart(key)
		return PartScales()[key] or (part and part.default) or 1
	end
	return SurvivorUIDB.panelScale or 1
end

-- A part's size on screen, the whole interface's times its own.
function SurvivorUI_PartScale(key)
	local part = FindPart(key)
	return part and Effective(part) or 1
end

function SurvivorUI_SetPartScale(key, value)
	local part = FindPart(key)
	value = tonumber(value)
	if not (part and value) then
		return
	end
	-- A group: each member keeps its place through the change.
	if part.members then
		local froms = {}
		for _, member in pairs(PARTS) do
			if member.group == part.members then
				froms[member.key] = Effective(member)
			end
		end
		PartScales()[key] = Clamp(math.floor(value * 100 + 0.5) / 100)
		for _, member in pairs(PARTS) do
			if member.group == part.members then
				ApplyPart(member, froms[member.key])
			end
		end
		return
	end
	local from = Effective(part)
	PartScales()[key] = Clamp(math.floor(value * 100 + 0.5) / 100)
	ApplyPart(part, from)
end

-- The whole interface's size: /sui scale 0.85, or the options' slider.
function SurvivorUI_SetScale(value, quiet)
	SurvivorUIDB = SurvivorUIDB or {}
	value = tonumber(value)
	if not value then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: interface at "..(SurvivorUIDB.panelScale or 1).."; /sui scale 0.85 sets it, 0.6 to 1.4. Each part has its own size in /sui opt.")
		return
	end
	local froms = {}
	for _, part in pairs(PARTS) do
		froms[part.key] = Effective(part)
	end
	SurvivorUIDB.panelScale = math.max(0.6, math.min(1.4, math.floor(value * 100 + 0.5) / 100))
	for _, part in pairs(PARTS) do
		ApplyPart(part, froms[part.key])
	end
	if not quiet then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: interface at "..SurvivorUIDB.panelScale..".")
	end
end

-- Every part back to its own size 1 (the whole interface's stays).
function SurvivorUI_ResetPartScales()
	for _, part in pairs(PARTS) do
		SurvivorUI_SetPartScale(part.key, part.default or 1)
	end
end

-- Before v2.8 the whole-interface size reached the panels only: a player who
-- had set it keeps the action bar, the frames, the buffs and the kills line
-- at the size they had, through their own sizes.
local function MigrateScale()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.scaleVersion == 2 then
		return
	end
	SurvivorUIDB.scaleVersion = 2
	local global = SurvivorUIDB.panelScale or 1
	if global ~= 1 then
		local parts = PartScales()
		for _, key in pairs({ "bar", "frames", "buffs", "tally" }) do
			parts[key] = parts[key] or Clamp(math.floor(100 / global + 0.5) / 100)
		end
	end
end

local scaler = CreateFrame("Frame")
scaler:RegisterEvent("PLAYER_ENTERING_WORLD")
scaler:SetScript("OnEvent", function()
	MigrateScale()
	ApplyScale()
end)

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