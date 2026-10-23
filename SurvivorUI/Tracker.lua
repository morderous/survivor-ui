-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the run tracker, after a Mythic+ timer.
--
-- Under the minimap, where a quest log would sit, centered: the zone, how the
-- run stands and the lives left, the time gone against the zone's full length
-- (the time gone alone in endless mode), a green timeline with a tick for every boss, every boss with the
-- second it comes, colored by where it stands (grey to come, white next,
-- orange alive, green slain), and the level's progress. It stands in for the game's own clock, which is put away while it
-- shows. Its size is fixed for the run: every line keeps its place, shown or
-- not, so nothing jumps as the run goes on.
--
-- Needs the game's addon API (AZS_RUN, AZS_SCHEDULE); without it nothing
-- shows. Hold Alt and drag it to move it; the place is kept. /sui tracker
-- hides it and brings the game's clock back.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 220
local BOSS_SLOTS = 5             -- lines kept for bosses, more if the zone has more

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.tracker == nil then
		SurvivorUIDB.tracker = true
	end
	return SurvivorUIDB
end

-- The game's run, while one is on: AZS_RUN and the phase.
local function Game()
	if AZS_GetPhase and AZS_RUN then
		local phase = AZS_GetPhase()
		if phase and phase ~= "ready" then
			return AZS_RUN, phase
		end
	end
end

local function Num(value)
	return tonumber(value) or 0
end

-- A list entry's field, by name or by place.
local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

-- 950, 1.2k, 3.4m
-- A big number as the whole addon writes it (SurvivorUI_Abbrev): 4.9k, 1.11M, 9.27B.
local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function Pair(label, value)
	GameTooltip:AddDoubleLine(label, value, 0.7, 0.7, 0.7, 1, 1, 1)
end

------------------------------------------------------------------------------
-- The frame.

local head = CreateFrame("Frame", "SurvivorUITracker", UIParent)
head:SetWidth(WIDTH)
head:SetHeight(100)
if Minimap then
	head:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -30)
else
	head:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -230)
end
head:SetMovable(true)
head:EnableMouse(true)
head:RegisterForDrag("LeftButton")
head:Hide()

-- The right column's one shade, as the run panel and the meter wear it.
head.shade = head:CreateTexture(nil, "BACKGROUND")
head.shade:SetTexture(FLAT)
head.shade:SetPoint("TOPLEFT", head, "TOPLEFT", -8, 6)
head.shade:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 8, -6)
head.shade:SetVertexColor(0.04, 0.04, 0.07, 0.55)

local function SavePlace()
	local settings = Settings()
	settings.trackerRight = math.floor(head:GetRight() + 0.5)
	settings.trackerTop = math.floor(head:GetTop() + 0.5)
end

local function RestorePlace()
	local settings = Settings()
	if settings.trackerRight then
		head:ClearAllPoints()
		head:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", settings.trackerRight, settings.trackerTop)
	end
end

head:SetScript("OnDragStart", function() if IsAltKeyDown() then head:StartMoving() end end)
head:SetScript("OnDragStop", function() head:StopMovingOrSizing() SavePlace() end)

local function HeadText(size, flags, justify)
	local text = head:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, flags or "OUTLINE")
	text:SetJustifyH(justify or "CENTER")
	return text
end

local function HeadBar(height)
	local bar = CreateFrame("StatusBar", nil, head)
	bar:SetWidth(WIDTH)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)
	bar.backing = bar:CreateTexture(nil, "BACKGROUND")
	bar.backing:SetTexture(FLAT)
	bar.backing:SetVertexColor(0.12, 0.12, 0.15, 0.9)
	bar.backing:SetAllPoints(bar)
	return bar
end

head.zone = HeadText(12, nil, "LEFT")
head.zone:SetHeight(14)
head.state = HeadText(9, nil, "RIGHT")
head.clock = HeadText(18, "THICKOUTLINE")

-- Left of the clock, a coin for the next cache, drawn as metal (a reeded
-- rim, a star in relief): gold when the gold carried pays for the cache
-- (Art\Coin.tga), red when it does not yet (Art\CoinRed.tga, a coin of its
-- own: the game's engine greys a desaturated texture and drops any tint after
-- it). (Right of it, the kill pace's orb: Pace.lua.)
local COIN_SIZE = 18
local COIN_GOLD = "Interface\\AddOns\\SurvivorUI\\Art\\Coin"
local COIN_RED = "Interface\\AddOns\\SurvivorUI\\Art\\CoinRed"
local PAYS = { 1.00, 0.82, 0.25 }
local SHORT = { 1.00, 0.28, 0.22 }
head.coin = CreateFrame("Frame", nil, head)
head.coin:SetWidth(COIN_SIZE)
head.coin:SetHeight(COIN_SIZE)
head.coin:SetPoint("RIGHT", head.clock, "LEFT", -8, 0)
head.coin.icon = head.coin:CreateTexture(nil, "ARTWORK")
head.coin.icon:SetTexture(COIN_GOLD)
head.coin.icon:SetPoint("CENTER", head.coin, "CENTER", 0, 0)
head.coin.icon:SetWidth(COIN_SIZE)
head.coin.icon:SetHeight(COIN_SIZE)
-- Its shine, the kill pace orb's glow and spark (Pace.lua) in gold.
head.coin.glow = head.coin:CreateTexture(nil, "BACKGROUND")
head.coin.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
head.coin.glow:SetBlendMode("ADD")
head.coin.glow:SetVertexColor(1, 0.78, 0.20)
head.coin.glow:SetPoint("CENTER", head.coin, "CENTER", 0, 0)
head.coin.glow:Hide()
head.coin.spark = head.coin:CreateTexture(nil, "OVERLAY")
head.coin.spark:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceSpark")
head.coin.spark:SetBlendMode("ADD")
head.coin.spark:SetVertexColor(1, 0.95, 0.70)
head.coin.spark:SetPoint("CENTER", head.coin, "TOPRIGHT", -3, -3)
head.coin.spark:Hide()
head.coin:EnableMouse(true)
head.coin:SetScript("OnEnter", function()
	local gold = Num(AZS_RUN and AZS_RUN.gold)
	local cost = Num(AZS_RUN and AZS_RUN.chest)
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText("Next cache", PAYS[1], PAYS[2], PAYS[3])
	GameTooltip:AddDoubleLine("It costs", Short(cost).." gold", 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("You carry", Short(gold).." gold", 0.8, 0.8, 0.8, 1, 1, 1)
	if gold >= cost then
		GameTooltip:AddLine("Enough to open it.", 0.55, 0.85, 0.55)
	else
		GameTooltip:AddLine(Short(cost - gold).." gold short.", SHORT[1], SHORT[2], SHORT[3])
	end
	GameTooltip:Show()
end)
head.coin:SetScript("OnLeave", function() GameTooltip:Hide() end)
head.coin:Hide()

-- While the cache can be paid the coin shines: a gold glow breathes behind
-- it and it brightens with the glow, a spark twinkles on its rim now and
-- then, and the moment the gold is first enough, a burst: the glow and the
-- coin swell, then settle into the breath.
local SHINE_BREATH = 1.4            -- seconds a breath takes
local SPARK_EVERY = 2.2             -- seconds between two twinkles
local BURST = 0.7                   -- seconds the burst takes
head.coin:SetScript("OnUpdate", function()
	local coin = this
	if not coin.pays or (SurvivorUIDB and SurvivorUIDB.trackerCoinShine == false) then
		coin.glow:Hide()
		coin.spark:Hide()
		return
	end
	local now = GetTime()
	local since = now - (coin.paysSince or now)
	local burst = since < BURST and (1 - since / BURST) or 0
	local wave = (math.sin(now * 6.283 / SHINE_BREATH) + 1) / 2
	local size = COIN_SIZE * (2.4 + 0.6 * wave + 2.6 * burst)
	coin.glow:SetWidth(size)
	coin.glow:SetHeight(size)
	coin.glow:SetAlpha(math.min(1, 0.45 + 0.45 * wave + burst))
	coin.glow:Show()
	local grow = COIN_SIZE * (1 + 0.4 * burst)
	coin.icon:SetWidth(grow)
	coin.icon:SetHeight(grow)
	local bright = 0.8 + 0.2 * wave
	coin.icon:SetVertexColor(bright, bright, bright)
	-- The twinkle: a quick flare on the rim, in the first fifth of its turn.
	local turn = math.mod(now, SPARK_EVERY) / SPARK_EVERY
	local twinkle = turn < 0.2 and math.sin(turn / 0.2 * 3.1416) or 0
	twinkle = math.max(twinkle, burst)
	if twinkle > 0.01 then
		local spark = COIN_SIZE * (0.6 + 0.9 * twinkle)
		coin.spark:SetWidth(spark)
		coin.spark:SetHeight(spark)
		coin.spark:SetAlpha(twinkle)
		coin.spark:Show()
	else
		coin.spark:Hide()
	end
end)
head.timeline = HeadBar(8)
head.timeline:SetStatusBarColor(0.30, 0.80, 0.35, 1)
head.level = HeadText(9)
head.xp = HeadBar(5)
head.xp:SetStatusBarColor(0.58, 0.30, 0.85, 1)
head.ticks = {}
head.bosses = {}

-- Across the frame at y, centered; returns the y under it.
local function Put(object, y, height)
	object:ClearAllPoints()
	object:SetPoint("TOP", head, "TOP", 0, y)
	object:Show()
	return y - height
end

-- A boss's color says where it stands, as in a Mythic+ timer: grey still to
-- come, white the next one, orange alive, green slain.
local STATE_COLORS = {
	due  = { 0.55, 0.55, 0.55 },
	next = { 1.00, 1.00, 1.00 },
	up   = { 1.00, 0.55, 0.25 },
	dead = { 0.30, 0.85, 0.35 },
}
local WAITING = STATE_COLORS.due

local function Hex(color)
	return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

------------------------------------------------------------------------------
-- The bosses.

local lastSeconds
local bossSeenUp = {}             -- [boss] = true once seen alive
local bossKilled = {}             -- [boss] = the run second it was seen to fall

-- The boss alive under this name, for its health.
local function LiveBoss(name)
	if not AZS_UNITS then
		return nil
	end
	for index = 1, table.getn(AZS_UNITS) do
		local unit = AZS_UNITS[index]
		local kind = Field(unit, "kind", 1)
		if (kind == "boss" or kind == "final") and Field(unit, "name", 3) == name then
			return unit
		end
	end
end

-- A boss line: the name on the left, the second it comes on the right.
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

-- With the health in the tracker (/sui opt, Run tracker), a boss alive fills
-- its line with its health, and a click targets it.
local function TrackerHealth()
	return SurvivorUIDB and SurvivorUIDB.trackerHealth
end

local function BossLine(index)
	local line = head.bosses[index]
	if not line then
		line = CreateFrame("Frame", nil, head)
		line:SetWidth(WIDTH)
		line:SetHeight(13)
		line.backing = line:CreateTexture(nil, "BACKGROUND")
		line.backing:SetTexture(FLAT)
		line.backing:SetAllPoints(line)
		line.backing:SetVertexColor(0.12, 0.12, 0.15, 0.9)
		line.backing:Hide()
		line.fill = line:CreateTexture(nil, "BORDER")
		line.fill:SetTexture(FLAT)
		line.fill:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
		line.fill:SetHeight(13)
		line.fill:Hide()
		line:SetScript("OnMouseUp", function()
			if this.target and TargetByName then
				TargetByName(this.target, true)
			end
		end)
		Outline(line)
		line.name = line:CreateFontString(nil, "OVERLAY")
		line.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
		line.name:SetPoint("LEFT", line, "LEFT", 0, 0)
		line.name:SetJustifyH("LEFT")
		line.time = line:CreateFontString(nil, "OVERLAY")
		line.time:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
		line.time:SetPoint("RIGHT", line, "RIGHT", 0, 0)
		line.time:SetJustifyH("RIGHT")
		head.bosses[index] = line
	end
	return line
end

-- Grey until it falls, then in its own color. Alive, its health shows by the
-- time; the next to come says how long.
local function FillBossLine(line, entry, index, seconds, isNext)
	local name = Field(entry, "name", 3) or "?"
	local at = Num(Field(entry, "at", 2))
	local state = Field(entry, "state", 5) or "due"
	local key = index..name
	if state == "up" then
		bossSeenUp[key] = true
	elseif state == "dead" and bossSeenUp[key] and not bossKilled[key] then
		bossKilled[key] = seconds
	end

	line.name:SetText(name)
	line.fill:Hide()
	line.backing:Hide()
	line.target = nil
	line:EnableMouse(false)
	if state == "dead" then
		local color = STATE_COLORS.dead
		line.name:SetTextColor(color[1], color[2], color[3])
		-- The second it came, and the second it fell when that was seen.
		if bossKilled[key] then
			line.time:SetText("|cff8a8a8a"..Clock(at).."  /|r  "..Clock(bossKilled[key]))
		else
			line.time:SetText(Clock(at))
		end
		line.time:SetTextColor(color[1], color[2], color[3])
	elseif state == "up" then
		local color = STATE_COLORS.up
		line.name:SetTextColor(color[1], color[2], color[3])
		local share = ""
		local unit = LiveBoss(name)
		if unit then
			local hpm = Num(Field(unit, "hpm", 5))
			if hpm > 0 then
				share = math.floor(Num(Field(unit, "hp", 4)) / hpm * 100 + 0.5).."%   "
			end
		end
		line.time:SetText("|cffff8c40"..share.."|r"..Clock(at))
		line.time:SetTextColor(1, 1, 1)
		-- In place of its boss bar: its health filling the line, the line a
		-- button that targets it.
		if TrackerHealth() and unit then
			local hp, hpm = Num(Field(unit, "hp", 4)), Num(Field(unit, "hpm", 5))
			line.backing:Show()
			line.fill:SetWidth(math.max(1, WIDTH * (hpm > 0 and hp / hpm or 0)))
			-- In the fight's orange, as a guardian awake in the guardians' bar.
			line.fill:SetVertexColor(1.00, 0.55, 0.15, 0.85)
			line.fill:Show()
			line.name:SetTextColor(1, 1, 1)
			-- Its health as chosen (/sui opt, Run tracker): its share, by default.
			local look = SurvivorUIDB and SurvivorUIDB.trackerHealthLook or "percent"
			if SurvivorUI_HealthText then
				line.time:SetText(SurvivorUI_HealthText(hp, hpm, look))
			else
				line.time:SetText(string.format("%d%%", (hpm > 0 and hp / hpm or 0) * 100 + 0.5))
			end
			line.target = name
			line:EnableMouse(true)
		end
	else
		local color = isNext and STATE_COLORS.next or WAITING
		line.name:SetTextColor(color[1], color[2], color[3])
		if isNext then
			line.time:SetText("|cffffd24din "..Clock(at - seconds).."|r   "..Clock(at))
		else
			line.time:SetText(Clock(at))
		end
		line.time:SetTextColor(color[1], color[2], color[3])
	end
	line:Show()
end

------------------------------------------------------------------------------
-- The elites alive (AZS_UNITS), under the guardians: a small bar each, its
-- health in the fight's orange. The game tells of no fight but the health, so
-- one that has taken a hit is bright, one still whole dim. Eight fit (4 to 12,
-- as chosen): the hurt first, the lowest leftmost, then the ones seen longest;
-- the rest only in the count. A click targets one.

local ELITE_GAP, ELITE_HEIGHT = 2, 7

-- How many bars (/sui opt, Run tracker), 4 to 12: 8 by default.
local function EliteSlots()
	local count = SurvivorUIDB and tonumber(SurvivorUIDB.trackerElitesMax) or 8
	return math.max(4, math.min(12, math.floor(count + 0.5)))
end
local ELITE_TOP, ELITE_LINE = 6, 12     -- room over the row, and its line of words
local ELITE_COLOR = { 1.00, 0.55, 0.15 }

local function TrackerElites()
	return not (SurvivorUIDB and SurvivorUIDB.trackerElites == false)
end

head.eliteTitle = HeadText(9, nil, "LEFT")
head.eliteTitle:SetTextColor(0.55, 0.55, 0.58)
head.eliteTitle:SetText("Elites")
head.eliteCount = HeadText(9, nil, "RIGHT")
head.elites = {}
local eliteSince = {}               -- [unit id] = the GetTime() it was first seen alive

local function EliteSlot(index)
	local slot = head.elites[index]
	if slot then
		return slot
	end
	slot = CreateFrame("Button", nil, head)
	slot:SetHeight(ELITE_HEIGHT)
	slot.backing = slot:CreateTexture(nil, "BACKGROUND")
	slot.backing:SetTexture(FLAT)
	slot.backing:SetAllPoints(slot)
	slot.backing:SetVertexColor(0.12, 0.12, 0.15, 0.9)
	slot.fill = slot:CreateTexture(nil, "BORDER")
	slot.fill:SetTexture(FLAT)
	slot.fill:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
	slot.fill:SetHeight(ELITE_HEIGHT)
	slot:SetScript("OnClick", function()
		if this.target and TargetByName then
			TargetByName(this.target, true)
		end
	end)
	Outline(slot)
	-- Its name and health under the mouse, with the outline when it targets.
	local edgesOn, edgesOff = slot:GetScript("OnEnter"), slot:GetScript("OnLeave")
	slot:SetScript("OnEnter", function()
		edgesOn()
		if this.name then
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetText(this.name, ELITE_COLOR[1], ELITE_COLOR[2], ELITE_COLOR[3])
			GameTooltip:AddLine(this.health, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	slot:SetScript("OnLeave", function()
		edgesOff()
		GameTooltip:Hide()
	end)
	head.elites[index] = slot
	return slot
end

local function HideElites()
	head.eliteTitle:Hide()
	head.eliteCount:Hide()
	for index = 1, table.getn(head.elites) do
		head.elites[index]:Hide()
	end
end

local function EliteRow(y)
	if not TrackerElites() then
		head.eliteTitle:Hide()
		head.eliteCount:Hide()
		for index = 1, table.getn(head.elites) do
			head.elites[index]:Hide()
		end
		return y
	end
	local alive, present = {}, {}
	local now = GetTime()
	local units = AZS_UNITS or {}
	for index = 1, table.getn(units) do
		local unit = units[index]
		if Field(unit, "kind", 1) == "elite" then
			local hp, hpm = Num(Field(unit, "hp", 4)), Num(Field(unit, "hpm", 5))
			if hp > 0 then
				local id = tostring(Field(unit, "id", 2) or Field(unit, "name", 3))
				present[id] = true
				eliteSince[id] = eliteSince[id] or now
				table.insert(alive, { id = id, name = Field(unit, "name", 3), hp = hp, hpm = hpm,
					share = hpm > 0 and math.min(1, hp / hpm) or 1, since = eliteSince[id] })
			end
		end
	end
	for id in pairs(eliteSince) do
		if not present[id] then
			eliteSince[id] = nil
		end
	end
	-- The hurt first, the lowest leftmost; then the ones seen longest. Each
	-- keeps its place from one drawing to the next.
	table.sort(alive, function(a, b)
		if a.share ~= b.share then
			return a.share < b.share
		elseif a.since ~= b.since then
			return a.since < b.since
		end
		return a.id < b.id
	end)
	local total, hurt = table.getn(alive), 0
	-- With none alive, no row at all, when chosen; else it keeps its room.
	if total == 0 and SurvivorUIDB and SurvivorUIDB.trackerElitesHide then
		HideElites()
		return y
	end
	for index = 1, total do
		if alive[index].share < 1 then
			hurt = hurt + 1
		end
	end
	if total == 0 then
		head.eliteCount:SetText("|cff8a8a8anone|r")
	elseif hurt > 0 then
		head.eliteCount:SetText("|cffffffff"..total.." alive|r  ·  |cffff8c26"..hurt.." fighting|r")
	else
		head.eliteCount:SetText("|cffffffff"..total.." alive|r")
	end
	head.eliteTitle:ClearAllPoints()
	head.eliteTitle:SetPoint("TOPLEFT", head, "TOPLEFT", 0, y - ELITE_TOP)
	head.eliteTitle:Show()
	head.eliteCount:ClearAllPoints()
	head.eliteCount:SetPoint("TOPRIGHT", head, "TOPRIGHT", 0, y - ELITE_TOP)
	head.eliteCount:Show()
	y = y - ELITE_TOP - ELITE_LINE
	local slots = EliteSlots()
	local each = (WIDTH - (slots - 1) * ELITE_GAP) / slots
	for index = slots + 1, table.getn(head.elites) do
		head.elites[index]:Hide()
	end
	for index = 1, slots do
		local slot = EliteSlot(index)
		slot:SetWidth(each)
		slot:ClearAllPoints()
		slot:SetPoint("TOPLEFT", head, "TOPLEFT", (index - 1) * (each + ELITE_GAP), y)
		local elite = alive[index]
		if elite then
			slot.fill:SetWidth(math.max(1, each * elite.share))
			slot.fill:SetVertexColor(ELITE_COLOR[1], ELITE_COLOR[2], ELITE_COLOR[3], elite.share < 1 and 0.9 or 0.35)
			slot.fill:Show()
			slot.name = elite.name
			slot.health = SurvivorUI_HealthText and SurvivorUI_HealthText(elite.hp, elite.hpm, "absolutePercent")
				or string.format("%d%%", elite.share * 100 + 0.5)
			slot.target = elite.name
			slot:EnableMouse(true)
		else
			slot.fill:Hide()
			slot.name, slot.target = nil, nil
			slot:EnableMouse(false)
		end
		slot:Show()
	end
	return y - ELITE_HEIGHT
end

------------------------------------------------------------------------------
-- Drawing.

local function Draw(game, phase)
	local zone = AZS_ZONE or {}
	local seconds = (AZS_GetRunTime and AZS_GetRunTime()) or Num(game.t)
	-- The clock going back means a new run: forget the last one's bosses.
	if lastSeconds and seconds + 3 < lastSeconds then
		bossSeenUp, bossKilled = {}, {}
	end
	lastSeconds = seconds

	-- The zone's facts come once a run, and can be missed (a restart mid-run):
	-- then the client's own zone name, and the run's length from AZS_RUN.
	local zoneName = zone.zname
	if not zoneName or zoneName == "" then
		zoneName = (GetRealZoneText and GetRealZoneText()) or GetZoneText() or ""
	end

	local y = 0

	-- How the run stands: won, fallen or endless, and the lives left, small on
	-- the zone's line, right of its name: the clock's sides hold the coin and
	-- the kill pace.
	local parts = {}
	if phase == "victory" then
		table.insert(parts, "|cff4dd94dVictory|r")
	elseif SurvivorUI_IsDown and SurvivorUI_IsDown() then
		-- A co-op hero down: the run goes on while a friend brings them back.
		table.insert(parts, "|cffff4040Down|r")
	elseif phase == "dead" then
		table.insert(parts, "|cffff4040Fallen|r")
	elseif phase == "paused" then
		table.insert(parts, "|cff9a9a9aPaused|r")
	elseif phase == "choosing" then
		table.insert(parts, "|cff9a9a9aChoosing|r")
	elseif Num(game.endl) == 1 then
		table.insert(parts, "|cffd080ffEndless|r")
	end
	local lives = Num(game.lives)
	if lives > 0 then
		table.insert(parts, "|cffff8080"..lives..(lives == 1 and " life" or " lives").." left|r")
	end
	head.state:SetText(table.concat(parts, "  "))
	head.state:ClearAllPoints()
	head.state:SetPoint("TOPRIGHT", head, "TOPRIGHT", 0, y - 2)
	head.state:Show()
	-- The zone's name on the left, cut short before the state if need be.
	local room = WIDTH
	if table.getn(parts) > 0 then
		room = WIDTH - head.state:GetStringWidth() - 10
	end
	head.zone:SetText(zoneName)
	head.zone:SetTextColor(1, 0.82, 0)
	head.zone:SetWidth(room)
	head.zone:ClearAllPoints()
	head.zone:SetPoint("TOPLEFT", head, "TOPLEFT", 0, y)
	head.zone:Show()
	y = y - 15

	-- Elapsed / the zone's full length, the time to victory. In endless mode,
	-- once chosen, the elapsed time alone.
	local length = Num(zone.len)
	if length <= 0 and AZS_GetRunLength then
		length = Num(AZS_GetRunLength())
	end
	if length <= 0 then
		length = Num(game.fin)
	end
	local endless = Num(game.endl) == 1
	if endless or length <= 0 then
		head.clock:SetText(Clock(seconds))
	else
		head.clock:SetText(Clock(seconds).." |cff8a8a8a/|r |cffb0b0b0"..Clock(length).."|r")
	end
	if phase == "paused" or phase == "choosing" then
		head.clock:SetTextColor(0.6, 0.6, 0.6)
	else
		head.clock:SetTextColor(1, 1, 1)
	end
	y = Put(head.clock, y - 1, 24)
	-- The cache's coin, when the game tells its price and it is chosen (off
	-- first: the kills and gold line shows the gold): it shines (its own
	-- OnUpdate) while the gold pays for the cache, red and still while not.
	local gold, cost = Num(game.gold), Num(game.chest)
	local coin = head.coin
	if cost > 0 and SurvivorUIDB and SurvivorUIDB.trackerCoin == true then
		local pays = gold >= cost
		if pays and not coin.pays then
			coin.paysSince = GetTime()
			coin.icon:SetTexture(COIN_GOLD)
		elseif pays then
			-- Not shining (/sui opt, Run tracker): gold and still.
			if SurvivorUIDB and SurvivorUIDB.trackerCoinShine == false then
				coin.icon:SetWidth(COIN_SIZE)
				coin.icon:SetHeight(COIN_SIZE)
				coin.icon:SetVertexColor(1, 1, 1)
			end
		elseif not pays and coin.pays ~= false then
			coin.glow:Hide()
			coin.spark:Hide()
			coin.icon:SetTexture(COIN_RED)
			coin.icon:SetWidth(COIN_SIZE)
			coin.icon:SetHeight(COIN_SIZE)
			coin.icon:SetVertexColor(1, 1, 1)
		end
		coin.pays = pays
		coin:Show()
	else
		coin.pays = nil
		coin:Hide()
	end
	-- Room over the timeline for each coming boss's countdown.
	y = y - 10

	-- The timeline: green up to now, each boss's tick in its own color.
	head.timeline:SetValue(length > 0 and math.min(1, seconds / length) or 1)
	if endless then
		head.timeline:SetStatusBarColor(0.70, 0.40, 1.00, 1)
	else
		head.timeline:SetStatusBarColor(0.30, 0.80, 0.35, 1)
	end
	y = Put(head.timeline, y, 15)

	local schedule = AZS_SCHEDULE or {}
	local count = table.getn(schedule)
	-- The same number of lines all run long: the zone's bosses, at least five.
	local slots = math.max(BOSS_SLOTS, Num(zone.bt), count)
	local nextShown = false
	for index = 1, count do
		local entry = schedule[index]
		local state = Field(entry, "state", 5) or "due"
		local isNext = state == "due" and not nextShown
		if isNext then
			nextShown = true
		end
		-- A tick is white until its boss is slain, then green.
		local color = state == "dead" and STATE_COLORS.dead or STATE_COLORS.next
		local final = Num(Field(entry, "final", 4)) == 1

		local tick = head.ticks[index]
		if not tick then
			tick = head.timeline:CreateTexture(nil, "OVERLAY")
			tick:SetTexture(FLAT)
			tick:SetWidth(3)
			tick:SetHeight(14)
			head.ticks[index] = tick
		end
		local at = Num(Field(entry, "at", 2))
		-- The final boss's tick is a little heavier.
		tick:SetWidth(final and 5 or 3)
		tick:ClearAllPoints()
		tick:SetPoint("CENTER", head.timeline, "LEFT", length > 0 and WIDTH * math.min(1, at / length) or WIDTH, 0)
		tick:SetVertexColor(color[1], color[2], color[3], 1)
		tick:Show()

		-- Over a boss still to come, small and yellow, the time until it does.
		if not tick.label then
			tick.label = head.timeline:CreateFontString(nil, "OVERLAY")
			tick.label:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
		end
		-- The next boss's countdown in orange, the later ones in yellow.
		if isNext then
			tick.label:SetTextColor(1, 0.55, 0.15)
		else
			tick.label:SetTextColor(1, 0.82, 0.2)
		end
		if state == "due" and at > seconds then
			-- Over its tick, kept inside the box at the ends.
			tick.label:SetText(Clock(at - seconds))
			local half = tick.label:GetStringWidth() / 2 + 1
			local x = length > 0 and WIDTH * math.min(1, at / length) or WIDTH
			x = math.max(half, math.min(WIDTH - half, x))
			tick.label:ClearAllPoints()
			tick.label:SetPoint("BOTTOM", head.timeline, "TOPLEFT", x, 4)
			tick.label:Show()
		else
			tick.label:Hide()
		end

		local line = BossLine(index)
		FillBossLine(line, entry, index, seconds, isNext)
		y = Put(line, y, 13)
	end
	for index = count + 1, table.getn(head.ticks) do
		head.ticks[index]:Hide()
		if head.ticks[index].label then
			head.ticks[index].label:Hide()
		end
	end
	for index = count + 1, table.getn(head.bosses) do
		head.bosses[index]:Hide()
	end
	-- Empty lines keep their room.
	y = y - (slots - count) * 13

	-- Endless mode: the schedule is spent and bosses return on a timer, so one
	-- more line, kept all run long, says when the next comes.
	local nextLine = head.nextBoss
	if not nextLine then
		nextLine = BossLine(table.getn(head.bosses) + 1)
		head.bosses[table.getn(head.bosses)] = nil
		head.nextBoss = nextLine
	end
	local nextIn = tonumber(game.nb) or -1
	if Num(game.endl) == 1 and nextIn >= 0 then
		local name = game.nbn
		if not name or name == "" then
			name = "Next boss"
		end
		nextLine.name:SetText(name)
		nextLine.name:SetTextColor(1, 1, 1)
		nextLine.time:SetText("|cffffd24din "..Clock(nextIn).."|r")
		y = Put(nextLine, y, 13)
	else
		nextLine:Hide()
		y = y - 13
	end
	-- The guardians' bar, when it stands here (Guardians.lua).
	if SurvivorUI_GuardianBar then
		y = SurvivorUI_GuardianBar(head, y)
	end
	-- The elites alive, under it.
	y = EliteRow(y)
	-- The level, and how far to the next, at the bottom; the time to the next
	-- level beside it (XpBar.lua). Each as chosen (Run tracker, XP bar).
	if not (SurvivorUIDB and SurvivorUIDB.trackerXp == false) then
		local xp, xpNeeded = Num(game.xp), Num(game.xpn)
		local level = "|cffbf8cffLv. "..Num(game.lvl).."|r"
		-- The levels waiting (Store Level-Ups, LevelUp.lua): "Lv. 12 +3".
		local stored = SurvivorUI_StoredLevels and SurvivorUI_StoredLevels() or 0
		if stored > 0 then
			level = level.." |cffffd100+"..stored.."|r"
		end
		if not (SurvivorUIDB and SurvivorUIDB.trackerXpEta == false) and SurvivorUI_XpNextText then
			local nextIn = SurvivorUI_XpNextText()
			if nextIn then
				level = level.."  |cff9a9a9a"..nextIn.."|r"
			end
		end
		head.level:SetText(level)
		-- A little room over it: the guardians' bar or the elites end right there.
		y = Put(head.level, y - 6, 13)
		head.xp:SetValue(xpNeeded > 0 and xp / xpNeeded or 0)
		y = Put(head.xp, y, 6)
	else
		head.level:Hide()
		head.xp:Hide()
	end

	head:SetHeight(-y)
end
-- For the last runs (RunHistory.lua): the tracker as it stands, to be drawn
-- again as it was when the run ended. The zone and how the run stands, the
-- clock against the zone's length, each boss with its second, where it stands
-- and when it fell, the guardians (Guardians.lua) and the elites alive, the
-- level and its experience.
function SurvivorUI_TrackerSnapshot()
	local game, phase = Game()
	if not game then
		return nil
	end
	local zone = AZS_ZONE or {}
	local seconds = (AZS_GetRunTime and AZS_GetRunTime()) or Num(game.t)
	local length = Num(zone.len)
	if length <= 0 and AZS_GetRunLength then
		length = Num(AZS_GetRunLength())
	end
	if length <= 0 then
		length = Num(game.fin)
	end
	local zoneName = zone.zname
	if not zoneName or zoneName == "" then
		zoneName = (GetRealZoneText and GetRealZoneText()) or GetZoneText() or ""
	end
	local schedule = AZS_SCHEDULE or {}
	local shot = {
		zone = zoneName, phase = phase, lives = Num(game.lives), seconds = seconds, length = length,
		endless = Num(game.endl) == 1 or nil,
		slots = math.max(BOSS_SLOTS, Num(zone.bt), table.getn(schedule)),
		bosses = {},
	}
	for index = 1, table.getn(schedule) do
		local entry = schedule[index]
		local name = Field(entry, "name", 3) or "?"
		local boss = {
			name = name, at = Num(Field(entry, "at", 2)), state = Field(entry, "state", 5) or "due",
			final = Num(Field(entry, "final", 4)) == 1 or nil, fell = bossKilled[index..name],
		}
		if boss.state == "up" then
			local unit = LiveBoss(name)
			if unit and Num(Field(unit, "hpm", 5)) > 0 then
				boss.hp = Num(Field(unit, "hp", 4)) / Num(Field(unit, "hpm", 5))
			end
		end
		table.insert(shot.bosses, boss)
	end
	if shot.endless and (tonumber(game.nb) or -1) >= 0 then
		local name = game.nbn
		shot.nextBoss = { name = (name and name ~= "") and name or "Next boss", left = tonumber(game.nb) }
	end
	shot.guardians = SurvivorUI_GuardianSnapshot and SurvivorUI_GuardianSnapshot() or nil
	-- The elites alive, the hurt first, the lowest leftmost.
	if TrackerElites() then
		local shares, hurt = {}, 0
		local units = AZS_UNITS or {}
		for index = 1, table.getn(units) do
			local unit = units[index]
			if Field(unit, "kind", 1) == "elite" then
				local hp, hpm = Num(Field(unit, "hp", 4)), Num(Field(unit, "hpm", 5))
				if hp > 0 then
					local share = hpm > 0 and math.min(1, hp / hpm) or 1
					table.insert(shares, share)
					if share < 1 then
						hurt = hurt + 1
					end
				end
			end
		end
		table.sort(shares)
		local total = table.getn(shares)
		if not (total == 0 and SurvivorUIDB and SurvivorUIDB.trackerElitesHide) then
			local slots = EliteSlots()
			while table.getn(shares) > slots do
				table.remove(shares)
			end
			shot.elites = { total = total, hurt = hurt, slots = slots, shares = shares }
		end
	end
	if not (SurvivorUIDB and SurvivorUIDB.trackerXp == false) then
		local xp, xpNeeded = Num(game.xp), Num(game.xpn)
		shot.level = Num(game.lvl)
		shot.xp = xpNeeded > 0 and math.min(1, xp / xpNeeded) or 0
		shot.stored = SurvivorUI_StoredLevels and SurvivorUI_StoredLevels() or 0
	end
	return shot
end

local elapsed = 0
head:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	local game, phase = Game()
	if game then
		Draw(game, phase)
	end
end)

-- The frame's own OnUpdate stops while it is hidden, so a watcher shows it.
local watcher = CreateFrame("Frame")
local watched = 0
watcher:SetScript("OnUpdate", function()
	watched = watched + arg1
	if watched < 0.25 then
		return
	end
	watched = 0
	local game, phase = Game()
	local showing = game and Settings().tracker
	if showing then
		if not head:IsShown() then
			Draw(game, phase)
			head:Show()
		end
	elseif head:IsShown() then
		head:Hide()
	end
	-- One experience bar is enough: the tracker's. Away whenever the tracker
	-- is on, before the run starts too; back only with the tracker off.
	local bar = getglobal("MainMenuExpBar")
	if bar then
		local want = Settings().tracker and 0 or 1
		if bar:GetAlpha() ~= want then
			bar:SetAlpha(want)
			if bar.EnableMouse then
				bar:EnableMouse(not showing)
			end
		end
	end
end)

------------------------------------------------------------------------------
-- More on hover: the time to the final boss, the run's settings.

local MOD_NAMES = { "Enemy density", "Enemy health", "Enemy damage", "Enemy speed" }
head:SetScript("OnEnter", function()
	local game = Game()
	if not game then
		return
	end
	local zone = AZS_ZONE or {}
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(zone.zname or "This run", 1, 0.82, 0)
	if Num(game.endl) == 1 then
		GameTooltip:AddLine("Endless mode: bosses return on a timer.", 0.85, 0.5, 1, 1)
	elseif Num(game.left) >= 0 then
		Pair("Final boss in", Clock(Num(game.left)))
	end
	Pair("Bosses so far", Num(game.bs).." / "..Num(game.bt))
	Pair("Lairs on the map", Num(game.lairs))
	if tonumber(zone.diff) and tonumber(zone.diff) ~= 1 then
		Pair("Zone difficulty", "x"..zone.diff)
	end
	-- "100 100 100 100" is a normal run; anything else is worth a line.
	if zone.mods then
		local index = 0
		for value in string.gfind(zone.mods, "%d+") do
			index = index + 1
			if MOD_NAMES[index] and value ~= "100" then
				Pair(MOD_NAMES[index], value.."%")
			end
		end
	end
	GameTooltip:AddLine("Hold Alt and drag to move. /sui tracker hides it.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
head:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------------
-- The game's own clock and "next boss" line: away while the tracker stands in
-- for them. The setting is the game's and is saved, so the addon remembers
-- that it was the one to turn it off.

local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.tracker or settings.noGameClock then
		if AZS_IsHudShown("clock") then
			AZS_SetHudShown("clock", false)
			settings.hidGameClock = true
		end
	elseif settings.hidGameClock then
		AZS_SetHudShown("clock", true)
		settings.hidGameClock = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.clock = ApplyGameHud

function SurvivorUI_ToggleTracker()
	local settings = Settings()
	settings.tracker = not settings.tracker
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.tracker
		and "run tracker on; the Default clock is put away."
		or (settings.noGameClock and "run tracker off, and the Default clock stays away." or "run tracker off; the Default clock is back.")))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(head, "Run tracker", SavePlace, nil, function()
		head:ClearAllPoints()
		if Minimap then
			head:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -30)
		else
			head:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -230)
		end
	end)
end
