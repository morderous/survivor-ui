-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a Heroic run's affixes, the week's (the game's 0.121 on).
--
-- From the game's 0.124 its zone line (AZS_ZONE) names them itself,
-- "affixes=sanguine,explosive" (in English, in its order; empty with none),
-- and those are the run's: the first from Heroic III, the second from V. An
-- affix newer than this file shows by its name alone.
--
-- Before 0.124 the game did not tell addons its affixes: its zone line had
-- the Heroic level only. So they are worked out as the game picks them, as
-- read in its exe (0.121): the week, whole weeks of Unix time (it turns on
-- Thursdays at 00:00 UTC); the zone's number; seed = the zone's number + 7 x
-- the week. Below Heroic III, none; III and IV, one, AFFIXES[seed % 3]; V, a
-- second, AFFIXES[(seed % 3 + 1 + floor(seed / 3) % 2) % 3]. A run keeps the
-- week it began in.
--
-- The game tells them itself as the run begins, a line in the chat ("Heroic
-- V · Sanguine: ... · Explosive: ...", in its language): from then on those
-- are the run's, the reckoning only standing in before it (or after a
-- reload). And an Explosive Orb comes with a banner ("An Explosive Orb
-- appears!"). Told or seen otherwise than foretold, the game picks them
-- some other way now: from then on, until the addon is updated, only what
-- the game told or showed is shown.
--
-- SurvivorUI_RunAffixes(): the run's, { name, text, from, seen } each, for
-- the run tracker (Tracker.lua) and Run History's copy of it.

-- Each with its symbol for the tracker's short tags (Art\Affix*.tga: two
-- chevrons up, a drop, a flame).
if SurvivorUI_Standby then return end

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
-- And with its name in each of the game's languages, for the run's start
-- line.
local AFFIXES = {
	{ name = "Bolstering", symbol = ART.."AffixBolstering",
		text = "A death makes the enemies near it tougher and stronger, stacking.",
		names = { "Bolstering", "Wzmacniający", "Posilující", "Anstachelnd", "Fortalecente", "Reforzante", "Galvanisant",
			"Întăritor", "Güçlendiren", "Усиливающий", "Підсилювальний", "激励", "強化", "강화" } },
	{ name = "Sanguine", symbol = ART.."AffixSanguine",
		text = "A slain elite leaves a pool that heals enemies standing in it.",
		names = { "Sanguine", "Krwawy", "Krvavý", "Blutig", "Sanguíneo", "Sanguinario", "Sanguin", "Sângeros", "Kanlı",
			"Кровавый", "Кривавий", "血池", "血溜まり", "피웅덩이" } },
	{ name = "Explosive", symbol = ART.."AffixExplosive",
		text = "Orbs come out of the horde: only direct hits hurt them, so kill them before they burst.",
		names = { "Explosive", "Wybuchowy", "Výbušný", "Explosiv", "Explosivo", "Explosif", "Exploziv", "Patlayıcı",
			"Взрывной", "Вибуховий", "易爆", "爆発", "폭발" } },
}
local EXPLOSIVE = 3
local WEEK = 604800

-- The zones' numbers, by the key the game sends (AZS_ZONE.zone). A zone not
-- here (one added since) is not foretold.
local ZONES = {
	elwynn = 0, duskwood = 1, wsg = 2, ungoro = 3, ab = 4, feralas = 5,
	arena = 6, sm = 7, av = 8, brm = 9, aq = 10, naxx = 11,
}

-- The Explosive Orb's banner, in each of the game's languages.
local ORB_BANNERS = {
	["An Explosive Orb appears! Destroy it before it bursts!"] = true,
	["Pojawia się Wybuchowa kula! Zniszcz ją, zanim wybuchnie!"] = true,
	["Objevuje se Výbušná koule! Znič ji, než vybuchne!"] = true,
	["Eine Explosive Kugel erscheint! Zerstört sie, bevor sie platzt!"] = true,
	["Um Orbe Explosivo aparece! Destrua-o antes que exploda!"] = true,
	["¡Aparece un orbe explosivo! ¡Destrúyelo antes de que estalle!"] = true,
	["Un Orbe explosif apparaît ! Détruisez-le avant qu'il n'éclate !"] = true,
	["Apare un Glob exploziv! Distruge-l înainte să explodeze!"] = true,
	["Bir Patlayıcı Küre belirdi! Patlamadan önce yok et!"] = true,
	["Появилась взрывная сфера! Уничтожьте её, пока она не взорвалась!"] = true,
	["З'явилася вибухова сфера! Знищте її, поки вона не вибухнула!"] = true,
	["易爆宝珠出现了！在它爆炸前摧毁它！"] = true,
	["爆発オーブが出現！弾ける前に破壊しろ！"] = true,
	["폭발 구슬이 나타났습니다! 터지기 전에 파괴하세요!"] = true,
}

-- The addon's version: the rule found wrong under it stays off until the
-- addon changes.
local VERSION = GetAddOnMetadata and GetAddOnMetadata("SurvivorUI", "Version") or "?"

local function Broken()
	return SurvivorUIDB ~= nil and SurvivorUIDB.affixesWrongIn == VERSION
end

-- The affixes the game picks for a zone, a Heroic level and a week: their
-- numbers, each with the level it comes from.
local function Picked(zone, heroic, week)
	local number = ZONES[zone]
	if not number or heroic < 3 then
		return {}
	end
	local seed = number + 7 * week
	local first = math.mod(seed, 3)
	local picked = { { index = first + 1, from = 3 } }
	if heroic >= 5 then
		local second = math.mod(first + 1 + math.mod(math.floor(seed / 3), 2), 3)
		table.insert(picked, { index = second + 1, from = 5 })
	end
	return picked
end

-- The run: its week, from when it began (now, less the run's clock), kept
-- for the run; the affixes the game has shown in it. A new run: the clock
-- gone back.
local runWeek, lastTime
local seen = {}

local function Watch()
	local now = AZS_GetRunTime and AZS_GetRunTime() or 0
	if not lastTime or now + 3 < lastTime then
		runWeek = math.floor((time() - now) / WEEK)
		seen = {}
	end
	lastTime = now
end

local function Foretold()
	local zone = AZS_ZONE
	local heroic = zone and tonumber(zone.heroic)
	if not (heroic and zone.zone) then
		return nil
	end
	Watch()
	return Picked(zone.zone, heroic, runWeek)
end

-- The affixes the game names itself (0.124 on): each the number of one known
-- here, else its name as the game sends it; nil from a game that sends none.
local function Given()
	local given = AZS_ZONE and AZS_ZONE.affixes
	if given == nil then
		return nil
	end
	Watch()
	local list = {}
	for name in string.gfind(tostring(given), "[^,]+") do
		local found = string.gsub(name, "^%s*(.-)%s*$", "%1")
		for index = 1, table.getn(AFFIXES) do
			if string.lower(AFFIXES[index].name) == string.lower(found) then
				found = index
				break
			end
		end
		if found ~= "" then
			table.insert(list, found)
		end
	end
	return list
end

-- The affixes the game told at the run's start (their numbers, in its
-- order), kept with when: they hold for the run begun before them.
local told, toldAt

local function Told()
	if not told then
		return nil
	end
	local now = AZS_GetRunTime and AZS_GetRunTime() or 0
	if toldAt < time() - now - 10 then
		return nil
	end
	return told
end

-- For a look from the chat (/script): the affixes told for this run, by
-- name, or nil.
function SurvivorUI_AffixesTold()
	local said = Told()
	if not said then
		return nil
	end
	local names = {}
	for each = 1, table.getn(said) do
		table.insert(names, AFFIXES[said[each]].name)
	end
	return table.concat(names, ", ")
end

-- The rule found wrong, once said in the chat.
local function FoundWrong()
	if SurvivorUIDB and not Broken() then
		SurvivorUIDB.affixesWrongIn = VERSION
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Survivor UI:|r "..SurvivorUI_T("the game picks its affixes another way now: the run tracker shows only the ones seen, until Survivor UI is updated."))
	end
end

function SurvivorUI_RunAffixes()
	local list = {}
	-- As the game names them (0.124 on).
	local given = Given()
	if given then
		for each = 1, table.getn(given) do
			local index = given[each]
			local from = each == 1 and 3 or 5
			if type(index) == "number" then
				local affix = AFFIXES[index]
				table.insert(list, { name = affix.name, text = affix.text, symbol = affix.symbol, from = from,
					seen = seen[index] or nil })
			else
				-- An affix newer than this file: its name, capitalized.
				local name = string.upper(string.sub(index, 1, 1))..string.sub(index, 2)
				table.insert(list, { name = name, from = from })
			end
		end
		return list
	end
	local picked = Foretold()
	if not picked then
		return nil
	end
	-- As the game told them, each its level from the reckoning when it agrees.
	local said = Told()
	if said then
		for each = 1, table.getn(said) do
			local affix, from = AFFIXES[said[each]], nil
			for one = 1, table.getn(picked) do
				if picked[one].index == said[each] then
					from = picked[one].from
				end
			end
			table.insert(list, { name = affix.name, text = affix.text, symbol = affix.symbol, from = from,
				seen = seen[said[each]] or nil })
		end
		return list
	end
	if Broken() then
		-- The rule found wrong: only what the game has shown.
		for index = 1, table.getn(AFFIXES) do
			if seen[index] then
				table.insert(list, { name = AFFIXES[index].name, text = AFFIXES[index].text,
					symbol = AFFIXES[index].symbol, seen = true })
			end
		end
		return list
	end
	for each = 1, table.getn(picked) do
		local affix = AFFIXES[picked[each].index]
		table.insert(list, { name = affix.name, text = affix.text, symbol = affix.symbol,
			from = picked[each].from, seen = seen[picked[each].index] or nil })
	end
	return list
end

-- The run's affixes by name ("Sanguine", "Explosive"), for Run History to
-- keep with the run; nil with none.
function SurvivorUI_RunAffixNames()
	local list = SurvivorUI_RunAffixes()
	if not list or table.getn(list) == 0 then
		return nil
	end
	local names = {}
	for each = 1, table.getn(list) do
		table.insert(names, list[each].name)
	end
	return names
end

-- An affix by its name: { name, text, symbol }, or nil.
function SurvivorUI_AffixInfo(name)
	for index = 1, table.getn(AFFIXES) do
		if AFFIXES[index].name == name then
			return AFFIXES[index]
		end
	end
end

-- An affix's tag: its description under the mouse, the level it comes from
-- this week, and whether the run has shown it.
function SurvivorUI_AffixTip(tag)
	tag:EnableMouse(true)
	tag:SetScript("OnEnter", function()
		local entry = this.affix
		if not entry then
			return
		end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(SurvivorUI_T(entry.name), 1, 0.35, 0.29)
		if entry.text then
			GameTooltip:AddLine(SurvivorUI_T(entry.text), 1, 1, 1, 1)
		end
		if entry.from and SurvivorUI_HeroicName then
			GameTooltip:AddLine(SurvivorUI_TF("This week, from {1}", SurvivorUI_HeroicName(entry.from)), 0.6, 0.6, 0.65)
		end
		if entry.seen then
			GameTooltip:AddLine(SurvivorUI_T("Seen in this run."), 0.55, 0.85, 0.55)
		end
		GameTooltip:Show()
	end)
	tag:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The game's banners: an Explosive Orb's shows the affix. Not foretold for
-- this run, the rule is found wrong, once said in the chat.
local function OnBanner(banner)
	local text = string.gsub(banner.text or "", "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	if not (ORB_BANNERS[text] or string.find(text, "Explosive Orb", 1, true)) then
		return
	end
	-- Named by the game: seen, nothing to check.
	if Given() then
		seen[EXPLOSIVE] = true
		return
	end
	local picked = Foretold()
	if not picked then
		return
	end
	seen[EXPLOSIVE] = true
	for each = 1, table.getn(picked) do
		if picked[each].index == EXPLOSIVE then
			return
		end
	end
	FoundWrong()
end

-- The game's line at the run's start: its affixes, each name followed by a
-- colon, between middle dots. Told otherwise than foretold, the rule is
-- found wrong.
local MIDDLE_DOT = "\194\183"
local function OnSystem(message)
	local text = string.gsub(message or "", "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	if not string.find(text, MIDDLE_DOT, 1, true) then
		return
	end
	local places, order = {}, {}
	for index = 1, table.getn(AFFIXES) do
		local names = AFFIXES[index].names
		for each = 1, table.getn(names) do
			local at = string.find(text, names[each]..":", 1, true) or string.find(text, names[each].."\239\188\154", 1, true)
			if at then
				places[index] = at
				table.insert(order, index)
				break
			end
		end
	end
	if table.getn(order) == 0 then
		return
	end
	table.sort(order, function(a, b) return places[a] < places[b] end)
	told, toldAt = order, time()
	-- Named by the game (0.124 on), the rule is not checked.
	if Given() then
		return
	end
	local picked = Foretold()
	if not picked or Broken() then
		return
	end
	local same = table.getn(picked) == table.getn(order)
	for each = 1, table.getn(picked) do
		if not places[picked[each].index] then
			same = false
		end
	end
	if not same then
		FoundWrong()
	end
end

local hook = CreateFrame("Frame")
hook:RegisterEvent("PLAYER_ENTERING_WORLD")
hook:RegisterEvent("CHAT_MSG_SYSTEM")
hook:SetScript("OnEvent", function()
	if event == "CHAT_MSG_SYSTEM" then
		OnSystem(arg1)
	elseif AZS_RegisterBannerHandler then
		AZS_RegisterBannerHandler(OnBanner)
	end
end)
