-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: more damage meter windows (asked for 2026-10-24).
--
-- The main meter's + (Meter.lua) opens another window on a page it does not
-- show: the party's damage in a co-op run, else the healing, the boss fight
-- or the damage, whichever no window shows yet. Up to three more. Each wears
-- the main one's bars (lent by Meter.lua: the same colors, icons, cards and
-- numbers), its title a menu of the pages, a - at its corner to close it.
-- Hold Alt and drag to move one, or move mode ("Damage meter 2" to 4); the
-- wheel rolls its list. Each as big as the main one: its size, and as many
-- lines as it shows. Which are open, their pages and places are kept. They
-- show while the main one does: in a run, the meter on.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local M = SurvivorUI_METER or { WIDTH = 228, BAR_HEIGHT = 18, BAR_GAP = 2, STRIP_TOP = 20, STRIP_HEIGHT = 14, BARS_TOP = 36 }

local MOST = 3                  -- windows besides the main one
local LINES = 6                 -- lines a window shows until the main one's are known
local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local NOW_UP, NOW_DOWN = { 0.45, 0.95, 0.5 }, { 1, 0.6, 0.3 }
-- The page a new window takes: the first of these no window shows.
local PREFER = { "party", "healing", "boss", "damage" }
local EMPTY = { boss = "No boss fight yet.", healing = "No healing yet.", party = "Not in a party.", damage = "No damage yet." }

local windows = {}

-- { [index] = { view = page key, left, top } }, an index a window open.
local function Saved()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.meterWindows = SurvivorUIDB.meterWindows or {}
	return SurvivorUIDB.meterWindows
end

local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function Pages()
	return SurvivorUI_MeterPages and SurvivorUI_MeterPages() or {}
end

local function TitleOf(key)
	for _, page in pairs(Pages()) do
		if page.key == key then
			return SurvivorUI_T(page.title)
		end
	end
	return key
end

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	return text
end

------------------------------------------------------------------------------
-- A window's place: where it was moved to, else left of the main one, each
-- next further left.

local function Place(window)
	window:ClearAllPoints()
	local entry = Saved()[window.index]
	if entry and entry.left and entry.top then
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", entry.left, entry.top)
		return
	end
	local main = getglobal("SurvivorUIMeter")
	if main then
		window:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", -8 - (window.index - 1) * (M.WIDTH + 16), 0)
	else
		window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260 - (window.index - 1) * (M.WIDTH + 16), 40)
	end
end

local function SavePlace(window)
	local entry = Saved()[window.index]
	if entry and window:GetLeft() then
		entry.left = math.floor(window:GetLeft() + 0.5)
		entry.top = math.floor(window:GetTop() + 0.5)
	end
end

------------------------------------------------------------------------------
-- The title's menu: a row a page, the one shown gold, one the game does not
-- share now greyed (still chosen if picked: it shows once shared).

local Draw

local function PaintMenu(window)
	local entry = Saved()[window.index]
	for _, row in pairs(window.menu.rows) do
		local chosen = entry and entry.view == row.key
		row.mark:SetAlpha(chosen and 1 or 0)
		row.wash:SetVertexColor(1, 1, 1, row.hot and 0.08 or 0)
		if chosen then
			row.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		elseif row.hot then
			row.text:SetTextColor(1, 1, 1)
		elseif row.shared then
			row.text:SetTextColor(0.75, 0.75, 0.78)
		else
			row.text:SetTextColor(0.4, 0.4, 0.44)
		end
	end
end

local function OpenMenu(window)
	local menu = window.menu
	local pages = Pages()
	for index = 1, table.getn(pages) do
		local row = menu.rows[index]
		if not row then
			row = CreateFrame("Button", nil, menu)
			row:SetHeight(18)
			row:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - (index - 1) * 18)
			row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -3, -3 - (index - 1) * 18)
			row.wash = row:CreateTexture(nil, "BACKGROUND")
			row.wash:SetTexture(FLAT)
			row.wash:SetAllPoints(row)
			row.mark = row:CreateTexture(nil, "ARTWORK")
			row.mark:SetTexture(FLAT)
			row.mark:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
			row.mark:SetWidth(2)
			row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
			row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
			row.text = Text(row, 10, WHITE)
			row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
			row.window = window
			row:SetScript("OnEnter", function() this.hot = true PaintMenu(this.window) end)
			row:SetScript("OnLeave", function() this.hot = nil PaintMenu(this.window) end)
			row:SetScript("OnClick", function()
				local entry = Saved()[this.window.index]
				if entry then
					entry.view = this.key
					this.window.scrolled = 0
				end
				this.window.menu:Hide()
				Draw(this.window)
			end)
			menu.rows[index] = row
		end
		row.key, row.shared = pages[index].key, pages[index].shared
		row.text:SetText(SurvivorUI_T(pages[index].title))
	end
	menu:SetHeight(6 + table.getn(pages) * 18)
	PaintMenu(window)
	menu:Show()
end

------------------------------------------------------------------------------
-- A window, made the first time it is opened.

local function StripCell(strip)
	local cell = {}
	cell.label = Text(strip, 7, { 0.58, 0.58, 0.64 })
	cell.value = Text(strip, 10, WHITE)
	cell.value:SetPoint("LEFT", cell.label, "RIGHT", 4, 0)
	return cell
end

local function Window(index)
	if windows[index] then
		return windows[index]
	end
	local window = CreateFrame("Frame", "SurvivorUIMeter"..(index + 1), UIParent)
	window.index = index
	window:SetWidth(M.WIDTH + 8)
	window:SetHeight(M.BARS_TOP + 4 + LINES * (M.BAR_HEIGHT + M.BAR_GAP))
	window:SetBackdrop({ bgFile = FLAT })
	window:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window.bars = {}
	window.scrolled = 0
	window.lines = LINES
	window:Hide()

	-- Moved with Alt held, as every piece; the bars lend their drag too.
	window.StartMove = function()
		if SurvivorUI_MoveKeyDown() then
			window:StartMoving()
		end
	end
	window.StopMove = function()
		window:StopMovingOrSizing()
		SavePlace(window)
	end
	window:SetScript("OnDragStart", window.StartMove)
	window:SetScript("OnDragStop", window.StopMove)
	window.Wheel = function()
		local most = window.most or 0
		window.scrolled = math.max(0, math.min(most, math.min(window.scrolled or 0, most) - (arg1 or 0)))
		Draw(window)
		GameTooltip:Hide()
		if SurvivorUI_CritCardHide then
			SurvivorUI_CritCardHide()
		end
	end
	window:EnableMouseWheel(true)
	window:SetScript("OnMouseWheel", window.Wheel)

	-- The title: the page's name and a caret, a menu of the pages.
	local title = CreateFrame("Button", nil, window)
	title:SetPoint("TOPLEFT", window, "TOPLEFT", 2, -2)
	title:SetHeight(17)
	title.text = Text(title, 11, GOLD)
	title.text:SetPoint("LEFT", title, "LEFT", 3, 0)
	title.caret = Text(title, 8, { 0.6, 0.6, 0.6 })
	title.caret:SetText("v")
	title:SetScript("OnClick", function()
		if window.menu:IsShown() then
			window.menu:Hide()
		else
			OpenMenu(window)
		end
	end)
	title:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.92, 0.5) end)
	title:SetScript("OnLeave", function() this.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", window.StartMove)
	title:SetScript("OnDragStop", window.StopMove)
	window.title = title

	window.menu = CreateFrame("Frame", nil, window)
	window.menu:SetFrameStrata("DIALOG")
	window.menu:SetWidth(120)
	window.menu:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	window.menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	window.menu:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
	window.menu:SetBackdropBorderColor(1, 0.82, 0, 0.35)
	window.menu:EnableMouse(true)
	window.menu.rows = {}
	window.menu.away = 0
	window.menu:SetScript("OnUpdate", function()
		if MouseIsOver(this) or MouseIsOver(title) then
			this.away = 0
		else
			this.away = this.away + arg1
			if this.away > 0.6 then
				this:Hide()
			end
		end
	end)
	window.menu:Hide()

	-- Its corner: a - to close it.
	local close = CreateFrame("Button", nil, window)
	close:SetWidth(14)
	close:SetHeight(14)
	close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -3)
	close.text = Text(close, 13, { 0.6, 0.6, 0.6 })
	close.text:SetPoint("CENTER", close, "CENTER", 0, 1)
	close.text:SetText("-")
	close:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 0.45, 0.4)
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(SurvivorUI_T("Close this window"), 1, 1, 1)
		GameTooltip:Show()
	end)
	close:SetScript("OnLeave", function()
		this.text:SetTextColor(0.6, 0.6, 0.6)
		GameTooltip:Hide()
	end)
	close:SetScript("OnClick", function()
		Saved()[window.index] = nil
		window.menu:Hide()
		window:Hide()
		GameTooltip:Hide()
		if window.handle then
			window.handle.disabled = true
		end
	end)

	-- The numbers under the title: NOW (when on), the rate, the total.
	local strip = CreateFrame("Frame", nil, window)
	strip:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -M.STRIP_TOP)
	strip:SetWidth(M.WIDTH)
	strip:SetHeight(M.STRIP_HEIGHT)
	strip.wash = strip:CreateTexture(nil, "BACKGROUND")
	strip.wash:SetTexture(FLAT)
	strip.wash:SetAllPoints(strip)
	strip.wash:SetVertexColor(1, 1, 1, 0.04)
	strip.cells = { StripCell(strip), StripCell(strip), StripCell(strip) }
	window.strip = strip

	window.empty = Text(window, 9, { 0.55, 0.55, 0.6 })
	window.empty:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -M.BARS_TOP - 2)

	if SurvivorUI_RegisterMover then
		window.handle = SurvivorUI_RegisterMover(window, "Damage meter "..(index + 1), function() SavePlace(window) end, nil, function()
			local entry = Saved()[window.index]
			if entry then
				entry.left, entry.top = nil, nil
			end
			Place(window)
		end)
	end
	windows[index] = window
	-- The main meter's font and text size (its card's), on this one too.
	if window.handle and SurvivorUI_WearPieceFont then
		SurvivorUI_WearPieceFont(window.handle)
	end
	Place(window)
	return window
end

-- The strip's cells, as many as shown, each in its share of the width.
local function SetCells(window, cells)
	local strip = window.strip
	local each = M.WIDTH / table.getn(cells)
	for index = 1, 3 do
		local cell = strip.cells[index]
		local data = cells[index]
		cell.label:ClearAllPoints()
		if data then
			cell.label:SetPoint("LEFT", strip, "LEFT", (index - 1) * each + 6, 0)
			cell.label:SetText(SurvivorUI_T(data[1]))
			cell.value:SetText(data[2])
			cell.value:SetTextColor(data[3][1], data[3][2], data[3][3])
			cell.label:Show()
			cell.value:Show()
		else
			cell.label:Hide()
			cell.value:Hide()
		end
	end
end

Draw = function(window)
	local entry = Saved()[window.index]
	if not entry then
		return
	end
	local key = entry.view
	window.title.text:SetText(TitleOf(key))
	local width = window.title.text:GetStringWidth()
	window.title.caret:ClearAllPoints()
	window.title.caret:SetPoint("LEFT", window.title, "LEFT", 3 + width + 4, -1)
	window.title:SetWidth(width + 16)

	local lines, total, rate = nil, 0, 0
	if SurvivorUI_MeterLines then
		lines, total, rate = SurvivorUI_MeterLines(key)
	end
	lines = lines or {}
	local unit = key == "healing" and "HPS" or "DPS"
	local now, nowOn = nil, false
	if SurvivorUI_MeterNow then
		now, nowOn = SurvivorUI_MeterNow(key, total or 0)
	end
	if nowOn then
		SetCells(window, {
			{ "NOW", now and Short(now) or "...", not now and WHITE or (now >= (rate or 0) and NOW_UP or NOW_DOWN) },
			{ unit, Short(rate or 0), GOLD },
			{ "TOTAL", Short(total or 0), WHITE },
		})
	else
		SetCells(window, { { unit, Short(rate or 0), GOLD }, { "TOTAL", Short(total or 0), WHITE } })
	end
	if table.getn(lines) == 0 then
		window.empty:SetText(SurvivorUI_T(EMPTY[key] or ""))
		window.empty:Show()
	else
		window.empty:Hide()
	end

	local shown = window.lines or LINES
	window.most = math.max(0, table.getn(lines) - shown)
	local skip = math.min(window.scrolled or 0, window.most)
	local count = math.min(shown, table.getn(lines) - skip)
	local top = count > 0 and lines[1].dmg or 0
	for index = 1, count do
		local bar = window.bars[index]
		if not bar and SurvivorUI_MeterNewBar then
			bar = SurvivorUI_MeterNewBar(window)
			if window.handle and SurvivorUI_WearPieceFont then
				SurvivorUI_WearPieceFont(window.handle)
			end
			window.bars[index] = bar
		end
		if bar then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -M.BARS_TOP - (index - 1) * (M.BAR_HEIGHT + M.BAR_GAP))
			SurvivorUI_MeterPaintBar(bar, lines[index + skip], top, key)
		end
	end
	for index = count + 1, table.getn(window.bars) do
		window.bars[index]:Hide()
		window.bars[index].ability = nil
	end
end

------------------------------------------------------------------------------
-- The main meter's +: another window on a page no window shows.

local function Shown(key)
	if SurvivorUI_MeterMainPage and SurvivorUI_MeterMainPage() == key then
		return true
	end
	for _, entry in pairs(Saved()) do
		if entry.view == key then
			return true
		end
	end
	return false
end

function SurvivorUI_MeterAddWindow()
	local saved = Saved()
	local index
	for each = 1, MOST do
		if not saved[each] and not index then
			index = each
		end
	end
	if not index then
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: three more meter windows at most; close one with its - first.")
		return
	end
	-- The first preferred page the game shares and no window shows; else any
	-- no window shows; else the healing.
	local shared = {}
	for _, page in pairs(Pages()) do
		shared[page.key] = page.shared
	end
	local view
	for _, key in pairs(PREFER) do
		if not view and shared[key] and not Shown(key) then
			view = key
		end
	end
	for _, key in pairs(PREFER) do
		if not view and not Shown(key) then
			view = key
		end
	end
	saved[index] = { view = view or "healing" }
	local window = Window(index)
	window.scrolled = 0
	if window.handle then
		window.handle.disabled = nil
	end
	Place(window)
	window:Show()
	Draw(window)
end

------------------------------------------------------------------------------
-- Four times a second: each open window shown while the main one is, drawn,
-- at the main one's size.

local wait = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.25 then
		return
	end
	wait = 0
	if not SurvivorUIDB then
		return
	end
	local showing = SurvivorUI_MeterShowing and SurvivorUI_MeterShowing()
	local scale = SurvivorUI_PartScale and SurvivorUI_PartScale("meter") or 1
	local saved = Saved()
	for index = 1, MOST do
		local entry = saved[index]
		if entry then
			local window = Window(index)
			if window.handle then
				window.handle.disabled = nil
			end
			if window:GetScale() ~= scale then
				window:SetScale(scale)
				Place(window)
			end
			-- As many lines as the main window, so as tall.
			local lines = SurvivorUI_MeterLineCount and SurvivorUI_MeterLineCount() or LINES
			if window.lines ~= lines then
				window.lines = lines
				window:SetHeight(M.BARS_TOP + 4 + lines * (M.BAR_HEIGHT + M.BAR_GAP))
			end
			if showing then
				window:Show()
				Draw(window)
			elseif window:IsShown() then
				window:Hide()
			end
		elseif windows[index] then
			windows[index]:Hide()
			if windows[index].handle then
				windows[index].handle.disabled = true
			end
		end
	end
end)
