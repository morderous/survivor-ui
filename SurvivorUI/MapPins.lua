-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: caches and lairs on the minimap.
--
-- The game shares every cache on the field (AZS_CHESTS) and every guardian's
-- lair (AZS_GetLairs), each with its place in the world (x, y, in yards) and
-- on the zone's map (mx, my). Since the game's 0.97 it shares the hero's
-- place in the world too (AZS_RUN px, py) and the way faced (pf): the pins go
-- by those yards, on every map, instances too. On an older game the hero's
-- place comes from the map (GetPlayerMapPosition), and the yards a map unit
-- spans are worked out from two shared places far apart.
--
-- A cache is a golden chest; a lair a horned skull (Art\PinLair, the one the
-- world markers and Survivor Plates' guardians wear), bright while its
-- guardian holds it, dimmed once it is empty. One beyond the
-- minimap's edge sits on the edge, smaller and fainter, pointing the way.
-- Hover a pin for what it is.
-- The options' Minimap tab sets them: lairs and caches each on or off and its
-- size, an empty lair dimmed or hidden, with its guardian's return under it or
-- not, a pin out of reach on the edge or hidden. All off with "Caches on the
-- minimap" (Modules); /sui pins prints
-- what the addon reads, to check it.
-- The same tab sets the hero's own marker in the minimap's middle: the game's
-- arrow, or ours in its place (at the end of this file).
-- The guardians' rings, where one wakes and how far from its lair you may go
-- before it gives up, are drawn here too (the options' World markers).

if SurvivorUI_Standby then return end

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local PIN_SIZE = 16                -- a pin's size untouched; on the edge, 11 of each 16
local EDGE_SIZE = 11

-- The yards across the minimap at each zoom level, as the 1.12 client draws
-- it (the game's too): outdoors, and indoors (in a building, most of an
-- instance), where it draws closer and keeps a zoom of its own.
local MINIMAP_YARDS = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 }
local INSIDE_YARDS = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }

local function Enabled()
	return not SurvivorUI_Feature or SurvivorUI_Feature("mapPins")
end

local function Playing()
	if not (AZS_GetPhase and AZS_CHESTS) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase == "playing" or phase == "choosing" or phase == "paused"
end

-- A map coordinate as a share of the map, 0 to 1, whether the game sends it
-- that way or in percent. A map the client has none of (an instance's) comes
-- as -1: no place on it.
local function Share(value)
	value = tonumber(value)
	if not value or value < 0 then
		return nil
	end
	if value > 1.5 then
		return value / 100
	end
	return value
end

------------------------------------------------------------------------------
-- The yards a map unit spans, across (mx) and down (my). On a WoW map, across
-- runs along the world's y and down along its x. Kept per zone once found.

local spans = {}                -- [zone name] = { across, down }

local function Places()
	local list = {}
	for index = 1, table.getn(AZS_CHESTS or {}) do
		table.insert(list, AZS_CHESTS[index])
	end
	if AZS_GetLairs then
		local lairs = AZS_GetLairs()
		for index = 1, table.getn(lairs or {}) do
			table.insert(list, lairs[index])
		end
	end
	return list
end

-- Two places this far apart on the map at least (a share of it): a run can
-- fill only a corner of a big zone's map (Feralas: its lairs lie within 3% of
-- it), and the game gives four decimals, so even that close they tell the
-- yards to a fraction of a percent. The farthest pair found so far is kept,
-- and a farther one, once shared, betters it.
local NEAREST = 0.004

local function Span()
	local zone = (AZS_ZONE and AZS_ZONE.zname) or "?"
	local known = spans[zone] or { baseAcross = 0, baseDown = 0 }
	local places = Places()
	for a = 1, table.getn(places) do
		for b = a + 1, table.getn(places) do
			local p, q = places[a], places[b]
			local pmx, qmx, pmy, qmy = Share(p.mx), Share(q.mx), Share(p.my), Share(q.my)
			local px, qx, py, qy = tonumber(p.x), tonumber(q.x), tonumber(p.y), tonumber(q.y)
			if pmx and qmx and pmy and qmy and px and qx and py and qy then
				local dmx, dmy = math.abs(pmx - qmx), math.abs(pmy - qmy)
				if dmx > known.baseAcross and dmx > NEAREST then
					known.baseAcross = dmx
					known.foundAcross = math.abs(py - qy) / dmx
				end
				if dmy > known.baseDown and dmy > NEAREST then
					known.baseDown = dmy
					known.foundDown = math.abs(px - qx) / dmy
				end
			end
		end
	end
	-- A map is drawn to scale: one side found gives the other.
	known.across = known.foundAcross or (known.foundDown and known.foundDown * 3 / 2)
	known.down = known.foundDown or (known.foundAcross and known.foundAcross * 2 / 3)
	spans[zone] = known
	if known.across and known.down then
		return known
	end
end

------------------------------------------------------------------------------
-- The pins.

local pins = {}

local function Pin(index)
	local pin = pins[index]
	if pin then
		return pin
	end
	pin = CreateFrame("Frame", nil, Minimap)
	pin:SetFrameLevel(Minimap:GetFrameLevel() + 4)
	pin.art = pin:CreateTexture(nil, "OVERLAY")
	pin.art:SetAllPoints(pin)
	-- The game's flag, ours: a gold glow breathing behind the lair it points at.
	pin.glow = pin:CreateTexture(nil, "ARTWORK")
	pin.glow:SetTexture(ART.."PaceGlow")
	pin.glow:SetBlendMode("ADD")
	pin.glow:SetVertexColor(1, 0.82, 0.2)
	pin.glow:SetPoint("CENTER", pin, "CENTER", 0, 0)
	pin.glow:Hide()
	-- How long till a lair's guardian is back (the options' Minimap tab).
	pin.timer = pin:CreateFontString(nil, "OVERLAY")
	pin.timer:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	pin.timer:SetPoint("TOP", pin, "BOTTOM", 0, -1)
	pin.timer:SetTextColor(1, 1, 1)
	pin.timer:Hide()
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.title or "", 1, 0.82, 0)
		if this.note then
			GameTooltip:AddLine(this.note, 0.8, 0.8, 0.8)
		end
		if this.flagged then
			GameTooltip:AddLine(SurvivorUI_T("The game's flag points here."), 1, 0.82, 0.2)
		end
		if this.yards then
			GameTooltip:AddLine(SurvivorUI_TF("{1} yards away", math.floor(this.yards + 0.5)), 0.6, 0.6, 0.6)
		end
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
	pins[index] = pin
	return pin
end

-- The hero's place on the zone's map.
local function HeroPlace()
	if not GetPlayerMapPosition then
		return nil
	end
	local x, y = GetPlayerMapPosition("player")
	if (not x or (x == 0 and y == 0)) and SetMapToCurrentZone then
		SetMapToCurrentZone()
		x, y = GetPlayerMapPosition("player")
	end
	if not x or (x == 0 and y == 0) then
		return nil
	end
	return x, y
end

-- The guardians' panel (Guardians.lua) finds its way the same way.
SurvivorUI_HeroPlace = HeroPlace
SurvivorUI_MapSpan = Span
SurvivorUI_MapShare = Share

-- The hero's place in the world, in the caches' and lairs' yards, and the way
-- faced in radians clockwise from north, as the arrows read it (a WoW
-- orientation: 0 north, turning toward the west). The game's live place (its
-- 0.132), in dungeons and raids too; else the px, py and pf it sends a few
-- times a second. Nil on a game that sends neither (before 0.97).
local function HeroWorld()
	local place = AZS_GetPlayerPosition and AZS_GetPlayerPosition()
	if place then
		return place.x, place.y, -place.facing
	end
	local run = AZS_RUN
	if not run then
		return nil
	end
	local px, py = tonumber(run.px), tonumber(run.py)
	if not (px and py) then
		return nil
	end
	local facing = tonumber(run.pf)
	if facing then
		facing = -facing
	end
	return px, py, facing
end

-- From the hero to a place in the world, in yards: east and south. In the
-- world, x runs north and y west.
local function WorldWay(px, py, x, y)
	return py - y, px - x
end

SurvivorUI_HeroWorld = HeroWorld
SurvivorUI_WorldWay = WorldWay

------------------------------------------------------------------------------
-- Indoors or out, as the minimap draws. Its zoom is the setting
-- minimapInsideZoom's indoors and minimapZoom's outdoors, so while the two
-- differ the zoom tells. While they are the same, a step of the zoom and back
-- does, for the step moves only the setting in use (as Gatherer read it in
-- 1.12); that is tried as the place changes. Where even that tells nothing, a
-- place with no map (an instance's) counts as indoors.

local function Setting(name)
	local ok, value = pcall(GetCVar, name)
	return ok and value or nil
end

local probed                    -- indoors, by the last step of the zoom; nil: untold
local probing = false

local function Probe()
	local zoom = Minimap:GetZoom()
	local outside, inside = tonumber(Setting("minimapZoom")), tonumber(Setting("minimapInsideZoom"))
	if not (zoom and outside and inside) or outside ~= inside then
		return
	end
	probing = true
	local step = zoom > 0 and -1 or 1
	Minimap:SetZoom(zoom + step)
	local nowOutside, nowInside = tonumber(Setting("minimapZoom")), tonumber(Setting("minimapInsideZoom"))
	Minimap:SetZoom(zoom)
	probing = false
	if nowInside ~= inside then
		probed = true
	elseif nowOutside ~= outside then
		probed = false
	else
		probed = nil
	end
end

local function Indoors()
	local zoom = Minimap:GetZoom()
	local outside, inside = tonumber(Setting("minimapZoom")), tonumber(Setting("minimapInsideZoom"))
	if zoom and outside and inside and outside ~= inside then
		return zoom == inside
	end
	if probed ~= nil then
		return probed
	end
	return not HeroPlace()
end

local prober = CreateFrame("Frame")
prober:RegisterEvent("PLAYER_ENTERING_WORLD")
prober:RegisterEvent("ZONE_CHANGED")
prober:RegisterEvent("ZONE_CHANGED_INDOORS")
prober:RegisterEvent("ZONE_CHANGED_NEW_AREA")
prober:RegisterEvent("MINIMAP_UPDATE_ZOOM")
prober:SetScript("OnEvent", function()
	if not probing then
		Probe()
	end
end)

-- The pins' settings (the options' Minimap tab): lairs and caches each on or
-- off and its size, an empty lair dimmed or hidden, a pin out of reach on the
-- edge or hidden.
local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

-- A kind's pin size, "lair" or "cache": 10 to 28, 16 untouched. The lairs'
-- sizes the bosses' and the elites' too (UNIT_PIN, below: 4 larger, 2 smaller).
function SurvivorUI_PinSize(kind)
	local size = tonumber(Settings()[kind == "cache" and "pinCacheSize" or "pinLairSize"])
	return size and math.max(10, math.min(28, size)) or PIN_SIZE
end

function SurvivorUI_SetPinSize(kind, size)
	Settings()[kind == "cache" and "pinCacheSize" or "pinLairSize"] = size ~= PIN_SIZE and size or nil
end

------------------------------------------------------------------------------
-- The game's red flag on the minimap, on the lair it points at (from the
-- game's 0.102: the nearest held, else the one back soonest; each lair's
-- flag field): "ours" (untouched), the game's flag away and that lair's pin
-- glowing instead, its mark in the run tracker too (Guardians.lua); "game",
-- the game's flag; "none", neither. The setting is the game's and is saved,
-- so the addon remembers that it was the one to turn it off.

local function FlagChoice()
	return Settings().gameFlag or "ours"
end

-- With the pins off (Modules), the game's flag is back, as every part's own
-- is with SurvivorUI's off, unless The game's is unticked there (noGameFlag).
local function ApplyGameFlag()
	if not (AZS_SetHudShown and AZS_IsHudShown and AZS_GetFlaggedLair) then
		return
	end
	local settings = Settings()
	local away
	if Enabled() then
		away = FlagChoice() ~= "game"
	else
		away = settings.noGameFlag
	end
	if away then
		if AZS_IsHudShown("flag") then
			AZS_SetHudShown("flag", false)
			settings.hidGameFlag = true
		end
	elseif settings.hidGameFlag then
		AZS_SetHudShown("flag", true)
		settings.hidGameFlag = nil
	end
end

-- For the options' Minimap tab and the run tracker: "ours", "game" or "none";
-- nil on a game without the flag (before 0.102).
function SurvivorUI_GameFlag()
	return AZS_GetFlaggedLair and FlagChoice() or nil
end

function SurvivorUI_SetGameFlag(choice)
	Settings().gameFlag = choice ~= "ours" and choice or nil
	ApplyGameFlag()
end

local flagLoader = CreateFrame("Frame")
flagLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
flagLoader:SetScript("OnEvent", ApplyGameFlag)

-- For the options' Modules: the game's flag ticked or not.
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.flag = ApplyGameFlag

local flaggedPin                -- the pin glowing for the game's flag, if one

-- The yards the minimap spans across, now; the range ring's too (WorldMarks.lua).
local function MinimapYards()
	local zoom = Minimap:GetZoom() or 0
	local yards = Indoors() and INSIDE_YARDS or MINIMAP_YARDS
	return yards[zoom] or yards[0], zoom
end
SurvivorUI_MinimapYards = MinimapYards

-- A pin at its size: beyond the square's edge, on the edge (on the line toward
-- it, smaller and fainter), or hidden with "Out of reach: hidden".
local function Place(pin, east, south, yardsAcross, size)
	local half = Minimap:GetWidth() / 2
	local perYard = (2 * half) / yardsAcross
	pin.yards = math.sqrt(east * east + south * south)
	local px, py = east * perYard, -south * perYard
	local edge = math.floor(size * EDGE_SIZE / PIN_SIZE + 0.5)
	local reach = math.max(math.abs(px), math.abs(py))
	local limit = half - edge / 2
	if reach > limit then
		if Settings().pinEdge == "hide" then
			pin:Hide()
			return
		end
		px, py = px * limit / reach, py * limit / reach
		size = edge
		pin:SetAlpha(0.7)
	else
		pin:SetAlpha(1)
	end
	pin:SetWidth(size)
	pin:SetHeight(size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", Minimap, "CENTER", px, py)
	pin:Show()
end

-- From the hero to a cache or a lair, east and south in yards: by the world's
-- yards when the game sends the hero's, else by the map.
local function WayTo(place, px, py, heroX, heroY, span)
	local x, y = tonumber(place.x), tonumber(place.y)
	if px and x and y then
		return WorldWay(px, py, x, y)
	end
	local mx, my = Share(place.mx), Share(place.my)
	if heroX and span and mx and my then
		return (mx - heroX) * span.across, (my - heroY) * span.down
	end
end

------------------------------------------------------------------------------
-- The ones on the move (the game's 0.139.2 world anchors, as WorldMarks.lua
-- reads them; ZA5TEESH, 2026-11-03): an awake guardian's lair pin follows it
-- as it leaves the lair to fight, and the bosses (elites too, with "Elites")
-- get a pin of their own that goes where they go. On an older game, none.

local MOVING = { "guardian", "elite", "boss", "finalBoss", "guardianLair" }
local UNIT_PIN = {
	boss = { art = "PinBoss", title = "Boss", size = 4 },
	finalBoss = { art = "PinBoss", title = "Final boss", size = 4, glow = { 1, 0.5, 0 } },
	elite = { art = "PinElite", title = "Elite", size = -2 },
}

-- The guardians away from their lairs ([lair index] = the guardian's anchor)
-- and the bosses and elites, alive, from the game's anchors now; and every
-- lair's anchor with its guardian's, for the guardians' rings (below).
local function Moving()
	local away, units, lairs = {}, {}, {}
	if not AZS_GetWorldAnchors then
		return away, units, lairs
	end
	local ok, result = pcall(AZS_GetWorldAnchors, { kinds = MOVING }, nil, 256)
	if not (ok and type(result) == "table" and result.entries) then
		return away, units, lairs
	end
	local byId = {}
	for index = 1, table.getn(result.entries) do
		local entry = result.entries[index]
		if entry.unitId and entry.state == "alive" then
			byId[tonumber(entry.unitId)] = entry
			if UNIT_PIN[entry.kind] then
				table.insert(units, entry)
			end
		end
	end
	for index = 1, table.getn(result.entries) do
		local entry = result.entries[index]
		local guardian = entry.kind == "guardianLair" and entry.state == "awake" and entry.occupantUnitId
			and byId[tonumber(entry.occupantUnitId)]
		if guardian and entry.lairIndex then
			away[tonumber(entry.lairIndex)] = guardian
		end
		if entry.kind == "guardianLair" and tonumber(entry.x) and tonumber(entry.y) then
			table.insert(lairs, { lair = entry, guardian = entry.occupantUnitId and byId[tonumber(entry.occupantUnitId)] })
		end
	end
	return away, units, lairs
end

------------------------------------------------------------------------------
-- The guardians' rings on the minimap, by the game's rule (WorldMarks.lua
-- tells it, and draws them on the ground): round an awake guardian's lair, a
-- circle of dots LEASH yards out, the line it gives up at, turning red in
-- your last WARN yards ("Warning"); round the nearest guardian asleep at home,
-- the WAKE yards it wakes at, once the zoom makes it wide enough to read round
-- its pin. Each with its own switch, color and opacity, and "On the minimap"
-- (the options' Range ring tab).
-- Only the dots inside the minimap are shown: its square, or the game's
-- round one; under the pins and the clock's strip.

local LeashMap
do
	local WAKE, HOME, LEASH, WARN = 20, 3, 97.5, 10   -- as WorldMarks.lua's
	local AWAKE, LATE = { 1.00, 0.62, 0.22 }, { 1.00, 0.28, 0.22 }
	local SPACING, DOT = 5, 3
	local ring = CreateFrame("Frame", "SurvivorUILeashRing", Minimap)
	ring:SetFrameLevel(Minimap:GetFrameLevel() + 2)   -- the range ring's, under the clock's strip (+3)
	ring:SetAllPoints(Minimap)
	local dots = {}

	local function On(key)
		return SurvivorUI_WorldOn and SurvivorUI_WorldOn(key)
	end

	-- Each ring's color and opacity, as on the ground ("Wake" or "Leash", the
	-- options' Range ring tab); always dots here, DOT wide.
	local function Color(which)
		if SurvivorUI_RangeColor then
			return SurvivorUI_RangeColor(which)
		end
		return AWAKE[1], AWAKE[2], AWAKE[3]
	end

	local function Alpha(which)
		return SurvivorUI_RangeLook and SurvivorUI_RangeLook(which, "Alpha") or 0.85
	end

	-- A circle of dots from used + 1 on, its middle cx, cy and radius in
	-- pixels from the minimap's middle; how many dots used back.
	local function Circle(used, cx, cy, radius, r, g, b, a)
		local half = Minimap:GetWidth() / 2 - DOT / 2
		local round = SurvivorUI_Feature and not SurvivorUI_Feature("minimap")
		local count = math.max(16, math.min(120, math.floor(2 * math.pi * radius / SPACING)))
		for index = 1, count do
			local angle = 2 * math.pi * index / count
			local x, y = cx + radius * math.cos(angle), cy + radius * math.sin(angle)
			local inside
			if round then
				inside = x * x + y * y <= half * half
			else
				inside = math.abs(x) <= half and math.abs(y) <= half
			end
			if inside then
				used = used + 1
				local dot = dots[used]
				if not dot then
					dot = ring:CreateTexture(nil, "ARTWORK")
					dot:SetTexture(ART.."PaceDot")
					dot:SetWidth(DOT)
					dot:SetHeight(DOT)
					dots[used] = dot
				end
				dot:SetVertexColor(r, g, b, a)
				dot:ClearAllPoints()
				dot:SetPoint("CENTER", Minimap, "CENTER", x, y)
				dot:Show()
			end
		end
		return used
	end

	-- lairs from Moving(); nil hides them.
	LeashMap = function(lairs, px, py, yardsAcross)
		local used = 0
		if lairs and px and yardsAcross and On("leashMinimap") then
			local perYard = Minimap:GetWidth() / yardsAcross
			local nearest, nearestYards
			for index = 1, table.getn(lairs) do
				local lair, guardian = lairs[index].lair, lairs[index].guardian
				local lx, ly = tonumber(lair.x), tonumber(lair.y)
				local east, south = WorldWay(px, py, lx, ly)
				local yards = math.sqrt(east * east + south * south)
				if lair.state == "awake" and On("leashReset") then
					local r, g, b = Color("Leash")
					local a = Alpha("Leash")
					local left = LEASH - yards
					if left < WARN and On("leashWarn") then
						local share = 0.5 + 0.5 * math.max(0, math.min(1, 1 - left / WARN))
						r = r + (LATE[1] - r) * share
						g = g + (LATE[2] - g) * share
						b = b + (LATE[3] - b) * share
						a = 1
					end
					used = Circle(used, east * perYard, -south * perYard, LEASH * perYard, r, g, b, a)
				elseif lair.state == "asleep" and (not nearestYards or yards < nearestYards) then
					-- Home: within HOME yards of its lair (walking home, only a hit wakes it).
					local gx, gy = guardian and tonumber(guardian.x), guardian and tonumber(guardian.y)
					local away = gx and gy and math.sqrt((gx - lx) * (gx - lx) + (gy - ly) * (gy - ly)) or 0
					if away <= HOME then
						nearest, nearestYards = { x = lx, y = ly }, yards
					end
				end
			end
			-- Wide enough to read round the lair's pin.
			if nearest and On("leashWake") and 2 * WAKE * perYard >= 1.6 * SurvivorUI_PinSize("lair") then
				local east, south = WorldWay(px, py, nearest.x, nearest.y)
				local r, g, b = Color("Wake")
				used = Circle(used, east * perYard, -south * perYard, WAKE * perYard, r, g, b, Alpha("Wake"))
			end
		end
		for index = used + 1, table.getn(dots) do
			dots[index]:Hide()
		end
	end
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

local pinsWere                  -- the pins on or off at the last look

local function Update()
	local shown, ringed = 0, false
	flaggedPin = nil
	-- The pins switched on or off (Modules, at once): the game's flag follows.
	if Enabled() ~= pinsWere then
		pinsWere = Enabled()
		ApplyGameFlag()
	end
	if Enabled() and Playing() then
		local px, py = HeroWorld()
		local heroX, heroY, span
		if not px then
			heroX, heroY = HeroPlace()
			span = heroX and Span()
		end
		if px or span then
			local settings = Settings()
			local yardsAcross = MinimapYards()
			local chests = settings.pinCaches ~= false and AZS_CHESTS or {}
			local cacheSize = SurvivorUI_PinSize("cache")
			for index = 1, table.getn(chests) do
				local chest = chests[index]
				local east, south = WayTo(chest, px, py, heroX, heroY, span)
				if east then
					shown = shown + 1
					local pin = Pin(shown)
					pin.art:SetTexture(ART.."PinCache")
					pin.art:SetTexCoord(0, 1, 0, 1)
					pin.art:SetVertexColor(1, 1, 1)
					pin.glow:Hide()
					pin.title, pin.note, pin.flagged = "Cache", nil, nil
					pin.timer:Hide()
					Place(pin, east, south, yardsAcross, cacheSize)
				end
			end
			local lairs = settings.pinLairs ~= false and AZS_GetLairs and AZS_GetLairs() or {}
			local lairSize = SurvivorUI_PinSize("lair")
			-- The game's seconds left are from its last word; while it plays they
			-- run on from there (Guardians.lua).
			local since = AZS_LAIRS_UPDATED and AZS_GetPhase() == "playing" and GetTime() - AZS_LAIRS_UPDATED or 0
			local away, units, rings = Moving()
			LeashMap(rings, px, py, yardsAcross)
			ringed = true
			if settings.pinFollow == false or not px then
				away = {}
			end
			for index = 1, table.getn(lairs) do
				local lair = lairs[index]
				-- Awake and out to fight: where its guardian is.
				local guardian = lair.active and away[tonumber(lair.index) or index]
				local east, south = WayTo(guardian or lair, px, py, heroX, heroY, span)
				if east and (lair.active or settings.pinEmpty ~= "hide") then
					shown = shown + 1
					local pin = Pin(shown)
					-- The skull, dimmed while the lair is empty.
					pin.art:SetTexture(ART.."PinLair")
					pin.art:SetTexCoord(0, 1, 0, 1)
					if lair.active then
						pin.art:SetVertexColor(1, 1, 1)
					else
						pin.art:SetVertexColor(0.45, 0.45, 0.45)
					end
					if guardian then
						pin.note = SurvivorUI_TF("Awake: {1}, on the move", guardian.name or lair.name or "?")
					elseif lair.active then
						pin.note = "Guardian's lair: "..(lair.name and lair.name ~= "" and lair.name or "a guardian holds it")
					else
						pin.note = "Empty lair"
					end
					pin.title = SurvivorUI_T("Lair")
					pin.flagged = tonumber(lair.flag) == 1 or nil
					local left = settings.pinTimers and not lair.active and (tonumber(lair.left) or -1) - since
					if left and left > 0 then
						pin.timer:SetText(Clock(left))
						pin.timer:Show()
					else
						pin.timer:Hide()
					end
					if pin.flagged and FlagChoice() == "ours" then
						pin.glow:SetVertexColor(1, 0.82, 0.2)
						flaggedPin = pin
					else
						pin.glow:Hide()
					end
					Place(pin, east, south, yardsAcross, lairSize)
				end
			end
			-- The bosses, and the elites with "Elites", where they are.
			for index = 1, table.getn(px and units or {}) do
				local unit = units[index]
				local look = UNIT_PIN[unit.kind]
				local on
				if unit.kind == "elite" then
					on = settings.pinElites == true
				else
					on = settings.pinBosses ~= false
				end
				local x, y = tonumber(unit.x), tonumber(unit.y)
				if on and x and y then
					shown = shown + 1
					local pin = Pin(shown)
					pin.art:SetTexture(ART..look.art)
					pin.art:SetTexCoord(0, 1, 0, 1)
					pin.art:SetVertexColor(1, 1, 1)
					pin.title = SurvivorUI_T(look.title)
					pin.note = unit.name
					pin.flagged = nil
					pin.timer:Hide()
					if look.glow then
						-- The final boss: an orange glow behind, as its plate's color.
						local size = (lairSize + look.size) * 2.2
						pin.glow:SetWidth(size)
						pin.glow:SetHeight(size)
						pin.glow:SetVertexColor(look.glow[1], look.glow[2], look.glow[3])
						pin.glow:SetAlpha(0.8)
						pin.glow:Show()
					else
						pin.glow:Hide()
					end
					local east, south = WorldWay(px, py, x, y)
					Place(pin, east, south, yardsAcross, math.max(10, lairSize + look.size))
				end
			end
		end
	end
	for index = shown + 1, table.getn(pins) do
		pins[index]:Hide()
	end
	if not ringed then
		LeashMap(nil)
	end
end

local elapsed = 0
local breath = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 0.1 then
		elapsed = 0
		Update()
	end
	-- The flagged lair's glow breathes, every frame.
	breath = breath + arg1
	if flaggedPin and flaggedPin:IsShown() then
		local size = flaggedPin:GetWidth() * (2.4 + 0.35 * math.sin(breath * 4))
		flaggedPin.glow:SetWidth(size)
		flaggedPin.glow:SetHeight(size)
		flaggedPin.glow:SetAlpha(0.6 + 0.3 * math.sin(breath * 4))
		flaggedPin.glow:Show()
	end
end)

-- The nearest of a list of places, by the world's yards: how far, east and
-- south.
local function Nearest(list, px, py)
	local best, bestEast, bestSouth
	for index = 1, table.getn(list) do
		local x, y = tonumber(list[index].x), tonumber(list[index].y)
		if x and y then
			local east, south = WorldWay(px, py, x, y)
			local yards = math.sqrt(east * east + south * south)
			if not best or yards < best then
				best, bestEast, bestSouth = yards, east, south
			end
		end
	end
	return best, bestEast, bestSouth
end

local COMPASS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }

local function Compass(east, south)
	local bearing = math.atan2(east, -south) * 180 / math.pi
	return COMPASS[math.mod(math.floor((bearing + 22.5) / 45) + 8, 8) + 1]
end

-- /sui pins: what the addon reads, to check the pins against the world.
function SurvivorUI_PinsReport()
	local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Survivor UI|r "..text) end
	say("zone: "..tostring(AZS_ZONE and AZS_ZONE.zone).." (map "..tostring(AZS_ZONE and AZS_ZONE.map)
		.."); the client's: "..tostring(GetRealZoneText and GetRealZoneText()))
	local chests = AZS_CHESTS or {}
	local lairs = AZS_GetLairs and AZS_GetLairs() or {}
	say("caches: "..table.getn(chests)..", lairs: "..table.getn(lairs))
	local px, py, facing = HeroWorld()
	if px then
		-- The way faced, as a compass reads it: 0 north, 90 east.
		local degrees = facing and math.mod(math.floor(facing * 180 / math.pi + 0.5) + 720, 360)
		say(string.format("hero in the world: x %.1f, y %.1f; facing %s", px, py,
			degrees and (degrees.."° (0 north, 90 east)") or "not sent"))
		local yards, east, south = Nearest(chests, px, py)
		if yards then
			say(string.format("nearest cache: %d yards %s", math.floor(yards + 0.5), Compass(east, south)))
		end
		yards, east, south = Nearest(lairs, px, py)
		if yards then
			say(string.format("nearest lair: %d yards %s", math.floor(yards + 0.5), Compass(east, south)))
		end
	else
		say("hero in the world: not sent by this version of the game")
		local heroX, heroY = HeroPlace()
		say("hero on the map: "..(heroX and string.format("%.3f, %.3f", heroX, heroY) or "unknown"))
		local span = Span()
		if span then
			say(string.format("map spans %.0f yards across, %.0f down", span.across, span.down))
		else
			say("map size not found yet: needs two caches or lairs far apart")
		end
	end
	local yardsAcross, zoom = MinimapYards()
	say(string.format("minimap: %s, zoom %d, %d yards across (zoom set outdoors %s, indoors %s)",
		Indoors() and "indoors" or "outdoors", zoom, math.floor(yardsAcross + 0.5),
		tostring(Setting("minimapZoom")), tostring(Setting("minimapInsideZoom"))))
end

------------------------------------------------------------------------------
-- You on the minimap (the options' Minimap tab): the game's arrow, untouched,
-- or ours in its place: a dot, a dot with a small arrow the way you walk, an
-- arrow the way you walk, or a cross; its size (S, M, L) and its color (the
-- range ring's colors, the class's first).
--
-- The game's arrow is the minimap's player model, as in 1.12: an empty name
-- for Minimap:SetPlayerModel takes it away (the game then says it could not
-- load the file, kept quiet), its own file brings it back. Read and tried in
-- the game's 0.139 (2026-11-03): its facing (AZS_GetPlayerPosition's, AZS_RUN
-- pf, the arrow's) stays one way through a run as the hero walks every way,
-- the way the camera looks (1.6, west, in Elwynn); only the hero's model
-- turns. So ours points the way the hero last walked, from its place in the
-- world; till it walks, the game's way. North is up on the minimap.

local GAME_ARROW = "Interface\\Minimap\\MinimapArrow.mdx"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local MARKER_SIZE = { dot = 8, dotArrow = 8, arrow = 14, cross = 11 }   -- each one's at M
local SHEET = 8                 -- Art\GuardianArrow: 8 by 8 cells, 64 ways, clockwise from up
local marker                    -- our marker's frame, made the first time it shows
local markerLook = {}           -- what it was last laid out for
local markerParts = { dark = {}, light = {} }
local arrowAway                 -- the game's arrow taken away by us
local walked, walkX, walkY      -- the way last walked (radians clockwise from north), and from where

-- The arrow sheet's cell nearest a way (radians clockwise from north), 0 to
-- 63, and that cell's corners for SetTexCoord.
function SurvivorUI_ArrowCellOf(way)
	local cells = SHEET * SHEET
	local k = math.mod(math.floor(way / (2 * math.pi) * cells + 0.5), cells)
	if k < 0 then
		k = k + cells
	end
	return k
end

function SurvivorUI_ArrowCell(way)
	local k = SurvivorUI_ArrowCellOf(way)
	local column, line = math.mod(k, SHEET), math.floor(k / SHEET)
	return column / SHEET, (column + 1) / SHEET, line / SHEET, (line + 1) / SHEET
end

-- The marker chosen, its size (a share of M) and its color's key.
function SurvivorUI_HeroMarker()
	local settings = Settings()
	return settings.heroMarker or "game", tonumber(settings.heroMarkerSize) or 1, settings.heroMarkerColor or "class"
end

-- Whether this game lets the arrow go (Minimap:SetPlayerModel).
function SurvivorUI_HeroMarkerUsable()
	return Minimap and Minimap.SetPlayerModel and true or false
end

function SurvivorUI_HeroMarkerColor(key)
	key = key or Settings().heroMarkerColor or "class"
	if key == "class" and SurvivorUI_ClassColor and UnitClass then
		local _, class = UnitClass("player")
		if class then
			return SurvivorUI_ClassColor(class)
		end
	end
	local list = SurvivorUI_RANGE_COLORS or {}
	for index = 1, table.getn(list) do
		local entry = list[index]
		if entry[1] == key and entry[3] then
			return entry[3][1], entry[3][2], entry[3][3]
		end
	end
	return 1, 1, 1
end

-- The way last walked, measured each 0.6 yards gone (a jump of 40 yards at
-- once, a new run or a port, starts again from there).
local function Walk()
	local px, py = HeroWorld()
	if not px then
		return
	end
	if not walkX then
		walkX, walkY = px, py
		return
	end
	local north, east = px - walkX, walkY - py
	local far = north * north + east * east
	if far > 1600 then
		walkX, walkY = px, py
	elseif far >= 0.36 then
		walked = math.atan2(east, north)
		walkX, walkY = px, py
	end
end

-- The way ours points: the way last walked, else the game's; nil when
-- neither is known.
function SurvivorUI_HeroHeading()
	if walked then
		return walked
	end
	local _, _, facing = HeroWorld()
	return facing
end

-- Our marker's pieces, for the minimap and the options' preview alike, at a
-- way: each { art, width, height, x, y (from the middle, y up), dark (its
-- black edge, under the rest), way (the arrow sheet's cell for it) }.
function SurvivorUI_HeroMarkerPieces(choice, scale, way)
	local size = (MARKER_SIZE[choice] or MARKER_SIZE.dot) * (scale or 1)
	local pieces = {}
	way = way or 0
	if choice == "cross" then
		local thick = math.max(2, math.floor(size / 4 + 0.5))
		table.insert(pieces, { art = FLAT, width = size + 2, height = thick + 2, x = 0, y = 0, dark = true })
		table.insert(pieces, { art = FLAT, width = thick + 2, height = size + 2, x = 0, y = 0, dark = true })
		table.insert(pieces, { art = FLAT, width = size, height = thick, x = 0, y = 0 })
		table.insert(pieces, { art = FLAT, width = thick, height = size, x = 0, y = 0 })
	elseif choice == "arrow" then
		table.insert(pieces, { art = ART.."GuardianArrow", width = size + 4, height = size + 4, x = 0, y = 0, dark = true, way = way })
		table.insert(pieces, { art = ART.."GuardianArrow", width = size, height = size, x = 0, y = 0, way = way })
	else
		-- Art\HeroDot: a solid disc (Disc is a fill at 59%, for the range ring).
		table.insert(pieces, { art = ART.."HeroDot", width = size + 3, height = size + 3, x = 0, y = 0, dark = true })
		table.insert(pieces, { art = ART.."HeroDot", width = size, height = size, x = 0, y = 0 })
		if choice == "dotArrow" then
			-- Just ahead of the dot, its tail under it.
			local tip = size * 0.9
			local reach = size / 2 + tip * 0.25
			local x, y = reach * math.sin(way), reach * math.cos(way)
			table.insert(pieces, { art = ART.."GuardianArrow", width = tip + 4, height = tip + 4, x = x, y = y, dark = true, way = way })
			table.insert(pieces, { art = ART.."GuardianArrow", width = tip, height = tip, x = x, y = y, way = way })
		end
	end
	return pieces
end

-- The pieces on the minimap: the dark ones a layer under the rest.
local function LayOut(choice, scale, way)
	local pieces = SurvivorUI_HeroMarkerPieces(choice, scale, way)
	local r, g, b = SurvivorUI_HeroMarkerColor()
	local used = { dark = 0, light = 0 }
	for index = 1, table.getn(pieces) do
		local piece = pieces[index]
		local kind = piece.dark and "dark" or "light"
		used[kind] = used[kind] + 1
		local part = markerParts[kind][used[kind]]
		if not part then
			part = marker:CreateTexture(nil, piece.dark and "BORDER" or "ARTWORK")
			markerParts[kind][used[kind]] = part
		end
		part:SetTexture(piece.art)
		if piece.way then
			part:SetTexCoord(SurvivorUI_ArrowCell(piece.way))
		else
			part:SetTexCoord(0, 1, 0, 1)
		end
		if piece.dark then
			part:SetVertexColor(0, 0, 0, 0.85)
		else
			part:SetVertexColor(r, g, b, 1)
		end
		part:SetWidth(piece.width)
		part:SetHeight(piece.height)
		part:ClearAllPoints()
		part:SetPoint("CENTER", marker, "CENTER", piece.x, piece.y)
		part:Show()
	end
	for kind, pool in pairs(markerParts) do
		for index = used[kind] + 1, table.getn(pool) do
			pool[index]:Hide()
		end
	end
end

-- Each frame while it shows: the way walked, and the pieces laid out again
-- when the choice, its size, its color or the arrow's cell changed.
local function MarkerUpdate()
	local choice, scale, color = SurvivorUI_HeroMarker()
	local way, cell = 0, 0
	if choice == "arrow" or choice == "dotArrow" then
		Walk()
		cell = SurvivorUI_ArrowCellOf(SurvivorUI_HeroHeading() or 0)
		-- The cell's own way, so the arrow and its place agree.
		way = cell * 2 * math.pi / (SHEET * SHEET)
	end
	local look = markerLook
	if look.choice ~= choice or look.scale ~= scale or look.color ~= color or look.cell ~= cell then
		look.choice, look.scale, look.color, look.cell = choice, scale, color, cell
		LayOut(choice, scale, way)
	end
end

-- The game's arrow away while ours shows, back once the game's is chosen.
local function ApplyMarker()
	if not SurvivorUI_HeroMarkerUsable() then
		return
	end
	if (Settings().heroMarker or "game") ~= "game" then
		if not marker then
			marker = CreateFrame("Frame", nil, Minimap)
			marker:SetFrameLevel(Minimap:GetFrameLevel() + 6)
			marker:SetWidth(1)
			marker:SetHeight(1)
			marker:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
			marker:SetScript("OnUpdate", MarkerUpdate)
		end
		markerLook.choice = nil
		marker:Show()
		pcall(Minimap.SetPlayerModel, Minimap, "")
		arrowAway = true
	else
		if marker then
			marker:Hide()
		end
		if arrowAway then
			pcall(Minimap.SetPlayerModel, Minimap, GAME_ARROW)
			arrowAway = nil
		end
	end
end

-- field: "look" ("game", "dot", "dotArrow", "arrow", "cross"), "size" (a
-- share of M) or "color" (a key of SurvivorUI_RANGE_COLORS, or "class").
function SurvivorUI_SetHeroMarker(field, value)
	local settings = Settings()
	if field == "size" then
		settings.heroMarkerSize = value ~= 1 and value or nil
	elseif field == "color" then
		settings.heroMarkerColor = value ~= "class" and value or nil
	else
		settings.heroMarker = value ~= "game" and value or nil
	end
	ApplyMarker()
end

local markerLoader = CreateFrame("Frame")
markerLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
markerLoader:SetScript("OnEvent", ApplyMarker)
