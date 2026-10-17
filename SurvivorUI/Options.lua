-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the options panel, /sui opt (or the minimap button).
--
-- A window with a column of tabs on the left, each in a color of its own, and
-- the tab's page on the right:
--   Global       the whole addon's font, color and size
--   Panels       every panel on or off
--   Run tracker  the tracker under the minimap: bosses, guardians, elites
--   Kill pace    the orb by the tracker's clock
--   Combat text  how the combat numbers show, or none at all
--   Counters     the numbers over the spells' buttons: DoTs, fears, totems
--   Nameplates   Survivor Plates: on every enemy, the dangerous ones, or none
--   Unit frames  the health numbers on the frames and the boss bars
--   Interface    the looks the addon gives the game's interface
--   Character    where the stats show, and which of them this class keeps
--   Size         each part's own size
--   Layout       move mode over a grid, the frames joined to the bar, resets
-- Most things act at once; a look that needs a reload lights the Reload
-- button at the bottom. Move mode sits beside it, on every page. Escape
-- closes the window.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH, HEIGHT = 640, 580
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
-- A fifth smaller than its layout; the type a point larger to make up for it.
panel:SetScale(0.8)
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

local close = CreateFrame("Button", nil, panel)
close:SetWidth(20)
close:SetHeight(20)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
close.text = Text(close, 13, MUTED)
close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
close.text:SetText("x")
close:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.35, 0.3) end)
close:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
close:SetScript("OnClick", function() panel:Hide() end)

------------------------------------------------------------------------------
-- Pages and their tabs.

local TABS = {
	{ key = "global", label = "Global", color = ACCENT },
	{ key = "panels", label = "Panels", color = { 0.45, 0.60, 1.00 } },
	{ key = "tracker", label = "Run tracker", color = { 0.30, 0.82, 0.40 } },
	{ key = "pace", label = "Kill pace", color = { 0.78, 0.95, 0.30 } },
	{ key = "combat", label = "Combat text", color = { 1.00, 0.38, 0.32 } },
	{ key = "counters", label = "Counters", color = { 0.40, 0.92, 0.70 } },
	{ key = "plates", label = "Nameplates", color = { 0.70, 0.55, 1.00 } },
	{ key = "units", label = "Unit frames", color = { 1.00, 0.62, 0.25 } },
	{ key = "interface", label = "Interface", color = { 0.35, 0.78, 1.00 } },
	{ key = "character", label = "Character", color = { 1.00, 0.50, 0.70 } },
	{ key = "size", label = "Size", color = { 0.85, 0.50, 1.00 } },
	{ key = "layout", label = "Layout", color = { 0.25, 0.85, 0.80 } },
}

local pages, tabButtons, widgets = {}, {}, {}
local current

local function RefreshAll()
	for index = 1, table.getn(widgets) do
		widgets[index]:Refresh()
	end
end

local function ShowPage(key)
	current = key
	for _, tab in pairs(TABS) do
		local page, button = pages[tab.key], tabButtons[tab.key]
		if tab.key == key then
			page:Show()
		else
			page:Hide()
		end
		button:Refresh()
	end
	RefreshAll()
end

for index = 1, table.getn(TABS) do
	local tab = TABS[index]
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
	button:SetHeight(26)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -56 - (index - 1) * 30)
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
		holder.value:SetText(string.format(format or "%.2f", value))
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
Check(page, "One font everywhere", FeatureOn("fonts"), FeatureToggle("fonts"), "the game's own windows too, after a reload")
page.y = page.y - 6
Button(page, "Every font back to default", 200, 0, function()
	if SurvivorUI_ResetFonts then
		SurvivorUI_ResetFonts()
	end
	RefreshAll()
end)
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
	function(value) if SurvivorUI_SetScale then SurvivorUI_SetScale(value, true) end end)
Note(page, "Each part also has a size of its own, on top of this one: the Size tab.")

------------------------------------------------------------------------------
-- Panels.

page = pages.panels
Header(page, "Panels", "Each turns on or off at once. To move one, hold Alt and drag it, or use move mode (Layout).")
Subheader(page, "Lists")
Check(page, "Build list", OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild"), "your spells, ranks and jewelry; off: the game's own")
Check(page, "Damage meter", OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter"), "off: the game's own")
Check(page, "This Run", OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun"), "the run's numbers")
Check(page, "Biggest Crits", OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits"), "each ability's biggest critical strike")
Check(page, "Loot list", OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot"), "what the run dropped; off: the game's own notices")
Subheader(page, "Boss bars")
Check(page, "Boss bars", OnUnlessOff("bossBars"), Call("SurvivorUI_BossBars"), "with their debuffs; away while the run tracker shows the bosses' health")
Check(page, "Elites on the boss bars", OnlyIfOn("bossBarsElites"), Call("SurvivorUI_BossBars", "elites"))
Subheader(page, "On the screen")
Check(page, "Kills and gold line", OnUnlessOff("tally"), Call("SurvivorUI_Tally"), "under the action bar; off: the game's own box")
Check(page, "Caches and lairs on the minimap", FeatureOn("mapPins"), FeatureToggle("mapPins", true))

------------------------------------------------------------------------------
-- Run tracker: the clock, the bosses, the guardians and the elites
-- (Tracker.lua, Guardians.lua).

page = pages.tracker
Header(page, "Run tracker", "Under the minimap: the zone, the run's clock against its length with a tick for each boss, the bosses, the guardians, the elites alive and your level.")
Check(page, "Run tracker", OnUnlessOff("tracker"), Call("SurvivorUI_ToggleTracker"), "off: the game's own clock")

Subheader(page, "Bosses")
Check(page, "Boss health in the tracker", OnlyIfOn("trackerHealth"), function()
	DB().trackerHealth = not DB().trackerHealth
end, "in place of the boss bars; click a boss, a guardian or an elite to target it")

Subheader(page, "Guardians")
Check(page, "Guardians", OnUnlessOff("guardians"), Call("SurvivorUI_ToggleGuardians"), "each lair: which way, how far, alive or slain, and the goal of 4 by 8:00")
Choice(page, {
	{ "bar", "A bar in the tracker", "A stretch a lair, over the level: green with its arrow; red once slain, with the time until it is back." },
	{ "list", "A list beside the tracker", "A line a lair: its name, SPAWNED or the time until it is back, its yards and an arrow." },
}, function() return DB().guardiansDocked and "bar" or "list" end,
	function(choice) DB().guardiansDocked = choice == "bar" end)
Check(page, "Arrows north up", OnlyIfOn("guardiansNorth"), Call("SurvivorUI_ToggleGuardians", "north"), "off: they turn as you walk, straight ahead up")

Subheader(page, "Elites")
Check(page, "Elites in the tracker", OnUnlessOff("trackerElites"), function()
	DB().trackerElites = DB().trackerElites == false
end, "a small bar for each one alive, bright once it is hurt")

------------------------------------------------------------------------------
-- Kill pace: the orb by the run tracker's clock (Pace.lua).

page = pages.pace
Header(page, "Kill pace", "An orb right of the run tracker's clock: how fast the enemies die now, against your own runs on the same zone and modifiers at the same minute. Hover it for the numbers.")
Check(page, "Kill pace", OnUnlessOff("pace"), Call("SurvivorUI_TogglePace"), "the orb, and This Run's Kills / min")

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
		SurvivorUI_TogglePace("reset")
	end
end)
page.y = page.y - 28

------------------------------------------------------------------------------
-- Combat text.

page = pages.combat
Header(page, "Combat text")
Choice(page, {
	{ "survivor", "The addon's own  |cff8a8a90quick numbers, set up below|r" },
	{ "game", "The game's own  |cff8a8a90the engine's floating numbers and combat text|r" },
	{ "none", "None  |cff8a8a90no numbers at all|r" },
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
Choice(page, {
	{ "sides", "Beside the hero" },
	{ "enemies", "Over the enemies", "Needs nameplates on (Nameplates tab); without them, they ring the hero." },
}, CTGet("ctLayout"), CTSet("ctLayout"))
Slider(page, "Distance from hero", 60, 320, 10, CTGet("ctDistance"), CTSet("ctDistance"), "%d")
Slider(page, "How high they rise", 80, 320, 10, CTGet("ctRise"), CTSet("ctRise"), "%d")
Check(page, "Crits in a column of their own", CTGet("ctCritColumn"), CTToggle("ctCritColumn"), "on the right")

Subheader(page, "Look")
Check(page, "Source icons", CTGet("ctIcons"), CTToggle("ctIcons"), "the spell's icon; melee and shots show the weapon")
Check(page, "Damage meter colors", CTGet("ctMeterColors"), CTToggle("ctMeterColors"), "each source in its color from the meter")
Check(page, "Short numbers", CTGet("ctShort"), CTToggle("ctShort"), "1475 as 1.5k, 2,200,000 as 2.2M")
Slider(page, "Text size", 0.5, 1.5, 0.05, CTGet("ctSize"), CTSet("ctSize"))

Subheader(page, "What shows")
Check(page, "Damage over time", CTGet("ctPeriodic"), CTToggle("ctPeriodic"))
Check(page, "Heals", CTGet("ctHeals"), CTToggle("ctHeals"))
Check(page, "Damage taken", CTGet("ctTaken"), CTToggle("ctTaken"))
page.y = page.y - 6
Button(page, "Combat text back to default", 220, 0, function()
	if SurvivorUI_CTDefaults then
		SurvivorUI_CTDefaults()
	end
	RefreshAll()
end)
page.y = page.y - 28

------------------------------------------------------------------------------
-- Counters: the numbers over the spells' buttons (DotCounter.lua).

page = pages.counters
Header(page, "Counters", "A number over a spell's button: how many of it are out right now, in the spell's damage meter color.")
local function Flip(key)
	return function() DB()[key] = DB()[key] == false end
end
Subheader(page, "Damage over time")
Check(page, "DoTs", OnUnlessOff("dotCounter"), Flip("dotCounter"), "how many of each are ticking on the enemies")
Subheader(page, "Fear")
Check(page, "Fears", OnUnlessOff("fearCounter"), Flip("fearCounter"), "how many enemies each one holds")
Subheader(page, "Totems")
Check(page, "Totems", OnUnlessOff("totemCounter"), Flip("totemCounter"), "how many of each are down, and the seconds until the next one ends")

Subheader(page, "How close they are")
Note(page, "The game tells none of these outright: each is worked out from the combat log and your spells' cooldowns, so it can be off now and then.")
Note(page, "DoTs: counted by their ticks over the last two seconds, so a number eases in and out, and one on an enemy that dies stays up to two seconds.")
Note(page, "Fears: the game writes a fear's hit but not its end, so each enemy hit counts for the fear's full time, even when it breaks early or dies.")
Note(page, "Totems: nothing is written as a totem goes down or ends, so each cast (its cooldown starting over) counts one totem for the time its tooltip gives. Two set down at once by a talent count as one, and one that drops on its own (the Searing Totem every 14 sec) is not seen.")

------------------------------------------------------------------------------
-- Nameplates.

page = pages.plates
Header(page, "Nameplates", "Survivor Plates: a plate over each enemy within 20 yards of the hero.")
if PlatesThere() then
	local function PlatesMode()
		local db = SurvivorPlatesDB or {}
		if db.hidden then
			return "none"
		elseif db.important then
			return "important"
		end
		return "all"
	end
	Choice(page, {
		{ "all", "On every enemy", "Every enemy near you gets a plate." },
		{ "important", "Elites, guardians and bosses", "Only the dangerous ones: a cleaner screen." },
		{ "none", "None (the default)", "No plates: the run tracker shows the bosses, guardians and elites." },
	}, PlatesMode, function(mode)
		local db = SurvivorPlatesDB or {}
		if (mode == "none") ~= (db.hidden == true) then
			Plates("none")
		end
		if mode ~= "none" and (mode == "important") ~= (db.important == true) then
			Plates("all")
		end
	end)
	Subheader(page, "Look")
	Check(page, "Names on every plate", function() return SurvivorPlatesDB and SurvivorPlatesDB.names == true end,
		function() Plates("names") end, "off: only on elites, guardians and bosses")
	Slider(page, "Plate size", 0.6, 2, 0.05,
		function() return SurvivorPlates_GetScale and SurvivorPlates_GetScale() or 1 end,
		function(value) if SurvivorPlates_SetScale then SurvivorPlates_SetScale(value) end end)
else
	Note(page, "Survivor Plates is not installed. It comes in the same download as Survivor UI.")
end

------------------------------------------------------------------------------
-- Interface.

page = pages.interface
Header(page, "Interface", "How the addon restyles the game's own interface. Most of these take hold after a reload.")
Subheader(page, "Action bar")
Check(page, "Cooldown numbers on the buttons", FeatureOn("cooldownNumbers"), FeatureToggle("cooldownNumbers"), "OmniCC, when installed, does it instead")
Check(page, "Hide key labels on the buttons", FeatureOn("hideKeys"), FeatureToggle("hideKeys"))
Subheader(page, "Windows")
Check(page, "Character pane, restyled", FeatureOn("characterPane"), FeatureToggle("characterPane"), "the stats in sections; off: the game's own pane")
Check(page, "Ability tooltips, laid out again", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip"))
Check(page, "Flat tooltips", FeatureOn("tooltip"), FeatureToggle("tooltip"))
Check(page, "Flat chat", FeatureOn("chat"), FeatureToggle("chat"))
Subheader(page, "Screen")
Check(page, "Square minimap", FeatureOn("minimap"), FeatureToggle("minimap"))
Check(page, "Menu buttons in the corner, on hover", FeatureOn("microMenu"), FeatureToggle("microMenu"))
Check(page, "White outline under the mouse", OnUnlessOff("hover"), Call("SurvivorUI_ToggleHover"), "around the frame or button the mouse is on")

------------------------------------------------------------------------------
-- Unit frames: the player's and the target's frames, and the boss bars.

page = pages.units
Header(page, "Unit frames", "Your frame, your target's and the boss bars.")
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
Subheader(page, "Health numbers")
Note(page, "The percent, the health left, the health left of the whole, or the health left and the percent. Always short: 1.2M for 1,200,000.")
HealthRow("Player", "playerHealth", "absolutePercent")
HealthRow("Target", "targetHealth", "absolutePercent")
HealthRow("Boss bars", "bossHealth", "absolutePercent")

------------------------------------------------------------------------------
-- Character: where the run's numbers go, and which of them this class shows.

page = pages.character
Header(page, "Character pane & stats")
Subheader(page, "Where the stats show")
Choice(page, {
	{ "attached", "In the character pane" },
	{ "detached", "On their own, with the character pane" },
	{ "always", "On their own, always shown" },
}, function() return SurvivorUI_StatsMode and SurvivorUI_StatsMode() or "attached" end,
	function(mode) if SurvivorUI_SetStatsMode then SurvivorUI_SetStatsMode(mode) end end)

-- The class whose choices these are, named in the section's title.
local classTitle = Subheader(page, "Stats for this class")
local classWidget = {}
function classWidget:Refresh()
	local name = UnitClass and UnitClass("player")
	classTitle:SetText(string.upper("Stats for "..(name or "this class")))
end
table.insert(widgets, classWidget)
Note(page, "Each class keeps its own. A stat switched off never shows. To change their order, drag a stat or a group's title in the stats panel, in move mode or holding Alt.")

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
Button(page, "Default for this class", 200, 0, function()
	if SurvivorUI_ResetStatOrder then
		SurvivorUI_ResetStatOrder()
	end
	RefreshAll()
end)

------------------------------------------------------------------------------
-- Size.

page = pages.size
Header(page, "Size", "Each part's own size, on top of the whole interface's (the Global tab). Changes act at once.")
if SurvivorUI_ScaleParts then
	local parts = SurvivorUI_ScaleParts()
	for index = 1, table.getn(parts) do
		local part = parts[index]
		local key = part.key
		Slider(page, part.label, 0.5, 2, 0.05,
			function() return SurvivorUI_GetScale(key) end,
			function(value) SurvivorUI_SetPartScale(key, value) end)
	end
end
page.y = page.y - 6
Button(page, "Every part back to default", 200, 0, function()
	if SurvivorUI_ResetPartScales then
		SurvivorUI_ResetPartScales()
	end
	RefreshAll()
end)

------------------------------------------------------------------------------
-- Layout.

page = pages.layout
Header(page, "Layout", "Move mode, the button at the bottom of this window, unlocks every piece over a grid: one let go snaps to the grid, or to a neighbour's edge. Click a piece for its card: its place, size and font, shown or hidden, reset and undo.")
Subheader(page, "Action bar")
Check(page, "Player and target frames move with the action bar",
	function() return SurvivorUI_LinkFrames and SurvivorUI_LinkFrames() end,
	function()
		if SurvivorUI_SetLinkFrames and SurvivorUI_LinkFrames then
			SurvivorUI_SetLinkFrames(not SurvivorUI_LinkFrames())
		end
	end)
page.y = page.y - 6
Button(page, "Center the action bar", 220, 0, Call("SurvivorUI_CenterRow"))
page.y = page.y - 28
Subheader(page, "Reset")
Button(page, "Every piece back in place", 220, 0, Call("SurvivorUI_ResetLayout"))
page.y = page.y - 28

------------------------------------------------------------------------------
-- The bottom: the reload, and who made it.

-- Move mode: on every page, at the bottom right, in the Layout tab's color;
-- lit and saying so while it is on.
local MOVE = { 0.25, 0.85, 0.8 }
local editButton = CreateFrame("Button", nil, panel)
editButton:SetWidth(170)
editButton:SetHeight(28)
editButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 12)
editButton:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
editButton.text = Text(editButton, 11, MOVE)
editButton.text:SetPoint("CENTER", editButton, "CENTER", 0, 0)
editButton:SetScript("OnClick", function()
	local on = not (SurvivorUI_EditMode and SurvivorUI_EditMode())
	if SurvivorUI_SetEditMode then
		SurvivorUI_SetEditMode(on)
	end
	this:Refresh()
end)
editButton:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
editButton:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
function editButton:Refresh()
	local on = SurvivorUI_EditMode and SurvivorUI_EditMode()
	self.text:SetText(on and "Done moving" or "Move mode (grid)")
	if on then
		self:SetBackdropColor(MOVE[1] * 0.55, MOVE[2] * 0.55, MOVE[3] * 0.55, 1)
		self:SetBackdropBorderColor(1, 1, 1, 1)
		self.text:SetTextColor(1, 1, 1)
	else
		self:SetBackdropColor(MOVE[1] * 0.18, MOVE[2] * 0.18, MOVE[3] * 0.18, 1)
		self:SetBackdropBorderColor(MOVE[1], MOVE[2], MOVE[3], self.hot and 1 or 0.7)
		if self.hot then
			self.text:SetTextColor(1, 1, 1)
		else
			self.text:SetTextColor(MOVE[1], MOVE[2], MOVE[3])
		end
	end
end
table.insert(widgets, editButton)

local reloadButton = CreateFrame("Button", nil, panel)
reloadButton:SetWidth(150)
reloadButton:SetHeight(28)
reloadButton:SetPoint("RIGHT", editButton, "LEFT", -8, 0)
reloadButton:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
reloadButton.text = Text(reloadButton, 10, TEXT)
reloadButton.text:SetPoint("CENTER", reloadButton, "CENTER", 0, 0)
reloadButton:SetScript("OnClick", function() ReloadUI() end)
reloadButton:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
reloadButton:SetScript("OnLeave", function() this:Refresh() end)
function reloadButton:Refresh()
	if needsReload then
		self.text:SetText("Reload to apply")
		self.text:SetTextColor(1, 0.85, 0.8)
		self:SetBackdropColor(0.5, 0.14, 0.1, 1)
		self:SetBackdropBorderColor(1, 0.38, 0.32, 1)
	else
		self.text:SetText("Reload interface")
		self.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		self:SetBackdropColor(0.1, 0.1, 0.13, 1)
		self:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	end
end
table.insert(widgets, reloadButton)

local credit = panel:CreateFontString(nil, "OVERLAY")
credit:SetFont(SurvivorUI_FONT, 9, "")
credit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
credit:SetWidth(SIDEBAR - 18)
credit:SetJustifyH("LEFT")
credit:SetTextColor(0.42, 0.42, 0.47)
credit:SetText("by morderous\ngithub.com/morderous/\nsurvivor-ui\nGPL-3.0")

------------------------------------------------------------------------------

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
	return left >= -1 and bottom >= -1 and right <= UIParent:GetWidth() + 1 and top <= UIParent:GetHeight() + 1
end

panel:SetScript("OnShow", function()
	if not OnScreen() then
		SurvivorUI_ResetOptionsPlace()
	end
	ShowPage(current or "global")
end)
-- Closing the panel ends move mode.
panel:SetScript("OnHide", function()
	if SurvivorUI_SetEditMode and SurvivorUI_EditMode and SurvivorUI_EditMode() then
		SurvivorUI_SetEditMode(false)
	end
end)

function SurvivorUI_ToggleOptions()
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end

-- Open on the Layout page with move mode on and the grid laid out (the
-- minimap button).
function SurvivorUI_OpenOptionsMoving()
	current = "layout"
	panel:Show()
	if SurvivorUI_SetEditMode then
		SurvivorUI_SetEditMode(true)
	end
	ShowPage("layout")
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
