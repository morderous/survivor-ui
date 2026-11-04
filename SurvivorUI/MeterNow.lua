-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the meter now (asked for 2026-11-04).
--
-- A damage meter window of its own for how the hero is doing now, while the
-- main one (Meter.lua) keeps the run's whole, or since its Reset. The
-- buttons under its title switch what it counts: the last 30 seconds of the run's clock (the first
-- pick), since its own Reset (the main one's stays as it is), or the damage
-- to the boss, from its coming to its fall, kept until the next one comes
-- (the game's boss meter, AZS_GetBossMeter; its cards' crits the ones on the
-- boss, by the combat log's target). The
-- main one's bars, colors, icons and cards (lent by Meter.lua), each card's
-- numbers, crits and hits this stretch's. On or off on its own (the options,
-- Damage meter; /sui meter now), shown in a run. Hold Alt and drag to move
-- it, or move mode ("Meter now"), where its card sets its width and lines.
--
-- The game's meter gives each source's damage over the whole run: the window
-- keeps them every second of the run's clock and shows what came since. It
-- keeps them through every run, shown or not, so it is ready when opened.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local M = SurvivorUI_METER or { WIDTH = 228, BAR_HEIGHT = 18, BAR_GAP = 2, STRIP_TOP = 20, STRIP_HEIGHT = 14, BARS_TOP = 36 }

local SPAN = 30                 -- the seconds "Last 30 s" counts
local LINES = 6                 -- lines shown until the main window's are known
local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local UP = { 0.45, 0.95, 0.5 }
local DOWN = { 1, 0.6, 0.3 }


local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function On()
	return DB().nowMeter == true
end

local function Mode()
	local mode = DB().nowMeterMode
	if mode == "reset" or mode == "boss" then
		return mode
	end
	return "last"
end

local function TitleOf(key)
	if key == "boss" then
		return SurvivorUI_T("This boss")
	elseif key == "reset" then
		return SurvivorUI_T("Since reset")
	end
	return SurvivorUI_T("Last 30 s")
end

local function Num(value)
	return tonumber(value) or 0
end

local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function RunSeconds()
	return (AZS_GetRunTime and AZS_GetRunTime()) or 0
end

local function Running()
	if not (AZS_GetPhase and AZS_GetMeter) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

------------------------------------------------------------------------------
-- What it keeps through a run: the game's numbers once a second of the run's
-- clock (the last SPAN seconds and one before), the ones at its Reset, the
-- boss fight's first and last, and the crits and hits of each.

local N = {
	samples = {},       -- shots, one a second, the oldest first
	base = nil,         -- the shot at its Reset; nil: the run's start
	boss = nil,         -- { from = shot, to = shot once over, name, names, lines, total once over }
	fighting = false,   -- a boss up now
	lastAt = nil,       -- the run's clock at the last look
	shot = nil,         -- the last look's
}

-- The game's numbers now: each source's damage over the run, the run's whole
-- and its damage a second.
local function Take()
	local lines, total, rate = (SurvivorUI_MeterGame or AZS_GetMeter)()
	local shot = { at = RunSeconds(), total = Num(total), rate = Num(rate), dmg = {}, proc = {} }
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		local name = line.name or "?"
		shot.dmg[name] = Num(line.dmg)
		shot.proc[name] = Num(line.proc) == 1 or nil
	end
	return shot
end

-- What each source dealt from one shot to another (from nil: the run's
-- start), the most first, each its damage, share and damage a second; the
-- whole, its damage a second and the seconds between.
local function Between(from, to)
	local lines, sum = {}, 0
	local span = to.at - (from and from.at or 0)
	for name, dmg in pairs(to.dmg) do
		local got = dmg - (from and from.dmg[name] or 0)
		if got > 0 then
			table.insert(lines, { name = name, dmg = got, proc = to.proc[name] == true })
			sum = sum + got
		end
	end
	table.sort(lines, function(a, b)
		if a.dmg ~= b.dmg then
			return a.dmg > b.dmg
		end
		return a.name < b.name
	end)
	for index = 1, table.getn(lines) do
		local line = lines[index]
		line.share = sum > 0 and line.dmg / sum or 0
		line.dps = span > 0 and line.dmg / span or 0
	end
	return lines, sum, span > 0 and sum / span or 0, span
end

-- Crits and hits, by the names the run panel keeps them under (RunPanel.lua):
-- a crit's count, sum, smallest, last, biggest and its second; a hit's count,
-- sum and last.
local function Ledger()
	return { crits = {}, hits = {} }
end

local function Count(ledger, ability, amount, crit, at)
	local list = crit and ledger.crits or ledger.hits
	local stats = list[ability]
	if not stats then
		stats = { sum = 0, count = 0, least = amount }
		list[ability] = stats
	end
	stats.last, stats.sum, stats.count = amount, stats.sum + amount, stats.count + 1
	if crit then
		stats.least = math.min(stats.least, amount)
		if not stats.best or amount > stats.best then
			stats.best, stats.bestAt = amount, at
		end
	end
end

N.reset, N.fight = Ledger(), Ledger()
N.recent = {}                   -- [ability] = { { at, amount, crit }, ... }, the last SPAN seconds

-- Each crit and hit the run panel reads in the combat log.
function SurvivorUI_MeterNowNote(ability, amount, crit)
	amount = tonumber(amount)
	if not (ability and amount) then
		return
	end
	local at = RunSeconds()
	Count(N.reset, ability, amount, crit, at)
	-- The boss fight's: only a blow on the boss, by its line's target.
	if N.fighting and N.boss and SurvivorUI_BlowLine then
		local _, _, target = string.find(SurvivorUI_BlowLine, " [hc]r?its? (.-) for %d")
		if target and N.boss.names[target] then
			Count(N.fight, ability, amount, crit, at)
		end
	end
	local list = N.recent[ability]
	if not list then
		list = {}
		N.recent[ability] = list
	end
	table.insert(list, { at, amount, crit })
	while list[1] and list[1][1] < at - SPAN do
		table.remove(list, 1)
	end
end

-- The last SPAN seconds' crits and hits of one ability.
local function Recent(ability)
	local ledger = Ledger()
	local list = N.recent[ability] or {}
	local since = RunSeconds() - SPAN
	for index = 1, table.getn(list) do
		local blow = list[index]
		if blow[1] >= since then
			Count(ledger, ability, blow[2], blow[3], blow[1])
		end
	end
	return ledger
end

-- A line's numbers for its card, as the game's meter lines have them.
local function CardLine(line)
	if not line then
		return nil
	end
	return { dmg = line.dmg, share = line.share, dps = line.dps or 0, proc = line.proc and 1 or 0 }
end

-- What a line's card shows (RunPanel.lua's CardOf, by bar.slice): this
-- stretch's crits, hits and numbers.
local SLICES = {
	last = {
		Crits = function(ability) return Recent(ability).crits[ability] end,
		Hits = function(ability) return Recent(ability).hits[ability] end,
		Line = CardLine,
	},
	reset = {
		Crits = function(ability) return N.reset.crits[ability] end,
		Hits = function(ability) return N.reset.hits[ability] end,
		Line = CardLine,
	},
	boss = {
		Crits = function(ability) return N.fight.crits[ability] end,
		Hits = function(ability) return N.fight.hits[ability] end,
		Line = CardLine,
	},
}

-- A new run (the clock gone back): what was kept goes with the old one.
local function Forget()
	N.samples, N.base, N.boss, N.fighting = {}, nil, nil, false
	N.reset, N.fight, N.recent = Ledger(), Ledger(), {}
end

-- The game's boss meter now (the fight's damage to bosses), its Pets a line a
-- pet as the damage meter has them: its lines and its whole.
local function BossMeter()
	local lines, total = nil, 0
	if AZS_GetBossMeter then
		lines, total = AZS_GetBossMeter()
	end
	local shown = {}
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		table.insert(shown, { name = line.name or "?", dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) == 1 })
	end
	if SurvivorUI_MeterSplitPets then
		shown = SurvivorUI_MeterSplitPets(shown)
	end
	return shown, Num(total)
end

-- A boss come (its schedule's "up", at its time: not the last run's states)
-- starts the fight; none up any more ends it, its boss meter kept until the
-- next one comes. The bosses up, by name, for the blows on them.
local function WatchBoss(shot)
	local up, names = false, {}
	local name
	for _, entry in pairs(AZS_SCHEDULE or {}) do
		local at = tonumber(Field(entry, "at", 2))
		if Field(entry, "state", 5) == "up" and (not at or shot.at >= at - 5) then
			up = true
			local each = Field(entry, "name", 3)
			name = name or each
			if each then
				names[tostring(each)] = true
			end
		end
	end
	if up and not N.fighting then
		N.boss = { from = shot, name = name, names = names }
		N.fight = Ledger()
	elseif up and N.boss then
		for each in pairs(names) do
			N.boss.names[each] = true
		end
	elseif N.fighting and not up and N.boss then
		N.boss.to = shot
		N.boss.lines, N.boss.total = BossMeter()
	end
	N.fighting = up
end

-- The numbers now, kept once a second of the run's clock.
local function Look()
	local shot = Take()
	if N.lastAt and shot.at + 3 < N.lastAt then
		Forget()
	end
	N.lastAt = shot.at
	local samples = N.samples
	local last = samples[table.getn(samples)]
	if not last or shot.at >= last.at + 1 then
		table.insert(samples, shot)
	end
	while samples[2] and samples[2].at <= shot.at - SPAN do
		table.remove(samples, 1)
	end
	WatchBoss(shot)
	N.shot, N.shotTime = shot, GetTime()
	return shot
end

-- The stretch shown: its lines, whole, damage a second and seconds.
local function Stretch(mode, shot)
	if mode == "boss" then
		if not N.boss then
			return {}, 0, 0, 0
		end
		-- The damage to the boss: the fight's boss meter, live, kept once over.
		local lines, total = N.boss.lines, N.boss.total
		if not lines then
			lines, total = BossMeter()
		end
		local span = (N.boss.to or shot).at - N.boss.from.at
		local shown = {}
		for index = 1, table.getn(lines) do
			local line = lines[index]
			table.insert(shown, { name = line.name, dmg = line.dmg, share = line.share, proc = line.proc,
				dps = span > 0 and line.dmg / span or 0 })
		end
		return shown, total, span > 0 and total / span or 0, span
	elseif mode == "reset" then
		return Between(N.base, shot)
	end
	return Between(N.samples[1], shot)
end

-- A stretch for the damage meter's 30s page (Meter.lua), looked at again when
-- the last look is older than a moment; and its cards' crits and hits.
function SurvivorUI_MeterStretch(mode)
	if not Running() then
		return nil
	end
	if not N.shot or GetTime() - (N.shotTime or 0) > 0.2 then
		Look()
	end
	return Stretch(mode, N.shot)
end

function SurvivorUI_MeterSlice(mode)
	return SLICES[mode]
end

------------------------------------------------------------------------------
-- The window: the main one's look, its buttons for what it counts.

local window = CreateFrame("Frame", "SurvivorUIMeterNow", UIParent)
-- Over the action bar and the unit frames where it is let go (Lucas, 2026-11-04).
window:SetFrameStrata("HIGH")
window:SetWidth(M.WIDTH + 8)
window:SetHeight(M.BARS_TOP + 4 + LINES * (M.BAR_HEIGHT + M.BAR_GAP) + (M.FOOT or 0))
window.foot = M.FOOT
window:SetBackdrop({ bgFile = FLAT })
window:SetMovable(true)
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:RegisterForDrag("LeftButton")
window:Hide()
window.bars = {}
window.scrolled = 0
window.lines = LINES

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	return text
end

-- Its shade, or none (the options' No backgrounds), as the main one's.
local function Ground()
	local db = SurvivorUIDB
	local bare = db and db.noBackgrounds and not (db.noBackgroundsOff and db.noBackgroundsOff.meter)
	window:SetBackdropColor(0.04, 0.04, 0.07, bare and 0 or 0.55)
end
Ground()
SurvivorUI_Grounds = SurvivorUI_Grounds or {}
SurvivorUI_Grounds.meterNow = Ground

-- Its size: its own (its card in move mode), else the main window's.
local function SizeOf()
	local db = DB()
	local width, lines = M.WIDTH, LINES
	if SurvivorUI_MeterMainSize then
		width, lines = SurvivorUI_MeterMainSize()
	end
	width = math.max(M.WIDTH_LEAST or 180, math.min(M.WIDTH_MOST or 400, tonumber(db.nowMeterWidth) or width))
	lines = math.max(M.LINES_LEAST or 3, math.min(M.LINES_MOST or 20, tonumber(db.nowMeterLines) or lines))
	return width, lines
end

local function Resize()
	local width, lines = SizeOf()
	if window.barWidth ~= width or window.lines ~= lines then
		window.barWidth, window.lines = width, lines
		window:SetWidth(width + 8)
		window:SetHeight(M.BARS_TOP + 4 + lines * (M.BAR_HEIGHT + M.BAR_GAP) + (M.FOOT or 0))
		window.strip:SetWidth(width)
	end
end

-- Its place: where it was moved to; else left of the main window, past the
-- extra windows open (MeterWindows.lua), level with its title.
local function Slot()
	local most = 0
	for index in pairs(DB().meterWindows or {}) do
		if type(index) == "number" and index > most then
			most = index
		end
	end
	return most
end

local function Place()
	window:ClearAllPoints()
	local db = DB()
	if db.nowMeterLeft and db.nowMeterTop then
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.nowMeterLeft, db.nowMeterTop)
		return
	end
	window.slot = Slot()
	local main = getglobal("SurvivorUIMeter")
	if main then
		window:SetPoint("TOPRIGHT", main, "TOPLEFT", -8 - window.slot * (M.WIDTH + 16), 0)
	else
		window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260 - window.slot * (M.WIDTH + 16), 40)
	end
end

local function SavePlace()
	if window:GetLeft() then
		local db = DB()
		db.nowMeterLeft = math.floor(window:GetLeft() + 0.5)
		db.nowMeterTop = math.floor(window:GetTop() + 0.5)
	end
	Place()
end

local Draw

-- Moved with Alt held, as every piece; the bars lend their drag too.
window.StartMove = function()
	if SurvivorUI_MoveKeyDown and SurvivorUI_MoveKeyDown() then
		window.moving = true
		window:StartMoving()
	end
end
window.StopMove = function()
	window:StopMovingOrSizing()
	if window.moving then
		window.moving = nil
		SavePlace()
	end
end
window:SetScript("OnDragStart", window.StartMove)
window:SetScript("OnDragStop", window.StopMove)
window.Roll = function(to)
	window.scrolled = math.max(0, math.min(window.most or 0, to))
	Draw()
	GameTooltip:Hide()
	if SurvivorUI_CritCardHide then
		SurvivorUI_CritCardHide()
	end
end
window.Wheel = function()
	window.Roll(math.min(window.scrolled or 0, window.most or 0) - (arg1 or 0))
end
window.Redraw = function()
	Draw()
end
window:EnableMouseWheel(true)
window:SetScript("OnMouseWheel", window.Wheel)
if SurvivorUI_MeterNewRoll then
	SurvivorUI_MeterNewRoll(window)
end

-- The title: what it counts; under it a button each for the three (Meter.lua's
-- page buttons), as the damage meter's, and its numbers at its foot.
local PAGES = {
	{ key = "last", title = "Last 30 s", label = "30s", color = { 0.3, 0.82, 0.88 },
		tip = function() return SurvivorUI_TF("The damage of the last {1} seconds of the run's clock, as they go.", SPAN) end },
	{ key = "reset", title = "Since reset", label = "Since reset", color = { 1, 0.78, 0.2 },
		tip = "The damage since this window's Reset, or since the run began." },
	{ key = "boss", title = "This boss", label = "This boss", color = { 0.95, 0.45, 0.75 },
		tip = "The damage to the boss, from its coming to its fall, kept until the next one comes." },
}
do
	local title = CreateFrame("Button", nil, window)
	title:SetPoint("TOPLEFT", window, "TOPLEFT", 2, -2)
	title:SetHeight(17)
	title.text = Text(title, 11, GOLD)
	title.text:SetPoint("LEFT", title, "LEFT", 3, 0)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", window.StartMove)
	title:SetScript("OnDragStop", window.StopMove)
	window.title = title
	if SurvivorUI_MeterPageRow then
		window.pages = SurvivorUI_MeterPageRow(window, function(key)
			DB().nowMeterMode = key ~= "last" and key or nil
			window.scrolled = 0
			Draw()
		end, PAGES)
	end
end

-- Its corner: a - to close it (the setting off) and Reset left of it; the
-- fold button right of the title, as the main one's.
do
	local close = CreateFrame("Button", nil, window)
	close:SetWidth(14)
	close:SetHeight(14)
	close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -3)
	close.text = Text(close, 13, { 0.6, 0.6, 0.6 })
	close.text:SetPoint("CENTER", close, "CENTER", 0, 1)
	close.text:SetText("-")
	close:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 0.45, 0.4)
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(SurvivorUI_T("Close this window"), 1, 1, 1)
		GameTooltip:AddLine(SurvivorUI_T("It opens again from the options' Damage meter tab, or /sui meter now."), 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	close:SetScript("OnLeave", function()
		this.text:SetTextColor(0.6, 0.6, 0.6)
		GameTooltip:Hide()
	end)
	close:SetScript("OnClick", function()
		GameTooltip:Hide()
		if SurvivorUI_ToggleMeterNow then
			SurvivorUI_ToggleMeterNow(true)
		end
	end)

	local reset = CreateFrame("Button", nil, window)
	reset.least = 32
	reset:SetWidth(reset.least)
	reset:SetHeight(12)
	reset:SetPoint("TOPRIGHT", window, "TOPRIGHT", -20, -5)
	reset.text = Text(reset, 9, { 0.6, 0.6, 0.6 })
	reset.text:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
	reset.text:SetText(SurvivorUI_T("Reset"))
	reset:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(SurvivorUI_T("Starts this window over from now."), 1, 1, 1)
		GameTooltip:AddLine(SurvivorUI_T("Its damage, damage per second, crits and hits count from here. The main meter keeps its own numbers."), 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	reset:SetScript("OnLeave", function()
		this.text:SetTextColor(0.6, 0.6, 0.6)
		GameTooltip:Hide()
	end)
	-- Every count starts over: the last 30 seconds from now, since reset,
	-- and the boss fight (one on now counts from here; none, none shown).
	reset:SetScript("OnClick", function()
		if Running() then
			local shot = Take()
			N.base, N.reset = shot, Ledger()
			N.samples, N.recent = { shot }, {}
			N.fight = Ledger()
			N.boss = N.fighting and { from = shot, name = N.boss and N.boss.name } or nil
			N.shot = shot
			window.scrolled = 0
			Draw()
		end
	end)
	window.reset = reset

	if SurvivorUI_MeterFoldButton then
		window.fold = SurvivorUI_MeterFoldButton(window)
		window.fold:SetPoint("LEFT", window.title, "RIGHT", 2, 0)
	end
end

-- The numbers at its foot: DPS this stretch (green while above the run's,
-- orange while below), the run's (RUN) or how long it is (TIME), and TOTAL.
do
	local strip = CreateFrame("Frame", nil, window)
	strip:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 4, 4)
	strip:SetWidth(M.WIDTH)
	strip:SetHeight(M.STRIP_HEIGHT)
	strip:EnableMouse(true)
	strip:RegisterForDrag("LeftButton")
	strip:SetScript("OnDragStart", window.StartMove)
	strip:SetScript("OnDragStop", window.StopMove)
	strip.wash = strip:CreateTexture(nil, "BACKGROUND")
	strip.wash:SetTexture(FLAT)
	strip.wash:SetAllPoints(strip)
	strip.wash:SetVertexColor(1, 1, 1, 0.04)
	strip.cells = {}
	for index = 1, 3 do
		local cell = {}
		cell.label = Text(strip, 7, { 0.58, 0.58, 0.64 })
		cell.value = Text(strip, 10, WHITE)
		cell.value:SetPoint("LEFT", cell.label, "RIGHT", 4, 0)
		strip.cells[index] = cell
	end
	window.strip = strip

	strip:SetScript("OnEnter", function()
		local mode = Mode()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(TitleOf(mode), 1, 0.82, 0)
		-- The whole phrase a piece, for a language with its own order.
		local what
		if mode == "boss" then
			what = SurvivorUI_T("The damage to the boss, from its coming to its fall, kept until the next one comes.")
		elseif mode == "reset" then
			what = SurvivorUI_T("The damage since this window's Reset, or since the run began.")
		else
			what = SurvivorUI_TF("The damage of the last {1} seconds of the run's clock, as they go.", SPAN)
		end
		GameTooltip:AddLine(what, 0.8, 0.8, 0.8, 1)
		if mode == "boss" and N.boss then
			local name = N.boss.name and tostring(N.boss.name) or SurvivorUI_T("the boss")
			GameTooltip:AddLine(SurvivorUI_TF(N.boss.to and "{1}: slain after {2}." or "{1}: fighting for {2}.", name, Clock(window.span or 0)), 1, 1, 1, 1)
		end
		GameTooltip:AddDoubleLine(SurvivorUI_T("DPS"), SurvivorUI_T("a second over this stretch"), UP[1], UP[2], UP[3], 0.8, 0.8, 0.8)
		if mode == "last" then
			GameTooltip:AddDoubleLine(SurvivorUI_T("RUN"), SurvivorUI_T("the run's damage a second"), GOLD[1], GOLD[2], GOLD[3], 0.8, 0.8, 0.8)
		else
			GameTooltip:AddDoubleLine(SurvivorUI_T("TIME"), SurvivorUI_T("how long this stretch is"), 1, 1, 1, 0.8, 0.8, 0.8)
		end
		GameTooltip:AddDoubleLine(SurvivorUI_T("TOTAL"), SurvivorUI_T("the damage this stretch"), 1, 1, 1, 0.8, 0.8, 0.8)
		GameTooltip:AddLine(SurvivorUI_T("DPS is green while above the run's, orange while below."), 0.6, 0.6, 0.65, 1)
		GameTooltip:AddLine(SurvivorUI_T("The main meter keeps the run's whole. The buttons under the title switch what this one counts."), 0.6, 0.6, 0.65, 1)
		GameTooltip:Show()
	end)
	strip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	window.empty = Text(window, 9, { 0.55, 0.55, 0.6 })
	window.empty:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -M.BARS_TOP - 2)
end

-- The strip's cells, each in its share of the width.
local function SetCells(cells)
	local strip = window.strip
	local each = (window.barWidth or M.WIDTH) / table.getn(cells)
	for index = 1, 3 do
		local cell = strip.cells[index]
		local data = cells[index]
		cell.label:ClearAllPoints()
		if data then
			cell.label:SetPoint("LEFT", strip, "LEFT", (index - 1) * each + 6, 0)
			cell.label:SetText(data[1])
			cell.value:SetText(data[2])
			cell.value:SetTextColor(data[3][1], data[3][2], data[3][3])
			cell.label:Show()
			cell.value:Show()
		else
			cell.label:Hide()
			cell.value:Hide()
		end
	end
end

-- The corner: Reset as wide as its word, the fold button as the setting stands.
local function LayCorner()
	local reset, fold = window.reset, window.fold
	local width = math.max(reset.least, math.ceil(reset.text:GetStringWidth()) + 2)
	if math.abs(reset:GetWidth() - width) > 0.5 then
		reset:SetWidth(width)
	end
	if fold and SurvivorUI_MeterFoldShow then
		SurvivorUI_MeterFoldShow(fold, "damage")
	end
end

Draw = function()
	local shot = N.shot
	if not shot then
		return
	end
	local mode = Mode()
	local title = window.title
	title.text:SetText(TitleOf(mode))
	title:SetWidth(title.text:GetStringWidth() + 6)
	if window.pages then
		window.pages.Lay(mode, window.barWidth or M.WIDTH)
	end
	LayCorner()

	local lines, total, rate, span = Stretch(mode, shot)
	window.span = span
	if SurvivorUI_MeterFold then
		lines = SurvivorUI_MeterFold(lines, "damage")
	end
	local ready = span >= 1
	local run = shot.rate
	local second = mode == "last" and { SurvivorUI_T("RUN"), Short(run), GOLD } or { SurvivorUI_T("TIME"), Clock(span), WHITE }
	SetCells({
		{ SurvivorUI_T("DPS"), ready and Short(rate) or "...", (not ready or total <= 0) and WHITE or (rate >= run and UP or DOWN) },
		second,
		{ SurvivorUI_T("TOTAL"), Short(total), WHITE },
	})
	if table.getn(lines) == 0 then
		window.empty:SetText(SurvivorUI_T((mode == "boss" and not N.boss) and "No boss fight yet." or "No damage yet."))
		window.empty:Show()
	else
		window.empty:Hide()
	end

	-- Rolled by the wheel or the bar at its right, as the main one.
	local shown = window.lines or LINES
	window.most = math.max(0, table.getn(lines) - shown)
	local skip = math.min(window.scrolled or 0, window.most)
	local count = math.min(shown, table.getn(lines) - skip)
	local top = count > 0 and lines[1].dmg or 0
	if SurvivorUI_MeterShowRoll then
		SurvivorUI_MeterShowRoll(window, skip, shown)
	end
	for index = 1, count do
		local bar = window.bars[index]
		if not bar and SurvivorUI_MeterNewBar then
			bar = SurvivorUI_MeterNewBar(window)
			window.bars[index] = bar
			window.dressed = nil
		end
		if bar then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -M.BARS_TOP - (index - 1) * (M.BAR_HEIGHT + M.BAR_GAP))
			SurvivorUI_MeterPaintBar(bar, lines[index + skip], top, "damage")
			-- Its card tells this stretch's numbers (RunPanel.lua).
			bar.slice = SLICES[mode]
		end
	end
	for index = count + 1, table.getn(window.bars) do
		window.bars[index]:Hide()
		window.bars[index].ability = nil
	end
	-- The main meter's font and text size (its card's), on new bars too.
	if not window.dressed and window.handle and SurvivorUI_WearPieceFont then
		window.dressed = true
		SurvivorUI_WearPieceFont(window.handle)
	end
end

------------------------------------------------------------------------------
-- Move mode: "Meter now", over the cards with the damage meter.

if SurvivorUI_RegisterMover then
	window.handle = SurvivorUI_RegisterMover(window, "Meter now", SavePlace, nil, function()
		local db = DB()
		db.nowMeterLeft, db.nowMeterTop, db.nowMeterWidth, db.nowMeterLines = nil, nil, nil, nil
		Resize()
		Place()
	end)
	if window.handle then
		window.handle.cardsAs = function() return "Damage meter" end
		window.handle.disabled = true
	end
end

-- Four times a second in a run: what it keeps (once a second while it is
-- closed), and while it is on, shown and drawn at its size.
local wait, lookedAt = 0, 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.25 then
		return
	end
	wait = 0
	if not SurvivorUIDB then
		return
	end
	local on = On()
	if window.handle then
		window.handle.disabled = not on or nil
	end
	-- Placed once the saved places are read, as the game loads them after
	-- the files.
	if not window.placed then
		window.placed = true
		Place()
	end
	if not Running() then
		if window:IsShown() then
			window:Hide()
		end
		return
	end
	if not on then
		if window:IsShown() then
			window:Hide()
		end
		if GetTime() >= lookedAt + 1 then
			lookedAt = GetTime()
			Look()
		end
		return
	end
	local scale = SurvivorUI_PartScale and SurvivorUI_PartScale("meter") or 1
	if window:GetScale() ~= scale then
		window:SetScale(scale)
		Place()
	end
	Resize()
	if not DB().nowMeterLeft and window.slot ~= Slot() then
		Place()
	end
	Look()
	window:Show()
	Draw()
end)

-- On or off (the options, Damage meter; /sui meter now; its -; the main
-- meter's stopwatch). quiet: no word in the chat (its buttons).
function SurvivorUI_ToggleMeterNow(quiet)
	local db = DB()
	db.nowMeter = not db.nowMeter or nil
	wait = 1
	if quiet then
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage(SurvivorUI_T(db.nowMeter and "Survivor UI: meter now on: the last 30 seconds, since its Reset or the boss fight, from its title."
		or "Survivor UI: meter now off; the damage meter keeps the run's whole."))
end

-- Its width and lines, for its card in move mode; set, each kept until its
-- Reset.
function SurvivorUI_MeterNowSize()
	return SizeOf()
end

function SurvivorUI_SetMeterNowSize(width, lines)
	local db = DB()
	if width then
		db.nowMeterWidth = width
	end
	if lines then
		db.nowMeterLines = lines
	end
	Resize()
	if window:IsShown() then
		Draw()
	end
end
