-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the experience, and how soon the next level comes.
--
-- The game shares the hero's level and experience in its run (AZS_RUN: lvl,
-- xp the experience into the level, xpn the level's whole). Their pace is
-- measured over the last WINDOW seconds of the run's own clock (t, which
-- stops while paused or choosing a card), the levels gained counted across,
-- and the time to the next level told from it once LEAST seconds are in: an
-- estimate that follows the run as the kills speed up or slow down.
--
-- Shown two ways, each on its own: at the run tracker's foot (Tracker.lua,
-- the time beside the level; Run tracker tab), and as an XP bar of its own,
-- movable (XP bar tab): the level, the bar with the experience's share,
-- marked at every 20%, and under it the time to the next level and the
-- experience a minute. No backing: it sits on the world.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WINDOW = 45               -- seconds of the run the pace is measured over
local LEAST = 10                -- seconds of it before a pace is told
local PURPLE = { 0.58, 0.30, 0.85 }
local MUTED = "|cff9a9a9a"
local NEXT_COLOR = "|cffbf8cff"   -- "Next lv. in", as "Lv. 12" over the bar

------------------------------------------------------------------------------
-- The pace.

local samples = {}              -- { t = run time, gained = experience gained so far }
local last                      -- the run's last reading: t, lvl, xp, xpn
local gained = 0                -- experience gained this run, across its levels
local levelSince                -- the run time the current level began, once seen

local function Sample()
	local run = AZS_RUN
	if not run then
		return
	end
	local t, lvl, xp, xpn = tonumber(run.t), tonumber(run.lvl), tonumber(run.xp), tonumber(run.xpn)
	if not (t and lvl and xp) then
		return
	end
	-- A new run: its clock or its level went back.
	if last and (t < last.t or lvl < last.lvl) then
		samples, last, gained, levelSince = {}, nil, 0, nil
	end
	if last then
		if t == last.t and lvl == last.lvl and xp == last.xp then
			return
		end
		if lvl > last.lvl then
			-- What was left of the last level, and what is in the new one.
			gained = gained + math.max(0, (last.xpn or last.xp) - last.xp) + xp
			levelSince = t
		else
			gained = gained + math.max(0, xp - last.xp)
		end
	end
	last = { t = t, lvl = lvl, xp = xp, xpn = xpn }
	table.insert(samples, { t = t, gained = gained })
	-- The oldest kept is the last one past the window, so the span fills it.
	while samples[2] and t - samples[2].t >= WINDOW do
		table.remove(samples, 1)
	end
end

-- The run's experience now: lvl, xp, xpn, share (0 to 1), perMinute and eta
-- (seconds to the next level) once a pace is known, inLevel once a level up
-- was seen. Nil before the run tells any.
function SurvivorUI_XpEstimate()
	if not last then
		return nil
	end
	local estimate = { lvl = last.lvl, xp = last.xp, xpn = last.xpn }
	estimate.share = (last.xpn and last.xpn > 0) and math.min(1, last.xp / last.xpn) or 0
	local first = samples[1]
	local span = first and (last.t - first.t) or 0
	if span >= LEAST then
		local perSecond = (gained - first.gained) / span
		estimate.perMinute = perSecond * 60
		if perSecond > 0 and last.xpn then
			estimate.eta = math.max(0, last.xpn - last.xp) / perSecond
		end
	end
	if levelSince then
		estimate.inLevel = last.t - levelSince
	end
	return estimate
end

local function Clock(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 3600 then
		return math.floor(seconds / 3600).."h "..math.floor(math.mod(seconds, 3600) / 60).."m"
	end
	return math.floor(seconds / 60)..":"..string.format("%02d", math.mod(seconds, 60))
end

local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(math.floor(value + 0.5))
	end
	return tostring(math.floor(value + 0.5))
end

-- "next in 0:42", for the tracker's level line; "…" while the pace is young.
function SurvivorUI_XpNextText()
	local estimate = SurvivorUI_XpEstimate()
	if not estimate then
		return nil
	end
	if estimate.eta then
		return SurvivorUI_TF("next in {1}", Clock(estimate.eta))
	end
	return SurvivorUI_T("next in ...")
end

local function Running()
	if not (AZS_GetPhase and AZS_RUN) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

------------------------------------------------------------------------------
-- The XP bar of its own (XP bar tab): on for a new install (v3.0.12), off
-- until chosen before.

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local WIDTH = 260

local panel = CreateFrame("Frame", "SurvivorUIXpBar", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(42)
panel:SetMovable(true)
panel:Hide()

local function Line(size, point)
	local text = panel:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, panel, point, 0, 0)
	return text
end

panel.level = Line(11, "TOPLEFT")
panel.amount = Line(10, "TOPRIGHT")

panel.track = panel:CreateTexture(nil, "BORDER")
panel.track:SetTexture(FLAT)
panel.track:SetVertexColor(0.12, 0.10, 0.16, 0.9)
panel.track:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -16)
panel.track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -16)
panel.track:SetHeight(8)

panel.fill = CreateFrame("StatusBar", nil, panel)
panel.fill:SetStatusBarTexture(FLAT)
panel.fill:SetStatusBarColor(PURPLE[1], PURPLE[2], PURPLE[3], 1)
panel.fill:SetMinMaxValues(0, 1)
panel.fill:SetAllPoints(panel.track)

-- A mark at every 20%, over the fill, so it reads past them too.
for step = 1, 4 do
	local mark = panel.fill:CreateTexture(nil, "OVERLAY")
	mark:SetTexture(FLAT)
	mark:SetVertexColor(0, 0, 0, 0.7)
	mark:SetWidth(1)
	mark:SetPoint("TOP", panel.fill, "TOPLEFT", WIDTH * step / 5, 0)
	mark:SetPoint("BOTTOM", panel.fill, "BOTTOMLEFT", WIDTH * step / 5, 0)
end

panel.next = Line(10, "BOTTOMLEFT")
panel.rate = Line(10, "BOTTOMRIGHT")

local function PanelOn()
	return Settings().xpBar == true
end

-- Under the bar, each on its own: the time to the next level, and the
-- experience a minute (one choice before v3.0.37, the time's: off, it keeps
-- both away).
local function EtaOn()
	return Settings().xpBarEta ~= false
end

local function RateOn()
	local settings = Settings()
	if settings.xpBarRate == nil and settings.xpBarEta == false then
		settings.xpBarRate = false
	end
	return settings.xpBarRate ~= false
end

------------------------------------------------------------------------------
-- Luck (asked for 2026-10-26): the hero's luck over the bar's middle, and
-- under the bar a thin ribbon of the next level-up card's odds, a stretch of
-- each rarity's color as wide as its chance, so the rarer colors are seen
-- to grow as the luck and the level do. Hovered, a card of the odds: each
-- kind of pick in its own ribbon.
--
-- The game's own roll (read in its 0.119 exe, game\upgrades.rs): with
-- m = 1 + luck + the level's 1% (30% at most), the weights are Common 60,
-- Uncommon 25m, Rare 10m^2, Epic 4m^3, Legendary m^4, each card rolled on
-- its own. Rings and trinkets roll as the cards do; amulets with half again
-- (m + 0.5); the jewelry of a guardian's hoard or a boss with 0.25 more,
-- a bought cache's without.

local RARITIES = {
	{ name = "Common", color = { 0.62, 0.62, 0.62 } },
	{ name = "Uncommon", color = { 0.12, 1.00, 0.00 } },
	{ name = "Rare", color = { 0.00, 0.44, 0.87 } },
	{ name = "Epic", color = { 0.64, 0.21, 0.93 } },
	{ name = "Legendary", color = { 1.00, 0.50, 0.00 } },
}
local LUCK_COLOR = { 0.35, 0.90, 0.55 }

local function LevelBonus(level)
	return math.min(level * 0.01, 0.3)
end

-- The five rarities' odds (0 to 1) for a roll with the given m.
local function Odds(m)
	local weights = { 60, 25 * m, 10 * m * m, 4 * m * m * m, m * m * m * m }
	local total = 0
	for index = 1, 5 do
		total = total + weights[index]
	end
	for index = 1, 5 do
		weights[index] = weights[index] / total
	end
	return weights
end

-- For others (the odds of a spell card now): Common to Legendary, 0 to 1.
function SurvivorUI_CardOdds(level, luck)
	return Odds(1 + luck + LevelBonus(level))
end

local function Luck()
	return AZS_STATS and tonumber(AZS_STATS.luck)
end

local function LuckOn()
	return Settings().xpBarLuck ~= false
end

-- A ribbon: five stretches side by side on a frame, their widths set later.
local function Ribbon(parent, height)
	local ribbon = CreateFrame("Frame", nil, parent)
	ribbon:SetHeight(height)
	ribbon.parts = {}
	for index = 1, 5 do
		local part = ribbon:CreateTexture(nil, "ARTWORK")
		part:SetTexture(FLAT)
		local color = RARITIES[index].color
		part:SetVertexColor(color[1], color[2], color[3], 1)
		part:SetHeight(height)
		if index == 1 then
			part:SetPoint("LEFT", ribbon, "LEFT", 0, 0)
		else
			part:SetPoint("LEFT", ribbon.parts[index - 1], "RIGHT", 0, 0)
		end
		ribbon.parts[index] = part
	end
	return ribbon
end

local function SetRibbon(ribbon, odds, width)
	for index = 1, 5 do
		-- A stretch of 0 width shows as the whole texture: the least is kept.
		ribbon.parts[index]:SetWidth(math.max(0.01, odds[index] * width))
	end
end

panel.luck = Line(10, "TOP")
panel.ribbon = Ribbon(panel, 3)
panel.ribbon:SetPoint("TOPLEFT", panel.track, "BOTTOMLEFT", 0, -2)
panel.ribbon:SetWidth(WIDTH)

-- What takes the mouse: the bar from its top down to the ribbon.
local hover = CreateFrame("Frame", nil, panel)
hover:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 2)
hover:SetPoint("BOTTOMRIGHT", panel.ribbon, "BOTTOMRIGHT", 0, -3)
hover:EnableMouse(true)
-- The card is its answer to the mouse: no outline round the bar (Hover.lua).
hover.noHoverOutline = true

-- The card: a row for each rarity, in its color, and a column for each kind
-- of pick (the spells, rings and trinkets rolling alike, and the amulets),
-- each odds a bar as long as its chance on a dim track, its number after the
-- track in the rarity's color; then a legendary among a level-up's three
-- cards, where luck comes from, and the hoards. On top the luck as summed,
-- the hero's and the level's, and under it in red that it has no cap.
local CARD_WIDTH = 330
local ROW_TOP, ROW_STEP = -58, 15
local WARNING = { 1.00, 0.36, 0.32 }
local BAR_MAX = 64              -- a bar's length at 100%
local NUMBER_RIGHT = 42         -- a number's right edge, past its track's end
-- Where luck comes from, as the game gives it (0.119: the Gnome's racial
-- line, Initiative's 0.06 a rank of 5, the jewelry by rarity at rank 1).
local SOURCES = {
	{ "Gnome racial", "+20%" },
	{ "Rogue talent: Initiative", "+6% to +30%" },
	{ "Trinket: Mark of the Chosen", "+22% to +72%" },
	{ "Amulet: Pristine Enchanted South Seas Kelp", "+30%" },
	{ "Gear with +luck" },
}
local COLUMNS = {
	{ head = "SPELLS, RINGS, TRINKETS", bonus = 0, x = 84 },
	{ head = "AMULETS", bonus = 0.5, x = 214 },
}
local card = CreateFrame("Frame", "SurvivorUILuckCard", UIParent)
card:SetFrameStrata("TOOLTIP")
card:SetWidth(CARD_WIDTH)
card:Hide()
card.back = card:CreateTexture(nil, "BACKGROUND")
card.back:SetTexture(FLAT)
card.back:SetVertexColor(0.05, 0.05, 0.07, 0.94)
card.back:SetAllPoints(card)
card.edge = card:CreateTexture(nil, "BORDER")
card.edge:SetTexture(FLAT)
card.edge:SetVertexColor(LUCK_COLOR[1] * 0.6, LUCK_COLOR[2] * 0.6, LUCK_COLOR[3] * 0.6, 1)
card.edge:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
card.edge:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
card.edge:SetHeight(2)

local function CardText(size, r, g, b)
	local text = card:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(r or 1, g or 1, b or 1)
	text:SetJustifyH("LEFT")
	return text
end

card.title = CardText(12, LUCK_COLOR[1], LUCK_COLOR[2], LUCK_COLOR[3])
card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -9)
card.cap = CardText(8, WARNING[1], WARNING[2], WARNING[3])
card.cap:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
card.cap:SetText(SurvivorUI_T("No cap: the more luck, the better your odds of a legendary."))

card.heads = {}
for index = 1, table.getn(COLUMNS) do
	local head = CardText(8, 0.65, 0.65, 0.65)
	head:SetText(SurvivorUI_T(COLUMNS[index].head))
	card.heads[index] = head
end

card.rows = {}
for rarity = 1, 5 do
	local row = { cells = {} }
	local y = ROW_TOP - (rarity - 1) * ROW_STEP
	local color = RARITIES[rarity].color
	row.name = CardText(10, color[1], color[2], color[3])
	-- Level with its bars' middle (they hang 3 below the row and are 8 tall).
	row.name:SetPoint("LEFT", card, "TOPLEFT", 10, y - 7)
	row.name:SetText(SurvivorUI_T(RARITIES[rarity].name))
	for index = 1, table.getn(COLUMNS) do
		local cell = {}
		local x = COLUMNS[index].x
		cell.track = card:CreateTexture(nil, "BORDER")
		cell.track:SetTexture(FLAT)
		cell.track:SetVertexColor(color[1], color[2], color[3], 0.16)
		cell.track:SetHeight(8)
		cell.track:SetWidth(BAR_MAX)
		cell.track:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 3)
		cell.bar = card:CreateTexture(nil, "ARTWORK")
		cell.bar:SetTexture(FLAT)
		cell.bar:SetVertexColor(color[1], color[2], color[3], 1)
		cell.bar:SetHeight(8)
		cell.bar:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 3)
		-- The numbers in a column of their own, their points lined up.
		cell.text = CardText(10, color[1], color[2], color[3])
		cell.text:SetPoint("RIGHT", card, "TOPLEFT", x + BAR_MAX + NUMBER_RIGHT, y - 7)
		cell.text:SetJustifyH("RIGHT")
		row.cells[index] = cell
	end
	card.rows[rarity] = row
end

card.three = CardText(9, 0.85, 0.85, 0.85)
-- The amulets' card only: why their odds are better.
card.amulets = CardText(9, 0.85, 0.85, 0.85)
card.amulets:SetText(SurvivorUI_T("An amulet rolls with +50% luck of its own, on top of yours."))

-- Where luck comes from: a line each, its luck on the card's right.
card.sourceHead = CardText(8, 0.65, 0.65, 0.65)
card.sourceHead:SetPoint("TOPLEFT", card.three, "BOTTOMLEFT", 0, -8)
card.sourceHead:SetText(SurvivorUI_T("LUCK FROM"))
card.sources = {}
local above = card.sourceHead
for index = 1, table.getn(SOURCES) do
	local label = CardText(9, 0.85, 0.85, 0.85)
	label:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
	label:SetText(SurvivorUI_T(SOURCES[index][1]))
	if SOURCES[index][2] then
		local value = CardText(9, LUCK_COLOR[1], LUCK_COLOR[2], LUCK_COLOR[3])
		value:SetPoint("TOPRIGHT", label, "TOPLEFT", CARD_WIDTH - 20, 0)
		value:SetJustifyH("RIGHT")
		value:SetText(SOURCES[index][2])
		label.value = value
	end
	card.sources[index] = label
	above = label
end
card.jewelry = CardText(9, 0.6, 0.6, 0.6)
card.jewelry:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
card.jewelry:SetWidth(CARD_WIDTH - 20)
card.jewelry:SetText(SurvivorUI_T("Jewelry gives more stats the better its quality and the higher its rank."))

-- The hoards' own luck (the game adds 0.25 to a guardian's hoard's and a
-- boss's jewelry rolls, none to a bought cache's), a warning of its own.
card.hoard = CardText(9, WARNING[1], WARNING[2], WARNING[3])
card.hoard:SetPoint("TOPLEFT", card.jewelry, "BOTTOMLEFT", 0, -8)
card.hoard:SetWidth(CARD_WIDTH - 20)
card.hoard:SetText(SurvivorUI_T("Guardian hoards and bosses: |cff59e68c+25%|r native luck on their jewelry."))

local function Percent(value)
	return string.format("%.1f%%", value * 100)
end

-- Beside the bar, to read without the mouse (XP bar tab: The odds beside the
-- bar): a legendary's, an epic's and a rare's chance, one under the other in
-- their colors; the spells' and jewelry's on its left, the amulets' on its
-- right (the card's two columns), centered under a title in the luck's green. As
-- numbers, or (XP bar tab, The odds as) each in a small bar of one size, the
-- number inside: filled in its rarity's color as far as the chance goes
-- (full at 40%), or in the run tracker's tag look (a thin border, a dark
-- wash of the color).
local SIDE_ROWS = { 5, 4, 3 }
-- The bars centered under their title, which goes over their middle.
local ODDS_BAR, ODDS_TALL, ODDS_STEP, ODDS_FULL = 76, 13, 14, 0.40
local SIDE_HEADS = { "SPELLS & JEWELRY", "AMULETS" }
local sides = {}
for index = 1, 2 do
	local side = CreateFrame("Frame", nil, panel)
	side:SetWidth(90)
	side:SetHeight(42)
	local leftSide = index == 1
	if leftSide then
		side:SetPoint("TOPRIGHT", panel, "TOPLEFT", -8, 0)
	else
		side:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, 0)
	end
	local justify = leftSide and "RIGHT" or "LEFT"
	local function Text(size, y, color)
		local text = side:CreateFontString(nil, "OVERLAY")
		text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
		text:SetTextColor(color[1], color[2], color[3])
		text:SetJustifyH(justify)
		text:SetPoint("TOP"..justify, side, "TOP"..justify, 0, y)
		return text
	end
	-- The title a little over the bar's top, apart from the legendary's line.
	side.head = Text(7, 2, { 0.35, 0.90, 0.55 })
	side.justify = justify
	side.head:SetText(SurvivorUI_T(SIDE_HEADS[index]))
	side.lines, side.bars = {}, {}
	for row = 1, 3 do
		side.lines[row] = Text(9, -10 - (row - 1) * 11, RARITIES[SIDE_ROWS[row]].color)
		local bar = CreateFrame("Frame", nil, side)
		bar:SetWidth(ODDS_BAR)
		bar:SetHeight(ODDS_TALL)
		bar:SetPoint("TOP", side, "TOP", 0, -11 - (row - 1) * ODDS_STEP)
		bar:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		bar.fill = bar:CreateTexture(nil, "ARTWORK")
		bar.fill:SetTexture(FLAT)
		bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
		bar.fill:SetHeight(ODDS_TALL - 2)
		bar.text = bar:CreateFontString(nil, "OVERLAY")
		bar.text:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
		bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
		bar:Hide()
		side.bars[row] = bar
	end
	side:Hide()
	sides[index] = side
end

local function SidesOn()
	return Settings().xpBarOddsSide == true
end

-- A chance's small bar, in a look ("fill" or "tag").
local function PaintOddsBar(bar, value, color, look)
	bar.text:SetText(Percent(value))
	if look == "fill" then
		bar:SetBackdropColor(0.11, 0.10, 0.13, 0.9)
		bar:SetBackdropBorderColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1)
		-- A stretch of 0 width shows as the whole texture: the least is kept.
		bar.fill:SetWidth(math.max(0.01, math.min(1, value / ODDS_FULL) * (ODDS_BAR - 2)))
		bar.fill:SetVertexColor(color[1], color[2], color[3], 0.75)
		bar.fill:Show()
		bar.text:SetTextColor(1, 1, 1)
	else
		bar:SetBackdropColor(color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 0.9)
		bar:SetBackdropBorderColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1)
		bar.fill:Hide()
		bar.text:SetTextColor(color[1], color[2], color[3])
	end
	bar:Show()
end

local function FillSides(luck, level)
	if not (luck and SidesOn()) then
		sides[1]:Hide()
		sides[2]:Hide()
		return
	end
	local m = 1 + luck + LevelBonus(level)
	local look = Settings().xpBarOddsLook
	local barred = look == "fill" or look == "tag"
	for index = 1, 2 do
		-- The title over the bars' middle, or at the numbers' side.
		local head, justify = sides[index].head, sides[index].justify
		head:ClearAllPoints()
		if barred then
			head:SetJustifyH("CENTER")
			head:SetPoint("TOP", sides[index], "TOP", 0, 2)
		else
			head:SetJustifyH(justify)
			head:SetPoint("TOP"..justify, sides[index], "TOP"..justify, 0, 2)
		end
		local odds = Odds(m + COLUMNS[index].bonus)
		for row = 1, 3 do
			local value = odds[SIDE_ROWS[row]]
			local line, bar = sides[index].lines[row], sides[index].bars[row]
			if barred then
				line:Hide()
				PaintOddsBar(bar, value, RARITIES[SIDE_ROWS[row]].color, look)
			else
				-- The number centered under its title.
				bar:Hide()
				line:SetText(Percent(value))
				line:SetWidth(math.max(head:GetStringWidth(), line:GetStringWidth()))
				line:SetJustifyH("CENTER")
				line:Show()
			end
		end
		sides[index]:Show()
	end
end

-- The card whole (the bar's), or one column only (only = 1, the spells' and
-- jewelry's, or 2, the amulets'), narrower, for the odds beside the bar:
-- the column at the first one's place, the rows as low as the lines over
-- them make them.
local SINGLE_WIDTH = 210
local function Shown(region, on)
	if on then
		region:Show()
	else
		region:Hide()
	end
end

local function FillCard(only)
	card.only = only
	local width = only and SINGLE_WIDTH or CARD_WIDTH
	card:SetWidth(width)
	card.cap:SetWidth(width - 20)
	local luck, estimate = Luck() or 0, SurvivorUI_XpEstimate()
	local level = estimate and estimate.lvl or tonumber(AZS_RUN and AZS_RUN.lvl) or 1
	local m = 1 + luck + LevelBonus(level)
	-- The luck the cards roll with: the hero's, and the level's (1% a level,
	-- 30% at most).
	card.title:SetText(SurvivorUI_TF("Luck: {1} + {2} (from Lv. {3})", string.format("%.0f%%", luck * 100),
		string.format("%.0f%%", LevelBonus(level) * 100), level))
	local rowTop = math.min(ROW_TOP, -(9 + card.title:GetHeight() + 3 + card.cap:GetHeight() + 20))
	for rarity = 1, 5 do
		card.rows[rarity].name:SetPoint("LEFT", card, "TOPLEFT", 10, rowTop - (rarity - 1) * ROW_STEP - 7)
	end
	for index = 1, table.getn(COLUMNS) do
		local on = not only or only == index
		local x = only and COLUMNS[1].x or COLUMNS[index].x
		card.heads[index]:SetPoint("TOPLEFT", card, "TOPLEFT", x, rowTop + 14)
		Shown(card.heads[index], on)
		local odds = Odds(m + COLUMNS[index].bonus)
		for rarity = 1, 5 do
			local cell = card.rows[rarity].cells[index]
			local y = rowTop - (rarity - 1) * ROW_STEP
			cell.track:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 3)
			cell.bar:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 3)
			cell.text:SetPoint("RIGHT", card, "TOPLEFT", x + BAR_MAX + NUMBER_RIGHT, y - 7)
			-- A bar of no width shows as the whole texture: one pixel at least.
			cell.bar:SetWidth(math.max(1, odds[rarity] * BAR_MAX))
			cell.text:SetText(Percent(odds[rarity]))
			Shown(cell.track, on)
			Shown(cell.bar, on)
			Shown(cell.text, on)
		end
	end
	-- Under the rows: the three cards' legendary (not on the amulets' card),
	-- the amulets' note (theirs only); the whole card then where luck comes
	-- from and the hoards.
	local under = rowTop - 5 * ROW_STEP - 6
	local note = only == 2 and card.amulets or card.three
	card.three:SetPoint("TOPLEFT", card, "TOPLEFT", 10, under)
	card.amulets:SetPoint("TOPLEFT", card, "TOPLEFT", 10, under)
	card.three:SetWidth(width - 20)
	card.amulets:SetWidth(width - 20)
	Shown(card.three, only ~= 2)
	Shown(card.amulets, only == 2)
	local none = 1 - Odds(m)[5]
	card.three:SetText(SurvivorUI_TF("A legendary among a level-up's 3 cards: {1} (each rolled on its own)",
		"|cffff8000"..Percent(1 - none * none * none).."|r"))
	local whole = not only
	Shown(card.sourceHead, whole)
	for index = 1, table.getn(card.sources) do
		Shown(card.sources[index], whole)
		if card.sources[index].value then
			Shown(card.sources[index].value, whole)
		end
	end
	Shown(card.jewelry, whole)
	Shown(card.hoard, whole)
	-- A wrapped text is as tall as its lines, as in the confirm box.
	local height = -under + note:GetHeight() + 10
	if whole then
		height = height - 2 + 8 + card.sourceHead:GetHeight()
		for index = 1, table.getn(card.sources) do
			height = height + 2 + card.sources[index]:GetHeight()
		end
		height = height + 2 + card.jewelry:GetHeight() + 8 + card.hoard:GetHeight()
	end
	card:SetHeight(height)
end

hover:SetScript("OnEnter", function()
	FillCard()
	card:ClearAllPoints()
	card:SetPoint("TOP", panel, "BOTTOM", 0, -6)
	card:Show()
end)
hover:SetScript("OnLeave", function()
	card:Hide()
end)

-- Each side's odds answer the mouse with their own card under them, their
-- column only.
for index = 1, 2 do
	local side = sides[index]
	side:EnableMouse(true)
	side.noHoverOutline = true
	side.index = index
	side:SetScript("OnEnter", function()
		FillCard(this.index)
		card:ClearAllPoints()
		if this.index == 1 then
			card:SetPoint("TOPRIGHT", this, "BOTTOMRIGHT", 0, -6)
		else
			card:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -6)
		end
		card:Show()
	end)
	side:SetScript("OnLeave", function()
		card:Hide()
	end)
end

-- The luck and the ribbon, as the run now has them; away with no luck told
-- (a game before AZS_STATS) or switched off (XP bar tab).
local function FillLuck(level)
	local luck = Luck()
	FillSides(luck, level)
	if not (luck and LuckOn()) then
		panel.luck:Hide()
		panel.ribbon:Hide()
		hover:Hide()
		card:Hide()
		return
	end
	-- The hero's luck and the level's, summed: what the cards roll with.
	panel.luck:SetText("|cff59e68c"..SurvivorUI_TF("Luck {1}", string.format("%+.0f%%", (luck + LevelBonus(level)) * 100)).."|r")
	SetRibbon(panel.ribbon, Odds(1 + luck + LevelBonus(level)), WIDTH)
	panel.luck:Show()
	-- The ribbon of the odds under the bar, when chosen (XP bar tab).
	if Settings().xpBarRibbon then
		panel.ribbon:Show()
	else
		panel.ribbon:Hide()
	end
	hover:Show()
	if card:IsShown() then
		FillCard(card.only)
	end
end

local function Fill()
	local estimate = SurvivorUI_XpEstimate()
	if not estimate then
		panel:Hide()
		return
	end
	-- The levels waiting (Store Level-Ups, LevelUp.lua): "Lv. 12 +3".
	local stored = SurvivorUI_StoredLevels and SurvivorUI_StoredLevels() or 0
	panel.level:SetText("|cffbf8cff"..SurvivorUI_TF("Lv. {1}", estimate.lvl).."|r"..(stored > 0 and " |cffffd100+"..stored.."|r" or ""))
	-- How far into the level, as a share (the experience itself, in the
	-- thousands late in a run, ran into the luck over the bar).
	local amount = Short(estimate.xp)
	if estimate.xpn and estimate.xpn > 0 then
		amount = math.floor(estimate.share * 100 + 0.5).."%"
	end
	panel.amount:SetText(amount)
	panel.fill:SetValue(estimate.share)
	FillLuck(estimate.lvl)
	if EtaOn() then
		if estimate.eta then
			-- Its words in the level's light purple, the time white.
			panel.next:SetText(NEXT_COLOR..SurvivorUI_T("Next lv. in").."|r "..Clock(estimate.eta))
		else
			panel.next:SetText(NEXT_COLOR..SurvivorUI_T("Next lv. in ...").."|r")
		end
		panel.next:Show()
	else
		panel.next:Hide()
	end
	if RateOn() then
		panel.rate:SetText(estimate.perMinute and (Short(estimate.perMinute)..MUTED.." "..SurvivorUI_T("XP/min").."|r") or "")
		panel.rate:Show()
	else
		panel.rate:Hide()
	end
	panel:SetHeight((EtaOn() or RateOn()) and 42 or 26)
	panel:Show()
end

-- The pace is measured all the run long, whatever shows it.
local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	if not Running() then
		panel:Hide()
		return
	end
	Sample()
	if PanelOn() then
		Fill()
	else
		panel:Hide()
	end
end)

function SurvivorUI_ToggleXpBar()
	local settings = Settings()
	settings.xpBar = not settings.xpBar
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the XP bar "..(settings.xpBar and "shows." or "is put away."))
end

-- Its place: the top of the screen, in the middle, until moved; once moved,
-- kept by the middle of its top.
local function DefaultPlace()
	panel:SetPoint("TOP", UIParent, "TOP", 0, -24)
end

local function RestorePlace()
	panel:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.xpBarX and db.xpBarTop then
		panel:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.xpBarX, db.xpBarTop)
	else
		DefaultPlace()
	end
end

local function SavePlace()
	local db = Settings()
	db.xpBarX = math.floor(panel:GetLeft() + panel:GetWidth() / 2 + 0.5)
	db.xpBarTop = math.floor(panel:GetTop() + 0.5)
	RestorePlace()
end

DefaultPlace()
if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(panel, "XP bar", SavePlace, nil, function()
		local db = Settings()
		db.xpBarX, db.xpBarTop = nil, nil
		RestorePlace()
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", RestorePlace)
