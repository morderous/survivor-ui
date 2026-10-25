-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: raid marks put on their own (the game's 0.115, "raid markers
-- work for everyone"; asked for on Discord by Farsigt). A mark for each kind,
-- each kind on or off (the Nameplates tab, Raid marks; all off by default):
-- the bosses (a skull), the lair guardians (a cross), the elites (a star).
--
-- A mark goes to an enemy the game lists (AZS_UNITS) once it is in the fight:
-- a boss, an elite, a guardian awake or hurt (asleep in its lair, far off, the
-- game takes no mark: seen 2026-10-24). When the game puts it in the hero's
-- target (it moves the target on its own), it is marked there. Else it is
-- targeted by its name, and marked a moment later: the game reads the target
-- a mark goes to as it was the frame before (marked at once, the skull went to
-- the target before, seen 2026-10-24). The mark is then looked for on it; not
-- there within a second, the enemy is tried again a little later. The target
-- before is put back after. Two of a name (a zone's two Kobold Taskmasters):
-- the target is told by its health against each one's, and a wrong one is let
-- be. The game keeps one enemy per mark: while the one marked lives, the next
-- of its kind waits. An enemy already marked (by a friend in a co-op run too)
-- is never marked again.
--
-- A co-op party's heroes too (asked for on Discord by Towneh, who marked his
-- friends to find them in the horde): a mark picked for each, Hero 1 to 5;
-- the heroes take them by their names in order, so every Survivor UI in the
-- party gives the same, and a hero already marked (by hand, or by a friend)
-- keeps that mark. Every mark is one row's: picked on a row it goes from the
-- others, and a row may have none (its "No mark"), marking nothing then.
--
-- The marks known, each enemy's (marked here, or read off the target and the
-- mouseover), show on Survivor UI's boss bars (SurvivorUI_RaidMarkOf), and the
-- target's over its frame; Survivor Plates shows the client's own on a plate.

local ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
SurvivorUI_RAID_MARKS = {
	{ 8, "Skull" }, { 7, "Cross" }, { 6, "Square" }, { 5, "Moon" },
	{ 4, "Triangle" }, { 3, "Diamond" }, { 2, "Circle" }, { 1, "Star" },
}
local KINDS = { "boss", "guardian", "elite" }
local ON_KEYS = { boss = "markBosses", guardian = "markGuardians", elite = "markElites", party = "markParty" }
local ICON_KEYS = { boss = "markBossIcon", guardian = "markGuardianIcon", elite = "markEliteIcon" }
-- The marks on a fresh install (nothing picked yet): the enemies' and the
-- heroes' (Square, Moon, Triangle, Diamond, Circle). Once anything is picked
-- or emptied, only what is saved counts: 0 saved is no mark.
local DEFAULT_ICONS = { boss = 8, guardian = 7, elite = 1 }
local DEFAULT_PARTY = { 6, 5, 4, 3, 2 }
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local PARTY_RETRY = 3           -- a hero asked to wear a mark again after this long
local TICK = 0.2
local RETRY = 4                 -- an enemy tried by name again after this long
local SETTLE = 1.5              -- a mark put here, read back as gone only after this long
local CHECK = 1                 -- how long a mark by name is looked for on its enemy

local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- The atlas: 4 columns, 2 rows of the file's 4.
function SurvivorUI_SetRaidMarkTexture(texture, index)
	index = tonumber(index)
	if not index or index < 1 or index > 8 then
		texture:Hide()
		return
	end
	local column, row = math.mod(index - 1, 4), math.floor((index - 1) / 4)
	texture:SetTexture(ICONS)
	texture:SetTexCoord(column * 0.25, column * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
	texture:Show()
end

function SurvivorUI_AutoMarkOn(kind)
	return DB()[ON_KEYS[kind]] == true
end

function SurvivorUI_ToggleAutoMark(kind)
	DB()[ON_KEYS[kind]] = not SurvivorUI_AutoMarkOn(kind)
end

-- Whether anything was ever picked or emptied: before that, the defaults.
local function Fresh()
	local db = DB()
	if db.markPartyIcons then
		return false
	end
	for _, key in pairs(ICON_KEYS) do
		if db[key] ~= nil then
			return false
		end
	end
	return true
end

-- The mark the party's hero at this place (by name, in order) wears; nil
-- for none.
function SurvivorUI_PartyMarkIcon(slot)
	local set = DB().markPartyIcons
	local saved = tonumber(set and set[slot])
	if saved == nil and Fresh() then
		return DEFAULT_PARTY[slot]
	end
	return saved and saved > 0 and saved or nil
end

-- A kind's mark; nil for none.
function SurvivorUI_AutoMarkIcon(kind)
	local saved = tonumber(DB()[ICON_KEYS[kind]])
	if saved == nil and Fresh() then
		return DEFAULT_ICONS[kind]
	end
	return saved and saved > 0 and saved or nil
end

-- What is saved the first time anything is picked: the defaults in use, so
-- the rows keep what they showed.
local function Settle()
	if not Fresh() then
		return
	end
	local db = DB()
	db.markPartyIcons = {}
	for slot = 1, 5 do
		db.markPartyIcons[slot] = DEFAULT_PARTY[slot]
	end
	for kind, key in pairs(ICON_KEYS) do
		db[key] = DEFAULT_ICONS[kind]
	end
end

-- A mark picked on a row goes from every other: 0 (none) there.
local function Release(index)
	local db = DB()
	for slot = 1, 5 do
		if db.markPartyIcons[slot] == index then
			db.markPartyIcons[slot] = 0
		end
	end
	for _, key in pairs(ICON_KEYS) do
		if db[key] == index then
			db[key] = 0
		end
	end
end

-- index nil or 0: no mark for that row.
function SurvivorUI_SetPartyMarkIcon(slot, index)
	Settle()
	index = tonumber(index) or 0
	if index > 0 then
		Release(index)
	end
	DB().markPartyIcons[slot] = index
end

function SurvivorUI_SetAutoMarkIcon(kind, index)
	Settle()
	index = tonumber(index) or 0
	if index > 0 then
		Release(index)
	end
	DB()[ICON_KEYS[kind]] = index
end

-- Whether a mark is another row's than the one asked for (its kind, or its
-- hero's slot): the options offer a row only the marks no other row has.
function SurvivorUI_MarkTakenElsewhere(index, kind, slot)
	for other = 1, 5 do
		if other ~= slot and SurvivorUI_PartyMarkIcon(other) == index then
			return true
		end
	end
	for _, otherKind in ipairs(KINDS) do
		if otherKind ~= kind and SurvivorUI_AutoMarkIcon(otherKind) == index then
			return true
		end
	end
	return false
end

-- The kind an enemy the game lists is marked as, once it is in the fight; nil
-- for the rest and a guardian asleep (one already hurt is in the fight, though
-- the game still calls it asleep, as the boss bars have it).
local function FightKind(unit)
	local kind = Field(unit, "kind", 1)
	if kind == "final" or kind == "boss" then
		return "boss"
	elseif kind == "elite" then
		return "elite"
	elseif kind == "guardian" then
		local hp, hpm = tonumber(Field(unit, "hp", 4)) or 0, tonumber(Field(unit, "hpm", 5)) or 0
		if (tonumber(Field(unit, "state", 6)) or 0) == 1 or (hpm > 0 and hp > 0 and hp < hpm) then
			return "guardian"
		end
	end
end

local known = {}                -- [id] = the mark it wears
local markedAt = {}             -- [id] = when it was marked here
local tried = {}                -- [id] = when it was last targeted by name
local alive = {}                -- [id] = the game's entry, this tick
local aim                       -- the mark by name under way: { id, index, had, step, at }
local lastTarget                -- the target's id the tick before

-- Which of the game's enemies a unit (target, mouseover) is: by its name, and
-- by its health against each one's when two share it; nil when unsure.
local function UnitId(unit)
	if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then
		return nil
	end
	local name = UnitName(unit)
	local most = UnitHealthMax(unit) or 0
	local share = most > 0 and (UnitHealth(unit) or 0) / most or 1
	local best, bestGap, secondGap, count = nil, 2, 2, 0
	for id, entry in pairs(alive) do
		if Field(entry, "name", 3) == name then
			count = count + 1
			local hpm = tonumber(Field(entry, "hpm", 5)) or 0
			local gap = math.abs(share - (hpm > 0 and (tonumber(Field(entry, "hp", 4)) or 0) / hpm or 1))
			if gap < bestGap then
				best, bestGap, secondGap = id, gap, bestGap
			elseif gap < secondGap then
				secondGap = gap
			end
		end
	end
	if count == 1 or (best and bestGap <= 0.03 and secondGap > 0.03) then
		return best
	end
end

-- One enemy per mark: the mark goes from whoever wore it.
local function Know(id, index)
	for other, worn in pairs(known) do
		if worn == index and other ~= id then
			known[other] = nil
		end
	end
	known[id] = index
end

-- What a unit wears, read: kept, or let go when the mark is gone.
local function Read(unit)
	local id = UnitId(unit)
	if not id then
		return
	end
	local index = GetRaidTargetIndex and GetRaidTargetIndex(unit)
	if index then
		Know(id, index)
	elseif known[id] and GetTime() - (markedAt[id] or 0) > SETTLE then
		known[id] = nil
	end
end

function SurvivorUI_RaidMarkOf(id)
	return id and known[tonumber(id)]
end

-- Whether a mark is worn by another enemy still alive, or about to be.
local function Taken(index, id)
	for other, worn in pairs(known) do
		if worn == index and other ~= id and alive[other] then
			return true
		end
	end
	return aim ~= nil and aim.index == index and aim.id ~= id
end

-- The target, when the game put one there that wants a mark: marked as it is,
-- once it was the target a tick before too (the mark goes to the target of the
-- frame before).
local function MarkTarget()
	local id = UnitId("target")
	local steady = id and id == lastTarget
	lastTarget = id
	local entry = steady and alive[id]
	local kind = entry and FightKind(entry)
	if not kind or not SurvivorUI_AutoMarkOn(kind) or known[id] or GetRaidTargetIndex("target") then
		return
	end
	local index = SurvivorUI_AutoMarkIcon(kind)
	if index and not Taken(index, id) then
		SetRaidTarget("target", index)
		markedAt[id] = GetTime()
		Know(id, index)
	end
end

-- An enemy that wants a mark and is not the target: targeted by its name.
local function Aim()
	local now = GetTime()
	for _, kind in ipairs(KINDS) do
		local index = SurvivorUI_AutoMarkIcon(kind)
		if index and SurvivorUI_AutoMarkOn(kind) and not Taken(index) then
			for id, entry in pairs(alive) do
				if FightKind(entry) == kind and not known[id] and now - (tried[id] or -RETRY) >= RETRY then
					tried[id] = now
					local had, name = UnitExists("target"), Field(entry, "name", 3)
					TargetByName(name, true)
					-- Found by its name (the one wanted or another of it): the target moved.
					if UnitName("target") == name then
						aim = { id = id, index = index, had = had, step = "mark", at = now }
						if UnitId("target") ~= id then
							aim.step = "back"
						end
					end
					return
				end
			end
		end
	end
end

-- The mark by name, a step a tick: marked, then looked for, then the target
-- before put back (when the game did not move it on meanwhile).
local function Steps()
	local now = GetTime()
	local on = UnitId("target") == aim.id
	if aim.step == "mark" then
		if on and not GetRaidTargetIndex("target") then
			SetRaidTarget("target", aim.index)
			aim.step, aim.at = "check", now
			return
		end
		aim.step = "back"
	elseif aim.step == "check" then
		if on and GetRaidTargetIndex("target") == aim.index then
			markedAt[aim.id] = now
			Know(aim.id, aim.index)
			aim.step = "back"
		elseif not on or now - aim.at > CHECK then
			aim.step = "back"
		end
		return
	end
	if on then
		if aim.had then
			TargetLastTarget()
		else
			ClearTarget()
		end
	end
	aim = nil
end

-- The party's heroes, each its mark, one a tick.
local partyTried = {}           -- [hero's name] = when it was last asked to wear one
local function MarkParty()
	if not SurvivorUI_AutoMarkOn("party") or (GetNumPartyMembers and GetNumPartyMembers() or 0) == 0 then
		return
	end
	local units, names = {}, {}
	for _, unit in ipairs(PARTY_UNITS) do
		local name = UnitExists(unit) and UnitName(unit)
		if name and not units[name] then
			units[name] = unit
			table.insert(names, name)
		end
	end
	table.sort(names)
	local now = GetTime()
	for index = 1, table.getn(names) do
		local name = names[index]
		local unit, mark = units[name], SurvivorUI_PartyMarkIcon(index)
		if mark and mark > 0 and not GetRaidTargetIndex(unit) and now - (partyTried[name] or -PARTY_RETRY) >= PARTY_RETRY then
			partyTried[name] = now
			SetRaidTarget(unit, mark)
			return
		end
	end
end

-- Everything off and every row without a mark (the options' Uncheck all);
-- the marks on the heroes and on the target taken off, those the game lets
-- this hero reach. One on an enemy out of reach stays until it falls.
function SurvivorUI_ResetAutoMarks()
	local db = DB()
	for _, key in pairs(ON_KEYS) do
		db[key] = nil
	end
	for _, key in pairs(ICON_KEYS) do
		db[key] = 0
	end
	db.markPartyIcons = { 0, 0, 0, 0, 0 }
	if SetRaidTarget and GetRaidTargetIndex then
		for _, unit in ipairs(PARTY_UNITS) do
			if UnitExists(unit) and GetRaidTargetIndex(unit) then
				SetRaidTarget(unit, 0)
			end
		end
		if UnitExists("target") and GetRaidTargetIndex("target") then
			SetRaidTarget("target", 0)
		end
	end
	known, markedAt, tried, partyTried = {}, {}, {}, {}
	aim = nil
end

local function AnyOn()
	for _, kind in ipairs(KINDS) do
		if SurvivorUI_AutoMarkOn(kind) then
			return true
		end
	end
	return SurvivorUI_AutoMarkOn("party")
end

-- The target's mark over its frame (Survivor UI's), at the portrait's top.
local targetMark
local function ShowTargetMark()
	local frame = getglobal("SurvivorUITarget")
	if not frame then
		return
	end
	if not targetMark then
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetFrameLevel(frame:GetFrameLevel() + 6)
		holder:SetAllPoints(frame.portrait or frame)
		targetMark = holder:CreateTexture(nil, "OVERLAY")
		targetMark:SetWidth(18)
		targetMark:SetHeight(18)
		targetMark:SetPoint("CENTER", holder, "TOP", 0, 0)
	end
	SurvivorUI_SetRaidMarkTexture(targetMark, UnitExists("target") and GetRaidTargetIndex and GetRaidTargetIndex("target"))
end

local wait = 0
local watch = CreateFrame("Frame")
watch:RegisterEvent("RAID_TARGET_UPDATE")
watch:RegisterEvent("PLAYER_TARGET_CHANGED")
watch:SetScript("OnEvent", ShowTargetMark)
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < TICK then
		return
	end
	wait = 0
	ShowTargetMark()
	if not (AZS_UNITS and AZS_GetPhase) then
		return
	end
	alive = {}
	for index = 1, table.getn(AZS_UNITS) do
		local entry = AZS_UNITS[index]
		local id = tonumber(Field(entry, "id", 2))
		if id then
			alive[id] = entry
		end
	end
	for id in pairs(known) do
		if not alive[id] then
			known[id], markedAt[id], tried[id] = nil, nil, nil
		end
	end
	Read("target")
	Read("mouseover")
	if aim then
		Steps()
		return
	end
	if AZS_GetPhase() ~= "playing" or not AnyOn() or not SetRaidTarget then
		return
	end
	MarkParty()
	MarkTarget()
	if TargetByName then
		Aim()
	end
end)
