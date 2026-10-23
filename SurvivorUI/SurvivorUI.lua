-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: unit frames and an action bar for Azeroth Survivors, in the
-- flat, dark manner of EllesmereUI. Everything sits in one centered row at the
-- bottom of the screen:
--
--   [portrait][ player ]  [1][2][3][4][5][6][=]  [ target ][portrait]
--
--   Unit frames: a health bar in the class color (red for an enemy) on a dark
--   backing with a thin black border, the name on the left, the health on the
--   right ("439K | 100%"), a slim power bar underneath and the portrait on the
--   outer end. The target's debuffs line up above its frame. They replace the
--   stock player and target frames.
--
--   Action bar: the game only uses the first bar. Buttons 1 to 6 and the last
--   button (the = key) make the middle of the row; the rest of the bar and its
--   art are put away. The experience bar becomes a thin strip under the row.
--
--   Also: the hero's buffs and debuffs above the player frame with time left
--   and stacks, cooldown numbers on the buttons, a square minimap, a flat
--   chat panel scrolled with the mouse wheel, and the micro buttons in the
--   bottom right corner, shown when the mouse reaches them.
--
--   Friz Quadrata on every piece of interface text, a flat tooltip, and small
--   quick damage numbers in place of the engine's (/sui damage switches back).
--
-- The row sits a little under the hero, who stands in the middle of the screen.
--
-- Left click a frame to target it, right click for its menu. Alt-drag either
-- frame to move the whole row.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
-- The interface's face, shared with the addon's other files: Friz Quadrata, the
-- game's own, unless a face is dropped in: Expressway in SurvivorUI\Fonts, or
-- Barlow Condensed in SurvivorUI\Media (neither is shipped).
-- A face that does not load leaves a font string without one, so each is tried
-- on a probe first, and Friz Quadrata, the game's own, is the last resort.
local FACES = {
	{ path = "Interface\\AddOns\\SurvivorUI\\Fonts\\Expressway.ttf", mark = "expressway" },
	{ path = "Interface\\AddOns\\SurvivorUI\\Media\\BarlowCondensed-Medium.ttf", mark = "barlow", bump = 1 },
}

local function FaceLoads(face)
	local probe = UIParent:CreateFontString(nil, "OVERLAY")
	probe:SetFont(face.path, 12)
	local got = probe:GetFont()
	return got and string.find(string.lower(got), face.mark, 1, true) ~= nil
end

SurvivorUI_FONT = "Fonts\\FRIZQT__.TTF"
SurvivorUI_FONT_BUMP = 0
for index = 1, table.getn(FACES) do
	if FaceLoads(FACES[index]) then
		SurvivorUI_FONT = FACES[index].path
		-- Barlow Condensed reads small at the same size: one point up.
		SurvivorUI_FONT_BUMP = FACES[index].bump or 0
		break
	end
end
-- The face found as the files ran: the global font's default (the options,
-- Global).
SurvivorUI_DEFAULT_FONT = SurvivorUI_FONT
local FONT_BUMP = SurvivorUI_FONT_BUMP

local BAR_BUTTONS = { 1, 2, 3, 4, 5, 6, 12 }     -- 12 is the = key
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local ROW_BELOW_CENTER = 150                    -- the row sits this far under the hero, who stands mid-screen
local SECTION_GAP = 6                           -- between a unit frame and the buttons

local FRAME_WIDTH = 150                         -- the bar part of a unit frame
local POWER_HEIGHT = 3
local HEALTH_HEIGHT = BUTTON_SIZE - POWER_HEIGHT - 1

local ENEMY = { 0.80, 0.22, 0.22 }

local CHAT_SIZE = 8                             -- default; /sui chat N changes it

-- Saved between sessions; the /sui command at the end of the file changes them.
-- Every look the addon gives the game's interface can be switched off in the
-- options panel (/sui opt): SurvivorUIDB.features[key] = false. Most take hold
-- at the next /reload, as they are laid on when the world loads.
function SurvivorUI_Feature(key)
	local features = SurvivorUIDB and SurvivorUIDB.features
	return not features or features[key] ~= false
end

function SurvivorUI_SetFeature(key, on)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.features = SurvivorUIDB.features or {}
	SurvivorUIDB.features[key] = on and true or false
end

local Feature = SurvivorUI_Feature

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.damageText == nil then
		SurvivorUIDB.damageText = true
	end
	-- From v2.8 the numbers beside the hero are the default: switched on once
	-- for everyone who has the addon's own numbers, and kept as each one sets
	-- them after that.
	if (SurvivorUIDB.damageDefaults or 0) < 2 then
		if SurvivorUIDB.damageText and not SurvivorUIDB.damageNone then
			SurvivorUIDB.damageSide = true
		end
	end
	-- From v2.9 the numbers beside the hero with icons are the default: once for everyone with
	-- the numbers beside the hero, kept as each one sets it after that.
	if (SurvivorUIDB.damageDefaults or 0) < 3 then
		SurvivorUIDB.damageDefaults = 3
		if SurvivorUIDB.damageText and SurvivorUIDB.damageSide and not SurvivorUIDB.damageNone then
			SurvivorUIDB.damageModern = true
		end
	end
	-- From v2.9 the chat's default is 10, not 12: the old default moves once.
	if (SurvivorUIDB.chatDefaults or 0) < 2 then
		SurvivorUIDB.chatDefaults = 2
		if SurvivorUIDB.chatSize == 12 then
			SurvivorUIDB.chatSize = nil
		end
	end
	SurvivorUIDB.chatSize = SurvivorUIDB.chatSize or CHAT_SIZE
	return SurvivorUIDB
end

-- The game sends its special enemies (AZS_UNITS) when the list changes, not
-- as a run begins: the list it sent last stays, and the guardians pulled in
-- the run before showed frozen in the next (the boss bars, the run tracker)
-- until a new one came. So each list is marked with the run's second it came
-- at; the run's clock gone back before it (a new run), or no run on (back in
-- the world), it is emptied until the game sends the next.
do
	local seen, seenAt
	local watch = CreateFrame("Frame")
	local wait = 0
	watch:SetScript("OnUpdate", function()
		wait = wait + arg1
		if wait < 0.25 then
			return
		end
		wait = 0
		local now = AZS_GetRunTime and AZS_GetRunTime()
		if AZS_UNITS_UPDATED ~= seen then
			seen, seenAt = AZS_UNITS_UPDATED, now
		end
		local phase = AZS_GetPhase and AZS_GetPhase()
		local stale = phase == "ready" or (now and seenAt and now + 3 < seenAt)
		if stale and AZS_UNITS and table.getn(AZS_UNITS) > 0 then
			AZS_UNITS = {}
		end
	end)
end

-- The game's own screens the addon puts its own in place of (the clock, the
-- boss bars, the minimap's flag, the Level Up! button...) are switched off by
-- the game's settings, which the game saves: left off, a game without the
-- addon would go on without them, two of them with no switch in its options.
-- So as the game closes or reloads, each one the addon switched off goes back
-- on, and the game's damage numbers too; at the next start each module
-- switches its own off again. Every call to AZS_SetHudShown is seen here
-- (this file loads first); each module's mark (hidGame...) covers the ones
-- switched off before this version.
do
	local gameSetHud = AZS_SetHudShown
	local switchedOff = {}
	local MARKS = {
		bosses = "hidGameBosses", build = "hidGameBuild", levels = "hidGameLevels", loot = "hidGameLoot",
		flag = "hidGameFlag", meter = "hidGameMeter", tally = "hidGameTally", clock = "hidGameClock",
	}
	if gameSetHud then
		AZS_SetHudShown = function(part, shown)
			if not part or part == "all" then
				for each in pairs(AZS_HUD_CVARS or {}) do
					switchedOff[each] = not shown or nil
				end
			else
				switchedOff[part] = not shown or nil
			end
			return gameSetHud(part, shown)
		end
	end
	local closing = CreateFrame("Frame")
	closing:RegisterEvent("PLAYER_LOGOUT")
	closing:SetScript("OnEvent", function()
		local db = SurvivorUIDB or {}
		if gameSetHud then
			for part, mark in pairs(MARKS) do
				if db[mark] then
					switchedOff[part] = true
				end
			end
			for part in pairs(switchedOff) do
				gameSetHud(part, true)
			end
		end
		-- The addon's numbers, or none, switch the game's off (ApplyDamageText).
		if db.damageText or db.damageNone then
			SetCVar("CombatDamage", "1")
		end
	end)
end

-- A time zone in hours as its name: "UTC", "UTC-3", "UTC+5:30".
function SurvivorUI_ZoneLabel(hours)
	hours = tonumber(hours) or 0
	if hours == 0 then
		return "UTC"
	end
	local sign = hours < 0 and "-" or "+"
	local whole = math.floor(math.abs(hours))
	local minutes = math.floor((math.abs(hours) - whole) * 60 + 0.5)
	return "UTC"..sign..whole..(minutes > 0 and string.format(":%02d", minutes) or "")
end

-- A tooltip's lines with their colors, to keep (the last runs, RunHistory.lua):
-- { l = left text, lc = its color, r = right text, rc = its color } each.
local function Color3(r, g, b)
	return { math.floor((r or 1) * 100 + 0.5) / 100, math.floor((g or 1) * 100 + 0.5) / 100, math.floor((b or 1) * 100 + 0.5) / 100 }
end

function SurvivorUI_ReadTooltip(tooltip)
	local name = tooltip:GetName()
	local lines = {}
	for index = 1, tooltip:NumLines() do
		local left = getglobal(name.."TextLeft"..index)
		local right = getglobal(name.."TextRight"..index)
		local line = {}
		if left and left:GetText() then
			line.l = left:GetText()
			line.lc = Color3(left:GetTextColor())
		end
		if right and right:IsShown() and right:GetText() and right:GetText() ~= "" then
			line.r = right:GetText()
			line.rc = Color3(right:GetTextColor())
		end
		table.insert(lines, line)
	end
	return lines
end

-- Kept lines shown again in GameTooltip, already owned and placed.
function SurvivorUI_ShowTooltipLines(lines)
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		local lc = line.lc or { 1, 1, 1 }
		if line.r then
			local rc = line.rc or { 1, 1, 1 }
			GameTooltip:AddDoubleLine(line.l or " ", line.r, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
		elseif index == 1 then
			GameTooltip:SetText(line.l or " ", lc[1], lc[2], lc[3], 1, 1)
		else
			GameTooltip:AddLine(line.l or " ", lc[1], lc[2], lc[3], 1)
		end
	end
	GameTooltip:Show()
end

-- A frame's tooltip as it would show now, read off GameTooltip without being
-- seen: its OnEnter run, the lines read, its OnLeave run, in one go.
function SurvivorUI_Photograph(frame)
	local enter = frame and frame:GetScript("OnEnter")
	if not enter then
		return nil
	end
	local before = this
	GameTooltip:Hide()
	this = frame
	local lines
	if pcall(enter) and GameTooltip:IsShown() and GameTooltip:NumLines() > 0 then
		lines = SurvivorUI_ReadTooltip(GameTooltip)
	end
	local leave = frame:GetScript("OnLeave")
	if leave then
		pcall(leave)
	end
	this = before
	GameTooltip:Hide()
	return lines
end

-- 1.12 paints shamans in the paladin's pink; they wear their modern blue here.
local CLASS_OVERRIDES = {
	SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
}

-- A class's color, as the unit frames wear it (the shaman's blue): r, g, b.
function SurvivorUI_ClassColor(class)
	local color = class and (CLASS_OVERRIDES[class] or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if color then
		return color.r, color.g, color.b
	end
	return 1, 0.82, 0
end

-- Two of the game's spells come in the combat log under another name than the
-- one its meter gives them, and SurvivorUI_SourceOf(name, line) gives the name
-- a hit's source goes by:
-- the Searing Totem's shots, as an "Attack" for Fire damage ("Your Attack
-- hits Scarlet Monk for 168 Fire damage."): with the totem among the hero's
-- spells, a Fire "Attack" is the totem's;
-- Call of Flame's blast, the totems exploding as they expire, as a "Fire
-- Nova" ("Your Fire Nova hits Core Hound for 3650 Fire damage."): with Call
-- of Flame among the hero's spells and no Fire Nova of its own, a Fire Nova
-- is Call of Flame's.
local keysSeen, keysHeld = nil, {}

-- Whether the hero has a spell, by its key in the game's list; the list read
-- again as it changes.
local function Holds(key)
	if AZS_SPELLS_UPDATED and AZS_SPELLS_UPDATED ~= keysSeen then
		keysSeen = AZS_SPELLS_UPDATED
		keysHeld = {}
		for index = 1, table.getn(AZS_SPELLS or {}) do
			local entry = AZS_SPELLS[index]
			keysHeld[entry.key or entry[1] or ""] = true
		end
	end
	return keysHeld[key]
end

-- The combat log can also name a spell at more length than the game's own
-- lists ("Fire Nova Totem" for the build's and the meter's Fire Nova): a name
-- that begins with one of the build's spells or the meter's lines, and a word
-- more, goes by that one, so its color, icon and crits are the same
-- everywhere. Found ones are kept; a name with none is asked again in a
-- while, as spells come during a run.
local KEY_NAMES = {
	sw_pain = "Shadow Word: Pain", pw_shield = "Power Word: Shield",
	demo_shout = "Demoralizing Shout", hunters_mark = "Hunter's Mark",
}
local shortOf, shortMissed = {}, {}

-- A spell's name from its key in the game's list, as the build list names it.
local function KeyName(key)
	if KEY_NAMES[key] then
		return KEY_NAMES[key]
	end
	local name = string.gsub(key or "", "_", " ")
	return (string.gsub(name, "(%a)([%w']*)", function(first, rest) return string.upper(first)..rest end))
end

local function ShortName(name)
	local known = shortOf[name]
	if known then
		return known
	end
	if shortMissed[name] and GetTime() - shortMissed[name] < 5 then
		return name
	end
	local best, exact
	local function Try(candidate)
		if not candidate or candidate == "" then
			return
		end
		if candidate == name then
			exact = true
		elseif string.sub(name, 1, string.len(candidate) + 1) == candidate.." "
			and (not best or string.len(candidate) > string.len(best)) then
			best = candidate
		end
	end
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		Try(KeyName(entry.key or entry[1]))
	end
	for index = 1, table.getn(AZS_METER or {}) do
		local lineName = AZS_METER[index].name
		Try(SurvivorUI_English and SurvivorUI_English(lineName) or lineName)
	end
	if exact then
		shortOf[name] = name
		return name
	end
	if best then
		shortOf[name] = best
		return best
	end
	shortMissed[name] = GetTime()
	return name
end

-- A warlock's demons' spells, which the combat log writes as the hero's own,
-- by the hero's own event ("Your Hellfire hits...", CHAT_MSG_SPELL_SELF_DAMAGE,
-- seen 2026-10-20), named as the meter counts them (the Imp's Fireball goes to
-- the Imp's bar, the Pit Lord's Searing Pain is its Felseeker, under the Pit
-- Lord's bar since the game's 0.105). The demon's when the hero doesn't hold
-- the spell; when the hero does, the two read the same: Biggest Crits tells
-- them apart by the hero's cooldown (RunPanel.lua, SurvivorUI_PetCast), the
-- rest keeps them the hero's.
local PET_CASTS = {
	["Fireball"] = { "fireball", "Imp's Fireball" },
	["Firebolt"] = { "firebolt", "Imp's Firebolt" },
	["Inferno"] = { "inferno", "Infernal's Inferno" },
	["Hellfire"] = { "hellfire", "Infernal's Hellfire" },
	["Searing Pain"] = { "searing_pain", "Pit Lord's Felseeker" },
	["Shadow Bolt"] = { "shadow_bolt", "Doomguard's Shadow Bolt" },
}

-- A demon's spell the hero holds too: its key and the demon's name for it
-- ("hellfire", "Infernal's Hellfire"); nil for any other name.
function SurvivorUI_PetCast(name)
	local cast = name and PET_CASTS[name]
	if cast and Holds(cast[1]) then
		return cast[1], cast[2]
	end
end

function SurvivorUI_SourceOf(name, line)
	if name == "Attack" and line and string.find(line, " Fire damage", 1, true) and Holds("searing_totem") then
		return "Searing Totem"
	end
	local cast = name and PET_CASTS[name]
	if cast and not Holds(cast[1]) then
		return cast[2]
	end
	if name == "Fire Nova" and Holds("call_of_flame") and not Holds("fire_nova") then
		return "Call of Flame"
	end
	if name then
		return ShortName(name)
	end
	return name
end

-- Each ability's biggest crit this run, and the run's biggest, kept in one
-- place for Biggest Crits (RunPanel.lua) and the combat numbers:
-- SurvivorUI_NoteCrit(amount, line) says whether a crit beats its ability's
-- own best, and whether it beats the run's biggest (a first only sets them),
-- the same answers to each that asks about the same line at the same moment,
-- whichever asks first.
local critBestBy, critTop = {}, nil
local noted, notedAt, notedRecord, notedTop

-- The ability a crit's line names, as Biggest Crits names it.
local function CritAbility(line)
	local _, _, ability = string.find(line, "^Your (.+) crits ")
	if ability then
		return ability
	end
	if string.find(line, "^You crit ") then
		return "Melee"
	end
	local _, _, owner, own = string.find(line, "^(.+)'s (.+) crits ")
	if own then
		-- A pet's own spell keeps its pet: "Imp's Fireball" (Meter.lua's pets).
		if SurvivorUI_IsPet and SurvivorUI_IsPet(owner) then
			return owner.."'s "..own
		end
		return own
	end
	local _, _, who = string.find(line, "^(.+) crits ")
	return who
end

function SurvivorUI_NoteCrit(amount, line)
	amount = tonumber(amount)
	if not (amount and line) then
		return false
	end
	local now = GetTime()
	if line == noted and now == notedAt then
		return notedRecord, notedTop
	end
	local record = false
	local ability = CritAbility(line)
	if ability then
		ability = SurvivorUI_SourceOf(ability, line)
		local best = critBestBy[ability]
		record = best ~= nil and amount > best
		if not best or amount > best then
			critBestBy[ability] = amount
		end
	end
	local top = critTop ~= nil and amount > critTop
	if not critTop or amount > critTop then
		critTop = amount
	end
	noted, notedAt, notedRecord, notedTop = line, now, record, top
	return record, top
end

function SurvivorUI_ResetCritRecord()
	critBestBy, critTop = {}, nil
end

-- The addon's own color, worn by its menus, its cards and its marks: the
-- hero's class color (gold until the class is known). One table, changed in
-- place, so whoever holds it reads the color of the moment;
-- SurvivorUI_OnAccent(paint) paints now and again on each change, for the
-- colors set once, as a frame is made.
SurvivorUI_ACCENT = { 1, 0.82, 0 }
local accentPainters = {}

function SurvivorUI_OnAccent(paint)
	table.insert(accentPainters, paint)
	paint()
end

function SurvivorUI_UpdateAccent()
	local r, g, b = 1, 0.82, 0
	if not (SurvivorUIDB and SurvivorUIDB.accent == "gold") then
		local _, class = UnitClass("player")
		if not class then
			return
		end
		r, g, b = SurvivorUI_ClassColor(class)
	end
	local accent = SurvivorUI_ACCENT
	if accent[1] == r and accent[2] == g and accent[3] == b then
		return
	end
	accent[1], accent[2], accent[3] = r, g, b
	for index = 1, table.getn(accentPainters) do
		accentPainters[index]()
	end
end

-- The class's color ("class") or the gold of before ("gold"): the options,
-- Global.
function SurvivorUI_SetAccent(mode)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.accent = mode == "gold" and "gold" or nil
	SurvivorUI_UpdateAccent()
end

local accentWatch = CreateFrame("Frame")
accentWatch:RegisterEvent("PLAYER_LOGIN")
accentWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
accentWatch:SetScript("OnEvent", SurvivorUI_UpdateAccent)
SurvivorUI_UpdateAccent()

local POWER_COLORS = {
	[0] = { 0.25, 0.50, 1.00 },   -- mana
	[1] = { 0.85, 0.20, 0.20 },   -- rage
	[2] = { 1.00, 0.55, 0.15 },   -- focus
	[3] = { 1.00, 0.90, 0.25 },   -- energy
}

------------------------------------------------------------------------------
-- Pieces

-- A thin black border: a flat texture one pixel larger than the frame.
local function AddBorder(frame)
	local border = frame:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(FLAT)
	border:SetVertexColor(0, 0, 0, 1)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	return border
end

local function AddBacking(frame, layer)
	local backing = frame:CreateTexture(nil, layer or "BORDER")
	backing:SetTexture(FLAT)
	backing:SetVertexColor(0.09, 0.09, 0.11, 1)
	backing:SetAllPoints(frame)
	return backing
end

local function FlatBar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)
	AddBorder(bar)
	AddBacking(bar)
	return bar
end

local function Text(parent, size, point, x, y)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, parent, point, x, y)
	return text
end

local function Hide(name)
	local object = getglobal(name)
	if object then
		object:Hide()
	end
end

-- One way to write a big number, everywhere in the addon: thousands k,
-- millions M, billions B, trillions T, three figures where they fit, the
-- trailing zeros dropped: 950, 4.9k, 12k, 282.7k, 1.11M, 9.27B, 10.3B, 1.5T.
local SIZES = { { 1000000000000, "T" }, { 1000000000, "B" }, { 1000000, "M" }, { 1000, "k" } }

local function Figures(scaled, decimals)
	local text = string.format("%."..decimals.."f", scaled)
	text = string.gsub(text, "(%.%d-)0+$", "%1")
	return (string.gsub(text, "%.$", ""))
end

function SurvivorUI_Abbrev(value)
	value = tonumber(value) or 0
	local sign = ""
	if value < 0 then
		sign, value = "-", -value
	end
	for index = 1, table.getn(SIZES) do
		local size = SIZES[index]
		if value >= size[1] then
			local scaled = value / size[1]
			local decimals = scaled < 10 and 2 or 1
			local step = decimals == 2 and 100 or 10
			scaled = math.floor(scaled * step + 0.5) / step
			-- 999,960 rounds to 1000k: the next size up says it.
			if scaled >= 1000 and index > 1 then
				size = SIZES[index - 1]
				scaled = math.floor(value / size[1] * 100 + 0.5) / 100
				decimals = 2
			end
			return sign..Figures(scaled, decimals)..size[2]
		end
	end
	return sign..tostring(math.floor(value + 0.5))
end

-- A health as an option reads it: "percent" 73%, "absolute" 1.2M, "both"
-- 1.2M / 3.4M, "absolutePercent" 1.2M | 73% (as the player's frame).
function SurvivorUI_HealthText(hp, hpm, style)
	hp, hpm = tonumber(hp) or 0, tonumber(hpm) or 0
	if style == "absolute" then
		return SurvivorUI_Abbrev(hp)
	elseif style == "both" then
		return SurvivorUI_Abbrev(hp).." / "..SurvivorUI_Abbrev(hpm)
	elseif style == "absolutePercent" then
		return SurvivorUI_Abbrev(hp).." | "..(hpm > 0 and math.floor(hp / hpm * 100 + 0.5) or 0).."%"
	end
	return (hpm > 0 and math.floor(hp / hpm * 100 + 0.5) or 0).."%"
end

------------------------------------------------------------------------------
-- The row: the buttons' holder is the anchor everything else hangs from.

local row = CreateFrame("Frame", "SurvivorUIRow", UIParent)
row:SetWidth(table.getn(BAR_BUTTONS) * (BUTTON_SIZE + BUTTON_GAP) - BUTTON_GAP)
row:SetHeight(BUTTON_SIZE)
row:SetPoint("CENTER", UIParent, "CENTER", 0, -ROW_BELOW_CENTER)
row:SetMovable(true)
row:SetFrameStrata("LOW")

-- A dark, bordered slot behind every button, so an empty one still reads as a
-- slot. These are frames of the row, not textures of the buttons: a texture
-- added to a button's own background layer draws over its icon.
row.slots = {}
for position = 1, table.getn(BAR_BUTTONS) do
	local slot = CreateFrame("Frame", nil, row)
	row.slots[position] = slot
	slot:SetWidth(BUTTON_SIZE)
	slot:SetHeight(BUTTON_SIZE)
	slot:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
	AddBorder(slot)
	AddBacking(slot)
end

------------------------------------------------------------------------------
-- Unit frames

local function HealthColor(unit)
	-- Players wear their class color; everything else on the field is an enemy.
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = class and (CLASS_OVERRIDES[class] or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
		if color then
			return color.r, color.g, color.b
		end
		return 0.6, 0.6, 0.6
	end
	return ENEMY[1], ENEMY[2], ENEMY[3]
end

-- side: "LEFT" puts the frame left of the buttons with its portrait on the far
-- left; "RIGHT" mirrors it.
local function UnitFrame(unit, name, side, dropdown)
	local left = side == "LEFT"

	local frame = CreateFrame("Button", name, UIParent)
	frame:SetWidth(FRAME_WIDTH + 1 + BUTTON_SIZE)
	frame:SetHeight(BUTTON_SIZE)
	if left then
		frame:SetPoint("RIGHT", row, "LEFT", -SECTION_GAP, 0)
	else
		frame:SetPoint("LEFT", row, "RIGHT", SECTION_GAP, 0)
	end
	frame.unit = unit

	frame.portrait = CreateFrame("Frame", nil, frame)
	frame.portrait:SetWidth(BUTTON_SIZE)
	frame.portrait:SetHeight(BUTTON_SIZE)
	frame.portrait:SetPoint(left and "LEFT" or "RIGHT", frame, left and "LEFT" or "RIGHT", 0, 0)
	AddBorder(frame.portrait)
	AddBacking(frame.portrait)
	frame.portrait.texture = frame.portrait:CreateTexture(nil, "ARTWORK")
	frame.portrait.texture:SetAllPoints(frame.portrait)
	-- The stock portrait is a disc; cropped in, it fills the square.
	frame.portrait.texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)

	frame.health = FlatBar(frame, FRAME_WIDTH, HEALTH_HEIGHT)
	frame.health:SetPoint(left and "TOPRIGHT" or "TOPLEFT", frame, left and "TOPRIGHT" or "TOPLEFT", 0, 0)

	frame.power = FlatBar(frame, FRAME_WIDTH, POWER_HEIGHT)
	frame.power:SetPoint("TOP", frame.health, "BOTTOM", 0, -1)

	-- The player's shield over the health (UpdateShield, below), and the name
	-- and the numbers a level over both.
	if unit == "player" then
		local shield = CreateFrame("Frame", nil, frame.health)
		shield:SetAllPoints(frame.health)
		shield:SetFrameLevel(frame.health:GetFrameLevel() + 1)
		shield.fill = shield:CreateTexture(nil, "BACKGROUND")
		shield.fill:SetTexture(FLAT)
		shield.fill:SetVertexColor(0.59, 0.82, 1, 0.45)
		shield.stripes = shield:CreateTexture(nil, "BORDER")
		shield.stripes:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\ShieldStripes")
		shield.edge = shield:CreateTexture(nil, "ARTWORK")
		shield.edge:SetTexture(FLAT)
		shield.edge:SetVertexColor(0.9, 0.97, 1, 1)
		shield:Hide()
		frame.shield = shield
	end
	frame.texts = CreateFrame("Frame", nil, frame.health)
	frame.texts:SetAllPoints(frame.health)
	frame.texts:SetFrameLevel(frame.health:GetFrameLevel() + 2)

	frame.name = Text(frame.texts, 10, "LEFT", 5, 0)
	-- The player's health reads "524 | 100%", a target's only "67%": the target's
	-- name gets the room the numbers leave.
	frame.nameRoom = unit == "player" and FRAME_WIDTH - 82 or FRAME_WIDTH - 44
	frame.name:SetWidth(frame.nameRoom)
	frame.name:SetHeight(12)
	frame.name:SetJustifyH("LEFT")
	frame.name:SetTextColor(1, 1, 1)

	frame.value = Text(frame.texts, 10, "RIGHT", -5, 0)
	frame.value:SetTextColor(1, 1, 1)

	-- Left click targets, right click opens the stock menu, Alt-drag moves the row.
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:SetScript("OnClick", function()
		if arg1 == "RightButton" and dropdown and getglobal(dropdown) then
			ToggleDropDownMenu(1, nil, getglobal(dropdown), "cursor")
		else
			TargetUnit(this.unit)
		end
	end)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() if IsAltKeyDown() then row:StartMoving() end end)
	frame:SetScript("OnDragStop", function() row:StopMovingOrSizing() end)
	return frame
end

local function UpdatePortrait(frame)
	if UnitExists(frame.unit) then
		SetPortraitTexture(frame.portrait.texture, frame.unit)
	end
end

-- What the shields on you still hold (AZS_RUN's sh, the game's), on the
-- health bar: from where the health ends, a bright edge at its end; past the
-- bar's end, over its right end instead, the edge where it begins. Over the
-- health of a light color (a priest's white, a rogue's yellow) the light
-- stripes would not show: there it goes deep blue, its stripes and edge dark.
local SHIELD_LOOKS = {
	light = { fill = { 0.59, 0.82, 1, 0.45 }, stripes = { 1, 1, 1, 1 }, edge = { 0.9, 0.97, 1, 1 } },
	dark = { fill = { 0.22, 0.5, 1, 0.6 }, stripes = { 0.08, 0.2, 0.55, 0.95 }, edge = { 0.06, 0.22, 0.65, 1 } },
}

local function ShieldLook(shield, look)
	if shield.look == look then
		return
	end
	shield.look = look
	local colors = SHIELD_LOOKS[look]
	shield.fill:SetVertexColor(colors.fill[1], colors.fill[2], colors.fill[3], colors.fill[4])
	shield.stripes:SetVertexColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], colors.stripes[4])
	shield.edge:SetVertexColor(colors.edge[1], colors.edge[2], colors.edge[3], colors.edge[4])
end

local function UpdateShield(frame, health, r, g, b)
	local shield = frame.shield
	local run = AZS_RUN or {}
	local most = tonumber(run.hpm) or 0
	local held = most > 0 and (tonumber(run.sh) or 0) / most or 0
	if held <= 0.002 then
		shield:Hide()
		return
	end
	held = math.min(1, held)
	local from, to, edge = health, health + held, health + held
	local over = false
	if to > 1 then
		from, to, edge, over = 1 - held, 1, 1 - held, true
	end
	ShieldLook(shield, over and (0.3 * r + 0.59 * g + 0.11 * b) > 0.75 and "dark" or "light")
	local bar = frame.health
	shield.fill:ClearAllPoints()
	shield.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", FRAME_WIDTH * from, 0)
	shield.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", FRAME_WIDTH * to, 0)
	shield.stripes:ClearAllPoints()
	shield.stripes:SetPoint("TOPLEFT", bar, "TOPLEFT", FRAME_WIDTH * from, 0)
	shield.stripes:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", FRAME_WIDTH * to, 0)
	shield.stripes:SetTexCoord(from, to, 0, 1)
	shield.edge:ClearAllPoints()
	shield.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", FRAME_WIDTH * edge - 1, 0)
	shield.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", FRAME_WIDTH * edge + 1, 0)
	shield:Show()
end

local function UpdateUnitFrame(frame)
	local unit = frame.unit
	if not UnitExists(unit) then
		frame:Hide()
		return
	end
	frame:Show()

	local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
	local share = healthMax > 0 and health / healthMax or 0
	local r, g, b = HealthColor(unit)
	frame.health:SetValue(share)
	frame.health:SetStatusBarColor(r, g, b, 1)
	if frame.shield then
		UpdateShield(frame, share, r, g, b)
	end
	-- The health as the option reads it (/sui opt, Unit frames): the player's
	-- "1.2k | 100%" by default, a target's "73%". The game's API has an enemy's
	-- numbers (AZS_TARGET); the client alone only its share. The name gets the
	-- room the numbers leave.
	local hp, hpm, style = health, healthMax, nil
	if unit == "player" then
		style = SurvivorUIDB and SurvivorUIDB.playerHealth or "absolutePercent"
	else
		style = SurvivorUIDB and SurvivorUIDB.targetHealth or "absolutePercent"
		if AZS_TARGET and AZS_TARGET.name == UnitName(unit) and (tonumber(AZS_TARGET.hpm) or 0) > 0 then
			hp, hpm = AZS_TARGET.hp, AZS_TARGET.hpm
		elseif healthMax == 100 then
			style = "percent"
		end
	end
	local room = FRAME_WIDTH - 44
	if style == "both" or style == "absolutePercent" then
		room = FRAME_WIDTH - 82
	elseif style == "absolute" then
		room = FRAME_WIDTH - 52
	end
	if room ~= frame.nameRoom then
		frame.nameRoom = room
		frame.shownName = nil
	end
	-- A name too long for its room goes by its first word, not cut short.
	local name = UnitName(unit) or ""
	if name ~= frame.shownName then
		frame.shownName = name
		frame.name:SetWidth(0)
		frame.name:SetText(name)
		if frame.name:GetStringWidth() > frame.nameRoom then
			local _, _, first = string.find(name, "^(%S+)")
			frame.name:SetText(first or name)
		end
		frame.name:SetWidth(frame.nameRoom)
	end

	if UnitIsDead(unit) or UnitIsGhost(unit) then
		-- Down in a co-op run (the game's 0.113): a friend can bring you back.
		frame.value:SetText((unit == "player" and SurvivorUI_IsDown and SurvivorUI_IsDown()) and "Down" or "Dead")
	else
		frame.value:SetText(SurvivorUI_HealthText(hp, hpm, style))
	end

	-- Rage has no bar here while the Bloodrage module shows it (SoulShards.lua):
	-- the health takes its room.
	local noPower = UnitPowerType(unit) == 1 and Feature("bloodrage")
	if noPower ~= frame.noPower then
		frame.noPower = noPower
		frame.health:SetHeight(noPower and BUTTON_SIZE or HEALTH_HEIGHT)
		if noPower then
			frame.power:Hide()
		else
			frame.power:Show()
		end
	end
	local power, powerMax = UnitMana(unit), UnitManaMax(unit)
	if powerMax > 0 then
		local color = POWER_COLORS[UnitPowerType(unit)] or POWER_COLORS[0]
		frame.power:SetValue(power / powerMax)
		frame.power:SetStatusBarColor(color[1], color[2], color[3], 1)
	else
		frame.power:SetValue(0)
	end
end

local player = UnitFrame("player", "SurvivorUIPlayer", "LEFT", "PlayerFrameDropDown")
local target = UnitFrame("target", "SurvivorUITarget", "RIGHT", "TargetFrameDropDown")

-- The target's debuffs, in a row above its frame.
local DEBUFFS = 8
local debuffs = {}
for index = 1, DEBUFFS do
	local icon = CreateFrame("Frame", nil, target)
	icon:SetWidth(18)
	icon:SetHeight(18)
	icon:SetPoint("BOTTOMLEFT", target, "TOPLEFT", (index - 1) * 21, 4)
	AddBorder(icon)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	icon.count = Text(icon, 9, "BOTTOMRIGHT", -1, 1)
	icon:Hide()
	debuffs[index] = icon
end

local function UpdateDebuffs()
	for index = 1, DEBUFFS do
		local texture, count = UnitDebuff("target", index)
		local icon = debuffs[index]
		if texture then
			icon.texture:SetTexture(texture)
			icon.count:SetText(count and count > 1 and count or "")
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local elapsed = 0
local unitUpdater = CreateFrame("Frame")
unitUpdater:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	UpdateUnitFrame(player)
	UpdateUnitFrame(target)
	if UnitExists("target") then
		UpdateDebuffs()
	end
end)

local function HideStockUnitFrames()
	for _, name in pairs({ "PlayerFrame", "TargetFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:UnregisterAllEvents()
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Action bar

-- Flat look: no rounded slot art and a cropped icon; the row's slot behind it
-- supplies the border.
local function StyleButton(button)
	local name = button:GetName()
	if not name then
		return
	end

	local normal = getglobal(name.."NormalTexture")
	if normal then
		normal:SetAlpha(0)
	end

	local icon = getglobal(name.."Icon")
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	if not button.survivorStyled then
		button.survivorStyled = true

		-- No key labels: the spells cast themselves. Made clear rather than hidden,
		-- since the stock code shows and fills them again on its own.
		local hotkey = getglobal(name.."HotKey")
		if hotkey then
			hotkey:SetAlpha(Feature("hideKeys") and 0 or 1)
		end
	end
end

-- The stock update puts the rounded slot art back; take it off again each time.
local stockActionButtonUpdate = ActionButton_Update
if stockActionButtonUpdate then
	ActionButton_Update = function()
		stockActionButtonUpdate()
		if this and this.survivorKept then
			StyleButton(this)
		end
	end
end

local function PlaceButton(prefix, id, position)
	local button = getglobal(prefix..id)
	if not button then
		return
	end

	button:ClearAllPoints()
	if position then
		button:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
		button.survivorKept = true
		StyleButton(button)
	else
		-- Off screen rather than hidden: the stock code shows buttons on its own.
		button:SetPoint("TOP", UIParent, "BOTTOM", 0, -600)
	end
end

local function LayoutBar()
	-- The bags: a run has nothing to keep in them, so B and Shift+B open none;
	-- with the action bar (Modules), as its bag buttons go.
	for _, name in pairs({ "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag", "OpenAllBags", "ToggleKeyRing" }) do
		if getglobal(name) then
			setglobal(name, function() end)
		end
	end

	local positions = {}
	for position = 1, table.getn(BAR_BUTTONS) do
		positions[BAR_BUTTONS[position]] = position
	end

	-- A stance bar's buttons, when a class has one, sit where the main bar's do.
	for id = 1, 12 do
		PlaceButton("ActionButton", id, positions[id])
		PlaceButton("BonusActionButton", id, positions[id])
	end

	for _, name in pairs({
		"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
		"MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
		"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber",
		"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
		"KeyRingButton", "MainMenuBarPerformanceBarFrame",
		"BonusActionBarTexture0", "BonusActionBarTexture1",
		"MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3",
		"ExhaustionTick",
		-- The game's 0.108 bar: a fifth slice of its art, and the racial's gold rim,
		-- which would follow the = button into the row.
		"AZS_MainMenuBarTexture4", "AZS_RacialRim",
	}) do
		Hide(name)
	end

	-- The game's bar itself, empty under the row: 397 wide since the game's
	-- 0.108, small enough for the hover outline to frame it, and its clicks
	-- went nowhere. It no longer takes the mouse; its buttons still do.
	for _, name in pairs({ "MainMenuBar", "MainMenuBarArtFrame" }) do
		local frame = getglobal(name)
		if frame and frame.EnableMouse then
			frame:EnableMouse(false)
		end
	end

	-- Its experience numbers, always up on the bar since the game's 0.108 (shown
	-- again at every change): kept away, the XP bar and the run tracker show them.
	local xpText = getglobal("MainMenuBarExpText")
	if xpText then
		xpText:Hide()
		xpText.Show = function() end
	end

	-- The bar the client puts in the experience bar's place at the top level
	-- (99), and the reputation bar: shown again by the stock code on every
	-- update, so kept away for good.
	for _, name in pairs({ "MainMenuBarMaxLevelBar", "ReputationWatchBar" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
			frame.Show = function() end
		end
	end

	-- The experience bar: a thin flat strip under the whole row.
	local xp = getglobal("MainMenuExpBar")
	if xp then
		xp:ClearAllPoints()
		xp:SetPoint("TOP", row, "BOTTOM", 0, -5)
		xp:SetWidth(row:GetWidth() + 2 * (SECTION_GAP + FRAME_WIDTH + 1 + BUTTON_SIZE))
		xp:SetHeight(4)
		xp:SetStatusBarTexture(FLAT)
		if not xp.survivorBorder then
			xp.survivorBorder = AddBorder(xp)
			xp.survivorBack = AddBacking(xp)
		end
	end
end

------------------------------------------------------------------------------
-- The hero's buffs and debuffs, in a row above the player frame, each with
-- its time left and its stacks. Right click a buff to cancel it.

local AURA_SIZE = 22
local AURA_MAX = 12

local function TimeText(seconds)
	if seconds >= 3600 then
		return math.floor(seconds / 3600 + 0.5).."h"
	elseif seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return math.floor(seconds)
	end
	return string.format("%.1f", seconds)
end

-- The buffs sit on a holder of their own, over the player frame, so they can be
-- moved apart from the middle block (Mover.lua).
local buffHolder = CreateFrame("Frame", "SurvivorUIBuffs", UIParent)
buffHolder:SetWidth(AURA_MAX * (AURA_SIZE + 3) - 3)
buffHolder:SetHeight(AURA_SIZE)
buffHolder:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 5)
buffHolder:SetMovable(true)

local auras = {}
for index = 1, AURA_MAX do
	local aura = CreateFrame("Button", nil, buffHolder)
	aura:SetWidth(AURA_SIZE)
	aura:SetHeight(AURA_SIZE)
	aura:SetPoint("BOTTOMLEFT", buffHolder, "BOTTOMLEFT", (index - 1) * (AURA_SIZE + 3), 0)
	aura.border = AddBorder(aura)

	aura.texture = aura:CreateTexture(nil, "ARTWORK")
	aura.texture:SetAllPoints(aura)
	aura.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	aura.time = Text(aura, 10, "CENTER", 0, 0)
	aura.time:SetTextColor(1, 0.95, 0.6)
	aura.count = Text(aura, 9, "BOTTOMRIGHT", -1, 1)

	aura:RegisterForClicks("RightButtonUp")
	aura:SetScript("OnClick", function() if this.helpful then CancelPlayerBuff(this.buffIndex) end end)
	aura:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetPlayerBuff(this.buffIndex)
	end)
	aura:SetScript("OnLeave", function() GameTooltip:Hide() end)
	aura:Hide()
	auras[index] = aura
end

local function UpdateAuras()
	local shown = 0
	for pass = 1, 2 do
		local filter = pass == 1 and "HELPFUL" or "HARMFUL"
		for slot = 0, 15 do
			local buffIndex = GetPlayerBuff(slot, filter)
			if buffIndex and buffIndex >= 0 and shown < AURA_MAX then
				shown = shown + 1
				local aura = auras[shown]
				aura.buffIndex = buffIndex
				aura.helpful = pass == 1
				aura.texture:SetTexture(GetPlayerBuffTexture(buffIndex))

				-- A debuff wears a red border.
				if pass == 1 then
					aura.border:SetVertexColor(0, 0, 0, 1)
				else
					aura.border:SetVertexColor(0.85, 0.10, 0.10, 1)
				end

				local left = GetPlayerBuffTimeLeft(buffIndex)
				aura.time:SetText(left and left > 0 and TimeText(left) or "")

				local count = GetPlayerBuffApplications(buffIndex)
				aura.count:SetText(count and count > 1 and count or "")
				aura:Show()
			end
		end
	end
	for index = shown + 1, AURA_MAX do
		auras[index]:Hide()
	end
end

local auraElapsed = 0
local auraUpdater = CreateFrame("Frame")
auraUpdater:SetScript("OnUpdate", function()
	auraElapsed = auraElapsed + arg1
	if auraElapsed >= 0.1 then
		auraElapsed = 0
		UpdateAuras()
	end
end)

local function HideStockBuffs()
	for _, name in pairs({ "BuffFrame", "TemporaryEnchantFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Cooldown numbers on the action buttons. OmniCC does the same job; with it
-- installed, this stands aside.

if CooldownFrame_SetTimer and not OmniCC_OnUpdate then
	local stockSetTimer = CooldownFrame_SetTimer

	-- The last two seconds count down in red.
	local function CounterUpdate()
		local left = this.start + this.duration - GetTime()
		if left <= 0 then
			this:Hide()
			return
		end
		this.text:SetText(TimeText(left))
		-- A short cooldown (shown when asked) is always nearly done: no red.
		local soon = left <= 2 and this.duration > 1.5
		if soon ~= this.soon then
			this.soon = soon
			if soon then
				this.text:SetTextColor(1, 0.25, 0.25)
			else
				this.text:SetTextColor(1, 0.95, 0.6)
			end
		end
	end

	CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
		stockSetTimer(cooldown, start, duration, enable)

		local parent = cooldown and cooldown:GetParent()
		if not parent then
			return
		end
		if not Feature("cooldownNumbers") then
			if parent.survivorCounter then
				parent.survivorCounter:Hide()
			end
			return
		end

		local counter = parent.survivorCounter
		if not counter then
			counter = CreateFrame("Frame", nil, parent)
			counter:SetAllPoints(parent)
			counter:SetFrameLevel(cooldown:GetFrameLevel() + 3)
			-- A button cooling down is dimmed under its count.
			counter.dim = counter:CreateTexture(nil, "BACKGROUND")
			counter.dim:SetTexture(FLAT)
			counter.dim:SetVertexColor(0, 0, 0, 0.45)
			counter.dim:SetAllPoints(counter)
			counter.text = Text(counter, 14, "CENTER", 0, 0)
			counter.text:SetTextColor(1, 0.95, 0.6)
			counter:SetScript("OnUpdate", CounterUpdate)
			parent.survivorCounter = counter
		end

		-- Every cooldown counts, the short ones much haste makes too; unless the
		-- options say otherwise (Frames & bar), which leaves out any of 1.5 s or
		-- less, the global cooldown's flicker with them.
		local shortest = SurvivorUIDB and SurvivorUIDB.shortCooldowns == false and 1.5 or 0
		if start and start > 0 and duration and duration > shortest and enable and enable > 0 then
			counter.start, counter.duration = start, duration
			counter:Show()
		else
			counter:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- A square minimap with a thin border, zoomed with the mouse wheel.

-- The minimap clock's time, and its setter: a click on the time opens a box
-- by the minimap with the time as the clock shows it, large, and a slider of
-- the time zone; moved until that time is the player's own, it is set (the
-- same time zone as This Run's, which dates Run History too).
do
	-- The time now as the clock shows it: the game's clock (UTC) moved by the
	-- time zone set, 24 or 12 hours; and whether a time zone is set at all.
	function SurvivorUI_ClockText()
		local db = SurvivorUIDB or {}
		local hours = tonumber(db.timeZone)
		local now = time() + (hours or 0) * 3600
		local hour, minute = math.floor(math.mod(now, 86400) / 3600), math.floor(math.mod(now, 3600) / 60)
		if db.clock12 then
			return string.format("%d:%02d %s", math.mod(hour + 11, 12) + 1, minute, hour < 12 and "am" or "pm"), hours ~= nil
		end
		return string.format("%02d:%02d", hour, minute), hours ~= nil
	end

	local LOW, HIGH, STEP = -12, 14, 0.5
	local GOLD, MUTED = { 1, 0.82, 0 }, { 0.6, 0.6, 0.65 }
	local setter

	local function TextButton(parent, label, onClick)
		local button = CreateFrame("Button", nil, parent)
		button:SetHeight(16)
		button.text = Text(button, 11, "CENTER", 0, 0)
		button.text:SetText(label)
		button:SetWidth(button.text:GetStringWidth() + 12)
		button:SetScript("OnClick", onClick)
		button:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
		button:SetScript("OnLeave", function() this:Paint() end)
		function button:Paint()
			local color = self.lit and GOLD or MUTED
			self.text:SetTextColor(color[1], color[2], color[3])
		end
		return button
	end

	local function Refresh()
		local text, set = SurvivorUI_ClockText()
		local hours = tonumber(SurvivorUIDB and SurvivorUIDB.timeZone)
		setter.time:SetText(text)
		setter.zone:SetText(set and (SurvivorUI_ZoneLabel and SurvivorUI_ZoneLabel(hours) or tostring(hours))
			or "UTC, the game's clock: no time zone set yet")
		local value = hours or 0
		setter.fill:SetWidth(math.max(1, (setter.slider:GetWidth() - 8) * (value - LOW) / (HIGH - LOW) + 4))
		setter.h24.lit = not (SurvivorUIDB and SurvivorUIDB.clock12)
		setter.h12.lit = not setter.h24.lit
		setter.h24:Paint()
		setter.h12:Paint()
		-- The strip under the minimap at once, not at its next half second.
		local strip = getglobal("SurvivorUIMinimapClock")
		if strip then
			strip.counted = 1
		end
	end

	local function SetZone(value)
		SurvivorUIDB = SurvivorUIDB or {}
		SurvivorUIDB.timeZone = math.max(LOW, math.min(HIGH, math.floor(value / STEP + 0.5) * STEP))
		Refresh()
	end

	local function Build()
		setter = CreateFrame("Frame", "SurvivorUIClockSetter", UIParent)
		setter:SetWidth(240)
		setter:SetHeight(168)
		setter:SetFrameStrata("DIALOG")
		setter:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		setter:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
		setter:SetBackdropBorderColor(0, 0, 0, 1)
		setter:EnableMouse(true)
		if setter.SetClampedToScreen then
			setter:SetClampedToScreen(true)
		end
		-- Escape closes it, as the game's own boxes.
		if UISpecialFrames then
			table.insert(UISpecialFrames, "SurvivorUIClockSetter")
		end

		local title = Text(setter, 12, "TOPLEFT", 10, -8)
		title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		title:SetText("Your time")
		local close = TextButton(setter, "x", function() setter:Hide() end)
		close:SetPoint("TOPRIGHT", setter, "TOPRIGHT", -4, -5)
		close:Paint()

		setter.time = Text(setter, 26, "TOP", 0, -30)
		setter.zone = Text(setter, 10, "TOP", 0, -64)
		setter.zone:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

		-- The slider, in the options' look, with a step each way beside it.
		local slider = CreateFrame("Slider", nil, setter)
		slider:SetOrientation("HORIZONTAL")
		slider:SetWidth(170)
		slider:SetHeight(14)
		slider:SetPoint("TOP", setter, "TOP", 0, -84)
		slider:SetMinMaxValues(LOW, HIGH)
		slider:SetValueStep(STEP)
		slider:EnableMouseWheel(true)
		local track = slider:CreateTexture(nil, "BACKGROUND")
		track:SetTexture(FLAT)
		track:SetVertexColor(0.14, 0.14, 0.18, 1)
		track:SetHeight(4)
		track:SetPoint("LEFT", slider, "LEFT", 0, 0)
		track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
		setter.fill = slider:CreateTexture(nil, "BORDER")
		setter.fill:SetTexture(FLAT)
		setter.fill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
		setter.fill:SetHeight(4)
		setter.fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetTexture(FLAT)
		thumb:SetWidth(8)
		thumb:SetHeight(14)
		slider:SetThumbTexture(thumb)
		slider:SetScript("OnValueChanged", function()
			if not this.quiet then
				SetZone(this:GetValue())
			end
		end)
		slider:SetScript("OnMouseWheel", function()
			this:SetValue(this:GetValue() + arg1 * STEP)
		end)
		setter.slider = slider
		local function Nudge(by)
			slider:SetValue((tonumber(SurvivorUIDB and SurvivorUIDB.timeZone) or 0) + by)
		end
		local less = TextButton(setter, "-", function() Nudge(-STEP) end)
		less:SetPoint("RIGHT", slider, "LEFT", -4, 0)
		less.lit = true
		less:Paint()
		local more = TextButton(setter, "+", function() Nudge(STEP) end)
		more:SetPoint("LEFT", slider, "RIGHT", 4, 0)
		more.lit = true
		more:Paint()

		setter.h24 = TextButton(setter, "24 hours", function()
			SurvivorUIDB = SurvivorUIDB or {}
			SurvivorUIDB.clock12 = nil
			Refresh()
		end)
		setter.h24:SetPoint("TOPRIGHT", setter, "TOP", -2, -106)
		setter.h12 = TextButton(setter, "12 hours", function()
			SurvivorUIDB = SurvivorUIDB or {}
			SurvivorUIDB.clock12 = true
			Refresh()
		end)
		setter.h12:SetPoint("TOPLEFT", setter, "TOP", 2, -106)

		local note = Text(setter, 9, "BOTTOM", 0, 8)
		note:SetWidth(220)
		note:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		note:SetText("Slide until the time above is yours. The game's clock runs in UTC; this time zone also dates Run History.")

		-- The minutes go on while it is open.
		setter.wait = 0
		setter:SetScript("OnUpdate", function()
			this.wait = this.wait + arg1
			if this.wait >= 1 then
				this.wait = 0
				Refresh()
			end
		end)
	end

	-- A click on the minimap's time: the box opens beside the minimap, or closes.
	function SurvivorUI_ToggleClockSetter()
		if not setter then
			Build()
		end
		if setter:IsShown() then
			setter:Hide()
			return
		end
		setter:ClearAllPoints()
		setter:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -10, 0)
		setter.slider.quiet = true
		setter.slider:SetValue(tonumber(SurvivorUIDB and SurvivorUIDB.timeZone) or 0)
		setter.slider.quiet = nil
		Refresh()
		setter:Show()
	end
end

local function SquareMinimap()
	if not Minimap then
		return
	end

	-- A solid texture as the mask leaves the whole square visible.
	Minimap:SetMaskTexture(FLAT)

	for _, name in pairs({
		"MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
		"MinimapToggleButton", "GameTimeFrame", "MiniMapWorldMapButton",
	}) do
		Hide(name)
	end

	if not Minimap.survivorBorder then
		local edge = CreateFrame("Frame", nil, Minimap)
		edge:SetAllPoints(Minimap)
		edge:SetFrameLevel(Minimap:GetFrameLevel() + 2)
		for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local line = edge:CreateTexture(nil, "OVERLAY")
			line:SetTexture(FLAT)
			line:SetVertexColor(0, 0, 0, 1)
			if side == "TOP" or side == "BOTTOM" then
				line:SetHeight(1)
				line:SetPoint(side.."LEFT", edge, side.."LEFT", -1, side == "TOP" and 1 or -1)
				line:SetPoint(side.."RIGHT", edge, side.."RIGHT", 1, side == "TOP" and 1 or -1)
			else
				line:SetWidth(1)
				line:SetPoint("TOP"..side, edge, "TOP"..side, side == "LEFT" and -1 or 1, 1)
				line:SetPoint("BOTTOM"..side, edge, "BOTTOM"..side, side == "LEFT" and -1 or 1, -1)
			end
		end
		Minimap.survivorBorder = edge

		Minimap:EnableMouseWheel(true)
		Minimap:SetScript("OnMouseWheel", function()
			if arg1 > 0 then
				Minimap:SetZoom(math.min(Minimap:GetZoomLevels() - 1, Minimap:GetZoom() + 1))
			else
				Minimap:SetZoom(math.max(0, Minimap:GetZoom() - 1))
			end
		end)

		-- Along its bottom, inside: the time and the frames a second (the
		-- options, Minimap: on unless switched off, 24 or 12 hours). The game's
		-- clock runs in UTC, so the time takes the time zone set in This Run,
		-- "UTC" beside it while none is; the game has no GetFramerate, so the
		-- frames are counted here, one OnUpdate a frame. Under the pins.
		local strip = CreateFrame("Frame", "SurvivorUIMinimapClock", Minimap)
		strip:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)
		strip:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
		strip:SetHeight(14)
		strip:SetFrameLevel(Minimap:GetFrameLevel() + 3)
		strip.shade = strip:CreateTexture(nil, "BACKGROUND")
		strip.shade:SetTexture(FLAT)
		strip.shade:SetVertexColor(0, 0, 0, 0.55)
		strip.shade:SetAllPoints(strip)
		strip.clock = Text(strip, 10, "LEFT", 4, 0)
		strip.fps = Text(strip, 10, "RIGHT", -4, 0)
		strip.frames, strip.counted = 0, 0.5
		-- A click on the time: the box to set it (SurvivorUI_ToggleClockSetter).
		strip.button = CreateFrame("Button", nil, strip)
		strip.button:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
		strip.button:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
		strip.button:SetWidth(76)
		strip.button:SetFrameLevel(strip:GetFrameLevel() + 3)
		-- A gold edge around the time while the mouse is over it: it takes a click.
		strip.button.edges = {}
		for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local line = strip.button:CreateTexture(nil, "OVERLAY")
			line:SetTexture(FLAT)
			line:SetVertexColor(1, 0.82, 0, 0.9)
			if side == "TOP" or side == "BOTTOM" then
				line:SetHeight(1)
				line:SetPoint(side.."LEFT", strip.button, side.."LEFT", 0, 0)
				line:SetPoint(side.."RIGHT", strip.button, side.."RIGHT", 0, 0)
			else
				line:SetWidth(1)
				line:SetPoint("TOP"..side, strip.button, "TOP"..side, 0, 0)
				line:SetPoint("BOTTOM"..side, strip.button, "BOTTOM"..side, 0, 0)
			end
			line:Hide()
			table.insert(strip.button.edges, line)
		end
		strip.button:SetScript("OnClick", function()
			if SurvivorUI_ToggleClockSetter then
				SurvivorUI_ToggleClockSetter()
			end
		end)
		strip.button:SetScript("OnEnter", function()
			for _, line in pairs(this.edges) do
				line:Show()
			end
			GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetText("Your time", 1, 0.82, 0)
			GameTooltip:AddLine("Click to set it: the game's clock runs in UTC, so the time takes your time zone.", 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		strip.button:SetScript("OnLeave", function()
			for _, line in pairs(this.edges) do
				line:Hide()
			end
			GameTooltip:Hide()
		end)
		strip:SetScript("OnUpdate", function()
			this.frames = this.frames + 1
			this.counted = this.counted + arg1
			if this.counted < 0.5 then
				return
			end
			local fps = this.frames / this.counted
			this.frames, this.counted = 0, 0
			local db = SurvivorUIDB or {}
			if db.minimapClock == false then
				this.shade:Hide()
				this.button:Hide()
				this.clock:SetText("")
				this.fps:SetText("")
				return
			end
			this.shade:Show()
			this.button:Show()
			local text, set = SurvivorUI_ClockText()
			this.clock:SetText(text..(set and "" or " |cff8a8a8aUTC|r"))
			-- The click's place, and its edge, as wide as the time.
			this.button:SetWidth(math.max(24, this.clock:GetStringWidth() + 8))
			local color = fps >= 60 and "66ff66" or (fps >= 30 and "ffd100" or "ff5050")
			this.fps:SetText("|cff"..color..math.floor(fps + 0.5).."|r |cff8a8a8afps|r")
		end)
	end
end

------------------------------------------------------------------------------
-- The micro buttons (character, talents, map, menu, help) go to the bottom
-- left corner, under the chat: the bottom right one is the damage meter's.
-- The others are chained to the first, so moving it moves all.

local function MoveMicroButtons()
	local first = getglobal("CharacterMicroButton")
	if first then
		first:ClearAllPoints()
		first:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 2)
	end
end

------------------------------------------------------------------------------
-- The micro buttons stay out of sight until the mouse reaches their corner.

local MICRO_BUTTONS = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
	"SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton",
}

local microZone = CreateFrame("Frame", "SurvivorUIMicroZone", UIParent)
microZone:SetWidth(170)
microZone:SetHeight(60)
microZone:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)

local microAlpha = 0
microZone:SetScript("OnUpdate", function()
	local want = MouseIsOver(this) and 1 or 0
	if microAlpha == want then
		return
	end

	-- A quick fade either way.
	local step = arg1 * 6
	if want > microAlpha then
		microAlpha = math.min(1, microAlpha + step)
	else
		microAlpha = math.max(0, microAlpha - step)
	end
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(microAlpha)
		end
	end
end)

local function HideMicroButtons()
	microAlpha = 0
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(0)
		end
	end
end

------------------------------------------------------------------------------
-- Chat: no scroll buttons, no tab art, the text on the world itself; a flat
-- dark panel behind it only if asked for (the options, Chat: Background, with
-- the addon's color down its left edge). The mouse wheel scrolls; with Shift
-- held it jumps to the top or the bottom.

-- The panel's strength, 0 (none, the default) to 1.
local function ChatBackground()
	return tonumber(Settings().chatBackground) or 0
end

local function ApplyChatBackground()
	local strength = ChatBackground()
	for index = 1, 7 do
		local chat = getglobal("ChatFrame"..index)
		local panel = chat and chat.survivorPanel
		if panel then
			panel.fill:SetVertexColor(0.04, 0.04, 0.06, strength)
			if strength > 0 then
				panel.accent:Show()
			else
				panel.accent:Hide()
			end
		end
	end
end

function SurvivorUI_ChatBackground()
	return ChatBackground()
end

function SurvivorUI_SetChatBackground(strength)
	Settings().chatBackground = strength
	ApplyChatBackground()
end

local function ChatWheel()
	if arg1 > 0 then
		if IsShiftKeyDown() then
			this:ScrollToTop()
		else
			this:ScrollUp()
		end
	else
		if IsShiftKeyDown() then
			this:ScrollToBottom()
		else
			this:ScrollDown()
		end
	end
end

local function StyleChat()
	Hide("ChatFrameMenuButton")

	for index = 1, 7 do
		local name = "ChatFrame"..index
		local chat = getglobal(name)
		if chat then
			Hide(name.."UpButton")
			Hide(name.."DownButton")
			Hide(name.."BottomButton")

			-- Plain text with a soft shadow in place of the stock look.
			chat:SetFont(SurvivorUI_FONT, Settings().chatSize)
			chat:SetShadowColor(0, 0, 0, 1)
			chat:SetShadowOffset(1, -1)

			chat:EnableMouseWheel(true)
			chat:SetScript("OnMouseWheel", ChatWheel)

			if not chat.survivorPanel then
				local panel = CreateFrame("Frame", nil, chat)
				panel:SetPoint("TOPLEFT", chat, "TOPLEFT", -6, 6)
				panel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 6, -6)
				panel:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
				local fill = panel:CreateTexture(nil, "BACKGROUND")
				fill:SetTexture(FLAT)
				fill:SetAllPoints(panel)
				panel.fill = fill
				-- An accent line down the left edge, in the addon's color.
				local accent = panel:CreateTexture(nil, "BORDER")
				accent:SetTexture(FLAT)
				SurvivorUI_OnAccent(function()
					local color = SurvivorUI_ACCENT
					accent:SetVertexColor(color[1], color[2], color[3], 0.8)
				end)
				accent:SetWidth(2)
				accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
				accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
				panel.accent = accent
				chat.survivorPanel = panel
			end

			-- The tab keeps its text and loses its art.
			for _, piece in pairs({ "Left", "Middle", "Right" }) do
				local art = getglobal(name.."Tab"..piece)
				if art then
					art:SetTexture("")
				end
			end
			local tabText = getglobal(name.."TabText")
			if tabText then
				tabText:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
			end
		end
	end

	ApplyChatBackground()

	-- The edit box: a flat field under the chat.
	local edit = getglobal("ChatFrameEditBox")
	if edit then
		for _, piece in pairs({ "Left", "Mid", "Right" }) do
			local art = getglobal("ChatFrameEditBox"..piece)
			if art then
				art:SetTexture("")
			end
		end
		if not edit.survivorBack then
			edit.survivorBack = edit:CreateTexture(nil, "BACKGROUND")
			edit.survivorBack:SetTexture(FLAT)
			edit.survivorBack:SetVertexColor(0.04, 0.04, 0.06, 0.8)
			edit.survivorBack:SetPoint("TOPLEFT", edit, "TOPLEFT", 4, -5)
			edit.survivorBack:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -4, 5)
		end
	end
end

------------------------------------------------------------------------------
-- One face everywhere (SurvivorUI_FONT). The stock interface mixes several:
-- Friz Quadrata for most things, others for chat, numbers, quest and mail text.

-- Read by the engine when the world loads, for the text it draws itself.
STANDARD_TEXT_FONT = SurvivorUI_FONT
UNIT_NAME_FONT = SurvivorUI_FONT
NAMEPLATE_FONT = SurvivorUI_FONT
DAMAGE_TEXT_FONT = SurvivorUI_FONT

local FONT_OBJECTS = {
	"GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontGreen", "GameFontRed", "GameFontBlack", "GameFontWhite",
	"GameFontNormalSmall", "GameFontHighlightSmall", "GameFontHighlightSmallOutline", "GameFontDisableSmall",
	"GameFontDarkGraySmall", "GameFontGreenSmall", "GameFontRedSmall",
	"GameFontNormalLarge", "GameFontHighlightLarge", "GameFontDisableLarge", "GameFontGreenLarge", "GameFontRedLarge",
	"GameFontNormalHuge",
	"NumberFontNormal", "NumberFontNormalYellow", "NumberFontNormalSmall", "NumberFontNormalSmallGray",
	"NumberFontNormalLarge", "NumberFontNormalHuge",
	"ChatFontNormal", "ChatFontSmall", "CombatLogFont",
	"QuestTitleFont", "QuestFont", "QuestFontNormalSmall", "QuestFontHighlight",
	"ItemTextFontNormal", "MailTextFontNormal", "InvoiceTextFontNormal", "InvoiceTextFontSmall",
	"SubSpellFont", "DialogButtonNormalText", "DialogButtonHighlightText",
	"ZoneTextFont", "SubZoneTextFont", "PVPInfoTextFont", "ErrorFont", "WorldMapTextFont",
	"TextStatusBarText", "TextStatusBarTextSmall",
	"GameTooltipText", "GameTooltipTextSmall", "GameTooltipHeaderText",
}

local function ApplyFonts()
	for _, name in pairs(FONT_OBJECTS) do
		local object = getglobal(name)
		if object and object.GetFont and object.SetFont then
			-- The stock size is kept on the first pass, so the bump is not added twice.
			if not object.survivorSize then
				local _, size, flags = object:GetFont()
				object.survivorSize, object.survivorFlags = size, flags
			end
			local size = object.survivorSize
			if size and size > 0 then
				object:SetFont(SurvivorUI_FONT, size + FONT_BUMP, object.survivorFlags)
			end
		end
	end
end

------------------------------------------------------------------------------
-- The global font (the options, Global): one face for every text of the
-- addon's and, with One font everywhere, the game's. The saved choice arrives
-- after the files have run, so the texts made by then are put in it once; the
-- ones made later read SurvivorUI_FONT as they are made. A piece's own font,
-- set on its card in move mode, stays its own.

local fontProbe = UIParent:CreateFontString(nil, "OVERLAY")

local function PathLoads(path)
	fontProbe:SetFont(SurvivorUI_DEFAULT_FONT, 12)
	fontProbe:SetFont(path, 12)
	local got = fontProbe:GetFont()
	return got ~= nil and string.lower(got) == string.lower(path)
end

-- A frame of the addon's: under one named SurvivorUI..., or under none with a
-- name up to the screen (a mover's handle).
local function Ours(frame)
	local at = frame
	while at do
		if at == UIParent then
			return true
		elseif at == WorldFrame then
			return false
		end
		local name = at:GetName()
		if name then
			return string.find(name, "^SurvivorUI") ~= nil
		end
		at = at:GetParent()
	end
	return false
end

local function EveryFrame(visit)
	if EnumerateFrames then
		local frame = EnumerateFrames()
		while frame do
			visit(frame)
			frame = EnumerateFrames(frame)
		end
		return
	end
	local function Down(frame)
		visit(frame)
		local children = { frame:GetChildren() }
		for index = 1, table.getn(children) do
			Down(children[index])
		end
	end
	Down(UIParent)
	Down(WorldFrame)
end

-- Text boxes, the chat and the like carry their face themselves.
local OWN_FACE = { EditBox = true, ScrollingMessageFrame = true, MessageFrame = true }

-- Every text in the old face takes the new one: the whole interface's with
-- One font everywhere, or when the old face is not the game's own (none but
-- the addon wears it then); else only the addon's.
local function Wear(face)
	local old = string.lower(SurvivorUI_FONT)
	if old == string.lower(face) then
		return
	end
	SurvivorUI_FONT = face
	local everything = Feature("fonts") or not string.find(old, "frizqt__", 1, true)
	if Feature("fonts") then
		STANDARD_TEXT_FONT, UNIT_NAME_FONT, NAMEPLATE_FONT, DAMAGE_TEXT_FONT = face, face, face, face
	end
	EveryFrame(function(frame)
		if not (everything or Ours(frame)) then
			return
		end
		local kind = frame.GetObjectType and frame:GetObjectType()
		if kind and OWN_FACE[kind] and frame.GetFont then
			local path, size, flags = frame:GetFont()
			if path and size and string.lower(path) == old then
				frame:SetFont(face, size, flags)
			end
		end
		local regions = { frame:GetRegions() }
		for index = 1, table.getn(regions) do
			local region = regions[index]
			if region.GetObjectType and region:GetObjectType() == "FontString" then
				local path, size, flags = region:GetFont()
				if path and size and string.lower(path) == old then
					region:SetFont(face, size, flags)
					-- A piece's card keeps its size steps by the face it last saw.
					if region.suiPath then
						region.suiPath = region:GetFont()
					end
				end
			end
		end
	end)
	if Feature("fonts") then
		ApplyFonts()
	end
end

-- The default global font: the face found as the files ran, the game's Friz
-- Quadrata (it writes every language the game speaks) unless one of one's own
-- was dropped in (Expressway).
function SurvivorUI_DefaultFont()
	return SurvivorUI_DEFAULT_FONT
end

function SurvivorUI_DefaultFontName()
	local face = string.lower(SurvivorUI_DefaultFont())
	if string.find(face, "expressway", 1, true) then
		return "Expressway"
	elseif string.find(face, "barlow", 1, true) then
		return "Barlow Condensed"
	end
	return "Friz Quadrata"
end

-- path nil: the default face. Saved, and worn at once.
function SurvivorUI_SetGlobalFont(path)
	Settings().globalFont = path
	if path and PathLoads(path) then
		Wear(path)
	else
		Wear(SurvivorUI_DefaultFont())
	end
end

function SurvivorUI_GlobalFont()
	return SurvivorUIDB and SurvivorUIDB.globalFont
end

-- What a new install starts with besides each file's own defaults, put in
-- where nothing is set yet; the toggles keep false for off.
local DEFAULTS = {
	critBox = true,             -- Biggest Crits
	bossBarsElites = true,      -- elites on the boss bars
	guardiansDocked = true,     -- the guardians as a bar in the run tracker
	trackerHealth = false,      -- the bosses' health in the run tracker (the boss bars have it)
	jewelryWithPane = true,     -- the Jewelry Collection beside the character pane
}

local globalFont = CreateFrame("Frame")
globalFont:RegisterEvent("ADDON_LOADED")
globalFont:SetScript("OnEvent", function()
	if arg1 ~= "SurvivorUI" then
		return
	end
	local settings = Settings()
	-- A new install (no scaleVersion yet: Mover.lua writes it as the hero
	-- enters the world) starts with the author's look (v3.0.12): these, put
	-- in where nothing is set. One from before keeps what nothing meant to it.
	if settings.scaleVersion == nil then
		local look = {
			statsPanel = true, statsPanelSize = { 150, 277 }, xpBar = true, levelUp = true,
			buildCooldown = true, trackerCoin = true, trackerElites = false, tallyPlace = "bar",
			lootBackground = false,
			paneStatsStep = 2, pinCacheSize = 12, pinLairSize = 11,
			pieceFonts = { ["Damage meter"] = { step = -1 }, ["Jewelry"] = { step = -2 } },
		}
		for key, value in pairs(look) do
			if settings[key] == nil then
				settings[key] = value
			end
		end
	end
	for key, value in pairs(DEFAULTS) do
		if settings[key] == nil then
			settings[key] = value
		end
	end
	if settings.globalFont then
		SurvivorUI_SetGlobalFont(settings.globalFont)
	end
end)

------------------------------------------------------------------------------
-- Tooltip: a flat dark box with a hairline border, a slim health bar along its
-- bottom edge, and smaller type.

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "WorldMapTooltip" }

local TOOLTIP_BACKDROP = {
	bgFile = FLAT, edgeFile = FLAT,
	tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function PaintTooltip(tooltip)
	tooltip:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
	tooltip:SetBackdropBorderColor(0, 0, 0, 1)
end

-- The game's right click menus (a chat tab's, a unit frame's): a fifth
-- smaller, as the tooltips.
local function SizeMenus()
	for level = 1, 3 do
		local menu = getglobal("DropDownList"..level)
		-- The stock code sets a menu's size each time it opens: a fifth off
		-- whatever it set, once (not again on a size already made smaller).
		local size = menu and menu:GetScale()
		if size and not (menu.survivorSize and math.abs(size - menu.survivorSize) < 0.001) then
			menu.survivorSize = size * 0.8
			menu:SetScale(menu.survivorSize)
		end
	end
end

-- After the stock opens one.
if ToggleDropDownMenu then
	local stockToggle = ToggleDropDownMenu
	ToggleDropDownMenu = function(a1, a2, a3, a4, a5, a6, a7, a8)
		stockToggle(a1, a2, a3, a4, a5, a6, a7, a8)
		if Feature("tooltip") then
			SizeMenus()
		end
	end
end

local function StyleTooltips()
	-- The stock code repaints a tooltip from these two.
	TOOLTIP_DEFAULT_COLOR = { r = 0, g = 0, b = 0 }
	TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.05, b = 0.07 }

	SizeMenus()
	for _, name in pairs(TOOLTIPS) do
		local tooltip = getglobal(name)
		if tooltip and not tooltip.survivorStyled then
			tooltip.survivorStyled = true
			tooltip:SetBackdrop(TOOLTIP_BACKDROP)
			-- A fifth smaller than the stock size: it covers less of the fight;
			-- the size chosen (Size, Tooltip) on top.
			tooltip:SetScale(0.8 * (Settings().tooltipSize or 1))
			PaintTooltip(tooltip)

			local stockShow = tooltip:GetScript("OnShow")
			tooltip:SetScript("OnShow", function()
				if stockShow then
					stockShow()
				end
				PaintTooltip(this)
			end)
		end
	end

	local header = getglobal("GameTooltipHeaderText")
	if header then
		header:SetFont(SurvivorUI_FONT, 13 + FONT_BUMP)
	end
	local body = getglobal("GameTooltipText")
	if body then
		body:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP)
	end
	local small = getglobal("GameTooltipTextSmall")
	if small then
		small:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP)
	end

	local bar = getglobal("GameTooltipStatusBar")
	if bar and GameTooltip then
		bar:SetStatusBarTexture(FLAT)
		bar:SetHeight(4)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 1, 1)
		bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -1, 1)
	end
end

------------------------------------------------------------------------------
-- Damage numbers: small, quick, and gone. A number pops over the enemy it hit,
-- shoots up and fades within half a second; a critical strike is larger and
-- gold. They replace the engine's own floating numbers while switched on
-- (/sui damage switches back and forth).
--
-- The addon reads hits from the combat log, which names the enemy but not
-- which one of several with that name. The number goes over one of them.

local DAMAGE_LIFE = 0.55        -- seconds on screen
local DAMAGE_RISE = 62          -- how far a number climbs
local DAMAGE_MAX = 48           -- numbers alive at once
local CRIT_SIZE = 22            -- a critical strike's number; a normal one is 14
local CRIT_POP_SIZE = 30        -- its size for the first instant
local CRIT_POP_TIME = 0.09

local damageLayer = CreateFrame("Frame", "SurvivorUIDamage", UIParent)
damageLayer:SetAllPoints(UIParent)
damageLayer:SetFrameStrata("HIGH")

local damageTexts = {}
local damageLive = 0

local function DamageText()
	for index = 1, table.getn(damageTexts) do
		if not damageTexts[index].live then
			return damageTexts[index]
		end
	end
	if table.getn(damageTexts) >= DAMAGE_MAX then
		return nil
	end
	local text = damageLayer:CreateFontString(nil, "OVERLAY")
	-- The source's icon, left of the number (beside the hero, with icons).
	text.icon = damageLayer:CreateTexture(nil, "OVERLAY")
	text.icon:SetPoint("RIGHT", text, "LEFT", -3, 0)
	text.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	text.icon:Hide()
	table.insert(damageTexts, text)
	return text
end

-- Every nameplate on screen showing this name. Survivor Plates blanks the art
-- a plate is recognized by, so its own list is used when it is installed.
local function PlatesNamed(name)
	local found = {}
	if SurvivorPlatesRegistry then
		for index = 1, table.getn(SurvivorPlatesRegistry) do
			local overlay = SurvivorPlatesRegistry[index]
			if overlay.plate:IsVisible() and overlay.stock.name:GetText() == name then
				table.insert(found, overlay.plate)
			end
		end
		return found
	end

	local children = { WorldFrame:GetChildren() }
	for index = 1, table.getn(children) do
		local plate = children[index]
		local border = plate:GetRegions()
		if plate:IsVisible() and border and border.GetTexture and border:GetObjectType() == "Texture"
			and border:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
			local regions = { plate:GetRegions() }
			for region = 1, table.getn(regions) do
				if regions[region]:GetObjectType() == "FontString" then
					if regions[region]:GetText() == name then
						table.insert(found, plate)
					end
					break
				end
			end
		end
	end
	return found
end

-- target is nil for a hit the hero took: that number rises over the hero, in red.
-- A pooled number changes size and outline only when it must: setting the same
-- face again still costs the engine a font lookup, many times a second.
------------------------------------------------------------------------------
-- Survivor's combat text, as the player sets it (the options, Combat text):
-- where the numbers go, how they look and what shows. The first time, the
-- choices of the earlier versions carry over.

local CT_DEFAULTS = {
	ctLayout = "sides", ctDistance = 140, ctRise = 170, ctCritColumn = true,
	ctIcons = true, ctMeterColors = true, ctSize = 0.85, ctCritSize = 1,
	ctPeriodic = true, ctHeals = true, ctTaken = true, ctShort = true,
	-- Hits from one source close together in one number (x3), each kind as
	-- chosen (the hits taken's switch kept its first name), within so many
	-- milliseconds; a heal shown once it comes to this much of max health, in
	-- percent.
	ctAddDealt = true, ctAddCrits = true, ctAddHeals = true, ctMergeTaken = true, ctAddWindow = 500,
	ctHealMin = 2,
	-- The new best crit: held still, an ability's own best (or the run's
	-- biggest), for so many seconds, at a size, over a glow.
	ctRecord = true, ctRecordKind = "ability", ctRecordHold = 2.3, ctRecordSize = 1, ctRecordGlow = true,
}

local function CT()
	local db = Settings()
	if (db.ctVersion or 0) < 1 then
		db.ctVersion = 1
		for key, value in pairs(CT_DEFAULTS) do
			if db[key] == nil then
				db[key] = value
			end
		end
		db.ctLayout = (db.damageSide or db.damageModern) and "sides" or "enemies"
		db.ctIcons = db.damageModern and true or false
		db.ctMeterColors = db.damageModern and true or false
	end
	-- 2: short numbers, on.
	if db.ctVersion < 2 then
		db.ctVersion = 2
		if db.ctShort == nil then
			db.ctShort = true
		end
	end
	-- 3: the new best crit's settings.
	if db.ctVersion < 3 then
		db.ctVersion = 3
		for _, key in pairs({ "ctRecord", "ctRecordKind", "ctRecordHold", "ctRecordSize", "ctRecordGlow" }) do
			if db[key] == nil then
				db[key] = CT_DEFAULTS[key]
			end
		end
	end
	-- 4: the crits' size, the hits taken adding up, the smallest heal.
	if db.ctVersion < 4 then
		db.ctVersion = 4
		for _, key in pairs({ "ctCritSize", "ctMergeTaken", "ctHealMin" }) do
			if db[key] == nil then
				db[key] = CT_DEFAULTS[key]
			end
		end
	end
	-- 5: every kind adding up, and how close together.
	if db.ctVersion < 5 then
		db.ctVersion = 5
		for _, key in pairs({ "ctAddDealt", "ctAddCrits", "ctAddHeals", "ctAddWindow" }) do
			if db[key] == nil then
				db[key] = CT_DEFAULTS[key]
			end
		end
	end
	return db
end

local function Face(text, size, flags)
	local share = CT().ctSize or 0.85
	local key = size..flags..share
	if text.faceKey ~= key then
		text.faceKey = key
		text:SetFont(SurvivorUI_FONT, math.max(6, math.floor(size * share + 0.5)), flags)
	end
end

-- The crits' size against the other numbers' (Combat text, Crit size).
local function CritScale()
	return CT().ctCritSize or 1
end

------------------------------------------------------------------------------
-- Beside the hero (/sui damage side, or the option): the numbers scroll in
-- columns by the hero instead of popping over the enemies. The damage dealt
-- climbs on the left in white, its crits on the right in gold; under the hero
-- the healing rises up to it, in green, and the damage
-- taken falls from under the hero, in red. Hits that come together start a
-- line apart, so the column reads. Each column moves in move mode.

local SIDE_LIFE = 1.3
local SIDE_RISE = 190
local SIDE_GAP = 15             -- between numbers that start together
-- The hits dealt in two columns, the plain ones left of the hero, the crits
-- right of it, so one never covers the other.
local SIDE_COLUMNS = {
	-- Five grid squares out (the move mode's lines are 32 apart).
	dealt = { x = -160, y = 0, rise = 1 },
	crit = { x = 160, y = 0, rise = 1 },
	-- The hits taken fall from under the action bar; the heals rise over the
	-- hero.
	taken = { x = 0, y = -167, rise = -1, reach = 70 },
	heal = { x = 0, y = 181, rise = 1, reach = 70 },
}
local sideStack = {}            -- [column] = { at = time, count = numbers started together }

-- Each column moves in move mode, as a piece of its own: where its numbers
-- start, saved; else by the hero as above (the damage and the crits the
-- distance chosen out).
local COLUMN_PIECES = {
	dealt = { name = "Damage numbers", left = "dealtLeft", top = "dealtTop", width = 120, height = 28 },
	crit = { name = "Crit numbers", left = "critLeft", top = "critTop", width = 120, height = 32 },
	taken = { name = "Damage taken", left = "takenLeft", top = "takenTop", width = 90, height = 24 },
	heal = { name = "Healing", left = "healLeft", top = "healTop", width = 90, height = 24 },
}
local COLUMN_ORDER = { "dealt", "crit", "taken", "heal" }
local columnFrames, columnHandles = {}, {}

-- The screen's middle in UIParent's units: GetScreenWidth, not
-- UIParent:GetWidth(), which does not take the UI scale in (at the game's
-- default 0.9 the columns stood off center, 2026-10-23).
local function ColumnDefault(kind)
	local x, y = GetScreenWidth() / 2, GetScreenHeight() / 2
	if kind == "taken" and CT().ctLayout ~= "sides" then
		-- Over the enemies: from the hero's feet down, ending short of the
		-- bar row (150 below).
		return x, y - 15
	elseif kind == "dealt" then
		return x - (CT().ctDistance or 170), y
	elseif kind == "crit" then
		return x + (CT().ctDistance or 170), y
	end
	return x + SIDE_COLUMNS[kind].x, y + SIDE_COLUMNS[kind].y
end

local function ColumnMoved(kind)
	local db = Settings()
	local piece = COLUMN_PIECES[kind]
	return db[piece.left] and db[piece.top]
end

-- Where a column's numbers start, now: the middle of its piece.
local function ColumnAt(kind)
	if ColumnMoved(kind) then
		local db = Settings()
		local piece = COLUMN_PIECES[kind]
		return db[piece.left] + piece.width / 2, db[piece.top] - piece.height / 2
	end
	return ColumnDefault(kind)
end

local function ColumnFrame(kind)
	local frame = columnFrames[kind]
	if not frame then
		local piece = COLUMN_PIECES[kind]
		frame = CreateFrame("Frame", nil, damageLayer)
		frame:SetWidth(piece.width)
		frame:SetHeight(piece.height)
		frame:SetMovable(true)
		columnFrames[kind] = frame
	end
	return frame
end

local function PlaceColumn(kind)
	local frame = ColumnFrame(kind)
	local x, y = ColumnAt(kind)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function SaveColumn(kind)
	local db = Settings()
	local piece = COLUMN_PIECES[kind]
	local frame = columnFrames[kind]
	db[piece.left] = math.floor(frame:GetLeft() + 0.5)
	db[piece.top] = math.floor(frame:GetTop() + 0.5)
end

local function SideOn()
	return CT().ctLayout == "sides"
end

-- Beside the hero, with icons: each hit with its source's icon, in
-- the color the damage meter gives that source. A melee hit shows the weapon
-- in hand; a shot the ranged weapon (a hunter's bow, a wand).
local OWN_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local RANGED = { ["Auto Shot"] = true, ["Shoot"] = true, ["Shot"] = true, ["Auto Shoot"] = true }
local iconCache, iconCacheAt = {}, 0

local function SourceIcon(source)
	if source == "Melee" then
		return GetInventoryItemTexture("player", 16) or OWN_ICON, false
	elseif RANGED[source] then
		return GetInventoryItemTexture("player", 18) or GetInventoryItemTexture("player", 16) or OWN_ICON, false
	end
	-- The meter's lookup goes through the spellbook, the talents and the
	-- items: kept a while, so a fight of many hits asks once per source.
	if GetTime() - iconCacheAt > 30 then
		iconCache, iconCacheAt = {}, GetTime()
	end
	if iconCache[source] == nil then
		iconCache[source] = (SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(source)) or false
	end
	if iconCache[source] then
		return iconCache[source], false
	end
	return OWN_ICON, true
end

-- A hit dealt in the meter's color and with its source's icon, as chosen;
-- false when neither.
local function Dress(text, dealt, crit, source, healed)
	local ct = CT()
	local colored = dealt and source and ct.ctMeterColors
	if colored then
		local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(source) or { 1, 1, 1 }
		text:SetTextColor(color[1], color[2], color[3])
	end
	local icon, whole
	if (dealt or healed) and source and ct.ctIcons then
		icon, whole = SourceIcon(source)
		-- A heal whose source has no icon shows none.
		if healed and icon == OWN_ICON then
			icon = nil
		end
	end
	if icon then
		text.icon:SetTexture(icon)
		if whole then
			text.icon:SetTexCoord(0, 1, 0, 1)
		else
			text.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		-- The icon sized with the type.
		local edge = math.floor((crit and 22 * CritScale() or 16) * (ct.ctSize or 0.85) + 0.5)
		text.icon:SetWidth(edge)
		text.icon:SetHeight(edge)
		text.icon:SetAlpha(1)
		text.icon:Show()
	else
		text.icon:Hide()
	end
	return colored
end

-- A hit's number, short when chosen (1475 as 1.5k), as the health reads.
local function Amount(amount)
	if CT().ctShort and SurvivorUI_Abbrev and tonumber(amount) then
		return SurvivorUI_Abbrev(amount)
	end
	return amount
end

-- Hits close together (a swarm's, an area spell's, a tenth or two apart) add
-- up, as chosen for each kind, in the number just shown from the same source:
-- their sum, and how many (x3), so a column reads instead of piling up.
local ADD_UP = { dealt = "ctAddDealt", crit = "ctAddCrits", heal = "ctAddHeals", taken = "ctMergeTaken" }
local lastOf = {}               -- [kind, crit, periodic and source] = the number shown last

local function Label(kind, sum, count)
	local label = Amount(sum)
	if kind == "taken" then
		label = "-"..label
	elseif kind == "heal" then
		label = "+"..label
	end
	if count > 1 then
		label = label.." |cffc8c8c8x"..count.."|r"
	end
	return label
end

local function AddUp(key, kind, amount)
	local ct = CT()
	local text, value = lastOf[key], tonumber(amount)
	if ct[ADD_UP[kind]] == false or not (value and text and text.live and text.addKey == key
		and text.age < (ct.ctAddWindow or 200) / 1000) then
		return false
	end
	text.sum = text.sum + value
	text.count = text.count + 1
	text:SetText(Label(kind, text.sum, text.count))
	return true
end

local function SpawnSide(kind, amount, crit, periodic, source)
	local ct = CT()
	local dealt = kind == "dealt"
	-- The crits in a column of their own, on the right, or with the rest.
	if dealt and crit and ct.ctCritColumn then
		kind = "crit"
	end
	local key = kind..(crit and "!" or "")..(periodic and "~" or "")..(source or "")
	if AddUp(key, kind, amount) then
		return
	end
	local text = DamageText()
	if not text then
		return
	end
	text.sum, text.count, text.addKey = tonumber(amount) or 0, 1, key
	lastOf[key] = text
	local column = SIDE_COLUMNS[kind]
	local startX, startY = ColumnAt(kind)
	local now = GetTime()
	local stack = sideStack[kind] or { at = 0, count = 0 }
	sideStack[kind] = stack
	if now - stack.at < 0.12 then
		stack.count = math.mod(stack.count + 1, 5)
	else
		stack.count = 0
	end
	stack.at = now

	local size = crit and CRIT_POP_SIZE * CritScale() or ((periodic and 12 or 14) + FONT_BUMP)
	Face(text, size, crit and "THICKOUTLINE" or "OUTLINE")
	if kind == "taken" then
		text:SetTextColor(1, 0.22, 0.22)
	elseif kind == "heal" then
		text:SetTextColor(0.3, 1, 0.4)
	elseif crit then
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		text:SetTextColor(0.80, 0.80, 0.80)
	else
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(Label(kind, text.sum, 1))
	Dress(text, dealt, crit, source, kind == "heal")

	text.live = true
	text.crit = crit
	text.popped = nil
	text.life = crit and SIDE_LIFE * 1.2 or SIDE_LIFE
	text.age = 0
	text.side = true
	-- Numbers that start together line up, the later ones a line behind.
	text.x = startX
	text.y = startY - column.rise * stack.count * SIDE_GAP
	text.drift = 0
	text.rise = (column.reach or ct.ctRise or SIDE_RISE) * column.rise
	text:SetAlpha(0)
	text:Show()
	damageLive = damageLive + 1
end

local function SpawnDamage(target, amount, crit, periodic, source)
	local ct = CT()
	if (periodic and not ct.ctPeriodic) or (not target and not ct.ctTaken) then
		return
	end
	if SideOn() then
		SpawnSide(target and "dealt" or "taken", amount, crit, periodic, source)
		return
	end
	local text = DamageText()
	if not text then
		return
	end
	text.side = nil
	text.addKey = nil
	amount = Amount(amount)

	-- Over one of the enemies with that name, else in a ring around the hero.
	local x, y
	local plates = target and PlatesNamed(target) or {}
	local count = table.getn(plates)
	if not target then
		-- Under the hero (the camera keeps it in the middle of the screen), or
		-- where the damage taken was moved to.
		x, y = ColumnAt("taken")
	elseif count > 0 then
		local plate = plates[math.random(1, count)]
		local px, py = plate:GetCenter()
		if px and py then
			local ratio = 1
			if plate.GetEffectiveScale and UIParent.GetEffectiveScale then
				ratio = plate:GetEffectiveScale() / UIParent:GetEffectiveScale()
			end
			x, y = px * ratio, py * ratio - 10
		end
	end
	if not x then
		local angle = math.random() * 6.2832
		local reach = 90 + math.random() * 70
		x = GetScreenWidth() / 2 + math.cos(angle) * reach
		y = GetScreenHeight() / 2 + 30 + math.sin(angle) * reach * 0.6
	end

	if not target then
		Face(text, crit and CRIT_POP_SIZE * CritScale() or 14, crit and "THICKOUTLINE" or "OUTLINE")
		text:SetTextColor(1, 0.22, 0.22)
		amount = "-"..amount
	elseif crit then
		-- Lands oversized, then settles: see the update below.
		Face(text, CRIT_POP_SIZE * CritScale(), "THICKOUTLINE")
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		Face(text, 12 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(0.80, 0.80, 0.80)
	else
		Face(text, 14 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(amount)
	Dress(text, target ~= nil, crit, source)

	text.live = true
	text.crit = crit
	text.popped = nil
	text.life = crit and DAMAGE_LIFE * 1.3 or DAMAGE_LIFE
	text.age = 0
	text.x = x + (math.random() - 0.5) * 24
	text.y = y
	text.drift = (math.random() - 0.5) * 30
	text.rise = crit and DAMAGE_RISE * 1.3 or DAMAGE_RISE
	if not target then
		-- A hit the hero took falls instead, apart from the ones it deals.
		text.rise = -text.rise
	end
	text:SetAlpha(0)
	text:Show()
	damageLive = damageLive + 1
end

-- In and out: alpha only, and a little lift; a font size set frame by frame
-- would cost (v2.3's stutter).
local FADE_IN, FADE_OUT, FADE_LIFT = 0.10, 0.50, 10

damageLayer:SetScript("OnUpdate", function()
	if damageLive == 0 then
		return
	end

	for index = 1, table.getn(damageTexts) do
		local text = damageTexts[index]
		if text.live then
			text.age = text.age + arg1
			local t = text.age / text.life
			if text.crit and not text.popped and text.age >= CRIT_POP_TIME then
				text.popped = true
				Face(text, CRIT_SIZE * CritScale(), "THICKOUTLINE")
			end
			if t >= 1 then
				text.live = nil
				text:Hide()
				text.icon:Hide()
				damageLive = damageLive - 1
			else
				-- Fast at first, slowing as it tops out. Beside the hero, a
				-- steadier scroll, so a column reads.
				local eased = text.side and (1 - (1 - t) * (1 - t) * 0.5 - 0.5 * (1 - t)) or (1 - (1 - t) * (1 - t))
				-- It comes in over the first tenth, from a little short of its
				-- start; it goes over the second half, slowly, then quicker.
				local alpha, lift = 1, 0
				if t < FADE_IN then
					local part = t / FADE_IN
					alpha = part * part * (3 - 2 * part)
					lift = (1 - alpha) * FADE_LIFT
				elseif t > FADE_OUT then
					local part = (t - FADE_OUT) / (1 - FADE_OUT)
					alpha = 1 - part * part
				end
				local down = text.rise < 0 and -1 or 1
				text:ClearAllPoints()
				text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", text.x + text.drift * eased, text.y + text.rise * eased - down * lift)
				text:SetAlpha(alpha)
				text.icon:SetAlpha(alpha)
			end
		end
	end
end)

-- The hit's source, as the damage meter names it: "Your Fireball" is
-- Fireball, "You" Melee, a pet its own name.
local function SourceOf(who)
	local _, _, spell = string.find(who or "", "^Your (.+)$")
	if spell then
		return spell
	elseif who == "You" then
		return "Melee"
	end
	return who
end

local function ParseDamage(message)
	-- Each pair of patterns only where its word is in the line: a plain find
	-- first, so a hit is not scanned for a crit, nor a tick for either.
	local _, who, target, amount
	if string.find(message, " crit", 1, true) then
		_, _, who, target, amount = string.find(message, "^(.-) crits (.+) for (%d+)")
		if target then
			return target, amount, true, false, SurvivorUI_SourceOf(SourceOf(who), message)
		end
		_, _, who, target, amount = string.find(message, "^(.-) crit (.+) for (%d+)")
		if target then
			return target, amount, true, false, SurvivorUI_SourceOf(SourceOf(who), message)
		end
	end
	if string.find(message, " hit", 1, true) then
		_, _, who, target, amount = string.find(message, "^(.-) hits (.+) for (%d+)")
		if target then
			return target, amount, false, false, SurvivorUI_SourceOf(SourceOf(who), message)
		end
		_, _, who, target, amount = string.find(message, "^(.-) hit (.+) for (%d+)")
		if target then
			return target, amount, false, false, SurvivorUI_SourceOf(SourceOf(who), message)
		end
	end
	-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
	local spell
	_, _, target, amount, spell = string.find(message, "^(.+) suffers (%d+) .+ from your (.-)%.?$")
	if target then
		return target, amount, false, true, spell
	end
end

-- The hits the hero takes come from the stock floating combat text's own feed.
local TAKEN_TYPES = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true }
-- And the heals, beside the hero only.
local HEAL_TYPES = { HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true }

------------------------------------------------------------------------------
-- A crit that beats its ability's best this run, or the run's biggest, as
-- chosen (SurvivorUI_NoteCrit; Combat text, New best crit): in place of its
-- number climbing with the rest, it stands still a moment, larger and gold
-- over a glow, "NEW BEST CRIT" over it, then fades. It stands beside the
-- Biggest Crits, where the bests are listed, or where it was moved to (move
-- mode). A newer record takes its place. /sui record shows one at once.

local RECORD_SIZE, RECORD_POP_SIZE, RECORD_POP = 32, 44, 0.12
local RECORD_FADE = 0.5                     -- seconds it takes to fade, after its hold
local RECORD_GOLD = { 1.00, 0.84, 0.20 }

local recordShown = CreateFrame("Frame", "SurvivorUIRecord", damageLayer)
recordShown:SetWidth(200)
recordShown:SetHeight(64)
recordShown:SetMovable(true)
recordShown:Hide()

-- Where it stands: the place it was moved to, else by the numbers' layout.
local function PlaceRecord()
	local db = Settings()
	recordShown:ClearAllPoints()
	if db.recordLeft and db.recordTop then
		recordShown:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.recordLeft, db.recordTop)
		return
	end
	-- Beside the Biggest Crits, where the bests are listed: on its right, or
	-- on its left when there is no room on the right.
	local crits = getglobal("SurvivorUICrits")
	local right = crits and crits:GetRight()
	if right and right + recordShown:GetWidth() < GetScreenWidth() then
		recordShown:SetPoint("TOPLEFT", crits, "TOPRIGHT", 8, -12)
	elseif right then
		recordShown:SetPoint("TOPRIGHT", crits, "TOPLEFT", -8, -12)
	else
		recordShown:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 223, -274)
	end
end

local function SaveRecordPlace()
	local db = Settings()
	db.recordLeft = math.floor(recordShown:GetLeft() + 0.5)
	db.recordTop = math.floor(recordShown:GetTop() + 0.5)
end

function SurvivorUI_ToggleRecord()
	local ct = CT()
	ct.ctRecord = ct.ctRecord == false
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: a new best crit "..(ct.ctRecord
		and "stands still, bigger and gold." or "climbs with the rest."))
end
recordShown.glow = recordShown:CreateTexture(nil, "BACKGROUND")
recordShown.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
recordShown.glow:SetBlendMode("ADD")
recordShown.glow:SetVertexColor(1, 0.75, 0.15)
recordShown.glow:SetPoint("CENTER", recordShown, "CENTER", 0, 0)
recordShown.number = recordShown:CreateFontString(nil, "OVERLAY")
recordShown.number:SetPoint("CENTER", recordShown, "CENTER", 0, 0)
recordShown.icon = recordShown:CreateTexture(nil, "OVERLAY")
recordShown.icon:SetPoint("RIGHT", recordShown.number, "LEFT", -4, 0)
recordShown.label = recordShown:CreateFontString(nil, "OVERLAY")
recordShown.label:SetPoint("BOTTOM", recordShown.number, "TOP", 0, 2)

local function ShowRecord(amount, source)
	local ct = CT()
	PlaceRecord()
	local scale = ct.ctRecordSize or 1
	recordShown.scale = scale
	recordShown.life = (ct.ctRecordHold or 1.7) + RECORD_FADE
	recordShown.glowing = ct.ctRecordGlow ~= false
	if recordShown.glowing then
		recordShown.glow:Show()
	else
		recordShown.glow:Hide()
	end
	Face(recordShown.number, RECORD_POP_SIZE * scale, "THICKOUTLINE")
	recordShown.number:SetTextColor(RECORD_GOLD[1], RECORD_GOLD[2], RECORD_GOLD[3])
	recordShown.number:SetText(Amount(amount))
	Face(recordShown.label, 10 * math.max(0.8, scale), "OUTLINE")
	recordShown.label:SetTextColor(1, 0.95, 0.75)
	recordShown.label:SetText("NEW BEST CRIT")
	local icon, whole = nil, false
	if source and ct.ctIcons then
		icon, whole = SourceIcon(source)
	end
	if icon then
		recordShown.icon:SetTexture(icon)
		if whole then
			recordShown.icon:SetTexCoord(0, 1, 0, 1)
		else
			recordShown.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		recordShown.icon:SetWidth(26 * scale)
		recordShown.icon:SetHeight(26 * scale)
		recordShown.icon:Show()
	else
		recordShown.icon:Hide()
	end
	recordShown.age = 0
	recordShown.popped = nil
	recordShown:SetAlpha(1)
	recordShown:Show()
end

recordShown:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local age = this.age
	local life = this.life or 2.2
	if age >= life then
		this:Hide()
		return
	end
	local scale = this.scale or 1
	if not this.popped and age >= RECORD_POP then
		this.popped = true
		Face(this.number, RECORD_SIZE * scale, "THICKOUTLINE")
	end
	-- The glow bursts, then breathes; all of it fades at the end.
	if this.glowing then
		local burst = math.max(0, 1 - age / 0.5)
		local size = (90 + 70 * burst + 10 * math.sin(age * 6)) * scale
		this.glow:SetWidth(size)
		this.glow:SetHeight(size * 0.7)
		this.glow:SetAlpha(0.55 + 0.45 * burst)
	end
	local fade = life - RECORD_FADE
	this:SetAlpha(age > fade and (1 - (age - fade) / RECORD_FADE) or math.min(1, age / 0.06))
end)

-- Placed once the saved settings are in, and a piece of move mode (Mover.lua
-- runs after this file), as are the columns.
local recordLoader = CreateFrame("Frame")
recordLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
recordLoader:SetScript("OnEvent", function()
	PlaceRecord()
	for _, kind in pairs(COLUMN_ORDER) do
		PlaceColumn(kind)
	end
	if not this.registered and SurvivorUI_RegisterMover then
		this.registered = true
		SurvivorUI_RegisterMover(recordShown, "New best crit", SaveRecordPlace, nil, function()
			local db = Settings()
			db.recordLeft, db.recordTop = nil, nil
			PlaceRecord()
		end)
		for _, kind in pairs(COLUMN_ORDER) do
			local column = kind
			local piece = COLUMN_PIECES[column]
			columnHandles[column] = SurvivorUI_RegisterMover(ColumnFrame(column), piece.name,
				function() SaveColumn(column) end, nil, function()
					local db = Settings()
					db[piece.left], db[piece.top] = nil, nil
					PlaceColumn(column)
				end)
		end
	end
end)

-- A column in move mode only while it is used: beside the hero the four
-- (the crits' while they have their own); over the enemies the damage taken
-- alone. Out of move mode each keeps to its place, as the distance changes.
local function ColumnUsed(kind)
	local db = Settings()
	if not db.damageText then
		return false
	end
	if kind == "taken" then
		return true
	elseif not SideOn() then
		return false
	elseif kind == "crit" then
		return CT().ctCritColumn and true or false
	end
	return true
end

local columnWatch = CreateFrame("Frame")
columnWatch.elapsed = 0
columnWatch:SetScript("OnUpdate", function()
	this.elapsed = this.elapsed + arg1
	if this.elapsed < 0.5 then
		return
	end
	this.elapsed = 0
	for _, kind in pairs(COLUMN_ORDER) do
		local handle = columnHandles[kind]
		if handle then
			handle.disabled = not ColumnUsed(kind) or nil
			if not handle:IsShown() then
				PlaceColumn(kind)
			end
		end
	end
end)

------------------------------------------------------------------------------
-- The heals: the game's own never reach the combat text's feed, so they are
-- read from its healing meter (AZS_HEALING, each source's health given this
-- run, overhealing left out) as it changes: what a source gave since last
-- shown, with its icon. A trickle (regeneration, a ring's health per second)
-- gathers until it is worth a number: 2% of max health, 1 at least.

local healSeen, healPending = {}, {}
local healAt, healPrimed

local function HealsOn()
	local db = Settings()
	return db.damageText and not db.damageNone and CT().ctHeals
end

local healWatch = CreateFrame("Frame")
healWatch:SetScript("OnUpdate", function()
	if not AZS_HEALING or AZS_HEALING_UPDATED == healAt then
		return
	end
	healAt = AZS_HEALING_UPDATED
	local on = healPrimed and HealsOn()
	local worth = math.max(1, (CT().ctHealMin or 2) / 100 * (UnitHealthMax("player") or 0))
	for index = 1, table.getn(AZS_HEALING) do
		local line = AZS_HEALING[index]
		local name, given = line.name, tonumber(line.dmg)
		if name and given then
			local seen = healSeen[name]
			if not seen or given < seen then
				-- A source new since the last read, or a new run's.
				healPending[name] = (seen and given) or (healPrimed and given) or 0
			else
				healPending[name] = (healPending[name] or 0) + given - seen
			end
			healSeen[name] = given
			if healPending[name] >= worth then
				if on then
					SpawnSide("heal", math.floor(healPending[name] + 0.5), false, false, name)
				end
				healPending[name] = 0
			end
		end
	end
	healPrimed = true
end)

-- The damage taken's and the heals' switches, for their cards in move mode.
function SurvivorUI_ToggleTakenNumbers()
	local ct = CT()
	ct.ctTaken = not ct.ctTaken
end

function SurvivorUI_ToggleHealNumbers()
	local ct = CT()
	ct.ctHeals = not ct.ctHeals
end

local damageEvents = CreateFrame("Frame")
damageEvents:SetScript("OnEvent", function()
	if not Settings().damageText then
		return
	end
	if event == "COMBAT_TEXT_UPDATE" then
		if TAKEN_TYPES[arg1] and tonumber(arg2) then
			SpawnDamage(nil, arg2, arg1 == "DAMAGE_CRIT")
		elseif HEAL_TYPES[arg1] and CT().ctHeals and not AZS_GetHealing then
			-- A heal: arg2 the healer, arg3 the health it gave.
			local amount = tonumber(arg3) or tonumber(arg2)
			if amount and amount > 0 then
				SpawnSide("heal", math.floor(amount + 0.5), arg1 == "HEAL_CRIT", arg1 == "PERIODIC_HEAL")
			end
		end
		return
	end
	local target, amount, crit, periodic, source = ParseDamage(arg1 or "")
	if target then
		-- A crit that beats its ability's best, or the run's biggest, as
		-- chosen: its moment, held still.
		if crit and not periodic then
			local mine, top = SurvivorUI_NoteCrit(amount, arg1)
			local ct = CT()
			local record = mine
			if ct.ctRecordKind == "run" then
				record = top
			end
			if record and ct.ctRecord ~= false then
				ShowRecord(amount, source)
				return
			end
		end
		SpawnDamage(target, amount, crit, periodic, source)
	end
end)

local DAMAGE_EVENTS = {
	"CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_SPELL_PET_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "COMBAT_TEXT_UPDATE",
}

-- The stock floating combat text (Blizzard_CombatText, loaded on demand)
-- scrolls the hits the hero takes slowly, in its own face. While the quick
-- numbers are on, it leaves those to them; heals and the rest stay its own.
-- Each kind's own "show", as the stock code set it, to give back after "no
-- combat text at all".
local stockShow

local function ApplyTakenText()
	if not COMBAT_TEXT_TYPE_INFO then
		return
	end
	if not stockShow then
		stockShow = {}
		for kind, info in pairs(COMBAT_TEXT_TYPE_INFO) do
			stockShow[kind] = info.show
		end
	end
	-- No combat text at all (/sui damage none): every kind of the stock
	-- floating text silenced; back as it was when switched off.
	local none = Settings().damageNone
	for kind, info in pairs(COMBAT_TEXT_TYPE_INFO) do
		if none then
			info.show = nil
		elseif info.var ~= "SURVIVORUI_NEVER" then
			info.show = stockShow[kind]
		end
	end
	if none then
		return
	end
	-- "Health Low" in big letters over the fight says what the player frame
	-- already shows. Tied to a setting no one sets, so the stock refresh keeps
	-- it off.
	for _, kind in pairs({ "HEALTH_LOW", "MANA_LOW" }) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.var = "SURVIVORUI_NEVER"
			info.show = nil
		end
	end
	local on = Settings().damageText
	for kind in pairs(TAKEN_TYPES) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.show = not on and 1 or nil
		end
	end
	-- Beside the hero, the heals are the addon's too.
	-- The heals are the addon's in its own mode, shown or not as chosen.
	local heals = on
	for kind in pairs(HEAL_TYPES) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.show = not heals and 1 or nil
		end
	end
end

local takenWatch = CreateFrame("Frame")
takenWatch:RegisterEvent("ADDON_LOADED")
takenWatch:SetScript("OnEvent", function()
	if arg1 == "Blizzard_CombatText" then
		ApplyTakenText()
	end
end)

-- The engine's numbers are on when the addon's are off, and the other way round.
local function ApplyDamageText()
	local none = Settings().damageNone
	local on = Settings().damageText and not none
	for _, event in pairs(DAMAGE_EVENTS) do
		if on then
			damageEvents:RegisterEvent(event)
		else
			damageEvents:UnregisterEvent(event)
		end
	end
	-- The engine's own numbers: only when the game's are the ones chosen.
	SetCVar("CombatDamage", (on or none) and "0" or "1")
	ApplyTakenText()
end

function SurvivorUI_ToggleDamage()
	local settings = Settings()
	settings.damageText = not settings.damageText
	settings.damageNone = nil
	ApplyDamageText()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.damageText and "SurvivorUI's damage numbers." or "Default damage numbers."))
end

-- How the combat numbers show, for the options: "quick" (over the enemies),
-- "side" (beside the hero), "game" (the game's own) or "none" (no combat text).
function SurvivorUI_DamageMode()
	local settings = Settings()
	if settings.damageNone then
		return "none"
	elseif not settings.damageText then
		return "game"
	end
	return "survivor"
end

function SurvivorUI_SetDamageMode(mode)
	local settings = Settings()
	settings.damageNone = mode == "none"
	settings.damageText = mode == "survivor"
	ApplyDamageText()
end

-- For the options: one of Survivor's combat text settings, and its change.
function SurvivorUI_CT(key)
	return CT()[key]
end

function SurvivorUI_SetCT(key, value)
	CT()[key] = value
	ApplyDamageText()
end

-- Survivor's own look: beside the hero, with icons and the meter's colors.
function SurvivorUI_CTDefaults()
	local ct = CT()
	for key, value in pairs(CT_DEFAULTS) do
		ct[key] = value
	end
	-- Every column and the new best crit back in their first places.
	for _, kind in pairs(COLUMN_ORDER) do
		local piece = COLUMN_PIECES[kind]
		ct[piece.left], ct[piece.top] = nil, nil
		PlaceColumn(kind)
	end
	ct.recordLeft, ct.recordTop = nil, nil
	PlaceRecord()
	SurvivorUI_SetDamageMode("survivor")
end

-- A sample of every number as set (Combat text, Show a sample; /sui sample):
-- hits dealt with the meter's top source, a crit, a swarm's hits taken, a
-- heal and a new best crit, a moment apart.
local sample = CreateFrame("Frame")
sample:Hide()
sample:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	while this.steps[this.at] and this.steps[this.at][1] <= this.age do
		this.steps[this.at][2]()
		this.at = this.at + 1
	end
	if not this.steps[this.at] then
		this:Hide()
	end
end)

function SurvivorUI_CTSample()
	local db = Settings()
	if not db.damageText or db.damageNone then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the sample shows SurvivorUI's numbers; choose SurvivorUI in Combat text first.")
		return
	end
	local source = AZS_METER and AZS_METER[1] and AZS_METER[1].name or "Melee"
	local healer = AZS_HEALING and AZS_HEALING[1] and AZS_HEALING[1].name
	local ct = CT()
	sample.steps = {
		{ 0, function() SpawnDamage("Sample", 128, false, false, source) end },
		{ 0.05, function() SpawnDamage("Sample", 131, false, false, source) end },
		{ 0.35, function() SpawnDamage("Sample", 352, true, false, source) end },
		{ 0.5, function() SpawnDamage(nil, 9) end },
		{ 0.6, function() SpawnDamage(nil, 6) end },
		{ 0.8, function() if ct.ctHeals then SpawnSide("heal", 27, false, false, healer) end end },
		{ 1.0, function() SpawnDamage("Sample", 96, false, ct.ctPeriodic and true or false, source) end },
		{ 1.3, function() if ct.ctRecord ~= false then ShowRecord(1234, source) end end },
	}
	sample.age, sample.at = 0, 1
	sample:Show()
end

-- The numbers beside the hero, or over the enemies again.
function SurvivorUI_ToggleDamageSide()
	local settings = Settings()
	local ct = CT()
	ct.ctLayout = ct.ctLayout == "sides" and "enemies" or "sides"
	settings.damageSide = ct.ctLayout == "sides"
	settings.damageText = true
	settings.damageNone = nil
	ApplyDamageText()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: damage numbers "..(settings.damageSide and "beside the hero." or "over the enemies."))
end

-- For the options (Size): the chat's text size, 8 to 18, and the tooltips'
-- size, on top of the flat tooltips' fifth smaller.
function SurvivorUI_ChatSize()
	return Settings().chatSize
end

function SurvivorUI_SetChatSize(size)
	Settings().chatSize = math.max(8, math.min(18, math.floor(size + 0.5)))
	StyleChat()
end

function SurvivorUI_TooltipSize()
	return Settings().tooltipSize or 1
end

function SurvivorUI_SetTooltipSize(size)
	Settings().tooltipSize = size
	for _, name in pairs(TOOLTIPS) do
		local tooltip = getglobal(name)
		if tooltip then
			tooltip:SetScale((tooltip.survivorStyled and 0.8 or 1) * size)
		end
	end
end

-- The tooltips' size put on once the saved settings are in (the flat ones
-- take it as they are styled).
local tooltipSizer = CreateFrame("Frame")
tooltipSizer:RegisterEvent("PLAYER_ENTERING_WORLD")
tooltipSizer:SetScript("OnEvent", function()
	local size = SurvivorUIDB and SurvivorUIDB.tooltipSize
	if size and size ~= 1 then
		SurvivorUI_SetTooltipSize(size)
	end
end)

SLASH_SURVIVORUI1 = "/sui"
SlashCmdList["SURVIVORUI"] = function(msg)
	local _, _, command, argument = string.find(msg or "", "^(%S*)%s*(.*)$")
	if command == "chat" and tonumber(argument) then
		local settings = Settings()
		settings.chatSize = math.max(8, math.min(18, tonumber(argument)))
		StyleChat()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: chat text size "..settings.chatSize..".")
	elseif msg == "run" then
		if SurvivorUI_ToggleRun then
			SurvivorUI_ToggleRun()
		end
	elseif msg == "run reset" then
		if SurvivorUI_ResetRun then
			SurvivorUI_ResetRun()
		end
	elseif msg == "bosses" or msg == "bosses elites" then
		if SurvivorUI_BossBars then
			SurvivorUI_BossBars(argument)
		end
	elseif msg == "tracker" then
		if SurvivorUI_ToggleTracker then
			SurvivorUI_ToggleTracker()
		end
	elseif msg == "tally" then
		if SurvivorUI_Tally then
			SurvivorUI_Tally()
		end
	elseif msg == "pace" or msg == "pace reset" or msg == "pace class" then
		if SurvivorUI_TogglePace then
			SurvivorUI_TogglePace(argument)
		end
	elseif msg == "meter" then
		if SurvivorUI_ToggleMeter then
			SurvivorUI_ToggleMeter()
		end
	elseif command == "scale" then
		if SurvivorUI_SetScale then
			SurvivorUI_SetScale(argument)
		end
	elseif msg == "layout" then
		if SurvivorUI_ResetLayout then
			SurvivorUI_ResetLayout()
		end
	elseif msg == "hover" then
		if SurvivorUI_ToggleHover then
			SurvivorUI_ToggleHover()
		end
	elseif msg == "loot" then
		if SurvivorUI_ToggleLoot then
			SurvivorUI_ToggleLoot()
		end
	elseif msg == "opt" or msg == "options" or msg == "config" then
		if SurvivorUI_ToggleOptions then
			SurvivorUI_ToggleOptions()
		end
	elseif msg == "build" then
		if SurvivorUI_ToggleBuild then
			SurvivorUI_ToggleBuild()
		end
	elseif msg == "crits" then
		if SurvivorUI_ToggleCrits then
			SurvivorUI_ToggleCrits()
		end
	elseif msg == "collection" or msg == "jewelry" then
		if SurvivorUI_ToggleJewelry then
			SurvivorUI_ToggleJewelry()
		end
	elseif msg == "history" or msg == "last" or msg == "runs" then
		if SurvivorUI_ShowLastRuns then
			SurvivorUI_ShowLastRuns()
		end
	elseif msg == "collection reset" then
		if SurvivorUI_ResetCollection then
			SurvivorUI_ResetCollection()
		end
	elseif msg == "record" then
		-- The look of a new best crit, at once.
		ShowRecord(12345)
	elseif msg == "sample" then
		SurvivorUI_CTSample()
	elseif msg == "dots" then
		if SurvivorUI_ToggleDots then
			SurvivorUI_ToggleDots()
		end
	elseif msg == "guardians" or msg == "guardians north" or msg == "guardians bar" then
		if SurvivorUI_ToggleGuardians then
			SurvivorUI_ToggleGuardians(argument)
		end
	elseif msg == "pins" then
		if SurvivorUI_PinsReport then
			SurvivorUI_PinsReport()
		end
	elseif msg == "center" then
		if SurvivorUI_CenterRow then
			SurvivorUI_CenterRow()
		end
	elseif msg == "damage" then
		SurvivorUI_ToggleDamage()
	elseif msg == "damage side" then
		SurvivorUI_ToggleDamageSide()
	elseif msg == "damage modern" or msg == "damage icons" then
		local on = not CT().ctIcons
		CT().ctIcons, CT().ctMeterColors = on, on
		SurvivorUI_SetDamageMode("survivor")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: damage numbers "..(on and "with their source's icon, in its damage meter color." or "without icons, in the classic colors."))
	elseif msg == "damage none" then
		local none = SurvivorUI_DamageMode() ~= "none"
		SurvivorUI_SetDamageMode(none and "none" or "survivor")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(none and "no combat text at all." or "quick damage numbers."))
	else
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui opt  opens the options: every piece on or off, panel size, and a move mode with a grid")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui damage  switches between SurvivorUI's damage numbers and Default")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui damage side  puts the damage numbers beside the hero, or back over the enemies")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui dots  shows or hides the counters over the action bar: DoTs, fears and totems")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui history  your run history, each run as it ended: the run tracker, the numbers, the build, the damage, the crits and the loot")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui record  shows how a new best crit looks in the combat numbers")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui sample  shows a sample of every combat number as set")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui guardians  shows or hides the guardians' list; /sui guardians north  points its arrows north up; /sui guardians bar  makes it a bar in the run tracker")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui pins  prints what the minimap's cache and lair pins read")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui collection  the Jewelry Collection: every amulet, ring and trinket found, and what is left to find; /sui collection reset  forgets it all")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui chat 10  sets the chat text size, 8 to 18 (default 10)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: hold Alt to see everything that moves, and drag; /sui center puts the middle back, /sui layout puts everything back")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui bosses  switches the boss bars on or off; /sui bosses elites  lists elites too")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tally  switches between the kills and gold line under the minimap and the Default box")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui pace  shows or hides the kill pace, the orb by the run tracker's clock; /sui pace class  against this class's runs only, or every class's; /sui pace reset  forgets the runs it holds against")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui run  shows or hides the run panel (the run's numbers and biggest crits); /sui run reset clears the crits")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tracker  shows or hides the run tracker under the minimap (the clock and the bosses)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui build  shows or hides the build list (spells, ranks, slots)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui crits  shows or hides the Biggest Crits box (off by default)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui hover  switches the white outline around what the mouse is on")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui scale 0.85  sizes the panels, 0.6 to 1.4, for smaller screens")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui meter  switches between SurvivorUI's damage meter, with the crits, and Default")
	end
end

------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UNIT_PORTRAIT_UPDATE")
loader:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		-- The core's three parts, each a module (after a reload): off, the game's
		-- own stays and SurvivorUI's neither shows nor runs.
		if Feature("unitFrames") then
			HideStockUnitFrames()
		else
			unitUpdater:SetScript("OnUpdate", nil)
			player:Hide()
			target:Hide()
		end
		if Feature("buffs") then
			HideStockBuffs()
		else
			auraUpdater:SetScript("OnUpdate", nil)
			buffHolder:Hide()
		end
		if Feature("actionBar") then
			LayoutBar()
		else
			-- The row stays, as what the frames hang from; its slots go.
			for _, slot in pairs(row.slots) do
				slot:Hide()
			end
		end
		if Feature("minimap") then
			SquareMinimap()
		end
		if Feature("microMenu") then
			MoveMicroButtons()
			HideMicroButtons()
		end
		if Feature("fonts") then
			ApplyFonts()
		end
		if Feature("chat") then
			StyleChat()
		end
		if Feature("tooltip") then
			StyleTooltips()
		end
		ApplyDamageText()
		UpdatePortrait(player)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdatePortrait(target)
	elseif arg1 == "player" then
		UpdatePortrait(player)
	elseif arg1 == "target" then
		UpdatePortrait(target)
	end
end)
