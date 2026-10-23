-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the damage meter.
--
-- The game's own meter, drawn again from the numbers it shares (its addon API,
-- AZS_GetMeter): one flat bar per source of damage, the most first, each in a
-- color of its own, a talent's or amulet's own damage tagged as a proc. Hover a line for its card: its damage, share and damage per second,
-- and its critical strikes and normal hits from the combat log. The title's
-- menu switches to the run's healing (AZS_GetHealing) or the last boss fight's damage
-- to bosses (AZS_GetBossMeter), in the same bars; in a co-op run (the game's
-- 0.113), to the party's damage (AZS_GetPartyMeter), a bar a hero in the
-- class's color, its top spell on hover.
--
-- Reset starts the meter over from that moment and clears the crits; the run
-- panel keeps the whole run. Its
-- size holds through a run: up to ten lines, fewer on a small screen. Hold Alt
-- and drag to move. The game's own meter is put away while this one is on;
-- /sui meter brings it back. Needs the API; without it nothing shows.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 228
local BAR_HEIGHT = 18           -- as the build list's rows
local BAR_GAP = 2
local MAX_LINES = 10
-- The bars start under the title and the strip of numbers (total, dps, now).
local STRIP_TOP, STRIP_HEIGHT = 20, 14
local BARS_TOP = STRIP_TOP + STRIP_HEIGHT + 2

-- One color per source, handed out in the order they first show: twelve hues
-- spread around the wheel, each next one far from the last, so neighbours in
-- the meter never look alike. A proc gets one too; its tag says it is a proc.
local PALETTE = {
	{ 0.93, 0.70, 0.15 }, -- gold
	{ 0.85, 0.20, 0.25 }, -- crimson
	{ 0.25, 0.45, 0.95 }, -- royal blue
	{ 0.30, 0.75, 0.30 }, -- green
	{ 0.65, 0.35, 0.90 }, -- purple
	{ 0.95, 0.50, 0.10 }, -- orange
	{ 0.15, 0.70, 0.70 }, -- teal
	{ 0.95, 0.40, 0.70 }, -- pink
	{ 0.65, 0.85, 0.20 }, -- lime
	{ 0.60, 0.40, 0.25 }, -- brown
	{ 0.45, 0.75, 1.00 }, -- sky
	{ 0.55, 0.55, 0.70 }, -- slate
}
local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.meter == nil then
		SurvivorUIDB.meter = true
	end
	return SurvivorUIDB
end

local function Num(value)
	return tonumber(value) or 0
end

-- 950, 1.2k, 3.4m
-- A big number as the whole addon writes it (SurvivorUI_Abbrev): 4.9k, 1.11M, 9.27B.
local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function Running()
	if not (AZS_GetPhase and AZS_GetMeter) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

-- On, and the game sharing its meter: the run panel asks, to leave its crit
-- list out.
function SurvivorUI_MeterActive()
	return Settings().meter and AZS_GetMeter ~= nil
end

------------------------------------------------------------------------------
-- The frame: a title line, then room for every bar from the start, so its size
-- holds through a run. At the bottom of the right column, under the run panel.

local meter = CreateFrame("Frame", "SurvivorUIMeter", UIParent)
meter:SetWidth(WIDTH + 8)
meter:SetHeight(BARS_TOP + 4 + MAX_LINES * (BAR_HEIGHT + BAR_GAP))
meter:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
meter:SetBackdrop({ bgFile = FLAT })
-- The right column's one shade, as the tracker and the run panel wear it.
meter:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
meter:SetMovable(true)
meter:EnableMouse(true)
meter:RegisterForDrag("LeftButton")
meter:Hide()

local function SavePlace()
	local settings = Settings()
	settings.meterRight = math.floor(meter:GetRight() + 0.5)
	settings.meterBottom = math.floor(meter:GetBottom() + 0.5)
end

local shownLines = MAX_LINES

local function SetLines(count)
	if count ~= shownLines then
		shownLines = count
		meter:SetHeight(BARS_TOP + 4 + count * (BAR_HEIGHT + BAR_GAP))
	end
end

-- The saved place, with every line; else the right column, under the build
-- list (or the run tracker), with as many lines as fit above the screen's bottom,
-- three at least. A small screen gets a shorter meter rather than an overlap.
-- The size follows the layout, never the numbers, so it holds through a run.
-- What the meter hangs from, last time: it is seated again only when that
-- changes, so a drag in progress is never pulled back.
local seatedOn

local function Seat(key, point, relative, relativePoint, x, y)
	if seatedOn ~= key then
		seatedOn = key
		meter:ClearAllPoints()
		meter:SetPoint(point, relative, relativePoint, x, y)
	end
end

local function Fit()
	local settings = Settings()
	if settings.meterRight then
		Seat("saved"..settings.meterRight..","..settings.meterBottom, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", settings.meterRight, settings.meterBottom)
		SetLines(MAX_LINES)
		return
	end
	local build, tracker = SurvivorUIBuild, SurvivorUITracker
	local above, shift = nil, 0
	if build and build:IsShown() and build:GetBottom() then
		above = build
	elseif tracker and tracker:GetBottom() then
		above, shift = tracker, 8
	end
	if not above then
		Seat("screen", "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
		SetLines(MAX_LINES)
		return
	end
	Seat(above:GetName(), "TOPRIGHT", above, "BOTTOMRIGHT", shift, -10)
	-- The piece above has a size of its own: its bottom read in the meter's units.
	local room = above:GetBottom() * above:GetEffectiveScale() / meter:GetEffectiveScale() - 10 - 8
	local fit = math.floor((room - BARS_TOP - 4) / (BAR_HEIGHT + BAR_GAP))
	SetLines(math.max(3, math.min(MAX_LINES, fit)))
end

local function StartMove()
	if IsAltKeyDown() then
		meter:StartMoving()
	end
end

local function StopMove()
	meter:StopMovingOrSizing()
	SavePlace()
end

meter:SetScript("OnDragStart", StartMove)
meter:SetScript("OnDragStop", StopMove)

-- What the meter shows: the run's damage, its healing, or the last boss
-- fight's damage to bosses. The title opens a menu of them; a view the game
-- does not share (an older game) is greyed out there.
local VIEWS = {
	{ key = "damage", title = "Damage Done", get = function() return AZS_GetMeter end },
	{ key = "healing", title = "Healing Done", get = function() return AZS_GetHealing end },
	{ key = "boss", title = "Boss Damage", get = function() return AZS_GetBossMeter end },
	-- A co-op run's: each hero's damage. Greyed out of a party.
	{ key = "party", title = "Party Damage", get = function()
		if AZS_GetPartyMeter and AZS_PARTY and table.getn(AZS_PARTY) > 0 then
			return AZS_GetPartyMeter
		end
	end },
}
local view = 1

local GOLD = { 1, 0.82, 0 }

-- The title: a button with the view's name and a small caret, lit under the
-- mouse with a soft gold wash, no outline.
local titleButton = CreateFrame("Button", nil, meter)
titleButton:SetPoint("TOPLEFT", meter, "TOPLEFT", 2, -2)
titleButton:SetHeight(17)
titleButton.noHoverOutline = true

titleButton.wash = titleButton:CreateTexture(nil, "BACKGROUND")
titleButton.wash:SetTexture(FLAT)
titleButton.wash:SetAllPoints(titleButton)
titleButton.wash:SetVertexColor(1, 0.82, 0, 0)

meter.title = titleButton:CreateFontString(nil, "OVERLAY")
meter.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
meter.title:SetPoint("LEFT", titleButton, "LEFT", 3, 0)
meter.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
meter.title:SetText("Damage Done")

-- The caret: three flat lines, five, three and one pixel wide, a small
-- triangle pointing down.
titleButton.caret = {}
for row = 1, 3 do
	local line = titleButton:CreateTexture(nil, "OVERLAY")
	line:SetTexture(FLAT)
	line:SetHeight(1)
	line:SetWidth(7 - 2 * row)
	table.insert(titleButton.caret, line)
end

local function TintCaret(r, g, b, a)
	for row = 1, 3 do
		titleButton.caret[row]:SetVertexColor(r, g, b, a)
	end
end

-- The button hugs the title and the caret beside it.
local function FitTitle()
	local width = meter.title:GetStringWidth()
	for row = 1, 3 do
		local line = titleButton.caret[row]
		line:ClearAllPoints()
		line:SetPoint("TOP", titleButton, "TOPLEFT", 3 + width + 7, -7 - row)
	end
	titleButton:SetWidth(width + 16)
end

local menu = CreateFrame("Frame", "SurvivorUIMeterViews", meter)
menu:SetFrameStrata("DIALOG")
menu:SetWidth(120)
menu:SetHeight(6 + table.getn(VIEWS) * 18)
menu:SetPoint("TOPLEFT", titleButton, "BOTTOMLEFT", 0, -2)
menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
menu:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
menu:SetBackdropBorderColor(1, 0.82, 0, 0.35)
menu:EnableMouse(true)
menu.noHoverOutline = true
menu:Hide()

local function Lit(on)
	if on or menu:IsShown() then
		titleButton.wash:SetVertexColor(1, 0.82, 0, 0.14)
		meter.title:SetTextColor(1, 0.92, 0.5)
		TintCaret(1, 0.92, 0.5, 1)
	else
		titleButton.wash:SetVertexColor(1, 0.82, 0, 0)
		meter.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		TintCaret(0.6, 0.6, 0.6, 0.9)
	end
end

-- passing: shown for now, the choice kept (a view gone for a while).
local function SetView(index, passing)
	view = index
	meter.scrolled = 0
	if not passing then
		Settings().meterView = VIEWS[index].key
	end
	meter.title:SetText(VIEWS[index].title)
	FitTitle()
end

-- One row a view: the one shown in gold with a gold mark at its left, one the
-- game does not share greyed, the one under the mouse on a soft wash.
menu.rows = {}
local function PaintRows()
	for index = 1, table.getn(VIEWS) do
		local row = menu.rows[index]
		local shared = VIEWS[index].get() ~= nil
		row.mark:SetAlpha(index == view and 1 or 0)
		row.wash:SetVertexColor(1, 1, 1, (row.hot and shared) and 0.08 or 0)
		if not shared then
			row.text:SetTextColor(0.35, 0.35, 0.38)
		elseif index == view then
			row.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		elseif row.hot then
			row.text:SetTextColor(1, 1, 1)
		else
			row.text:SetTextColor(0.75, 0.75, 0.78)
		end
	end
end

for index = 1, table.getn(VIEWS) do
	local row = CreateFrame("Button", nil, menu)
	row:SetHeight(18)
	row:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - (index - 1) * 18)
	row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -3 - (index - 1) * 18)
	row.noHoverOutline = true
	row.index = index

	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(FLAT)
	row.wash:SetAllPoints(row)

	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetTexture(FLAT)
	row.mark:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	row.mark:SetWidth(2)
	row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
	row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)

	row.text = row:CreateFontString(nil, "OVERLAY")
	row.text:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.text:SetText(VIEWS[index].title)

	row:SetScript("OnEnter", function()
		this.hot = true
		PaintRows()
	end)
	row:SetScript("OnLeave", function()
		this.hot = nil
		PaintRows()
	end)
	row:SetScript("OnClick", function()
		if VIEWS[this.index].get() then
			SetView(this.index)
			menu:Hide()
			Lit(false)
		end
	end)
	menu.rows[index] = row
end

-- The menu closes once the mouse has been off it and the title a moment.
menu.away = 0
menu:SetScript("OnShow", function()
	this.away = 0
	PaintRows()
end)
menu:SetScript("OnUpdate", function()
	if MouseIsOver(this) or MouseIsOver(titleButton) then
		this.away = 0
	else
		this.away = this.away + arg1
		if this.away > 0.6 then
			this:Hide()
			Lit(false)
		end
	end
end)

-- A view by its key ("damage", "healing", "boss", "party"), as its row in
-- the title's menu: true if the game shares it now.
function SurvivorUI_SetMeterView(key)
	for index = 1, table.getn(VIEWS) do
		if VIEWS[index].key == key and VIEWS[index].get() then
			SetView(index)
			return true
		end
	end
	return false
end

titleButton:SetScript("OnEnter", function() Lit(true) end)
titleButton:SetScript("OnLeave", function() Lit(false) end)
titleButton:SetScript("OnClick", function()
	if menu:IsShown() then
		menu:Hide()
	else
		menu:Show()
	end
	Lit(true)
end)
titleButton:RegisterForDrag("LeftButton")
titleButton:SetScript("OnDragStart", StartMove)
titleButton:SetScript("OnDragStop", StopMove)
FitTitle()
Lit(false)
-- Under the title, the numbers, each named, in cells across the meter: NOW a
-- second over the last few seconds (the options, Damage meter), green while
-- above the average, orange while below; DPS that a second on average; and
-- TOTAL the view's whole. Hover them for what each is.
local WHITE = { 1, 1, 1 }
local NOW_UP = { 0.45, 0.95, 0.5 }
local NOW_DOWN = { 1, 0.6, 0.3 }

local function NowOn()
	return Settings().meterNow ~= false
end

-- The seconds of the run's clock "now" is measured over.
local NOW_WINDOW = 5

local strip = CreateFrame("Frame", nil, meter)
strip:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -STRIP_TOP)
strip:SetWidth(WIDTH)
strip:SetHeight(STRIP_HEIGHT)
strip:EnableMouse(true)
strip:RegisterForDrag("LeftButton")
strip:SetScript("OnDragStart", StartMove)
strip:SetScript("OnDragStop", StopMove)
strip.wash = strip:CreateTexture(nil, "BACKGROUND")
strip.wash:SetTexture(FLAT)
strip.wash:SetAllPoints(strip)
strip.wash:SetVertexColor(1, 1, 1, 0.04)

local function Cell()
	local cell = {}
	cell.label = strip:CreateFontString(nil, "OVERLAY")
	cell.label:SetFont(SurvivorUI_FONT, 7 + FONT_BUMP, "OUTLINE")
	cell.label:SetTextColor(0.58, 0.58, 0.64)
	cell.value = strip:CreateFontString(nil, "OVERLAY")
	cell.value:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	cell.value:SetPoint("LEFT", cell.label, "RIGHT", 4, 0)
	return cell
end
strip.cells = { Cell(), Cell(), Cell() }

-- Each cell in its share of the width; three with NOW, two without.
local function LayCells(count)
	if strip.count == count then
		return
	end
	strip.count = count
	local each = WIDTH / count
	for index = 1, 3 do
		local cell = strip.cells[index]
		cell.label:ClearAllPoints()
		if index <= count then
			cell.label:SetPoint("LEFT", strip, "LEFT", (index - 1) * each + 6, 0)
			cell.label:Show()
			cell.value:Show()
		else
			cell.label:Hide()
			cell.value:Hide()
		end
	end
end

local function SetCell(index, label, value, color)
	local cell = strip.cells[index]
	cell.label:SetText(label)
	cell.value:SetText(value)
	cell.value:SetTextColor(color[1], color[2], color[3])
end

strip:SetScript("OnEnter", function()
	local healing = this.view == "healing"
	local what = healing and "healing" or "damage"
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	local titles = { healing = "Healing Done", boss = "Boss Damage", party = "Party Damage" }
	GameTooltip:SetText(titles[this.view] or "Damage Done", 1, 0.82, 0)
	if NowOn() then
		GameTooltip:AddDoubleLine("NOW", "a second over the last "..NOW_WINDOW.." seconds", NOW_UP[1], NOW_UP[2], NOW_UP[3], 0.8, 0.8, 0.8)
	end
	GameTooltip:AddDoubleLine(healing and "HPS" or "DPS", "a second on average", GOLD[1], GOLD[2], GOLD[3], 0.8, 0.8, 0.8)
	local whose = (this.view == "boss" and "last boss fight's") or (this.view == "party" and "party's") or "run's"
	GameTooltip:AddDoubleLine("TOTAL", "the "..whose.." "..what..(this.view == "damage" and ", since Reset" or ""), 1, 1, 1, 0.8, 0.8, 0.8)
	if NowOn() then
		GameTooltip:AddLine("NOW is green while above the average, orange while below.", 0.6, 0.6, 0.65, 1)
	end
	GameTooltip:Show()
end)
strip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- A view with nothing in it yet says so.
meter.empty = meter:CreateFontString(nil, "OVERLAY")
meter.empty:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
meter.empty:SetPoint("TOPLEFT", meter, "TOPLEFT", 8, -BARS_TOP - 2)
meter.empty:SetTextColor(0.55, 0.55, 0.6)
meter.empty:Hide()

local reset = CreateFrame("Button", nil, meter)
reset:SetWidth(32)
reset:SetHeight(12)
reset:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -5, -5)
reset.text = reset:CreateFontString(nil, "OVERLAY")
reset.text:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
reset.text:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
reset.text:SetText("Reset")
reset.text:SetTextColor(0.6, 0.6, 0.6)
reset:SetScript("OnEnter", function()
	this.text:SetTextColor(1, 1, 1)
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText("Starts the meter over from now.", 1, 1, 1)
	GameTooltip:AddLine("Damage, damage per second and shares count from here, and the crits are cleared. The run panel keeps the whole run's numbers.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)
------------------------------------------------------------------------------
-- Reset: the game's numbers cover the whole run, so the meter keeps what each
-- source stood at when Reset was pressed, and shows what came after.

local base = nil                -- { at = run second, total = damage, [source] = damage }
local lastSeconds

local function RunSeconds()
	return (AZS_GetRunTime and AZS_GetRunTime()) or 0
end

-- The damage (or healing) a second right now: the view's total as it climbs
-- over the last NOW_WINDOW seconds of the run's clock, as the game's own
-- meter has it beside the run's rate. Paused or choosing a card, the clock
-- stands still and so does it; the clock going back, or the total (Reset),
-- starts it over.
local recent = {}               -- [view key] = { { at = run second, total }, ... }

local function NowRate(key, total)
	local list = recent[key] or {}
	recent[key] = list
	local at = RunSeconds()
	local last = list[table.getn(list)]
	if last and (at < last.at or total < last.total) then
		list = {}
		recent[key] = list
		last = nil
	end
	if not last or at > last.at then
		table.insert(list, { at = at, total = total })
	end
	while table.getn(list) > 1 and list[1].at < at - NOW_WINDOW do
		table.remove(list, 1)
	end
	local span = at - list[1].at
	if span < 1 then
		return nil
	end
	return (total - list[1].total) / span
end

local function TakeBase()
	local lines, total = AZS_GetMeter()
	base = { at = RunSeconds(), total = Num(total), sources = {} }
	for index = 1, table.getn(lines or {}) do
		base.sources[lines[index].name or "?"] = Num(lines[index].dmg)
	end
end

reset:SetScript("OnClick", function()
	TakeBase()
	if SurvivorUI_ResetRun then
		SurvivorUI_ResetRun()
	end
end)

------------------------------------------------------------------------------
-- The bars.

-- A name or bonus line in English, whatever language the game is in
-- (Locale.lua). The combat log still writes "Soul Fire", the 1.12 spell's
-- name, where the game's meter, cards and tooltips spell it "Soulfire" since
-- its 0.110: one source, under the game's spelling.
local SPELLINGS = { ["Soul Fire"] = "Soulfire" }

local function English(name)
	name = SurvivorUI_English and SurvivorUI_English(name) or name
	return SPELLINGS[name] or name
end

local colors = {}               -- [source] = palette entry
local colorsGiven = 0
local bars = {}

-- The pets and the summoned, by their own name in the meter: the game's
-- summoning icons (its data has them all but the Felguard's, which came
-- later in WoW). Looked at before the worn items, whose names an "Imp"
-- could be found in.
local PETS = {
	["Imp"] = "Spell_Shadow_SummonImp",
	["Succubus"] = "Spell_Shadow_SummonSuccubus",
	["Voidwalker"] = "Spell_Shadow_SummonVoidWalker",
	["Felhunter"] = "Spell_Shadow_SummonFelHunter",
	["Felguard"] = "Spell_Shadow_Metamorphosis",
	["Infernal"] = "Spell_Shadow_SummonInfernal",
	["Doomguard"] = "Spell_Shadow_AntiMagicShell",
	["Pit Lord"] = "Spell_Shadow_RitualOfSacrifice",
	["Felseeker"] = "Spell_Fire_SoulBurn",        -- the Pit Lord's Searing Pain
	["Water Elemental"] = "Spell_Frost_SummonWaterElemental",
	["Spirit Wolf"] = "Spell_Nature_SpiritWolf",
	["Treant"] = "Spell_Nature_ForceOfNature",
	["Wolf"] = "Ability_Hunter_Pet_Wolf",
	["Raptor"] = "Ability_Hunter_Pet_Raptor",
}

-- What pets cast that the hero may not have, so no button or spellbook shows
-- it: the Imp's Fireball, the Infernal's fall from the sky (Inferno: a great
-- fireball, a meteor; not the Infernal's own icon, so its row and the
-- Infernal's blows' tell apart, nor Rain of Fire's, a warlock's own spell).
local PET_SPELLS = {
	["Fireball"] = "Spell_Fire_FlameBolt",
	["Firebolt"] = "Spell_Fire_FireBolt",
	["Inferno"] = "Spell_Fire_Fireball02",
}

-- A pet's own spell as Biggest Crits names it, "Imp's Fireball": its pet
-- and its spell; nil for anything else ("Magma Totem's Magma Totem").
local function PetSpell(name)
	local _, _, owner, spell = string.find(name or "", "^(.-)'s (.+)$")
	if owner and PETS[owner] then
		return owner, spell
	end
end

-- True for a pet's or a summon's name (Biggest Crits keeps it before its spell).
function SurvivorUI_IsPet(name)
	return PETS[English(name)] ~= nil
end

local function ColorOf(name)
	name = English(name)
	-- A pet's spell in the pet's color, as its bar in the meter.
	name = PetSpell(name) or name
	if not colors[name] then
		colorsGiven = colorsGiven + 1
		colors[name] = PALETTE[math.mod(colorsGiven - 1, table.getn(PALETTE)) + 1]
	end
	return colors[name]
end

-- A spell's rank, from the game's list (AZS_SPELLS names it by key: "holy_wrath"
-- for "Holy Wrath"): 12 in the meter, or XII (SurvivorUI_RankText).
local SPELL_KEYS = {
	["shadow word: pain"] = "sw_pain", ["power word: shield"] = "pw_shield",
	["demoralizing shout"] = "demo_shout", ["hunter's mark"] = "hunters_mark",
}

-- A source's icon. A spell of the build: its action button's (the game puts
-- them on buttons 1 to 6, the racial on the last, until one is dragged
-- elsewhere: SurvivorUI_SpellSlot). Anything else, a talent's or
-- an item's own damage: the spellbook, the talents, then the worn items, by
-- name. Found icons are kept; a miss is asked again now and then, as talents
-- and items come during a run.
local OWN_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local icons = {}                -- [name] = texture
local missedAt = {}             -- [name] = GetTime() of the last miss

-- A burst that goes off under a name of its own (the game's 0.98): the icon
-- of the spell it comes from, whichever of them the hero has.
local BORROWED = {
	["Corpse Explosion"] = { "Seed of Corruption", "Shadowform" },
	["Noxious Cloud"] = { "Toxic Bloom" },
}

local function SpellIndex(name)
	if not AZS_SPELLS then
		return nil
	end
	local lower = string.lower(name)
	local key = SPELL_KEYS[lower] or string.gsub(string.gsub(lower, "[^%a ]", ""), " ", "_")
	local count = table.getn(AZS_SPELLS)
	for index = 1, count do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == key then
			return index, index == count
		end
	end
	-- By the letters alone: a button's tooltip calls soul_fire "Soulfire".
	local letters = string.gsub(lower, "[^%a]", "")
	for index = 1, count do
		local entry = AZS_SPELLS[index]
		if string.gsub(tostring(entry.key or entry[1]), "[^%a]", "") == letters then
			return index, index == count
		end
	end
end

local function FromSpellbook(name)
	if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName and GetSpellTexture) then
		return nil
	end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
			if GetSpellName(index, "spell") == name then
				return GetSpellTexture(index, "spell")
			end
		end
	end
end

local function FromTalents(name)
	if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then
		return nil
	end
	for tab = 1, GetNumTalentTabs() do
		for index = 1, GetNumTalents(tab) do
			local talent, texture = GetTalentInfo(tab, index)
			if talent == name then
				return texture
			end
		end
	end
end

-- A worn piece whose name the source's starts with ("Eye of the Splitting Sky:
-- Exorcism" is the amulet's) or is.
local function FromItems(name)
	if not (GetInventoryItemLink and GetInventoryItemTexture) then
		return nil
	end
	local lower = string.lower(name)
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		local _, _, item = string.find(link or "", "%[(.-)%]")
		if item and item ~= "" then
			local itemLower = string.lower(item)
			if lower == itemLower or string.find(lower, itemLower, 1, true) == 1 or string.find(itemLower, lower, 1, true) then
				return GetInventoryItemTexture("player", slot)
			end
		end
	end
end

-- The white damage: a swing shows the weapon in hand, a shot the ranged one
-- (a bow, a gun, a wand). Read each time: the weapon can change in a run.
local MELEE = { ["Melee"] = true, ["Attack"] = true, ["Auto Attack"] = true }
local RANGED = { ["Auto Shot"] = true, ["Shoot"] = true, ["Shot"] = true, ["Auto Shoot"] = true }

local function WeaponIcon(name)
	if not GetInventoryItemTexture then
		return nil
	end
	if MELEE[name] then
		return GetInventoryItemTexture("player", 16)
	elseif RANGED[name] then
		return GetInventoryItemTexture("player", 18) or GetInventoryItemTexture("player", 16)
	end
end

local function IconOf(name)
	name = English(name)
	local weapon = WeaponIcon(name)
	if weapon then
		return weapon
	end
	if PETS[name] then
		return "Interface\\Icons\\"..PETS[name]
	end
	-- "Imp's Fireball": the spell's icon, else its pet's.
	local pet, spell = PetSpell(name)
	if pet then
		return IconOf(spell) or "Interface\\Icons\\"..PETS[pet]
	end
	-- A spell of the build: its button's icon, read each time (cheap), never
	-- kept: a reading in a wrong instant would stay the whole run.
	local index = SpellIndex(name)
	local texture = index and GetActionTexture and GetActionTexture(SurvivorUI_SpellSlot(index))
	if texture then
		return texture
	end
	if icons[name] then
		return icons[name]
	end
	if not texture then
		if missedAt[name] and GetTime() - missedAt[name] < 10 then
			return nil
		end
		texture = FromSpellbook(name) or FromTalents(name) or FromItems(name)
	end
	if not texture and BORROWED[name] then
		for _, source in pairs(BORROWED[name]) do
			texture = texture or IconOf(source)
		end
	end
	if not texture and PET_SPELLS[name] then
		texture = "Interface\\Icons\\"..PET_SPELLS[name]
	end
	if texture then
		icons[name] = texture
	else
		missedAt[name] = GetTime()
	end
	return texture
end

local function RankOf(name)
	if not (name and AZS_SPELLS) then
		return nil
	end
	name = English(name)
	local lower = string.lower(name)
	local key = SPELL_KEYS[lower] or string.gsub(string.gsub(lower, "[^%a ]", ""), " ", "_")
	for index = 1, table.getn(AZS_SPELLS) do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == key then
			return tonumber(entry.rank or entry[3])
		end
	end
end

local ROMAN = { { 50, "L" }, { 40, "XL" }, { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } }

local function Roman(number)
	local text = ""
	for index = 1, table.getn(ROMAN) do
		local value, letters = ROMAN[index][1], ROMAN[index][2]
		while number >= value do
			text = text..letters
			number = number - value
		end
	end
	return text
end

-- A source's rank as the meter shows it after the name, and a number in Roman
-- numerals (the last runs, RunHistory.lua).
function SurvivorUI_MeterRank(name)
	return RankOf(name)
end

function SurvivorUI_Roman(number)
	return Roman(tonumber(number) or 0)
end

-- A spell's rank as the tooltips show it, "Rank 63", or as the meter does
-- after a name (bare), "Fireball  63"; LXIII in both with the Roman ranks on
-- (the options, Tooltips).
function SurvivorUI_RankText(number, bare)
	number = tonumber(number) or 0
	if SurvivorUIDB and SurvivorUIDB.romanRanks then
		return Roman(number)
	end
	return bare and tostring(number) or "Rank "..number
end

-- The same icon for a source anywhere in the interface (the Biggest Crits box).
function SurvivorUI_MeterIcon(name)
	return IconOf(name)
end

-- The same color for the same source anywhere in the interface (the build list).
function SurvivorUI_MeterColor(name)
	return ColorOf(name)
end

-- The action button a spell sits on (the build list, the DoT counters, the
-- totems, the soul shards). The game lays its spells on the bar in its list's
-- order, AZS_SPELLS: the first on button 1, the racial on the = key, button 12;
-- but a spell can be dragged to any button, as in 1.12, and stays there until
-- the next new spell lays the whole bar out again (2026-10-22: a dragged
-- spell took the icon, the range and the tooltip of the one on its old
-- button). So each button is read: its tooltip names its spell, looked up in
-- the list. Read again half a second after the bar changes
-- (ACTIONBAR_SLOT_CHANGED) or the list changes size, never in the instant a
-- card is taken (the game hung once, v3.0.17, with a tooltip read right at
-- the choice), and every few seconds besides. A spell on no button keeps its
-- place in the list as its button. Kept by the spell's key, not its place in
-- the list: a new spell moves the racial (always last) one place down, and a
-- map by place gave the new spell the racial's button until the next reading
-- (Eviscerate with Perception's icon in the meter, 2026-10-23).
local slotOf = {}               -- [spell's key] = action button
local slotsRead                 -- GetTime() of the last reading, nil to read again
local slotsCount                -- the list's size then
local slotsDue                  -- GetTime() from which to read again, after a change
local slotScan = CreateFrame("GameTooltip", "SurvivorUISlotScan", nil, "GameTooltipTemplate")

local function ReadSlots()
	slotOf = {}
	slotsRead, slotsCount, slotsDue = GetTime(), table.getn(AZS_SPELLS or {}), nil
	if not (slotScan.SetAction and GetActionTexture) then
		return
	end
	-- Each button's spell, by its tooltip's title: {button: index in the list}.
	local at = {}
	for slot = 1, 120 do
		local held
		if HasAction then
			held = HasAction(slot)
		else
			held = GetActionTexture(slot)
		end
		if held then
			slotScan:SetOwner(WorldFrame, "ANCHOR_NONE")
			slotScan:ClearLines()
			slotScan:SetAction(slot)
			-- A tooltip the game left with no lines says nothing: its old
			-- text is not read (a title read off the wrong button put the
			-- racial's icon on Curse of Agony once, 2026-10-22).
			local title = slotScan:NumLines() > 0 and getglobal("SurvivorUISlotScanTextLeft1")
			title = title and title:GetText()
			slotScan:Hide()
			if title and title ~= "" then
				title = string.gsub(string.gsub(title, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
				at[slot] = SpellIndex(English(title))
			end
		end
	end
	-- The list's order is the rule: a spell keeps its own button (the
	-- twelfth for the racial) unless that button's tooltip names another
	-- spell and some other button's names this one.
	local count = slotsCount
	for index = 1, count do
		local entry = AZS_SPELLS[index]
		local key = entry and (entry.key or entry[1])
		local own = (index == count) and 12 or index
		if key then
			if at[own] == index then
				slotOf[key] = own
			elseif at[own] ~= nil then
				for slot = 1, 120 do
					if at[slot] == index then
						slotOf[key] = slot
						break
					end
				end
			end
		end
	end
end

local slotWatch = CreateFrame("Frame")
slotWatch:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
slotWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
slotWatch:SetScript("OnEvent", function()
	slotsDue = GetTime() + 0.5
end)

-- The action button of the spell at this index of AZS_SPELLS.
function SurvivorUI_SpellSlot(index)
	local count = table.getn(AZS_SPELLS or {})
	local now = GetTime()
	if count ~= slotsCount and not slotsDue then
		slotsDue = now + 0.5
	end
	if not slotsRead or (slotsDue and now >= slotsDue) or now - slotsRead > 5 then
		ReadSlots()
	end
	local entry = AZS_SPELLS and AZS_SPELLS[index]
	local key = entry and (entry.key or entry[1])
	return (key and slotOf[key]) or (index == count and 12 or index)
end

function SurvivorUI_SpellButton(name)
	if not name then
		return nil
	end
	local index = SpellIndex(English(name))
	return index and getglobal("ActionButton"..SurvivorUI_SpellSlot(index))
end

-- A source's share of the meter's damage as shown, 0 to 1, or nil.
local shares = {}
function SurvivorUI_MeterShare(name)
	return shares[name]
end

-- The numbers' columns, from the bar's right end: the share, then the amount.
local SHARE_WIDTH = 30
local AMOUNT_WIDTH = 44
local AMOUNT_RIGHT = SHARE_WIDTH + 6
local NAME_ROOM = WIDTH - BAR_HEIGHT - 2 - (AMOUNT_RIGHT + AMOUNT_WIDTH + 2) - 4

-- The filled part never shorter than the icon's square, so the source's
-- color goes round its icon, as in the build list, however small its share.
local function Filled(share)
	return math.max(BAR_HEIGHT / WIDTH, share)
end

-- The edge around the bar's filled part only: its top and bottom as long as
-- the fill, its right side at the fill's end (edges: top, bottom, left, right).
local function PlaceEdges(bar, share)
	local width = math.max(2, math.floor(WIDTH * Filled(share) + 0.5))
	if bar.edgeWidth == width then
		return
	end
	bar.edgeWidth = width
	local top, bottom, right = bar.edges[1], bar.edges[2], bar.edges[4]
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	top:SetWidth(width)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bottom:SetWidth(width)
	right:ClearAllPoints()
	right:SetPoint("TOPLEFT", bar, "TOPLEFT", width - 1, 0)
	right:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", width - 1, 0)
end

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("StatusBar", nil, meter)
	bar:SetWidth(WIDTH)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)

	-- The build list's look: a dark base the whole width, the color over it to
	-- the source's share in an edge of the color (around the filled part
	-- only: PlaceEdges), and the amount and the share in columns of their
	-- own, between dividers.
	bar.backing = bar:CreateTexture(nil, "BACKGROUND")
	bar.backing:SetTexture(FLAT)
	bar.backing:SetVertexColor(0.05, 0.05, 0.07, 0.92)
	bar.backing:SetAllPoints(bar)
	bar.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = bar:CreateTexture(nil, "OVERLAY")
		line:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", bar, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", bar, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, bar, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, bar, "BOTTOM"..side, 0, 0)
		end
		table.insert(bar.edges, line)
	end
	for _, from in pairs({ AMOUNT_RIGHT + AMOUNT_WIDTH + 2, SHARE_WIDTH + 2 }) do
		local divider = bar:CreateTexture(nil, "OVERLAY")
		divider:SetTexture(FLAT)
		divider:SetVertexColor(1, 1, 1, 0.14)
		divider:SetWidth(1)
		divider:SetPoint("TOP", bar, "TOPRIGHT", -from, 0)
		divider:SetPoint("BOTTOM", bar, "BOTTOMRIGHT", -from, 0)
	end

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	-- The source's icon at the bar's left end, a little inside it: the color
	-- goes round it, as in the build list.
	bar.icon = bar:CreateTexture(nil, "OVERLAY")
	bar.icon:SetWidth(BAR_HEIGHT - 4)
	bar.icon:SetHeight(BAR_HEIGHT - 4)
	bar.icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	bar.name:SetPoint("LEFT", bar, "LEFT", BAR_HEIGHT + 2, 0)
	-- Room for the numbers' columns on the right.
	bar.name:SetWidth(NAME_ROOM)
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	-- "(proc)", smaller, right after the name.
	bar.tag = bar:CreateFontString(nil, "OVERLAY")
	bar.tag:SetFont(SurvivorUI_FONT, 7 + FONT_BUMP, "OUTLINE")
	bar.tag:SetTextColor(0.78, 0.91, 1)
	bar.tag:SetText("(proc)")
	bar.tag:Hide()

	bar.value = bar:CreateFontString(nil, "OVERLAY")
	bar.value:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.value:SetPoint("RIGHT", bar, "RIGHT", -AMOUNT_RIGHT, 0)
	bar.value:SetTextColor(1, 1, 1)

	bar.share = bar:CreateFontString(nil, "OVERLAY")
	bar.share:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	bar.share:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	bar.share:SetTextColor(0.85, 0.85, 0.85)

	-- The crit card sits beside the whole meter, on its left, tops together.
	bar.cardFrame = meter
	bar:EnableMouse(true)
	-- The damage view's lines have the crit card; the others, their numbers.
	bar:SetScript("OnEnter", function()
		if this.view ~= "damage" and this.line then
			GameTooltip:SetOwner(meter, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", meter, "TOPLEFT", -4, 0)
			GameTooltip:SetText(this.line.name, this.color[1], this.color[2], this.color[3])
			local word = (this.view == "healing" and "Healing") or (this.view == "party" and "Damage") or "Damage to bosses"
			GameTooltip:AddDoubleLine(word, Short(this.line.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Share", math.floor(this.line.share * 100 + 0.5).."%", 0.8, 0.8, 0.8, 1, 1, 1)
			-- A hero of the party: the damage a second, the spell that dealt the most.
			if this.view == "party" then
				GameTooltip:AddDoubleLine("Damage per second", Short(this.line.dps), 0.8, 0.8, 0.8, 1, 1, 1)
				if this.line.top then
					GameTooltip:AddDoubleLine("Top spell", this.line.top.."  ("..Short(this.line.topdps).." dps)", 0.8, 0.8, 0.8, 1, 0.82, 0)
				end
			end
			GameTooltip:Show()
		elseif SurvivorUI_CritCardShow then
			SurvivorUI_CritCardShow(this)
		end
	end)
	bar:SetScript("OnLeave", function()
		GameTooltip:Hide()
		if SurvivorUI_CritCardHide then
			SurvivorUI_CritCardHide()
		end
	end)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", StartMove)
	bar:SetScript("OnDragStop", StopMove)
	-- The wheel over a line slides the list, as over the meter (meter.Wheel).
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function()
		if meter.Wheel then
			meter.Wheel()
		end
	end)

	bars[index] = bar
	return bar
end

-- The game's lines, or what came after Reset: each source's damage less what
-- it had then, the most first, shares and damage per second from there.
local function DamageLines()
	local lines, total, dps = AZS_GetMeter()
	lines = lines or {}
	local seconds = RunSeconds()
	-- The clock going back means a new run: the reset goes with the old one.
	if base and lastSeconds and seconds + 3 < lastSeconds then
		base = nil
	end
	lastSeconds = seconds
	if not base then
		local shown = {}
		for index = 1, table.getn(lines) do
			local line = lines[index]
			table.insert(shown, { name = line.name or "?", dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) == 1 })
		end
		return shown, Num(total), Num(dps)
	end

	local shown, sum = {}, 0
	for index = 1, table.getn(lines) do
		local line = lines[index]
		local name = line.name or "?"
		local dmg = Num(line.dmg) - (base.sources[name] or 0)
		if dmg > 0 then
			table.insert(shown, { name = name, dmg = dmg, proc = Num(line.proc) == 1 })
			sum = sum + dmg
		end
	end
	table.sort(shown, function(a, b) return a.dmg > b.dmg end)
	for index = 1, table.getn(shown) do
		shown[index].share = sum > 0 and shown[index].dmg / sum or 0
	end
	local span = seconds - base.at
	return shown, sum, span > 0 and sum / span or 0
end

-- A party's line: its hero's class color and icon (the character
-- creation's, cut inside its round edge), its damage a second and top spell.
local function PartyLine(shown, line)
	local class = string.upper(tostring(line.class))
	local r, g, b = 0.6, 0.6, 0.6
	if SurvivorUI_ClassColor then
		r, g, b = SurvivorUI_ClassColor(class)
	end
	shown.color = { r, g, b }
	shown.dps, shown.topdps = Num(line.dps), Num(line.topdps)
	if line.top and line.top ~= "" and line.top ~= 0 then
		shown.top = English(tostring(line.top))
	end
	local art, coords = nil, nil
	if SurvivorUI_ClassIcon then
		art, coords = SurvivorUI_ClassIcon(class)
	end
	if coords then
		local cutX, cutY = (coords[2] - coords[1]) * 0.1, (coords[4] - coords[3]) * 0.1
		shown.art = art
		shown.coords = { coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY }
	end
end

-- The healing, the boss fight's or the party's lines, as the game gives
-- them (Reset is the damage view's).
local function OtherLines(get)
	local lines, total, rate = get()()
	local shown = {}
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		local entry = { name = line.name or "?", dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) == 1 }
		if line.class and line.class ~= "" then
			PartyLine(entry, line)
		end
		table.insert(shown, entry)
	end
	return shown, Num(total), Num(rate)
end

local function Draw()
	-- The build list's shares are always the damage's.
	local damage, damageTotal, damageRate = DamageLines()
	for name in pairs(shares) do
		shares[name] = nil
	end
	for index = 1, table.getn(damage) do
		shares[damage[index].name] = damage[index].share
	end

	local key = VIEWS[view].key
	local lines, total, dps
	if key == "damage" then
		lines, total, dps = damage, damageTotal, damageRate
	else
		lines, total, dps = OtherLines(VIEWS[view].get)
	end
	local nowOn = NowOn()
	LayCells(nowOn and 3 or 2)
	strip.view = key
	local unit = key == "healing" and "HPS" or "DPS"
	if nowOn then
		local now = NowRate(key, total)
		SetCell(1, "NOW", now and Short(now) or "...", not now and WHITE or (now >= dps and NOW_UP or NOW_DOWN))
		SetCell(2, unit, Short(dps), GOLD)
		SetCell(3, "TOTAL", Short(total), WHITE)
	else
		SetCell(1, unit, Short(dps), GOLD)
		SetCell(2, "TOTAL", Short(total), WHITE)
	end
	reset:SetAlpha(key == "damage" and 1 or 0)
	reset:EnableMouse(key == "damage")
	if table.getn(lines) == 0 then
		meter.empty:SetText((key == "boss" and "No boss fight yet.") or (key == "healing" and "No healing yet.")
			or (key == "party" and "No party damage yet.") or "")
		meter.empty:Show()
	else
		meter.empty:Hide()
	end

	-- Rolled down by the wheel: the first lines out of sight and as many more
	-- in at the bottom, never past the last. The bars keep the top line's
	-- measure. Where the wheel left it is kept as it is: a list the game sends
	-- shorter for a moment is drawn from higher up, and the next one from
	-- where the wheel left it again (meter.most: the most it can roll now).
	meter.most = math.max(0, table.getn(lines) - shownLines)
	local skip = math.min(meter.scrolled or 0, meter.most)
	local count = math.min(shownLines, table.getn(lines) - skip)
	local top = count > 0 and lines[1].dmg or 0
	local firstBar = BARS_TOP
	for index = 1, count do
		local line = lines[index + skip]
		local name = line.name
		local proc = line.proc
		local color = line.color or ColorOf(name)
		local bar = Bar(index)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -firstBar - (index - 1) * (BAR_HEIGHT + BAR_GAP))
		local share = top > 0 and line.dmg / top or 0
		bar:SetValue(Filled(share))
		bar:SetStatusBarColor(color[1], color[2], color[3], 0.45)
		for _, edge in pairs(bar.edges) do
			edge:SetVertexColor(color[1], color[2], color[3], 0.6)
		end
		PlaceEdges(bar, share)
		bar.ability = key == "damage" and name or nil
		bar.view, bar.line = key, line
		bar.color = color

		-- A talent's or amulet's own damage says so, as the game's meter does.
		-- The spell's rank after its name, when asked for (the options, Damage
		-- meter): "Holy Wrath  12", or XII.
		local rank = not line.art and RankOf(name)
		-- With no icon of its own found, the addon's (the minimap button's),
		-- whole. A party's hero: the class's.
		local icon = line.art or IconOf(name)
		bar.icon:SetVertexColor(1, 1, 1)
		if line.coords then
			bar.icon:SetTexture(icon)
			bar.icon:SetTexCoord(line.coords[1], line.coords[2], line.coords[3], line.coords[4])
		elseif icon then
			bar.icon:SetTexture(icon)
			bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			bar.icon:SetTexture(OWN_ICON)
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
		-- With "(proc)" after it, the name gives it room: neither runs into
		-- the numbers, a long name ends in "..." first.
		local room = NAME_ROOM - (proc and 30 or 0)
		if bar.room ~= room then
			bar.room = room
			bar.name:SetWidth(room)
		end
		local ranked = rank and rank > 0 and SurvivorUIDB and SurvivorUIDB.meterRanks
		bar.name:SetText(name..(ranked and "  |cffbdbdbd"..SurvivorUI_RankText(rank, true).."|r" or ""))
		if proc then
			bar.tag:ClearAllPoints()
			bar.tag:SetPoint("LEFT", bar, "LEFT", BAR_HEIGHT + 2 + math.min(bar.name:GetStringWidth(), room) + 3, 0)
			bar.tag:Show()
		else
			bar.tag:Hide()
		end
		bar.value:SetText(Short(line.dmg))
		bar.share:SetText(math.floor(line.share * 100 + 0.5).."%")
		bar:Show()
	end
	for index = count + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].ability = nil
	end
end

-- The wheel over the meter: down, the first line goes up out of sight and the
-- next comes in at the bottom; up, back. A view chosen starts at the top.
meter.Wheel = function()
	local most = meter.most or 0
	meter.scrolled = math.max(0, math.min(most, math.min(meter.scrolled or 0, most) - (arg1 or 0)))
	Draw()
	-- The line under the mouse now holds another source: its card closed,
	-- open again on the next line the mouse goes to.
	GameTooltip:Hide()
	if SurvivorUI_CritCardHide then
		SurvivorUI_CritCardHide()
	end
end
meter:EnableMouseWheel(true)
meter:SetScript("OnMouseWheel", meter.Wheel)

local elapsed = 0
local viewRestored
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	Fit()
	-- The view chosen last time, once the saved settings are in and the game
	-- shares it (Party Damage: in a party).
	if not viewRestored and SurvivorUIDB then
		local known = false
		for index = 1, table.getn(VIEWS) do
			if VIEWS[index].key == SurvivorUIDB.meterView then
				known = true
				if VIEWS[index].get() then
					SetView(index)
					viewRestored = true
				end
			end
		end
		viewRestored = viewRestored or not known
	end
	if Settings().meter and Running() then
		-- A view gone (the party left): the damage for now, the choice
		-- kept for when it comes back.
		if not VIEWS[view].get() then
			SetView(1, true)
			viewRestored = false
		end
		Draw()
		if not meter:IsShown() then
			meter:Show()
			-- The title's width is known once it is drawn.
			FitTitle()
		end
	elseif meter:IsShown() then
		meter:Hide()
	end
end)

------------------------------------------------------------------------------
-- The game's own meter: away while this one is on. The setting is the game's
-- and is saved, so the addon remembers that it was the one to turn it off.

local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.meter or settings.noGameMeter then
		if AZS_IsHudShown("meter") then
			AZS_SetHudShown("meter", false)
			settings.hidGameMeter = true
		end
	elseif settings.hidGameMeter then
		AZS_SetHudShown("meter", true)
		settings.hidGameMeter = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.meter = ApplyGameHud

function SurvivorUI_ToggleMeter()
	local settings = Settings()
	settings.meter = not settings.meter
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.meter
		and "damage meter on; the Default meter is put away."
		or (settings.noGameMeter and "damage meter off, and the Default one stays away." or "damage meter off; the Default one is back, with its healing and boss damage.")))
end

-- The game's tooltip for units and the world: it opens at an anchor of its own
-- that Alt can move. Left where it is, the anchor sits beside the meter, on its
-- left, bottoms together (the tooltip's stock corner is where the meter is), or
-- in that corner when the meter is off.
local tipAnchor = CreateFrame("Frame", "SurvivorUITooltipAnchor", UIParent)
tipAnchor:SetWidth(200)
tipAnchor:SetHeight(80)
tipAnchor:SetMovable(true)
if tipAnchor.SetClampedToScreen then
	tipAnchor:SetClampedToScreen(true)
end

local function PlaceTipAnchor()
	local settings = Settings()
	tipAnchor:ClearAllPoints()
	if settings.tipRight then
		tipAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", settings.tipRight, settings.tipBottom)
	elseif meter:IsVisible() then
		tipAnchor:SetPoint("BOTTOMRIGHT", meter, "BOTTOMLEFT", -6, 0)
	else
		tipAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 64)
	end
end

local function SaveTipAnchor()
	local settings = Settings()
	settings.tipRight = math.floor(tipAnchor:GetRight() + 0.5)
	settings.tipBottom = math.floor(tipAnchor:GetBottom() + 0.5)
end

local stockDefaultAnchor = GameTooltip_SetDefaultAnchor
if stockDefaultAnchor then
	GameTooltip_SetDefaultAnchor = function(tooltip, parent)
		stockDefaultAnchor(tooltip, parent)
		if tooltip then
			PlaceTipAnchor()
			tooltip:ClearAllPoints()
			tooltip:SetPoint("BOTTOMRIGHT", tipAnchor, "BOTTOMRIGHT", 0, 0)
		end
	end
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(tipAnchor, "Tooltip", SaveTipAnchor, nil, PlaceTipAnchor)
end
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	seatedOn = nil
	Fit()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(meter, "Damage meter", SavePlace, nil, function()
		seatedOn = nil
		Fit()
	end)
end
