-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: how many of each damage over time are out, and how many
-- enemies a fear holds, over the spell's button.
--
-- The game writes every tick ("Kobold Vermin suffers 18 Shadow damage from
-- your Shadow Word: Pain.") but not when a DoT ends on an enemy that dies, so
-- the DoTs are counted by their ticks: each one out ticks once a second (less,
-- with DoT Haste), so the ticks of the last two seconds say how many are out,
-- and an enemy that dies drops out on its own. Any spell that ticks counts,
-- with no list to keep.
--
-- A fear is not written at all, only its hit ("Your Psychic Scream hits Kobold
-- Vermin for 9"): each enemy it hits flees for its time (read off the button's
-- tooltip, "They flee for 3 sec", else the list below), so the enemies hit in
-- that time are the ones it holds. Bosses are left out: a fear does not take
-- them.
--
-- The totems are not written either, set down or ending: each cast is told by
-- its spell's cooldown starting over (AZS_SPELLS), and counts a totem for the
-- time its button's tooltip gives then ("Drops a totem beside you for 20
-- sec"), by the run's clock, so a pause stops it too. The shaman's talents
-- are not told to addons, but two say themselves in the spells a run starts
-- with: Searing Totem from the first second is Call of the Elements, every
-- totem set down with a second beside it (each cast counts two); Magma Totem
-- is Totemic Wrath, a Searing Totem more dropping on its own every 14 sec
-- (counted by the run's clock, as the game tells nothing of it).
--
-- A shout: Demoralizing Shout's hits are written, not its end, so the enemies
-- its last cast hit count for its time (its tooltip's "for 6 sec"), bosses
-- too; Battle Shout, a buff on the hero, shows the seconds it has left.
--
-- The number stands over the spell's action button, in the spell's damage
-- meter color, and goes once nothing is out; a totem's has the seconds until
-- the next one ends beside it. Each counter is on or off in the options
-- (Counters); /sui dots switches them all.

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WINDOW = 2        -- seconds of ticks a DoT's count is read over
local LINGER = 2.5      -- seconds without a tick before a DoT's number goes
local BASE = 1          -- seconds between two ticks of a DoT, before DoT Haste

-- The fears, and how long each holds when its tooltip does not say.
local FEARS = {
	["Psychic Scream"] = 3, ["Intimidating Shout"] = 3, ["Howl of Terror"] = 3, ["Fear"] = 3,
}
-- The shouts that weaken the enemies they hit, the same way.
local SHOUTS = { ["Demoralizing Shout"] = 6 }
-- The marks: a debuff laid on every enemy it hits, written as a hit, not its
-- end, so each enemy hit counts for the mark's time (its tooltip's "for N
-- sec", else this). Asked for by a druid (Faerie Fire) in 2026-10.
local MARKS = { ["Faerie Fire"] = 10 }

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.dotCounter == nil then
		SurvivorUIDB.dotCounter = true
	end
	return SurvivorUIDB
end

-- Each counter, on unless switched off: dotCounter, fearCounter, totemCounter,
-- shoutCounter, markCounter; none while the counters are off as a whole (the
-- Modules tab).
local function On(key)
	local settings = Settings()
	return settings.counters ~= false and settings[key] ~= false
end

local ticks = {}        -- [spell] = { the GetTime() of each DoT tick, oldest first }
local hits = {}         -- [fear] = { the GetTime() of each enemy it hit, oldest first }
local marks = {}        -- [mark] = the same, bosses too
local shouts = {}       -- [shout] = its last cast: { at, last hit, enemies hit }
local shown = {}        -- [spell] = the count on screen, eased toward the ticks'
local badges = {}       -- [action button] = its number

-- The seconds between two ticks: the base, quicker with DoT Haste.
local function Interval()
	local haste = tonumber(AZS_STATS and AZS_STATS.doth) or 0
	return BASE / (1 + math.max(0, haste))
end

-- How long a fear or a shout holds: its button's tooltip ("They flee for 3
-- sec", "deal 20% less damage for 6 sec"), read now and then, else the lists.
local scan = CreateFrame("GameTooltip", "SurvivorUIDotScan", nil, "GameTooltipTemplate")
local held, heldAt = {}, {}
local function Holds(spell)
	if heldAt[spell] and GetTime() - heldAt[spell] < 10 then
		return held[spell]
	end
	heldAt[spell] = GetTime()
	held[spell] = FEARS[spell] or SHOUTS[spell] or MARKS[spell]
	local button = SurvivorUI_SpellButton and SurvivorUI_SpellButton(spell)
	local _, _, slot = string.find(button and button:GetName() or "", "(%d+)$")
	if slot and scan.SetAction then
		scan:SetOwner(WorldFrame, "ANCHOR_NONE")
		scan:ClearLines()
		scan:SetAction(tonumber(slot))
		for index = 1, scan:NumLines() do
			local line = getglobal("SurvivorUIDotScanTextLeft"..index)
			local text = line and line:GetText() or ""
			local _, _, seconds = string.find(text, "flee for (%d+%.?%d*) sec")
			if not seconds then
				_, _, seconds = string.find(text, "less damage for (%d+%.?%d*) sec")
			end
			-- A mark's tooltip: the first "for N sec" it says.
			if not seconds and MARKS[spell] then
				_, _, seconds = string.find(text, "for (%d+%.?%d*) sec")
			end
			if seconds then
				held[spell] = tonumber(seconds)
			end
		end
	end
	return held[spell]
end

-- The bosses alive now, by name: a fear does not take them.
local function IsBoss(name)
	for _, unit in pairs(AZS_UNITS or {}) do
		local kind = unit.kind or unit[1]
		if (kind == "boss" or kind == "final") and (unit.name or unit[3]) == name then
			return true
		end
	end
end

local events = CreateFrame("Frame")
for _, name in pairs({ "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
		"CHAT_MSG_SPELL_SELF_DAMAGE" }) do
	events:RegisterEvent(name)
end
events:SetScript("OnEvent", function()
	if Settings().counters == false then
		return
	end
	local message = arg1 or ""
	if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
		-- "Your Psychic Scream hits Kobold Vermin for 9 Shadow damage." (or crits)
		local _, _, spell, target = string.find(message, "^Your (.-) hits (.-) for %d+")
		if not spell then
			_, _, spell, target = string.find(message, "^Your (.-) crits (.-) for %d+")
		end
		if spell and FEARS[spell] and On("fearCounter") and not IsBoss(target) then
			hits[spell] = hits[spell] or {}
			table.insert(hits[spell], GetTime())
		end
		-- A mark takes bosses too.
		if spell and MARKS[spell] and On("markCounter") then
			marks[spell] = marks[spell] or {}
			table.insert(marks[spell], GetTime())
		end
		-- A shout's hits come all at once: a hit long after the last is a new cast.
		if spell and SHOUTS[spell] and On("shoutCounter") then
			local now = GetTime()
			local cast = shouts[spell]
			if not cast or now - cast.last > 0.5 then
				cast = { at = now, last = now, count = 0 }
				shouts[spell] = cast
			end
			cast.last = now
			cast.count = cast.count + 1
		end
		return
	end
	local _, _, spell = string.find(message, " suffers %d+ .- from your (.-)%.")
	if spell and On("dotCounter") then
		ticks[spell] = ticks[spell] or {}
		table.insert(ticks[spell], GetTime())
	end
end)

local function Badge(button)
	local badge = badges[button]
	if badge then
		return badge
	end
	badge = button:CreateFontString(nil, "OVERLAY")
	badge:SetFont(SurvivorUI_FONT, 13 + FONT_BUMP, "THICKOUTLINE")
	badge:SetPoint("BOTTOM", button, "TOP", 0, 2)
	badge:Hide()
	-- A totem's: the seconds until the next one ends, small beside it.
	badge.timer = button:CreateFontString(nil, "OVERLAY")
	badge.timer:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	badge.timer:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 2, 1)
	badge.timer:SetTextColor(0.85, 0.85, 0.85)
	badge.timer:Hide()
	badges[button] = badge
	return badge
end

-- A spell's number over its button, in its meter color; a totem's with its
-- seconds left; no count (a buff's): the seconds left as the number.
local function Light(lit, spell, count, seconds)
	local button = SurvivorUI_SpellButton and SurvivorUI_SpellButton(spell)
	if not (button and button:IsVisible()) then
		return
	end
	local badge = Badge(button)
	-- At the size set in the options' Counters tab.
	local size = SurvivorUIDB and tonumber(SurvivorUIDB.counterSize) or 1
	if badge.size ~= size then
		badge.size = size
		badge:SetFont(SurvivorUI_FONT, math.floor(13 * size + 0.5) + FONT_BUMP, "THICKOUTLINE")
		badge.timer:SetFont(SurvivorUI_FONT, math.floor(9 * size + 0.5) + FONT_BUMP, "OUTLINE")
	end
	if count then
		badge:SetText(math.max(1, math.floor(count + 0.5)))
	else
		badge:SetText(math.ceil(seconds).."s")
	end
	local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(spell)
	if color then
		badge:SetTextColor(color[1], color[2], color[3])
	else
		badge:SetTextColor(1, 1, 1)
	end
	badge:Show()
	if count and seconds then
		badge.timer:SetText(math.ceil(seconds).."s")
		badge.timer:Show()
	else
		badge.timer:Hide()
	end
	lit[badge] = true
end

------------------------------------------------------------------------------
-- The totems, by their spells' cooldowns.

local totems = {}       -- [key] = { name, ends = { the run second each one ends } }
local kinds = {}        -- [key] = true for a totem, false for a spell that is not one
local lastCd = {}       -- [key] = its cooldown left at the last look
local spellsSeen        -- AZS_SPELLS_UPDATED at the last look
local lastRunTime
local started           -- this run's first spells looked at
local wrathDone         -- Totemic Wrath's drops counted, by 14 sec of the run
local WRATH_EVERY = 14

-- "searing_totem" as "Searing Totem".
local function Title(key)
	return (string.gsub(string.gsub(key, "_", " "), "(%a)(%a*)", function(first, rest)
		return string.upper(first)..rest
	end))
end

-- How long a totem stands, off its button's tooltip now: "Drops a totem
-- beside you for 20 sec". Nil for a spell that sets none.
local function TotemTime(slot)
	if not scan.SetAction then
		return nil
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetAction(slot)
	for index = 1, scan:NumLines() do
		local line = getglobal("SurvivorUIDotScanTextLeft"..index)
		local _, _, seconds = string.find(line and line:GetText() or "", "totem.- for (%d+%.?%d*) sec")
		if seconds then
			return tonumber(seconds)
		end
	end
end

local function RunTime()
	return AZS_GetRunTime and AZS_GetRunTime() or GetTime()
end

-- The talents the run's first spells told (Settings().totemStart), for this
-- hero: { twice = Call of the Elements, wrath = Totemic Wrath }.
local function Talents()
	local start = Settings().totemStart
	if start and start.hero == UnitName("player") then
		return start
	end
	return {}
end

-- Searing Totem's button, for its time: the racial on the twelfth, the rest in order.
local function SearingSlot()
	local count = table.getn(AZS_SPELLS or {})
	for index = 1, count do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == "searing_totem" then
			return SurvivorUI_SpellSlot and SurvivorUI_SpellSlot(index) or (index == count and 12 or index)
		end
	end
end

-- A totem set down now, for so many seconds, so many times.
local function SetDown(key, name, ends, copies)
	local totem = totems[key] or { name = name, ends = {} }
	for copy = 1, copies do
		table.insert(totem.ends, ends)
	end
	table.sort(totem.ends)
	totems[key] = totem
end

-- A cooldown that starts over is a cast: a totem's sets one down (two with
-- Call of the Elements); Totemic Wrath drops a Searing Totem every 14 sec.
local function WatchTotems()
	local now = RunTime()
	-- A new run: the clock went back.
	if lastRunTime and now + 3 < lastRunTime then
		totems, lastCd, started, wrathDone = {}, {}, nil, nil
	end
	lastRunTime = now
	local talents = Talents()
	if talents.wrath then
		local due = math.floor(now / WRATH_EVERY)
		-- Looked at first mid-run (a reload): the drops from before are let go.
		wrathDone = math.min(wrathDone or due, due)
		while wrathDone < due do
			wrathDone = wrathDone + 1
			local slot = SearingSlot()
			local seconds = slot and TotemTime(slot)
			if seconds then
				SetDown("searing_totem", "Searing Totem", wrathDone * WRATH_EVERY + seconds, 1)
			end
		end
	end
	if not AZS_SPELLS or AZS_SPELLS_UPDATED == spellsSeen then
		return
	end
	spellsSeen = AZS_SPELLS_UPDATED
	local count = table.getn(AZS_SPELLS)
	-- The run's first seconds: Searing Totem there from the start is Call of
	-- the Elements, Magma Totem Totemic Wrath.
	if not started and now < 5 then
		started = true
		local has = {}
		for index = 1, count do
			local entry = AZS_SPELLS[index]
			has[entry.key or entry[1] or ""] = true
		end
		Settings().totemStart = { hero = UnitName("player"), twice = has.searing_totem, wrath = has.magma_totem }
		talents = Talents()
	end
	for index = 1, count do
		local entry = AZS_SPELLS[index]
		local key = entry.key or entry[1]
		local cd = tonumber(entry.cd or entry[4])
		if key and cd then
			local before = lastCd[key]
			lastCd[key] = cd
			if before and cd > before + 0.5 and kinds[key] ~= false then
				-- Its button (Meter.lua): the twelfth for the racial, the rest
				-- in order, unless one was dragged elsewhere.
				local seconds = TotemTime(SurvivorUI_SpellSlot and SurvivorUI_SpellSlot(index) or (index == count and 12 or index))
				kinds[key] = seconds ~= nil
				if seconds then
					SetDown(key, Title(key), now + seconds, talents.twice and 2 or 1)
				end
			end
		end
	end
end

-- A buff of the hero's, by its spell's key: the seconds it has left, by the
-- run's clock since the game last told the buffs (it tells them on a change).
local buffsSeen, buffsAt
local function BuffLeft(key)
	if not (AZS_SPELLS and AZS_BUFFS) then
		return nil
	end
	local id
	for index = 1, table.getn(AZS_SPELLS) do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == key then
			id = tonumber(entry.spell or entry[2])
		end
	end
	if not id then
		return nil
	end
	if AZS_BUFFS_UPDATED ~= buffsSeen then
		buffsSeen, buffsAt = AZS_BUFFS_UPDATED, RunTime()
	end
	for index = 1, table.getn(AZS_BUFFS) do
		local entry = AZS_BUFFS[index]
		if tonumber(entry.spell or entry[1]) == id then
			local left = (tonumber(entry.left or entry[2]) or 0) - (RunTime() - buffsAt)
			return left > 0 and left or nil
		end
	end
end

local frame = CreateFrame("Frame")
local wait = 0
frame:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.1 then
		return
	end
	local elapsed = wait
	wait = 0
	-- Off as a whole: nothing counted, nothing shown.
	if Settings().counters == false then
		for _, badge in pairs(badges) do
			badge:Hide()
		end
		return
	end
	local now = GetTime()
	local on = On("dotCounter")
	local lit = {}
	-- The DoTs: their ticks of the last two seconds, eased.
	for spell, list in pairs(ticks) do
		while list[1] and list[1] < now - LINGER do
			table.remove(list, 1)
		end
		local recent = 0
		for index = table.getn(list), 1, -1 do
			if list[index] < now - WINDOW then
				break
			end
			recent = recent + 1
		end
		if on and list[1] then
			local count = recent / WINDOW * Interval()
			shown[spell] = shown[spell] and shown[spell] + (count - shown[spell]) * math.min(1, elapsed * 4) or count
			Light(lit, spell, shown[spell])
		else
			shown[spell] = nil
		end
	end
	-- The fears: the enemies hit within the time one holds.
	for spell, list in pairs(hits) do
		local holds = Holds(spell) or 3
		while list[1] and list[1] < now - holds do
			table.remove(list, 1)
		end
		if On("fearCounter") and list[1] then
			Light(lit, spell, table.getn(list))
		end
	end
	-- The marks: the enemies hit within the time one holds.
	for spell, list in pairs(marks) do
		local holds = Holds(spell) or MARKS[spell] or 10
		while list[1] and list[1] < now - holds do
			table.remove(list, 1)
		end
		if On("markCounter") and list[1] then
			Light(lit, spell, table.getn(list))
		end
	end
	-- The totems: the ones set down whose time has not run out.
	WatchTotems()
	if On("totemCounter") then
		local runNow = RunTime()
		for _, totem in pairs(totems) do
			while totem.ends[1] and totem.ends[1] <= runNow do
				table.remove(totem.ends, 1)
			end
			if totem.ends[1] then
				Light(lit, totem.name, table.getn(totem.ends), totem.ends[1] - runNow)
			end
		end
	end
	-- The shouts: the enemies Demoralizing Shout's last cast hit, while it
	-- holds; Battle Shout's seconds left.
	if On("shoutCounter") then
		for spell, cast in pairs(shouts) do
			if now - cast.at < (Holds(spell) or 6) then
				Light(lit, spell, cast.count)
			end
		end
		local left = BuffLeft("battle_shout")
		if left then
			Light(lit, "Battle Shout", nil, left)
		end
	end
	for _, badge in pairs(badges) do
		if not lit[badge] then
			badge:Hide()
			badge.timer:Hide()
		end
	end
end)

-- /sui dots: every counter at once, off while any is on, else on.
function SurvivorUI_ToggleDots()
	local settings = Settings()
	local on = not (On("dotCounter") or On("fearCounter") or On("totemCounter") or On("shoutCounter") or On("markCounter"))
	settings.dotCounter, settings.fearCounter, settings.totemCounter, settings.shoutCounter, settings.markCounter = on, on, on, on, on
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the counters over the action bar (DoTs, fears, totems, shouts, marks) are "..(on and "on." or "off."))
end
