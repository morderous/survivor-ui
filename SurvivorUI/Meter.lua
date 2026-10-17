-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the damage meter.
--
-- The game's own meter, drawn again from the numbers it shares (its addon API,
-- AZS_GetMeter): one flat bar per source of damage, the most first, each in a
-- color of its own, a talent's or amulet's own damage tagged as a proc. Hover a line for its card: its damage, share and damage per second,
-- and its critical strikes and normal hits from the combat log. The title's
-- menu switches to the run's healing (AZS_GetHealing) or the last boss fight's damage
-- to bosses (AZS_GetBossMeter), in the same bars.
--
-- Reset starts the meter over from that moment and clears the crits; the run
-- panel keeps the whole run. Its
-- size holds through a run: up to ten lines, fewer on a small screen. Hold Alt
-- and drag to move. The game's own meter is put away while this one is on;
-- /sui meter brings it back. Needs the API; without it nothing shows.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 228
local BAR_HEIGHT = 16
local BAR_GAP = 2
local MAX_LINES = 10

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
local function Short(value)
	if value >= 1000000 then
		return string.format("%.2fm", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
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
meter:SetHeight(24 + MAX_LINES * (BAR_HEIGHT + BAR_GAP))
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
		meter:SetHeight(24 + count * (BAR_HEIGHT + BAR_GAP))
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
	local fit = math.floor((room - 24) / (BAR_HEIGHT + BAR_GAP))
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

local function SetView(index)
	view = index
	Settings().meterView = VIEWS[index].key
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
meter.total = meter:CreateFontString(nil, "OVERLAY")
meter.total:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
meter.total:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -42, -6)
meter.total:SetTextColor(0.7, 0.7, 0.7)

-- A view with nothing in it yet says so.
meter.empty = meter:CreateFontString(nil, "OVERLAY")
meter.empty:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
meter.empty:SetPoint("TOPLEFT", meter, "TOPLEFT", 8, -24)
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

-- A name or bonus line in English, whatever language the game is in (Locale.lua).
local function English(name)
	return SurvivorUI_English and SurvivorUI_English(name) or name
end

local colors = {}               -- [source] = palette entry
local colorsGiven = 0
local bars = {}

local function ColorOf(name)
	name = English(name)
	if not colors[name] then
		colorsGiven = colorsGiven + 1
		colors[name] = PALETTE[math.mod(colorsGiven - 1, table.getn(PALETTE)) + 1]
	end
	return colors[name]
end

-- A spell's rank, from the game's list (AZS_SPELLS names it by key: "holy_wrath"
-- for "Holy Wrath"), as a Roman numeral: XII.
local SPELL_KEYS = {
	["shadow word: pain"] = "sw_pain", ["power word: shield"] = "pw_shield",
	["demoralizing shout"] = "demo_shout", ["hunter's mark"] = "hunters_mark",
}

-- A source's icon. A spell of the build: its action button's (the game puts
-- them on buttons 1 to 6, the racial on the last). Anything else, a talent's or
-- an item's own damage: the spellbook, the talents, then the worn items, by
-- name. Found icons are kept; a miss is asked again now and then, as talents
-- and items come during a run.
local OWN_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local icons = {}                -- [name] = texture
local missedAt = {}             -- [name] = GetTime() of the last miss

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
	if icons[name] then
		return icons[name]
	end
	local index, racial = SpellIndex(name)
	local texture = index and GetActionTexture and GetActionTexture(racial and 12 or index)
	if not texture then
		if missedAt[name] and GetTime() - missedAt[name] < 10 then
			return nil
		end
		texture = FromSpellbook(name) or FromTalents(name) or FromItems(name)
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

-- The same icon for a source anywhere in the interface (the Biggest Crits box).
function SurvivorUI_MeterIcon(name)
	return IconOf(name)
end

-- The same color for the same source anywhere in the interface (the build list).
function SurvivorUI_MeterColor(name)
	return ColorOf(name)
end

-- The action button a spell sits on (the DoT counter, DotCounter.lua): its
-- place in the game's spell list is its slot, the racial on the = key.
function SurvivorUI_SpellButton(name)
	if not name then
		return nil
	end
	local index, racial = SpellIndex(English(name))
	return index and getglobal("ActionButton"..(racial and 12 or index))
end

-- A source's share of the meter's damage as shown, 0 to 1, or nil.
local shares = {}
function SurvivorUI_MeterShare(name)
	return shares[name]
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

	bar.backing = bar:CreateTexture(nil, "BACKGROUND")
	bar.backing:SetTexture(FLAT)
	bar.backing:SetVertexColor(0.10, 0.10, 0.13, 0.9)
	bar.backing:SetAllPoints(bar)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	-- The source's icon, square at the bar's left end.
	bar.icon = bar:CreateTexture(nil, "OVERLAY")
	bar.icon:SetWidth(BAR_HEIGHT)
	bar.icon:SetHeight(BAR_HEIGHT)
	bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	bar.name:SetPoint("LEFT", bar, "LEFT", BAR_HEIGHT + 4, 0)
	-- Room for the numbers on the right: damage and share.
	bar.name:SetWidth(WIDTH - 76 - BAR_HEIGHT)
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
	bar.value:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	bar.value:SetTextColor(1, 1, 1)

	-- The crit card sits beside the whole meter, on its left, tops together.
	bar.cardFrame = meter
	bar:EnableMouse(true)
	-- The damage view's lines have the crit card; the others, their numbers.
	bar:SetScript("OnEnter", function()
		if this.view ~= "damage" and this.line then
			GameTooltip:SetOwner(meter, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", meter, "TOPLEFT", -4, 0)
			GameTooltip:SetText(this.line.name, this.color[1], this.color[2], this.color[3])
			local word = this.view == "healing" and "Healing" or "Damage to bosses"
			GameTooltip:AddDoubleLine(word, Short(this.line.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine("Share", math.floor(this.line.share * 100 + 0.5).."%", 0.8, 0.8, 0.8, 1, 1, 1)
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

-- The healing or the boss fight's lines, as the game gives them (Reset is the
-- damage view's).
local function OtherLines(get)
	local lines, total, rate = get()()
	local shown = {}
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		table.insert(shown, { name = line.name or "?", dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) == 1 })
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
	meter.total:SetText(Short(total).."  |cffffffff"..Short(dps).."|r "..(key == "healing" and "hps" or "dps"))
	reset:SetAlpha(key == "damage" and 1 or 0)
	reset:EnableMouse(key == "damage")
	if table.getn(lines) == 0 then
		meter.empty:SetText(key == "boss" and "No boss fight yet." or (key == "healing" and "No healing yet." or ""))
		meter.empty:Show()
	else
		meter.empty:Hide()
	end

	local count = math.min(shownLines, table.getn(lines))
	local top = count > 0 and lines[1].dmg or 0
	for index = 1, count do
		local line = lines[index]
		local name = line.name
		local proc = line.proc
		local color = ColorOf(name)
		local bar = Bar(index)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -20 - (index - 1) * (BAR_HEIGHT + BAR_GAP))
		bar:SetValue(top > 0 and line.dmg / top or 0)
		bar:SetStatusBarColor(color[1], color[2], color[3], 0.85)
		bar.ability = key == "damage" and name or nil
		bar.view, bar.line = key, line
		bar.color = color

		-- A talent's or amulet's own damage says so, as the game's meter does.
		-- The spell's rank after its name, as a Roman numeral: "Holy Wrath XII".
		local rank = RankOf(name)
		-- With no icon of its own found, the addon's (the minimap button's), whole.
		local icon = IconOf(name)
		bar.icon:SetVertexColor(1, 1, 1)
		if icon then
			bar.icon:SetTexture(icon)
			bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			bar.icon:SetTexture(OWN_ICON)
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
		bar.name:SetText(index..". "..name..(rank and rank > 0 and "  |cffbdbdbd"..Roman(rank).."|r" or ""))
		if proc then
			bar.tag:ClearAllPoints()
			bar.tag:SetPoint("LEFT", bar, "LEFT", BAR_HEIGHT + 4 + bar.name:GetStringWidth() + 4, 0)
			bar.tag:Show()
		else
			bar.tag:Hide()
		end
		bar.value:SetText(Short(line.dmg).."  |cffb0b0b0"..math.floor(line.share * 100 + 0.5).."%|r")
		bar:Show()
	end
	for index = count + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].ability = nil
	end
end

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
	-- The view chosen last time, once the saved settings are in.
	if not viewRestored and SurvivorUIDB then
		viewRestored = true
		for index = 1, table.getn(VIEWS) do
			if VIEWS[index].key == SurvivorUIDB.meterView and VIEWS[index].get() then
				SetView(index)
			end
		end
	end
	if Settings().meter and Running() then
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
	if settings.meter then
		if AZS_IsHudShown("meter") then
			AZS_SetHudShown("meter", false)
			settings.hidGameMeter = true
		end
	elseif settings.hidGameMeter then
		AZS_SetHudShown("meter", true)
		settings.hidGameMeter = nil
	end
end

function SurvivorUI_ToggleMeter()
	local settings = Settings()
	settings.meter = not settings.meter
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.meter
		and "damage meter on; the game's own meter is put away."
		or "damage meter off; the game's own is back, with its healing and boss damage."))
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
