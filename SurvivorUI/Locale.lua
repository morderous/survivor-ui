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
-- (AZS_ZONE.rname). Until it is known, every language is tried.
local language

local function Languages()
	if not language and AZS_ZONE and AZS_ZONE.rname then
		local race = AZS_ZONE.rname
		local matches, which = 0, nil
		for code, data in pairs(LOCALE) do
			for _, name in pairs(data.races or {}) do
				if name == race then
					matches, which = matches + 1, code
				end
			end
		end
		-- "Orc" is Orc in several: a name of one language only says which.
		if matches == 1 then
			language = which
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
