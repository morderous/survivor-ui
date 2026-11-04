-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: marks on the world itself, from the game's 0.139.2 world
-- anchors (AZS_GetWorldAnchors, AZS_ProjectWorldAnchors,
-- AZS_GetDownedPartyMembers), each its own switch (the options, World
-- markers):
--
-- - Friends down (co-op): over each, a gold cross, their name and how far;
--   their party frame reads the yards too (SurvivorUI_DownedYards).
-- - Caches: a chest over each one still there, with how far; with Light
--   beams, in a column of gold light, the chest floating near its top (as
--   SurvivorUI Classic's 0.2.10).
-- - Lairs: the lair's mark and its guardian's name over a lair whose guardian
--   sleeps there (grey); awake, over the guardian itself (orange), following
--   it out of the lair; slain, back over the lair, greyed, with the time until
--   the lair is claimed again in red (AZS_LAIRS' left, as Guardians.lua).
-- - Arrows: on a ring round the hero, toward the friends down, the caches and
--   the lairs out of sight, the nearest few, with how far.
-- - Marks drawn (the Raid marks tab, "Draw the enemies' marks"): over every
--   boss, guardian and elite of a kind ticked there, that kind's mark, all at
--   once and with no target taken (Marks.lua leaves those kinds then). Only
--   this player sees them; the heroes' marks stay the game's raid marks.
-- - Explosive orbs (the Explosive affix): a pulsing mark over each.
-- - Bars (a test): over each elite, guardian and boss, its name and health
--   (AZS_UNITS) in its kind's color, with no nameplate.
-- - Range rings: the reach of the build's longest spell round the hero, on
--   the minimap (its yards across, MapPins.lua) and on the ground (dots
--   along points of the circle, each a spot by offset), each its own look
--   (the options' Range ring tab).
-- - Guardians' rings: where a sleeping guardian wakes, and how far from its
--   lair an awake one lets you go before it gives up (the game's rule, read
--   in its 0.139.2), with a warning in your last yards; on the minimap too
--   (MapPins.lua).
--
-- An enemy whose Survivor Plates plate shows (SurvivorPlates_PlateShows) is
-- left to it: the plate names it and wears the mark drawn beside its bar.
--
-- The catalog is read four times a second; the places every frame, after the
-- camera (AZS_RegisterWorldAnchorFrameHandler), so nothing trails. Seen in the
-- 0.139.2 test game (2026-11-02): caches and lairs take no "overhead" (only
-- "position"), units both; a place off the screen comes without x and y; the
-- answers come in the requests' order. An anchor's offset may be any number
-- of yards, so any spot of the world is one anchor and an offset away: the
-- hero's own (AZS_GetPlayerPosition), and a point six yards from it toward
-- what an arrow points at. The line between the two on the screen is the
-- arrow's way.

if SurvivorUI_Standby then return end

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local READ_EVERY = 0.25
local CELLS = 8                  -- the arrow sheet (Guardians.lua's): 8 x 8 arrows
-- The arrows' ring round the hero: a share of the screen's width across, of
-- its height up and down.
local RING_WIDE, RING_TALL = 0.3, 0.3
local WAY = 6                    -- yards from the hero, for an arrow's way
local MOST_ARROWS = 6
local SPECIAL = { "elite", "guardian", "boss", "finalBoss", "cache", "guardianLair", "downedPartyMember" }
local ORB = "Explosive Orb"
-- Each kind's color, for its bar and its name.
local COLORS = {
	elite = { 0.40, 0.90, 0.45 }, guardian = { 1.00, 0.62, 0.22 },
	boss = { 0.78, 0.48, 1.00 }, finalBoss = { 1.00, 0.45, 0.20 },
}
local MARK_KIND = { elite = "elite", guardian = "guardian", boss = "boss", finalBoss = "boss" }
local GOLD = { 1.00, 0.82, 0.00 }
local RESPAWN = { 1.00, 0.28, 0.22 }  -- an empty lair's time, as Guardians.lua's
local DEFAULTS = {
	worldDowned = true, worldCaches = true, worldLairs = true, worldArrows = true,
	worldOrbs = true, worldBars = false, markDrawn = true, worldBeams = true,
	rangeMinimap = true, rangeWorld = true,
	-- The guardians' rings (below, and MapPins.lua's on the minimap).
	leashWake = true, leashReset = true, leashWarn = true, leashMinimap = true,
}
-- A cache's beam (Lucas, 2026-11-02, after the world markers of the game's
-- live client): a column of light BEAM_TALL yards up and BEAM_WIDE across, a
-- pool POOL_WIDE across on the ground, the chest floating near the top. Ours,
-- drawn flat over the world, so nothing hides behind it: dimmed where the
-- hero stands in front.
local BEAM_TALL, BEAM_WIDE, POOL_WIDE = 6, 2.4, 3.4
local BEAM_COLOR = { 1.00, 0.77, 0.27 }
-- The range rings (Lucas, 2026-11-02, after an idea of ProTecz's): as far as
-- the build's longest spell strikes (BuildList.lua, SurvivorUI_LongestReach),
-- round the hero: on the minimap along MAP_POINTS points of its circle, on
-- the ground along RING_POINTS (both on at first). Each its look (the
-- options' Range ring tab, 2026-11-03): its color, dots, dashes or a line
-- (on the minimap all of dots, round you of pieces, below), the dots' size,
-- the gap between them and how strong; round you its yards over it, on the
-- minimap a shade inside. Never more than MOST_DOTS dots round you,
-- MOST_MAP_DOTS on the minimap: the step between them widens first.
local RING_COLOR = { 0.55, 0.82, 1.00 }
local RING_POINTS, MAP_POINTS = 48, 64
local MOST_DOTS, MOST_MAP_DOTS = 360, 240
SurvivorUI_RANGE_COLORS = {
	{ "ice", "Light blue", RING_COLOR },
	{ "class", "Class color", nil },
	{ "gold", "Gold", { 1.00, 0.78, 0.15 } },
	{ "white", "White", { 1.00, 1.00, 1.00 } },
	{ "red", "Red", { 1.00, 0.28, 0.22 } },
	{ "orange", "Orange", { 1.00, 0.55, 0.15 } },
	{ "green", "Green", { 0.40, 1.00, 0.45 } },
	{ "teal", "Teal", { 0.30, 0.95, 0.90 } },
	{ "purple", "Purple", { 0.72, 0.48, 1.00 } },
	{ "pink", "Pink", { 1.00, 0.50, 0.80 } },
}
-- Each ring's first look: "World" round you, "Map" on the minimap (saved as
-- ringWorldSize, ringMapLook...). The minimap's line as thin as its ring was.
-- The guardians' (below): "Wake", the aggro ring, and "Leash", the reset
-- area, in orange; "LeashWarn", the reset area in your last yards, a line
-- (its size the reset area's and 2 more, its color going to red).
local RING_LOOK = {
	World = { Look = "dots", Color = "ice", Size = 6, Gap = 10, Alpha = 0.8, Yards = false },
	Map = { Look = "line", Color = "ice", Size = 3, Gap = 6, Alpha = 0.9, Shade = false },
	Wake = { Look = "dots", Color = "orange", Size = 5, Gap = 12, Alpha = 0.8 },
	Leash = { Look = "dashes", Color = "orange", Size = 7, Gap = 9, Alpha = 0.85 },
	LeashWarn = { Look = "line", Size = 9, Gap = 9, Alpha = 1 },
}
local looks = 0                  -- counts the changes of look, for the dots to take them
-- A line or dashes round you (as big as the screen with a reach of 30 yards,
-- where dots near enough to touch would be thousands): pieces of the
-- RingLine art stretched and turned (SurvivorUI_RangePiece), as thick as
-- LINE_SHARE of the dots' size, each no longer than PIECE_MOST times that,
-- never more than MOST_PIECES. BAND_UV: the art's band, of its height.
local LINE_SHARE, PIECE_MOST, MOST_PIECES = 0.6, 14, 300
local BAND_UV = 4 / 64

local function On(key)
	local value = SurvivorUIDB and SurvivorUIDB[key]
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

function SurvivorUI_WorldOn(key)
	return On(key) and true or false
end

function SurvivorUI_ToggleWorld(key)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB[key] = not On(key)
end

-- Whether the enemies' marks are drawn here (Marks.lua then marks only the heroes).
function SurvivorUI_MarksDrawn()
	return AZS_ProjectWorldAnchors ~= nil and On("markDrawn") and true or false
end

local downedYards = {}           -- [name] = yards, this read

-- How far a friend down is, in whole yards; nil when not down or not known.
function SurvivorUI_DownedYards(name)
	return name and downedYards[name]
end

-- A range ring's look, for the rings and the options' preview: which is
-- "World" or "Map", field one of RING_LOOK's.
function SurvivorUI_RangeLook(which, field)
	if which == "LeashWarn" and field == "Size" then
		return SurvivorUI_RangeLook("Leash", "Size") + 2
	end
	local value = SurvivorUIDB and SurvivorUIDB["ring"..which..field]
	if value == nil then
		return RING_LOOK[which][field]
	end
	return value
end

function SurvivorUI_SetRangeLook(which, field, value)
	SurvivorUIDB = SurvivorUIDB or {}
	if value == RING_LOOK[which][field] then
		value = nil
	end
	SurvivorUIDB["ring"..which..field] = value
	looks = looks + 1
end

-- Every ring on, each in its first look: the range rings and the guardians'.
function SurvivorUI_ResetRangeRings()
	SurvivorUIDB = SurvivorUIDB or {}
	for which, fields in pairs(RING_LOOK) do
		for field in pairs(fields) do
			SurvivorUIDB["ring"..which..field] = nil
		end
	end
	SurvivorUIDB.rangeWorld, SurvivorUIDB.rangeMinimap, SurvivorUIDB.rangeKept = nil, nil, nil
	SurvivorUIDB.leashWake, SurvivorUIDB.leashReset, SurvivorUIDB.leashWarn, SurvivorUIDB.leashMinimap = nil, nil, nil, nil
	looks = looks + 1
end

function SurvivorUI_RangeColor(which)
	local chosen = SurvivorUI_RangeLook(which, "Color")
	if chosen == "class" and SurvivorUI_ClassColor and UnitClass then
		local _, class = UnitClass("player")
		if class then
			return SurvivorUI_ClassColor(class)
		end
	end
	for index = 1, table.getn(SurvivorUI_RANGE_COLORS) do
		local entry = SurvivorUI_RANGE_COLORS[index]
		if entry[1] == chosen and entry[3] then
			return entry[3][1], entry[3][2], entry[3][3]
		end
	end
	return RING_COLOR[1], RING_COLOR[2], RING_COLOR[3]
end

-- Along a ring's way, lines[1] to lines[count] (each on, or left out; from x,
-- y by dx, dy; its length): a dot each step, Put(n, x, y) placing the nth.
-- Dots: a step of the gap. A line: steps under the dot's size, so they
-- touch. Dashes: the line's steps, only along the first three dots' sizes
-- of each stretch, the gap after. Returns how many were put.
function SurvivorUI_RangeAlong(lines, count, which, most, Put)
	local around = 0
	for index = 1, count do
		if lines[index].on then
			around = around + lines[index].length
		end
	end
	local look = SurvivorUI_RangeLook(which, "Look")
	local size, gap = SurvivorUI_RangeLook(which, "Size"), SurvivorUI_RangeLook(which, "Gap")
	local step, dash, stretch = gap, nil, nil
	if look == "line" or look == "dashes" then
		step = math.max(1, size * 0.4)
	end
	if look == "dashes" then
		dash = size * 3
		stretch = dash + gap
	end
	step = math.max(step, around / most)
	local used, carry, run = 0, 0, 0
	for index = 1, count do
		local line = lines[index]
		if not line.on then
			carry = 0
		elseif line.length > 0 then
			local at = carry
			while at < line.length and used < most do
				if not stretch or math.mod(run + at, stretch) < dash then
					used = used + 1
					local share = at / line.length
					Put(used, line.x + line.dx * share, line.y + line.dy * share)
				end
				at = at + step
			end
			carry = math.max(0, at - line.length)
			run = run + line.length
		end
	end
	return used
end

-- The pieces of a line, or of its dashes (three dots' sizes long, the gap
-- after), along the same way: Put(n, x1, y1, x2, y2, thick) placing the nth,
-- each piece within one line and no longer than PIECE_MOST times thick.
-- Returns how many were put.
function SurvivorUI_RangePieces(lines, count, which, most, Put)
	local size, gap = SurvivorUI_RangeLook(which, "Size"), SurvivorUI_RangeLook(which, "Gap")
	local thick = size * LINE_SHARE
	local longest = PIECE_MOST * thick
	local dash, stretch
	if SurvivorUI_RangeLook(which, "Look") == "dashes" then
		dash = size * 3
		stretch = dash + gap
	end
	local used, run = 0, 0
	for index = 1, count do
		local line = lines[index]
		if line.on and line.length > 0 then
			-- Each stretch drawn on this line, s to e from its start: the
			-- whole line, or each dash's share of it.
			local k = stretch and math.floor(run / stretch) or 0
			local s, e = 0, line.length
			while used < most do
				if stretch then
					if k * stretch >= run + line.length then
						break
					end
					s = math.max(k * stretch, run) - run
					e = math.min(k * stretch + dash, run + line.length) - run
					k = k + 1
				elseif s >= e then
					break
				end
				while s < e and used < most do
					local t = math.min(e, s + longest)
					used = used + 1
					local a, b = s / line.length, t / line.length
					Put(used, line.x + line.dx * a, line.y + line.dy * a, line.x + line.dx * b, line.y + line.dy * b, thick)
					s = t
				end
			end
			run = run + line.length
		end
	end
	return used
end

-- One piece from x1, y1 to x2, y2 (y up), thick across: the texture's box
-- the piece's own, sized here, and the art's band mapped onto the piece by
-- SetTexCoord's eight corners (as the game's TaxiFrame draws its routes),
-- each corner's UV inside the art, so nothing repeats: the band's middle
-- half along it, BAND_UV across. A piece shorter than about its thickness
-- draws its band a little longer, the corners kept inside. The caller
-- places the texture by its middle: returned.
function SurvivorUI_RangePiece(texture, x1, y1, x2, y2, thick)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.01 then
		length, dx, dy = 0.01, 0.01, 0
	end
	local ex, ey = dx / length, dy / length
	local nx, ny = -ey, ex
	local halfLength, halfThick = length / 2, thick * 0.75
	local hx = halfLength * math.abs(ex) + halfThick * math.abs(nx)
	local hy = halfLength * math.abs(ey) + halfThick * math.abs(ny)
	local su = math.min(0.25 / halfLength, 0.5 / (halfLength + halfThick * 2 * math.abs(ex * ey)))
	local sv = BAND_UV / thick
	local a, b, c, d = hx * ex * su, hy * ey * su, hx * nx * sv, hy * ny * sv
	-- Upper left, lower left, upper right, lower right.
	texture:SetTexCoord(0.5 - a + b, 0.5 - c + d, 0.5 - a - b, 0.5 - c - d,
		0.5 + a + b, 0.5 + c + d, 0.5 + a - b, 0.5 + c - d)
	texture:SetWidth(2 * hx)
	texture:SetHeight(2 * hy)
	return (x1 + x2) / 2, (y1 + y2) / 2
end

if not (AZS_GetWorldAnchors and AZS_ProjectWorldAnchors and AZS_RegisterWorldAnchorFrameHandler) then
	return
end

------------------------------------------------------------------------------
-- What there is: the catalog's anchors, the friends down, the units' health.

local spots = {}                 -- this read's: { anchor, attachment, lift, look, ... }
local heroAt                     -- { x, y, z } from AZS_GetPlayerPosition, read each frame
local base                       -- an anchor that stays put, for spots by offset: { id, x, y, z }

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function Read(query, into)
	local cursor
	for page = 1, 8 do
		local ok, result = pcall(AZS_GetWorldAnchors, query, cursor, 256)
		if not ok or not result then
			return
		end
		local entries = result.entries or {}
		for index = 1, table.getn(entries) do
			table.insert(into, entries[index])
		end
		if not result.hasMore or not result.nextCursor then
			return
		end
		cursor = result.nextCursor
	end
end

local function Has(list, wanted)
	for index = 1, table.getn(list or {}) do
		if list[index] == wanted then
			return true
		end
	end
	return false
end

local function Health()
	local health = {}
	for index = 1, table.getn(AZS_UNITS or {}) do
		local entry = AZS_UNITS[index]
		local id = tonumber(Field(entry, "id", 2))
		if id then
			health[id] = { tonumber(Field(entry, "hp", 4)) or 0, tonumber(Field(entry, "hpm", 5)) or 0 }
		end
	end
	return health
end

-- An enemy's spot: its mark drawn, its bar, or both, over its head.
local function EnemySpot(entry, health)
	local kind = MARK_KIND[entry.kind]
	local mark = kind and SurvivorUI_MarksDrawn() and SurvivorUI_AutoMarkOn and SurvivorUI_AutoMarkOn(kind)
		and SurvivorUI_AutoMarkIcon and SurvivorUI_AutoMarkIcon(kind)
	local bar = On("worldBars") and COLORS[entry.kind] ~= nil
	if not mark and not bar then
		return nil
	end
	local unit = entry.unitId and health[tonumber(entry.unitId)]
	return { anchor = entry.anchorId, attachment = "overhead", lift = 0.4, look = "enemy", kind = entry.kind,
		mark = mark, bar = bar, name = entry.name, hp = unit and unit[1], hpm = unit and unit[2],
		unit = entry.unitId and tostring(entry.unitId) }
end

local function ReadAll()
	local entries = {}
	Read({ kinds = SPECIAL }, entries)
	local explosive = On("worldOrbs") and SurvivorUI_RunAffixNames and Has(SurvivorUI_RunAffixNames(), "Explosive")
	if explosive then
		local enemies = {}
		Read({ kinds = { "enemy" }, states = { "alive" } }, enemies)
		for index = 1, table.getn(enemies) do
			if enemies[index].name == ORB then
				table.insert(entries, enemies[index])
			end
		end
	end
	local health = Health()
	spots = {}
	base = nil
	-- Each lair, for the guardians' rings (below), whatever the marks: its
	-- spot, its state, and whether its guardian is home (within 3 yards of
	-- it: only then does it wake as the hero comes near).
	local lairs = {}
	spots.lairs = lairs
	-- When each empty lair is claimed again (AZS_LAIRS' "left", seconds from
	-- its line, as Guardians.lua reads it).
	local refill = {}
	local since = AZS_LAIRS_UPDATED and (GetTime() - AZS_LAIRS_UPDATED) or 0
	for index = 1, table.getn(AZS_LAIRS or {}) do
		local lair = AZS_LAIRS[index]
		local left = tonumber(Field(lair, "left", 5))
		if left then
			refill[tonumber(Field(lair, "index", 1)) or index] = GetTime() + left - since
		end
	end
	-- The enemies first, each by its unit, so a lair's guardian is found.
	local units = {}
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		if COLORS[entry.kind] and entry.state == "alive" then
			local spot = EnemySpot(entry, health)
			if entry.unitId then
				units[tonumber(entry.unitId)] = { entry = entry, spot = spot }
			end
			if spot then
				spot.x, spot.y, spot.z = entry.x, entry.y, entry.z
				table.insert(spots, spot)
			end
		end
	end
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		local spot
		if entry.kind == "cache" then
			base = base or { id = entry.anchorId, x = entry.x, y = entry.y, z = entry.z }
			if entry.state == "present" and On("worldCaches") then
				local beam = On("worldBeams")
				spot = { anchor = entry.anchorId, attachment = "position", lift = beam and BEAM_TALL * 0.8 or 1.2,
					look = "cache", arrow = true, beam = beam }
			end
		elseif entry.kind == "guardianLair" then
			base = base or { id = entry.anchorId, x = entry.x, y = entry.y, z = entry.z }
			local occupant = entry.occupantUnitId and units[tonumber(entry.occupantUnitId)]
			if entry.x and entry.y then
				local gx, gy = occupant and occupant.entry.x, occupant and occupant.entry.y
				local away = gx and gy and math.sqrt((gx - entry.x) * (gx - entry.x) + (gy - entry.y) * (gy - entry.y)) or 0
				table.insert(lairs, { anchor = entry.anchorId, x = entry.x, y = entry.y, z = entry.z or 0, state = entry.state,
					home = away <= 3, gx = gx, gy = gy, away = away })
			end
			-- Asleep, over the lair; awake, over the guardian, which leaves it
			-- to fight (with its own mark or bar, its name goes with them).
			local guardian = entry.state == "awake" and occupant
			if not On("worldLairs") then
				spot = nil
			elseif entry.state == "empty" then
				-- Slain: back over the lair, the time until it is claimed again.
				spot = { anchor = entry.anchorId, attachment = "position", lift = 3, look = "lair", name = entry.name,
					empty = true, refill = refill[tonumber(entry.lairIndex)] }
			elseif entry.state ~= "asleep" and entry.state ~= "awake" then
				spot = nil
			elseif guardian and guardian.spot then
				guardian.spot.lair = entry.name
			elseif guardian then
				local unit = guardian.entry
				spot = { anchor = unit.anchorId, attachment = "overhead", lift = 0.6, look = "lair", arrow = true,
					name = entry.name, awake = true, unit = unit.unitId and tostring(unit.unitId) }
				entry = unit
			else
				spot = { anchor = entry.anchorId, attachment = "position", lift = 3, look = "lair", arrow = true,
					name = entry.name, awake = entry.state == "awake" }
			end
		elseif entry.kind == "enemy" then
			spot = { anchor = entry.anchorId, attachment = "overhead", lift = 0.6, look = "orb" }
		end
		if spot then
			spot.x, spot.y, spot.z = entry.x, entry.y, entry.z
			table.insert(spots, spot)
		end
	end
	-- The friends down, by the game's own list: the anchor when ready, else
	-- their spot by offset from another one.
	downedYards = {}
	local ok, downed = pcall(AZS_GetDownedPartyMembers)
	if ok and downed and On("worldDowned") then
		for index = 1, table.getn(downed) do
			local friend = downed[index]
			if friend.positionAvailable then
				local spot = { look = "downed", arrow = true, name = friend.name, x = friend.x, y = friend.y, z = friend.z, lift = 2.5 }
				if friend.anchorStatus == "ready" and friend.anchorId then
					spot.anchor, spot.attachment = friend.anchorId, "position"
				end
				table.insert(spots, spot)
			end
		end
	end
end

------------------------------------------------------------------------------
-- What is drawn: a spot's mark, words and bar; an arrow at the edge.

local layer = CreateFrame("Frame", "SurvivorUIWorldMarks", UIParent)
layer:SetAllPoints(UIParent)
layer:SetFrameStrata("LOW")
layer:Hide()

local marks, arrows = {}, {}

-- The beams under the nameplates' bars: a child of WorldFrame, on the world's
-- own strata as the plates are (the game draws by strata, then level), placed
-- in WorldFrame's units, as the places come.
local beams = CreateFrame("Frame", "SurvivorUIWorldBeams", WorldFrame)
beams:SetAllPoints(WorldFrame)
beams:Hide()
local lights = {}

local function Light(index)
	local light = lights[index]
	if light then
		return light
	end
	light = {}
	light.pool = beams:CreateTexture(nil, "BORDER")
	light.pool:SetTexture(ART.."CachePool")
	light.pool:SetBlendMode("ADD")
	light.beam = beams:CreateTexture(nil, "ARTWORK")
	light.beam:SetTexture(ART.."CacheBeam")
	light.beam:SetBlendMode("ADD")
	lights[index] = light
	return light
end

local function HideLights(first)
	for index = first, table.getn(lights) do
		lights[index].pool:Hide()
		lights[index].beam:Hide()
	end
end

-- A beam from its spot on the ground (low) to BEAM_TALL yards up (high), as
-- wide as the ground's yards there; the pool squashed as the camera tilts (a
-- yard up looks shorter than a yard across as the camera looks down).
local function PaintLight(light, low, high, hero, phase)
	local yard = low.uiUnitsPerYard
	local tall = high.y - low.y
	if not yard or yard <= 0 or tall <= 1 then
		light.pool:Hide()
		light.beam:Hide()
		return
	end
	local wide = BEAM_WIDE * yard
	light.beam:ClearAllPoints()
	light.beam:SetPoint("BOTTOM", beams, "BOTTOMLEFT", low.x, low.y)
	light.beam:SetWidth(wide)
	light.beam:SetHeight(tall)
	local up = math.min(1, tall / (BEAM_TALL * yard))
	local squash = math.max(0.25, math.sqrt(1 - up * up))
	local pool = POOL_WIDE * yard
	light.pool:ClearAllPoints()
	light.pool:SetPoint("CENTER", beams, "BOTTOMLEFT", low.x, low.y)
	light.pool:SetWidth(pool)
	light.pool:SetHeight(pool * squash)
	local a = 0.85 + 0.15 * math.sin(GetTime() * 2.2 + phase)
	if hero and hero.x and math.abs(hero.x - low.x) < wide * 0.7 and hero.y < high.y
			and hero.y > low.y - 3 * yard and (hero.cameraDepth or 0) < (low.cameraDepth or 0) then
		a = a * 0.35
	end
	light.beam:SetVertexColor(BEAM_COLOR[1], BEAM_COLOR[2], BEAM_COLOR[3], a)
	light.pool:SetVertexColor(BEAM_COLOR[1], BEAM_COLOR[2], BEAM_COLOR[3], a * 0.8)
	light.pool:Show()
	light.beam:Show()
end

local function Words(parent, size)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF", size + FONT_BUMP, "OUTLINE")
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	return text
end

local function Mark(index)
	local mark = marks[index]
	if mark then
		return mark
	end
	mark = CreateFrame("Frame", nil, layer)
	mark:SetWidth(1)
	mark:SetHeight(1)
	mark.icon = mark:CreateTexture(nil, "ARTWORK")
	mark.name = Words(mark, 10)
	mark.yards = Words(mark, 9)
	mark.back = mark:CreateTexture(nil, "BORDER")
	mark.back:SetTexture(FLAT)
	mark.back:SetVertexColor(0, 0, 0, 0.75)
	mark.fill = mark:CreateTexture(nil, "ARTWORK")
	mark.fill:SetTexture(FLAT)
	marks[index] = mark
	return mark
end

local function Arrow(index)
	local arrow = arrows[index]
	if arrow then
		return arrow
	end
	arrow = CreateFrame("Frame", nil, layer)
	arrow:SetWidth(1)
	arrow:SetHeight(1)
	arrow.point = arrow:CreateTexture(nil, "ARTWORK")
	arrow.point:SetTexture(ART.."GuardianArrow")
	arrow.point:SetWidth(26)
	arrow.point:SetHeight(26)
	arrow.point:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	arrow.icon = arrow:CreateTexture(nil, "OVERLAY")
	arrow.icon:SetWidth(16)
	arrow.icon:SetHeight(16)
	arrow.yards = Words(arrow, 9)
	arrows[index] = arrow
	return arrow
end

-- The arrow sheet's cell nearest to an angle (radians, clockwise from up).
local function Point(texture, angle)
	local cells = CELLS * CELLS
	local k = math.mod(math.floor(angle / (2 * math.pi) * cells + 0.5), cells)
	if k < 0 then
		k = k + cells
	end
	local column, line = math.mod(k, CELLS), math.floor(k / CELLS)
	texture:SetTexCoord(column / CELLS, (column + 1) / CELLS, line / CELLS, (line + 1) / CELLS)
end

-- A lair's time until it is claimed again, as Guardians.lua writes it.
local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

local function Yards(value)
	return SurvivorUI_TF and SurvivorUI_TF("{1} yd", math.floor(value + 0.5)) or (math.floor(value + 0.5).." yd")
end

-- Each look's mark and words. A mark is placed by its middle at x, y.
local function Paint(mark, spot, x, y, yards)
	local icon, name, back, fill = mark.icon, mark.name, mark.back, mark.fill
	icon:Hide()
	name:Hide()
	back:Hide()
	fill:Hide()
	mark.yards:Hide()
	mark:ClearAllPoints()
	mark:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	icon:ClearAllPoints()
	icon:SetTexCoord(0, 1, 0, 1)
	icon:SetVertexColor(1, 1, 1, 1)
	local look = spot.look
	if look == "enemy" then
		local top = 0
		if spot.bar then
			local color = COLORS[spot.kind] or GOLD
			local width = (spot.kind == "boss" or spot.kind == "finalBoss") and 110 or 74
			back:SetWidth(width + 2)
			back:SetHeight(7)
			back:SetPoint("CENTER", mark, "CENTER", 0, 0)
			back:Show()
			local share = (spot.hpm and spot.hpm > 0) and math.max(0, math.min(1, spot.hp / spot.hpm)) or 1
			fill:SetVertexColor(color[1], color[2], color[3], 1)
			fill:SetWidth(math.max(1, width * share))
			fill:SetHeight(5)
			fill:SetPoint("LEFT", back, "LEFT", 1, 0)
			fill:Show()
			name:SetText(spot.name or "")
			name:SetTextColor(color[1], color[2], color[3])
			name:ClearAllPoints()
			name:SetPoint("BOTTOM", back, "TOP", 0, 1)
			name:Show()
			top = 16
		end
		if spot.mark and SurvivorUI_SetRaidMarkTexture then
			SurvivorUI_SetRaidMarkTexture(icon, spot.mark)
			icon:SetWidth(20)
			icon:SetHeight(20)
			icon:SetPoint("BOTTOM", mark, "CENTER", 0, top + 2)
		end
		-- A guardian awake, out of its lair: its name over it (the bar has it already).
		if spot.lair and not spot.bar then
			name:SetText(spot.lair)
			name:SetTextColor(1, 0.62, 0.22)
			name:ClearAllPoints()
			if spot.mark then
				name:SetPoint("BOTTOM", icon, "TOP", 0, 1)
			else
				name:SetPoint("BOTTOM", mark, "CENTER", 0, 2)
			end
			name:Show()
		end
	elseif look == "orb" then
		local pulse = 1 + 0.15 * math.sin(GetTime() * 7)
		icon:SetTexture(ART.."AffixExplosive")
		icon:SetWidth(26 * pulse)
		icon:SetHeight(26 * pulse)
		icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
		icon:Show()
	elseif look == "cache" then
		icon:SetTexture(ART.."PinCache")
		icon:SetWidth(20)
		icon:SetHeight(20)
		icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
		icon:Show()
	elseif look == "lair" then
		icon:SetTexture(ART.."PinLair")
		icon:SetWidth(22)
		icon:SetHeight(22)
		icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
		icon:Show()
		name:SetText(spot.name or "")
		if spot.awake then
			name:SetTextColor(1, 0.62, 0.22)
		else
			name:SetTextColor(0.75, 0.75, 0.75)
		end
		name:ClearAllPoints()
		name:SetPoint("BOTTOM", icon, "TOP", 0, 1)
		name:Show()
		if spot.empty then
			icon:SetVertexColor(0.6, 0.6, 0.6, 0.6)
			name:SetTextColor(0.55, 0.55, 0.55)
			local left = spot.refill and spot.refill - GetTime()
			mark.yards:SetText(left and left > 0 and Clock(left) or (SurvivorUI_T and SurvivorUI_T("soon") or "soon"))
			mark.yards:SetTextColor(RESPAWN[1], RESPAWN[2], RESPAWN[3])
			mark.yards:ClearAllPoints()
			mark.yards:SetPoint("TOP", mark, "CENTER", 0, -12)
			mark.yards:Show()
			yards = nil
		end
	elseif look == "downed" then
		local pulse = 1 + 0.12 * math.sin(GetTime() * 5)
		icon:SetTexture(ART.."HealCross")
		icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
		icon:SetWidth(26 * pulse)
		icon:SetHeight(26 * pulse)
		icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
		icon:Show()
		name:SetText(spot.name or "")
		name:SetTextColor(1, 0.36, 0.30)
		name:ClearAllPoints()
		name:SetPoint("BOTTOM", icon, "TOP", 0, 1)
		name:Show()
	end
	if yards and look ~= "enemy" then
		mark.yards:SetText(Yards(yards))
		mark.yards:SetTextColor(1, 1, 1)
		mark.yards:ClearAllPoints()
		mark.yards:SetPoint("TOP", mark, "CENTER", 0, -12)
		mark.yards:Show()
	end
	mark:Show()
end

local ICONS = { cache = "PinCache", lair = "PinLair", downed = "HealCross" }

-- An arrow on a ring round the hero's spot (hx, hy), where the line toward
-- dx, dy meets it: the screen's edge is where the panels stand, and the
-- combat text's columns stand close by the hero, so the ring is wider than
-- tall.
local function PaintArrow(arrow, spot, hx, hy, dx, dy, yards)
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.001 then
		arrow:Hide()
		return
	end
	dx, dy = dx / length, dy / length
	local wide, tall = UIParent:GetWidth() * RING_WIDE, UIParent:GetHeight() * RING_TALL
	local reach = 1 / math.sqrt((dx / wide) * (dx / wide) + (dy / tall) * (dy / tall))
	arrow:ClearAllPoints()
	arrow:SetPoint("CENTER", UIParent, "BOTTOMLEFT", hx + dx * reach, hy + dy * reach)
	Point(arrow.point, math.atan2(dx, dy))
	if spot.look == "downed" then
		arrow.point:SetVertexColor(1, 0.36, 0.30, 1)
		arrow.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	else
		arrow.point:SetVertexColor(1, 0.82, 0.2, 1)
		arrow.icon:SetVertexColor(1, 1, 1, 1)
	end
	arrow.icon:SetTexture(ART..(ICONS[spot.look] or "PinCache"))
	arrow.icon:ClearAllPoints()
	-- The icon and the yards on the inner side, toward the middle.
	arrow.icon:SetPoint("CENTER", arrow, "CENTER", -dx * 24, -dy * 24)
	arrow.yards:SetText(Yards(yards))
	arrow.yards:ClearAllPoints()
	arrow.yards:SetPoint("TOP", arrow.icon, "BOTTOM", 0, -1)
	arrow:Show()
end

------------------------------------------------------------------------------
-- Each frame, after the camera: the spots and the arrows where the game says.

local function Distance(spot)
	if not heroAt or not spot.x then
		return nil
	end
	local dx, dy, dz = spot.x - heroAt.x, spot.y - heroAt.y, (spot.z or 0) - (heroAt.z or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The request for a world spot, by offset from the anchor that stays put.
local function Spot(wx, wy, wz)
	return { anchorId = base.id, attachment = "position", offset = { x = wx - base.x, y = wy - base.y, z = wz - base.z } }
end

local function HideFrom(list, first)
	for index = first, table.getn(list) do
		list[index]:Hide()
	end
end

local function Draw()
	local requests, wanted = {}, {}
	for index = 1, table.getn(spots) do
		local spot = spots[index]
		if spot.unit and SurvivorPlates_PlateShows and SurvivorPlates_PlateShows(spot.unit) then
			-- its nameplate names it, with the mark drawn beside its bar (Survivor Plates)
		elseif spot.anchor then
			table.insert(requests, { anchorId = spot.anchor, attachment = spot.attachment, offset = { x = 0, y = 0, z = spot.lift or 0 } })
			table.insert(wanted, spot)
		elseif base and spot.x then
			table.insert(requests, Spot(spot.x, spot.y, spot.z + (spot.lift or 0)))
			table.insert(wanted, spot)
		end
	end
	-- Each beam's foot and top.
	local lit = {}
	for index = 1, table.getn(wanted) do
		local spot = wanted[index]
		if spot.beam then
			table.insert(requests, { anchorId = spot.anchor, attachment = "position", offset = { x = 0, y = 0, z = 0 } })
			table.insert(requests, { anchorId = spot.anchor, attachment = "position", offset = { x = 0, y = 0, z = BEAM_TALL } })
			table.insert(lit, table.getn(requests) - 1)
		end
	end
	-- The hero's spot, for the arrows' way and the beams it stands in front of.
	local heroIndex
	local pointing = On("worldArrows")
	if base and heroAt and (pointing or table.getn(lit) > 0) then
		table.insert(requests, Spot(heroAt.x, heroAt.y, heroAt.z))
		heroIndex = table.getn(requests)
	end
	if table.getn(requests) == 0 or table.getn(requests) > 256 then
		HideFrom(marks, 1)
		HideFrom(arrows, 1)
		HideLights(1)
		return
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, requests)
	local entries = ok and result and result.entries or {}
	local ratio = WorldFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local shown, away = 0, {}
	for index = 1, table.getn(wanted) do
		local entry, spot = entries[index], wanted[index]
		if entry and entry.state == "onScreen" and entry.x then
			shown = shown + 1
			-- A beam's chest floats up and down a little.
			local bob = spot.beam and 2 * math.sin(GetTime() * 2.2 + index) or 0
			Paint(Mark(shown), spot, entry.x * ratio, entry.y * ratio + bob, entry.playerDistance or Distance(spot))
		elseif spot.arrow and entry and (entry.state == "offscreen" or entry.state == "behindCamera") then
			table.insert(away, spot)
		end
	end
	HideFrom(marks, shown + 1)
	local hero = heroIndex and entries[heroIndex]
	local glowing = 0
	for index = 1, table.getn(lit) do
		local low, high = entries[lit[index]], entries[lit[index] + 1]
		if low and high and low.state == "onScreen" and high.state == "onScreen" and low.x and high.x then
			glowing = glowing + 1
			PaintLight(Light(glowing), low, high, hero and hero.state == "onScreen" and hero or nil, index)
		end
	end
	HideLights(glowing + 1)
	-- The arrows: the nearest spots out of sight, each by its way from the hero.
	local pointed = 0
	if pointing and hero and hero.state == "onScreen" and hero.x then
		for index = 1, table.getn(away) do
			away[index].yards = Distance(away[index]) or 0
		end
		table.sort(away, function(a, b)
			if (a.look == "downed") ~= (b.look == "downed") then
				return a.look == "downed"
			end
			return a.yards < b.yards
		end)
		local ways = {}
		for index = 1, math.min(table.getn(away), MOST_ARROWS) do
			local spot = away[index]
			local dx, dy, dz = spot.x - heroAt.x, spot.y - heroAt.y, 0
			local length = math.sqrt(dx * dx + dy * dy)
			if length > 0.5 then
				table.insert(ways, spot)
				table.insert(requests, Spot(heroAt.x + dx / length * WAY, heroAt.y + dy / length * WAY, heroAt.z))
			end
		end
		if table.getn(ways) > 0 then
			-- Only the ways this time: the first read's are kept above.
			local wayRequests = {}
			for index = heroIndex + 1, table.getn(requests) do
				table.insert(wayRequests, requests[index])
			end
			local fine, answer = pcall(AZS_ProjectWorldAnchors, wayRequests)
			local points = fine and answer and answer.entries or {}
			local hx, hy = hero.x * ratio, hero.y * ratio
			for index = 1, table.getn(ways) do
				local point = points[index]
				if point and point.x and point.y then
					pointed = pointed + 1
					PaintArrow(Arrow(pointed), ways[index], hx, hy, point.x * ratio - hx, point.y * ratio - hy, ways[index].yards)
				end
			end
		end
	end
	HideFrom(arrows, pointed + 1)
end

------------------------------------------------------------------------------
-- The range rings.

local reach                      -- the longest spell's yards, this read
local ringClass                  -- the hero's class, for a ring in its color

-- On the minimap: a ring as wide as the yards across allow, under the pins
-- (MapPins.lua's stand 4 over the map); left out while it fits no more. Its
-- dots placed again only as its size or its look changes, its shade (a disc)
-- under them.
local mapRing = CreateFrame("Frame", "SurvivorUIRangeRing", Minimap)
mapRing:SetFrameLevel(Minimap:GetFrameLevel() + 2)
mapRing:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
mapRing:Hide()
mapRing.shade = mapRing:CreateTexture(nil, "BACKGROUND")
mapRing.shade:SetTexture(ART.."Disc")
mapRing.shade:SetAllPoints(mapRing)
local mapDots, mapLines = {}, {}
for index = 1, MAP_POINTS do
	mapLines[index] = { on = true }
end

local function PutMapDot(index, x, y)
	local dot = mapDots[index]
	if not dot then
		dot = mapRing:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(ART.."PaceDot")
		mapDots[index] = dot
	end
	dot:SetWidth(mapRing.dotSize)
	dot:SetHeight(mapRing.dotSize)
	dot:SetVertexColor(mapRing.r, mapRing.g, mapRing.b, mapRing.alpha)
	dot:SetPoint("CENTER", mapRing, "CENTER", x, y)
	dot:Show()
end

local function PlaceMapRing(running)
	local across = SurvivorUI_MinimapYards and SurvivorUI_MinimapYards()
	local width = Minimap:GetWidth() or 0
	local size = reach and across and across > 0 and 2 * reach * width / across
	if not (running and size and size >= 6 and size <= width and On("rangeMinimap")) then
		mapRing:Hide()
		return
	end
	local drawn = math.floor(size * 10 + 0.5) + looks * 100000
	if mapRing.drawn ~= drawn then
		mapRing.drawn = drawn
		mapRing:SetWidth(size)
		mapRing:SetHeight(size)
		mapRing.r, mapRing.g, mapRing.b = SurvivorUI_RangeColor("Map")
		mapRing.alpha = SurvivorUI_RangeLook("Map", "Alpha")
		mapRing.dotSize = SurvivorUI_RangeLook("Map", "Size")
		local radius = size / 2
		for index = 1, MAP_POINTS do
			local line = mapLines[index]
			local from, to = 2 * math.pi * (index - 1) / MAP_POINTS, 2 * math.pi * index / MAP_POINTS
			line.x, line.y = radius * math.cos(from), radius * math.sin(from)
			line.dx, line.dy = radius * math.cos(to) - line.x, radius * math.sin(to) - line.y
			line.length = math.sqrt(line.dx * line.dx + line.dy * line.dy)
		end
		local used = SurvivorUI_RangeAlong(mapLines, MAP_POINTS, "Map", MOST_MAP_DOTS, PutMapDot)
		for index = used + 1, table.getn(mapDots) do
			mapDots[index]:Hide()
		end
		if SurvivorUI_RangeLook("Map", "Shade") then
			mapRing.shade:SetVertexColor(mapRing.r, mapRing.g, mapRing.b, 0.3 * mapRing.alpha)
			mapRing.shade:Show()
		else
			mapRing.shade:Hide()
		end
	end
	mapRing:Show()
end

-- On the ground: under the beams, a child of WorldFrame as they are.
local ground = CreateFrame("Frame", "SurvivorUIWorldRange", WorldFrame)
ground:SetAllPoints(WorldFrame)
ground:Hide()
ground.yards = Words(ground, 10)
local dots, pieces = {}, {}
local ringAsk, lines = {}, {}    -- the circle's points, asked anew each frame; the lines between
for index = 1, RING_POINTS do
	ringAsk[index] = { anchorId = "", attachment = "position", offset = { x = 0, y = 0, z = 0 } }
	lines[index] = {}
end

-- A piece of the line or of a dash, in its look as it stands.
local function PutPiece(index, x1, y1, x2, y2, thick)
	local piece = pieces[index]
	if not piece then
		piece = ground:CreateTexture(nil, "BACKGROUND")
		piece:SetTexture(ART.."RingLine")
		pieces[index] = piece
	end
	if piece.looks ~= looks then
		piece.looks = looks
		local r, g, b = SurvivorUI_RangeColor("World")
		piece:SetVertexColor(r, g, b, SurvivorUI_RangeLook("World", "Alpha"))
	end
	local x, y = SurvivorUI_RangePiece(piece, x1, y1, x2, y2, thick)
	piece:SetPoint("CENTER", ground, "BOTTOMLEFT", x, y)
	piece:Show()
end

-- A dot of the ring, in its look as it stands (taken again after a change).
local function PutDot(index, x, y)
	local dot = dots[index]
	if not dot then
		dot = ground:CreateTexture(nil, "BACKGROUND")
		dot:SetTexture(ART.."PaceDot")
		dots[index] = dot
	end
	if dot.looks ~= looks then
		dot.looks = looks
		local size = SurvivorUI_RangeLook("World", "Size")
		dot:SetWidth(size)
		dot:SetHeight(size)
		local r, g, b = SurvivorUI_RangeColor("World")
		dot:SetVertexColor(r, g, b, SurvivorUI_RangeLook("World", "Alpha"))
	end
	dot:SetPoint("CENTER", ground, "BOTTOMLEFT", x, y)
	dot:Show()
end

-- The dots from first on and the pieces from firstPiece on hidden; with
-- none left, the yards too.
local function HideDots(first, firstPiece)
	for index = first, table.getn(dots) do
		dots[index]:Hide()
	end
	for index = firstPiece or first, table.getn(pieces) do
		pieces[index]:Hide()
	end
	if first == 1 and (firstPiece or 1) == 1 then
		ground.yards:Hide()
	end
end

------------------------------------------------------------------------------
-- The guardians' rings (Lucas, 2026-11-03), by the game's rule (read in its
-- 0.139.2, the same for every zone, Heroic and guardian): a sleeping guardian
-- wakes at any hit, from any distance, or with the hero within WAKE yards of
-- it while it is home (within HOME yards of its lair); an awake one gives up
-- when the hero, not it, is more than LEASH yards from its lair, wherever it
-- stands itself: full health, its debuffs gone, asleep, walking home. Drawn
-- on the ground in the range ring's own call (DrawRing, below), each lair's
-- spot and state from the catalog's read (spots.lairs), each its switch and
-- its look (the options' Range ring tab; orange dots and dashes at first):
-- - the wake ring ("aggro ring"): round the nearest guardian asleep at home,
--   within NEAR yards (one only: a ring round every lair would fill the
--   screen);
-- - the reset ring ("reset area") of an awake guardian's lair, along the arc
--   within SEEN yards of the hero (the rest lies far off the screen), at the
--   hero's height, where the ground near it is; in the last WARN yards
--   ("Warning"), a line turning red, pulsing, the yards left beside it.
-- The minimap's are MapPins.lua's.

do
	local WAKE, LEASH, WARN = 20, 97.5, 10   -- HOME, 3 yards: ReadAll's
	-- The screen reaches about 90 yards up from the hero (the camera looks
	-- ahead, from behind): SEEN past that.
	local SEEN, NEAR = 120, 90
	local WAKE_POINTS, ARC_POINTS = 32, 61   -- odd: the arc's middle point is the nearest to the hero
	-- Each its look (RING_LOOK's Wake, Leash and LeashWarn; the options' Range
	-- ring tab); the warning's red the empty lair's time's (RESPAWN).

	local pool, wakeLines, arcLines, wakeDots, arcPieces = {}, {}, {}, {}, {}
	for index = 1, ARC_POINTS do
		wakeLines[index], arcLines[index] = {}, {}
	end
	local now = { arcs = {} }                -- this frame's asks: { wake = first, arcs = { { first, left } }, hero = index }
	local tint = { 1, 1, 1, 1 }
	local label = Words(ground, 12)
	label:Hide()

	-- The nth request after count, by offset from a lair's anchor.
	local function Ask(asks, count, anchor, x, y, z)
		count = count + 1
		local ask = pool[count]
		if not ask then
			ask = { attachment = "position", offset = {} }
			pool[count] = ask
		end
		ask.anchorId = anchor
		ask.offset.x, ask.offset.y, ask.offset.z = x, y, z
		asks[count] = ask
		return count
	end

	-- This frame's rings asked after asks[count]; the new count back.
	function ground.LeashAsk(asks, count)
		local arcs = {}
		now.arcs, now.wake, now.hero = arcs, nil, nil
		local lairs = spots.lairs
		if not (heroAt and lairs) then
			return count
		end
		local nearest, nearestYards
		for index = 1, table.getn(lairs) do
			local lair = lairs[index]
			local dx, dy = heroAt.x - lair.x, heroAt.y - lair.y
			local yards = math.sqrt(dx * dx + dy * dy)
			lair.yards = yards
			if lair.state == "asleep" and lair.home and yards <= NEAR and (not nearestYards or yards < nearestYards) then
				nearest, nearestYards = lair, yards
			elseif lair.state == "awake" and On("leashReset") and yards > LEASH - SEEN and yards < LEASH + WARN
					and table.getn(arcs) < 2 and count + ARC_POINTS + WAKE_POINTS + 1 <= 256 then
				-- The arc's ends where the circle is SEEN yards from the hero.
				local cosine = (LEASH * LEASH + yards * yards - SEEN * SEEN) / (2 * LEASH * yards)
				cosine = math.max(-1, math.min(1, cosine))
				local wide = math.atan2(math.sqrt(1 - cosine * cosine), cosine)
				local toward = math.atan2(dy, dx)
				table.insert(arcs, { first = count + 1, left = LEASH - yards })
				for point = 1, ARC_POINTS do
					local angle = toward - wide + 2 * wide * (point - 1) / (ARC_POINTS - 1)
					count = Ask(asks, count, lair.anchor, LEASH * math.cos(angle), LEASH * math.sin(angle), heroAt.z - lair.z)
				end
				if not now.hero then
					count = Ask(asks, count, lair.anchor, dx, dy, heroAt.z - lair.z)
					now.hero = count
				end
			end
		end
		if nearest and On("leashWake") and count + WAKE_POINTS <= 256 then
			now.wake = count + 1
			local cx, cy = (nearest.gx or nearest.x) - nearest.x, (nearest.gy or nearest.y) - nearest.y
			for point = 1, WAKE_POINTS do
				local angle = 2 * math.pi * (point - 1) / WAKE_POINTS
				count = Ask(asks, count, nearest.anchor, cx + WAKE * math.cos(angle), cy + WAKE * math.sin(angle), 0)
			end
		end
		return count
	end

	-- The lines between points first to first + n - 1 on the screen, closed
	-- (the last back to the first) or not: one with an end off it left out.
	local function Join(lines, points, first, n, closed)
		local last = closed and n or n - 1
		for index = 1, last do
			local a, b = points[first + index - 1], points[first + math.mod(index, n)]
			local line = lines[index]
			line.on = a and b and a.state == "onScreen" and b.state == "onScreen" and a.x and b.x and true or false
			if line.on then
				line.x, line.y, line.dx, line.dy = a.x, a.y, b.x - a.x, b.y - a.y
				line.length = math.sqrt(line.dx * line.dx + line.dy * line.dy)
			end
		end
		return last
	end

	-- The dots and the pieces of both rings, in the look being drawn (tint:
	-- its color, opacity and dots' size); dotted and laid, those put so far.
	local dotted, laid = 0, 0
	local function PutDot(index, x, y)
		local dot = wakeDots[dotted + index]
		if not dot then
			dot = ground:CreateTexture(nil, "BACKGROUND")
			dot:SetTexture(ART.."PaceDot")
			wakeDots[dotted + index] = dot
		end
		dot:SetWidth(tint.size)
		dot:SetHeight(tint.size)
		dot:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
		dot:SetPoint("CENTER", ground, "BOTTOMLEFT", x, y)
		dot:Show()
	end

	local function PutPiece(index, x1, y1, x2, y2, thick)
		local piece = arcPieces[laid + index]
		if not piece then
			piece = ground:CreateTexture(nil, "BACKGROUND")
			piece:SetTexture(ART.."RingLine")
			arcPieces[laid + index] = piece
		end
		piece:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
		local x, y = SurvivorUI_RangePiece(piece, x1, y1, x2, y2, thick)
		piece:SetPoint("CENTER", ground, "BOTTOMLEFT", x, y)
		piece:Show()
	end

	-- A ring's lines in a look ("Wake", "Leash" or "LeashWarn"): dots, or the
	-- pieces of its dashes or line. The look's color unless given (r, g, b).
	local function Trace(lines, count, which, r, g, b, a)
		if not r then
			r, g, b = SurvivorUI_RangeColor(which)
		end
		tint[1], tint[2], tint[3], tint[4] = r, g, b, a or SurvivorUI_RangeLook(which, "Alpha")
		tint.size = SurvivorUI_RangeLook(which, "Size")
		if SurvivorUI_RangeLook(which, "Look") == "dots" then
			dotted = dotted + SurvivorUI_RangeAlong(lines, count, which, MOST_DOTS - dotted, PutDot)
		else
			laid = laid + SurvivorUI_RangePieces(lines, count, which, MOST_PIECES - laid, PutPiece)
		end
	end

	-- This frame's rings drawn from the call's answers (points, nil: none).
	function ground.LeashDraw(points)
		local warned
		dotted, laid = 0, 0
		if points and now.wake then
			Trace(wakeLines, Join(wakeLines, points, now.wake, WAKE_POINTS, true), "Wake")
		end
		for index = 1, table.getn(points and now.arcs or {}) do
			local arc = now.arcs[index]
			local count = Join(arcLines, points, arc.first, ARC_POINTS, false)
			if arc.left < WARN and On("leashWarn") then
				-- A line from the reset area's color half way to red at once,
				-- all red at the limit; pulsing, a little thicker.
				local share = 0.5 + 0.5 * math.max(0, math.min(1, 1 - arc.left / WARN))
				local r, g, b = SurvivorUI_RangeColor("Leash")
				Trace(arcLines, count, "LeashWarn", r + (RESPAWN[1] - r) * share, g + (RESPAWN[2] - g) * share,
					b + (RESPAWN[3] - b) * share, 0.75 + 0.25 * math.sin(GetTime() * 6))
				if not warned or arc.left < warned.left then
					warned = arc
				end
			else
				Trace(arcLines, count, "Leash")
			end
		end
		for index = dotted + 1, table.getn(wakeDots) do
			wakeDots[index]:Hide()
		end
		for index = laid + 1, table.getn(arcPieces) do
			arcPieces[index]:Hide()
		end
		-- The yards left, by the arc's middle (the nearest point), on its
		-- far side from the hero.
		local middle = warned and points[warned.first + (ARC_POINTS - 1) / 2]
		if not (middle and middle.state == "onScreen" and middle.x and warned.left > 0) then
			label:Hide()
			return
		end
		local hero = now.hero and points[now.hero]
		local ux, uy = 0, 1
		if hero and hero.state == "onScreen" and hero.x then
			local dx, dy = middle.x - hero.x, middle.y - hero.y
			local length = math.sqrt(dx * dx + dy * dy)
			if length > 1 then
				ux, uy = dx / length, dy / length
			end
		end
		label:SetText(SurvivorUI_TF and SurvivorUI_TF("Resets in {1} yd", math.ceil(warned.left))
			or ("Resets in "..math.ceil(warned.left).." yd"))
		label:SetTextColor(RESPAWN[1], RESPAWN[2], RESPAWN[3])
		label:ClearAllPoints()
		label:SetPoint("CENTER", ground, "BOTTOMLEFT", middle.x + ux * 18, middle.y + uy * 14)
		label:Show()
	end
end

-- The circle's points on the screen, by offset from the anchor that stays
-- put, then dots or pieces along the lines between them: a line with an end
-- off the screen left out. Its yards, chosen, over the ring's highest point
-- with room under the screen's top. The guardians' rings asked after its
-- points, in the same call.
local function DrawRing()
	local asks, count = {}, 0
	local ringOn = reach and base and heroAt and On("rangeWorld")
	if ringOn then
		for index = 1, RING_POINTS do
			local angle = 2 * math.pi * (index - 1) / RING_POINTS
			local ask = ringAsk[index]
			ask.anchorId = base.id
			ask.offset.x = heroAt.x + reach * math.cos(angle) - base.x
			ask.offset.y = heroAt.y + reach * math.sin(angle) - base.y
			ask.offset.z = heroAt.z - base.z
			asks[index] = ask
		end
		count = RING_POINTS
	end
	count = ground.LeashAsk(asks, count)
	if count == 0 then
		ground.LeashDraw(nil)
		HideDots(1)
		return
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, asks)
	local points = ok and result and result.entries or {}
	ground.LeashDraw(points)
	if not ringOn then
		HideDots(1)
		return
	end
	for index = 1, RING_POINTS do
		local a, b = points[index], points[math.mod(index, RING_POINTS) + 1]
		local line = lines[index]
		line.on = a and b and a.state == "onScreen" and b.state == "onScreen" and a.x and b.x and true or false
		if line.on then
			line.x, line.y, line.dx, line.dy = a.x, a.y, b.x - a.x, b.y - a.y
			line.length = math.sqrt(line.dx * line.dx + line.dy * line.dy)
		end
	end
	local used, laid = 0, 0
	if SurvivorUI_RangeLook("World", "Look") == "dots" then
		used = SurvivorUI_RangeAlong(lines, RING_POINTS, "World", MOST_DOTS, PutDot)
	else
		laid = SurvivorUI_RangePieces(lines, RING_POINTS, "World", MOST_PIECES, PutPiece)
	end
	HideDots(used + 1, laid + 1)
	local label = ground.yards
	if used + laid == 0 or not SurvivorUI_RangeLook("World", "Yards") then
		label:Hide()
		return
	end
	local roof = (ground:GetHeight() or 0) * 0.88
	local topX, topY
	for index = 1, RING_POINTS do
		local line = lines[index]
		if line.on and line.y < roof and (not topY or line.y > topY) then
			topX, topY = line.x, line.y
		end
	end
	if not topX then
		label:Hide()
		return
	end
	if label.reach ~= reach or label.looks ~= looks then
		label.reach, label.looks = reach, looks
		label:SetText(Yards(reach))
		label:SetTextColor(SurvivorUI_RangeColor("World"))
	end
	label:SetPoint("BOTTOM", ground, "BOTTOMLEFT", topX, topY + SurvivorUI_RangeLook("World", "Size") / 2 + 3)
	label:Show()
end

local function Showing()
	return AZS_GetPhase and AZS_GetPhase() == "playing"
end

local waited = READ_EVERY
local function Frame()
	if not Showing() then
		if layer:IsShown() then
			layer:Hide()
			beams:Hide()
			ground:Hide()
		end
		return
	end
	if not layer:IsShown() then
		layer:Show()
		beams:Show()
		ground:Show()
	end
	local ok, p = pcall(AZS_GetPlayerPosition)
	heroAt = ok and p and p.x and { x = p.x, y = p.y, z = p.z or 0 } or nil
	Draw()
	DrawRing()
end

AZS_RegisterWorldAnchorFrameHandler(Frame)

-- The catalog, four times a second; the friends' yards for the party frames;
-- the longest spell's reach and the minimap's ring.
local reader = CreateFrame("Frame")
reader:SetScript("OnUpdate", function()
	waited = waited + arg1
	if waited < READ_EVERY then
		return
	end
	waited = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	local running = phase == "playing" or phase == "choosing" or phase == "paused"
	reach = running and (On("rangeMinimap") or On("rangeWorld")) and SurvivorUI_LongestReach
		and SurvivorUI_LongestReach() or nil
	local _, class = UnitClass("player")
	if class ~= ringClass then
		ringClass = class
		looks = looks + 1
	end
	PlaceMapRing(running)
	if not Showing() then
		return
	end
	ReadAll()
	for index = 1, table.getn(spots) do
		local spot = spots[index]
		if spot.look == "downed" and spot.name then
			local yards = Distance(spot)
			downedYards[spot.name] = yards and math.floor(yards + 0.5) or nil
		end
	end
end)
