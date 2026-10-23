-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the options panel, /sui opt (or the minimap button).
--
-- A window with a column of tabs on the left, in five groups, each tab in a
-- color of its own, and the tab's page on the right. General: Global (the
-- whole addon's font, color and size), Modules (each part on or off as a
-- whole), Layout. Then a tab for each panel, with the same head (its switch,
-- the same as in Modules; Back to its place; its size) and its own settings: Run
-- (Run tracker, Kill pace, Boss bars, Kills & gold, XP bar, Loot list),
-- Combat (Combat text, Damage meter, This Run, Biggest Crits, Counters),
-- Character (Build list, Character pane, Stats panel, Jewelry), Interface
-- (Frames & bar, Chat, Nameplates). Before, by subject:
--   Global       the whole addon's font, color and size
--   Modules      each part on or off as a whole
--   Panels       every panel on or off
--   Run tracker  the tracker under the minimap: bosses, guardians, elites
--   Kill pace    the orb by the tracker's clock
--   Combat text  how the combat numbers show, or none at all
--   Counters     the numbers over the spells' buttons: DoTs, fears, totems
--   Nameplates   Survivor Plates: on every enemy, the dangerous ones, or none
--   Frames & bar the health numbers on the frames, the action bar's looks
--   Character    the pane's size, where the stats show, which this class keeps
--   Size         each part's own size, in sections
--   Layout       the frames joined to the bar, resets
-- Most things act at once. Move UI, at the top beside each page's title,
-- unlocks every piece over a grid; each tab's own pieces can be dragged while
-- it is open, so one can play while setting them. Save & Close at the bottom
-- (Reload & Close while a look waits for a reload), or Escape, closes the
-- window; the - beside the x minimizes it to a bar of three buttons.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH, HEIGHT = 640, 740
local SIDEBAR = 150
local PAGE_X = SIDEBAR + 18               -- the pages' left edge
local PAGE_WIDTH = WIDTH - PAGE_X - 18
local ROW = 20
local MUTED = { 0.6, 0.6, 0.65 }
local TEXT = { 0.9, 0.9, 0.92 }
-- The addon's own color, the class's: the title and the Global page wear it.
-- What takes it once, as it is made, is painted again when it changes.
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }
local accented = {}

local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function Call(name, argument)
	return function()
		local command = getglobal(name)
		if command then
			command(argument)
		end
	end
end

local function OnUnlessOff(key)
	return function() return DB()[key] ~= false end
end

local function OnlyIfOn(key)
	return function() return DB()[key] == true end
end

-- A setting on unless false, switched.
local function Flip(key)
	return function() DB()[key] = DB()[key] == false end
end

-- A look the addon gives the game's interface (SurvivorUI_Feature): most wait
-- for a reload.
local needsReload = false

local function FeatureOn(key)
	return function() return not SurvivorUI_Feature or SurvivorUI_Feature(key) end
end

local function FeatureToggle(key, live)
	return function()
		if SurvivorUI_SetFeature and SurvivorUI_Feature then
			SurvivorUI_SetFeature(key, not SurvivorUI_Feature(key))
			if not live then
				needsReload = true
			end
		end
	end
end

local function PlatesThere()
	return SlashCmdList and SlashCmdList["SURVIVORPLATES"] ~= nil
end

local function Plates(command)
	if PlatesThere() then
		SlashCmdList["SURVIVORPLATES"](command)
	end
end

------------------------------------------------------------------------------
-- The window.

local panel = CreateFrame("Frame", "SurvivorUIOptions", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(HEIGHT)
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
-- A fifth smaller than its layout (the type a point larger to make up for
-- it), at a UI Scale of 1; FitWindow sets it as the window opens.
panel:SetScale(0.8)

-- The window's size: the same share of the screen's height whatever the
-- game's UI Scale (the screen counts more of UIParent's units as the scale
-- shrinks: at 0.64 the window stood a third smaller and hard to read,
-- 2026-10-23), times the Whole interface size (0.9, its default, gives the
-- size it always had at a UI Scale of 1), never past the screen's height.
local WINDOW_SHARE = HEIGHT * 0.8 / 768

local function WindowScale()
	local whole = SurvivorUI_GetScale and SurvivorUI_GetScale() or 0.9
	local share = math.max(0.55, math.min(0.95, WINDOW_SHARE * whole / 0.9))
	return GetScreenHeight() * share / HEIGHT
end

-- A frame of the options to that size, its middle kept where it was.
local function FitWindow(frame)
	local scale = WindowScale()
	if math.abs((frame:GetScale() or 1) - scale) < 0.005 then
		return
	end
	local x, y = frame:GetCenter()
	local before = frame:GetEffectiveScale()
	frame:SetScale(scale)
	if x and y then
		local after = frame:GetEffectiveScale()
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * before / after, y * before / after)
	end
end
panel:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
panel:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:EnableMouse(true)
panel:SetMovable(true)
if panel.SetClampedToScreen then
	panel:SetClampedToScreen(true)
end
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
panel:Hide()
-- Escape closes it, as it does the game's own windows.
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUIOptions")
end

local function Text(parent, size, color, flags)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + 1 + FONT_BUMP, flags or "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	if color == ACCENT then
		table.insert(accented, function() text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
	end
	return text
end

local function Fill(parent, layer, r, g, b, a)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(FLAT)
	texture:SetVertexColor(r, g, b, a)
	return texture
end

-- The sidebar: a darker strip down the left.
local sidebar = Fill(panel, "BACKGROUND", 0.03, 0.03, 0.045, 1)
sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
sidebar:SetWidth(SIDEBAR)
local sideEdge = Fill(panel, "BORDER", 1, 1, 1, 0.06)
sideEdge:SetPoint("TOPLEFT", panel, "TOPLEFT", SIDEBAR + 1, -1)
sideEdge:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", SIDEBAR + 1, 1)
sideEdge:SetWidth(1)

local title = Text(panel, 15, ACCENT)
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
title:SetText("Survivor UI")

local version = Text(panel, 9, MUTED)
version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
local versionNumber = GetAddOnMetadata and GetAddOnMetadata("SurvivorUI", "Version")
version:SetText(versionNumber and ("v"..versionNumber) or "")

-- A square button at the window's top right: filled and edged in its color,
-- brighter under the mouse, its sign in white.
local function CornerButton(sign, color, lift)
	local button = CreateFrame("Button", nil, panel)
	button:SetWidth(22)
	button:SetHeight(22)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.text = Text(button, 12, { 1, 1, 1 })
	button.text:SetPoint("CENTER", button, "CENTER", 0, lift or 0)
	button.text:SetText(sign)
	button.color = color
	function button:Light(hot)
		local fill = hot and 0.8 or 0.45
		self:SetBackdropColor(self.color[1] * fill, self.color[2] * fill, self.color[3] * fill, 1)
		if hot then
			self:SetBackdropBorderColor(1, 1, 1, 1)
		else
			self:SetBackdropBorderColor(self.color[1], self.color[2], self.color[3], 0.9)
		end
	end
	button:Light(false)
	button:SetScript("OnEnter", function() this:Light(true) end)
	button:SetScript("OnLeave", function() this:Light(false) end)
	return button
end

local close = CornerButton("x", { 0.95, 0.32, 0.28 }, 1)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
close:SetScript("OnClick", function() panel:Hide() end)

------------------------------------------------------------------------------
-- Pages and their tabs.

local TABS = {
	{ group = "General" },
	{ key = "global", label = "Global", color = ACCENT },
	{ key = "modules", label = "Modules", color = { 0.95, 0.80, 0.35 } },
	{ key = "layout", label = "Layout", color = { 0.25, 0.85, 0.80 } },
	{ group = "Run" },
	{ key = "tracker", label = "Run tracker", color = { 0.30, 0.82, 0.40 } },
	{ key = "pace", label = "Kill pace", color = { 0.78, 0.95, 0.30 } },
	{ key = "bosses", label = "Boss bars", color = { 0.95, 0.45, 0.35 } },
	{ key = "tally", label = "Kills & gold", color = { 1.00, 0.82, 0.30 } },
	{ key = "xpbar", label = "XP bar", color = { 0.72, 0.45, 1.00 } },
	{ key = "levelup", label = "Level Up!", color = { 1.00, 0.86, 0.30 } },
	{ key = "loot", label = "Loot list", color = { 0.55, 0.75, 1.00 } },
	{ key = "history", label = "Run History", color = { 0.82, 0.62, 1.00 } },
	{ group = "Combat" },
	{ key = "combat", label = "Combat text", color = { 1.00, 0.38, 0.32 } },
	{ key = "meter", label = "Damage meter", color = { 1.00, 0.58, 0.25 } },
	{ key = "run", label = "This Run", color = { 0.45, 0.60, 1.00 } },
	{ key = "crits", label = "Biggest Crits", color = { 1.00, 0.76, 0.10 } },
	{ key = "counters", label = "Counters", color = { 0.40, 0.92, 0.70 } },
	{ key = "summons", label = "Summons", color = { 0.62, 0.42, 0.95 } },
	{ key = "party", label = "Party", color = { 0.45, 0.78, 1.00 } },
	{ group = "Character" },
	{ key = "build", label = "Build list", color = { 0.45, 0.85, 1.00 } },
	{ key = "character", label = "Character pane", color = { 1.00, 0.50, 0.70 } },
	{ key = "stats", label = "Stats panel", color = { 0.95, 0.62, 0.88 } },
	{ key = "jewelry", label = "Jewelry", color = { 0.92, 0.76, 0.45 } },
	{ group = "Interface" },
	{ key = "units", label = "Frames & bar", color = { 1.00, 0.62, 0.25 } },
	{ key = "minimap", label = "Minimap", color = { 0.55, 0.82, 0.40 } },
	{ key = "chat", label = "Chat", color = { 0.60, 0.80, 0.95 } },
	{ key = "tooltips", label = "Tooltips", color = { 0.90, 0.86, 0.62 } },
	{ key = "plates", label = "Nameplates", color = { 0.70, 0.55, 1.00 } },
}

local pages, tabButtons, widgets = {}, {}, {}
local current

local function RefreshAll()
	for index = 1, table.getn(widgets) do
		widgets[index]:Refresh()
	end
end

-- What goes, or goes back to default, asked first in the addon's one box
-- (Confirm.lua): once, or with a word typed (word).
local function Asked(title, text, yes, action, word)
	return function()
		local function Done()
			action()
			RefreshAll()
		end
		if SurvivorUI_Confirm then
			SurvivorUI_Confirm({ title = title, text = text, yes = yes, word = word, onYes = Done })
		else
			Done()
		end
	end
end

-- Each tab's pieces, movable while it is open (Mover.lua), by their names in
-- move mode; the tabs left out move none (Move UI moves every piece).
local TAB_PIECES = {
	tracker = { "Run tracker", "Guardians" },
	bosses = { "Boss bars" },
	tally = { "Kills and gold line" },
	xpbar = { "XP bar" },
	levelup = { "Level Up!" },
	loot = { "Loot list" },
	combat = { "Damage numbers", "Crit numbers", "Damage taken", "Healing", "New best crit" },
	meter = { "Damage meter" },
	party = { "Party frames", "Revive bar" },
	run = { "This Run" },
	crits = { "Biggest Crits" },
	build = { "Build list" },
	character = { "Character pane" },
	stats = { "Stats" },
	units = { "Player frame", "Target frame", "Buffs" },
	minimap = { "Minimap", "Minimap button" },
	chat = { "Chat" },
}

-- The Character pane tab opens the character pane, to see what it sets; one
-- it opened closes again as the tab is left.
local paneOpenedHere

local function CharacterPaneFor(key)
	local pane = getglobal("CharacterFrame")
	if not pane then
		return
	end
	if key == "character" then
		if not pane:IsShown() and ToggleCharacter then
			ToggleCharacter("PaperDollFrame")
			paneOpenedHere = true
		end
	elseif paneOpenedHere then
		paneOpenedHere = nil
		if pane:IsShown() and HideUIPanel then
			HideUIPanel(pane)
		end
	end
end

local function ShowPage(key)
	current = key
	if SurvivorUI_SetMoveFocus then
		SurvivorUI_SetMoveFocus(TAB_PIECES[key])
	end
	CharacterPaneFor(key)
	for _, tab in pairs(TABS) do
		if tab.key then
			local page, button = pages[tab.key], tabButtons[tab.key]
			if tab.key == key then
				page:Show()
			else
				page:Hide()
			end
			button:Refresh()
		end
	end
	RefreshAll()
end

-- The sidebar from its top down: a group's name over its tabs.
local TAB_TOP, TAB_HEIGHT, TAB_STEP, GROUP_STEP = -54, 19, 20, 18
local tabY = TAB_TOP
for index = 1, table.getn(TABS) do
	local tab = TABS[index]
	if tab.group then
		local groupTitle = Text(panel, 8, MUTED)
		groupTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, tabY - 6)
		groupTitle:SetText(string.upper(tab.group))
		tabY = tabY - GROUP_STEP
	else
		local page = CreateFrame("Frame", nil, panel)
		page:SetPoint("TOPLEFT", panel, "TOPLEFT", PAGE_X, -16)
		page:SetWidth(PAGE_WIDTH)
		page:SetHeight(HEIGHT - 70)
		page.color = tab.color
		page.y = 0
		page:Hide()
		pages[tab.key] = page

		-- The tab: its name, a bar of its color at the left, a wash when chosen.
		local button = CreateFrame("Button", nil, panel)
		button:SetWidth(SIDEBAR - 12)
		button:SetHeight(TAB_HEIGHT)
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, tabY)
		tabY = tabY - TAB_STEP
		button.wash = Fill(button, "BACKGROUND", tab.color[1], tab.color[2], tab.color[3], 0)
		button.wash:SetAllPoints(button)
		button.bar = Fill(button, "BORDER", tab.color[1], tab.color[2], tab.color[3], 1)
		if tab.color == ACCENT then
			local bar = button.bar
			table.insert(accented, function() bar:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
		end
		button.bar:SetWidth(3)
		button.bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
		button.bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
		button.label = Text(button, 11, TEXT)
		button.label:SetPoint("LEFT", button, "LEFT", 12, 0)
		button.label:SetText(tab.label)
		button.key = tab.key
		button.color = tab.color
		function button:Refresh()
			local chosen = current == self.key
			local c = self.color
			self.wash:SetVertexColor(c[1], c[2], c[3], chosen and 0.16 or (self.hot and 0.07 or 0))
			self.bar:SetAlpha(chosen and 1 or 0.45)
			if chosen then
				self.label:SetTextColor(c[1], c[2], c[3])
			elseif self.hot then
				self.label:SetTextColor(1, 1, 1)
			else
				self.label:SetTextColor(TEXT[1] * 0.85, TEXT[2] * 0.85, TEXT[3] * 0.85)
			end
		end
		button:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		button:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		button:SetScript("OnClick", function() ShowPage(this.key) end)
		tabButtons[tab.key] = button
	end
end

------------------------------------------------------------------------------
-- The pieces a page is made of. Each goes under the last one (page.y).

-- How many lines a text wraps to at a width: measured in the face it is made
-- in, with room to spare for a wider global font.
local function Lines(text, width)
	return math.max(1, math.ceil(text:GetStringWidth() / (width * 0.9)))
end

local function Header(page, text, note)
	local header = Text(page, 13, page.color)
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	header:SetText(text)
	local rule = Fill(page, "ARTWORK", page.color[1], page.color[2], page.color[3], 0.35)
	if page.color == ACCENT then
		table.insert(accented, function() rule:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.35) end)
	end
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 19)
	rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page.y - 19)
	page.y = page.y - 27
	if note then
		local hint = Text(page, 9, MUTED)
		hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
		hint:SetWidth(PAGE_WIDTH)
		hint:SetJustifyH("LEFT")
		hint:SetText(note)
		page.y = page.y - 13 * Lines(hint, PAGE_WIDTH) - 6
	end
end

-- A section's title: small capitals in the page's color, over a faint line
-- across the page.
local function Subheader(page, text)
	page.y = page.y - 8
	local header = Text(page, 9, page.color)
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	header:SetText(string.upper(text))
	local rule = Fill(page, "ARTWORK", page.color[1], page.color[2], page.color[3], 0.15)
	if page.color == ACCENT then
		table.insert(accented, function() rule:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.15) end)
	end
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 14)
	rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page.y - 14)
	page.y = page.y - 20
	return header
end

-- Grey words across the page, as many lines as they take.
local function Note(page, text)
	local hint = Text(page, 9, MUTED)
	hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	hint:SetWidth(PAGE_WIDTH)
	hint:SetJustifyH("LEFT")
	hint:SetText(text)
	page.y = page.y - 13 * Lines(hint, PAGE_WIDTH) - 4
	return hint
end

-- A check: a square with a mark in the page's color when on (it reads in any
-- color, a priest's white too), and its label; a note in grey beside it, or
-- under it when it does not fit.
local function Check(page, label, isOn, toggle, note)
	local check = CreateFrame("Button", nil, page)
	check:SetWidth(PAGE_WIDTH)
	check:SetHeight(ROW)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	local color = page.color

	check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
	check.edge:SetWidth(13)
	check.edge:SetHeight(13)
	check.edge:SetPoint("TOPLEFT", check, "TOPLEFT", 2, -3)
	check.box = Fill(check, "ARTWORK", 0.06, 0.06, 0.08, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.mark = Fill(check, "OVERLAY", 1, 1, 1, 0)
	check.mark:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 3, -3)
	check.mark:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -3, 3)

	check.label = Text(check, 11, TEXT)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 9, 0)
	check.label:SetText(label)
	if note then
		check.note = Text(check, 9, MUTED)
		check.note:SetText(note)
		local room = PAGE_WIDTH - 24 - check.label:GetStringWidth() - 8
		if check.note:GetStringWidth() < room * 0.9 then
			check.note:SetPoint("LEFT", check.label, "RIGHT", 8, 0)
		else
			check.note:SetPoint("TOPLEFT", check.label, "BOTTOMLEFT", 0, -3)
			check.note:SetWidth(PAGE_WIDTH - 24)
			check.note:SetJustifyH("LEFT")
			check:SetHeight(ROW + 13 * Lines(check.note, PAGE_WIDTH - 24))
		end
	end

	check:SetScript("OnClick", function()
		toggle()
		RefreshAll()
	end)
	check:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
	check:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
	function check:Refresh()
		local on = isOn()
		if on then
			self.edge:SetVertexColor(color[1], color[2], color[3], 1)
			self.mark:SetVertexColor(color[1], color[2], color[3], 1)
		else
			self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
			self.mark:SetVertexColor(1, 1, 1, 0)
		end
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		else
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
	table.insert(widgets, check)
	page.y = page.y - check:GetHeight()
	return check
end

-- A choice of one among several: a square ring with a small dot in the
-- page's color, each option with a note under it, wrapped as it needs.
local function Choice(page, options, get, set)
	-- In order: pairs() walks a table in no set order in this client.
	for index = 1, table.getn(options) do
		local option = options[index]
		local value = option[1]
		local row = CreateFrame("Button", nil, page)
		row:SetWidth(PAGE_WIDTH)
		row:SetHeight(ROW)
		row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
		local color = page.color

		row.ring = Fill(row, "BORDER", 0.3, 0.3, 0.35, 1)
		row.ring:SetWidth(13)
		row.ring:SetHeight(13)
		row.ring:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
		-- A ring: the edge, a dark inside, the dot in the middle.
		row.inner = Fill(row, "ARTWORK", 0.05, 0.05, 0.07, 1)
		row.inner:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 1, -1)
		row.inner:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -1, 1)
		row.dot = Fill(row, "OVERLAY", 0, 0, 0, 1)
		row.dot:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 4, -4)
		row.dot:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -4, 4)

		row.label = Text(row, 11, TEXT)
		row.label:SetPoint("TOPLEFT", row.ring, "TOPRIGHT", 9, 0)
		row.label:SetText(option[2])
		if option[3] then
			row.note = Text(row, 9, MUTED)
			row.note:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
			row.note:SetWidth(PAGE_WIDTH - 26)
			row.note:SetJustifyH("LEFT")
			row.note:SetText(option[3])
			row:SetHeight(20 + 13 * Lines(row.note, PAGE_WIDTH - 26))
		end

		row:SetScript("OnClick", function()
			set(value)
			RefreshAll()
		end)
		row:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		row:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function row:Refresh()
			local chosen = get() == value
			self.ring:SetVertexColor(chosen and color[1] or 0.3, chosen and color[2] or 0.3, chosen and color[3] or 0.35, 1)
			self.dot:SetVertexColor(color[1], color[2], color[3], chosen and 1 or 0)
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif chosen then
				self.label:SetTextColor(color[1], color[2], color[3])
			else
				self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			end
		end
		table.insert(widgets, row)
		page.y = page.y - row:GetHeight() - 2
	end
end

-- A choice in one row: an optional label on the left, then each option's ring
-- and words side by side.
local function Inline(page, label, options, get, set)
	local color = page.color
	local x = 0
	if label then
		local text = Text(page, 10, TEXT)
		text:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 3)
		text:SetText(label)
		x = 140
	end
	for index = 1, table.getn(options) do
		local option = options[index]
		local value = option[1]
		local row = CreateFrame("Button", nil, page)
		row:SetHeight(ROW)
		row:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		row.ring = Fill(row, "BORDER", 0.3, 0.3, 0.35, 1)
		row.ring:SetWidth(13)
		row.ring:SetHeight(13)
		row.ring:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
		row.inner = Fill(row, "ARTWORK", 0.05, 0.05, 0.07, 1)
		row.inner:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 1, -1)
		row.inner:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -1, 1)
		row.dot = Fill(row, "OVERLAY", 0, 0, 0, 1)
		row.dot:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 4, -4)
		row.dot:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -4, 4)
		row.label = Text(row, 10, TEXT)
		row.label:SetPoint("TOPLEFT", row.ring, "TOPRIGHT", 6, 0)
		row.label:SetText(option[2])
		local width = 2 + 13 + 6 + row.label:GetStringWidth() + 18
		row:SetWidth(width)
		x = x + width
		row:SetScript("OnClick", function()
			set(value)
			RefreshAll()
		end)
		row:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		row:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function row:Refresh()
			local chosen = get() == value
			self.ring:SetVertexColor(chosen and color[1] or 0.3, chosen and color[2] or 0.3, chosen and color[3] or 0.35, 1)
			self.dot:SetVertexColor(color[1], color[2], color[3], chosen and 1 or 0)
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif chosen then
				self.label:SetTextColor(color[1], color[2], color[3])
			else
				self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			end
		end
		table.insert(widgets, row)
	end
	page.y = page.y - ROW - 2
end

-- Checks in one row, side by side: { label, isOn, toggle } each.
local function InlineChecks(page, items, label)
	local color = page.color
	local x, gap = 0, 22
	if label then
		local text = Text(page, 10, TEXT)
		text:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 3)
		text:SetText(label)
		x, gap = 140, 12
	end
	for index = 1, table.getn(items) do
		local item = items[index]
		local isOn, toggle = item[2], item[3]
		local check = CreateFrame("Button", nil, page)
		check:SetHeight(ROW)
		check:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
		check.edge:SetWidth(13)
		check.edge:SetHeight(13)
		check.edge:SetPoint("TOPLEFT", check, "TOPLEFT", 2, -3)
		check.box = Fill(check, "ARTWORK", 0.06, 0.06, 0.08, 1)
		check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
		check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
		check.mark = Fill(check, "OVERLAY", 1, 1, 1, 0)
		check.mark:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 3, -3)
		check.mark:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -3, 3)
		check.label = Text(check, 11, TEXT)
		check.label:SetPoint("LEFT", check.edge, "RIGHT", 9, 0)
		check.label:SetText(item[1])
		local width = 2 + 13 + 9 + check.label:GetStringWidth() + gap
		check:SetWidth(width)
		x = x + width
		check:SetScript("OnClick", function()
			toggle()
			RefreshAll()
		end)
		check:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		check:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function check:Refresh()
			local on = isOn()
			if on then
				self.edge:SetVertexColor(color[1], color[2], color[3], 1)
				self.mark:SetVertexColor(color[1], color[2], color[3], 1)
			else
				self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
				self.mark:SetVertexColor(1, 1, 1, 0)
			end
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif on then
				self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			else
				self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
		end
		table.insert(widgets, check)
	end
	page.y = page.y - ROW
end

-- A row of color swatches after a label: {{key, name, {r, g, b} or nil for
-- the class's color}, ...}; the chosen one in a white edge, the name as a
-- tooltip.
local function Swatches(page, label, colors, get, set)
	local text = Text(page, 10, TEXT)
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 3)
	text:SetText(label)
	local x = 140
	for index = 1, table.getn(colors) do
		local entry = colors[index]
		local key, name, color = entry[1], entry[2], entry[3]
		if not color then
			local _, class = UnitClass("player")
			local r, g, b = 1, 0.82, 0
			if class and SurvivorUI_ClassColor then
				r, g, b = SurvivorUI_ClassColor(class)
			end
			color = { r, g, b }
		end
		local swatch = CreateFrame("Button", nil, page)
		swatch:SetWidth(18)
		swatch:SetHeight(ROW)
		swatch:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		swatch.edge = Fill(swatch, "BORDER", 0.3, 0.3, 0.35, 1)
		swatch.edge:SetWidth(16)
		swatch.edge:SetHeight(16)
		swatch.edge:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, -2)
		swatch.fill = Fill(swatch, "ARTWORK", color[1], color[2], color[3], 1)
		swatch.fill:SetPoint("TOPLEFT", swatch.edge, "TOPLEFT", 2, -2)
		swatch.fill:SetPoint("BOTTOMRIGHT", swatch.edge, "BOTTOMRIGHT", -2, 2)
		x = x + 22
		swatch:SetScript("OnClick", function()
			set(key)
			RefreshAll()
		end)
		swatch:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(name, 1, 1, 1)
			GameTooltip:Show()
		end)
		swatch:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		function swatch:Refresh()
			local chosen = get() == key
			if chosen then
				self.edge:SetVertexColor(1, 1, 1, 1)
			elseif self.hot then
				self.edge:SetVertexColor(0.7, 0.7, 0.75, 1)
			else
				self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
			end
			self.fill:SetAlpha((chosen or self.hot) and 1 or 0.7)
		end
		table.insert(widgets, swatch)
	end
	page.y = page.y - ROW
end

-- A slider: its label, a flat track filled in the page's color up to the
-- thumb, and the value on the right. set() runs as it moves.
local function Slider(page, label, low, high, step, get, set, format)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(PAGE_WIDTH)
	holder:SetHeight(20)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	local color = page.color

	holder.label = Text(holder, 10, TEXT)
	holder.label:SetPoint("LEFT", holder, "LEFT", 2, 0)
	holder.label:SetText(label)

	holder.value = Text(holder, 10, color)
	holder.value:SetPoint("RIGHT", holder, "RIGHT", -2, 0)

	local slider = CreateFrame("Slider", nil, holder)
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(PAGE_WIDTH - 190)
	slider:SetHeight(14)
	slider:SetPoint("LEFT", holder, "LEFT", 140, 0)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseDown", function() panel.sliding = true end)
	slider:SetScript("OnMouseUp", function() panel.sliding = nil end)

	slider.track = Fill(slider, "BACKGROUND", 0.14, 0.14, 0.18, 1)
	slider.track:SetHeight(4)
	slider.track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	slider.track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	slider.fill = Fill(slider, "BORDER", color[1], color[2], color[3], 0.8)
	if color == ACCENT then
		local fill = slider.fill
		table.insert(accented, function() fill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8) end)
	end
	slider.fill:SetHeight(4)
	slider.fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	local thumb = Fill(slider, "OVERLAY", 1, 1, 1, 1)
	thumb:SetWidth(8)
	thumb:SetHeight(14)
	slider:SetThumbTexture(thumb)

	local function Show(value)
		holder.value:SetText(type(format) == "function" and format(value) or string.format(format or "%.2f", value))
		local share = (value - low) / (high - low)
		slider.fill:SetWidth(math.max(1, (slider:GetWidth() - 8) * share + 4))
	end

	slider:SetScript("OnValueChanged", function()
		local value = math.floor(this:GetValue() / step + 0.5) * step
		Show(value)
		if not this.quiet then
			set(value)
		end
	end)
	slider:SetScript("OnMouseWheel", function()
		this:SetValue(this:GetValue() + arg1 * step)
	end)
	slider:SetScript("OnEnter", function() thumb:SetVertexColor(color[1], color[2], color[3], 1) end)
	slider:SetScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, 1) end)

	function holder:Refresh()
		slider.quiet = true
		local value = get()
		slider:SetValue(value)
		Show(value)
		slider.quiet = nil
	end
	table.insert(widgets, holder)
	page.y = page.y - 22
	return holder
end

local function Button(page, text, width, x, onClick, color)
	local button = CreateFrame("Button", nil, page)
	button:SetWidth(width)
	button:SetHeight(24)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
	color = color or page.color
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, 1)
	button:SetBackdropBorderColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1)
	if color == ACCENT then
		table.insert(accented, function()
			button:SetBackdropColor(ACCENT[1] * 0.18, ACCENT[2] * 0.18, ACCENT[3] * 0.18, 1)
			button:SetBackdropBorderColor(ACCENT[1] * 0.6, ACCENT[2] * 0.6, ACCENT[3] * 0.6, 1)
		end)
	end
	button.text = Text(button, 10, color)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button.color = color
	button:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(this.color[1], this.color[2], this.color[3], 1)
	end)
	button:SetScript("OnLeave", function()
		this.text:SetTextColor(this.color[1], this.color[2], this.color[3])
		this:SetBackdropBorderColor(this.color[1] * 0.6, this.color[2] * 0.6, this.color[3] * 0.6, 1)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- A font, picked from a list where each face is written in itself (EditCard's
-- SurvivorUI_FontList, the addon's default first). get() and set(path), nil
-- for the default.
local function FontPicker(page, label, get, set)
	local color = page.color
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(PAGE_WIDTH)
	holder:SetHeight(22)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	holder.label = Text(holder, 10, TEXT)
	holder.label:SetPoint("LEFT", holder, "LEFT", 2, 0)
	holder.label:SetText(label)

	local button = CreateFrame("Button", nil, holder)
	button:SetWidth(220)
	button:SetHeight(22)
	button:SetPoint("LEFT", holder, "LEFT", 140, 0)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(0, 0, 0, 0.6)
	button:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
	button.text = Text(button, 10, TEXT)
	button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
	button.arrow = Text(button, 9, color)
	button.arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
	button.arrow:SetText("v")

	local menu = CreateFrame("Frame", nil, button)
	menu:SetFrameLevel(button:GetFrameLevel() + 20)
	menu:SetWidth(220)
	menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
	menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	menu:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
	menu:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
	menu:Hide()
	menu.items = {}

	local function Same(a, b)
		return (a and string.lower(a)) == (b and string.lower(b))
	end
	local function Faces()
		return SurvivorUI_FontList and SurvivorUI_FontList(true) or {}
	end

	button:SetScript("OnEnter", function() this:SetBackdropBorderColor(color[1], color[2], color[3], 1) end)
	button:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.3, 0.3, 0.35, 1) end)
	button:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
			return
		end
		local list = Faces()
		local chosen = get()
		for index = 1, table.getn(list) do
			local face = list[index]
			local item = menu.items[index]
			if not item then
				item = CreateFrame("Button", nil, menu)
				item:SetWidth(216)
				item:SetHeight(20)
				item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (index - 1) * 20)
				item.wash = Fill(item, "BACKGROUND", 1, 1, 1, 0)
				item.wash:SetAllPoints(item)
				item.text = item:CreateFontString(nil, "OVERLAY")
				item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
				item:SetScript("OnEnter", function() this.wash:SetVertexColor(color[1], color[2], color[3], 0.2) end)
				item:SetScript("OnLeave", function() this.wash:SetVertexColor(color[1], color[2], color[3], this.on and 0.12 or 0) end)
				item:SetScript("OnClick", function()
					set(this.path)
					menu:Hide()
					RefreshAll()
				end)
				menu.items[index] = item
			end
			item.path = face.path
			item.on = Same(chosen, face.path)
			-- Each face written in itself; the one chosen lit.
			item.text:SetFont(face.path or SurvivorUI_DEFAULT_FONT or SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
			item.text:SetText(face.name)
			item.text:SetTextColor(item.on and color[1] or 1, item.on and color[2] or 1, item.on and color[3] or 1)
			item.wash:SetVertexColor(color[1], color[2], color[3], item.on and 0.12 or 0)
			item:Show()
		end
		for index = table.getn(list) + 1, table.getn(menu.items) do
			menu.items[index]:Hide()
		end
		menu:SetHeight(table.getn(list) * 20 + 4)
		menu:Show()
	end)

	function holder:Refresh()
		local list = Faces()
		local chosen = get()
		local name = list[1] and list[1].name or "Default"
		for _, face in pairs(list) do
			if face.path and Same(chosen, face.path) then
				name = face.name
			end
		end
		button.text:SetText(name)
	end
	table.insert(widgets, holder)
	page.y = page.y - 28
end

------------------------------------------------------------------------------
-- Global: the whole addon's font, color and size.

local page = pages.global
Header(page, "Global", "Settings for the whole addon: its font, its color and its size.")
Subheader(page, "Font")
FontPicker(page, "Global font",
	function() return SurvivorUI_GlobalFont and SurvivorUI_GlobalFont() end,
	function(path) if SurvivorUI_SetGlobalFont then SurvivorUI_SetGlobalFont(path) end end)
Note(page, "Changes every text of the addon at once. A piece given a font of its own, on its card in move mode, keeps that one.")
Check(page, "One font everywhere", FeatureOn("fonts"), FeatureToggle("fonts"), "the game's windows too, after a reload")
page.y = page.y - 6
Button(page, "Every font back to default", 200, 0, Asked("Every font back to default?",
	"The global font the game's again, and every piece's own font and text size gone.", "Back to default",
	function() if SurvivorUI_ResetFonts then SurvivorUI_ResetFonts() end end))
page.y = page.y - 28

Subheader(page, "Color")
Choice(page, {
	{ "class", "Your class color", "Worn by the menus, the cards, move mode and the minimap button." },
	{ "gold", "Gold", "The addon's color up to v2.11." },
}, function() return DB().accent == "gold" and "gold" or "class" end,
	function(mode) if SurvivorUI_SetAccent then SurvivorUI_SetAccent(mode) end end)

Subheader(page, "Size")
Slider(page, "Whole interface", 0.6, 1.4, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale() or 1 end,
	function(value)
		if SurvivorUI_SetScale then
			SurvivorUI_SetScale(value, true)
		end
		panel.refitAt = GetTime() + 0.4
	end)
Note(page, "Each part also has a size of its own, on top of this one, in its own tab. This window grows and shrinks with it too, and keeps its size on screen whatever the game's UI Scale (the game's own, in its Options; its HUD Scale sizes the game's HUD only).")

------------------------------------------------------------------------------
-- Modules: each part of SurvivorUI on or off as a whole. Off, it does not
-- run, and the Default comes back where there is one; the other tabs keep only
-- how each part shows. Two columns; hover one for what it does.

local function DamageOn()
	return SurvivorUI_DamageMode and SurvivorUI_DamageMode() == "survivor"
end

local function PlatesOn()
	return PlatesThere() and not (SurvivorPlatesDB and SurvivorPlatesDB.hidden)
end

-- The parts the game has its own of, the Default: its HUD's part, its name,
-- and what else of SurvivorUI's keeps it away (the run tracker's boss health).
local GAME = {
	clock = { key = "noGameClock", hud = "clock", name = "clock" },
	bosses = { key = "noGameBosses", hud = "bosses", name = "boss bars", also = "trackerHealth" },
	tally = { key = "noGameTally", hud = "tally", name = "kills and gold box" },
	build = { key = "noGameBuild", hud = "build", name = "row of spells" },
	loot = { key = "noGameLoot", hud = "loot", name = "loot notices" },
	meter = { key = "noGameMeter", hud = "meter", name = "damage meter" },
	levels = { key = "noGameLevels", hud = "levels", name = "Level Up! button" },
	flag = { key = "noGameFlag", hud = "flag", name = "red flag on the minimap" },
}

-- The Default shows while SurvivorUI's is off, and it is wanted.
local function GameShown(game, oursOn)
	return not oursOn() and not DB()[game.key] and not (game.also and DB()[game.also])
end

-- Ticked on: SurvivorUI's goes (and what else stood in), the Default comes;
-- ticked off: it goes, and with SurvivorUI's off, neither shows.
local function GameToggle(game, oursOn, oursToggle)
	if GameShown(game, oursOn) then
		DB()[game.key] = true
	else
		DB()[game.key] = nil
		if oursOn() then
			oursToggle()
		end
		if game.also then
			DB()[game.also] = false
		end
	end
	local apply = SurvivorUI_GameHud and SurvivorUI_GameHud[game.hud]
	if apply then
		apply()
	end
end

-- The Default's tick: a small square and its name, what it is on hover.
local function GameTick(page, x, y, width, label, game, oursOn, oursToggle)
	local color = page.color
	local tick = CreateFrame("Button", nil, page)
	tick:SetWidth(width)
	tick:SetHeight(ROW)
	tick:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	tick.edge = Fill(tick, "BORDER", 0.3, 0.3, 0.35, 1)
	tick.edge:SetWidth(11)
	tick.edge:SetHeight(11)
	tick.edge:SetPoint("LEFT", tick, "LEFT", 2, 0)
	tick.box = Fill(tick, "ARTWORK", 0.06, 0.06, 0.08, 1)
	tick.box:SetPoint("TOPLEFT", tick.edge, "TOPLEFT", 1, -1)
	tick.box:SetPoint("BOTTOMRIGHT", tick.edge, "BOTTOMRIGHT", -1, 1)
	tick.mark = Fill(tick, "OVERLAY", 1, 1, 1, 0)
	tick.mark:SetPoint("TOPLEFT", tick.edge, "TOPLEFT", 3, -3)
	tick.mark:SetPoint("BOTTOMRIGHT", tick.edge, "BOTTOMRIGHT", -3, 3)
	tick.label = Text(tick, 10, TEXT)
	tick.label:SetPoint("LEFT", tick.edge, "RIGHT", 6, 0)
	tick.label:SetText(label)
	tick:SetScript("OnClick", function()
		GameToggle(game, oursOn, oursToggle)
		RefreshAll()
	end)
	tick:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText("The game's "..game.name, color[1], color[2], color[3])
		GameTooltip:AddLine("The game's own "..game.name..", shown while SurvivorUI's is off. Ticked, SurvivorUI's goes"
			..(game.also and " (and the run tracker's boss health)" or "").."; untick both for neither.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	tick:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	function tick:Refresh()
		local on = GameShown(game, oursOn)
		self.edge:SetVertexColor(on and color[1] or 0.3, on and color[2] or 0.3, on and color[3] or 0.35, 1)
		self.mark:SetVertexColor(color[1], color[2], color[3], on and 1 or 0)
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		else
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
	table.insert(widgets, tick)
	return tick
end

-- A module's tick: its name (* after a reload), what it does on hover; for a
-- part the game has its own of, the Default's tick beside it.
local function ModuleCheck(page, x, y, item)
	local label, isOn, toggle, tip, reload, usable, game = item[1], item[2], item[3], item[4], item[5], item[6], item[7]
	local color = page.color
	local check = CreateFrame("Button", nil, page)
	check:SetWidth(PAGE_WIDTH / 2 - (game and 84 or 6))
	check:SetHeight(ROW)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
	check.edge:SetWidth(13)
	check.edge:SetHeight(13)
	check.edge:SetPoint("LEFT", check, "LEFT", 2, 0)
	check.box = Fill(check, "ARTWORK", 0, 0, 0, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.label = Text(check, 11, TEXT)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 9, 0)
	check.label:SetText(label..(reload and "  |cff8a8a95*|r" or ""))
	check:SetScript("OnClick", function()
		if usable and not usable() then
			return
		end
		toggle()
		RefreshAll()
	end)
	check:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, color[1], color[2], color[3])
		GameTooltip:AddLine(tip, 1, 1, 1, 1)
		if usable and not usable() then
			GameTooltip:AddLine("Not installed: it comes in the same download.", 1, 0.45, 0.4, 1)
		elseif reload then
			GameTooltip:AddLine("Takes hold after a reload.", 0.6, 0.6, 0.65, 1)
		end
		GameTooltip:Show()
	end)
	check:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	function check:Refresh()
		local on = isOn()
		if on then
			self.box:SetVertexColor(color[1], color[2], color[3], 1)
			self.edge:SetVertexColor(color[1], color[2], color[3], 1)
		else
			self.box:SetVertexColor(0.1, 0.1, 0.13, 1)
			self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
		end
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		else
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
	table.insert(widgets, check)
	if game then
		GameTick(page, x + PAGE_WIDTH / 2 - 92, y, 86, "The game's", game, isOn, toggle)
	end
end

page = pages.modules
Header(page, "Modules", "Each part of SurvivorUI on or off as a whole: off, it does not run at all. Where the game has its own, The game's beside it is that one: SurvivorUI's puts it away, and with both unticked neither shows. Hover one for what it does; * after a reload.")

local MODULES = {
	{ "Run", {
		{ "Run tracker", OnUnlessOff("tracker"), Call("SurvivorUI_ToggleTracker"),
			"Under the minimap: the zone, the run's clock, the bosses, the guardians, the elites and your level. It puts the game's clock away.", nil, nil, GAME.clock },
		{ "Kill pace", OnUnlessOff("pace"), Call("SurvivorUI_TogglePace"),
			"The orb by the tracker's clock: how fast the enemies die, against your own runs. It sits on the run tracker." },
		{ "Guardians", OnUnlessOff("guardians"), Call("SurvivorUI_ToggleGuardians"),
			"Each lair: which way, how far, alive or slain, as a bar in the tracker, a list beside it or a count." },
		{ "Boss bars", OnUnlessOff("bossBars"), Call("SurvivorUI_BossBars"),
			"The bosses and the awake guardians with their debuffs, apart from the tracker. They put the game's bars away.", nil, nil, GAME.bosses },
		{ "Minimap pins", FeatureOn("mapPins"), FeatureToggle("mapPins", true),
			"On the minimap, a mark for each guardian's lair and a chest for each cache, set in the Minimap tab; the lair to head for glowing gold in place of the game's red flag.", nil, nil, GAME.flag },
		{ "Kills & gold", OnUnlessOff("tally"), Call("SurvivorUI_Tally"),
			"Your kills, your gold and the next cache's price. It puts the game's box away.", nil, nil, GAME.tally },
		{ "XP bar", OnlyIfOn("xpBar"), Call("SurvivorUI_ToggleXpBar"),
			"Your level and experience as a bar of its own, with the time to the next level." },
		{ "Level Up!", OnlyIfOn("levelUp"), Call("SurvivorUI_ToggleLevelUp"),
			"With Store Level-Ups on, a button over the action bar for the levels waiting. On for a new install; on a touch screen only the game's own takes a tap: switch this off there.", nil, nil, GAME.levels },
		{ "Loot list", OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot"),
			"What the run dropped. It puts the game's loot notices away.", nil, nil, GAME.loot },
	} },
	{ "Combat", {
		{ "Combat text", DamageOn, function()
				if SurvivorUI_SetDamageMode then
					SurvivorUI_SetDamageMode(DamageOn() and "game" or "survivor")
				end
			end,
			"SurvivorUI's combat numbers, set in the Combat text tab. Off: the game's." },
		{ "Damage meter", OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter"),
			"Each source's damage, its crits on hover, the healing and the boss damage. It puts the game's meter away.", nil, nil, GAME.meter },
		{ "This Run", OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun"),
			"The run's numbers, as the game's victory screen gives them." },
		{ "Biggest Crits", OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits"),
			"Each ability's biggest critical strike this run." },
		{ "Counters", OnUnlessOff("counters"), Flip("counters"),
			"Over the spells' buttons: the DoTs ticking, the enemies feared, the totems down, the shouts." },
		{ "Soul shards", FeatureOn("soulShards"), FeatureToggle("soulShards", true),
			"A warlock's, with Soul Fire: five violet gems under your frame, filling as the game counts your shards, emptied by the free Soul Fire. With a game before 0.105, worked out from your kills; dimmed, the count may be off (the chat says why)." },
		{ "Combo points", FeatureOn("comboPoints"), FeatureToggle("comboPoints", true),
			"A rogue's: five red orbs under your frame, filling as the game counts your combo points, emptied by a finisher. Moved with the soul shards: move mode, Class gems." },
		{ "Lightwell", FeatureOn("lightwell"), FeatureToggle("lightwell", true),
			"A priest's: three fonts of light under your frame, one for each well standing, the newest at the left, its beam of light as high as its time left, fading through its last seconds; a new one comes with a flash. Dim, filling, while the next one waits. Moved with the class gems." },
		{ "Bloodrage", FeatureOn("bloodrage"), FeatureToggle("bloodrage", true),
			"A warrior's: five iron chevrons under your frame, a fifth of your rage each, filling as the game counts it; near the top the full ones beat, and they blaze white as Bloodrage is set off. While on, your frame shows no rage bar of its own. Moved with the class gems." },
		{ "Summons", FeatureOn("summons"), FeatureToggle("summons", true),
			"Your summons over your frame: a buff-sized icon for each kind out (a hunter's beast, Treants, Spirit Wolves, a Water Elemental, each demon), how many of it are out and the longest time one has left; hover one for each of them. From the game's 0.110. Moved on its own: move mode, Summons." },
		{ "Party frames", FeatureOn("partyFrames"), FeatureToggle("partyFrames", true),
			"In a co-op run, a frame for each friend: the health in the class's color, DOWN while down, a gold fill while you bring them back; hover one for their damage. It puts the game's party frames away. From the game's 0.113. Moved on its own: move mode, Party frames." },
		{ "Revive bar", OnlyIfOn("reviveBar"), function() DB().reviveBar = DB().reviveBar ~= true end,
			"In a co-op run, a bar while you are down (how far a friend has brought you back, and who) or while you bring a friend back. Off by default: the game shows a slim one of its own while a friend is brought back. From the game's 0.113. Moved on its own: move mode, Revive bar." },
	} },
	{ "Character", {
		{ "Build list", OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild"),
			"Your spells, their ranks and your jewelry. It puts the game's row of spells away.", nil, nil, GAME.build },
		{ "Character pane", FeatureOn("characterPane"), FeatureToggle("characterPane"),
			"The character pane laid out again, the stats in sections. Off: the game's pane.", true },
		{ "Stats panel", OnlyIfOn("statsPanel"), Call("SurvivorUI_ToggleStatsPanel"),
			"The run's numbers as a panel on the screen all the time, apart from the character pane." },
		{ "Jewelry", OnUnlessOff("jewelry"), Flip("jewelry"),
			"Every amulet, ring and trinket found, and what is left to find." },
		{ "Ability tooltips", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip"),
			"A spell's tooltip laid out again: what it does, its numbers in colors, its upgrades, bonuses and talents.", true },
		{ "Item tooltips", FeatureOn("itemTooltip"), FeatureToggle("itemTooltip", true),
			"An item's tooltip laid out again: no bind line, its health green, each effect a line of its own, its numbers in colors." },
	} },
	{ "Interface", {
		{ "Unit frames", FeatureOn("unitFrames"), FeatureToggle("unitFrames"),
			"Your frame and your target's: flat, the portrait, the health in numbers, the target's debuffs over it. Off: the game's frames.", true },
		{ "Action bar", FeatureOn("actionBar"), FeatureToggle("actionBar"),
			"Buttons 1 to 6 and = in one flat row, the rest of the bar and the bags put away, the experience a strip under it. Off: the game's bar.", true },
		{ "Buffs", FeatureOn("buffs"), FeatureToggle("buffs"),
			"Your buffs and debuffs over your frame, with time left and stacks. Off: the game's, at the top right.", true },
		{ "Flat tooltips", FeatureOn("tooltip"), FeatureToggle("tooltip"),
			"Dark, flat tooltips, with a health bar.", true },
		{ "Flat chat", FeatureOn("chat"), FeatureToggle("chat"),
			"The chat without its frame.", true },
		{ "Square minimap", FeatureOn("minimap"), FeatureToggle("minimap"),
			"The minimap square, its buttons tidied.", true },
		{ "Menu buttons on hover", FeatureOn("microMenu"), FeatureToggle("microMenu"),
			"The game's menu buttons in the bottom left corner, shown on hover.", true },
		{ "White outline", OnUnlessOff("hover"), Call("SurvivorUI_ToggleHover"),
			"Around the frame or button the mouse is on." },
		{ "Nameplates", PlatesOn, function() Plates("none") end,
			"Survivor Plates: a plate over the enemies near you, set in the Nameplates tab.", nil, PlatesThere },
	} },
}

for group = 1, table.getn(MODULES) do
	Subheader(page, MODULES[group][1])
	local items = MODULES[group][2]
	for index = 1, table.getn(items) do
		local column = math.mod(index - 1, 2)
		ModuleCheck(page, column * (PAGE_WIDTH / 2), page.y, items[index])
		if column == 1 or index == table.getn(items) then
			page.y = page.y - ROW - 2
		end
	end
end

------------------------------------------------------------------------------
-- The health on the frames and the boss bars: one row each, its four looks
-- side by side, always short (1.1k, 2.2M).
local HEALTH_LOOKS = {
	{ "percent", "73%", 64 },
	{ "absolute", "1.2M", 64 },
	{ "both", "1.2M / 3.4M", 104 },
	{ "absolutePercent", "1.2M | 73%", 104 },
}
local function HealthRow(label, key, default)
	local color = page.color
	local name = Text(page, 10, TEXT)
	name:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 3)
	name:SetText(label)
	local x = 96
	for index = 1, table.getn(HEALTH_LOOKS) do
		local look = HEALTH_LOOKS[index]
		local value = look[1]
		local option = CreateFrame("Button", nil, page)
		option:SetWidth(look[3])
		option:SetHeight(ROW)
		option:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		x = x + look[3]

		option.ring = Fill(option, "BORDER", 0.3, 0.3, 0.35, 1)
		option.ring:SetWidth(13)
		option.ring:SetHeight(13)
		option.ring:SetPoint("TOPLEFT", option, "TOPLEFT", 2, -4)
		option.inner = Fill(option, "ARTWORK", 0.05, 0.05, 0.07, 1)
		option.inner:SetPoint("TOPLEFT", option.ring, "TOPLEFT", 1, -1)
		option.inner:SetPoint("BOTTOMRIGHT", option.ring, "BOTTOMRIGHT", -1, 1)
		option.dot = Fill(option, "OVERLAY", 0, 0, 0, 1)
		option.dot:SetPoint("TOPLEFT", option.ring, "TOPLEFT", 4, -4)
		option.dot:SetPoint("BOTTOMRIGHT", option.ring, "BOTTOMRIGHT", -4, 4)
		option.label = Text(option, 10, TEXT)
		option.label:SetPoint("TOPLEFT", option.ring, "TOPRIGHT", 6, 0)
		option.label:SetText(look[2])

		option:SetScript("OnClick", function()
			DB()[key] = value
			RefreshAll()
		end)
		option:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		option:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function option:Refresh()
			local chosen = (DB()[key] or default) == value
			self.ring:SetVertexColor(chosen and color[1] or 0.3, chosen and color[2] or 0.3, chosen and color[3] or 0.35, 1)
			self.dot:SetVertexColor(color[1], color[2], color[3], chosen and 1 or 0)
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif chosen then
				self.label:SetTextColor(color[1], color[2], color[3])
			else
				self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			end
		end
		table.insert(widgets, option)
	end
	page.y = page.y - ROW - 2
end

------------------------------------------------------------------------------
-- A part's size, compact for two columns (the Size and Character tabs): its
-- name and value over the bar.
local function SizeSlider(page, x, y, width, label, low, high, step, get, set, format)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(width)
	holder:SetHeight(30)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	local color = page.color
	holder.label = Text(holder, 10, TEXT)
	holder.label:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, 0)
	holder.label:SetText(label)
	holder.value = Text(holder, 10, color)
	holder.value:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, 0)

	local slider = CreateFrame("Slider", nil, holder)
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(width - 4)
	slider:SetHeight(12)
	slider:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -15)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	slider.track = Fill(slider, "BACKGROUND", 0.14, 0.14, 0.18, 1)
	slider.track:SetHeight(4)
	slider.track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	slider.track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	slider.fill = Fill(slider, "BORDER", color[1], color[2], color[3], 0.8)
	slider.fill:SetHeight(4)
	slider.fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	local thumb = Fill(slider, "OVERLAY", 1, 1, 1, 1)
	thumb:SetWidth(7)
	thumb:SetHeight(12)
	slider:SetThumbTexture(thumb)

	local function Show(value)
		holder.value:SetText(type(format) == "function" and format(value) or string.format(format or "%.2f", value))
		local share = (value - low) / (high - low)
		slider.fill:SetWidth(math.max(1, (slider:GetWidth() - 7) * share + 3))
	end
	slider:SetScript("OnValueChanged", function()
		local value = math.floor(this:GetValue() / step + 0.5) * step
		Show(value)
		if not this.quiet then
			set(value)
		end
	end)
	slider:SetScript("OnMouseWheel", function()
		this:SetValue(this:GetValue() + arg1 * step)
	end)
	slider:SetScript("OnEnter", function() thumb:SetVertexColor(color[1], color[2], color[3], 1) end)
	slider:SetScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, 1) end)
	function holder:Refresh()
		slider.quiet = true
		local value = get()
		slider:SetValue(value)
		Show(value)
		slider.quiet = nil
	end
	table.insert(widgets, holder)
	return holder
end

-- Two columns of them.
local SIZE_COLUMN = (PAGE_WIDTH - 18) / 2

local function SizeGrid(page, items)
	for index = 1, table.getn(items) do
		local item = items[index]
		local column = math.mod(index - 1, 2)
		SizeSlider(page, column * (SIZE_COLUMN + 18), page.y, SIZE_COLUMN, item[1], item[2], item[3], item[4], item[5], item[6], item[7])
		if column == 1 or index == table.getn(items) then
			page.y = page.y - 34
		end
	end
end

-- A part's size (Mover.lua), as a SizeGrid item.
local function PartSize(key, label)
	return { label, 0.5, 2, 0.05,
		function() return SurvivorUI_GetScale and SurvivorUI_GetScale(key) or 1 end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale(key, value) end end }
end

-- A piece's text size: its card's step (A- and A+), -4 to +8, by its name
-- (EditCard.lua); a window with no card by the name its tab gives it.
local function TextSize(page, name, get, set, label)
	Slider(page, label or "Text size", -4, 8, 1,
		get or function() return SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep(name) or 0 end,
		set or function(value) if SurvivorUI_SetPieceTextStep then SurvivorUI_SetPieceTextStep(name, value) end end,
		function(value)
			value = math.floor(value + 0.5)
			return value == 0 and "normal" or ((value > 0 and "+" or "")..value)
		end)
end

------------------------------------------------------------------------------
-- A panel's tab opens with the same head: whether it is on (Modules), Back to
-- its place at the right, its size and its text's size; each where the panel
-- has one. extra: { back = Back to its place for a window with no card,
-- font = the name its Text size goes by, false for none }.

local function PanelHead(page, isOn, toggle, partKey, pieceName, reloads, game, extra)
	extra = extra or {}
	-- The switch: the part on or off, the same as its tick in Modules.
	local color = page.color
	local switch = CreateFrame("Button", nil, page)
	switch:SetWidth(game and 84 or 220)
	switch:SetHeight(ROW)
	switch:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 2)
	switch.edge = Fill(switch, "BORDER", 0.3, 0.3, 0.35, 1)
	switch.edge:SetWidth(13)
	switch.edge:SetHeight(13)
	switch.edge:SetPoint("TOPLEFT", switch, "TOPLEFT", 2, -3)
	switch.box = Fill(switch, "ARTWORK", 0.06, 0.06, 0.08, 1)
	switch.box:SetPoint("TOPLEFT", switch.edge, "TOPLEFT", 1, -1)
	switch.box:SetPoint("BOTTOMRIGHT", switch.edge, "BOTTOMRIGHT", -1, 1)
	switch.mark = Fill(switch, "OVERLAY", 1, 1, 1, 0)
	switch.mark:SetPoint("TOPLEFT", switch.edge, "TOPLEFT", 3, -3)
	switch.mark:SetPoint("BOTTOMRIGHT", switch.edge, "BOTTOMRIGHT", -3, 3)
	switch.label = Text(switch, 11, TEXT)
	switch.label:SetPoint("LEFT", switch.edge, "RIGHT", 9, 0)
	switch.note = Text(switch, 9, MUTED)
	switch.note:SetPoint("LEFT", switch.label, "RIGHT", 8, 0)
	switch.note:SetText(reloads and "after a reload" or "")
	switch:SetScript("OnClick", function()
		if toggle then
			toggle()
		end
		RefreshAll()
	end)
	switch:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
	switch:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
	function switch:Refresh()
		local on = not isOn or isOn()
		self.label:SetText(on and "On" or "Off")
		if on then
			self.edge:SetVertexColor(color[1], color[2], color[3], 1)
			self.mark:SetVertexColor(color[1], color[2], color[3], 1)
		else
			self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
			self.mark:SetVertexColor(1, 1, 1, 0)
		end
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(color[1], color[2], color[3])
		else
			self.label:SetTextColor(1, 0.42, 0.36)
		end
	end
	table.insert(widgets, switch)
	if pieceName or extra.back then
		Button(page, "Back to its place", 150, PAGE_WIDTH - 150, extra.back or function()
			if SurvivorUI_ResetPiece then
				SurvivorUI_ResetPiece(pieceName)
			end
		end)
	end
	-- A part the game has its own of: The game's tick, beside the switch.
	if game then
		GameTick(page, 92, page.y - 2, 210, "The game's", game, isOn or function() return true end, toggle)
	end
	page.y = page.y - 30
	if partKey then
		Slider(page, "Size", 0.5, 2, 0.05,
			function() return SurvivorUI_GetScale and SurvivorUI_GetScale(partKey) or 1 end,
			function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale(partKey, value) end end)
	end
	local font = extra.font
	if font == nil then
		font = pieceName
	end
	if font then
		TextSize(page, font)
	end
end

------------------------------------------------------------------------------
-- Run tracker: the clock, the bosses, the guardians and the elites
-- (Tracker.lua, Guardians.lua).

page = pages.tracker
Header(page, "Run tracker", "Under the minimap: the zone, the run's clock against its length, the bosses, the guardians, the elites alive and your level, each part on its own.")
PanelHead(page, OnUnlessOff("tracker"), Call("SurvivorUI_ToggleTracker"), "tracker", "Run tracker", nil, GAME.clock)

Subheader(page, "Bosses")
Check(page, "Boss health", OnlyIfOn("trackerHealth"), function()
	DB().trackerHealth = not DB().trackerHealth
	if SurvivorUI_ApplyBossHud then
		SurvivorUI_ApplyBossHud()
	end
end, "each boss alive fills its line; click it to target")
Inline(page, "Health shows as", {
	{ "percent", "73%" },
	{ "absolutePercent", "1.2M | 73%" },
	{ "absolute", "1.2M" },
}, function() return DB().trackerHealthLook or "percent" end, function(look) DB().trackerHealthLook = look end)

Subheader(page, "Guardians")
Inline(page, "Show as", {
	{ "bar", "A bar" },
	{ "list", "A list" },
	{ "count", "A count" },
	{ "off", "Off" },
}, function()
	if DB().guardians == false then
		return "off"
	end
	if DB().guardiansCount then
		return "count"
	end
	return DB().guardiansDocked and "bar" or "list"
end, function(choice)
	DB().guardians = choice ~= "off"
	if choice ~= "off" then
		DB().guardiansDocked = choice ~= "list"
		DB().guardiansCount = choice == "count" or nil
	end
end)
Note(page, "Bar: a stretch a lair in the tracker, red once slain. List: a line a lair beside it, yards and an arrow. Count: 3 / 5 alive. Off: none, as in Modules.")
Check(page, "Arrows north up", OnlyIfOn("guardiansNorth"), Call("SurvivorUI_ToggleGuardians", "north"), "off: they turn with you, straight ahead up")
Check(page, "Lair marks", OnUnlessOff("guardianMarks"), Flip("guardianMarks"), "each lair its own heraldic mark: the same in the tracker, on the minimap and on its boss bar")
-- The list's Back to its place, on a row of its own: by Show as, its four
-- choices reach the page's edge.
local listPlace = Text(page, 10, TEXT)
listPlace:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 6)
listPlace:SetText("List place")
Button(page, "Back to its place", 150, PAGE_WIDTH - 150, function()
	if SurvivorUI_ResetPiece then
		SurvivorUI_ResetPiece("Guardians")
	end
end)
page.y = page.y - 30
Slider(page, "List size", 0.5, 2, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale("guardians") or 1 end,
	function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("guardians", value) end end)
TextSize(page, "Guardians")

Subheader(page, "Elites")
Check(page, "Elites", OnUnlessOff("trackerElites"), Flip("trackerElites"), "a small bar for each one alive, bright once hurt; click one to target")
Slider(page, "Bars shown", 4, 12, 1, function() return DB().trackerElitesMax or 8 end,
	function(value) DB().trackerElitesMax = math.floor(value + 0.5) end, "%d")
Check(page, "Only while one is alive", OnlyIfOn("trackerElitesHide"), function()
	DB().trackerElitesHide = not DB().trackerElitesHide
end, "off: the row keeps its room")

Subheader(page, "Cache coin")
Check(page, "Coin on the tracker", OnlyIfOn("trackerCoin"), function()
	DB().trackerCoin = not DB().trackerCoin
end, "left of the clock: gold when you can pay, red when not; it shines as the kills and gold line's coin does (Kills & gold tab)")

Subheader(page, "XP bar")
Check(page, "Level and experience", OnUnlessOff("trackerXp"), Flip("trackerXp"), "the bar at the tracker's foot")
Check(page, "Time to the next level", OnUnlessOff("trackerXpEta"), Flip("trackerXpEta"), "beside the level, from the recent pace")

------------------------------------------------------------------------------
-- Kill pace: the orb by the run tracker's clock (Pace.lua).

page = pages.pace
Header(page, "Kill pace", "An orb right of the run tracker's clock: how fast the enemies die now, against your own runs on the same zone and modifiers at the same minute. Hover it for the numbers.")
PanelHead(page, OnUnlessOff("pace"), Call("SurvivorUI_TogglePace"))

Subheader(page, "Compared with")
Choice(page, {
	{ "account", "All your runs", "Every class's, on this zone and modifiers." },
	{ "class", "This class's runs only" },
}, function() return DB().paceClassOnly and "class" or "account" end,
	function(choice) DB().paceClassOnly = choice == "class" or nil end)
Slider(page, "Rate over", 10, 60, 5, function() return DB().paceWindow or 20 end,
	function(value) DB().paceWindow = math.floor(value + 0.5) end, "%d s")
Slider(page, "Runs needed", 1, 10, 1, function() return DB().paceMinRuns or 3 end,
	function(value) DB().paceMinRuns = math.floor(value + 0.5) end, "%d")
Note(page, "The orb stays white until that many of your runs have reached the same minute.")

Subheader(page, "The orb")
Choice(page, {
	{ "full", "Full: sparks, and stars when it flies" },
	{ "calm", "Calm: fewer sparks, no stars" },
	{ "none", "The orb alone" },
}, function() return DB().paceEffects or "full" end, function(choice) DB().paceEffects = choice end)

Subheader(page, "Each boss's stretch")
Check(page, "A banner as each boss comes", OnUnlessOff("paceBanner"),
	function() DB().paceBanner = DB().paceBanner == false end, "how the stretch just ended went, left of the tracker")
Slider(page, "Banner stays", 3, 15, 1, function() return DB().paceBannerHold or 6 end,
	function(value) DB().paceBannerHold = math.floor(value + 0.5) end, "%d s")
page.y = page.y - 6
Button(page, "Forget this zone's runs", 200, 0, function()
	if SurvivorUI_TogglePace then
		SurvivorUI_TogglePace("ask")
	end
end)
page.y = page.y - 28

------------------------------------------------------------------------------
-- Boss bars (BossBars.lua).

page = pages.bosses
Header(page, "Boss bars", "At the top of the screen: the bosses and the awake guardians, with their debuffs, apart from the run tracker.")
PanelHead(page, OnUnlessOff("bossBars"), Call("SurvivorUI_BossBars"), "bosses", "Boss bars", nil, GAME.bosses)
Subheader(page, "What shows")
Check(page, "Elites on the boss bars", OnlyIfOn("bossBarsElites"), Call("SurvivorUI_BossBars", "elites"))
Note(page, "Only the run tracker's own bosses? Untick these and The game's, and keep the tracker's Boss health on (Run tracker tab): with it on, the game's bars stay away anyway.")
HealthRow("Health", "bossHealth", "absolutePercent")

------------------------------------------------------------------------------
-- Kills & gold: the line of the kills, the gold and the cache (Tally.lua).

page = pages.tally
Header(page, "Kills & gold", "Your kills, your gold and the next cache's price, in one line. Off: the game's box.")
PanelHead(page, OnUnlessOff("tally"), Call("SurvivorUI_Tally"), "tally", "Kills and gold line", nil, GAME.tally)
Subheader(page, "Where")
Inline(page, nil, {
	{ "minimap", "Under the minimap" },
	{ "bar", "Under the action bar" },
}, function() return DB().tallyPlace == "bar" and "bar" or "minimap" end,
	function(place) if SurvivorUI_SetTallyPlace then SurvivorUI_SetTallyPlace(place) end end)
Subheader(page, "What shows")
Inline(page, nil, {
	{ "killsGold", "Kills, gold" },
	{ "goldKills", "Gold, kills" },
	{ "kills", "Kills only" },
	{ "gold", "Gold only" },
}, function() return DB().tallyLayout or "killsGold" end, function(layout) DB().tallyLayout = layout end)
Check(page, "Gold and cache apart", OnlyIfOn("tallySplit"), function()
	DB().tallySplit = not DB().tallySplit
end, "the coin with your gold, the chest with the next cache's price")
Check(page, "Coin shines when you can pay", OnUnlessOff("trackerCoinShine"), Flip("trackerCoinShine"), "this coin and the tracker's")

------------------------------------------------------------------------------
-- XP bar (XpBar.lua).

page = pages.xpbar
Header(page, "XP bar", "Your level and experience as a bar of its own, at the top of the screen; the run tracker shows them too, at its foot (Run tracker tab).")
PanelHead(page, OnlyIfOn("xpBar"), Call("SurvivorUI_ToggleXpBar"), "xpbar", "XP bar")
Subheader(page, "What shows")
Check(page, "Time to the next level", OnUnlessOff("xpBarEta"), Flip("xpBarEta"), "and the experience a minute, from the recent pace")

------------------------------------------------------------------------------
-- Level Up! (LevelUp.lua): the button for the levels waiting, and the game's
-- Store Level-Ups.

page = pages.levelup
Header(page, "Level Up!", "With Store Level-Ups on, a level-up no longer stops the fight: the levels wait, and a button opens them, one card choice after another: SurvivorUI's over the action bar, or the game's own where its action bars were.")
PanelHead(page, OnlyIfOn("levelUp"), Call("SurvivorUI_ToggleLevelUp"), "levelup", "Level Up!", nil, GAME.levels)
Note(page, "On: SurvivorUI's button. Off with The game's ticked: the game's own, which on a touch screen is the only one that takes a tap. Both off: no button at all, so keep Store Level-Ups off then, or the levels wait with nothing to open them.")
Subheader(page, "Store Level-Ups")
Check(page, "Level-ups wait until you are ready", function() return AZS_IsStoringLevels and AZS_IsStoringLevels() end,
	function()
		if AZS_SetStoringLevels and AZS_IsStoringLevels then
			AZS_SetStoringLevels(not AZS_IsStoringLevels())
		end
	end, "the game's own setting (its Options, Controls); turned off, the levels waiting are offered at once")
if not AZS_SetStoringLevels then
	Note(page, "Needs the game's 0.98 or later.")
end
Subheader(page, "Look")
Check(page, "Sparks and a shine on the button", function() return DB().levelUpSparks ~= false end,
	function() DB().levelUpSparks = DB().levelUpSparks == false end,
	"as Run History's Victory box: sparks rising, stars, a shine crossing it now and then")
Swatches(page, "Color", SurvivorUI_LEVELUP_COLORS or {},
	function() return DB().levelUpColor or "class" end,
	function(key) DB().levelUpColor = key end)
Note(page, "The levels waiting also show by your level, in the run tracker and on the XP bar: Lv. 12 +3. While this tab is open the button shows, to be placed.")

------------------------------------------------------------------------------
-- Loot list (LootLog.lua).

page = pages.loot
Header(page, "Loot list", "What the run dropped, a bar a piece filled with its quality's color, with the second it came.")
PanelHead(page, OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot"), "loot", "Loot list", nil, GAME.loot)
Subheader(page, "Look")
Check(page, "Background behind the list", OnUnlessOff("lootBackground"), Flip("lootBackground"), "off: the rows on the world itself")
Slider(page, "Lines shown", 3, 15, 1, function() return DB().lootLines or 8 end,
	function(value) DB().lootLines = math.floor(value + 0.5) end, "%d")

------------------------------------------------------------------------------
-- Combat text.

page = pages.combat
Header(page, "Combat text", "The combat numbers: SurvivorUI's, set below; the game's; or off.")
Inline(page, "Combat numbers", {
	{ "survivor", "SurvivorUI's" },
	{ "game", "The game's" },
	{ "none", "Off" },
}, function() return SurvivorUI_DamageMode and SurvivorUI_DamageMode() or "survivor" end,
	function(mode) if SurvivorUI_SetDamageMode then SurvivorUI_SetDamageMode(mode) end end)

-- Survivor's settings: each a setting of SurvivorUI.lua's (SurvivorUI_CT).
local function CTGet(key)
	return function() return SurvivorUI_CT and SurvivorUI_CT(key) end
end
local function CTToggle(key)
	return function()
		if SurvivorUI_SetCT and SurvivorUI_CT then
			SurvivorUI_SetCT(key, not SurvivorUI_CT(key))
		end
	end
end
local function CTSet(key)
	return function(value)
		if SurvivorUI_SetCT then
			SurvivorUI_SetCT(key, value)
		end
	end
end

Subheader(page, "Where")
Inline(page, nil, {
	{ "sides", "Beside the hero" },
	{ "enemies", "Over the enemies" },
}, CTGet("ctLayout"), CTSet("ctLayout"))
Slider(page, "Distance from hero", 60, 320, 10, CTGet("ctDistance"), CTSet("ctDistance"), "%d")
Slider(page, "How high they rise", 80, 320, 10, CTGet("ctRise"), CTSet("ctRise"), "%d")
Check(page, "Crits in a separate column", CTGet("ctCritColumn"), CTToggle("ctCritColumn"), "on the right")
Note(page, "Drag a column while this tab is open, or click it for its card; moved, it stays put whatever the distance. Over the enemies needs nameplates.")

Subheader(page, "Look")
InlineChecks(page, {
	{ "Source icons", CTGet("ctIcons"), CTToggle("ctIcons") },
	{ "Meter colors", CTGet("ctMeterColors"), CTToggle("ctMeterColors") },
	{ "Short numbers", CTGet("ctShort"), CTToggle("ctShort") },
})
Slider(page, "Size", 0.5, 1.5, 0.05, CTGet("ctSize"), CTSet("ctSize"))
Slider(page, "Crit size", 0.6, 1.6, 0.05, CTGet("ctCritSize"), CTSet("ctCritSize"))

Subheader(page, "What shows")
InlineChecks(page, {
	{ "Damage over time", CTGet("ctPeriodic"), CTToggle("ctPeriodic") },
	{ "Heals", CTGet("ctHeals"), CTToggle("ctHeals") },
	{ "Damage taken", CTGet("ctTaken"), CTToggle("ctTaken") },
})
Slider(page, "Smallest heal", 0, 10, 1, CTGet("ctHealMin"), CTSet("ctHealMin"), "%d%% HP")
InlineChecks(page, {
	{ "Damage", CTGet("ctAddDealt"), CTToggle("ctAddDealt") },
	{ "Crits", CTGet("ctAddCrits"), CTToggle("ctAddCrits") },
	{ "Heals", CTGet("ctAddHeals"), CTToggle("ctAddHeals") },
	{ "Taken", CTGet("ctMergeTaken"), CTToggle("ctMergeTaken") },
}, "Add up")
Slider(page, "Add up within", 50, 500, 25, CTGet("ctAddWindow"), CTSet("ctAddWindow"), "%d ms")
Note(page, "One source's hits that close: one number, their sum and count (1.2k x3).")

Subheader(page, "New best crit")
Check(page, "Held still when a best is beaten", CTGet("ctRecord"), CTToggle("ctRecord"), "bigger and gold, beside the Biggest Crits")
Inline(page, "A best is", {
	{ "ability", "per ability" },
	{ "run", "the run's biggest" },
}, CTGet("ctRecordKind"), CTSet("ctRecordKind"))
Slider(page, "Stays", 1, 4, 0.1, CTGet("ctRecordHold"), CTSet("ctRecordHold"), "%.1f s")
Slider(page, "Size", 0.6, 1.6, 0.05, CTGet("ctRecordSize"), CTSet("ctRecordSize"))
Check(page, "A glow behind it", CTGet("ctRecordGlow"), CTToggle("ctRecordGlow"))
page.y = page.y - 4
Button(page, "Show a sample", 150, 0, function()
	if SurvivorUI_CTSample then
		SurvivorUI_CTSample()
	end
end)
Button(page, "Combat text back to default", 220, 162, Asked("Combat text back to default?",
	"Every setting of this tab as it first was; the columns you moved stay where they are.", "Back to default",
	function() if SurvivorUI_CTDefaults then SurvivorUI_CTDefaults() end end))
page.y = page.y - 28

------------------------------------------------------------------------------
-- Damage meter (Meter.lua).

page = pages.meter
Header(page, "Damage meter", "Each source's damage and its share, its crits on hover; its title's menu for the healing or the last boss fight. Off: the game's meter.")
PanelHead(page, OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter"), "meter", "Damage meter", nil, GAME.meter)
Subheader(page, "What shows")
Check(page, "Damage a second right now", OnUnlessOff("meterNow"), Flip("meterNow"), "under the run's, over the last 5 seconds, as the game's meter has it")
Check(page, "Spell ranks after the names", OnlyIfOn("meterRanks"), function() DB().meterRanks = not DB().meterRanks or nil end,
	"Holy Shock  2, here and in the Run History's meter; in Roman numerals with Roman spell ranks on (Tooltips)")

------------------------------------------------------------------------------
-- This Run (RunPanel.lua).

page = pages.run
Header(page, "This Run", "The run's numbers, as the game's victory screen gives them: time, level, kills, elites, guardians and bosses slain, damage, gold and caches. Hover a row for more.")
PanelHead(page, OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun"), "run", "This Run")
Note(page, "Run History, each run as it ended, opens from the hourglass by the minimap: the Run History tab sets what it keeps.")

------------------------------------------------------------------------------
-- Run History (RunHistory.lua).

page = pages.history
Header(page, "Run History", "Every run as it ended: its run tracker, numbers, build and jewelry, damage, crits and loot, with their tooltips. Open it with the hourglass by the minimap, or /sui history.")
Button(page, "Open Run History", 170, 0, function()
	if SurvivorUI_ShowRunHistory then
		SurvivorUI_ShowRunHistory()
	end
end)
-- The window and Career's: back under the screen's top, one size, one text size.
Button(page, "Back to its place", 150, PAGE_WIDTH - 150, function()
	if SurvivorUI_ResetHistoryPlace then
		SurvivorUI_ResetHistoryPlace()
	end
end)
page.y = page.y - 32
Slider(page, "Size", 0.5, 2, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale("history") or 1 end,
	function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("history", value) end end)
TextSize(page, "Run History")
Note(page, "The size and text size of the Run History window and of Career, alike.")

local function Sets(key)
	return function(value) DB()[key] = value end
end

Subheader(page, "Which runs")
Inline(page, "Keep", { { "all", "Every run" }, { "victories", "Victories only" }, { "none", "None" } },
	function() return DB().historyWhich or "all" end, Sets("historyWhich"))
Inline(page, "How many", { { 10, "10" }, { 25, "25" }, { 50, "50" }, { 100, "100" } },
	function() return tonumber(DB().historyKeep) or 100 end, Sets("historyKeep"))
Inline(page, "The 10 longest", { { true, "Always kept" }, { false, "Go like the others" } },
	function() return DB().historyLongest ~= false end, Sets("historyLongest"))
Note(page, "Past the limit, the oldest run goes as a new one is kept; the longest (when kept) and the pinned ones (Pin, in the window) never go. Changes here apply from the next run on, so nothing is deleted at a click.")

Subheader(page, "Tooltips")
Inline(page, "Keep them for", { { "all", "All" }, { "50", "Newest 50" }, { "25", "Newest 25" }, { "0", "None" } },
	function() return DB().historyPhotos or "25" end, Sets("historyPhotos"))
Note(page, "A run takes about 20 kB with its tooltips and 7 kB without, in the saved file the game reads at every login and reload. The pinned and the longest keep theirs. Taken off an older run, they do not come back.")

Subheader(page, "Time zone")
local clockLine
local function ShowClock()
	local hours = tonumber(DB().timeZone)
	local now = time() + (hours or 0) * 3600
	local clock = string.format("%02d:%02d", math.floor(math.mod(now, 86400) / 3600), math.floor(math.mod(now, 3600) / 60))
	if hours then
		clockLine:SetText("Your time now: |cffffffff"..clock.."|r, if this is your zone. The game's own clock runs in UTC, so the runs' dates take this one.")
	else
		clockLine:SetText("Not set: the runs' dates are in UTC (|cffffffff"..clock.."|r now), the game's own clock. Set yours: Brazil UTC-3, Portugal UTC+0 or +1.")
	end
end
Slider(page, "Your time zone", -12, 14, 0.5,
	function() return tonumber(DB().timeZone) or 0 end,
	function(value)
		DB().timeZone = value
		ShowClock()
	end,
	function(value) return SurvivorUI_ZoneLabel and SurvivorUI_ZoneLabel(value) or tostring(value) end)
clockLine = Text(page, 9, MUTED)
clockLine:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
clockLine:SetWidth(PAGE_WIDTH)
clockLine:SetJustifyH("LEFT")
local clockHolder = {}
function clockHolder:Refresh()
	ShowClock()
end
table.insert(widgets, clockHolder)
page.y = page.y - 30

Subheader(page, "Saved now")
local historyStats = Text(page, 10, TEXT)
historyStats:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y)
historyStats:SetWidth(PAGE_WIDTH)
historyStats:SetJustifyH("LEFT")
local historyPage = page
local statsHolder = {}
function statsHolder:Refresh()
	-- Counted only with the tab open: the whole history is gone through.
	if not historyPage:IsVisible() then
		return
	end
	if not SurvivorUI_HistoryStats then
		historyStats:SetText("")
		return
	end
	local count, won, pinned, photos, bytes = SurvivorUI_HistoryStats()
	local size = bytes >= 1048576 and string.format("%.1f MB", bytes / 1048576) or math.max(1, math.floor(bytes / 1024 + 0.5)).." kB"
	local dot = "  |cff8a8a8a\194\183|r  "
	historyStats:SetText("|cffffffff"..count.."|r"..(count == 1 and " run" or " runs")
		..dot.."|cff73f280"..won.."|r won"
		..dot.."|cffffd100"..pinned.."|r pinned"
		..dot.."|cffffffff"..photos.."|r with their tooltips"
		..dot.."about |cffffffff"..size.."|r")
end
table.insert(widgets, statsHolder)
page.y = page.y - 24
local clearAll = Button(page, "Clear all runs", 170, 0, function()
	if SurvivorUI_AskClearHistory then
		SurvivorUI_AskClearHistory(RefreshAll)
	end
end, { 0.95, 0.40, 0.35 })
local clearNote = Text(page, 9, MUTED)
clearNote:SetPoint("LEFT", clearAll, "RIGHT", 12, 0)
clearNote:SetText("Every run, the pinned ones too: the word clear typed first.")
page.y = page.y - 30

------------------------------------------------------------------------------
-- Biggest Crits (RunPanel.lua).

page = pages.crits
Header(page, "Biggest Crits", "Each ability's biggest critical strike this run; hover one for its card, its Reset clears them. A new best held still in the combat numbers is set in Combat text.")
PanelHead(page, OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits"), "crits", "Biggest Crits")

------------------------------------------------------------------------------
-- Counters: the numbers over the spells' buttons (DotCounter.lua).

page = pages.counters
Header(page, "Counters", "A number over a spell's button: how many of it are out right now (Battle Shout: the seconds it has left), in the spell's damage meter color. The game tells none of these outright: each is worked out from the combat log and your spells' cooldowns, so it can be off now and then.")
PanelHead(page, OnUnlessOff("counters"), Flip("counters"))
Subheader(page, "What is counted")
Check(page, "DoTs", OnUnlessOff("dotCounter"), Flip("dotCounter"), "how many of each are ticking on the enemies, by their ticks over the last two seconds; one on an enemy that dies stays up to two seconds")
Check(page, "Fears", OnUnlessOff("fearCounter"), Flip("fearCounter"), "how many enemies each one holds; the game writes a fear's hit but not its end, so each enemy hit counts for the fear's full time")
Check(page, "Totems", OnUnlessOff("totemCounter"), Flip("totemCounter"), "how many of each are down, and the seconds until the next one ends: each cast counts a totem for its tooltip's time; two with Call of the Elements, and Totemic Wrath's Searing Totem every 14 sec, told by the spells a run starts with")
Check(page, "Shouts", OnUnlessOff("shoutCounter"), Flip("shoutCounter"), "Demoralizing Shout: how many enemies its last cast weakened, for its time; Battle Shout: the seconds it has left")
Check(page, "Marks", OnUnlessOff("markCounter"), Flip("markCounter"), "Faerie Fire: how many enemies carry it, bosses too; each one it hits counts for the mark's time (its tooltip's), so one hit again before it fades counts twice until it does")

Subheader(page, "Look")
Slider(page, "Size", 0.5, 2, 0.05, function() return tonumber(DB().counterSize) or 1 end,
	function(value) DB().counterSize = math.floor(value * 100 + 0.5) / 100 end)

------------------------------------------------------------------------------
-- Summons (Summons.lua): your summons over the player frame.

page = pages.summons
Header(page, "Summons", "Your summons over your frame, from the game's 0.110: a buff-sized icon for each kind out, how many against the game's limit in the corner and the longest time one has left in the middle. The Legion Gate's lesser demons are one icon; hover any icon for each one's time.")
PanelHead(page, FeatureOn("summons"), FeatureToggle("summons", true), nil, "Summons", nil, nil, { font = false })
Subheader(page, "What shows")
Check(page, "Track permanent pets", OnlyIfOn("summonsPermanent"),
	function() DB().summonsPermanent = DB().summonsPermanent ~= true end,
	"the ones that stay the whole run too: the Imp, your companion demon, a hunter's beast, Treants, Spirit Wolves, a Water Elemental. Off (the default), only the ones that come and go.")

------------------------------------------------------------------------------
-- Party (Party.lua): a co-op run's party frames and revive bar.

page = pages.party
Header(page, "Party", "For co-op runs, from the game's 0.113: a frame for each friend in your party, and, if you want it, a bar while you are down or bring a friend back. The damage meter's title opens a Party Damage page too, and Run History names the party of a run played in one. Out of a party nothing shows; while this tab is open, a sample does.")
PanelHead(page, FeatureOn("partyFrames"), FeatureToggle("partyFrames", true), "party", "Party frames", nil, nil, { font = false })
Note(page, "Left of your frame, the first friend at the bottom and each next one over it. Each friend's class icon, their health in the class's color and what is left of it; DOWN in red while down, a gold fill while you bring them back, Reviving you on the one bringing you back. Hover one for their damage this run and their top spell; click to target. The game's party frames are put away while these are on.")
Subheader(page, "Revive bar")
Check(page, "Revive bar", OnlyIfOn("reviveBar"), function() DB().reviveBar = DB().reviveBar ~= true end,
	"while you are down: how far a friend has brought you back, and who; while you bring one back: how far. Off by default: the game shows a slim bar of its own while a friend is brought back, and it cannot be put away. Moved on its own: move mode, Revive bar.")

------------------------------------------------------------------------------
-- Build list (BuildList.lua).

page = pages.build
Header(page, "Build list", "Your spells with their icons and ranks, the free slots and the jewelry you wear. Off: the game's row of spells.")
PanelHead(page, OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild"), "build", "Build list", nil, GAME.build)
Subheader(page, "Beside each spell")
InlineChecks(page, {
	{ "Info", function() return DB().buildRange ~= false and DB().buildShows ~= "cooldown" end, function()
		DB().buildShows = nil
		DB().buildRange = DB().buildRange == false
	end },
	{ "Cooldown", function() return DB().buildCooldown == true or DB().buildShows == "cooldown" end, function()
		DB().buildShows = nil
		DB().buildCooldown = not DB().buildCooldown
	end },
})
Note(page, "Either or both. Info: the range read off the spell's own tooltip, or its radius for one with no range (a measuring arrow); for the buffs on you (Divine Shield, Holy Shield, Battle Shout, Slice and Dice, Adrenaline Rush, Lightning Shield, Thorns, and your demons' Demonic Empowerment) how long they last (an hourglass), the row a timer while one is up; for Holy Light, Renew, Healing Wave, Rejuvenation and Regrowth how much they heal (a cross); for Power Word: Shield and Ice Barrier how much they hold back (a shield). A totem's reach is its own, not where it is dropped from. The cooldown as the game has it now, haste in.")Check(page, "Keep the game's row of spells too", OnlyIfOn("gameBuildToo"), function()
	DB().gameBuildToo = DB().gameBuildToo ~= true
	if SurvivorUI_GameHud and SurvivorUI_GameHud.build then
		SurvivorUI_GameHud.build()
	end
end, "The game's own row stays under the list. Since the game's 0.111 it is the only place that counts down to the next Felguard or Pit Lord (Butcher, Pact of the Annihilan), on the talent's icon.")

-- Character pane (CharacterPane.lua): it opens with this tab.

page = pages.character
Header(page, "Character pane", "The character pane laid out again: the hero and the slots, and the run's numbers beside them. It opens with this tab: drag it while the tab is open, or click it for its card.")
PanelHead(page, FeatureOn("characterPane"), FeatureToggle("characterPane"), "character", "Character pane", true, nil, { font = false })
Subheader(page, "In the pane")
Check(page, "The stats beside the hero", function() return not SurvivorUI_StatsInPane or SurvivorUI_StatsInPane() end,
	function()
		if SurvivorUI_SetStatsInPane and SurvivorUI_StatsInPane then
			SurvivorUI_SetStatsInPane(not SurvivorUI_StatsInPane())
		end
	end, "off: the hero and the slots alone")
TextSize(page, nil, function() return SurvivorUI_PaneStatsStep and SurvivorUI_PaneStatsStep() or 0 end,
	function(value) if SurvivorUI_SetPaneStatsStep then SurvivorUI_SetPaneStatsStep(value) end end, "Stats text size")
Note(page, "The same numbers on the screen all the time are a panel of their own: the Stats panel tab. The Jewelry Collection can open beside the pane: the Jewelry tab.")

------------------------------------------------------------------------------
-- Stats panel: the run's numbers as a panel of their own on the screen, apart
-- from the character pane; and which numbers show, in both.

page = pages.stats
Header(page, "Stats panel", "The run's numbers as a panel of their own, on the screen all the time, apart from the character pane. Drag it by its title while this tab is open; its corner resizes it (a right click there: the first size again).")
PanelHead(page, OnlyIfOn("statsPanel"), Call("SurvivorUI_ToggleStatsPanel"), "stats", "Stats")

-- The class whose choices these are, named in the section's title.
local classTitle = Subheader(page, "Stats for this class")
local classWidget = {}
function classWidget:Refresh()
	local name = UnitClass and UnitClass("player")
	classTitle:SetText(string.upper("Stats for "..(name or "this class")))
end
table.insert(widgets, classWidget)
Note(page, "In the character pane and on the panel alike. Each class keeps its own; a number switched off never shows. For their order, drag a number or a group's title in either, in move mode or holding Alt.")

-- Every number, by group, in two columns: on shows, off never does.
local function StatCheck(x, y, width, label, color)
	local check = CreateFrame("Button", nil, page)
	check:SetWidth(width)
	check:SetHeight(15)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
	check.edge:SetWidth(10)
	check.edge:SetHeight(10)
	check.edge:SetPoint("LEFT", check, "LEFT", 2, 0)
	check.box = Fill(check, "ARTWORK", 0, 0, 0, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.label = Text(check, 9, TEXT)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 6, 0)
	check.label:SetText(label)
	check:SetScript("OnClick", function()
		if SurvivorUI_SetStatShown and SurvivorUI_StatShown then
			SurvivorUI_SetStatShown(label, not SurvivorUI_StatShown(label))
		end
		this:Refresh()
	end)
	check:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
	check:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
	function check:Refresh()
		local on = not SurvivorUI_StatShown or SurvivorUI_StatShown(label)
		self.box:SetVertexColor(color[1], color[2], color[3], on and 1 or 0)
		self.edge:SetVertexColor(on and color[1] or 0.3, on and color[2] or 0.3, on and color[3] or 0.35, 1)
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		else
			self.label:SetTextColor(MUTED[1] * 0.8, MUTED[2] * 0.8, MUTED[3] * 0.8)
		end
	end
	table.insert(widgets, check)
end

local groups = SurvivorUI_StatList and SurvivorUI_StatList() or {}
-- Three columns, each group into the shortest, in order.
local columnWidth = PAGE_WIDTH / 3 - 4
local columnX = { 0, PAGE_WIDTH / 3 + 2, 2 * PAGE_WIDTH / 3 + 4 }
local columnY = { page.y, page.y, page.y }
for index = 1, table.getn(groups) do
	local group = groups[index]
	local column = 1
	for each = 2, 3 do
		if columnY[each] > columnY[column] then
			column = each
		end
	end
	local y = columnY[column]
	local title = Text(page, 9, group.color)
	title:SetPoint("TOPLEFT", page, "TOPLEFT", columnX[column], y)
	title:SetText(group.title)
	y = y - 15
	for each = 1, table.getn(group.rows) do
		StatCheck(columnX[column], y, columnWidth, group.rows[each][1], group.color)
		y = y - 15
	end
	columnY[column] = y - 6
end
page.y = math.min(columnY[1], math.min(columnY[2], columnY[3])) - 4
Button(page, "Stats back to default", 200, 0, Asked("Stats back to default?",
	"This class's numbers all shown again, in their first order.", "Back to default",
	function() if SurvivorUI_ResetStatOrder then SurvivorUI_ResetStatOrder() end end))

------------------------------------------------------------------------------
-- Jewelry: the Jewelry Collection (Jewelry.lua).

page = pages.jewelry
Header(page, "Jewelry", "The Jewelry Collection: every amulet, ring and trinket of the game's codex, found or still to find, and what each gives by rarity; your class's own amulets by spell.")
PanelHead(page, OnUnlessOff("jewelry"), Flip("jewelry"), "jewelry", nil, nil, nil, { font = "Jewelry",
	back = function() if SurvivorUI_ResetJewelryPlace then SurvivorUI_ResetJewelryPlace() end end })
Check(page, "Beside the character pane", function() return SurvivorUI_JewelryWithPane and SurvivorUI_JewelryWithPane() end,
	function()
		if SurvivorUI_SetJewelryWithPane and SurvivorUI_JewelryWithPane then
			SurvivorUI_SetJewelryWithPane(not SurvivorUI_JewelryWithPane())
		end
	end, "each time the pane opens; off: /sui collection opens it")
page.y = page.y - 4
local forget = Button(page, "Forget the collection", 170, 0, function()
	if SurvivorUI_ResetCollection then
		SurvivorUI_ResetCollection()
	end
end, { 0.95, 0.40, 0.35 })
local forgetNote = Text(page, 9, MUTED)
forgetNote:SetPoint("LEFT", forget, "RIGHT", 12, 0)
forgetNote:SetText("Every piece, for every class and account on this game: the word forget typed first.")
page.y = page.y - 30

------------------------------------------------------------------------------
-- Frames & bar: the player's and the target's frames, and the action bar.

page = pages.units
Header(page, "Frames & bar", "Your frame and your target's, the action bar and the tooltip (the minimap has a tab of its own). While this tab is open, drag the frames or the buffs to move them.")
InlineChecks(page, {
	{ "Unit frames", FeatureOn("unitFrames"), FeatureToggle("unitFrames") },
	{ "Action bar", FeatureOn("actionBar"), FeatureToggle("actionBar") },
	{ "Buffs", FeatureOn("buffs"), FeatureToggle("buffs") },
}, "On")
Note(page, "Each a module, as in Modules: off, the game's own comes back. After a reload.")
Subheader(page, "Health numbers")
Note(page, "The percent, the health left, the health left of the whole, or the health left and the percent. Always short: 1.2M for 1,200,000.")
HealthRow("Player", "playerHealth", "absolutePercent")
HealthRow("Target", "targetHealth", "absolutePercent")
Note(page, "The boss bars' health: the Boss bars tab.")
Subheader(page, "Action bar")
Check(page, "Cooldown numbers on the buttons", FeatureOn("cooldownNumbers"), FeatureToggle("cooldownNumbers"), "OmniCC, when installed, does it instead")
Check(page, "Short cooldowns too (1.5 s or less)", function() return DB().shortCooldowns ~= false end,
	function()
		if DB().shortCooldowns == false then
			DB().shortCooldowns = nil
		else
			DB().shortCooldowns = false
		end
	end, "with much haste; and the global cooldown, cast by hand")
Check(page, "Hide key labels on the buttons", FeatureOn("hideKeys"), FeatureToggle("hideKeys"), "after a reload")
Check(page, "Player and target frames move with the action bar",
	function() return SurvivorUI_LinkFrames and SurvivorUI_LinkFrames() end,
	function()
		if SurvivorUI_SetLinkFrames and SurvivorUI_LinkFrames then
			SurvivorUI_SetLinkFrames(not SurvivorUI_LinkFrames())
		end
	end)
page.y = page.y - 4
Button(page, "Center the action bar", 200, 0, Call("SurvivorUI_CenterRow"))
Button(page, "Frames back in place", 200, 212, function()
	if SurvivorUI_ResetPiece then
		for _, name in pairs({ "Player frame", "Target frame", "Buffs" }) do
			SurvivorUI_ResetPiece(name)
		end
	end
end)
page.y = page.y - 28
Subheader(page, "Size")
SizeGrid(page, {
	PartSize("middle", "Whole center bar"), PartSize("bar", "Action bar"),
	PartSize("frames", "Player and target"), PartSize("buffs", "Buffs"),
	{ "Tooltip", 0.5, 2, 0.05,
		function() return SurvivorUI_TooltipSize and SurvivorUI_TooltipSize() or 1 end,
		function(value) if SurvivorUI_SetTooltipSize then SurvivorUI_SetTooltipSize(value) end end },
})

------------------------------------------------------------------------------
-- Minimap: its look and size, and the pins a run puts on it (MapPins.lua).

page = pages.minimap
Header(page, "Minimap", "Its look and its size, and the pins a run puts on it: each guardian's lair its own mark, a chest for each cache. While this tab is open, drag the minimap or its button to move them.")
Button(page, "Back to its place", 150, PAGE_WIDTH - 150, function()
	if SurvivorUI_ResetPiece then
		SurvivorUI_ResetPiece("Minimap")
	end
end)
Check(page, "Square minimap", FeatureOn("minimap"), FeatureToggle("minimap"), "its buttons tidied; after a reload")
Check(page, "Run History button", OnUnlessOff("historyMapButton"), function()
	DB().historyMapButton = DB().historyMapButton == false
	if SurvivorUI_PlaceMapButtons then
		SurvivorUI_PlaceMapButtons()
	end
end, "the hourglass over the [S], opening Run History")
Check(page, "Clock and FPS", OnUnlessOff("minimapClock"), Flip("minimapClock"),
	"along its bottom: your time (the time zone in This Run) and the frames a second")
Inline(page, "Clock", { { "24", "24 hours" }, { "12", "12 hours" } },
	function() return DB().clock12 and "12" or "24" end,
	function(value) DB().clock12 = value == "12" or nil end)
Slider(page, "Size", 0.5, 2, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale("minimap") or 1 end,
	function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("minimap", value) end end)

-- The pins as they are set, drawn under the settings; each size slider redraws it.
local pinPreview

local function PinSizeSlider(label, kind)
	Slider(page, label, 10, 28, 1,
		function() return SurvivorUI_PinSize and SurvivorUI_PinSize(kind) or 16 end,
		function(value)
			if SurvivorUI_SetPinSize then
				SurvivorUI_SetPinSize(kind, value)
			end
			if pinPreview then
				pinPreview:Refresh()
			end
		end, "%d")
end

Subheader(page, "Pins")
Check(page, "Pins on the minimap", FeatureOn("mapPins"), FeatureToggle("mapPins", true), "all of them; the same as Minimap pins in Modules")
Check(page, "Lairs", OnUnlessOff("pinLairs"), Flip("pinLairs"), "each guardian's lair, alive or empty")
PinSizeSlider("Lair size", "lair")
Check(page, "Lair marks", OnUnlessOff("guardianMarks"), Flip("guardianMarks"), "off: a skull for each lair; the same marks as the run tracker's and the boss bars'")
Inline(page, "An empty lair", { { "dim", "Dimmed" }, { "hide", "Hidden" } },
	function() return DB().pinEmpty == "hide" and "hide" or "dim" end,
	function(value) DB().pinEmpty = value == "hide" and "hide" or nil end)
Check(page, "Caches", OnUnlessOff("pinCaches"), Flip("pinCaches"), "a chest for each one on the field")
PinSizeSlider("Cache size", "cache")
Inline(page, "Out of reach", { { "edge", "On the edge" }, { "hide", "Hidden" } },
	function() return DB().pinEdge == "hide" and "hide" or "edge" end,
	function(value) DB().pinEdge = value == "hide" and "hide" or nil end)
Note(page, "On the edge: a pin past the minimap's reach sits on its edge, smaller and fainter, pointing the way. Hidden: only what the minimap reaches.")

Subheader(page, "The game's flag")
Inline(page, "Red flag", { { "ours", "Our glow" }, { "game", "The game's" }, { "none", "Off" } },
	function() return SurvivorUI_GameFlag and SurvivorUI_GameFlag() or "game" end,
	function(value) if SurvivorUI_SetGameFlag then SurvivorUI_SetGameFlag(value) end end)
Note(page, "The game flags the lair to head for: the nearest with its guardian, else the one back soonest. Our glow: the flag put away, that lair's mark glowing gold on the minimap and in the run tracker. The game's: its red flag. Off: neither. With the pins off (Modules), the game's flag is back, unless its The game's is unticked there. From the game's 0.102.")

-- The preview: the eight marks (or the skull) at the lairs' size and the chest
-- at the caches', on a minimap's grass, as the settings stand.
Subheader(page, "Preview")
pinPreview = CreateFrame("Frame", nil, page)
pinPreview:SetWidth(PAGE_WIDTH)
pinPreview:SetHeight(40)
pinPreview:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
pinPreview.back = Fill(pinPreview, "BACKGROUND", 0.20, 0.26, 0.13, 0.95)
pinPreview.back:SetAllPoints(pinPreview)
pinPreview.icons = {}
for index = 1, 9 do
	pinPreview.icons[index] = pinPreview:CreateTexture(nil, "ARTWORK")
end
-- The first lair as the flagged one, with our glow.
pinPreview.glow = pinPreview:CreateTexture(nil, "BORDER")
pinPreview.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
pinPreview.glow:SetBlendMode("ADD")
pinPreview.glow:SetVertexColor(1, 0.82, 0.2, 0.85)
pinPreview.glow:SetPoint("CENTER", pinPreview.icons[1], "CENTER", 0, 0)
pinPreview.none = Text(pinPreview, 10, MUTED)
pinPreview.none:SetPoint("CENTER", pinPreview, "CENTER", 0, 0)
pinPreview.none:SetText("No pins")
function pinPreview:Refresh()
	local pinsOn = not SurvivorUI_Feature or SurvivorUI_Feature("mapPins")
	local lairsOn = pinsOn and DB().pinLairs ~= false
	local cachesOn = pinsOn and DB().pinCaches ~= false
	local lair = SurvivorUI_PinSize and SurvivorUI_PinSize("lair") or 16
	local cache = SurvivorUI_PinSize and SurvivorUI_PinSize("cache") or 16
	local x = 14
	for index = 1, 8 do
		local icon = self.icons[index]
		if lairsOn and (index == 1 or DB().guardianMarks ~= false) then
			icon:SetWidth(lair)
			icon:SetHeight(lair)
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", self, "LEFT", x + lair / 2, 0)
			if DB().guardianMarks ~= false and SurvivorUI_SetLairMark then
				SurvivorUI_SetLairMark(icon, index)
			else
				icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PinLair")
				icon:SetTexCoord(0, 1, 0, 1)
				icon:SetVertexColor(1, 1, 1, 1)
				icon:Show()
			end
			x = x + lair + 8
		else
			icon:Hide()
		end
	end
	if lairsOn and SurvivorUI_GameFlag and SurvivorUI_GameFlag() == "ours" then
		self.glow:SetWidth(lair * 2.4)
		self.glow:SetHeight(lair * 2.4)
		self.glow:Show()
	else
		self.glow:Hide()
	end
	local chest = self.icons[9]
	if cachesOn then
		chest:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PinCache")
		chest:SetWidth(cache)
		chest:SetHeight(cache)
		chest:ClearAllPoints()
		chest:SetPoint("CENTER", self, "LEFT", x + 10 + cache / 2, 0)
		chest:Show()
	else
		chest:Hide()
	end
	if lairsOn or cachesOn then
		self.none:Hide()
	else
		self.none:Show()
	end
end
table.insert(widgets, pinPreview)
page.y = page.y - 46

------------------------------------------------------------------------------
-- Chat.

page = pages.chat
Header(page, "Chat", "The chat window: flat, its buttons on hover (Flat chat, in the Modules tab), its text's size, and what reaches it.")
PanelHead(page, FeatureOn("chat"), FeatureToggle("chat"), nil, "Chat", true, nil, { font = false })
Slider(page, "Text size", 8, 18, 1,
	function() return SurvivorUI_ChatSize and SurvivorUI_ChatSize() or 8 end,
	function(value) if SurvivorUI_SetChatSize then SurvivorUI_SetChatSize(value) end end, "%d pt")
Slider(page, "Background", 0, 100, 5,
	function() return math.floor((SurvivorUI_ChatBackground and SurvivorUI_ChatBackground() or 0) * 100 + 0.5) end,
	function(value) if SurvivorUI_SetChatBackground then SurvivorUI_SetChatBackground(value / 100) end end, "%d%%")
Note(page, "0%: the text on the world itself. Up from there, a dark panel behind it, the addon's color down its left edge. With Flat chat on.")

Subheader(page, "Chat filter")
Note(page, "What a run fills the chat with, kept away, in every language; the alerts stay: a new spell, an upgrade's news, the run's end. New lines only.")
Check(page, "Level-ups", OnUnlessOff("chatFilterLevels"), Flip("chatFilterLevels"), "\"you have reached level 12\" and its gains: the XP bar shows the level")
Check(page, "What the banners show", OnUnlessOff("chatFilterBanners"), Flip("chatFilterBanners"), "the horde's moves, a boss or a guardian coming or slain, shown mid-screen by the game; keep them if its Show Banners is off")
Check(page, "Boss yells", OnUnlessOff("chatFilterYells"), Flip("chatFilterYells"), "\"Hogger yells: Grrr... fresh meat!\"")
Check(page, "Loot, while the loot list is on", OnUnlessOff("chatFilterLoot"), Flip("chatFilterLoot"), "the list has it")
Check(page, "The Combat Log window", OnUnlessOff("chatFilterCombat"), Flip("chatFilterCombat"), "fed 13 lines a second, opened or not; SurvivorUI reads the fight from the game's own events, never from it")

------------------------------------------------------------------------------
-- Tooltips: the spells' (AbilityTooltip.lua) and the Biggest Crits' cards;
-- the ranks' option also the meter's.

page = pages.tooltips
Header(page, "Tooltips", "Your spells' tooltips, on the action bar and the build list, and the Biggest Crits' cards.")
Subheader(page, "Spell ranks")
Check(page, "Roman spell ranks (also applied to the meter)", OnlyIfOn("romanRanks"), function() DB().romanRanks = not DB().romanRanks or nil end,
	"LXIII instead of Rank 63 in the spells' tooltips and the Biggest Crits' cards, and instead of 63 after the spells' names in the damage meter, the run's and the Run History's")

------------------------------------------------------------------------------
-- Nameplates.

page = pages.plates
Header(page, "Nameplates", "Survivor Plates: a plate over the enemies within 20 yards of the hero, and over your own pets and totems, each kind as you choose (off by default: the run tracker shows the bosses, guardians and elites).")
if PlatesThere() then
	PanelHead(page, PlatesOn, function() Plates("none") end)
	-- Each kind on its own (Survivor Plates' show), a box each.
	local function Kind(label, kind, command, note)
		Check(page, label, function() return SurvivorPlates_Shown and SurvivorPlates_Shown(kind) end,
			function() Plates(command) end, note)
	end
	Subheader(page, "Friendly")
	Kind("Pets and summons", "pet", "pets", "a warlock's demons, the Water Elemental, spirit wolves, treants, a hunter's pets: small and green, with the name and icon")
	Kind("Totems", "totem", "totems", "a shaman's: small and blue")
	Subheader(page, "Enemy")
	Kind("Normal", "normal", "normal", "the rank and file of the horde")
	Kind("Elites", "elite", "elites", nil)
	Kind("Guardians", "guardian", "guardians", "told from an elite of the same name by its health")
	Kind("Bosses", "boss", "bosses", "a kind left out still shows as your target")
	Subheader(page, "Look")
	Check(page, "Names on every plate", function() return SurvivorPlatesDB and SurvivorPlatesDB.names == true end,
		function() Plates("names") end, "off: only on elites, guardians, bosses and friends")
	Check(page, "Ignore V and Shift+V", function() return not (SurvivorPlates_KeysAllowed and SurvivorPlates_KeysAllowed()) end,
		function() Plates("keys") end, "the game's keys for its plates: what they turn on or off goes back to the choices here")
	Slider(page, "Size", 0.5, 2, 0.05,
		function() return SurvivorPlates_GetScale and SurvivorPlates_GetScale() or 1 end,
		function(value) if SurvivorPlates_SetScale then SurvivorPlates_SetScale(value) end end)
else
	Note(page, "Survivor Plates is not installed. It comes in the same download as Survivor UI.")
end

------------------------------------------------------------------------------
-- Layout.

page = pages.layout
Header(page, "Layout", "Move UI, the button at the top of this window (or a right click on the minimap button), unlocks every piece over a grid: one let go snaps to the grid, or to a neighbour's edge. Holding Alt shows the same grid, and a piece dragged with Alt snaps too (let go of Alt first to put it down free). Click a piece for its card: its place, size and font, shown or hidden, reset and undo. Each tab's own pieces can be dragged while it is open, so you can play while setting them.")
Subheader(page, "Reset")
Button(page, "Every piece back in place", 220, 0, Asked("Every piece back in place?",
	"Every piece you moved goes back where it first stood.", "Back in place",
	function() if SurvivorUI_ResetLayout then SurvivorUI_ResetLayout() end end))
page.y = page.y - 32
Button(page, "Every size back to default", 220, 0, Asked("Every size back to default?",
	"Every part's own size back to its first; the whole interface's stays.", "Back to default",
	function() if SurvivorUI_ResetPartScales then SurvivorUI_ResetPartScales() end end))
page.y = page.y - 28

------------------------------------------------------------------------------
-- The bottom: the reload, and who made it.

-- Move UI: on every page, at the top right beside the page's title (and on
-- the minimized bar), in the Layout tab's color, filled and breathing a glow
-- so it is seen at once; "Done moving" while it is on.
local MOVE = { 0.25, 0.85, 0.8 }
local moveButtons = {}
local Minimize                  -- the window down to its bar, set below

local function MakeMoveButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(132)
	button:SetHeight(22)
	button:SetFrameLevel(parent:GetFrameLevel() + 5)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.glow = button:CreateTexture(nil, "BACKGROUND")
	button.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
	button.glow:SetBlendMode("ADD")
	button.glow:SetVertexColor(MOVE[1], MOVE[2], MOVE[3])
	button.glow:SetWidth(190)
	button.glow:SetHeight(54)
	button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text = Text(button, 11, { 1, 1, 1 })
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnClick", function()
		local on = not (SurvivorUI_EditMode and SurvivorUI_EditMode())
		if SurvivorUI_SetEditMode then
			SurvivorUI_SetEditMode(on)
		end
		for _, each in pairs(moveButtons) do
			each:Refresh()
		end
		-- Moving, the window steps aside: down to its bar.
		if on and this:GetParent() == panel then
			Minimize()
		end
	end)
	button:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
	button:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
	button:SetScript("OnShow", function() this:Refresh() end)
	button.age = 0
	button:SetScript("OnUpdate", function()
		this.age = this.age + arg1
		local breath = 0.5 + 0.5 * math.sin(this.age * 3)
		this.glow:SetAlpha((this.on and 0.75 or 0.35) + 0.3 * breath)
	end)
	function button:Refresh()
		local on = SurvivorUI_EditMode and SurvivorUI_EditMode()
		self.on = on
		self.text:SetText(on and "DONE MOVING" or "MOVE UI")
		local fill = on and 0.4 or (self.hot and 0.85 or 0.62)
		self:SetBackdropColor(MOVE[1] * fill, MOVE[2] * fill, MOVE[3] * fill, 1)
		self:SetBackdropBorderColor(1, 1, 1, (on or self.hot) and 1 or 0.75)
	end
	table.insert(moveButtons, button)
	return button
end

local editButton = MakeMoveButton(panel)
editButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -72, -10)
table.insert(widgets, editButton)

-- Save & Close: at the bottom right; Reload & Close, lit, while a look waits
-- for a reload.
local doneButton = CreateFrame("Button", nil, panel)
doneButton:SetWidth(170)
doneButton:SetHeight(28)
doneButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 12)
doneButton:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
doneButton.text = Text(doneButton, 11, TEXT)
doneButton.text:SetPoint("CENTER", doneButton, "CENTER", 0, 0)
doneButton:SetScript("OnClick", function()
	if needsReload then
		ReloadUI()
	else
		panel:Hide()
	end
end)
doneButton:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
doneButton:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
function doneButton:Refresh()
	if needsReload then
		self.text:SetText("Reload & Close")
		self.text:SetTextColor(1, self.hot and 1 or 0.85, self.hot and 1 or 0.8)
		self:SetBackdropColor(0.5, 0.14, 0.1, 1)
		self:SetBackdropBorderColor(1, 0.38, 0.32, 1)
	else
		self.text:SetText("Save & Close")
		if self.hot then
			self.text:SetTextColor(1, 1, 1)
		else
			self.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		end
		self:SetBackdropColor(0.12, 0.12, 0.15, 1)
		self:SetBackdropBorderColor(0.4, 0.4, 0.45, self.hot and 1 or 0.8)
	end
end
table.insert(widgets, doneButton)

------------------------------------------------------------------------------
-- Minimized: the window down to a small bar of three buttons, Maximize, Move
-- UI and Save & Close, so the screen is free to set the pieces; the open
-- tab's pieces stay movable. The bar moves by its edge, and Escape closes it
-- as it does the window.

local minimizing, restoring

local mini = CreateFrame("Frame", "SurvivorUIOptionsMini", UIParent)
mini:SetScale(0.8)
mini:SetWidth(380)
mini:SetHeight(40)
mini:SetFrameStrata("FULLSCREEN_DIALOG")
mini:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
mini:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
mini:SetBackdropBorderColor(0, 0, 0, 1)
mini:EnableMouse(true)
mini:SetMovable(true)
if mini.SetClampedToScreen then
	mini:SetClampedToScreen(true)
end
mini:RegisterForDrag("LeftButton")
mini:SetScript("OnDragStart", function() this:StartMoving() end)
mini:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
mini:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUIOptionsMini")
end

-- Closed for good (not put away to show the window again): move mode ends
-- and the tab's pieces lock again, as when the window closes.
mini:SetScript("OnHide", function()
	if restoring then
		return
	end
	if SurvivorUI_SetEditMode and SurvivorUI_EditMode and SurvivorUI_EditMode() then
		SurvivorUI_SetEditMode(false)
	end
	if SurvivorUI_SetMoveFocus then
		SurvivorUI_SetMoveFocus(nil)
	end
end)

local function MiniButton(text, width, onClick)
	local button = CreateFrame("Button", nil, mini)
	button:SetWidth(width)
	button:SetHeight(24)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(0.12, 0.12, 0.15, 1)
	button:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.8)
	button.text = Text(button, 10, TEXT)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
	end)
	button:SetScript("OnLeave", function()
		this.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		this:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.8)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

local function Maximize()
	restoring = true
	mini:Hide()
	restoring = nil
	panel:Show()
end

function Minimize()
	local right, top = panel:GetRight(), panel:GetTop()
	minimizing = true
	panel:Hide()
	minimizing = nil
	mini:SetScale(panel:GetScale())
	mini:ClearAllPoints()
	if right and top then
		mini:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
	else
		mini:SetPoint("TOP", UIParent, "TOP", 0, -40)
	end
	mini:Show()
end

local maximize = MiniButton("Maximize", 100, Maximize)
maximize:SetPoint("LEFT", mini, "LEFT", 8, 0)
local miniMove = MakeMoveButton(mini)
miniMove:SetHeight(24)
miniMove:SetPoint("LEFT", maximize, "RIGHT", 8, 0)
local miniDone = MiniButton("Save & Close", 116, function()
	if needsReload then
		ReloadUI()
	else
		mini:Hide()
	end
end)
miniDone:SetPoint("LEFT", miniMove, "RIGHT", 8, 0)
miniDone:SetScript("OnShow", function()
	this.text:SetText(needsReload and "Reload & Close" or "Save & Close")
end)

-- The - beside the x, in Move UI's teal.
local minimize = CornerButton("-", MOVE, 2)
minimize:SetPoint("RIGHT", close, "LEFT", -6, 0)
minimize:SetScript("OnEnter", function()
	this:Light(true)
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText("Minimize", 1, 1, 1)
	GameTooltip:AddLine("Down to Maximize, Move UI and Save & Close, to set the pieces with the screen free.", 0.8, 0.8, 0.8, 1)
	GameTooltip:Show()
end)
minimize:SetScript("OnLeave", function()
	this:Light(false)
	GameTooltip:Hide()
end)
minimize:SetScript("OnClick", Minimize)

local credit = panel:CreateFontString(nil, "OVERLAY")
credit:SetFont(SurvivorUI_FONT, 9, "")
credit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
credit:SetWidth(SIDEBAR - 18)
credit:SetJustifyH("LEFT")
credit:SetTextColor(0.42, 0.42, 0.47)
credit:SetText("by morderous\ngithub.com/morderous/\nsurvivor-ui\nGPL-3.0")

-- Over the credit: a coffee on Ko-fi, in a warm gold. The game opens no link:
-- it shows in a box, selected, for Ctrl+C.
local KOFI = "https://ko-fi.com/morderous"
local WARM = { 1.00, 0.80, 0.42 }

local linkBox
local function ShowLink(title, url)
	if not linkBox then
		linkBox = CreateFrame("Frame", "SurvivorUILinkBox", panel)
		linkBox:SetWidth(380)
		linkBox:SetHeight(104)
		linkBox:SetPoint("CENTER", panel, "CENTER", 0, 40)
		linkBox:SetFrameLevel(panel:GetFrameLevel() + 30)
		linkBox:EnableMouse(true)
		linkBox:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		linkBox:SetBackdropColor(0.08, 0.04, 0.03, 0.98)
		linkBox:SetBackdropBorderColor(WARM[1] * 0.75, WARM[2] * 0.75, WARM[3] * 0.75, 1)
		linkBox.title = Text(linkBox, 12, WARM)
		linkBox.title:SetPoint("TOP", linkBox, "TOP", 0, -14)
		linkBox.edit = CreateFrame("EditBox", nil, linkBox)
		local edit = linkBox.edit
		edit:SetWidth(340)
		edit:SetHeight(24)
		edit:SetPoint("TOP", linkBox, "TOP", 0, -40)
		edit:SetAutoFocus(false)
		edit:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
		edit:SetTextColor(1, 1, 1)
		edit:SetTextInsets(8, 8, 0, 0)
		edit:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		edit:SetBackdropColor(0, 0, 0, 0.85)
		edit:SetBackdropBorderColor(0.35, 0.3, 0.28, 1)
		-- The link stays as it is, whatever is typed; Enter or Escape closes.
		edit:SetScript("OnTextChanged", function()
			if this.url and this:GetText() ~= this.url then
				this:SetText(this.url)
				this:HighlightText()
			end
		end)
		edit:SetScript("OnEnterPressed", function() linkBox:Hide() end)
		edit:SetScript("OnEscapePressed", function() linkBox:Hide() end)
		linkBox.hint = Text(linkBox, 9, MUTED)
		linkBox.hint:SetPoint("TOP", edit, "BOTTOM", 0, -8)
		linkBox.hint:SetText("Ctrl+C copies it; paste it in your browser.")
		local shut = CreateFrame("Button", nil, linkBox)
		shut:SetWidth(18)
		shut:SetHeight(18)
		shut:SetPoint("TOPRIGHT", linkBox, "TOPRIGHT", -4, -4)
		shut.text = Text(shut, 11, MUTED)
		shut.text:SetPoint("CENTER", shut, "CENTER", 0, 0)
		shut.text:SetText("x")
		shut:SetScript("OnClick", function() linkBox:Hide() end)
		linkBox:SetScript("OnHide", function() this.edit:ClearFocus() end)
	end
	linkBox.title:SetText(title)
	linkBox.edit.url = url
	linkBox.edit:SetText(url)
	linkBox:Show()
	linkBox.edit:SetFocus()
	linkBox.edit:HighlightText()
end

local function WarmButton(width, onClick, tip)
	local button = CreateFrame("Button", nil, panel)
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(0.20, 0.07, 0.04, 1)
	button:SetBackdropBorderColor(WARM[1] * 0.7, WARM[2] * 0.7, WARM[3] * 0.7, 1)
	button:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(WARM[1], WARM[2], WARM[3], 1)
		if this.text then
			this.text:SetTextColor(1, 1, 1)
		end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(tip, WARM[1], WARM[2], WARM[3])
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(WARM[1] * 0.7, WARM[2] * 0.7, WARM[3] * 0.7, 1)
		if this.text then
			this.text:SetTextColor(WARM[1], WARM[2], WARM[3])
		end
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- A little smaller than the window's other buttons (a scale, so its words
-- shrink with it); its place in the window's own units.
local SUPPORT_SCALE = 0.7
local coffee = WarmButton(108, function() ShowLink("Buy me a coffee :)", KOFI) end,
	"If you want to support this love project, feel free.")
coffee:SetScale(SUPPORT_SCALE)
-- At the page's foot, level with Save & Close: over the credit it covered
-- the sidebar's last tab once the list grew (Summons, v3.0.22).
coffee:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (SIDEBAR + 18) / SUPPORT_SCALE, 20 / SUPPORT_SCALE)
coffee.text = Text(coffee, 9, WARM)
coffee.text:SetPoint("CENTER", coffee, "CENTER", 0, 0)
coffee.text:SetText("Buy me a coffee :)")

------------------------------------------------------------------------------

-- The Whole interface slider moved and let go: the window to its new size.
local refitter = CreateFrame("Frame")
refitter:SetScript("OnUpdate", function()
	if panel.refitAt and GetTime() >= panel.refitAt and not panel.sliding then
		panel.refitAt = nil
		if panel:IsShown() then
			FitWindow(panel)
		end
	end
end)

-- The game keeps the place it was dragged to, per character, and a change of
-- size since can leave it past the screen's edge: then it opens in the
-- middle again. /sui layout puts it there too.
function SurvivorUI_ResetOptionsPlace()
	panel:ClearAllPoints()
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
end

local function OnScreen()
	local left, right, top, bottom = panel:GetLeft(), panel:GetRight(), panel:GetTop(), panel:GetBottom()
	if not (left and right and top and bottom) then
		return false
	end
	local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
	left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
	return left >= -1 and bottom >= -1 and right <= GetScreenWidth() + 1 and top <= GetScreenHeight() + 1
end

panel:SetScript("OnShow", function()
	this.sliding = nil
	FitWindow(this)
	if not OnScreen() then
		SurvivorUI_ResetOptionsPlace()
	end
	ShowPage(current or "global")
end)
-- Closing the panel ends move mode, and its tab's pieces lock again; not when
-- it is only minimized.
panel:SetScript("OnHide", function()
	if minimizing then
		return
	end
	CharacterPaneFor(nil)
	if SurvivorUI_SetEditMode and SurvivorUI_EditMode and SurvivorUI_EditMode() then
		SurvivorUI_SetEditMode(false)
	end
	if SurvivorUI_SetMoveFocus then
		SurvivorUI_SetMoveFocus(nil)
	end
end)

function SurvivorUI_ToggleOptions()
	if mini:IsShown() then
		Maximize()
	elseif panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end

-- Move mode on and the grid laid out, the window down to its bar (the minimap
-- button's right click); Maximize opens it on the Layout page.
function SurvivorUI_OpenOptionsMoving()
	current = "layout"
	if SurvivorUI_SetEditMode then
		SurvivorUI_SetEditMode(true)
	end
	if not mini:IsShown() then
		panel:Show()
		Minimize()
	end
	for _, each in pairs(moveButtons) do
		each:Refresh()
	end
end

-- A new class color: what took it once takes it again; the rest reads it as
-- it refreshes.
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function()
		for index = 1, table.getn(accented) do
			accented[index]()
		end
		if panel:IsShown() then
			RefreshAll()
		end
	end)
end
