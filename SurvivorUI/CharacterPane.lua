-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the character pane, in the manner of EllesmereUI's.
--
-- One flat dark panel: the hero and the item slots on the left, and on the
-- right the run's numbers in titled sections, in place of the stock stat rows
-- and the game's separate "Run Stats" box. The same numbers as a panel of
-- their own on the screen, the Stats panel, further down.
--
-- The numbers are the game's own: its interface keeps them in the global
-- AZS_STATS table, fed by the server. This file only reads that table.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

if not PaperDollFrame or not CharacterFrame then
	return
end

-- Where the stock art sits inside the 384 by 512 character frame.
local ART_LEFT, ART_TOP, ART_WIDTH, ART_HEIGHT = 11, -11, 342, 430
-- The hero's side of the pane, for what sits in its corner (Jewelry.lua).
SurvivorUI_CHARACTER_WIDTH = ART_WIDTH
local STATS_WIDTH = 204
-- The list sizes itself to fit without scrolling: rows shrink as more of them
-- show, between these bounds.
local ROW_MAX, ROW_MIN = 14, 9
local HEADER_HEIGHT = 16

local function Line(parent, r, g, b, a)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(FLAT)
	line:SetVertexColor(r, g, b, a or 1)
	return line
end

------------------------------------------------------------------------------
-- The panel.

local panel = CreateFrame("Frame", "SurvivorUICharacter", PaperDollFrame)
panel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", ART_LEFT, ART_TOP)
panel:SetWidth(ART_WIDTH + STATS_WIDTH)
panel:SetHeight(ART_HEIGHT)
panel:SetFrameLevel(math.max(0, PaperDollFrame:GetFrameLevel() - 1))

local panelEdge = panel:CreateTexture(nil, "BACKGROUND")
panelEdge:SetTexture(FLAT)
panelEdge:SetVertexColor(0, 0, 0, 1)
panelEdge:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, 1)
panelEdge:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, -1)

local panelFill = panel:CreateTexture(nil, "BORDER")
panelFill:SetTexture(FLAT)
panelFill:SetVertexColor(0.05, 0.05, 0.07, 0.96)
panelFill:SetAllPoints(panel)

-- A hairline between the hero and the numbers.
local divider = Line(panel, 1, 1, 1, 0.08)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", panel, "TOPLEFT", ART_WIDTH, -8)
divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ART_WIDTH, 8)

-- The stock stone frame and the round portrait.
do
	local regions = { PaperDollFrame:GetRegions() }
	for index = 1, table.getn(regions) do
		if regions[index]:GetObjectType() == "Texture" then
			regions[index]:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Item slots: square, with a border in the item's quality color.

local SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
	"MainHand", "SecondaryHand", "Ranged", "Ammo",
}

local slotBorders = {}

for _, slotName in pairs(SLOTS) do
	local name = "Character"..slotName.."Slot"
	local slot = getglobal(name)
	if slot then
		local normal = getglobal(name.."NormalTexture")
		if normal then
			normal:SetAlpha(0)
		end
		local icon = getglobal(name.."IconTexture")
		if icon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end

	end

	-- No border for the ammo slot: it is never used here and would read as an
	-- empty square.
	if slot and slotName ~= "Ammo" then
		-- A frame behind the slot, not a texture inside it: that would cover the icon.
		local border = CreateFrame("Frame", nil, panel)
		border:SetPoint("TOPLEFT", slot, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
		border.edge = border:CreateTexture(nil, "BACKGROUND")
		border.edge:SetTexture(FLAT)
		border.edge:SetAllPoints(border)
		border.fill = border:CreateTexture(nil, "BORDER")
		border.fill:SetTexture(FLAT)
		border.fill:SetVertexColor(0.09, 0.09, 0.11, 1)
		border.fill:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
		border.fill:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
		border.slot = slot
		table.insert(slotBorders, border)
	end
end

local function UpdateSlotBorders()
	for index = 1, table.getn(slotBorders) do
		local border = slotBorders[index]
		local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", border.slot:GetID())
		local color = quality and quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if color then
			border.edge:SetVertexColor(color.r, color.g, color.b, 1)
		else
			border.edge:SetVertexColor(0, 0, 0, 1)
		end
	end
end

------------------------------------------------------------------------------
-- The model: no rotate buttons; drag it to turn the hero.

for _, name in pairs({ "CharacterModelFrameRotateLeftButton", "CharacterModelFrameRotateRightButton" }) do
	local button = getglobal(name)
	if button then
		button:Hide()
	end
end

if CharacterModelFrame then
	local model = CharacterModelFrame
	model:EnableMouse(true)
	model:SetScript("OnMouseDown", function()
		this.dragFrom = GetCursorPosition()
	end)
	model:SetScript("OnMouseUp", function()
		this.dragFrom = nil
	end)
	local stockUpdate = model:GetScript("OnUpdate")
	model:SetScript("OnUpdate", function()
		if stockUpdate then
			stockUpdate()
		end
		if this.dragFrom then
			local x = GetCursorPosition()
			this.rotation = (this.rotation or 0) + (x - this.dragFrom) * 0.01
			this.dragFrom = x
			this:SetRotation(this.rotation)
		end
	end)
end

------------------------------------------------------------------------------
-- Tabs: flat, with a gold line under the one that is open.

local tabs = {}
for index = 1, 5 do
	local name = "CharacterFrameTab"..index
	local tab = getglobal(name)
	if tab then
		for _, piece in pairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
			local art = getglobal(name..piece)
			if art then
				art:SetTexture("")
			end
		end
		local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
		if highlight then
			highlight:SetTexture("")
		end

		tab.survivorBack = tab:CreateTexture(nil, "BACKGROUND")
		tab.survivorBack:SetTexture(FLAT)
		tab.survivorBack:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -4)
		tab.survivorBack:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 6)

		tab.survivorMark = tab:CreateTexture(nil, "BORDER")
		tab.survivorMark:SetTexture(FLAT)
		tab.survivorMark:SetVertexColor(1, 0.82, 0, 1)
		tab.survivorMark:SetHeight(2)
		tab.survivorMark:SetPoint("BOTTOMLEFT", tab.survivorBack, "BOTTOMLEFT", 0, 0)
		tab.survivorMark:SetPoint("BOTTOMRIGHT", tab.survivorBack, "BOTTOMRIGHT", 0, 0)

		local text = getglobal(name.."Text")
		if text then
			text:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP)
		end
		table.insert(tabs, tab)
		-- Only the character's own page: skills, honor and the rest are not
		-- part of a run, and a tab alone to the page it is on says nothing.
		-- Every tab kept away, though the stock code shows them again.
		tab:Hide()
		tab.Show = function() end
	end
end

local function UpdateTabs()
	local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(CharacterFrame)
	for index = 1, table.getn(tabs) do
		local tab = tabs[index]
		if tab:GetID() == selected then
			tab.survivorBack:SetVertexColor(0.05, 0.05, 0.07, 0.96)
			tab.survivorMark:Show()
		else
			tab.survivorBack:SetVertexColor(0.03, 0.03, 0.04, 0.85)
			tab.survivorMark:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- The run's numbers.

local function Pct(value)
	return string.format("%+.0f%%", value * 100)
end

-- label, value(s), what it means, and for the conditional rows when to show.
local SECTIONS = {
	{ title = "Offense", color = { 1.00, 0.45, 0.25 }, rows = {
		{ "Crit",     function(s) return string.format("%.1f%%", s.crit * 100) end, "The chance a spell strikes critically. Past 100%, the rest adds to your critical damage." },
		{ "Crit Dmg", function(s) return string.format("%.0f%%", s.cm * 100) end, "A critical strike deals this much of a spell's damage." },
		{ "Damage",   function(s) return Pct(s.dmg - 1) end, "Every spell you cast deals this much more damage. It grows with your level, gear, talents, jewelry and buffs." },
		{ "Haste",    function(s) return Pct(1 - s.cd) end, "Your spells come back this much sooner." },
		{ "Echo",     function(s) return string.format("%.0f%%", s.echo * 100) end, "The chance a spell strikes twice. Past 100%, every spell strikes twice and the rest is the chance of a third." },
	} },
	{ title = "Defense", color = { 0.30, 0.65, 1.00 }, rows = {
		{ "Health",    function(s) return string.format("%.0f", s.hp) end, "The most health you can have." },
		{ "Regen",     function(s) return string.format("%.1f", s.reg) end, "Health you regain every second." },
		{ "Lifesteal", function(s) return string.format("%.1f%%", s.lch * 100) end, "Heals you for this much of all the damage you deal." },
		{ "Armor",     function(s) return string.format("%.0f%%", s.arm * 100) end, "Damage you take is reduced by this much (60% at most)." },
		{ "Kill Heal", function(s) return string.format("%.0f", s.heal) end, "Every kill heals you for this much." },
		{ "Thorns",    function(s) return string.format("%.0f%%", s.thn * 100) end, "This much of the melee damage you take is dealt back to the attacker." },
		{ "Lives",     function(s) return string.format("%d", s.liv) end, "Times you rise again instead of dying." },
	} },
	{ title = "Reach", color = { 0.72, 0.45, 1.00 }, rows = {
		{ "Area",     function(s) return Pct(s.area - 1) end, "Your spells' areas and ranges are this much larger." },
		{ "Targets",  function(s) return string.format("+%d", s.cnt) end, "Every spell that picks its targets picks this many more." },
		{ "Pickup",   function(s) return string.format("%.0f yd", s.pick) end, "Experience and gold fly to you from this far." },
	} },
	{ title = "Utility", color = { 0.35, 0.90, 0.55 }, rows = {
		{ "Speed",      function(s) return Pct(s.spd - 1) end, "You run this much faster." },
		{ "Experience", function(s) return Pct(s.xp - 1) end, "You gain this much more experience." },
		{ "Gold",       function(s) return Pct(s.gold - 1) end, "You find this much more gold." },
		{ "Luck",       function(s) return Pct(s.luck) end, "Better odds of rarer upgrades when you level up." },
		{ "Buff Power", function(s) return Pct(s.bp) end, "Your damage, haste, shield and thorns buffs are this much stronger." },
	} },
	{ title = "Damage over time", color = { 0.25, 0.85, 0.85 }, rows = {
		{ "DoT Stacks", function(s) return string.format("%d", s.dots) end, "How many of each of your damage-over-time effects one enemy carries at once." },
		{ "DoT Haste",  function(s) return Pct(s.doth) end, "Your damage-over-time effects tick this much faster." },
	} },
	{ title = "Bonus damage", color = { 1.00, 0.82, 0.00 }, rows = {
		{ "Vs Elites",     function(s) return Pct(s.big) end,  "More damage to elites and bosses.", "big" },
		{ "Execute",       function(s) return Pct(s.exe) end,  "More damage to enemies below 30% health.", "exe" },
		{ "Vs Controlled", function(s) return Pct(s.cc) end,   "More damage to rooted, stunned, slowed or fleeing enemies.", "cc" },
		{ "Vs Afflicted",  function(s) return Pct(s.dotd) end, "More damage to enemies carrying one of your damage-over-time effects.", "dotd" },
		{ "Shielded",      function(s) return Pct(s.shd) end,  "More damage while you hold an absorb shield.", "shd" },
		{ "Melee",         function(s) return Pct(s.auto) end, "Your melee swings deal this much more damage.", "auto" },
		{ "Pet Damage",    function(s) return Pct(s.pet) end,  "Your pets deal this much more damage.", "pet" },
	} },
}

-- What the gear worn adds to a number, as the game's own pane tells it
-- (AZS_STATS's keys with a g: gdmg, gcrit...), and what the rest gives
-- (level, talents, cards, buffs, race): each as text, the rest nil where it
-- cannot be told apart (the pickup's yards against the gear's share). Of the
-- stats given, the run's now unless told: the last runs keep theirs.
local GEAR = {
	-- label = { gear key, total's key, how the total reads as a bonus, format }
	Health = { "ghp", "hp", nil, "+%.0f" }, Regen = { "greg", "reg", nil, "+%.1f" },
	Targets = { "gcnt", "cnt", nil, "+%d" }, Armor = { "garm", "arm" }, Crit = { "gcrit", "crit" },
	Echo = { "gecho", "echo" }, ["Crit Dmg"] = { "gcm" }, Pickup = { "gpick" },
	Damage = { "gdmg", "dmg", "less1" }, Area = { "garea", "area", "less1" },
	Speed = { "gspd", "spd", "less1" }, Gold = { "ggold", "gold", "less1" }, Haste = { "gcd", "cd", "from1" },
}

local function Share(value)
	local share = value * 100
	return string.format(math.abs(share - math.floor(share + 0.5)) > 0.05 and "%+.1f%%" or "%+.0f%%", share)
end

function SurvivorUI_StatGear(label, stats)
	stats = stats or AZS_STATS
	local gear = GEAR[label]
	local value = gear and stats and tonumber(stats[gear[1]])
	if not value or value == 0 then
		return nil
	end
	local total = gear[2] and tonumber(stats[gear[2]])
	if total and gear[3] == "less1" then
		total = total - 1
	elseif total and gear[3] == "from1" then
		total = 1 - total
	end
	local rest = total and total - value
	if gear[4] then
		return string.format(gear[4], value), rest and rest > 0.001 and string.format(gear[4], rest) or nil
	end
	return Share(value), rest and rest > 0.0001 and Share(rest) or nil
end

-- A missing number reads as 0, so a row the game has not learned yet shows a
-- plain zero instead of breaking the panel.
local function Stats()
	if not AZS_STATS then
		return nil
	end
	return setmetatable({}, { __index = function(_, key) return AZS_STATS[key] or 0 end })
end

------------------------------------------------------------------------------
-- The numbers, in two places that stand on their own: the character pane's
-- right side (on unless switched off: the options, Character pane), and the
-- Stats panel, a panel of its own on the screen all the time (a module, on
-- for a new install from v3.0.12: the options, Stats panel), moved, sized and resized like the
-- other panels. Both can be on at once. Which numbers show, and their order,
-- are the same in both.

local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

-- Up to v3.0.4 the numbers had one place, statsMode: "attached" (in the pane),
-- "detached" (a window of their own, with the pane) or "always" (a panel).
-- The first two keep the pane's numbers; "always" becomes the Stats panel on
-- and the pane's numbers off, as the screen was.
local function Migrate()
	local db = DB()
	if db.statsMode then
		if db.statsMode == "always" then
			db.statsPanel = true
			db.statsInPane = false
		end
		db.statsMode = nil
		db.statsWindowSize = nil
	end
end

local function StatsInPane()
	return DB().statsInPane ~= false
end

local function PanelOn()
	return DB().statsPanel == true
end

------------------------------------------------------------------------------
-- The order: each group, and each number within its group, where the player
-- put it; a number can be switched off for good (the options, Stats panel).
-- Kept per class, as names, in SurvivorUIDB.statsByClass; anything the addon
-- adds later goes at the end of its group.

-- This class's choices: { order, hidden }. The ones kept before v2.9 (for
-- every class at once) become the class of whoever logs in first.
local function ClassStats()
	local db = DB()
	local _, class = UnitClass("player")
	class = class or "UNKNOWN"
	db.statsByClass = db.statsByClass or {}
	local mine = db.statsByClass[class]
	if not mine then
		mine = { order = db.statOrder, hidden = db.statHidden }
		db.statOrder, db.statHidden = nil, nil
		db.statsByClass[class] = mine
	end
	return mine
end

local function Ordered()
	local saved = ClassStats().order or {}
	local sectionOrder = saved.sections or {}
	local byTitle = {}
	for index = 1, table.getn(SECTIONS) do
		byTitle[SECTIONS[index].title] = SECTIONS[index]
	end
	local list, used = {}, {}
	for index = 1, table.getn(sectionOrder) do
		local section = byTitle[sectionOrder[index]]
		if section and not used[section.title] then
			table.insert(list, section)
			used[section.title] = true
		end
	end
	for index = 1, table.getn(SECTIONS) do
		if not used[SECTIONS[index].title] then
			table.insert(list, SECTIONS[index])
		end
	end

	local ordered = {}
	for index = 1, table.getn(list) do
		local section = list[index]
		local rowOrder = (saved.rows or {})[section.title] or {}
		local byLabel = {}
		for each = 1, table.getn(section.rows) do
			byLabel[section.rows[each][1]] = section.rows[each]
		end
		local rowsInOrder, taken = {}, {}
		for each = 1, table.getn(rowOrder) do
			local entry = byLabel[rowOrder[each]]
			if entry and not taken[entry[1]] then
				table.insert(rowsInOrder, entry)
				taken[entry[1]] = true
			end
		end
		for each = 1, table.getn(section.rows) do
			if not taken[section.rows[each][1]] then
				table.insert(rowsInOrder, section.rows[each])
			end
		end
		table.insert(ordered, { title = section.title, color = section.color, rows = rowsInOrder })
	end
	return ordered
end

-- What a class hides unless the player chose otherwise: the damage over time
-- and bonus damage numbers. Each class takes its own copy the first time.
local DEFAULT_HIDDEN = {
	["DoT Stacks"] = true, ["DoT Haste"] = true,
	["Vs Elites"] = true, ["Execute"] = true, ["Vs Controlled"] = true, ["Vs Afflicted"] = true,
	["Shielded"] = true, ["Melee"] = true, ["Pet Damage"] = true,
}

local function HiddenSet()
	local mine = ClassStats()
	if not mine.hidden then
		mine.hidden = {}
		for label in pairs(DEFAULT_HIDDEN) do
			mine.hidden[label] = true
		end
	end
	return mine.hidden
end

local function Hidden(label)
	return HiddenSet()[label]
end

-- Arranging: in move mode, or with Alt held.
local function Arranging()
	return (SurvivorUI_EditMode and SurvivorUI_EditMode()) or IsAltKeyDown()
end

local function SaveOrder(ordered)
	local saved = { sections = {}, rows = {} }
	for index = 1, table.getn(ordered) do
		local section = ordered[index]
		table.insert(saved.sections, section.title)
		saved.rows[section.title] = {}
		for each = 1, table.getn(section.rows) do
			table.insert(saved.rows[section.title], section.rows[each][1])
		end
	end
	ClassStats().order = saved
end

-- For the options: this class back to the first order, with the numbers
-- shown by default (DEFAULT_HIDDEN off).
function SurvivorUI_ResetStatOrder()
	local mine = ClassStats()
	mine.order, mine.hidden = nil, nil
end

-- For the options: every group and its numbers, in the first order.
function SurvivorUI_StatList()
	return SECTIONS
end

function SurvivorUI_StatShown(label)
	return not Hidden(label)
end

function SurvivorUI_SetStatShown(label, shown)
	HiddenSet()[label] = (not shown) or nil
end

------------------------------------------------------------------------------
-- A view of the numbers: its frame, its rows and headers, and the arranging
-- by drag (in move mode or with Alt held). Made twice: in the character pane,
-- and as the Stats panel (`alone`), which wears the panels' look (a light
-- shade, a gold title, slim rows washed in their group's color, as tall as
-- what they hold) and has a place and a size of its own.

local PANEL_WIDTH = 220
local PANEL_ROW = 16
local PANEL_HEADER = 14

local views = {}
local UpdateAll                 -- every view shown drawn again; set below

local function MakeView(alone)
	local view = { alone = alone }
	local stats = CreateFrame("Frame", alone and "SurvivorUIStatsPanel" or "SurvivorUICharacterStats", alone and UIParent or panel)
	view.frame = stats
	stats:SetWidth(alone and PANEL_WIDTH or STATS_WIDTH)
	stats:SetHeight(ART_HEIGHT)

	local headline, headlineCaption, grip
	if alone then
		local fill = stats:CreateTexture(nil, "BORDER")
		fill:SetTexture(FLAT)
		fill:SetVertexColor(0.04, 0.04, 0.07, 0.55)
		fill:SetAllPoints(stats)
		local title = stats:CreateFontString(nil, "OVERLAY")
		title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
		title:SetPoint("TOPLEFT", stats, "TOPLEFT", 8, -9)
		title:SetTextColor(1, 0.82, 0)
		title:SetText("Stats")
		-- The top strip, where the panel is taken to be moved (the rows under
		-- it stay free for arranging).
		grip = CreateFrame("Frame", nil, stats)
		grip:SetPoint("TOPLEFT", stats, "TOPLEFT", 0, 0)
		grip:SetPoint("TOPRIGHT", stats, "TOPRIGHT", 0, 0)
		grip:SetHeight(24)
		stats:SetFrameStrata("MEDIUM")
		stats:SetMovable(true)
		if stats.SetClampedToScreen then
			stats:SetClampedToScreen(true)
		end
	else
		-- The headline: the damage bonus, with the hero's health under it.
		headline = stats:CreateFontString(nil, "OVERLAY")
		headline:SetFont(SurvivorUI_FONT, 20 + FONT_BUMP, "OUTLINE")
		headline:SetPoint("TOP", stats, "TOP", 0, -14)
		headline:SetTextColor(0.72, 0.45, 1)
		headlineCaption = stats:CreateFontString(nil, "OVERLAY")
		headlineCaption:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP)
		headlineCaption:SetPoint("TOP", headline, "BOTTOM", 0, -3)
	end

	local scroll = CreateFrame("ScrollFrame", alone and "SurvivorUIStatsPanelScroll" or "SurvivorUICharacterScroll", stats)
	if alone then
		scroll:SetPoint("TOPLEFT", stats, "TOPLEFT", 4, -28)
		scroll:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -4, 6)
	else
		scroll:SetPoint("TOPLEFT", stats, "TOPLEFT", 12, -54)
		scroll:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -12, 8)
	end
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(STATS_WIDTH - 24)
	content:SetHeight(10)
	scroll:SetScrollChild(content)

	local scrollOffset, scrollRange = 0, 0
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function()
		scrollOffset = math.max(0, math.min(scrollRange, scrollOffset - arg1 * ROW_MAX * 2))
		this:SetVerticalScroll(scrollOffset)
	end)

	-- The panel's size, dragged by its corner: { w, h }, or nil for the first.
	local sizing = false
	local function SavedSize()
		return alone and DB().statsPanelSize or nil
	end

	-- The rows and headers.
	local headers, rows = {}, {}
	local layout = {}               -- what is drawn: { kind, section, label, top, height }
	local dragging                  -- { kind, section, label }
	local UpdateStats

	local function RowEnter()
		if dragging then
			return
		end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.title, 1, 1, 1)
		GameTooltip:AddLine(this.text, 1, 0.82, 0, 1)
		-- Its parts: what the gear worn gives, and the rest.
		local gear, rest = SurvivorUI_StatGear(this.key)
		if gear then
			GameTooltip:AddDoubleLine("Worn gear", gear, 0.12, 1, 0, 0.12, 1, 0)
			if rest then
				GameTooltip:AddDoubleLine("Everything else", rest, 0.62, 0.62, 0.65, 0.85, 0.85, 0.85)
			end
		end
		if Arranging() then
			GameTooltip:AddLine("Drag to move it within its group. Which numbers show: /sui opt, Stats panel.", 0.6, 0.6, 0.65, 1)
		end
		GameTooltip:Show()
	end

	-- Where the cursor stands, in the content's units, from its top.
	local function CursorDepth()
		local _, y = GetCursorPosition()
		return content:GetTop() - y / content:GetEffectiveScale()
	end

	-- The gold line where a dragged piece would land.
	local mark = content:CreateTexture(nil, "OVERLAY")
	mark:SetTexture(FLAT)
	mark:SetVertexColor(1, 0.82, 0, 1)
	mark:SetHeight(2)
	mark:Hide()

	-- Where the dragged piece would go: the index among its kind (rows of its
	-- group, or groups) it would come before, and the depth to draw the mark.
	local function Target()
		local depth = CursorDepth()
		local candidates = {}
		for index = 1, table.getn(layout) do
			local item = layout[index]
			if dragging.kind == "row" and item.kind == "row" and item.section == dragging.section then
				table.insert(candidates, { top = item.top, height = item.height, key = item.label })
			elseif dragging.kind == "section" and item.kind == "header" then
				table.insert(candidates, { top = item.top, height = item.block, key = item.section })
			end
		end
		for index = 1, table.getn(candidates) do
			local c = candidates[index]
			if depth < c.top + c.height / 2 then
				return index, c.top
			end
		end
		local last = candidates[table.getn(candidates)]
		return table.getn(candidates) + 1, last and (last.top + last.height) or 0
	end

	local function Drop()
		local before = Target()
		local ordered = Ordered()
		if dragging.kind == "section" then
			local moving, rest = nil, {}
			for index = 1, table.getn(ordered) do
				if ordered[index].title == dragging.section then
					moving = ordered[index]
				end
			end
			-- The shown groups' order, the dragged one taken out and put back.
			local shownTitles = {}
			for index = 1, table.getn(layout) do
				if layout[index].kind == "header" then
					table.insert(shownTitles, layout[index].section)
				end
			end
			local target = shownTitles[before]
			for index = 1, table.getn(ordered) do
				if ordered[index].title ~= dragging.section then
					if target and ordered[index].title == target then
						table.insert(rest, moving)
					end
					table.insert(rest, ordered[index])
				end
			end
			if not target then
				table.insert(rest, moving)
			end
			ordered = rest
		else
			for index = 1, table.getn(ordered) do
				local section = ordered[index]
				if section.title == dragging.section then
					local shownLabels = {}
					for each = 1, table.getn(layout) do
						local item = layout[each]
						if item.kind == "row" and item.section == section.title then
							table.insert(shownLabels, item.label)
						end
					end
					local target = shownLabels[before]
					local moving, rest = nil, {}
					for each = 1, table.getn(section.rows) do
						if section.rows[each][1] == dragging.label then
							moving = section.rows[each]
						end
					end
					for each = 1, table.getn(section.rows) do
						local entry = section.rows[each]
						if entry[1] ~= dragging.label then
							if target and entry[1] == target then
								table.insert(rest, moving)
							end
							table.insert(rest, entry)
						end
					end
					if not target then
						table.insert(rest, moving)
					end
					section.rows = rest
				end
			end
		end
		SaveOrder(ordered)
	end

	local function StartDrag(kind, frame)
		if not Arranging() then
			return
		end
		dragging = { kind = kind, section = frame.section, label = frame.key }
		frame:SetAlpha(0.4)
		GameTooltip:Hide()
	end

	-- Dropped, the order is the same in both views: both drawn again.
	local function StopDrag(frame)
		if not dragging then
			return
		end
		Drop()
		dragging = nil
		mark:Hide()
		frame:SetAlpha(1)
		UpdateAll()
	end

	local function Header(index)
		local header = headers[index]
		if not header then
			header = CreateFrame("Frame", nil, content)
			header:SetWidth(STATS_WIDTH - 24)
			header:SetHeight(HEADER_HEIGHT)
			header.text = header:CreateFontString(nil, "OVERLAY")
			header.text:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
			header.text:SetPoint("CENTER", header, "CENTER", 0, -2)
			header.left = Line(header, 1, 1, 1)
			header.left:SetHeight(1)
			header.left:SetPoint("LEFT", header, "LEFT", 0, -2)
			header.left:SetPoint("RIGHT", header.text, "LEFT", -6, 0)
			header.right = Line(header, 1, 1, 1)
			header.right:SetHeight(1)
			header.right:SetPoint("RIGHT", header, "RIGHT", 0, -2)
			header.right:SetPoint("LEFT", header.text, "RIGHT", 6, 0)
			header:EnableMouse(true)
			header:RegisterForDrag("LeftButton")
			header:SetScript("OnDragStart", function() StartDrag("section", this) end)
			header:SetScript("OnDragStop", function() StopDrag(this) end)
			header:SetScript("OnEnter", function()
				if Arranging() and not dragging then
					GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
					GameTooltip:SetText(this.section, 1, 1, 1)
					GameTooltip:AddLine("Drag to move the whole group.", 0.6, 0.6, 0.65, 1)
					GameTooltip:Show()
				end
			end)
			header:SetScript("OnLeave", function() GameTooltip:Hide() end)
			headers[index] = header
		end
		return header
	end

	local function Row(index)
		local row = rows[index]
		if not row then
			row = CreateFrame("Button", nil, content)
			row:SetWidth(STATS_WIDTH - 24)
			row:SetHeight(ROW_MAX)
			row:EnableMouse(true)
			row:RegisterForDrag("LeftButton")
			row:SetScript("OnEnter", RowEnter)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
			row:SetScript("OnDragStart", function() StartDrag("row", this) end)
			row:SetScript("OnDragStop", function() StopDrag(this) end)
			row.wash = row:CreateTexture(nil, "BACKGROUND")
			row.wash:SetTexture(FLAT)
			row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
			row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
			row.rule = row:CreateTexture(nil, "BORDER")
			row.rule:SetTexture(FLAT)
			row.rule:SetHeight(1)
			row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
			row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
			row.grip = row:CreateFontString(nil, "OVERLAY")
			row.grip:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP)
			row.grip:SetPoint("LEFT", row, "LEFT", 0, 0)
			row.grip:SetTextColor(1, 0.82, 0)
			row.grip:SetText("::")
			row.label = row:CreateFontString(nil, "OVERLAY")
			row.label:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP)
			row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
			row.label:SetTextColor(0.82, 0.82, 0.82)
			row.value = row:CreateFontString(nil, "OVERLAY")
			row.value:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP)
			row.value:SetPoint("RIGHT", row, "RIGHT", -2, 0)
			rows[index] = row
		end
		return row
	end

	UpdateStats = function()
		local s = Stats()
		local arranging = Arranging()

		if headline then
			if s then
				headline:SetText(Pct(s.dmg - 1))
				headlineCaption:SetText("|cffa0a0a0Damage  \194\183  Health:|r |cff4da6ff"..string.format("%.0f", s.hp).."|r")
			else
				headline:SetText("-")
				headlineCaption:SetText("|cffa0a0a0Start a run to see its numbers|r")
			end
		end

		-- What shows: a group appears once one of its rows does. While arranging,
		-- the hidden rows show too, faint, to bring them back.
		local ordered = Ordered()
		local shown = {}
		local totalRows, totalHeaders = 0, 0
		for index = 1, table.getn(ordered) do
			local visible = {}
			local section = ordered[index]
			for each = 1, table.getn(section.rows) do
				local entry = section.rows[each]
				local relevant = not entry[4] or (s and s[entry[4]] ~= 0)
				if (relevant or arranging) and not Hidden(entry[1]) then
					table.insert(visible, entry)
				end
			end
			shown[index] = visible
			if table.getn(visible) > 0 then
				totalRows = totalRows + table.getn(visible)
				totalHeaders = totalHeaders + 1
			end
		end

		-- Rows as tall as the room allows, and the type to match; in the panel,
		-- slim rows and the panel as tall as they make it, unless sized by the
		-- player: then the rows fill the room it was given, the type with them.
		local headerHeight = alone and PANEL_HEADER or HEADER_HEIGHT
		local frameWidth = alone and stats:GetWidth() or STATS_WIDTH
		local width = frameWidth - (alone and 8 or 24)
		content:SetWidth(width)
		local rowHeight, fontSize
		local sized = alone and (SavedSize() or sizing)
		if alone and not sized then
			rowHeight, fontSize = PANEL_ROW, 10
		else
			local room = scroll:GetHeight() - totalHeaders * headerHeight
			local most = sized and 26 or ROW_MAX
			rowHeight = most
			if totalRows > 0 and room > 0 then
				rowHeight = math.max(ROW_MIN, math.min(most, math.floor(room / totalRows)))
			end
			fontSize = math.max(8, math.min(sized and 15 or 11, rowHeight - 3))
		end
		-- In the pane, the text size set in the options' Character pane tab, on top.
		if not alone then
			fontSize = math.max(6, fontSize + (SurvivorUIDB and tonumber(SurvivorUIDB.paneStatsStep) or 0))
		end

		local y = 0
		local headerCount, rowCount = 0, 0
		layout = {}
		for index = 1, table.getn(ordered) do
			local section = ordered[index]
			local visible = shown[index]

			if table.getn(visible) > 0 then
				local color = section.color
				headerCount = headerCount + 1
				local header = Header(headerCount)
				header:SetWidth(width)
				header:SetHeight(headerHeight)
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
				header.text:SetText(section.title)
				header.text:SetTextColor(color[1], color[2], color[3])
				header.left:SetVertexColor(color[1], color[2], color[3], 0.6)
				header.right:SetVertexColor(color[1], color[2], color[3], 0.6)
				header.section = section.title
				header:Show()
				local headerItem = { kind = "header", section = section.title, top = y, height = headerHeight }
				table.insert(layout, headerItem)
				y = y + headerHeight

				for each = 1, table.getn(visible) do
					local entry = visible[each]
					rowCount = rowCount + 1
					local row = Row(rowCount)
					row:SetWidth(width)
					row:SetHeight(rowHeight)
					local face = fontSize..(alone and "o" or "")
					if row.face ~= face then
						row.face = face
						row.label:SetFont(SurvivorUI_FONT, fontSize + FONT_BUMP, alone and "OUTLINE" or "")
						row.value:SetFont(SurvivorUI_FONT, fontSize + FONT_BUMP, alone and "OUTLINE" or "")
					end
					-- The panel: the row washed in its group's color, label too.
					if alone then
						row.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
						row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
						row.wash:Show()
						row.rule:Show()
						row.label:SetTextColor(color[1], color[2], color[3])
					else
						row.wash:Hide()
						row.rule:Hide()
						row.label:SetTextColor(0.82, 0.82, 0.82)
					end
					local value = s and entry[2](s) or "-"
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
					row.label:SetText(entry[1])
					row.value:SetText(value)
					row.value:SetTextColor(color[1], color[2], color[3])
					row.title = entry[1].." "..value
					row.text = entry[3]
					row.section, row.key = section.title, entry[1]
					-- Arranging: a grip, the label moved off it, hidden rows faint.
					row.label:ClearAllPoints()
					if arranging then
						row.grip:Show()
						row.label:SetPoint("LEFT", row, "LEFT", 12, 0)
					else
						row.grip:Hide()
						row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
					end
					if not (dragging and dragging.label == entry[1]) then
						row:SetAlpha(Hidden(entry[1]) and 0.3 or 1)
					end
					row:Show()
					table.insert(layout, { kind = "row", section = section.title, label = entry[1], top = y, height = rowHeight })
					y = y + rowHeight
				end
				headerItem.block = y - headerItem.top
			end
		end

		for index = headerCount + 1, table.getn(headers) do
			headers[index]:Hide()
		end
		for index = rowCount + 1, table.getn(rows) do
			rows[index]:Hide()
		end

		content:SetHeight(math.max(10, y))
		if alone and not SavedSize() and not sizing then
			stats:SetHeight(28 + math.max(10, y) + 6)
		end
		scrollRange = math.max(0, y - scroll:GetHeight())
		if scrollOffset > scrollRange then
			scrollOffset = scrollRange
			scroll:SetVerticalScroll(scrollOffset)
		end
	end
	view.Update = UpdateStats

	-- The numbers keep themselves current while shown; the mark follows a
	-- drag at once.
	local statsElapsed, wasArranging = 0, nil
	stats:SetScript("OnUpdate", function()
		if dragging then
			local _, top = Target()
			mark:ClearAllPoints()
			mark:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top + 1)
			mark:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -top + 1)
			mark:Show()
		end
		statsElapsed = statsElapsed + arg1
		local arranging = Arranging() and true or false
		if statsElapsed < 0.3 and arranging == wasArranging then
			return
		end
		statsElapsed = 0
		wasArranging = arranging
		if not dragging then
			UpdateStats()
		end
	end)

	if alone then
		-- The panel's place: where it was left, or first right of the character
		-- window; moved by its top strip (Mover.lua), Stats on its card.
		local function SavePlace()
			DB().statsLeft = math.floor(stats:GetLeft() + 0.5)
			DB().statsTop = math.floor(stats:GetTop() + 0.5)
		end

		local function Place()
			stats:ClearAllPoints()
			if DB().statsLeft and DB().statsTop then
				stats:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB().statsLeft, DB().statsTop)
			else
				-- First at the top of the screen, right of This Run.
				stats:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 256, -13)
			end
		end

		-- Its size: the one dragged to, or its first width with the height its
		-- rows make.
		local function Size()
			local size = SavedSize()
			stats:SetWidth(size and size[1] or PANEL_WIDTH)
			if size then
				stats:SetHeight(size[2])
			end
			scrollOffset = 0
			scroll:SetVerticalScroll(0)
		end

		-- Its scale (the options, Stats panel: Size), place and size, shown
		-- while the module is on.
		function view.Apply()
			stats:SetScale(SurvivorUI_PartScale and SurvivorUI_PartScale("stats") or 1)
			Place()
			Size()
			if PanelOn() then
				stats:Show()
				UpdateStats()
			else
				stats:Hide()
			end
		end

		-- The panel takes the size it is dragged to by its bottom right corner:
		-- a grip shows there under the mouse. The rows and their type follow
		-- the room. Right click the grip for the first size again.
		stats:SetResizable(true)
		if stats.SetMinResize then
			stats:SetMinResize(150, 120)
			stats:SetMaxResize(520, 900)
		end
		local corner = CreateFrame("Button", nil, stats)
		corner:SetWidth(16)
		corner:SetHeight(16)
		corner:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -1, 1)
		corner:SetFrameLevel(stats:GetFrameLevel() + 20)
		corner.noHoverOutline = true
		corner:RegisterForClicks("RightButtonUp")
		-- Three gold strokes, a corner's grip, faint until the mouse is on it.
		corner.lines = {}
		for index = 1, 3 do
			local line = corner:CreateTexture(nil, "OVERLAY")
			line:SetTexture(FLAT)
			line:SetVertexColor(1, 0.82, 0, 1)
			line:SetHeight(2)
			line:SetWidth(4 * index + 2)
			line:SetPoint("BOTTOMRIGHT", corner, "BOTTOMRIGHT", 0, (index - 1) * 4)
			table.insert(corner.lines, line)
		end
		corner:SetAlpha(0)
		corner:SetScript("OnEnter", function()
			this:SetAlpha(1)
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText("Drag to resize", 1, 1, 1)
			GameTooltip:AddLine("Right click: the first size again.", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		corner:SetScript("OnLeave", function()
			if not sizing then
				this:SetAlpha(0)
			end
			GameTooltip:Hide()
		end)
		corner:SetScript("OnMouseDown", function()
			if arg1 == "LeftButton" then
				sizing = true
				GameTooltip:Hide()
				stats:StartSizing("BOTTOMRIGHT")
			end
		end)
		corner:SetScript("OnMouseUp", function()
			if not sizing then
				return
			end
			stats:StopMovingOrSizing()
			sizing = false
			DB().statsPanelSize = { math.floor(stats:GetWidth() + 0.5), math.floor(stats:GetHeight() + 0.5) }
			-- Its place kept as it now stands.
			SavePlace()
			this:SetAlpha(MouseIsOver(this) and 1 or 0)
			UpdateStats()
		end)
		corner:SetScript("OnClick", function()
			DB().statsPanelSize = nil
			Size()
			UpdateStats()
		end)
		stats:SetScript("OnSizeChanged", function()
			if sizing then
				UpdateStats()
			end
		end)

		if SurvivorUI_RegisterMover then
			view.handle = SurvivorUI_RegisterMover(grip, "Stats", SavePlace, stats, function()
				DB().statsLeft, DB().statsTop = nil, nil
				Place()
			end)
		end
	else
		-- In the pane: its right side, the pane as wide as both; or off, the
		-- hero and the slots alone.
		function view.Apply()
			if StatsInPane() then
				stats:ClearAllPoints()
				stats:SetPoint("TOPLEFT", panel, "TOPLEFT", ART_WIDTH + 1, 0)
				stats:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
				stats:SetFrameLevel(panel:GetFrameLevel() + 1)
				panel:SetWidth(ART_WIDTH + STATS_WIDTH)
				divider:Show()
				stats:Show()
				scrollOffset = 0
				scroll:SetVerticalScroll(0)
				UpdateStats()
			else
				panel:SetWidth(ART_WIDTH)
				divider:Hide()
				stats:Hide()
			end
		end
	end

	table.insert(views, view)
	return view
end

local paneView = MakeView(false)
local panelView = MakeView(true)

-- The pane's stats' text size, -4 to +8 over what their rows give (the
-- options' Character pane tab; the Stats panel's is its own tab's).
function SurvivorUI_PaneStatsStep()
	return SurvivorUIDB and tonumber(SurvivorUIDB.paneStatsStep) or 0
end

function SurvivorUI_SetPaneStatsStep(step)
	SurvivorUIDB = SurvivorUIDB or {}
	step = math.max(-4, math.min(8, math.floor((tonumber(step) or 0) + 0.5)))
	SurvivorUIDB.paneStatsStep = step ~= 0 and step or nil
	paneView.Apply()
end

UpdateAll = function()
	for index = 1, table.getn(views) do
		if views[index].frame:IsVisible() then
			views[index].Update()
		end
	end
end

------------------------------------------------------------------------------
-- Putting the stock pieces away, and keeping everything current while open.

-- Switched off in the options panel: the stock pane stays, the game's own box
-- with it.
local function Enabled()
	return not SurvivorUI_Feature or SurvivorUI_Feature("characterPane")
end

-- The game's own side box would sit on top of the numbers.
if AZS_UpdateMore then
	local stockUpdateMore = AZS_UpdateMore
	AZS_UpdateMore = function()
		if not Enabled() then
			return stockUpdateMore()
		end
	end
end

local function HideStock()
	for _, name in pairs({ "CharacterAttributesFrame", "CharacterResistanceFrame", "AZSMoreStats", "CharacterFramePortrait" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- For the options: the pane's numbers on or off, the Stats panel on or off,
-- and the panel at its size (Mover.lua).

function SurvivorUI_StatsInPane()
	return StatsInPane()
end

function SurvivorUI_SetStatsInPane(on)
	DB().statsInPane = on and true or false
	if panel:IsVisible() then
		paneView.Apply()
	end
end

function SurvivorUI_StatsPanel()
	return PanelOn()
end

-- Switched, or set to `on`.
function SurvivorUI_ToggleStatsPanel(on)
	if on == nil then
		on = not PanelOn()
	end
	DB().statsPanel = on and true or false
	panelView.Apply()
end

function SurvivorUI_StatsScale()
	panelView.Apply()
end

local closeButton = getglobal("CharacterFrameCloseButton")

------------------------------------------------------------------------------
-- The pane's place: where it was dragged to, its tab open or in move mode
-- (Mover.lua; its card has the numbers), kept as its top left corner; else
-- where the game seats it. The game seats it again each time it opens, so a
-- saved place is put back as it shows, and once more on the next tick.

local stockPlace                -- where the game seated it, for Reset
local placePending

local function SavePanePlace()
	DB().characterLeft = math.floor(CharacterFrame:GetLeft() + 0.5)
	DB().characterTop = math.floor(CharacterFrame:GetTop() + 0.5)
end

local function PlacePane()
	local db = DB()
	if db.characterLeft and db.characterTop then
		CharacterFrame:ClearAllPoints()
		CharacterFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.characterLeft, db.characterTop)
	elseif not stockPlace and CharacterFrame:GetLeft() then
		stockPlace = { CharacterFrame:GetLeft(), CharacterFrame:GetTop() }
	end
end

local function DefaultPanePlace()
	DB().characterLeft, DB().characterTop = nil, nil
	if stockPlace then
		CharacterFrame:ClearAllPoints()
		CharacterFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", stockPlace[1], stockPlace[2])
	end
end

CharacterFrame:SetMovable(true)
if CharacterFrame.SetClampedToScreen then
	CharacterFrame:SetClampedToScreen(true)
end
if SurvivorUI_RegisterMover then
	local paneHandle = SurvivorUI_RegisterMover(panel, "Character pane", SavePanePlace, CharacterFrame, DefaultPanePlace)
	-- With the pane: shown and hidden with it, over it.
	paneHandle:SetParent(panel)
	paneHandle:SetFrameStrata("DIALOG")
end

-- The hero's class color: on the name and level line, and the pane's edge.
local function PaintClass()
	local _, class = UnitClass("player")
	local r, g, b = 1, 0.82, 0
	if SurvivorUI_ClassColor then
		r, g, b = SurvivorUI_ClassColor(class)
	end
	for _, name in pairs({ "CharacterNameText", "CharacterLevelText", "CharacterTitleText" }) do
		local text = getglobal(name)
		if text then
			text:SetTextColor(r, g, b)
		end
	end
	panelEdge:SetVertexColor(r, g, b, 1)
end

panel:SetScript("OnShow", function()
	if not Enabled() then
		this:Hide()
		return
	end
	PaintClass()
	HideStock()
	UpdateSlotBorders()
	UpdateTabs()
	paneView.Apply()
	PlacePane()
	placePending = true
	if closeButton then
		closeButton:ClearAllPoints()
		closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 4, 4)
	end
end)

-- The other tabs keep the stock frame, portrait and close button.
panel:SetScript("OnHide", function()
	local portrait = getglobal("CharacterFramePortrait")
	if portrait then
		portrait:Show()
	end
	if closeButton then
		closeButton:ClearAllPoints()
		closeButton:SetPoint("CENTER", CharacterFrame, "TOPRIGHT", -44, -25)
	end
end)

local elapsed = 0
panel:SetScript("OnUpdate", function()
	if placePending then
		placePending = nil
		PlacePane()
	end
	elapsed = elapsed + arg1
	if elapsed < 0.3 then
		return
	end
	elapsed = 0
	HideStock()
	UpdateSlotBorders()
end)

-- The character window in front of the panels that stay on the screen (the
-- Stats panel, the meter, the collection on its own).
CharacterFrame:SetFrameStrata("HIGH")

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	Migrate()
	panelView.Apply()
end)

-- The Stats panel comes back by itself: the game puts frames away as a match
-- closes and another starts, and nothing else would show it again.
local keeper = CreateFrame("Frame")
local keepElapsed = 0
keeper:SetScript("OnUpdate", function()
	keepElapsed = keepElapsed + arg1
	if keepElapsed < 0.5 then
		return
	end
	keepElapsed = 0
	if SurvivorUIDB and PanelOn() and not panelView.frame:IsShown() then
		panelView.Apply()
	end
end)

-- The tabs belong to the whole character window, whichever page is open.
local tabWatcher = CreateFrame("Frame", nil, CharacterFrame)
local tabElapsed = 0
tabWatcher:SetScript("OnUpdate", function()
	tabElapsed = tabElapsed + arg1
	if tabElapsed >= 0.1 then
		tabElapsed = 0
		UpdateTabs()
	end
end)
