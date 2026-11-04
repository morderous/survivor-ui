-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the damage meter.
--
-- The game's own meter, drawn again from the numbers it shares (its addon API,
-- AZS_GetMeter): one flat bar per source of damage, the most first, each in a
-- color of its own, a talent's or amulet's own damage tagged as a proc. Hover a line for its card: its damage, share and damage per second,
-- and its critical strikes and normal hits from the combat log. The buttons
-- under its title switch to each source's damage a second (DPS, over the meter's own clock),
-- the last 30 seconds or the run's healing (AZS_GetHealing), in the same
-- bars; in a co-op run (the game's 0.113), to the party's damage
-- (AZS_GetPartyMeter), a bar a hero in the class's color, with its damage a
-- second, its top spell on hover. The row's last button opens the meter now
-- (MeterNow.lua), a window of its own: the last 30 seconds, since its own
-- Reset or the boss fight. The + at its corner opens another window on
-- another page (MeterWindows.lua), in the same bars. The small
-- button left of Reset folds the lines under 10% of the total (the options,
-- Damage meter: 1 to 20%) into one, Others, in every window alike.
--
-- Reset starts the meter over from that moment and clears the crits; the run
-- panel keeps the whole run. Its
-- size holds through a run: up to ten lines, fewer on a small screen, or as
-- many as set (the options, or its card in move mode); the lines that do not
-- fit roll by the wheel or the scroll bar at its right. Hold Alt
-- and drag to move. The game's own meter is put away while this one is on;
-- /sui meter brings it back. Needs the API; without it nothing shows.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 228
local BAR_HEIGHT = 18           -- as the build list's rows
local BAR_GAP = 2
local MAX_LINES = 10
-- Each window's own size, set on its card in move mode: its width, and its
-- lines (until set, as many as the layout fits).
local WIDTH_LEAST, WIDTH_MOST = 180, 400
local LINES_LEAST, LINES_MOST = 3, 20
-- The scroll bar at a window's right, for the lines that do not fit: the bars
-- give it this much of their width while it shows.
local ROLL_WIDTH, ROLL_ROOM = 8, 6
-- The bars start under the title and the strip of numbers (total, dps, now).
local STRIP_TOP, STRIP_HEIGHT = 20, 14
local BARS_TOP = STRIP_TOP + STRIP_HEIGHT + 2
-- The numbers strip at the foot of the main window and the extra ones (the
-- page buttons stand where it was): the room it takes there.
local FOOT = STRIP_HEIGHT + 4

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
meter:SetHeight(BARS_TOP + 4 + MAX_LINES * (BAR_HEIGHT + BAR_GAP) + FOOT)
meter.barWidth = WIDTH
meter.foot = FOOT
meter:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
meter:SetBackdrop({ bgFile = FLAT })
-- The right column's one shade, as the tracker and the run panel wear it.
meter:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
meter:SetMovable(true)
meter:EnableMouse(true)
meter:RegisterForDrag("LeftButton")
meter:Hide()

-- No backgrounds (the options' No backgrounds, Experimental): the shade away,
-- the bars keeping their own dark base and color, unless the meter is kept
-- (its extra windows follow it: MeterWindows.lua). Painted as the world loads
-- and as the options change it (Options.lua: every SurvivorUI_Grounds).
SurvivorUI_Grounds = SurvivorUI_Grounds or {}
function SurvivorUI_Grounds.meter()
	local db = SurvivorUIDB
	local bare = db and db.noBackgrounds and not (db.noBackgroundsOff and db.noBackgroundsOff.meter)
	meter:SetBackdropColor(0.04, 0.04, 0.07, bare and 0 or 0.55)
end

local function SavePlace()
	local settings = Settings()
	settings.meterRight = math.floor(meter:GetRight() + 0.5)
	settings.meterBottom = math.floor(meter:GetBottom() + 0.5)
	-- Let go against another window: that one holds on to this one.
	if SurvivorUI_MeterLinkTo then
		SurvivorUI_MeterLinkTo("main")
	end
end

local function MainWidth()
	return math.max(WIDTH_LEAST, math.min(WIDTH_MOST, tonumber(Settings().meterWidth) or WIDTH))
end

local shownLines = MAX_LINES

-- How tall it is with this many lines, and how many lines a height holds.
local function Tall(count)
	return BARS_TOP + 4 + count * (BAR_HEIGHT + BAR_GAP) + FOOT
end

local function LinesIn(room)
	return math.floor((room - BARS_TOP - 4 - FOOT) / (BAR_HEIGHT + BAR_GAP))
end

-- The lines it wants: as many as given (the layout's fit), or as set on its
-- card.
local function Wanted(count)
	return math.max(LINES_LEAST, math.min(LINES_MOST, tonumber(Settings().meterLines) or count))
end

-- As many lines as it wants, no more than most (the room the right column
-- leaves it, Fit), three at least; as wide as set on its card.
local function SetLines(count, most)
	count = Wanted(count)
	if most then
		count = math.max(LINES_LEAST, math.min(count, most))
	end
	local width = MainWidth()
	if count ~= shownLines or width ~= meter.barWidth then
		shownLines = count
		meter.barWidth = width
		meter:SetWidth(width + 8)
		meter:SetHeight(Tall(count))
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

-- Moved, it keeps its place; but the right column above it (the pieces hung
-- from the minimap) grows as a run's tracker takes more lines, and could run
-- into it (seen 2026-11-04: a meter let go right under Jewelry worn, the
-- tracker one row taller, its title over the last slot). Then it stands
-- right under the column, as many lines as fit down to the screen's bottom,
-- and goes back to its place as the column shrinks. Its bottom for now, and
-- the lines that fit (nil: its own).
local function ClearOfColumn(settings, above, right, bottom)
	if not (above and above:IsShown() and above:GetLeft()) then
		return bottom
	end
	-- The column's head: the tracker, or the build list moved on its own.
	local head = SurvivorUITracker or above
	if settings.buildLeft and above ~= SurvivorUITracker and SurvivorUIBuild then
		head = SurvivorUIBuild
	end
	local ratio = above:GetEffectiveScale() / meter:GetEffectiveScale()
	local under = above:GetBottom() * ratio
	local top = bottom + Tall(Wanted(MAX_LINES))
	local left = right - MainWidth() - 8
	local headTop = head:GetTop() and head:GetTop() * head:GetEffectiveScale() / meter:GetEffectiveScale()
	if under >= top or not headTop or headTop <= top
		or left >= above:GetRight() * ratio or right <= above:GetLeft() * ratio then
		return bottom
	end
	local most = LinesIn(under - 8)
	return math.floor(under - Tall(math.max(LINES_LEAST, math.min(Wanted(MAX_LINES), most))) + 0.5), most
end

local function Fit()
	local settings = Settings()
	local build, worn, tracker = SurvivorUIBuild, SurvivorUIWorn, SurvivorUITracker
	local above, shift = nil, 0
	if worn and worn:IsShown() and not settings.wornLeft and worn:GetBottom() then
		above = worn
	elseif build and build:IsShown() and build:GetBottom() then
		above = build
	elseif tracker and tracker:GetBottom() then
		above, shift = tracker, 8
	end
	if settings.meterRight then
		local bottom, most = ClearOfColumn(settings, above, settings.meterRight, settings.meterBottom)
		Seat("saved"..settings.meterRight..","..bottom, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", settings.meterRight, bottom)
		SetLines(MAX_LINES, most)
		return
	end
	if not above then
		Seat("screen", "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
		SetLines(MAX_LINES)
		return
	end
	Seat(above:GetName(), "TOPRIGHT", above, "BOTTOMRIGHT", shift, -10)
	-- The piece above has a size of its own: its bottom read in the meter's units.
	local room = above:GetBottom() * above:GetEffectiveScale() / meter:GetEffectiveScale() - 10 - 8
	local fit = LinesIn(room)
	-- Lines set on its card or in the options: no more than fit, as more
	-- would reach past the screen's bottom and be pushed up over the column.
	SetLines(math.max(3, math.min(MAX_LINES, fit)), fit)
end

local function StartMove()
	if SurvivorUI_MoveKeyDown() then
		meter:StartMoving()
	end
end

local function StopMove()
	meter:StopMovingOrSizing()
	SavePlace()
end

meter:SetScript("OnDragStart", StartMove)
meter:SetScript("OnDragStop", StopMove)

-- What the meter shows, a page each: the run's damage, each source's damage
-- a second, a co-op run's party, the last 30 seconds (MeterNow.lua keeps
-- them) and the healing. A row of buttons under the title switches them
-- (asked for 2026-11-04), each in a color of its own, the one shown lit; one
-- the game does not share now greyed (the party's out of a party). The last
-- boss fight's page went with them (Lucas, 2026-11-04): the meter now's This
-- boss tells a fight.
local VIEWS = {
	{ key = "damage", title = "Damage Done", label = "DMG", color = { 0.95, 0.42, 0.28 }, get = function() return AZS_GetMeter end,
		tip = "Each source's damage this run, since Reset." },
	-- Each source's damage a second, as the strip's DPS counts it.
	{ key = "dps", title = "DPS", label = "DPS", color = { 1, 0.78, 0.2 }, get = function() return AZS_GetMeter end,
		tip = "Each source's damage a second, since the run began or Reset." },
	-- A co-op run's: each hero's damage. Greyed out of a party.
	{ key = "party", title = "Party Damage", label = "PARTY", color = { 0.38, 0.62, 1 }, get = function()
		if AZS_GetPartyMeter and AZS_PARTY and table.getn(AZS_PARTY) > 0 then
			return AZS_GetPartyMeter
		end
	end, tip = "Each hero's damage in a co-op run.", why = "Not in a party." },
	{ key = "last", title = "Last 30 s", label = "30s", color = { 0.3, 0.82, 0.88 }, get = function()
		return SurvivorUI_MeterStretch and AZS_GetMeter
	end, tip = "Each source's damage over the last 30 seconds of the run's clock." },
	{ key = "healing", title = "Healing Done", label = "Healing", color = { 0.42, 0.88, 0.42 }, get = function() return AZS_GetHealing end,
		tip = "Your healing this run." },
}
local view = 1

-- The row's buttons: the pages, then the meter now's (MeterNow.lua), which
-- opens or closes that window and is lit while it is open.
local ROW_PAGES = {}
for index = 1, table.getn(VIEWS) do
	ROW_PAGES[index] = VIEWS[index]
end
table.insert(ROW_PAGES, { key = "now", title = "Meter now", icon = "Interface\\AddOns\\SurvivorUI\\Art\\NowIcon",
	color = { 0.72, 0.48, 1 },
	tip = "A window of its own for how you are doing now: the last 30 seconds, since its own Reset, or the boss fight. Click to open or close it.",
	action = function()
		if SurvivorUI_ToggleMeterNow then
			SurvivorUI_ToggleMeterNow(true)
		end
	end,
	lit = function() return Settings().nowMeter == true end })

local GOLD = { 1, 0.82, 0 }

-- The title: the page's name in gold; a drag on it moves the meter.
local titleButton = CreateFrame("Button", nil, meter)
titleButton:SetPoint("TOPLEFT", meter, "TOPLEFT", 2, -2)
titleButton:SetHeight(17)
titleButton.noHoverOutline = true

meter.title = titleButton:CreateFontString(nil, "OVERLAY")
meter.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
meter.title:SetPoint("LEFT", titleButton, "LEFT", 3, 0)
meter.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
meter.title:SetText(SurvivorUI_T("Damage Done"))

-- The button hugs the title.
local function FitTitle()
	titleButton:SetWidth(meter.title:GetStringWidth() + 6)
end

-- passing: shown for now, the choice kept (a page gone for a while).
local function SetView(index, passing)
	view = index
	meter.scrolled = 0
	if not passing then
		Settings().meterView = VIEWS[index].key
	end
	meter.title:SetText(SurvivorUI_T(VIEWS[index].title))
	FitTitle()
end

-- A page by its key ("damage", "healing", "boss", "party"...), as its button:
-- true if the game shares it now.
function SurvivorUI_SetMeterView(key)
	for index = 1, table.getn(VIEWS) do
		if VIEWS[index].key == key and VIEWS[index].get() then
			SetView(index)
			return true
		end
	end
	return false
end

titleButton:RegisterForDrag("LeftButton")
titleButton:SetScript("OnDragStart", StartMove)
titleButton:SetScript("OnDragStop", StopMove)
FitTitle()

-- The page buttons, a row under the title, in this window and the extra ones
-- (MeterWindows.lua), and in the meter now with its own pages (MeterNow.lua):
-- a pill a page (Art\Pill, its ends kept round as it widens) in the page's
-- color, the one shown filled with its word dark, the others a soft wash of
-- their color with their word in it, the one under the mouse a little
-- brighter, one the game does not share now greyed (the party's out of a
-- party). Hover one for what it shows. They share the row by their words, a
-- size smaller when those are too long for it. pick(key) is called on a
-- click; a button with an action of its own (the meter now's) does that
-- instead, lit while it says so.
local PILL = "Interface\\AddOns\\SurvivorUI\\Art\\Pill"
local PILL_HEIGHT, PILL_GAP, PILL_PAD = 14, 2, 6

local function Shared(page)
	return not page.get or page.get() ~= nil
end

local function PaintPill(pill)
	local page, color = pill.view, pill.view.color
	local lit = (page.lit and page.lit()) or (not page.action and pill.key == pill.row.shown)
	local shared = Shared(page)
	local alpha = lit and 0.92 or (not shared and 0.08) or (pill.hot and 0.4 or 0.2)
	for part = 1, 3 do
		pill.parts[part]:SetVertexColor(color[1], color[2], color[3], alpha)
	end
	local r, g, b = color[1], color[2], color[3]
	if lit then
		r, g, b = 0.06, 0.06, 0.08
	elseif not shared then
		r, g, b = 0.4, 0.4, 0.44
	elseif pill.hot then
		r, g, b = 1, 1, 1
	end
	pill.text:SetTextColor(r, g, b)
	if pill.icon then
		pill.icon:SetVertexColor(r, g, b)
	end
end

local function PillTip(pill)
	local page = pill.view
	GameTooltip:SetOwner(pill, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(SurvivorUI_T(page.title), page.color[1], page.color[2], page.color[3])
	local tip = type(page.tip) == "function" and page.tip() or (page.tip and SurvivorUI_T(page.tip))
	if tip then
		GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, 1)
	end
	if not Shared(page) and page.why then
		GameTooltip:AddLine(SurvivorUI_T(page.why), 0.6, 0.6, 0.65, 1)
	end
	GameTooltip:Show()
end

function SurvivorUI_MeterPageRow(window, pick, pages)
	pages = pages or ROW_PAGES
	local row = CreateFrame("Frame", nil, window)
	row:SetHeight(PILL_HEIGHT)
	row:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -STRIP_TOP)
	row.pills = {}
	local cap = PILL_HEIGHT / 2
	for index = 1, table.getn(pages) do
		local pill = CreateFrame("Button", nil, row)
		pill:SetHeight(PILL_HEIGHT)
		pill.row, pill.view, pill.key = row, pages[index], pages[index].key
		pill.parts = {}
		for part = 1, 3 do
			pill.parts[part] = pill:CreateTexture(nil, "BACKGROUND")
			pill.parts[part]:SetTexture(PILL)
			pill.parts[part]:SetHeight(PILL_HEIGHT)
		end
		pill.parts[1]:SetTexCoord(0, 0.25, 0, 1)
		pill.parts[1]:SetWidth(cap)
		pill.parts[1]:SetPoint("LEFT", pill, "LEFT", 0, 0)
		pill.parts[3]:SetTexCoord(0.75, 1, 0, 1)
		pill.parts[3]:SetWidth(cap)
		pill.parts[3]:SetPoint("RIGHT", pill, "RIGHT", 0, 0)
		pill.parts[2]:SetTexCoord(0.25, 0.75, 0, 1)
		pill.parts[2]:SetPoint("LEFT", pill.parts[1], "RIGHT", 0, 0)
		pill.parts[2]:SetPoint("RIGHT", pill.parts[3], "LEFT", 0, 0)
		pill.text = pill:CreateFontString(nil, "OVERLAY")
		pill.text:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP)
		pill.text:SetPoint("CENTER", pill, "CENTER", 0, 0)
		if pages[index].icon then
			pill.icon = pill:CreateTexture(nil, "OVERLAY")
			pill.icon:SetTexture(pages[index].icon)
			pill.icon:SetWidth(11)
			pill.icon:SetHeight(11)
			pill.icon:SetPoint("CENTER", pill, "CENTER", 0, 0)
		end
		pill.noHoverOutline = true
		pill:SetScript("OnEnter", function()
			this.hot = true
			PaintPill(this)
			PillTip(this)
		end)
		pill:SetScript("OnLeave", function()
			this.hot = nil
			PaintPill(this)
			GameTooltip:Hide()
		end)
		pill:SetScript("OnClick", function()
			if not Shared(this.view) then
				return
			end
			if this.view.action then
				this.view.action()
				PaintPill(this)
			else
				pick(this.key)
			end
		end)
		pill:RegisterForDrag("LeftButton")
		pill:SetScript("OnDragStart", function()
			if window.StartMove then
				window.StartMove()
			end
		end)
		pill:SetScript("OnDragStop", function()
			if window.StopMove then
				window.StopMove()
			end
		end)
		row.pills[index] = pill
	end
	-- Across width, the page shown lit.
	row.Lay = function(shown, width)
		row.shown = shown
		local list = row.pills
		local count = table.getn(list)
		local sign = count..":"..width..":"..SurvivorUI_T(list[1].view.label or "")
		if row.sign ~= sign then
			row.sign = sign
			row:SetWidth(width)
			local room = width - (count - 1) * PILL_GAP
			local function Measure(size)
				local sum = 0
				for index = 1, count do
					local pill = list[index]
					if pill.icon then
						pill.natural = 12 + 2 * PILL_PAD
					else
						pill.text:SetFont(SurvivorUI_FONT, size)
						pill.text:SetText(SurvivorUI_T(pill.view.label))
						pill.natural = pill.text:GetStringWidth() + 2 * PILL_PAD
						-- A word not measured yet (the window still hidden): again next time.
						if pill.natural <= 2 * PILL_PAD then
							row.sign = nil
						end
					end
					sum = sum + pill.natural
				end
				return sum
			end
			local sum = Measure(8 + FONT_BUMP)
			if sum > room then
				sum = Measure(7 + FONT_BUMP)
			end
			local stretch = room / math.max(1, sum)
			local x = 0
			for index = 1, count do
				local pill = list[index]
				local each = index == count and (width - x) or math.floor(pill.natural * stretch + 0.5)
				pill:SetWidth(each)
				pill:ClearAllPoints()
				pill:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
				x = x + each + PILL_GAP
			end
		end
		for index = 1, count do
			list[index]:Show()
			PaintPill(list[index])
		end
	end
	return row
end
-- At its foot, the numbers, each named, in cells across the meter: NOW a
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
strip:SetPoint("BOTTOMLEFT", meter, "BOTTOMLEFT", 4, 4)
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
	local width = meter.barWidth or WIDTH
	if strip.count == count and strip.width == width then
		return
	end
	strip.count, strip.width = count, width
	strip:SetWidth(width)
	local each = width / count
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
	cell.label:SetText(SurvivorUI_T(label))
	cell.value:SetText(value)
	cell.value:SetTextColor(color[1], color[2], color[3])
end

strip:SetScript("OnEnter", function()
	local healing = this.view == "healing"
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	-- The DPS page: now and on average, no total.
	if this.view == "dps" then
		GameTooltip:SetText(SurvivorUI_T("DPS"), 1, 0.82, 0)
		if NowOn() then
			GameTooltip:AddDoubleLine(SurvivorUI_T("NOW"), SurvivorUI_TF("a second over the last {1} seconds", NOW_WINDOW), NOW_UP[1], NOW_UP[2], NOW_UP[3], 0.8, 0.8, 0.8)
		end
		GameTooltip:AddDoubleLine(SurvivorUI_T("AVG"), SurvivorUI_T("a second on average, since the run began or Reset"), GOLD[1], GOLD[2], GOLD[3], 0.8, 0.8, 0.8)
		if NowOn() then
			GameTooltip:AddLine(SurvivorUI_T("NOW is green while above the average, orange while below."), 0.6, 0.6, 0.65, 1)
		end
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(meter.title:GetText() or "", 1, 0.82, 0)
	if NowOn() then
		GameTooltip:AddDoubleLine(SurvivorUI_T("NOW"), SurvivorUI_TF("a second over the last {1} seconds", NOW_WINDOW), NOW_UP[1], NOW_UP[2], NOW_UP[3], 0.8, 0.8, 0.8)
	end
	GameTooltip:AddDoubleLine(healing and "HPS" or "DPS", SurvivorUI_T("a second on average"), GOLD[1], GOLD[2], GOLD[3], 0.8, 0.8, 0.8)
	-- The whole phrase a piece, for a language with its own order.
	local total = (this.view == "boss" and "the last boss fight's damage") or (this.view == "party" and "the party's damage")
		or (this.view == "last" and "the damage of the last 30 seconds")
		or (healing and "the run's healing") or "the run's damage, since Reset"
	GameTooltip:AddDoubleLine(SurvivorUI_T("TOTAL"), SurvivorUI_T(total), 1, 1, 1, 0.8, 0.8, 0.8)
	if NowOn() then
		GameTooltip:AddLine(SurvivorUI_T("NOW is green while above the average, orange while below."), 0.6, 0.6, 0.65, 1)
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

-- At the corner, a + opening another window on another page
-- (MeterWindows.lua); Reset left of it. The fold button stands right of the
-- title; the meter now's button (MeterNow.lua) ends the row of pages.
local more = CreateFrame("Button", nil, meter)
more:SetWidth(14)
more:SetHeight(14)
more:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -3, -3)
more.text = more:CreateFontString(nil, "OVERLAY")
more.text:SetFont(SurvivorUI_FONT, 13 + FONT_BUMP, "OUTLINE")
more.text:SetPoint("CENTER", more, "CENTER", 0, 1)
more.text:SetText("+")
more.text:SetTextColor(0.6, 0.6, 0.6)
more:SetScript("OnEnter", function()
	this.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(SurvivorUI_T("Another meter window"), 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T("Opens a window of its own on a page this one does not show: the party's damage in a co-op run, else the healing or the boss fight. Its buttons switch its page, its - closes it.").." "..SurvivorUI_MoveHint(" it"), 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
more:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)
more:SetScript("OnClick", function()
	if SurvivorUI_MeterAddWindow then
		SurvivorUI_MeterAddWindow()
	end
end)


-- As wide as its word, 32 at least (Reset): a longer one (Сброс) reaches
-- left, and the fold button stands left of it (Draw).
local reset = CreateFrame("Button", nil, meter)
reset.least = 32
reset:SetWidth(reset.least)
reset:SetHeight(12)
reset:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -20, -5)
reset.text = reset:CreateFontString(nil, "OVERLAY")
reset.text:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
reset.text:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
reset.text:SetText(SurvivorUI_T("Reset"))
reset.text:SetTextColor(0.6, 0.6, 0.6)
reset:SetScript("OnEnter", function()
	this.text:SetTextColor(1, 1, 1)
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(SurvivorUI_T("Starts the meter over from now."), 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T("Damage, damage per second and shares count from here, and the crits are cleared. The run panel keeps the whole run's numbers."), 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)

-- The fold button, right of the title (in every window): a small
-- glyph of two bars over three dots, gold on a soft gold wash while on. On,
-- the lines under 10% of the total (or as the options' Damage meter tab
-- sets it, 1 to 20%) fold into one at the bottom, Others, in every window
-- alike (SurvivorUIDB.meterFold, meterFoldUnder). Not on the party's page.
local OTHERS_COLOR = { 0.62, 0.62, 0.68 }
local foldButtons = {}

local function FoldOn()
	return Settings().meterFold == true
end

-- The share under which a line folds, 0.01 to 0.20.
local function FoldUnder()
	return math.max(1, math.min(20, tonumber(Settings().meterFoldUnder) or 10)) / 100
end

local function PaintFold(button)
	local on = FoldOn()
	local r, g, b = 0.6, 0.6, 0.6
	if button.hot then
		r, g, b = 1, on and 0.92 or 1, on and 0.5 or 1
	elseif on then
		r, g, b = GOLD[1], GOLD[2], GOLD[3]
	end
	for index = 1, table.getn(button.parts) do
		button.parts[index]:SetVertexColor(r, g, b, 1)
	end
	button.wash:SetVertexColor(1, 0.82, 0, on and 0.12 or 0)
end

local function FoldTip(button)
	local share = math.floor(FoldUnder() * 100 + 0.5)
	GameTooltip:SetOwner(button, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(SurvivorUI_T("Fold the small lines"), 1, 1, 1)
	if FoldOn() then
		GameTooltip:AddLine(SurvivorUI_TF("On: the lines under {1}% are one line, Others.", share), GOLD[1], GOLD[2], GOLD[3], 1)
	else
		GameTooltip:AddLine(SurvivorUI_T("Off: every line on its own."), 0.6, 0.6, 0.6, 1)
	end
	GameTooltip:AddLine(SurvivorUI_TF("The lines under {1}% of the total join one line at the bottom, Others, with what they add up to and their share. Hover it for each of them. Click to switch, in every meter window.", share), 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine(SurvivorUI_T("The share can be changed, from 1 to 20%: /sui opt, Damage meter."), 0.6, 0.6, 0.65, 1)
	GameTooltip:Show()
end

function SurvivorUI_MeterFoldButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(15)
	button:SetHeight(14)
	button.wash = button:CreateTexture(nil, "BACKGROUND")
	button.wash:SetTexture(FLAT)
	button.wash:SetAllPoints(button)
	-- The glyph, 11 by 8: a long bar, a shorter one, three dots under them.
	button.parts = {}
	local shape = { { 2, -3, 11, 2 }, { 2, -6, 7, 2 }, { 2, -9, 2, 2 }, { 6, -9, 2, 2 }, { 10, -9, 2, 2 } }
	for index = 1, table.getn(shape) do
		local part = button:CreateTexture(nil, "OVERLAY")
		part:SetTexture(FLAT)
		part:SetPoint("TOPLEFT", button, "TOPLEFT", shape[index][1], shape[index][2])
		part:SetWidth(shape[index][3])
		part:SetHeight(shape[index][4])
		table.insert(button.parts, part)
	end
	button:SetScript("OnEnter", function()
		this.hot = true
		PaintFold(this)
		FoldTip(this)
	end)
	button:SetScript("OnLeave", function()
		this.hot = nil
		PaintFold(this)
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", function()
		Settings().meterFold = not FoldOn() or nil
		for index = 1, table.getn(foldButtons) do
			PaintFold(foldButtons[index])
		end
		FoldTip(this)
		local window = this:GetParent()
		if window.Redraw then
			window.Redraw()
		end
	end)
	table.insert(foldButtons, button)
	PaintFold(button)
	return button
end

-- The button on a page: away on the party's, painted as the setting stands.
function SurvivorUI_MeterFoldShow(button, key)
	button:SetAlpha(key == "party" and 0 or 1)
	button:EnableMouse(key ~= "party")
	PaintFold(button)
end

local fold = SurvivorUI_MeterFoldButton(meter)
fold:SetPoint("LEFT", titleButton, "RIGHT", 2, 0)

meter.pages = SurvivorUI_MeterPageRow(meter, function(key)
	for index = 1, table.getn(VIEWS) do
		if VIEWS[index].key == key and VIEWS[index].get() then
			SetView(index)
			if meter.Redraw then
				meter.Redraw()
			end
		end
	end
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

------------------------------------------------------------------------------
-- The pets each on a line of their own (asked for 2026-11-04): the game's
-- meter adds a hunter's beasts (or any summon it puts there) up in one line,
-- Pets. Its meter API (AZS_GetMeterSnapshot by actor and source) tells each
-- pet's own attacks, AZS_GetSummons each one's name and icon: Pets is shared
-- out between them by those amounts, so every total still adds up to the
-- game's. The talents and amulets a pet casts keep their own lines. Asked once
-- a second, only while there is a Pets line; without the API, or no pet found
-- in it, Pets stays one line. Every reader of the game's lines goes through
-- SurvivorUI_MeterGame (this meter, the meter now, the run panel, Run History).
do
	local split = {}            -- { { name, share }, ... }: each pet's part of Pets
	local askedAt = -10
	local summonIcons = {}      -- [name] = the game's icon for a summon
	local summonNames = {}      -- [the summon's id, as AZS_GetSummons gives it] = its name
	local summonsAt = -10

	-- The summons the game tells (AZS_GetSummons), their names and icons,
	-- once a second at most.
	local function KnowSummons()
		if not AZS_GetSummons or GetTime() - summonsAt < 1 then
			return
		end
		summonsAt = GetTime()
		local ok, summons = pcall(AZS_GetSummons)
		for _, summon in pairs(ok and type(summons) == "table" and summons or {}) do
			if summon.id and summon.name then
				summonNames[tostring(summon.id)] = summon.name
				summonIcons[summon.name] = summon.icon
				if SurvivorUI_English then
					summonIcons[SurvivorUI_English(summon.name)] = summon.icon
				end
			end
		end
	end

	-- The shares asked again; a failed asking keeps the last ones (the API
	-- answers busy at times), so no blow goes back to Pets for a moment.
	local function Ask()
		if not (AZS_GetMeterSnapshot and AZS_GetMeterContext and AZS_GetSummons) then
			return
		end
		local ok, context = pcall(AZS_GetMeterContext)
		if not (ok and type(context) == "table" and context.runId) then
			return
		end
		local okSnap, snap = pcall(AZS_GetMeterSnapshot, { apiVersion = 1, runId = context.runId, metric = "damage",
			scope = "self", period = "run", groupBy = "actor_source", windowSeconds = 0 })
		if not (okSnap and type(snap) == "table" and type(snap.rows) == "table") then
			return
		end
		local okSummons, summons = pcall(AZS_GetSummons)
		local names = {}
		for _, summon in pairs(okSummons and type(summons) == "table" and summons or {}) do
			if summon.id and summon.name then
				names["P"..tostring(summon.id)] = summon.name
				summonNames[tostring(summon.id)] = summon.name
				summonIcons[summon.name] = summon.icon
				if SurvivorUI_English then
					summonIcons[SurvivorUI_English(summon.name)] = summon.icon
				end
			end
		end
		local amounts, order, sum = {}, {}, 0
		for _, row in pairs(snap.rows) do
			local name = row.actorId and row.actorId ~= context.localOwnerId and names[row.actorId]
			if name and row.procClassification ~= "proc" then
				local amount = tonumber(row.displayAmount) or 0
				if not amounts[name] then
					amounts[name] = 0
					table.insert(order, name)
				end
				amounts[name] = amounts[name] + amount
				sum = sum + amount
			end
		end
		if sum > 0 then
			local fresh = {}
			for index = 1, table.getn(order) do
				table.insert(fresh, { name = order[index], share = amounts[order[index]] / sum })
			end
			split = fresh
		end
	end

	-- A list of the game's lines with Pets a line a pet, by the shares last
	-- asked (the boss fight's too, MeterNow.lua); as it is without them.
	local function SplitLines(lines)
		local at
		for index = 1, table.getn(lines or {}) do
			if lines[index].name == "Pets" then
				at = index
			end
		end
		if not at or table.getn(split) == 0 then
			return lines
		end
		local pets, shown = lines[at], {}
		for index = 1, table.getn(lines) do
			if index ~= at then
				table.insert(shown, lines[index])
			end
		end
		for index = 1, table.getn(split) do
			local pet = split[index]
			table.insert(shown, { name = pet.name, dmg = Num(pets.dmg) * pet.share, share = Num(pets.share) * pet.share,
				dps = Num(pets.dps) * pet.share, proc = 0 })
		end
		table.sort(shown, function(a, b)
			if Num(a.dmg) ~= Num(b.dmg) then
				return Num(a.dmg) > Num(b.dmg)
			end
			return tostring(a.name) < tostring(b.name)
		end)
		return shown
	end

	function SurvivorUI_MeterSplitPets(lines)
		return SplitLines(lines)
	end

	-- The game's lines (AZS_GetMeter), with Pets a line a pet.
	function SurvivorUI_MeterGame()
		local lines, total, dps = AZS_GetMeter()
		local pets = false
		for index = 1, table.getn(lines or {}) do
			pets = pets or lines[index].name == "Pets"
		end
		if pets and GetTime() - askedAt >= 1 then
			askedAt = GetTime()
			Ask()
		end
		return SplitLines(lines), total, dps
	end

	-- A pet's name when it has a line of its own now (its crits go there,
	-- SurvivorUI.lua), else nil; and the game's icon for a summon.
	function SurvivorUI_MeterPetLine(name)
		if not name then
			return nil
		end
		for index = 1, table.getn(split) do
			if split[index].name == name then
				return name
			end
		end
		-- Not shared out yet (a run's first seconds): a summon of the game's
		-- Pets is its own line as soon as it is.
		if table.getn(split) == 0 and AZS_GetMeterSnapshot and SurvivorUI_MeterHasLine("Pets") then
			KnowSummons()
			for _, known in pairs(summonNames) do
				if known == name then
					return name
				end
			end
		end
	end

	function SurvivorUI_MeterPetIcon(name)
		return name and summonIcons[name]
	end

	-- Whether the game's meter has a line of that name (AZS_METER, as sent).
	function SurvivorUI_MeterHasLine(name)
		for index = 1, table.getn(AZS_METER or {}) do
			if AZS_METER[index].name == name then
				return true
			end
		end
		return false
	end

	-- A pet's line by the id the game's hits give it: its sourceId ends in the
	-- summon's id in hex ("uf13000252700000c": 0x2700000c, 654311436, read
	-- in the game's 0.141). Pets shared out (above), or a line of its own in
	-- the game's meter (a mage's Water Elemental, which the hits call Pets);
	-- else nil.
	function SurvivorUI_MeterPetById(id)
		local number = id and tonumber(string.sub(tostring(id), -8), 16)
		if not number then
			return nil
		end
		local key = tostring(number)
		if not summonNames[key] then
			KnowSummons()
		end
		local name = summonNames[key]
		if name and (SurvivorUI_MeterPetLine(name) or SurvivorUI_MeterHasLine(name)) then
			return name
		end
		return nil
	end
end

local function TakeBase()
	local lines, total = SurvivorUI_MeterGame()
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
	["Dread Lord"] = "Spell_Shadow_UnholyStrength",    -- its talent's, Pact of the Nathrezim (the game's 0.140)
	["Pit Lord"] = "Spell_Shadow_RitualOfSacrifice", -- the Dread Lord's name up to the game's 0.139
	["Felseeker"] = "Spell_Fire_SoulBurn",        -- the Dread Lord's Searing Pain
	["Water Elemental"] = "Spell_Frost_SummonWaterElemental",
	["Spirit Wolf"] = "Spell_Nature_SpiritWolf",
	["Treant"] = "Spell_Nature_ForceOfNature",
	["Wolf"] = "Ability_Hunter_Pet_Wolf",
	["Raptor"] = "Ability_Hunter_Pet_Raptor",
	["White Devilsaur"] = "Ability_Hunter_Pet_Raptor", -- the look a hunter's wolf and raptor take (its talent's icon, the game's 0.141)
	["Pets"] = "Ability_Hunter_BeastCall",        -- the game's meter's one line for a hunter's beasts
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
	["demoralizing shout"] = "demo_shout", ["hunter's mark"] = "hunters_mark", ["rockbiter weapon"] = "rockbiter",
}

-- A source's icon. A spell of the build: its action button's (the game puts
-- them on buttons 1 to 6, the racial on the last: SurvivorUI_SpellSlot).
-- Anything else, a talent's or an item's own damage: the spellbook, the
-- talents, then the worn items, by name. Found icons are kept; a miss is asked again now and then, as talents
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

-- A talent of the game's (TalentIcons.lua, written from its exe): a proc's
-- own damage (Nightfall's, Daybreak's) shows its talent's icon, which the
-- client's 1.12 talents have only now and then.
local function FromGameTalents(name)
	local icon = SurvivorUI_TALENT_ICONS and SurvivorUI_TALENT_ICONS[name]
	return icon and "Interface\\Icons\\"..icon or nil
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
	-- A summon on a line of its own with no icon of ours: the game's for it.
	local summoned = SurvivorUI_MeterPetIcon and SurvivorUI_MeterPetIcon(name)
	if summoned then
		return summoned
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
		texture = FromGameTalents(name) or FromSpellbook(name) or FromTalents(name) or FromItems(name)
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
	return bare and tostring(number) or SurvivorUI_TF("Rank {1}", number)
end

-- The same icon for a source anywhere in the interface (the Biggest Crits box).
function SurvivorUI_MeterIcon(name)
	return IconOf(name)
end

-- The tag after a proc's name (the game marks its procs): an amulet's own
-- damage "(neck)" (a codex amulet by its name, JewelryData.lua, or a class
-- amulet's "Amulet of the Inferno: Consecration"), a talent's "(talent)"
-- (TalentIcons.lua, the game's talents), the rest "(proc)" (a ring's, a
-- trinket's). Run History's copy of the meter wears the same.
local necks
function SurvivorUI_ProcTag(name)
	name = English(name or "")
	if not necks then
		necks = {}
		local list = SurvivorUI_JEWELRY and SurvivorUI_JEWELRY.Neck or {}
		for index = 1, table.getn(list) do
			necks[list[index][1]] = true
		end
	end
	if necks[name] or string.find(name, ": ", 1, true) then
		return SurvivorUI_T("(neck)")
	elseif SurvivorUI_TALENT_ICONS and SurvivorUI_TALENT_ICONS[name] then
		return SurvivorUI_T("(talent)")
	end
	return SurvivorUI_T("(proc)")
end

-- The same color for the same source anywhere in the interface (the build list).
function SurvivorUI_MeterColor(name)
	return ColorOf(name)
end

-- The action button a spell sits on (the build list, the DoT counters, the
-- totems, the soul shards): the game lays its spells on the bar in its list's
-- order, AZS_SPELLS, the first on button 1 and the racial on the = key, button
-- 12, and that order is the rule. A spell dragged to another button (as in
-- 1.12) is not followed: from v3.0.23 to v3.0.31 every button's tooltip was
-- read every few seconds to follow one, and the reading confused the icons
-- now and then (Amarolk's, 2026-10-25), more trouble than a drag is worth;
-- the bar is locked against a drag instead (SurvivorUI.lua, from v3.0.32).
function SurvivorUI_SpellSlot(index)
	local count = table.getn(AZS_SPELLS or {})
	return (index == count and count > 0) and 12 or index
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

-- The numbers' columns, from the bar's right end: the share, then the amount;
-- on the party's page, a hero's damage a second left of the amount.
local SHARE_WIDTH = 30
local AMOUNT_WIDTH = 44
local AMOUNT_RIGHT = SHARE_WIDTH + 6
local RATE_WIDTH = 36
local RATE_RIGHT = AMOUNT_RIGHT + AMOUNT_WIDTH + 6
-- The name's room in a bar of a width: what the numbers' columns leave.
local function NameRoom(width, rated)
	return width - BAR_HEIGHT - 2 - (AMOUNT_RIGHT + AMOUNT_WIDTH + 2) - 4 - (rated and RATE_WIDTH + 6 or 0)
end

-- The filled part never shorter than the icon's square, so the source's
-- color goes round its icon, as in the build list, however small its share.
local function Filled(share, width)
	return math.max(BAR_HEIGHT / (width or WIDTH), share)
end

-- The edge around the bar's filled part only: its top and bottom as long as
-- the fill, its right side at the fill's end (edges: top, bottom, left, right).
local function PlaceEdges(bar, share)
	local barWidth = bar.width or WIDTH
	local width = math.max(2, math.floor(barWidth * Filled(share, barWidth) + 0.5))
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

-- A hero of the party in the game's meter feed (its 0.132): their id, by name
-- or else by class. The feed comes from the game's server, so it reaches a
-- friend, as addon messages do not.
local function HeroOwner(line, context)
	local party = AZS_GetMeterSnapshot({ apiVersion = 1, runId = context.runId, metric = "damage", scope = "party", period = "run",
		groupBy = "owner", windowSeconds = 0 })
	local byClass
	for id, actor in pairs(party and party.actors or {}) do
		if actor.name == line.name then
			return id
		end
		if actor.classKey and line.class and string.upper(actor.classKey) == string.upper(tostring(line.class)) then
			byClass = id
		end
	end
	return byClass
end

-- A hero's lines on their card: the damage by spell, the jewelry, the talents.
local function AddHeroDetail(line)
	if not (AZS_GetMeterContext and AZS_GetMeterSnapshot and AZS_GetMeterLoadout) then
		return
	end
	local context = AZS_GetMeterContext()
	local owner = context and HeroOwner(line, context)
	if not owner then
		return
	end
	local spells = AZS_GetMeterSnapshot({ apiVersion = 1, runId = context.runId, metric = "damage", scope = "owner", ownerId = owner,
		period = "run", groupBy = "source", windowSeconds = 0 })
	local rows = spells and spells.rows or {}
	if table.getn(rows) > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(SurvivorUI_T("Damage by spell"), 1, 0.82, 0)
		for index = 1, math.min(table.getn(rows), 8) do
			local source = spells.sources and spells.sources[rows[index].sourceKey]
			GameTooltip:AddDoubleLine(source and source.name or "?", math.floor(Num(rows[index].share) * 100 + 0.5).."%", 1, 1, 1, 0.8, 0.8, 0.8)
		end
	end
	local loadout = AZS_GetMeterLoadout({ apiVersion = 1, runId = context.runId, ownerId = owner })
	if not loadout then
		return
	end
	local jewelry = loadout.runJewelry or {}
	if table.getn(jewelry) > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(SurvivorUI_T("Jewelry"), 1, 0.82, 0)
		for index = 1, table.getn(jewelry) do
			local source = loadout.sources and loadout.sources[jewelry[index].sourceKey]
			if source then
				GameTooltip:AddLine(source.name, 1, 1, 1)
			end
		end
	end
	local points = 0
	for index = 1, table.getn(loadout.talents or {}) do
		points = points + Num(loadout.talents[index].rank)
	end
	if points > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(SurvivorUI_T("Talents"), points, 1, 0.82, 0, 1, 1, 1)
	end
end

-- A bar in the meter's look, for any window (MeterWindows.lua too): its
-- tooltip and the crit card beside its window, dragged with it (the
-- window's StartMove and StopMove), the wheel rolling its list (its Wheel).
local function MakeBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetWidth(WIDTH)
	bar.width = WIDTH
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
	-- The party's page: one divider more, left of the damage a second.
	bar.rateDivider = bar:CreateTexture(nil, "OVERLAY")
	bar.rateDivider:SetTexture(FLAT)
	bar.rateDivider:SetVertexColor(1, 1, 1, 0.14)
	bar.rateDivider:SetWidth(1)
	bar.rateDivider:SetPoint("TOP", bar, "TOPRIGHT", -(RATE_RIGHT + RATE_WIDTH + 2), 0)
	bar.rateDivider:SetPoint("BOTTOM", bar, "BOTTOMRIGHT", -(RATE_RIGHT + RATE_WIDTH + 2), 0)
	bar.rateDivider:Hide()

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	-- The source's icon at the bar's left end, a little inside it: the color
	-- goes round it, as in the build list.
	bar.icon = bar:CreateTexture(nil, "OVERLAY")
	bar.icon:SetWidth(BAR_HEIGHT - 4)
	bar.icon:SetHeight(BAR_HEIGHT - 4)
	bar.icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Others' square: the icons of up to four of the lines folded into it,
	-- small, two by two, the bar's grey between them.
	bar.tiles = {}
	local tile = math.floor((BAR_HEIGHT - 6) / 2)
	for index = 1, 4 do
		local texture = bar:CreateTexture(nil, "OVERLAY")
		texture:SetWidth(tile)
		texture:SetHeight(tile)
		texture:SetPoint("TOPLEFT", bar.icon, "TOPLEFT", math.mod(index - 1, 2) * (tile + 2), -math.floor((index - 1) / 2) * (tile + 2))
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		texture:Hide()
		bar.tiles[index] = texture
	end

	bar.name:SetPoint("LEFT", bar, "LEFT", BAR_HEIGHT + 2, 0)
	-- Room for the numbers' columns on the right.
	bar.name:SetWidth(NameRoom(WIDTH))
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	-- "(proc)", smaller, right after the name; Others' count in grey.
	bar.tag = bar:CreateFontString(nil, "OVERLAY")
	bar.tag:SetFont(SurvivorUI_FONT, 7 + FONT_BUMP, "OUTLINE")
	bar.tag:SetTextColor(0.78, 0.91, 1)
	bar.tag:SetText(SurvivorUI_T("(proc)"))
	bar.tag:Hide()

	bar.value = bar:CreateFontString(nil, "OVERLAY")
	bar.value:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.value:SetPoint("RIGHT", bar, "RIGHT", -AMOUNT_RIGHT, 0)
	bar.value:SetTextColor(1, 1, 1)

	bar.share = bar:CreateFontString(nil, "OVERLAY")
	bar.share:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	bar.share:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	bar.share:SetTextColor(0.85, 0.85, 0.85)

	-- A hero's damage a second, on the party's page only, in the gold of the
	-- strip's DPS.
	bar.rate = bar:CreateFontString(nil, "OVERLAY")
	bar.rate:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.rate:SetPoint("RIGHT", bar, "RIGHT", -RATE_RIGHT, 0)
	bar.rate:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	bar.rate:Hide()

	-- The crit card sits beside the whole window, on its left, tops together.
	bar.cardFrame = parent
	bar:EnableMouse(true)
	-- The damage view's lines have the crit card; the others, their numbers.
	bar:SetScript("OnEnter", function()
		if this.line and this.line.others then
			-- Others: each line in it, in its color, its amount and share.
			local window = this:GetParent()
			GameTooltip:SetOwner(window, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, 0)
			GameTooltip:SetText(this.line.name, OTHERS_COLOR[1], OTHERS_COLOR[2], OTHERS_COLOR[3])
			local folded = this.line.others
			for index = 1, table.getn(folded) do
				local line = folded[index]
				local color = line.color or ColorOf(line.name)
				GameTooltip:AddDoubleLine(line.name, Short(line.dmg).."  |cffa0a0a0"..math.floor(line.share * 100 + 0.5).."%|r",
					color[1], color[2], color[3], 1, 1, 1)
			end
			GameTooltip:AddLine(SurvivorUI_TF("Each under {1}% of the total. The button at the top shows them on their own again; /sui opt, Damage meter changes the share.",
				math.floor(FoldUnder() * 100 + 0.5)), 0.6, 0.6, 0.65, 1)
			GameTooltip:Show()
		elseif this.view ~= "damage" and this.view ~= "dps" and this.view ~= "last" and this.line then
			local window = this:GetParent()
			GameTooltip:SetOwner(window, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, 0)
			GameTooltip:SetText(this.line.name, this.color[1], this.color[2], this.color[3])
			local word = (this.view == "healing" and "Healing") or (this.view == "party" and "Damage") or "Damage to bosses"
			GameTooltip:AddDoubleLine(word, Short(this.line.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine(SurvivorUI_T("Share"), math.floor(this.line.share * 100 + 0.5).."%", 0.8, 0.8, 0.8, 1, 1, 1)
			-- A hero of the party: the damage a second, the spell that dealt the most.
			if this.view == "party" then
				GameTooltip:AddDoubleLine(SurvivorUI_T("Damage per second"), Short(this.line.dps), 0.8, 0.8, 0.8, 1, 1, 1)
				if this.line.top then
					GameTooltip:AddDoubleLine(SurvivorUI_T("Top spell"), SurvivorUI_TF("{1}  ({2} dps)", this.line.top, Short(this.line.topdps)), 0.8, 0.8, 0.8, 1, 0.82, 0)
				end
				AddHeroDetail(this.line)
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
	bar:SetScript("OnDragStart", function()
		local window = this:GetParent()
		if window.StartMove then
			window.StartMove()
		end
	end)
	bar:SetScript("OnDragStop", function()
		local window = this:GetParent()
		if window.StopMove then
			window.StopMove()
		end
	end)
	-- The wheel over a line slides the list, as over its window (its Wheel).
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function()
		local window = this:GetParent()
		if window.Wheel then
			window.Wheel()
		end
	end)
	return bar
end

meter.StartMove, meter.StopMove = StartMove, StopMove

local function Bar(index)
	if not bars[index] then
		bars[index] = MakeBar(meter)
	end
	return bars[index]
end

-- The game's lines, or what came after Reset: each source's damage less what
-- it had then, the most first, shares and damage per second from there.
local function DamageLines()
	local lines, total, dps = SurvivorUI_MeterGame()
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

-- The DPS page: each source's damage a second over the meter's own clock
-- (the run's, or since Reset), as the strip's DPS counts it, so the column
-- adds up to it; the shares are the damage's.
local function DpsOf(lines, total, rate)
	local per = total > 0 and rate / total or 0
	local shown = {}
	for index = 1, table.getn(lines) do
		local line = lines[index]
		table.insert(shown, { name = line.name, dmg = line.dmg * per, share = line.share, proc = line.proc })
	end
	return shown, total, rate
end

-- The fold button on: the lines under its share of the total, two or more,
-- as one at the bottom, Others, with what they add up to and their share. A
-- party's heroes stay each on their own.
local function Folded(lines, key)
	if not FoldOn() or key == "party" then
		return lines
	end
	local under = FoldUnder()
	local kept, small = {}, {}
	for index = 1, table.getn(lines) do
		local line = lines[index]
		if line.share < under then
			table.insert(small, line)
		else
			table.insert(kept, line)
		end
	end
	if table.getn(small) < 2 then
		return lines
	end
	local others = { name = SurvivorUI_T("Others"), dmg = 0, share = 0, color = OTHERS_COLOR, others = small }
	for index = 1, table.getn(small) do
		others.dmg = others.dmg + small[index].dmg
		others.share = others.share + small[index].share
	end
	table.insert(kept, others)
	return kept
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
	shown.class = line.class
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

-- The last 30 seconds of the run's clock, as the meter now keeps them.
local function LastLines()
	local lines, total, rate
	if SurvivorUI_MeterStretch then
		lines, total, rate = SurvivorUI_MeterStretch("last")
	end
	return lines or {}, total or 0, rate or 0
end

-- A bar painted from a line of the page key: filled to its share of the top
-- line's (top), in its color (a hero's class's), its icon, its name and rank,
-- "(proc)", its amount and share.
local function PaintBar(bar, line, top, key)
	local name = line.name
	local proc = line.proc
	local folded = line.others
	local color = line.color or ColorOf(name)
	-- As wide as its window (set on its card in move mode), less the scroll
	-- bar's room while it shows.
	local width = (bar:GetParent().barWidth or WIDTH) - (bar:GetParent().rolling and ROLL_ROOM or 0)
	if bar.width ~= width then
		bar.width = width
		bar:SetWidth(width)
		bar.edgeWidth, bar.room = nil, nil
	end
	local share = top > 0 and line.dmg / top or 0
	bar:SetValue(Filled(share, width))
	bar:SetStatusBarColor(color[1], color[2], color[3], 0.45)
	for _, edge in pairs(bar.edges) do
		edge:SetVertexColor(color[1], color[2], color[3], 0.6)
	end
	PlaceEdges(bar, share)
	bar.ability = (key == "damage" or key == "dps" or key == "last") and not folded and name or nil
	bar.view, bar.line = key, line
	bar.color = color

	-- A talent's or amulet's own damage says so, as the game's meter does.
	-- The spell's rank after its name, when asked for (the options, Damage
	-- meter): "Holy Wrath  12", or XII.
	local rank = not line.art and not folded and RankOf(name)
	-- With no icon of its own found, the addon's (the minimap button's),
	-- whole. A party's hero: the class's. Others: its lines' icons, small.
	local icon = not folded and (line.art or IconOf(name))
	bar.icon:SetVertexColor(1, 1, 1)
	for index = 1, 4 do
		bar.tiles[index]:Hide()
	end
	if folded then
		bar.icon:Hide()
		-- Four, three, or two across a diagonal.
		local count = math.min(4, table.getn(folded))
		local spots = (count == 2 and { 1, 4 }) or (count == 3 and { 1, 2, 3 }) or { 1, 2, 3, 4 }
		for index = 1, table.getn(spots) do
			local tile = bar.tiles[spots[index]]
			local art = IconOf(folded[index].name)
			tile:SetTexture(art or OWN_ICON)
			if art then
				tile:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			else
				tile:SetTexCoord(0, 1, 0, 1)
			end
			tile:Show()
		end
	elseif line.coords then
		bar.icon:SetTexture(icon)
		bar.icon:SetTexCoord(line.coords[1], line.coords[2], line.coords[3], line.coords[4])
	elseif icon then
		bar.icon:SetTexture(icon)
		bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	else
		bar.icon:SetTexture(OWN_ICON)
		bar.icon:SetTexCoord(0, 1, 0, 1)
	end
	if not folded then
		bar.icon:Show()
	end
	-- With its tag after it, "(proc)", "(talent)" or "(neck)", or Others'
	-- "(5 spells)", the name gives it room: neither runs into the numbers, a
	-- long name ends in "..." first.
	local tagged = proc or folded
	if folded then
		bar.tag:SetText(SurvivorUI_TF("({1} spells)", table.getn(folded)))
		bar.tag:SetTextColor(0.7, 0.7, 0.75)
	elseif proc then
		bar.tag:SetText(SurvivorUI_ProcTag(name))
		bar.tag:SetTextColor(0.78, 0.91, 1)
	end
	-- A party's hero: its damage a second in a column of its own.
	local rated = key == "party" and line.dps ~= nil
	if rated then
		bar.rate:SetText(Short(line.dps))
		bar.rate:Show()
		bar.rateDivider:Show()
	else
		bar.rate:Hide()
		bar.rateDivider:Hide()
	end
	local room = NameRoom(width, rated) - (tagged and math.floor(bar.tag:GetStringWidth() + 6) or 0)
	if bar.room ~= room then
		bar.room = room
		bar.name:SetWidth(room)
	end
	local ranked = rank and rank > 0 and SurvivorUIDB and SurvivorUIDB.meterRanks
	-- The white damage's row, which the game names in English in every
	-- language: in the game's own word for it (Ближний бой, 近战).
	local shown = MELEE[name] and SurvivorUI_Native and SurvivorUI_Native(name) or name
	bar.name:SetText(shown..(ranked and "  |cffbdbdbd"..SurvivorUI_RankText(rank, true).."|r" or ""))
	-- Others: grey, as its bar.
	if folded then
		bar.name:SetTextColor(0.8, 0.8, 0.84)
	else
		bar.name:SetTextColor(1, 1, 1)
	end
	if tagged then
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

-- A window's scroll bar, there while its lines do not all fit: the thumb as
-- long as the share of the lines that shows. Dragged or clicked, the window's
-- list rolls as by the wheel (window.Roll).
local function MakeRoll(window)
	local roll = CreateFrame("Slider", nil, window)
	roll:SetOrientation("VERTICAL")
	roll:SetWidth(ROLL_WIDTH)
	roll:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -BARS_TOP)
	roll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 4 + BAR_GAP + (window.foot or 0))
	roll:SetFrameLevel(window:GetFrameLevel() + 6)
	roll:SetMinMaxValues(0, 1)
	roll:SetValueStep(1)
	roll:EnableMouse(true)
	roll:EnableMouseWheel(true)
	local track = roll:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(FLAT)
	track:SetVertexColor(0, 0, 0, 0.45)
	track:SetWidth(ROLL_WIDTH - 2)
	track:SetPoint("TOP", roll, "TOP", 0, 0)
	track:SetPoint("BOTTOM", roll, "BOTTOM", 0, 0)
	roll.thumb = roll:CreateTexture(nil, "OVERLAY")
	roll.thumb:SetTexture(FLAT)
	roll.thumb:SetVertexColor(0.55, 0.55, 0.6, 1)
	roll.thumb:SetWidth(ROLL_WIDTH - 2)
	roll.thumb:SetHeight(16)
	roll:SetThumbTexture(roll.thumb)
	roll:SetScript("OnEnter", function() this.thumb:SetVertexColor(0.9, 0.9, 0.95, 1) end)
	roll:SetScript("OnLeave", function() this.thumb:SetVertexColor(0.55, 0.55, 0.6, 1) end)
	roll:SetScript("OnValueChanged", function()
		if not this.quiet then
			window.Roll(math.floor(this:GetValue() + 0.5))
		end
	end)
	roll:SetScript("OnMouseWheel", function()
		window.Wheel()
	end)
	roll:Hide()
	window.roll = roll
end

-- Its list rolled to where it stands: called with window.most worked out,
-- before its bars are painted (they make room for it).
local function ShowRoll(window, skip, shown)
	local roll, most = window.roll, window.most or 0
	window.rolling = most > 0
	if most == 0 then
		roll:Hide()
		return
	end
	roll.quiet = true
	roll:SetMinMaxValues(0, most)
	roll:SetValue(skip)
	roll.quiet = nil
	roll.thumb:SetHeight(math.max(14, math.floor(shown * (BAR_HEIGHT + BAR_GAP) * shown / (shown + most))))
	roll:Show()
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
	elseif key == "dps" then
		lines, total, dps = DpsOf(damage, damageTotal, damageRate)
	elseif key == "last" then
		lines, total, dps = LastLines()
	else
		lines, total, dps = OtherLines(VIEWS[view].get)
	end
	lines = Folded(lines, key)
	meter.pages.Lay(key, meter.barWidth or WIDTH)
	local nowOn = NowOn()
	strip.view = key
	local unit = key == "healing" and "HPS" or "DPS"
	if key == "dps" then
		-- The DPS page: now and on average (AVG); its total is Damage Done's.
		LayCells(nowOn and 2 or 1)
		if nowOn then
			local now = NowRate(key, total)
			SetCell(1, "NOW", now and Short(now) or "...", not now and WHITE or (now >= dps and NOW_UP or NOW_DOWN))
			SetCell(2, "AVG", Short(dps), GOLD)
		else
			SetCell(1, "AVG", Short(dps), GOLD)
		end
	elseif nowOn then
		LayCells(3)
		local now = NowRate(key, total)
		SetCell(1, "NOW", now and Short(now) or "...", not now and WHITE or (now >= dps and NOW_UP or NOW_DOWN))
		SetCell(2, unit, Short(dps), GOLD)
		SetCell(3, "TOTAL", Short(total), WHITE)
	else
		LayCells(2)
		SetCell(1, unit, Short(dps), GOLD)
		SetCell(2, "TOTAL", Short(total), WHITE)
	end
	-- Reset on the damage's pages.
	local resettable = key == "damage" or key == "dps"
	reset:SetAlpha(resettable and 1 or 0)
	reset:EnableMouse(resettable)
	-- Its word measured at the size it is drawn (the piece's text size).
	local resetWidth = math.max(reset.least, math.ceil(reset.text:GetStringWidth()) + 2)
	if math.abs(reset:GetWidth() - resetWidth) > 0.5 then
		reset:SetWidth(resetWidth)
	end
	SurvivorUI_MeterFoldShow(fold, key)
	if table.getn(lines) == 0 then
		meter.empty:SetText(SurvivorUI_T((key == "boss" and "No boss fight yet.") or (key == "healing" and "No healing yet.")
			or (key == "party" and "No party damage yet.") or (key == "last" and "No damage yet.") or ""))
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
	ShowRoll(meter, skip, shownLines)
	local firstBar = BARS_TOP
	for index = 1, count do
		local bar = Bar(index)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -firstBar - (index - 1) * (BAR_HEIGHT + BAR_GAP))
		PaintBar(bar, lines[index + skip], top, key)
		-- The last 30 seconds' cards tell that stretch's crits (MeterNow.lua).
		bar.slice = key == "last" and SurvivorUI_MeterSlice and SurvivorUI_MeterSlice("last") or nil
	end
	for index = count + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].ability = nil
	end
end
meter.Redraw = Draw

------------------------------------------------------------------------------
-- Lent to the other windows (MeterWindows.lua, MeterNow.lua): the bars, the pages, the
-- numbers.

SurvivorUI_METER = { WIDTH = WIDTH, BAR_HEIGHT = BAR_HEIGHT, BAR_GAP = BAR_GAP, FOOT = FOOT,
	STRIP_TOP = STRIP_TOP, STRIP_HEIGHT = STRIP_HEIGHT, BARS_TOP = BARS_TOP,
	WIDTH_LEAST = WIDTH_LEAST, WIDTH_MOST = WIDTH_MOST, LINES_LEAST = LINES_LEAST, LINES_MOST = LINES_MOST }

-- The main window's width and lines, for its card in move mode; set, each
-- kept (its Reset puts back the first width and the lines the layout fits).
function SurvivorUI_MeterMainSize()
	return meter.barWidth or WIDTH, shownLines
end

function SurvivorUI_SetMeterMainSize(width, lines)
	local settings = Settings()
	if width then
		settings.meterWidth = width ~= WIDTH and width or nil
	end
	if lines then
		settings.meterLines = lines
	end
	local height = meter:GetHeight()
	Fit()
	-- Moved, the place kept is its bottom edge: that goes by what the height
	-- changed, so its title stays where it is.
	if settings.meterBottom and meter:GetHeight() ~= height then
		settings.meterBottom = settings.meterBottom + height - meter:GetHeight()
		Fit()
	end
	if meter:IsShown() then
		Draw()
	end
end

function SurvivorUI_MeterNewBar(parent)
	return MakeBar(parent)
end

function SurvivorUI_MeterNewRoll(window)
	MakeRoll(window)
end

function SurvivorUI_MeterShowRoll(window, skip, shown)
	ShowRoll(window, skip, shown)
end

function SurvivorUI_MeterPaintBar(bar, line, top, key)
	PaintBar(bar, line, top, key)
end

-- The pages: { key, title, shared (the game shares it now) } each.
function SurvivorUI_MeterPages()
	local list = {}
	for index = 1, table.getn(VIEWS) do
		table.insert(list, { key = VIEWS[index].key, title = VIEWS[index].title, shared = VIEWS[index].get() ~= nil })
	end
	return list
end

-- A page's lines, its total and its rate; nil while the game does not share it.
function SurvivorUI_MeterLines(key)
	if key == "damage" then
		return DamageLines()
	elseif key == "dps" then
		return DpsOf(DamageLines())
	elseif key == "last" then
		return LastLines()
	end
	for index = 1, table.getn(VIEWS) do
		if VIEWS[index].key == key then
			if not VIEWS[index].get() then
				return nil
			end
			return OtherLines(VIEWS[index].get)
		end
	end
end

-- A page's lines as the fold button has them (Others at the bottom, or not).
function SurvivorUI_MeterFold(lines, key)
	return Folded(lines, key)
end

-- The page the main window shows, whether it shows (a run on, the meter on),
-- and the NOW rate (a page's total climbing over the last seconds).
function SurvivorUI_MeterMainPage()
	return VIEWS[view].key
end

-- How many lines the main window shows (its size follows the screen): the
-- other windows take the same.
function SurvivorUI_MeterLineCount()
	return shownLines
end

function SurvivorUI_MeterShowing()
	return Settings().meter and Running() and true or false
end

function SurvivorUI_MeterNow(key, total)
	if not NowOn() then
		return nil, false
	end
	return NowRate(key, total), true
end

-- The wheel over the meter: down, the first line goes up out of sight and the
-- next comes in at the bottom; up, back. A view chosen starts at the top.
meter.Roll = function(to)
	meter.scrolled = math.max(0, math.min(meter.most or 0, to))
	Draw()
	-- The line under the mouse now holds another source: its card closed,
	-- open again on the next line the mouse goes to.
	GameTooltip:Hide()
	if SurvivorUI_CritCardHide then
		SurvivorUI_CritCardHide()
	end
end
meter.Wheel = function()
	meter.Roll(math.min(meter.scrolled or 0, meter.most or 0) - (arg1 or 0))
end
meter:EnableMouseWheel(true)
meter:SetScript("OnMouseWheel", meter.Wheel)
MakeRoll(meter)

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

-- Where it opens (the Frames & bar tab): at the anchor (nil), at the mouse
-- ("cursor"), or where the game or another addon puts it ("game": nothing
-- moved, and the anchor out of move mode).
local stockDefaultAnchor = GameTooltip_SetDefaultAnchor
if stockDefaultAnchor then
	GameTooltip_SetDefaultAnchor = function(tooltip, parent)
		stockDefaultAnchor(tooltip, parent)
		local place = Settings().tipPlace
		if not tooltip or place == "game" then
			return
		end
		if place == "cursor" then
			tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
		else
			PlaceTipAnchor()
			tooltip:ClearAllPoints()
			tooltip:SetPoint("BOTTOMRIGHT", tipAnchor, "BOTTOMRIGHT", 0, 0)
		end
	end
end

local tipHandle
if SurvivorUI_RegisterMover then
	tipHandle = SurvivorUI_RegisterMover(tipAnchor, "Tooltip", SaveTipAnchor, nil, PlaceTipAnchor)
end

local function HoldTipHandle()
	if tipHandle then
		tipHandle.disabled = Settings().tipPlace ~= nil or nil
	end
end

function SurvivorUI_TooltipPlace()
	return Settings().tipPlace or "anchor"
end

function SurvivorUI_SetTooltipPlace(place)
	Settings().tipPlace = place ~= "anchor" and place or nil
	HoldTipHandle()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	seatedOn = nil
	Fit()
	ApplyGameHud()
	HoldTipHandle()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(meter, "Damage meter", SavePlace, nil, function()
		seatedOn = nil
		Fit()
	end)
end
