-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: caches and lairs on the minimap.
--
-- The game shares every cache on the field (AZS_CHESTS) and every guardian's
-- lair (AZS_GetLairs), each with its place in the world (x, y, in yards) and
-- on the zone's map (mx, my). The hero's own place comes from the map
-- (GetPlayerMapPosition); the yards a map unit spans are worked out from two
-- shared places far apart, so any zone works without a table of sizes.
--
-- A cache is a golden chest; a lair a horned skull, bright while its guardian
-- holds it, grey once it is empty. One beyond the minimap's edge sits on the
-- edge, smaller and fainter, pointing the way. Hover a pin for what it is.
-- Off with the option "Caches and lairs on the minimap"; /sui pins prints what
-- the addon reads, to check it.

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local PIN_SIZE = 16
local EDGE_SIZE = 11

-- The yards across the minimap at each zoom level, outdoors, as the 1.12
-- client draws it.
local MINIMAP_YARDS = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 }

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

local function Place(pin, mx, my, heroX, heroY, span)
	local half = Minimap:GetWidth() / 2
	local zoom = Minimap:GetZoom() or 0
	local yardsAcross = MINIMAP_YARDS[zoom] or MINIMAP_YARDS[0]
	local perYard = (2 * half) / yardsAcross
	local east = (mx - heroX) * span.across
	local south = (my - heroY) * span.down
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

local function Update()
	local shown = 0
	if Enabled() and Playing() then
		local heroX, heroY = HeroPlace()
		local span = heroX and Span()
		if span then
			for index = 1, table.getn(AZS_CHESTS) do
				local chest = AZS_CHESTS[index]
				local mx, my = Share(chest.mx), Share(chest.my)
				if mx and my then
					shown = shown + 1
					local pin = Pin(shown)
					pin.art:SetTexture(ART.."PinCache")
					pin.art:SetVertexColor(1, 1, 1)
					pin.title, pin.note = "Cache", nil
					Place(pin, mx, my, heroX, heroY, span)
				end
			end
			local lairs = AZS_GetLairs and AZS_GetLairs() or {}
			for index = 1, table.getn(lairs) do
				local lair = lairs[index]
				local mx, my = Share(lair.mx), Share(lair.my)
				if mx and my then
					shown = shown + 1
					local pin = Pin(shown)
					pin.art:SetTexture(ART.."PinLair")
					if lair.active then
						pin.art:SetVertexColor(1, 1, 1)
						pin.note = "Guardian's lair: "..(lair.name and lair.name ~= "" and lair.name or "a guardian holds it")
					else
						pin.art:SetVertexColor(0.45, 0.45, 0.45)
						pin.note = "Empty lair"
					end
					pin.title = "Lair"
					Place(pin, mx, my, heroX, heroY, span)
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

-- /sui pins: what the addon reads, to check the pins against the world.
function SurvivorUI_PinsReport()
	local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Survivor UI|r "..text) end
	local heroX, heroY = HeroPlace()
	say("zone: "..tostring(AZS_ZONE and AZS_ZONE.zone).." (map "..tostring(AZS_ZONE and AZS_ZONE.map)
		.."); the client's: "..tostring(GetRealZoneText and GetRealZoneText()))
	say("hero on the map: "..(heroX and string.format("%.3f, %.3f", heroX, heroY) or "unknown"))
	say("caches: "..table.getn(AZS_CHESTS or {})..", lairs: "..table.getn(AZS_GetLairs and AZS_GetLairs() or {}))
	local span = Span()
	if span then
		say(string.format("map spans %.0f yards across, %.0f down; minimap zoom %d", span.across, span.down, Minimap:GetZoom() or 0))
	else
		say("map size not found yet: needs two caches or lairs far apart")
	end
	local first = (AZS_CHESTS or {})[1]
	if first then
		say("first cache: x "..tostring(first.x)..", y "..tostring(first.y)..", map "..tostring(first.mx)..", "..tostring(first.my))
	end
	local lair = (AZS_GetLairs and AZS_GetLairs() or {})[1]
	if lair then
		say("first lair: x "..tostring(lair.x)..", y "..tostring(lair.y)..", map "..tostring(lair.mx)..", "..tostring(lair.my))
	end
end
