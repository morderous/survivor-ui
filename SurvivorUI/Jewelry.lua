-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the Jewelry Collection: the jewelry found on this game, and what is left.
--
-- Every neck, ring and trinket a character wears is written down, run after
-- run: its name, slot, quality, the ranks seen, and for each bonus the lowest
-- and highest value seen, overall and by rank. One book for the whole game
-- folder (SurvivorUIJewelryBook): the game is offline, so everyone who plays on
-- it, any class, any account, fills the same book. Rings, trinkets and the
-- common necks drop for every class; a legendary amulet names a spell of one
-- class, so it shows only to that class (known by its spell, or by who found it).
-- The game shares no card offers with addons: only the pieces worn count,
-- and every piece picked from a card is worn at once.
--
-- The book opens from its own button on the minimap, or /sui jewelry: a slim
-- list to read at a glance, even in a fight.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local SLOTS = { [2] = "Neck", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket" }
local SLOT_ORDER = { Neck = 1, Ring = 2, Trinket = 3 }

-- The quality a link's color names, for sorting: grey up to orange.
local QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

-- The books, by class ("PALADIN"), and where the list was left.
local function Books()
	SurvivorUIJewelryBook = SurvivorUIJewelryBook or {}
	SurvivorUIJewelryBook.classes = SurvivorUIJewelryBook.classes or {}
	return SurvivorUIJewelryBook
end

local function ClassName()
	local name, class = UnitClass("player")
	return class or "UNKNOWN", name or "?"
end

-- Every class's spells, as the game offers them: a legendary amulet names one,
-- and so its class. Matched without case, spaces or marks ("Multi-Shot").
local CLASS_SPELLS = {
	WARRIOR = { "Cleave", "Whirlwind", "Thunder Clap", "Mortal Strike", "Execute", "Demoralizing Shout", "Battle Shout", "Bloodthirst", "Rend", "Shield Slam", "Bloodrage" },
	PALADIN = { "Consecration", "Exorcism", "Hammer Of Wrath", "Holy Shock", "Holy Wrath", "Judgement", "Hammer Of Justice", "Holy Light", "Divine Shield", "Holy Shield", "Redemption" },
	HUNTER = { "Auto Shot", "Arcane Shot", "Multi Shot", "Serpent Sting", "Volley", "Explosive Trap", "Concussive Shot", "Aimed Shot", "Immolation Trap", "Frost Trap", "Hunter's Mark" },
	ROGUE = { "Sinister Strike", "Eviscerate", "Blade Flurry", "Rupture", "Kidney Shot", "Gouge", "Ghostly Strike", "Adrenaline Rush", "Backstab", "Slice And Dice", "Seal Fate" },
	PRIEST = { "Smite", "Shadow Word: Pain", "Mind Blast", "Holy Nova", "Power Word: Shield", "Renew", "Holy Fire", "Mind Flay", "Psychic Scream", "Devouring Plague", "Lightwell" },
	SHAMAN = { "Lightning Bolt", "Chain Lightning", "Earth Shock", "Flame Shock", "Frost Shock", "Lightning Shield", "Magma Totem", "Searing Totem", "Fire Nova", "Healing Wave", "Call Of Flame" },
	MAGE = { "Fireball", "Frostbolt", "Arcane Missiles", "Frost Nova", "Arcane Explosion", "Blizzard", "Flamestrike", "Fire Blast", "Cone Of Cold", "Blast Wave", "Pyroblast", "Ice Barrier", "Polymorph" },
	WARLOCK = { "Shadow Bolt", "Corruption", "Immolate", "Curse Of Agony", "Rain Of Fire", "Hellfire", "Death Coil", "Searing Pain", "Drain Life", "Fear", "Soul Fire" },
	DRUID = { "Wrath", "Moonfire", "Starfire", "Hurricane", "Insect Swarm", "Entangling Roots", "Rejuvenation", "Regrowth", "Thorns", "Swipe", "Faerie Fire", "Shred" },
}

-- The common pieces there are to find, for every class (the game's codex):
-- the legendary amulets are one per spell of a class, above.
local COMMON_TOTALS = { Neck = 17, Ring = 9, Trinket = 13 }

local function Plain(text)
	return string.gsub(string.lower(text or ""), "[^%a]", "")
end

local spellClass = {}
for class, spells in pairs(CLASS_SPELLS) do
	for index = 1, table.getn(spells) do
		spellClass[Plain(spells[index])] = class
	end
end

-- The class a spell belongs to, or nil for one not in the list.
local function SpellClass(spell)
	return spell and spellClass[Plain(spell)]
end

-- A piece written in an earlier book (by character, or by class in v2.8)
-- joins the one book.
local function MergeItem(book, base, old)
	local item = book.items[base]
	if not item then
		book.items[base] = old
		return
	end
	item.found = (item.found or 0) + (old.found or 0)
	if (old.quality or 0) > (item.quality or 0) then
		item.quality, item.color = old.quality, old.color
	end
	for rank in pairs(old.ranks or {}) do
		item.ranks[rank] = true
	end
	-- Its bonuses join as they are: the same one is kept once as the book is
	-- read (Canon).
	for each = 1, table.getn(old.stats or {}) do
		table.insert(item.stats, old.stats[each])
	end
end

local function EnglishLine(text)
	return SurvivorUI_EnglishLine and SurvivorUI_EnglishLine(text) or text
end

-- A bonus line's pattern, every number a # ("Equip: Lightning Bolt's hits
-- leap to # more enemies for #%."), and its numbers in order.
local function Bonus(text)
	local values = {}
	local pattern = string.gsub(text or "", "%d+%.?%d*", function(number)
		table.insert(values, tonumber(number))
		return "#"
	end)
	if table.getn(values) == 0 then
		return nil
	end
	local _, _, percent = string.find(text, "%d+%.?%d*(%%?)")
	return pattern, values, percent
end

-- A pattern's words, to tell bonuses apart: "1 more target" and "2 more
-- targets" are the same one.
local function Key(pattern)
	local key = string.lower(pattern or "").." "
	key = string.gsub(key, "(%a)ies([^%a])", "%1y%2")
	key = string.gsub(key, "(%a)s([^%a])", "%1%2")
	return key
end

-- A sighting's numbers on a bonus (or on one of its ranks): the lowest and
-- highest of each; the first's also as min and max.
local function Note(into, values)
	into.values = into.values or {}
	for index = 1, table.getn(values) do
		local value = values[index]
		local seen = into.values[index] or {}
		seen.min = math.min(seen.min or value, value)
		seen.max = math.max(seen.max or value, value)
		into.values[index] = seen
	end
	into.min = math.min(into.min or values[1], values[1])
	into.max = math.max(into.max or values[1], values[1])
end

local function Digits(value)
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return tostring(value)
end

-- A bonus's line again, its numbers put back: each one's lowest, or highest.
-- One kept before v3.0 has only its first number as a #, in min and max.
local function Line(stat, high)
	local index = 0
	return (string.gsub(stat.pattern, "#", function()
		index = index + 1
		local seen = stat.values and stat.values[index]
		local value
		if seen then
			value = high and seen.max or seen.min
		elseif index == 1 then
			value = high and stat.max or stat.min
		end
		return Digits(value or 0)
	end))
end

-- A legendary amulet's own lines all start "Equip:"; the short ones the codex
-- gave it (seed_class_amulets.py) give way once those are known.
local function Settle(item)
	local own = false
	for each = 1, table.getn(item.stats) do
		local stat = item.stats[each]
		if not stat.seed and string.find(stat.pattern, "^Equip:") then
			own = true
		end
	end
	if not own then
		return
	end
	local kept = {}
	for each = 1, table.getn(item.stats) do
		local stat = item.stats[each]
		if not (stat.seed or (item.spell and not string.find(stat.pattern, "^Equip:"))) then
			table.insert(kept, stat)
		end
	end
	item.stats = kept
end

-- A piece's bonuses in English, every number a #, the same bonus once. Those
-- kept another way (in another language's words, or before v3.0 with only
-- their first number a #) are read again from their lowest and highest.
local function Canon(item)
	local stats, byKey = {}, {}
	local function Into(text, seed)
		local pattern, values, unit = Bonus(text)
		if not pattern then
			return nil
		end
		local key = Key(pattern)
		local stat = byKey[key]
		if not stat then
			stat = { pattern = pattern, unit = unit, ranks = {}, seed = seed,
				tag = SurvivorUI_StatOf and SurvivorUI_StatOf(text) or nil }
			byKey[key] = stat
			table.insert(stats, stat)
		else
			stat.seed = stat.seed and seed
			-- "2 more targets" over "1 more target".
			if string.len(pattern) > string.len(stat.pattern) then
				stat.pattern = pattern
			end
		end
		return stat, values
	end
	for each = 1, table.getn(item.stats or {}) do
		local old = item.stats[each]
		if old.pattern and not string.find(old.pattern, "#") then
			-- A line with no number (the codex's "Chains lose nothing").
			local key = Key(old.pattern)
			if not byKey[key] then
				byKey[key] = old
				table.insert(stats, old)
			end
		elseif old.pattern then
			-- Read in English once; a line already English needs no more.
			local low = Line(old, false)
			local english = EnglishLine(low)
			local foreign = english ~= low
			local high = Line(old, true)
			for _, text in pairs({ english, foreign and EnglishLine(high) or high }) do
				local stat, values = Into(text, old.seed)
				if stat then
					Note(stat, values)
				end
			end
			for rank, seen in pairs(old.ranks or {}) do
				local own = { pattern = old.pattern, values = seen.values, min = seen.min, max = seen.max }
				for _, top in pairs({ false, true }) do
					local text = Line(own, top)
					local stat, values = Into(foreign and EnglishLine(text) or text, old.seed)
					if stat then
						stat.ranks[rank] = stat.ranks[rank] or {}
						Note(stat.ranks[rank], values)
					end
				end
			end
		end
	end
	item.stats = stats
	Settle(item)
end

-- Pieces kept under another language's name (before v2.11 kept them all in
-- English, or with the game switched to another language) join their English
-- one. A class's amulet keeps the name the game gives it, so two for one
-- class and spell are one piece: they join, under the name seen last.
local function Unify(book)
	local items = book.items
	local renames = {}
	for base, item in pairs(items) do
		if item.spell and SurvivorUI_English then
			item.spell = SurvivorUI_English(item.spell)
		end
		local english = SurvivorUI_English and SurvivorUI_English(base) or base
		if english ~= base then
			table.insert(renames, { base, english })
		end
	end
	for _, pair in pairs(renames) do
		local old = items[pair[1]]
		items[pair[1]] = nil
		MergeItem(book, pair[2], old)
	end
	local bySpell, joins = {}, {}
	for base, item in pairs(items) do
		if item.spell then
			local key = (item.class or "")..":"..Plain(item.spell)
			local other = bySpell[key]
			if other then
				local keep, gone = other, base
				if (item.last or 0) > (items[other].last or 0) then
					keep, gone = base, other
				end
				table.insert(joins, { gone, keep })
				bySpell[key] = keep
			else
				bySpell[key] = base
			end
		end
	end
	for _, pair in pairs(joins) do
		local old = items[pair[1]]
		if old and items[pair[2]] then
			items[pair[1]] = nil
			MergeItem(book, pair[2], old)
		end
	end
	for _, item in pairs(items) do
		Canon(item)
	end
end

local unified = false

-- This character's class book.
-- The one book. The books kept by class (v2.8) and by character (before it)
-- join it once, their legendary amulets marked with their class.
local function Book()
	local books = Books()
	if not books.shared then
		books.shared = { items = {} }
		for class, book in pairs(books.classes) do
			for base, old in pairs(book.items or {}) do
				if old.spell then
					old.class = old.class or class
				end
				MergeItem(books.shared, base, old)
			end
		end
		books.classes = {}
	end
	if SurvivorUIJewelry and SurvivorUIJewelry.items then
		local class = ClassName()
		for base, old in pairs(SurvivorUIJewelry.items) do
			if old.spell then
				old.class = old.class or class
			end
			MergeItem(books.shared, base, old)
		end
		SurvivorUIJewelry.items = nil
	end
	-- Once a session, once the words to read them by are loaded.
	if not unified and SurvivorUI_English then
		unified = true
		Unify(books.shared)
	end
	return books.shared
end

-- /sui collection reset, or the options' Jewelry tab: everything found is
-- forgotten, for every class and account on this game; asked first in the
-- addon's one box (Confirm.lua), the word forget typed, the pieces counted.
local function Forget()
	Books().shared = { items = {} }
	if SurvivorUIJewelryPanel and SurvivorUIJewelryPanel:IsShown() then
		SurvivorUIJewelryPanel.Draw()
	end
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the Jewelry Collection is empty again. Pieces you wear now come back on their own.")
end

function SurvivorUI_ResetCollection()
	local count = 0
	for _ in pairs(Book().items or {}) do
		count = count + 1
	end
	if count == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the Jewelry Collection holds no piece yet.")
		return
	end
	if not SurvivorUI_Confirm then
		Forget()
		return
	end
	SurvivorUI_Confirm({
		title = "Forget the collection?",
		text = "Every piece found goes: "..count..(count == 1 and " piece" or " pieces")
			..", for every class and account on this game. Pieces you wear come back on their own."
			.."\n|cff9a9aa0Type|r forget |cff9a9aa0to forget them.|r",
		word = "forget",
		yes = "Forget all",
		onYes = Forget,
	})
end

-- A piece this class can find: every one but another class's legendary
-- amulet. Its class comes from its spell; a spell not in the list goes by the
-- class it was found by.
local function ForThisClass(item)
	if not item.spell then
		return true
	end
	local class = SpellClass(item.spell) or item.class
	return not class or class == ClassName()
end

------------------------------------------------------------------------------
-- Reading what is worn.

local scan = CreateFrame("GameTooltip", "SurvivorUIJewelryScan", nil, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

local worn = {}                 -- [slot] = link, as last read
local firstLook = true          -- the pieces worn at login were found before

-- A bonus line, as a pattern with its number taken out, the number and its
-- unit: "Increases your luck by #%", 70, "%".
-- A name or bonus line in English, whatever language the game is in (Locale.lua).
local function English(name)
	return SurvivorUI_English and SurvivorUI_English(name) or name
end


local function Record(slot, link)
	local _, _, color, name = string.find(link, "|cff(%x%x%x%x%x%x).-%[(.-)%]")
	if not name then
		return
	end
	color = string.lower(color or "ffffff")
	local base, rank = name, nil
	local _, _, found = string.find(name, " ([IVXL]+%+?)$")
	if found then
		rank = found
		base = string.sub(name, 1, string.len(name) - string.len(found) - 1)
	end
	rank = rank or "I"
	-- Kept by its English name, as the codex has it: one collection whatever
	-- language the game is in.
	base = English(base)

	local book = Book()
	local item = book.items[base]
	if not item then
		item = { slot = SLOTS[slot], found = 0, ranks = {}, stats = {}, first = time() }
		book.items[base] = item
	end
	item.slot = SLOTS[slot]
	item.last = time()
	item.texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or item.texture
	-- The best quality seen names its color.
	local quality = QUALITY[color] or 1
	if not item.quality or quality > item.quality then
		item.quality, item.color = quality, color
	end
	item.ranks[rank] = true
	local _, _, spell = string.find(base, ": (.+)$")
	if spell and quality == 5 and SLOTS[slot] == "Neck" then
		item.spell = spell
		-- It shows to its spell's class only (the finder's, for a spell the
		-- list does not know).
		item.class = SpellClass(spell) or ClassName()
	end

	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	-- At login the game may not have the piece's text yet: nothing to read,
	-- and it is read again on the next look.
	local read = false
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIJewelryScanTextLeft"..index)
		if line and line:GetText() and string.find(line:GetText(), "%d") then
			read = true
		end
	end
	if not read then
		return base, false
	end
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIJewelryScanTextLeft"..index)
		local text = EnglishLine(line and line:GetText())
		local pattern, values, unit = Bonus(text or "")
		if pattern then
			local key = Key(pattern)
			local stat
			for each = 1, table.getn(item.stats) do
				if Key(item.stats[each].pattern) == key then
					stat = item.stats[each]
				end
			end
			if not stat then
				stat = { pattern = pattern, unit = unit, ranks = {},
					tag = SurvivorUI_StatOf and SurvivorUI_StatOf(text) or nil }
				table.insert(item.stats, stat)
			elseif string.len(pattern) > string.len(stat.pattern) then
				stat.pattern = pattern
			end
			stat.seed = nil
			Note(stat, values)
			stat.ranks[rank] = stat.ranks[rank] or {}
			Note(stat.ranks[rank], values)
		end
	end
	Settle(item)
	return base, true
end

local bases = {}                -- [slot] = the base name worn there

local function Look()
	for slot in pairs(SLOTS) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link ~= worn[slot] then
			worn[slot] = link
			if link then
				local base, read = Record(slot, link)
				if not read then
					-- Not read yet: looked at again in two seconds.
					worn[slot] = nil
				end
				-- A piece new to its slot (not an upgrade of the one there) is
				-- one more found; not those already worn at login.
				local item = base and Book().items[base]
				if item and base ~= bases[slot] and (not firstLook or item.found == 0) then
					item.found = item.found + 1
				end
				bases[slot] = base
			else
				bases[slot] = nil
			end
		end
	end
	firstLook = false
	if SurvivorUIJewelryPanel and SurvivorUIJewelryPanel:IsShown() then
		SurvivorUIJewelryPanel.Draw()
	end
end

-- The collection on unless switched off as a whole (the Modules tab): off,
-- nothing is looked at, kept or shown.
local function Enabled()
	return not (SurvivorUIDB and SurvivorUIDB.jewelry == false)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
watcher:SetScript("OnEvent", function()
	if (event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player") or not Enabled() then
		return
	end
	Look()
end)
-- An upgrade from a card can change a piece without an inventory event: a
-- look every two seconds too.
local elapsed = 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 2 and Enabled() then
		elapsed = 0
		Look()
	end
end)

------------------------------------------------------------------------------
-- The collection: a compact window, to read at a glance in a fight. Two
-- columns: this class's legendary amulets and the amulets on the left, the
-- rings and trinkets on the right; each group with how many are found, and a
-- bar of it. A piece found is a thin bar in its quality's color with its name
-- in short; one still to find is faint, by name where the codex gives it.
-- Hover any for what it gives. Drag it anywhere; it stays where it is left.

local COLUMN = 150
local ROW = 13
local SLOT_COLORS = { Neck = { 1, 0.6, 0.2 }, Ring = { 0.4, 0.68, 1 }, Trinket = { 0.78, 0.52, 1 } }
local LEGENDARY_COLOR = { 1, 0.5, 0 }
local MUTED = { 0.6, 0.6, 0.65 }
local RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS = { { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- Opened with the character pane and set beside it (see Dock below).
local docked = false

local panel = CreateFrame("Frame", "SurvivorUIJewelryPanel", UIParent)
panel:SetWidth(8 + COLUMN + 8 + COLUMN + 8)
panel:SetHeight(60)
panel:SetFrameStrata("MEDIUM")
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 280, -120)
panel:SetBackdrop({ bgFile = FLAT })
panel:SetBackdropColor(0.04, 0.04, 0.07, 0.88)
panel:EnableMouse(true)
panel:SetMovable(true)
if panel.SetClampedToScreen then
	panel:SetClampedToScreen(true)
end
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	docked = false
	local books = Books()
	books.left = math.floor(this:GetLeft() + 0.5)
	books.top = math.floor(this:GetTop() + 0.5)
end)
panel:Hide()

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	return text
end

-- A thin white outline just outside a frame, hidden until asked for.
local function Outline(frame, r, g, b)
	local edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = frame:CreateTexture(nil, "OVERLAY")
		edge:SetTexture(FLAT)
		edge:SetVertexColor(r or 1, g or 1, b or 1, 0.9)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetHeight(1)
			edge:SetPoint(side.."LEFT", frame, side.."LEFT", -1, side == "TOP" and 1 or -1)
			edge:SetPoint(side.."RIGHT", frame, side.."RIGHT", 1, side == "TOP" and 1 or -1)
		else
			edge:SetWidth(1)
			edge:SetPoint("TOP"..side, frame, "TOP"..side, side == "LEFT" and -1 or 1, 1)
			edge:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side, side == "LEFT" and -1 or 1, -1)
		end
		edge:Hide()
		table.insert(edges, edge)
	end
	return function(shown)
		for index = 1, table.getn(edges) do
			if shown then
				edges[index]:Show()
			else
				edges[index]:Hide()
			end
		end
	end
end

local function Fill(parent, layer, r, g, b, a)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(FLAT)
	texture:SetVertexColor(r, g, b, a)
	return texture
end

local title = Text(panel, 10, { 1, 0.82, 0 })
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)

-- The window's outline, while the mouse is anywhere on it.
panel.noHoverOutline = true
local panelOutline = Outline(panel)
local overPanel = false
panel:SetScript("OnUpdate", function()
	local over = MouseIsOver(this) and true or false
	if over ~= overPanel then
		overPanel = over
		panelOutline(over)
	end
end)

local close = CreateFrame("Button", nil, panel)
close.noHoverOutline = true
close:SetWidth(14)
close:SetHeight(14)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
close.text = Text(close, 9, MUTED)
close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
close.text:SetText("x")
close:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.35, 0.3) end)
close:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
close:SetScript("OnClick", function() panel:Hide() end)

-- "29%" or "29-86%".
local function Range(low, high, unit)
	local function Number(value)
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.1f", value)
	end
	if low == high then
		return Number(low)..unit
	end
	return Number(low).."-"..Number(high)..unit
end

-- A name in short, for the slim rows: the small words out, then the middle
-- words by their initials, then cut ("Pristine Enchanted South Seas Kelp"
-- Pristine ESS Kelp).
local SMALL = { of = true, the = true, a = true, an = true }
local MAX_NAME = 22

-- The long names, short by hand: the part that tells them apart.
local SHORT_NAMES = {
	["Pristine Enchanted South Seas Kelp"] = "South Seas Kelp",
	["Archimtiros' Ring of Reckoning"] = "Ring of Reckoning",
	["Talisman of Ephemeral Power"] = "Ephemeral Power",
	["Master Dragonslayer's Ring"] = "Dragonslayer's Ring",
	["Pendant of the Fallen Dragon"] = "Fallen Dragon",
	["Royal Seal of Eldre'Thalas"] = "Seal of Eldre'Thalas",
	["Gnomish Universal Remote"] = "Gnomish Remote",
	["Medallion of Steadfast Might"] = "Steadfast Might",
	["Talvash's Enhancing Necklace"] = "Talvash's Necklace",
	["Jeklik's Opaline Talisman"] = "Jeklik's Talisman",
	["Choker of Enlightenment"] = "Enlightenment",
	["Amulet of the Darkmoon"] = "Darkmoon Amulet",
	["Animated Chain Necklace"] = "Animated Chain",
	["Pendant of the Plague"] = "Plague Pendant",
	["Prestor's Talisman of Connivery"] = "Prestor's Talisman",
}

local function Abbrev(name)
	if SHORT_NAMES[name] then
		return SHORT_NAMES[name]
	end
	if string.len(name) <= MAX_NAME then
		return name
	end
	local words = {}
	for word in string.gfind(name, "%S+") do
		if table.getn(words) == 0 or not SMALL[string.lower(word)] then
			table.insert(words, word)
		end
	end
	local text = table.concat(words, " ")
	if string.len(text) > MAX_NAME and table.getn(words) > 2 then
		local middle = ""
		for index = 2, table.getn(words) - 1 do
			middle = middle..string.upper(string.sub(words[index], 1, 1))
		end
		text = words[1].." "..middle.." "..words[table.getn(words)]
	end
	if string.len(text) > MAX_NAME then
		text = string.sub(text, 1, MAX_NAME - 1).."."
	end
	return text
end

-- The rows, made as they are needed.
local rows = {}

local function ShowTip(row)
	local entry = row.entry
	if not entry then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local item = entry.item
	local color = row.color or { 1, 1, 1 }
	GameTooltip:SetText(entry.name, color[1], color[2], color[3])
	if entry.spell then
		GameTooltip:AddLine("Legendary amulet  ·  remakes "..entry.spell, 1, 0.5, 0)
	elseif entry.slot then
		GameTooltip:AddLine(entry.slot == "Neck" and "Amulet" or entry.slot, 0.7, 0.7, 0.7)
	end
	if item then
		GameTooltip:AddLine("Found "..item.found.." time"..(item.found == 1 and "" or "s")..", the values seen:", 0.7, 0.7, 0.7)
		for each = 1, table.getn(item.stats) do
			local stat = item.stats[each]
			-- Each number as the lowest and highest seen.
			local index = 0
			local text = string.gsub(stat.pattern, "#", function()
				index = index + 1
				local seen = stat.values and stat.values[index]
				if seen then
					return Range(seen.min, seen.max, "")
				end
				return Range(stat.min or 0, stat.max or 0, "")
			end)
			GameTooltip:AddLine("  "..text, 0.3, 1, 0.4, 1)
		end
	else
		GameTooltip:AddLine("Not found yet", 0.55, 0.55, 0.6)
	end
	-- What the codex says it gives: by rarity for a ring or trinket, or the
	-- amulet's own.
	local codex = entry.codex
	if codex and codex.byRarity then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("A new one, by rarity", 1, 0.82, 0)
		for index = 1, 5 do
			local value = codex.byRarity[index]
			if value then
				local c = RARITY_COLORS[index]
				GameTooltip:AddDoubleLine(RARITY_NAMES[index], value, c[1], c[2], c[3], 0.9, 0.9, 0.9)
			end
		end
	elseif codex and codex.bonuses then
		GameTooltip:AddLine(" ")
		local c = RARITY_COLORS[RARITY_INDEX[codex.rarity] or 1]
		GameTooltip:AddLine(codex.rarity.." amulet", c[1], c[2], c[3])
		for each = 1, table.getn(codex.bonuses) do
			GameTooltip:AddLine("  "..codex.bonuses[each], 0.9, 0.9, 0.9, 1)
		end
	end
	GameTooltip:Show()
end

local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, panel)
	row:SetWidth(COLUMN)
	row:SetHeight(ROW - 1)
	row.noHoverOutline = true
	row.outline = Outline(row)
	-- A green "E" at the row's end on the pieces worn now.
	row.badge = CreateFrame("Frame", nil, row)
	row.badge:SetWidth(ROW - 3)
	row.badge:SetHeight(ROW - 3)
	row.badge:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	row.badge.edge = Fill(row.badge, "BACKGROUND", 0, 0, 0, 1)
	row.badge.edge:SetPoint("TOPLEFT", row.badge, "TOPLEFT", -1, 1)
	row.badge.edge:SetPoint("BOTTOMRIGHT", row.badge, "BOTTOMRIGHT", 1, -1)
	row.badge.fill = Fill(row.badge, "BORDER", 0.2, 0.72, 0.28, 1)
	row.badge.fill:SetAllPoints(row.badge)
	row.badge.text = Text(row.badge, 7, { 1, 1, 1 })
	row.badge.text:SetPoint("CENTER", row.badge, "CENTER", 1, 0)
	row.badge.text:SetText("E")
	row.badge:Hide()
	row.worn = function(on)
		if on then
			row.badge:Show()
		else
			row.badge:Hide()
		end
	end
	row.wash = Fill(row, "BACKGROUND", 1, 1, 1, 0)
	row.wash:SetAllPoints(row)
	row.edge = Fill(row, "BORDER", 1, 1, 1, 0)
	row.edge:SetWidth(2)
	row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	-- A title's bar, behind its words: the share found, in the group's color,
	-- over the same color faint.
	row.track = Fill(row, "BACKGROUND", 1, 1, 1, 0.08)
	row.track:SetAllPoints(row)
	row.bar = Fill(row, "BORDER", 1, 1, 1, 1)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	-- After the title's name: what is worn of the group ("- 1/2").
	row.extra = Text(row, 9, { 1, 1, 1 })
	row.extra:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW - 3)
	row.icon:SetHeight(ROW - 3)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.name = Text(row, 9, { 1, 1, 1 })
	row.name:SetJustifyH("LEFT")
	row.count = Text(row, 9, MUTED)
	row.count:SetPoint("RIGHT", row, "RIGHT", -2, 1)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function() panel:GetScript("OnDragStart")() end)
	row:SetScript("OnDragStop", function() panel:GetScript("OnDragStop")() end)
	row:SetScript("OnEnter", function()
		if this.entry then
			this.outline(true)
			ShowTip(this)
		end
	end)
	row:SetScript("OnLeave", function()
		this.outline(false)
		GameTooltip:Hide()
	end)
	rows[index] = row
	return row
end

-- The class's own icon, for its title: the character creation's class icons.
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

-- The class's icon for other windows (the last runs): the texture and the
-- class's part of it.
function SurvivorUI_ClassIcon(class)
	return CLASS_ICONS, class and CLASS_ICON_COORDS[class]
end

-- A group's title: its name, the count found, a bar of it under the line.
local function Header(row, label, color, found, total, worn, slots, class)
	row.entry, row.color = nil, nil
	row.outline(false)
	row.worn(false)
	row.wash:SetVertexColor(0, 0, 0, 0)
	row.edge:SetVertexColor(0, 0, 0, 0)
	row.icon:Hide()
	local coords = class and CLASS_ICON_COORDS[class]
	-- "Shaman Amulets - 0/1", white on the group's bar; found, right. The
	-- class's own with its icon first.
	row.name:ClearAllPoints()
	if coords then
		row.icon:SetTexture(CLASS_ICONS)
		row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		row.icon:SetVertexColor(1, 1, 1)
		row.icon:Show()
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	else
		row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
	end
	row.name:SetText(label)
	row.name:SetTextColor(1, 1, 1)
	row.extra:ClearAllPoints()
	row.extra:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
	row.extra:SetText("- "..(worn or 0).."/"..(slots or 0))
	row.extra:Show()
	row.count:SetText(found.." / "..total)
	row.count:SetTextColor(1, 1, 1)
	row.count:Show()
	row.track:Show()
	row.track:SetVertexColor(color[1], color[2], color[3], 0.18)
	row.bar:Show()
	row.bar:SetVertexColor(color[1], color[2], color[3], 0.75)
	row.bar:SetWidth(math.max(1, COLUMN * (total > 0 and math.min(1, found / total) or 0)))
end

-- A piece: found (in its quality's color) or still to find (faint).
local function Piece(row, entry)
	row.entry = entry
	row.badge:ClearAllPoints()
	row.badge:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.worn(entry.worn and true or false)
	row.extra:Hide()
	row.count:Hide()
	row.track:Hide()
	row.bar:Hide()
	row.icon:Show()
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetText(Abbrev(entry.short or entry.name))
	local item = entry.item
	if item then
		local hex = item.color or "ffffff"
		local r = tonumber(string.sub(hex, 1, 2), 16) / 255
		local g = tonumber(string.sub(hex, 3, 4), 16) / 255
		local b = tonumber(string.sub(hex, 5, 6), 16) / 255
		row.color = { r, g, b }
		row.wash:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, 0.5)
		row.edge:SetVertexColor(r, g, b, 1)
		-- A piece with no icon of its own (one written in, never worn here): a
		-- class amulet shows its spell's.
		local icon = item.texture or (entry.spell and SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(entry.spell))
		row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.icon:SetVertexColor(1, 1, 1)
		row.name:SetTextColor(1, 1, 1)
	elseif entry.classColor then
		-- A class amulet still to find: its spell's icon, faint, on the class's color.
		local c = entry.classColor
		row.color = { c[1], c[2], c[3] }
		row.wash:SetVertexColor(c[1], c[2], c[3], 0.10)
		row.edge:SetVertexColor(c[1], c[2], c[3], 0.8)
		local icon = SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(entry.spell)
		row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.icon:SetVertexColor(0.55, 0.55, 0.55)
		row.name:SetTextColor(0.35 + c[1] * 0.4, 0.35 + c[2] * 0.4, 0.35 + c[3] * 0.4)
	else
		row.color = { 0.7, 0.7, 0.75 }
		row.wash:SetVertexColor(0.5, 0.5, 0.55, 0.06)
		row.edge:SetVertexColor(0.4, 0.4, 0.45, 0.5)
		row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		row.icon:SetVertexColor(0.4, 0.4, 0.4)
		row.name:SetTextColor(0.5, 0.5, 0.55)
	end
end

-- "6 more to find": the pieces the codex here does not name.
local function More(row, count)
	row.entry, row.color = nil, nil
	row.outline(false)
	row.worn(false)
	row.extra:Hide()
	row.count:Hide()
	row.track:Hide()
	row.bar:Hide()
	row.icon:Hide()
	row.wash:SetVertexColor(0, 0, 0, 0)
	row.edge:SetVertexColor(0, 0, 0, 0)
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.name:SetText(count.." more to find")
	row.name:SetTextColor(0.45, 0.45, 0.5)
end

local GROUP_LABELS = { Neck = "Amulets", Ring = "Rings", Trinket = "Trinkets" }


-- A slot's group: the pieces found, those the codex names still to find, and
-- how many more it does not name.
local function Group(list, slot, foundItems, wornNow, slots)
	local codex = SurvivorUI_JEWELRY and SurvivorUI_JEWELRY[slot] or {}
	local known, entries, taken = {}, {}, {}
	for index = 1, table.getn(codex) do
		local spec = codex[index]
		local data = slot == "Neck" and { rarity = spec[2], bonuses = spec[3] } or { byRarity = spec[2] }
		known[Plain(spec[1])] = { name = spec[1], data = data }
	end
	-- The found ones: what is worn now first, to see at a glance, then the
	-- best quality.
	table.sort(foundItems, function(a, b)
		local aWorn, bWorn = wornNow[a.base] and 1 or 0, wornNow[b.base] and 1 or 0
		if aWorn ~= bWorn then
			return aWorn > bWorn
		end
		if (a.item.quality or 0) ~= (b.item.quality or 0) then
			return (a.item.quality or 0) > (b.item.quality or 0)
		end
		return a.base < b.base
	end)
	for index = 1, table.getn(foundItems) do
		local found = foundItems[index]
		local match = known[Plain(found.base)]
		if match then
			taken[Plain(found.base)] = true
		end
		table.insert(entries, { name = found.base, slot = slot, item = found.item, codex = match and match.data,
			worn = wornNow[found.base] })
	end
	local missing = 0
	for index = 1, table.getn(codex) do
		local key = Plain(codex[index][1])
		if not taken[key] then
			table.insert(entries, { name = codex[index][1], slot = slot, codex = known[key].data })
			missing = missing + 1
		end
	end
	local total = COMMON_TOTALS[slot]
	local found = table.getn(foundItems)
	local unnamed = total - found - missing
	local wornCount = 0
	for index = 1, table.getn(foundItems) do
		if wornNow[foundItems[index].base] then
			wornCount = wornCount + 1
		end
	end
	table.insert(list, { header = GROUP_LABELS[slot], color = SLOT_COLORS[slot], found = found, total = total,
		worn = wornCount, slots = slots })
	for index = 1, table.getn(entries) do
		table.insert(list, entries[index])
	end
	if unnamed > 0 then
		table.insert(list, { more = unnamed })
	end
end

function panel.Draw()
	local book = Book()
	local class, className = ClassName()
	local bySlot, legendary = { Neck = {}, Ring = {}, Trinket = {} }, {}
	local foundSpells = {}
	for base, item in pairs(book.items) do
		if item.spell then
			if ForThisClass(item) then
				table.insert(legendary, { base = base, item = item })
				foundSpells[Plain(item.spell)] = true
			end
		elseif bySlot[item.slot] then
			table.insert(bySlot[item.slot], { base = base, item = item })
		end
	end

	-- What is worn now, by its base name.
	local wornNow = {}
	for slot, base in pairs(bases) do
		if base then
			wornNow[base] = true
		end
	end

	-- Left: this class's legendary amulets, then the amulets. Right: the
	-- rings and the trinkets.
	local left, right = {}, {}
	local spells = CLASS_SPELLS[class] or {}
	local total, found = 0, 0
	if table.getn(spells) > 0 then
		local wornLegendary = 0
		for index = 1, table.getn(legendary) do
			if wornNow[legendary[index].base] then
				wornLegendary = 1
			end
		end
		-- The one worn now first, then by spell.
		table.sort(legendary, function(a, b)
			local aWorn, bWorn = wornNow[a.base] and 1 or 0, wornNow[b.base] and 1 or 0
			if aWorn ~= bWorn then
				return aWorn > bWorn
			end
			return (a.item.spell or a.base) < (b.item.spell or b.base)
		end)
		-- The neck is one slot, shared by a class amulet and the others.
		local cr, cg, cb = 1, 0.5, 0
		if SurvivorUI_ClassColor then
			cr, cg, cb = SurvivorUI_ClassColor(class)
		end
		local classColor = { cr, cg, cb }
		-- By the class's name alone: "Shaman Amulets" leaves no room for the counts.
		table.insert(left, { header = className, color = classColor, found = table.getn(legendary), total = table.getn(spells),
			worn = wornLegendary, slots = 1, class = class })
		for index = 1, table.getn(legendary) do
			local entry = legendary[index]
			table.insert(left, { name = entry.base, short = entry.item.spell, spell = entry.item.spell, item = entry.item,
				worn = wornNow[entry.base] })
		end
		for index = 1, table.getn(spells) do
			if not foundSpells[Plain(spells[index])] then
				table.insert(left, { name = spells[index], spell = spells[index], classColor = classColor })
			end
		end
		total, found = total + table.getn(spells), found + table.getn(legendary)
	end
	Group(left, "Neck", bySlot.Neck, wornNow, 1)
	Group(right, "Ring", bySlot.Ring, wornNow, 2)
	Group(right, "Trinket", bySlot.Trinket, wornNow, 2)
	for _, slot in pairs({ "Neck", "Ring", "Trinket" }) do
		total = total + COMMON_TOTALS[slot]
		found = found + table.getn(bySlot[slot])
	end

	local used = 0
	local function Lay(list, x)
		for index = 1, table.getn(list) do
			used = used + 1
			local row, entry = Row(used), list[index]
			row:ClearAllPoints()
			-- A group after the first starts a little lower.
			local gap = 0
			for each = 2, index do
				if list[each].header then
					gap = gap + 4
				end
			end
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -22 - (index - 1) * ROW - gap)
			if entry.header then
				Header(row, entry.header, entry.color, entry.found, entry.total, entry.worn, entry.slots, entry.class)
			elseif entry.more then
				More(row, entry.more)
			else
				Piece(row, entry)
			end
			row:Show()
		end
	end
	Lay(left, 8)
	Lay(right, 8 + COLUMN + 8)
	for index = used + 1, table.getn(rows) do
		rows[index]:Hide()
	end

	title:SetText("Jewelry Collection  |cffe0e0e0"..found.."|r|cff8a8a90 / "..total.."  ·  "..className.."|r")
	local tallest = math.max(table.getn(left), table.getn(right))
	panel:SetHeight(22 + tallest * ROW + 12 + 6)
end

------------------------------------------------------------------------------
-- With the character pane (its own button, or the options, Jewelry): the
-- collection opens and closes with it, set right beside it. From the minimap
-- button, on its own, where it was left.

local function WithPane()
	return SurvivorUIDB and SurvivorUIDB.jewelryWithPane
end

local function Dock()
	local pane = getglobal("SurvivorUICharacter")
	if not pane then
		return
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", pane, "TOPRIGHT", 8, 0)
	-- In front with the character window.
	panel:SetFrameStrata("HIGH")
end

panel:SetScript("OnShow", function()
	if not docked then
		panel:SetFrameStrata("MEDIUM")
		local books = Books()
		if books.left and books.top then
			this:ClearAllPoints()
			this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", books.left, books.top)
		end
	end
	Look()
	panel.Draw()
end)

-- The options' Back to its place (Jewelry tab): where it first opens, away from
-- the character pane; beside the pane it still docks there.
function SurvivorUI_ResetJewelryPlace()
	local books = Books()
	books.left, books.top = nil, nil
	if not docked then
		panel:ClearAllPoints()
		panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 280, -120)
	end
end

function SurvivorUI_ToggleJewelry()
	if not Enabled() then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the Jewelry Collection is off (/sui opt, Modules).")
		return
	end
	if panel:IsShown() then
		panel:Hide()
	else
		docked = false
		panel:Show()
	end
end

local paneButton

-- For the options and the character pane's button.
function SurvivorUI_JewelryWithPane()
	return WithPane() and true or false
end

function SurvivorUI_SetJewelryWithPane(on)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.jewelryWithPane = on and true or false
	local pane = getglobal("SurvivorUICharacter")
	if pane and pane:IsVisible() then
		if on then
			docked = true
			Dock()
			panel:Show()
		elseif docked then
			docked = false
			panel:Hide()
		end
	end
	if paneButton then
		paneButton:Refresh()
	end
end

-- The character pane's button: the collection beside it, or put away. At the
-- hero's side's bottom right, the collection's own icon, lit while it is open.
local pane = getglobal("SurvivorUICharacter")
if pane then
	paneButton = CreateFrame("Button", nil, pane)
	paneButton:SetWidth(20)
	paneButton:SetHeight(20)
	-- In the corner of the hero's side, whether the numbers are in the pane or not.
	paneButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", (SurvivorUI_CHARACTER_WIDTH or 342) - 6, 6)
	paneButton:SetFrameLevel(pane:GetFrameLevel() + 10)
	paneButton.noHoverOutline = true
	paneButton.edge = Fill(paneButton, "BACKGROUND", 0, 0, 0, 1)
	paneButton.edge:SetPoint("TOPLEFT", paneButton, "TOPLEFT", -1, 1)
	paneButton.edge:SetPoint("BOTTOMRIGHT", paneButton, "BOTTOMRIGHT", 1, -1)
	paneButton.icon = paneButton:CreateTexture(nil, "ARTWORK")
	paneButton.icon:SetAllPoints(paneButton)
	paneButton.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\JewelryIcon")
	function paneButton:Refresh()
		local on = WithPane()
		self.icon:SetVertexColor(on and 1 or 0.55, on and 1 or 0.55, on and 1 or 0.55)
		self.edge:SetVertexColor(self.hot and 1 or (on and 1 or 0), self.hot and 0.82 or (on and 0.82 or 0), 0, 1)
	end
	paneButton:SetScript("OnClick", function()
		SurvivorUI_SetJewelryWithPane(not WithPane())
	end)
	paneButton:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText("Jewelry Collection", 1, 0.82, 0)
		GameTooltip:AddLine(WithPane() and "Click to put it away." or "Click to show it beside the character pane, every time it opens.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	paneButton:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	paneButton:Refresh()
end

-- The character pane's coming and going, watched.
local paneWatch = CreateFrame("Frame")
local paneShown = false
local paneElapsed = 0
paneWatch:SetScript("OnUpdate", function()
	paneElapsed = paneElapsed + arg1
	if paneElapsed < 0.1 then
		return
	end
	paneElapsed = 0
	-- Off as a whole: no button, no collection.
	if not Enabled() then
		if paneButton and paneButton:IsShown() then
			paneButton:Hide()
		end
		if panel:IsShown() then
			docked = false
			panel:Hide()
		end
		paneShown = nil
		return
	elseif paneButton and not paneButton:IsShown() then
		paneButton:Show()
	end
	-- Off as a whole: no button, no collection.
	if not Enabled() then
		if paneButton and paneButton:IsShown() then
			paneButton:Hide()
		end
		if panel:IsShown() then
			docked = false
			panel:Hide()
		end
		paneShown = nil
		return
	elseif paneButton and not paneButton:IsShown() then
		paneButton:Show()
	end
	local characterPane = getglobal("SurvivorUICharacter")
	local shown = characterPane and characterPane:IsVisible() and true or false
	if shown == paneShown then
		return
	end
	paneShown = shown
	if paneButton then
		paneButton:Refresh()
	end
	if not WithPane() then
		return
	end
	if shown and not panel:IsShown() then
		docked = true
		Dock()
		panel:Show()
	elseif not shown and docked then
		docked = false
		panel:Hide()
	end
end)
