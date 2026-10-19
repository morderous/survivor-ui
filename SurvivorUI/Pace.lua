-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the kill pace, a glowing orb right of the run tracker's clock.
--
-- How fast the enemies die, as kills a minute over the run's last 20 seconds,
-- held against your own runs on the same zone and run modifiers, at the same
-- minute of the run, as the enemies come thicker as a run goes on: every
-- class's (the account's, to see how one hero does against another), or this
-- class's only. The orb says it in its color, and its sparks in how lively
-- they are:
--
--   white   no runs yet to hold it against (three must have reached the minute)
--   red     as slow as your slowest run at this minute: sparks sinking
--   yellow  in between
--   blue    near your fastest
--   green   as fast as your fastest, or faster: quick sparks and stars
--
-- The run is also told in stretches, from one boss's spawn to the next's (the
-- first from the start): as each boss comes, a banner left of the tracker
-- says the kills of the stretch just ended, their share of your best on that
-- stretch and the place they take among your runs, in the color of their
-- state; the tooltip has the stretch going on.
--
-- The numbers are in its tooltip only. It reads the game's own count (its
-- addon API: AZS_RUN.kills and the run's clock, which stops on a pause or a
-- card choice). Each run keeps its kills minute by minute, its stretches and
-- its class, the last 60 runs of each zone and modifiers.
--
-- Its settings have a tab of their own in /sui opt: what it is held against,
-- the seconds the rate is read over, the runs a minute needs before it is
-- colored, how lively the sparks are, and the boss banner and how long it
-- stays.
--
-- It hangs on the run tracker: it moves and sizes with it, and goes with it.
-- /sui pace hides it, /sui pace class holds it against this class's runs only
-- (or every class's again), /sui pace reset forgets the runs it holds against.

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WINDOW = 20   -- run seconds the rate is read over, unless set
local SETTLE = 5    -- run seconds before a rate is shown
local MIN_RUNS = 3  -- runs at a minute before it is held against them, unless set
local KEEP = 60     -- runs kept for each zone and modifiers
local SPARKS = 16
local STARS = 4

local MUTED = { 0.60, 0.60, 0.62 }

-- Each state: its name, color, how fast the orb breathes (seconds a breath),
-- how often a spark leaves it (seconds), which way the sparks go, how far,
-- and whether stars come out.
local TIERS = {
	none    = { label = "No runs to compare yet", color = { 0.92, 0.92, 0.96 }, breath = 2.6, every = 0.70, rise = 1, reach = 16 },
	slow    = { label = "Slow", color = { 1.00, 0.28, 0.22 }, breath = 2.2, every = 0.45, rise = -1, reach = 14 },
	steady  = { label = "Steady", color = { 1.00, 0.82, 0.18 }, breath = 1.8, every = 0.45, rise = 1, reach = 18 },
	fast    = { label = "Fast", color = { 0.30, 0.62, 1.00 }, breath = 1.3, every = 0.28, rise = 1, reach = 22 },
	blazing = { label = "Out of this world", color = { 0.30, 1.00, 0.45 }, breath = 0.8, every = 0.13, rise = 1, reach = 26, stars = 0.45 },
}
-- Slow to blazing, and the score (0 your slowest, 1 your fastest) between each
-- two; a state changes only a little past the line, so it does not flicker.
local ORDER = { "slow", "steady", "fast", "blazing" }
local LINES = { 0.35, 0.65, 0.90 }
local MARGIN = 0.03
local BANNER_HOLD = 6  -- seconds the stretch's banner stays, unless set

-- The runs were first kept by class, zone and modifiers ("rogue:elwynn:100
-- 100 100 100"); now by zone and modifiers, each run naming its class.
local function Migrate(db)
	local old = {}
	for key in pairs(db.paceRuns) do
		if string.find(key, "^%a+:%a+:") then
			table.insert(old, key)
		end
	end
	for _, key in pairs(old) do
		local _, _, class, rest = string.find(key, "^(%a+):(.*)$")
		db.paceRuns[rest] = db.paceRuns[rest] or {}
		for _, record in pairs(db.paceRuns[key]) do
			record.class = record.class or class
			table.insert(db.paceRuns[rest], record)
		end
		db.paceRuns[key] = nil
	end
	db.paceVersion = 2
end

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.pace == nil then
		SurvivorUIDB.pace = true
	end
	SurvivorUIDB.paceRuns = SurvivorUIDB.paceRuns or {}
	if SurvivorUIDB.paceVersion ~= 2 then
		Migrate(SurvivorUIDB)
	end
	return SurvivorUIDB
end

-- The settings the tab sets (Options.lua), or their defaults.
local function Window()
	return Settings().paceWindow or WINDOW
end

local function MinRuns()
	return Settings().paceMinRuns or MIN_RUNS
end

-- The runs it is held against: the same zone and modifiers.
local function RunKey()
	if not (AZS_ZONE and AZS_ZONE.zone) then
		return nil
	end
	return AZS_ZONE.zone..":"..(AZS_ZONE.mods or "")
end

-- A schedule entry's field, by name or by place.
local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- 2,054
local function Thousands(value)
	local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
	local result = ""
	while string.len(text) > 3 do
		result = ","..string.sub(text, -3)..result
		text = string.sub(text, 1, -4)
	end
	return text..result
end

-- The run's modifiers ("100 100 100 100": enemy density, health, damage,
-- speed) as words: "normal", or the ones that differ ("density 150%, health 200%").
local MOD_NAMES = { "density", "health", "damage", "speed" }
local function ModsLabel(mods)
	local parts, index = {}, 0
	for value in string.gfind(tostring(mods or ""), "%d+") do
		index = index + 1
		if MOD_NAMES[index] and value ~= "100" then
			table.insert(parts, MOD_NAMES[index].." "..value.."%")
		end
	end
	if index == 0 then
		return nil
	end
	return table.getn(parts) > 0 and table.concat(parts, ", ") or "normal"
end
-- For the last runs (RunHistory.lua).
SurvivorUI_ModsLabel = ModsLabel

-- "shaman" as "Shaman".
local function ClassLabel(class)
	if not class then
		return "?"
	end
	return string.upper(string.sub(class, 1, 1))..string.sub(class, 2)
end

------------------------------------------------------------------------------
-- The orb: a soft glow behind a bright core, the sparks and the stars.

local frame = CreateFrame("Frame", "SurvivorUIPace", UIParent)
frame:SetWidth(20)
frame:SetHeight(20)
frame:EnableMouse(true)
frame:Hide()

local glow = frame:CreateTexture(nil, "BACKGROUND")
glow:SetTexture(ART.."PaceGlow")
glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", frame, "CENTER", 0, 0)

local core = frame:CreateTexture(nil, "ARTWORK")
core:SetTexture(ART.."PaceDot")
core:SetBlendMode("ADD")
core:SetPoint("CENTER", frame, "CENTER", 0, 0)

local function Pool(count, art, layer)
	local pool = {}
	for index = 1, count do
		local piece = frame:CreateTexture(nil, layer)
		piece:SetTexture(ART..art)
		piece:SetBlendMode("ADD")
		piece:Hide()
		pool[index] = piece
	end
	return pool
end

local sparks = Pool(SPARKS, "PaceDot", "ARTWORK")
local stars = Pool(STARS, "PaceSpark", "OVERLAY")

------------------------------------------------------------------------------
-- This run.

local run          -- this run's minutes in the history: [minute] = its kills
local recording    -- whether this run is seen from its start, minute by minute
local lastTime     -- the run clock at the last sample
local minute       -- the minute of the run going on
local minuteKills  -- the kills when it began
local samples = {} -- { time, kills }, the last WINDOW seconds
local rate         -- kills a minute now, nil until SETTLE seconds in
local shown        -- the rate the orb is judged by, eased toward the live one
local spawned = {}       -- [boss index] = true once its spawn is counted (or came before a reload)
local stretches = {}     -- [boss index] = the kills from the boss before (or the start) to its spawn
local lastMark           -- the kills at the last boss's spawn (or the start); nil when not seen
local announcements = {} -- stretches just ended, for the banner: { index, name, kills }

-- A new run, or one found already going (a reload): its first minutes are not
-- known then, so it is held against the others but not kept.
local function StartRun(time, kills)
	samples = {}
	rate, shown = nil, nil
	minute = math.floor(time / 60) + 1
	minuteKills = kills
	run = nil
	recording = time < 2
	spawned, stretches, announcements = {}, {}, {}
	lastMark = nil
	if recording then
		lastMark = kills
	else
		-- Found going: the bosses already come are not this session's to tell.
		for _, entry in pairs(AZS_SCHEDULE or {}) do
			local at = tonumber(Field(entry, "at", 2))
			if at and at <= time then
				spawned[Field(entry, "index", 1)] = true
			end
		end
	end
end

-- The run goes into the history as its first minute ends, under the zone and
-- modifiers the game has sent by then, with its class.
local function Keep()
	local key = RunKey()
	if not key then
		return nil
	end
	local history = Settings().paceRuns
	history[key] = history[key] or {}
	local list = history[key]
	-- Runs of under two minutes say nothing.
	for index = table.getn(list), 1, -1 do
		if table.getn(list[index]) < 2 then
			table.remove(list, index)
		end
	end
	while table.getn(list) >= KEEP do
		table.remove(list, 1)
	end
	local record = { class = AZS_ZONE.class, stretches = stretches }
	table.insert(list, record)
	return record
end

-- A boss come (out of "due", at its time: not the last run's states, before
-- the game sends the new schedule): the stretch up to it ends.
local function Bosses(time, kills)
	for _, entry in pairs(AZS_SCHEDULE or {}) do
		local index, at = Field(entry, "index", 1), tonumber(Field(entry, "at", 2))
		local state = Field(entry, "state", 5) or "due"
		if index and at and state ~= "due" and not spawned[index] and time >= at - 5 then
			spawned[index] = true
			if lastMark then
				local got = kills - lastMark
				if recording then
					stretches[index] = got
				end
				table.insert(announcements, { index = index, name = Field(entry, "name", 3), kills = got })
			end
			lastMark = kills
		end
	end
end

local function Sample()
	if not (AZS_GetRunTime and AZS_RUN and AZS_RUN.kills) then
		return
	end
	local time = AZS_GetRunTime()
	local kills = AZS_RUN.kills
	if not time then
		return
	end
	-- A new run: the clock went back (or none seen yet).
	local fresh = not lastTime or time < lastTime - 1
	if fresh then
		StartRun(time, kills)
	end
	Bosses(time, kills)
	if not fresh and (AZS_GetPhase() ~= "playing" or time <= lastTime) then
		lastTime = time
		return
	end
	lastTime = time

	-- A minute over: its kills kept. A gap of more than one (a long hitch, or
	-- the pace switched off a while) and the rest of the run is not kept.
	local now = math.floor(time / 60) + 1
	if now > minute then
		if recording and now == minute + 1 then
			if not run and minute == 1 then
				run = Keep()
			end
			if run and table.getn(run) == minute - 1 then
				run[minute] = kills - minuteKills
			else
				recording = false
			end
		else
			recording = false
		end
		minute = now
		minuteKills = kills
	end

	table.insert(samples, { time, kills })
	while samples[2] and samples[1][1] < time - Window() do
		table.remove(samples, 1)
	end
	local first = samples[1]
	local span = time - first[1]
	if span >= SETTLE then
		rate = (kills - first[2]) / span * 60
	end
end

-- Whether a kept run is one to hold this one against: every class's, or this
-- class's only.
local function Compared(record)
	if record == run then
		return false
	end
	return not Settings().paceClassOnly or record.class == (AZS_ZONE and AZS_ZONE.class)
end

-- Your other runs at this minute: slowest, fastest, average, how many, and
-- the classes of the slowest and the fastest.
local function Reference()
	local key = RunKey()
	local list = key and Settings().paceRuns[key]
	if not (list and minute) then
		return nil, 0
	end
	local slowest, fastest, slowClass, fastClass, sum, count
	count, sum = 0, 0
	for _, record in pairs(list) do
		local kills = Compared(record) and record[minute]
		if kills then
			count = count + 1
			sum = sum + kills
			if not slowest or kills < slowest then
				slowest, slowClass = kills, record.class
			end
			if not fastest or kills > fastest then
				fastest, fastClass = kills, record.class
			end
		end
	end
	if count < MinRuns() then
		return nil, count
	end
	return slowest, count, fastest, sum / count, slowClass, fastClass
end

-- 0 as slow as your slowest, 1 as fast as your fastest.
-- Runs all much alike: the span is widened evenly around them, to at least a
-- tenth of the fastest.
local function Score(value, slowest, fastest)
	local span = math.max(fastest - slowest, fastest * 0.1, 1)
	local low = (slowest + fastest - span) / 2
	return math.max(0, math.min(1, (value - low) / span))
end

------------------------------------------------------------------------------
-- The state.

local tier = "none"            -- the state shown
local score                    -- 0 your slowest .. 1 your fastest, nil without runs
local r, g, b = 0.92, 0.92, 0.96  -- the color shown, eased toward the state's

-- The state a score falls in, slow 1 to blazing 4.
local function RawTier(value)
	local raw = 1
	for index = 1, table.getn(LINES) do
		if value >= LINES[index] then
			raw = index + 1
		end
	end
	return raw
end

-- The state for this score, kept until the score is a little past a line.
local function TierFor(value)
	local raw = RawTier(value)
	local now = 0
	for index = 1, table.getn(ORDER) do
		if ORDER[index] == tier then
			now = index
		end
	end
	if now == 0 or raw == now then
		return ORDER[raw]
	end
	if raw > now and value >= LINES[raw - 1] + MARGIN then
		return ORDER[raw]
	end
	if raw < now and value < LINES[raw] - MARGIN then
		return ORDER[raw]
	end
	return tier
end

local function Judge()
	score = nil
	if not shown then
		tier = "none"
		return
	end
	local slowest, _, fastest = Reference()
	if not slowest then
		tier = "none"
		return
	end
	score = Score(shown, slowest, fastest)
	tier = TierFor(score)
end

------------------------------------------------------------------------------
-- The stretches: from one boss's spawn to the next's.

-- Your other runs' stretch up to this boss: how many, slowest, fastest,
-- average, and the place `value` takes among them.
local function StretchReference(index, value)
	local key = RunKey()
	local list = key and Settings().paceRuns[key]
	local slowest, fastest, sum, count, better = nil, nil, 0, 0, 0
	for _, record in pairs(list or {}) do
		local kills = Compared(record) and record.stretches and record.stretches[index]
		if kills then
			count = count + 1
			sum = sum + kills
			if not slowest or kills < slowest then
				slowest = kills
			end
			if not fastest or kills > fastest then
				fastest = kills
			end
			if value and kills > value then
				better = better + 1
			end
		end
	end
	return count, slowest, fastest, count > 0 and sum / count or nil, better + 1
end

-- The boss to come next: { index, name }.
local function NextBoss()
	local best
	for _, entry in pairs(AZS_SCHEDULE or {}) do
		local at = tonumber(Field(entry, "at", 2))
		if (Field(entry, "state", 5) or "due") == "due" and at and (not best or at < best.at) then
			best = { index = Field(entry, "index", 1), name = Field(entry, "name", 3), at = at }
		end
	end
	return best
end

-- 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th, 21st.
local function Ordinal(n)
	local tens, ones = math.mod(n, 100), math.mod(n, 10)
	if tens >= 11 and tens <= 13 then
		return n.."th"
	end
	return n..(ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th")
end

-- The banner: "Up to Hogger" over "1,520 kills / 94% of your best / 2nd of 6".
local banner = CreateFrame("Frame", "SurvivorUIPaceBanner", UIParent)
banner:SetWidth(300)
banner:SetHeight(30)
banner:Hide()
banner.title = banner:CreateFontString(nil, "OVERLAY")
banner.title:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
banner.title:SetJustifyH("RIGHT")
banner.title:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
banner.title:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
banner.line = banner:CreateFontString(nil, "OVERLAY")
banner.line:SetFont(SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
banner.line:SetJustifyH("RIGHT")
banner.line:SetPoint("TOPRIGHT", banner.title, "BOTTOMRIGHT", 0, -2)

-- Left of the tracker, level with the orb; under the guardians' list when it
-- stands there (Guardians.lua).
local function PlaceBanner()
	local tracker = getglobal("SurvivorUITracker")
	local guardians = getglobal("SurvivorUIGuardians")
	banner:ClearAllPoints()
	if guardians and guardians:IsShown() and guardians:GetAlpha() > 0 then
		banner:SetParent(tracker or UIParent)
		banner:SetFrameLevel((tracker or UIParent):GetFrameLevel() + 3)
		banner:SetPoint("TOPRIGHT", guardians, "BOTTOMRIGHT", 0, -8)
	elseif tracker and tracker:IsShown() then
		banner:SetParent(tracker)
		banner:SetFrameLevel(tracker:GetFrameLevel() + 3)
		local _, orbY = frame:GetCenter()
		local _, trackerY = tracker:GetCenter()
		banner:SetPoint("RIGHT", tracker, "LEFT", -16, (orbY and trackerY) and (orbY - trackerY) or 0)
	else
		banner:SetParent(UIParent)
		banner:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	end
end

local function Announce(ended)
	local count, slowest, fastest, _, place = StretchReference(ended.index, ended.kills)
	local color = TIERS.none.color
	local text = Thousands(ended.kills).." kills"
	if count > 0 then
		text = text.."  |cff8a8a8a/|r  "..string.format("%.0f%%", ended.kills / math.max(fastest, 1) * 100).." of your best"
			.."  |cff8a8a8a/|r  "..(place == 1 and "your best" or Ordinal(place)).." of "..(count + 1)
		if count >= MinRuns() then
			color = TIERS[ORDER[RawTier(Score(ended.kills, slowest, fastest))]].color
		end
	else
		text = text.."  |cff8a8a8a/|r  the first to compare"
	end
	banner.title:SetText("Up to "..(ended.name or "the boss"))
	banner.line:SetText(text)
	banner.line:SetTextColor(color[1], color[2], color[3])
	PlaceBanner()
	banner.age = 0
	banner.hold = Settings().paceBannerHold or BANNER_HOLD
	banner:SetAlpha(0)
	banner:Show()
end

-- In over a quarter second, held, out over a second.
banner:SetScript("OnUpdate", function()
	banner.age = (banner.age or 0) + arg1
	local age = banner.age
	if age < 0.25 then
		banner:SetAlpha(age / 0.25)
	elseif age < banner.hold then
		banner:SetAlpha(1)
	elseif age < banner.hold + 1 then
		banner:SetAlpha(banner.hold + 1 - age)
	else
		banner:Hide()
	end
end)

------------------------------------------------------------------------------
-- The effects.

local clock = 0      -- seconds, for the breathing
local sparkWait = 0
local starWait = 0

-- A spark from the orb's edge, going up (or down) and fading.
local function Spark(state)
	for _, spark in pairs(sparks) do
		if not spark.life then
			spark.life = 0
			spark.length = 0.9 + math.random() * 0.7
			spark.x = (math.random() - 0.5) * 10
			spark.drift = (math.random() - 0.5) * 8
			spark.reach = state.reach * (0.7 + math.random() * 0.5)
			spark.rise = state.rise
			local size = 2.5 + math.random() * 2.5
			spark:SetWidth(size)
			spark:SetHeight(size)
			return
		end
	end
end

-- A star near the orb, growing and fading.
local function Star()
	for _, star in pairs(stars) do
		if not star.life then
			star.life = 0
			star.length = 0.6 + math.random() * 0.3
			local angle = math.random() * 6.283
			local distance = 9 + math.random() * 6
			star.x, star.y = math.cos(angle) * distance, math.sin(angle) * distance
			star.size = 8 + math.random() * 5
			return
		end
	end
end

local function Animate(elapsed, playing)
	local state = TIERS[tier]
	local color = state.color
	-- The color eases over a third of a second or so.
	local ease = math.min(1, elapsed * 3)
	r = r + (color[1] - r) * ease
	g = g + (color[2] - g) * ease
	b = b + (color[3] - b) * ease

	-- The breath: the glow swells and fades; slower and dimmer while the clock
	-- stands still.
	clock = clock + elapsed
	local breath = playing and state.breath or 3.5
	local wave = (math.sin(clock * 6.283 / breath) + 1) / 2
	local strength = playing and 1 or 0.55
	glow:SetWidth(26 + 10 * wave)
	glow:SetHeight(26 + 10 * wave)
	glow:SetVertexColor(r, g, b)
	glow:SetAlpha((0.45 + 0.4 * wave) * strength)
	core:SetWidth(8 + 2 * wave)
	core:SetHeight(8 + 2 * wave)
	core:SetVertexColor(0.55 + 0.45 * r, 0.55 + 0.45 * g, 0.55 + 0.45 * b)
	core:SetAlpha(0.85 * strength + 0.15)

	local effects = Settings().paceEffects or "full"
	if playing and effects ~= "none" then
		sparkWait = sparkWait - elapsed
		if sparkWait <= 0 then
			Spark(state)
			sparkWait = state.every * (effects == "calm" and 2.5 or 1) * (0.7 + math.random() * 0.6)
		end
		if state.stars and effects == "full" then
			starWait = starWait - elapsed
			if starWait <= 0 then
				Star()
				starWait = state.stars * (0.6 + math.random() * 0.8)
			end
		end
	end

	for _, spark in pairs(sparks) do
		if spark.life then
			spark.life = spark.life + elapsed
			local part = spark.life / spark.length
			if part >= 1 then
				spark.life = nil
				spark:Hide()
			else
				spark:ClearAllPoints()
				spark:SetPoint("CENTER", frame, "CENTER", spark.x + spark.drift * part,
					spark.rise * (4 + spark.reach * part))
				spark:SetVertexColor(r, g, b)
				spark:SetAlpha(0.9 * (1 - part))
				spark:Show()
			end
		end
	end
	for _, star in pairs(stars) do
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
				star:SetPoint("CENTER", frame, "CENTER", star.x, star.y)
				star:SetVertexColor(0.7 + 0.3 * r, 0.7 + 0.3 * g, 0.7 + 0.3 * b)
				star:SetAlpha(1 - part)
				star:Show()
			end
		end
	end
end

local function Running()
	if not (AZS_GetPhase and AZS_RUN) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

-- The counting: whenever the pace is on and a run is going, the tracker (and
-- so the orb) shown or not, so This Run has the rate and every run is kept.
local counter = CreateFrame("Frame")
local sampleWait = 0
counter:SetScript("OnUpdate", function()
	if not (Settings().pace and Running()) then
		return
	end
	local elapsed = arg1
	sampleWait = sampleWait + elapsed
	if sampleWait >= 0.25 then
		sampleWait = 0
		Sample()
		Judge()
		if announcements[1] then
			local ended = table.remove(announcements, 1)
			if Settings().paceBanner ~= false then
				Announce(ended)
			end
		end
	end
	if rate then
		shown = shown and shown + (rate - shown) * math.min(1, elapsed * 2) or rate
	else
		shown = nil
	end
end)

frame:SetScript("OnUpdate", function()
	Animate(arg1, AZS_GetPhase and AZS_GetPhase() == "playing")
end)

-- Shown during a run (on the tracker, so only while the tracker is).
local watcher = CreateFrame("Frame")
local watchWait = 0
watcher:SetScript("OnUpdate", function()
	watchWait = watchWait + arg1
	if watchWait < 0.5 then
		return
	end
	watchWait = 0
	if Settings().pace and Running() then
		frame:Show()
	else
		frame:Hide()
	end
end)

------------------------------------------------------------------------------
-- The tooltip: the numbers.

frame:SetScript("OnEnter", function()
	local state = TIERS[tier]
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText("Kill pace: "..state.label, state.color[1], state.color[2], state.color[3])
	if rate then
		GameTooltip:AddDoubleLine("Kills a minute, last "..Window().." sec", string.format("%.0f", rate), 0.8, 0.8, 0.8, 1, 1, 1)
	else
		GameTooltip:AddLine("Counting: a few seconds of the run first.", 0.8, 0.8, 0.8)
	end
	if AZS_RUN and AZS_RUN.en then
		GameTooltip:AddDoubleLine("Enemies alive now", AZS_RUN.en, 0.8, 0.8, 0.8, 1, 1, 1)
	end
	local coming = NextBoss()
	if coming and lastMark and AZS_RUN and AZS_RUN.kills then
		GameTooltip:AddDoubleLine("This stretch, to "..(coming.name or "the next boss"), Thousands(AZS_RUN.kills - lastMark).." kills", 0.8, 0.8, 0.8, 1, 1, 1)
		local stretchCount, _, stretchBest, stretchAverage = StretchReference(coming.index)
		if stretchCount > 0 then
			GameTooltip:AddDoubleLine("  your best / average on it", Thousands(stretchBest).." / "..Thousands(stretchAverage), 0.6, 0.6, 0.62, 1, 1, 1)
		end
	end
	local slowest, count, fastest, average, slowClass, fastClass = Reference()
	local zoneName = AZS_ZONE and AZS_ZONE.zname or "this zone"
	-- The run's four modifiers, each on its line: as the menu has them, harder
	-- in orange, easier in green, the others grey; the pace is held against
	-- runs with the same.
	local values, index = {}, 0
	for value in string.gfind(tostring(AZS_ZONE and AZS_ZONE.mods or ""), "%d+") do
		index = index + 1
		values[index] = tonumber(value)
	end
	if index > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Modifiers  |cff8a8a92(held against runs with the same)|r", 1, 0.82, 0)
		for place = 1, table.getn(MOD_NAMES) do
			local value = values[place] or 100
			local r, g, b = 0.62, 0.62, 0.66
			if value > 100 then
				r, g, b = 1.00, 0.58, 0.25
			elseif value < 100 then
				r, g, b = 0.40, 0.95, 0.45
			end
			GameTooltip:AddDoubleLine("  Enemy "..MOD_NAMES[place], value.."%", 0.8, 0.8, 0.8, r, g, b)
		end
	end
	local classOnly = Settings().paceClassOnly
	local what = classOnly and ((AZS_ZONE and AZS_ZONE.cname or "this class").." runs on "..zoneName)
		or ("runs on "..zoneName..", every class")
	GameTooltip:AddLine(" ")
	if slowest then
		GameTooltip:AddLine("Minute "..minute.." of your "..what..":", 0.8, 0.8, 0.8)
		if rate and fastest > 0 then
			GameTooltip:AddDoubleLine("Share of your fastest", string.format("%.0f%%", (shown or rate) / fastest * 100), 0.8, 0.8, 0.8, 1, 1, 1)
		end
		local blazing, fast, steady, slow = TIERS.blazing.color, TIERS.fast.color, TIERS.steady.color, TIERS.slow.color
		local fastText, slowText = string.format("%.0f", fastest), string.format("%.0f", slowest)
		if not classOnly then
			fastText = fastText.."  |cff9a9a9a"..ClassLabel(fastClass).."|r"
			slowText = slowText.."  |cff9a9a9a"..ClassLabel(slowClass).."|r"
		end
		GameTooltip:AddDoubleLine("Fastest", fastText, blazing[1], blazing[2], blazing[3], 1, 1, 1)
		GameTooltip:AddDoubleLine("Average", string.format("%.0f", average), steady[1], steady[2], steady[3], 1, 1, 1)
		GameTooltip:AddDoubleLine("Slowest", slowText, slow[1], slow[2], slow[3], 1, 1, 1)
		GameTooltip:AddDoubleLine("Runs held against", count, 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Red as slow as your slowest run at this minute, yellow in between, blue near your fastest, green as fast or faster.", MUTED[1], MUTED[2], MUTED[3], 1)
	else
		GameTooltip:AddLine("Held against your "..what.." at the same minute, once "..MinRuns().." of them have reached it ("..(count or 0).." so far).", MUTED[1], MUTED[2], MUTED[3], 1)
	end
	GameTooltip:AddLine(classOnly and "This class only: /sui pace class for every class." or "Every class: /sui pace class for this class only.", MUTED[1], MUTED[2], MUTED[3], 1)
	GameTooltip:Show()
end)
frame:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- On and off, forgetting, its place.

-- Kills a minute over the last Window() seconds, for This Run (RunPanel.lua);
-- nil until a few seconds in, or while the pace is off.
function SurvivorUI_PaceRate()
	if not Settings().pace then
		return nil, Window()
	end
	return rate, Window()
end

function SurvivorUI_TogglePace(argument)
	local settings = Settings()
	if argument == "class" then
		settings.paceClassOnly = not settings.paceClassOnly or nil
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the kill pace holds a run against "..(settings.paceClassOnly
			and "your runs of the same class on its zone." or "all your runs on its zone, every class's."))
		return
	end
	-- The options' Forget this zone's runs: the runs counted, asked once first.
	if argument == "ask" then
		local key = RunKey()
		local list = key and settings.paceRuns[key]
		local count = 0
		for _, each in pairs(list or {}) do
			if not settings.paceClassOnly or each.class == AZS_ZONE.class then
				count = count + 1
			end
		end
		if count == 0 or not SurvivorUI_Confirm then
			SurvivorUI_TogglePace("reset")
			return
		end
		local whose = settings.paceClassOnly and ((AZS_ZONE.cname or "this class").."'s") or "every class's"
		SurvivorUI_Confirm({
			title = "Forget this zone's runs?",
			text = "The kill pace forgets "..count..(count == 1 and " run" or " runs").." of "..(AZS_ZONE.zname or "this zone")
				.." ("..whose..", these modifiers). The runs from now on teach it again.",
			yes = "Forget",
			onYes = function() SurvivorUI_TogglePace("reset") end,
		})
		return
	end
	if argument == "reset" then
		local key = RunKey()
		local list = key and settings.paceRuns[key]
		if not list then
			DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the kill pace forgets a zone's runs during a run there, and has none of this one's.")
			return
		end
		-- The runs it holds against: this class's only, or the whole zone's.
		for index = table.getn(list), 1, -1 do
			if not settings.paceClassOnly or list[index].class == AZS_ZONE.class then
				table.remove(list, index)
			end
		end
		run, recording = nil, false
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the kill pace forgot your "..(settings.paceClassOnly and ((AZS_ZONE.cname or "").." ") or "")
			.."runs on "..(AZS_ZONE.zname or "this zone")..".")
		return
	end
	settings.pace = not settings.pace
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.pace
		and "the kill pace is on, right of the run tracker's clock."
		or "the kill pace is off."))
end

-- On the run tracker, right of its clock (the cache's coin is on its left):
-- it moves, sizes and hides with it.
local function Place()
	local tracker = getglobal("SurvivorUITracker")
	frame:ClearAllPoints()
	if tracker and tracker.clock then
		frame:SetParent(tracker)
		frame:SetFrameLevel(tracker:GetFrameLevel() + 3)
		frame:SetPoint("LEFT", tracker.clock, "RIGHT", 8, 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	Place()
end)
