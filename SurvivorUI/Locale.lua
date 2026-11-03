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

if SurvivorUI_Standby then return end

local LOCALE = SurvivorUI_LOCALE or {}

-- The game's language: the game's own (AZS_MLang), known before any run. In a
-- game without it, or set to English, told by the hero's race as the game
-- names it (AZS_ZONE.rname), read again whenever that name changes (the game
-- set to another language between runs). Until it is known, every language is
-- tried. Read on first use, then again by the watch at the bottom.
local language
local raceSeen
local detected, fromGame = false, false

local function Detect()
	detected = true
	local code = AZS_MLang and AZS_MLang()
	if code and code ~= "en" and LOCALE[code] then
		language, fromGame = code, true
		return
	end
	if fromGame then
		language, raceSeen, fromGame = nil, nil, false
	end
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
end

local function Languages()
	if not detected then
		Detect()
	end
	if language then
		return { LOCALE[language] }
	end
	return LOCALE
end

-- The game's language as LocaleData names it ("de", "ru", "zh"...): nil for
-- English, or until the game or the hero's race has told.
function SurvivorUI_Language()
	Languages()
	return language
end

-- A talent: the game's list of names has none, but its meter's loadout (its
-- 0.132) says each one's English. Asked again now and then for a name not
-- there, as the next card can bring it.
local talents, talentsAt = {}, {}

local function TalentEnglish(name)
	if talents[name] then
		return talents[name]
	end
	local now = GetTime()
	if talentsAt[name] and now - talentsAt[name] < 5 then
		return name
	end
	talentsAt[name] = now
	local context = AZS_GetMeterContext and AZS_GetMeterContext()
	if not (context and context.runId and AZS_GetMeterLoadout) then
		return name
	end
	local loadout = AZS_GetMeterLoadout({ apiVersion = 1, runId = context.runId, ownerId = context.localOwnerId })
	for _, source in pairs(loadout and loadout.sources or {}) do
		if source.kind == "talent" and source.name and source.localizationKey then
			talents[source.name] = source.localizationKey
		end
	end
	return talents[name] or name
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
	if english == name and language then
		english = TalentEnglish(name)
		if english == name then
			return name
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
				-- A placeholder may end in a digit: {v2}.
				return (string.gsub(line[2], "{([%a_][%w_]*)}", function(key) return values[key] or "" end))
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
-- language is known, it stays English.
--
--   SurvivorUI_T("Biggest Crits")                  "最高暴击"
--   SurvivorUI_TF("{1} more to find", 3)          "还有3件待发现"
--   SurvivorUI_Native("Mind Blast")               "心灵震爆" (the game's name)

-- The table of the game's language, if the addon speaks it.
local function Words()
	local words = SurvivorUI_WORDS
	if not words then
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

-- A word after a number in the form the number asks for: {1:забег/забега/забегов}
-- is the first for 1, 21, 31..., the second for 2 to 4, 22 to 24..., the third
-- for the rest (5 to 20, 25 to 30..., 0), as Russian counts.
local function Counted(number, forms)
	local _, _, one, few, many = string.find(forms, "^([^/]*)/([^/]*)/([^/]*)$")
	if not one then
		return forms
	end
	number = math.abs(math.floor(tonumber(number) or 0))
	local units, tens = math.mod(number, 10), math.mod(number, 100)
	if units == 1 and tens ~= 11 then
		return one
	elseif units >= 2 and units <= 4 and (tens < 12 or tens > 14) then
		return few
	end
	return many
end

-- A text with values in it, {1} to {4} where each goes, so a language can put
-- them in its own order; {1:...} a word counted by {1}.
function SurvivorUI_TF(text, ...)
	local values = arg
	local counted = string.gsub(SurvivorUI_T(text), "{(%d):([^}]*)}", function(index, forms)
		return Counted(values[tonumber(index)], forms)
	end)
	return (string.gsub(counted, "{(%d)}", function(index)
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

-- Uppercases ASCII as well as UTF-8 Cyrillic characters.
function SurvivorUI_Upper(text)
	if not text then return text end
	local res = string.upper(text)
	local len = string.len(res)
	local i = 1
	local out = {}
	while i <= len do
		local b1 = string.byte(res, i)
		if b1 == 208 and i < len then
			local b2 = string.byte(res, i + 1)
			if b2 >= 176 and b2 <= 191 then
				table.insert(out, string.char(208, b2 - 32))
			else
				table.insert(out, string.char(b1, b2))
			end
			i = i + 2
		elseif b1 == 209 and i < len then
			local b2 = string.byte(res, i + 1)
			if b2 >= 128 and b2 <= 143 then
				table.insert(out, string.char(208, b2 + 32))
			elseif b2 == 145 then
				table.insert(out, string.char(208, 129))
			elseif b2 == 150 then
				table.insert(out, string.char(208, 134))
			elseif b2 == 151 then
				table.insert(out, string.char(208, 135))
			elseif b2 == 148 then
				table.insert(out, string.char(208, 132))
			else
				table.insert(out, string.char(b1, b2))
			end
			i = i + 2
		else
			table.insert(out, string.char(b1))
			i = i + 1
		end
	end
	return table.concat(out)
end

-- Lowercases ASCII and UTF-8 Cyrillic as SurvivorUI_Upper uppercases them,
-- for the options' search.
function SurvivorUI_Lower(text)
	if not text then return text end
	local res = string.lower(text)
	local len = string.len(res)
	local i = 1
	local out = {}
	while i <= len do
		local b1 = string.byte(res, i)
		if b1 == 208 and i < len then
			local b2 = string.byte(res, i + 1)
			if b2 >= 144 and b2 <= 159 then
				table.insert(out, string.char(208, b2 + 32))
			elseif b2 >= 160 and b2 <= 175 then
				table.insert(out, string.char(209, b2 - 32))
			elseif b2 == 129 then
				table.insert(out, string.char(209, 145))
			elseif b2 == 132 or b2 == 134 or b2 == 135 then
				table.insert(out, string.char(209, b2 + 16))
			else
				table.insert(out, string.char(b1, b2))
			end
			i = i + 2
		else
			table.insert(out, string.char(b1))
			i = i + 1
		end
	end
	return table.concat(out)
end

-- Whether the addon speaks the game's language (its words not English).
function SurvivorUI_Translated()
	return Words() ~= nil
end

-- The languages the options window is translated into; in any other it stays
-- English, not half of it in another language.
SurvivorUI_OPTIONS_LANGUAGES = { ru = true }

function SurvivorUI_OptionsTranslated()
	return Words() ~= nil and SurvivorUI_OPTIONS_LANGUAGES[language] == true
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
	-- A talent: the game's list of names has spells, pets and jewelry, so the
	-- addon's own words hold these.
	return native or Words()[name] or name
end

-- The texts already on screen as the language turns up (set before it was
-- known, as the files ran) put in it: every font string of the addon's
-- frames whose text is one of its words, the options window's left out in a
-- language it is not translated into (it stays English there). Each keeps its
-- English, so the game set back to English puts that back.
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
				and (string.find(name, "^SurvivorUIOptions") == nil or SurvivorUI_OptionsTranslated())
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
local zoneSeen, elapsed = nil, 0

local function CheckLanguage()
	Detect()
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
end

languageWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
languageWatch:RegisterEvent("VARIABLES_LOADED")
languageWatch:SetScript("OnEvent", function()
	CheckLanguage()
end)

languageWatch:SetScript("OnUpdate", function()
	elapsed = elapsed + (arg1 or 0)
	if elapsed < 0.5 and AZS_ZONE_UPDATED == zoneSeen then
		return
	end
	elapsed = 0
	zoneSeen = AZS_ZONE_UPDATED
	CheckLanguage()
end)
