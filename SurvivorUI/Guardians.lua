-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the guardians, a small list without a background.
--
-- One line a lair (the game's AZS_LAIRS): the guardian's name, where it
-- stands (SPAWNED in green, its health while awake, or, slain, the time until
-- its lair is claimed again, in red), how far it is, and a little arrow
-- toward it. The guardians alive come first, then the empty lairs, each the
-- nearest first; a line passes another only once it is 10 yards nearer, so
-- the list holds still while you run. The first line, the one to head for, is
-- lit faintly in its color. A name too long for its room goes by its first
-- words' initials ("K. Taskmaster").
--
-- The client cannot tell which way the hero faces, so the arrows turn with the
-- way the hero faces (the game sends it from 0.97; before, the way walked):
-- straight up is straight ahead, and they turn smoothly. /sui guardians north
-- points them north up instead, as the minimap does.
--
-- Over the list, the achievement "Slay four guardians before 8:00": how many
-- fell before 8:00 and the time left, green once four did.
--
-- Walking straight at a guardian turns its arrow gold, with a glow; within 10
-- yards of a living one, its line (or stretch) flashes.
--
-- Or, with "Guardians as a bar in the run tracker" (/sui guardians bar), a bar
-- inside the tracker, under its experience: a stretch a lair, in the lairs'
-- order, green while its guardian is there (orange while awake) with its arrow
-- in the middle (while awake, its health in its place: the fight is right
-- there), red once slain with the time until its lair is claimed again;
-- over the bar, a thin line with the 8:00 achievement.
--
-- Or only a count (the options, Run tracker): one line in the tracker, how
-- many lairs hold their guardian, "3 / 5 alive", orange while one is awake.
--
-- Each lair wears its own mark, a heraldic charge (Art\LairMarks: crossed
-- swords, a shield, a crown, a chalice, a fleur-de-lis, a war hammer, a tower,
-- a helm), by its place among the run's lairs: the same mark on its stretch of
-- the bar, its line of the list, the count, its pin on the minimap, its boss
-- bar and the last runs, dimmed while the lair is empty. Off with the option
-- "Lair marks". The lair the game's red flag points at (from 0.102) has its
-- mark glowing gold, in place of the flag (the Minimap tab, "The game's flag").
--
-- Hold Alt to move it; /sui guardians hides it.

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"

local WIDTH = 210
local ROW = 14
local CELLS = 8               -- the arrow sheet: 8 x 8 arrows, each turned 360/64 more
local GOAL, GOAL_TIME = 4, 480
local STEP = 1.5              -- yards walked before the way walked counts
local MARGIN = 10             -- yards nearer before a line passes another
local TURN = 8                -- how quickly an arrow turns to its way (per second)
local ARROW, NEAR = 12, 15    -- an arrow's size, and the nearest living guardian's
local AHEAD = 0.26            -- radians either side of straight ahead (15 degrees)
local CLOSE = 10              -- yards: a living guardian this near flashes
local GOLD = { 1.00, 0.85, 0.25 }

local MUTED = { 0.55, 0.55, 0.58 }
local SPAWNED = { 0.30, 1.00, 0.40 }
local AWAKE = { 1.00, 0.55, 0.15 }
local RESPAWN = { 1.00, 0.28, 0.22 }
local NAME = { 0.88, 0.88, 0.90 }
local GREEN = { 0.35, 0.90, 0.40 }
local HELD = { 0.30, 0.80, 0.35 }  -- the bar's green, the tracker timeline's
-- The living by how near: the nearest lightest, the farthest darkest.
local NEARNESS = {
	{ 0.78, 1.00, 0.62 }, { 0.36, 0.86, 0.40 }, { 0.15, 0.56, 0.22 }, { 0.06, 0.30, 0.10 },
}
local BAR_HEIGHT, BAR_GAP, BAR_TOP = 9, 3, 6
local LINE = 12                    -- the thin line over the bar
local MARK_KINDS = 8               -- the marks' sheet: 4 x 2
local MARK = 13                    -- a mark's size on the bar
local ROW_MARK = 12                -- on a line of the list
local COUNT_MARK = 11              -- in the count
local MARK_NAMES = { "Crossed swords", "Shield", "Crown", "Chalice", "Fleur-de-lis", "War hammer", "Tower", "Helm" }

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.guardians == nil then
		SurvivorUIDB.guardians = true
	end
	return SurvivorUIDB
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

------------------------------------------------------------------------------
-- The lairs' marks.

-- Each lair's mark, 1 to 8 by its place among the run's lairs (a ninth lair
-- starts them over): [place] = mark. Empty with the marks off.
function SurvivorUI_LairMarks(lairs)
	local marks = {}
	if Settings().guardianMarks == false then
		return marks
	end
	lairs = lairs or (AZS_GetLairs and AZS_GetLairs()) or {}
	local places = {}
	for index = 1, table.getn(lairs) do
		table.insert(places, tonumber(Field(lairs[index], "index", 1)) or index)
	end
	table.sort(places)
	for rank = 1, table.getn(places) do
		marks[places[rank]] = math.mod(rank - 1, MARK_KINDS) + 1
	end
	return marks
end

-- The mark of the guardian with this unit id (a boss bar's), nil for none.
function SurvivorUI_GuardianMark(id)
	id = tonumber(id)
	if not id or Settings().guardianMarks == false then
		return nil
	end
	local lairs = AZS_GetLairs and AZS_GetLairs() or {}
	for index = 1, table.getn(lairs) do
		if tonumber(Field(lairs[index], "id", 4)) == id then
			return SurvivorUI_LairMarks(lairs)[tonumber(Field(lairs[index], "index", 1)) or index]
		end
	end
end

function SurvivorUI_LairMarkName(mark)
	return mark and MARK_NAMES[mark]
end

-- A texture showing a mark in its own colors, dimmed for an empty lair;
-- hidden for none.
function SurvivorUI_SetLairMark(texture, mark, dim)
	if not mark then
		texture:Hide()
		return
	end
	local column, line = math.mod(mark - 1, 4), math.floor((mark - 1) / 4)
	texture:SetTexture(ART.."LairMarks")
	texture:SetTexCoord(column / 4, (column + 1) / 4, line / 2, (line + 1) / 2)
	if dim then
		texture:SetVertexColor(0.5, 0.5, 0.5, 0.8)
	else
		texture:SetVertexColor(1, 1, 1, 1)
	end
	texture:Show()
end

-- An angle brought within half a turn either way.
local function Wrap(angle)
	while angle > math.pi do
		angle = angle - 2 * math.pi
	end
	while angle < -math.pi do
		angle = angle + 2 * math.pi
	end
	return angle
end

------------------------------------------------------------------------------
-- The frame: the title and the goal, then a line a lair.

local frame = CreateFrame("Frame", "SurvivorUIGuardians", UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(ROW)
frame:SetMovable(true)
frame:Hide()

local header = frame:CreateFontString(nil, "OVERLAY")
header:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
header:SetTextColor(1, 0.82, 0)
header:SetText("Guardians")

local goal = frame:CreateFontString(nil, "OVERLAY")
goal:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
goal:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)

local rows = {}

-- The game's flag, ours (MapPins.lua, the options' Minimap tab): a gold glow
-- breathing behind the mark of the lair it points at.
local function FlagGlow(parent, mark, layer)
	local glow = parent:CreateTexture(nil, layer)
	glow:SetTexture(ART.."PaceGlow")
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(1, 0.82, 0.2)
	glow:SetPoint("CENTER", mark, "CENTER", 0, 0)
	glow:Hide()
	return glow
end

-- A line: the name on the left; on the right, where it stands, how far, and
-- the arrow last of all.
local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = {}
	local top = -ROW * index - 2
	-- The arrow over a dark one a little larger, to stand out on anything.
	row.shadow = frame:CreateTexture(nil, "ARTWORK")
	row.shadow:SetTexture(ART.."GuardianArrow")
	row.shadow:SetVertexColor(0, 0, 0, 0.85)
	row.shadow:SetPoint("CENTER", frame, "TOPRIGHT", -6, top - 6)
	row.glow = frame:CreateTexture(nil, "BORDER")
	row.glow:SetTexture(ART.."PaceGlow")
	row.glow:SetBlendMode("ADD")
	row.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	row.glow:SetPoint("CENTER", frame, "TOPRIGHT", -6, top - 6)
	row.glow:Hide()
	row.arrow = frame:CreateTexture(nil, "OVERLAY")
	row.arrow:SetTexture(ART.."GuardianArrow")
	row.arrow:SetPoint("CENTER", frame, "TOPRIGHT", -6, top - 6)
	-- Within 10 yards: the whole line flashes.
	row.flash = frame:CreateTexture(nil, "BACKGROUND")
	row.flash:SetTexture(FLAT)
	row.flash:SetBlendMode("ADD")
	row.flash:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, top + 1)
	row.flash:SetWidth(WIDTH + 6)
	row.flash:SetHeight(ROW)
	row.flash:Hide()
	row.yards = frame:CreateFontString(nil, "OVERLAY")
	row.yards:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	row.yards:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, top - 1)
	row.yards:SetJustifyH("RIGHT")
	row.yards:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	row.state = frame:CreateFontString(nil, "OVERLAY")
	row.state:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	row.state:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -57, top - 1)
	row.state:SetJustifyH("RIGHT")
	row.name = frame:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
	row.name:SetHeight(12)
	row.name:SetJustifyH("LEFT")
	row.top, row.room = top, 0
	-- Its lair's mark, before the name.
	row.mark = frame:CreateTexture(nil, "ARTWORK")
	row.mark:SetWidth(ROW_MARK)
	row.mark:SetHeight(ROW_MARK)
	row.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, top + 1)
	row.mark:Hide()
	row.flagGlow = FlagGlow(frame, row.mark, "BORDER")
	-- The line to head for: a faint wash of its color, fading to the right.
	row.light = frame:CreateTexture(nil, "BACKGROUND")
	row.light:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	row.light:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, top + 1)
	row.light:SetWidth(WIDTH + 6)
	row.light:SetHeight(ROW)
	row.light:Hide()
	rows[index] = row
	return row
end

local NAME_ROOM = WIDTH - 118

-- A name in its room (less a mark's): whole if it fits; else its first words
-- by their initial, the last whole ("K. Taskmaster"); else cut short.
local function SetName(text, name, taken)
	local room = NAME_ROOM - (taken or 0)
	text:SetWidth(0)
	text:SetText(name)
	if text:GetStringWidth() > room then
		local words = {}
		for word in string.gfind(name, "%S+") do
			table.insert(words, word)
		end
		if table.getn(words) > 1 then
			local short = ""
			for index = 1, table.getn(words) - 1 do
				short = short..string.sub(words[index], 1, 1)..". "
			end
			text:SetText(short..words[table.getn(words)])
		end
	end
	-- Still too long (one long word, or a name with no spaces): cut, letter by
	-- letter, whole characters only.
	local shown = text:GetText() or ""
	while text:GetStringWidth() > room and string.len(shown) > 2 do
		shown = string.gsub(shown, "[%z\1-\127\194-\244][\128-\191]*%.?%.?$", "")
		text:SetText(shown.."..")
	end
	text:SetWidth(room)
end

local function HideRow(row)
	row.mark:Hide()
	row.light:Hide()
	row.arrow:Hide()
	row.shadow:Hide()
	row.glow:Hide()
	row.flash:Hide()
	row.name:Hide()
	row.state:Hide()
	row.yards:Hide()
	row.place = nil
	row.shownName = nil
	row.flagged = nil
end

-- The arrow turned by angle (radians, clockwise from straight up): the cell of
-- the sheet nearest to it.
local function Point(texture, angle)
	local cells = CELLS * CELLS
	local k = math.mod(math.floor(angle / (2 * math.pi) * cells + 0.5), cells)
	if k < 0 then
		k = k + cells
	end
	local column, line = math.mod(k, CELLS), math.floor(k / CELLS)
	texture:SetTexCoord(column / CELLS, (column + 1) / CELLS, line / CELLS, (line + 1) / CELLS)
end

------------------------------------------------------------------------------
-- The run: when each guardian fell, the hero's way, the lines' order.

local fallen = {}       -- [lair index] = the run second its guardian last fell
local lastState = {}    -- [lair index] = its state at the last look
local before = 0        -- guardians slain before 8:00
local lastTime          -- the run clock at the last look
local wayX, wayY        -- where the hero stood when the way was last taken
local heading           -- the way walked (radians, clockwise from north), nil until walked
local order = {}        -- the lairs' indexes, in the order shown
local wanted = {}       -- [lair index] = the way its arrow should point
local shownAngle = {}   -- [lair index] = the way its arrow points now, on its way there
local byPlace = {}      -- [lair index] = its entry at the last look (the bar reads it)
local active = false    -- a run with lairs, and the guardians on
local goalText, goalColor = "", MUTED  -- the achievement's line, for the bar too
local nearest           -- the lair of the nearest living guardian
local clock = 0         -- seconds, for the nearest arrow's breath
local handle            -- the list's move handle (Mover.lua), off while the bar stands in

local function NewRun()
	fallen, lastState, before, order = {}, {}, 0, {}
	wayX, wayY, heading = nil, nil, nil
end

local function Running()
	local phase = AZS_GetPhase and AZS_GetPhase()
	return phase == "playing" or phase == "choosing" or phase == "paused"
end

-- The way walked, from the hero's last few yards on the map.
local function Walked(heroX, heroY, span)
	if not wayX then
		wayX, wayY = heroX, heroY
		return
	end
	local east = (heroX - wayX) * span.across
	local south = (heroY - wayY) * span.down
	if east * east + south * south >= STEP * STEP then
		heading = math.atan2(east, -south)
		wayX, wayY = heroX, heroY
	end
end

-- Each awake guardian's health, by its id (the game's AZS_UNITS).
local function Healths()
	local out = {}
	for _, unit in pairs(AZS_UNITS or {}) do
		if Field(unit, "kind", 1) == "guardian" then
			local hp, hpm = tonumber(Field(unit, "hp", 4)) or 0, tonumber(Field(unit, "hpm", 5)) or 0
			out[tonumber(Field(unit, "id", 2)) or 0] = hpm > 0 and hp / hpm or nil
		end
	end
	return out
end

-- Whether line a should come before line b: the living before the empty;
-- then the nearer, by a margin.
local function Before(a, b)
	if a.alive ~= b.alive then
		return a.alive
	end
	return a.yards and b.yards and a.yards + MARGIN < b.yards
end

-- The order kept from the last look, a line moved only past those it beats.
local function Sorted(entries)
	local byPlace, list = {}, {}
	for _, entry in pairs(entries) do
		byPlace[entry.place] = entry
	end
	for _, place in pairs(order) do
		if byPlace[place] then
			table.insert(list, byPlace[place])
			byPlace[place] = nil
		end
	end
	for _, entry in pairs(entries) do
		if byPlace[entry.place] then
			table.insert(list, entry)
		end
	end
	local moved, passes = true, 0
	while moved and passes <= table.getn(list) do
		moved, passes = false, passes + 1
		for index = 1, table.getn(list) - 1 do
			if Before(list[index + 1], list[index]) then
				list[index], list[index + 1] = list[index + 1], list[index]
				moved = true
			end
		end
	end
	order = {}
	for index = 1, table.getn(list) do
		order[index] = list[index].place
	end
	return list
end

-- Four before 8:00. Before 8:00 every guardian slain counts (the game's
-- count, right after a reload too); after, the count stays as it was. A
-- function apart from Draw: the game's Lua (5.0, from the game's 0.101) lets
-- a function reach at most 32 of the file's locals.
local function DrawGoal(time)
	local slain = tonumber(AZS_RUN and AZS_RUN.gk) or 0
	if time < GOAL_TIME then
		before = math.max(before, slain)
	end
	if before >= GOAL then
		goal:SetText("4/4 by 8:00 · done")
		goal:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
	elseif time < GOAL_TIME then
		goal:SetText(before.."/4 by 8:00 · "..Clock(GOAL_TIME - time))
		goal:SetTextColor(0.9, 0.9, 0.92)
	else
		goal:SetText(before.."/4 by 8:00")
		goal:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	end
	local r, g, b = goal:GetTextColor()
	goalText, goalColor = goal:GetText() or "", { r, g, b }
end

local function Draw()
	local lairs = AZS_GetLairs and AZS_GetLairs() or {}
	local time = AZS_GetRunTime and AZS_GetRunTime() or 0
	-- A new run: the clock went back.
	if lastTime and time + 3 < lastTime then
		NewRun()
	end
	lastTime = time

	-- The hero's place: in the world's yards and the way faced, when the game
	-- sends them (0.97 on, every map); else on the map, the way walked.
	local px, py, facing
	if SurvivorUI_HeroWorld then
		px, py, facing = SurvivorUI_HeroWorld()
	end
	local heroX, heroY, span
	if not px then
		if SurvivorUI_HeroPlace then
			heroX, heroY = SurvivorUI_HeroPlace()
		end
		span = SurvivorUI_MapSpan and SurvivorUI_MapSpan()
	end
	if facing then
		heading = facing
	elseif heroX and span then
		Walked(heroX, heroY, span)
	end
	local north = Settings().guardiansNorth
	local healths = Healths()
	local since = AZS_LAIRS_UPDATED and (GetTime() - AZS_LAIRS_UPDATED) or 0
	if AZS_GetPhase and AZS_GetPhase() ~= "playing" then
		since = 0
	end

	-- Each lair: what it is and where, and its mark.
	local entries = {}
	local marks = SurvivorUI_LairMarks(lairs)
	for index = 1, table.getn(lairs) do
		local lair = lairs[index]
		local place = tonumber(Field(lair, "index", 1)) or index
		local state = Field(lair, "state", 2) or "asleep"
		-- A guardian just slain: its second, and one more before 8:00.
		if state == "empty" and lastState[place] and lastState[place] ~= "empty" then
			fallen[place] = time
			if time < GOAL_TIME then
				before = before + 1
			end
		end
		lastState[place] = state
		local entry = { place = place, state = state, alive = state ~= "empty", name = Field(lair, "name", 3) or "?",
			id = tonumber(Field(lair, "id", 4)) or 0, mark = marks[place],
			flag = tonumber(Field(lair, "flag", 11)) == 1 or nil }
		if state == "empty" then
			entry.left = (tonumber(Field(lair, "left", 5)) or -1) - since
		elseif state == "awake" then
			entry.share = healths[entry.id]
		elseif healths[entry.id] and healths[entry.id] < 1 then
			-- Hurt while the game still calls it asleep (feared or held from
			-- the first hit, it never turned on the hero): a fight all the same.
			entry.state = "awake"
			entry.share = healths[entry.id]
		end
		local east, south
		local lx, ly = tonumber(Field(lair, "x", 6)), tonumber(Field(lair, "y", 7))
		if px and lx and ly then
			east, south = SurvivorUI_WorldWay(px, py, lx, ly)
		else
			local mx = SurvivorUI_MapShare and SurvivorUI_MapShare(Field(lair, "mx", 9))
			local my = SurvivorUI_MapShare and SurvivorUI_MapShare(Field(lair, "my", 10))
			if heroX and span and mx and my then
				east, south = (mx - heroX) * span.across, (my - heroY) * span.down
			end
		end
		if east then
			entry.yards = math.sqrt(east * east + south * south)
			local bearing = math.atan2(east, -south)
			wanted[place] = (north or not heading) and bearing or bearing - heading
		else
			wanted[place] = nil
		end
		table.insert(entries, entry)
	end

	byPlace = {}
	nearest = nil
	for _, entry in pairs(entries) do
		byPlace[entry.place] = entry
		if entry.alive and entry.yards and (not nearest or entry.yards < byPlace[nearest].yards) then
			nearest = entry.place
		end
	end
	local list = Sorted(entries)
	for index = 1, table.getn(list) do
		local entry = list[index]
		local row = Row(index)
		row.place = entry.place
		-- The mark first, the name after it.
		local room = entry.mark and ROW_MARK + 2 or 0
		if row.room ~= room then
			row.room = room
			row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", room, row.top)
			row.shownName = nil
		end
		SurvivorUI_SetLairMark(row.mark, entry.mark, entry.state == "empty")
		row.flagged = entry.flag and SurvivorUI_GameFlag and SurvivorUI_GameFlag() == "ours"
		if row.shownName ~= entry.name then
			row.shownName = entry.name
			SetName(row.name, entry.name, room)
		end
		if entry.state == "empty" then
			row.name:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			if entry.left and entry.left > 0 then
				row.state:SetText(Clock(entry.left))
			else
				row.state:SetText("soon")
			end
			row.state:SetTextColor(RESPAWN[1], RESPAWN[2], RESPAWN[3])
			row.color = MUTED
		elseif entry.state == "awake" then
			local share = healths[entry.id]
			row.name:SetTextColor(AWAKE[1], AWAKE[2], AWAKE[3])
			row.state:SetText(share and string.format("%d%%", share * 100 + 0.5) or "AWAKE")
			row.state:SetTextColor(AWAKE[1], AWAKE[2], AWAKE[3])
			row.color = AWAKE
		else
			row.name:SetTextColor(NAME[1], NAME[2], NAME[3])
			row.state:SetText("SPAWNED")
			row.state:SetTextColor(SPAWNED[1], SPAWNED[2], SPAWNED[3])
			row.color = SPAWNED
		end
		row.yards:SetText(entry.yards and (math.floor(entry.yards + 0.5).." yd") or "")
		if index == 1 then
			local color = entry.state == "empty" and RESPAWN or entry.state == "awake" and AWAKE or SPAWNED
			-- The fade and the color set together: a color set after would
			-- undo the fade.
			if row.light.SetGradientAlpha then
				row.light:SetGradientAlpha("HORIZONTAL", color[1], color[2], color[3], 0.22, color[1], color[2], color[3], 0.03)
			else
				row.light:SetVertexColor(color[1], color[2], color[3], 0.14)
			end
			row.light:Show()
		else
			row.light:Hide()
		end
		if wanted[entry.place] then
			row.arrow:Show()
			row.shadow:Show()
		else
			row.arrow:Hide()
			row.shadow:Hide()
		end
		row.name:Show()
		row.state:Show()
		row.yards:Show()
	end
	for index = table.getn(list) + 1, table.getn(rows) do
		HideRow(rows[index])
	end
	frame:SetHeight(ROW * (table.getn(list) + 1) + 2)

	DrawGoal(time)
	return table.getn(list)
end

------------------------------------------------------------------------------
-- The bar in the run tracker.

-- A thin white outline, shown under the mouse on what a click can target.
local function Outline(frame)
	local edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = frame:CreateTexture(nil, "OVERLAY")
		edge:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		edge:SetVertexColor(1, 1, 1, 0.9)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetHeight(1)
			edge:SetPoint(side.."LEFT", frame, side.."LEFT", 0, 0)
			edge:SetPoint(side.."RIGHT", frame, side.."RIGHT", 0, 0)
		else
			edge:SetWidth(1)
			edge:SetPoint("TOP"..side, frame, "TOP"..side, 0, 0)
			edge:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side, 0, 0)
		end
		edge:Hide()
		table.insert(edges, edge)
	end
	frame:SetScript("OnEnter", function()
		if this.target then
			for _, edge in pairs(edges) do
				edge:Show()
			end
		end
	end)
	frame:SetScript("OnLeave", function()
		for _, edge in pairs(edges) do
			edge:Hide()
		end
	end)
end

local bar
local counter                   -- the count, a line in the tracker
local segments = {}

local function Segment(index)
	local segment = segments[index]
	if segment then
		return segment
	end
	segment = {}
	-- The stretch's own room (dark, seen where an awake guardian's health has
	-- drained), its fill over it, the shadow, the arrow on top.
	segment.back = bar:CreateTexture(nil, "BACKGROUND")
	segment.back:SetTexture(FLAT)
	segment.back:SetVertexColor(0.12, 0.12, 0.15, 0.9)
	segment.fill = bar:CreateTexture(nil, "BORDER")
	segment.fill:SetTexture(FLAT)
	segment.fill:SetPoint("TOPLEFT", segment.back, "TOPLEFT", 0, 0)
	segment.fill:SetHeight(BAR_HEIGHT)
	segment.shadow = bar:CreateTexture(nil, "ARTWORK")
	segment.shadow:SetTexture(ART.."GuardianArrow")
	segment.shadow:SetVertexColor(0, 0, 0, 0.85)
	segment.shadow:SetPoint("CENTER", segment.back, "CENTER", 0, 0)
	segment.glow = bar:CreateTexture(nil, "ARTWORK")
	segment.glow:SetTexture(ART.."PaceGlow")
	segment.glow:SetBlendMode("ADD")
	segment.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	segment.glow:SetPoint("CENTER", segment.back, "CENTER", 0, 0)
	segment.glow:Hide()
	segment.arrow = bar:CreateTexture(nil, "OVERLAY")
	segment.arrow:SetTexture(ART.."GuardianArrow")
	segment.arrow:SetPoint("CENTER", segment.back, "CENTER", 0, 0)
	segment.flash = bar:CreateTexture(nil, "ARTWORK")
	segment.flash:SetTexture(FLAT)
	segment.flash:SetBlendMode("ADD")
	segment.flash:SetAllPoints(segment.back)
	segment.flash:Hide()
	-- With the health in the tracker, a click on a living one's stretch targets
	-- it (by its name, the only way 1.12 has: an elite of the same name may
	-- come first).
	segment.button = CreateFrame("Frame", nil, bar)
	segment.button:SetAllPoints(segment.back)
	segment.button:SetScript("OnMouseUp", function()
		if this.target and TargetByName then
			TargetByName(this.target, true)
		end
	end)
	Outline(segment.button)
	segment.color = { 1, 1, 1 }
	segment.time = bar:CreateFontString(nil, "OVERLAY")
	segment.time:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	segment.time:SetPoint("CENTER", segment.back, "CENTER", 0, 0)
	segment.time:SetTextColor(1, 1, 1)
	-- Its lair's mark at its left end, over the fill.
	segment.mark = bar:CreateTexture(nil, "OVERLAY")
	segment.mark:SetWidth(MARK)
	segment.mark:SetHeight(MARK)
	segment.mark:SetPoint("LEFT", segment.back, "LEFT", -1, 0)
	segment.mark:Hide()
	segment.flagGlow = FlagGlow(bar, segment.mark, "ARTWORK")
	segment.shift = 0
	segments[index] = segment
	return segment
end

-- The arrow and the words in the middle of what the mark leaves of the
-- stretch.
local function Middle(segment, shift)
	if segment.shift == shift then
		return
	end
	segment.shift = shift
	for _, piece in pairs({ segment.shadow, segment.glow, segment.arrow, segment.time }) do
		piece:ClearAllPoints()
		piece:SetPoint("CENTER", segment.back, "CENTER", shift, 0)
	end
end

local function Docked()
	return Settings().guardiansDocked
end

-- For the last runs (RunHistory.lua): the guardians as the run tracker shows
-- them, nil when they are not in it: the count, or each lair's stretch of the
-- bar (its color, how full, its words: "alive" in green, the health awake in
-- orange, the time to its return slain in red) and the 8:00 achievement's
-- line. From the last look, which holds as the run ends.
function SurvivorUI_GuardianSnapshot()
	if not (Settings().guardians and Docked() and next(byPlace)) then
		return nil
	end
	local places = {}
	for place in pairs(byPlace) do
		table.insert(places, place)
	end
	table.sort(places)
	local living = {}
	for _, place in pairs(places) do
		if byPlace[place].alive and byPlace[place].yards then
			table.insert(living, place)
		end
	end
	table.sort(living, function(a, b) return byPlace[a].yards < byPlace[b].yards end)
	local rank = {}
	for index = 1, table.getn(living) do
		rank[living[index]] = index
	end
	local shot = {
		count = Settings().guardiansCount and true or nil, alive = 0, awake = 0,
		goal = goalText, goalColor = { goalColor[1], goalColor[2], goalColor[3] }, lairs = {},
	}
	for _, place in pairs(places) do
		local entry = byPlace[place]
		local share, color, text = 1, nil, nil
		if not entry.alive then
			color = RESPAWN
			if entry.left and entry.left > 0 then
				text = Clock(entry.left)
			end
		elseif entry.state == "awake" then
			color, share = AWAKE, entry.share or 1
			text = entry.share and string.format("%d%%", entry.share * 100 + 0.5) or "FIGHT"
			shot.awake = shot.awake + 1
		else
			-- In the bar its arrow; in the copy, which has no arrow, a word.
			color = NEARNESS[math.min(rank[place] or 1, table.getn(NEARNESS))]
			text = "alive"
		end
		if entry.alive then
			shot.alive = shot.alive + 1
		end
		table.insert(shot.lairs, { color = { color[1], color[2], color[3] }, share = share, text = text,
			mark = entry.mark, empty = (not entry.alive) or nil,
			flag = entry.flag and SurvivorUI_GameFlag and SurvivorUI_GameFlag() == "ours" or nil })
	end
	return shot
end

-- Laid out by the run tracker (Tracker.lua) under its experience, at y; the
-- y under it comes back, so the tracker makes room.
function SurvivorUI_GuardianBar(head, y)
	if not (active and Docked()) then
		if bar then
			bar:Hide()
		end
		if counter then
			counter:Hide()
		end
		return y
	end
	-- Only a count: "Guardians   3 / 5 alive".
	if Settings().guardiansCount then
		if bar then
			bar:Hide()
		end
		if not counter then
			counter = CreateFrame("Frame", nil, head)
			counter:SetHeight(LINE)
			counter.title = counter:CreateFontString(nil, "OVERLAY")
			counter.title:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
			counter.title:SetPoint("LEFT", counter, "LEFT", 0, 0)
			counter.title:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			counter.title:SetText("Guardians")
			counter.value = counter:CreateFontString(nil, "OVERLAY")
			counter.value:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
			counter.value:SetPoint("RIGHT", counter, "RIGHT", 0, 0)
			counter.marks = {}
		end
		-- Between the two, the lairs' marks in their order, the empty dimmed.
		local places = {}
		for place in pairs(byPlace) do
			table.insert(places, place)
		end
		table.sort(places)
		local marked = 0
		for index = 1, table.getn(places) do
			local entry = byPlace[places[index]]
			if entry.mark then
				marked = marked + 1
				local texture = counter.marks[marked]
				if not texture then
					texture = counter:CreateTexture(nil, "ARTWORK")
					texture:SetWidth(COUNT_MARK)
					texture:SetHeight(COUNT_MARK)
					texture:SetPoint("LEFT", counter.title, "RIGHT", 4 + (marked - 1) * (COUNT_MARK + 1), 0)
					counter.marks[marked] = texture
				end
				SurvivorUI_SetLairMark(texture, entry.mark, not entry.alive)
			end
		end
		for index = marked + 1, table.getn(counter.marks) do
			counter.marks[index]:Hide()
		end
		local alive, total, awake = 0, 0, 0
		for _, entry in pairs(byPlace) do
			total = total + 1
			if entry.alive then
				alive = alive + 1
			end
			if entry.state == "awake" then
				awake = awake + 1
			end
		end
		local color = awake > 0 and AWAKE or (alive > 0 and SPAWNED or MUTED)
		counter.value:SetText(alive.." / "..total.." alive")
		counter.value:SetTextColor(color[1], color[2], color[3])
		counter:SetWidth(head:GetWidth())
		counter:ClearAllPoints()
		counter:SetPoint("TOP", head, "TOP", 0, y - BAR_TOP)
		counter:Show()
		return y - BAR_TOP - LINE
	end
	if counter then
		counter:Hide()
	end
	if not bar then
		bar = CreateFrame("Frame", nil, head)
		bar:SetHeight(BAR_HEIGHT)
		bar.title = bar:CreateFontString(nil, "OVERLAY")
		bar.title:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
		bar.title:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
		bar.title:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		bar.title:SetText("Guardians")
		bar.goal = bar:CreateFontString(nil, "OVERLAY")
		bar.goal:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
		bar.goal:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 3)
	end
	local width = head:GetWidth()
	bar:SetWidth(width)
	bar:ClearAllPoints()
	bar:SetPoint("TOP", head, "TOP", 0, y - BAR_TOP - LINE)
	bar.goal:SetText(goalText)
	bar.goal:SetTextColor(goalColor[1], goalColor[2], goalColor[3])
	bar:Show()
	local places = {}
	for place in pairs(byPlace) do
		table.insert(places, place)
	end
	table.sort(places)
	local count = table.getn(places)
	local each = (width - BAR_GAP * (count - 1)) / math.max(count, 1)
	-- The living, nearest first, for their greens.
	local living = {}
	for _, place in pairs(places) do
		if byPlace[place].alive and byPlace[place].yards then
			table.insert(living, place)
		end
	end
	table.sort(living, function(a, b) return byPlace[a].yards < byPlace[b].yards end)
	local rank = {}
	for index = 1, table.getn(living) do
		rank[living[index]] = index
	end
	for index = 1, count do
		local place = places[index]
		local entry = byPlace[place]
		local segment = Segment(index)
		segment.back:ClearAllPoints()
		segment.back:SetPoint("TOPLEFT", bar, "TOPLEFT", (index - 1) * (each + BAR_GAP), 0)
		segment.back:SetWidth(each)
		segment.back:SetHeight(BAR_HEIGHT)
		segment.back:Show()
		-- Awake, the fill is its health, draining from the right.
		local share = 1
		local color
		if not entry.alive then
			color = RESPAWN
		elseif entry.state == "awake" then
			color = AWAKE
			share = entry.share or 1
		else
			color = NEARNESS[math.min(rank[place] or 1, table.getn(NEARNESS))]
		end
		segment.fill:SetWidth(math.max(1, each * share))
		segment.fill:SetVertexColor(color[1], color[2], color[3], 0.9)
		segment.fill:Show()
		SurvivorUI_SetLairMark(segment.mark, entry.mark, not entry.alive)
		segment.flagged = entry.flag and SurvivorUI_GameFlag and SurvivorUI_GameFlag() == "ours"
		Middle(segment, entry.mark and math.floor(MARK / 2) or 0)
		local clickable = entry.alive
		segment.button.target = clickable and entry.name or nil
		segment.button:EnableMouse(clickable and true or false)
		local fighting = entry.state == "awake"
		if entry.alive and not fighting and wanted[place] then
			segment.place = place
			segment.arrow:Show()
			segment.shadow:Show()
		else
			segment.place = nil
			segment.arrow:Hide()
			segment.shadow:Hide()
		end
		if fighting then
			segment.time:SetText(entry.share and string.format("%d%%", entry.share * 100 + 0.5) or "FIGHT")
			segment.time:Show()
		elseif not entry.alive and entry.left and entry.left > 0 then
			segment.time:SetText(Clock(entry.left))
			segment.time:Show()
		else
			segment.time:Hide()
		end
	end
	for index = count + 1, table.getn(segments) do
		segments[index].mark:Hide()
		segments[index].fill:Hide()
		segments[index].back:Hide()
		segments[index].arrow:Hide()
		segments[index].shadow:Hide()
		segments[index].glow:Hide()
		segments[index].flash:Hide()
		segments[index].time:Hide()
		segments[index].place = nil
		segments[index].flagged = nil
	end
	return y - BAR_TOP - LINE - BAR_HEIGHT
end

-- Every frame, each arrow turns a little toward its way, the short way round.
-- The nearest living guardian's arrow is larger and breathes; its shadow
-- turns with it. Walked straight at, it turns gold over a glow; within 10
-- yards, its line or stretch flashes.
local function TurnOne(piece, place, step)
	local arrow, shadow = piece.arrow, piece.shadow
	local target = place and wanted[place]
	if not target then
		piece.glow:Hide()
		piece.flash:Hide()
		return
	end
	local now = shownAngle[place] or target
	now = Wrap(now + Wrap(target - now) * step)
	shownAngle[place] = now
	Point(arrow, now)
	Point(shadow, now)
	local size = ARROW
	if place == nearest then
		size = NEAR * (1 + 0.12 * math.sin(clock * 5))
	end
	arrow:SetWidth(size)
	arrow:SetHeight(size)
	shadow:SetWidth(size + 4)
	shadow:SetHeight(size + 4)

	local ahead = heading and not Settings().guardiansNorth and math.abs(Wrap(now)) < AHEAD
	local color = ahead and GOLD or piece.color or { 1, 1, 1 }
	arrow:SetVertexColor(color[1], color[2], color[3])
	if ahead then
		local glow = size * (2.6 + 0.3 * math.sin(clock * 6))
		piece.glow:SetWidth(glow)
		piece.glow:SetHeight(glow)
		piece.glow:SetAlpha(0.9)
		piece.glow:Show()
	else
		piece.glow:Hide()
	end

	local entry = byPlace[place]
	if entry and entry.alive and entry.yards and entry.yards <= CLOSE then
		piece.flash:SetVertexColor(0.55, 1, 0.6)
		piece.flash:SetAlpha(0.15 + 0.35 * (math.sin(clock * 10) + 1) / 2)
		piece.flash:Show()
	else
		piece.flash:Hide()
	end
end

-- The flagged lair's glow breathes, every frame, while its mark shows.
local function Breathe(piece)
	if piece.flagged and piece.mark:IsShown() then
		local size = piece.mark:GetWidth() * (2.4 + 0.35 * math.sin(clock * 4))
		piece.flagGlow:SetWidth(size)
		piece.flagGlow:SetHeight(size)
		piece.flagGlow:SetAlpha(0.6 + 0.3 * math.sin(clock * 4))
		piece.flagGlow:Show()
	else
		piece.flagGlow:Hide()
	end
end

local function Turn(elapsed)
	clock = clock + elapsed
	local step = math.min(1, elapsed * TURN)
	for _, row in pairs(rows) do
		TurnOne(row, row.place, step)
		Breathe(row)
	end
	for _, segment in pairs(segments) do
		TurnOne(segment, segment.place, step)
		Breathe(segment)
	end
end

-- The reading goes on while there is a run with lairs, the list shown or the
-- bar in the tracker.
local updater = CreateFrame("Frame")
local wait = 0
updater:SetScript("OnUpdate", function()
	if not active then
		return
	end
	wait = wait + arg1
	if wait >= 0.1 then
		wait = 0
		frame:SetAlpha(Draw() == 0 and 0 or 1)
	end
	Turn(arg1)
end)

-- The list shown during a run with lairs on its map, unless the bar stands in.
local watcher = CreateFrame("Frame")
local watchWait = 0
watcher:SetScript("OnUpdate", function()
	watchWait = watchWait + arg1
	if watchWait < 0.5 then
		return
	end
	watchWait = 0
	local lairs = AZS_GetLairs and AZS_GetLairs()
	active = Settings().guardians and Running() and lairs and table.getn(lairs) > 0 and true or false
	if active and not Docked() then
		frame:Show()
	else
		frame:Hide()
	end
	-- With the bar in the tracker, the list has no place to move.
	if handle then
		handle.disabled = Docked() and true or nil
	end
end)

------------------------------------------------------------------------------
-- On and off, the arrows' north, its place.

function SurvivorUI_ToggleGuardians(argument)
	local settings = Settings()
	if argument == "bar" then
		settings.guardiansCount = nil
		settings.guardiansDocked = not settings.guardiansDocked
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the guardians "..(settings.guardiansDocked
			and "are a bar in the run tracker." or "are a list beside the run tracker again."))
		return
	end
	if argument == "north" then
		settings.guardiansNorth = not settings.guardiansNorth or nil
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the guardians' arrows "..(settings.guardiansNorth
			and "point north up, as the minimap." or "turn with the way you walk."))
		return
	end
	settings.guardians = not settings.guardians
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the guardians' list is "..(settings.guardians and "on." or "off."))
end

local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.guardiansLeft = math.floor(frame:GetLeft() + 0.5)
	SurvivorUIDB.guardiansTop = math.floor(frame:GetTop() + 0.5)
end

-- Its place: against the run tracker's left side, tops level, until moved.
local function RestorePlace()
	frame:ClearAllPoints()
	local tracker = getglobal("SurvivorUITracker")
	if SurvivorUIDB and SurvivorUIDB.guardiansLeft and SurvivorUIDB.guardiansTop then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB.guardiansLeft, SurvivorUIDB.guardiansTop)
	elseif tracker then
		-- Past the tracker's shade (8 to its left), and a little gap.
		frame:SetPoint("TOPRIGHT", tracker, "TOPLEFT", -14, 0)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -260)
	end
end

if SurvivorUI_RegisterMover then
	handle = SurvivorUI_RegisterMover(frame, "Guardians", SavePlace, nil, RestorePlace)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
end)
