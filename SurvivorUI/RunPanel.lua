-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the run so far, in one small panel.
--
-- This Run: a running count of what the game totals up on the screen that
-- ends a run: time, level, kills, damage. The crits it reads from the combat
-- log are shown in the damage meter's cards (Meter.lua), not here.
--
-- Where the game shares its run with addons (its API: AZS_RUN, AZS_GetRunTime,
-- AZS_GetMeter, AZS_TAKEN), the panel shows the game's own numbers: its clock,
-- which stops on a pause or a card choice, kills, elites, guardians and bosses
-- apart, damage, gold, caches and the next boss. Hover a row for more.
--
-- An older game without the API gets the panel's own count instead, from the
-- combat log: a clock of its own, elites and guardians together, no gold.
--
-- The boss timeline is the run tracker's, under the minimap (Tracker.lua).
--
-- On the left by default, under the loot list. Hold Alt to move it; the place
-- is kept. /sui run hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 220
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 24

-- The game's elites and bosses, by name: three elites and five bosses a zone.
-- A lair guardian is one of the zone's elites, made stronger, under the same
-- name and as an elite to the client: the two are counted together.
local ELITES = {
	"Kobold Taskmaster", "Gruff Swiftbite", "Bellygrub",
	"Nightbane Worgen Alpha", "Carrion Recluse", "Flesh Eating Abomination",
	"Felguard Elite", "Infernal", "Doomguard",
	"Crypt Fiend", "Bone Golem", "Death Knight Captain",
	"Gordunni Brute", "Warpwood Treant", "Ironbark Protector",
	"Gurubashi Berserker", "Zulian Crocolisk", "Gurubashi Champion",
	"Alterac Yeti Lord", "Mountain Giant", "Winterax Warlord",
	"Core Hound", "Black Drake", "Molten Giant",
	"Qiraji Champion", "Anubisath Sentinel", "Obsidian Destroyer",
}
local BOSSES = {
	"Hogger", "Mother Fang", "Rhahk'Zor", "Mr. Smite", "Edwin VanCleef",
	"Naraxis", "Mor'Ladim", "Stitches", "Lupos", "Morbent Fel",
	"Doomguard Commander", "Mannoroth's Herald", "Varimathras", "Lord Hel'nurath", "Lord Kazzak",
	"Patchwerk", "Lord Blackwood", "Baron Rivendare", "Anub'Rekhan", "Kel'Thuzad",
	"Zevrim Thornhoof", "Alzzin the Wildshaper", "Tendris Warpwood", "Immol'thar", "King Gordok",
	"High Priestess Jeklik", "High Priest Venoxis", "Bloodlord Mandokir", "Jin'do the Hexxer", "Hakkar the Soulflayer",
	"Korrak the Bloodrager", "Ivus the Forest Lord", "Lokholar the Ice Lord", "Glacius the Frozen Titan", "Azuregos",
	"General Angerforge", "Warchief Rend Blackhand", "Emperor Dagran Thaurissan", "Majordomo Executus", "Nefarian",
	"Kurinnaxx", "General Rajaxx", "Princess Huhuran", "Ossirian the Unscarred", "C'Thun",
}

local kindByName = {}
for index = 1, table.getn(ELITES) do
	kindByName[ELITES[index]] = "elites"
end
for index = 1, table.getn(BOSSES) do
	kindByName[BOSSES[index]] = "bosses"
end

-- One color per ability, handed out in the order abilities first crit.
local CRIT_PALETTE = {
	{ 0.86, 0.24, 0.24 }, { 0.26, 0.52, 0.96 }, { 0.93, 0.76, 0.20 }, { 0.30, 0.78, 0.45 },
	{ 0.70, 0.36, 0.90 }, { 0.95, 0.52, 0.18 }, { 0.25, 0.80, 0.82 }, { 0.90, 0.40, 0.65 },
	{ 0.62, 0.42, 0.24 }, { 0.60, 0.70, 0.85 },
}

------------------------------------------------------------------------------
-- The tally.

local run = {}
local critBest, critStats, critColor, critSeen = {}, {}, {}, 0
local critBestAt = {}           -- [ability] = the run second its best was set
local hitStats = {}             -- [ability] = { last, sum, count }, normal hits only

-- The run's clock: a pause stops it.
local function RunNow()
	return AZS_GetRunTime and AZS_GetRunTime() or GetTime()
end

local function ResetCrits()
	critBest, critStats, critColor, critSeen = {}, {}, {}, 0
	critBestAt = {}
	hitStats = {}
	if SurvivorUI_ResetCritRecord then
		SurvivorUI_ResetCritRecord()
	end
end

local function ResetRun()
	run.started = nil       -- GetTime() the clock started
	run.armed = nil         -- waiting for the hero's first step
	run.fromX = nil
	run.pausedAt = nil      -- GetTime() the clock was stopped at, while the game is paused
	run.lastSign = nil      -- GetTime() of the last step or combat log line
	run.atX = nil
	run.ended = nil         -- GetTime() the run was over
	run.kills = 0
	run.elites = 0
	run.bosses = 0
	run.dealt = 0
	run.taken = 0
	run.hits = {}           -- the hits taken last, the newest last (Taken)

	ResetCrits()
end
ResetRun()

local function Seconds()
	if not run.started then
		return 0
	end
	return (run.ended or run.pausedAt or GetTime()) - run.started
end

-- The game pauses on Escape and while a level's cards are up, and tells the
-- addon nothing: its clock and its frames keep running. What does stop is the
-- world. A run is never quiet, so a stretch with no step taken and no line in
-- the combat log is a pause, and the clock is wound back to where it began.
local QUIET = 1.5

local function Position()
	local x, y = GetPlayerMapPosition("player")
	if (not x or (x == 0 and y == 0)) and SetMapToCurrentZone then
		-- The world map was left on another zone: no position until it is back.
		SetMapToCurrentZone()
		x, y = GetPlayerMapPosition("player")
	end
	if not x or (x == 0 and y == 0) then
		return nil
	end
	return x, y
end

-- A sign of life: a step, or anything in the combat log.
local function Alive()
	if not run.started or run.ended then
		return
	end
	local now = GetTime()
	if run.pausedAt then
		-- The clock picks up where it stopped: the start moves by the time paused.
		run.started = run.started + (now - run.pausedAt)
		run.pausedAt = nil
	end
	run.lastSign = now
end

local function WatchPause()
	local x, y = Position()
	if x then
		if not run.atX or math.abs(x - run.atX) + math.abs(y - run.atY) > 0.0002 then
			run.atX, run.atY = x, y
			Alive()
		end
	end
	local last = run.lastSign or run.started
	if not run.pausedAt and GetTime() - last > QUIET then
		-- Stopped back at the last sign, so the quiet wait itself is not counted.
		run.pausedAt = last
	end
end

-- The game's run, while one is on: AZS_RUN and the phase. nil without the API,
-- or before the run starts.
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

-- The game's meter line for an ability, by the name the combat log gave it.
local MELEE_NAMES = { "Melee", "Attack", "Auto Attack" }
-- A name or bonus line in English, whatever language the game is in (Locale.lua).
local function English(name)
	return SurvivorUI_English and SurvivorUI_English(name) or name
end

local function MeterLine(ability)
	ability = English(ability)
	if not AZS_GetMeter then
		return nil
	end
	local lines, total = AZS_GetMeter()
	if not lines then
		return nil
	end
	local names = ability == "Melee" and MELEE_NAMES or { ability }
	for index = 1, table.getn(lines) do
		for n = 1, table.getn(names) do
			if English(lines[index].name) == names[n] then
				return lines[index], total
			end
		end
	end
end

-- 950, 1k, 1.2k, 3.4m
-- A big number as the whole addon writes it (SurvivorUI_Abbrev): 4.9k, 1.11M, 9.27B.
local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

------------------------------------------------------------------------------
-- The panel.

-- api: only with the game's API.
local RUN_ROWS = {
	{ key = "time",      label = "Survived",        color = { 1.00, 0.82, 0.00 } },
	{ key = "level",     label = "Level",           color = { 0.40, 1.00, 0.40 } },
	{ key = "kills",     label = "Kills",           color = { 0.92, 0.92, 0.92 } },
	{ key = "kpm",       label = "Kills / min",     color = { 0.78, 0.80, 0.88 }, api = true },
	{ key = "elites",    label = "Elites slain",    color = { 1.00, 0.55, 0.10 }, plain = "Elites & guardians slain" },
	{ key = "guardians", label = "Guardians slain", color = { 0.20, 0.75, 0.95 }, api = true },
	{ key = "bosses",    label = "Bosses slain",    color = { 0.72, 0.32, 1.00 } },
	{ key = "dealt",     label = "Damage dealt",    color = { 1.00, 0.76, 0.08 } },
	{ key = "dps",       label = "Damage / sec",    color = { 0.95, 0.60, 0.20 } },
	{ key = "taken",     label = "Damage taken",    color = { 0.90, 0.25, 0.25 } },
	{ key = "gold",      label = "Gold earned",     color = { 1.00, 0.86, 0.35 }, api = true },
	{ key = "caches",    label = "Caches opened",   color = { 0.55, 0.85, 0.55 }, api = true },
}

local panel = CreateFrame("Frame", "SurvivorUIRun", UIParent)
panel:SetWidth(WIDTH + 16)
panel:SetHeight(TITLE_HEIGHT + 8)
-- In the right column, under the run tracker (placed once the tracker is, see
-- the placer below); until then, under the minimap.
if Minimap then
	panel:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 8, -230)
else
	panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -420)
end
panel:SetBackdrop({ bgFile = FLAT })
-- The right column's one shade: the tracker and the meter wear it too.
panel:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
panel:SetMovable(true)
panel:Hide()

-- A place the player chose is kept, by the panel's top left corner.
local function SavePanel()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.runLeft = math.floor(panel:GetLeft() + 0.5)
	SurvivorUIDB.runTop = math.floor(panel:GetTop() + 0.5)
end

-- The saved place, or under the run tracker, right edges together.
local function RestorePanel()
	panel:ClearAllPoints()
	if SurvivorUIDB and SurvivorUIDB.runLeft and SurvivorUIDB.runTop then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB.runLeft, SurvivorUIDB.runTop)
	else
		-- The left column's top: Biggest Crits under it, the loot list last.
		panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
	end
end

-- A tooltip beside its box, level with what it tells: right of the box on
-- the screen's left half, left of it on the right half. Above a row it would
-- be pushed down over the rows at the screen's top, where the panel starts.
local function Beside(owner, box)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	-- The gap from the row's edge out past the box's, in the tooltip's units.
	local scale = owner:GetEffectiveScale() / GameTooltip:GetEffectiveScale()
	local center = box:GetCenter()
	if center and center * box:GetEffectiveScale() > GetScreenWidth() * UIParent:GetEffectiveScale() / 2 then
		local gap = ((owner:GetLeft() or 0) - (box:GetLeft() or 0)) * scale + 6
		GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -gap, 0)
	else
		local gap = ((box:GetRight() or 0) - (owner:GetRight() or 0)) * scale + 6
		GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 0)
	end
end

-- A section title. It says how to move the panel, and is a handle for doing it.
local function Title(text, tip)
	local handle = CreateFrame("Frame", nil, panel)
	handle:SetWidth(WIDTH - 46)
	handle:SetHeight(TITLE_HEIGHT - 6)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function() if IsAltKeyDown() then panel:StartMoving() end end)
	handle:SetScript("OnDragStop", function() panel:StopMovingOrSizing() SavePanel() end)
	handle:SetScript("OnEnter", function()
		Beside(this, panel)
		GameTooltip:SetText(text, 1, 0.82, 0)
		GameTooltip:AddLine("Hold Alt and drag to move.", 1, 1, 1)
		GameTooltip:AddLine(this.tip, 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

	handle.text = handle:CreateFontString(nil, "OVERLAY")
	handle.text:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
	handle.text:SetPoint("LEFT", handle, "LEFT", 4, 0)
	handle.text:SetTextColor(1, 0.82, 0)
	handle.text:SetText(text)
	handle.tip = tip
	return handle
end

local RUN_TIP_GAME = "The game's numbers. Hover a row for more."
local RUN_TIP_OWN = "Counted by the addon from the combat log. A new run starts it over."
local runTitle = Title("This Run", RUN_TIP_OWN)

-- A row: a label and a value in one color, on a faint wash of that color, over
-- a rule of it.
local function MakeRow(valueSize, valueFlags, parent)
	local row = CreateFrame("Frame", nil, parent or panel)
	row:SetWidth(WIDTH)
	row:SetHeight(ROW_HEIGHT)

	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(FLAT)
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)

	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetTexture(FLAT)
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	row.label = row:CreateFontString(nil, "OVERLAY")
	row.label:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
	row.label:SetWidth(WIDTH - 66)
	row.label:SetHeight(11)
	row.label:SetJustifyH("LEFT")

	row.value = row:CreateFontString(nil, "OVERLAY")
	row.value:SetFont(SurvivorUI_FONT, valueSize + FONT_BUMP, valueFlags)
	row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
	return row
end

local function Paint(row, color)
	row.label:SetTextColor(color[1], color[2], color[3])
	row.value:SetTextColor(color[1], color[2], color[3])
	row.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
	row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
end

local runRows = {}
for index = 1, table.getn(RUN_ROWS) do
	local info = RUN_ROWS[index]
	local row = MakeRow(11, "OUTLINE")
	row.label:SetText(info.label)
	Paint(row, info.color)
	runRows[info.key] = row
	runRows[index] = row
end

-- Kills / min: small notes, "last 20s" after the label and the run's average
-- before the value.
local function Note(row)
	local note = row:CreateFontString(nil, "OVERLAY")
	note:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	note:SetTextColor(0.55, 0.55, 0.58)
	return note
end
runRows.kpm.window = Note(runRows.kpm)
runRows.kpm.window:SetPoint("LEFT", runRows.kpm, "LEFT", 5 + runRows.kpm.label:GetStringWidth() + 4, -1)
runRows.kpm.average = Note(runRows.kpm)
runRows.kpm.average:SetPoint("RIGHT", runRows.kpm.value, "LEFT", -6, -1)

-- The clock is the addon's own count, not the game's: say where they can part.
runRows.time:EnableMouse(true)
runRows.time:SetScript("OnEnter", function()
	Beside(this, panel)
	GameTooltip:SetText("Survived", 1, 0.82, 0)
	local game = Game()
	if game then
		GameTooltip:AddLine("The game's clock. It stops while you pause or choose a card.", 1, 1, 1, 1)
		if Num(game.left) >= 0 and Num(game.endl) == 0 then
			GameTooltip:AddDoubleLine("Final boss in", Clock(Num(game.left)), 0.7, 0.7, 0.7, 1, 1, 1)
		elseif Num(game.endl) == 1 then
			GameTooltip:AddLine("Endless mode.", 0.85, 0.5, 1)
		end
		GameTooltip:AddDoubleLine("Bosses so far", Num(game.bs).." / "..Num(game.bt), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:Show()
		return
	end
	GameTooltip:AddLine("An estimate. The game does not share its clock with addons, so this one can drift from it.", 1, 1, 1, 1)
	GameTooltip:AddLine("Starts at your first step, or your first blow if the step was missed.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Pauses after 1.5 seconds with no movement and no combat, which is how it sees Escape and the level-up cards.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Standing still out of combat is not counted either.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Stops when the run ends.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
runRows.time:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- More from the game, on the rows that have it.
local MUTED = { 0.7, 0.7, 0.7 }

local function Pair(label, value, r, g, b)
	GameTooltip:AddDoubleLine(label, value, r or MUTED[1], g or MUTED[2], b or MUTED[3], 1, 1, 1)
end

local function Percent(part, whole)
	if whole <= 0 then
		return "0%"
	end
	return math.floor(part / whole * 100 + 0.5).."%"
end

local function RowTip(key, fill)
	local row = runRows[key]
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		local game = Game()
		if not game then
			return
		end
		Beside(this, panel)
		fill(game)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

RowTip("kpm", function(game)
	GameTooltip:SetText("Kills / min", 0.78, 0.80, 0.88)
	local rate, window
	if SurvivorUI_PaceRate then
		rate, window = SurvivorUI_PaceRate()
	end
	local seconds = AZS_GetRunTime and AZS_GetRunTime() or Num(game.t)
	Pair("Last "..(window or 20).." seconds", rate and string.format("%.0f", rate) or "-")
	Pair("The whole run", (seconds or 0) >= 10 and string.format("%.0f", Num(game.kills) / seconds * 60) or "-")
	GameTooltip:AddLine("The last seconds' rate is the kill pace's (/sui pace): off with it.", 0.7, 0.7, 0.7, 1)
end)

RowTip("kills", function(game)
	GameTooltip:SetText("Kills", 0.92, 0.92, 0.92)
	Pair("Enemies alive", Num(game.en))
	Pair("Elites alive", Num(game.el))
	Pair("Guardians awake", Num(game.ga).." / "..Num(game.gu))
end)

-- The game's damage meter: every source, the most damage first.
local function MeterTip()
	GameTooltip:SetText("Damage dealt", 1, 0.76, 0.08)
	local lines, total, dps = nil, 0, 0
	if AZS_GetMeter then
		lines, total, dps = AZS_GetMeter()
	end
	if not lines or table.getn(lines) == 0 then
		GameTooltip:AddLine("Nothing yet.", MUTED[1], MUTED[2], MUTED[3])
		return
	end
	Pair("Total", Short(Num(total)).."  ("..Short(Num(dps)).." / sec)")
	for index = 1, math.min(10, table.getn(lines)) do
		local line = lines[index]
		-- A talent's or amulet's own damage is blue, as in the game's meter.
		local r, g, b = 0.85, 0.85, 0.85
		if Num(line.proc) == 1 then
			r, g, b = 0.44, 0.84, 1.00
		end
		Pair(line.name or "?", Short(Num(line.dmg)).."  "..math.floor(Num(line.share) * 100 + 0.5).."%", r, g, b)
	end
end
RowTip("dealt", MeterTip)
RowTip("dps", MeterTip)

RowTip("taken", function(game)
	GameTooltip:SetText("Damage taken", 0.90, 0.25, 0.25)
	local list = AZS_TAKEN
	if not list or table.getn(list) == 0 then
		GameTooltip:AddLine("Nothing yet.", MUTED[1], MUTED[2], MUTED[3])
		return
	end
	local total = Num(game.taken)
	for index = 1, table.getn(list) do
		local source = Field(list[index], "source", 1) or "?"
		local dmg = Num(Field(list[index], "dmg", 2))
		Pair(string.upper(string.sub(source, 1, 1))..string.sub(source, 2), Short(dmg).."  "..Percent(dmg, total))
	end
end)

local function GoldTip(game)
	GameTooltip:SetText("Gold", 1, 0.86, 0.35)
	Pair("Gold now", Num(game.gold))
	Pair("Earned this run", Num(game.ge))
	Pair("Next cache costs", Num(game.chest))
	Pair("Caches opened", Num(game.ck))
	Pair("Rerolls left", Num(game.rr))
	Pair("Extra lives", Num(game.lives))
end
RowTip("gold", GoldTip)
RowTip("caches", GoldTip)

-- For the last runs (RunHistory.lua): each row's tooltip as it would show
-- now, by the row's key.
function SurvivorUI_RunRowTips()
	local tips = {}
	if SurvivorUI_Photograph then
		for index = 1, table.getn(RUN_ROWS) do
			local key = RUN_ROWS[index].key
			tips[key] = SurvivorUI_Photograph(runRows[key])
		end
	end
	return tips
end
-- An ability's other numbers, in a card of the panel's own: each line over a
-- rule in the ability's color, and the normal hits set apart under a heavier
-- one.
local TIP_WIDTH = 170
local TIP_ROW = 16

local critTip = CreateFrame("Frame", "SurvivorUICritTip", UIParent)
critTip:SetFrameStrata("TOOLTIP")
if critTip.SetClampedToScreen then
	critTip:SetClampedToScreen(true)
end
critTip:SetWidth(TIP_WIDTH + 16)
critTip:Hide()

critTip.edge = critTip:CreateTexture(nil, "BACKGROUND")
critTip.edge:SetTexture(FLAT)
critTip.edge:SetPoint("TOPLEFT", critTip, "TOPLEFT", -1, 1)
critTip.edge:SetPoint("BOTTOMRIGHT", critTip, "BOTTOMRIGHT", 1, -1)

critTip.fill = critTip:CreateTexture(nil, "BORDER")
critTip.fill:SetTexture(FLAT)
critTip.fill:SetVertexColor(0.05, 0.05, 0.07, 0.97)
critTip.fill:SetAllPoints(critTip)

critTip.title = critTip:CreateFontString(nil, "OVERLAY")
critTip.title:SetFont(SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
critTip.title:SetPoint("TOPLEFT", critTip, "TOPLEFT", 8, -8)

critTip.lines = {}

-- kind: "row" label and value, "head" a section title over a heavier rule.
-- A line of the card at y from its top; its height comes back. "head" a
-- section's title, "row" a label and its value, "text" words wrapped across
-- the card (a trait's description).
local function TipLine(index, kind, label, value, color, y)
	local line = critTip.lines[index]
	if not line then
		line = CreateFrame("Frame", nil, critTip)
		line:SetWidth(TIP_WIDTH)
		line:SetHeight(TIP_ROW)
		line.rule = line:CreateTexture(nil, "ARTWORK")
		line.rule:SetTexture(FLAT)
		line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
		line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
		line.label = line:CreateFontString(nil, "OVERLAY")
		line.label:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP)
		line.label:SetPoint("LEFT", line, "LEFT", 2, 0)
		line.value = line:CreateFontString(nil, "OVERLAY")
		line.value:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
		line.value:SetPoint("RIGHT", line, "RIGHT", -2, 0)
		line.text = line:CreateFontString(nil, "OVERLAY")
		line.text:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP)
		line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 2, -3)
		line.text:SetWidth(TIP_WIDTH - 4)
		line.text:SetJustifyH("LEFT")
		line.text:SetTextColor(0.85, 0.85, 0.85)
		critTip.lines[index] = line
	end

	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", critTip, "TOPLEFT", 8, -y)
	if kind == "text" then
		line.label:SetText("")
		line.value:SetText("")
		line.text:SetText(label)
		local lines = math.max(1, math.ceil(line.text:GetStringWidth() / ((TIP_WIDTH - 4) * 0.92)))
		line.text:SetHeight(lines * 11)
		line.text:Show()
		line:SetHeight(lines * 11 + 6)
		line.rule:SetHeight(1)
		line.rule:SetVertexColor(color[1], color[2], color[3], 0.12)
		line:Show()
		return lines * 11 + 6
	end
	line.text:Hide()
	line:SetHeight(TIP_ROW)
	line.label:SetText(label)
	line.value:SetText(value or "")
	if kind == "head" then
		line.label:SetTextColor(color[1], color[2], color[3])
		line.rule:SetHeight(1)
		line.rule:SetVertexColor(color[1], color[2], color[3], 0.75)
	else
		line.label:SetTextColor(0.80, 0.80, 0.80)
		line.value:SetTextColor(1, 1, 1)
		line.rule:SetHeight(1)
		line.rule:SetVertexColor(color[1], color[2], color[3], 0.22)
	end
	line:Show()
	return TIP_ROW
end

local critHovered = nil

-- The spell's live entry in the game's list (AZS_SPELLS): its rank and its
-- cooldown. The list names spells by key ("holy_wrath"), the meter and the
-- combat log by name ("Holy Wrath").
local SPELL_KEYS = {
	["shadow word: pain"] = "sw_pain", ["power word: shield"] = "pw_shield",
	["demoralizing shout"] = "demo_shout", ["hunter's mark"] = "hunters_mark",
}

-- Buffs: the game lists each one with its spell id and the seconds it has left
-- (AZS_BUFFS), not its full length. The length is learned instead: the left
-- time right after a buff goes up, or comes back up when refreshed.
local buffLength = {}           -- [spell id] = seconds it lasts
local buffLastLeft = {}

local function WatchBuffs()
	local seen = {}
	for index = 1, table.getn(AZS_BUFFS or {}) do
		local entry = AZS_BUFFS[index]
		local spell = tonumber(Field(entry, "spell", 1))
		local left = Num(Field(entry, "left", 2))
		if spell then
			seen[spell] = true
			if left > (buffLastLeft[spell] or 0) + 0.3 then
				buffLength[spell] = left
			end
			buffLastLeft[spell] = left
		end
	end
	for spell in pairs(buffLastLeft) do
		if not seen[spell] then
			buffLastLeft[spell] = nil
		end
	end
end

-- The seconds left on this spell's buff, or nil when it is not up.
local function BuffLeft(spell)
	for index = 1, table.getn(AZS_BUFFS or {}) do
		local entry = AZS_BUFFS[index]
		if tonumber(Field(entry, "spell", 1)) == spell then
			return Num(Field(entry, "left", 2))
		end
	end
end

local function SpellEntry(ability)
	if not (ability and AZS_SPELLS) then
		return nil
	end
	ability = English(ability)
	local lower = string.lower(ability)
	local key = SPELL_KEYS[lower] or string.gsub(string.gsub(lower, "[^%a ]", ""), " ", "_")
	for index = 1, table.getn(AZS_SPELLS) do
		local entry = AZS_SPELLS[index]
		if Field(entry, "key", 1) == key then
			return entry
		end
	end
end

local function Seconds1(value)
	return string.format("%.1f sec", value)
end

-- An ability's card as data: its title, color and lines ({ kind, label,
-- value }), or nil with nothing to tell. kept: for the last runs, the lines
-- of the moment only, not "ready in" nor "beaten ... ago".
local function CardOf(row, kept)
	-- The meter's line by its name in the game's language; the crits by the
	-- combat log's, in English.
	local ability = English(row.ability)
	local stats = ability and critStats[ability]
	local hits = ability and hitStats[ability]
	-- Its line in the game's damage meter, where the game shares it.
	local meter = ability and MeterLine(ability)
	if not (stats or hits or meter or SpellEntry(ability)) then
		return nil
	end
	-- The row's own color (the damage meter's), else the crit's.
	local color = row.color or critColor[ability] or { 0.8, 0.8, 0.8 }
	local card = { title = ability, color = { color[1], color[2], color[3] }, lines = {} }
	local function Add(kind, label, value)
		table.insert(card.lines, { kind, label, value })
	end

	-- Its rank and cooldown, from the game: the action bar's own count is gone
	-- while the cards are up.
	local spell = SpellEntry(ability)
	if spell then
		local left, full = Num(Field(spell, "cd", 4)), Num(Field(spell, "cdmax", 5))
		-- Its rank as the spells' tooltips have it: "Rank 2", or II.
		local rank = Num(Field(spell, "rank", 3))
		Add("head", "Spell", SurvivorUI_RankText and SurvivorUI_RankText(rank) or "Rank "..rank)
		Add("row", "Cooldown", full > 0 and Seconds1(full) or "none")
		if not kept then
			Add("row", "Ready in", left > 0.05 and Seconds1(left) or "ready")
		end
		-- A buff also says how long it lasts and how long it has left.
		local spellId = tonumber(Field(spell, "spell", 2))
		local length = spellId and buffLength[spellId]
		if length then
			Add("row", "Lasts", Seconds1(length))
			if not kept then
				local up = BuffLeft(spellId)
				Add("row", "Active", up and up > 0.05 and Seconds1(up).." left" or "not now")
			end
		end
	end
	-- The racial: the race's traits too, as the game told them at a run's
	-- start (BuildList.lua).
	if row.racial then
		local race, traits = nil, nil
		if SurvivorUI_Racials then
			race, traits = SurvivorUI_Racials()
		end
		Add("head", (race or "Race").."'s traits", "")
		if traits and table.getn(traits) > 0 then
			for _, trait in pairs(traits) do
				Add("text", "|cffffd100"..trait.name.."|r  "..trait.text)
			end
		else
			Add("text", "Read from the chat as a run begins: start one to see them.")
		end
	end
	if meter then
		Add("head", "Damage done", Short(Num(meter.dmg)))
		Add("row", "Share of all", math.floor(Num(meter.share) * 100 + 0.5).."%")
		Add("row", "Per second", Short(Num(meter.dps)))
		if Num(meter.proc) == 1 then
			Add("row", "A talent's or amulet's own", "proc")
		end
	end
	-- A racial with no damage of its own: no empty crits and hits.
	local quiet = row.racial and not stats and not hits and not meter
	if not quiet then
	Add("head", "Critical strikes", stats and stats.count or 0)
	if stats then
		Add("row", "Biggest", Short(critBest[ability]))
		if critBestAt[ability] and not kept then
			Add("row", "Beaten last", Clock(RunNow() - critBestAt[ability]).." ago")
		end
		Add("row", "Last", Short(stats.last))
		Add("row", "Average", Short(stats.sum / stats.count))
		Add("row", "Smallest", Short(stats.least))
	else
		Add("row", "None seen", "")
	end
	Add("head", "Normal hits", hits and hits.count or 0)
	if hits then
		Add("row", "Average", Short(hits.sum / hits.count))
		Add("row", "Last", Short(hits.last))
	else
		Add("row", "None seen", "")
	end
	end
	return card
end

local function CritTooltip(row)
	-- A card kept with a past run (RunHistory.lua) shows as it was.
	local card = row.keptCard or CardOf(row)
	if not card then
		critTip:Hide()
		return
	end
	local color = card.color

	critTip.edge:SetVertexColor(color[1], color[2], color[3], 0.8)
	critTip.title:SetText(card.title)
	critTip.title:SetTextColor(color[1], color[2], color[3])

	local y = 26
	for index = 1, table.getn(card.lines) do
		local line = card.lines[index]
		y = y + TipLine(index, line[1], line[2], line[3], color, y)
	end
	for index = table.getn(card.lines) + 1, table.getn(critTip.lines) do
		critTip.lines[index]:Hide()
	end

	critTip:SetHeight(y + 8)
	-- Beside the whole window the row belongs to, top edges together, on its
	-- left: the right column sits at the screen's edge.
	critTip:ClearAllPoints()
	if row.cardRight then
		critTip:SetPoint("TOPLEFT", row.cardFrame or row, "TOPRIGHT", 6, 0)
	else
		critTip:SetPoint("TOPRIGHT", row.cardFrame or row, "TOPLEFT", -6, 0)
	end
	critTip:Show()
end

-- For the last runs (RunHistory.lua): an ability's card as it stands, kept
-- with the run. A frame carrying one (frame.keptCard) shows it again by
-- SurvivorUI_CritCardShow.
function SurvivorUI_CritCardData(ability, color, racial)
	return CardOf({ ability = ability, color = color, racial = racial }, true)
end

-- The card, for the damage meter's lines (Meter.lua). frame.ability is the
-- source's name; frame.color and frame.cardFrame (the window to sit beside)
-- are optional.
function SurvivorUI_CritCardShow(frame)
	critHovered = frame
	CritTooltip(frame)
end

function SurvivorUI_CritCardHide()
	critHovered = nil
	critTip:Hide()
end

function SurvivorUI_CritBest(ability)
	return critBest[ability]
end

-- For the last runs (RunHistory.lua): the run's biggest crits, the biggest
-- first, at most this many: { ability, amount } each.
function SurvivorUI_CritList(most)
	local sorted = {}
	for ability, amount in pairs(critBest) do
		table.insert(sorted, { ability = ability, amount = amount })
	end
	table.sort(sorted, function(a, b) return a.amount > b.amount end)
	while table.getn(sorted) > (most or 5) do
		table.remove(sorted)
	end
	return sorted
end

local function Shown()
	return not SurvivorUIDB or SurvivorUIDB.runPanel ~= false
end

-- Lays the rows out top to bottom and sizes the panel to them.
local function Draw()
	local y = -4

	local game, phase = Game()
	local running = game ~= nil or run.started ~= nil
	if running then
		runTitle:ClearAllPoints()
		runTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
		runTitle:Show()
		runTitle.tip = game and RUN_TIP_GAME or RUN_TIP_OWN
		y = y - TITLE_HEIGHT

		local seconds, paused
		if game then
			seconds = AZS_GetRunTime and AZS_GetRunTime() or Num(game.t)
			paused = phase == "paused" or phase == "choosing"
		else
			seconds = Seconds()
			paused = run.pausedAt
		end
		seconds = seconds or 0
		if paused then
			runRows.time.label:SetText(phase == "choosing" and "Survived (choosing)" or "Survived (paused)")
			runRows.time.value:SetTextColor(0.6, 0.6, 0.6)
		else
			runRows.time.label:SetText("Survived")
			runRows.time.value:SetTextColor(1, 0.82, 0)
		end
		runRows.time.value:SetText(Clock(seconds))
		runRows.elites.label:SetText(game and "Elites slain" or "Elites & guardians slain")

		local dealt
		if game then
			dealt = Num(game.dealt)
			runRows.level.value:SetText(Num(game.lvl))
			runRows.kills.value:SetText(Num(game.kills))
			-- The kill pace's rate (Pace.lua), and the whole run's.
			local rate, window
			if SurvivorUI_PaceRate then
				rate, window = SurvivorUI_PaceRate()
			end
			runRows.kpm.value:SetText(rate and string.format("%.0f", rate) or "-")
			runRows.kpm.window:SetText("last "..(window or 20).."s")
			runRows.kpm.average:SetText(seconds >= 10 and string.format("run %.0f", Num(game.kills) / seconds * 60) or "")
			runRows.elites.value:SetText(Num(game.ek))
			runRows.guardians.value:SetText(Num(game.gk))
			runRows.bosses.value:SetText(Num(game.bk))
			runRows.taken.value:SetText(Short(Num(game.taken)))
			runRows.gold.value:SetText(Short(Num(game.ge)))
			runRows.caches.value:SetText(Num(game.ck))

		else
			dealt = run.dealt
			runRows.level.value:SetText(UnitLevel("player") or 1)
			runRows.kills.value:SetText(run.kills)
			runRows.elites.value:SetText(run.elites)
			runRows.bosses.value:SetText(run.bosses)
			runRows.taken.value:SetText(Short(run.taken))
		end
		runRows.dealt.value:SetText(Short(dealt))
		runRows.dps.value:SetText(seconds > 0 and Short(dealt / seconds) or 0)
	else
		runTitle:Hide()
	end
	for index = 1, table.getn(RUN_ROWS) do
		local row = runRows[index]
		local info = RUN_ROWS[index]
		if running and (game or not info.api) then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
			row:Show()
			y = y - ROW_HEIGHT
		else
			row:Hide()
		end
	end

	panel:SetHeight(-y + 4)
	return running
end

------------------------------------------------------------------------------
-- Biggest Crits: the old box, on request. Every ability that has crit, in its
-- own color, with its biggest critical strike; hover one for its card. Off by
-- default: /sui crits shows it. Right under This Run and in its style, growing
-- downward; Alt moves it.

local CRIT_ROWS = 10

local critBox = CreateFrame("Frame", "SurvivorUICrits", UIParent)
critBox:SetWidth(WIDTH + 16)
critBox:SetHeight(TITLE_HEIGHT + 8)
critBox:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -10)
critBox:SetBackdrop({ bgFile = FLAT })
critBox:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
critBox:SetMovable(true)
critBox:Hide()

local function CritsShown()
	return SurvivorUIDB and SurvivorUIDB.critBox == true
end

local function SaveCritBox()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.critsLeft = math.floor(critBox:GetLeft() + 0.5)
	SurvivorUIDB.critsTop = math.floor(critBox:GetTop() + 0.5)
end

local function RestoreCritBox()
	critBox:ClearAllPoints()
	if SurvivorUIDB and SurvivorUIDB.critsLeft and SurvivorUIDB.critsTop then
		critBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB.critsLeft, SurvivorUIDB.critsTop)
	else
		-- Under This Run, left edges together.
		critBox:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -10)
	end
end

critBox.title = critBox:CreateFontString(nil, "OVERLAY")
critBox.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
critBox.title:SetPoint("TOPLEFT", critBox, "TOPLEFT", 8, -9)
critBox.title:SetTextColor(1, 0.82, 0)
critBox.title:SetText("Biggest Crits")

local critReset = CreateFrame("Button", nil, critBox)
critReset:SetWidth(40)
critReset:SetHeight(14)
critReset:SetPoint("TOPRIGHT", critBox, "TOPRIGHT", -8, -8)
critReset.text = critReset:CreateFontString(nil, "OVERLAY")
critReset.text:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
critReset.text:SetPoint("RIGHT", critReset, "RIGHT", 0, 0)
critReset.text:SetText("Reset")
critReset.text:SetTextColor(0.6, 0.6, 0.6)
critReset:SetScript("OnEnter", function()
	this.text:SetTextColor(1, 1, 1)
	Beside(this, critBox)
	GameTooltip:SetText("Clears the crits.", 1, 1, 1)
	GameTooltip:Show()
end)
critReset:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)
critReset:SetScript("OnClick", function() ResetCrits() end)

local critRows = {}
for index = 1, CRIT_ROWS do
	-- Rows in the build list's look: the spell's icon, the row filled with its
	-- damage meter color under light text, a border in that color.
	local row = MakeRow(10, "OUTLINE", critBox)
	row:SetPoint("TOPLEFT", critBox, "TOPLEFT", 8, -TITLE_HEIGHT - 4 - (index - 1) * ROW_HEIGHT)
	-- A dark base under the row's color, drawn by the box under the row: the
	-- color reads the same over any ground, as the build list's.
	row.base = critBox:CreateTexture(nil, "ARTWORK")
	row.base:SetTexture(FLAT)
	row.base:SetVertexColor(0.05, 0.05, 0.07, 0.92)
	row.base:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.base:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
	row.base:Hide()
	row.label:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW_HEIGHT - 4)
	row.icon:SetHeight(ROW_HEIGHT - 4)
	row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", ROW_HEIGHT + 2, 0)
	row.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = row:CreateTexture(nil, "OVERLAY")
		line:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", row, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", row, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, row, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, row, "BOTTOM"..side, 0, 0)
		end
		table.insert(row.edges, line)
	end
	-- The value in a column of its own, as the build list's numbers.
	row.divider = row:CreateTexture(nil, "OVERLAY")
	row.divider:SetTexture(FLAT)
	row.divider:SetVertexColor(1, 1, 1, 0.14)
	row.divider:SetWidth(1)
	row.divider:SetPoint("TOP", row, "TOPRIGHT", -46, 0)
	row.divider:SetPoint("BOTTOM", row, "BOTTOMRIGHT", -46, 0)
	-- The box sits on the left of the screen: its cards open on its right.
	row.cardFrame = critBox
	row.cardRight = true
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		critHovered = this
		CritTooltip(this)
	end)
	row:SetScript("OnLeave", function()
		critHovered = nil
		critTip:Hide()
	end)
	row:Hide()
	critRows[index] = row
end

local function DrawCrits()
	if not CritsShown() then
		critBox:Hide()
		return
	end
	local sorted = {}
	for ability in pairs(critBest) do
		table.insert(sorted, ability)
	end
	table.sort(sorted, function(a, b) return critBest[a] > critBest[b] end)
	for index = 1, CRIT_ROWS do
		local row = critRows[index]
		local ability = sorted[index]
		if ability then
			row.ability = ability
			row.label:SetText(ability)
			row.value:SetText(Short(critBest[ability]))
			-- The damage meter's color for the ability, so both lists match.
			local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(ability) or critColor[ability]
			row.color = color
			-- The build list's look: filled with the color, light text, a border.
			row.label:SetTextColor(1, 1, 1)
			row.value:SetTextColor(1, 1, 1)
			row.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
			row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
			for _, line in pairs(row.edges) do
				line:SetVertexColor(color[1], color[2], color[3], 0.6)
			end
			local icon = SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(ability)
			if icon then
				row.icon:SetTexture(icon)
				row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			else
				row.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon")
				row.icon:SetTexCoord(0, 1, 0, 1)
			end
			row.base:Show()
			row:Show()
		else
			row.ability = nil
			row.base:Hide()
			row:Hide()
		end
	end
	local count = math.min(CRIT_ROWS, table.getn(sorted))
	if count == 0 then
		critBox:Hide()
		return
	end
	critBox:SetHeight(TITLE_HEIGHT + 8 + count * ROW_HEIGHT)
	critBox:Show()
end

function SurvivorUI_ToggleCrits()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.critBox = not CritsShown()
	DrawCrits()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: Biggest Crits box "..(SurvivorUIDB.critBox and "on (it shows once something crits)." or "off."))
end
-- The game's own clock starts when the hero first moves, so this one does
-- too: from "Move to begin" the hero's map position is watched for a change.
local function WatchFirstStep()
	local x, y = Position()
	if not x then
		return
	end

	if not run.fromX then
		run.fromX, run.fromY = x, y
	elseif math.abs(x - run.fromX) + math.abs(y - run.fromY) > 0.0002 then
		run.armed = nil
		run.started = GetTime()
		run.ended = nil
	end
end

-- On screen from the start of a run; it stays after the run so its last
-- numbers can be read, until the next one starts.
local elapsed = 0
local lastGameT                  -- the game's clock last seen, to notice a new run
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	-- The game's clock going back means a new run: a clean slate.
	local game = Game()
	if game then
		local now = Num(game.t)
		if lastGameT and now + 3 < lastGameT then
			ResetRun()
		end
		lastGameT = now
	end

	if run.armed and not run.started then
		WatchFirstStep()
	end

	if run.started and not run.ended then
		WatchPause()
	end

	-- A reset can take a row away from under the mouse; its card goes with it.
	if critTip:IsVisible() and not (critHovered and critHovered:IsVisible() and critHovered.ability) then
		critHovered = nil
		critTip:Hide()
	end

	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0

	if Shown() and Draw() then
		panel:Show()
	else
		panel:Hide()
	end
	DrawCrits()
	WatchBuffs()
	-- An open card keeps its cooldown and damage current.
	if critHovered and critTip:IsVisible() then
		CritTooltip(critHovered)
	end
end)

local placer = CreateFrame("Frame")
placer:RegisterEvent("PLAYER_ENTERING_WORLD")
placer:SetScript("OnEvent", function()
	RestorePanel()
	RestoreCritBox()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(panel, "This Run", SavePanel, nil, RestorePanel)
	SurvivorUI_RegisterMover(critBox, "Biggest Crits", SaveCritBox, nil, RestoreCritBox)
end

function SurvivorUI_ToggleRun()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.runPanel = not Shown()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: run panel "..(SurvivorUIDB.runPanel and "shown." or "hidden."))
end

function SurvivorUI_ResetRun()
	ResetCrits()
end

------------------------------------------------------------------------------
-- Reading the combat log.

-- A blow landed with the clock still stopped (the first step went unseen, or
-- the panel was reset mid-run): start it here.
local function Begin()
	if not run.started then
		run.armed = nil
		run.started = GetTime()
		run.ended = nil
	end
end

local function RecordCrit(ability, amount)
	amount = tonumber(amount)
	if not ability or not amount then
		return
	end
	if not critColor[ability] then
		critSeen = critSeen + 1
		critColor[ability] = CRIT_PALETTE[math.mod(critSeen - 1, table.getn(CRIT_PALETTE)) + 1]
	end

	local stats = critStats[ability]
	if not stats then
		stats = { sum = 0, count = 0, least = amount }
		critStats[ability] = stats
	end
	stats.last = amount
	stats.sum = stats.sum + amount
	stats.count = stats.count + 1
	stats.least = math.min(stats.least, amount)

	if not critBest[ability] or amount > critBest[ability] then
		critBest[ability] = amount
		critBestAt[ability] = RunNow()
	end
	if critHovered and critHovered:IsVisible() then
		CritTooltip(critHovered)
	end
end

local function RecordHit(ability, amount)
	amount = tonumber(amount)
	if not ability or not amount then
		return
	end
	local stats = hitStats[ability]
	if not stats then
		stats = { sum = 0, count = 0 }
		hitStats[ability] = stats
	end
	stats.last = amount
	stats.sum = stats.sum + amount
	stats.count = stats.count + 1
	if critHovered and critHovered:IsVisible() then
		CritTooltip(critHovered)
	end
end

------------------------------------------------------------------------------
-- A demon's spell the hero holds too (the Infernal's Hellfire and the
-- hero's): the combat log writes both the same, by the hero's own event. The
-- game's spell list (AZS_SPELLS, sent every 2 seconds or so) tells the
-- hero's casts: a cast starts the cooldown over, so the list shows when it
-- began. A line that came from then to 1.2 sec after (a spell's flight) is
-- the hero's; any other is the demon's, once a list after the line has had
-- its say (or 4 sec on). So such a line reaches Biggest Crits 2 sec or so
-- late. A spell cooling faster than the list comes casts unseen between two
-- lists: its lines stay the hero's, as before.

local held = {}           -- lines waiting: { at, key, hero, demon, amount, crit }
local casts = {}          -- [key] = the hero's cast times the lists told, the last ones
local listSeen            -- AZS_SPELLS_UPDATED at the last look
local SLOWEST_LIST = 1.9  -- a cooldown at least this long shows every cast

local function Cooldown(key)
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == key then
			return tonumber(entry.cd or entry[4]), tonumber(entry.cdmax or entry[5])
		end
	end
end

-- Each new list: every spell's last cast, while its cooldown runs (a spell
-- ready shows a tenth or two, which tells nothing).
local function ReadCasts()
	local sent = AZS_SPELLS_UPDATED
	if not sent or sent == listSeen then
		return
	end
	listSeen = sent
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		local key = entry.key or entry[1] or ""
		local cd, cdmax = tonumber(entry.cd or entry[4]), tonumber(entry.cdmax or entry[5])
		if cd and cdmax and cd > 0.3 and cd <= cdmax + 0.1 then
			local at = sent - (cdmax - cd)
			casts[key] = casts[key] or {}
			local told = casts[key]
			local last = told[table.getn(told)]
			if not last or math.abs(last - at) > 0.3 then
				table.insert(told, at)
				if table.getn(told) > 12 then
					table.remove(told, 1)
				end
			end
		end
	end
end

-- A line kept back to tell whose, or false to record it as it is.
local function Hold(name, amount, crit)
	local key, demon = SurvivorUI_PetCast and SurvivorUI_PetCast(name)
	if not key then
		return false
	end
	local _, cdmax = Cooldown(key)
	if not (cdmax and cdmax >= SLOWEST_LIST) then
		return false
	end
	table.insert(held, { at = GetTime(), key = key, hero = name, demon = demon, amount = amount, crit = crit })
	return true
end

local function Whose(line)
	for _, at in pairs(casts[line.key] or {}) do
		if at <= line.at + 0.15 and at >= line.at - 1.2 then
			return line.hero
		end
	end
	if (listSeen and listSeen > line.at + 0.15) or GetTime() - line.at > 4 then
		return line.demon
	end
end

local castWatch = CreateFrame("Frame")
castWatch:SetScript("OnUpdate", function()
	ReadCasts()
	local index = 1
	while index <= table.getn(held) do
		local line = held[index]
		local whose = Whose(line)
		if whose then
			table.remove(held, index)
			if line.crit then
				RecordCrit(whose, line.amount)
			else
				RecordHit(whose, line.amount)
			end
		else
			index = index + 1
		end
	end
end)

-- The same four shapes as a crit's line, with "hits" in place of "crits".
local function Hit(message)
	-- Every shape below has one of these: a crit's line, the most of them in a
	-- fight, goes without the patterns.
	if not (string.find(message, " hits ", 1, true) or string.find(message, "You hit ", 1, true)) then
		return
	end
	local _, _, ability, _, amount = string.find(message, "^Your (.+) hits (.+) for (%d+)")
	if not ability then
		_, _, _, amount = string.find(message, "^You hit (.+) for (%d+)")
		if amount then
			ability = "Melee"
		end
	end
	if not ability then
		local owner
		_, _, owner, ability, _, amount = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+)")
		if owner and SurvivorUI_IsPet and SurvivorUI_IsPet(owner) then
			ability = owner.."'s "..ability
		end
	end
	if not ability then
		_, _, ability, _, amount = string.find(message, "^(.+) hits (.+) for (%d+)")
	end
	local name = SurvivorUI_SourceOf and SurvivorUI_SourceOf(ability, message) or ability
	if not Hold(name, amount, false) then
		RecordHit(name, amount)
	end
end

local function Crit(message)
	-- Every shape below has " crit": a plain hit goes without the patterns.
	if not string.find(message, " crit", 1, true) then
		return
	end
	-- Each ability's best crit, as the combat numbers see it (SurvivorUI.lua).
	local _, _, any = string.find(message, " crits? .- for (%d+)")
	if any and SurvivorUI_NoteCrit then
		SurvivorUI_NoteCrit(any, message)
	end
	-- "Your Lightning Bolt crits Kobold Vermin for 168."
	local _, _, ability, _, amount = string.find(message, "^Your (.+) crits (.+) for (%d+)")
	if not ability then
		-- "You crit Kobold Vermin for 40."
		_, _, _, amount = string.find(message, "^You crit (.+) for (%d+)")
		if amount then
			ability = "Melee"
		end
	end
	if not ability then
		-- "Magma Totem's Magma Totem crits Kobold Vermin for 90." A pet's own
		-- spell keeps its pet, as the combat numbers have it (SurvivorUI.lua):
		-- "Imp's Fireball crits..." is the Imp's Fireball.
		local owner
		_, _, owner, ability, _, amount = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+)")
		if owner and SurvivorUI_IsPet and SurvivorUI_IsPet(owner) then
			ability = owner.."'s "..ability
		end
	end
	if not ability then
		-- "Spirit Wolf crits Kobold Vermin for 30."
		_, _, ability, _, amount = string.find(message, "^(.+) crits (.+) for (%d+)")
	end
	local name = SurvivorUI_SourceOf and SurvivorUI_SourceOf(ability, message) or ability
	if not Hold(name, amount, true) then
		RecordCrit(name, amount)
	end
end

local function Dealt(message)
	local _, _, amount = string.find(message, " for (%d+)")
	if not amount then
		-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
		_, _, amount = string.find(message, " suffers (%d+) .+ from your ")
	end
	if not amount then
		-- "You reflect 4 Nature damage to Kobold Vermin."
		_, _, amount = string.find(message, "^You reflect (%d+) ")
	end
	if amount then
		Begin()
		run.dealt = run.dealt + tonumber(amount)
	end
end

-- The damage the game counts as from the ground ("area" in AZS_TAKEN), so far.
local function AreaTaken()
	for _, entry in pairs(AZS_TAKEN or {}) do
		if Field(entry, "source", 1) == "area" then
			return Num(Field(entry, "dmg", 2))
		end
	end
	return 0
end

-- Who hit, with what (nil: a swing), and whether a crit, from the combat log:
-- "Hogger hits you for 12.", "Hogger crits you for 30.", "Kobold Geomancer's
-- Fireball crits you for 80 Fire damage.", "You suffer 3 Nature damage from
-- Venom Spider's Poison."
local function HitFrom(message)
	local _, _, who, what, verb = string.find(message, "^(.-)'s (.-) (%a+) you for %d+")
	if who and (verb == "hits" or verb == "crits") then
		return who, what, verb == "crits"
	end
	_, _, who, verb = string.find(message, "^(.-) (%a+) you for %d+")
	if who and (verb == "hits" or verb == "crits") then
		return who, nil, verb == "crits"
	end
	_, _, who, what = string.find(message, "^You suffer %d+ .- damage from (.-)'s (.-)%.")
	if who then
		return who, what, false
	end
	_, _, who = string.find(message, "^You suffer %d+ .- damage from (.-)%.")
	return who, nil, false
end

local KEEP_HITS = 8

local function Taken(message)
	-- "Kobold Vermin hits you for 5." / "You suffer 3 Nature damage from ..."
	local _, _, amount = string.find(message, " you for (%d+)")
	if not amount then
		_, _, amount = string.find(message, "^You suffer (%d+) ")
	end
	if amount then
		run.taken = run.taken + tonumber(amount)
		-- Kept for the killing blow: the last few, with the ground's damage so far.
		local who, what, crit = HitFrom(message)
		run.hits = run.hits or {}
		table.insert(run.hits, { at = GetTime(), who = who, what = what, crit = crit,
			amount = tonumber(amount), area = AreaTaken() })
		if table.getn(run.hits) > KEEP_HITS then
			table.remove(run.hits, 1)
		end
	end
end

-- As the hero falls (Run History, RunHistory.lua): what struck last, the hits
-- of the last 10 seconds (the newest first, how long before), and the damage
-- taken by kind as the game counts it (AZS_TAKEN: boss melee, mob spell,
-- area...). The killing blow is the last hit the combat log wrote, unless the
-- ground's damage grew after it: then a ground effect (the log writes none).
function SurvivorUI_DeathRecap()
	local now = GetTime()
	local hits = run.hits or {}
	local last = hits[table.getn(hits)]
	local area = AreaTaken()
	local recap = { hits = {}, kinds = {} }
	if last and area > last.area then
		recap.killer = { area = true, amount = area - last.area }
	elseif last then
		recap.killer = { who = last.who, what = last.what, crit = last.crit, amount = last.amount }
	elseif area > 0 then
		recap.killer = { area = true }
	end
	for index = table.getn(hits), 1, -1 do
		local hit = hits[index]
		if now - hit.at <= 10 then
			table.insert(recap.hits, { who = hit.who, what = hit.what, crit = hit.crit, amount = hit.amount,
				ago = math.floor((now - hit.at) * 10 + 0.5) / 10 })
		end
	end
	for _, entry in pairs(AZS_TAKEN or {}) do
		local dmg = Num(Field(entry, "dmg", 2))
		if dmg > 0 then
			table.insert(recap.kinds, { source = Field(entry, "source", 1) or "?", dmg = dmg })
		end
	end
	table.sort(recap.kinds, function(a, b) return a.dmg > b.dmg end)
	return recap
end

local function Death(message)
	-- "You have slain Kobold Vermin!" / "Kobold Vermin dies."
	local _, _, name = string.find(message, "^You have slain (.+)!")
	if not name then
		_, _, name = string.find(message, "^(.+) dies%.")
	end
	if not name or not run.started then
		return
	end

	run.kills = run.kills + 1
	local kind = kindByName[name]
	if kind then
		run[kind] = run[kind] + 1
	end
end

-- Events whose hits can also be critical strikes.
local HIT_EVENTS = {
	CHAT_MSG_COMBAT_SELF_HITS = true, CHAT_MSG_SPELL_SELF_DAMAGE = true,
	CHAT_MSG_COMBAT_PET_HITS = true, CHAT_MSG_SPELL_PET_DAMAGE = true,
}
local DEALT_EVENTS = {
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = true, CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = true,
}
local TAKEN_EVENTS = {
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = true, CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = true,
	CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = true,
}

local events = CreateFrame("Frame")
for _, group in pairs({ HIT_EVENTS, DEALT_EVENTS, TAKEN_EVENTS }) do
	for event in pairs(group) do
		events:RegisterEvent(event)
	end
end
events:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
events:RegisterEvent("CHAT_MSG_SYSTEM")
-- Nothing to tally in a miss, but it is the world moving: see Alive.
events:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
events:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
events:SetScript("OnEvent", function()
	local message = arg1 or ""


	if event == "CHAT_MSG_SYSTEM" then
		-- "<hero> enters <zone>. Move to begin.": a new run.
		if string.find(message, "Move to begin", 1, true) then
			ResetRun()
			run.armed = true
		-- "Your mages earn 373 talent experience.": the run is over.
		elseif string.find(message, "talent experience", 1, true) and run.started and not run.ended then
			Alive()
			run.ended = GetTime()
		end
		return
	end

	if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		Death(message)
	elseif HIT_EVENTS[event] then
		Dealt(message)
		Crit(message)
		Hit(message)
	elseif DEALT_EVENTS[event] then
		-- The periodic event also carries other units' damage; only "your" counts.
		if event ~= "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" or string.find(message, "from your", 1, true) then
			Dealt(message)
		end
	elseif TAKEN_EVENTS[event] then
		Taken(message)
	end
	Alive()
end)
