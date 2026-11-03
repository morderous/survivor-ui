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
--   along points of the circle, each a spot by offset).
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
-- round the hero, light blue: on the minimap a ring, on the ground dots
-- along RING_POINTS points of the circle (both on at first), at least
-- DOT_GAP apart on the screen and never more than MOST_DOTS.
local RING_COLOR = { 0.55, 0.82, 1.00 }
local RING_POINTS = 48
local DOT_GAP, DOT_SIZE, MOST_DOTS = 10, 6, 200

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
			-- Asleep, over the lair; awake, over the guardian, which leaves it
			-- to fight (with its own mark or bar, its name goes with them).
			local guardian = entry.state == "awake" and entry.occupantUnitId and units[tonumber(entry.occupantUnitId)]
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

-- On the minimap: a ring as wide as the yards across allow, under the pins
-- (MapPins.lua's stand 4 over the map); left out while it fits no more.
local mapRing = CreateFrame("Frame", "SurvivorUIRangeRing", Minimap)
mapRing:SetFrameLevel(Minimap:GetFrameLevel() + 2)
mapRing:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
mapRing:Hide()
mapRing.ring = mapRing:CreateTexture(nil, "ARTWORK")
mapRing.ring:SetTexture(ART.."Ring")
mapRing.ring:SetAllPoints(mapRing)
mapRing.ring:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 0.9)

local function PlaceMapRing(running)
	local across = SurvivorUI_MinimapYards and SurvivorUI_MinimapYards()
	local width = Minimap:GetWidth() or 0
	local size = reach and across and across > 0 and 2 * reach * width / across
	if not (running and size and size >= 6 and size <= width and On("rangeMinimap")) then
		mapRing:Hide()
		return
	end
	mapRing:SetWidth(size)
	mapRing:SetHeight(size)
	mapRing:Show()
end

-- On the ground: under the beams, a child of WorldFrame as they are.
local ground = CreateFrame("Frame", "SurvivorUIWorldRange", WorldFrame)
ground:SetAllPoints(WorldFrame)
ground:Hide()
local dots = {}
local ringAsk, lines = {}, {}    -- the circle's points, asked anew each frame; the lines between
for index = 1, RING_POINTS do
	ringAsk[index] = { anchorId = "", attachment = "position", offset = { x = 0, y = 0, z = 0 } }
	lines[index] = {}
end

local function Dot(index)
	local dot = dots[index]
	if not dot then
		dot = ground:CreateTexture(nil, "BACKGROUND")
		dot:SetTexture(ART.."PaceDot")
		dot:SetWidth(DOT_SIZE)
		dot:SetHeight(DOT_SIZE)
		dot:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 0.8)
		dots[index] = dot
	end
	return dot
end

local function HideDots(first)
	for index = first, table.getn(dots) do
		dots[index]:Hide()
	end
end

-- The circle's points on the screen, by offset from the anchor that stays
-- put, then dots along the lines between them: a line with an end off the
-- screen left out.
local function DrawRing()
	if not (reach and base and heroAt and On("rangeWorld")) then
		HideDots(1)
		return
	end
	for index = 1, RING_POINTS do
		local angle = 2 * math.pi * (index - 1) / RING_POINTS
		local ask = ringAsk[index]
		ask.anchorId = base.id
		ask.offset.x = heroAt.x + reach * math.cos(angle) - base.x
		ask.offset.y = heroAt.y + reach * math.sin(angle) - base.y
		ask.offset.z = heroAt.z - base.z
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, ringAsk)
	local points = ok and result and result.entries or {}
	local around = 0
	for index = 1, RING_POINTS do
		local a, b = points[index], points[math.mod(index, RING_POINTS) + 1]
		local line = lines[index]
		line.on = a and b and a.state == "onScreen" and b.state == "onScreen" and a.x and b.x and true or false
		if line.on then
			line.x, line.y, line.dx, line.dy = a.x, a.y, b.x - a.x, b.y - a.y
			line.length = math.sqrt(line.dx * line.dx + line.dy * line.dy)
			around = around + line.length
		end
	end
	local gap = math.max(DOT_GAP, around / MOST_DOTS)
	local used, carry = 0, 0
	for index = 1, RING_POINTS do
		local line = lines[index]
		if not line.on then
			carry = 0
		elseif line.length > 0 then
			local at = carry
			while at < line.length and used < MOST_DOTS do
				used = used + 1
				local dot = Dot(used)
				local share = at / line.length
				dot:SetPoint("CENTER", ground, "BOTTOMLEFT", line.x + line.dx * share, line.y + line.dy * share)
				dot:Show()
				at = at + gap
			end
			carry = at - line.length
		end
	end
	HideDots(used + 1)
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
