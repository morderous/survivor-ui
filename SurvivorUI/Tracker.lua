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
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
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
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
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
	text:SetFont(FONT, size + FONT_BUMP, flags or "OUTLINE")
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

head.zone = HeadText(12)
head.state = HeadText(9)
head.clock = HeadText(18, "THICKOUTLINE")
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
local function BossLine(index)
	local line = head.bosses[index]
	if not line then
		line = CreateFrame("Frame", nil, head)
		line:SetWidth(WIDTH)
		line:SetHeight(13)
		line.name = line:CreateFontString(nil, "OVERLAY")
		line.name:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
		line.name:SetPoint("LEFT", line, "LEFT", 0, 0)
		line.name:SetJustifyH("LEFT")
		line.time = line:CreateFontString(nil, "OVERLAY")
		line.time:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
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
			if Num(Field(unit, "state", 6)) == 1 then
				share = "|cffff4040enraged|r  "..share
			end
		end
		line.time:SetText("|cffff8c40"..share.."|r"..Clock(at))
		line.time:SetTextColor(1, 1, 1)
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
	head.zone:SetText(zoneName)
	head.zone:SetTextColor(1, 0.82, 0)
	y = Put(head.zone, y, 15)

	-- How the run stands: won, fallen or endless, and the lives left, small in
	-- the top right corner, so it takes no line of its own.
	local parts = {}
	if phase == "victory" then
		table.insert(parts, "|cff4dd94dVictory|r")
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
	head.state:SetPoint("TOPRIGHT", head, "TOPRIGHT", 0, -20)
	head.state:Show()

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
			tick.label:SetFont(FONT, 8 + FONT_BUMP, "OUTLINE")
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
	-- The level, and how far to the next.
	local xp, xpNeeded = Num(game.xp), Num(game.xpn)
	head.level:SetText("|cffbf8cffLevel "..Num(game.lvl).."|r")
	y = Put(head.level, y - 2, 13)
	head.xp:SetValue(xpNeeded > 0 and xp / xpNeeded or 0)
	y = Put(head.xp, y, 6)

	head:SetHeight(-y)
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
	-- One experience bar is enough: the tracker's, while it shows.
	local bar = getglobal("MainMenuExpBar")
	if bar then
		local want = showing and 0 or 1
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
	if settings.tracker then
		if AZS_IsHudShown("clock") then
			AZS_SetHudShown("clock", false)
			settings.hidGameClock = true
		end
	elseif settings.hidGameClock then
		AZS_SetHudShown("clock", true)
		settings.hidGameClock = nil
	end
end

function SurvivorUI_ToggleTracker()
	local settings = Settings()
	settings.tracker = not settings.tracker
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.tracker
		and "run tracker on; the game's own clock is put away."
		or "run tracker off; the game's own clock is back."))
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
