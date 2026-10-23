-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the middle of the screen moves as one.
--
-- The player frame, the action buttons, the target frame, the experience bar,
-- the hero's buffs and the target's debuffs all hang from one row
-- (SurvivorUIRow). Holding Alt lays a handle over the whole block, outlined so
-- it shows: drag it and everything goes along. The place is kept between
-- sessions; /sui center puts the block back under the hero.
--
-- Every other movable piece registers here too (SurvivorUI_RegisterMover), so
-- Alt outlines them all at once. /sui layout puts everything back.
--
-- In move mode a click on a piece opens its card (EditCard.lua): its place to
-- the unit, its size, shown or hidden, back to its first place, undo. A piece
-- let go there lands on the grid, or lines up with a neighbour's edge when one
-- is near.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }   -- the addon's own color, the class's
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

-- The pieces of the options' open tab, movable while it is open, without the
-- grid ("all" for every one); a drag moves them, a click opens a card.
local focus
local focusVersion = 0

local function InFocus(handle)
	return focus == "all" or (focus ~= nil and handle.name ~= nil and focus[handle.name] == true)
end

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
	line.bright = bright
	if bright then
		line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
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
	-- In UIParent's units, the UI scale taken in, so the lines reach the edges.
	local halfWidth, halfHeight = GetScreenWidth() / 2, GetScreenHeight() / 2
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

local EDGE = 6                  -- a neighbour's edge this near pulls a piece to it

-- The nearest of a neighbour's lines to one of ours, along one axis: the
-- shift that lines them up, or nil when none is within EDGE.
local function Pull(mine, theirs)
	local best
	for _, a in pairs(mine) do
		for _, b in pairs(theirs) do
			local shift = b - a
			if math.abs(shift) <= EDGE and (not best or math.abs(shift) < math.abs(best)) then
				best = shift
			end
		end
	end
	return best
end

-- A piece let go in configuration mode lands on the nearest SNAP step, its top
-- left corner counted from the screen's corner, in the screen's own units; then
-- a neighbour's edge (or middle) near one of its own pulls it into line.
local function Snap(frame, own)
	-- In Move UI, on a tab's pieces, or with Alt held (the grid is up): let
	-- go of Alt before the mouse to put a piece down free.
	if not (editing or focus or IsAltKeyDown()) then
		return
	end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then
		return
	end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local x = math.floor(left * ratio / SNAP + 0.5) * SNAP
	local y = math.floor(top * ratio / SNAP + 0.5) * SNAP
	local width, height = (frame:GetWidth() or 0) * ratio, (frame:GetHeight() or 0) * ratio
	local pullX, pullY
	for _, other in pairs(handles) do
		if other ~= own and other:IsShown() and other:GetLeft() then
			local l, r, t, b = other:GetLeft(), other:GetRight(), other:GetTop(), other:GetBottom()
			local dx = Pull({ x, x + width, x + width / 2 }, { l, r, (l + r) / 2 })
			local dy = Pull({ y, y - height, y - height / 2 }, { t, b, (t + b) / 2 })
			if dx and (not pullX or math.abs(dx) < math.abs(pullX)) then
				pullX = dx
			end
			if dy and (not pullY or math.abs(dy) < math.abs(pullY)) then
				pullY = dy
			end
		end
	end
	x, y = x + (pullX or 0), y + (pullY or 0)
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
	handle.fill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)

	-- A faint outline, and bright marks at the corners.
	handle.marks = {}
	handle.outline = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = handle:CreateTexture(nil, "BORDER")
		line:SetTexture(FLAT)
		line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
		table.insert(handle.outline, line)
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
	for _, corner in pairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		for _, across in pairs({ true, false }) do
			local mark = handle:CreateTexture(nil, "ARTWORK")
			mark:SetTexture(FLAT)
			mark:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.95)
			mark:SetWidth(across and 9 or 2)
			mark:SetHeight(across and 2 or 9)
			mark:SetPoint(corner, handle, corner, 0, 0)
			table.insert(handle.marks, mark)
		end
	end

	handle.label = handle:CreateFontString(nil, "OVERLAY")
	handle.label:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
	handle.label:SetPoint("TOP", handle, "TOP", 0, -4)
	handle.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	handle.label:SetText(label)
	handle.name = label

	-- In move mode, or the piece's tab open, a click picks the piece for its
	-- card (EditCard.lua); a drag only moves it.
	handle:SetScript("OnMouseDown", function()
		this.wasDragged = nil
	end)
	handle:SetScript("OnMouseUp", function()
		if this.wasDragged then
			this.wasDragged = nil
			return
		end
		if (editing or InFocus(this)) and SurvivorUI_EditSelect then
			SurvivorUI_EditSelect(this)
		end
	end)

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
	handle.mover, handle.save = mover, save
	handle:SetAllPoints(frame)
	handle:SetScript("OnDragStart", function()
		if SurvivorUI_EditBefore then
			SurvivorUI_EditBefore(this)
		end
		this.wasDragged = true
		dragging = this
		mover:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		dragging = nil
		mover:StopMovingOrSizing()
		Snap(mover, this)
		if save then
			save()
		end
		if editing and SurvivorUI_EditSelect then
			SurvivorUI_EditSelect(this)
		end
	end)
	return handle
end

-- Every piece that moves, for the card: { handle, ... }, each with its name,
-- what it moves (mover), how it saves (save) and its first place (default).
function SurvivorUI_MoverHandles()
	return handles
end

-- The action bar: the buttons and the experience bar under them. The player
-- and target frames and the buffs move on their own, below; left where they
-- are, they follow the bar.
local middle = MakeHandle("Action bar  -  /sui center puts it back")
middle.name = "Action bar"
middle.mover, middle.save = row, Save
middle.default = function()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.rowX, SurvivorUIDB.rowY = nil, nil
	Place(0, DEFAULT_Y)
end
middle:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 4)
middle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 4, -12)
middle.label:ClearAllPoints()
middle.label:SetPoint("BOTTOM", middle, "TOP", 0, 3)
middle:SetScript("OnDragStart", function()
	if SurvivorUI_EditBefore then
		SurvivorUI_EditBefore(this)
	end
	this.wasDragged = true
	dragging = this
	row:StartMoving()
end)
middle:SetScript("OnDragStop", function()
	dragging = nil
	row:StopMovingOrSizing()
	Snap(row, this)
	Save()
	if editing and SurvivorUI_EditSelect then
		SurvivorUI_EditSelect(this)
	end
end)

-- The frames and the buffs: their own handles. Left where they are, they
-- follow the middle block; once moved, they stay put.
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

-- Every one shown with Alt held, in configuration mode, or while a drag (of
-- one held with Alt) is still going; the open tab's pieces while it is open.
-- The grid under them whenever they all show (asked for 2026-10-22: with
-- Alt too, not only in Move UI).
local shown
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local all = IsAltKeyDown() or editing or (dragging ~= nil and not InFocus(dragging))
	local state = (all and "all" or "some")..focusVersion
	if state == shown then
		return
	end
	shown = state
	if all then
		BuildGrid()
		grid:Show()
	else
		grid:Hide()
	end
	for index = 1, table.getn(handles) do
		local handle = handles[index]
		if (all or InFocus(handle)) and not handle.disabled then
			handle:Show()
			handle:EnableMouse(true)
		else
			handle:EnableMouse(false)
			handle:Hide()
		end
	end
end)

-- The options' open tab: its pieces by name, "all", or nil (closed). A card
-- open on a piece put away closes.
function SurvivorUI_SetMoveFocus(names)
	if names == nil or names == "all" then
		focus = names
	else
		focus = {}
		for _, name in pairs(names) do
			focus[name] = true
		end
	end
	focusVersion = focusVersion + 1
	if not editing and SurvivorUI_EditSelect then
		SurvivorUI_EditSelect(nil)
	end
end

-- Whether a piece is being placed (move mode, Alt held, or its tab open): one
-- that only shows now and then (the Level Up! button) shows a sample then.
function SurvivorUI_Placing(name)
	return editing or IsAltKeyDown() or focus == "all" or (focus ~= nil and focus[name] == true)
end

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
	-- Its first place: low in the bottom left corner (since v3.0.6; the stock
	-- one stood higher, 32, 95).
	local function ChatDefault()
		ChatFrame1:ClearAllPoints()
		ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8, 40)
	end
	SurvivorUI_RegisterMover(ChatFrame1, "Chat", save, nil, ChatDefault)
	table.insert(gameRestores, function()
		if SurvivorUIDB and SurvivorUIDB.chatLeft then
			restore()
		else
			ChatDefault()
		end
	end)
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
-- Each in a section, as the options' tabs are grouped.
local PARTS = {
	{ key = "tracker", label = "Run tracker", section = "Run", frames = { "SurvivorUITracker" },
		places = { { "trackerRight", "trackerTop", "TOPRIGHT" } } },
	{ key = "build", section = "Character", label = "Build list", frames = { "SurvivorUIBuild" },
		places = { { "buildLeft", "buildTop", "TOPLEFT" } } },
	{ key = "meter", section = "Combat", label = "Damage meter", frames = { "SurvivorUIMeter", "SurvivorUICritTip" },
		places = { { "meterRight", "meterBottom", "BOTTOMRIGHT" } } },
	{ key = "run", section = "Combat", label = "This Run", frames = { "SurvivorUIRun" },
		places = { { "runLeft", "runTop", "TOPLEFT" } }, extra = { "runBottom" } },
	{ key = "crits", section = "Combat", label = "Biggest Crits", frames = { "SurvivorUICrits" },
		places = { { "critsLeft", "critsTop", "TOPLEFT" } }, extra = { "critsBottom" } },
	{ key = "bosses", section = "Run", label = "Boss bars", frames = { "SurvivorUIBosses" },
		places = { { "bossLeft", "bossTop", "TOPLEFT" } } },
	{ key = "loot", section = "Run", label = "Loot list", frames = { "SurvivorUILoot" },
		places = { { "lootLeft", "lootTop", "TOPLEFT" } } },
	{ key = "guardians", section = "Run", label = "Guardians", frames = { "SurvivorUIGuardians" },
		places = { { "guardiansLeft", "guardiansTop", "TOPLEFT" } } },
	-- A co-op run's (Party.lua): the friends' frames, and the revive bar.
	{ key = "party", section = "Combat", label = "Party frames", frames = { "SurvivorUIParty" },
		places = { { "partyLeft", "partyBottom", "BOTTOMLEFT" } } },
	{ key = "revive", section = "Combat", label = "Revive bar", frames = { "SurvivorUIRevive" },
		places = { { "reviveX", "reviveTop", "TOP" } } },
	-- The whole center at once: the bar, the frames and the buffs, each still
	-- with its own size on top.
	{ key = "middle", section = "Center bar", label = "Whole center bar", frames = {}, places = {}, members = "middle", default = 0.9 },
	-- The buttons belong to the game's bar, hung on the row: sized with it.
	{ key = "bar", section = "Center bar", label = "Action bar", group = "middle", feature = "actionBar", frames = { "SurvivorUIRow", "MainMenuExpBar",
		"ActionButton1", "ActionButton2", "ActionButton3", "ActionButton4", "ActionButton5", "ActionButton6",
		"ActionButton7", "ActionButton8", "ActionButton9", "ActionButton10", "ActionButton11", "ActionButton12",
		"BonusActionButton1", "BonusActionButton2", "BonusActionButton3", "BonusActionButton4", "BonusActionButton5", "BonusActionButton6",
		"BonusActionButton7", "BonusActionButton8", "BonusActionButton9", "BonusActionButton10", "BonusActionButton11", "BonusActionButton12" },
		places = {}, extra = { "rowX", "rowY" }, restore = function() Restore() end, default = 0.85 },
	{ key = "frames", section = "Center bar", label = "Player and target", group = "middle", frames = { "SurvivorUIPlayer", "SurvivorUITarget" },
		places = { { "playerLeft", "playerTop", "TOPLEFT", "SurvivorUIPlayer" }, { "targetLeft", "targetTop", "TOPLEFT", "SurvivorUITarget" } } },
	{ key = "buffs", section = "Center bar", label = "Buffs", group = "middle", frames = { "SurvivorUIBuffs" },
		places = { { "buffsLeft", "buffsBottom", "BOTTOMLEFT" } } },
	-- Under the minimap now: a size of its own, out of the center bar's.
	{ key = "tally", section = "Run", label = "Kills and gold line", frames = { "SurvivorUITallyFrame" },
		places = { { "tallyX", "tallyTop", "TOP" } } },
	{ key = "xpbar", section = "Run", label = "XP bar", frames = { "SurvivorUIXpBar" },
		places = { { "xpBarX", "xpBarTop", "TOP" } } },
	{ key = "levelup", section = "Run", label = "Level Up!", frames = { "SurvivorUILevelUp" },
		places = { { "levelUpX", "levelUpTop", "TOP" } } },
	-- The minimap with all it holds: the zone's name, the pins and the buttons.
	{ key = "minimap", section = "Screen", label = "Minimap", frames = { "MinimapCluster" },
		places = { { "mapRight", "mapTop", "TOPRIGHT" } } },
	-- A little smaller than the game made it, to leave room beside it.
	{ key = "character", section = "Character", label = "Character pane", frames = { "CharacterFrame" },
		places = { { "characterLeft", "characterTop", "TOPLEFT" } }, default = 0.85 },
	-- The numbers on their own (CharacterPane.lua): sized and placed there, as
	-- inside the character pane they take its size.
	{ key = "stats", section = "Character", label = "Stats", frames = {}, places = {}, extra = { "statsLeft", "statsTop" },
		apply = function(scale) if SurvivorUI_StatsScale then SurvivorUI_StatsScale(scale) end end },
	{ key = "jewelry", section = "Character", label = "Jewelry Collection", frames = { "SurvivorUIJewelryPanel" }, places = {} },
	-- Run History and Career, one size for both (the options' Run History tab).
	{ key = "history", section = "Run", label = "Run History", frames = { "SurvivorUILastRuns", "SurvivorUICareer" }, places = {} },
}

local function Clamp(value)
	return math.max(SCALE_MIN, math.min(SCALE_MAX, value))
end

-- The whole interface's size a new install starts with.
local DEFAULT_SCALE = 0.9

local function PartScales()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.partScale = SurvivorUIDB.partScale or {}
	return SurvivorUIDB.partScale
end

-- A part's size on screen: the whole interface's times its group's (the
-- whole center bar) times its own.
local function Own(key)
	local set = PartScales()[key]
	if set then
		return set
	end
	for index = 1, table.getn(PARTS) do
		if PARTS[index].key == key then
			return PARTS[index].default or 1
		end
	end
	return 1
end

local function Effective(part)
	local group = part.group and Own(part.group) or 1
	return Clamp((SurvivorUIDB and SurvivorUIDB.panelScale or DEFAULT_SCALE) * group * Own(part.key))
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
	-- A module off (the action bar): the game's own frames left as they are.
	if part.feature and SurvivorUI_Feature and not SurvivorUI_Feature(part.feature) then
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
		table.insert(list, { key = PARTS[index].key, label = PARTS[index].label, section = PARTS[index].section })
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
	return SurvivorUIDB.panelScale or DEFAULT_SCALE
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
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: interface at "..(SurvivorUIDB.panelScale or DEFAULT_SCALE).."; /sui scale 0.85 sets it, 0.6 to 1.4. Each part has its own size in /sui opt.")
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

-- Every part back to its own default size (the whole interface's stays).
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
	local fresh = SurvivorUIDB.scaleVersion == nil and SurvivorUIDB.partScale == nil
	if (SurvivorUIDB.scaleVersion or 0) < 2 then
		SurvivorUIDB.scaleVersion = 2
		local global = SurvivorUIDB.panelScale or 1
		if global ~= 1 then
			local parts = PartScales()
			for _, key in pairs({ "bar", "frames", "buffs", "tally" }) do
				parts[key] = parts[key] or Clamp(math.floor(100 / global + 0.5) / 100)
			end
		end
	end
	-- 3 (v3.0.5): the kills and gold line out of the center bar's size; its own
	-- takes the center bar's in once, so it stays as large as it was.
	if SurvivorUIDB.scaleVersion < 3 then
		SurvivorUIDB.scaleVersion = 3
		if not fresh then
			local parts = PartScales()
			parts.tally = Clamp(math.floor((parts.tally or 1) * Own("middle") * 100 + 0.5) / 100)
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
		if SurvivorUI_EditSelect then
			SurvivorUI_EditSelect(nil)
		end
	end
end

function SurvivorUI_EditMode()
	return editing
end

local PLACES = {
	"rowX", "rowY", "runLeft", "runTop", "runBottom", "trackerRight", "trackerTop",
	"meterRight", "meterBottom", "bossLeft", "bossTop", "lootLeft", "lootTop",
	"chatLeft", "chatBottom", "mapRight", "mapTop", "tipRight", "tipBottom", "critsLeft", "critsBottom", "critsTop", "buildLeft", "buildTop",
	"buffsLeft", "buffsBottom", "tallyLeft", "tallyX", "tallyTop", "playerLeft", "playerTop", "targetLeft", "targetTop",
	"guardiansLeft", "guardiansTop", "recordLeft", "recordTop",
	"dealtLeft", "dealtTop", "critLeft", "critTop", "takenLeft", "takenTop", "healLeft", "healTop",
	"mapButtonX", "mapButtonY", "xpBarX", "xpBarTop", "shardsX", "shardsTop",
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
	if SurvivorUI_ResetOptionsPlace then
		SurvivorUI_ResetOptionsPlace()
	end
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: every piece is back in its first place.")
end

-- The saved place comes back once the saved settings have.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Restore)

-- A new class color: the grid's middle lines and every handle take it.
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function()
		for _, line in pairs(grid.lines) do
			if line.bright then
				line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
			end
		end
		for index = 1, table.getn(handles) do
			local handle = handles[index]
			handle.fill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)
			for _, line in pairs(handle.outline) do
				line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
			end
			for _, mark in pairs(handle.marks) do
				mark:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.95)
			end
			handle.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		end
	end)
end
