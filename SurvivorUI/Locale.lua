-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the game's words back in English, for a game set to another
-- language.
--
-- The game translates its spells, items and bonus lines ("Spalten" for
-- Cleave, "+6% kritische Trefferchance"), while the client's combat log and
-- spellbook stay in English, and so do the addon's own lists (the codex, the
-- short names). Whatever the addon matches goes through English first:
--
--   SurvivorUI_English("Spalten")                      "Cleave"
--   SurvivorUI_EnglishLine("+6% kritische Trefferchance")  "+6% critical strike"
--
-- Anything already English, or not known, comes back as it was. The words
-- are the game's own (LocaleData.lua, written from its translation tables).

local LOCALE = SurvivorUI_LOCALE or {}

-- The game's language: told by the hero's race as the game names it
-- (AZS_ZONE.rname), read again whenever that name changes (the game set to
-- another language between runs). Until it is known, every language is tried.
local language
local raceSeen

local function Languages()
	local race = AZS_ZONE and AZS_ZONE.rname
	if race and race ~= raceSeen then
		raceSeen = race
		local matches, which = 0, nil
		for code, data in pairs(LOCALE) do
			for _, name in pairs(data.races or {}) do
				if name == race then
					matches, which = matches + 1, code
				end
			end
		end
		-- "Orc" is Orc in several: a name of one language only says which; a
		-- name of none is English's.
		if matches == 1 then
			language = which
		elseif matches == 0 then
			language = nil
		end
	end
	if language then
		return { LOCALE[language] }
	end
	return LOCALE
end

-- The game's language as LocaleData names it ("de", "ru", "zh"...): nil for
-- English, or until the hero's race has told.
function SurvivorUI_Language()
	Languages()
	return language
end

local names = {}     -- the answers so far
function SurvivorUI_English(name)
	if not name or name == "" then
		return name
	end
	local known = names[name]
	if known then
		return known
	end
	local english = name
	for _, data in pairs(Languages()) do
		if data.names and data.names[name] then
			english = data.names[name]
			break
		end
	end
	-- A class amulet: "Amulett des Infernos: Weihe", its spell after the colon.
	if english == name then
		local _, _, before, spell = string.find(name, "^(.-): (.+)$")
		if spell then
			for _, data in pairs(Languages()) do
				if data.names and data.names[spell] then
					english = before..": "..data.names[spell]
					break
				end
			end
		end
	end
	names[name] = english
	return english
end

-- A bonus line, read again in English: its numbers put in the English words.
local function Translate(text)
	for _, data in pairs(Languages()) do
		for _, line in pairs(data.lines or {}) do
			local found = { string.find(text, line[1]) }
			if found[1] then
				local values = {}
				for index = 1, table.getn(line[3]) do
					values[line[3][index]] = found[index + 2] or ""
				end
				return (string.gsub(line[2], "{([%a_]+)}", function(key) return values[key] or "" end))
			end
		end
	end
end

local lines = {}
function SurvivorUI_EnglishLine(text)
	if not text or text == "" or not string.find(text, "%d") then
		return text
	end
	if lines[text] then
		return lines[text]
	end
	local english = Translate(text)
	-- The client's own words before the game's stay English: "Equip: Erhöht
	-- den Schaden deiner kritischen Treffer um 29%."
	if not english then
		local _, _, prefix, rest = string.find(text, "^([%a ]+: )(.+)$")
		local translated = rest and Translate(rest)
		english = translated and prefix..translated
	end
	english = english or text
	lines[text] = english
	return english
end

------------------------------------------------------------------------------
-- The other way: the addon's own words in the game's language, for the
-- languages the addon is translated into (Locale_zh.lua: Chinese, its game
-- terms the game's own words, the rest translated for it). Every text the
-- addon shows goes through these; in any other language, or until the
-- hero's race has told, it stays English.
--
--   SurvivorUI_T("Biggest Crits")                  "最高暴击"
--   SurvivorUI_TF("{1} more to find", 3)          "还有3件待发现"
--   SurvivorUI_Native("Mind Blast")               "心灵震爆" (the game's name)

-- The table of the game's language, if the addon speaks it.
local function Words()
	local words = SurvivorUI_WORDS
	if not (words and AZS_ZONE and AZS_ZONE.rname) then
		return nil
	end
	Languages()
	return language and words[language]
end

function SurvivorUI_T(text)
	local words = Words()
	local found = words and text and words[text]
	if found then
		return found
	end
	-- Two texts that read the same in English and not in another language
	-- are told apart by a word before them, "@number:run {1}": shown without it.
	if text and string.sub(text, 1, 1) == "@" then
		local _, _, rest = string.find(text, "^@%a+:(.*)$")
		return rest or text
	end
	return text
end

-- A text with values in it, {1} to {4} where each goes, so a language can put
-- them in its own order.
function SurvivorUI_TF(text, ...)
	local values = arg
	return (string.gsub(SurvivorUI_T(text), "{(%d)}", function(index)
		local value = values[tonumber(index)]
		return value ~= nil and tostring(value) or ""
	end))
end

-- A text's first count characters, one of several bytes (Chinese's three)
-- kept whole, where string.sub would cut it.
function SurvivorUI_Cut(text, count)
	text = text or ""
	local index, chars, length = 1, 0, string.len(text)
	while index <= length and chars < count do
		local byte = string.byte(text, index)
		index = index + (byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1)
		chars = chars + 1
	end
	return string.sub(text, 1, index - 1)
end

-- Whether the addon speaks the game's language (its words not English).
function SurvivorUI_Translated()
	return Words() ~= nil
end

-- A name of the game's (a spell, a pet, a piece of jewelry) as the game writes
-- it in its language, in a language the addon speaks, else in English. A name
-- kept in another language (a run played in it, its records) goes through
-- English first, so it never shows in letters the font of the moment lacks.
local natives, loose, nativesOf = {}, {}, nil

-- A name without case, spaces or marks: "Curse Of Agony" and "Soul Fire"
-- find "Curse of Agony" and "Soulfire".
local function Loose(name)
	return (string.gsub(string.lower(name), "[^%a%d]", ""))
end

function SurvivorUI_Native(name)
	if not name then
		return name
	end
	local _, _, owner, spell = string.find(name, "^(.-)'s (.+)$")
	if owner then
		name = SurvivorUI_English(owner).."'s "..spell
	else
		name = SurvivorUI_English(name)
	end
	if not Words() then
		return name
	end
	if nativesOf ~= language then
		nativesOf, natives, loose = language, {}, {}
		for native, english in pairs(LOCALE[language] and LOCALE[language].names or {}) do
			if not natives[english] then
				natives[english] = native
				loose[Loose(english)] = native
			end
		end
	end
	local native = natives[name] or loose[Loose(name)]
	if not native then
		-- A pet's own spell as the combat log names it: "Imp's Fireball".
		local _, _, pet, spell = string.find(name, "^(.-)'s (.+)$")
		if pet and natives[pet] then
			native = SurvivorUI_TF("{1}'s {2}", natives[pet], natives[spell] or spell)
		end
		-- A class amulet, "Amulet of the Inferno: Consecration": its spell.
		local _, _, before, boosted = string.find(name, "^(.-): (.+)$")
		if not native and boosted and natives[boosted] then
			native = before..": "..natives[boosted]
		end
	end
	return native or name
end

-- The texts already on screen as the language turns up (set before it was
-- known, as the files ran) put in it: every font string of the addon's
-- frames whose text is one of its words, the options window's left out
-- (it stays English for now, not half of it in another language). Each
-- keeps its English, so the game set back to English puts that back.
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
			return string.find(name, "^SurvivorUI") ~= nil and string.find(name, "^SurvivorUIOptions") == nil
				and name ~= "SurvivorUILinkBox"
		end
		at = at:GetParent()
	end
	return false
end

local function Retell(frame)
	local regions = { frame:GetRegions() }
	for index = 1, table.getn(regions) do
		local region = regions[index]
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local text = region:GetText()
			if text then
				-- Its English kept, unless its text was changed since.
				local english = region.suiEnglish
				if not (english and (text == english or text == region.suiShown)) then
					english = text
				end
				local shown = SurvivorUI_T(english)
				if shown ~= text then
					region:SetText(shown)
				end
				if shown ~= english then
					region.suiEnglish, region.suiShown = english, shown
				end
			end
		end
	end
end

local spoken = false
local languageWatch = CreateFrame("Frame")
local zoneSeen
languageWatch:SetScript("OnUpdate", function()
	if AZS_ZONE_UPDATED == zoneSeen then
		return
	end
	zoneSeen = AZS_ZONE_UPDATED
	local now = Words() or false
	if now == spoken then
		return
	end
	spoken = now
	local frame = EnumerateFrames and EnumerateFrames()
	while frame do
		if Ours(frame) then
			Retell(frame)
		end
		frame = EnumerateFrames(frame)
	end
end)
