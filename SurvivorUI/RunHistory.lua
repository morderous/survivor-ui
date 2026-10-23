-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the run history, the last runs as they ended.
--
-- The game's end screen (fallen or won) covers the addon's panels, and says
-- nothing of the damage a second, the spells' shares or the biggest crits.
-- So as a run ends, the panels are kept as they stand: the run tracker (the
-- clock, each boss and when it fell, the guardians, the elites, the level),
-- the run's numbers, the build with its ranks and the jewelry worn, the damage
-- by source, the biggest crits and the loot; with the hero (name, race,
-- class), the map and its modifiers, and the talent experience the game gives
-- for the run (read off its chat line); a co-op run's party too (the game's
-- 0.113), each hero with their damage. The last ten, for the account, newest
-- first.
--
-- Won, a run can go on in endless mode: the same run, then, with two moments,
-- the victory and the endless end, each kept whole (the game's numbers run on
-- from the start, so the endless one is the whole run).
--
-- Shown in a window of their own, one run at a time, < and > for the others,
-- each panel in a frame of its own and in its own look, as it stood when the
-- run ended: the hourglass by the minimap, or /sui history. Which runs are
-- kept, how many and with their tooltips: the options, Run History; a run
-- pinned stays however many come after it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local OWN_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local LONGEST = 10                -- the longest runs, kept however old when chosen
local GOLD = { 1, 0.82, 0 }
local MUTED = { 0.6, 0.6, 0.65 }
local WHITE = { 1, 1, 1 }

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function History()
	local db = Settings()
	db.runHistory = db.runHistory or {}
	return db.runHistory
end

local function Num(value)
	return tonumber(value) or 0
end

-- The damage a run dealt as the meter counts it, what reached the enemies,
-- as This Run shows it while the run lasts. The game's end screen counts it
-- with the overkill too (2026-10-20: 960k against the meter's 252k, many weak
-- enemies under big blows), and that is what dealt keeps. A run kept before
-- the meter's total was, by dealt. Career.lua's too.
local function Dealt(run)
	return run and tonumber(run.meterTotal) or Num(run and run.dealt)
end
SurvivorUI_RunDealt = Dealt

local function Short(value)
	return SurvivorUI_Abbrev and SurvivorUI_Abbrev(value) or tostring(math.floor(Num(value) + 0.5))
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(Num(seconds)))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

-- The computer's own clock. The game's is UTC (date() gives 23:44 for 20:44
-- in Brazil), and nothing in it tells the computer's time zone: its
-- GetGameTime() is a clock of the game's world (09:59 for 21:35). So the zone
-- is set in the options (This Run, "Your time zone", SurvivorUIDB.timeZone in
-- hours); until then, the zone date() gives against its "!" UTC, should the
-- game ever give the computer's; else none, and the times say UTC. A run
-- keeps its moment (time(), the same the world over) and is shown in it.
local function Zone()
	local hours = SurvivorUIDB and tonumber(SurvivorUIDB.timeZone)
	if hours then
		return hours * 3600
	end
	local ok, here, utc = pcall(function() return date("*t"), date("!*t") end)
	if ok and type(here) == "table" and type(utc) == "table" and here.hour and utc.hour then
		local apart = (here.hour * 60 + (here.min or 0)) - (utc.hour * 60 + (utc.min or 0))
		while apart > 720 do
			apart = apart - 1440
		end
		while apart <= -720 do
			apart = apart + 1440
		end
		if apart ~= 0 then
			return apart * 60
		end
	end
	return nil
end

-- How long ago: "just now", "18 min ago", "3 h ago", "2 days ago".
local function Ago(at)
	local seconds = time() - Num(at)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return math.floor(seconds / 60).." min ago"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600).." h ago"
	end
	local days = math.floor(seconds / 86400)
	return days == 1 and "1 day ago" or days.." days ago"
end

-- A moment (seconds since 1970, UTC) as the computer's date and time,
-- "2026-10-18 20:44" (with "UTC" after it while the zone is not known): the
-- days counted into a year, month and day.
local function When(at)
	local zone = Zone()
	local seconds = Num(at) + (zone or 0)
	local days = math.floor(seconds / 86400)
	local rest = seconds - days * 86400
	local z = days + 719468
	local era = math.floor(z / 146097)
	local dayOfEra = z - era * 146097
	local yearOfEra = math.floor((dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365)
	local year = yearOfEra + era * 400
	local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
	local m = math.floor((5 * dayOfYear + 2) / 153)
	local day = dayOfYear - math.floor((153 * m + 2) / 5) + 1
	local month = m < 10 and m + 3 or m - 9
	if month <= 2 then
		year = year + 1
	end
	return string.format("%d-%02d-%02d %02d:%02d", year, month, day, math.floor(rest / 3600), math.floor(math.mod(rest, 3600) / 60))
		..(zone and "" or " UTC")
end

-- "ffa335ee" as a color; white when unknown.
local function HexColor(hex)
	if not hex or string.len(hex) ~= 8 then
		return WHITE
	end
	local function Part(from)
		return (tonumber(string.sub(hex, from, from + 1), 16) or 255) / 255
	end
	return { Part(3), Part(5), Part(7) }
end

------------------------------------------------------------------------------
-- Keeping a run as it ends.

-- The talent experience the run gave, from the game's line as it ends:
-- "Your Shamans earn 31475 talent experience." It can come just before the
-- run is kept, or just after.
local pendingTalent             -- { amount, at }: come before the run was kept
local awaitingTalent            -- the moment kept, its line not come yet

-- An item's tooltip, read off a tooltip of the addon's own (unseen).
local scanner = CreateFrame("GameTooltip", "SurvivorUIHistoryScan", nil, "GameTooltipTemplate")
local function ItemTip(link)
	if not (link and SurvivorUI_ReadTooltip) then
		return nil
	end
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanner:ClearLines()
	scanner:SetHyperlink(link)
	local lines = scanner:NumLines() > 0 and SurvivorUI_ReadTooltip(scanner) or nil
	scanner:Hide()
	return lines
end

-- The run as it stands: its numbers and every panel's, with their tooltips
-- as photos. "going" (an endless run's moment taken while it lasts): not the
-- tooltips that show in GameTooltip, which would close one open under the
-- mouse.
local function Snapshot(phase)
	local run, zone = AZS_RUN or {}, AZS_ZONE or {}
	local seconds = Num(run.t)
	local _, classKey = UnitClass("player")
	local record = {
		at = time(),
		when = date("%Y-%m-%d %H:%M"),
		result = phase,
		hero = UnitName("player"),
		race = UnitRace("player"),
		class = zone.cname or UnitClass("player"),
		classKey = classKey,
		zone = zone.zname or GetZoneText(),
		mods = SurvivorUI_ModsLabel and SurvivorUI_ModsLabel(zone.mods) or nil,
		time = seconds,
		level = Num(run.lvl),
		kills = Num(run.kills),
		elites = Num(run.ek),
		guardians = Num(run.gk),
		bosses = Num(run.bk),
		dealt = Num(run.dealt),
		taken = Num(run.taken),
		gold = Num(run.ge),
		caches = Num(run.ck),
	}
	-- The damage by source, the most first, as the game's meter has it.
	record.sources = {}
	if AZS_GetMeter then
		local lines, total, dps = AZS_GetMeter()
		lines = lines or {}
		record.meterTotal, record.meterDps = Num(total), Num(dps)
		for index = 1, math.min(8, table.getn(lines)) do
			local line = lines[index]
			local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(line.name) or { 0.8, 0.8, 0.8 }
			table.insert(record.sources, {
				name = line.name, dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) == 1,
				color = { color[1], color[2], color[3] },
				icon = SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(line.name) or nil,
				rank = SurvivorUI_MeterRank and SurvivorUI_MeterRank(line.name) or nil,
			})
		end
	end
	-- The colors and icons as they are now: the meter hands colors out in the
	-- order sources first show, so another session gives others.
	record.crits = SurvivorUI_CritList and SurvivorUI_CritList(8) or {}
	for _, crit in pairs(record.crits) do
		local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(crit.ability)
		crit.color = color and { color[1], color[2], color[3] } or nil
		crit.icon = SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(crit.ability) or nil
	end
	record.build = SurvivorUI_BuildSnapshot and SurvivorUI_BuildSnapshot() or {}
	record.gear = SurvivorUI_GearSnapshot and SurvivorUI_GearSnapshot() or nil
	record.loot = SurvivorUI_LootList and SurvivorUI_LootList(12) or {}
	-- The hero's numbers (the Stats panel's), every one, as they stand.
	if AZS_STATS then
		record.stats = {}
		for key, value in pairs(AZS_STATS) do
			if type(value) == "number" then
				record.stats[key] = value
			end
		end
	end
	record.tracker = SurvivorUI_TrackerSnapshot and SurvivorUI_TrackerSnapshot() or nil
	-- A co-op run: the party, each hero's damage as the game's party meter had it (Party.lua).
	record.party = SurvivorUI_PartySnapshot and SurvivorUI_PartySnapshot() or nil
	-- Fallen: what struck last, the last hits, the damage taken by kind (RunPanel.lua).
	if phase == "dead" and SurvivorUI_DeathRecap then
		record.death = SurvivorUI_DeathRecap()
	end
	-- The cards of the spells, the sources and the crits (RunPanel.lua).
	record.cards = {}
	if SurvivorUI_CritCardData then
		local function Card(name, color, racial)
			if name and not record.cards[name] then
				record.cards[name] = SurvivorUI_CritCardData(name, color, racial)
			end
		end
		for _, spell in pairs(record.build) do
			Card(spell.name, spell.color, spell.racial)
		end
		for _, source in pairs(record.sources) do
			Card(source.name, source.color)
		end
		for _, crit in pairs(record.crits) do
			Card(crit.ability, crit.color)
		end
	end
	for _, item in pairs(record.loot) do
		item.tip = ItemTip(item.item)
	end
	if phase ~= "going" then
		record.rowTips = SurvivorUI_RunRowTips and SurvivorUI_RunRowTips() or nil
		local head = getglobal("SurvivorUITracker")
		if record.tracker and head and SurvivorUI_Photograph then
			record.tracker.tip = SurvivorUI_Photograph(head)
		end
	end
	return record
end

-- The talent line for a moment just kept: come already, or awaited.
local function TalentFor(moment)
	if pendingTalent and math.abs(time() - pendingTalent.at) < 30 then
		moment.talentXp = pendingTalent.amount
		awaitingTalent = nil
	else
		awaitingTalent = moment
	end
	pendingTalent = nil
end

-- A moment without its tooltips' photos.
local function Unphotograph(moment)
	if not moment then
		return
	end
	moment.cards, moment.rowTips = nil, nil
	if moment.tracker then
		moment.tracker.tip = nil
	end
	for _, piece in pairs(moment.gear or {}) do
		piece.tip = nil
	end
	for _, item in pairs(moment.loot or {}) do
		item.tip = nil
	end
end

-- How long a run went: its endless end's time, or its own.
local function Length(run)
	return Num(run.endless and run.endless.time or run.time)
end

-- The history to its settings (the options, Run History): past the count
-- chosen, the oldest runs go, but not the pinned ones nor, when chosen, the
-- ten longest; and past the runs chosen to keep their tooltips' photos (the
-- most of a run's room: some 20 kB a run against 7), the photos go, the
-- pinned and the longest keeping theirs.
local function Trim()
	local db = Settings()
	local history = History()
	local count = tonumber(db.historyKeep) or 100
	local photos = db.historyPhotos or "25"
	-- The run just kept never goes at once, nor a pinned one.
	local protected = {}
	if history[1] then
		protected[history[1]] = true
	end
	for _, run in pairs(history) do
		if run.pinned then
			protected[run] = true
		end
	end
	if db.historyLongest ~= false then
		local sorted = {}
		for _, run in pairs(history) do
			table.insert(sorted, run)
		end
		table.sort(sorted, function(a, b) return Length(a) > Length(b) end)
		for index = 1, math.min(LONGEST, table.getn(sorted)) do
			protected[sorted[index]] = true
		end
	end
	local index = table.getn(history)
	while table.getn(history) > count and index >= 1 do
		if not protected[history[index]] then
			table.remove(history, index)
		end
		index = index - 1
	end
	local withPhotos = photos == "all" and table.getn(history) or (tonumber(photos) or 0)
	for place = 1, table.getn(history) do
		local run = history[place]
		if place > withPhotos and not (photos ~= "0" and protected[run]) then
			Unphotograph(run)
			Unphotograph(run.endless)
		end
	end
end

local function Same(a, b)
	return a and b and a.time == b.time and a.kills == b.kills
end

-- The run kept last, kept again a moment later: its clock went on as long as
-- the computer's did between the two (a new run's starts again from 0).
local function SameRun(last, record)
	if not (last and not last.endless and last.zone == record.zone and last.hero == record.hero) then
		return false
	end
	local apart = Num(record.at) - Num(last.at)
	return apart >= 0 and apart < 120 and math.abs((Num(record.time) - Num(last.time)) - apart) <= 3
end

local function Keep(record)
	local history = History()
	local last = history[1]
	-- The same run kept already (a reload on the end screen): not again.
	if last and last.zone == record.zone and (Same(last, record) or Same(last.endless, record)) then
		return
	end
	TalentFor(record)
	-- The same run a moment ago (an end message the game sends again and
	-- again): this moment in its place, not one run more.
	if SameRun(last, record) then
		record.pinned = last.pinned
		history[1] = record
		return
	end
	table.insert(history, 1, record)
	Trim()
end

-- The run kept at its victory, while it goes on in endless mode: the same
-- zone, endless on, its clock past the victory's, its endless end not kept
-- for good yet.
local function EndlessOf()
	local last = History()[1]
	local run, zone = AZS_RUN, AZS_ZONE or {}
	if not (last and run and last.result == "victory" and Num(run.endl) == 1) then
		return nil
	end
	if last.endless and last.endless.result ~= "going" then
		return nil
	end
	if (zone.zname or GetZoneText()) ~= last.zone or Num(run.t) < Num(last.time) then
		return nil
	end
	return last
end

-- Kept as the run ends; looked at twice a second. In endless mode, its
-- endless moment taken every 10 seconds, so a run left from the menu keeps
-- its last; at the fall, for good. From the game's 0.102 the end comes with
-- the end screen's own numbers too (Settle), and a run left from the menu is
-- kept as well.
local captured
local endlessWait = 0
local lastKept                  -- the moment just kept by the watcher, the game's numbers awaited
local summaryAt                 -- the game's last end settled (its AZS_END_UPDATED)
-- A co-op hero down (the game's 0.113): the game sends its end message every
-- 0.2 s while down, the run going on (a run kept each time, 2026-10-23). The
-- last one held here until the hero is up again (dropped) or the run is over.
local heldEnd
local settledAt                 -- when (GetTime) it was

local END_RESULTS = { defeat = "dead", victory = "victory", left = "left" }
local SUMMARY_FIELDS = {
	time = "t", level = "lvl", kills = "kills", elites = "elites", guardians = "guardians", bosses = "bosses",
	dealt = "dmg", taken = "taken", gold = "gold", caches = "chests", magnets = "magnets",
}

-- The game's own end of the run (AZS_GetRunSummary): the moment the watcher
-- just kept for it brought to the end screen's numbers; an endless run's
-- moment taken while it lasted, brought to its end; else, a run the watcher
-- did not see end (left from the menu), kept now.
local function Settle(summary)
	local result = END_RESULTS[summary.result] or "dead"
	local moment = lastKept
	lastKept = nil
	if not (moment and math.abs(time() - Num(moment.at)) < 60) then
		moment = nil
		local last = History()[1]
		if Num(summary.endl) == 1 and result ~= "victory" then
			if last and last.result == "victory" and last.endless and last.endless.result ~= "dead"
				and math.abs(time() - Num(last.endless.at)) < 30 then
				moment = last.endless
			end
		elseif result == "victory" or (Settings().historyWhich or "all") ~= "victories" then
			moment = Snapshot(result)
			Keep(moment)
		end
	end
	if not moment then
		return
	end
	for field, key in pairs(SUMMARY_FIELDS) do
		if summary[key] ~= nil then
			moment[field] = Num(summary[key])
		end
	end
	moment.result = result
end
local watcher = CreateFrame("Frame")
local elapsed = 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	local step = elapsed
	elapsed = 0
	if not SurvivorUIDB then
		return
	end
	local phase = AZS_GetPhase and AZS_GetPhase()
	-- Keep: None (the options, Run History): nothing kept.
	local which = Settings().historyWhich or "all"
	if which == "none" then
		return
	end
	-- The game's end, come since the last look (0.102 on).
	if AZS_GetRunSummary and AZS_END_UPDATED and AZS_END_UPDATED ~= summaryAt then
		summaryAt = AZS_END_UPDATED
		heldEnd = AZS_GetRunSummary()
	end
	if heldEnd then
		local party = SurvivorUI_InParty and SurvivorUI_InParty()
		local inRun = phase ~= nil and phase ~= "ready"
		if party and inRun and SurvivorUI_IsDown() then
			-- Down in a party, the run on: not the end yet.
		elseif party and (phase == "playing" or phase == "choosing" or phase == "paused") then
			-- Brought back: the run goes on.
			heldEnd = nil
		else
			Settle(heldEnd)
			heldEnd = nil
			captured = true
			settledAt = GetTime()
		end
	end
	-- In a co-op party (the game's 0.113) a hero down is not the run's end,
	-- though the phase says dead while down: only the game's end message,
	-- once the hero is no longer down (heldEnd, above), says the run is over.
	if phase == "dead" and SurvivorUI_InParty and SurvivorUI_InParty() then
		return
	end
	if phase == "dead" or phase == "victory" then
		if not captured then
			captured = true
			local entry = phase == "dead" and EndlessOf()
			if entry then
				entry.endless = Snapshot("dead")
				TalentFor(entry.endless)
				lastKept = entry.endless
			elseif phase == "victory" or which ~= "victories" then
				local record = Snapshot(phase)
				Keep(record)
				lastKept = record
			end
		end
	elseif phase == "playing" or phase == "choosing" or phase == "paused" then
		-- A run going on, but not in the moment the game's end came in
		-- (its message can come a moment before the phase turns).
		if phase == "playing" and not (settledAt and GetTime() - settledAt < 5) then
			captured = nil
			awaitingTalent = nil
			lastKept = nil
		end
		local entry = EndlessOf()
		if entry then
			endlessWait = endlessWait - step
			if not entry.endless or endlessWait <= 0 then
				endlessWait = 10
				entry.endless = Snapshot("going")
			end
		end
	elseif phase == "ready" then
		captured = nil
		-- An endless run left from the menu: its last moment stands.
		local last = History()[1]
		if last and last.endless and last.endless.result == "going" then
			last.endless.result = "left"
		end
	end
end)

local talent = CreateFrame("Frame")
talent:RegisterEvent("CHAT_MSG_SYSTEM")
talent:SetScript("OnEvent", function()
	local _, _, amount = string.find(arg1 or "", "(%d+) talent experience")
	if not amount then
		return
	end
	if awaitingTalent and not awaitingTalent.talentXp then
		awaitingTalent.talentXp = tonumber(amount)
		awaitingTalent = nil
	else
		pendingTalent = { amount = tonumber(amount), at = time() }
	end
end)

------------------------------------------------------------------------------
-- The window: the run's header (the map, how it ended, the hero), then the
-- panels in four columns: the run tracker and the run's numbers; the build
-- with its jewelry, and the damage; Biggest Crits and the loot; the hero's
-- numbers (Stats).

local PAD, GAP = 10, 8            -- the window's margin, and between two panels
local INNER = 220                 -- a panel's rows, as This Run's
local BOX = INNER + 12            -- a panel: its rows 6 in from each side
local WIDTH = PAD * 2 + BOX * 4 + GAP * 3
local HEADER = 72                 -- the result, the hero and the map, over the panels
local ROW = 18
local TOP = 24                    -- a panel's first row, under its title
local SLOTS = 6                   -- the build's spell slots

-- Held by its top: a taller or a shorter run grows or shrinks it downward,
-- the title bar (the arrows, the run's number) staying where it is. At first
-- a little under the screen's top; dragged, held by its top where it is let go.
local window = CreateFrame("Frame", "SurvivorUILastRuns", UIParent)
window:SetWidth(WIDTH)
window:SetHeight(200)
window:SetPoint("TOP", UIParent, "TOP", 0, -60)
window:SetFrameStrata("DIALOG")
window:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
window:SetBackdropColor(0.04, 0.04, 0.07, 0.97)
window:SetBackdropBorderColor(0.42, 0.36, 0.16, 1)
window:EnableMouse(true)
window:SetMovable(true)
if window.SetClampedToScreen then
	window:SetClampedToScreen(true)
end
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", function() this:StartMoving() end)
window:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local left, top = this:GetLeft(), this:GetTop()
	if left and top then
		this:ClearAllPoints()
		this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	end
end)
window:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUILastRuns")
end

local function Font(parent, size, color, flags, justify)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, flags or "OUTLINE")
	color = color or WHITE
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH(justify or "LEFT")
	return text
end

local function Flat(parent, layer, color, alpha)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(FLAT)
	color = color or WHITE
	texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	return texture
end

-- A 1-pixel border around a frame, its four sides apart for their color.
local function Edges(frame, layer)
	local edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = frame:CreateTexture(nil, layer or "OVERLAY")
		line:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", frame, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", frame, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, frame, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side, 0, 0)
		end
		table.insert(edges, line)
	end
	return edges
end

local function Tint(edges, color, alpha)
	for _, line in pairs(edges) do
		line:SetVertexColor(color[1], color[2], color[3], alpha)
	end
end

-- A text at a place in its frame.
local function At(object, frame, x, y)
	object:ClearAllPoints()
	object:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
	object:Show()
end

-- The window in the hero's class color: its edge, the line under the header,
-- the panels' edges and titles, the tab shown. A dark class a little lighter
-- for its words.
local THEMED = {}               -- { kind, region }
local theme = { 1, 0.82, 0 }

local function Light(color)
	return { color[1] + (1 - color[1]) * 0.3, color[2] + (1 - color[2]) * 0.3, color[3] + (1 - color[3]) * 0.3 }
end

local function Themed(kind, region)
	table.insert(THEMED, { kind, region })
	return region
end

local function Theme(color)
	theme = color
	local light = Light(color)
	window:SetBackdropBorderColor(color[1], color[2], color[3], 0.8)
	for _, entry in pairs(THEMED) do
		local kind, region = entry[1], entry[2]
		if kind == "text" then
			region:SetTextColor(light[1], light[2], light[3])
		elseif kind == "rule" then
			region:SetVertexColor(color[1], color[2], color[3], 0.5)
		elseif kind == "box" then
			region:SetBackdropBorderColor(color[1], color[2], color[3], 0.28)
		end
	end
end

-- A kept tooltip beside the window, level with its row: on the window's left
-- for the first two columns, on its right for the other two.
local function Aside(owner, column)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	local scale = owner:GetEffectiveScale() / GameTooltip:GetEffectiveScale()
	if column <= 2 then
		local gap = ((owner:GetLeft() or 0) - (window:GetLeft() or 0)) * scale + 6
		GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -gap, 0)
	else
		local gap = ((window:GetRight() or 0) - (owner:GetRight() or 0)) * scale + 6
		GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 0)
	end
end

local function ShowKept(owner, lines, column)
	if lines and SurvivorUI_ShowTooltipLines then
		Aside(owner, column)
		SurvivorUI_ShowTooltipLines(lines)
		return true
	end
end

-- A row with a kept card (RunPanel.lua's): beside the window, as the panels'.
local function CardRow(row, column)
	row.cardFrame = window
	row.cardRight = column > 2
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		if this.keptCard and SurvivorUI_CritCardShow then
			SurvivorUI_CritCardShow(this)
		end
	end)
	row:SetScript("OnLeave", function()
		if SurvivorUI_CritCardHide then
			SurvivorUI_CritCardHide()
		end
	end)
end

local function TextButton(label, width, onClick)
	local button = CreateFrame("Button", nil, window)
	button:SetWidth(width)
	button:SetHeight(18)
	button.text = Font(button, 12, MUTED, nil, "CENTER")
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(label)
	button:SetScript("OnEnter", function() if this:IsEnabled() == 1 then this.text:SetTextColor(1, 1, 1) end end)
	button:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	button:SetScript("OnClick", onClick)
	return button
end

------------------------------------------------------------------------------
-- The header: how the run ended at the top in the middle, as its title (an
-- endless run's two, each showing its moment on a click), the modifiers under
-- it; the hero at the top left in the class's color, the map under it; the
-- date on the right.

local shown = 1
local view = "end"                -- an endless run's moment shown: "victory" or "end"
local Draw
local Disarm                      -- the Delete asked for, put back (set with its button)

-- A run by its number, going round: the first's < is the last, the last's >
-- the first.
local function Go(number)
	local total = table.getn(History())
	if Disarm then
		Disarm()
	end
	if total == 0 then
		shown = 1
		Draw()
		return
	end
	shown = math.mod(number - 1 + total, total) + 1
	view = "end"
	Draw()
	window.again = true
end

local close = TextButton("x", 18, function() window:Hide() end)
close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -7)
local after = TextButton(">", 18, function() Go(shown + 1) end)
after:SetPoint("RIGHT", close, "LEFT", -10, 0)

-- The run's number and the count in one box, "3 / 10"; a click on it to
-- type another, Enter goes there, Escape leaves it as it was.
local pageButton = CreateFrame("Button", nil, window)
pageButton:SetWidth(72)
pageButton:SetHeight(20)
pageButton:SetPoint("RIGHT", after, "LEFT", -6, 0)
pageButton:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
pageButton:SetBackdropColor(0, 0, 0, 0.55)
pageButton:SetBackdropBorderColor(1, 1, 1, 0.25)
pageButton.text = Font(pageButton, 11, WHITE, nil, "CENTER")
pageButton.text:SetPoint("CENTER", pageButton, "CENTER", 0, 0)

local pageBox = CreateFrame("EditBox", nil, pageButton)
pageBox:SetPoint("TOPLEFT", pageButton, "TOPLEFT", 6, 0)
pageBox:SetPoint("BOTTOMRIGHT", pageButton, "BOTTOMRIGHT", -6, 0)
pageBox:SetAutoFocus(false)
pageBox:SetNumeric(true)
pageBox:SetMaxLetters(3)
pageBox:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
pageBox:SetJustifyH("CENTER")
pageBox:SetTextColor(1, 1, 1)
pageBox:Hide()

pageButton:SetScript("OnClick", function()
	this.text:Hide()
	pageBox:SetText("")
	pageBox:Show()
	pageBox:SetFocus()
end)
pageButton:SetScript("OnEnter", function()
	this:SetBackdropBorderColor(1, 1, 1, 0.6)
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Run "..shown.." of "..table.getn(History()), 1, 1, 1)
	GameTooltip:AddLine("1 is the newest. Click to type a run's number, then Enter.", 0.8, 0.8, 0.8, 1)
	GameTooltip:Show()
end)
pageButton:SetScript("OnLeave", function()
	if not pageBox.typing then
		this:SetBackdropBorderColor(1, 1, 1, 0.25)
	end
	GameTooltip:Hide()
end)
pageBox:SetScript("OnEnterPressed", function()
	local number = tonumber(this:GetText())
	this:ClearFocus()
	if number then
		Go(math.max(1, math.min(number, table.getn(History()))))
	end
end)
pageBox:SetScript("OnEscapePressed", function()
	this:ClearFocus()
end)
pageBox:SetScript("OnEditFocusGained", function()
	this.typing = true
	pageButton:SetBackdropBorderColor(1, 1, 1, 0.8)
end)
pageBox:SetScript("OnEditFocusLost", function()
	this.typing = nil
	this:Hide()
	pageButton:SetBackdropBorderColor(1, 1, 1, 0.25)
	pageButton.text:Show()
end)

local before = TextButton("<", 18, function() Go(shown - 1) end)
before:SetPoint("RIGHT", pageButton, "LEFT", -6, 0)

------------------------------------------------------------------------------
-- A photo of the page, to share: for a moment the rest of the interface put
-- away (UIParent hidden, the window lent to the world's frame meanwhile, and
-- the game's own HUD parts that show), the world dimmed behind it; the
-- game's Screenshot taken (its Screenshots folder); then all as it was.

local HUD_PARTS = { "clock", "bosses", "tally", "build", "banners", "loot", "meter", "levels", "flag" }

local shade = CreateFrame("Frame", nil, WorldFrame)
shade:SetAllPoints(WorldFrame)
shade:SetFrameStrata("BACKGROUND")
shade.fill = shade:CreateTexture(nil, "BACKGROUND")
shade.fill:SetTexture(FLAT)
shade.fill:SetVertexColor(0, 0, 0, 0.55)
shade.fill:SetAllPoints(shade)
shade:Hide()

local photo = CreateFrame("Frame")
photo:Hide()
photo.hud = {}

local camera

-- The window held at the same place on the screen, by its top left, under
-- parent: its scale set so it stays the same size there.
local function LendTo(parent, scale)
	local left, top = window:GetLeft(), window:GetTop()
	local effective = window:GetEffectiveScale()
	window:SetParent(parent)
	window:SetScale(scale or effective / parent:GetEffectiveScale())
	if left and top then
		-- The same place in screen pixels, in the window's units at its new scale.
		local ratio = effective / window:GetEffectiveScale()
		window:ClearAllPoints()
		window:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", left * ratio, top * ratio)
	end
end

local function PhotoDone(result)
	photo:Hide()
	photo:UnregisterAllEvents()
	shade:Hide()
	LendTo(UIParent, photo.scale)
	window:SetFrameStrata("DIALOG")
	UIParent:Show()
	for _, part in pairs(photo.hud) do
		AZS_SetHudShown(part, true)
	end
	photo.hud = {}
	camera:Show()
	if result == "SCREENSHOT_SUCCEEDED" then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: Run History's page saved as a screenshot, in the game's Screenshots folder.")
	elseif result == "SCREENSHOT_FAILED" then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the game could not save the screenshot.")
	end
end

-- Two frames drawn without the rest of the interface, then the picture; all
-- back as the game says it is saved (or failed), or after 3 seconds.
photo:SetScript("OnUpdate", function()
	this.frames = this.frames + 1
	this.waited = this.waited + arg1
	if this.frames == 3 then
		Screenshot()
	elseif this.waited > 3 then
		PhotoDone()
	end
end)
photo:SetScript("OnEvent", function()
	PhotoDone(event)
end)

local function TakePhoto()
	if not Screenshot or photo:IsShown() then
		return
	end
	GameTooltip:Hide()
	photo.scale = window:GetScale()
	camera:Hide()
	LendTo(WorldFrame)
	window:SetFrameStrata("FULLSCREEN_DIALOG")
	shade:Show()
	UIParent:Hide()
	if AZS_IsHudShown and AZS_SetHudShown then
		for _, part in pairs(HUD_PARTS) do
			if AZS_IsHudShown(part) then
				AZS_SetHudShown(part, false)
				table.insert(photo.hud, part)
			end
		end
	end
	photo.frames, photo.waited = 0, 0
	photo:RegisterEvent("SCREENSHOT_SUCCEEDED")
	photo:RegisterEvent("SCREENSHOT_FAILED")
	photo:Show()
end

-- Its button: a camera, left of < at the top.
camera = CreateFrame("Button", nil, window)
camera:SetWidth(22)
camera:SetHeight(20)
camera:SetPoint("RIGHT", before, "LEFT", -12, 0)
camera.icon = camera:CreateTexture(nil, "ARTWORK")
camera.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\Camera")
camera.icon:SetWidth(20)
camera.icon:SetHeight(20)
camera.icon:SetPoint("CENTER", camera, "CENTER", 0, 0)
camera.icon:SetVertexColor(0.85, 0.85, 0.85)
camera:SetScript("OnEnter", function()
	this.icon:SetVertexColor(1, 1, 1)
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Photo", 1, 0.82, 0)
	GameTooltip:AddLine("A screenshot of this page alone, to share.", 1, 1, 1, 1)
	GameTooltip:AddLine("Saved in the game's Screenshots folder.", 0.65, 0.65, 0.7, 1)
	GameTooltip:Show()
end)
camera:SetScript("OnLeave", function()
	this.icon:SetVertexColor(0.85, 0.85, 0.85)
	GameTooltip:Hide()
end)
camera:SetScript("OnClick", function() TakePhoto() end)

------------------------------------------------------------------------------
-- Every run in a list, from a small arrow beside the run's number: a line a
-- run ("Fallen, Paladin 28 - EF": how it ended in its color, the class and
-- level in the class's, the map short in green; how long ago, small); a click
-- goes to it, the wheel scrolls. One table for it all: the file is near Lua
-- 5.0's 200 locals.

local pick = { rows = {}, offset = 0, SHOWN = 16, ROW = 16, WIDTH = 280 }
-- The maps the game has, as players write them; another goes by its words'
-- initials ("Stormwind City", SC), one word by its first three letters.
pick.SHORT = {
	["Elwynn Forest"] = "EF", ["Duskwood"] = "DW", ["Arathi Basin"] = "AB", ["Alterac Valley"] = "AV",
	["Warsong Gulch"] = "WSG", ["Scarlet Monastery"] = "SM", ["Blackrock Mountain"] = "BRM", ["Feralas"] = "FER",
	["Naxxramas"] = "NAXX", ["Un'Goro Crater"] = "UNG", ["Gurubashi Arena"] = "GA", ["Gates of Ahn'Qiraj"] = "AQ",
}

function pick.Short(name)
	name = name or "?"
	if pick.SHORT[name] then
		return pick.SHORT[name]
	end
	local letters, words = "", 0
	for word in string.gfind(name, "[^%s%-]+") do
		local lower = string.lower(word)
		if lower ~= "the" and lower ~= "of" then
			words = words + 1
			letters = letters..string.upper(string.sub(word, 1, 1))
		end
	end
	if words <= 1 then
		return string.upper(string.sub(name, 1, 3))
	end
	return letters
end

function pick.Hex(color)
	return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

-- How a run ended, in its badge's colors: Victory green, Fallen red, Endless
-- purple, Left steel blue.
pick.ENDS = {
	victory = { "Victory", { 0.40, 0.95, 0.45 } }, dead = { "Fallen", { 1.00, 0.38, 0.32 } },
	endless = { "Endless", { 0.80, 0.56, 1.00 } }, left = { "Left", { 0.56, 0.78, 1.00 } },
}

-- A run's line: how it ended (an endless one as Endless), the class and level
-- reached, the map.
function pick.Line(run)
	local final = run.endless or run
	local ending = pick.ENDS[run.endless and "endless" or run.result] or pick.ENDS.dead
	local r, g, b = 0.9, 0.9, 0.9
	if SurvivorUI_ClassColor and run.classKey then
		r, g, b = SurvivorUI_ClassColor(run.classKey)
	end
	return pick.Hex(ending[2])..ending[1]..",|r "..pick.Hex({ r, g, b })..(run.class or "?").." "..Num(final.level).."|r"
		.." |cff9a9aa2-|r "..pick.Hex({ 0.40, 1.00, 0.42 })..pick.Short(run.zone).."|r"
		..(run.party and ("  |cff8fc3ffParty "..table.getn(run.party).."|r") or "")
end

pick.arrow = CreateFrame("Button", nil, window)
pick.arrow:SetWidth(16)
pick.arrow:SetHeight(16)
pick.arrow:SetPoint("RIGHT", after, "LEFT", -4, 0)
-- Our own arrow (Art\\DropArrow, light, tinted gold): pushed a shade darker,
-- lit under the mouse.
pick.arrow:SetNormalTexture("Interface\\AddOns\\SurvivorUI\\Art\\DropArrow")
pick.arrow:GetNormalTexture():SetVertexColor(1, 0.82, 0)
pick.arrow:SetPushedTexture("Interface\\AddOns\\SurvivorUI\\Art\\DropArrow")
pick.arrow:GetPushedTexture():SetVertexColor(0.72, 0.58, 0)
pick.arrow:SetHighlightTexture("Interface\\AddOns\\SurvivorUI\\Art\\DropArrow")
pick.arrow:GetHighlightTexture():SetVertexColor(0.5, 0.42, 0.1)
-- The run's number box moves over for it.
pageButton:ClearAllPoints()
pageButton:SetPoint("RIGHT", pick.arrow, "LEFT", -3, 0)

pick.list = CreateFrame("Frame", nil, window)
pick.list:SetFrameStrata("FULLSCREEN_DIALOG")
pick.list:SetWidth(pick.WIDTH)
pick.list:SetPoint("TOPRIGHT", pick.arrow, "BOTTOMRIGHT", 26, -4)
pick.list:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
pick.list:SetBackdropColor(0.04, 0.04, 0.07, 0.98)
pick.list:SetBackdropBorderColor(1, 0.82, 0, 0.55)
pick.list:EnableMouse(true)
pick.list:EnableMouseWheel(true)
pick.list:Hide()
pick.more = Font(pick.list, 8, MUTED, nil, "CENTER")
pick.more:SetPoint("BOTTOM", pick.list, "BOTTOM", 0, 4)

function pick.Row(index)
	local row = pick.rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, pick.list)
	row:SetWidth(pick.WIDTH - 8)
	row:SetHeight(pick.ROW)
	row.wash = Flat(row, "BACKGROUND")
	row.wash:SetAllPoints(row)
	row.text = Font(row, 9, WHITE)
	row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.when = Font(row, 8, MUTED, nil, "RIGHT")
	row.when:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row:SetScript("OnEnter", function() this.wash:SetVertexColor(1, 1, 1, 0.10) end)
	row:SetScript("OnLeave", function() pick.Paint(this) end)
	row:SetScript("OnClick", function()
		pick.list:Hide()
		Go(this.index)
	end)
	pick.rows[index] = row
	return row
end

-- The run shown lit gold in the list.
function pick.Paint(row)
	if row.index == shown then
		row.wash:SetVertexColor(1, 0.82, 0, 0.16)
	else
		row.wash:SetVertexColor(0, 0, 0, 0)
	end
end

function pick.Draw()
	local history = History()
	local total = table.getn(history)
	local count = math.min(pick.SHOWN, total)
	pick.offset = math.max(0, math.min(pick.offset, total - count))
	for place = 1, count do
		local index = pick.offset + place
		local run = history[index]
		local row = pick.Row(place)
		row.index = index
		row.text:SetText("|cff8a8a92"..index..".|r  "..pick.Line(run))
		row.when:SetText(run.at and Ago(run.at) or (run.when or ""))
		pick.Paint(row)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", pick.list, "TOPLEFT", 4, -4 - (place - 1) * pick.ROW)
		row:Show()
	end
	for place = count + 1, table.getn(pick.rows) do
		pick.rows[place]:Hide()
	end
	local scrolls = total > count
	pick.more:SetText(scrolls and ((pick.offset + 1).." - "..(pick.offset + count).." of "..total.."   \194\183   the wheel scrolls") or "")
	pick.list:SetHeight(8 + count * pick.ROW + (scrolls and 14 or 0))
end

pick.list:SetScript("OnMouseWheel", function()
	pick.offset = pick.offset - arg1 * 3
	pick.Draw()
end)
pick.arrow:SetScript("OnClick", function()
	if pick.list:IsShown() or table.getn(History()) == 0 then
		pick.list:Hide()
		return
	end
	-- Opened on the run shown, near the middle.
	pick.offset = shown - math.floor(pick.SHOWN / 2)
	pick.Draw()
	pick.list:Show()
end)
pick.arrow:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Every run", 1, 0.82, 0)
	GameTooltip:AddLine("Pick one to go to it.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
pick.arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- At the bottom: Pin on the left, the history's name in the middle, Delete
-- on the right.
local FOOTER = 28

-- Survivor UI's small gold button: an icon and a word on a dark gold body in
-- a gold edge, lit under the mouse with a soft glow; kept lit while .lit is
-- set (a pinned run's Pin). Run History's Pin and Career, Career's Runs; in
-- red (tone), Delete. .tipTitle and .tipText: its tooltip.
local TONES = {
	gold = { edge = GOLD, body = { 0.32, 0.25, 0.04 }, text = { 1, 0.88, 0.5 } },
	red = { edge = { 1, 0.40, 0.34 }, body = { 0.34, 0.08, 0.07 }, text = { 1, 0.74, 0.70 } },
}
function SurvivorUI_GoldButton(parent, width, texture, coords, label, tone)
	tone = tone or TONES.gold
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(17)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.glow = button:CreateTexture(nil, "BACKGROUND")
	button.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
	button.glow:SetBlendMode("ADD")
	button.glow:SetVertexColor(tone.edge[1], tone.edge[2], tone.edge[3])
	button.glow:SetWidth(width + 40)
	button.glow:SetHeight(40)
	button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(texture)
	if coords then
		button.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	end
	button.icon:SetWidth(14)
	button.icon:SetHeight(14)
	button.icon:SetPoint("LEFT", button, "LEFT", 2, 0)
	button.text = Font(button, 9, WHITE)
	button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
	button.text:SetText(label)
	function button:Light(hot)
		local on = hot or self.lit
		local lift = on and 1.4 or 1
		self:SetBackdropColor(tone.body[1] * lift, tone.body[2] * lift, tone.body[3], 0.95)
		self:SetBackdropBorderColor(tone.edge[1], tone.edge[2], tone.edge[3], on and 1 or 0.6)
		if on then
			self.text:SetTextColor(1, 1, 1)
		else
			self.text:SetTextColor(tone.text[1], tone.text[2], tone.text[3])
		end
		self.glow:SetAlpha(hot and 0.45 or (self.lit and 0.2 or 0))
	end
	button:Light(false)
	button:SetScript("OnEnter", function()
		this:Light(true)
		if this.tipTitle then
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(this.tipTitle, 1, 0.82, 0)
			if this.tipText then
				GameTooltip:AddLine(this.tipText, 1, 1, 1, 1)
			end
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		this:Light(false)
		GameTooltip:Hide()
	end)
	return button
end

-- Pin: the run shown kept however many come after it, its tooltips too;
-- Delete still takes it. A push pin, lit while the run is pinned.
local pinButton = SurvivorUI_GoldButton(window, 64, "Interface\\AddOns\\SurvivorUI\\Art\\Pin", nil, "Pin")
pinButton:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 9)
pinButton.tipText = "A pinned run stays however many runs come after it, its tooltips too. Delete still takes it."
pinButton:SetScript("OnClick", function()
	local run = History()[shown]
	if run then
		run.pinned = (not run.pinned) or nil
		Draw()
	end
end)

-- Career (Career.lua): every run added up, in this window's place; a crown
-- (the lair marks' own).
local careerButton = SurvivorUI_GoldButton(window, 70, "Interface\\AddOns\\SurvivorUI\\Art\\LairMarks",
	{ 0.5, 0.75, 0, 0.5 }, "Career")
careerButton:SetPoint("LEFT", pinButton, "RIGHT", 6, 0)
careerButton.tipTitle = "Career"
careerButton.tipText = "Every run kept, added up by class and by map."
careerButton:SetScript("OnClick", function()
	if SurvivorUI_ShowCareer then
		SurvivorUI_ShowCareer(window)
	end
end)

local footer = Font(window, 9, MUTED, "", "CENTER")
footer:SetPoint("BOTTOM", window, "BOTTOM", 0, 12)

-- Delete, red (a trash can, our arrow): a list over it, "Delete this run"
-- (asked once) and "Clear all runs" (the word clear typed first), both in
-- the addon's one box (Confirm.lua). One table for it all: the file is near
-- Lua 5.0's 200 locals.
local del = {}
local deleteButton = SurvivorUI_GoldButton(window, 84, "Interface\\AddOns\\SurvivorUI\\Art\\Trash", nil, "Delete", TONES.red)
deleteButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 9)
deleteButton.icon:SetVertexColor(1, 0.66, 0.62)
deleteButton.drop = deleteButton:CreateTexture(nil, "ARTWORK")
deleteButton.drop:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\DropArrow")
deleteButton.drop:SetVertexColor(1, 0.6, 0.55)
deleteButton.drop:SetWidth(12)
deleteButton.drop:SetHeight(12)
deleteButton.drop:SetPoint("RIGHT", deleteButton, "RIGHT", -4, 0)
deleteButton.tipTitle = "Delete"
deleteButton.tipText = "This run, or every run kept."
deleteButton:SetScript("OnClick", function() del.Toggle() end)

-- The list, over the button.
del.menu = CreateFrame("Frame", nil, window)
del.menu:SetFrameStrata("FULLSCREEN_DIALOG")
del.menu:SetWidth(200)
del.menu:SetHeight(48)
del.menu:SetPoint("BOTTOMRIGHT", deleteButton, "TOPRIGHT", 0, 4)
del.menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
del.menu:SetBackdropColor(0.05, 0.03, 0.04, 0.98)
del.menu:SetBackdropBorderColor(1, 0.40, 0.34, 0.6)
del.menu:EnableMouse(true)
del.menu:Hide()

function del.Item(index, label, kind)
	local row = CreateFrame("Button", nil, del.menu)
	row:SetWidth(192)
	row:SetHeight(20)
	row:SetPoint("TOPLEFT", del.menu, "TOPLEFT", 4, -4 - (index - 1) * 20)
	row.wash = Flat(row, "BACKGROUND", WHITE, 0)
	row.wash:SetAllPoints(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\Trash")
	row.icon:SetVertexColor(1, 0.6, 0.55)
	row.icon:SetWidth(12)
	row.icon:SetHeight(12)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.text = Font(row, 10, WHITE)
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.text:SetText(label)
	row.note = Font(row, 8, MUTED, nil, "RIGHT")
	row.note:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.kind = kind
	row:SetScript("OnEnter", function() this.wash:SetVertexColor(1, 0.40, 0.34, 0.18) end)
	row:SetScript("OnLeave", function() this.wash:SetVertexColor(1, 1, 1, 0) end)
	row:SetScript("OnClick", function()
		del.menu:Hide()
		del.Ask(this.kind)
	end)
	return row
end
del.one = del.Item(1, "Delete this run", "one")
del.all = del.Item(2, "Clear all runs", "all")

function del.Toggle()
	local total = table.getn(History())
	if del.menu:IsShown() or total == 0 then
		del.menu:Hide()
		return
	end
	del.one.note:SetText("run "..shown)
	del.all.note:SetText(total..(total == 1 and " run" or " runs"))
	pick.list:Hide()
	del.menu:Show()
end

function del.Ask(kind)
	local history = History()
	if table.getn(history) == 0 then
		return
	end
	if kind == "all" then
		SurvivorUI_AskClearHistory()
		return
	end
	local run, index = history[shown], shown
	SurvivorUI_Confirm({
		title = "Delete this run?",
		text = pick.Line(run).."  |cff9a9aa0(run "..index..", "..(run.at and Ago(run.at) or (run.when or ""))..")|r"
			.."\n|cff9a9aa0It goes for good.|r",
		yes = "Delete",
		onYes = function()
			local list = History()
			if list[index] == run then
				table.remove(list, index)
			end
			Go(math.min(shown, table.getn(list)))
		end,
	})
end

-- Another run shown, or the window closed: the list and the box put away.
Disarm = function()
	del.menu:Hide()
end

-- The class's icon in an edge of its color, the map beside it, the hero
-- under the map.
-- The class's icon: the client's own (the character creation's), cut to a
-- square inside its round edge; in a frame of the class's color, lit from
-- above (lighter top and left, darker bottom and right) between a black
-- outline and a dark line; a glass shine over its top half; a soft glow of the
-- class's color behind it.
local ICON = 46
local CROP = 0.1                  -- of the icon cut away on each side
local classIcon = CreateFrame("Frame", nil, window)
classIcon:SetWidth(ICON)
classIcon:SetHeight(ICON)
classIcon:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + 2, -9)
classIcon.glow = classIcon:CreateTexture(nil, "BACKGROUND")
classIcon.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
classIcon.glow:SetBlendMode("ADD")
classIcon.glow:SetWidth(ICON * 2.3)
classIcon.glow:SetHeight(ICON * 2.3)
classIcon.glow:SetPoint("CENTER", classIcon, "CENTER", 0, 0)
classIcon.glow:SetAlpha(0.3)
classIcon.outline = Flat(classIcon, "BORDER", { 0, 0, 0 }, 1)
classIcon.outline:SetAllPoints(classIcon)
classIcon.ring = Flat(classIcon, "ARTWORK")
classIcon.ring:SetPoint("TOPLEFT", classIcon, "TOPLEFT", 1, -1)
classIcon.ring:SetPoint("BOTTOMRIGHT", classIcon, "BOTTOMRIGHT", -1, 1)
-- The frame's light and shade: a line on each side of it.
local function Bevel(point, horizontal)
	local line = Flat(classIcon, "OVERLAY")
	if horizontal then
		line:SetHeight(1)
		line:SetPoint(point.."LEFT", classIcon, point.."LEFT", 1, point == "TOP" and -1 or 1)
		line:SetPoint(point.."RIGHT", classIcon, point.."RIGHT", -1, point == "TOP" and -1 or 1)
	else
		line:SetWidth(1)
		line:SetPoint("TOP"..point, classIcon, "TOP"..point, point == "LEFT" and 1 or -1, -1)
		line:SetPoint("BOTTOM"..point, classIcon, "BOTTOM"..point, point == "LEFT" and 1 or -1, 1)
	end
	return line
end
classIcon.lights = { Bevel("TOP", true), Bevel("LEFT", false) }
classIcon.shades = { Bevel("BOTTOM", true), Bevel("RIGHT", false) }
-- The art itself, over the frame: a dark line round it, the shine on top.
classIcon.inner = CreateFrame("Frame", nil, classIcon)
classIcon.inner:SetPoint("TOPLEFT", classIcon, "TOPLEFT", 3, -3)
classIcon.inner:SetPoint("BOTTOMRIGHT", classIcon, "BOTTOMRIGHT", -3, 3)
classIcon.inner:SetFrameLevel(classIcon:GetFrameLevel() + 2)
classIcon.dark = Flat(classIcon.inner, "BACKGROUND", { 0, 0, 0 }, 1)
classIcon.dark:SetAllPoints(classIcon.inner)
classIcon.texture = classIcon.inner:CreateTexture(nil, "ARTWORK")
classIcon.texture:SetPoint("TOPLEFT", classIcon.inner, "TOPLEFT", 1, -1)
classIcon.texture:SetPoint("BOTTOMRIGHT", classIcon.inner, "BOTTOMRIGHT", -1, 1)
classIcon.shine = classIcon.inner:CreateTexture(nil, "OVERLAY")
classIcon.shine:SetTexture(FLAT)
classIcon.shine:SetBlendMode("ADD")
classIcon.shine:SetPoint("TOPLEFT", classIcon.inner, "TOPLEFT", 1, -1)
classIcon.shine:SetPoint("TOPRIGHT", classIcon.inner, "TOPRIGHT", -1, -1)
classIcon.shine:SetHeight(math.floor((ICON - 8) / 2))
classIcon.shine:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)

-- The class's colors on the frame and the glow.
local function PaintIcon(color)
	local light = Light(color)
	classIcon.ring:SetVertexColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8, 1)
	for _, line in pairs(classIcon.lights) do
		line:SetVertexColor(light[1], light[2], light[3], 1)
	end
	for _, line in pairs(classIcon.shades) do
		line:SetVertexColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 1)
	end
	classIcon.glow:SetVertexColor(color[1], color[2], color[3])
end

-- Beside it: the name, large in the class's color; "Lv. 29  Night Elf
-- Warrior" under it, lighter; the map last, by its own icon (Art\MapIcon: a
-- parchment map folded in three, a dotted trail to an X), its name in green
-- as the game writes a zone's name over the minimap.
local nameText = Font(window, 17, WHITE)
nameText:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", 10, 1)
local heroText = Font(window, 11, WHITE)
heroText:SetPoint("TOPLEFT", classIcon, "TOPRIGHT", 10, -20)

-- A co-op run's party (the game's 0.113, Party.lua): after the hero's line,
-- "Party of 3: Bleedin, Faye", each in the class's color; hover for each
-- hero's damage as the run ended. Nothing for a run alone.
local party = { text = Font(window, 11, MUTED) }
party.text:SetPoint("LEFT", heroText, "RIGHT", 0, 0)
party.tip = CreateFrame("Frame", nil, window)
party.tip:SetAllPoints(party.text)
party.tip:EnableMouse(true)

function party.Color(member)
	if SurvivorUI_ClassColor and member.class and member.class ~= "" then
		return SurvivorUI_ClassColor(member.class)
	end
	return 0.9, 0.9, 0.9
end

function party.Draw(run)
	party.run = run
	local members = run and run.party
	if not (members and table.getn(members) > 1) then
		party.text:SetText("")
		party.tip:Hide()
		return
	end
	local names = {}
	for _, member in pairs(members) do
		if not member.me then
			local r, g, b = party.Color(member)
			table.insert(names, pick.Hex({ r, g, b })..(member.name or "?").."|r")
		end
	end
	party.text:SetText("   |cff9a9aa2\194\183|r   |cff8fc3ffParty of "..table.getn(members)..":|r "..table.concat(names, ", "))
	party.tip:Show()
end

party.tip:SetScript("OnEnter", function()
	local members = party.run and party.run.party
	if not members then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText("A co-op run, a party of "..table.getn(members), 1, 0.82, 0)
	for _, member in pairs(members) do
		local r, g, b = party.Color(member)
		local right = member.dmg and (Short(member.dmg).."   "..math.floor(Num(member.share) * 100 + 0.5).."%") or ""
		GameTooltip:AddDoubleLine((member.name or "?")..(member.me and "  (you)" or ""), right, r, g, b, 1, 1, 1)
		if member.top then
			GameTooltip:AddLine("    Top spell: "..member.top, 0.65, 0.65, 0.7)
		end
	end
	GameTooltip:AddLine("Each hero's damage as the game's party meter had it when the run ended.", 0.6, 0.6, 0.65, 1)
	GameTooltip:Show()
end)
party.tip:SetScript("OnLeave", function() GameTooltip:Hide() end)
local zoneIcon = window:CreateTexture(nil, "ARTWORK")
zoneIcon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\MapIcon")
zoneIcon:SetWidth(16)
zoneIcon:SetHeight(16)
zoneIcon:SetPoint("BOTTOMLEFT", classIcon, "BOTTOMRIGHT", 8, -1)
local zoneText = Font(window, 10, { 0.40, 1.00, 0.42 })
zoneText:SetPoint("LEFT", zoneIcon, "RIGHT", 3, 0)
local whenText = Font(window, 9, MUTED, "")
whenText:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD - 2, -34)

-- The date's zone, under the mouse: where to set it.
local whenTip = CreateFrame("Frame", nil, window)
whenTip:SetAllPoints(whenText)
whenTip:EnableMouse(true)
whenTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	local hours = SurvivorUIDB and tonumber(SurvivorUIDB.timeZone)
	if hours then
		GameTooltip:SetText("Your time zone: "..(SurvivorUI_ZoneLabel and SurvivorUI_ZoneLabel(hours) or hours), 1, 1, 1)
	else
		GameTooltip:SetText("The game's clock is in UTC", 1, 1, 1)
		GameTooltip:AddLine("Set your time zone for your own clock's time.", 0.8, 0.8, 0.8, 1)
	end
	GameTooltip:AddLine("/sui opt, Run History: Your time zone.", 0.6, 0.6, 0.65, 1)
	GameTooltip:Show()
end)
whenTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- How the run ended, a word in a box beside the map, alive as Move UI's
-- button and the kill pace's orb (Pace.lua): filled, a light edge, a glow
-- breathing behind it, and a motion of its own. Victory green, its sparks
-- rising in green and gold, stars twinkling, a shine crossing it now and
-- then; Fallen red, embers falling slowly, a heavy breath; an endless run's
-- end purple (Endless, fallen or still going; Left in blue), sparks circling
-- it. A burst as a run is shown; under the mouse a brighter glow and how it
-- ended. Each holds its time. An endless run's two are its switch: the moment
-- shown, its badge lit with a line under it; the other dimmed, lit under the
-- mouse, a click showing its moment.
local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local SPARKS, STARS = 14, 5
local RESULTS = {
	victory = { word = "VICTORY", fill = { 0.12, 0.60, 0.24 }, edge = { 0.62, 1.00, 0.66 }, glow = { 0.35, 1.00, 0.45 },
		sparks = { { 0.45, 1.00, 0.50 }, { 1.00, 0.85, 0.30 } }, breath = 1.6, motion = "rise", every = 0.16, stars = 0.45, shine = 2.6 },
	dead    = { word = "FALLEN", fill = { 0.70, 0.10, 0.10 }, edge = { 1.00, 0.55, 0.48 }, glow = { 1.00, 0.22, 0.16 },
		sparks = { { 1.00, 0.42, 0.12 }, { 1.00, 0.20, 0.10 } }, breath = 3.2, motion = "fall", every = 0.42 },
	endless = { word = "ENDLESS", fill = { 0.48, 0.18, 0.80 }, edge = { 0.86, 0.66, 1.00 }, glow = { 0.68, 0.38, 1.00 },
		sparks = { { 0.80, 0.58, 1.00 }, { 0.55, 0.75, 1.00 } }, breath = 2.2, motion = "circle", every = 0.2, stars = 0.7 },
	-- Left from the menu: neither won nor lost, in steel blue, its sparks
	-- drifting out to the right, as one walking out.
	left    = { word = "LEFT", fill = { 0.15, 0.33, 0.56 }, edge = { 0.62, 0.82, 1.00 }, glow = { 0.32, 0.62, 1.00 },
		sparks = { { 0.62, 0.84, 1.00 }, { 0.86, 0.94, 1.00 } }, breath = 2.8, motion = "drift", every = 0.28 },
	going   = { word = "ENDLESS", fill = { 0.48, 0.18, 0.80 }, edge = { 0.86, 0.66, 1.00 }, glow = { 0.68, 0.38, 1.00 },
		sparks = { { 0.80, 0.58, 1.00 } }, breath = 2, motion = "circle", every = 0.3, stars = 0.9 },
	-- The Level Up! button's (LevelUp.lua, SurvivorUI_Sparkle): Victory's
	-- motion in gold.
	levelup = { word = "LEVEL UP!", fill = { 0.16, 0.12, 0.02 }, edge = { 1.00, 0.82, 0.00 }, glow = { 1.00, 0.85, 0.30 },
		sparks = { { 1.00, 0.85, 0.30 }, { 1.00, 0.95, 0.60 } }, breath = 1.6, motion = "rise", every = 0.16, stars = 0.45, shine = 2.6 },
}

local function Glowing(badge, art, layer)
	local texture = badge:CreateTexture(nil, layer)
	texture:SetTexture(ART..art)
	texture:SetBlendMode("ADD")
	texture:Hide()
	return texture
end

-- A spark off the box: rising from its top, falling from its bottom, or
-- setting off around it. It keeps the way it was born to move: the badge's
-- look can change under it (another run shown) while it is still in the air.
local function Spark(badge, look)
	for _, spark in pairs(badge.sparks) do
		if not spark.life then
			local width = badge:GetWidth()
			spark.life = 0
			spark.motion = look.motion
			spark.color = look.sparks[math.random(table.getn(look.sparks))]
			local size = 2.5 + math.random() * 2.5
			spark:SetWidth(size)
			spark:SetHeight(size)
			if look.motion == "circle" then
				spark.length = 1.2 + math.random() * 0.8
				spark.angle = math.random() * 6.283
				spark.turn = (math.random() < 0.5 and -1 or 1) * (1.4 + math.random())
			elseif look.motion == "drift" then
				-- From over the box, out past its right edge.
				spark.length = 1.0 + math.random() * 0.6
				spark.x = (math.random() - 0.3) * width * 0.6
				spark.y = (math.random() - 0.5) * 16
				spark.reach = width * 0.45 + 12 + math.random() * 14
			else
				spark.length = (look.motion == "fall" and 1.3 or 0.9) + math.random() * 0.7
				spark.x = (math.random() - 0.5) * (width - 6)
				spark.drift = (math.random() - 0.5) * 10
				spark.reach = (look.motion == "fall" and 10 or 16) + math.random() * 8
			end
			return
		end
	end
end

local function Star(badge)
	for _, star in pairs(badge.stars) do
		if not star.life then
			local width = badge:GetWidth()
			star.life = 0
			star.length = 0.5 + math.random() * 0.4
			star.x = (math.random() - 0.5) * (width + 10)
			star.y = (math.random() < 0.5 and -1 or 1) * (10 + math.random() * 6)
			star.size = 7 + math.random() * 5
			return
		end
	end
end

-- The shine, the sparks and the stars of a box, a frame's width wide: the
-- badge's, or an overlay's over another frame (SurvivorUI_Sparkle).
local function Twinkle(badge, look, elapsed, width)
	local glow = look.glow
	-- Victory's shine: a band of light across it now and then.
	if look.shine then
		badge.shineWait = badge.shineWait - elapsed
		if badge.shineWait <= 0 then
			badge.shineWait = look.shine * (0.8 + math.random() * 0.4)
			badge.shineAt = 0
		end
	end
	if badge.shineAt then
		badge.shineAt = badge.shineAt + elapsed
		local part = badge.shineAt / 0.6
		if part >= 1 then
			badge.shineAt = nil
			badge.shineLeft:Hide()
			badge.shineRight:Hide()
		else
			local x = 7 + (width - 14) * part
			badge.shineLeft:ClearAllPoints()
			badge.shineLeft:SetPoint("RIGHT", badge, "LEFT", x, 0)
			badge.shineRight:ClearAllPoints()
			badge.shineRight:SetPoint("LEFT", badge, "LEFT", x, 0)
			local alpha = math.sin(part * 3.1416)
			badge.shineLeft:SetAlpha(alpha)
			badge.shineRight:SetAlpha(alpha)
			badge.shineLeft:Show()
			badge.shineRight:Show()
		end
	end

	badge.sparkWait = badge.sparkWait - elapsed
	if badge.sparkWait <= 0 then
		Spark(badge, look)
		badge.sparkWait = look.every * (0.6 + math.random() * 0.8)
	end
	if look.stars then
		badge.starWait = badge.starWait - elapsed
		if badge.starWait <= 0 then
			Star(badge)
			badge.starWait = look.stars * (0.6 + math.random() * 0.8)
		end
	end
	for _, spark in pairs(badge.sparks) do
		if spark.life then
			spark.life = spark.life + elapsed
			local part = spark.life / spark.length
			if part >= 1 then
				spark.life = nil
				spark:Hide()
			else
				spark:ClearAllPoints()
				if spark.motion == "circle" then
					local angle = spark.angle + spark.turn * spark.life
					spark:SetPoint("CENTER", badge, "CENTER", math.cos(angle) * (width / 2 + 5), math.sin(angle) * 16)
				elseif spark.motion == "drift" then
					spark:SetPoint("CENTER", badge, "CENTER", spark.x + spark.reach * part, spark.y + 2 * math.sin(part * 6.283))
				elseif spark.motion == "fall" then
					spark:SetPoint("CENTER", badge, "BOTTOM", spark.x + spark.drift * part, -2 - spark.reach * part)
				else
					spark:SetPoint("CENTER", badge, "TOP", spark.x + spark.drift * part, 2 + spark.reach * part)
				end
				spark:SetVertexColor(spark.color[1], spark.color[2], spark.color[3])
				spark:SetAlpha(0.95 * (1 - part))
				spark:Show()
			end
		end
	end
	for _, star in pairs(badge.stars) do
		if star.life then
			star.life = star.life + elapsed
			local part = star.life / star.length
			if part >= 1 then
				star.life = nil
				star:Hide()
			else
				local size = star.size * (0.4 + 0.6 * math.sin(part * 3.1416))
				star:SetWidth(size)
				star:SetHeight(size)
				star:ClearAllPoints()
				star:SetPoint("CENTER", badge, "CENTER", star.x, star.y)
				star:SetVertexColor(0.75 + 0.25 * glow[1], 0.75 + 0.25 * glow[2], 0.75 + 0.25 * glow[3])
				star:SetAlpha(1 - part)
				star:Show()
			end
		end
	end
end

local function Animate()
	local badge, elapsed = this, arg1
	local look = badge.look
	if not look then
		return
	end
	badge.clock = badge.clock + elapsed
	badge:SetAlpha(badge.dim and (badge.hot and 0.85 or 0.45) or 1)
	local wave = (math.sin(badge.clock * 6.283 / look.breath) + 1) / 2
	-- The burst as the run is shown: the glow swells, then settles.
	local burst = 0
	if badge.burst then
		badge.burst = badge.burst + elapsed
		burst = math.max(0, 1 - badge.burst / 0.8)
		if burst == 0 then
			badge.burst = nil
		end
	end
	local width = badge:GetWidth()
	local glow, fill = look.glow, look.fill
	badge.glow:SetVertexColor(glow[1], glow[2], glow[3])
	badge.glow:SetAlpha(math.min(1, (badge.hot and 0.75 or 0.4) + 0.35 * wave + burst))
	badge.glow:SetWidth(width + 46 + 14 * wave + 60 * burst)
	badge.glow:SetHeight(50 + 10 * wave + 24 * burst)
	local lift = 0.82 + 0.18 * wave + (badge.hot and 0.18 or 0)
	badge:SetBackdropColor(math.min(1, fill[1] * lift), math.min(1, fill[2] * lift), math.min(1, fill[3] * lift), 1)
	Twinkle(badge, look, elapsed, width)
end

local function Badge(parent)
	local badge = CreateFrame("Frame", nil, parent or window)
	badge:SetHeight(24)
	badge:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	badge.glow = Glowing(badge, "PaceGlow", "BACKGROUND")
	badge.glow:SetPoint("CENTER", badge, "CENTER", 0, 0)
	badge.glow:Show()
	-- The shine: two halves of a band, fading out to each side.
	badge.shineLeft = badge:CreateTexture(nil, "ARTWORK")
	badge.shineLeft:SetTexture(FLAT)
	badge.shineLeft:SetBlendMode("ADD")
	badge.shineLeft:SetWidth(7)
	badge.shineLeft:SetHeight(20)
	badge.shineLeft:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 0.55)
	badge.shineLeft:Hide()
	badge.shineRight = badge:CreateTexture(nil, "ARTWORK")
	badge.shineRight:SetTexture(FLAT)
	badge.shineRight:SetBlendMode("ADD")
	badge.shineRight:SetWidth(7)
	badge.shineRight:SetHeight(20)
	badge.shineRight:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.55, 1, 1, 1, 0)
	badge.shineRight:Hide()
	-- The word and the time beside it, smaller and lighter, as one in the middle.
	badge.text = Font(badge, 13, WHITE)
	badge.text:SetPoint("LEFT", badge, "LEFT", 15, 0)
	badge.time = Font(badge, 10, { 0.92, 0.92, 0.92 })
	badge.time:SetPoint("LEFT", badge.text, "RIGHT", 7, 0)
	-- Under the moment shown: a line of its color.
	badge.mark = Flat(badge, "OVERLAY", WHITE, 1)
	badge.mark:SetHeight(2)
	badge.mark:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 8, -3)
	badge.mark:SetPoint("TOPRIGHT", badge, "BOTTOMRIGHT", -8, -3)
	badge.mark:Hide()
	badge.sparks, badge.stars = {}, {}
	for index = 1, SPARKS do
		badge.sparks[index] = Glowing(badge, "PaceDot", "OVERLAY")
	end
	for index = 1, STARS do
		badge.stars[index] = Glowing(badge, "PaceSpark", "OVERLAY")
	end
	badge.clock, badge.sparkWait, badge.starWait, badge.shineWait = 0, 0, 0.3, 0.8
	badge:SetScript("OnUpdate", Animate)
	badge:EnableMouse(true)
	badge:SetScript("OnEnter", function()
		this.hot = true
		if this.tipTitle then
			GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
			local edge = this.look and this.look.edge or WHITE
			GameTooltip:SetText(this.tipTitle, edge[1], edge[2], edge[3])
			if this.tipLine then
				GameTooltip:AddLine(this.tipLine, 1, 1, 1, 1)
			end
			GameTooltip:Show()
		end
	end)
	badge:SetScript("OnLeave", function()
		this.hot = nil
		GameTooltip:Hide()
	end)
	-- An endless run's: its moment, on a click.
	badge:SetScript("OnMouseUp", function()
		if this.view and view ~= this.view then
			view = this.view
			Draw()
			window.again = true
		end
	end)
	badge:Hide()
	return badge
end

local firstBadge = Badge()
local secondBadge = Badge()
secondBadge:SetPoint("LEFT", firstBadge, "RIGHT", 8, 0)

-- The boxes at the top in the middle, as the window's title: one centered,
-- two centered together.
local function PlaceBadges()
	local width = firstBadge:GetWidth()
	if secondBadge:IsShown() then
		width = width + 8 + secondBadge:GetWidth()
	end
	firstBadge:ClearAllPoints()
	firstBadge:SetPoint("TOPLEFT", window, "TOP", -math.floor(width / 2 + 0.5), -8)
end

-- A box set to a result; a new one (another run, or the window opened) with
-- its burst and a handful of sparks at once.
-- Of an endless run's two, moment is the one it shows ("victory" or "end").
local function SetBadge(badge, key, tipTitle, tipLine, time, moment)
	local look = RESULTS[key]
	if not look then
		badge:Hide()
		badge.look, badge.shown, badge.view, badge.dim = nil, nil, nil, nil
		return
	end
	badge.tipTitle, badge.tipLine = tipTitle, tipLine
	badge.text:SetText(look.word)
	badge.time:SetText(time or "")
	badge:SetWidth(badge.text:GetStringWidth() + (time and badge.time:GetStringWidth() + 7 or 0) + 30)
	badge:SetBackdropBorderColor(look.edge[1], look.edge[2], look.edge[3], 1)
	badge.view = moment
	badge.dim = moment and view ~= moment or nil
	badge.mark:SetVertexColor(look.edge[1], look.edge[2], look.edge[3], 1)
	if moment and not badge.dim then
		badge.mark:Show()
	else
		badge.mark:Hide()
	end
	local stamp = key..":"..tostring(tipLine)
	if badge.shown ~= stamp or not badge:IsVisible() then
		badge.shown = stamp
		badge.look = look
		badge.burst = 0
		for _ = 1, 5 do
			Spark(badge, look)
		end
	end
	badge.look = look
	badge:Show()
end

-- A result's box anywhere else, in its look and alive (the note by the
-- minimap, MinimapButton.lua): made for a parent, then set to a result and
-- its time; it takes no click, its parent does.
function SurvivorUI_ResultBadge(parent)
	local badge = Badge(parent)
	badge:EnableMouse(false)
	return badge
end

function SurvivorUI_SetResultBadge(badge, key, time)
	SetBadge(badge, key, nil, nil, time, nil)
end

-- A result's sparks, stars and shine over any frame (the Level Up! button,
-- LevelUp.lua): an overlay of the frame's size, blind to the mouse, alive on
-- its own; shown and hidden with its frame. nil for a look not known.
function SurvivorUI_Sparkle(frame, key)
	local look = RESULTS[key]
	if not look then
		return nil
	end
	local over = CreateFrame("Frame", nil, frame)
	over:SetAllPoints(frame)
	over:SetFrameLevel(frame:GetFrameLevel() + 2)
	over:EnableMouse(false)
	local band = math.max(8, (frame:GetHeight() or 24) - 10)
	over.shineLeft = over:CreateTexture(nil, "ARTWORK")
	over.shineLeft:SetTexture(FLAT)
	over.shineLeft:SetBlendMode("ADD")
	over.shineLeft:SetWidth(7)
	over.shineLeft:SetHeight(band)
	over.shineLeft:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 0.55)
	over.shineLeft:Hide()
	over.shineRight = over:CreateTexture(nil, "ARTWORK")
	over.shineRight:SetTexture(FLAT)
	over.shineRight:SetBlendMode("ADD")
	over.shineRight:SetWidth(7)
	over.shineRight:SetHeight(band)
	over.shineRight:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.55, 1, 1, 1, 0)
	over.shineRight:Hide()
	over.sparks, over.stars = {}, {}
	for index = 1, SPARKS do
		over.sparks[index] = Glowing(over, "PaceDot", "OVERLAY")
	end
	for index = 1, STARS do
		over.stars[index] = Glowing(over, "PaceSpark", "OVERLAY")
	end
	over.look, over.base = look, look
	over.sparkWait, over.starWait, over.shineWait = 0, 0.3, 0.8
	over:SetScript("OnUpdate", function()
		Twinkle(this, this.look, arg1, this:GetWidth() or 0)
	end)
	for _ = 1, 4 do
		Spark(over, look)
	end
	return over
end

-- An overlay's sparks and stars in a color of its own (the Level Up!
-- button's choice): the look copied with that color and a lighter one; the
-- sparks in the air keep the color they were born with.
function SurvivorUI_SparkleTint(over, r, g, b)
	local base = over.base or over.look
	local light = { r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5 }
	over.look = { word = base.word, fill = base.fill, edge = base.edge, glow = { r, g, b },
		sparks = { { r, g, b }, light }, breath = base.breath, motion = base.motion, every = base.every,
		stars = base.stars, shine = base.shine }
end

-- A line of the class's color between the header and the panels.
local rule = Themed("rule", Flat(window, "ARTWORK", GOLD, 0.3))
rule:SetHeight(1)
rule:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -62)
rule:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -62)

-- The modifiers under the badges: a chip each, its name and its share,
-- harder than normal in orange, easier in green, normal in grey (as the kill
-- pace orb's tooltip has them). Kept as words ("density 175%, health 1%", or
-- "normal"), read back here.
local MODS = { { "density", "Density" }, { "health", "Health" }, { "damage", "Damage" }, { "speed", "Speed" } }
local modChips = {}
for index = 1, 4 do
	local chip = CreateFrame("Frame", nil, window)
	chip:SetHeight(16)
	chip:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	chip.name = Font(chip, 8, MUTED)
	chip.name:SetPoint("LEFT", chip, "LEFT", 6, 0)
	chip.value = Font(chip, 9, WHITE)
	chip.value:SetPoint("LEFT", chip.name, "RIGHT", 4, 0)
	chip:EnableMouse(true)
	chip:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Modifiers", 1, 0.82, 0)
		GameTooltip:AddLine("The run's Run Options: enemy density, health, damage and speed.", 1, 1, 1, 1)
		GameTooltip:AddLine("Orange: harder than normal. Green: easier. Grey: normal.", 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	chip:Hide()
	modChips[index] = chip
end

local function DrawMods(label)
	for _, chip in pairs(modChips) do
		chip:Hide()
	end
	if not label then
		return
	end
	local values = {}
	for name, value in string.gfind(label, "(%a+) (%d+)%%") do
		values[name] = tonumber(value)
	end
	local width, count = 0, label == "normal" and 1 or 4
	for index = 1, count do
		local chip, value = modChips[index], values[MODS[index][1]] or 100
		local color = { 0.62, 0.62, 0.66 }
		if value > 100 then
			color = { 1.00, 0.58, 0.25 }
		elseif value < 100 then
			color = { 0.40, 0.95, 0.45 }
		end
		if count == 1 then
			chip.name:SetText("Modifiers")
			chip.value:SetText("normal")
		else
			chip.name:SetText(MODS[index][2])
			chip.value:SetText(value.."%")
		end
		chip.value:SetTextColor(color[1], color[2], color[3])
		chip:SetBackdropColor(color[1] * 0.14, color[2] * 0.14, color[3] * 0.14, 0.85)
		chip:SetBackdropBorderColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1)
		chip:SetWidth(chip.name:GetStringWidth() + chip.value:GetStringWidth() + 16)
		width = width + chip:GetWidth() + (index > 1 and 4 or 0)
	end
	-- In the middle, under the badges (and the line under the one shown).
	local x = -math.floor(width / 2 + 0.5)
	for index = 1, count do
		local chip = modChips[index]
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", window, "TOP", x, -40)
		chip:Show()
		x = x + chip:GetWidth() + 4
	end
end

local empty = Font(window, 11, MUTED, "", "CENTER")
empty:SetPoint("TOP", window, "TOP", 0, -100)
empty:SetWidth(WIDTH - 120)
empty:SetText("No run kept yet. Finish one, fallen or won, and it shows here: the run tracker as it ended, its numbers, build, damage, crits and loot.")

------------------------------------------------------------------------------
-- The panels: each in a frame of its own, a gold title in its corner as the
-- addon's panels have, the rows 6 in from its sides.

local function Box(name)
	local box = CreateFrame("Frame", nil, window)
	box:SetWidth(BOX)
	box:SetHeight(TOP)
	box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(1, 1, 1, 0.03)
	box:SetBackdropBorderColor(1, 1, 1, 0.1)
	Themed("box", box)
	if name then
		box.title = Themed("text", Font(box, 11, GOLD))
		box.title:SetPoint("TOPLEFT", box, "TOPLEFT", 7, -6)
		box.title:SetText(name)
	end
	box.note = Font(box, 10, WHITE, nil, "RIGHT")
	box.note:SetPoint("TOPRIGHT", box, "TOPRIGHT", -7, -7)
	-- A line for a panel with nothing to show.
	box.none = Font(box, 9, MUTED)
	box.none:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -TOP - 2)
	box.none:Hide()
	box.rows = {}
	box:Hide()
	return box
end

local function HideRows(box, from)
	for index = from, table.getn(box.rows) do
		local row = box.rows[index]
		row:Hide()
		if row.base then
			row.base:Hide()
		end
	end
end

local function Nothing(box, text)
	if text then
		box.none:SetText(text)
		box.none:Show()
		return TOP + 18
	end
	box.none:Hide()
	return 0
end

------------------------------------------------------------------------------
-- The run tracker, as it stood when the run ended (Tracker.lua's look): the
-- zone and how the run ended, the clock against the zone's length, the
-- timeline with a tick for every boss, each boss colored by where it stood
-- and the second it fell, the guardians and the elites, the level.

local STATE_COLORS = {
	due  = { 0.55, 0.55, 0.55 },
	next = { 1.00, 1.00, 1.00 },
	up   = { 1.00, 0.55, 0.25 },
	dead = { 0.30, 0.85, 0.35 },
}
local DIM = { 0.55, 0.55, 0.58 }
local ELITE_COLOR = { 1.00, 0.55, 0.15 }
local BACKING = { 0.12, 0.12, 0.15 }
local SPAWNED = { 0.30, 1.00, 0.40 }
local AWAKE = { 1.00, 0.55, 0.15 }

local tracker = Box()
tracker.zone = Font(tracker, 12, GOLD)
tracker.zone:SetHeight(14)
tracker.state = Font(tracker, 9, WHITE, nil, "RIGHT")
tracker.clock = Font(tracker, 18, WHITE, "THICKOUTLINE", "CENTER")
tracker.timeline = Flat(tracker, "BORDER", BACKING, 0.9)
tracker.timeline:SetWidth(INNER)
tracker.timeline:SetHeight(8)
tracker.gone = Flat(tracker, "ARTWORK")
tracker.gone:SetHeight(8)
tracker.guardTitle = Font(tracker, 9, DIM)
tracker.guardTitle:SetText("Guardians")
tracker.guardNote = Font(tracker, 9, WHITE, nil, "RIGHT")
tracker.eliteTitle = Font(tracker, 9, DIM)
tracker.eliteTitle:SetText("Elites")
tracker.eliteNote = Font(tracker, 9, WHITE, nil, "RIGHT")
tracker.level = Font(tracker, 9, WHITE, nil, "CENTER")
tracker.xpBack = Flat(tracker, "BORDER", BACKING, 0.9)
tracker.xpBack:SetWidth(INNER)
tracker.xpBack:SetHeight(5)
tracker.xpFill = Flat(tracker, "ARTWORK", { 0.58, 0.30, 0.85 }, 1)
tracker.xpFill:SetHeight(5)
tracker.ticks, tracker.segments, tracker.slots, tracker.guardMarks = {}, {}, {}, {}
tracker:EnableMouse(true)
tracker:SetScript("OnEnter", function() ShowKept(this, this.tip, 1) end)
tracker:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Pieces made as they are needed: a boss's tick (its countdown over it), a
-- boss's line, a lair's stretch of the guardians' bar, an elite's bar.
local function Tick(index)
	local tick = tracker.ticks[index]
	if not tick then
		tick = CreateFrame("Frame", nil, tracker)
		tick:SetHeight(14)
		tick.mark = Flat(tick, "OVERLAY")
		tick.mark:SetAllPoints(tick)
		tick.label = Font(tick, 8, WHITE, nil, "CENTER")
		tracker.ticks[index] = tick
	end
	return tick
end

local function BossLine(index)
	local line = tracker.rows[index]
	if not line then
		line = CreateFrame("Frame", nil, tracker)
		line:SetWidth(INNER)
		line:SetHeight(13)
		line.name = Font(line, 9, WHITE)
		line.name:SetPoint("LEFT", line, "LEFT", 0, 0)
		line.name:SetHeight(13)
		line.time = Font(line, 9, WHITE, nil, "RIGHT")
		line.time:SetPoint("RIGHT", line, "RIGHT", 0, 0)
		tracker.rows[index] = line
	end
	return line
end

local function Stretch(list, index, height)
	local piece = list[index]
	if not piece then
		piece = CreateFrame("Frame", nil, tracker)
		piece:SetHeight(height)
		piece.back = Flat(piece, "BACKGROUND", BACKING, 0.9)
		piece.back:SetAllPoints(piece)
		piece.fill = Flat(piece, "BORDER")
		piece.fill:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, 0)
		piece.fill:SetHeight(height)
		piece.text = Font(piece, 8, WHITE, nil, "CENTER")
		piece.text:SetPoint("CENTER", piece, "CENTER", 0, 0)
		list[index] = piece
	end
	return piece
end

local function HideAll(list, from)
	for index = from, table.getn(list) do
		list[index]:Hide()
	end
end

-- Lays the copy out, top to bottom; the panel's height comes back.
local function DrawTracker(shot, result)
	tracker.tip = shot.tip
	local x, y = 6, -6
	local parts = {}
	if result == "left" then
		-- Left from the menu: the game passes through its fall on the way out,
		-- so the tracker was kept "dead"; the run's result says it.
		local edge = RESULTS.left.edge
		table.insert(parts, string.format("|cff%02x%02x%02xLeft|r",
			math.floor(edge[1] * 255), math.floor(edge[2] * 255), math.floor(edge[3] * 255)))
	elseif shot.phase == "victory" then
		table.insert(parts, "|cff4dd94dVictory|r")
	elseif shot.phase == "dead" then
		table.insert(parts, "|cffff4040Fallen|r")
	elseif shot.endless then
		table.insert(parts, "|cffd080ffEndless|r")
	end
	local lives = Num(shot.lives)
	if lives > 0 then
		table.insert(parts, "|cffff8080"..lives..(lives == 1 and " life" or " lives").." left|r")
	end
	tracker.state:SetText(table.concat(parts, "  "))
	tracker.state:ClearAllPoints()
	tracker.state:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -6, y - 2)
	tracker.zone:SetText(shot.zone or "")
	tracker.zone:SetWidth(INNER - tracker.state:GetStringWidth() - 10)
	At(tracker.zone, tracker, x, y)
	y = y - 15

	-- The clock against the zone's length; in endless mode, alone.
	local seconds, length = Num(shot.seconds), Num(shot.length)
	if shot.endless or length <= 0 then
		tracker.clock:SetText(Clock(seconds))
	else
		tracker.clock:SetText(Clock(seconds).." |cff8a8a8a/|r |cffb0b0b0"..Clock(length).."|r")
	end
	tracker.clock:ClearAllPoints()
	tracker.clock:SetPoint("TOP", tracker, "TOP", 0, y - 1)
	-- Room over the timeline for the coming bosses' countdowns.
	y = y - 25 - 10

	-- The timeline: green up to the end, a tick for every boss, white until
	-- it fell, then green; over each boss still to come, the time it had left.
	At(tracker.timeline, tracker, x, y)
	tracker.gone:SetWidth(math.max(1, INNER * (length > 0 and math.min(1, seconds / length) or 1)))
	if shot.endless then
		tracker.gone:SetVertexColor(0.70, 0.40, 1.00, 1)
	else
		tracker.gone:SetVertexColor(0.30, 0.80, 0.35, 1)
	end
	At(tracker.gone, tracker, x, y)
	local bosses = shot.bosses or {}
	local total = table.getn(bosses)
	local nextIndex
	for index = 1, total do
		if not nextIndex and bosses[index].state == "due" then
			nextIndex = index
		end
	end
	for index = 1, total do
		local boss = bosses[index]
		local at = Num(boss.at)
		local spot = length > 0 and INNER * math.min(1, at / length) or INNER
		local tick = Tick(index)
		tick:SetWidth(boss.final and 5 or 3)
		local color = boss.state == "dead" and STATE_COLORS.dead or STATE_COLORS.next
		tick.mark:SetVertexColor(color[1], color[2], color[3], 1)
		tick:ClearAllPoints()
		tick:SetPoint("CENTER", tracker, "TOPLEFT", x + spot, y - 4)
		tick:Show()
		if boss.state == "due" and at > seconds then
			tick.label:SetText(Clock(at - seconds))
			if index == nextIndex then
				tick.label:SetTextColor(1, 0.55, 0.15)
			else
				tick.label:SetTextColor(1, 0.82, 0.2)
			end
			local half = tick.label:GetStringWidth() / 2 + 1
			tick.label:ClearAllPoints()
			tick.label:SetPoint("BOTTOM", tracker, "TOPLEFT", x + math.max(half, math.min(INNER - half, spot)), y + 4)
			tick.label:Show()
		else
			tick.label:Hide()
		end
	end
	HideAll(tracker.ticks, total + 1)
	y = y - 15

	-- A line a boss: grey to come, white the next, orange alive, green slain
	-- with the second it came and the second it fell.
	for index = 1, total do
		local boss = bosses[index]
		local at = Num(boss.at)
		local line = BossLine(index)
		local color, timeColor, timeText
		if boss.state == "dead" then
			color = STATE_COLORS.dead
			timeColor = color
			timeText = boss.fell and ("|cff8a8a8a"..Clock(at).."  /|r  "..Clock(boss.fell)) or Clock(at)
		elseif boss.state == "up" then
			color, timeColor = STATE_COLORS.up, WHITE
			timeText = (boss.hp and ("|cffff8c40"..math.floor(boss.hp * 100 + 0.5).."%|r   ") or "")..Clock(at)
		elseif index == nextIndex then
			color = STATE_COLORS.next
			timeColor = color
			timeText = (at > seconds and ("|cffffd24din "..Clock(at - seconds).."|r   ") or "")..Clock(at)
		else
			color = STATE_COLORS.due
			timeColor = color
			timeText = Clock(at)
		end
		line.name:SetText(boss.name or "?")
		line.name:SetTextColor(color[1], color[2], color[3])
		line.time:SetText(timeText)
		line.time:SetTextColor(timeColor[1], timeColor[2], timeColor[3])
		line.name:SetWidth(INNER - line.time:GetStringWidth() - 8)
		At(line, tracker, x, y)
		y = y - 13
	end
	-- The empty lines keep their room, as in the tracker.
	y = y - math.max(0, Num(shot.slots) - total) * 13
	-- Endless mode: when the next boss was to come.
	local used = total
	if shot.nextBoss then
		used = used + 1
		local line = BossLine(used)
		line.name:SetText(shot.nextBoss.name or "Next boss")
		line.name:SetTextColor(1, 1, 1)
		line.time:SetText("|cffffd24din "..Clock(shot.nextBoss.left).."|r")
		line.name:SetWidth(INNER - line.time:GetStringWidth() - 8)
		At(line, tracker, x, y)
	end
	HideAll(tracker.rows, used + 1)
	y = y - 13

	-- The guardians, as they stood in the tracker: their count, or a stretch
	-- of the bar a lair, the 8:00 achievement over it.
	local guard = shot.guardians
	local lairs = guard and not guard.count and guard.lairs or {}
	local marked = 0
	if guard then
		At(tracker.guardTitle, tracker, x, y - 6)
		tracker.guardNote:ClearAllPoints()
		tracker.guardNote:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -6, y - 6)
		tracker.guardNote:Show()
		if guard.count then
			local color = Num(guard.awake) > 0 and AWAKE or (Num(guard.alive) > 0 and SPAWNED or DIM)
			tracker.guardNote:SetText(Num(guard.alive).." / "..table.getn(guard.lairs or {}).." alive")
			tracker.guardNote:SetTextColor(color[1], color[2], color[3])
			-- The lairs' marks after the title, as the count showed them.
			for index = 1, table.getn(guard.lairs or {}) do
				local lair = guard.lairs[index]
				if lair.mark and SurvivorUI_SetLairMark then
					marked = marked + 1
					local texture = tracker.guardMarks[marked]
					if not texture then
						texture = tracker:CreateTexture(nil, "ARTWORK")
						texture:SetWidth(11)
						texture:SetHeight(11)
						tracker.guardMarks[marked] = texture
					end
					texture:ClearAllPoints()
					texture:SetPoint("LEFT", tracker.guardTitle, "RIGHT", 4 + (marked - 1) * 12, 0)
					SurvivorUI_SetLairMark(texture, lair.mark, lair.empty)
				end
			end
			y = y - 6 - 12
		else
			local goal = guard.goalColor or DIM
			tracker.guardNote:SetText(guard.goal or "")
			tracker.guardNote:SetTextColor(goal[1], goal[2], goal[3])
			y = y - 6 - 12
			local lairCount = table.getn(lairs)
			local each = (INNER - 3 * (lairCount - 1)) / math.max(lairCount, 1)
			for index = 1, lairCount do
				local lair = lairs[index]
				local piece = Stretch(tracker.segments, index, 9)
				piece:SetWidth(each)
				local color = lair.color or SPAWNED
				piece.fill:SetWidth(math.max(1, each * Num(lair.share)))
				piece.fill:SetVertexColor(color[1], color[2], color[3], 0.9)
				-- Its lair's mark at its left end; the words in what is left.
				if not piece.mark then
					piece.mark = piece:CreateTexture(nil, "OVERLAY")
					piece.mark:SetWidth(13)
					piece.mark:SetHeight(13)
					piece.mark:SetPoint("LEFT", piece, "LEFT", -1, 0)
					-- The lair the game's flag pointed at, its mark glowing.
					piece.flagGlow = piece:CreateTexture(nil, "ARTWORK")
					piece.flagGlow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
					piece.flagGlow:SetBlendMode("ADD")
					piece.flagGlow:SetVertexColor(1, 0.82, 0.2, 0.8)
					piece.flagGlow:SetWidth(32)
					piece.flagGlow:SetHeight(32)
					piece.flagGlow:SetPoint("CENTER", piece.mark, "CENTER", 0, 0)
				end
				if lair.mark and SurvivorUI_SetLairMark then
					SurvivorUI_SetLairMark(piece.mark, lair.mark, lair.empty)
					piece.text:SetPoint("CENTER", piece, "CENTER", 6, 0)
				else
					piece.mark:Hide()
					piece.text:SetPoint("CENTER", piece, "CENTER", 0, 0)
				end
				if lair.flag and lair.mark then
					piece.flagGlow:Show()
				else
					piece.flagGlow:Hide()
				end
				piece.text:SetText(lair.text or "")
				At(piece, tracker, x + (index - 1) * (each + 3), y)
			end
			y = y - 9
		end
	else
		tracker.guardTitle:Hide()
		tracker.guardNote:Hide()
	end
	HideAll(tracker.segments, table.getn(lairs) + 1)
	HideAll(tracker.guardMarks, marked + 1)

	-- The elites alive as the run ended: a small bar each, bright once hurt.
	local elites = shot.elites
	local slots = elites and Num(elites.slots) or 0
	if elites then
		At(tracker.eliteTitle, tracker, x, y - 6)
		local alive, hurt = Num(elites.total), Num(elites.hurt)
		if alive == 0 then
			tracker.eliteNote:SetText("|cff8a8a8anone|r")
		elseif hurt > 0 then
			tracker.eliteNote:SetText("|cffffffff"..alive.." alive|r  ·  |cffff8c26"..hurt.." fighting|r")
		else
			tracker.eliteNote:SetText("|cffffffff"..alive.." alive|r")
		end
		tracker.eliteNote:ClearAllPoints()
		tracker.eliteNote:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -6, y - 6)
		tracker.eliteNote:Show()
		y = y - 6 - 12
		local each = (INNER - 2 * (slots - 1)) / math.max(slots, 1)
		for index = 1, slots do
			local piece = Stretch(tracker.slots, index, 7)
			piece:SetWidth(each)
			local share = elites.shares and elites.shares[index]
			if share then
				piece.fill:SetWidth(math.max(1, each * share))
				piece.fill:SetVertexColor(ELITE_COLOR[1], ELITE_COLOR[2], ELITE_COLOR[3], share < 1 and 0.9 or 0.35)
				piece.fill:Show()
			else
				piece.fill:Hide()
			end
			At(piece, tracker, x + (index - 1) * (each + 2), y)
		end
		y = y - 7
	else
		tracker.eliteTitle:Hide()
		tracker.eliteNote:Hide()
	end
	HideAll(tracker.slots, slots + 1)

	-- The level and how far to the next, at the bottom.
	if shot.level then
		local text = "|cffbf8cffLv. "..Num(shot.level).."|r"
		if Num(shot.stored) > 0 then
			text = text.." |cffffd100+"..Num(shot.stored).."|r"
		end
		tracker.level:SetText(text)
		tracker.level:ClearAllPoints()
		tracker.level:SetPoint("TOP", tracker, "TOP", 0, y - 6)
		tracker.level:Show()
		y = y - 6 - 13
		At(tracker.xpBack, tracker, x, y)
		tracker.xpFill:SetWidth(math.max(1, INNER * math.min(1, Num(shot.xp))))
		At(tracker.xpFill, tracker, x, y)
		y = y - 6
	else
		tracker.level:Hide()
		tracker.xpBack:Hide()
		tracker.xpFill:Hide()
	end
	return -y + 6
end

------------------------------------------------------------------------------
-- The run's numbers, in This Run's look (RunPanel.lua): each row a label and
-- a value in its color, on a faint wash of it, over a rule of it.

local runBox = Box("The Run")

local function RunRow(index)
	local row = runBox.rows[index]
	if not row then
		row = CreateFrame("Frame", nil, runBox)
		row:SetWidth(INNER)
		row:SetHeight(ROW)
		row.wash = Flat(row, "BACKGROUND")
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.rule = Flat(row, "BORDER")
		row.rule:SetHeight(1)
		row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.label = Font(row, 10, WHITE)
		row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
		row.label:SetWidth(INNER - 66)
		row.label:SetHeight(11)
		row.value = Font(row, 11, WHITE, nil, "RIGHT")
		row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		-- In an endless run's end: what the endless part added.
		row.more = Font(row, 8, { 0.62, 0.62, 0.66 }, nil, "RIGHT")
		row.more:SetPoint("RIGHT", row.value, "LEFT", -6, -1)
		-- A personal best: "NEW BEST" in gold after its name.
		row.best = Font(row, 7, GOLD)
		row.best:SetText("NEW BEST")
		row.best:Hide()
		row:EnableMouse(true)
		row:SetScript("OnEnter", function() ShowKept(this, this.tip, 1) end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		runBox.rows[index] = row
	end
	return row
end

-- base: the victory, for an endless run's end, whose numbers then say what
-- the endless part added.
local function DrawRun(run, base)
	local seconds = Num(run.time)
	local function Plain(value)
		return tostring(value)
	end
	local function More(key, write)
		local added = base and Num(run[key]) - Num(base[key]) or 0
		return added > 0 and "+"..write(added) or nil
	end
	local addedDealt = base and Dealt(run) - Dealt(base) or 0
	-- The damage's row tells the end screen's count too, with the overkill:
	-- first under its title, in red, and what it is.
	local dealtTip = run.rowTips and run.rowTips.dealt
	if run.meterTotal and Num(run.dealt) > Dealt(run) + 0.5 then
		local red = { 1, 0.35, 0.35 }
		local tip = { (dealtTip and dealtTip[1]) or { l = "Damage dealt", lc = { 1, 0.76, 0.08 } } }
		table.insert(tip, { l = "Damage with overkill", r = Short(run.dealt), lc = red, rc = red })
		table.insert(tip, { l = "As the game's end of the run shows it. "..Short(Num(run.dealt) - Dealt(run))
			.." of it is overkill: blows past what each enemy had left.", lc = MUTED })
		table.insert(tip, { l = " " })
		for index = 2, table.getn(dealtTip or {}) do
			table.insert(tip, dealtTip[index])
		end
		dealtTip = tip
	end
	-- Label, value, color, what the endless part added, the row's key (for
	-- its tooltip, as This Run's).
	local lines = {
		{ "Survived",        Clock(seconds),             { 1.00, 0.82, 0.00 }, More("time", Clock), "time" },
		{ "Level",           Num(run.level),             { 0.40, 1.00, 0.40 }, More("level", Plain), "level" },
		{ "Kills",           Num(run.kills),             { 0.92, 0.92, 0.92 }, More("kills", Plain), "kills" },
		{ "Kills / min",     seconds > 0 and string.format("%.0f", Num(run.kills) / seconds * 60) or "-", { 0.78, 0.80, 0.88 }, nil, "kpm" },
		{ "Elites slain",    Num(run.elites),            { 1.00, 0.55, 0.10 }, More("elites", Plain), "elites" },
		{ "Guardians slain", Num(run.guardians),         { 0.20, 0.75, 0.95 }, More("guardians", Plain), "guardians" },
		{ "Bosses slain",    Num(run.bosses),            { 0.72, 0.32, 1.00 }, More("bosses", Plain), "bosses" },
		{ "Damage dealt",    Short(Dealt(run)),          { 1.00, 0.76, 0.08 }, addedDealt > 0 and "+"..Short(addedDealt) or nil, "dealt", dealtTip },
		{ "Damage / sec",    seconds > 0 and Short(Dealt(run) / seconds) or "-", { 0.95, 0.60, 0.20 }, nil, "dps" },
		{ "Damage taken",    Short(run.taken),           { 0.90, 0.25, 0.25 }, More("taken", Short), "taken" },
		{ "Gold earned",     Short(run.gold),            { 1.00, 0.86, 0.35 }, More("gold", Short), "gold" },
		{ "Caches opened",   Num(run.caches),            { 0.55, 0.85, 0.55 }, More("caches", Plain), "caches" },
	}
	-- The magnets taken, from the game's own end (0.102 on).
	if run.magnets then
		table.insert(lines, { "Magnets taken", Num(run.magnets), { 0.55, 0.70, 1.00 }, More("magnets", Plain) })
	end
	-- Personal bests: each number against every earlier run of the same class
	-- on the same map (an endless one by its end), "NEW BEST" where it beat
	-- them all. The rates only between runs of 2 minutes or more, so a short
	-- one does not win them by its few seconds; the damage taken not at all.
	local best = {}
	local function Value(x, key)
		local time = Num(x.time)
		if key == "kpm" then
			return time >= 120 and Num(x.kills) / time * 60 or nil
		elseif key == "dps" then
			return time >= 120 and Dealt(x) / time or nil
		elseif key == "dealt" then
			return Dealt(x)
		end
		return Num(x[key])
	end
	local earlier = {}
	for _, other in pairs(History()) do
		if other.classKey == run.classKey and other.zone == run.zone and Num(other.at) < Num(run.at)
			and other ~= base and other.endless ~= run then
			table.insert(earlier, other.endless or other)
		end
	end
	if table.getn(earlier) > 0 then
		for _, key in pairs({ "time", "level", "kills", "kpm", "elites", "guardians", "bosses", "dealt", "dps", "gold", "caches" }) do
			local mine = Value(run, key)
			if mine and mine > 0 then
				local beaten = true
				for _, other in pairs(earlier) do
					local theirs = Value(other, key)
					if theirs and theirs >= mine then
						beaten = false
					end
				end
				best[key] = beaten or nil
			end
		end
	end

	-- The talent experience: the victory's and the end's together, the end's
	-- beside it.
	local talent = Num(run.talentXp) + (base and Num(base.talentXp) or 0)
	if talent > 0 then
		table.insert(lines, { "Talent experience", "+"..talent, { 0.45, 0.80, 1.00 },
			base and run.talentXp and ("+"..Num(run.talentXp)) or nil })
	end
	for index = 1, table.getn(lines) do
		local line = lines[index]
		local color = line[3]
		local row = RunRow(index)
		row.label:SetText(line[1])
		row.value:SetText(line[2])
		row.more:SetText(line[4] or "")
		row.tip = line[6] or (line[5] and run.rowTips and run.rowTips[line[5]]) or nil
		row.label:SetTextColor(color[1], color[2], color[3])
		row.value:SetTextColor(color[1], color[2], color[3])
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
		if line[5] and best[line[5]] then
			row.rule:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
			row.best:ClearAllPoints()
			row.best:SetPoint("LEFT", row.label, "LEFT", math.min(row.label:GetStringWidth(), INNER - 66) + 6, 0)
			row.best:Show()
		else
			row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
			row.best:Hide()
		end
		At(row, runBox, 6, -TOP - (index - 1) * ROW)
	end
	HideRows(runBox, table.getn(lines) + 1)
	return TOP + table.getn(lines) * ROW + 6
end

------------------------------------------------------------------------------
-- The build, in the build list's look (BuildList.lua): every slot, the spells
-- from the highest rank down, each filled with its color in a border of it,
-- the first a point larger; the empty slots faint; the racial apart. Its
-- columns as the list showed them: the range, the cooldown, the rank. Under
-- it the jewelry, each slot filled with its piece's quality color and what
-- the piece gives, in short.

local HEAD = 13                   -- the columns' names, under the title
local BUILD_TOP = 21 + HEAD       -- the first spell
local GEAR_TOP = BUILD_TOP + (SLOTS + 1) * ROW + 6
local GEAR_ROW = 17
local COLUMN_WIDTH = { rank = 24, cd = 30, range = 34 }
local EMPTY = { 0.45, 0.45, 0.45 }

local buildBox = Box("Build")
buildBox.head = CreateFrame("Frame", nil, buildBox)
buildBox.head:SetPoint("TOPLEFT", buildBox, "TOPLEFT", 6, -21)
buildBox.head:SetWidth(INNER)
buildBox.head:SetHeight(HEAD)
buildBox.labels = {}
for _, key in pairs({ "range", "cd", "rank" }) do
	local label = Font(buildBox.head, 8, { 0.62, 0.62, 0.66 }, nil, "CENTER")
	label:SetText(key == "range" and "Range" or (key == "cd" and "CD" or "Rank"))
	buildBox.labels[key] = label
end
-- The dividers, over the rows, from the header's top to the racial's bottom.
buildBox.over = CreateFrame("Frame", nil, buildBox)
buildBox.over:SetAllPoints(buildBox)
buildBox.over:SetFrameLevel(buildBox:GetFrameLevel() + 6)
buildBox.dividers = {}
for _, key in pairs({ "range", "cd", "rank" }) do
	local line = Flat(buildBox.over, "OVERLAY", WHITE, 0.14)
	line:SetWidth(1)
	line:SetHeight(HEAD + (SLOTS + 1) * ROW - 1)
	buildBox.dividers[key] = line
end
buildBox.gearTitle = Themed("text", Font(buildBox, 9, GOLD))
buildBox.gearTitle:SetPoint("TOPLEFT", buildBox, "TOPLEFT", 7, -GEAR_TOP)
buildBox.gearTitle:SetText("Jewelry")
buildBox.gear = {}

-- The columns shown, laid out from the right edge: { [key] = { right, width,
-- divider } }, and the room left for the names.
local function BuildColumns(showRange, showCooldown)
	local columns, order = {}, { "rank" }
	if showCooldown then
		table.insert(order, "cd")
	end
	if showRange then
		table.insert(order, "range")
	end
	local right = 2
	for index = 1, table.getn(order) do
		local width = COLUMN_WIDTH[order[index]]
		columns[order[index]] = { right = right, width = width, divider = right + width + 1 }
		right = right + width + 3
	end
	return columns, INNER - right - ROW - 1
end

local function PlaceColumn(text, column)
	text:ClearAllPoints()
	if column then
		text:SetPoint("RIGHT", text:GetParent(), "RIGHT", -column.right, 0)
		text:SetWidth(column.width)
		text:Show()
	else
		text:Hide()
	end
end

local function SpellRow(index)
	local row = buildBox.rows[index]
	if not row then
		row = CreateFrame("Frame", nil, buildBox)
		row:SetWidth(INNER)
		row:SetHeight(ROW)
		-- A dark base under the color, drawn by the panel under the row.
		row.base = Flat(buildBox, "ARTWORK", { 0.05, 0.05, 0.07 }, 0.92)
		row.base:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.base:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.wash = Flat(row, "BACKGROUND")
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.rule = Flat(row, "BORDER")
		row.rule:SetHeight(1)
		row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.edges = Edges(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(ROW - 4)
		row.icon:SetHeight(ROW - 4)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = Font(row, 9, WHITE)
		row.name:SetPoint("LEFT", row, "LEFT", ROW + 2, 0)
		row.name:SetHeight(12)
		row.range = Font(row, 8, WHITE, nil, "CENTER")
		row.cd = Font(row, 8, WHITE, nil, "CENTER")
		row.rank = Font(row, 10, WHITE, nil, "CENTER")
		CardRow(row, 2)
		buildBox.rows[index] = row
	end
	return row
end

-- The top spell's name and rank a point larger.
local function Bold(row, bold)
	if row.bold ~= bold then
		row.bold = bold
		row.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
		row.rank:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
	end
end

-- Filled with the color, the text light over it, in a border of it; or the
-- racial and an empty slot, a faint wash and the text in the color.
local function PaintSpell(row, color, filled, alpha)
	if filled then
		row.base:Show()
		row.name:SetTextColor(1, 1, 1)
		row.rank:SetTextColor(1, 1, 1)
		row.range:SetTextColor(0.9, 0.9, 0.9)
		row.cd:SetTextColor(0.9, 0.9, 0.9)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
		Tint(row.edges, color, 0.6)
	else
		row.base:Hide()
		row.name:SetTextColor(color[1], color[2], color[3])
		row.rank:SetTextColor(color[1], color[2], color[3])
		row.range:SetTextColor(0.6, 0.6, 0.6)
		row.cd:SetTextColor(0.6, 0.6, 0.6)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.07 * alpha)
		Tint(row.edges, color, 0)
	end
	row.rule:SetVertexColor(color[1], color[2], color[3], 0.28 * alpha)
end

local function GearLine(index)
	local line = buildBox.gear[index]
	if not line then
		line = CreateFrame("Frame", nil, buildBox)
		line:SetWidth(INNER)
		line:SetHeight(GEAR_ROW - 1)
		line.wash = Flat(line, "BACKGROUND")
		line.wash:SetAllPoints(line)
		line.edges = Edges(line, "BORDER")
		line.label = Font(line, 9, WHITE)
		line.label:SetPoint("LEFT", line, "LEFT", 4, 0)
		line.tags = Font(line, 9, WHITE, nil, "RIGHT")
		line.tags:SetPoint("RIGHT", line, "RIGHT", -4, 0)
		-- Its piece's tooltip, from the link kept.
		line:EnableMouse(true)
		line:SetScript("OnEnter", function()
			if ShowKept(this, this.tip, 2) then
				return
			end
			if this.item then
				Aside(this, 2)
				GameTooltip:SetHyperlink(this.item)
				GameTooltip:Show()
			elseif this.itemName then
				local color = this.color or WHITE
				Aside(this, 2)
				GameTooltip:SetText(this.itemName, color[1], color[2], color[3])
				GameTooltip:Show()
			end
		end)
		line:SetScript("OnLeave", function() GameTooltip:Hide() end)
		buildBox.gear[index] = line
	end
	return line
end

-- What a piece gives beside its slot, a point or two smaller when it would
-- run into the slot's name (a legendary amulet gives much).
local function FitTags(line, text)
	line.tags:SetText(text)
	local room = INNER - 8 - line.label:GetStringWidth() - 10
	for size = 9, 6, -1 do
		line.tags:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
		if line.tags:GetStringWidth() <= room then
			break
		end
	end
end

local GEAR_SLOT_NAMES = { "Neck", "Ring", "Ring", "Trinket", "Trinket" }

-- The jewelry lines: as kept, or from the first runs kept (v3.0.7's first
-- builds), the pieces' names by their slots.
local function GearLines(run)
	if run.gear then
		return run.gear
	end
	local lines = {}
	for _, piece in pairs(run.jewelry or {}) do
		table.insert(lines, { label = piece.slot, tags = piece.name, color = HexColor(piece.color), name = piece.name })
	end
	return lines
end

local function DrawBuild(run)
	local spells, racial = {}, nil
	local showRange, showCooldown = false, false
	for _, spell in pairs(run.build or {}) do
		if spell.racial then
			racial = spell
		else
			table.insert(spells, spell)
		end
		showRange = showRange or spell.range ~= nil
		showCooldown = showCooldown or spell.cd ~= nil
	end
	-- The columns as the list showed them.
	local columns, nameRoom = BuildColumns(showRange, showCooldown)
	for key, label in pairs(buildBox.labels) do
		local column = columns[key]
		label:ClearAllPoints()
		if column then
			label:SetPoint("CENTER", buildBox.head, "RIGHT", -column.right - column.width / 2, 0)
			label:Show()
		else
			label:Hide()
		end
	end
	for key, line in pairs(buildBox.dividers) do
		local column = columns[key]
		line:ClearAllPoints()
		if column then
			line:SetPoint("TOPLEFT", buildBox, "TOPLEFT", 6 + INNER - column.divider, -22)
			line:Show()
		else
			line:Hide()
		end
	end
	local filledCount = table.getn(spells)
	buildBox.note:SetText((filledCount >= SLOTS and "|cffff8080" or "|cffd0d0d0")..math.min(filledCount, SLOTS).." / "..SLOTS.."|r")

	for place = 1, SLOTS + 1 do
		local row = SpellRow(place)
		local spell = place <= SLOTS and spells[place] or (place == SLOTS + 1 and racial)
		PlaceColumn(row.range, columns.range)
		PlaceColumn(row.cd, columns.cd)
		PlaceColumn(row.rank, columns.rank)
		row.name:SetWidth(nameRoom)
		Bold(row, place == 1 and spell and true or false)
		row.ability = spell and spell.name or nil
		row.keptCard = spell and run.cards and run.cards[spell.name] or nil
		if spell then
			local color = spell.color or { 0.8, 0.8, 0.8 }
			row.icon:SetTexture(spell.icon or OWN_ICON)
			row.icon:SetVertexColor(1, 1, 1)
			row.icon:SetAlpha(1)
			row.name:SetText(spell.racial and spell.name.."  |cff8a8a8a(racial)|r" or spell.name)
			row.rank:SetText(spell.rank or "")
			row.range:SetText(spell.range or "")
			row.cd:SetText(spell.cd or "")
			PaintSpell(row, color, not spell.racial, spell.racial and 0.5 or 1)
			At(row, buildBox, 6, -BUILD_TOP - (place - 1) * ROW)
		elseif place <= SLOTS then
			row.icon:SetTexture(FLAT)
			row.icon:SetVertexColor(0.15, 0.15, 0.18)
			row.icon:SetAlpha(0.8)
			row.name:SetText("empty slot")
			row.rank:SetText("")
			row.range:SetText("")
			row.cd:SetText("")
			PaintSpell(row, EMPTY, false, 0.6)
			At(row, buildBox, 6, -BUILD_TOP - (place - 1) * ROW)
		else
			row.base:Hide()
			row:Hide()
		end
	end

	-- The jewelry, a line a slot.
	local gear = GearLines(run)
	local lines = math.max(table.getn(gear), table.getn(GEAR_SLOT_NAMES))
	for index = 1, lines do
		local piece = gear[index] or { label = GEAR_SLOT_NAMES[index], empty = true }
		local line = GearLine(index)
		line.item, line.itemName, line.tip = piece.item, piece.name, piece.tip
		if piece.empty then
			line.wash:SetVertexColor(0.5, 0.5, 0.55, 0.06)
			Tint(line.edges, { 0.5, 0.5, 0.55 }, 0.15)
			line.label:SetText(piece.label or "")
			line.label:SetTextColor(0.45, 0.45, 0.5)
			FitTags(line, "empty")
			line.tags:SetTextColor(0.4, 0.4, 0.45)
		else
			local color = piece.color or WHITE
			line.color = color
			line.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
			Tint(line.edges, color, 0.7)
			line.label:SetText(piece.label or "")
			line.label:SetTextColor(1, 1, 1)
			FitTags(line, piece.tags or "-")
			line.tags:SetTextColor(1, 1, 1)
		end
		At(line, buildBox, 6, -GEAR_TOP - 15 - (index - 1) * GEAR_ROW)
	end
	HideAll(buildBox.gear, lines + 1)
	return GEAR_TOP + 15 + lines * GEAR_ROW + 5
end

------------------------------------------------------------------------------
-- The damage by source, in the meter's look (Meter.lua): DPS and TOTAL under
-- the title, then a bar a source on a dark base, its color to its share of
-- the first's in an edge of it, the amount and the share in their columns.

local BAR = 18                     -- as the build list's rows
local SHARE_WIDTH, AMOUNT_WIDTH = 30, 44
local AMOUNT_RIGHT = SHARE_WIDTH + 6
local NAME_ROOM = INNER - BAR - 2 - (AMOUNT_RIGHT + AMOUNT_WIDTH + 2) - 4
local BARS_TOP = 21 + 14 + 2

local damageBox = Box("Damage Done")
damageBox.strip = CreateFrame("Frame", nil, damageBox)
damageBox.strip:SetPoint("TOPLEFT", damageBox, "TOPLEFT", 6, -21)
damageBox.strip:SetWidth(INNER)
damageBox.strip:SetHeight(14)
damageBox.strip.wash = Flat(damageBox.strip, "BACKGROUND", WHITE, 0.04)
damageBox.strip.wash:SetAllPoints(damageBox.strip)
damageBox.cells = {}
for index = 1, 2 do
	local cell = {}
	cell.label = Font(damageBox.strip, 7, { 0.58, 0.58, 0.64 })
	cell.label:SetPoint("LEFT", damageBox.strip, "LEFT", (index - 1) * INNER / 2 + 6, 0)
	cell.value = Font(damageBox.strip, 10, WHITE)
	cell.value:SetPoint("LEFT", cell.label, "RIGHT", 4, 0)
	damageBox.cells[index] = cell
end
damageBox.cells[1].label:SetText("DPS")
damageBox.cells[1].value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
damageBox.cells[2].label:SetText("TOTAL")

local function SourceBar(index)
	local bar = damageBox.rows[index]
	if not bar then
		bar = CreateFrame("Frame", nil, damageBox)
		bar:SetWidth(INNER)
		bar:SetHeight(BAR)
		bar.backing = Flat(bar, "BACKGROUND", { 0.05, 0.05, 0.07 }, 0.92)
		bar.backing:SetAllPoints(bar)
		bar.fill = Flat(bar, "BORDER")
		bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		bar.fill:SetHeight(BAR)
		bar.edges = Edges(bar)
		for _, from in pairs({ AMOUNT_RIGHT + AMOUNT_WIDTH + 2, SHARE_WIDTH + 2 }) do
			local divider = Flat(bar, "OVERLAY", WHITE, 0.14)
			divider:SetWidth(1)
			divider:SetPoint("TOP", bar, "TOPRIGHT", -from, 0)
			divider:SetPoint("BOTTOM", bar, "BOTTOMRIGHT", -from, 0)
		end
		-- The icon a little inside the bar, the color round it.
		bar.icon = bar:CreateTexture(nil, "OVERLAY")
		bar.icon:SetWidth(BAR - 4)
		bar.icon:SetHeight(BAR - 4)
		bar.icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
		bar.name = Font(bar, 9, WHITE)
		bar.name:SetPoint("LEFT", bar, "LEFT", BAR + 2, 0)
		bar.name:SetHeight(12)
		bar.tag = Font(bar, 7, { 0.78, 0.91, 1 })
		bar.tag:SetText("(proc)")
		bar.value = Font(bar, 9, WHITE, nil, "RIGHT")
		bar.value:SetPoint("RIGHT", bar, "RIGHT", -AMOUNT_RIGHT, 0)
		bar.share = Font(bar, 8, { 0.85, 0.85, 0.85 }, nil, "RIGHT")
		bar.share:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
		CardRow(bar, 2)
		damageBox.rows[index] = bar
	end
	return bar
end

-- The edge around the filled part only: its top and bottom as long as the
-- fill, its right side at the fill's end.
local function EdgeTo(bar, width)
	local top, bottom, right = bar.edges[1], bar.edges[2], bar.edges[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	top:SetWidth(width)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bottom:SetWidth(width)
	right:ClearAllPoints()
	right:SetPoint("TOPLEFT", bar, "TOPLEFT", width - 1, 0)
	right:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", width - 1, 0)
end

local function DrawDamage(run)
	local seconds = Num(run.time)
	local total = run.meterTotal or Num(run.dealt)
	local dps = run.meterDps or (seconds > 0 and Num(run.dealt) / seconds or 0)
	damageBox.cells[1].value:SetText(Short(dps))
	damageBox.cells[2].value:SetText(Short(total))
	-- The ranks, as the meter shows them after the names: kept with the
	-- source, or the build's.
	local ranks = {}
	for _, spell in pairs(run.build or {}) do
		ranks[spell.name] = spell.rank
	end
	local sources = run.sources or {}
	local top = sources[1] and Num(sources[1].dmg) or 0
	for index = 1, table.getn(sources) do
		local source = sources[index]
		local bar = SourceBar(index)
		bar.ability = source.name
		bar.keptCard = run.cards and run.cards[source.name] or nil
		local color = source.color or { 0.8, 0.8, 0.8 }
		local share = top > 0 and math.min(1, Num(source.dmg) / top) or 0
		-- Never shorter than the icon's square: the color goes round it.
		local width = math.max(BAR, math.floor(INNER * share + 0.5))
		bar.fill:SetWidth(width)
		bar.fill:SetVertexColor(color[1], color[2], color[3], 0.45)
		Tint(bar.edges, color, 0.6)
		EdgeTo(bar, width)
		if source.icon then
			bar.icon:SetTexture(source.icon)
			bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			bar.icon:SetTexture(OWN_ICON)
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
		local rank = source.rank or ranks[source.name]
		local room = NAME_ROOM - (source.proc and 30 or 0)
		bar.name:SetWidth(room)
		local ranked = rank and rank > 0 and SurvivorUI_RankText and SurvivorUIDB and SurvivorUIDB.meterRanks
		bar.name:SetText((source.name or "?")..(ranked and "  |cffbdbdbd"..SurvivorUI_RankText(rank, true).."|r" or ""))
		bar.tag:ClearAllPoints()
		if source.proc then
			bar.tag:SetPoint("LEFT", bar, "LEFT", BAR + 2 + math.min(bar.name:GetStringWidth(), room) + 3, 0)
			bar.tag:Show()
		else
			bar.tag:Hide()
		end
		bar.value:SetText(Short(source.dmg))
		bar.share:SetText(math.floor(Num(source.share) * 100 + 0.5).."%")
		At(bar, damageBox, 6, -BARS_TOP - (index - 1) * (BAR + 2))
	end
	HideRows(damageBox, table.getn(sources) + 1)
	local height = Nothing(damageBox, table.getn(sources) == 0 and "The game's meter had nothing." or nil)
	return math.max(height, BARS_TOP + table.getn(sources) * (BAR + 2) + 4)
end

------------------------------------------------------------------------------
-- The biggest crits, in Biggest Crits' look (RunPanel.lua): the build list's
-- rows, the value in a column of its own.

local critBox = Box("Biggest Crits")

local function CritRow(index)
	local row = critBox.rows[index]
	if not row then
		row = CreateFrame("Frame", nil, critBox)
		row:SetWidth(INNER)
		row:SetHeight(ROW)
		row.base = Flat(critBox, "ARTWORK", { 0.05, 0.05, 0.07 }, 0.92)
		row.base:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.base:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.wash = Flat(row, "BACKGROUND")
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.rule = Flat(row, "BORDER")
		row.rule:SetHeight(1)
		row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.edges = Edges(row)
		row.divider = Flat(row, "OVERLAY", WHITE, 0.14)
		row.divider:SetWidth(1)
		row.divider:SetPoint("TOP", row, "TOPRIGHT", -46, 0)
		row.divider:SetPoint("BOTTOM", row, "BOTTOMRIGHT", -46, 0)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(ROW - 4)
		row.icon:SetHeight(ROW - 4)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.label = Font(row, 9, WHITE)
		row.label:SetPoint("LEFT", row, "LEFT", ROW + 2, 0)
		row.label:SetWidth(INNER - ROW - 54)
		row.label:SetHeight(11)
		row.value = Font(row, 10, WHITE, nil, "RIGHT")
		row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		CardRow(row, 3)
		critBox.rows[index] = row
	end
	return row
end

local function DrawCrits(run)
	local crits = run.crits or {}
	for index = 1, table.getn(crits) do
		local crit = crits[index]
		local row = CritRow(index)
		row.ability = crit.ability
		row.keptCard = run.cards and run.cards[crit.ability] or nil
		local color = crit.color or (SurvivorUI_MeterColor and SurvivorUI_MeterColor(crit.ability)) or WHITE
		row.label:SetText(crit.ability or "?")
		row.value:SetText(Short(crit.amount))
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
		row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
		Tint(row.edges, color, 0.6)
		local icon = crit.icon or (SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(crit.ability))
		if icon then
			row.icon:SetTexture(icon)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			row.icon:SetTexture(OWN_ICON)
			row.icon:SetTexCoord(0, 1, 0, 1)
		end
		row.base:Show()
		At(row, critBox, 6, -TOP - (index - 1) * ROW)
	end
	HideRows(critBox, table.getn(crits) + 1)
	local height = Nothing(critBox, table.getn(crits) == 0 and "No crit this run." or nil)
	return math.max(height, TOP + table.getn(crits) * ROW + 6)
end

------------------------------------------------------------------------------
-- The loot, in the loot list's look (LootLog.lua): each piece filled with
-- its quality's color in a black edge; the run second it came.

local lootBox = Box("Loot")

local function LootRow(index)
	local row = lootBox.rows[index]
	if not row then
		row = CreateFrame("Frame", nil, lootBox)
		row:SetWidth(INNER)
		row:SetHeight(ROW)
		row.border = Flat(row, "BACKGROUND", { 0, 0, 0 }, 1)
		row.border:SetAllPoints(row)
		row.wash = Flat(row, "BORDER")
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.name = Font(row, 10, WHITE)
		row.name:SetPoint("LEFT", row, "LEFT", 5, 0)
		row.name:SetHeight(11)
		-- The count and "new" after the name, never cut with it.
		row.extra = Font(row, 10, WHITE)
		row.at = Font(row, 11, { 0.88, 0.88, 0.88 }, nil, "RIGHT")
		row.at:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		-- Its tooltip: the link kept, else its name and quality.
		row:EnableMouse(true)
		row:SetScript("OnEnter", function()
			if ShowKept(this, this.tip, 3) then
				return
			end
			local link = this.item or (SurvivorUI_KnownItem and SurvivorUI_KnownItem(this.itemName))
			Aside(this, 3)
			if link then
				GameTooltip:SetHyperlink(link)
			else
				local color = this.color or WHITE
				GameTooltip:SetText(this.itemName or "?", color[1], color[2], color[3])
				if this.qualityName then
					GameTooltip:AddLine(string.upper(string.sub(this.qualityName, 1, 1))..string.sub(this.qualityName, 2), color[1], color[2], color[3])
				end
				GameTooltip:AddLine("Not yet seen equipped in a run: its details show here once you have worn it in one.", 0.62, 0.62, 0.68, 1)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		lootBox.rows[index] = row
	end
	return row
end

local function DrawLoot(run)
	local loot = run.loot or {}
	for index = 1, table.getn(loot) do
		local item = loot[index]
		local row = LootRow(index)
		local color = HexColor(item.color)
		local quality = SurvivorUI_QualityName and SurvivorUI_QualityName(item.color)
		row.item, row.itemName, row.color, row.qualityName, row.tip = item.item, item.name, color, quality, item.tip
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.75)
		local extra = ""
		if item.count and item.count > 1 then
			extra = "  x"..item.count
		end
		if item.new then
			extra = extra.."  |cff7dff7dnew|r"
		end
		row.extra:SetText(extra)
		local extraWidth = extra ~= "" and row.extra:GetStringWidth() or 0
		-- A long name is cut, the count and "new" after it not.
		local room = INNER - 48 - extraWidth
		row.name:SetWidth(room)
		row.name:SetText(item.name or "?")
		local nameWidth = math.min(row.name:GetStringWidth(), room)
		row.extra:ClearAllPoints()
		row.extra:SetPoint("LEFT", row, "LEFT", 5 + nameWidth, 0)
		row.at:SetText(item.at and Clock(item.at) or "")
		At(row, lootBox, 6, -TOP - (index - 1) * ROW)
	end
	HideRows(lootBox, table.getn(loot) + 1)
	local height = Nothing(lootBox, table.getn(loot) == 0 and "Nothing dropped." or nil)
	return math.max(height, TOP + table.getn(loot) * ROW + 6)
end

------------------------------------------------------------------------------
-- What felled the hero (a run fallen, kept since v3.0.9): the killing blow,
-- large in red; the hits of its last 10 seconds, the newest first, how long
-- before the fall; the damage taken by kind as the game counts it, each in a
-- bar of its share. One table for it all: the file is near Lua 5.0's 200
-- locals.

local fallen = { box = Box("Fallen to"), heads = {}, colors = {
	["boss melee"] = { 0.72, 0.32, 1.00 }, ["boss spell"] = { 0.86, 0.52, 1.00 }, elite = { 1.00, 0.55, 0.10 },
	["mob melee"] = { 0.80, 0.80, 0.84 }, ["mob spell"] = { 0.58, 0.74, 1.00 }, area = { 0.40, 0.86, 0.56 },
} }

function fallen.Row(index)
	local row = fallen.box.rows[index]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, fallen.box)
	row:SetWidth(INNER)
	row:SetHeight(ROW)
	row.wash = Flat(row, "BACKGROUND")
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
	row.fill = Flat(row, "BORDER")
	row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
	row.rule = Flat(row, "ARTWORK")
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.label = Font(row, 9, WHITE)
	row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
	row.label:SetWidth(INNER - 66)
	row.label:SetHeight(11)
	row.value = Font(row, 10, WHITE, nil, "RIGHT")
	row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
	fallen.box.rows[index] = row
	return row
end

local function DrawFallen(run)
	local death = run.death or {}
	local y, used, heads = TOP, 0, 0
	-- A row: its words, its value, its color, how much of it a bar fills.
	local function Line(label, value, color, share, strong)
		used = used + 1
		local row = fallen.Row(used)
		row.label:SetText(label)
		row.value:SetText(value)
		row.label:SetTextColor(color[1], color[2], color[3])
		row.value:SetTextColor(color[1], color[2], color[3])
		row.wash:SetVertexColor(color[1], color[2], color[3], strong and 0.42 or 0.07)
		row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
		if share then
			row.fill:SetWidth(math.max(1, INNER * share))
			row.fill:SetVertexColor(color[1], color[2], color[3], 0.32)
			row.fill:Show()
		else
			row.fill:Hide()
		end
		At(row, fallen.box, 6, -y)
		y = y + ROW
	end
	-- A small title over a part.
	local function Head(text)
		heads = heads + 1
		local head = fallen.heads[heads]
		if not head then
			head = Font(fallen.box, 8, MUTED)
			fallen.heads[heads] = head
		end
		head:SetText(text)
		At(head, fallen.box, 8, -y - 3)
		y = y + 15
	end
	local killer = death.killer
	if killer then
		local name = killer.area and "A ground effect" or ((killer.who or "?")..(killer.what and ("  \194\183  "..killer.what) or ""))
		Line(name, (killer.amount and Short(killer.amount) or "")..(killer.crit and " crit" or ""), { 1.00, 0.36, 0.30 }, nil, true)
	end
	local hits = death.hits or {}
	if table.getn(hits) > 0 then
		Head("ITS LAST 10 SECONDS")
		for index = 1, math.min(4, table.getn(hits)) do
			local hit = hits[index]
			Line(string.format("%.1fs  ", Num(hit.ago))..(hit.who or "?")..(hit.what and ("  \194\183  "..hit.what) or ""),
				Short(hit.amount)..(hit.crit and " crit" or ""), { 0.86, 0.86, 0.90 })
		end
	end
	local kinds = death.kinds or {}
	local total = 0
	for _, kind in pairs(kinds) do
		total = total + Num(kind.dmg)
	end
	if total > 0 then
		Head("DAMAGE TAKEN, BY KIND")
		for index = 1, math.min(4, table.getn(kinds)) do
			local kind = kinds[index]
			local share = Num(kind.dmg) / total
			local word = kind.source or "?"
			Line(string.upper(string.sub(word, 1, 1))..string.sub(word, 2), math.floor(share * 100 + 0.5).."%  "..Short(kind.dmg),
				fallen.colors[word] or WHITE, share)
		end
	end
	HideRows(fallen.box, used + 1)
	for index = heads + 1, table.getn(fallen.heads) do
		fallen.heads[index]:Hide()
	end
	local height = Nothing(fallen.box, used == 0 and "No hit seen before the fall." or nil)
	return math.max(height, y + 6)
end

------------------------------------------------------------------------------
-- The hero's numbers as they stood (the Stats panel's, CharacterPane.lua's):
-- in its groups and colors, every number but those at nothing (+0%, 0), each
-- with what it means. Kept since v3.0.12. One table, for the file's locals.

local statsPanel = { box = Box("Stats"), LINE = 16, HEAD = 18 }

function statsPanel.Row(index)
	local box = statsPanel.box
	local row = box.rows[index]
	if not row then
		row = CreateFrame("Frame", nil, box)
		row:SetWidth(INNER)
		row.wash = Flat(row, "BACKGROUND")
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.rule = Flat(row, "BORDER")
		row.rule:SetHeight(1)
		row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.label = Font(row, 10, WHITE)
		row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
		row.label:SetHeight(11)
		row.value = Font(row, 10, WHITE, nil, "RIGHT")
		row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function()
			if not this.tipText then
				return
			end
			local color = this.color
			Aside(this, 4)
			GameTooltip:SetText(this.tipTitle, color[1], color[2], color[3])
			GameTooltip:AddLine(this.tipText, 0.62, 0.62, 0.68, 1)
			-- Its parts as the run stood: the gear worn, and the rest.
			if this.gear then
				GameTooltip:AddDoubleLine("Worn gear", this.gear, 0.12, 1, 0, 0.12, 1, 0)
				if this.rest then
					GameTooltip:AddDoubleLine("Everything else", this.rest, 0.62, 0.62, 0.65, 0.85, 0.85, 0.85)
				end
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		box.rows[index] = row
	end
	return row
end

function statsPanel.Draw(run)
	local box, kept = statsPanel.box, run.stats
	local sections = SurvivorUI_StatList and SurvivorUI_StatList()
	if not (kept and sections) then
		HideRows(box, 1)
		return Nothing(box, "Not kept for runs before v3.0.12.")
	end
	Nothing(box, nil)
	-- A number the game had not sent reads as 0, as in the Stats panel.
	local stats = setmetatable({}, { __index = function(_, key) return kept[key] or 0 end })
	local used, y = 0, TOP
	local function Place(height, label, value, color, tip)
		used = used + 1
		local row = statsPanel.Row(used)
		row:SetHeight(height)
		row.label:SetText(label)
		row.value:SetText(value or "")
		row.label:SetTextColor(color[1], color[2], color[3])
		row.value:SetTextColor(color[1], color[2], color[3])
		row.color, row.tipTitle, row.tipText = color, label, tip
		row.gear, row.rest = nil, nil
		At(row, box, 6, -y)
		y = y + height
		return row
	end
	for index = 1, table.getn(sections) do
		local section = sections[index]
		local lines = {}
		for each = 1, table.getn(section.rows) do
			local entry = section.rows[each]
			local ok, text = pcall(entry[2], stats)
			text = ok and text and tostring(text)
			if text and string.find(text, "[1-9]") then
				table.insert(lines, { entry[1], text, entry[3] })
			end
		end
		if table.getn(lines) > 0 then
			local color = section.color
			if used > 0 then
				y = y + 4
			end
			-- The group's name, a rule of its color under it.
			local head = Place(statsPanel.HEAD, string.upper(section.title), nil, color, nil)
			head.wash:SetVertexColor(color[1], color[2], color[3], 0)
			head.rule:SetVertexColor(color[1], color[2], color[3], 0.6)
			for each = 1, table.getn(lines) do
				local line = lines[each]
				local row = Place(statsPanel.LINE, line[1], line[2], color, line[3])
				if SurvivorUI_StatGear then
					row.gear, row.rest = SurvivorUI_StatGear(line[1], kept)
				end
				row.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
				row.rule:SetVertexColor(color[1], color[2], color[3], 0.2)
			end
		end
	end
	HideRows(box, used + 1)
	return math.max(Nothing(box, used == 0 and "No numbers kept." or nil), y + 6)
end

------------------------------------------------------------------------------
-- Drawing a run: the header, then each column's panels top to bottom.

local BOXES = { tracker, runBox, buildBox, damageBox, critBox, lootBox, fallen.box, statsPanel.box }

-- A panel at its column's next place, its height given; the place under it
-- comes back.
local function Stack(box, column, y, height)
	box:SetHeight(height)
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + (column - 1) * (BOX + GAP), -y)
	box:Show()
	return y + height + GAP
end

-- Draw in parts, a function each: the game's Lua (5.0, from the game's
-- 0.101) lets a function reach at most 32 of the file's locals.

-- No run kept: the window empty.
local function DrawEmpty()
	pageButton:Hide()
	deleteButton:Hide()
	pinButton:Hide()
	footer:SetText("")
	before:Disable()
	after:Disable()
	zoneIcon:Hide()
	for _, text in pairs({ nameText, zoneText, whenText, heroText }) do
		text:SetText("")
	end
	party.Draw(nil)
	DrawMods(nil)
	SetBadge(firstBadge, nil)
	SetBadge(secondBadge, nil)
	classIcon:Hide()
	Theme(GOLD)
	for _, box in pairs(BOXES) do
		box:Hide()
	end
	rule:Hide()
	empty:Show()
	window:SetHeight(160)
end

-- Under and over the panels: the run's number, < and >, the pin, the footer.
local function DrawNavigation(history, total)
	empty:Hide()
	rule:Show()
	-- The run's number and the count in their box; < and > go round, so with
	-- two runs or more both work.
	pageButton.text:SetText(shown.." / "..total)
	pageButton:Show()
	deleteButton:Show()
	-- The footer: the run's pin, how many are kept.
	local pinned = 0
	for _, each in pairs(history) do
		if each.pinned then
			pinned = pinned + 1
		end
	end
	-- How many are kept, out of how many the options keep (the Run History tab).
	local most = tonumber(Settings().historyKeep) or 100
	-- "RUN HISTORY  ·  43 of 100 runs kept  ·  2 pinned  ·  Survivor UI v3.0.16":
	-- the name in soft gold, the numbers white; the addon's version (its .toc)
	-- last, so a picture of the window tells which one took it.
	local dot = "   \194\183   "
	local version = GetAddOnMetadata and GetAddOnMetadata("SurvivorUI", "Version")
	footer:SetText("|cffd9b44aRUN HISTORY|r"..dot.."|cffffffff"..total.."|r of "..most.." runs kept"
		..(pinned > 0 and (dot.."|cffffffff"..pinned.."|r pinned") or "")
		..(version and (dot.."Survivor UI v"..version) or ""))
	local pinnedRun = history[shown].pinned and true or false
	pinButton.text:SetText(pinnedRun and "Pinned" or "Pin")
	pinButton.lit = pinnedRun
	pinButton.tipTitle = pinnedRun and "Pinned" or "Pin this run"
	pinButton:Light(false)
	pinButton:Show()
	if total > 1 then
		before:Enable()
		after:Enable()
	else
		before:Disable()
		after:Disable()
	end
end

-- Over the panels: the map, the result and when, the hero, the tabs.
local function DrawHeader(run, final, moment)
	zoneText:SetText(run.zone or "?")
	zoneIcon:Show()
	-- An endless run's two badges show its moments on a click; the line under
	-- the one shown.
	local first, second = final and "victory" or nil, final and "end" or nil
	local pick = final and "\n|cff9a9aa0Click to show this moment.|r" or ""
	if run.result == "victory" then
		SetBadge(firstBadge, "victory", "Victory", "The final boss slain at "..Clock(run.time).."."..pick, Clock(run.time), first)
	elseif run.result == "left" then
		SetBadge(firstBadge, "left", "Left", "Left from the menu at "..Clock(run.time)..", level "..Num(run.level)..".", Clock(run.time), first)
	else
		SetBadge(firstBadge, "dead", "Fallen", "Fell at "..Clock(run.time)..", level "..Num(run.level)..".", Clock(run.time), first)
	end
	if final then
		local after = Clock(Num(final.time) - Num(run.time))
		if final.result == "dead" then
			SetBadge(secondBadge, "endless", "Fallen in endless mode", "Fell at "..Clock(final.time)..", "..after.." after the victory."..pick, Clock(final.time), second)
		elseif final.result == "left" then
			SetBadge(secondBadge, "left", "Left in endless mode", "Left at "..Clock(final.time)..", "..after.." after the victory."..pick, Clock(final.time), second)
		else
			SetBadge(secondBadge, "going", "Endless mode, still going", Clock(final.time).." so far, "..after.." after the victory."..pick, Clock(final.time), second)
		end
	else
		SetBadge(secondBadge, nil)
	end
	PlaceBadges()
	-- The time on the computer's clock; the first runs kept only their text.
	local at = moment.at or run.at
	whenText:SetText(at and (When(at).."  ·  "..Ago(at)) or (run.when or ""))
	local r, g, b = 1, 0.82, 0
	if SurvivorUI_ClassColor and run.classKey then
		r, g, b = SurvivorUI_ClassColor(run.classKey)
	end
	Theme({ r, g, b })
	local texture, coords = nil, nil
	if SurvivorUI_ClassIcon then
		texture, coords = SurvivorUI_ClassIcon(run.classKey)
	end
	if coords then
		-- Cut square inside the art's round edge.
		local cutX, cutY = (coords[2] - coords[1]) * CROP, (coords[4] - coords[3]) * CROP
		classIcon.texture:SetTexture(texture)
		classIcon.texture:SetTexCoord(coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY)
		PaintIcon({ r, g, b })
		classIcon:Show()
	else
		classIcon:Hide()
	end
	-- The hero: the name in the class's color, the rest lighter under it.
	nameText:SetText(run.hero or "?")
	nameText:SetTextColor(r, g, b)
	local light = Light({ r, g, b })
	-- The level as the run tracker and the XP bar write it, "Lv. 18", in the
	-- line's own color (the class's, lighter).
	heroText:SetText("Lv. "..Num(moment.level).."  "..(run.race or "").." "..(run.class or ""))
	heroText:SetTextColor(light[1], light[2], light[3])
	party.Draw(run)
	DrawMods(run.mods)
end

-- The panels in their four columns, the window's height to hold them.
local function DrawPanels(moment, base)
	-- The run tracker and the run's numbers; the build and the damage; the
	-- crits and the loot; the hero's numbers.
	local first = HEADER
	local left = first
	if moment.tracker then
		left = Stack(tracker, 1, left, DrawTracker(moment.tracker, moment.result))
	else
		tracker:Hide()
	end
	left = Stack(runBox, 1, left, DrawRun(moment, base))
	local middle = Stack(buildBox, 2, first, DrawBuild(moment))
	middle = Stack(damageBox, 2, middle, DrawDamage(moment))
	local right = Stack(critBox, 3, first, DrawCrits(moment))
	right = Stack(lootBox, 3, right, DrawLoot(moment))
	-- What felled the hero, on a fall kept since v3.0.9.
	if moment.death and moment.result == "dead" then
		right = Stack(fallen.box, 3, right, DrawFallen(moment))
	else
		fallen.box:Hide()
	end
	-- The hero's numbers, a column of their own.
	local fourth = Stack(statsPanel.box, 4, first, statsPanel.Draw(moment))
	window:SetHeight(math.max(left, middle, right, fourth) - GAP + PAD + FOOTER)
end

Draw = function()
	local history = History()
	local total = table.getn(history)
	shown = math.max(1, math.min(shown, total))
	if total == 0 then
		DrawEmpty()
		return
	end
	DrawNavigation(history, total)
	local run = history[shown]
	-- An endless run: its victory, or its end (the whole run), by the tabs.
	local final = run.endless
	local moment, base = run, nil
	if final and view ~= "victory" then
		moment, base = final, run
	end
	DrawHeader(run, final, moment)
	DrawPanels(moment, base)
end

-- Once more on the next frame: a text not drawn yet measures nothing, and
-- some places go by a text's width.
window:SetScript("OnUpdate", function()
	if this.again then
		this.again = nil
		Draw()
	end
end)

window:SetScript("OnHide", function()
	pageBox:ClearFocus()
	Disarm()
end)

-- For the options (Run History): what is kept, and about how much room it
-- takes in the saved file (its text, read at each login and reload).
local function Bytes(value)
	local kind = type(value)
	if kind == "string" then
		return string.len(value) + 6
	elseif kind == "number" then
		return 10
	elseif kind == "boolean" then
		return 8
	elseif kind == "table" then
		local total = 4
		for key, item in pairs(value) do
			total = total + Bytes(key) + Bytes(item) + 12
		end
		return total
	end
	return 0
end

function SurvivorUI_HistoryStats()
	local history = History()
	local won, pinned, photos = 0, 0, 0
	for _, run in pairs(history) do
		if run.result == "victory" then
			won = won + 1
		end
		if run.pinned then
			pinned = pinned + 1
		end
		if run.cards or run.rowTips then
			photos = photos + 1
		end
	end
	return table.getn(history), won, pinned, photos, Bytes(history)
end

-- Every run away (the options' Delete all), the window too.
function SurvivorUI_ClearHistory()
	Settings().runHistory = {}
	if window:IsShown() then
		Go(1)
	end
end

-- Every run, asked first: the word clear typed (the window's Delete list and
-- the options' Run History tab); then is called after, if given.
function SurvivorUI_AskClearHistory(then_)
	local history = History()
	local total = table.getn(history)
	if total == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: Run History keeps no run.")
		return
	end
	local pinned = 0
	for _, each in pairs(history) do
		if each.pinned then
			pinned = pinned + 1
		end
	end
	SurvivorUI_Confirm({
		title = "Clear all runs?",
		text = "Every run kept goes for good: "..total..(total == 1 and " run" or " runs")
			..(pinned > 0 and (", the "..pinned.." pinned too") or "")..".\n|cff9a9aa0Type|r clear |cff9a9aa0to clear them.|r",
		word = "clear",
		yes = "Clear all",
		onYes = function()
			SurvivorUI_ClearHistory()
			if then_ then
				then_()
			end
		end,
	})
end

-- The options' Back to its place (Run History tab): this window and Career's
-- under the screen's top, in the middle, as at first.
function SurvivorUI_ResetHistoryPlace()
	for _, frame in pairs({ window, getglobal("SurvivorUICareer") }) do
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "TOP", 0, -60)
	end
end

function SurvivorUI_ShowLastRuns()
	if window:IsShown() then
		window:Hide()
		return
	end
	shown, view = 1, "end"
	window:Show()
	Draw()
	window.again = true
end

SurvivorUI_ShowRunHistory = SurvivorUI_ShowLastRuns

-- The newest run kept, for the note by the minimap (MinimapButton.lua).
function SurvivorUI_NewestRun()
	return History()[1]
end

