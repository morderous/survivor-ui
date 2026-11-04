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

-- The game's language: its meter API names it (AZS_GetMeterCapabilities,
-- languageCode, from the game's 0.139), as the files run and before any run,
-- Russian apart from Ukrainian too; asked again at most once a second. A game
-- without it is told by the hero's race as the game names it (AZS_ZONE.rname),
-- read again whenever that name changes (the game set to another language
-- between runs). Until it is known, every language is tried.
local language
local raceSeen
local fromGame, askedAt

local function FromGame()
	if not AZS_GetMeterCapabilities then
		return nil
	end
	local now = GetTime()
	if askedAt and now - askedAt < 1 then
		return fromGame
	end
	askedAt = now
	local ok, capabilities = pcall(AZS_GetMeterCapabilities)
	local code = ok and type(capabilities) == "table" and capabilities.languageCode
	if type(code) == "string" and code ~= "" then
		fromGame = code
	end
	return fromGame
end

-- By the race: Russian and Ukrainian name five races alike (Орк, Дворф,
-- Нежить, Таурен, Гном). The hero's other words, which the game also gives in
-- its language (its class, its zone and the zone's line under it), tell them
-- apart by the letters only one of the two writes.
local OWN_LETTERS = {
	ru = { "ы", "э", "ъ", "ё", "Э", "Ё" },
	uk = { "і", "ї", "є", "ґ", "І", "Ї", "Є", "Ґ" },
}

local function ByLetters(candidates)
	local zone = AZS_ZONE or {}
	local words = (zone.rname or "").." "..(zone.cname or "").." "..(zone.zname or "").." "..(zone.zsub or "")
	local which
	for code in pairs(candidates) do
		for _, letter in pairs(OWN_LETTERS[code] or {}) do
			if string.find(words, letter, 1, true) then
				if which and which ~= code then
					return nil
				end
				which = code
				break
			end
		end
	end
	return which
end

local function ByRace()
	local race = AZS_ZONE and AZS_ZONE.rname
	if not race or race == raceSeen then
		return
	end
	raceSeen = race
	local matches, which, candidates = 0, nil, {}
	for code, data in pairs(LOCALE) do
		for _, name in pairs(data.races or {}) do
			if name == race then
				matches, which = matches + 1, code
				candidates[code] = true
			end
		end
	end
	-- "Orc" is Orc in several: a name of one language only says which; a
	-- name of none is English's. Several keep the language as it was, unless
	-- the letters tell Russian from Ukrainian.
	if matches == 1 then
		language = which
	elseif matches == 0 then
		language = nil
	else
		language = ByLetters(candidates) or language
	end
end

local function Told()
	local code = FromGame()
	if code then
		-- English, or a language LocaleData does not have, is English here.
		language = LOCALE[code] and code or nil
	else
		ByRace()
	end
end

local function Languages()
	Told()
	if language then
		return { LOCALE[language] }
	end
	return LOCALE
end

-- The game's language as LocaleData names it ("de", "ru", "zh"...): nil for
-- English, or until the game has told.
function SurvivorUI_Language()
	Told()
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
-- languages the addon is translated into (Locale_zh.lua: Chinese,
-- Locale_ru.lua: Russian; their game terms the game's own words, the rest
-- translated for them). Every text the addon shows goes through these; in
-- any other language, or until the game has told its language, it stays
-- English.
--
--   SurvivorUI_T("Biggest Crits")                  "最高暴击"
--   SurvivorUI_TF("{1} more to find", 3)          "还有3件待发现"
--   SurvivorUI_Native("Mind Blast")               "心灵震爆" (the game's name)

-- The table of the game's language, if the addon speaks it.
local function Words()
	-- Not before the run's zone has come, even with the language known: texts
	-- set before it stay English, so the pass below can tell each one's English
	-- (and put it back, should the language change).
	local words = SurvivorUI_WORDS
	if not (words and AZS_ZONE and AZS_ZONE.rname) then
		return nil
	end
	Told()
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
	-- A talent: the game's list of names has spells, pets and jewelry, so the
	-- addon's own words hold these.
	return native or Words()[name] or name
end

-- The texts already on screen as the language turns up (set before it was
-- known, as the files ran) put in it: every font string of the addon's
-- frames whose text is one of its words, the options window's left out
-- (it has words of its own, and its own pass: below). Each keeps its
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
		-- A font string of the options window's speaks its own words (below).
		if not region.suiSet and region.GetObjectType and region:GetObjectType() == "FontString" then
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

-- Russian is written in the face chosen (the global font, a piece's own) when
-- that face has every letter the addon writes in Russian: А to я, Ё and ё, and
-- the signs its Russian uses besides (« » — ·; a run's number is "#", not
-- "№", which Morpheus, Skurri and Expressway lack). A face short of one would
-- draw it from a face of the game's, and the engine mixes up a face's letters
-- with those it borrows from another (SurvivorUI.lua, the global font), or
-- draw nothing there: such a face gives way to the addon's Noto Sans SC, whose
-- Cyrillic is whole. The faces that have them all (SurvivorUI_WRITERS.ru), by
-- their cmaps, read with fontTools on 2026-11-04 (the game's 0.140): the
-- addon's Fonts folder, and the game's own faces as the game reads them, Arial
-- Narrow out of its patch.MPQ, and Friz Quadrata, Morpheus and Skurri out of
-- AzerothSurvivors.exe, which carries them with Cyrillic ("Friz Quadrata TT",
-- "Morpheus Cyr", "Skurri Cyr"; the 1.12 files in patch.MPQ have none):
--   all of them: Friz Quadrata, Arial Narrow, Fira Sans, Noto Sans, Russo
--     One, Noto Sans SC; and, short only of a № the addon no longer writes,
--     Morpheus, Skurri, Expressway (dropped in, not shipped);
--   no Cyrillic: Exo, Cinzel Decorative, Barlow Condensed, Barlow Semi
--     Condensed.
-- A face in no list is taken for one short of them.
SurvivorUI_LANGUAGE_FONTS = SurvivorUI_LANGUAGE_FONTS or {}
SurvivorUI_LANGUAGE_FONTS.ru = "Interface\\AddOns\\SurvivorUI\\Fonts\\NotoSansSC-Medium.ttf"
SurvivorUI_WRITERS = SurvivorUI_WRITERS or {}
SurvivorUI_WRITERS.ru = {
	["fonts\\frizqt__.ttf"] = true,
	["fonts\\arialn.ttf"] = true,
	["interface\\addons\\survivorui\\fonts\\firasans-medium.ttf"] = true,
	["interface\\addons\\survivorui\\fonts\\notosans-medium.ttf"] = true,
	["interface\\addons\\survivorui\\fonts\\russoone-regular.ttf"] = true,
	["interface\\addons\\survivorui\\fonts\\notosanssc-medium.ttf"] = true,
	["fonts\\morpheus.ttf"] = true,
	["fonts\\skurri.ttf"] = true,
	["interface\\addons\\survivorui\\fonts\\expressway.ttf"] = true,
}

local spoken = false
local languageWatch = CreateFrame("Frame")
local zoneSeen, languageSeen
languageWatch:SetScript("OnUpdate", function()
	-- The language changed without a new zone (the game's API answering, or
	-- its setting changed) is seen here too, and its face worn.
	Told()
	if AZS_ZONE_UPDATED == zoneSeen and language == languageSeen then
		return
	end
	zoneSeen, languageSeen = AZS_ZONE_UPDATED, language
	if SurvivorUI_FitGlobalFont then
		SurvivorUI_FitGlobalFont()
	end
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

------------------------------------------------------------------------------
-- The options window in the game's language: its words in a table of their
-- own (Locale_zh_Options.lua: SurvivorUI_OPTION_WORDS.zh, the window's
-- English to the language's), the rest of the addon's (Locale_zh.lua) after
-- them. A language with no table of the window's own leaves it all English.
--
-- The window is made in English as the files run, every piece laid out by
-- its English. Each of its font strings is spoken (SurvivorUI_Spoken): what
-- is set on it goes through the window's words as it is set, its English
-- kept. As it opens in a language the addon has its words in (Options.lua
-- asks, SurvivorUI_SpeakOptions), every text already in it is set again, in
-- that language; the game set back to English, in English. A text not found
-- is looked for again in capitals as it was written ("NUMBERS" by
-- "Numbers"), as a name of the game's (SurvivorUI_Native), with its numbers
-- out ("6 px" by "{1} px"), and piece by piece when it is a list ("Simple /
-- Advanced", "Auto Shot, 32 yd"). Two texts that read the same in English and
-- not in another language are told apart by a word before them, as
-- SurvivorUI_T's: "@grow:Left" (the way a row grows) is "Left" in English.
--
--   SurvivorUI_OT("Reset this page")         "重置本页"
--   SurvivorUI_OTF("{1} found.", 3)         "找到 3 项。"

local spokenIn                  -- the language the window speaks: nil for English
local said, saidCount = {}, 0   -- its texts so far, as they read in it
local capitals                  -- the tables' words by their keys in capitals
local JOINTS = { [" / "] = "(.-) / ", [", "] = "(.-), " }

local function Found(text, own, rest)
	local found = own[text] or (rest and rest[text])
	if found or string.upper(text) ~= text or not string.find(text, "%a") then
		return found
	end
	if not capitals then
		capitals = {}
		for key, value in pairs(rest or {}) do
			capitals[string.upper(key)] = value
		end
		for key, value in pairs(own) do
			capitals[string.upper(key)] = value
		end
	end
	return capitals[text]
end

-- A text with its numbers out, {1} to {9}, its color codes kept: "{1} px"
-- for "6 px", and the numbers.
local function Shape(text)
	local codes, values = {}, {}
	local shape = string.gsub(text, "|c%x%x%x%x%x%x%x%x", function(code)
		table.insert(codes, code)
		return "\1"
	end)
	shape = string.gsub(shape, "%d[%d,%.]*", function(number)
		local _, _, digits, tail = string.find(number, "^(.-)([,%.]*)$")
		table.insert(values, digits)
		return "{"..table.getn(values).."}"..tail
	end)
	local index = 0
	shape = string.gsub(shape, "\1", function()
		index = index + 1
		return codes[index]
	end)
	return shape, values
end

-- A text without the words that tell it apart ("@grow:Left" as "Left"): in
-- English, or in a language with no words of its own for it.
local function Plain(text)
	if type(text) == "string" and string.find(text, "@", 1, true) then
		return (string.gsub(text, "@%a+:", ""))
	end
	return text
end

local function Spoken(text)
	-- No letters (a number, a clock, words already in the language): as it is.
	if not string.find(text, "%a") then
		return text
	end
	local own = SurvivorUI_OPTION_WORDS[spokenIn]
	local rest = SurvivorUI_WORDS and SurvivorUI_WORDS[spokenIn]
	local found = Found(text, own, rest)
	if found then
		return found
	end
	-- A name of the game's (a spell of the build list's preview): its own.
	if string.len(text) < 40 and not string.find(text, "[%d|;,.!?]") then
		local native = SurvivorUI_Native(text)
		if native ~= text then
			return native
		end
	end
	if string.find(text, "%d") and not string.find(text, "{%d}") then
		local shape, values = Shape(text)
		local form = table.getn(values) <= 9 and Found(shape, own, rest)
		if form then
			return (string.gsub(form, "{(%d)}", function(index) return values[tonumber(index)] or "" end))
		end
	end
	-- A list ("Simple / Advanced", "Auto Shot, 32 yd"): each piece found, or
	-- with no letters, joined as the language joins them (its own ", ").
	for joint, pattern in pairs(JOINTS) do
		if string.find(text, joint, 1, true) then
			local pieces, changed, whole = {}, false, true
			for piece in string.gfind(text..joint, pattern) do
				local shown = SurvivorUI_OT(piece)
				changed = changed or shown ~= piece
				whole = whole and (shown ~= piece or not string.find(piece, "%a%a"))
				table.insert(pieces, shown)
			end
			if changed and whole then
				return table.concat(pieces, own[joint] or joint)
			end
		end
	end
	return Plain(text)
end

function SurvivorUI_OT(text)
	if not spokenIn or type(text) ~= "string" or text == "" then
		return Plain(text)
	end
	local known = said[text]
	if not known then
		known = Spoken(text)
		if saidCount >= 3000 then
			said, saidCount = {}, 0
		end
		said[text], saidCount = known, saidCount + 1
	end
	return known
end

-- A text with values in it, {1} to {4} where each goes, as SurvivorUI_TF.
function SurvivorUI_OTF(text, ...)
	local values = arg
	return (string.gsub(SurvivorUI_OT(text), "{(%d)}", function(index)
		local value = values[tonumber(index)]
		return value ~= nil and tostring(value) or ""
	end))
end

-- Set on a font string: in a language whose letters its face lacks (one of
-- the previews' faces, Latin only), the language's own face (SurvivorUI.lua's
-- SurvivorUI_LANGUAGE_FONTS) once the addon wears it.
local function Put(region, text)
	if spokenIn and type(text) == "string" and string.find(text, "[\128-\255]") then
		local face = SurvivorUI_LANGUAGE_FONTS and SurvivorUI_LANGUAGE_FONTS[spokenIn]
		local path, size, flags = region:GetFont()
		if face and path and size and string.lower(path) ~= string.lower(face)
			and string.lower(SurvivorUI_FONT or "") == string.lower(face) then
			region:SetFont(face, size, flags)
		end
	end
	region.suiSet(region, text)
end

local function Said(region, text)
	region.suiMake = nil
	if type(text) == "string" then
		region.suiEnglish = text
		text = SurvivorUI_OT(text)
	else
		region.suiEnglish = nil
	end
	Put(region, text)
end

-- A font string of the window's: whatever is set on it from now on in the
-- window's words, its English kept. Given back.
function SurvivorUI_Spoken(region)
	if region and not region.suiSet then
		region.suiSet = region.SetText
		region.suiEnglish = region:GetText()
		region.SetText = Said
	end
	return region
end

-- A text made of pieces (a name in a sentence), by Make: set now, and made
-- again as the language changes.
function SurvivorUI_SpokenBy(region, Make)
	SurvivorUI_Spoken(region)
	Put(region, Make())
	region.suiEnglish, region.suiMake = nil, Make
end

local function Speak(frame)
	local regions = { frame:GetRegions() }
	for index = 1, table.getn(regions) do
		local region = regions[index]
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			SurvivorUI_Spoken(region)
			if region.suiMake then
				Put(region, region.suiMake())
			elseif region.suiEnglish then
				region:SetText(region.suiEnglish)
			end
		end
	end
	local children = { frame:GetChildren() }
	for index = 1, table.getn(children) do
		Speak(children[index])
	end
end

-- The window's frames (those given) in the game's language, when the addon
-- has the window's words in it, else in English: every text in them set
-- again. True when the language changed.
function SurvivorUI_SpeakOptions(...)
	local now = Words() and language
	if now and not (SurvivorUI_OPTION_WORDS and SurvivorUI_OPTION_WORDS[now]) then
		now = nil
	end
	if now == spokenIn then
		return false
	end
	spokenIn, said, saidCount, capitals = now, {}, 0, nil
	for index = 1, table.getn(arg) do
		if arg[index] then
			Speak(arg[index])
		end
	end
	return true
end

-- The language the window speaks: nil for English.
function SurvivorUI_OptionsLanguage()
	return spokenIn
end
