-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the build, in the right column between the run tracker and the
-- damage meter, the same spells side by side with what they deal.
--
-- Every spell slot, filled or not: each spell with its icon, its name in the
-- same color the damage meter gives it, its rank, and its range, its cooldown
-- or both (as chosen: Build list tab), then the racial apart (it takes no
-- slot). The third column, Info, holds what matters most besides the
-- cooldown: a range, a radius, how long a spell lasts (its row a timer while
-- it is up), or how much a heal gives back. Empty slots show, since how many
-- are left matters at every card choice. Hover a spell for its card: rank,
-- cooldown, damage and crits. The spells run from the highest rank down, each
-- in a border of its color.
--
-- Under the spells, the jewelry worn (neck, rings, trinkets), the gear a run
-- drops: each slot filled with the piece's quality color, with what it gives in
-- short, read off its tooltip ("Neck  CDR · DMG").
--
-- From the game's addon API (AZS_SPELLS); without it nothing shows. Hold Alt
-- and drag to move; /sui build hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 224
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 20
local HEAD_HEIGHT = 13          -- the columns' names, under the title
local SLOTS = 6                 -- spell slots a run has
local RACIAL_SLOT = 12          -- the action bar's last button carries the racial
local MUTED = { 0.45, 0.45, 0.45 }
local GEAR_SLOTS = {               -- inventory slot, label
	{ 2, "Neck" }, { 11, "Ring" }, { 12, "Ring" }, { 13, "Trinket" }, { 14, "Trinket" },
}
local GEAR_TOP = TITLE_HEIGHT + HEAD_HEIGHT + (SLOTS + 1) * ROW_HEIGHT + 6

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.buildList == nil then
		SurvivorUIDB.buildList = true
	end
	return SurvivorUIDB
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- The action button of the spell at this index of the game's list (Meter.lua,
-- SurvivorUI_SpellSlot: the list's order, unless a spell was dragged
-- elsewhere), for its icon and its tooltip.
local function Slot(index, count)
	if SurvivorUI_SpellSlot then
		return SurvivorUI_SpellSlot(index)
	end
	return index == count and RACIAL_SLOT or index
end

-- "holy_wrath" as the meter and the cards name it: "Holy Wrath". The game
-- spells soul_fire "Soulfire" (its 0.110), as the meter does (Meter.lua).
local NAMES = {
	sw_pain = "Shadow Word: Pain", pw_shield = "Power Word: Shield",
	demo_shout = "Demoralizing Shout", hunters_mark = "Hunter's Mark",
	soul_fire = "Soulfire",
}

-- "of", "the" and "and" small after the first word, as the meter has them:
-- "Call of Flame". The colors go by the name, so the spelling must match.
local LOWER_WORDS = { of = true, the = true, ["and"] = true }

local function SpellName(key)
	if NAMES[key] then
		return NAMES[key]
	end
	local name = string.gsub(key or "?", "_", " ")
	local first = true
	return (string.gsub(name, "(%a)([%w']*)", function(initial, rest)
		local word = initial..rest
		if not first and LOWER_WORDS[string.lower(word)] then
			return string.lower(word)
		end
		first = false
		return string.upper(initial)..rest
	end))
end

local function Running()
	if not (AZS_GetPhase and AZS_SPELLS) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

------------------------------------------------------------------------------
-- The frame.

local list = CreateFrame("Frame", "SurvivorUIBuild", UIParent)
list:SetWidth(WIDTH + 12)
list:SetHeight(GEAR_TOP + 16 + table.getn(GEAR_SLOTS) * 17 + 6)
list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -260)
list:SetBackdrop({ bgFile = FLAT })
list:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
list:SetMovable(true)
list:Hide()

local function SavePlace()
	local settings = Settings()
	settings.buildLeft = math.floor(list:GetLeft() + 0.5)
	settings.buildTop = math.floor(list:GetTop() + 0.5)
end

local function RestorePlace()
	local settings = Settings()
	list:ClearAllPoints()
	if settings.buildLeft then
		list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings.buildLeft, settings.buildTop)
	elseif SurvivorUITracker then
		-- Under the run tracker, right edges together.
		list:SetPoint("TOPRIGHT", SurvivorUITracker, "BOTTOMRIGHT", 8, -14)
	else
		list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -260)
	end
end

list.title = list:CreateFontString(nil, "OVERLAY")
list.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
list.title:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -6)
list.title:SetTextColor(1, 0.82, 0)
list.title:SetText("Build")

list.count = list:CreateFontString(nil, "OVERLAY")
list.count:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
list.count:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -7)

------------------------------------------------------------------------------
-- The columns at the right of each spell: its range and its cooldown (each
-- as chosen: Build list tab) and its rank, each under its name in the header
-- and between dividers. Laid out from the right edge; the name takes the
-- rest.

-- Info's symbol a column of its own at its left, no name over it.
local COLUMN_WIDTH = { rank = 24, cd = 30, range = 34, symbol = 13 }
local columns                   -- [key] = { right, width, divider }, the ones shown
local columnsKey
local nameRoom = WIDTH - ROW_HEIGHT - 70

local function Columns(showRange, showCooldown)
	local key = (showRange and "r" or "")..(showCooldown and "c" or "")
	if key == columnsKey then
		return false
	end
	columnsKey = key
	columns = {}
	local order = { "rank" }
	if showCooldown then
		table.insert(order, "cd")
	end
	if showRange then
		table.insert(order, "range")
		table.insert(order, "symbol")
	end
	local right = 2
	for index = 1, table.getn(order) do
		local width = COLUMN_WIDTH[order[index]]
		columns[order[index]] = { right = right, width = width, divider = right + width + 1 }
		right = right + width + 3
	end
	nameRoom = WIDTH - right - ROW_HEIGHT - 1
	return true
end

-- A column's text, centered in its column; away with its column.
local function PlaceText(text, column)
	text:ClearAllPoints()
	if column then
		text:SetPoint("RIGHT", text:GetParent(), "RIGHT", -column.right, 0)
		text:SetWidth(column.width)
		text:Show()
	else
		text:Hide()
	end
end

local head = CreateFrame("Frame", nil, list)
head:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -TITLE_HEIGHT)
head:SetWidth(WIDTH)
head:SetHeight(HEAD_HEIGHT)
local function HeadLabel(text)
	local label = head:CreateFontString(nil, "OVERLAY")
	label:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	label:SetJustifyH("CENTER")
	label:SetTextColor(0.62, 0.62, 0.66)
	label:SetText(text)
	return label
end
head.range = HeadLabel("Info")
head.cd = HeadLabel("CD")
head.rank = HeadLabel("Rank")

-- The dividers, over the rows: from the header's top to the racial's bottom,
-- each at its column's left.
local rules = CreateFrame("Frame", nil, list)
rules:SetAllPoints(list)
rules:SetFrameLevel(list:GetFrameLevel() + 6)
rules.lines = {}
for _, key in pairs({ "rank", "cd", "range", "symbol" }) do
	local line = rules:CreateTexture(nil, "OVERLAY")
	line:SetTexture(FLAT)
	line:SetVertexColor(1, 1, 1, 0.14)
	line:SetWidth(1)
	rules.lines[key] = line
end

-- A column's name, centered over it, never wrapped.
local function PlaceLabel(label, column)
	label:ClearAllPoints()
	if column then
		label:SetPoint("CENTER", head, "RIGHT", -column.right - column.width / 2, 0)
		label:Show()
	else
		label:Hide()
	end
end

local function PlaceHead()
	for key, line in pairs(rules.lines) do
		local column = columns[key]
		line:ClearAllPoints()
		if column then
			-- Between Info's symbols and its numbers, from the rows down only:
			-- the name over them is the two columns'.
			local under = key == "range" and columns.symbol and HEAD_HEIGHT or 0
			line:SetPoint("TOPLEFT", list, "TOPLEFT", 6 + WIDTH - column.divider, -TITLE_HEIGHT - 1 - under)
			line:SetHeight(HEAD_HEIGHT + (SLOTS + 1) * ROW_HEIGHT - 1 - under)
			line:Show()
		else
			line:Hide()
		end
	end
	-- Info's name over its symbols and its numbers together.
	local info = columns.range
	if info and columns.symbol then
		local left = columns.symbol.right + columns.symbol.width
		info = { right = info.right, width = left - info.right }
	end
	PlaceLabel(head.range, info)
	PlaceLabel(head.cd, columns.cd)
	PlaceLabel(head.rank, columns.rank)
end

local function PlaceRow(row)
	PlaceText(row.range, columns.range)
	PlaceText(row.cd, columns.cd)
	PlaceText(row.rank, columns.rank)
	row.name:SetWidth(nameRoom)
end

local rows = {}

local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, list)
	row:SetWidth(WIDTH)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -TITLE_HEIGHT - HEAD_HEIGHT - (index - 1) * ROW_HEIGHT)
	-- A dark base under a spell's color, drawn by the list under the row: the
	-- color reads the same over any ground, as Biggest Crits'.
	row.base = list:CreateTexture(nil, "ARTWORK")
	row.base:SetTexture(FLAT)
	row.base:SetVertexColor(0.05, 0.05, 0.07, 0.92)
	row.base:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.base:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
	row.base:Hide()

	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(FLAT)
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)

	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetTexture(FLAT)
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	-- A border for the highest ranks, hidden otherwise.
	row.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = row:CreateTexture(nil, "OVERLAY")
		line:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", row, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", row, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, row, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, row, "BOTTOM"..side, 0, 0)
		end
		line:Hide()
		table.insert(row.edges, line)
	end

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW_HEIGHT - 4)
	row.icon:SetHeight(ROW_HEIGHT - 4)
	row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	row.name:SetPoint("LEFT", row, "LEFT", ROW_HEIGHT + 2, 0)
	row.name:SetWidth(WIDTH - ROW_HEIGHT - 70)
	row.name:SetHeight(12)
	row.name:SetJustifyH("LEFT")

	row.range = row:CreateFontString(nil, "OVERLAY")
	row.range:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	row.range:SetJustifyH("CENTER")
	row.range:SetTextColor(0.6, 0.6, 0.6)

	-- A lasting spell's hourglass or a heal's cross in the Info cell; the part
	-- of a lasting spell's row its time has run out of, and the timer's edge.
	row.glass = row:CreateTexture(nil, "OVERLAY")
	row.glass:SetWidth(9)
	row.glass:SetHeight(9)
	row.glass:Hide()
	row.spent = row:CreateTexture(nil, "BACKGROUND")
	row.spent:SetTexture(FLAT)
	row.spent:Hide()
	row.tick = row:CreateTexture(nil, "BORDER")
	row.tick:SetTexture(FLAT)
	row.tick:SetVertexColor(1, 0.94, 0.78, 0.9)
	row.tick:SetWidth(1)
	row.tick:SetHeight(ROW_HEIGHT - 2)
	row.tick:Hide()

	row.cd = row:CreateFontString(nil, "OVERLAY")
	row.cd:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	row.cd:SetJustifyH("CENTER")
	row.cd:SetTextColor(0.6, 0.6, 0.6)

	row.rank = row:CreateFontString(nil, "OVERLAY")
	row.rank:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	row.rank:SetJustifyH("CENTER")
	if columns then
		PlaceRow(row)
	end

	-- The spell's tooltip, as on its action button (AbilityTooltip.lua lays it
	-- out): beside the list, on its left, level with the row. Its damage and
	-- crits are the damage meter's and Biggest Crits' cards.
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		if not (this.ability and this.actionSlot) then
			return
		end
		GameTooltip:SetOwner(this, "ANCHOR_NONE")
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPRIGHT", this, "TOPLEFT", -((this:GetLeft() or 0) - (list:GetLeft() or 0)) - 6, 0)
		GameTooltip:SetAction(this.actionSlot)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)

	rows[index] = row
	return row
end

local function Border(row, color, alpha)
	for index = 1, table.getn(row.edges) do
		local line = row.edges[index]
		if alpha and alpha > 0 then
			line:SetVertexColor(color[1], color[2], color[3], alpha)
			line:Show()
		else
			line:Hide()
		end
	end
end

-- The top spell's name and rank a point larger, a touch brighter; set only
-- when it changes, since setting a font costs the engine every time.
local function Bold(row, bold)
	if row.bold ~= bold then
		row.bold = bold
		row.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
		row.rank:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
	end
end

-- A spell's row filled with its color, the text light over it; an empty slot
-- or the racial only a faint wash, the text in the color.
local function Paint(row, color, alpha, filled)
	if filled then
		row.base:Show()
	else
		row.base:Hide()
	end
	if filled then
		row.name:SetTextColor(1, 1, 1)
		row.rank:SetTextColor(1, 1, 1)
		row.range:SetTextColor(0.9, 0.9, 0.9)
		row.cd:SetTextColor(0.9, 0.9, 0.9)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
	else
		row.name:SetTextColor(color[1], color[2], color[3])
		row.rank:SetTextColor(color[1], color[2], color[3])
		row.range:SetTextColor(0.6, 0.6, 0.6)
		row.cd:SetTextColor(0.6, 0.6, 0.6)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.07 * alpha)
	end
	row.rule:SetVertexColor(color[1], color[2], color[3], 0.28 * alpha)
end

-- A spell's range, read off its button's tooltip: the short lines over its
-- cast line ("28 yd"; a spell with none, its radius: "11 yd radius"). Kept
-- by its name and rank a few seconds, an upgrade can widen it.
local scan = CreateFrame("GameTooltip", "SurvivorUIBuildScan", nil, "GameTooltipTemplate")
local reaches = {}              -- [name:rank] = { text or false, when read }

local function Reach(actionSlot, name, rank)
	local key = tostring(name)..":"..tostring(rank)
	local known = reaches[key]
	if known and GetTime() - known[2] < 5 then
		return known[1] or nil
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetAction(actionSlot)
	local range, radius
	for line = 2, scan:NumLines() do
		local text = getglobal("SurvivorUIBuildScanTextLeft"..line)
		text = text and text:GetText() or ""
		-- "Cast once enemies are within 30 yd", a totem's "once enemies are
		-- within 25 yd", Blizzard's "once enemies come within 30 yd": where it
		-- is cast from, not how far it reaches.
		text = string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
		text = string.gsub(text, "once enemies [ac][ro][em]e? within [%d%.]+ yd", "")
		local _, _, yards = string.find(text, "(%d+%.?%d*) yd")
		if yards then
			if string.find(text, "radius", 1, true) then
				radius = radius or yards
			else
				range = range or yards
			end
		end
	end
	scan:Hide()
	local reach = (range or radius) and ((range or radius).." yd") or false
	reaches[key] = { reach, GetTime() }
	return reach or nil
end

-- Beside each spell (the options, Build list): its range, its cooldown, or
-- both. The first builds of v3.0.5-beta.2 kept one choice, buildShows.
local function Shows()
	local db = Settings()
	if db.buildShows then
		if db.buildShows == "cooldown" then
			db.buildRange, db.buildCooldown = false, true
		end
		db.buildShows = nil
	end
	return db.buildRange ~= false, db.buildCooldown == true
end

-- A spell's cooldown as the game has it now, haste in: "3.1s", "12s".
local function CooldownText(entry)
	local cd = tonumber(Field(entry, "cdmax", 5)) or 0
	if cd <= 0 then
		return ""
	end
	if cd >= 10 then
		return string.format("%ds", math.floor(cd + 0.5))
	end
	return string.format("%.1fs", cd)
end

------------------------------------------------------------------------------
-- A spell whose time it lasts matters more than its reach (option A of the
-- build list's mockup, 2026-10-21): in its range cell an hourglass and its
-- length in gold, "8"; while it is up its row drains as a timer, the cell
-- counting down, "5.2". Buffs only (Divine Shield, Holy Shield, Battle Shout,
-- Slice and Dice, Adrenaline Rush, Lightning Shield, Thorns, and your demons'
-- Demonic Empowerment, which the game may not list among your own buffs, so
-- its length only; the shields' and the shout's reach is only where they are
-- cast from); a weakening on the enemies, Demoralizing Shout's, was tried and
-- left out. Its length is the game's: the time
-- left as its buff last went up (AZS_BUFFS, by its spell id
-- in AZS_SPELLS; kept for the account, an upgrade can lengthen it), else read
-- off its tooltip ("for 8 sec", "For 14 sec").

local LASTING = { divine_shield = true, holy_shield = true, battle_shout = true,
	slice_and_dice = true, adrenaline_rush = true, lightning_shield = true, thorns = true,
	demonic_empowerment = true }
local HOURGLASS = { 1, 0.84, 0.43 }
local buffs = { last = {} }      -- the run time the buffs were last told at; each spell's left then
local timing = false             -- a lasting spell up: the list drawn more often

local function RunSeconds()
	return AZS_GetRunTime and AZS_GetRunTime() or GetTime()
end

-- The seconds left on a spell's buff now, and its length as last seen.
local function Lasting(entry, key)
	local db = Settings()
	db.buildLasting = db.buildLasting or {}
	if AZS_BUFFS_UPDATED ~= buffs.seen then
		buffs.seen, buffs.at = AZS_BUFFS_UPDATED, RunSeconds()
	end
	local id = tonumber(Field(entry, "spell", 2))
	local left
	for index = 1, table.getn(AZS_BUFFS or {}) do
		local buff = AZS_BUFFS[index]
		if id and tonumber(Field(buff, "spell", 1)) == id then
			left = tonumber(Field(buff, "left", 2)) or 0
		end
	end
	-- Gone up, or up again: the time it has left is its length.
	if left and left > (buffs.last[key] or 0) + 0.3 then
		db.buildLasting[key] = math.floor(left * 10 + 0.5) / 10
	end
	buffs.last[key] = left
	if left then
		left = left - (RunSeconds() - (buffs.at or RunSeconds()))
	end
	return left and left > 0 and left or nil, db.buildLasting[key]
end

------------------------------------------------------------------------------
-- A heal on yourself (2026-10-21): how much of your health it gives back says
-- more than a range it has none of (Holy Light at once, Renew over its time). A green cross and its share, "48%", off
-- its tooltip ("48% of your max health"), else its amount ("Heals you for 287").

local HEALING = { holy_light = true, renew = true, healing_wave = true, rejuvenation = true, regrowth = true }
local CROSS = { 0.42, 1, 0.5 }
-- An absorb on yourself, Power Word: Shield's: how much of your health it
-- holds back, "25%", under a blue shield (it lasts until it breaks, so no
-- hourglass); else its amount ("Absorbs the next 120 damage").
-- Each with the words its amount follows in its tooltip.
local ABSORBING = { pw_shield = "[Aa]bsorbs the next (%d+)", ice_barrier = "up to (%d+)" }
local SHIELD = { 0.59, 0.82, 1 }
-- And a range or a radius, "22 yd", under a measuring arrow in gray, |<->| (idea C):
-- the most common, so the plainest; each color one meaning, gold a time, green
-- a heal, blue a shield.
local RANGE = { 0.8, 0.8, 0.83 }
local heals = {}                 -- [name:rank] = { text or false, when read }

-- A tooltip's line as plain text, its colors taken out.
local function Plain(text)
	text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
	return (string.gsub(text, "|r", ""))
end

local function HealText(actionSlot, name, rank, amountPattern)
	local key = tostring(name)..":"..tostring(rank)
	local known = heals[key]
	if known and GetTime() - known[2] < 5 then
		return known[1] or nil
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetAction(actionSlot)
	local share, amount
	for line = 2, scan:NumLines() do
		local text = getglobal("SurvivorUIBuildScanTextLeft"..line)
		text = Plain(text and text:GetText())
		local _, _, p = string.find(text, "(%d+%.?%d*)%% of your max health")
		local _, _, n = string.find(text, amountPattern or "[Hh]eals you for (%d+)")
		share, amount = share or p, amount or n
	end
	scan:Hide()
	local shown = share and (share.."%") or amount or false
	heals[key] = { shown, GetTime() }
	return shown or nil
end

-- Its length off its tooltip, before the game has shown it once.
local lengths = {}               -- [name:rank] = seconds, or false
local function TipLength(actionSlot, name, rank)
	local key = tostring(name)..":"..tostring(rank)
	if lengths[key] == nil then
		lengths[key] = false
		scan:SetOwner(WorldFrame, "ANCHOR_NONE")
		scan:ClearLines()
		scan:SetAction(actionSlot)
		for line = 2, scan:NumLines() do
			local text = getglobal("SurvivorUIBuildScanTextLeft"..line)
			local _, _, secs = string.find(Plain(text and text:GetText()), "[Ff]or (%d+%.?%d*) sec")
			if secs and not lengths[key] then
				lengths[key] = tonumber(secs)
			end
		end
		scan:Hide()
	end
	return lengths[key] or nil
end

-- The hourglass stands for the seconds: "8" or "5.5" beside it, no "s".
local function Length(seconds)
	if math.mod(seconds, 1) == 0 then
		return string.format("%d", seconds)
	end
	return string.format("%.1f", seconds)
end

-- The Info cell's number, centered as every column's, and its symbol in its
-- tint, centered in the symbols' column at its left: the hourglass, the cross,
-- the shield, the measuring arrow.
local function PlaceReach(row, symbol, tint)
	local column = columns and columns.range
	local place = columns and columns.symbol
	row.range:ClearAllPoints()
	if not column then
		row.glass:Hide()
		row.range:Hide()
		return
	end
	row.range:SetPoint("RIGHT", row, "RIGHT", -column.right, 0)
	row.range:SetWidth(column.width)
	row.range:SetJustifyH("CENTER")
	row.range:Show()
	if symbol and place then
		if row.symbol ~= symbol then
			row.symbol = symbol
			row.glass:SetTexture(ART..symbol)
		end
		-- Square between the column's two dividers, on whole pixels: 15 free
		-- between them, 3 either side of the 9 of the symbol.
		row.glass:ClearAllPoints()
		row.glass:SetPoint("RIGHT", row, "RIGHT", -place.right - 1, 0)
		row.glass:SetVertexColor(tint[1], tint[2], tint[3])
		row.glass:Show()
	else
		row.glass:Hide()
	end
end

-- The row as a timer: its color as far as the time left reaches, the rest
-- faint, a bright edge between; whole again otherwise.
local function Drain(row, share, color)
	row.wash:ClearAllPoints()
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	if share then
		local x = math.max(1, WIDTH * share)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", x, 1)
		row.spent:ClearAllPoints()
		row.spent:SetPoint("TOPLEFT", row, "TOPLEFT", x, -1)
		row.spent:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.spent:SetVertexColor(color[1], color[2], color[3], 0.12)
		row.spent:Show()
		row.tick:ClearAllPoints()
		row.tick:SetPoint("TOP", row, "TOPLEFT", x, -1)
		row.tick:Show()
	else
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
		row.spent:Hide()
		row.tick:Hide()
	end
end

-- A lasting spell's cell: its time left while it is up, else its length.
-- Returns the share of its time left, for the row's timer.
local function FillLasting(row, entry, key, actionSlot, name, showRange)
	local left, length = Lasting(entry, key)
	length = length or TipLength(actionSlot, name, Field(entry, "rank", 3))
	if left then
		timing = true
		row.range:SetText(showRange and string.format("%.1f", left) or "")
		row.range:SetTextColor(1, 1, 1)
		return length and math.min(1, left / length) or 1
	end
	row.range:SetText(showRange and length and Length(length) or "")
	row.range:SetTextColor(HOURGLASS[1], HOURGLASS[2], HOURGLASS[3])
end

local function Fill(row, entry, actionSlot, isRacial)
	local key = Field(entry, "key", 1)
	local name = SpellName(key)
	local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(name) or { 0.8, 0.8, 0.8 }
	row.ability, row.color = name, color
	-- Its tooltip is its action button's; the racial's tells the race's
	-- traits too (AbilityTooltip.lua).
	row.racial = isRacial
	row.actionSlot = actionSlot
	row.icon:SetTexture(GetActionTexture and GetActionTexture(actionSlot) or nil)
	row.icon:SetAlpha(1)
	row.name:SetText(isRacial and name.."  |cff8a8a8a(racial)|r" or name)
	row.rank:SetText(tonumber(Field(entry, "rank", 3)) or "")
	local showRange, showCooldown = Shows()
	local lasting = LASTING[key] and not isRacial
	if lasting and showRange then
		-- Up, or its length known or told; else its range, as any spell's.
		local left, length = Lasting(entry, key)
		lasting = (left or length or TipLength(actionSlot, name, Field(entry, "rank", 3))) and true
	end
	-- A heal's or an absorb's share of your health, when its tooltip tells it;
	-- else its range, as any spell's.
	local healing = HEALING[key] and not isRacial and showRange
		and HealText(actionSlot, name, Field(entry, "rank", 3))
	local absorbing = ABSORBING[key] and not isRacial and showRange
		and HealText(actionSlot, name, Field(entry, "rank", 3), ABSORBING[key])
	if lasting then
		PlaceReach(row, showRange and "Hourglass", HOURGLASS)
	elseif healing then
		PlaceReach(row, "HealCross", CROSS)
		row.range:SetText(healing)
	elseif absorbing then
		PlaceReach(row, "Shield", SHIELD)
		row.range:SetText(absorbing)
	else
		-- The measuring arrow stands for the yards: "22" beside it, not "22 yd".
		local reach = showRange and Reach(actionSlot, name, Field(entry, "rank", 3))
		PlaceReach(row, reach and "Range", RANGE)
		row.range:SetText(reach and (string.gsub(reach, " yd$", "")) or "")
	end
	row.cd:SetText(showCooldown and CooldownText(entry) or "")
	Paint(row, color, isRacial and 0.5 or 1, not isRacial)
	if healing then
		row.range:SetTextColor(CROSS[1], CROSS[2], CROSS[3])
	elseif absorbing then
		row.range:SetTextColor(SHIELD[1], SHIELD[2], SHIELD[3])
	end
	Drain(row, lasting and FillLasting(row, entry, key, actionSlot, name, showRange), color)
	row:Show()
end

local function Empty(row)
	row.ability, row.color, row.racial = nil, nil, nil
	row.icon:SetTexture(FLAT)
	row.icon:SetVertexColor(0.15, 0.15, 0.18)
	row.icon:SetAlpha(0.8)
	row.name:SetText("empty slot")
	row.rank:SetText("")
	PlaceReach(row, false)
	row.range:SetText("")
	row.cd:SetText("")
	Paint(row, MUTED, 0.6)
	Drain(row, nil)
	row:Show()
end

------------------------------------------------------------------------------
-- The race's traits, as the game tells them in the chat as a run begins:
-- "- Berserking: every 35 sec, cooldowns recover 30% faster for 10 sec",
-- "- Regeneration: +1.5 health per second". Read before the run starts (its
-- lines come then), kept by race for the account, a new run's list in place
-- of the last; for the racial's card (RunPanel.lua: SurvivorUI_Racials).

local function Racials()
	local db = Settings()
	db.racials = db.racials or {}
	return db.racials
end

local function RaceKey()
	local _, race = UnitRace("player")
	return race or "?"
end

local function ReadRacial(text)
	if not text then
		return
	end
	local phase = AZS_GetPhase and AZS_GetPhase()
	if phase and phase ~= "ready" then
		return
	end
	local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	plain = string.gsub(plain, "|r", "")
	local _, _, name, desc = string.find(plain, "^%- ([^:]+): (.+)$")
	if not name then
		return
	end
	local racials = Racials()
	local key = RaceKey()
	local entry = racials[key]
	-- A list older than a minute is a run before: this one starts it again.
	local now = time and time() or GetTime()
	if not entry or math.abs(now - (entry.at or 0)) > 60 then
		entry = { at = now, traits = {} }
		racials[key] = entry
	end
	for _, trait in pairs(entry.traits) do
		if trait.name == name then
			trait.text = desc
			return
		end
	end
	table.insert(entry.traits, { name = name, text = desc })
end

-- The race's name and its traits, nil until a run has told them.
function SurvivorUI_Racials()
	local entry = Racials()[RaceKey()]
	return UnitRace("player"), entry and entry.traits
end

-- By the system's line, and by the chat window's, for a line no event brings.
local racialWatch = CreateFrame("Frame")
racialWatch:RegisterEvent("CHAT_MSG_SYSTEM")
racialWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
racialWatch:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		local frame = DEFAULT_CHAT_FRAME
		if frame and not frame.survivorRacialWatched then
			frame.survivorRacialWatched = true
			local stock = frame.AddMessage
			frame.AddMessage = function(self, text, r, g, b, id, hold)
				ReadRacial(text)
				return stock(self, text, r, g, b, id, hold)
			end
		end
		return
	end
	ReadRacial(arg1)
end)

local function Draw()
	timing = false
	-- The columns as chosen; changed, every row laid out again.
	if Columns(Shows()) then
		PlaceHead()
		for index = 1, table.getn(rows) do
			PlaceRow(rows[index])
		end
	end
	local spells = AZS_SPELLS or {}
	local count = table.getn(spells)
	-- The racial comes last in the game's list and takes no slot.
	local slotted = math.max(0, count - 1)
	-- The three highest ranks among the slotted spells, ties to the earlier
	-- slot: the first bold with a full border, the second a full border, the
	-- third a faint one; the rest plain. The list itself runs in that order.
	local order = {}
	for index = 1, slotted do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		local ra = tonumber(Field(spells[a], "rank", 3)) or 0
		local rb = tonumber(Field(spells[b], "rank", 3)) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	-- Rows from the highest rank down; each spell keeps its own action button
	-- for its icon.
	for place = 1, SLOTS do
		local row = Row(place)
		row.icon:SetVertexColor(1, 1, 1)
		local index = order[place]
		if index then
			Fill(row, spells[index], Slot(index, count), false)
		else
			Empty(row)
		end
	end
	-- Every spell the same border in its color; the order says the rest.
	for slot = 1, SLOTS do
		local row = rows[slot]
		if order[slot] then
			Border(row, row.color, 0.6)
		else
			Border(row, nil, 0)
		end
	end
	local racialRow = Row(SLOTS + 1)
	racialRow.icon:SetVertexColor(1, 1, 1)
	if count >= 1 then
		Fill(racialRow, spells[count], Slot(count, count), true)
	else
		racialRow.base:Hide()
		racialRow:Hide()
	end
	list.count:SetText((slotted >= SLOTS and "|cffff8080" or "|cffd0d0d0")..math.min(slotted, SLOTS).." / "..SLOTS.."|r")
end

------------------------------------------------------------------------------
-- The gear: each piece of jewelry and what it gives, in short.

-- Words in a tooltip line and their short names, the more specific first.
local STAT_WORDS = {
	{ "stun duration", "STUN" }, { "stun", "STUN" }, { "root", "ROOT" },
	{ "shields you", "SHIELD" }, { "absorb", "ABSORB" }, { "weaken", "WEAK" },
	{ "explode", "BOOM" }, { "leap", "LEAP" }, { "splash", "SPLASH" }, { "burn and bleed", "BLEED" },
	{ "strike again", "AGAIN" }, { "duration", "DUR" },
	{ "you kill restores", "HP/KILL" }, { "kill heals", "HP/KILL" }, { "each kill", "HP/KILL" },
	{ "damage dealt heals", "LEECH" }, { "of all damage dealt", "LEECH" }, { "leech", "LEECH" },
	{ "critical strike damage", "CRIT DMG" }, { "critical damage", "CRIT DMG" },
	{ "damage of your critical", "CRIT DMG" }, { "critical strikes deal", "CRIT DMG" },
	{ "critical", "CRIT" }, { "crit", "CRIT" }, { "cooldown", "CDR" },
	{ "damage reduction", "DMG RED" }, { "damage taken", "DMG RED" }, { "armor", "DMG RED" },
	{ "area", "AREA" }, { "target", "TGT" }, { "twice", "ECHO" }, { "echo", "ECHO" },
	{ "movement", "SPD" }, { "speed", "SPD" }, { "per second", "REGEN" }, { "regen", "REGEN" },
	{ "health", "HP" }, { "pickup", "PICK" }, { "pick up", "PICK" }, { "experience", "XP" }, { "gold", "GOLD" },
	{ "luck", "LUCK" }, { "heal", "HEAL" }, { "thorns", "THORNS" },
	{ "live", "LIFE" }, { "damage", "DMG" },
}

-- A line's number as it reads, with its sign: "+24%", "-19%". A line that
-- gives more without a sign ("strikes 1 more target", "increases ... by 24%")
-- gets a +. A leap's count and its share: "2x36%".
local MORE_WORDS = { "more", "increase", "improve", "restore", "heals" }
local function Value(tag, text)
	local _, _, value = string.find(text, "([%+%-]?%d+%.?%d*%%?)")
	if not value then
		return nil
	end
	if tag == "LEAP" then
		local _, last = string.find(text, value, 1, true)
		local _, _, share = string.find(text, "(%d+%.?%d*%%)", (last or 0) + 1)
		return share and (value.."x"..share) or value
	end
	local first = string.sub(value, 1, 1)
	if first ~= "+" and first ~= "-" then
		for _, word in pairs(MORE_WORDS) do
			if string.find(text, word, 1, true) then
				return "+"..value
			end
		end
	end
	return value
end

-- How a bonus reads in the list: the number first, then its word; a leap the
-- other way round, its two numbers together; a stun or a root its word first
-- and its seconds (STUN 1.5s), or the chance of it (STUN 20%).
local CONTROL = { STUN = true, ROOT = true }
local function Tagged(tag, value)
	if not value then
		return tag
	elseif tag == "LEAP" then
		return tag.." "..value
	elseif CONTROL[tag] then
		if string.find(value, "%", 1, true) then
			return tag.." "..value
		end
		return tag.." "..value.."s"
	end
	return value.." "..tag
end

-- The short name a tooltip line gives: the first word of the list it names,
-- in the list's order, so "+29% critical strike damage" is CRIT DMG, not CRIT.
local function StatOf(text)
	for index = 1, table.getn(STAT_WORDS) do
		if string.find(text, STAT_WORDS[index][1], 1, true) then
			return STAT_WORDS[index][2]
		end
	end
end

-- The same short names for the jewelry collection (Jewelry.lua).
function SurvivorUI_StatOf(text)
	return StatOf(string.lower(text or ""))
end

local scan = CreateFrame("GameTooltip", "SurvivorUIScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Each worn piece, by its link: its rank, the Roman numeral that ends its name
-- ("Blackhand's Breadth IV"); the spell a legendary amulet boosts, named after
-- its colon ("Amulet of the Inferno: Consecration IV"); and what it gives, the
-- tooltip's lines with a number in them. An upgrade renames the piece, so the
-- link alone says when to read it again.
local pieces = {}               -- [item link] = { rank, spell, tags }

-- A name or bonus line in English, whatever language the game is in (Locale.lua).
local function English(name)
	return SurvivorUI_English and SurvivorUI_English(name) or name
end

local function EnglishLine(text)
	return SurvivorUI_EnglishLine and SurvivorUI_EnglishLine(text) or text
end

local function ReadPiece(slot, link)
	if pieces[link] then
		return pieces[link]
	end
	local _, _, name = string.find(link, "%[(.-)%]")
	name = name or ""
	-- Past rank X the name says "X+", and so does the row.
	local _, _, rank = string.find(name, " ([IVXL]+%+?)$")
	if rank then
		name = string.sub(name, 1, string.len(name) - string.len(rank) - 1)
	end
	name = English(name)
	-- Only a legendary amulet names a spell: one for each spell of each class.
	local spell
	if slot == 2 and string.find(link, "|cffff8000", 1, true) then
		_, _, spell = string.find(name, ": (.+)$")
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local tags, seen = {}, {}
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIScanTipTextLeft"..index)
		local text = line and string.lower(EnglishLine(line:GetText() or "")) or ""
		if string.find(text, "%d") then
			local tag = StatOf(text)
			if tag and not seen[tag] then
				seen[tag] = true
				table.insert(tags, Tagged(tag, Value(tag, text)))
			end
		end
	end
	pieces[link] = { rank = rank or "I", spell = spell, tags = table.concat(tags, " · ") }
	return pieces[link]
end

list.gearTitle = list:CreateFontString(nil, "OVERLAY")
list.gearTitle:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
list.gearTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -GEAR_TOP)
list.gearTitle:SetTextColor(1, 0.82, 0)
list.gearTitle:SetText("Gear")

-- The jewelry worn, the gear a run drops: one row a slot, filled with the
-- piece's quality color, the slot's name and what the piece gives in short;
-- an empty slot faint. Hover a piece for its own tooltip.
local GEAR_ROW = 17

local gearLines = {}
for index = 1, table.getn(GEAR_SLOTS) do
	local line = CreateFrame("Frame", nil, list)
	line:SetWidth(WIDTH)
	line:SetHeight(GEAR_ROW - 1)
	line:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -GEAR_TOP - 15 - (index - 1) * GEAR_ROW)

	line.wash = line:CreateTexture(nil, "BACKGROUND")
	line.wash:SetTexture(FLAT)
	line.wash:SetAllPoints(line)

	line.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = line:CreateTexture(nil, "BORDER")
		edge:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetHeight(1)
			edge:SetPoint(side.."LEFT", line, side.."LEFT", 0, 0)
			edge:SetPoint(side.."RIGHT", line, side.."RIGHT", 0, 0)
		else
			edge:SetWidth(1)
			edge:SetPoint("TOP"..side, line, "TOP"..side, 0, 0)
			edge:SetPoint("BOTTOM"..side, line, "BOTTOM"..side, 0, 0)
		end
		table.insert(line.edges, edge)
	end

	line.label = line:CreateFontString(nil, "OVERLAY")
	line.label:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	line.label:SetPoint("LEFT", line, "LEFT", 4, 0)
	line.tags = line:CreateFontString(nil, "OVERLAY")
	line.tags:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	line.tags:SetPoint("RIGHT", line, "RIGHT", -4, 0)

	line:EnableMouse(true)
	line:SetScript("OnEnter", function()
		if this.slot and GetInventoryItemLink("player", this.slot) then
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetInventoryItem("player", this.slot)
			GameTooltip:Show()
		end
	end)
	line:SetScript("OnLeave", function() GameTooltip:Hide() end)
	gearLines[index] = line
end

local function PaintGear(line, r, g, b, fill, edge)
	line.wash:SetVertexColor(r, g, b, fill)
	for _, piece in pairs(line.edges) do
		piece:SetVertexColor(r, g, b, edge)
	end
end

-- A piece's bonuses beside its slot, a point or two smaller when they would
-- run into it (a legendary amulet has many). Sized again only when the text
-- changes, as a font set over and over costs.
-- A legendary amulet's spell, short, to leave room for its bonuses: several
-- words by their initials ("Hammer of Justice" HoJ), one long word cut
-- ("Consecration" Consec.). Hover the row for the whole name.
local SMALL_WORDS = { of = true, the = true, ["and"] = true }

local function Short(spell)
	local initials, words = "", 0
	for word in string.gfind(spell, "%S+") do
		words = words + 1
		local first = string.sub(word, 1, 1)
		initials = initials..(SMALL_WORDS[string.lower(word)] and string.lower(first) or string.upper(first))
	end
	if words > 1 then
		return initials
	end
	if string.len(spell) > 7 then
		return string.sub(spell, 1, 6).."."
	end
	return spell
end

local function FitTags(line, text)
	local key = (line.label:GetText() or "").."|"..text
	if line.tagText == key then
		return
	end
	line.tags:SetText(text)
	local labelWidth = line.label:GetStringWidth()
	-- A label not drawn yet measures nothing: sized again next time.
	line.tagText = labelWidth > 0 and key or nil
	local room = WIDTH - 8 - labelWidth - 10
	for size = 9, 6, -1 do
		line.tags:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
		if line.tags:GetStringWidth() <= room then
			break
		end
	end
end

local function DrawGear()
	list.gearTitle:SetText("Jewelry")
	for index = 1, table.getn(GEAR_SLOTS) do
		local slot, label = GEAR_SLOTS[index][1], GEAR_SLOTS[index][2]
		local line = gearLines[index]
		line.slot = slot
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link then
			-- The quality color the link carries: "|cffa335ee" is an epic's purple.
			local _, _, rr, gg, bb = string.find(link, "|c%x%x(%x%x)(%x%x)(%x%x)")
			local r = (tonumber(rr or "cc", 16) or 204) / 255
			local g = (tonumber(gg or "cc", 16) or 204) / 255
			local b = (tonumber(bb or "cc", 16) or 204) / 255
			PaintGear(line, r, g, b, 0.45, 0.7)
			-- The slot, then the piece's rank as a Roman numeral: "Ring  II". A
			-- legendary amulet shows the spell it boosts in the slot's place.
			local piece = ReadPiece(slot, link)
			line.label:SetText((piece.spell and Short(piece.spell) or label).."  "..piece.rank)
			line.label:SetTextColor(1, 1, 1)
			FitTags(line, piece.tags ~= "" and piece.tags or "-")
			line.tags:SetTextColor(1, 1, 1)
		else
			PaintGear(line, 0.5, 0.5, 0.55, 0.06, 0.15)
			line.label:SetText(label)
			line.label:SetTextColor(0.45, 0.45, 0.5)
			FitTags(line, "empty")
			line.tags:SetTextColor(0.4, 0.4, 0.45)
		end
		line:Show()
	end
end

local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	-- A lasting spell's timer counts down in tenths.
	if elapsed < (timing and 0.1 or 0.25) then
		return
	end
	elapsed = 0
	if Settings().buildList and Running() then
		Draw()
		DrawGear()
		if not list:IsShown() then
			list:Show()
		end
	elseif list:IsShown() then
		list:Hide()
	end
end)

-- The game's own build, its row of spells and jewelry with their cooldowns:
-- away while this list is on, unless asked to stay (gameBuildToo: since the
-- game's 0.111 its talent icon is the only place that counts down to the
-- next Felguard or Pit Lord of Butcher and Pact of the Annihilan). The
-- setting is the game's and is saved, so the addon remembers that it was the
-- one to turn it off.
local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if (settings.buildList and not settings.gameBuildToo) or settings.noGameBuild then
		if AZS_IsHudShown("build") then
			AZS_SetHudShown("build", false)
			settings.hidGameBuild = true
		end
	elseif settings.hidGameBuild then
		AZS_SetHudShown("build", true)
		settings.hidGameBuild = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.build = ApplyGameHud

-- For the last runs (RunHistory.lua): the build as it stands, the spells by
-- rank, the highest first, then the racial: { name, rank, icon, color, racial,
-- range, cd }, the range and the cooldown as the list shows them.
function SurvivorUI_BuildSnapshot()
	local spells = AZS_SPELLS or {}
	local count = table.getn(spells)
	local order = {}
	for index = 1, math.max(0, count - 1) do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		local ra = tonumber(Field(spells[a], "rank", 3)) or 0
		local rb = tonumber(Field(spells[b], "rank", 3)) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local list = {}
	local showRange, showCooldown = Shows()
	local function Add(entry, slot, racial)
		local name = SpellName(Field(entry, "key", 1))
		local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(name) or { 0.8, 0.8, 0.8 }
		local rank = tonumber(Field(entry, "rank", 3))
		table.insert(list, {
			name = name, rank = rank, racial = racial,
			icon = GetActionTexture and GetActionTexture(slot) or nil,
			color = { color[1], color[2], color[3] },
			range = showRange and (Reach(slot, name, rank) or "") or nil,
			cd = showCooldown and CooldownText(entry) or nil,
		})
	end
	for index = 1, table.getn(order) do
		Add(spells[order[index]], Slot(order[index], count), false)
	end
	if count >= 1 then
		Add(spells[count], Slot(count, count), true)
	end
	return list
end

-- For the last runs too: the jewelry lines as they read, one a slot: { label,
-- tags, color, item, name, tip }, or { label, empty } for a slot with nothing.
function SurvivorUI_GearSnapshot()
	local gear = {}
	for index = 1, table.getn(GEAR_SLOTS) do
		local slot, label = GEAR_SLOTS[index][1], GEAR_SLOTS[index][2]
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link then
			local _, _, rr, gg, bb = string.find(link, "|c%x%x(%x%x)(%x%x)(%x%x)")
			local _, _, item = string.find(link, "|H(item:[%d:%-]+)|h")
			local _, _, name = string.find(link, "%[(.-)%]")
			local piece = ReadPiece(slot, link)
			-- Its tooltip as it reads now.
			local tip
			if SurvivorUI_ReadTooltip then
				scan:SetOwner(WorldFrame, "ANCHOR_NONE")
				scan:ClearLines()
				scan:SetInventoryItem("player", slot)
				tip = SurvivorUI_ReadTooltip(scan)
				scan:Hide()
			end
			table.insert(gear, {
				label = (piece.spell and Short(piece.spell) or label).."  "..piece.rank,
				tags = piece.tags ~= "" and piece.tags or "-",
				color = { (tonumber(rr or "cc", 16) or 204) / 255, (tonumber(gg or "cc", 16) or 204) / 255, (tonumber(bb or "cc", 16) or 204) / 255 },
				item = item, name = name, tip = tip,
			})
		else
			table.insert(gear, { label = label, empty = true })
		end
	end
	return gear
end

function SurvivorUI_ToggleBuild()
	local settings = Settings()
	settings.buildList = not settings.buildList
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.buildList
		and (settings.gameBuildToo and "build list shown, and the Default row of spells stays with it."
			or "build list shown; the Default row of spells is put away.")
		or (settings.noGameBuild and "build list hidden, and the Default row of spells stays away." or "build list hidden; the Default row of spells is back.")))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(list, "Build list", SavePlace, nil, RestorePlace)
end
