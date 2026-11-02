-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: marks on the world itself, from the game's 0.139.2 world
-- anchors (AZS_GetWorldAnchors, AZS_ProjectWorldAnchors,
-- AZS_GetDownedPartyMembers), each its own switch (the options, World
-- markers):
--
-- - Friends down (co-op): over each, a gold cross, their name and how far;
--   their party frame reads the yards too (SurvivorUI_DownedYards).
-- - Caches: a chest over each one still there, with how far.
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
	worldOrbs = true, worldBars = false, markDrawn = true,
}

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
		mark = mark, bar = bar, name = entry.name, hp = unit and unit[1], hpm = unit and unit[2] }
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
				spot = { anchor = entry.anchorId, attachment = "position", lift = 1.2, look = "cache", arrow = true }
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
					name = entry.name, awake = true }
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
		if spot.anchor then
			table.insert(requests, { anchorId = spot.anchor, attachment = spot.attachment, offset = { x = 0, y = 0, z = spot.lift or 0 } })
			table.insert(wanted, spot)
		elseif base and spot.x then
			table.insert(requests, Spot(spot.x, spot.y, spot.z + (spot.lift or 0)))
			table.insert(wanted, spot)
		end
	end
	-- The hero's spot, for the arrows' way.
	local heroIndex
	if base and heroAt and On("worldArrows") then
		table.insert(requests, Spot(heroAt.x, heroAt.y, heroAt.z))
		heroIndex = table.getn(requests)
	end
	if table.getn(requests) == 0 or table.getn(requests) > 256 then
		HideFrom(marks, 1)
		HideFrom(arrows, 1)
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
			Paint(Mark(shown), spot, entry.x * ratio, entry.y * ratio, entry.playerDistance or Distance(spot))
		elseif spot.arrow and entry and (entry.state == "offscreen" or entry.state == "behindCamera") then
			table.insert(away, spot)
		end
	end
	HideFrom(marks, shown + 1)
	-- The arrows: the nearest spots out of sight, each by its way from the hero.
	local pointed = 0
	local hero = heroIndex and entries[heroIndex]
	if hero and hero.state == "onScreen" and hero.x then
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

local function Showing()
	return AZS_GetPhase and AZS_GetPhase() == "playing"
end

local waited = READ_EVERY
local function Frame()
	if not Showing() then
		if layer:IsShown() then
			layer:Hide()
		end
		return
	end
	if not layer:IsShown() then
		layer:Show()
	end
	local ok, p = pcall(AZS_GetPlayerPosition)
	heroAt = ok and p and p.x and { x = p.x, y = p.y, z = p.z or 0 } or nil
	Draw()
end

AZS_RegisterWorldAnchorFrameHandler(Frame)

-- The catalog, four times a second; the friends' yards for the party frames.
local reader = CreateFrame("Frame")
reader:SetScript("OnUpdate", function()
	waited = waited + arg1
	if waited < READ_EVERY then
		return
	end
	waited = 0
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
