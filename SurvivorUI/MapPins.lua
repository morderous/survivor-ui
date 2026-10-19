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
-- A cache is a golden chest; a lair its own mark (the one the guardians' bar
-- and list show, Guardians.lua), or with the marks off a horned skull, bright
-- while its guardian holds it, dimmed once it is empty. One beyond the
-- minimap's edge sits on the edge, smaller and fainter, pointing the way.
-- Hover a pin for what it is.
-- Off with the option "Caches and lairs on the minimap"; /sui pins prints what
-- the addon reads, to check it.

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local PIN_SIZE = 16
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
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.title or "", 1, 0.82, 0)
		if this.note then
			GameTooltip:AddLine(this.note, 0.8, 0.8, 0.8)
		end
		if this.yards then
			GameTooltip:AddLine(math.floor(this.yards + 0.5).." yards away", 0.6, 0.6, 0.6)
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
-- faced in radians clockwise from north, as the arrows read it (the game's
-- pf, a WoW orientation: 0 north, turning toward the west). Nil on a game
-- that does not send them (before 0.97).
local function HeroWorld()
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

-- The yards the minimap spans across, now.
local function MinimapYards()
	local zoom = Minimap:GetZoom() or 0
	local yards = Indoors() and INSIDE_YARDS or MINIMAP_YARDS
	return yards[zoom] or yards[0], zoom
end

local function Place(pin, east, south, yardsAcross)
	local half = Minimap:GetWidth() / 2
	local perYard = (2 * half) / yardsAcross
	pin.yards = math.sqrt(east * east + south * south)
	local px, py = east * perYard, -south * perYard
	-- Beyond the square's edge: on the edge, on the line toward it.
	local reach = math.max(math.abs(px), math.abs(py))
	local limit = half - EDGE_SIZE / 2
	local size = PIN_SIZE
	if reach > limit then
		px, py = px * limit / reach, py * limit / reach
		size = EDGE_SIZE
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

local function Update()
	local shown = 0
	if Enabled() and Playing() then
		local px, py = HeroWorld()
		local heroX, heroY, span
		if not px then
			heroX, heroY = HeroPlace()
			span = heroX and Span()
		end
		if px or span then
			local yardsAcross = MinimapYards()
			for index = 1, table.getn(AZS_CHESTS) do
				local chest = AZS_CHESTS[index]
				local east, south = WayTo(chest, px, py, heroX, heroY, span)
				if east then
					shown = shown + 1
					local pin = Pin(shown)
					pin.art:SetTexture(ART.."PinCache")
					pin.art:SetTexCoord(0, 1, 0, 1)
					pin.art:SetVertexColor(1, 1, 1)
					pin.title, pin.note = "Cache", nil
					Place(pin, east, south, yardsAcross)
				end
			end
			local lairs = AZS_GetLairs and AZS_GetLairs() or {}
			local marks = SurvivorUI_LairMarks and SurvivorUI_LairMarks(lairs) or {}
			for index = 1, table.getn(lairs) do
				local lair = lairs[index]
				local east, south = WayTo(lair, px, py, heroX, heroY, span)
				if east then
					shown = shown + 1
					local pin = Pin(shown)
					-- Its mark, as the guardians' bar and list show it; with the
					-- marks off, the skull.
					local mark = marks[tonumber(lair.index) or index]
					if mark and SurvivorUI_SetLairMark then
						SurvivorUI_SetLairMark(pin.art, mark, not lair.active)
					else
						pin.art:SetTexture(ART.."PinLair")
						pin.art:SetTexCoord(0, 1, 0, 1)
						if lair.active then
							pin.art:SetVertexColor(1, 1, 1)
						else
							pin.art:SetVertexColor(0.45, 0.45, 0.45)
						end
					end
					if lair.active then
						pin.note = "Guardian's lair: "..(lair.name and lair.name ~= "" and lair.name or "a guardian holds it")
					else
						pin.note = "Empty lair"
					end
					local markName = SurvivorUI_LairMarkName and SurvivorUI_LairMarkName(mark)
					pin.title = markName and (markName.." lair") or "Lair"
					Place(pin, east, south, yardsAcross)
				end
			end
		end
	end
	for index = shown + 1, table.getn(pins) do
		pins[index]:Hide()
	end
end

local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 0.1 then
		elapsed = 0
		Update()
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
