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
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
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

-- Two records of a bonus (or a rank's), as one: the lowest and highest of both.
local function Widen(into, from)
	into.min = math.min(into.min or from.min, from.min)
	into.max = math.max(into.max or from.max, from.max)
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
	for each = 1, table.getn(old.stats or {}) do
		local stat = old.stats[each]
		local mine
		for other = 1, table.getn(item.stats) do
			if item.stats[other].pattern == stat.pattern then
				mine = item.stats[other]
			end
		end
		if mine then
			Widen(mine, stat)
			for rank, values in pairs(stat.ranks or {}) do
				mine.ranks[rank] = mine.ranks[rank] or {}
				Widen(mine.ranks[rank], values)
			end
		else
			table.insert(item.stats, stat)
		end
	end
end

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
	return books.shared
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
local function Bonus(text)
	local _, _, number, percent = string.find(text, "(%d+%.?%d*)(%%?)")
	if not number then
		return nil
	end
	local pattern = string.gsub(text, "%d+%.?%d*", "#", 1)
	return pattern, tonumber(number), percent
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
		local text = line and line:GetText()
		local pattern, value, unit = Bonus(text or "")
		if pattern then
			local stat
			for each = 1, table.getn(item.stats) do
				if item.stats[each].pattern == pattern then
					stat = item.stats[each]
				end
			end
			if not stat then
				stat = { pattern = pattern, unit = unit, ranks = {},
					tag = SurvivorUI_StatOf and SurvivorUI_StatOf(text) or nil }
				table.insert(item.stats, stat)
			end
			stat.min = math.min(stat.min or value, value)
			stat.max = math.max(stat.max or value, value)
			local byRank = stat.ranks[rank] or {}
			byRank.min = math.min(byRank.min or value, value)
			byRank.max = math.max(byRank.max or value, value)
			stat.ranks[rank] = byRank
		end
	end
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

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
watcher:SetScript("OnEvent", function()
	if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
		return
	end
	Look()
end)
-- An upgrade from a card can change a piece without an inventory event: a
-- look every two seconds too.
local elapsed = 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 2 then
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
	text:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
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
			GameTooltip:AddLine("  "..(string.gsub(stat.pattern, "#", Range(stat.min, stat.max, ""))), 0.3, 1, 0.4, 1)
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
-- With the character pane (its own button, or the options, Character): the
-- collection opens and closes with it, set right beside it (beside the
-- numbers, when they stand on their own against it). From the minimap
-- button, on its own, where it was left.

local function WithPane()
	return SurvivorUIDB and SurvivorUIDB.jewelryWithPane
end

local function Dock()
	local pane = getglobal("SurvivorUICharacter")
	if not pane then
		return
	end
	local beside = pane
	local stats = getglobal("SurvivorUICharacterStats")
	if stats and stats:IsVisible() and stats:GetParent() ~= pane and stats:GetLeft() and pane:GetRight() then
		local gap = stats:GetLeft() * stats:GetEffectiveScale() - pane:GetRight() * pane:GetEffectiveScale()
		if gap > -40 and gap < 40 then
			beside = stats
		end
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", beside, "TOPRIGHT", 8, 0)
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

function SurvivorUI_ToggleJewelry()
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
	SurvivorUIDB.jewelryWithPane = on and true or nil
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
