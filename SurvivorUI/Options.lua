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
-- Most things act at once. Move UI, at the sidebar's foot, unlocks every
-- piece over a grid; each tab's own pieces can be dragged while it is open, so
-- one can play while setting them. Save & Close at the bottom (Reload & Close
-- while a look waits for a reload), or Escape, closes the window; the - beside
-- the x minimizes it to a bar of three buttons.
--
-- The options menu rework (v3.1): a search box over the groups, each group
-- open one at a time, and the pages made of one kit (Kit, below the old
-- pieces): a head with the part's switch, a live preview where there is
-- something to see, choices as segments, pictures and chips, a size as S M L
-- and a bar, the fine settings in an Advanced box, Reset this page at the
-- foot. A page still made of the old pieces works as before, and every piece,
-- old or new, is found by the search.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"

local WIDTH, HEIGHT = 740, 740
local SIDEBAR = 184
local PAGE_X = SIDEBAR + 20               -- the pages' left edge
local PAGE_WIDTH = WIDTH - PAGE_X - 20
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
-- A click on the window itself gives the keys back to the game, from the
-- search box (set below).
panel:SetScript("OnMouseDown", function()
	if this.box then
		this.box:ClearFocus()
	end
end)
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
	-- In the game's language, as the window speaks it (Locale.lua).
	if SurvivorUI_Spoken then
		SurvivorUI_Spoken(text)
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
version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 7, 1)
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
	{ group = "General", color = ACCENT },
	{ key = "global", label = "Global", color = ACCENT },
	{ key = "modules", label = "Modules", color = { 0.95, 0.80, 0.35 } },
	{ key = "layout", label = "Layout", color = { 0.25, 0.85, 0.80 } },
	{ group = "Run", color = { 0.35, 0.82, 0.50 } },
	{ key = "tracker", label = "Run tracker", color = { 0.30, 0.82, 0.40 } },
	{ key = "pace", label = "Kill pace", color = { 0.78, 0.95, 0.30 } },
	{ key = "bosses", label = "Boss bars", color = { 0.95, 0.45, 0.35 } },
	{ key = "tally", label = "Kills & gold", color = { 1.00, 0.82, 0.30 } },
	{ key = "xpbar", label = "XP bar", color = { 0.72, 0.45, 1.00 } },
	{ key = "levelup", label = "Level Up!", color = { 1.00, 0.86, 0.30 } },
	{ key = "loot", label = "Loot list", color = { 0.55, 0.75, 1.00 } },
	{ key = "history", label = "Run History", color = { 0.82, 0.62, 1.00 } },
	{ group = "Combat", color = { 1.00, 0.50, 0.38 } },
	{ key = "combat", label = "Combat text", color = { 1.00, 0.38, 0.32 } },
	{ key = "range", label = "Range indicator", color = { 0.55, 0.82, 1.00 } },
	{ key = "rangespell", label = "Spell per class", color = { 0.55, 0.82, 1.00 } },
	{ key = "meter", label = "Damage meter", color = { 1.00, 0.58, 0.25 } },
	{ key = "run", label = "This Run", color = { 0.45, 0.60, 1.00 } },
	{ key = "crits", label = "Biggest Crits", color = { 1.00, 0.76, 0.10 } },
	{ key = "records", label = "Records", color = { 1.00, 0.55, 0.22 } },
	{ key = "counters", label = "Counters", color = { 0.40, 0.92, 0.70 } },
	{ key = "summons", label = "Summons", color = { 0.62, 0.42, 0.95 } },
	{ key = "party", label = "Party", color = { 0.45, 0.78, 1.00 } },
	{ group = "Character", color = { 0.95, 0.55, 0.78 } },
	{ key = "build", label = "Build list", color = { 0.45, 0.85, 1.00 } },
	{ key = "worn", label = "Jewelry worn", color = { 0.92, 0.76, 0.45 } },
	{ key = "character", label = "Character pane", color = { 1.00, 0.50, 0.70 } },
	{ key = "stats", label = "Stats panel", color = { 0.95, 0.62, 0.88 } },
	{ key = "jewelry", label = "Jewelry collection", color = { 0.92, 0.76, 0.45 } },
	{ group = "Interface", color = { 0.45, 0.72, 1.00 } },
	{ key = "units", label = "Frames & bar", color = { 1.00, 0.62, 0.25 } },
	{ key = "minimap", label = "Minimap", color = { 0.55, 0.82, 0.40 } },
	{ key = "mapbuttons", label = "Minimap buttons", color = { 0.45, 0.88, 0.66 } },
	{ key = "chat", label = "Chat", color = { 0.60, 0.80, 0.95 } },
	{ key = "tooltips", label = "Tooltips", color = { 0.90, 0.86, 0.62 } },
	{ key = "plates", label = "Nameplates", color = { 0.70, 0.55, 1.00 } },
	{ key = "marks", label = "Raid marks", color = { 0.95, 0.60, 0.50 } },
	{ key = "world", label = "World markers", color = { 0.50, 0.85, 0.95 } },
	{ group = "Experimental", color = { 1.00, 0.45, 0.75 },
		tip = "Everything you see here is subject to change and is for testing only. Feel free to give your feedback on Discord: I read every one." },
	{ key = "dial", label = "Tracker Ring", color = { 0.40, 0.88, 0.50 } },
	{ key = "nobg", label = "No backgrounds", color = { 0.70, 0.70, 0.95 } },
}

local pages, tabButtons, widgets = {}, {}, {}
local current

-- The sidebar's own (below): its groups, the one open, the search box, the
-- search's index and its results; and the pieces sized by their words, fit
-- again as the window speaks another language (side.Speak, in the kit).
local side = { groups = {}, index = {}, fits = {} }

local function RefreshAll()
	if side.Speak then
		side.Speak()
	end
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
			SurvivorUI_Confirm({ title = SurvivorUI_OT(title), text = SurvivorUI_OT(text), yes = SurvivorUI_OT(yes),
				word = word, onYes = Done })
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
	meter = { "Damage meter", "Meter now" },
	party = { "Party frames", "Revive bar" },
	run = { "This Run" },
	records = { "New best crit", "New jump record" },
	crits = { "Biggest Crits" },
	build = { "Build list" },
	worn = { "Jewelry worn" },
	character = { "Character pane" },
	stats = { "Stats" },
	units = { "Player frame", "Target frame", "Target debuffs", "Buffs" },
	minimap = { "Minimap", "Minimap buttons" },
	mapbuttons = { "Minimap buttons" },
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
	if side.results then
		side.results:Hide()
	end
	-- A tab picked in the middle of a search: the search ends, and the keys
	-- go back to the game (not when the search was only emptied: typing).
	if side.box and not side.typing then
		if side.box:GetText() ~= "" then
			side.going = true
			side.box:SetText("")
			side.going = nil
			side.found = nil
		end
		side.box:ClearFocus()
	end
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
	-- Its group open in the sidebar, the page's tab in sight.
	if side.Open and pages[key] then
		side.Open(pages[key].group)
	end
	RefreshAll()
end

-- The sidebar from its top down: the search box, then each group's head (an
-- arrow, its name, how many tabs it holds), the open group's tabs under it,
-- one group open at a time. Donate and Move UI stand at its foot.
local GROUP_TOP, GROUP_HEIGHT, TAB_HEIGHT = -78, 24, 20
local group
for index = 1, table.getn(TABS) do
	local tab = TABS[index]
	if tab.group then
		group = { name = tab.group, color = tab.color, tabs = {}, tip = tab.tip }
		table.insert(side.groups, group)
		local head = CreateFrame("Button", nil, panel)
		head:SetWidth(SIDEBAR - 16)
		head:SetHeight(GROUP_HEIGHT)
		head.wash = Fill(head, "BACKGROUND", 1, 1, 1, 0)
		head.wash:SetAllPoints(head)
		head.arrow = head:CreateTexture(nil, "ARTWORK")
		head.arrow:SetTexture(ART.."DropArrow")
		head.arrow:SetWidth(11)
		head.arrow:SetHeight(11)
		head.arrow:SetPoint("LEFT", head, "LEFT", 6, 0)
		head.label = Text(head, 10, TEXT)
		head.label:SetPoint("LEFT", head, "LEFT", 23, 0)
		head.label:SetText(string.upper(tab.group))
		head.count = Text(head, 9, MUTED)
		head.count:SetPoint("RIGHT", head, "RIGHT", -7, 0)
		head.group = group
		group.head = head
		function head:Refresh()
			local open = side.open == self.group.name
			local c = self.group.color
			-- The arrow down while open, turned to the right while shut.
			if open then
				self.arrow:SetTexCoord(0, 1, 0, 1)
			else
				self.arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
			end
			self.arrow:SetVertexColor(c[1], c[2], c[3], open and 1 or 0.7)
			self.wash:SetVertexColor(1, 1, 1, self.hot and 0.05 or 0)
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif open then
				self.label:SetTextColor(c[1], c[2], c[3])
			else
				self.label:SetTextColor(TEXT[1] * 0.85, TEXT[2] * 0.85, TEXT[3] * 0.85)
			end
			self.count:SetText(table.getn(self.group.tabs))
		end
		-- A group's own word on hover (Experimental's), when it has one.
		head:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			if this.group.tip then
				local c = this.group.color
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(SurvivorUI_OT(this.group.name), c[1], c[2], c[3])
				GameTooltip:AddLine(SurvivorUI_OT(this.group.tip), 1, 1, 1, 1)
				GameTooltip:Show()
			end
		end)
		head:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		head:SetScript("OnClick", function() side.Open(this.group.name, true) end)
	else
		local page = CreateFrame("Frame", nil, panel)
		page:SetPoint("TOPLEFT", panel, "TOPLEFT", PAGE_X, -16)
		page:SetWidth(PAGE_WIDTH)
		page:SetHeight(HEIGHT - 70)
		page.color = tab.color
		page.y = 0
		page.key, page.label, page.group = tab.key, tab.label, group.name
		page:Hide()
		pages[tab.key] = page
		-- Found by its name too.
		table.insert(side.index, { page = page, key = tab.key, label = tab.label, y = 0, height = 22,
			words = string.lower(tab.label.." "..group.name), order = table.getn(side.index) })

		-- The tab: its name, a bar of its color at the left, a wash when chosen;
		-- set in its place as its group opens.
		local button = CreateFrame("Button", nil, panel)
		button:SetWidth(SIDEBAR - 26)
		button:SetHeight(TAB_HEIGHT)
		table.insert(group.tabs, button)
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

-- Each group's head and, under the open one, its tabs, from the top down.
function side.Lay()
	local y = GROUP_TOP
	for index = 1, table.getn(side.groups) do
		local each = side.groups[index]
		each.head:ClearAllPoints()
		each.head:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
		each.head:Refresh()
		y = y - GROUP_HEIGHT - 2
		local open = side.open == each.name
		for slot = 1, table.getn(each.tabs) do
			local button = each.tabs[slot]
			if open then
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y)
				button:Show()
				y = y - TAB_HEIGHT - 1
			else
				button:Hide()
			end
		end
		if open then
			y = y - 6
		end
	end
end

-- A group open, the rest shut; its head clicked again shuts it (clicked).
function side.Open(name, clicked)
	if clicked and side.open == name then
		side.open = nil
	else
		side.open = name
	end
	side.Lay()
end

-- The search box, under the title: what is typed finds every setting by its
-- name, its note or its tab's (the search's words, each found somewhere);
-- Enter opens the first found, Escape empties it.
local searchBox = CreateFrame("EditBox", nil, panel)
side.box = searchBox
panel.box = searchBox
searchBox:SetWidth(SIDEBAR - 20)
searchBox:SetHeight(24)
searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -42)
searchBox:SetAutoFocus(false)
searchBox:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "")
searchBox:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
searchBox:SetTextInsets(24, 8, 0, 0)
searchBox:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
searchBox:SetBackdropColor(0.085, 0.085, 0.11, 1)
searchBox:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
searchBox.glass = searchBox:CreateTexture(nil, "OVERLAY")
searchBox.glass:SetTexture(ART.."Search")
searchBox.glass:SetWidth(12)
searchBox.glass:SetHeight(12)
searchBox.glass:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
searchBox.glass:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 1)
searchBox.hint = Text(searchBox, 9, MUTED, "")
searchBox.hint:SetPoint("LEFT", searchBox, "LEFT", 24, 0)
searchBox.hint:SetText("Search: crit, size, sound")
searchBox:SetScript("OnEditFocusGained", function()
	this.hint:Hide()
	this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
end)
searchBox:SetScript("OnEditFocusLost", function()
	if this:GetText() == "" then
		this.hint:Show()
	end
	this:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
end)
searchBox:SetScript("OnTextChanged", function()
	if not side.going then
		side.Search(this:GetText())
	end
end)
searchBox:SetScript("OnEscapePressed", function()
	this:SetText("")
	this:ClearFocus()
end)
searchBox:SetScript("OnEnterPressed", function()
	if side.found and side.found[1] then
		side.Go(side.found[1])
	else
		this:ClearFocus()
	end
end)

-- What the search finds, in the page's place: a row for each setting, its
-- tab's color, its name, and where it is.
local RESULT_ROWS = 20
local results = CreateFrame("Frame", nil, panel)
side.results = results
results:SetPoint("TOPLEFT", panel, "TOPLEFT", PAGE_X, -16)
results:SetWidth(PAGE_WIDTH)
results:SetHeight(HEIGHT - 70)
results:Hide()
results.title = Text(results, 13, ACCENT)
results.title:SetPoint("TOPLEFT", results, "TOPLEFT", 0, 0)
results.title:SetText("Search")
results.line = Text(results, 9, MUTED)
results.line:SetPoint("TOPLEFT", results.title, "BOTTOMLEFT", 0, -6)
results.rows = {}
for index = 1, RESULT_ROWS do
	local row = CreateFrame("Button", nil, results)
	row:SetWidth(PAGE_WIDTH)
	row:SetHeight(26)
	row:SetPoint("TOPLEFT", results, "TOPLEFT", 0, -44 - (index - 1) * 28)
	row:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	row:SetBackdropColor(0.075, 0.075, 0.095, 1)
	row:SetBackdropBorderColor(0.15, 0.15, 0.19, 1)
	row.dot = Fill(row, "ARTWORK", 1, 1, 1, 1)
	row.dot:SetWidth(6)
	row.dot:SetHeight(6)
	row.dot:SetPoint("LEFT", row, "LEFT", 10, 0)
	row.label = Text(row, 10, TEXT)
	row.label:SetPoint("LEFT", row, "LEFT", 24, 0)
	row.where = Text(row, 9, MUTED)
	row.where:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row:SetScript("OnEnter", function()
		local c = this.entry.page.color
		this:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		this.label:SetTextColor(1, 1, 1)
	end)
	row:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(0.15, 0.15, 0.19, 1)
		this.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	end)
	row:SetScript("OnClick", function() side.Go(this.entry) end)
	row:Hide()
	results.rows[index] = row
end

-- A setting found by the search: its page (or a page's Advanced box, which
-- opens with it), its name, its note's words too, and where it stands, to
-- light it once its page opens.
function side.Index(page, label, note, y, height)
	if not (page and page.key and label and label ~= "") then
		return
	end
	local clean = string.gsub(string.gsub(label, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
	table.insert(side.index, { page = page, key = page.key, label = clean, y = y or 0, height = height or ROW,
		advanced = page.advanced, words = string.lower(clean.." "..(note or "").." "..(page.label or "")),
		note = note, order = table.getn(side.index) })
end

-- A setting's words for the search, and its name's: its English, and while
-- the window speaks another language, its words in that one too, so either
-- finds it.
function side.Words(entry)
	local language = SurvivorUI_OptionsLanguage and SurvivorUI_OptionsLanguage()
	if not language then
		return entry.words, string.lower(entry.label)
	end
	if entry.saidIn ~= language then
		local page = pages[entry.key]
		entry.saidIn, entry.said = language, SurvivorUI_OT(entry.label)
		entry.saidWords = string.lower(entry.words.." "..entry.said.." "..SurvivorUI_OT(entry.note or "")
			.." "..SurvivorUI_OT(page.label or "").." "..SurvivorUI_OT(page.group or ""))
	end
	return entry.saidWords, string.lower(entry.label.." "..entry.said)
end

function side.Search(text)
	local query = string.lower(string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
	if query == "" then
		side.found = nil
		if results:IsShown() then
			side.typing = true
			ShowPage(current or "global")
			side.typing = nil
		end
		return
	end
	for _, page in pairs(pages) do
		page:Hide()
	end
	results:Show()
	-- Every word of it in the setting's words; the ones whose name holds it
	-- first, the rest in the window's order.
	local found = {}
	for index = 1, table.getn(side.index) do
		local entry = side.index[index]
		local words, name = side.Words(entry)
		local all = true
		for word in string.gfind(query, "%S+") do
			if not string.find(words, word, 1, true) then
				all = false
				break
			end
		end
		if all then
			entry.score = string.find(name, query, 1, true) and 0 or 1
			table.insert(found, entry)
		end
	end
	table.sort(found, function(a, b)
		if a.score ~= b.score then
			return a.score < b.score
		end
		return a.order < b.order
	end)
	side.found = found
	local count = table.getn(found)
	if count == 0 then
		results.line:SetText(SurvivorUI_OTF("Nothing found for \"{1}\".", text))
	elseif count > RESULT_ROWS then
		results.line:SetText(SurvivorUI_OTF("{1} found; the first {2} here. Another word narrows them.", count, RESULT_ROWS))
	else
		results.line:SetText(SurvivorUI_OTF("{1} found.", count))
	end
	for index = 1, RESULT_ROWS do
		local row, entry = results.rows[index], found[index]
		if entry then
			local c = entry.page.color
			row.entry = entry
			row.dot:SetVertexColor(c[1], c[2], c[3], 1)
			row.label:SetText(entry.label)
			local tab = pages[entry.key]
			row.where:SetText(SurvivorUI_OT(tab.group).."  >  "..SurvivorUI_OT(tab.label)
				..(entry.advanced and "  >  "..SurvivorUI_OT("Advanced") or ""))
			row:Show()
		else
			row:Hide()
		end
	end
end

-- A setting picked from the search: the box emptied, its page open (its
-- Advanced box too), and the setting lit a moment.
local flasher = CreateFrame("Frame", nil, panel)
flasher:Hide()
flasher:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local left = 1.6 - this.age
	if left <= 0 then
		this.light:SetAlpha(0)
		this:Hide()
		return
	end
	-- Two beats, then it fades.
	local beat = 0.5 + 0.5 * math.cos(this.age * 7.8)
	this.light:SetAlpha(math.min(1, left) * (0.12 + 0.2 * beat))
end)

function side.Go(entry)
	side.going = true
	searchBox:SetText("")
	searchBox:ClearFocus()
	side.going = nil
	side.found = nil
	if entry.advanced then
		DB().optionsAdvanced = true
	end
	ShowPage(entry.key)
	local holder = entry.page
	if not holder.light then
		holder.light = Fill(holder, "BORDER", 1, 1, 1, 0)
	end
	local c = holder.color
	holder.light:SetVertexColor(c[1], c[2], c[3], 1)
	holder.light:ClearAllPoints()
	holder.light:SetPoint("TOPLEFT", holder, "TOPLEFT", -6, entry.y + 3)
	holder.light:SetWidth((holder.width or PAGE_WIDTH) + 12)
	holder.light:SetHeight(entry.height + 6)
	if flasher.light and flasher.light ~= holder.light then
		flasher.light:SetAlpha(0)
	end
	flasher.light = holder.light
	flasher.age = 0
	flasher:Show()
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
	side.Index(page, text, nil, page.y, 16)
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

-- A suggestion boxed in an alert's amber, apart from the page's own color
-- (the Nameplates tab's): its title, then its words, room left on its right
-- for a button the caller puts there.
local ALERT = { 1.00, 0.70, 0.20 }
local function Callout(page, title, text, room)
	room = room or 0
	local box = CreateFrame("Frame", nil, page)
	box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	box:SetWidth(PAGE_WIDTH)
	box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(ALERT[1], ALERT[2], ALERT[3], 0.10)
	box:SetBackdropBorderColor(ALERT[1], ALERT[2], ALERT[3], 0.75)
	local head = Text(box, 10, ALERT)
	head:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -7)
	head:SetText(title)
	local body = Text(box, 9, TEXT)
	body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
	body:SetWidth(PAGE_WIDTH - 16 - room)
	body:SetJustifyH("LEFT")
	body:SetText(text)
	local height = 7 + 14 + 4 + 13 * Lines(body, PAGE_WIDTH - 16 - room) + 8
	box:SetHeight(height)
	page.y = page.y - height - 6
	return box
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
	side.Index(page, label, note, page.y, check:GetHeight())
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
		side.Index(page, option[2], option[3], page.y, row:GetHeight())
		page.y = page.y - row:GetHeight() - 2
	end
end

-- A choice in one row: an optional label on the left, then each option's ring
-- and words side by side.
-- labelWidth: the label's column, 140 unless given (a long row of choices).
local function Inline(page, label, options, get, set, labelWidth)
	local color = page.color
	local x = 0
	if label then
		local text = Text(page, 10, TEXT)
		text:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 3)
		text:SetText(label)
		x = labelWidth or 140
	end
	local rows, start, top = {}, x, page.y
	for index = 1, table.getn(options) do
		local option = options[index]
		local value = option[1]
		local row = CreateFrame("Button", nil, page)
		table.insert(rows, row)
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
	-- Their words in another language: side by side again, each as wide as them.
	table.insert(side.fits, function()
		local at = start
		for index = 1, table.getn(rows) do
			local row = rows[index]
			row:SetWidth(2 + 13 + 6 + row.label:GetStringWidth() + 18)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", page, "TOPLEFT", at, top)
			at = at + row:GetWidth()
		end
	end)
	local names = {}
	for index = 1, table.getn(options) do
		table.insert(names, options[index][2])
	end
	names = table.concat(names, " / ")
	side.Index(page, (label and label ~= "") and label or names, names, page.y, ROW)
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
	local checks, start, top = {}, x, page.y
	for index = 1, table.getn(items) do
		local item = items[index]
		local isOn, toggle = item[2], item[3]
		local check = CreateFrame("Button", nil, page)
		table.insert(checks, check)
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
		side.Index(page, item[1], label, page.y, ROW)
	end
	-- Their words in another language: side by side again, each as wide as them.
	table.insert(side.fits, function()
		local at = start
		for index = 1, table.getn(checks) do
			local check = checks[index]
			check:SetWidth(2 + 13 + 9 + check.label:GetStringWidth() + gap)
			check:ClearAllPoints()
			check:SetPoint("TOPLEFT", page, "TOPLEFT", at, top)
			at = at + check:GetWidth()
		end
	end)
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
			GameTooltip:SetText(SurvivorUI_OT(name), 1, 1, 1)
			GameTooltip:Show()
		end)
		swatch:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		swatch.classColor = not entry[3]
		function swatch:Refresh()
			-- The class's swatch in the hero's color as it is now (the pages
			-- are made before the run tells the hero's class).
			if self.classColor then
				local _, class = UnitClass("player")
				if class and SurvivorUI_ClassColor then
					self.fill:SetVertexColor(SurvivorUI_ClassColor(class))
				end
			end
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
	side.Index(page, label, "color", page.y, ROW)
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
		-- Switched off by another setting (holder.off): dimmed, it takes no mouse.
		if self.off then
			local off = self.off()
			slider:EnableMouse(not off)
			slider:EnableMouseWheel(not off)
			self:SetAlpha(off and 0.4 or 1)
		end
	end
	table.insert(widgets, holder)
	side.Index(page, label, nil, page.y, 20)
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
	side.Index(page, text, nil, page.y, 24)
	return button
end

-- A key of the game's bindings (Key Bindings in the game's menu lists it too):
-- click, then press the key, Alt, Ctrl or Shift with it if wanted (Escape
-- leaves it as it was); a right click clears it.
local keyCapture = CreateFrame("Frame", nil, UIParent)
keyCapture:SetFrameStrata("TOOLTIP")
keyCapture:EnableKeyboard(true)
keyCapture:Hide()
keyCapture:SetScript("OnKeyDown", function()
	local key = arg1
	if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT"
		or key == "UNKNOWN" then
		return
	end
	this:Hide()
	local command = this.command
	if key ~= "ESCAPE" and SetBinding then
		if IsShiftKeyDown() then
			key = "SHIFT-"..key
		end
		if IsControlKeyDown() then
			key = "CTRL-"..key
		end
		if IsAltKeyDown() then
			key = "ALT-"..key
		end
		local old = GetBindingKey(command)
		if old then
			SetBinding(old)
		end
		SetBinding(key, command)
		SaveBindings(GetCurrentBindingSet())
	end
	RefreshAll()
end)

local function KeyButton(page, label, command, note)
	local text = Text(page, 10, TEXT)
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y - 5)
	text:SetText(label)
	local button = CreateFrame("Button", nil, page)
	button:SetWidth(150)
	button:SetHeight(ROW)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", 140, page.y)
	button.edge = Fill(button, "BORDER", 0.3, 0.3, 0.35, 1)
	button.edge:SetAllPoints(button)
	button.fill = Fill(button, "ARTWORK", 0.06, 0.06, 0.08, 1)
	button.fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.label = Text(button, 10, TEXT)
	button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function()
		if arg1 == "RightButton" then
			local old = GetBindingKey and GetBindingKey(command)
			if old then
				SetBinding(old)
				SaveBindings(GetCurrentBindingSet())
			end
			keyCapture:Hide()
		else
			keyCapture.command = command
			keyCapture:Show()
		end
		RefreshAll()
	end)
	button:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(SurvivorUI_OT(label), 1, 1, 1)
		if note then
			GameTooltip:AddLine(SurvivorUI_OT(note), 0.8, 0.8, 0.8, 1)
		end
		GameTooltip:AddLine(SurvivorUI_OT("Click, then press the key (Alt, Ctrl or Shift with it if you like). Escape leaves it as it was; a right click clears it."), 0.8, 0.8, 0.8, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	function button:Refresh()
		local color = page.color
		local waiting = keyCapture:IsShown() and keyCapture.command == command
		local key = GetBindingKey and GetBindingKey(command)
		if waiting then
			self.label:SetText("Press a key...")
			self.label:SetTextColor(color[1], color[2], color[3])
		elseif key then
			self.label:SetText(key)
			self.label:SetTextColor(1, 1, 1)
		else
			self.label:SetText("Not set")
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
		if waiting or self.hot then
			self.edge:SetVertexColor(color[1], color[2], color[3], 1)
		else
			self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
		end
	end
	table.insert(widgets, button)
	side.Index(page, label, note, page.y, ROW)
	page.y = page.y - ROW - 2
end

-- A choice from a list that drops down: Items() gives the list, each
-- { value, name, and as wanted font (the item written in it), color, note (a
-- muted word on its right) }; get() the value chosen, set(value) on a pick.
-- Values match without regard to case; the first item when none does.
local function Dropdown(page, label, Items, get, set, width)
	local color = page.color
	width = width or 220
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(PAGE_WIDTH)
	holder:SetHeight(22)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	holder.label = Text(holder, 10, TEXT)
	holder.label:SetPoint("LEFT", holder, "LEFT", 2, 0)
	holder.label:SetText(label)

	local button = CreateFrame("Button", nil, holder)
	button:SetWidth(width)
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
	menu:SetWidth(width)
	menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
	menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	menu:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
	menu:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
	menu:Hide()
	menu.items = {}

	local function Same(a, b)
		if type(a) == "string" and type(b) == "string" then
			return string.lower(a) == string.lower(b)
		end
		return a == b
	end

	button:SetScript("OnEnter", function() this:SetBackdropBorderColor(color[1], color[2], color[3], 1) end)
	button:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.3, 0.3, 0.35, 1) end)
	button:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
			return
		end
		local list = Items()
		local chosen = get()
		for index = 1, table.getn(list) do
			local entry = list[index]
			local item = menu.items[index]
			if not item then
				item = CreateFrame("Button", nil, menu)
				item:SetWidth(width - 4)
				item:SetHeight(20)
				item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (index - 1) * 20)
				item.wash = Fill(item, "BACKGROUND", 1, 1, 1, 0)
				item.wash:SetAllPoints(item)
				item.text = item:CreateFontString(nil, "OVERLAY")
				SurvivorUI_Spoken(item.text)
				item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
				item.note = Text(item, 9, MUTED)
				item.note:SetPoint("RIGHT", item, "RIGHT", -8, 0)
				item:SetScript("OnEnter", function() this.wash:SetVertexColor(color[1], color[2], color[3], 0.2) end)
				item:SetScript("OnLeave", function() this.wash:SetVertexColor(color[1], color[2], color[3], this.on and 0.12 or 0) end)
				item:SetScript("OnClick", function()
					set(this.value)
					menu:Hide()
					RefreshAll()
				end)
				menu.items[index] = item
			end
			item.value = entry.value
			item.on = Same(chosen, entry.value)
			-- Each in its own font and color, if it has one; the one chosen lit.
			item.text:SetFont(entry.font or SurvivorUI_FONT, (entry.font and 12 or 11) + FONT_BUMP, "OUTLINE")
			item.text:SetText(entry.name)
			local tint = item.on and color or entry.color or TEXT
			item.text:SetTextColor(tint[1], tint[2], tint[3])
			item.note:SetText(entry.note or "")
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
		local list = Items()
		local chosen = get()
		local shown = list[1]
		for index = 1, table.getn(list) do
			if Same(chosen, list[index].value) then
				shown = list[index]
			end
		end
		button.text:SetText(shown and shown.name or "")
		local tint = shown and shown.color or TEXT
		button.text:SetTextColor(tint[1], tint[2], tint[3])
	end
	table.insert(widgets, holder)
	-- Found by its items' names too (Survivor's Hoard by "hoard").
	local names = {}
	local listed, list = pcall(Items)
	if listed and type(list) == "table" then
		for index = 1, table.getn(list) do
			table.insert(names, list[index].name or "")
		end
	end
	side.Index(page, label, table.concat(names, " "), page.y, 22)
	page.y = page.y - 28
end

-- A font, picked from a list where each face is written in itself (EditCard's
-- SurvivorUI_FontList, the addon's default first). get() and set(path), nil
-- for the default.
local function FontPicker(page, label, get, set)
	Dropdown(page, label, function()
		local list, faces = {}, SurvivorUI_FontList and SurvivorUI_FontList(true) or {}
		for index = 1, table.getn(faces) do
			local face = faces[index]
			table.insert(list, { value = face.path, name = face.name,
				font = face.path or SurvivorUI_DEFAULT_FONT or SurvivorUI_FONT })
		end
		return list
	end, get, set)
end

------------------------------------------------------------------------------
-- Global: the whole addon's font, color and size.

local page = pages.global
Header(page, "Global", "Settings for the whole addon: its font, its color and its size, and the mouse cursor.")
Subheader(page, "Font")
FontPicker(page, "Global font",
	function() return SurvivorUI_GlobalFont and SurvivorUI_GlobalFont() end,
	function(path) if SurvivorUI_SetGlobalFont then SurvivorUI_SetGlobalFont(path) end end)
Note(page, "Changes every text of the addon at once. A piece given a font of its own, on its card in move mode, keeps that one.")
Note(page, "Playing in English? Any font works. With the game in Chinese or Japanese, the addon switches by itself to Noto Sans SC, a font that has those letters: the other fonts don't, and the game mixes them up with English letters and numbers."):SetTextColor(1, 0.35, 0.35)
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

-- The mouse cursor (Cursor.lua): the game's gauntlet or our arrow, in a
-- color and a size, with its touches; it changes as they are picked, so the
-- cursor over the window is the preview.
Subheader(page, "Mouse cursor")
Check(page, "Cursor in a color of yours", function() return SurvivorUI_CursorOn and SurvivorUI_CursorOn() end,
	function() if SurvivorUI_SetCursorOn then SurvivorUI_SetCursorOn(not SurvivorUI_CursorOn()) end end,
	"the game's shows while you hold something")
Dropdown(page, "Shape", function()
	local list, shapes = {}, SurvivorUI_CURSOR_SHAPES or {}
	for index = 1, table.getn(shapes) do
		table.insert(list, { value = shapes[index].key, name = shapes[index].name, note = shapes[index].note })
	end
	return list
end, function() return SurvivorUI_CursorShape and SurvivorUI_CursorShape() or "gauntlet" end, function(key)
	if SurvivorUI_SetCursorShape then
		SurvivorUI_SetCursorShape(key)
	end
end, 220)
Dropdown(page, "Color", function()
	local list, colors = {}, SurvivorUI_CURSOR_COLORS or {}
	for index = 1, table.getn(colors) do
		local entry = colors[index]
		local color = entry.color
		if entry.key == "class" then
			local _, class = UnitClass("player")
			color = { SurvivorUI_ClassColor(class) }
		end
		table.insert(list, { value = entry.key, name = entry.name, color = color })
	end
	return list
end, function() return SurvivorUI_CursorColor and SurvivorUI_CursorColor() or "White" end, function(key)
	if SurvivorUI_SetCursorColor then
		SurvivorUI_SetCursorColor(key)
	end
end, 220)
Dropdown(page, "Size", function()
	local list, sizes = {}, SurvivorUI_CURSOR_SIZES or {}
	for index = 1, table.getn(sizes) do
		table.insert(list, { value = sizes[index].key, name = sizes[index].name })
	end
	return list
end, function() return SurvivorUI_CursorSize and SurvivorUI_CursorSize() or "Medium" end, function(key)
	if SurvivorUI_SetCursorSize then
		SurvivorUI_SetCursorSize(key)
	end
end, 220)
Check(page, "Its touches", function() return SurvivorUI_CursorFx and SurvivorUI_CursorFx() end,
	function() if SurvivorUI_SetCursorFx then SurvivorUI_SetCursorFx(not SurvivorUI_CursorFx()) end end,
	"in its color: a glow round it, motes as it moves, sparks where it clicks the world")
Note(page, "Gauntlet: the game's own cursors (its sword over an enemy, its glow while a spell waits for its target), tinted, any size. Arrow: ours, 32 pixels at most (Large fills them). The cursor over this window shows each pick.")

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
	revive = { key = "noGameRevive", hud = "revive", name = "revive bar" },
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
		GameTooltip:SetText(SurvivorUI_OTF("The game's {1}", SurvivorUI_OT(game.name)), color[1], color[2], color[3])
		GameTooltip:AddLine(SurvivorUI_OTF(game.also
			and "The game's own {1}, shown while SurvivorUI's is off. Ticked, SurvivorUI's goes (and the run tracker's boss health); untick both for neither."
			or "The game's own {1}, shown while SurvivorUI's is off. Ticked, SurvivorUI's goes; untick both for neither.",
			SurvivorUI_OT(game.name)), 1, 1, 1, 1)
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
	SurvivorUI_SpokenBy(check.label, function() return SurvivorUI_OT(label)..(reload and "  |cff8a8a95*|r" or "") end)
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
		GameTooltip:SetText(SurvivorUI_OT(label), color[1], color[2], color[3])
		GameTooltip:AddLine(SurvivorUI_OT(tip), 1, 1, 1, 1)
		if usable and not usable() then
			GameTooltip:AddLine(SurvivorUI_OT("Not installed: it comes in the same download."), 1, 0.45, 0.4, 1)
		elseif reload then
			GameTooltip:AddLine(SurvivorUI_OT("Takes hold after a reload."), 0.6, 0.6, 0.65, 1)
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
	side.Index(page, label, tip, y, ROW)
	if game then
		GameTick(page, x + PAGE_WIDTH / 2 - 92, y, 86, "The game's", game, isOn, toggle)
	end
end

page = pages.modules
Header(page, "Modules", "Each part of SurvivorUI on or off as a whole: off, it does not run at all. Where the game has its own, The game's beside it is that one: SurvivorUI's puts it away, and with both unticked neither shows. Hover one for what it does; * after a reload.")

-- The revive bar: on as Party.lua reads it (by default where the game lets
-- its own be put away).
local function ReviveIsOn()
	return SurvivorUI_ReviveOn ~= nil and SurvivorUI_ReviveOn()
end

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
		{ "Meter now", OnlyIfOn("nowMeter"), Call("SurvivorUI_ToggleMeterNow"),
			"A second meter window for how you are doing now: the last 30 seconds, since its own Reset, or the boss fight." },
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
		{ "Revive bar", ReviveIsOn, Call("SurvivorUI_ToggleRevive"),
			"In a co-op run, a bar while you are down (how far a friend has brought you back, and who) or while you bring a friend back. It puts the game's revive bar away (the game's 0.115 on; before it, off unless chosen). Moved on its own: move mode, Revive bar.", nil, nil, GAME.revive },
	} },
	{ "Character", {
		{ "Build list", OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild"),
			"Your spells and their ranks. It puts the game's row of spells away.", nil, nil, GAME.build },
		{ "Jewelry worn", OnUnlessOff("jewelryWorn"), Call("SurvivorUI_ToggleWorn"),
			"The panel under the build list: the neck, the rings and the trinkets you wear this run." },
		{ "Character pane", FeatureOn("characterPane"), FeatureToggle("characterPane"),
			"The character pane laid out again, the stats in sections. Off: the game's pane.", true },
		{ "Stats panel", OnlyIfOn("statsPanel"), Call("SurvivorUI_ToggleStatsPanel"),
			"The run's numbers as a panel on the screen all the time, apart from the character pane." },
		{ "Jewelry collection", OnUnlessOff("jewelry"), Flip("jewelry"),
			"The list by the character pane: every amulet, ring and trinket found, and what is left to find." },
		{ "Ability tooltips", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip"),
			"A spell's tooltip laid out again: what it does, its numbers in colors, its upgrades, bonuses and talents.", true },
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
	side.Index(page, label.." health", "health numbers percent", page.y, ROW)
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
	side.Index(page, label, "size", y, 30)
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
-- The kit (the options menu rework): the pieces a reworked page is made of,
-- alike on every page, so a new tab is laid out the same way. Each goes under
-- the last one (page.y), as the old pieces do, in the page's column:
-- Kit.Split, Kit.Right and Kit.Join lay two columns side by side; an Advanced
-- box is a page of its own inside the page (inset, full: its room).

local Kit = {}
local Paint = {}                       -- the pages' previews and pictures
local WELL = { 0.075, 0.075, 0.095 }    -- a control's ground
local EDGE = { 0.20, 0.20, 0.25 }       -- and its edge, at rest

-- A piece's left edge and its width, in the column it goes in.
local function Span(page)
	return (page.inset or 0) + (page.left or 0), page.width or page.full or PAGE_WIDTH
end

-- A color lightened toward white: a chosen control's words.
function Kit.Light(color, share)
	share = share or 0.45
	return color[1] + (1 - color[1]) * share, color[2] + (1 - color[2]) * share, color[3] + (1 - color[3]) * share
end

local function Boxed(frame, ground, edge)
	frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	frame:SetBackdropColor(ground[1], ground[2], ground[3], 1)
	frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

function Kit.Split(page)
	page.splitY = page.y
	page.left, page.width = 0, math.floor(((page.full or PAGE_WIDTH) - 24) / 2)
end

function Kit.Right(page)
	page.leftY = page.y
	page.y = page.splitY
	page.left = page.width + 24
end

function Kit.Join(page)
	page.y = math.min(page.y, page.leftY or page.y)
	page.left, page.width, page.splitY, page.leftY = nil, nil, nil, nil
end

-- A "?" in a ring after a piece's words: what it is, on hover.
function Kit.Help(parent, anchor, title, text, color)
	color = color or parent.color or MUTED
	local help = CreateFrame("Button", nil, parent)
	help:SetWidth(14)
	help:SetHeight(14)
	help:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
	help.ring = help:CreateTexture(nil, "ARTWORK")
	help.ring:SetTexture(ART.."Ring")
	help.ring:SetAllPoints(help)
	help.ring:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 0.9)
	help.mark = Text(help, 8, MUTED, "")
	help.mark:SetPoint("CENTER", help, "CENTER", 1, 0)
	help.mark:SetText("?")
	help:SetScript("OnEnter", function()
		this.ring:SetVertexColor(color[1], color[2], color[3], 1)
		this.mark:SetTextColor(1, 1, 1)
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(SurvivorUI_OT(title), color[1], color[2], color[3])
		GameTooltip:AddLine(SurvivorUI_OT(text), 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	help:SetScript("OnLeave", function()
		this.ring:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 0.9)
		this.mark:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		GameTooltip:Hide()
	end)
	return help
end

-- A section's name in small grey capitals, its help after it.
function Kit.Section(page, text, help)
	local left = Span(page)
	page.y = page.y - 4
	local label = Text(page, 9, MUTED)
	label:SetPoint("TOPLEFT", page, "TOPLEFT", left, page.y)
	label:SetText(string.upper(text))
	if help then
		Kit.Help(page, label, text, help)
	end
	side.Index(page, text, help, page.y, 14)
	page.y = page.y - 17
	return label
end

-- One of a few, side by side in one box: the chosen one lit in the page's
-- color with a bar under it. options: { { value, name }, ... }.
local function Segs(parent, options, get, set, color)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(26)
	Boxed(holder, WELL, EDGE)
	holder.parts = {}
	local x = 2
	for index = 1, table.getn(options) do
		local part = CreateFrame("Button", nil, holder)
		part:SetHeight(22)
		part:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -2)
		part.wash = Fill(part, "BACKGROUND", color[1], color[2], color[3], 0)
		part.wash:SetAllPoints(part)
		part.bar = Fill(part, "BORDER", color[1], color[2], color[3], 0)
		part.bar:SetHeight(2)
		part.bar:SetPoint("BOTTOMLEFT", part, "BOTTOMLEFT", 0, 0)
		part.bar:SetPoint("BOTTOMRIGHT", part, "BOTTOMRIGHT", 0, 0)
		part.label = Text(part, 10, TEXT)
		part.label:SetPoint("CENTER", part, "CENTER", 0, 0)
		part.label:SetText(options[index][2])
		part.words = math.ceil(part.label:GetStringWidth())
		part:SetWidth(part.words + 24)
		part.value = options[index][1]
		x = x + part:GetWidth()
		part:SetScript("OnClick", function()
			if holder.usable and not holder.usable() then
				return
			end
			set(this.value)
			RefreshAll()
		end)
		part:SetScript("OnEnter", function() this.hot = true holder:Refresh() end)
		part:SetScript("OnLeave", function() this.hot = nil holder:Refresh() end)
		table.insert(holder.parts, part)
	end
	holder:SetWidth(x + 2)
	-- Its words in another language: each part as wide as its new words and
	-- the room it had round them (Kit.NarrowSegments may have cut it).
	table.insert(side.fits, function()
		local at = 2
		for index = 1, table.getn(holder.parts) do
			local part = holder.parts[index]
			local words = math.ceil(part.label:GetStringWidth())
			part:SetWidth(part:GetWidth() - part.words + words)
			part.words = words
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", holder, "TOPLEFT", at, -2)
			at = at + part:GetWidth()
		end
		holder:SetWidth(at + 2)
	end)
	function holder:Refresh()
		-- Faded and still while what it depends on is off (holder.usable).
		self:SetAlpha((self.usable and not self.usable()) and 0.4 or 1)
		local chosen = get()
		for index = 1, table.getn(self.parts) do
			local part = self.parts[index]
			local on = chosen == part.value
			part.wash:SetVertexColor(color[1], color[2], color[3], on and 0.24 or (part.hot and 0.08 or 0))
			part.bar:SetVertexColor(color[1], color[2], color[3], on and 1 or 0)
			if part.hot then
				part.label:SetTextColor(1, 1, 1)
			elseif on then
				part.label:SetTextColor(Kit.Light(color))
			else
				part.label:SetTextColor(TEXT[1] * 0.75, TEXT[2] * 0.75, TEXT[3] * 0.78)
			end
		end
	end
	table.insert(widgets, holder)
	return holder
end

-- usable (optional): whether it can be chosen now, as a setting it depends on
-- stands; faded and still while not.
function Kit.Segments(page, options, get, set, usable)
	local left = Span(page)
	local holder = Segs(page, options, get, set, page.color)
	holder.usable = usable
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", left, page.y)
	local names = {}
	for index = 1, table.getn(options) do
		table.insert(names, options[index][2])
	end
	names = table.concat(names, " / ")
	side.Index(page, names, names, page.y, 26)
	page.y = page.y - 34
	return holder
end

-- Simple or Advanced, at the page's top right: Advanced opens every page's
-- box of fine settings, and stays so.
function Kit.Mode(page)
	local holder = Segs(page, { { "simple", "Simple" }, { "advanced", "Advanced" } },
		function() return DB().optionsAdvanced and "advanced" or "simple" end,
		function(mode) DB().optionsAdvanced = mode == "advanced" or nil end, page.color)
	holder:SetPoint("RIGHT", close, "LEFT", -40, 0)
	return holder
end

-- A choice among pictures: each a tile with a small drawing of what it does
-- (Paint(tile, ground) lays it on the ground), its name and a line.
-- options: { { value, name, line, Paint }, ... }.
function Kit.Tiles(page, options, get, set)
	local left, width = Span(page)
	local color = page.color
	local count, gap = table.getn(options), 10
	local each = math.floor((width - gap * (count - 1)) / count)
	for index = 1, count do
		local option = options[index]
		local tile = CreateFrame("Button", nil, page)
		tile:SetWidth(each)
		tile:SetHeight(56)
		tile:SetPoint("TOPLEFT", page, "TOPLEFT", left + (index - 1) * (each + gap), page.y)
		Boxed(tile, WELL, EDGE)
		tile.ground = Fill(tile, "BORDER", 0.10, 0.14, 0.09, 1)
		tile.ground:SetWidth(72)
		tile.ground:SetHeight(42)
		tile.ground:SetPoint("LEFT", tile, "LEFT", 7, 0)
		if option[4] then
			option[4](tile, tile.ground)
		end
		tile.name = Text(tile, 11, TEXT)
		tile.name:SetPoint("TOPLEFT", tile.ground, "TOPRIGHT", 10, -5)
		tile.name:SetText(option[2])
		tile.line = Text(tile, 9, MUTED)
		tile.line:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -4)
		tile.line:SetWidth(each - 72 - 26)
		tile.line:SetJustifyH("LEFT")
		tile.line:SetText(option[3] or "")
		tile.value = option[1]
		tile:SetScript("OnClick", function()
			set(this.value)
			RefreshAll()
		end)
		tile:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		tile:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function tile:Refresh()
			local on = get() == self.value
			if on then
				self:SetBackdropColor(color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 1)
				self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
			else
				self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
				local edge = self.hot and 0.45 or EDGE[1]
				self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
			end
			if self.hot then
				self.name:SetTextColor(1, 1, 1)
			elseif on then
				self.name:SetTextColor(Kit.Light(color))
			else
				self.name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			end
		end
		table.insert(widgets, tile)
		side.Index(page, option[2], option[3], page.y, 56)
	end
	page.y = page.y - 56 - 10
end

-- Things on or off, as pills that wrap: on, filled in the page's color with
-- a tick; off, an outline with a +. Hover one for its help.
-- items: { { name, isOn, toggle, help, usable = f, why = "..." }, ... }:
-- usable (optional), whether it can be changed now, as a setting it depends
-- on stands; faded and still while not, why said on hover.
function Kit.Chips(page, items)
	local left, width = Span(page)
	local color = page.color
	local x, row = 0, 0
	local chips, top = {}, page.y
	for index = 1, table.getn(items) do
		local item = items[index]
		local chip = CreateFrame("Button", nil, page)
		table.insert(chips, chip)
		chip:SetHeight(22)
		Boxed(chip, WELL, EDGE)
		chip.tick = chip:CreateTexture(nil, "OVERLAY")
		chip.tick:SetTexture(ART.."Tick")
		chip.tick:SetWidth(10)
		chip.tick:SetHeight(10)
		chip.tick:SetPoint("LEFT", chip, "LEFT", 9, 0)
		chip.plus = Text(chip, 10, MUTED, "")
		chip.plus:SetPoint("CENTER", chip.tick, "CENTER", 0, 0)
		chip.plus:SetText("+")
		chip.label = Text(chip, 10, TEXT)
		chip.label:SetPoint("LEFT", chip, "LEFT", 24, 0)
		chip.label:SetText(item[1])
		local chipWidth = 24 + math.ceil(chip.label:GetStringWidth()) + 11
		chip:SetWidth(chipWidth)
		if x > 0 and x + chipWidth > width then
			x, row = 0, row + 1
		end
		chip:SetPoint("TOPLEFT", page, "TOPLEFT", left + x, page.y - row * 27)
		chip.row, chip.placed = row, left + x
		x = x + chipWidth + 6
		chip.name, chip.isOn, chip.toggle, chip.help = item[1], item[2], item[3], item[4]
		chip.usable, chip.why = item.usable, item.why
		chip:SetScript("OnClick", function()
			if this.usable and not this.usable() then
				return
			end
			this.toggle()
			RefreshAll()
		end)
		chip:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			local still = this.usable and not this.usable()
			if this.help or still then
				GameTooltip:SetOwner(this, "ANCHOR_TOP")
				GameTooltip:SetText(SurvivorUI_OT(this.name), color[1], color[2], color[3])
				if this.help then
					GameTooltip:AddLine(SurvivorUI_OT(this.help), 1, 1, 1, 1)
				end
				if still and this.why then
					GameTooltip:AddLine(SurvivorUI_OT(this.why), MUTED[1], MUTED[2], MUTED[3], 1)
				end
				GameTooltip:Show()
			end
		end)
		chip:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		function chip:Refresh()
			self:SetAlpha((self.usable and not self.usable()) and 0.4 or 1)
			local on = self.isOn()
			if on then
				self:SetBackdropColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1)
				self:SetBackdropBorderColor(color[1], color[2], color[3], self.hot and 1 or 0.8)
				self.tick:SetVertexColor(Kit.Light(color))
				self.tick:Show()
				self.plus:Hide()
			else
				self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
				local edge = self.hot and 0.45 or EDGE[1]
				self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
				self.tick:Hide()
				self.plus:Show()
			end
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif on then
				self.label:SetTextColor(Kit.Light(color, 0.6))
			else
				self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
		end
		table.insert(widgets, chip)
		side.Index(page, item[1], item[4], page.y - row * 27, 22)
	end
	-- Their words in another language: each chip as wide as its new words, in
	-- the row it had (one its page moved on its own keeps its place).
	table.insert(side.fits, function() Kit.Refit(chips, page, left, top) end)
	page.y = page.y - (row + 1) * 27 - 5
end

-- Chips (Kit.Chips, Kit.PlateChips) fit again to their words: each as wide as
-- them, side by side again in the row it had; one its page moved since it was
-- put (chip.placed) only takes its new width, out of the row.
function Kit.Refit(chips, page, left, top)
	local at, line = 0, 0
	for index = 1, table.getn(chips) do
		local chip = chips[index]
		if chip.row ~= line then
			at, line = 0, chip.row
		end
		local point, _, _, x = chip:GetPoint(1)
		chip:SetWidth(24 + math.ceil(chip.label:GetStringWidth()) + 11)
		if point == "TOPLEFT" and x and math.abs(x - chip.placed) < 0.5 then
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", page, "TOPLEFT", left + at, top - line * 27)
			chip.placed = left + at
			at = at + chip:GetWidth() + 6
		end
	end
end

-- A bar to drag, filled in the page's color, its value on the right: the
-- old Slider's, at any place and width.
function Kit.Bar(page, x, y, width, low, high, step, get, set, format)
	local color = page.color
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(width)
	holder:SetHeight(18)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	holder.value = Text(holder, 10, color)
	holder.value:SetPoint("RIGHT", holder, "RIGHT", -2, 0)
	local slider = CreateFrame("Slider", nil, holder)
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(width - 58)
	slider:SetHeight(14)
	slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
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
	slider.fill:SetHeight(4)
	slider.fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	local thumb = Fill(slider, "OVERLAY", 1, 1, 1, 1)
	thumb:SetWidth(8)
	thumb:SetHeight(14)
	slider:SetThumbTexture(thumb)
	local function Show(value)
		holder.value:SetText(type(format) == "function" and format(value) or string.format(format or "%.2f", value))
		slider.fill:SetWidth(math.max(1, (slider:GetWidth() - 8) * (value - low) / (high - low) + 4))
	end
	slider:SetScript("OnValueChanged", function()
		local me = this
		local value = math.floor(me:GetValue() / step + 0.5) * step
		Show(value)
		if not me.quiet then
			set(value)
			-- The page's other pieces (its preview, its S M L) follow.
			if not me.refreshing then
				me.refreshing = true
				RefreshAll()
				me.refreshing = nil
			end
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

-- A size: its name with S, M and L on the right, and the bar under them for
-- any size between. presets: { { "S", value }, ... }.
function Kit.Size(page, label, low, high, step, get, set, presets, format)
	local left, width = Span(page)
	local color = page.color
	local top = page.y - 4
	local title = Text(page, 9, MUTED)
	title:SetPoint("TOPLEFT", page, "TOPLEFT", left, top)
	title:SetText(string.upper(label))
	local x = left + width
	for index = table.getn(presets), 1, -1 do
		local preset = presets[index]
		local button = CreateFrame("Button", nil, page)
		button:SetWidth(26)
		button:SetHeight(18)
		x = x - 26
		button:SetPoint("TOPLEFT", page, "TOPLEFT", x, top + 4)
		x = x - 4
		Boxed(button, WELL, EDGE)
		button.text = Text(button, 9, TEXT)
		button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.text:SetText(preset[1])
		button.value = preset[2]
		button:SetScript("OnClick", function()
			set(this.value)
			RefreshAll()
		end)
		button:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		button:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function button:Refresh()
			local on = math.abs((get() or 0) - self.value) < step / 2
			if on then
				self:SetBackdropColor(color[1] * 0.26, color[2] * 0.26, color[3] * 0.26, 1)
				self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
			else
				self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
				local edge = self.hot and 0.45 or EDGE[1]
				self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
			end
			if self.hot then
				self.text:SetTextColor(1, 1, 1)
			elseif on then
				self.text:SetTextColor(Kit.Light(color))
			else
				self.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
		end
		table.insert(widgets, button)
	end
	local bar = Kit.Bar(page, left, top - 20, width, low, high, step, get, set, format)
	side.Index(page, label, "size small medium large", top, 40)
	page.y = top - 46
	return bar
end

-- Fine settings, two to a row: each its name and value over its bar.
-- items: { { label, low, high, step, get, set, format }, ... }.
function Kit.Fine(page, items)
	local left, width = Span(page)
	local column = math.floor((width - 24) / 2)
	for index = 1, table.getn(items) do
		local item = items[index]
		local slot = math.mod(index - 1, 2)
		-- The page's preview follows each one.
		SizeSlider(page, left + slot * (column + 24), page.y, column,
			item[1], item[2], item[3], item[4], item[5], function(value)
				item[6](value)
				if page.preview then
					page.preview:Refresh()
				end
			end, item[7])
		if slot == 1 or index == table.getn(items) then
			page.y = page.y - 36
		end
	end
end

-- A number a step at a time: - and + about its value, in a box.
function Kit.Stepper(page, label, low, high, step, get, set, format)
	local left = Span(page)
	local x = left
	if label then
		local text = Text(page, 10, TEXT)
		text:SetPoint("TOPLEFT", page, "TOPLEFT", left + 2, page.y - 5)
		text:SetText(label)
		x = left + 140
	end
	local color = page.color
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(116)
	holder:SetHeight(24)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
	Boxed(holder, WELL, EDGE)
	holder.value = Text(holder, 10, TEXT)
	holder.value:SetPoint("CENTER", holder, "CENTER", 0, 0)
	local function Step(by)
		local value = math.max(low, math.min(high, (get() or 0) + by))
		set(value)
		RefreshAll()
	end
	local function Side(sign, point, by)
		local button = CreateFrame("Button", nil, holder)
		button:SetWidth(26)
		button:SetHeight(22)
		button:SetPoint(point, holder, point, point == "LEFT" and 1 or -1, 0)
		button.wash = Fill(button, "BACKGROUND", color[1], color[2], color[3], 0)
		button.wash:SetAllPoints(button)
		button.text = Text(button, 12, TEXT)
		button.text:SetPoint("CENTER", button, "CENTER", 0, 1)
		button.text:SetText(sign)
		button:SetScript("OnClick", function() Step(by) end)
		button:SetScript("OnEnter", function()
			this.wash:SetVertexColor(color[1], color[2], color[3], 0.2)
			this.text:SetTextColor(1, 1, 1)
		end)
		button:SetScript("OnLeave", function()
			this.wash:SetVertexColor(color[1], color[2], color[3], 0)
			this.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		end)
		return button
	end
	holder.less = Side("-", "LEFT", -step)
	holder.more = Side("+", "RIGHT", step)
	function holder:Refresh()
		local value = get() or 0
		self.value:SetText(type(format) == "function" and format(value) or string.format(format or "%d", value))
		self.value:SetTextColor(Kit.Light(color, 0.3))
		self.less:SetAlpha(value <= low and 0.35 or 1)
		self.more:SetAlpha(value >= high and 0.35 or 1)
	end
	table.insert(widgets, holder)
	if label then
		side.Index(page, label, nil, page.y, 24)
	end
	page.y = page.y - 30
	return holder
end

-- The part's switch: a track with a knob, On in the page's color, Off in red.
function Kit.Switch(page, x, y, isOn, toggle)
	local color = page.color
	local switch = CreateFrame("Button", nil, page)
	switch:SetWidth(76)
	switch:SetHeight(20)
	switch:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	switch.track = Fill(switch, "BORDER", 0.22, 0.22, 0.27, 1)
	switch.track:SetWidth(32)
	switch.track:SetHeight(16)
	switch.track:SetPoint("LEFT", switch, "LEFT", 0, 0)
	switch.knob = Fill(switch, "ARTWORK", 1, 1, 1, 1)
	switch.knob:SetWidth(12)
	switch.knob:SetHeight(12)
	switch.label = Text(switch, 11, TEXT)
	switch.label:SetPoint("LEFT", switch.track, "RIGHT", 8, 0)
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
		self.knob:ClearAllPoints()
		if on then
			self.track:SetVertexColor(color[1], color[2], color[3], 0.9)
			self.knob:SetPoint("RIGHT", self.track, "RIGHT", -2, 0)
			self.knob:SetVertexColor(1, 1, 1, 1)
		else
			self.track:SetVertexColor(0.22, 0.22, 0.27, 1)
			self.knob:SetPoint("LEFT", self.track, "LEFT", 2, 0)
			self.knob:SetVertexColor(0.62, 0.62, 0.66, 1)
		end
		self.label:SetText(on and "On" or "Off")
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(Kit.Light(color, 0.3))
		else
			self.label:SetTextColor(1, 0.42, 0.36)
		end
	end
	table.insert(widgets, switch)
	return switch
end

-- A quiet button (an outline) and the page's one strong button (filled in
-- its color).
function Kit.Quiet(page, text, width, onClick)
	local button = CreateFrame("Button", nil, page)
	button:SetWidth(width)
	button:SetHeight(24)
	Boxed(button, WELL, { 0.3, 0.3, 0.36 })
	button.text = Text(button, 10, TEXT)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(0.6, 0.6, 0.66, 1)
	end)
	button:SetScript("OnLeave", function()
		this.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		this:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

function Kit.Strong(page, text, width, onClick)
	local color = page.color
	local button = CreateFrame("Button", nil, page)
	button:SetWidth(width)
	button:SetHeight(24)
	Boxed(button, { color[1] * 0.5, color[2] * 0.5, color[3] * 0.5 }, color)
	button.text = Text(button, 10, { 1, 1, 1 })
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button:SetScript("OnEnter", function()
		this:SetBackdropColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1)
		this:SetBackdropBorderColor(1, 1, 1, 1)
	end)
	button:SetScript("OnLeave", function()
		this:SetBackdropColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1)
		this:SetBackdropBorderColor(color[1], color[2], color[3], 1)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- A page's head: its name in its color (Simple and Advanced at the top right
-- when it has fine settings), a line on what it is, then the part's switch,
-- The game's beside it where the game has its own, and Back to its place.
-- spec: { title, line, isOn, toggle, reloads, game, piece, back, advanced }.
function Kit.Head(page, spec)
	local color = page.color
	local title = Text(page, 15, color)
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	title:SetText(spec.title or page.label)
	if spec.advanced then
		Kit.Mode(page)
	end
	page.y = -27
	if spec.line then
		local line = Text(page, 9, MUTED)
		line:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
		line:SetWidth(PAGE_WIDTH)
		line:SetJustifyH("LEFT")
		line:SetText(spec.line)
		page.y = page.y - 13 * Lines(line, PAGE_WIDTH) - 9
	end
	if spec.isOn then
		local y = page.y
		Kit.Switch(page, 0, y, spec.isOn, spec.toggle)
		local x = 84
		if spec.reloads then
			local note = Text(page, 9, MUTED)
			note:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 5)
			note:SetText("after a reload")
			x = x + math.ceil(note:GetStringWidth()) + 16
		end
		if spec.game then
			GameTick(page, x, y, 120, "The game's", spec.game, spec.isOn, spec.toggle)
		end
		if spec.piece or spec.back then
			local back = Kit.Quiet(page, "Back to its place", 140, spec.back or function()
				if SurvivorUI_ResetPiece then
					SurvivorUI_ResetPiece(spec.piece)
				end
			end)
			back:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_WIDTH - 140, y + 2)
			side.Index(page, "Back to its place", "reset place position", y, 22)
		end
		page.y = y - 30
	end
	local rule = Fill(page, "ARTWORK", color[1], color[2], color[3], 0.22)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y + 4)
	rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page.y + 4)
	page.y = page.y - 6
end

-- What the settings do, shown as they change: a strip of ground, LIVE
-- PREVIEW in its corner, and Paint(preview) drawing on it each refresh with
-- its pool of words (preview:Word) and boxes (preview:Box, in a layer: two
-- boxes in one layer may draw either way round, so one over another goes a
-- layer up).
function Kit.Preview(page, height, Paint)
	local preview = CreateFrame("Frame", nil, page)
	preview:SetWidth(PAGE_WIDTH)
	preview:SetHeight(height)
	preview:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	Boxed(preview, { 0.085, 0.115, 0.075 }, { 0.17, 0.23, 0.15 })
	preview.tag = Text(preview, 8, { 0.55, 0.66, 0.50 }, "")
	preview.tag:SetPoint("TOPLEFT", preview, "TOPLEFT", 8, -6)
	preview.tag:SetText("LIVE PREVIEW")
	preview.words, preview.boxes = {}, {}
	function preview:Begin()
		for index = 1, table.getn(self.words) do
			self.words[index]:Hide()
		end
		for _, pool in pairs(self.boxes) do
			for index = 1, table.getn(pool) do
				pool[index]:Hide()
			end
			pool.used = 0
		end
		self.wordCount = 0
	end
	function preview:Word(font, size, flags, r, g, b, text)
		self.wordCount = self.wordCount + 1
		local word = self.words[self.wordCount]
		if not word then
			word = SurvivorUI_Spoken(self:CreateFontString(nil, "OVERLAY"))
			self.words[self.wordCount] = word
		end
		word:SetFont(font, math.max(6, math.floor(size + 0.5)), flags)
		word:SetTextColor(r, g, b)
		word:SetText(text)
		word:ClearAllPoints()
		word:Show()
		return word
	end
	function preview:Box(r, g, b, a, texture, layer)
		layer = layer or "ARTWORK"
		local pool = self.boxes[layer]
		if not pool then
			pool = { used = 0 }
			self.boxes[layer] = pool
		end
		pool.used = pool.used + 1
		local box = pool[pool.used]
		if not box then
			box = self:CreateTexture(nil, layer)
			pool[pool.used] = box
		end
		box:SetTexture(texture or FLAT)
		box:SetTexCoord(0, 1, 0, 1)
		box:SetVertexColor(r, g, b, a or 1)
		box:ClearAllPoints()
		box:Show()
		return box
	end
	function preview:Refresh()
		if self:IsVisible() then
			Paint(self)
		end
	end
	table.insert(widgets, preview)
	page.preview = preview
	page.y = page.y - height - 12
	return preview
end

-- A line that opens another tab: where a setting of this one lives.
function Kit.Link(page, text, key)
	local left = Span(page)
	local link = CreateFrame("Button", nil, page)
	link:SetHeight(16)
	link:SetPoint("TOPLEFT", page, "TOPLEFT", left, page.y)
	link.text = Text(link, 9, MUTED)
	link.text:SetPoint("LEFT", link, "LEFT", 0, 0)
	local target = pages[key]
	SurvivorUI_SpokenBy(link.text, function()
		return SurvivorUI_OT(text).."  |cffd8d8de"..SurvivorUI_OT(target.label).."  >|r"
	end)
	link:SetWidth(math.ceil(link.text:GetStringWidth()) + 4)
	table.insert(side.fits, function() link:SetWidth(math.ceil(link.text:GetStringWidth()) + 4) end)
	link:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	link:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	link:SetScript("OnClick", function() ShowPage(key) end)
	page.y = page.y - 20
	return link
end

-- The fine settings: a box of its own under the rest, shown in Advanced only
-- (a line in Simple says what it holds, and opens it). The pieces go in the
-- box as in a page (Kit.Advanced returns it); Kit.EndAdvanced closes it.
-- It comes last, so nothing under it moves as it opens.
function Kit.Advanced(page, holds)
	local box = CreateFrame("Frame", nil, page)
	box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 2)
	box:SetWidth(PAGE_WIDTH)
	Boxed(box, { 0.062, 0.062, 0.08 }, { 0.17, 0.17, 0.22 })
	box.color, box.key, box.label, box.advanced = page.color, page.key, page.label, true
	box.preview = page.preview
	box.inset, box.full, box.y = 12, PAGE_WIDTH - 24, -10
	local more = CreateFrame("Button", nil, page)
	more:SetHeight(18)
	more:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 2)
	more.text = Text(more, 9, MUTED)
	more.text:SetPoint("LEFT", more, "LEFT", 0, 0)
	SurvivorUI_SpokenBy(more.text, function()
		return SurvivorUI_OTF("Advanced: {1}", SurvivorUI_OT(holds)).."  |cffd8d8de>|r"
	end)
	more:SetWidth(math.ceil(more.text:GetStringWidth()) + 4)
	table.insert(side.fits, function() more:SetWidth(math.ceil(more.text:GetStringWidth()) + 4) end)
	more:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	more:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	more:SetScript("OnClick", function()
		DB().optionsAdvanced = true
		RefreshAll()
	end)
	box.more = more
	Kit.Section(box, "Fine-tuning")
	return box
end

function Kit.EndAdvanced(page, box)
	box:SetHeight(-box.y + 4)
	function box:Refresh()
		if DB().optionsAdvanced then
			self:Show()
			self.more:Hide()
		else
			self:Hide()
			self.more:Show()
		end
	end
	table.insert(widgets, box)
	page.y = page.y - 2 - box:GetHeight() - 8
end

-- The page's foot, level with Save & Close: Reset this page at the left,
-- the page's one strong button beside Save & Close.
-- spec: { reset = its action, resetText, strong = { text, action } }.
function Kit.Foot(page, spec)
	if spec.reset then
		local reset = Kit.Quiet(page, spec.resetText or "Reset this page", 140, spec.reset)
		reset:SetHeight(28)
		reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAGE_X, 12)
		side.Index(page, spec.resetText or "Reset this page", "default", -(HEIGHT - 16 - 40), 28)
	end
	if spec.strong then
		local strong = Kit.Strong(page, spec.strong[1], 150, spec.strong[2])
		strong:SetHeight(28)
		strong:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14 - 170 - 10, 12)
	end
end

-- The window in the game's language, when the addon has its words in it
-- (Locale.lua, SurvivorUI_SpeakOptions), asked as it refreshes: every text
-- set again in it (the link box's too, made on it; the minimized bar's), and
-- the pieces sized by their words fit to the new ones.
function side.Speak()
	if SurvivorUI_SpeakOptions and SurvivorUI_SpeakOptions(panel, getglobal("SurvivorUIOptionsMini")) then
		for index = 1, table.getn(side.fits) do
			side.fits[index]()
		end
	end
end

------------------------------------------------------------------------------
-- Run tracker: the clock, the bosses, the guardians and the elites
-- (Tracker.lua, Guardians.lua).

-- Made with the kit: the tracker is tall and narrow, so its preview stands in
-- a column of its own beside the first settings, drawn as Tracker.lua and
-- Guardians.lua lay it out, at its own size and text size: the zone and the
-- run's tags, the clock against the run's length with the cache's coin, the
-- timeline and its pips, a boss alive in its health look and the next, the
-- guardians as chosen (the list hung under the tracker, in its shade), the
-- elites. The run on now when there is one, a sample run else;
-- a sample Heroic V with its two affixes for the tags while the run has none.

page = pages.tracker
do
	local tab = pages.tracker
	-- The page's own, kept off the file's locals (near Lua 5.0's 200): the
	-- preview's colors, its samples and its drawing, in parts (each under Lua
	-- 5.0's 32 upvalues).
	local TR = {
		WIDTH = 220,
		COUNTS = { count = true, line = true, row = true },
		STATE = { due = { 0.55, 0.55, 0.55 }, next = { 1, 1, 1 }, up = { 1.00, 0.55, 0.25 }, dead = { 0.30, 0.85, 0.35 } },
		TAG = { normal = { 0.62, 0.62, 0.66 }, heroic = { 1.00, 0.48, 0.18 }, endless = { 0.82, 0.50, 1.00 }, affix = { 1.00, 0.35, 0.29 } },
		SPAWNED = { 0.30, 1.00, 0.40 }, AWAKE = { 1.00, 0.55, 0.15 }, RESPAWN = { 1.00, 0.28, 0.22 },
		DIM = { 0.55, 0.55, 0.58 }, NAME = { 0.88, 0.88, 0.90 }, WHITE = { 1, 1, 1 },
		NEARNESS = { { 0.78, 1.00, 0.62 }, { 0.36, 0.86, 0.40 }, { 0.15, 0.56, 0.22 }, { 0.06, 0.30, 0.10 } },
		DOT = "\194\183",
		GAP = 10,           -- the tracker's last line to the hung list's title (Guardians.lua)
		LIST = 210,         -- the free list's width
		step = 0,
	}
	Kit.Head(tab, { line = "Under the minimap: the run's difficulty, clock, bosses, guardians and elites.",
		isOn = OnUnlessOff("tracker"), toggle = Call("SurvivorUI_ToggleTracker"), game = GAME.clock, piece = "Run tracker", advanced = true })
	-- The page's own, for the Tracker Ring's page too (Experimental): its preview's
	-- pieces and the looks both share.
	Paint.TrackerTR = TR

	-- A sample run, while none is on: a boss slain, one alive, three to come;
	-- five lairs, one awake and one empty; three elites, two hurt.
	TR.SAMPLE_BOSSES = {
		{ name = "Hogger", at = 180, state = "dead", fell = 236 },
		{ name = "Princess", at = 360, state = "up", hp = 2400000, hpm = 3300000 },
		{ name = "Morgan the Collector", at = 540, state = "due" },
		{ name = "Gruff Swiftbite", at = 720, state = "due" },
		{ name = "Edwin VanCleef", at = 900, state = "due", final = true },
	}
	TR.SAMPLE_LAIRS = {
		{ place = 1, name = "Kobold Taskmaster", state = "asleep", yards = 48, angle = 0.5 },
		{ place = 2, name = "Murloc Tidehunter", state = "awake", share = 0.64, yards = 14, angle = -0.4 },
		{ place = 3, name = "Defias Overseer", state = "empty", left = 47 },
		{ place = 4, name = "Gnoll Packleader", state = "asleep", yards = 96, angle = -2.2 },
		{ place = 5, name = "Old Blackfang", state = "asleep", yards = 160, angle = 2.6 },
	}

	function TR.Clock(seconds, round)
		seconds = math.max(0, math.floor(seconds + (round and 0.5 or 0)))
		return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
	end

	function TR.Field(entry, name, index)
		if entry[name] ~= nil then
			return entry[name]
		end
		return entry[index]
	end

	function TR.Copy(list)
		local out = {}
		for index = 1, table.getn(list) do
			local copy = {}
			for key, value in pairs(list[index]) do
				copy[key] = value
			end
			table.insert(out, copy)
		end
		return out
	end

	-- The guardians' way to show, as Guardians.lua reads it: guardiansCount
	-- "count", "line" or "row" (true, before v3.0.37, is "count"), else the
	-- bar (guardiansDocked) or the list; off with the guardians off.
	function TR.Way()
		local db = DB()
		if db.guardians == false then
			return "off"
		end
		local count = db.guardiansCount
		if count then
			return count == true and "count" or count
		end
		return db.guardiansDocked and "bar" or "list"
	end

	function TR.SetWay(choice)
		local db = DB()
		db.guardians = choice ~= "off"
		if choice ~= "off" then
			db.guardiansDocked = choice ~= "list"
			db.guardiansCount = TR.COUNTS[choice] and choice or nil
		end
	end

	function TR.StepGet(name)
		return function() return SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep(name) or 0 end
	end

	function TR.StepSet(name)
		return function(value)
			if SurvivorUI_SetPieceTextStep then
				SurvivorUI_SetPieceTextStep(name, value)
			end
		end
	end

	function TR.StepText(value)
		value = math.floor(value + 0.5)
		return value == 0 and "normal" or ((value > 0 and "+" or "")..value)
	end

	----------------------------------------------------------------------------
	-- The run the preview draws.

	-- A boss alive's health, by its name (AZS_UNITS).
	function TR.Health(name)
		for _, unit in pairs(AZS_UNITS or {}) do
			local kind = TR.Field(unit, "kind", 1)
			if (kind == "boss" or kind == "final") and TR.Field(unit, "name", 3) == name then
				return tonumber(TR.Field(unit, "hp", 4)) or 0, tonumber(TR.Field(unit, "hpm", 5)) or 0
			end
		end
	end

	-- The run's lairs as Guardians.lua reads them: where each stands, how far
	-- and which way from the hero; nil for none.
	function TR.Lairs(phase)
		local lairs = AZS_GetLairs and AZS_GetLairs()
		if not lairs or table.getn(lairs) == 0 then
			return nil
		end
		local healths = {}
		for _, unit in pairs(AZS_UNITS or {}) do
			if TR.Field(unit, "kind", 1) == "guardian" then
				local hp, hpm = tonumber(TR.Field(unit, "hp", 4)) or 0, tonumber(TR.Field(unit, "hpm", 5)) or 0
				healths[tonumber(TR.Field(unit, "id", 2)) or 0] = hpm > 0 and hp / hpm or nil
			end
		end
		local since = (phase == "playing" and AZS_LAIRS_UPDATED) and GetTime() - AZS_LAIRS_UPDATED or 0
		local px, py, facing
		if SurvivorUI_HeroWorld then
			px, py, facing = SurvivorUI_HeroWorld()
		end
		local north = DB().guardiansNorth
		local out = {}
		for index = 1, table.getn(lairs) do
			local lair = lairs[index]
			local place = tonumber(TR.Field(lair, "index", 1)) or index
			local entry = { place = place, state = TR.Field(lair, "state", 2) or "asleep", name = TR.Field(lair, "name", 3) or "?" }
			local share = healths[tonumber(TR.Field(lair, "id", 4)) or 0]
			if entry.state == "empty" then
				entry.left = (tonumber(TR.Field(lair, "left", 5)) or -1) - since
			elseif share and (entry.state == "awake" or share < 1) then
				entry.state, entry.share = "awake", share
			end
			local lx, ly = tonumber(TR.Field(lair, "x", 6)), tonumber(TR.Field(lair, "y", 7))
			if px and lx and ly and SurvivorUI_WorldWay then
				local east, south = SurvivorUI_WorldWay(px, py, lx, ly)
				if east then
					entry.yards = math.sqrt(east * east + south * south)
					local bearing = math.atan2(east, -south)
					entry.angle = (north or not facing) and bearing or bearing - facing
				end
			end
			table.insert(out, entry)
		end
		table.sort(out, function(a, b) return a.place < b.place end)
		return out
	end

	-- The living lairs by how near, the nearest first (the bar's greens, the
	-- larger arrow).
	function TR.Rank(lairs)
		local living = {}
		for index = 1, table.getn(lairs) do
			local entry = lairs[index]
			entry.alive, entry.rank = entry.state ~= "empty", nil
			if entry.alive and entry.yards then
				table.insert(living, entry)
			end
		end
		table.sort(living, function(a, b) return a.yards < b.yards end)
		for index = 1, table.getn(living) do
			living[index].rank = index
		end
	end

	-- The 8:00 achievement's line, as Guardians.lua writes it.
	function TR.Goal(m)
		if m.goal then
			return
		end
		local slain, time = m.slain or 0, m.seconds or 0
		if slain >= 4 then
			m.goal, m.goalColor = SurvivorUI_T("4/4 by 8:00 · done"), { 0.35, 0.90, 0.40 }
		elseif time < 480 then
			m.goal, m.goalColor = SurvivorUI_TF("{1}/4 by 8:00 · {2}", slain, TR.Clock(480 - time, true)), { 0.9, 0.9, 0.92 }
		else
			m.goal, m.goalColor = SurvivorUI_TF("{1}/4 by 8:00", slain), TR.DIM
		end
	end

	-- A Heroic V's two affixes (Affixes.lua's), for the tags.
	function TR.SampleAffixes()
		local out = {}
		for _, name in pairs({ "Sanguine", "Explosive" }) do
			local info = SurvivorUI_AffixInfo and SurvivorUI_AffixInfo(name)
			table.insert(out, { name = name, symbol = info and info.symbol or ART.."Affix"..name })
		end
		return out
	end

	function TR.Sample()
		local db = DB()
		local m = { zone = "Elwynn Forest", heroic = 5, seconds = 400, length = 900, gold = 1840, cost = 1500, slain = 1,
			affixes = TR.SampleAffixes(), bosses = TR.Copy(TR.SAMPLE_BOSSES), sample = true }
		if db.trackerElites ~= false then
			m.elites = { total = 3, hurt = 2, shares = { 0.35, 0.8, 1 },
				slots = math.max(4, math.min(12, math.floor((tonumber(db.trackerElitesMax) or 8) + 0.5))) }
		end
		return m
	end

	-- The run on now (Tracker.lua's own snapshot of it), else the sample; the
	-- sample's lairs too where the run has none.
	function TR.Model()
		local m = SurvivorUI_TrackerSnapshot and SurvivorUI_TrackerSnapshot()
		if m then
			local run = AZS_RUN or {}
			m.gold, m.cost, m.slain = tonumber(run.gold) or 0, tonumber(run.chest) or 0, tonumber(run.gk) or 0
			if m.guardians and m.guardians.goal then
				m.goal, m.goalColor = m.guardians.goal, m.guardians.goalColor
			end
			for index = 1, table.getn(m.bosses) do
				local boss = m.bosses[index]
				boss.hp, boss.hpm = nil, nil
				if boss.state == "up" then
					boss.hp, boss.hpm = TR.Health(boss.name)
				end
			end
			m.lairs = TR.Lairs(m.phase)
			-- A run with no affix: the tags a sample Heroic V's, so their looks show.
			if not (m.affixes and table.getn(m.affixes) > 0) then
				m.heroic, m.affixes, m.sampleTags = 5, TR.SampleAffixes(), true
			end
		else
			m = TR.Sample()
		end
		if not m.lairs then
			m.lairs = TR.Copy(TR.SAMPLE_LAIRS)
		end
		TR.Rank(m.lairs)
		TR.Goal(m)
		return m
	end

	-- How the run stands, after the left tags: won, fallen, paused..., and the
	-- lives left.
	function TR.State(m)
		local parts, phase = {}, m.phase
		if phase == "victory" then
			table.insert(parts, "|cff4dd94d"..SurvivorUI_T("Victory").."|r")
		elseif not m.sample and SurvivorUI_IsDown and SurvivorUI_IsDown() then
			table.insert(parts, "|cffff4040"..SurvivorUI_T("Down").."|r")
		elseif phase == "dead" then
			table.insert(parts, "|cffff4040"..SurvivorUI_T("Fallen").."|r")
		elseif phase == "paused" then
			table.insert(parts, "|cff9a9a9a"..SurvivorUI_T("Paused").."|r")
		elseif phase == "choosing" then
			table.insert(parts, "|cff9a9a9a"..SurvivorUI_T("Choosing").."|r")
		end
		local lives = m.lives or 0
		if lives > 0 then
			table.insert(parts, "|cffff8080"..SurvivorUI_TF(lives == 1 and "{1} life left" or "{1} lives left", lives).."|r")
		end
		return table.concat(parts, "  ")
	end

	----------------------------------------------------------------------------
	-- The preview's pieces.

	-- A box at x, y from the preview's top left, so wide and tall.
	function TR.Box(self, r, g, b, a, texture, layer, x, y, width, height)
		local box = self:Box(r, g, b, a, texture, layer)
		box:SetBlendMode("BLEND")
		if x then
			box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		end
		if width then
			box:SetWidth(width)
			box:SetHeight(height)
		end
		return box
	end

	-- A frame a level over the preview, with layers of its own: a pip's ring
	-- and core over its dark edge, an arrow over its shadow.
	function TR.Up(self, r, g, b, a, texture, layer)
		local pool = self.over.pools[layer]
		if not pool then
			pool = { used = 0 }
			self.over.pools[layer] = pool
		end
		pool.used = pool.used + 1
		local box = pool[pool.used]
		if not box then
			box = self.over:CreateTexture(nil, layer)
			pool[pool.used] = box
		end
		box:SetTexture(texture)
		box:SetTexCoord(0, 1, 0, 1)
		box:SetVertexColor(r, g, b, a or 1)
		box:ClearAllPoints()
		box:Show()
		return box
	end

	function TR.Begin(self)
		self:Begin()
		if not self.over then
			self.over = CreateFrame("Frame", nil, self)
			self.over:SetAllPoints(self)
			self.over:SetFrameLevel(self:GetFrameLevel() + 2)
			self.over.pools = {}
		end
		for _, pool in pairs(self.over.pools) do
			for index = 1, table.getn(pool) do
				pool[index]:Hide()
			end
			pool.used = 0
		end
	end

	-- Words in the tracker's face, at its text size (TR.step).
	function TR.Word(self, size, flags, color, text)
		return self:Word(SurvivorUI_FONT, size + FONT_BUMP + TR.step, flags, color[1], color[2], color[3], text or "")
	end

	-- The arrows' sheet: 8 x 8, each turned 360/64 more (clockwise from up).
	function TR.Turn(texture, angle)
		local k = math.mod(math.floor(angle / (2 * math.pi) * 64 + 0.5), 64)
		if k < 0 then
			k = k + 64
		end
		local column, line = math.mod(k, 8), math.floor(k / 8)
		texture:SetTexCoord(column / 8, (column + 1) / 8, line / 8, (line + 1) / 8)
	end

	function TR.Arrow(self, x, y, angle, size, color)
		local shadow = TR.Box(self, 0, 0, 0, 0.85, ART.."GuardianArrow", "OVERLAY", nil, nil, size + 4, size + 4)
		shadow:SetPoint("CENTER", self, "TOPLEFT", x, y)
		TR.Turn(shadow, angle)
		local arrow = TR.Up(self, color[1], color[2], color[3], 1, ART.."GuardianArrow", "BORDER")
		arrow:SetWidth(size)
		arrow:SetHeight(size)
		arrow:SetPoint("CENTER", self, "TOPLEFT", x, y)
		TR.Turn(arrow, angle)
	end

	-- A boss's pip on the timeline (Tracker.lua's SurvivorUI_PaintPip): its
	-- dark edge, then its ring and core a level up.
	function TR.Pip(self, x, y, state, final)
		local size = final and 11 or 9
		local color = TR.STATE[state] or TR.STATE.due
		local ring = final and { 1.00, 0.82, 0.00 } or color
		local core = state == "due" and { 0.09, 0.09, 0.11 } or color
		local edge = TR.Box(self, 0.05, 0.05, 0.07, 1, ART.."Pip", "OVERLAY", nil, nil, size + 4, size + 4)
		edge:SetPoint("CENTER", self, "TOPLEFT", x, y)
		local box = TR.Up(self, ring[1], ring[2], ring[3], 1, ART.."Pip", "BORDER")
		box:SetWidth(size)
		box:SetHeight(size)
		box:SetPoint("CENTER", self, "TOPLEFT", x, y)
		box = TR.Up(self, core[1], core[2], core[3], 1, ART.."Pip", "ARTWORK")
		box:SetWidth(size - 3)
		box:SetHeight(size - 3)
		box:SetPoint("CENTER", self, "TOPLEFT", x, y)
		return edge
	end

	-- A name in its room: its first words by their initial ("K. Taskmaster"),
	-- then cut short, as the guardians' list does.
	function TR.Fit(word, name, room)
		if word:GetStringWidth() > room then
			local words = {}
			for each in string.gfind(name, "%S+") do
				table.insert(words, each)
			end
			if table.getn(words) > 1 then
				local short = ""
				for index = 1, table.getn(words) - 1 do
					short = short..string.sub(words[index], 1, 1)..". "
				end
				word:SetText(short..words[table.getn(words)])
			end
		end
		local shown = word:GetText() or ""
		while word:GetStringWidth() > room and string.len(shown) > 2 do
			shown = string.gsub(shown, "[%z\1-\127\194-\244][\128-\191]*%.?%.?$", "")
			word:SetText(shown.."..")
		end
	end

	----------------------------------------------------------------------------
	-- The tracker's parts, from the top down, each at y; the y under it comes
	-- back.

	-- The tags under the zone's name (SurvivorUI_TagRow), then how the run
	-- stands after the left ones.
	function TR.Tags(self, m, x0, y, state)
		local db = DB()
		local words, named = db.trackerTagWords == true, db.trackerAffixWords == true
		local level = db.trackerDifficulty ~= false
		local row, heroic = {}, level and tonumber(m.heroic)
		if heroic then
			local said = words and SurvivorUI_HeroicName or SurvivorUI_HeroicShort
			table.insert(row, { kind = heroic > 0 and "heroic" or "normal", text = said and said(heroic) or tostring(heroic) })
		end
		if m.endless and level then
			table.insert(row, { kind = "endless", text = words and SurvivorUI_T("Endless") or nil, symbol = ART.."Endless" })
		end
		local leftCount = table.getn(row)
		local affixes = db.trackerAffixes ~= false and m.affixes or {}
		for index = 1, table.getn(affixes) do
			local affix = affixes[index]
			table.insert(row, { kind = "affix", text = (named or not affix.symbol) and SurvivorUI_T(affix.name or "?") or nil,
				symbol = affix.symbol })
		end
		local total, wide = table.getn(row), -3
		for index = 1, total do
			local tag = row[index]
			tag.width = 13
			if tag.text then
				tag.word = TR.Word(self, 9, "", TR.TAG[tag.kind], tag.text)
				tag.width = math.max(13, math.floor(tag.word:GetStringWidth() + 8.5))
			end
			wide = wide + tag.width + 3
		end
		local x = x0
		if db.trackerTagsCentered == true then
			x = x0 + math.floor((TR.WIDTH - wide) / 2 + 0.5)
			for index = 1, total do
				row[index].x = x
				x = x + row[index].width + 3
			end
		else
			for index = 1, leftCount do
				row[index].x = x
				x = x + row[index].width + 3
			end
			local edge = x0 + TR.WIDTH
			for index = total, leftCount + 1, -1 do
				row[index].x = edge - row[index].width
				edge = edge - row[index].width - 3
			end
		end
		for index = 1, total do
			local tag = row[index]
			local color = TR.TAG[tag.kind]
			TR.Box(self, color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1, nil, "BORDER", tag.x, y - 1, tag.width, 13)
			TR.Box(self, color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 1, nil, "ARTWORK", tag.x + 1, y - 2, tag.width - 2, 11)
			if tag.word then
				tag.word:SetPoint("CENTER", self, "TOPLEFT", tag.x + tag.width / 2, y - 7.5)
			else
				TR.Box(self, color[1], color[2], color[3], 1, tag.symbol, "OVERLAY", nil, nil, 9, 9):SetPoint("CENTER", self, "TOPLEFT", tag.x + tag.width / 2, y - 7.5)
			end
		end
		if state ~= "" then
			TR.Word(self, 9, "OUTLINE", TR.WHITE, state):SetPoint("TOPLEFT", self, "TOPLEFT", x > x0 and x + 1 or x0, y - 3)
		end
		if total > 0 or state ~= "" then
			return y - 17
		end
		return y
	end

	-- The clock against the run's length, the coin left of it, then the
	-- timeline: green up to now, a white cap at now, each boss's pip, and over
	-- the next one's its countdown.
	function TR.Time(self, m, x0, y)
		local db = DB()
		local seconds, length = m.seconds or 0, m.length or 0
		local text = TR.Clock(seconds)
		if not m.endless and length > 0 then
			text = text.." |cff8a8a8a/|r |cffb0b0b0"..TR.Clock(length).."|r"
		end
		local grey = (m.phase == "paused" or m.phase == "choosing") and 0.6 or 1
		local clock = TR.Word(self, 18, "THICKOUTLINE", { grey, grey, grey }, text)
		clock:SetPoint("TOP", self, "TOPLEFT", x0 + TR.WIDTH / 2, y - 1)
		if db.trackerCoin == true and (m.cost or 0) > 0 then
			local pays = (m.gold or 0) >= m.cost
			local shine = pays and db.trackerCoinShine ~= false
			local bright = shine and 0.9 or 1
			local coin = TR.Box(self, bright, bright, bright, 1, ART..(pays and "Coin" or "CoinRed"), "OVERLAY", nil, nil, 18, 18)
			coin:SetPoint("RIGHT", clock, "LEFT", -8, 0)
			if shine then
				local glow = TR.Box(self, 1, 0.78, 0.20, 0.7, ART.."PaceGlow", "ARTWORK", nil, nil, 49, 49)
				glow:SetBlendMode("ADD")
				glow:SetPoint("CENTER", coin, "CENTER", 0, 0)
			end
		end
		y = y - 1 - 24 - 12
		local gone = length > 0 and math.min(1, seconds / length) or 1
		TR.Box(self, 0.12, 0.12, 0.15, 0.9, nil, "BORDER", x0, y, TR.WIDTH, 6)
		local fill = m.endless and { 0.70, 0.40, 1.00 } or { 0.30, 0.80, 0.35 }
		if gone > 0 then
			TR.Box(self, fill[1], fill[2], fill[3], 1, nil, "ARTWORK", x0, y, TR.WIDTH * gone, 6)
		end
		if not m.endless and gone < 1 then
			TR.Box(self, 1, 1, 1, 0.95, nil, "OVERLAY", nil, nil, 2, 10):SetPoint("CENTER", self, "TOPLEFT", x0 + TR.WIDTH * gone, y - 3)
		end
		local nextShown
		for index = 1, table.getn(m.bosses or {}) do
			local boss = m.bosses[index]
			local state = m.endless and "dead" or boss.state or "due"
			local isNext = state == "due" and not nextShown
			if isNext then
				nextShown = true
			end
			local at = tonumber(boss.at) or 0
			local spot = length > 0 and TR.WIDTH * math.min(1, at / length) or TR.WIDTH
			local edge = TR.Pip(self, x0 + spot, y - 3, isNext and "next" or state, boss.final)
			if isNext and at > seconds then
				local label = TR.Word(self, 8, "OUTLINE", { 1, 0.55, 0.15 }, TR.Clock(at - seconds))
				local half = label:GetStringWidth() / 2 + 1
				label:SetPoint("BOTTOM", edge, "TOP", math.max(half, math.min(TR.WIDTH - half, spot)) - spot, -1)
			end
		end
		return y - 13
	end

	-- A boss's line (Tracker.lua's FillBossLine), kind "up", "next", "due" or
	-- "dead". Alive with the health on, its health fills the line and reads in
	-- the look chosen; sampled: the next boss as it will look once it comes.
	function TR.BossLine(self, m, x0, y, boss, kind, sampled)
		local db = DB()
		local mid, at = y - 6.5, tonumber(boss.at) or 0
		local color = TR.STATE[kind]
		local name = TR.Word(self, 9, "OUTLINE", kind == "next" and TR.WHITE or color, boss.name or "?")
		name:SetPoint("LEFT", self, "TOPLEFT", x0, mid)
		local time = TR.Word(self, 9, "OUTLINE", kind == "up" and TR.WHITE or color, TR.Clock(at))
		time:SetPoint("RIGHT", self, "TOPLEFT", x0 + TR.WIDTH, mid)
		if kind == "up" then
			local hp, hpm = boss.hp, boss.hpm
			if sampled then
				hp, hpm = 2400000, 3300000
			end
			if db.trackerHealth and hp and hpm then
				TR.Box(self, 0.12, 0.12, 0.15, 0.9, nil, "BORDER", x0, y, TR.WIDTH, 13)
				TR.Box(self, 1.00, 0.55, 0.15, 0.85, nil, "ARTWORK", x0, y, math.max(1, TR.WIDTH * (hpm > 0 and hp / hpm or 0)), 13)
				name:SetTextColor(1, 1, 1)
				time:SetText(SurvivorUI_HealthText and SurvivorUI_HealthText(hp, hpm, db.trackerHealthLook or "percent") or "")
			else
				local share = (hp and hpm and hpm > 0) and math.floor(hp / hpm * 100 + 0.5).."%   " or ""
				time:SetText("|cffff8c40"..share.."|r"..TR.Clock(at))
			end
		elseif kind == "next" then
			time:SetText("|cffffd24d"..SurvivorUI_TF("in {1}", TR.Clock(at - (m.seconds or 0))).."|r   "..TR.Clock(at))
		elseif kind == "dead" and boss.fell then
			time:SetText("|cff8a8a8a"..TR.Clock(at).."  /|r  "..TR.Clock(boss.fell))
		end
		return y - 13
	end

	-- Two of the bosses' lines: the one alive (else the next, as it will look
	-- alive), then the one to come after it.
	function TR.Bosses(self, m, x0, y)
		local bosses = m.bosses or {}
		local count, first, real = table.getn(bosses), nil, nil
		for index = 1, count do
			if not first and bosses[index].state == "up" and not m.endless then
				first, real = index, true
			end
		end
		for index = 1, count do
			if not first and (bosses[index].state or "due") == "due" and not m.endless then
				first = index
			end
		end
		first = first or count
		if first < 1 then
			return y
		end
		y = TR.BossLine(self, m, x0, y, bosses[first], "up", not real)
		for index = first + 1, count do
			if (bosses[index].state or "due") == "due" and not m.endless then
				return TR.BossLine(self, m, x0, y, bosses[index], real and "next" or "due")
			end
		end
		return y
	end

	-- The guardians as a bar (Guardians.lua's SurvivorUI_GuardianBar): a
	-- stretch a lair in their order, its arrow in its middle, the 8:00
	-- achievement over it.
	function TR.Bar(self, m, x0, y)
		local db = DB()
		local thick = tonumber(db.guardiansBarHeight) or 9
		local top = y - 18
		TR.Word(self, 9, "OUTLINE", TR.DIM, SurvivorUI_T("Guardians")):SetPoint("BOTTOMLEFT", self, "TOPLEFT", x0, top + 3)
		TR.Word(self, 9, "OUTLINE", m.goalColor or TR.DIM, m.goal):SetPoint("BOTTOMRIGHT", self, "TOPLEFT", x0 + TR.WIDTH, top + 3)
		local lairs = m.lairs
		local count = table.getn(lairs)
		local each = (TR.WIDTH - 3 * (count - 1)) / math.max(count, 1)
		for index = 1, count do
			local entry = lairs[index]
			local x, middle = x0 + (index - 1) * (each + 3), top - thick / 2
			local share, color = 1, TR.RESPAWN
			if entry.alive and entry.state == "awake" then
				share, color = entry.share or 1, TR.AWAKE
			elseif entry.alive then
				color = TR.NEARNESS[math.min(entry.rank or 1, 4)]
			end
			TR.Box(self, 0.12, 0.12, 0.15, 0.9, nil, "BORDER", x, top, each, thick)
			TR.Box(self, color[1], color[2], color[3], 0.9, nil, "ARTWORK", x, top, math.max(1, each * share), thick)
			local spot = x + each / 2
			local words
			if entry.state == "awake" then
				words = entry.share and string.format("%d%%", entry.share * 100 + 0.5) or SurvivorUI_T("FIGHT")
			elseif not entry.alive and entry.left and entry.left > 0 then
				words = TR.Clock(entry.left, true)
			elseif entry.alive and entry.angle and db.guardiansBarArrows ~= false then
				TR.Arrow(self, spot, middle, entry.angle, entry.rank == 1 and 15 or 12, TR.WHITE)
			end
			if words then
				TR.Word(self, 8, "OUTLINE", TR.WHITE, words):SetPoint("CENTER", self, "TOPLEFT", spot, middle)
			end
		end
		return top - thick
	end

	-- The lairs as cells (SurvivorUI_LairCells): on the count's line from the
	-- right ("line"), or in a row under it, each in its share ("row").
	function TR.Cells(self, lairs, style, left, right, y)
		local count, cells = table.getn(lairs), {}
		for index = 1, count do
			local lair = lairs[index]
			local cell = { color = TR.SPAWNED }
			if not lair.alive then
				cell.color = TR.RESPAWN
				cell.words = (lair.left and lair.left > -1) and TR.Clock(math.max(0, lair.left), true) or "-"
			elseif lair.state == "awake" then
				cell.color = TR.AWAKE
				cell.words = lair.share and string.format("%d%%", lair.share * 100 + 0.5) or SurvivorUI_T("FIGHT")
			elseif style == "row" then
				cell.words = SurvivorUI_T("alive")
			end
			cell.width = 8
			if cell.words then
				cell.word = TR.Word(self, 9, "OUTLINE", cell.color, cell.words)
				cell.width = cell.word:GetStringWidth()
			end
			cells[index] = cell
		end
		local edge = right
		for step = 1, count do
			local index = style == "row" and step or count - step + 1
			local cell = cells[index]
			local x
			if style == "row" then
				x = left + (index - 0.5) * (right - left) / count - cell.width / 2
			else
				x = edge - cell.width
				edge = x - 6
			end
			if cell.word then
				cell.word:SetPoint("LEFT", self, "TOPLEFT", x, y)
			else
				TR.Box(self, TR.SPAWNED[1], TR.SPAWNED[2], TR.SPAWNED[3], 1, ART.."Pip", "OVERLAY", nil, nil, 8, 8):SetPoint("LEFT", self, "TOPLEFT", x, y)
			end
		end
	end

	-- The guardians as a count, of its three kinds ("count", "line", "row"):
	-- Guardians.lua's DrawCount.
	function TR.Count(self, m, x0, y, style)
		local top = y - 6
		local mid = top - 6
		local title = TR.Word(self, 9, "OUTLINE", TR.DIM, SurvivorUI_T("Guardians"))
		title:SetPoint("LEFT", self, "TOPLEFT", x0, mid)
		local titleWidth = title:GetStringWidth()
		local lairs = m.lairs
		local alive, awake, soonest = 0, 0, nil
		for index = 1, table.getn(lairs) do
			local entry = lairs[index]
			if entry.alive then
				alive = alive + 1
			end
			if entry.state == "awake" then
				awake = awake + 1
			end
			if not entry.alive and entry.left and entry.left > 0 and (not soonest or entry.left < soonest) then
				soonest = entry.left
			end
		end
		if style == "line" then
			TR.Cells(self, lairs, "line", x0 + titleWidth + 8, x0 + TR.WIDTH, mid)
			return top - 12
		end
		local color = awake > 0 and TR.AWAKE or (alive > 0 and TR.SPAWNED or TR.DIM)
		local text = SurvivorUI_TF("{1} / {2} alive", alive, table.getn(lairs))
		if style == "count" and soonest then
			text = text.."|cff8c8c94  "..TR.DOT.." "..SurvivorUI_TF("next {1}", "|cffff4738"..TR.Clock(soonest, true).."|cff8c8c94").."|r"
		end
		TR.Word(self, 9, "OUTLINE", color, text):SetPoint("RIGHT", self, "TOPLEFT", x0 + TR.WIDTH, mid)
		if style ~= "row" then
			return top - 12
		end
		TR.Cells(self, lairs, "row", x0, x0 + TR.WIDTH, mid - 12)
		-- The box round the count and its row, a little past them.
		local bx, by, bw, bh = x0 - 4, top + 3, TR.WIDTH + 8, 30
		TR.Box(self, 0.05, 0.05, 0.07, 0.6, nil, "BORDER", bx, by, bw, bh)
		TR.Box(self, 0.34, 0.34, 0.38, 0.9, nil, "ARTWORK", bx, by, bw, 1)
		TR.Box(self, 0.34, 0.34, 0.38, 0.9, nil, "ARTWORK", bx, by - bh + 1, bw, 1)
		TR.Box(self, 0.34, 0.34, 0.38, 0.9, nil, "ARTWORK", bx, by, 1, bh)
		TR.Box(self, 0.34, 0.34, 0.38, 0.9, nil, "ARTWORK", bx + bw - 1, by, 1, bh)
		return top - 12 - 15
	end

	-- The elites alive: a small bar each, bright once hurt.
	function TR.Elites(self, m, x0, y)
		local e = m.elites
		if DB().trackerElites == false or not e then
			return y
		end
		TR.Word(self, 9, "OUTLINE", TR.DIM, SurvivorUI_T("Elites")):SetPoint("TOPLEFT", self, "TOPLEFT", x0, y - 6)
		local text
		if e.total == 0 then
			text = SurvivorUI_T("|cff8a8a8anone|r")
		elseif e.hurt > 0 then
			text = "|cffffffff"..SurvivorUI_TF("{1} alive", e.total).."|r  "..TR.DOT.."  |cff59ff33"..SurvivorUI_TF("{1} fighting", e.hurt).."|r"
		else
			text = "|cffffffff"..SurvivorUI_TF("{1} alive", e.total).."|r"
		end
		TR.Word(self, 9, "OUTLINE", TR.WHITE, text):SetPoint("TOPRIGHT", self, "TOPLEFT", x0 + TR.WIDTH, y - 6)
		y = y - 18
		local slots = e.slots or 8
		local each = (TR.WIDTH - (slots - 1) * 2) / slots
		for index = 1, slots do
			local x, share = x0 + (index - 1) * (each + 2), e.shares[index]
			TR.Box(self, 0.12, 0.12, 0.15, 0.9, nil, "BORDER", x, y, each, 7)
			if share then
				TR.Box(self, 0.35, 1.00, 0.20, share < 1 and 0.9 or 0.35, nil, "ARTWORK", x, y, math.max(1, each * share), 7)
			end
		end
		return y - 7
	end

	-- The guardians' list (Guardians.lua's Draw), so wide: the living first,
	-- the nearest first; each line its name, where it stands, how far and its
	-- arrow, these from its right edge; the first lit faintly, over a
	-- shade behind it. As many lines as fit above bottom; the y under the last
	-- comes back.
	function TR.List(self, m, x, y, bottom, wide)
		TR.Word(self, 10, "OUTLINE", { 1, 0.82, 0 }, SurvivorUI_T("Guardians")):SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		TR.Word(self, 9, "OUTLINE", m.goalColor or TR.DIM, m.goal):SetPoint("TOPRIGHT", self, "TOPLEFT", x + wide, y - 1)
		local list = {}
		for index = 1, table.getn(m.lairs) do
			table.insert(list, m.lairs[index])
		end
		table.sort(list, function(a, b)
			if a.alive ~= b.alive then
				return a.alive and true or false
			end
			local ya, yb = a.yards or 99999, b.yards or 99999
			if ya ~= yb then
				return ya < yb
			end
			return a.place < b.place
		end)
		local foot = y - 16
		for index = 1, table.getn(list) do
			local top = y - 14 * index - 2
			if top - 13 < bottom then
				return foot
			end
			foot = top - 14
			local entry = list[index]
			local color, nameColor, state = TR.SPAWNED, TR.NAME, SurvivorUI_T("SPAWNED")
			if not entry.alive then
				color, nameColor = TR.RESPAWN, TR.DIM
				state = (entry.left and entry.left > 0) and TR.Clock(entry.left, true) or SurvivorUI_T("soon")
			elseif entry.state == "awake" then
				color, nameColor = TR.AWAKE, TR.AWAKE
				state = entry.share and string.format("%d%%", entry.share * 100 + 0.5) or SurvivorUI_T("AWAKE")
			end
			if index == 1 then
				local light = TR.Box(self, color[1], color[2], color[3], 0.14, nil, "BORDER", x - 3, top + 1, wide + 6, 14)
				if light.SetGradientAlpha then
					light:SetGradientAlpha("HORIZONTAL", color[1], color[2], color[3], 0.22, color[1], color[2], color[3], 0.03)
				end
			end
			local name = TR.Word(self, 10, "OUTLINE", nameColor, entry.name)
			name:SetPoint("TOPLEFT", self, "TOPLEFT", x, top)
			TR.Fit(name, entry.name or "?", wide - 118)
			TR.Word(self, 9, "OUTLINE", color, state):SetPoint("TOPRIGHT", self, "TOPLEFT", x + wide - 57, top - 1)
			if entry.yards then
				TR.Word(self, 9, "OUTLINE", TR.DIM, SurvivorUI_TF("{1} yd", math.floor(entry.yards + 0.5))):SetPoint("TOPRIGHT", self, "TOPLEFT", x + wide - 15, top - 1)
			end
			if entry.angle then
				TR.Arrow(self, x + wide - 6, top - 6, entry.angle, entry.rank == 1 and 15 or 12, entry.alive and color or TR.DIM)
			end
		end
		return foot
	end

	-- The preview: the tracker at the column's middle, its shade behind it;
	-- the list, when chosen, hung right under it inside that shade (or in its
	-- place with the tracker off), or free under it at its own width.
	function Paint.Tracker(self)
		TR.Begin(self)
		local m, way = TR.Model(), TR.Way()
		local x0, y0 = math.floor((self:GetWidth() - TR.WIDTH) / 2), -18
		local y, hung, bottom = y0, DB().guardiansFree ~= true, -self:GetHeight() + 5
		if m.sample or (m.sampleTags and DB().tracker ~= false) then
			self:Word(SurvivorUI_FONT, 8 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], m.sample and "A sample run" or "Sample tags"):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		end
		if DB().tracker ~= false then
			TR.step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Run tracker") or 0
			TR.Word(self, 12, "OUTLINE", { 0.45, 0.90, 0.45 }, m.zone):SetPoint("TOP", self, "TOPLEFT", x0 + TR.WIDTH / 2, y)
			y = TR.Tags(self, m, x0, y - 15, TR.State(m))
			y = TR.Time(self, m, x0, y)
			y = TR.Bosses(self, m, x0, y)
			if way == "bar" then
				y = TR.Bar(self, m, x0, y)
			elseif TR.COUNTS[way] then
				y = TR.Count(self, m, x0, y, way)
			end
			y = TR.Elites(self, m, x0, y)
			if way == "list" and hung then
				TR.step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Guardians") or 0
				y = TR.List(self, m, x0, y - TR.GAP, bottom, TR.WIDTH)
				way = nil
			end
			TR.Box(self, 0.04, 0.04, 0.07, 0.55, nil, "BACKGROUND", x0 - 8, y0 + 6, TR.WIDTH + 16, y0 - y + 12)
			y = y - 14
		elseif way == "list" and hung then
			-- The list in the tracker's place.
			y = y0
		else
			self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "Run tracker off"):SetPoint("TOP", self, "TOP", 0, -34)
			y = -60
		end
		if way == "list" then
			TR.step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Guardians") or 0
			TR.List(self, m, hung and x0 or x0 + 5, y, bottom, hung and TR.WIDTH or TR.LIST)
		end
	end

	----------------------------------------------------------------------------
	-- The settings: a column of them beside the preview, then across the page.
	-- A switch on a section's line sits on its top edge, the piece under it
	-- right under it.

	Kit.Split(tab)
	local left, width = Span(tab)
	Kit.Size(tab, "Size", 0.5, 2, 0.05,
		function() return SurvivorUI_GetScale and SurvivorUI_GetScale("tracker") or 1 end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("tracker", value) end end,
		{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Section(tab, "Text size", "The tracker's words, a step at a time. The guardians' list has its own, under Advanced.")
	Kit.Stepper(tab, nil, -4, 8, 1, TR.StepGet("Run tracker"), TR.StepSet("Run tracker"), TR.StepText)
	-- The run's difficulty and the week's affixes, the tags under the zone's
	-- name (Tracker.lua's SurvivorUI_TagRow): each side short, in words or
	-- away, a row each; Centered on the section's line, at its right.
	function TR.DifficultyLook()
		local db = DB()
		if db.trackerDifficulty == false then
			return "off"
		end
		return db.trackerTagWords == true and "words" or "short"
	end

	function TR.SetDifficultyLook(look)
		local db = DB()
		if look == "off" then
			db.trackerDifficulty = false
		else
			db.trackerDifficulty, db.trackerTagWords = nil, look == "words" or nil
		end
	end

	function TR.AffixLook()
		local db = DB()
		if db.trackerAffixes == false then
			return "off"
		end
		return db.trackerAffixWords == true and "words" or "icons"
	end

	function TR.SetAffixLook(look)
		local db = DB()
		if look == "off" then
			db.trackerAffixes = false
		else
			db.trackerAffixes, db.trackerAffixWords = nil, look == "words" or nil
		end
	end

	function TR.AnyTag()
		return DB().trackerDifficulty ~= false or DB().trackerAffixes ~= false
	end

	-- A choice on a row of its own, its name before it; on another page with
	-- on (the Tracker Ring's).
	function TR.Row(label, options, get, set, on)
		on = on or tab
		local y = on.y
		local name = Text(on, 10, TEXT)
		name:SetPoint("TOPLEFT", on, "TOPLEFT", (on.inset or 0) + (on.left or 0) + 2, y - 7)
		name:SetText(label)
		local holder = Kit.Segments(on, options, get, set)
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", on, "TOPLEFT", (on.inset or 0) + (on.left or 0) + 64, y)
		on.y = y - 30
		return holder
	end

	do
		local top = tab.y
		Kit.Section(tab, "Difficulty and affixes", "The tags under the zone's name. At the left the run's difficulty: N or the Heroic level (in words, Normal or Heroic II), and endless mode's symbol once the run goes on past its end. At the right the week's affixes, a Heroic run's from III (one) and V (two), each by its symbol or its name. Under the mouse, each in full; an affix with what it does. Off: that side away.")
		local below = tab.y
		tab.y = top + 1
		Kit.Chips(tab, {
			{ "Centered", OnlyIfOn("trackerTagsCentered"), function() DB().trackerTagsCentered = not DB().trackerTagsCentered or nil end,
				"All the tags together in the middle. Off: the difficulty at the left, the affixes at the right.",
				usable = TR.AnyTag, why = "Nothing to center: the difficulty and the affixes are both off." },
		})
		local chip = widgets[table.getn(widgets)]
		chip:ClearAllPoints()
		chip:SetPoint("TOPRIGHT", tab, "TOPLEFT", left + width, top + 1)
		tab.y = below
		TR.Row("Difficulty", { { "short", "Short" }, { "words", "Words" }, { "off", "Off" } }, TR.DifficultyLook, TR.SetDifficultyLook)
		TR.Row("Affixes", { { "icons", "Icons" }, { "words", "Words" }, { "off", "Off" } }, TR.AffixLook, TR.SetAffixLook)
	end
	Kit.Section(tab, "Elites", "A small bar for each elite alive, bright once hurt; click one to target it. The bars shown, 4 to 12: the hurt first, the rest only in the count.")
	Kit.Switch(tab, left + width - 62, tab.y + 20, OnUnlessOff("trackerElites"), Flip("trackerElites"))
	do
		local y = tab.y
		Kit.Stepper(tab, nil, 4, 12, 1, function() return tonumber(DB().trackerElitesMax) or 8 end,
			function(value) DB().trackerElitesMax = value end, "%d bars")
		side.Index(tab, "Bars shown", "elites bars count", y, 24)
		-- Its chip right of the stepper.
		tab.width, tab.y = width - 120, y - 1
		tab.left = 120
		Kit.Chips(tab, {
			{ "Hide when none", OnlyIfOn("trackerElitesHide"), function() DB().trackerElitesHide = not DB().trackerElitesHide end,
				"With no elite alive, the row goes. Off: it keeps its room, so nothing under it moves." },
		})
		tab.left, tab.width, tab.y = 0, width, y - 30
	end
	-- The Tracker Ring, the tracker's other look, in its own tab (Experimental):
	-- in the room the column leaves beside the preview.
	tab.y = tab.y + 4
	Kit.Link(tab, "Try the tracker as a dial, in Experimental:", "dial")
	Kit.Right(tab)
	do
		local preview = Kit.Preview(tab, 238, Paint.Tracker)
		preview:ClearAllPoints()
		preview:SetPoint("TOPLEFT", tab, "TOPLEFT", tab.left, tab.splitY)
		preview:SetWidth(tab.width)
		-- The run's clock goes on: drawn again each second.
		preview:SetScript("OnUpdate", function()
			this.wait = (this.wait or 0) + arg1
			if this.wait >= 1 then
				this.wait = 0
				this:Refresh()
			end
		end)
	end
	Kit.Join(tab)

	-- The boss health's switch at the right of its looks, on their row.
	Kit.Section(tab, "Boss health", "Each boss alive fills its line with its health, in the fight's orange; click the line to target it. With it on, the game's boss bars stay away. Off: the line shows its share and the second it came. The looks: how its health reads.")
	do
		local looks = Kit.Segments(tab, HEALTH_LOOKS, function() return DB().trackerHealthLook or "percent" end,
			function(look) DB().trackerHealthLook = look end)
		local switch = Kit.Switch(tab, 0, 0, OnlyIfOn("trackerHealth"), function()
			DB().trackerHealth = not DB().trackerHealth
			if SurvivorUI_ApplyBossHud then
				SurvivorUI_ApplyBossHud()
			end
		end)
		switch:ClearAllPoints()
		switch:SetPoint("LEFT", looks, "RIGHT", 18, 0)
	end

	-- The thickness of the bar on the section's line, right; the looks under it.
	Kit.Section(tab, "Guardians","A bar: a stretch a lair in the tracker, red once slain, an arrow toward each guardian there. A list: a line a lair, hung right under the tracker (Free, under Advanced: on its own), with how far. A count: how many lairs hold their guardian, and the next to fill. Lair timers: each lair's time to fill again, on that line. Count and timers: both. Off: none, as in Modules.")
	do
		local y = tab.y
		local thick = Kit.Stepper(tab, nil, 4, 16, 1, function() return tonumber(DB().guardiansBarHeight) or 9 end,
			function(value) DB().guardiansBarHeight = value ~= 9 and value or nil end, "%d px")
		thick:ClearAllPoints()
		thick:SetPoint("TOPLEFT", tab, "TOPLEFT", PAGE_WIDTH - 116, y + 20)
		local label = Text(tab, 10, TEXT)
		label:SetPoint("RIGHT", thick, "LEFT", -10, 0)
		label:SetText("Bar thickness")
		side.Index(tab, "Bar thickness", "guardians bar thick height", y + 20, 24)
		tab.y = y - 6
	end
	Kit.Segments(tab, { { "bar", "A bar" }, { "list", "A list" }, { "count", "A count" }, { "line", "Lair timers" },
		{ "row", "Count and timers" }, { "off", "Off" } }, TR.Way, TR.SetWay)
	Kit.Chips(tab, {
		{ "Arrows on the bar", OnUnlessOff("guardiansBarArrows"), Flip("guardiansBarArrows"),
			"An arrow toward each guardian on its stretch. Off: a stretch still flashes as you come near.",
			usable = function() return TR.Way() == "bar" end, why = "Only for the bar: A bar, under Guardians." },
		{ "North up", OnlyIfOn("guardiansNorth"), Call("SurvivorUI_ToggleGuardians", "north"),
			"The arrows point north up, as the minimap does. Off: they turn with you, straight up straight ahead." },
	})

	Kit.Section(tab, "Coin","The coin, left of the clock: gold while your gold pays for the next cache, red while not. The Kills & gold line's coin has a shine of its own, in that tab. Your level and its experience: the XP bar tab.")
	Kit.Chips(tab, {
		{ "Cache coin", OnlyIfOn("trackerCoin"), function() DB().trackerCoin = not DB().trackerCoin end,
			"Left of the clock: gold when you can pay for the next cache, red when not. Hover it for the price." },
		{ "Coin shines", OnUnlessOff("trackerCoinShine"), Flip("trackerCoinShine"),
			"While you can pay, the Cache coin shines: a glow breathes behind it, a spark on its rim now and then. The Kills & gold line's coin has its own, in that tab.",
			usable = OnlyIfOn("trackerCoin"), why = "Cache coin is off." },
	})

	-- The list's own (Guardians.lua's window): hung under the tracker, at its
	-- width and size, or Free, on its own, at its own size and place (the
	-- size and Back to its place faded while hung).
	function TR.Free()
		return DB().guardiansFree == true
	end

	-- A piece of the box live only while the list is free; inner, the part
	-- that takes the mouse.
	function TR.WhileFree(piece, inner)
		local Shown = piece.Refresh
		function piece:Refresh()
			if Shown then
				Shown(self)
			end
			local free = TR.Free()
			self:SetAlpha(free and 1 or 0.4)
			if inner then
				inner:EnableMouse(free)
				inner:EnableMouseWheel(free)
			end
		end
		if not Shown then
			table.insert(widgets, piece)
		end
	end

	do
		local box = Kit.Advanced(tab, "the guardians' list: hung or free, its size, text size and place")
		local column = math.floor((box.full - 24) / 2)
		local size = SizeSlider(box, box.inset, box.y, column, "List size", 0.5, 2, 0.05,
			function() return SurvivorUI_GetScale and SurvivorUI_GetScale("guardians") or 1 end,
			function(value)
				if SurvivorUI_SetPartScale then
					SurvivorUI_SetPartScale("guardians", value)
				end
			end)
		TR.WhileFree(size, size:GetChildren())
		SizeSlider(box, box.inset + column + 24, box.y, column, "List text size", -4, 8, 1, TR.StepGet("Guardians"),
			function(value)
				TR.StepSet("Guardians")(value)
				tab.preview:Refresh()
			end, TR.StepText)
		box.y = box.y - 36
		local back = Kit.Quiet(box, "List back to its place", 160, function()
			if TR.Free() and SurvivorUI_ResetPiece then
				SurvivorUI_ResetPiece("Guardians")
			end
		end)
		back:SetHeight(20)
		back:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, -8)
		TR.WhileFree(back)
		side.Index(box, "List back to its place", "guardians list reset place position", -10, 20)
		-- Free on the box's first line, left of Back to its place.
		local y = box.y
		box.y = -8
		Kit.Chips(box, {
			{ "Free list", TR.Free, function()
					DB().guardiansFree = not DB().guardiansFree or nil
					if SurvivorUI_PlaceGuardians then
						SurvivorUI_PlaceGuardians()
					end
					-- Its move handle out or back at once, the tab still open.
					if SurvivorUI_SetMoveFocus then
						SurvivorUI_SetMoveFocus(TAB_PIECES.tracker)
					end
				end,
				"The list on its own: moved by itself (hold Alt, or Move UI), at its own size (List size); first against the tracker's left side. Off: it hangs right under the tracker, at its width and size, and goes with it.",
				usable = function() return TR.Way() == "list" end, why = "Only for the list: A list, under Guardians." },
		})
		local chip = widgets[table.getn(widgets)]
		chip:ClearAllPoints()
		chip:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12 - 160 - 8, -7)
		box.y = y
		Kit.EndAdvanced(tab, box)
	end

	-- Every look on this page back to its first, the list hung again; where
	-- the tracker stands stays, and the free list's place. The guardians as a
	-- new install has them (SurvivorUI.lua, v3.0.56): the bar, its arrows on.
	function TR.Reset()
		local db = DB()
		for _, key in pairs({ "trackerTagWords", "trackerAffixWords", "trackerTagsCentered", "trackerDifficulty", "trackerAffixes",
			"trackerHealthLook", "guardiansCount", "guardiansBarArrows", "guardiansNorth", "guardiansBarHeight",
			"guardiansFree", "trackerElites", "trackerElitesMax", "trackerElitesHide", "trackerCoin", "trackerCoinShine" }) do
			db[key] = nil
		end
		db.trackerHealth = false
		db.guardians, db.guardiansDocked = true, true
		if SurvivorUI_ApplyBossHud then
			SurvivorUI_ApplyBossHud()
		end
		if SurvivorUI_SetPartScale then
			SurvivorUI_SetPartScale("tracker", 1)
			SurvivorUI_SetPartScale("guardians", 1)
		end
		if SurvivorUI_SetPieceTextStep then
			SurvivorUI_SetPieceTextStep("Run tracker", 0)
			SurvivorUI_SetPieceTextStep("Guardians", 0)
		end
		if SurvivorUI_PlaceGuardians then
			SurvivorUI_PlaceGuardians()
		end
	end
	Kit.Foot(tab, { reset = Asked("Run tracker back to default?",
		"The difficulty and the affixes short, at the row's ends; no boss health in the lines (73% when on); the guardians as a bar with its arrows, the list hung under the tracker; 8 elite bars; no coin (it shines when on); the first sizes and text sizes. Where the tracker stands stays, and the free list's place for when it is free again: Back to its place for those.",
		"Back to default", TR.Reset) })
end

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

-- Reworked (the kit): the preview draws the bars as BossBars.lua does, a
-- boss's, a guardian's and an elite's, at their size and text size.

page = pages.bosses
Kit.Head(page, { line = "At the top of the screen: the bosses and the awake guardians, with their debuffs, apart from the run tracker.",
	isOn = OnUnlessOff("bossBars"), toggle = Call("SurvivorUI_BossBars"), game = GAME.bosses, piece = "Boss bars", advanced = true })

function Paint.Bosses(self)
	self:Begin()
	if DB().bossBars == false then
		self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "No boss bars"):SetPoint("CENTER", self, "CENTER", 0, 0)
		return
	end
	local scale = SurvivorUI_GetScale and SurvivorUI_GetScale("bosses") or 1
	local step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Boss bars") or 0
	local look = DB().bossHealth or "absolutePercent"
	local width, height = math.floor(220 * scale + 0.5), math.floor(18 * scale + 0.5)
	local bars = {
		{ { 0.72, 0.32, 1.00 }, "Hogger", 2400000, 3300000 },
		{ { 0.20, 0.75, 0.95 }, "Lair guardian", 640000, 1500000 },
	}
	if DB().bossBarsElites then
		table.insert(bars, { { 0.35, 1.00, 0.20 }, "Elite", 90000, 120000 })
	end
	local x = math.floor((PAGE_WIDTH - width) / 2)
	local y = -math.floor((self:GetHeight() - table.getn(bars) * (height + 4)) / 2) - 4
	for index = 1, table.getn(bars) do
		local bar = bars[index]
		local color = bar[1]
		-- The black edge a layer under; the health and the dark rest of the
		-- bar side by side over it.
		local border = self:Box(0, 0, 0, 1, nil, "BORDER")
		border:SetPoint("TOPLEFT", self, "TOPLEFT", x - 1, y + 1)
		border:SetWidth(width + 2)
		border:SetHeight(height + 2)
		local filled = math.floor(width * bar[3] / bar[4] + 0.5)
		local fill = self:Box(color[1], color[2], color[3], 0.9)
		fill:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		fill:SetWidth(filled)
		fill:SetHeight(height)
		local rest = self:Box(0.08, 0.08, 0.1, 1)
		rest:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
		rest:SetWidth(width - filled)
		rest:SetHeight(height)
		local size = (10 + FONT_BUMP + step) * math.max(0.7, scale)
		self:Word(SurvivorUI_FONT, size, "OUTLINE", 1, 1, 1, bar[2]):SetPoint("LEFT", border, "LEFT", 6, 0)
		local value = SurvivorUI_HealthText and SurvivorUI_HealthText(bar[3], bar[4], look) or ""
		self:Word(SurvivorUI_FONT, size, "OUTLINE", 1, 1, 1, value):SetPoint("RIGHT", border, "RIGHT", -6, 0)
		y = y - height - 4
	end
end
Kit.Preview(page, 96, Paint.Bosses)

Kit.Section(page, "Health", "As each bar's right end reads it. Always short: 1.2M for 1,200,000.")
do
	local looks = {}
	for index = 1, table.getn(HEALTH_LOOKS) do
		table.insert(looks, { HEALTH_LOOKS[index][1], HEALTH_LOOKS[index][2] })
	end
	Kit.Segments(page, looks, function() return DB().bossHealth or "absolutePercent" end,
		function(look) DB().bossHealth = look end)
end
Kit.Split(page)
Kit.Size(page, "Size", 0.5, 2, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale("bosses") or 1 end,
	function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("bosses", value) end end,
	{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
Kit.Right(page)
Kit.Section(page, "Shows", "Only the run tracker's own bosses? Untick Elites and The game's, and keep the tracker's Boss health on (Run tracker tab): with it on, the game's bars stay away anyway.")
Kit.Chips(page, {
	{ "Elites", OnlyIfOn("bossBarsElites"), Call("SurvivorUI_BossBars", "elites"), "The elites alive get a bar too, under the bosses and guardians." },
})
Kit.Join(page)
do
	local box = Kit.Advanced(page, "text size")
	Kit.Stepper(box, "Text size", -4, 8, 1,
		function() return SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Boss bars") or 0 end,
		function(value) if SurvivorUI_SetPieceTextStep then SurvivorUI_SetPieceTextStep("Boss bars", value) end end,
		function(value) return value == 0 and "normal" or ((value > 0 and "+" or "")..value) end)
	Kit.EndAdvanced(page, box)
end
Kit.Foot(page, { reset = Asked("Boss bars back to default?",
	"The health as 1.2M | 73%, no elites, the first size and text size. Where it stands stays: Back to its place for that.", "Back to default",
	function()
		DB().bossHealth = nil
		if DB().bossBarsElites and SurvivorUI_BossBars then
			SurvivorUI_BossBars("elites")
		end
		if SurvivorUI_SetPartScale then
			SurvivorUI_SetPartScale("bosses", 1)
		end
		if SurvivorUI_SetPieceTextStep then
			SurvivorUI_SetPieceTextStep("Boss bars", 0)
		end
	end) })

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
Check(page, "Coin shines when you can pay", function() return not SurvivorUI_TallyCoinShine or SurvivorUI_TallyCoinShine() end,
	function()
		if SurvivorUI_SetTallyCoinShine then
			SurvivorUI_SetTallyCoinShine(not SurvivorUI_TallyCoinShine())
		end
	end, "this coin; the run tracker's Cache coin has its own (Run tracker tab)")
Check(page, "A coin drops when you can pay", OnUnlessOff("coinDrop"), Flip("coinDrop"), "each time your gold pays for one cache more, bought or not; the line on or off")
-- Its sound from a list (Tally.lua's): ours, and the game's own coin and
-- auction house sounds; picking one plays it.
Dropdown(page, "Sound", function()
	local list, sounds = {}, SurvivorUI_COIN_SOUNDS or {}
	for index = 1, table.getn(sounds) do
		table.insert(list, { value = sounds[index].key, name = sounds[index].name, note = sounds[index].note })
	end
	return list
end, function() return DB().coinSound or "hoard" end, function(key)
	DB().coinSound = key ~= "hoard" and key or nil
	if SurvivorUI_CoinDrop then
		SurvivorUI_CoinDrop()
	end
end, 300)
Check(page, "Coins rain on the gold", OnUnlessOff("coinRain"), Flip("coinRain"), "with it: on this line, else the tracker's coin, else over you")
Button(page, "Try it", 120, 0, function()
	if SurvivorUI_CoinDrop then
		SurvivorUI_CoinDrop()
	end
	if SurvivorUI_CoinRain then
		SurvivorUI_CoinRain(true)
	end
end)
page.y = page.y - 28

------------------------------------------------------------------------------
-- XP bar (XpBar.lua).

page = pages.xpbar
Header(page, "XP bar", "Your level and experience as a bar of its own, at the top of the screen.")
PanelHead(page, OnlyIfOn("xpBar"), Call("SurvivorUI_ToggleXpBar"), "xpbar", "XP bar")
Subheader(page, "What shows")
Check(page, "Time to the next level", OnUnlessOff("xpBarEta"), Flip("xpBarEta"), "under the bar's left end, from the recent pace")
Check(page, "Experience a minute", function()
	-- Off before v3.0.37 with the time (one choice then): off still.
	if DB().xpBarRate == nil and DB().xpBarEta == false then
		return false
	end
	return DB().xpBarRate ~= false
end, function()
	local on = DB().xpBarRate ~= false and not (DB().xpBarRate == nil and DB().xpBarEta == false)
	DB().xpBarRate = not on
end, "under the bar's right end, the recent pace")
Check(page, "Luck and the cards' odds", OnUnlessOff("xpBarLuck"), Flip("xpBarLuck"),
	"your luck over the bar; hover the bar for every kind of pick, or a side's odds for its own")
Check(page, "The odds' ribbon under the bar", function() return DB().xpBarRibbon == true end,
	function() DB().xpBarRibbon = (not DB().xpBarRibbon) or nil end,
	"the next card's odds, each rarity's color as wide as its chance")
Check(page, "The odds beside the bar", function() return DB().xpBarOddsSide == true end,
	function() DB().xpBarOddsSide = (not DB().xpBarOddsSide) or nil end,
	"to read without the mouse: a legendary's, an epic's and a rare's chance, the spells' and jewelry's on its left, the amulets' on its right")
-- Their look (XpBar.lua): the numbers, or each in a small bar.
Inline(page, "The odds as", {
	{ "numbers", "Numbers" },
	{ "fill", "Bars filled" },
	{ "tag", "Tags" },
}, function() return DB().xpBarOddsLook or "numbers" end, function(look) DB().xpBarOddsLook = look ~= "numbers" and look or nil end)

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
Note(page, "The levels waiting also show by your level on the XP bar: Lv. 12 +3. While this tab is open the button shows, to be placed.")

------------------------------------------------------------------------------
-- Loot list (LootLog.lua).

page = pages.loot
Header(page, "Loot list", "What the run dropped, a bar a piece filled with its quality's color, with the second it came.")
PanelHead(page, OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot"), "loot", "Loot list", nil, GAME.loot)
Subheader(page, "Look")
Check(page, "Background behind the list", OnUnlessOff("lootBackground"), Flip("lootBackground"), "off: the rows on the world itself")
Slider(page, "Lines shown", 3, 15, 1, function() return DB().lootLines or 8 end,
	function(value) DB().lootLines = math.floor(value + 0.5) end, "%d")
Note(page, "The same piece again in a run is one bar, x2. On its title, the run's marks: hover them for each boss's.")

------------------------------------------------------------------------------
-- Combat text.

page = pages.combat
Kit.Head(page, { line = "The numbers of the fight: SurvivorUI's, set here, the game's own, or none.", advanced = true })

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

-- A dab of color on a tile's picture: x and y from the picture's top left.
function Kit.Dab(tile, ground, x, y, width, height, r, g, b, a)
	local dab = tile:CreateTexture(nil, "ARTWORK")
	dab:SetTexture(FLAT)
	dab:SetVertexColor(r, g, b, a or 1)
	dab:SetWidth(width)
	dab:SetHeight(height)
	dab:SetPoint("CENTER", ground, "TOPLEFT", x, -y)
	return dab
end

-- The hero in the previews and pictures: its class's color.
function Paint.HeroColor()
	local _, class = UnitClass("player")
	if class and SurvivorUI_ClassColor then
		return SurvivorUI_ClassColor(class)
	end
	return 0.58, 0.51, 0.79
end

-- The preview: the hero and the numbers about it as SurvivorUI.lua lays them
-- (the hits dealt left of the hero, the crits right of it, the heals over it,
-- the damage taken under it; over the enemies, over three of them), in their
-- sizes, colors and icons. The sources: the meter's top three this run, else
-- three spells to show the look.
Paint.SAMPLE = {
	{ "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt" },
	{ "Corruption", "Interface\\Icons\\Spell_Shadow_AbominationExplosion" },
	{ "Holy Light", "Interface\\Icons\\Spell_Holy_HolyBolt" },
}
function Paint.Combat(self)
	self:Begin()
	local function CT(key)
		return SurvivorUI_CT and SurvivorUI_CT(key)
	end
	local mode = SurvivorUI_DamageMode and SurvivorUI_DamageMode() or "survivor"
	if mode == "none" then
		self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "No combat numbers"):SetPoint("CENTER", self, "CENTER", 0, 0)
		return
	end
	local middle = -math.floor(self:GetHeight() / 2) - 4
	local sides = mode == "survivor" and CT("ctLayout") ~= "enemies"
	local heroX = sides and math.floor(PAGE_WIDTH / 2) or 150
	-- The hero: a ball of its class's color, a soft glow round it.
	local r, g, b = Paint.HeroColor()
	local glow = self:Box(r, g, b, 0.5, ART.."PaceDot", "BORDER")
	glow:SetWidth(44)
	glow:SetHeight(44)
	glow:SetPoint("CENTER", self, "TOPLEFT", heroX, middle)
	local lr, lg, lb = Kit.Light({ r, g, b }, 0.35)
	local hero = self:Box(lr, lg, lb, 1, ART.."PaceDot")
	hero:SetWidth(24)
	hero:SetHeight(24)
	hero:SetPoint("CENTER", glow, "CENTER", 0, 0)
	local foes = {}
	if not sides then
		for index = 1, 3 do
			foes[index] = 270 + (index - 1) * 82
			local foe = self:Box(0.45, 0.16, 0.13, 1)
			foe:SetWidth(18)
			foe:SetHeight(18)
			foe:SetPoint("CENTER", self, "TOPLEFT", foes[index], middle - 6)
		end
	end
	if mode == "game" then
		-- The game's own: plain numbers over the enemies, in its font or the
		-- one chosen below (smaller faces draw smaller at the same size).
		local font = SurvivorUI_NumberFont and SurvivorUI_NumberFont() or "Fonts\\FRIZQT__.TTF"
		self:Word(font, 16, "OUTLINE", 1, 1, 1, "1234"):SetPoint("BOTTOM", self, "TOPLEFT", foes[1], middle + 6)
		self:Word(font, 16, "OUTLINE", 1, 1, 1, "348"):SetPoint("BOTTOM", self, "TOPLEFT", foes[2], middle + 14)
		self:Word(font, 24, "OUTLINE", 1, 1, 1, "12960"):SetPoint("BOTTOM", self, "TOPLEFT", foes[3], middle + 6)
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], "The game's own numbers"):SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8, 6)
		return
	end
	local size = CT("ctSize") or 0.85
	local critScale = CT("ctCritSize") or 1
	local names, icons = {}, {}
	for index = 1, 3 do
		local entry = AZS_METER and AZS_METER[index]
		names[index] = entry and entry.name or Paint.SAMPLE[index][1]
		icons[index] = entry and SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(entry.name) or Paint.SAMPLE[index][2]
	end
	-- The distance as the screen has it, near enough, kept in the strip.
	local distance = math.min(heroX - 50, math.floor((CT("ctDistance") or 140) * 0.75))
	local critApart = CT("ctCritColumn")
	-- Each: its kind, amount, source, periodic, crit, where, and shown or not.
	local hits = {
		{ "dealt", 1234, 1, nil, nil, sides and heroX - distance or foes[1], middle - 2, true },
		{ "dealt", 3480, 2, "periodic", nil, sides and heroX - distance or foes[2], sides and middle + 18 or middle + 6, CT("ctPeriodic") },
		{ "dealt", 12960, 1, nil, "crit", sides and (critApart and heroX + distance or heroX - distance) or foes[3],
			(sides and not critApart) and middle + 40 or middle - 2, true },
		{ "heal", 640, 3, nil, nil, heroX, middle + 28, CT("ctHeals") },
		{ "taken", 212, nil, nil, nil, heroX, middle - 30, CT("ctTaken") },
	}
	for index = 1, table.getn(hits) do
		local hit = hits[index]
		local kind, amount, source, periodic, crit, x, y = hit[1], hit[2], hit[3], hit[4], hit[5], hit[6], hit[7]
		if hit[8] then
			local text = CT("ctShort") and SurvivorUI_Abbrev and SurvivorUI_Abbrev(amount) or tostring(amount)
			if kind == "taken" then
				text = "-"..text
			elseif kind == "heal" then
				text = "+"..text
			end
			if periodic then
				text = text.." |cffc8c8c8x3|r"
			end
			local cr, cg, cb = 1, 1, 1
			if kind == "taken" then
				cr, cg, cb = 1, 0.22, 0.22
			elseif kind == "heal" then
				cr, cg, cb = 0.3, 1, 0.4
			elseif crit then
				cr, cg, cb = 1, 0.76, 0.08
			elseif periodic then
				cr, cg, cb = 0.8, 0.8, 0.8
			end
			if kind == "dealt" and CT("ctMeterColors") and SurvivorUI_MeterColor then
				local color = SurvivorUI_MeterColor(names[source]) or { 1, 1, 1 }
				cr, cg, cb = color[1], color[2], color[3]
			end
			local points = crit and 22 * critScale or ((periodic and 12 or 14) + FONT_BUMP)
			local word = self:Word(SurvivorUI_FONT, points * size, crit and "THICKOUTLINE" or "OUTLINE", cr, cg, cb, text)
			word:SetPoint(sides and "CENTER" or "BOTTOM", self, "TOPLEFT", x, sides and y or y + 10)
			if source and kind ~= "taken" and CT("ctIcons") then
				local edgeSize = math.floor((crit and 22 * critScale or 16) * size + 0.5)
				local icon = self:Box(1, 1, 1, 1, icons[source])
				icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				icon:SetWidth(edgeSize)
				icon:SetHeight(edgeSize)
				icon:SetPoint("RIGHT", word, "LEFT", -3, 0)
			end
		end
	end
end

Kit.Preview(page, 112, Paint.Combat)
Kit.Split(page)
Kit.Section(page, "Numbers")
Kit.Segments(page, { { "survivor", "SurvivorUI's" }, { "game", "The game's" }, { "none", "Off" } },
	function() return SurvivorUI_DamageMode and SurvivorUI_DamageMode() or "survivor" end,
	function(mode) if SurvivorUI_SetDamageMode then SurvivorUI_SetDamageMode(mode) end end)
Kit.Right(page)
Kit.Size(page, "Size", 0.5, 1.5, 0.05, CTGet("ctSize"), CTSet("ctSize"), { { "S", 0.7 }, { "M", 0.85 }, { "L", 1.1 } })
Kit.Join(page)

-- The game's own numbers' face and size (SurvivorUI.lua: DAMAGE_TEXT_FONT).
-- A face or a size picked: the game's numbers in place of ours.
local function NumberFontSet(key, value, plain)
	return function(choice)
		DB()[key] = choice ~= plain and choice or nil
		if SurvivorUI_ApplyNumberFont then
			SurvivorUI_ApplyNumberFont()
		end
		if SurvivorUI_DamageMode and SurvivorUI_DamageMode() ~= "game" and SurvivorUI_SetDamageMode then
			SurvivorUI_SetDamageMode("game")
		end
	end
end
Kit.Section(page, "The game's numbers", "The game's own numbers, always over the very enemy hit, in the face and size picked here; picking one turns ours off for them. "
	.."The game reads the face as it enters the world, so a change shows from your next run. Its own face comes at its own size only; "
	.."the other four carry Latin letters only.")
-- Their size a step at a time on the section's line, at its right (one row
-- less, for Advanced to fit above the foot).
do
	local y = page.y
	local size = Kit.Stepper(page, nil, 40, 100, 10,
		function() return DB().numberFont and tonumber(DB().numberFontSize) or 100 end, NumberFontSet("numberFontSize", nil, 100), "%d%%")
	size:ClearAllPoints()
	size:SetPoint("TOPRIGHT", page, "TOPLEFT", PAGE_WIDTH, y + 24)
	local label = Text(page, 9, MUTED)
	label:SetPoint("RIGHT", size, "LEFT", -8, 0)
	label:SetText("SIZE")
	side.Index(page, "Size of the game's numbers", "font size percent", y + 24, 24)
	page.y = y
end
Kit.Segments(page, { { "game", "The game's" }, { "barlow", "Barlow" }, { "exo", "Exo" }, { "fira", "Fira" }, { "noto", "Noto" } },
	function() return DB().numberFont or "game" end, NumberFontSet("numberFont", nil, "game"))

-- The two places, each a small picture: the hero, the damage's white, the
-- crits' gold, the heals' green, the damage taken's red; enemies dark red.
-- The hero's dot in the pictures, in the class's color as it is when the tab
-- shows: they are drawn as the page is made, before the run tells the hero's
-- class (UnitClass, SurvivorUI.lua).
Paint.heroDabs = {}
function Paint.Hero(dab)
	table.insert(Paint.heroDabs, dab)
	return dab
end
do
	local recolor = {}
	function recolor:Refresh()
		local r, g, b = Paint.HeroColor()
		for index = 1, table.getn(Paint.heroDabs) do
			Paint.heroDabs[index]:SetVertexColor(r, g, b, 1)
		end
	end
	table.insert(widgets, recolor)
end

function Paint.Sides(tile, ground)
	local r, g, b = Paint.HeroColor()
	Paint.Hero(Kit.Dab(tile, ground, 36, 22, 6, 6, r, g, b))
	Kit.Dab(tile, ground, 15, 20, 14, 3, 1, 1, 1)
	Kit.Dab(tile, ground, 13, 14, 10, 3, 1, 1, 1, 0.7)
	Kit.Dab(tile, ground, 57, 20, 14, 4, 1, 0.76, 0.08)
	Kit.Dab(tile, ground, 36, 10, 10, 3, 0.3, 1, 0.4)
	Kit.Dab(tile, ground, 36, 33, 10, 3, 1, 0.22, 0.22)
end
function Paint.Over(tile, ground)
	local r, g, b = Paint.HeroColor()
	Paint.Hero(Kit.Dab(tile, ground, 14, 24, 6, 6, r, g, b))
	for index = 1, 3 do
		local x = 32 + (index - 1) * 16
		local crit = index == 3
		Kit.Dab(tile, ground, x, 28, 8, 8, 0.45, 0.16, 0.13)
		Kit.Dab(tile, ground, x, 17 - math.mod(index, 2) * 4, 10, 3, 1, crit and 0.76 or 1, crit and 0.08 or 1)
	end
end
Kit.Section(page, "Where", "Drag a column while this tab is open, or click it for its card; moved, it stays put whatever the distance. Over the enemies: each number over the enemy it hit, kept where that enemy fell.")
Kit.Tiles(page, {
	{ "sides", "Beside the hero", "Damage left, crits right, heals over you", Paint.Sides },
	{ "enemies", "Over the enemies", "Each number over the enemy it hit", Paint.Over },
}, CTGet("ctLayout"), CTSet("ctLayout"))

Kit.Split(page)
Kit.Section(page, "Look")
Kit.Chips(page, {
	{ "Source icons", CTGet("ctIcons"), CTToggle("ctIcons"), "Each number with its spell's icon." },
	{ "Meter colors", CTGet("ctMeterColors"), CTToggle("ctMeterColors"), "Each spell's numbers in its damage meter color." },
	{ "Short numbers", CTGet("ctShort"), CTToggle("ctShort"), "1.2k for 1234, as the health reads." },
	{ "Crits apart", CTGet("ctCritColumn"), CTToggle("ctCritColumn"), "Beside the hero: the crits in a column of their own, on the right." },
})
Kit.Link(page, "The new best crit, in", "records")
Kit.Right(page)
Kit.Section(page, "Shows")
Kit.Chips(page, {
	{ "Damage over time", CTGet("ctPeriodic"), CTToggle("ctPeriodic"), "Your DoTs' ticks, a little smaller, in grey." },
	{ "Heals", CTGet("ctHeals"), CTToggle("ctHeals"), "The heals you get, green, over you." },
	{ "Damage taken", CTGet("ctTaken"), CTToggle("ctTaken"), "What hits you, red, under you." },
	{ "Far numbers fade", CTGet("ctFar"), CTToggle("ctFar"), "Over the enemies: hits on enemies more than 20 yards from you grow fainter, down to a third at 60. From the game's 0.139.2." },
	{ "Buff notices", function() return SurvivorUI_CombatTextAuras and SurvivorUI_CombatTextAuras() end,
		function() if SurvivorUI_SetCombatTextAuras then SurvivorUI_SetCombatTextAuras(not SurvivorUI_CombatTextAuras()) end end,
		"The game's own notices as a buff comes or goes, <Power Word: Shield>, and its debuffs. Off by default." },
})
Kit.Join(page)

do
	local box = Kit.Advanced(page, "crit size, adding up, distance, rise, smallest heal")
	Kit.Section(box, "Add up", "One source's hits that close together: one number, their sum and how many (1.2k x3).")
	Kit.Chips(box, {
		{ "Damage", CTGet("ctAddDealt"), CTToggle("ctAddDealt") },
		{ "Crits", CTGet("ctAddCrits"), CTToggle("ctAddCrits") },
		{ "Heals", CTGet("ctAddHeals"), CTToggle("ctAddHeals") },
		{ "Taken", CTGet("ctMergeTaken"), CTToggle("ctMergeTaken") },
	})
	-- Three to a row (Kit.Fine's two would take a row more than the page has).
	local FINE = {
		{ "Crit size", 0.6, 1.6, 0.05, CTGet("ctCritSize"), CTSet("ctCritSize") },
		{ "Add up within", 50, 500, 25, CTGet("ctAddWindow"), CTSet("ctAddWindow"), "%d ms" },
		{ "Distance from hero", 60, 320, 10, CTGet("ctDistance"), CTSet("ctDistance"), "%d" },
		{ "How high they rise", 80, 320, 10, CTGet("ctRise"), CTSet("ctRise"), "%d" },
		{ "Smallest heal", 0, 10, 1, CTGet("ctHealMin"), CTSet("ctHealMin"), "%d%% HP" },
	}
	local left, width = Span(box)
	local column = math.floor((width - 32) / 3)
	for index = 1, table.getn(FINE) do
		local item = FINE[index]
		local slot = math.mod(index - 1, 3)
		SizeSlider(box, left + slot * (column + 16), box.y, column, item[1], item[2], item[3], item[4], item[5],
			function(value)
				item[6](value)
				if box.preview then
					box.preview:Refresh()
				end
			end, item[7])
		if slot == 2 or index == table.getn(FINE) then
			box.y = box.y - 36
		end
	end
	Kit.EndAdvanced(page, box)
end
Kit.Foot(page, {
	reset = Asked("Combat text back to default?",
		"Every setting of this tab as it first was, and the columns and the new best crit back in their first places.", "Back to default",
		function() if SurvivorUI_CTDefaults then SurvivorUI_CTDefaults() end end),
	strong = { "Show a sample", function()
		if SurvivorUI_CTSample then
			SurvivorUI_CTSample()
		end
	end },
})

------------------------------------------------------------------------------
-- Damage meter (Meter.lua).

page = pages.meter
Header(page, "Damage meter", "Each source's damage and its share, its crits on hover; the buttons under its title for the DPS, the last 30 seconds, the healing and the bosses. Off: the game's meter.")
PanelHead(page, OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter"), "meter", "Damage meter", nil, GAME.meter)
-- Its height in lines (Meter.lua), the same as its card's in move mode: the
-- other windows follow unless set on their own cards.
Slider(page, "Height", 3, 20, 1,
	function()
		local _, lines = SurvivorUI_MeterMainSize()
		return lines
	end,
	function(value) SurvivorUI_SetMeterMainSize(nil, math.floor(value + 0.5)) end,
	function(value) return string.format("%d lines", value) end)
Note(page, "With more to show than lines, roll them with the mouse wheel or the bar at its right. Move mode sets each window's height and width on its own, and its Reset gives back the lines the screen fits.")
-- Others: the share under which the fold button in the meter's title folds
-- the lines into one (Meter.lua's Folded).
Subheader(page, "Others")
Slider(page, "Lines under", 1, 20, 1, function() return tonumber(DB().meterFoldUnder) or 10 end,
	function(value)
		value = math.floor(value + 0.5)
		DB().meterFoldUnder = value ~= 10 and value or nil
	end, "%d%%")
Note(page, "The button left of Reset in the meter's title folds the lines under this share of the total into one at the bottom, Others; hover it for each of them.")
Subheader(page, "What shows")
Check(page, "Damage a second right now", OnUnlessOff("meterNow"), Flip("meterNow"), "under the run's, over the last 5 seconds, as the game's meter has it")
Check(page, "Spell ranks after the names", OnlyIfOn("meterRanks"), function() DB().meterRanks = not DB().meterRanks or nil end,
	"Holy Shock  2, here and in the Run History's meter; in Roman numerals with Roman spell ranks on (Tooltips)")
-- The meter now (MeterNow.lua): a window of its own for how the hero is doing
-- now, the main one keeping the run's whole; what it counts is its title's.
Subheader(page, "Meter now")
Check(page, "Meter now window", OnlyIfOn("nowMeter"), Call("SurvivorUI_ToggleMeterNow"),
	"a second window, the main one's look, for how you are doing now; /sui meter now")
Inline(page, "It counts", { { "last", "Last 30 s" }, { "reset", "Since reset" }, { "boss", "This boss" } },
	function() return DB().nowMeterMode or "last" end,
	function(value) DB().nowMeterMode = value ~= "last" and value or nil end, 100)
Note(page, "Last 30 s: the last 30 seconds of the run's clock, as they go. Since reset: from its own Reset, the main meter's untouched. This boss: from a boss's coming to its fall, kept until the next one comes. Its title switches it too, and each line's card tells that stretch's crits and hits.")

------------------------------------------------------------------------------
-- This Run (RunPanel.lua).

page = pages.run
Header(page, "This Run", "The run's numbers, as the game's victory screen gives them: time, level, kills, elites, guardians and bosses slain, damage, gold and caches. Hover a row for more.")
PanelHead(page, OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun"), "run", "This Run")
Note(page, "Run History, each run as it ended, opens from the hourglass by the minimap: the Run History tab sets what it keeps.")

Subheader(page, "Jumps")
Check(page, "Jumps row", OnUnlessOff("runJumps"), Flip("runJumps"),
	"your jumps this run, a fun stat; hover it for your record in one run and all your jumps. Beating your record: the Records tab")

------------------------------------------------------------------------------
-- Records (Effects.lua): the new best crit (SurvivorUI.lua) and the new jump
-- record (Jumps.lua), each on or off and with an effect of its own.

page = pages.records
Header(page, "Records", "A moment of glory as a record falls: its number stands still a moment, over an effect if you pick one (No effect by default), each record with its own, and each class its own pick. Picking one shows it.")
local FX_CHOICES = {}
for index = 1, table.getn(SurvivorUI_RECORD_FX or {}) do
	table.insert(FX_CHOICES, { SurvivorUI_RECORD_FX[index][1], SurvivorUI_RECORD_FX[index][2] })
end
-- Each record's effect is picked for a class (Effects.lua): the class from a
-- list, each in its color, the hero's marked; the hero's until another is
-- picked.
local CLASSES = {
	{ "WARRIOR", "Warrior" }, { "PALADIN", "Paladin" }, { "HUNTER", "Hunter" },
	{ "ROGUE", "Rogue" }, { "PRIEST", "Priest" }, { "SHAMAN", "Shaman" },
	{ "MAGE", "Mage" }, { "WARLOCK", "Warlock" }, { "DRUID", "Druid" },
}
local function HeroClass()
	local _, class = UnitClass("player")
	return class
end
local function ClassItems()
	local list, hero = {}, HeroClass()
	for index = 1, table.getn(CLASSES) do
		local class = CLASSES[index]
		local r, g, b = 1, 0.82, 0
		if SurvivorUI_ClassColor then
			r, g, b = SurvivorUI_ClassColor(class[1])
		end
		table.insert(list, { value = class[1], name = class[2], color = { r, g, b },
			note = class[1] == hero and "your hero" or nil })
	end
	return list
end
local pickedClass = {}
local function PickedClass(which)
	return pickedClass[which] or HeroClass()
end
local function PickedFx(which)
	return SurvivorUI_RecordFxKind and SurvivorUI_RecordFxKind(which, PickedClass(which))
end

local function ShowCrit()
	if SurvivorUI_ShowCritRecord then
		SurvivorUI_ShowCritRecord(PickedFx("crit"))
	end
end
local function ShowJump()
	if SurvivorUI_ShowJumpRecord then
		SurvivorUI_ShowJumpRecord(PickedFx("jump"))
	end
end
-- A record's class, then its effect for that class; picking one shows it.
-- Eight, No effect the last (the default): in two rows of four.
local function FxRow(which, show)
	Dropdown(page, "Class", ClassItems, function() return PickedClass(which) end,
		function(class) pickedClass[which] = class end, 160)
	local get = function() return PickedFx(which) end
	local set = function(kind)
		if SurvivorUI_SetRecordFx then
			SurvivorUI_SetRecordFx(which, kind, PickedClass(which))
		end
		show()
	end
	local first, second = {}, {}
	for index = 1, table.getn(FX_CHOICES) do
		table.insert(index <= 4 and first or second, FX_CHOICES[index])
	end
	Inline(page, "Effect", first, get, set, 60)
	if table.getn(second) > 0 then
		Inline(page, "", second, get, set, 60)
	end
end

Subheader(page, "Crit record")
Check(page, "New best crit", CTGet("ctRecord"), CTToggle("ctRecord"),
	"a crit that beats the best stands still a moment, bigger, beside the Biggest Crits; off, it climbs with the rest")
Inline(page, "A best is", {
	{ "ability", "per ability" },
	{ "run", "the run's biggest" },
}, CTGet("ctRecordKind"), CTSet("ctRecordKind"))
FxRow("crit", ShowCrit)
Slider(page, "Stays", 1, 4, 0.1, CTGet("ctRecordHold"), CTSet("ctRecordHold"), "%.1f s")
Slider(page, "Size", 0.6, 1.6, 0.05, CTGet("ctRecordSize"), CTSet("ctRecordSize"))
Button(page, "Show it", 150, 0, ShowCrit)
page.y = page.y - 34

Subheader(page, "Jump record")
Check(page, "New jump record", OnUnlessOff("jumpRecord"), Flip("jumpRecord"),
	"at every 50 jumps in a run (50, 100, 150...) the first time ever, under the new best crit; your jumps are counted in This Run")
FxRow("jump", ShowJump)
Slider(page, "Stays", 1, 4, 0.1, function() return tonumber(DB().jumpRecordHold) or 3.2 end,
	function(value) DB().jumpRecordHold = math.floor(value * 10 + 0.5) / 10 end, "%.1f s")
Slider(page, "Size", 0.6, 1.6, 0.05, function() return tonumber(DB().jumpRecordSize) or 1 end,
	function(value) DB().jumpRecordSize = math.floor(value * 100 + 0.5) / 100 end)
Check(page, "Winged boot", OnUnlessOff("jumpRecordIcon"), Flip("jumpRecordIcon"),
	"left of the number, as the crit record wears its spell's icon")
Button(page, "Show it", 150, 0, ShowJump)
page.y = page.y - 34

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
Inline(page, "Victory & Endless", { { true, "Always kept" }, { false, "Go like the others" } },
	function() return DB().historyKeepWins ~= false end, Sets("historyKeepWins"))
Note(page, "Past the limit, the oldest run goes as a new one is kept: a Fallen or Left one first, a Victory or an Endless one only when no other can (when always kept; also at the Run History window's foot). The longest (when kept) and the pinned ones (Pin, in the window) never go. Changes here apply from the next run on, so nothing is deleted at a click.")

Subheader(page, "Tooltips")
Inline(page, "Keep them for", { { "all", "All" }, { "50", "Newest 50" }, { "25", "Newest 25" }, { "0", "None" } },
	function() return DB().historyPhotos or "25" end, Sets("historyPhotos"))
Note(page, "A run takes about 20 kB with its tooltips and 7 kB without, in the saved file the game reads at every login and reload. The pinned and the longest keep theirs. Taken off an older run, they do not come back.")

Subheader(page, "Time zone")
local clockLine
local function ShowClock()
	local hours = tonumber(DB().timeZone)
	local zone = SurvivorUI_TimeZone()
	local now = time() + (zone or 0)
	local clock = string.format("%02d:%02d", math.floor(math.mod(now, 86400) / 3600), math.floor(math.mod(now, 3600) / 60))
	if hours then
		clockLine:SetText(SurvivorUI_OTF("Your time now: {1} in this zone. The minimap's clock and the runs' dates take it.", "|cffffffff"..clock.."|r"))
	elseif zone then
		clockLine:SetText(SurvivorUI_OTF("Your computer's time: {1} now. The minimap's clock and the runs' dates take it. Untick it for another zone.", "|cffffffff"..clock.."|r"))
	else
		clockLine:SetText(SurvivorUI_OTF("Not set: the runs' dates are in UTC ({1} now), the game's own clock. Set yours: Brazil UTC-3, Portugal UTC+0 or +1.", "|cffffffff"..clock.."|r"))
	end
end
Check(page, "Your computer's time", function() return DB().timeZone == nil end, function()
	if DB().timeZone == nil then
		DB().timeZone = (SurvivorUI_TimeZone() or 0) / 3600
	else
		DB().timeZone = nil
	end
	ShowClock()
end, "untick it for the time zone under it")
local zoneRow = Slider(page, "Your time zone", -12, 14, 0.5,
	function() return (SurvivorUI_TimeZone() or 0) / 3600 end,
	function(value)
		DB().timeZone = value
		ShowClock()
	end,
	function(value) return SurvivorUI_ZoneLabel and SurvivorUI_ZoneLabel(value) or tostring(value) end)
function zoneRow.off()
	return DB().timeZone == nil and SurvivorUI_ComputerZone() ~= nil
end
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
	historyStats:SetText(SurvivorUI_OTF(count == 1 and "{1} run" or "{1} runs", "|cffffffff"..count.."|r")
		..dot..SurvivorUI_OTF("{1} won", "|cff73f280"..won.."|r")
		..dot..SurvivorUI_OTF("{1} pinned", "|cffffd100"..pinned.."|r")
		..dot..SurvivorUI_OTF("{1} with their tooltips", "|cffffffff"..photos.."|r")
		..dot..SurvivorUI_OTF("about {1}", "|cffffffff"..size.."|r"))
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
Header(page, "Biggest Crits", "Each ability's biggest critical strike this run; hover one for its card, its Reset clears them. A new best held still in the combat numbers is set in Records.")
PanelHead(page, OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits"), "crits", "Biggest Crits")
Check(page, "Damage and crits under the title", OnUnlessOff("critStats"), Flip("critStats"),
	"your Damage, Crit and Crit Dmg, as the Stats panel has them; hover them for what each is")

------------------------------------------------------------------------------
-- Counters: the numbers over the spells' buttons (DotCounter.lua).

page = pages.counters
Header(page, "Counters", "A number over a spell's button: how many of it are out right now (Battle Shout: the seconds it has left), in the spell's damage meter color. The game tells none of these outright: each is worked out from the combat log and your spells' cooldowns, so it can be off now and then.")
PanelHead(page, OnUnlessOff("counters"), Flip("counters"))
Subheader(page, "What is counted")
Check(page, "DoTs", OnUnlessOff("dotCounter"), Flip("dotCounter"), "how many of each are ticking on the enemies, by their ticks over the last two seconds; one on an enemy that dies stays up to two seconds")
Check(page, "Fears", OnUnlessOff("fearCounter"), Flip("fearCounter"), "how many enemies each one holds; the game writes a fear's hit but not its end, so each enemy hit counts for the fear's full time")
Check(page, "Totems", OnUnlessOff("totemCounter"), Flip("totemCounter"), "how many of each are down, out of the most that can stand at once, as the game tells them (its 0.124 on); with an older game each cast counts a totem for its tooltip's time, two with Call of the Elements, and Totemic Wrath's Searing Totem every 14 sec, told by the spells a run starts with, with the seconds until the next one ends beside it")
Check(page, "Shouts", OnUnlessOff("shoutCounter"), Flip("shoutCounter"), "Demoralizing Shout: how many enemies its last cast weakened, for its time; Battle Shout: the seconds it has left")
Check(page, "Marks", OnUnlessOff("markCounter"), Flip("markCounter"), "Faerie Fire: how many enemies carry it, bosses too; each one it hits counts for the mark's time (its tooltip's), so one hit again before it fades counts twice until it does")

Subheader(page, "Look")
Slider(page, "Size", 0.5, 2, 0.05, function() return tonumber(DB().counterSize) or 1 end,
	function(value) DB().counterSize = math.floor(value * 100 + 0.5) / 100 end)

------------------------------------------------------------------------------
-- Summons (Summons.lua): your summons over the player frame.

page = pages.summons
Header(page, "Summons", "Your summons over your frame, from the game's 0.110: a buff-sized icon for each kind out, how many against the game's limit in the corner and the longest time one has left in the middle. The Legion Gate's lesser demons are one icon; hover any icon for each one's time. From the game's 0.115 your talents' clocks too: a bar under a demon's icon filling to the next one (Butcher, Pact of the Nathrezim, Legion Gate), a dimmed icon counting down while none is out.")
PanelHead(page, FeatureOn("summons"), FeatureToggle("summons", true), nil, "Summons", nil, nil, { font = false })
Subheader(page, "What shows")
Check(page, "Track permanent pets", OnlyIfOn("summonsPermanent"),
	function() DB().summonsPermanent = DB().summonsPermanent ~= true end,
	"the ones that stay the whole run too: the Imp, your companion demon, a hunter's beast, Treants, Spirit Wolves, a Water Elemental. Off (the default), only the ones that come and go.")
Check(page, "Talent cooldowns", OnUnlessOff("summonsTimers"), Flip("summonsTimers"),
	"a talent's or a piece of jewelry's wait between two goes, from 5 sec long: a second life (Cheat Death, Reincarnation, Last Stand, Divine Intervention), a shield or a heal (Rapture, Swiftmend). An icon of its own, dimmed and counting while it waits, bright when ready. From the game's 0.115.")

------------------------------------------------------------------------------
-- Party (Party.lua): a co-op run's party frames and revive bar.

page = pages.party
Header(page, "Party", "For co-op runs, from the game's 0.113: a frame for each friend in your party, and a bar while you are down or bring a friend back. The damage meter's title opens a Party Damage page too, and Run History names the party of a run played in one. Out of a party nothing shows; while this tab is open, a sample does.")
PanelHead(page, FeatureOn("partyFrames"), FeatureToggle("partyFrames", true), "party", "Party frames", nil, nil, { font = false })
Note(page, "Left of your frame, the first friend level with it and each next one over it, or from the top down (Order, below). Each friend's class icon, their health in the class's color and what is left of it; DOWN in red while down, a gold fill while you bring them back, Reviving you on the one bringing you back. Hover one for their damage this run and their top spell; click to target. The game's party frames are put away while these are on.")

-- The preview: a full party of four left of your frame as Party.lua lays it
-- out until moved, in its order, each friend's buffs on the side chosen (over
-- or under, the rows that much further apart), the far one faded. Party.lua's
-- sizes, at 0.8. Each friend: name, class, health, its words, buffs, leader.
Paint.PARTY = {
	{ "Friend", "WARRIOR", 0.82, nil, 4, true },
	{ "Another", "MAGE", 0, "Reviving 45%", 1 },
	{ "Healer", "PRIEST", 0.46, nil, 3 },
	{ "Hunter", "HUNTER", 1, "far", 5 },
}
Paint.PARTY_BUFFS = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Ability_Warrior_BattleShout",
	"Spell_Holy_PowerWordShield", "Spell_Nature_Rejuvenation" }
function Paint.Party(self)
	self:Begin()
	if SurvivorUI_Feature and not SurvivorUI_Feature("partyFrames") then
		self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "Party frames off"):SetPoint("CENTER", self, "CENTER", 0, 0)
		return
	end
	local S = 0.8
	local ICON, BAR, HIGH, GAP, BUFF, BUFF_GAP = 24, 140, 24, 5, 16, 2
	local buffsOn = DB().partyBuffs ~= false
	local side = DB().partyBuffSide
	if side ~= "right" and side ~= "top" and side ~= "bottom" then
		side = "left"
	end
	local down = DB().partyDown == true
	local band = (buffsOn and (side == "top" or side == "bottom")) and (BUFF + BUFF_GAP) or 0
	local lead = ((down and side == "top") or (not down and side == "bottom")) and band or 0
	local cell = HIGH + band + GAP
	local room = 4 * (HIGH + band) + 3 * GAP
	-- Across: the buffs on the left, the rows, the room the right's take (a
	-- full line), the gap, your frame.
	local most = 0
	for index = 1, table.getn(Paint.PARTY) do
		most = math.max(most, Paint.PARTY[index][5])
	end
	local left = (buffsOn and side == "left") and (3 + most * (BUFF + BUFF_GAP) - BUFF_GAP) or 0
	local right = (buffsOn and side == "right") and (3 + 8 * (BUFF + BUFF_GAP) - BUFF_GAP) or 0
	local you = { 120, 36 }
	local across = left + ICON + 1 + BAR + right + 14 + you[1]
	local x0 = math.floor((PAGE_WIDTH - across * S) / 2 + left * S)
	local roomTop = -22 - math.floor((self:GetHeight() - 32 - room * S) / 2)
	local roomBottom = roomTop - room * S
	local font = 10 * S + FONT_BUMP
	local high, iconWide, barWide = math.floor(HIGH * S + 0.5), math.floor(ICON * S + 0.5), math.floor(BAR * S + 0.5)
	local size, step = math.floor(BUFF * S + 0.5), (BUFF + BUFF_GAP) * S
	-- A box with a black edge a layer under it.
	local function Edged(x, y, width, height, r, g, b, texture, layer)
		local edge = self:Box(0, 0, 0, 1, nil, "BORDER")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", x - 1, y + 1)
		edge:SetWidth(width + 2)
		edge:SetHeight(height + 2)
		local box = self:Box(r, g, b, 1, texture, layer)
		box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		box:SetWidth(width)
		box:SetHeight(height)
		return box
	end
	local rangeOn = DB().partyRange ~= false
	for index = 1, table.getn(Paint.PARTY) do
		local friend = Paint.PARTY[index]
		local top
		if down then
			top = roomTop - (lead + (index - 1) * cell) * S
		else
			top = roomBottom + (lead + (index - 1) * cell + HIGH) * S
		end
		top = math.floor(top + 0.5)
		local far = friend[4] == "far" and rangeOn
		local dim = far and 0.55 or 1
		local r, g, b = 0.6, 0.6, 0.6
		if SurvivorUI_ClassColor then
			r, g, b = SurvivorUI_ClassColor(friend[2])
		end
		local art, coords
		if SurvivorUI_ClassIcon then
			art, coords = SurvivorUI_ClassIcon(friend[2])
		end
		local icon = Edged(x0, top, iconWide, high, dim, dim, dim, art)
		if coords then
			local cutX, cutY = (coords[2] - coords[1]) * 0.1, (coords[4] - coords[3]) * 0.1
			icon:SetTexCoord(coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY)
		end
		if friend[6] then
			local crown = self:Box(1, 1, 1, 1, "Interface\\GroupFrame\\UI-Group-LeaderIcon", "OVERLAY")
			crown:SetPoint("TOPLEFT", self, "TOPLEFT", x0 - 4, top + 5)
			crown:SetWidth(11)
			crown:SetHeight(11)
		end
		local barX = x0 + iconWide + 1
		local value = friend[4] or (math.floor(friend[3] * 100 + 0.5).."%")
		if friend[3] <= 0 then
			-- Down, a friend bringing them back: the gold over the red.
			local back = Edged(barX, top, barWide, high, 0.30, 0.07, 0.07)
			local gold = self:Box(1, 0.76, 0.18, 0.85, nil, "OVERLAY")
			gold:SetPoint("TOPLEFT", back, "TOPLEFT", 0, 0)
			gold:SetWidth(math.floor(barWide * 0.45 + 0.5))
			gold:SetHeight(high)
		else
			local back = Edged(barX, top, barWide, high, 0.08 * dim, 0.08 * dim, 0.1 * dim)
			local fill = self:Box(r * dim, g * dim, b * dim, 1)
			fill:SetPoint("TOPLEFT", back, "TOPLEFT", 0, 0)
			fill:SetWidth(math.max(1, math.floor(barWide * friend[3] + 0.5)))
			fill:SetHeight(high)
		end
		if friend[4] == "far" then
			value = far and "34 yd | 100%" or "100%"
		end
		self:Word(SurvivorUI_FONT, font, "OUTLINE", dim, dim, dim, friend[1]):SetPoint("LEFT", self, "TOPLEFT", barX + 4, top - high / 2)
		self:Word(SurvivorUI_FONT, font, "OUTLINE", dim, dim, dim, value):SetPoint("RIGHT", self, "TOPLEFT", barX + barWide - 4, top - high / 2)
		if buffsOn then
			for slot = 1, friend[5] do
				local x, y
				if side == "right" then
					x, y = barX + barWide + 3 * S + (slot - 1) * step, top - (high - size) / 2
				elseif side == "top" then
					x, y = x0 + (slot - 1) * step, top + BUFF_GAP * S + size
				elseif side == "bottom" then
					x, y = x0 + (slot - 1) * step, top - high - BUFF_GAP * S
				else
					x, y = x0 - 3 * S - size - (slot - 1) * step, top - (high - size) / 2
				end
				local buff = Edged(math.floor(x + 0.5), math.floor(y + 0.5), size, size, dim, dim, dim,
					"Interface\\Icons\\"..Paint.PARTY_BUFFS[slot])
				buff:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			end
		end
	end
	-- Your frame, its bottom level with the party's room.
	local hr, hg, hb = Paint.HeroColor()
	local youX = x0 + math.floor((ICON + 1 + BAR + right + 14) * S + 0.5)
	local youWide, youHigh = math.floor(you[1] * S + 0.5), math.floor(you[2] * S + 0.5)
	local frame = Edged(youX, math.floor(roomBottom + youHigh + 0.5), youWide, youHigh, hr * 0.7, hg * 0.7, hb * 0.7)
	self:Word(SurvivorUI_FONT, font, "OUTLINE", 1, 1, 1, "Your frame"):SetPoint("CENTER", frame, "CENTER", 0, 0)
end
Kit.Preview(page, 184, Paint.Party)

Inline(page, "Order", {
	{ "up", "Bottom to top" },
	{ "down", "Top to bottom" },
}, function() return DB().partyDown and "down" or "up" end,
	function(value)
		DB().partyDown = value == "down" or nil
		if SurvivorUI_PlacePartyFrames then
			SurvivorUI_PlacePartyFrames()
		end
	end)
Note(page, "Bottom to top, each friend who joins goes over the last; top to bottom, under it, the first one where the fourth stands bottom to top. A full party takes the same place either way.")
Check(page, "Party buffs", OnUnlessOff("partyBuffs"), function()
	Flip("partyBuffs")()
	if SurvivorUI_PlacePartyFrames then
		SurvivorUI_PlacePartyFrames()
	end
end, "each friend's buffs in a line beside their frame; hover one for what it is")
Inline(page, "Buffs", {
	{ "left", "Left" },
	{ "right", "Right" },
	{ "top", "Top" },
	{ "bottom", "Bottom" },
}, function()
	local side = DB().partyBuffSide
	return (side == "right" or side == "top" or side == "bottom") and side or "left"
end, function(value)
	DB().partyBuffSide = value ~= "left" and value or nil
	if SurvivorUI_PlacePartyFrames then
		SurvivorUI_PlacePartyFrames()
	end
end)
Note(page, "Left: the far side from your frame. Right: until moved, the frames stand a line of buffs further left of yours, for them to fit. Top or bottom: a line over or under each friend, the frames that much further apart.")
Check(page, "Party distance", OnUnlessOff("partyRange"), Flip("partyRange"), "past 30 yards a friend's frame fades and says how far")
Subheader(page, "Revive bar")
Check(page, "Revive bar", ReviveIsOn, Call("SurvivorUI_ToggleRevive"),
	"while you are down: how far a friend has brought you back, and who; while you bring one back: how far. It puts the game's slim revive bar away (the game's 0.115 on; before it, the game's could not be put away, so ours was off unless chosen). Moved on its own: move mode, Revive bar.")

------------------------------------------------------------------------------
-- Build list (BuildList.lua).

-- Reworked (the kit): the preview draws the list as BuildList.lua does, its
-- rows, columns and Info symbols at its size and text size, each part of a
-- row as chosen: the run's build when in one (SurvivorUI_BuildRows), else a
-- sample with each of Info's symbols; the symbols' key beside it.

do
	local tab = pages.build
	Kit.Head(tab, { line = "Your spells with their icons and ranks, and the free slots. Off: the game's row of spells.",
		isOn = OnUnlessOff("buildList"), toggle = Call("SurvivorUI_ToggleBuild"), game = GAME.build, piece = "Build list", advanced = true })

	-- Grey words in the page's column (a split's half, an Advanced box), as
	-- many lines as they take.
	function Kit.BuildNote(page, text)
		local left, width = Span(page)
		local note = Text(page, 9, MUTED)
		note:SetPoint("TOPLEFT", page, "TOPLEFT", left, page.y)
		note:SetWidth(width)
		note:SetJustifyH("LEFT")
		note:SetText(text)
		page.y = page.y - 13 * Lines(note, width) - 6
		return note
	end

	-- A piece's text size (its card's A- and A+, EditCard.lua), a step at a
	-- time under its name.
	function Kit.BuildTextSize(page, name)
		Kit.Section(page, "Text size")
		Kit.Stepper(page, nil, -4, 8, 1,
			function() return SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep(name) or 0 end,
			function(value) if SurvivorUI_SetPieceTextStep then SurvivorUI_SetPieceTextStep(name, value) end end,
			function(value) return value == 0 and "normal" or ((value > 0 and "+" or "")..value) end)
	end

	-- What each row shows as BuildList.lua reads it: Info, the cooldown,
	-- Info's symbol, the rank (buildShows: the first builds' one choice).
	function Paint.BuildShows()
		if SurvivorUI_BuildShows then
			return SurvivorUI_BuildShows()
		end
		local db = DB()
		return db.buildRange ~= false and db.buildShows ~= "cooldown", db.buildCooldown == true or db.buildShows == "cooldown",
			db.buildSymbols ~= false, db.buildRank ~= false
	end

	-- Whether Info shows a kind (by its symbol's Art file), and its switch:
	-- the kinds left out kept in buildInfoOff, none at first.
	function Paint.BuildKind(kind)
		local off = DB().buildInfoOff
		return not (off and off[kind])
	end

	function Paint.BuildFlip(kind)
		local db = DB()
		db.buildInfoOff = db.buildInfoOff or {}
		db.buildInfoOff[kind] = not db.buildInfoOff[kind] or nil
		if not next(db.buildInfoOff) then
			db.buildInfoOff = nil
		end
	end

	-- A kind's chip, faded while Info is off.
	function Paint.BuildKindChip(name, kind, help)
		return { name, function() return Paint.BuildKind(kind) end, function() Paint.BuildFlip(kind) end, help,
			usable = function() local on = Paint.BuildShows() return on end, why = "Info is off." }
	end

	-- A spell's rank as the list shows it: 24, or XXIV with the Roman ranks on.
	function Paint.BuildRank(rank)
		rank = tonumber(rank)
		if not rank then
			return ""
		end
		return SurvivorUI_RankText and SurvivorUI_RankText(rank, true) or tostring(rank)
	end

	-- The list's colors (BuildList.lua): its ground, a spell's dark base, the
	-- words over a spell's color and beside the rest, the timer's edge, the
	-- title, the count, the columns' names, an empty slot's icon; the key's
	-- words while what they stand for is off.
	Paint.BUILD_INK = {
		ground = { 0.04, 0.04, 0.07 }, base = { 0.05, 0.05, 0.07 }, white = { 1, 1, 1 }, soft = { 0.9, 0.9, 0.9 },
		dim = { 0.6, 0.6, 0.6 }, tick = { 1, 0.94, 0.78 }, gold = { 1, 0.82, 0 }, count = { 0.82, 0.82, 0.82 },
		full = { 1, 0.5, 0.5 }, head = { 0.62, 0.62, 0.66 }, icon = { 0.15, 0.15, 0.18 }, off = { 0.38, 0.38, 0.42 },
	}

	-- A sample build, one of each of Info's symbols: a range, an area, a buff
	-- (up 8 seconds of every 12: its row a timer), a heal, an absorb; then a
	-- free slot and the racial. { name, icon, rank, color, symbol, number, cd
	-- (its seconds, written as the list writes them in the game's language),
	-- its range, shown with its own kind left out (none: nothing) }.
	Paint.BUILD_SAMPLE = {
		{ "Fireball", "Spell_Fire_FlameBolt", 24, { 0.93, 0.70, 0.15 }, "Range", "30", 2.5 },
		{ "Frost Nova", "Spell_Frost_FrostNova", 18, { 0.25, 0.45, 0.95 }, "Area", "10", 8, "10" },
		{ "Divine Shield", "Spell_Holy_DivineIntervention", 12, { 0.85, 0.20, 0.25 }, "Hourglass", 8, 30 },
		{ "Holy Light", "Spell_Holy_HolyBolt", 9, { 0.30, 0.75, 0.30 }, "HealCross", "48%", 6 },
		{ "Power Word: Shield", "Spell_Holy_PowerWordShield", 6, { 0.65, 0.35, 0.90 }, "Shield", "25%", 12 },
	}

	-- A cooldown of so many seconds as the list writes it: "8.0s", "8.0 Sek.".
	function Paint.BuildCooldown(seconds)
		return SurvivorUI_CooldownText and SurvivorUI_CooldownText(seconds) or ""
	end

	-- The sample's rows, as SurvivorUI_BuildRows gives the run's: a kind left
	-- out, the spell's range instead (BuildList.lua's InfoOf).
	function Paint.BuildSample(showRange, showCooldown)
		local look, rows = SurvivorUI_BUILD_LOOK, {}
		for index = 1, table.getn(Paint.BUILD_SAMPLE) do
			local each = Paint.BUILD_SAMPLE[index]
			local row = { name = SurvivorUI_Native(each[1]), icon = "Interface\\Icons\\"..each[2], rank = each[3],
				color = each[4], cd = showCooldown and Paint.BuildCooldown(each[7]) or "" }
			local kind, number = each[5], each[6]
			if not Paint.BuildKind(kind) then
				kind, number = each[8] and "Range", each[8] or ""
			end
			if kind == "Range" and not Paint.BuildKind("Range") then
				kind, number = nil, ""
			end
			row.number = number
			if kind == "Hourglass" then
				local left = number - math.mod(GetTime(), 12)
				row.number = tostring(number)
				if left > 0 then
					row.share = left / number
					row.number, row.numberColor = string.format("%.1f", left), Paint.BUILD_INK.white
				end
			end
			if not showRange then
				row.number = ""
			elseif kind then
				row.symbol, row.tint = kind, look.tints[kind]
				row.numberColor = row.numberColor or look.numbers[kind]
			end
			table.insert(rows, row)
		end
		table.insert(rows, { empty = true, name = SurvivorUI_T("empty slot") })
		-- The racial as the game lists it: rank 1, its cooldown (Shadowmeld's 105).
		local racial, tag = SurvivorUI_Native("Shadowmeld"), SurvivorUI_T("(racial)")
		table.insert(rows, { racial = true, name = racial.."  |cff8a8a8a"..tag.."|r", spell = racial, tag = tag,
			icon = "Interface\\Icons\\Ability_Ambush", rank = 1, color = { 0.15, 0.70, 0.70 }, cd = showCooldown and Paint.BuildCooldown(105) or "" })
		return rows
	end

	-- The preview's pen: the list's own measures (x across, y down from its
	-- top left) put on the preview at the size drawn (zoom), the words at the
	-- piece's text size (bump).
	local canvas, ox, oy, zoom, bump

	local function Put(x, y, width, height, color, a, texture, layer)
		local box = canvas:Box(color[1], color[2], color[3], a, texture, layer)
		box:SetPoint("TOPLEFT", canvas, "TOPLEFT", ox + x * zoom, oy - y * zoom)
		box:SetWidth(math.max(1, width * zoom))
		box:SetHeight(math.max(1, height * zoom))
		return box
	end

	-- A word on one line, cut at its width as the list's names are: pooled,
	-- so each is given its width, height and justification again.
	local function Say(size, color, text, width, justify)
		local word = canvas:Word(SurvivorUI_FONT, size, "OUTLINE", color[1], color[2], color[3], text)
		word:SetWidth(width)
		word:SetHeight(math.max(6, math.floor(size + 0.5)) + 4)
		word:SetJustifyH(justify or "LEFT")
		return word
	end

	-- A row's word centered in its column, level with the row's middle (y).
	local function InColumn(size, color, text, column, y)
		Say((size + bump) * zoom, color, text, column.width * zoom, "CENTER"):SetPoint("RIGHT", canvas, "TOPLEFT",
			ox + (6 + SurvivorUI_BUILD_LOOK.width - column.right) * zoom, y)
	end

	-- Words' width as the preview draws them at a size of the list's (points,
	-- the text size in), in the list's measures: on a word of the pool.
	function Paint.BuildMeasure(probe, points, words)
		probe:SetFont(SurvivorUI_FONT, math.max(6, math.floor((points + bump) * zoom + 0.5)), "OUTLINE")
		probe:SetText(words)
		return (probe:GetStringWidth() or 0) / zoom
	end

	-- A row's name fit to its room as the list fits its own (BuildList.lua's
	-- FitSpell, SurvivorUI_FitBuildName), measured as drawn here: a point
	-- smaller, never under 7; the racial's "(racial)" left out; else cut,
	-- "...". Its size (9 or 8) and words, kept while the room, the text size,
	-- the size drawn and the face stay.
	function Paint.BuildName(row, room)
		local name, tag = row.spell or row.name or "", row.tag
		if not SurvivorUI_FitBuildName then
			return 9, row.name or ""
		end
		local fits = Paint.buildFits
		local key = room.."|"..bump.."|"..zoom.."|"..tostring(SurvivorUI_FONT)
		if not (fits and fits.key == key) then
			fits = { key = key }
			Paint.buildFits = fits
		end
		local fit = fits[name.."|"..(tag or "")]
		if not fit then
			local probe
			local points, words = SurvivorUI_FitBuildName(name, tag, room, bump - FONT_BUMP, function(size, text)
				probe = probe or Say(9, Paint.BUILD_INK.white, "", 400)
				return Paint.BuildMeasure(probe, size, text)
			end)
			if probe then
				probe:Hide()
			end
			fit = { points or 9, words }
			-- Not drawn yet, it measured nothing: again next time.
			if points then
				fits[name.."|"..(tag or "")] = fit
			end
		end
		return fit[1], fit[2]
	end

	-- The cooldowns fit to their column as the list's (FitCooldown,
	-- SurvivorUI_FitCooldowns), measured as drawn here: all at one size, a
	-- point smaller or without the space where the language's word needs it
	-- ("8.6Sek."); English as written. Each row's cdSize and cdShown.
	function Paint.BuildCooldowns(rows, column)
		local texts = {}
		for index = 1, table.getn(rows) do
			texts[index] = rows[index].cd or ""
		end
		local size, shown, probe = 8, texts
		if column and SurvivorUI_FitCooldowns then
			size, shown = SurvivorUI_FitCooldowns(texts, column.width, function(points, text)
				probe = probe or Say(8, Paint.BUILD_INK.white, "", 400)
				return Paint.BuildMeasure(probe, points, text)
			end)
			if probe then
				probe:Hide()
			end
		end
		for index = 1, table.getn(rows) do
			rows[index].cdSize, rows[index].cdShown = size, shown[index]
		end
	end

	-- One row as BuildList.lua's Fill, Empty and Draw paint it (top: its top
	-- in the list): a spell filled with its color over a dark base in a border
	-- of it, the words light; an empty slot or the racial a faint wash, the
	-- words in the color; a lasting spell up, its row a timer.
	local function Row(row, top, columns, nameRoom)
		local look, ink = SurvivorUI_BUILD_LOOK, Paint.BUILD_INK
		local W, R = look.width, look.row
		local filled = not (row.empty or row.racial)
		local color = row.empty and look.muted or row.color or ink.soft
		local alpha = row.empty and 0.6 or (row.racial and 0.5 or 1)
		local mid = oy - (top + R / 2) * zoom
		if filled then
			Put(6, top + 1, W, R - 2, ink.base, 0.92, nil, "BORDER")
		end
		local lit = row.share and math.max(1, W * row.share) or W
		Put(6, top + 1, lit, R - 2, color, filled and 0.45 or 0.07 * alpha, nil, "ARTWORK")
		if row.share then
			if lit < W then
				Put(6 + lit, top + 1, W - lit, R - 2, color, 0.12, nil, "ARTWORK")
			end
			Put(6 + lit - 0.5, top + 1, 1, R - 2, ink.tick, 0.9, nil, "OVERLAY")
		end
		Put(6, top + R - 1, W, 1, color, 0.28 * alpha, nil, "ARTWORK")
		if filled then
			Put(6, top, W, 1, color, 0.6, nil, "OVERLAY")
			Put(6, top + R - 1, W, 1, color, 0.6, nil, "OVERLAY")
			Put(6, top, 1, R, color, 0.6, nil, "OVERLAY")
			Put(6 + W - 1, top, 1, R, color, 0.6, nil, "OVERLAY")
		end
		if row.empty then
			Put(8, top + 2, R - 4, R - 4, ink.icon, 0.8, nil, "OVERLAY")
		elseif row.icon then
			Put(8, top + 2, R - 4, R - 4, ink.white, 1, row.icon, "OVERLAY"):SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local words = filled and ink.white or color
		local points, name = Paint.BuildName(row, nameRoom)
		Say((points + bump) * zoom, words, name, nameRoom * zoom, "LEFT"):SetPoint("LEFT", canvas, "TOPLEFT", ox + (6 + R + 2) * zoom, mid)
		if columns.rank then
			InColumn(10, words, Paint.BuildRank(row.rank), columns.rank, mid)
		end
		if columns.cd then
			InColumn(row.cdSize or 8, filled and ink.soft or ink.dim, row.cdShown or row.cd or "", columns.cd, mid)
		end
		if columns.range then
			InColumn(8, row.numberColor or (filled and ink.soft or ink.dim), row.number or "", columns.range, mid)
			if row.symbol and columns.symbol then
				local tint = row.tint or ink.soft
				local glass = canvas:Box(tint[1], tint[2], tint[3], 1, ART..row.symbol, "OVERLAY")
				glass:SetWidth(9 * zoom)
				glass:SetHeight(9 * zoom)
				glass:SetPoint("RIGHT", canvas, "TOPLEFT", ox + (6 + W - columns.symbol.right - 1) * zoom, mid)
			end
		end
	end

	-- The rank column as BuildList.lua sizes it: a number's width, or as wide
	-- as the longest Roman numeral needs (measured at the list's size, the
	-- piece's text size in).
	function Paint.BuildRankRoom(rows)
		local room = SurvivorUI_BUILD_LOOK.rankWidth or 24
		if not DB().romanRanks then
			return room
		end
		for index = 1, table.getn(rows) do
			local text = Paint.BuildRank(rows[index].rank)
			if text ~= "" then
				local probe = Say(10 + bump, Paint.BUILD_INK.white, text, 400)
				room = math.max(room, math.ceil(probe:GetStringWidth() or 0) + 4)
				probe:Hide()
			end
		end
		return room
	end

	-- The key beside the list: each of Info's symbols and what its number is,
	-- then the cooldown's column and the rank's; dim while off.
	Paint.BUILD_KEY = {
		{ "Range", "A range, or a cone's length" },
		{ "Area", "An area's radius" },
		{ "Hourglass", "A buff's length; up, a timer" },
		{ "HealCross", "How much a heal gives back" },
		{ "Shield", "How much an absorb holds" },
	}
	Paint.BUILD_ROOM, Paint.BUILD_KEY_WIDTH = 300, 176

	function Paint.BuildKey(self, showRange, showCooldown, showSymbol, showRank)
		local look, ink = SurvivorUI_BUILD_LOOK, Paint.BUILD_INK
		local x = PAGE_WIDTH - 12 - Paint.BUILD_KEY_WIDTH
		local y = -math.floor((self:GetHeight() - 150) / 2)
		Say(8 + FONT_BUMP, MUTED, "INFO", 100):SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		y = y - 16
		for index = 1, table.getn(Paint.BUILD_KEY) do
			local each = Paint.BUILD_KEY[index]
			local on = showRange and Paint.BuildKind(each[1])
			local tint = look.tints[each[1]]
			local mark = self:Box(tint[1], tint[2], tint[3], (on and showSymbol) and 1 or 0.3, ART..each[1], "OVERLAY")
			mark:SetWidth(11)
			mark:SetHeight(11)
			mark:SetPoint("LEFT", self, "TOPLEFT", x, y - 7)
			Say(9 + FONT_BUMP, on and TEXT or ink.off, each[2], Paint.BUILD_KEY_WIDTH - 18):SetPoint("LEFT", self, "TOPLEFT", x + 18, y - 7)
			y = y - 18
		end
		y = y - 8
		Say(8 + FONT_BUMP, showCooldown and ink.head or ink.off, "CD", 18):SetPoint("LEFT", self, "TOPLEFT", x - 2, y - 7)
		Say(9 + FONT_BUMP, showCooldown and TEXT or ink.off, "Its cooldown, haste in", Paint.BUILD_KEY_WIDTH - 18):SetPoint("LEFT", self, "TOPLEFT", x + 18, y - 7)
		y = y - 18
		Say(9 + FONT_BUMP, showRank and TEXT or ink.off, Paint.BuildRank(9), 20, "CENTER"):SetPoint("LEFT", self, "TOPLEFT", x - 5, y - 7)
		Say(9 + FONT_BUMP, showRank and TEXT or ink.off, DB().romanRanks and "Its rank, in Roman numerals" or "Its rank",
			Paint.BUILD_KEY_WIDTH - 18):SetPoint("LEFT", self, "TOPLEFT", x + 18, y - 7)
	end

	function Paint.Build(self)
		self:Begin()
		canvas, zoom, bump = self, 1, FONT_BUMP
		local look, ink = SurvivorUI_BUILD_LOOK, Paint.BUILD_INK
		if not (look and SurvivorUI_BuildLayout) or DB().buildList == false then
			Say(11 + FONT_BUMP, MUTED, look and "Build list off: the game's row of spells" or "No build list", PAGE_WIDTH, "CENTER"):SetPoint("CENTER", self, "CENTER", 0, 0)
			return
		end
		local showRange, showCooldown, showSymbol, showRank = Paint.BuildShows()
		local rows = SurvivorUI_BuildRows and SurvivorUI_BuildRows()
		Say(9 + FONT_BUMP, MUTED, rows and "Your build" or "A sample build", 200, "RIGHT"):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		rows = rows or Paint.BuildSample(showRange, showCooldown)
		local W, R, T, H, slots = look.width, look.row, look.title, look.head, look.slots
		local tall = T + H + (slots + 1) * R + 6
		local height = self:GetHeight()
		-- At its size as far as the preview has room, the key beside it.
		zoom = math.min(SurvivorUI_GetScale and SurvivorUI_GetScale("build") or 1, (height - 28) / tall, Paint.BUILD_ROOM / (W + 12))
		bump = FONT_BUMP + (SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Build list") or 0)
		local columns, nameRoom = SurvivorUI_BuildLayout(showRange, showCooldown, showSymbol, showRank, Paint.BuildRankRoom(rows))
		ox = 12 + math.floor((Paint.BUILD_ROOM - (W + 12) * zoom) / 2)
		oy = -math.max(20, math.floor((height - tall * zoom) / 2 + 4))
		Put(0, 0, W + 12, tall, ink.ground, 0.55, nil, "BACKGROUND")
		-- Its title, and how many of the slots are taken.
		local taken = 0
		for index = 1, table.getn(rows) do
			if not (rows[index].empty or rows[index].racial) then
				taken = taken + 1
			end
		end
		Say((11 + bump) * zoom, ink.gold, SurvivorUI_T("Build"), 120 * zoom):SetPoint("TOPLEFT", self, "TOPLEFT", ox + 7 * zoom, oy - 4 * zoom)
		Say((10 + bump) * zoom, taken >= slots and ink.full or ink.count, math.min(taken, slots).." / "..slots, 60 * zoom, "RIGHT"):SetPoint("TOPRIGHT", self, "TOPLEFT", ox + (W + 5) * zoom, oy - 5 * zoom)
		-- The columns' names (Info's over its symbols and its numbers), and
		-- the lines between the columns.
		local info = columns.range
		if info and columns.symbol then
			info = { right = info.right, width = columns.symbol.right + columns.symbol.width - info.right }
		end
		local heads = { { "Info", info }, { "CD", columns.cd }, { "Rank", columns.rank } }
		for index = 1, 3 do
			local column = heads[index][2]
			if column then
				Say((8 + bump) * zoom, ink.head, SurvivorUI_T(heads[index][1]), (column.width + 24) * zoom, "CENTER"):SetPoint("CENTER", self, "TOPLEFT", ox + (6 + W - column.right - column.width / 2) * zoom, oy - (T + H / 2) * zoom)
			end
		end
		for _, key in pairs({ "rank", "cd", "range", "symbol" }) do
			local column = columns[key]
			if column then
				local under = (key == "range" and columns.symbol) and H or 0
				Put(6 + W - column.divider, T + 1 + under, 1, H + (slots + 1) * R - 1 - under, ink.white, 0.14, nil, "OVERLAY")
			end
		end
		Paint.BuildCooldowns(rows, columns.cd)
		for index = 1, table.getn(rows) do
			Row(rows[index], T + H + (index - 1) * R, columns, nameRoom)
		end
		Paint.BuildKey(self, showRange, showCooldown, showSymbol, showRank)
	end

	-- Drawn again as the build changes and a lasting spell's timer runs.
	local preview = Kit.Preview(tab, 240, Paint.Build)
	preview.wait = 0
	preview:SetScript("OnUpdate", function()
		this.wait = this.wait + arg1
		if this.wait >= 0.25 then
			this.wait = 0
			this:Refresh()
		end
	end)

	-- Each part of the row on or off; the ranks' one choice beside them.
	Kit.Split(tab)
	Kit.Section(tab, "Beside each spell", "Each part of a spell's row on or off, each a column at its right: Info (what matters most besides the cooldown, by its symbol), the cooldown, the rank. What is off leaves the name more room. The list runs from the highest rank down either way.")
	Kit.Chips(tab, {
		{ "Info", function() local on = Paint.BuildShows() return on end, function()
			DB().buildShows = nil
			DB().buildRange = DB().buildRange == false
		end, "A range, an area's radius, a buff's length, a heal or an absorb, as its symbol says: the key in the preview. Which of them: Info shows, below." },
		{ "Info's symbol", function() local _, _, on = Paint.BuildShows() return on end, function()
			DB().buildSymbols = DB().buildSymbols == false
		end, "The small symbol at the left of Info's number, what kind of number it is: the key in the preview. Off: the number alone.",
			usable = function() local on = Paint.BuildShows() return on end, why = "Info is off." },
		{ "Cooldown", function() local _, on = Paint.BuildShows() return on end, function()
			DB().buildShows = nil
			DB().buildCooldown = not DB().buildCooldown
		end, "The cooldown as the game has it now, haste in: 3.1s, 12s." },
		{ "Rank", function() local _, _, _, on = Paint.BuildShows() return on end, function()
			DB().buildRank = DB().buildRank == false
		end, "The spell's rank at the row's right: 24, or XXIV with the Roman ranks." },
	})
	Kit.Right(tab)
	Kit.Section(tab, "Ranks", "Rank 63 or LXIII: one choice for the whole interface, the same as Spell ranks in Tooltips. The build list's ranks, the spells' tooltips and the Biggest Crits' cards, and the ranks after the spells' names in the damage meter, the run's and the Run History's, all follow it.")
	Kit.Segments(tab, { { "rank", "Rank 63" }, { "roman", "LXIII" } }, function() return DB().romanRanks and "roman" or "rank" end,
		function(value) DB().romanRanks = value == "roman" or nil end,
		function() local _, _, _, on = Paint.BuildShows() return on end)
	Kit.Link(tab, "The same choice as in", "tooltips")
	Kit.Join(tab)

	Kit.Section(tab, "Info shows", "Which kinds of number Info shows, each by its symbol. A measuring arrow: the range read off the spell's own tooltip, or a cone's length. A ring: an area's radius, what its Area upgrades widen: around you (Frost Nova, Thunder Clap), where a spell lands (Flamestrike, Blizzard), a totem's (its own, not where it is dropped from), a burst's. An hourglass: how long a buff on you lasts (Divine Shield, Holy Shield, Battle Shout, Slice and Dice, Adrenaline Rush, Lightning Shield, Thorns, your demons' Demonic Empowerment), the row a timer while it is up. A cross: how much Holy Light, Renew, Healing Wave, Rejuvenation and Regrowth heal. A shield: how much Power Word: Shield and Ice Barrier hold back. A kind off: such a spell shows its range instead, when it has one.")
	Kit.Chips(tab, {
		Paint.BuildKindChip("Range or cone", "Range", "The range read off the spell's own tooltip, or a cone's length, by a measuring arrow. Off: nothing for those spells; the kinds after it still show."),
		Paint.BuildKindChip("Area", "Area", "An area's radius by a ring: around you, where a spell lands, a totem's, a burst's. Off: its range instead, when it has one."),
		Paint.BuildKindChip("Buff's length", "Hourglass", "How long a buff on you lasts by an hourglass, its row a timer while it is up. Off: its range instead, when it has one, and no timer."),
		Paint.BuildKindChip("Heal", "HealCross", "How much a heal gives back by a cross: Holy Light, Renew, Healing Wave, Rejuvenation, Regrowth. Off: its range instead, when it has one."),
		Paint.BuildKindChip("Absorb", "Shield", "How much an absorb holds back by a shield: Power Word: Shield, Ice Barrier. Off: its range instead, when it has one."),
	})

	Kit.Split(tab)
	Kit.Size(tab, "Size", 0.5, 2, 0.05,
		function() return SurvivorUI_GetScale and SurvivorUI_GetScale("build") or 1 end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("build", value) end end,
		{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Right(tab)
	Kit.BuildTextSize(tab, "Build list")
	Kit.Join(tab)

	local box = Kit.Advanced(tab, "the game's row of spells too")
	Kit.Chips(box, {
		{ "Keep the game's row of spells too", OnlyIfOn("gameBuildToo"), function()
			DB().gameBuildToo = DB().gameBuildToo ~= true
			if SurvivorUI_GameHud and SurvivorUI_GameHud.build then
				SurvivorUI_GameHud.build()
			end
		end, "The game's own row stays under the list. No longer needed: from the game's 0.115 the Summons count down to the next Felguard or Dread Lord (Butcher, Pact of the Nathrezim) as well." },
	})
	Kit.EndAdvanced(tab, box)

	Kit.Foot(tab, { reset = Asked("Build list back to default?",
		"Info with its symbol and every kind, the rank, the cooldown off, the first size and text size. The game's row, where the list stands and Rank 63 or LXIII (one choice with Tooltips) stay: Back to its place for where it stands.", "Back to default",
		function()
			DB().buildShows, DB().buildRange, DB().buildCooldown = nil, nil, nil
			DB().buildSymbols, DB().buildRank, DB().buildInfoOff = nil, nil, nil
			if SurvivorUI_SetPartScale then
				SurvivorUI_SetPartScale("build", 1)
			end
			if SurvivorUI_SetPieceTextStep then
				SurvivorUI_SetPieceTextStep("Build list", 0)
			end
		end) })
end

------------------------------------------------------------------------------
-- Jewelry worn (BuildList.lua).

-- Reworked (the kit): the preview draws the panel as BuildList.lua's
-- DrawGear does, at its size and text size, by the settings: what you wear
-- in a run, else a sample (SurvivorUI_WornRows), the rarities' key beside
-- it; each look a small picture of the panel's rows, in their pieces'
-- quality colors.

do
	local tab = pages.worn
	Kit.Head(tab, { line = "The neck, the rings and the trinkets you wear this run, a panel of its own, under the build list until you move it.",
		isOn = OnUnlessOff("jewelryWorn"), toggle = Call("SurvivorUI_ToggleWorn"), piece = "Jewelry worn" })

	-- A bar of color on a picture, x and y from its top left, in a layer: the
	-- rows a layer under their words.
	local function Dab(tile, ground, layer, x, y, width, height, color, a)
		local dab = tile:CreateTexture(nil, layer)
		dab:SetTexture(FLAT)
		dab:SetVertexColor(color[1], color[2], color[3], a)
		dab:SetWidth(width)
		dab:SetHeight(height)
		dab:SetPoint("TOPLEFT", ground, "TOPLEFT", x, -y)
		return dab
	end

	-- The panel's rows as BuildList.lua's DrawGear paints them: an epic, a
	-- rare, an empty slot; the slot and rank at the left and what the piece
	-- gives at the right, or its name alone.
	Paint.WORN_ROWS = { { 0.64, 0.21, 0.93 }, { 0, 0.44, 0.87 } }
	local function Rows(tile, ground, named)
		local white, grey = { 1, 1, 1 }, { 0.5, 0.5, 0.55 }
		for index = 1, 3 do
			local y = 4 + (index - 1) * 12
			local quality = Paint.WORN_ROWS[index]
			if quality then
				Dab(tile, ground, "ARTWORK", 4, y, 64, 10, quality, 0.5)
				if named then
					Dab(tile, ground, "OVERLAY", 7, y + 4, index == 1 and 44 or 36, 2, white, 0.95)
				else
					Dab(tile, ground, "OVERLAY", 7, y + 4, 16, 2, white, 0.95)
					Dab(tile, ground, "OVERLAY", 42, y + 4, 9, 2, white, 0.95)
					Dab(tile, ground, "OVERLAY", 54, y + 4, 11, 2, white, 0.95)
				end
			else
				Dab(tile, ground, "ARTWORK", 4, y, 64, 10, grey, 0.12)
				Dab(tile, ground, "OVERLAY", 7, y + 4, 14, 2, grey, 0.9)
				Dab(tile, ground, "OVERLAY", 53, y + 4, 12, 2, grey, 0.7)
			end
		end
	end
	function Paint.WornStats(tile, ground) Rows(tile, ground, false) end
	function Paint.WornName(tile, ground) Rows(tile, ground, true) end

	-- The preview's pen, as the build list's: the panel's measures put on the
	-- preview at its size (zoom), a word's width read at the panel's own size
	-- (Width), so a row's words fit as DrawGear fits them.
	local pen = {}

	local function Put(x, y, width, height, color, a, layer)
		local box = pen.canvas:Box(color[1], color[2], color[3], a, nil, layer)
		box:SetPoint("TOPLEFT", pen.canvas, "TOPLEFT", pen.ox + x * pen.zoom, pen.oy - y * pen.zoom)
		box:SetWidth(math.max(1, width * pen.zoom))
		box:SetHeight(math.max(1, height * pen.zoom))
	end

	-- A word as wide as it reads (a pooled word keeps the width it was last
	-- given), lined up as anchored.
	local function Say(size, color, text, justify)
		local word = pen.canvas:Word(SurvivorUI_FONT, size, "OUTLINE", color[1], color[2], color[3], text)
		word:SetWidth(math.ceil(word:GetStringWidth() or 0) + 4)
		word:SetJustifyH(justify or "LEFT")
		return word
	end

	local function Width(size, text)
		local word = Say(size, MUTED, text)
		local width = word:GetStringWidth() or 0
		word:Hide()
		return width
	end

	-- A row's words as DrawGear lays them: a name cut to the row, with a ".";
	-- the words at the right 9 points down to 7 beside the left ones, then the
	-- first of them and "...+" (all of them on hover in the game). The words
	-- at the left, at the right, the right ones' size.
	function Paint.WornFit(row, step)
		local W = SurvivorUI_BUILD_LOOK.width
		local left, right = row.left or "", row.right or ""
		if row.named and Width(9 + FONT_BUMP + step, left) > W - 8 then
			local count = string.len((string.gsub(left, "[\128-\191]", "")))
			local cut = left
			while count > 1 and Width(9 + FONT_BUMP + step, cut) > W - 8 do
				count = count - 1
				cut = (string.gsub(SurvivorUI_Cut(left, count), "%s+$", "")).."."
			end
			left = cut
		end
		if right == "" then
			return left, right, 9
		end
		local room = W - 8 - (left ~= "" and Width(9 + FONT_BUMP + step, left) or 0) - 10
		for size = 9, 7, -1 do
			if Width(size + FONT_BUMP + step, right) <= room then
				return left, right, size
			end
		end
		local parts, from, separator = {}, 1, " \194\183 "
		while true do
			local at = string.find(right, separator, from, true)
			if not at then
				table.insert(parts, string.sub(right, from))
				break
			end
			table.insert(parts, string.sub(right, from, at - 1))
			from = at + string.len(separator)
		end
		for count = table.getn(parts) - 1, 1, -1 do
			local shown = {}
			for index = 1, count do
				shown[index] = parts[index]
			end
			local text = table.concat(shown, separator)..separator.."...+"
			if Width(7 + FONT_BUMP + step, text) <= room then
				return left, text, 7
			end
		end
		return left, parts[1]..separator.."...+", 6
	end

	-- The rarities, as the collection colors them (Jewelry.lua).
	Paint.WORN_KEY = {
		{ "Legendary", { 1, 0.5, 0 } }, { "Epic", { 0.64, 0.21, 0.93 } }, { "Rare", { 0, 0.44, 0.87 } }, { "Uncommon", { 0.12, 1, 0 } },
	}
	Paint.WORN_ROOM, Paint.WORN_GOLD = 300, { 1, 0.82, 0 }

	function Paint.Worn(self)
		self:Begin()
		pen.canvas = self
		local look = SurvivorUI_BUILD_LOOK
		local gear = look and look.gear
		if not (gear and SurvivorUI_WornRows) or DB().jewelryWorn == false then
			Say(11 + FONT_BUMP, MUTED, gear and "Jewelry worn off" or "No jewelry panel", "CENTER"):SetPoint("CENTER", self, "CENTER", 0, 0)
			return
		end
		local rows, real = SurvivorUI_WornRows()
		Say(9 + FONT_BUMP, MUTED, real and "What you wear" or "A sample", "RIGHT"):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		local W, top, R = look.width, gear.top, gear.row
		local tall = top + table.getn(rows) * R + 5
		local height = self:GetHeight()
		-- At its size (its own, else the build list's) as far as the preview
		-- has room for all its slots, at its text size.
		local own = DB().partScale and DB().partScale.worn
		pen.zoom = math.min(own or (SurvivorUI_GetScale and SurvivorUI_GetScale("build")) or 1,
			(height - 28) / (top + gear.slots * R + 5), Paint.WORN_ROOM / (W + 12))
		local step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Jewelry worn") or 0
		local zoom = pen.zoom
		pen.ox = 12 + math.floor((Paint.WORN_ROOM - (W + 12) * zoom) / 2)
		pen.oy = -math.max(20, math.floor((height - tall * zoom) / 2 + 4))
		Put(0, 0, W + 12, tall, { 0.04, 0.04, 0.07 }, 0.55, "BACKGROUND")
		Say((9 + FONT_BUMP + step) * zoom, Paint.WORN_GOLD, SurvivorUI_T("Jewelry")):SetPoint("TOPLEFT", self, "TOPLEFT", pen.ox + 7 * zoom, pen.oy - 6 * zoom)
		local chosen = gear.paint[DB().jewelryColor or "row"] or gear.paint.row
		for index = 1, table.getn(rows) do
			local row = rows[index]
			local y = top + (index - 1) * R
			local paint = row.empty and gear.paint.empty or chosen
			local tint = paint.plain and gear.plain or row.color
			Put(6, y, W, R - 1, tint, paint.fill, "BORDER")
			Put(6, y, W, 1, tint, paint.edge, "ARTWORK")
			Put(6, y + R - 2, W, 1, tint, paint.edge, "ARTWORK")
			Put(6, y, 1, R - 1, tint, paint.edge, "ARTWORK")
			Put(6 + W - 1, y, 1, R - 1, tint, paint.edge, "ARTWORK")
			local words = row.empty and { 0.45, 0.45, 0.5 } or (paint.words and row.color or { 1, 1, 1 })
			local after = row.empty and { 0.4, 0.4, 0.45 } or words
			local left, right, size = Paint.WornFit(row, step)
			local mid = pen.oy - (y + (R - 1) / 2) * zoom
			Say((9 + FONT_BUMP + step) * zoom, words, left):SetPoint("LEFT", self, "TOPLEFT", pen.ox + 10 * zoom, mid)
			if right ~= "" then
				local word = Say((size + FONT_BUMP + step) * zoom, after, right, left == "" and "LEFT" or "RIGHT")
				if left == "" then
					word:SetPoint("LEFT", self, "TOPLEFT", pen.ox + 10 * zoom, mid)
				else
					word:SetPoint("RIGHT", self, "TOPLEFT", pen.ox + (6 + W - 4) * zoom, mid)
				end
			end
		end
		-- The rarities' key, dim with their color left out.
		local x = PAGE_WIDTH - 12 - 150
		local ky = -math.floor((height - 88) / 2)
		Say(8 + FONT_BUMP, MUTED, "RARITY"):SetPoint("TOPLEFT", self, "TOPLEFT", x, ky)
		ky = ky - 16
		for index = 1, table.getn(Paint.WORN_KEY) do
			local each = Paint.WORN_KEY[index]
			local swatch = self:Box(each[2][1], each[2][2], each[2][3], DB().jewelryColor == "none" and 0.3 or 1, nil, "OVERLAY")
			swatch:SetWidth(11)
			swatch:SetHeight(11)
			swatch:SetPoint("LEFT", self, "TOPLEFT", x, ky - 7)
			Say(9 + FONT_BUMP, TEXT, each[1]):SetPoint("LEFT", self, "TOPLEFT", x + 18, ky - 7)
			ky = ky - 18
		end
	end

	-- Drawn again now and then, for a piece put on or upgraded in the run, and
	-- for words measured once drawn.
	local preview = Kit.Preview(tab, 170, Paint.Worn)
	preview.wait = 0
	preview:SetScript("OnUpdate", function()
		this.wait = this.wait + arg1
		if this.wait >= 0.5 then
			this.wait = 0
			this:Refresh()
		end
	end)

	Kit.Section(tab, "Each piece shows", "Its stats: the slot and the piece's rank (a legendary amulet's spell, short, in the slot's place), then what it gives in short, smaller when long. Its name: the piece's own, cut when long, and only that. Hover a piece for its stats either way.")
	Kit.Tiles(tab, {
		{ "stats", "Its stats", "Its slot and rank, then what it gives", Paint.WornStats },
		{ "name", "Its name", "Cut when long, and only that", Paint.WornName },
	}, function() return DB().jewelryNames and "name" or "stats" end,
		function(value) DB().jewelryNames = value == "name" or nil end)

	-- What each row tells, and how its rarity shows.
	Kit.Split(tab)
	Kit.Section(tab, "Each row", "The parts of a piece's row on or off, and the empty slots.")
	Kit.Chips(tab, {
		{ "Its slot", function() return DB().jewelrySlot ~= false end, function() DB().jewelrySlot = DB().jewelrySlot == false end,
			"Neck, Ring or Trinket at the row's left (a legendary amulet's spell, short, in its place). Off: what it gives has more room.",
			usable = function() return not DB().jewelryNames end, why = "By its name, the row shows the name alone." },
		{ "Its rank", function() return DB().jewelryRank ~= false end, function() DB().jewelryRank = DB().jewelryRank == false end,
			"The piece's rank, the Roman numeral that ends its name: Ring  II. Off: by its stats, the slot alone; by its name, the name without it." },
		{ "Empty slots", function() return DB().jewelryEmpty ~= false end, function() DB().jewelryEmpty = DB().jewelryEmpty == false end,
			"The slots with nothing in them yet, faint, to see what is left to wear. Off: only what you wear, the panel as tall as that (its title alone with nothing on)." },
	})
	Kit.Right(tab)
	Kit.Section(tab, "Rarity color", "A piece's rarity in its color: green uncommon, blue rare, purple epic, orange legendary. The row: the row filled with it, as at first. The words: its words in it, over a plain row. None: every row alike.")
	Kit.Segments(tab, { { "row", "The row" }, { "words", "The words" }, { "none", "None" } },
		function() return DB().jewelryColor or "row" end,
		function(value) DB().jewelryColor = value ~= "row" and value or nil end)
	Kit.Join(tab)

	-- Its size: its own once given one, until then the build list's (Mover.lua:
	-- part of the list until v3.0.49).
	Kit.Split(tab)
	Kit.Size(tab, "Size", 0.5, 2, 0.05,
		function()
			local own = DB().partScale and DB().partScale.worn
			return own or (SurvivorUI_GetScale and SurvivorUI_GetScale("build")) or 1
		end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("worn", value) end end,
		{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Right(tab)
	Kit.BuildTextSize(tab, "Jewelry worn")
	Kit.Join(tab)
	Kit.BuildNote(tab, "Until given a size of its own here, it takes the build list's.")

	Kit.Foot(tab, { reset = Asked("Jewelry worn back to default?",
		"Each piece by its stats, its slot and rank, the empty slots shown, the rows in their rarity's color, at the build list's size and the first text size. Where it stands stays: Back to its place for that.", "Back to default",
		function()
			DB().jewelryNames, DB().jewelrySlot, DB().jewelryRank = nil, nil, nil
			DB().jewelryColor, DB().jewelryEmpty = nil, nil
			-- At the build list's size, and following it again.
			if DB().partScale and DB().partScale.worn and SurvivorUI_SetPartScale then
				SurvivorUI_SetPartScale("worn", SurvivorUI_GetScale and SurvivorUI_GetScale("build") or 1)
				DB().partScale.worn = nil
			end
			if SurvivorUI_SetPieceTextStep then
				SurvivorUI_SetPieceTextStep("Jewelry worn", 0)
			end
		end) })
end

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
Subheader(page, "What shows")
Check(page, "Hide the numbers at 0 or below", OnUnlessOff("statsHideZero"), Flip("statsHideZero"),
	"in the pane and on the panel, back once past 0; every class")

-- The class whose choices these are, named in the section's title.
local classTitle = Subheader(page, "Stats for this class")
local classWidget = {}
function classWidget:Refresh()
	local name = UnitClass and UnitClass("player")
	classTitle:SetText(string.upper(name and SurvivorUI_OTF("Stats for {1}", name) or "Stats for this class"))
end
table.insert(widgets, classWidget)
Note(page, "In the character pane and on the panel alike. Each class keeps its own; a number switched off never shows. For their order, drag a number or a group's title in either, in move mode or holding the move key (Alt unless chosen in Layout).")

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
	check.label:SetText(SurvivorUI_StatName and SurvivorUI_StatName(label, true) or label)
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
	side.Index(page, SurvivorUI_StatName and SurvivorUI_StatName(label, true) or label, "stat "..label, y, 15)
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
Header(page, "Jewelry collection", "The Jewelry Collection: every amulet, ring and trinket of the game's codex, found or still to find, and what each gives by rarity; your class's own amulets by spell.")
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

-- Made with the kit: the preview draws the row at the bottom of the screen
-- as SurvivorUI.lua lays it out (your frame, the buttons, your target's, your
-- buffs over yours) in the looks chosen; under it the health's looks side by
-- side, the modules and the bar's looks as chips, the sizes, and the bar's
-- two buttons. The tooltip has a tab of its own (Tooltips).

do
	local tab = pages.units
	Kit.Head(tab, { line = "Your frame, your target's, the action bar and your buffs over your frame. While this tab is open, drag the frames, the buffs or the target's debuffs to move them." })

	-- SurvivorUI.lua's sizes: a button's side and the gap between two, the
	-- gap between a frame and the buttons, a frame's bar, its power bar, a
	-- buff's side; the power's colors; the bar's buttons (12 is the = key),
	-- their keys, and a sample of each (spells, buffs) for an empty bar.
	Paint.ROW = { button = 36, gap = 2, apart = 6, bar = 150, power = 3, aura = 22 }
	Paint.POWER = { [0] = { 0.25, 0.50, 1.00 }, [1] = { 0.85, 0.20, 0.20 }, [2] = { 1.00, 0.55, 0.15 }, [3] = { 1.00, 0.90, 0.25 } }
	Paint.BAR = { 1, 2, 3, 4, 5, 6, 12 }
	Paint.BAR_KEYS = { "1", "2", "3", "4", "5", "6", "=" }
	Paint.BAR_SAMPLE = { "Spell_Fire_FlameBolt", "Spell_Shadow_ShadowWordPain", "Spell_Holy_HolyBolt", "Spell_Frost_FrostBolt02",
		"Spell_Nature_Lightning", "Spell_Nature_StarFall", "Spell_Holy_PowerWordShield" }
	Paint.BUFF_SAMPLE = { { "Spell_Holy_WordFortitude", "2m" }, { "Spell_Nature_Regeneration", "45" }, { "Spell_Holy_PowerWordShield", "8.2" } }
	-- The shield over the health (SurvivorUI.lua's SHIELD_LOOKS): its fill,
	-- its stripes and its edge; dark over a light health past the bar's end.
	Paint.SHIELD = {
		light = { 0.59, 0.82, 1, 0.45, 1, 1, 1, 1, 0.9, 0.97, 1 },
		dark = { 0.22, 0.5, 1, 0.6, 0.08, 0.2, 0.55, 0.95, 0.06, 0.22, 0.65 },
	}

	-- A box with a black edge a layer under it, the edge a pixel out.
	function Paint.RowEdged(self, x, y, width, height, r, g, b, texture, layer)
		local edge = self:Box(0, 0, 0, 1, nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", x - 1, y + 1)
		edge:SetWidth(width + 2)
		edge:SetHeight(height + 2)
		local box = self:Box(r, g, b, 1, texture, layer or "BORDER")
		box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		box:SetWidth(width)
		box:SetHeight(height)
		return box
	end

	-- A flat bar: its edge, its fill to the share and its dark backing after
	-- it, side by side in one layer (never over each other).
	function Paint.UnitBar(self, x, y, width, height, share, r, g, b)
		local edge = self:Box(0, 0, 0, 1, nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", x - 1, y + 1)
		edge:SetWidth(width + 2)
		edge:SetHeight(height + 2)
		local filled = math.floor(width * math.max(0, math.min(1, share or 0)) + 0.5)
		if filled > 0 then
			local fill = self:Box(r, g, b, 1, nil, "BORDER")
			fill:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
			fill:SetWidth(filled)
			fill:SetHeight(height)
		end
		if filled < width then
			local rest = self:Box(0.09, 0.09, 0.11, 1, nil, "BORDER")
			rest:SetPoint("TOPLEFT", self, "TOPLEFT", x + filled, y)
			rest:SetWidth(width - filled)
			rest:SetHeight(height)
		end
	end

	-- A frame's numbers: yours; your target's (an enemy's as the game gives
	-- them, as SurvivorUI.lua reads them); else a sample enemy's.
	function Paint.UnitData(unit)
		local data = {}
		if unit == "player" then
			data.name, data.portrait = UnitName("player") or "Hero", "player"
			data.health, data.most = UnitHealth("player") or 0, UnitHealthMax("player") or 0
			if data.most <= 0 then
				data.health, data.most = 1180, 1240
			end
			data.hp, data.hpm = data.health, data.most
			data.r, data.g, data.b = Paint.HeroColor()
			data.style = DB().playerHealth or "absolutePercent"
			-- What the shields on you hold (the game's), else a fifth, to show it.
			local run = AZS_RUN or {}
			data.held, data.heldMost = tonumber(run.sh) or 0, tonumber(run.hpm) or 0
			if data.held < 1 or data.heldMost <= 0 then
				data.held, data.heldMost = math.floor(data.most * 0.2 + 0.5), data.most
			end
		elseif UnitExists("target") then
			data.name, data.portrait = UnitName("target") or "", "target"
			data.health, data.most = UnitHealth("target") or 0, UnitHealthMax("target") or 0
			data.hp, data.hpm = data.health, data.most
			data.style = DB().targetHealth or "absolutePercent"
			local game = AZS_TARGET
			if game and game.name == data.name and (tonumber(game.hpm) or 0) > 0 then
				data.hp, data.hpm = tonumber(game.hp) or 0, tonumber(game.hpm)
			elseif data.most == 100 then
				data.style = "percent"
			end
			data.r, data.g, data.b = 0.80, 0.22, 0.22
			local _, class = UnitClass("target")
			if UnitIsPlayer("target") and class and SurvivorUI_ClassColor then
				data.r, data.g, data.b = SurvivorUI_ClassColor(class)
			end
		else
			data.name, data.icon = "Young Wolf", "Interface\\Icons\\Ability_Hunter_Pet_Wolf"
			data.health, data.most, data.hp, data.hpm = 73, 100, 1240000, 1700000
			data.r, data.g, data.b = 0.80, 0.22, 0.22
			data.style = DB().targetHealth or "absolutePercent"
		end
		data.share = data.most > 0 and data.health / data.most or 0
		data.power, data.powerMost = 0, 0
		if data.portrait then
			data.kind = UnitPowerType(data.portrait)
			data.power, data.powerMost = UnitMana(data.portrait) or 0, UnitManaMax(data.portrait) or 0
		end
		return data
	end

	-- The shields' share over your health, from where it ends (past the bar's
	-- end, over its right end instead), striped, a bright edge at its end.
	function Paint.Shield(self, data, x, top, wide, high, zoom)
		local held = math.min(1, data.held / data.heldMost)
		if held <= 0.002 then
			return
		end
		local from, to, at = data.share, data.share + held, data.share + held
		local over = to > 1
		if over then
			from, to, at = 1 - held, 1, 1 - held
		end
		local look = Paint.SHIELD.light
		if over and (0.3 * data.r + 0.59 * data.g + 0.11 * data.b) > 0.75 then
			look = Paint.SHIELD.dark
		end
		local left, right = x + math.floor(wide * from + 0.5), x + math.floor(wide * to + 0.5)
		if right - left < 1 then
			return
		end
		local fill = self:Box(look[1], look[2], look[3], look[4], nil, "ARTWORK")
		fill:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
		fill:SetWidth(right - left)
		fill:SetHeight(high)
		local stripes = self:Box(look[5], look[6], look[7], look[8], ART.."ShieldStripes", "ARTWORK")
		stripes:SetTexCoord(from, to, 0, 1)
		stripes:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
		stripes:SetWidth(right - left)
		stripes:SetHeight(high)
		local thick = math.max(1, math.floor(2 * zoom + 0.5))
		local edge = self:Box(look[9], look[10], look[11], 1, nil, "ARTWORK")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", x + math.floor(wide * at + 0.5) - math.floor(thick / 2), top)
		edge:SetWidth(thick)
		edge:SetHeight(high)
	end

	-- A frame as SurvivorUI.lua draws it, at a zoom: the portrait at its
	-- outer end (yours at the left), the health in its color with the name
	-- and the numbers on it in the look chosen, the power under it; on yours
	-- the shields, your numbers counting them, in light blue, with "Shield in
	-- the health text" on.
	function Paint.UnitFrame(self, data, x, top, zoom, left)
		local side = math.floor(Paint.ROW.button * zoom + 0.5)
		local wide = math.floor(Paint.ROW.bar * zoom + 0.5)
		local low = math.max(2, math.floor(Paint.ROW.power * zoom + 0.5))
		local noPower = data.kind == 1 and SurvivorUI_Feature and SurvivorUI_Feature("bloodrage")
		local high = noPower and side or side - low - 1
		local barX = left and x + side + 1 or x
		local portrait = Paint.RowEdged(self, left and x or x + wide + 1, top, side, side, 1, 1, 1, data.icon)
		if data.portrait and SetPortraitTexture then
			SetPortraitTexture(portrait, data.portrait)
			portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		else
			portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		Paint.UnitBar(self, barX, top, wide, high, data.share, data.r, data.g, data.b)
		if not noPower then
			local color = Paint.POWER[data.kind or 0] or Paint.POWER[0]
			Paint.UnitBar(self, barX, top - high - 1, wide, low, data.powerMost > 0 and data.power / data.powerMost or 0, color[1], color[2], color[3])
		end
		local hp, shielded = data.hp, false
		if data.held then
			Paint.Shield(self, data, barX, top, wide, high, zoom)
			if DB().shieldText ~= false then
				hp, shielded = hp + data.held, true
			end
		end
		local font = (10 + FONT_BUMP) * zoom
		local value = self:Word(SurvivorUI_FONT, font, "OUTLINE", 1, 1, 1, SurvivorUI_HealthText and SurvivorUI_HealthText(hp, data.hpm, data.style) or "")
		if shielded then
			value:SetTextColor(0.59, 0.82, 1)
		end
		value:SetPoint("RIGHT", self, "TOPLEFT", barX + wide - 5 * zoom, top - high / 2)
		-- The name in the room the numbers leave, else its first word.
		local room = Paint.ROW.bar - 44
		if data.style == "both" or data.style == "absolutePercent" then
			room = Paint.ROW.bar - 82
		elseif data.style == "absolute" then
			room = Paint.ROW.bar - 52
		end
		local name = self:Word(SurvivorUI_FONT, font, "OUTLINE", 1, 1, 1, data.name)
		-- (Measured as the frame measures it: at its size, on a hidden frame at
		-- its scale, a word's width at a scale being whole pixels.)
		if not Paint.namer then
			Paint.namer = CreateFrame("Frame", nil, UIParent)
			Paint.namer:Hide()
			Paint.namer.word = Paint.namer:CreateFontString(nil, "OVERLAY")
		end
		local real = getglobal("SurvivorUIPlayer")
		Paint.namer:SetScale(real and real:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1)
		Paint.namer.word:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
		Paint.namer.word:SetText(data.name)
		if Paint.namer.word:GetStringWidth() > room then
			local _, _, first = string.find(data.name, "^(%S+)")
			name:SetText(first or data.name)
		end
		name:SetPoint("LEFT", self, "TOPLEFT", barX + 5 * zoom, top - high / 2)
	end

	-- The buttons, as the bar has them (a sample bar while it is empty): each
	-- its key over its top right while the key labels show, a cooldown
	-- counting on the third with Cooldown numbers on.
	function Paint.Buttons(self, x, top, zoom)
		local side = math.floor(Paint.ROW.button * zoom + 0.5)
		local step = side + math.max(1, math.floor(Paint.ROW.gap * zoom + 0.5))
		local real = false
		for index = 1, table.getn(Paint.BAR) do
			if GetActionTexture and GetActionTexture(Paint.BAR[index]) then
				real = true
			end
		end
		local keys = SurvivorUI_Feature and not SurvivorUI_Feature("hideKeys")
		local counts = not SurvivorUI_Feature or SurvivorUI_Feature("cooldownNumbers")
		for index = 1, table.getn(Paint.BAR) do
			local id = Paint.BAR[index]
			local art = "Interface\\Icons\\"..Paint.BAR_SAMPLE[index]
			if real then
				art = GetActionTexture(id)
			end
			-- The cooldown on the first spell there is (the sample's third).
			local counting = counts and art and (real or index == 3)
			if counting then
				counts = false
			end
			local left = x + (index - 1) * step
			local dark = art and 1 or 0.1
			local icon = Paint.RowEdged(self, left, top, side, side, dark, dark, dark + (art and 0 or 0.01), art)
			if art then
				icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			if keys then
				local hotkey = getglobal("ActionButton"..id.."HotKey")
				local text = hotkey and hotkey:GetText()
				if not text or text == "" or text == RANGE_INDICATOR then
					text = Paint.BAR_KEYS[index]
				end
				local font, size, flags, r, g, b
				if hotkey then
					font, size, flags = hotkey:GetFont()
					r, g, b = hotkey:GetTextColor()
				end
				local label = self:Word(font or "Fonts\\ARIALN.TTF", (size or 12) * zoom, flags or "OUTLINE", r or 0.6, g or 0.6, b or 0.6, text)
				label:SetPoint("TOPRIGHT", self, "TOPLEFT", left + side - 2 * zoom, top - 2 * zoom)
			end
			if counting then
				local dim = self:Box(0, 0, 0, 0.45, nil, "ARTWORK")
				dim:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
				dim:SetWidth(side)
				dim:SetHeight(side)
				self:Word(SurvivorUI_FONT, (14 + FONT_BUMP) * zoom, "OUTLINE", 1, 0.95, 0.6, "3.4"):SetPoint("CENTER", icon, "CENTER", 0, 0)
			end
		end
	end

	-- A buff's time left as SurvivorUI.lua writes it.
	function Paint.BuffTime(seconds)
		if not seconds or seconds <= 0 then
			return ""
		elseif seconds >= 3600 then
			return math.floor(seconds / 3600 + 0.5).."h"
		elseif seconds >= 60 then
			return math.floor(seconds / 60 + 0.5).."m"
		elseif seconds >= 10 then
			return tostring(math.floor(seconds))
		end
		return string.format("%.1f", seconds)
	end

	-- Your buffs, then your debuffs (red edged), over your frame from its left;
	-- a sample of three while you have none.
	function Paint.Buffs(self, x, bottom, zoom)
		local side = math.floor(Paint.ROW.aura * zoom + 0.5)
		local step = side + math.max(1, math.floor(3 * zoom + 0.5))
		local list = {}
		for pass = 1, 2 do
			for slot = 0, 15 do
				local index = GetPlayerBuff and GetPlayerBuff(slot, pass == 1 and "HELPFUL" or "HARMFUL")
				if index and index >= 0 and table.getn(list) < 8 then
					table.insert(list, { GetPlayerBuffTexture(index), Paint.BuffTime(GetPlayerBuffTimeLeft(index)), pass == 2 })
				end
			end
		end
		if table.getn(list) == 0 then
			for index = 1, table.getn(Paint.BUFF_SAMPLE) do
				list[index] = { "Interface\\Icons\\"..Paint.BUFF_SAMPLE[index][1], Paint.BUFF_SAMPLE[index][2] }
			end
		end
		for index = 1, table.getn(list) do
			local left, top = x + (index - 1) * step, bottom + side
			local edge = self:Box(list[index][3] and 0.85 or 0, list[index][3] and 0.1 or 0, list[index][3] and 0.1 or 0, 1, nil, "BACKGROUND")
			edge:SetPoint("TOPLEFT", self, "TOPLEFT", left - 1, top + 1)
			edge:SetWidth(side + 2)
			edge:SetHeight(side + 2)
			local icon = self:Box(1, 1, 1, 1, list[index][1], "BORDER")
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
			icon:SetWidth(side)
			icon:SetHeight(side)
			self:Word(SurvivorUI_FONT, (10 + FONT_BUMP) * zoom, "OUTLINE", 1, 0.95, 0.6, list[index][2] or ""):SetPoint("CENTER", icon, "CENTER", 0, 0)
		end
	end

	-- Your target's debuffs over its frame from its left, 18 a side and 21
	-- apart (SurvivorUI.lua's); a sample's two with no target.
	Paint.DEBUFF_SAMPLE = { "Spell_Shadow_ShadowWordPain", "Spell_Frost_FrostNova" }
	function Paint.Debuffs(self, x, bottom, zoom)
		local side = math.floor(18 * zoom + 0.5)
		local step = side + math.max(1, math.floor(3 * zoom + 0.5))
		local list = {}
		if UnitExists("target") then
			for index = 1, 8 do
				local texture = UnitDebuff("target", index)
				if texture then
					table.insert(list, texture)
				end
			end
		else
			for index = 1, table.getn(Paint.DEBUFF_SAMPLE) do
				list[index] = "Interface\\Icons\\"..Paint.DEBUFF_SAMPLE[index]
			end
		end
		for index = 1, table.getn(list) do
			local icon = Paint.RowEdged(self, x + (index - 1) * step, bottom + side, side, side, 1, 1, 1, list[index])
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	end

	-- The preview: the row as SurvivorUI.lua lays it out until moved, each
	-- part at its own size (Size, below), as large as the strip lets the
	-- whole row be; a part switched off (Modules) says so in its place.
	function Paint.Units(self)
		self:Begin()
		local R = Paint.ROW
		local function On(key)
			return not SurvivorUI_Feature or SurvivorUI_Feature(key)
		end
		local function Size(key)
			return SurvivorUI_GetScale and SurvivorUI_GetScale(key) or 1
		end
		local frames, bar, buffs = Size("frames"), Size("bar"), Size("buffs")
		local frameWide = (R.button + 1 + R.bar + R.apart) * frames
		local barWide = (table.getn(Paint.BAR) * (R.button + R.gap) - R.gap) * bar
		local zoom = math.min(1, (PAGE_WIDTH - 24) / (barWide + 2 * frameWide))
		local rowHigh = math.max(R.button * frames, R.button * bar) * zoom
		local auraHigh = math.max(On("buffs") and (R.aura + 5) * buffs or 0, On("unitFrames") and 22 * frames or 0) * zoom
		local spare = math.max(0, self:GetHeight() - 26 - auraHigh - rowHigh)
		local middle = math.floor(-18 - auraHigh - spare / 2 - rowHigh / 2 + 0.5)
		local x = math.floor((PAGE_WIDTH - (barWide + 2 * frameWide) * zoom) / 2 + 0.5)
		local frameTop = math.floor(middle + R.button * frames * zoom / 2 + 0.5)
		local barX = x + math.floor(frameWide * zoom + 0.5)
		local targetX = barX + math.floor((barWide + R.apart * frames) * zoom + 0.5)
		if On("unitFrames") then
			Paint.UnitFrame(self, Paint.UnitData("player"), x, frameTop, frames * zoom, true)
			Paint.UnitFrame(self, Paint.UnitData("target"), targetX, frameTop, frames * zoom, false)
			Paint.Debuffs(self, targetX, frameTop + math.floor(4 * frames * zoom + 0.5), frames * zoom)
		else
			for _, at in pairs({ x, targetX }) do
				local off = self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], "Unit frames off: the game's")
				off:SetPoint("CENTER", self, "TOPLEFT", at + (R.button + 1 + R.bar) * frames * zoom / 2, middle)
			end
		end
		if On("actionBar") then
			Paint.Buttons(self, barX, math.floor(middle + R.button * bar * zoom / 2 + 0.5), bar * zoom)
		else
			local off = self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], "Action bar off: the game's")
			off:SetPoint("CENTER", self, "TOPLEFT", barX + barWide * zoom / 2, middle)
		end
		if On("buffs") then
			Paint.Buffs(self, x, frameTop + math.floor(5 * buffs * zoom + 0.5), buffs * zoom)
		end
	end
	Kit.Preview(tab, 96, Paint.Units)

	-- Kit.Segments narrowed to its column: each part's pad cut from 24 (down
	-- to 8) to share the room out, the kit's parts being as wide as their
	-- words and 24.
	function Kit.NarrowSegments(holder, page)
		local _, width = Span(page)
		if holder:GetWidth() <= width then
			return holder
		end
		local count, words = table.getn(holder.parts), 0
		for index = 1, count do
			words = words + math.ceil(holder.parts[index].label:GetStringWidth())
		end
		local pad, x = math.max(8, math.floor((width - 4 - words) / count)), 2
		for index = 1, count do
			local part = holder.parts[index]
			part:SetWidth(math.ceil(part.label:GetStringWidth()) + pad)
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -2)
			x = x + part:GetWidth()
		end
		holder:SetWidth(x + 2)
		return holder
	end

	-- The health's four looks (HEALTH_LOOKS: 73%, 1.2M, 1.2M / 3.4M,
	-- 1.2M | 73%), each frame's own.
	local looks = {}
	for index = 1, table.getn(HEALTH_LOOKS) do
		looks[index] = { HEALTH_LOOKS[index][1], HEALTH_LOOKS[index][2] }
	end
	local function Health(key)
		return function() return DB()[key] or "absolutePercent" end, function(value) DB()[key] = value end
	end
	local LOOKS_HELP = "The percent, the health left, the health left of the whole, or the health left and the percent. Always short: 1.2M for 1,200,000."
	Kit.Split(tab)
	Kit.Section(tab, "Player health", LOOKS_HELP)
	Kit.NarrowSegments(Kit.Segments(tab, looks, Health("playerHealth")), tab)
	Kit.Chips(tab, {
		{ "Shield in the health text", OnUnlessOff("shieldText"), Flip("shieldText"),
			"Shielded, your numbers count the shield too, in light blue: 851 | 155%. The shield shows on the bar either way." },
	})
	Kit.Right(tab)
	Kit.Section(tab, "Target health", "The percent, the health left, the health left of the whole, or the health left and the percent. Always short: 1.2M for 1,200,000. A target the game gives no numbers for shows its percent.")
	Kit.NarrowSegments(Kit.Segments(tab, looks, Health("targetHealth")), tab)
	Kit.Link(tab, "The boss bars' health, in", "bosses")
	Kit.Join(tab)

	Kit.Section(tab, "Modules", "Each a module, as in Modules: off, the game's own comes back. After a reload.")
	Kit.Chips(tab, {
		{ "Unit frames", FeatureOn("unitFrames"), FeatureToggle("unitFrames"),
			"Your frame and your target's: flat, the portrait, the health in numbers, the target's debuffs over it. Off: the game's frames. After a reload." },
		{ "Action bar", FeatureOn("actionBar"), FeatureToggle("actionBar"),
			"Buttons 1 to 6 and = in one flat row, the rest of the bar and the bags put away, the experience a strip under it. Off: the game's bar. After a reload." },
		{ "Buffs", FeatureOn("buffs"), FeatureToggle("buffs"),
			"Your buffs and debuffs over your frame, with time left and stacks. Off: the game's, at the top right. After a reload." },
	})

	Kit.Section(tab, "Action bar")
	Kit.Chips(tab, {
		{ "Cooldown numbers", FeatureOn("cooldownNumbers"), FeatureToggle("cooldownNumbers"),
			"Each button's cooldown left on it, the last two seconds in red. OmniCC, when installed, does it instead." },
		{ "Short cooldowns too", function() return DB().shortCooldowns ~= false end, function()
				if DB().shortCooldowns == false then
					DB().shortCooldowns = nil
				else
					DB().shortCooldowns = false
				end
			end, "Cooldowns of 1.5 s or less count too: those much haste makes, and the global cooldown's flicker." },
		{ "Key labels", function() return SurvivorUI_Feature and not SurvivorUI_Feature("hideKeys") end, FeatureToggle("hideKeys"),
			"Each button's key, 1 to 6 and =. Hidden by default, as the spells go off by themselves: hide or show them here. After a reload." },
		{ "Spells locked", function() return SurvivorUI_BarLocked and SurvivorUI_BarLocked() end,
			function() if SurvivorUI_ToggleBarLock then SurvivorUI_ToggleBarLock() end end,
			"Spells locked on the bar: none dragged or shift-clicked off its button. The addon reads the bar in the game's order, and a moved spell wore another's icon and tooltip." },
		{ "Frames follow the bar", function() return SurvivorUI_LinkFrames and SurvivorUI_LinkFrames() end, function()
				if SurvivorUI_SetLinkFrames and SurvivorUI_LinkFrames then
					SurvivorUI_SetLinkFrames(not SurvivorUI_LinkFrames())
				end
			end, "Player and target frames move with the action bar." },
	})

	Kit.Section(tab, "Size", "Each part's own, on top of the whole interface's (Global). The whole center bar sizes the other three together, each still with its own on top.")
	Kit.Fine(tab, {
		PartSize("middle", "Whole center bar"), PartSize("bar", "Action bar"),
		PartSize("frames", "Player and target"), PartSize("buffs", "Buffs"),
	})

	-- The row's places: the bar back under the hero, the frames, the buffs and
	-- the target's debuffs back where the bar puts them.
	local y = tab.y - 2
	local center = Kit.Quiet(tab, "Center the action bar", 170, Call("SurvivorUI_CenterRow"))
	center:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y)
	side.Index(tab, "Center the action bar", "middle reset place position under the hero", y, 24)
	local back = Kit.Quiet(tab, "Frames back in place", 170, function()
		if SurvivorUI_ResetPiece then
			for _, name in pairs({ "Player frame", "Target frame", "Target debuffs", "Buffs" }) do
				SurvivorUI_ResetPiece(name)
			end
		end
	end)
	back:SetPoint("TOPLEFT", tab, "TOPLEFT", 180, y)
	side.Index(tab, "Frames back in place", "reset place position player target buffs debuffs", y, 24)
	tab.y = y - 30

	-- Its looks back as they first were (Mover.lua's sizes: the center bar
	-- 0.9, the bar 0.85); the modules and every place stay.
	Kit.Foot(tab, { reset = Asked("Frames & bar back to default?",
		"The health as 1.2M | 73% on both frames, the shield counted in yours, cooldown numbers with the short ones, no key labels, and the four sizes as they first were. The modules, the lock, the frames following the bar and where each stands stay.", "Back to default",
		function()
			local db = DB()
			db.playerHealth, db.targetHealth, db.shieldText, db.shortCooldowns = nil, nil, nil, nil
			local features = db.features or {}
			if features.hideKeys == false then
				needsReload = true
			end
			features.cooldownNumbers, features.hideKeys = nil, nil
			if SurvivorUI_SetPartScale then
				for key, size in pairs({ middle = 0.9, bar = 0.85, frames = 1, buffs = 1 }) do
					SurvivorUI_SetPartScale(key, size)
				end
			end
		end) })
end

------------------------------------------------------------------------------
-- Minimap: its look and size, and the pins a run puts on it (MapPins.lua).

-- Made with the kit: the preview draws the minimap as the game will, square
-- (round with Square minimap off), a sample of each kind of pin on it as the
-- settings stand, you in its middle, and a line for each kind beside it;
-- under it the kinds as chips, the choices two to a row, your marker, the
-- sizes, and where its buttons and the range ring are set.

do
	local tab = pages.minimap
	Kit.Head(tab, { line = "Square (the switch): its buttons tidied, your time and the frames a second along its bottom; off, the game's round one. Then the pins a run puts on it. While this tab is open, drag the minimap or its buttons to move them.",
		isOn = FeatureOn("minimap"), toggle = FeatureToggle("minimap"), reloads = true, piece = "Minimap" })
	side.Index(tab, "Square minimap", "round square minimap reload", tab.y + 36, 22)

	local MAP = 140                    -- the game's minimap across: the pins' sizes are on it
	local SIDE = 140                   -- the preview's: the game's own size (room for your marker's row)
	local ZOOM = SIDE / MAP
	local canvas, midX, midY           -- the pins' frame (over the preview), the minimap's middle on it

	-- What a setting here needs (Lucas, 2026-11-04: one whose part is off
	-- stands faded and still, the reason on hover): the pins on the minimap
	-- (Minimap pins in Modules), the lairs' pins, the empty lairs shown, a kind
	-- of pin on, the square minimap, a game that lets its arrow go.
	local Needs = {}
	function Needs.Pins()
		return not SurvivorUI_Feature or SurvivorUI_Feature("mapPins")
	end
	-- The red flag's choice: with the pins off, Modules has the game's flag.
	function Needs.Flag()
		return Needs.Pins()
	end
	function Needs.Lairs()
		return Needs.Pins() and DB().pinLairs ~= false
	end
	-- A timer sits under an empty lair's pin: none while they are hidden.
	function Needs.Timers()
		return Needs.Lairs() and DB().pinEmpty ~= "hide"
	end
	-- The lairs' size is the bosses' and the elites' too.
	function Needs.Skulls()
		local db = DB()
		return Needs.Pins() and (db.pinLairs ~= false or db.pinBosses ~= false or db.pinElites == true)
	end
	function Needs.Caches()
		return Needs.Pins() and DB().pinCaches ~= false
	end
	function Needs.Any()
		return Needs.Skulls() or Needs.Caches()
	end
	function Needs.Square()
		return not SurvivorUI_Feature or SurvivorUI_Feature("minimap")
	end
	function Needs.Marker()
		return SurvivorUI_HeroMarkerUsable and SurvivorUI_HeroMarkerUsable()
	end

	-- Why one is still, by what it needs: the first part of it that is off.
	function Needs.Why(usable)
		if usable == Needs.Square then
			return "Only on the square minimap: its switch at the top is off."
		elseif usable == Needs.Marker then
			return "This version of the game cannot put its arrow away."
		elseif usable == Needs.Flag and not Needs.Pins() then
			return "Pins on the minimap are off: the game's flag is back, unless The game's is unticked in Modules."
		elseif not Needs.Pins() then
			return "Pins on the minimap are off."
		elseif usable == Needs.Skulls then
			return "Lairs, Bosses and Elites are all off."
		elseif usable == Needs.Caches then
			return "Caches are off."
		elseif usable == Needs.Any then
			return "Every kind of pin is off."
		elseif DB().pinLairs == false then
			return "Lairs are off."
		end
		return "Empty lairs are hidden: no pin to put the timer under."
	end

	-- The tooltip of a still piece: its name, the reason under it.
	function Needs.Tip(owner, title, reason)
		GameTooltip:SetOwner(owner, "ANCHOR_TOP")
		GameTooltip:SetText(SurvivorUI_OT(title), tab.color[1], tab.color[2], tab.color[3])
		GameTooltip:AddLine(SurvivorUI_OT(reason), MUTED[1], MUTED[2], MUTED[3], 1)
		GameTooltip:Show()
	end

	-- The last count chips just made: each one's reason as things stand when
	-- it is hovered (its Refresh runs first).
	function Needs.Chips(count)
		local last = table.getn(widgets)
		for index = last - count + 1, last do
			local chip = widgets[index]
			if chip.usable then
				local Shown = chip.Refresh
				function chip:Refresh()
					self.why = Needs.Why(self.usable)
					Shown(self)
				end
			end
		end
	end

	-- A row of Kit.Segments: the reason on hover while it stands still. One
	-- part of it (value) may need more (usable), faded and still on its own
	-- while not, with its own reason (why).
	function Needs.Row(holder, title, value, usable, why)
		for index = 1, table.getn(holder.parts) do
			local part = holder.parts[index]
			part:SetScript("OnEnter", function()
				this.hot = true
				holder:Refresh()
				if holder.usable and not holder.usable() then
					Needs.Tip(this, title, Needs.Why(holder.usable))
				elseif value and this.value == value and not usable() then
					Needs.Tip(this, title, why)
				end
			end)
			part:SetScript("OnLeave", function()
				this.hot = nil
				holder:Refresh()
				GameTooltip:Hide()
			end)
		end
		if value then
			-- The game's SetAlpha writes down to every child, no product: each
			-- part set after the row, faded with it or on its own.
			local Shown = holder.Refresh
			function holder:Refresh()
				Shown(self)
				local still = self.usable and not self.usable()
				for index = 1, table.getn(self.parts) do
					local part = self.parts[index]
					part:SetAlpha((still or (part.value == value and not usable())) and 0.4 or 1)
				end
			end
		end
		return holder
	end

	-- A Kit.Size just made (its S M L, then its bar: the last four pieces),
	-- faded and still while what it needs is off, the reason on its S M L.
	function Needs.Size(title, usable)
		local last = table.getn(widgets)
		for index = last - 3, last do
			local piece = widgets[index]
			local Shown = piece.Refresh
			local bar = index == last and piece:GetChildren()
			function piece:Refresh()
				Shown(self)
				local on = usable() and true or false
				self:SetAlpha(on and 1 or 0.4)
				if bar then
					bar:EnableMouse(on)
					bar:EnableMouseWheel(on)
				end
			end
			if not bar then
				piece:SetScript("OnEnter", function()
					this.hot = true
					this:Refresh()
					if not usable() then
						Needs.Tip(this, title, Needs.Why(usable))
					end
				end)
				piece:SetScript("OnLeave", function()
					this.hot = nil
					this:Refresh()
					GameTooltip:Hide()
				end)
			end
		end
	end

	local function PinSize(kind)
		return SurvivorUI_PinSize and SurvivorUI_PinSize(kind) or 16
	end

	-- A pin's art at its size, its middle x, y from the minimap's (y up).
	local function Put(art, size, x, y, alpha)
		local box = canvas:Box(1, 1, 1, 1, art, "OVERLAY")
		box:SetBlendMode("BLEND")
		box:SetAlpha(alpha or 1)
		box:SetWidth(size)
		box:SetHeight(size)
		box:SetPoint("CENTER", canvas, "TOPLEFT", midX + x, midY + y)
		return box
	end

	-- A glow behind a pin, as MapPins.lua lays it: light added, a layer under.
	local function Glow(size, r, g, b, a, x, y)
		local glow = canvas:Box(r, g, b, a, ART.."PaceGlow", "ARTWORK")
		glow:SetBlendMode("ADD")
		glow:SetAlpha(1)
		glow:SetWidth(size)
		glow:SetHeight(size)
		glow:SetPoint("CENTER", canvas, "TOPLEFT", midX + x, midY + y)
	end

	-- The game's own red flag on a lair, as near as boxes draw it: behind
	-- the pin, its pole at the left, its cloth showing over it.
	local function Flag(x, y, size)
		local pole = canvas:Box(0.42, 0.42, 0.45, 1, nil, "ARTWORK")
		pole:SetBlendMode("BLEND")
		pole:SetAlpha(1)
		pole:SetWidth(math.max(2, math.floor(size / 7 + 0.5)))
		pole:SetHeight(size * 1.15)
		pole:SetPoint("BOTTOMLEFT", canvas, "TOPLEFT", midX + x - size * 0.6, midY + y - size * 0.55)
		local cloth = canvas:Box(0.80, 0.08, 0.08, 1, nil, "ARTWORK")
		cloth:SetBlendMode("BLEND")
		cloth:SetAlpha(1)
		cloth:SetWidth(size)
		cloth:SetHeight(size * 0.55)
		cloth:SetPoint("TOPLEFT", pole, "TOPRIGHT", 0, 0)
	end

	-- The game's red flag alone on the flagged lair: with our lairs' pins off,
	-- or all of ours off and Modules leaving the game's on (MapPins.lua).
	function Needs.GameFlag()
		for index = 1, table.getn(Paint.MAP_LAIRS) do
			local spot = Paint.MAP_LAIRS[index]
			if spot[5] then
				Flag(spot[2] * ZOOM, spot[3] * ZOOM, PinSize("lair") * ZOOM)
			end
		end
	end

	-- A lair's pin: the skull, dimmed while empty (MapPins.lua's).
	local function Lair(empty, size, x, y, alpha)
		local pin = Put(ART.."PinLair", size, x, y, alpha)
		if empty then
			pin:SetVertexColor(0.45, 0.45, 0.45, 1)
		end
		return pin
	end

	-- Where a pin goes, as MapPins.lua's Place has it: past the square's edge,
	-- on the edge toward it, smaller and fainter; nil with Out of reach hidden.
	local function Reach(x, y, size)
		local edge = math.floor(size * 11 / 16 + 0.5)
		local limit = MAP / 2 - edge / 2
		local reach = math.max(math.abs(x), math.abs(y))
		if reach <= limit then
			return x, y, size, 1
		elseif DB().pinEdge == "hide" then
			return nil
		end
		return x * limit / reach, y * limit / reach, edge, 0.7
	end

	-- The sample, x, y from the minimap's middle (you): the lairs (each its
	-- place, held, empty or awake, the flagged one; an awake one's guardian
	-- out at the last two), the caches, the bosses, an elite. One lair and one
	-- cache lie past its reach.
	Paint.MAP_LAIRS = {
		{ 1, -40, 30, "held", true },
		{ 2, 34, 36, "empty" },
		{ 3, -46, -24, "held" },
		{ 4, 50, -40, "awake", nil, 14, -18 },
		{ 5, -12, 120, "held" },
	}
	Paint.MAP_UNITS = { { "cache", 2, 46 }, { "cache", -14, -50 }, { "cache", 160, -4 },
		{ "boss", 40, 4 }, { "finalBoss", -16, 12 }, { "elite", 22, -46 } }

	-- The minimap's ground: a square with a black edge and the clock's strip
	-- along its bottom, or round in a stone rim.
	local function Ground(self, square)
		if not square then
			local looks = { { 0.40, 0.38, 0.33, SIDE + 14, "BACKGROUND" }, { 0, 0, 0, SIDE + 5, "BORDER" },
				{ 0.20, 0.26, 0.13, SIDE, "ARTWORK" }, { 0.20, 0.26, 0.13, SIDE, "ARTWORK" } }
			for index = 1, table.getn(looks) do
				local look = looks[index]
				local disc = self:Box(look[1], look[2], look[3], 1, ART.."Disc", look[5])
				disc:SetPoint("CENTER", self, "TOPLEFT", midX, midY)
				disc:SetWidth(look[4])
				disc:SetHeight(look[4])
			end
			if DB().minimapClock ~= false then
				self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], "Round: no clock and FPS"):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
			end
			return
		end
		local edge = self:Box(0, 0, 0, 1, nil, "BACKGROUND")
		edge:SetPoint("CENTER", self, "TOPLEFT", midX, midY)
		edge:SetWidth(SIDE + 2)
		edge:SetHeight(SIDE + 2)
		local map = self:Box(0.20, 0.26, 0.13, 1, nil, "BORDER")
		map:SetPoint("CENTER", self, "TOPLEFT", midX, midY)
		map:SetWidth(SIDE)
		map:SetHeight(SIDE)
		if DB().minimapClock == false then
			return
		end
		-- Your time and the frames a second (the game's own, while it runs),
		-- under the pins.
		local shade = self:Box(0, 0, 0, 0.55, nil, "ARTWORK")
		shade:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 0, 0)
		shade:SetWidth(SIDE)
		shade:SetHeight(14 * ZOOM)
		local text, set = "12:00", true
		if SurvivorUI_ClockText then
			text, set = SurvivorUI_ClockText()
		end
		self:Word(SurvivorUI_FONT, (10 + FONT_BUMP) * ZOOM, "OUTLINE", 1, 1, 1, text..(set and "" or " |cff8a8a8aUTC|r")):SetPoint("LEFT", shade, "LEFT", 4 * ZOOM, 0)
		local strip = getglobal("SurvivorUIMinimapClock")
		local fps = strip and strip.fps and strip.fps:GetText()
		if not fps or fps == "" then
			fps = "|cff66ff6660|r |cff8a8a8afps|r"
		end
		self:Word(SurvivorUI_FONT, (10 + FONT_BUMP) * ZOOM, "OUTLINE", 1, 1, 1, fps):SetPoint("RIGHT", shade, "RIGHT", -4 * ZOOM, 0)
	end

	-- The sample's pins as MapPins.lua draws them, as the settings stand.
	local function Pins(db)
		local lair, flag = PinSize("lair"), SurvivorUI_GameFlag and SurvivorUI_GameFlag()
		for index = 1, table.getn(Paint.MAP_UNITS) do
			local unit = Paint.MAP_UNITS[index]
			local kind = unit[1]
			local x, y, size, alpha
			if kind == "cache" then
				if db.pinCaches ~= false then
					x, y, size, alpha = Reach(unit[2], unit[3], PinSize("cache"))
					if x then
						Put(ART.."PinCache", size * ZOOM, x * ZOOM, y * ZOOM, alpha)
					end
				end
			elseif (kind == "elite" and db.pinElites == true) or (kind ~= "elite" and db.pinBosses ~= false) then
				-- A boss's skull 4 larger than a lair's, an elite's 2 smaller.
				local base = lair + (kind == "elite" and -2 or 4)
				x, y, size, alpha = Reach(unit[2], unit[3], math.max(10, base))
				if x then
					if kind == "finalBoss" then
						Glow(base * 2.2 * ZOOM, 1, 0.5, 0, 0.8, x * ZOOM, y * ZOOM)
					end
					Put(ART..(kind == "elite" and "PinElite" or "PinBoss"), size * ZOOM, x * ZOOM, y * ZOOM, alpha)
				end
			end
		end
		if db.pinLairs == false then
			-- The game's flag stays with the lairs' pins off: it is the game's.
			if flag == "game" then
				Needs.GameFlag()
			end
			return
		end
		for index = 1, table.getn(Paint.MAP_LAIRS) do
			local spot = Paint.MAP_LAIRS[index]
			local empty = spot[4] == "empty"
			local x, y, size, alpha = spot[2], spot[3]
			if spot[4] == "awake" and db.pinFollow ~= false then
				x, y = spot[6], spot[7]
			end
			x, y, size, alpha = Reach(x, y, lair)
			if x and not (empty and db.pinEmpty == "hide") then
				x, y, size = x * ZOOM, y * ZOOM, size * ZOOM
				local pin = Lair(empty, size, x, y, alpha)
				if spot[5] and flag == "ours" then
					Glow(size * 2.4, 1, 0.82, 0.2, 0.75, x, y)
				elseif spot[5] and flag == "game" then
					Flag(x, y, size)
				end
				if empty and db.pinTimers then
					canvas:Word(SurvivorUI_FONT, (9 + FONT_BUMP) * ZOOM, "OUTLINE", 1, 1, 1, "1:30"):SetPoint("TOP", pin, "BOTTOM", 0, -ZOOM)
				end
			end
		end
	end

	-- A line beside the minimap, grey while off: its words, and where its
	-- small pin goes (x, y from the minimap's middle, as Put takes them).
	local function Key(self, column, row, rows, text, on)
		local x = column == 1 and 34 or midX + SIDE / 2 + 40
		local y = midY + (rows - 1) * 8 - (row - 1) * 16
		local shade = on and 0.85 or 0.5
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", shade, shade, shade + 0.02, text):SetPoint("LEFT", self, "TOPLEFT", x, y)
		return x - 12 - midX, y - midY
	end

	-- What each pin is: the lairs on the left, the rest on the right.
	local function Keys(self, db)
		local x, y
		local flag = SurvivorUI_GameFlag and SurvivorUI_GameFlag()
		if db.pinLairs == false then
			-- Off, but the game's own flag (when chosen) still on the flagged one.
			Key(self, 1, 1, 2, "Lairs: off", false)
			x, y = Key(self, 1, 2, 2, flag == "game" and "Flagged: the game's flag" or "Flagged: no mark", flag == "game")
			if flag == "game" then
				Flag(x, y, 12)
			end
		else
			x, y = Key(self, 1, 1, 4, "Guardian's lair", true)
			Lair(false, 12, x, y)
			local hidden = db.pinEmpty == "hide"
			x, y = Key(self, 1, 2, 4, hidden and "Empty lair: hidden" or (db.pinTimers and "Empty, back in 1:30" or "Empty lair, dimmed"), not hidden)
			Lair(true, 12, x, y, hidden and 0.4 or 1)
			x, y = Key(self, 1, 3, 4, flag == "ours" and "Flagged: our glow" or (flag == "game" and "Flagged: the game's flag" or "Flagged: no mark"),
				flag == "ours" or flag == "game")
			Lair(false, 12, x, y)
			if flag == "ours" then
				Glow(12 * 2.4, 1, 0.82, 0.2, 0.75, x, y)
			elseif flag == "game" then
				Flag(x, y, 12)
			end
			x, y = Key(self, 1, 4, 4, db.pinFollow ~= false and "Awake: where it goes" or "Awake: at its lair", true)
			Lair(false, 12, x, y)
		end
		local caches, bosses, elites, edge = db.pinCaches ~= false, db.pinBosses ~= false, db.pinElites == true, db.pinEdge ~= "hide"
		x, y = Key(self, 2, 1, 5, caches and "Cache" or "Caches: off", caches)
		Put(ART.."PinCache", 12, x, y, caches and 1 or 0.4)
		x, y = Key(self, 2, 2, 5, bosses and "Boss" or "Bosses: off", bosses)
		Put(ART.."PinBoss", 12, x, y, bosses and 1 or 0.4)
		x, y = Key(self, 2, 3, 5, bosses and "Final boss" or "Final boss: off", bosses)
		if bosses then
			Glow(12 * 2.2, 1, 0.5, 0, 0.8, x, y)
		end
		Put(ART.."PinBoss", 12, x, y, bosses and 1 or 0.4)
		x, y = Key(self, 2, 4, 5, elites and "Elite" or "Elites: off", elites)
		Put(ART.."PinElite", 12, x, y, elites and 1 or 0.4)
		-- Out of reach lit only while a pin of some kind shows.
		local reach = edge and Needs.Any()
		x, y = Key(self, 2, 5, 5, edge and "Out of reach: on the edge" or "Out of reach: hidden", reach)
		Put(ART.."PinCache", 8, x, y, reach and 0.7 or 0.3)
	end

	-- You in its middle, in a frame over the pins: the game's arrow (pale,
	-- the way the game points it: west at first, as in Elwynn), or ours
	-- (MapPins.lua's pieces) the way you last walked (north-east at first).
	function Paint.MinimapYou(self)
		local you = self.you
		if not you then
			you = CreateFrame("Frame", nil, self)
			you:SetAllPoints(self)
			you:SetFrameLevel(self.pins:GetFrameLevel() + 1)
			you.words, you.boxes = {}, {}
			you.Begin, you.Box, you.Word = self.Begin, self.Box, self.Word
			self.you = you
		end
		you:Begin()
		if not (SurvivorUI_HeroMarkerPieces and SurvivorUI_HeroMarker) then
			Put(ART.."PaceDot", 7 * ZOOM, 0, 0):SetVertexColor(1, 0.82, 0.2, 1)
			return
		end
		local choice, scale = SurvivorUI_HeroMarker()
		local way, r, g, b
		if choice == "game" then
			local _, _, facing = SurvivorUI_HeroWorld()
			way, choice, scale = facing or 1.5 * math.pi, "arrow", 0.9
			r, g, b = 0.86, 0.88, 0.92
		else
			way = SurvivorUI_HeroHeading() or 0.25 * math.pi
			r, g, b = SurvivorUI_HeroMarkerColor()
		end
		way = SurvivorUI_ArrowCellOf(way) * math.pi / 32
		local pieces = SurvivorUI_HeroMarkerPieces(choice, scale, way)
		for index = 1, table.getn(pieces) do
			local piece = pieces[index]
			local box
			if piece.dark then
				box = you:Box(0, 0, 0, 0.85, piece.art, "ARTWORK")
			else
				box = you:Box(r, g, b, 1, piece.art, "OVERLAY")
			end
			box:SetBlendMode("BLEND")
			if piece.way then
				box:SetTexCoord(SurvivorUI_ArrowCell(piece.way))
			end
			box:SetWidth(piece.width * ZOOM)
			box:SetHeight(piece.height * ZOOM)
			box:SetPoint("CENTER", you, "TOPLEFT", midX + piece.x * ZOOM, midY + piece.y * ZOOM)
		end
	end

	-- The pins in a frame of their own over the preview's, so that each sits
	-- over the minimap's ground and its clock whatever their layers.
	function Paint.Minimap(self)
		self:Begin()
		local top = self.pins
		if not top then
			top = CreateFrame("Frame", nil, self)
			top:SetAllPoints(self)
			top.words, top.boxes = {}, {}
			top.Begin, top.Box, top.Word = self.Begin, self.Box, self.Word
			self.pins = top
		end
		top:Begin()
		canvas = top
		midX, midY = math.floor(PAGE_WIDTH / 2), -math.floor(self:GetHeight() / 2)
		local db = DB()
		Ground(self, not SurvivorUI_Feature or SurvivorUI_Feature("minimap"))
		if not Needs.Pins() then
			-- The game's flag is back, unless Modules leaves it off.
			local flag = SurvivorUI_GameFlag and SurvivorUI_GameFlag() and not db.noGameFlag
			Key(self, 1, 1, flag and 2 or 1, "Pins on the minimap: off", false)
			if flag then
				Needs.GameFlag()
				local x, y = Key(self, 1, 2, 2, "Red flag: the game's", true)
				Flag(x, y, 12)
			end
		else
			Pins(db)
			Keys(self, db)
		end
		Paint.MinimapYou(self)
	end
	Kit.Preview(tab, SIDE + 20, Paint.Minimap)

	Kit.Section(tab, "Pins", "What a run puts on the minimap; hover one for what it is. A pin's tooltip, in the game, says what it is and how far.")
	Kit.Chips(tab, {
		{ "Pins on the minimap", FeatureOn("mapPins"), FeatureToggle("mapPins", true),
			"All of them at once: the same as Minimap pins in Modules. Off, the game's flag is back, unless The game's is unticked there." },
		{ "Lairs", OnUnlessOff("pinLairs"), Flip("pinLairs"), "A horned skull on each guardian's lair, bright while it holds it, dimmed once empty.",
			usable = Needs.Pins },
		{ "Lair timers", OnlyIfOn("pinTimers"), function() DB().pinTimers = not DB().pinTimers end,
			"Under an empty lair's pin, how long till its guardian is back.", usable = Needs.Timers },
		{ "Lairs follow their guardian", OnUnlessOff("pinFollow"), Flip("pinFollow"),
			"An awake guardian's pin goes where it goes, back to the lair once slain (the game's 0.139.2 on).", usable = Needs.Lairs },
		{ "Bosses", OnUnlessOff("pinBosses"), Flip("pinBosses"),
			"A horned skull on each boss, where it is, 4 px larger than a lair's; the final boss in an orange glow (the game's 0.139.2 on).",
			usable = Needs.Pins },
		{ "Elites", OnlyIfOn("pinElites"), function() DB().pinElites = not DB().pinElites end,
			"A bone skull on each elite, where it is, 2 px smaller than a lair's.", usable = Needs.Pins },
		{ "Caches", OnUnlessOff("pinCaches"), Flip("pinCaches"), "A chest for each one on the field.", usable = Needs.Pins },
	})
	Needs.Chips(7)

	Kit.Split(tab)
	Kit.Section(tab, "Empty lair", "A lair whose guardian is slain, until it is back: its pin dimmed, or hidden.")
	Needs.Row(Kit.Segments(tab, { { "dim", "Dimmed" }, { "hide", "Hidden" } },
		function() return DB().pinEmpty == "hide" and "hide" or "dim" end,
		function(value) DB().pinEmpty = value == "hide" and "hide" or nil end, Needs.Lairs), "Empty lair")
	Kit.Right(tab)
	Kit.Section(tab, "Out of reach", "On the edge: a pin past the minimap's reach sits on its edge, toward it, smaller and fainter. Hidden: only what it reaches.")
	Needs.Row(Kit.Segments(tab, { { "edge", "On the edge" }, { "hide", "Hidden" } },
		function() return DB().pinEdge == "hide" and "hide" or "edge" end,
		function(value) DB().pinEdge = value == "hide" and "hide" or nil end, Needs.Any), "Out of reach")
	Kit.Join(tab)

	Kit.Split(tab)
	Kit.Section(tab, "Red flag", "The game's flag on the lair to head for. Our glow: its skull glows gold on the minimap. The game's: its red flag. Off: neither. With the pins off (Modules), the game's flag is back, unless unticked there.")
	-- Our glow is on the lair's skull: still with the lairs' pins off.
	Needs.Row(Kit.Segments(tab, { { "ours", "Our glow" }, { "game", "The game's" }, { "none", "Off" } },
		function() return SurvivorUI_GameFlag and SurvivorUI_GameFlag() or "game" end,
		function(value)
			if SurvivorUI_SetGameFlag and (value ~= "ours" or Needs.Lairs()) then
				SurvivorUI_SetGameFlag(value)
			end
		end, Needs.Flag), "Red flag", "ours", Needs.Lairs, "Lairs are off: no skull to glow.")
	Kit.Right(tab)
	Kit.Section(tab, "Clock and FPS", "Along the square minimap's bottom: your time (a click on it sets the time zone) and the frames a second. It puts the game's own clock away. The round minimap has none.")
	Needs.Row(Kit.Segments(tab, { { "24", "24 hours" }, { "12", "12 hours" }, { "off", "Off" } },
		function()
			if DB().minimapClock == false then
				return "off"
			end
			return DB().clock12 and "12" or "24"
		end,
		function(value)
			if value == "off" then
				DB().minimapClock = false
			else
				DB().minimapClock = nil
				DB().clock12 = value == "12" or nil
			end
			if SurvivorUI_GameHud and SurvivorUI_GameHud.localClock then
				SurvivorUI_GameHud.localClock()
			end
		end, Needs.Square), "Clock and FPS")
	Kit.Join(tab)

	-- You on the minimap (MapPins.lua): the game's arrow, or ours in its
	-- place, across the page; on the section's line its color (one of the
	-- range ring's) and its size (S M L, as Kit.Size has them). Color and size
	-- faded and still while the game's arrow is chosen; all of it on a game
	-- without Minimap:SetPlayerModel.
	do
		local function Ours()
			return SurvivorUI_HeroMarker and SurvivorUI_HeroMarker() ~= "game"
		end
		local top = tab.y - 4
		Kit.Section(tab, "You on the minimap", "Your marker in its middle. The game's arrow keeps one way as you walk (where the camera looks); ours in its place: a dot, a dot with a small arrow the way you walk, an arrow the way you walk, or a cross. On this line its color (your class's at first) and its size. North is up on the minimap.")
		Needs.Row(Kit.Segments(tab, { { "game", "The game's" }, { "dot", "Dot" }, { "dotArrow", "Dot + arrow" }, { "arrow", "Arrow" }, { "cross", "Cross" } },
			function() return SurvivorUI_HeroMarker and SurvivorUI_HeroMarker() or "game" end,
			function(value) if SurvivorUI_SetHeroMarker then SurvivorUI_SetHeroMarker("look", value) end end,
			Needs.Marker), "You on the minimap")
		local color = tab.color
		local x, width = Span(tab)
		x = x + width
		for index = 3, 1, -1 do
			local button = CreateFrame("Button", nil, tab)
			button:SetWidth(26)
			button:SetHeight(18)
			x = x - 26
			button:SetPoint("TOPLEFT", tab, "TOPLEFT", x, top + 4)
			x = x - 4
			Boxed(button, WELL, EDGE)
			button.text = Text(button, 9, TEXT)
			button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
			button.text:SetText(({ "S", "M", "L" })[index])
			button.value = ({ 0.75, 1, 1.35 })[index]
			button:SetScript("OnClick", function()
				if Ours() then
					SurvivorUI_SetHeroMarker("size", this.value)
					RefreshAll()
				end
			end)
			button:SetScript("OnEnter", function()
				this.hot = true
				this:Refresh()
				if not Ours() then
					Needs.Tip(this, "Marker size", "Only for ours: the game's arrow is chosen.")
				end
			end)
			button:SetScript("OnLeave", function() this.hot = nil this:Refresh() GameTooltip:Hide() end)
			function button:Refresh()
				self:SetAlpha(Ours() and 1 or 0.4)
				local _, scale = 1, 1
				if SurvivorUI_HeroMarker then
					_, scale = SurvivorUI_HeroMarker()
				end
				local on = math.abs(scale - self.value) < 0.01
				if on then
					self:SetBackdropColor(color[1] * 0.26, color[2] * 0.26, color[3] * 0.26, 1)
					self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
				else
					self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
					local edge = self.hot and 0.45 or EDGE[1]
					self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
				end
				if self.hot then
					self.text:SetTextColor(1, 1, 1)
				elseif on then
					self.text:SetTextColor(Kit.Light(color))
				else
					self.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
				end
			end
			table.insert(widgets, button)
		end
		side.Index(tab, "Marker size", "you hero marker arrow dot size small medium large", top, 18)

		-- The colors, a row ending 16 before the S.
		local list = SurvivorUI_RANGE_COLORS or {}
		local left = x + 4 - 16 - (table.getn(list) * 24 - 6)
		for index = 1, table.getn(list) do
			local swatch = CreateFrame("Button", nil, tab)
			swatch.key, swatch.name, swatch.tint = list[index][1], list[index][2], list[index][3]
			swatch:SetWidth(18)
			swatch:SetHeight(ROW)
			swatch:SetPoint("TOPLEFT", tab, "TOPLEFT", left + (index - 1) * 24, top + 5)
			swatch.edge = Fill(swatch, "BORDER", 0.3, 0.3, 0.35, 1)
			swatch.edge:SetWidth(18)
			swatch.edge:SetHeight(18)
			swatch.edge:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, -1)
			swatch.fill = Fill(swatch, "ARTWORK", 1, 1, 1, 1)
			swatch.fill:SetPoint("TOPLEFT", swatch.edge, "TOPLEFT", 2, -2)
			swatch.fill:SetPoint("BOTTOMRIGHT", swatch.edge, "BOTTOMRIGHT", -2, 2)
			swatch:SetScript("OnClick", function()
				if Ours() then
					SurvivorUI_SetHeroMarker("color", this.key)
					RefreshAll()
				end
			end)
			swatch:SetScript("OnEnter", function()
				this.hot = true
				this:Refresh()
				GameTooltip:SetOwner(this, "ANCHOR_TOP")
				GameTooltip:SetText(SurvivorUI_OT(this.name), 1, 1, 1)
				if not Ours() then
					GameTooltip:AddLine(SurvivorUI_OT("Only for ours: the game's arrow is chosen."), MUTED[1], MUTED[2], MUTED[3], 1)
				end
				GameTooltip:Show()
			end)
			swatch:SetScript("OnLeave", function()
				this.hot = nil
				this:Refresh()
				GameTooltip:Hide()
			end)
			function swatch:Refresh()
				self:SetAlpha(Ours() and 1 or 0.4)
				if self.tint then
					self.fill:SetVertexColor(self.tint[1], self.tint[2], self.tint[3], 1)
				else
					self.fill:SetVertexColor(Paint.HeroColor())
				end
				local chosen = (DB().heroMarkerColor or "class") == self.key
				if chosen then
					self.edge:SetVertexColor(1, 1, 1, 1)
				elseif self.hot then
					self.edge:SetVertexColor(0.7, 0.7, 0.75, 1)
				else
					self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
				end
				self.fill:SetAlpha((chosen or self.hot) and 1 or 0.75)
			end
			table.insert(widgets, swatch)
		end
		side.Index(tab, "Marker color", "you hero marker class light blue gold white red orange green teal purple pink", top, 18)
	end

	-- The pins' sizes: the lairs' sizes the bosses' and the elites' too
	-- (MapPins.lua: 4 larger, 2 smaller).
	-- Still while what they need is off (Needs.Size).
	local function SetPin(kind, usable)
		return function(value)
			if SurvivorUI_SetPinSize and usable() then
				SurvivorUI_SetPinSize(kind, math.floor(value + 0.5))
			end
		end
	end
	local PIN_SIZES = { { "S", 12 }, { "M", 16 }, { "L", 20 } }
	Kit.Split(tab)
	Kit.Size(tab, "Lair and boss pins", 10, 28, 1, function() return PinSize("lair") end, SetPin("lair", Needs.Skulls), PIN_SIZES, "%d px")
	Needs.Size("Lair and boss pins", Needs.Skulls)
	Kit.Right(tab)
	Kit.Size(tab, "Cache pins", 10, 28, 1, function() return PinSize("cache") end, SetPin("cache", Needs.Caches), PIN_SIZES, "%d px")
	Needs.Size("Cache pins", Needs.Caches)
	Kit.Join(tab)

	Kit.Split(tab)
	Kit.Size(tab, "Minimap size", 0.5, 2, 0.05,
		function() return SurvivorUI_GetScale and SurvivorUI_GetScale("minimap") or 1 end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("minimap", value) end end,
		{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Right(tab)
	Kit.Link(tab, "Its buttons, in", "mapbuttons")
	Kit.Link(tab, "Your range ring on it, in", "range")
	Kit.Join(tab)

	Kit.Foot(tab, { reset = Asked("Minimap back to default?",
		"Every pin on but the elites and the lair timers, an empty lair dimmed, pins out of reach on the edge, our glow on the flagged lair, the clock in 24 hours, the game's arrow in the middle, the first sizes. The square minimap and Pins on the minimap stay, and where it stands: Back to its place for that.", "Back to default",
		function()
			local db = DB()
			local keys = { "pinLairs", "pinEmpty", "pinTimers", "pinFollow", "pinBosses", "pinElites", "pinCaches", "pinEdge", "minimapClock", "clock12",
				"heroMarkerSize", "heroMarkerColor" }
			for index = 1, table.getn(keys) do
				db[keys[index]] = nil
			end
			if SurvivorUI_SetHeroMarker then
				SurvivorUI_SetHeroMarker("look", "game")
			end
			if SurvivorUI_SetPinSize then
				SurvivorUI_SetPinSize("lair", 16)
				SurvivorUI_SetPinSize("cache", 16)
			end
			if SurvivorUI_SetGameFlag then
				SurvivorUI_SetGameFlag("ours")
			end
			if SurvivorUI_GameHud and SurvivorUI_GameHud.localClock then
				SurvivorUI_GameHud.localClock()
			end
			if SurvivorUI_SetPartScale then
				SurvivorUI_SetPartScale("minimap", 1)
			end
		end) })
end

------------------------------------------------------------------------------
-- Minimap buttons (MinimapButton.lua): which show, their order, each one's
-- color, the way they line up, their size and the gap between them.

-- Made with the kit: the preview draws them as the game will, beside a corner
-- of the minimap; under it a row each, in their order, with its arrows, its
-- switch and, for the three switches, its key; then the colors of the one
-- picked (a click on its row, or on its square in the preview).

-- A key of the game's (Bindings.xml) in a small box: a click, then the key; a
-- right click clears it. Command() names the binding; with none, it hides.
function Kit.Key(parent, color, Command)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(84)
	button:SetHeight(20)
	Boxed(button, WELL, EDGE)
	button.label = Text(button, 9, TEXT)
	button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function()
		local command = Command()
		if arg1 == "RightButton" then
			local old = GetBindingKey and GetBindingKey(command)
			if old then
				SetBinding(old)
				SaveBindings(GetCurrentBindingSet())
			end
			keyCapture:Hide()
		else
			keyCapture.command = command
			keyCapture:Show()
		end
		RefreshAll()
	end)
	button:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(SurvivorUI_OT("Its key"), 1, 1, 1)
		GameTooltip:AddLine(SurvivorUI_OT("Click, then press the key (Alt, Ctrl or Shift with it if you like). Escape leaves it as it was; a right click clears it. Key Bindings in the game's menu lists it as well."), 0.8, 0.8, 0.8, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	function button:Refresh()
		local command = Command()
		if not command then
			self:Hide()
			return
		end
		self:Show()
		local waiting = keyCapture:IsShown() and keyCapture.command == command
		local key = GetBindingKey and GetBindingKey(command)
		if waiting then
			self.label:SetText("Press a key...")
			self.label:SetTextColor(color[1], color[2], color[3])
		elseif key then
			self.label:SetText(key)
			self.label:SetTextColor(1, 1, 1)
		else
			self.label:SetText("No key")
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
		if waiting or self.hot then
			self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
		else
			self:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], 1)
		end
	end
	table.insert(widgets, button)
	return button
end

page = pages.mapbuttons
Kit.Head(page, { line = "The squares beside the minimap: which show, their order, each one's color and the way they line up. While this tab is open, drag them to move them all." })

do
	local tab = page
	local color = tab.color
	-- Each one in its first order: its key, its name for the search, its line
	-- in its row (what it does).
	local BUTTONS = {
		{ "options", "Survivor UI button", "Click: these options. Right click: move the UI." },
		{ "history", "Run History button", "Your runs, each as it ended." },
		{ "effects", "Spell effects button", "No explosions, missiles, glows or beams, in a click." },
		{ "sound", "Sound effects button", "Mutes spells, hits and clicks; the music stays." },
		{ "range", "Range indicator button", "Your range on the minimap and round you." },
		{ "guide", "Guide button", "How the game's numbers work; a ! with a page unread." },
	}
	local LINES = {}
	for index = 1, table.getn(BUTTONS) do
		LINES[BUTTONS[index][1]] = BUTTONS[index][3]
	end
	local picked                       -- the key whose colors show under the rows

	local function Order()
		return SurvivorUI_MapButtonOrder and SurvivorUI_MapButtonOrder() or {}
	end

	local function Info(key)
		return key and SurvivorUI_MapButtonInfo and SurvivorUI_MapButtonInfo(key)
	end

	-- The one picked: the first one until a click picks another.
	local function Picked()
		if not Info(picked) then
			picked = Order()[1]
		end
		return picked
	end

	local function Pick(key)
		picked = key
		RefreshAll()
	end

	-- The shown ones as the game lines them up, beside the minimap's corner
	-- (its bottom left; its top left, down), as large as the room lets up to
	-- half again their size: each its edge, its icon in its color (dimmed
	-- while off) or the Guide's fill and mark, its place in the order beside
	-- it, a white ring round the one picked. A click on one picks it.
	function Paint.MapButtons(self)
		self:Begin()
		self.hits = self.hits or {}
		for index = 1, table.getn(self.hits) do
			self.hits[index]:Hide()
		end
		local way = DB().mapButtonWay or "up"
		local size, gap = DB().mapButtonSize or 16, DB().mapButtonGap or 5
		local order, shown = Order(), {}
		for index = 1, table.getn(order) do
			local info = Info(order[index])
			if info and info.shown then
				info.key = order[index]
				table.insert(shown, info)
			end
		end
		local count = table.getn(shown)
		local height = self:GetHeight()
		local mapX, mapSide = 330, 100
		local mapTop = way == "down" and -8 or -(height - 8 - mapSide)
		local edge = self:Box(0, 0, 0, 1, nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", mapX - 1, mapTop + 1)
		edge:SetWidth(mapSide + 2)
		edge:SetHeight(mapSide + 2)
		local map = self:Box(0.20, 0.26, 0.13, 1, nil, "BORDER")
		map:SetPoint("TOPLEFT", self, "TOPLEFT", mapX, mapTop)
		map:SetWidth(mapSide)
		map:SetHeight(mapSide)
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", 0.45, 0.55, 0.35, "Minimap"):SetPoint("CENTER", map, "CENTER", 0, 0)
		if count == 0 then
			self:Word(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3],
				"None shown: /sui opens these options"):SetPoint("RIGHT", map, "LEFT", -16, 0)
			return
		end
		local column = way == "up" or way == "down"
		local length = count * size + (count - 1) * gap
		local zoom = math.min(1.5, ((column and height or mapX) - 20) / length)
		local s, g, off = size * zoom, gap * zoom, 5 * zoom
		local x, y, stepX, stepY = mapX - off - s, mapTop - mapSide + s, 0, s + g
		if way == "down" then
			y, stepY = mapTop, -(s + g)
		elseif way == "left" then
			stepX, stepY = -(s + g), 0
		elseif way == "right" then
			x, stepX, stepY = mapX - off - length * zoom, s + g, 0
		end
		for index = 1, count do
			local info = shown[index]
			local left, top = x + (index - 1) * stepX, y + (index - 1) * stepY
			if info.key == Picked() then
				local ring = self:Box(1, 1, 1, 1, nil, "BACKGROUND")
				ring:SetPoint("TOPLEFT", self, "TOPLEFT", left - 2, top + 2)
				ring:SetWidth(s + 4)
				ring:SetHeight(s + 4)
			end
			local rim = self:Box(0, 0, 0, 1, nil, "BORDER")
			rim:SetPoint("TOPLEFT", self, "TOPLEFT", left - 1, top + 1)
			rim:SetWidth(s + 2)
			rim:SetHeight(s + 2)
			local icon = self:Box(info.r * info.dim, info.g * info.dim, info.b * info.dim, 1, info.icon)
			icon:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
			icon:SetWidth(s)
			icon:SetHeight(s)
			if info.mark then
				self:Word("Fonts\\FRIZQT__.TTF", 13 * s / 16, "", 0.13, 0.08, 0, info.mark):SetPoint("CENTER", icon, "CENTER", 0, 0)
			end
			local number = self:Word(SurvivorUI_FONT, 8 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], tostring(index))
			if column then
				number:SetPoint("RIGHT", icon, "LEFT", -5, 0)
			else
				number:SetPoint("BOTTOM", icon, "TOP", 0, 5)
			end
			local hit = self.hits[index]
			if not hit then
				hit = CreateFrame("Button", nil, self)
				hit:SetScript("OnClick", function() Pick(this.key) end)
				hit:SetScript("OnEnter", function()
					GameTooltip:SetOwner(this, "ANCHOR_TOP")
					GameTooltip:SetText(SurvivorUI_OT(this.title), 1, 1, 1)
					GameTooltip:AddLine(SurvivorUI_OT("Click: its color, under the buttons"), 0.8, 0.8, 0.8)
					GameTooltip:Show()
				end)
				hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
				self.hits[index] = hit
			end
			hit.key, hit.title = info.key, info.title
			hit:ClearAllPoints()
			hit:SetPoint("TOPLEFT", self, "TOPLEFT", left, top)
			hit:SetWidth(s)
			hit:SetHeight(s)
			hit:Show()
		end
	end
	Kit.Preview(tab, 160, Paint.MapButtons)

	-- An arrow that moves its row's button a step toward the first (up) or
	-- the last.
	local function Arrow(row, earlier)
		local arrow = CreateFrame("Button", nil, row)
		arrow:SetWidth(20)
		arrow:SetHeight(20)
		arrow.wash = Fill(arrow, "BACKGROUND", color[1], color[2], color[3], 0)
		arrow.wash:SetAllPoints(arrow)
		arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
		arrow.icon:SetTexture(ART.."DropArrow")
		arrow.icon:SetWidth(10)
		arrow.icon:SetHeight(10)
		arrow.icon:SetPoint("CENTER", arrow, "CENTER", 0, 0)
		if earlier then
			arrow.icon:SetTexCoord(0, 1, 1, 0)
		end
		arrow.by = earlier and -1 or 1
		arrow:SetScript("OnClick", function()
			local slot = this:GetParent().slot
			local order = Order()
			if order[slot] and order[slot + this.by] and SurvivorUI_MoveMapButton then
				picked = order[slot]
				SurvivorUI_MoveMapButton(order[slot], this.by)
			end
			RefreshAll()
		end)
		arrow:SetScript("OnEnter", function() this.wash:SetVertexColor(color[1], color[2], color[3], 0.25) end)
		arrow:SetScript("OnLeave", function() this.wash:SetVertexColor(color[1], color[2], color[3], 0) end)
		return arrow
	end

	-- A row each, its button as the order has it at that place.
	local function Row(slot)
		local row = CreateFrame("Button", nil, tab)
		row.slot = slot
		row:SetWidth(PAGE_WIDTH)
		row:SetHeight(28)
		row:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, tab.y)
		row.wash = Fill(row, "BACKGROUND", color[1], color[2], color[3], 0)
		row.wash:SetAllPoints(row)
		row.number = Text(row, 9, MUTED)
		row.number:SetPoint("LEFT", row, "LEFT", 6, 0)
		row.edge = Fill(row, "BORDER", 0, 0, 0, 1)
		row.edge:SetWidth(20)
		row.edge:SetHeight(20)
		row.edge:SetPoint("LEFT", row, "LEFT", 22, 0)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("TOPLEFT", row.edge, "TOPLEFT", 1, -1)
		row.icon:SetPoint("BOTTOMRIGHT", row.edge, "BOTTOMRIGHT", -1, 1)
		row.mark = row:CreateFontString(nil, "OVERLAY")
		row.mark:SetFont("Fonts\\FRIZQT__.TTF", 14)
		row.mark:SetTextColor(0.13, 0.08, 0)
		row.mark:SetPoint("CENTER", row.edge, "CENTER", 0, 0)
		row.name = Text(row, 10, TEXT)
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -2)
		row.line = Text(row, 8, MUTED)
		row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
		-- Its controls, over the row: the key, the arrows, the switch.
		row.key = Kit.Key(row, color, function()
			local info = Info(Order()[row.slot])
			return info and info.binding
		end)
		row.key:SetPoint("RIGHT", row, "RIGHT", -132, 0)
		row.earlier = Arrow(row, true)
		row.earlier:SetPoint("LEFT", row.key, "RIGHT", 4, 0)
		row.later = Arrow(row, false)
		row.later:SetPoint("LEFT", row.earlier, "RIGHT", 2, 0)
		row.switch = Kit.Switch(tab, PAGE_WIDTH - 72, tab.y - 4, function()
			local info = Info(Order()[row.slot])
			return info and info.shown
		end, function()
			local key = Order()[row.slot]
			if key and SurvivorUI_ShowMapButton then
				SurvivorUI_ShowMapButton(key)
			end
		end)
		row.switch:SetFrameLevel(row:GetFrameLevel() + 2)
		row:SetScript("OnClick", function() Pick(Order()[this.slot]) end)
		row:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
		row:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
		function row:Refresh()
			local order = Order()
			local key = order[self.slot]
			local info = Info(key)
			if not info then
				self:Hide()
				self.switch:Hide()
				return
			end
			self:Show()
			self.switch:Show()
			local on = key == Picked()
			self.wash:SetVertexColor(color[1], color[2], color[3], on and 0.16 or (self.hot and 0.06 or 0))
			self.number:SetText(tostring(self.slot))
			self.edge:SetVertexColor(on and 1 or 0, on and 1 or 0, on and 1 or 0, 1)
			if info.icon then
				self.icon:SetTexture(info.icon)
				self.icon:SetVertexColor(info.r * info.dim, info.g * info.dim, info.b * info.dim)
				self.mark:Hide()
			else
				self.icon:SetTexture(FLAT)
				self.icon:SetVertexColor(info.r, info.g, info.b)
				self.mark:SetText(info.mark or "?")
				self.mark:Show()
			end
			self.icon:SetAlpha(info.shown and 1 or 0.35)
			self.mark:SetAlpha(info.shown and 1 or 0.35)
			self.name:SetText(info.title)
			if info.shown then
				self.name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			else
				self.name:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
			if key == "options" and not info.shown then
				self.line:SetText("Hidden: /sui still opens these options.")
			else
				self.line:SetText(LINES[key] or "")
			end
			self.earlier:SetAlpha(self.slot > 1 and 1 or 0.3)
			self.later:SetAlpha(order[self.slot + 1] and 1 or 0.3)
		end
		table.insert(widgets, row)
		side.Index(tab, BUTTONS[slot][2], BUTTONS[slot][3], tab.y, 28)
		tab.y = tab.y - 30
	end

	Kit.Section(tab, "Buttons", "In their order from the first, the one by the minimap's corner. The arrows move one; its switch shows or hides it; a click on a row picks it for the colors under them.")
	for slot = 1, table.getn(BUTTONS) do
		Row(slot)
	end

	-- A color for the one picked, its name after the section's: the class's
	-- first, then the others (MinimapButton.lua's, read as they refresh: it
	-- loads after this file); at the right, every button in it.
	tab.y = tab.y - 4
	local head = Kit.Section(tab, "Color", "The picked button's: the class's (the addon's own color: gold if the Global tab says so) or one of these. All in this color: every button in it.")
	local which = CreateFrame("Frame", nil, tab)
	which:SetWidth(1)
	which:SetHeight(1)
	which:SetPoint("LEFT", head, "RIGHT", 28, 0)
	which.text = Text(which, 9, TEXT)
	which.text:SetPoint("LEFT", which, "LEFT", 0, 0)
	function which:Refresh()
		local info = Info(Picked())
		if info then
			self.text:SetText(info.title)
			self.text:SetTextColor(Kit.Light({ info.r, info.g, info.b }, 0.2))
		else
			self.text:SetText("")
		end
	end
	table.insert(widgets, which)
	for index = 1, 10 do
		local swatch = CreateFrame("Button", nil, tab)
		swatch.index = index
		swatch:SetWidth(18)
		swatch:SetHeight(ROW)
		swatch:SetPoint("TOPLEFT", tab, "TOPLEFT", (index - 1) * 24, tab.y)
		swatch.edge = Fill(swatch, "BORDER", 0.3, 0.3, 0.35, 1)
		swatch.edge:SetWidth(18)
		swatch.edge:SetHeight(18)
		swatch.edge:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, -1)
		swatch.fill = Fill(swatch, "ARTWORK", 1, 1, 1, 1)
		swatch.fill:SetPoint("TOPLEFT", swatch.edge, "TOPLEFT", 2, -2)
		swatch.fill:SetPoint("BOTTOMRIGHT", swatch.edge, "BOTTOMRIGHT", -2, 2)
		swatch:SetScript("OnClick", function()
			if this.key and SurvivorUI_SetMapButtonColor and Picked() then
				SurvivorUI_SetMapButtonColor(Picked(), this.key)
			end
			RefreshAll()
		end)
		swatch:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(SurvivorUI_OT(this.name or ""), 1, 1, 1)
			GameTooltip:Show()
		end)
		swatch:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		function swatch:Refresh()
			local entry = SurvivorUI_MAPBUTTON_COLORS and SurvivorUI_MAPBUTTON_COLORS[self.index]
			if not entry then
				self:Hide()
				return
			end
			self:Show()
			self.key, self.name = entry[1], entry[2]
			local tint = entry[3] or ACCENT
			self.fill:SetVertexColor(tint[1], tint[2], tint[3], 1)
			local info = Info(Picked())
			local chosen = info and info.color == self.key
			if chosen then
				self.edge:SetVertexColor(1, 1, 1, 1)
			elseif self.hot then
				self.edge:SetVertexColor(0.7, 0.7, 0.75, 1)
			else
				self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
			end
			self.fill:SetAlpha((chosen or self.hot) and 1 or 0.75)
		end
		table.insert(widgets, swatch)
	end
	local all = Kit.Quiet(tab, "All in this color", 130, function()
		local info = Info(Picked())
		if info and SurvivorUI_SetMapButtonColor then
			SurvivorUI_SetMapButtonColor(nil, info.color)
		end
		RefreshAll()
	end)
	all:SetPoint("TOPLEFT", tab, "TOPLEFT", PAGE_WIDTH - 130, tab.y + 2)
	side.Index(tab, "Color", "class color gold white red orange green teal blue purple pink all", tab.y, ROW)
	tab.y = tab.y - ROW - 10

	-- How they line up, their size and the gap: the buttons and the preview
	-- follow each.
	local function Follow(set)
		return function(value)
			set(value)
			if SurvivorUI_PlaceMapButtons then
				SurvivorUI_PlaceMapButtons()
			end
			if tab.preview then
				tab.preview:Refresh()
			end
		end
	end
	Kit.Split(tab)
	Kit.Section(tab, "Line up", "From the first, the one by the minimap's corner: up and down in a column, left and right in a row. The first one stays where it is.")
	-- Left and right as the way the row grows ("@grow:"), apart from a side's
	-- (the party's buffs) in another language.
	Kit.Segments(tab, { { "up", "Up" }, { "down", "Down" }, { "left", "@grow:Left" }, { "right", "@grow:Right" } },
		function() return DB().mapButtonWay or "up" end,
		Follow(function(way) DB().mapButtonWay = way ~= "up" and way or nil end))
	Kit.Right(tab)
	Kit.Size(tab, "Size", 12, 28, 1, function() return DB().mapButtonSize or 16 end,
		Follow(function(value)
			value = math.floor(value + 0.5)
			DB().mapButtonSize = value ~= 16 and value or nil
		end), { { "S", 14 }, { "M", 16 }, { "L", 20 } }, "%d")
	Kit.Join(tab)
	local y = tab.y
	Kit.Stepper(tab, "Gap", 0, 12, 1, function() return DB().mapButtonGap or 5 end,
		Follow(function(value) DB().mapButtonGap = value ~= 5 and value or nil end), "%d px")
	local back = Kit.Quiet(tab, "Back to its place", 140, function()
		if SurvivorUI_ResetPiece then
			SurvivorUI_ResetPiece("Minimap buttons")
		end
	end)
	back:SetPoint("TOPLEFT", tab, "TOPLEFT", PAGE_WIDTH - 140, y)
	side.Index(tab, "Back to its place", "reset place position", y, 24)

	Kit.Foot(tab, { reset = Asked("Minimap buttons back to default?",
		"All of them shown, in their first order and colors, lined up upward at the first size and gap. Where they stand stays: Back to its place for that.", "Back to default",
		function()
			if SurvivorUI_ResetMapButtons then
				SurvivorUI_ResetMapButtons()
			end
			picked = nil
		end) })
end

------------------------------------------------------------------------------
-- Chat.

-- Reworked (the kit): the looks as pictures, the filter as chips.

page = pages.chat
Kit.Head(page, { line = "The chat window, flat (Flat chat): its look, its text's size, and what reaches it.",
	isOn = FeatureOn("chat"), toggle = FeatureToggle("chat"), reloads = true, piece = "Chat" })

-- The two looks, each a small picture: the panel, its tabs along its top
-- and the copy button; the lines alone on the world, the addon's color down
-- their left edge.
function Paint.Panel(tile, ground)
	Kit.Dab(tile, ground, 36, 23, 60, 30, 0.03, 0.03, 0.04, 0.95)
	-- The addon's color, painted again as it changes (a class told late).
	local tab = Kit.Dab(tile, ground, 14, 9, 14, 4, ACCENT[1], ACCENT[2], ACCENT[3])
	table.insert(accented, function() tab:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
	Kit.Dab(tile, ground, 30, 9, 14, 4, 0.4, 0.4, 0.45)
	Kit.Dab(tile, ground, 62, 9, 5, 4, 0.75, 0.75, 0.8)
	Kit.Dab(tile, ground, 26, 18, 40, 2, 0.85, 0.85, 0.88)
	Kit.Dab(tile, ground, 22, 24, 32, 2, 0.6, 0.85, 1)
	Kit.Dab(tile, ground, 29, 30, 46, 2, 0.85, 0.85, 0.88)
end
function Paint.World(tile, ground)
	local edge = Kit.Dab(tile, ground, 8, 23, 2, 26, ACCENT[1], ACCENT[2], ACCENT[3])
	table.insert(accented, function() edge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
	Kit.Dab(tile, ground, 32, 14, 40, 2, 0.95, 0.95, 0.97)
	Kit.Dab(tile, ground, 28, 21, 32, 2, 0.6, 0.85, 1)
	Kit.Dab(tile, ground, 35, 28, 46, 2, 0.95, 0.95, 0.97)
	Kit.Dab(tile, ground, 26, 35, 28, 2, 1, 0.82, 0.3)
end
Kit.Section(page, "Look", "Panel: one dark panel holds the chat, the windows as tabs along its top (right-click a tab for its menu), the copy button at its top right, the typing box under it. Text on the world: the lines alone, a dark backing behind them as dark as Background chooses, the addon's color down their left edge.")
Kit.Tiles(page, {
	{ "panel", "Panel", "Tabs on top, a copy button", Paint.Panel },
	{ "text", "Text on the world", "The lines alone, as before", Paint.World },
}, function() return SurvivorUI_ChatLook and SurvivorUI_ChatLook() or "panel" end,
	function(look) if SurvivorUI_SetChatLook then SurvivorUI_SetChatLook(look) end end)

Kit.Split(page)
Kit.Section(page, "Text size")
Kit.Stepper(page, nil, 8, 18, 1,
	function() return SurvivorUI_ChatSize and SurvivorUI_ChatSize() or 8 end,
	function(value) if SurvivorUI_SetChatSize then SurvivorUI_SetChatSize(value) end end, "%d pt")
Kit.Right(page)
-- The look's own: each look keeps its strength.
Kit.Section(page, "Background", "How dark behind the lines. Text on the world: 0% is the text alone.")
do
	local left, width = Span(page)
	Kit.Bar(page, left, page.y - 3, width, 0, 100, 5,
		function() return math.floor((SurvivorUI_ChatBackground and SurvivorUI_ChatBackground() or 0) * 100 + 0.5) end,
		function(value) if SurvivorUI_SetChatBackground then SurvivorUI_SetChatBackground(value / 100) end end, "%d%%")
	page.y = page.y - 30
end
Kit.Join(page)
Kit.Chips(page, {
	{ "Locked", function() return SurvivorUI_ChatLocked and SurvivorUI_ChatLocked() end,
		function() if SurvivorUI_SetChatLocked then SurvivorUI_SetChatLocked(not SurvivorUI_ChatLocked()) end end,
		"The Panel look's panel alone: no tabs, no copy button, no grip, no edges. Unlocked, it moves and sizes again." },
})

Kit.Section(page, "Kept out of the chat", "What a run fills the chat with, kept away, in every language; the alerts stay: a new spell, an upgrade's news, the run's end. New lines only.")
Kit.Chips(page, {
	{ "Level-ups", OnUnlessOff("chatFilterLevels"), Flip("chatFilterLevels"), "\"You have reached level 12\" and its gains: the XP bar shows the level." },
	{ "Banners", OnUnlessOff("chatFilterBanners"), Flip("chatFilterBanners"), "The horde's moves, a boss or a guardian coming or slain, shown mid-screen by the game. Keep them in the chat if the game's Show Banners is off." },
	{ "Boss yells", OnUnlessOff("chatFilterYells"), Flip("chatFilterYells"), "\"Hogger yells: Grrr... fresh meat!\"" },
	{ "Loot", OnUnlessOff("chatFilterLoot"), Flip("chatFilterLoot"), "While the loot list is on: the list has it." },
	{ "Combat Log", OnUnlessOff("chatFilterCombat"), Flip("chatFilterCombat"), "The Combat Log window, fed 13 lines a second, opened or not; SurvivorUI reads the fight from the game's own events, never from it." },
})

------------------------------------------------------------------------------
-- Experimental (a group of its own, Lucas, 2026-11-04): what is tried out
-- before it settles somewhere. Each page its own block.

-- Tracker Ring: the run tracker as a dial (Dial.lua, Tracker.lua's look).

-- Made with the kit: its switch puts the run tracker in the Dial's look (the
-- Run tracker tab keeps the Classic lines' own settings and those both
-- share). The preview draws the dial as Dial.lua lays it out, at its size and
-- text size, the run on now or a sample; a click on it shows a boss alive (the
-- next, as it will look: its mark pulsing, its name under the clock; no boss
-- health on the Dial, Lucas, 2026-11-04) or the run exploring. Beside it the
-- Dial's own (its ring, its compass and the compass's distance) and its size;
-- under them the Dial's own tags (the difficulty and the affixes, always
-- short, each shown or off, apart from the Classic lines' looks) and the
-- looks both share (the coin, the elites).
do
	local tab, TR, DL = pages.dial, Paint.TrackerTR, {}
	Kit.Head(tab, { line = "The run tracker as a round dial: the whole run its ring, each boss a mark on it (pulsing while alive), the time to the next inside it, the guardians' compass under it. In the tracker's place, at its size; off, the Classic lines.",
		isOn = function() return DB().trackerLook == "dial" end,
		toggle = function() DB().trackerLook = DB().trackerLook ~= "dial" and "dial" or nil end, piece = "Run tracker" })
	-- Movable while the tab is open, as in the Run tracker tab.
	TAB_PIECES.dial = { "Run tracker" }

	-- Dial.lua's sizes: the tiles TALL with the distance, SHORT without, the
	-- arrow at HUB from a tile's top, the distance at FOOT from its foot, a
	-- tile its words' width and PAD, ROOM more while the row has it.
	DL.D = { R = 82, TOP = 8, OUT = 72, THIN = 62, THIN_INNER = 60.5, RIM = 81, CLOCK = 7, GAP = 8, DOT = 64 / 60, LABEL = 91,
		TALL = 34, SHORT = 24, HUB = 12, FOOT = 8, PAD = 8, ROOM = 2, TILE_GAP = 6, ARROW = 20 }
	DL.C = {
		green = { 0.40, 0.88, 0.48 }, endless = { 0.70, 0.40, 1.00 }, track = { 0.14, 0.19, 0.125 },
		orange = { 1.00, 0.60, 0.24 }, orangeTrack = { 0.20, 0.16, 0.09 }, violet = { 0.72, 0.52, 1.00 }, red = { 1.00, 0.35, 0.28 },
		clockTrack = { 0.22, 0.12, 0.11 }, doneEdge = { 0.36, 0.42, 0.32 }, tick = { 0.61, 0.83, 0.54 },
		dueEdge = { 0.43, 0.42, 0.38 }, markFill = { 0.045, 0.05, 0.04 }, nextFill = { 0.10, 0.07, 0.03 },
		upFill = { 0.11, 0.06, 0.15 }, text = { 0.95, 0.945, 0.91 }, muted = { 0.60, 0.61, 0.56 },
		label = { 1.00, 0.75, 0.50 }, gold = { 1.00, 0.82, 0.30 }, goldDim = { 0.62, 0.56, 0.44 },
		bossName = { 0.85, 0.76, 1.00 }, finalName = { 1.00, 0.75, 0.50 }, lives = { 1.00, 0.50, 0.50 },
		disc = { 0.055, 0.07, 0.047 }, discEdge = { 0.18, 0.23, 0.16 }, discBoss = { 0.07, 0.05, 0.085 }, discBossEdge = { 0.23, 0.165, 0.28 },
		upBack = { 0.045, 0.10, 0.05 }, upEdge = { 0.24, 0.70, 0.32 }, upArrow = { 0.45, 1.00, 0.52 }, upText = { 0.55, 0.92, 0.58 },
		awakeBack = { 0.114, 0.075, 0.035 }, awakeText = { 1.00, 0.75, 0.50 },
		slainBack = { 0.055, 0.055, 0.06 }, slainEdge = { 0.22, 0.22, 0.24 }, slainText = { 1.00, 0.38, 0.32 },
	}

	----------------------------------------------------------------------------
	-- The preview's pieces: the disc and its rings on the preview's layers,
	-- the marks and tags a level up (TR.Up), its words over all (DL.Word).

	function DL.Begin(self)
		TR.Begin(self)
		local pool = self.dialText
		if not pool then
			pool = CreateFrame("Frame", nil, self)
			pool:SetAllPoints(self)
			pool:SetFrameLevel(self:GetFrameLevel() + 3)
			pool.words = {}
			self.dialText = pool
		end
		pool.used = 0
		for index = 1, table.getn(pool.words) do
			pool.words[index]:Hide()
		end
	end

	function DL.Word(self, size, flags, color, text)
		local pool = self.dialText
		pool.used = pool.used + 1
		local word = pool.words[pool.used]
		if not word then
			word = SurvivorUI_Spoken(pool:CreateFontString(nil, "OVERLAY"))
			pool.words[pool.used] = word
		end
		word:SetFont(SurvivorUI_FONT, math.max(6, math.floor(size + FONT_BUMP + TR.step + 0.5)), flags or "OUTLINE")
		word:SetTextColor(color[1], color[2], color[3])
		word:SetText(text or "")
		word:ClearAllPoints()
		word:Show()
		return word
	end

	function DL.Put(self, size, flags, color, text, x, y)
		local word = DL.Word(self, size, flags, color, text)
		word:SetPoint("CENTER", self, "TOPLEFT", x, y)
		return word
	end

	-- Words at cx, cy + y inside a ring's inner edge: the first size that
	-- fits, else the last made short, tail whole after them (Dial.lua's FitIn).
	function DL.Fit(self, sizes, flags, color, text, cx, cy, y, inner, tail)
		local word
		for index = 1, table.getn(sizes) do
			if word then
				word:Hide()
			end
			word = DL.Word(self, sizes[index], flags, color, text..(tail or ""))
			local tall = word:GetHeight() > 0 and word:GetHeight() or sizes[index]
			local room = SurvivorUI_DialRoom and SurvivorUI_DialRoom(inner, y, tall) or 90
			if word:GetStringWidth() <= room or index == table.getn(sizes) then
				if SurvivorUI_DialShorten then
					SurvivorUI_DialShorten(word, text, room, tail)
				end
				word:SetPoint("CENTER", self, "TOPLEFT", cx, cy + y)
				return word
			end
		end
	end

	-- A texture a level up, centered at x, y, so big.
	function DL.UpAt(self, r, g, b, a, texture, layer, x, y, size)
		local box = TR.Up(self, r, g, b, a, texture, layer)
		box:SetBlendMode("BLEND")
		box:SetWidth(size)
		box:SetHeight(size)
		box:SetPoint("CENTER", self, "TOPLEFT", x, y)
		return box
	end

	-- A ring round cx, cy (Dial.lua's): its track, the whole ring in one quad
	-- (low), and its fill from the top clockwise to share, two half quads
	-- (high), each the half ring turned (SurvivorUI_DialHalf).
	function DL.Ring(self, cx, cy, kind, radius, share, color, track, low, high)
		if not (SurvivorUI_DIAL_RINGS and SurvivorUI_DialHalf) then
			return
		end
		local q, art = SurvivorUI_DialQuad(kind, radius), SurvivorUI_DIAL_RINGS[kind].file
		if track then
			local whole = TR.Box(self, track[1], track[2], track[3], 1, art, low, nil, nil, 2 * q, 2 * q)
			whole:SetTexCoord(0.14645, 0.85355, 0.14645, 0.85355)
			whole:SetPoint("CENTER", self, "TOPLEFT", cx, cy)
		end
		share = math.max(0, math.min(1, share or 0))
		if share < 0.002 then
			return
		end
		local right = TR.Box(self, color[1], color[2], color[3], 1, share <= 0.5 and art.."Half" or art, high, nil, nil, q, 2 * q)
		SurvivorUI_DialHalf(right, q, 1, share <= 0.5 and share - 0.5 or 0)
		right:SetPoint("TOPLEFT", self, "TOPLEFT", cx, cy + q)
		if share > 0.5 then
			local left = TR.Box(self, color[1], color[2], color[3], 1, share >= 0.998 and art or art.."Half", high, nil, nil, q, 2 * q)
			SurvivorUI_DialHalf(left, q, -1, share >= 0.998 and 0 or share - 0.5)
			left:SetPoint("TOPRIGHT", self, "TOPLEFT", cx, cy + q)
		end
	end

	-- The run as the Dial reads it: the boss alive (asked for one, boss, with
	-- none: the next, as it will look; the sample's own, a long name, at 9:20),
	-- the next to come, the second the last came (the boss alive's).
	function DL.Model(boss)
		local m = TR.Model()
		local bosses = m.bosses or {}
		if m.sample then
			for index = 1, table.getn(bosses) do
				if bosses[index].state == "up" then
					bosses[index].state, bosses[index].fell = "dead", 395
				end
			end
			if boss and bosses[3] then
				m.seconds = 560
				bosses[3].state = "up"
			end
		end
		m.up, m.next, m.prevAt = nil, nil, 0
		for index = 1, table.getn(bosses) do
			local state = m.endless and "dead" or bosses[index].state or "due"
			if state == "up" and not m.up then
				m.up = index
			elseif state == "due" and not m.next then
				m.next = index
			end
			if not m.next and state ~= "due" then
				m.prevAt = tonumber(bosses[index].at) or 0
			end
		end
		if boss and not m.up and m.next then
			m.up, m.sampledBoss = m.next, true
			bosses[m.up].state = "up"
			m.prevAt = tonumber(bosses[m.up].at) or m.prevAt
			m.next = nil
			for index = m.up + 1, table.getn(bosses) do
				if not m.next and (bosses[index].state or "due") == "due" then
					m.next = index
				end
			end
		end
		m.final = m.up and bosses[m.up].final or nil
		m.length = m.length or 0
		return m
	end

	function DL.RingColor(m)
		if m.endless then
			return DL.C.endless
		end
		if DB().trackerDialRing == "class" and SurvivorUI_ClassColor and UnitClass then
			local _, class = UnitClass("player")
			if class then
				local r, g, b = SurvivorUI_ClassColor(class)
				return { r, g, b }
			end
		end
		return DL.C.green
	end

	-- The disc, its rim and its rings: the run's, then the next boss's
	-- countdown, a boss alive or not; the disc a shade of violet while one is.
	function DL.Rings(self, m, cx, cy)
		local d, c, boss = DL.D, DL.C, m.up ~= nil
		local size = 2 * (d.R - 0.5) * d.DOT
		local fill = boss and c.discBoss or c.disc
		TR.Box(self, fill[1], fill[2], fill[3], 0.93, ART.."HeroDot", "BACKGROUND", nil, nil, size, size):SetPoint("CENTER", self, "TOPLEFT", cx, cy)
		DL.Ring(self, cx, cy, "thin", d.RIM, 0, nil, boss and c.discBossEdge or c.discEdge, "BORDER")
		DL.Ring(self, cx, cy, "main", d.OUT, m.endless and 1 or (m.length > 0 and (m.seconds or 0) / m.length or 0), DL.RingColor(m),
			c.track, "ARTWORK", "OVERLAY")
		if m.next and m.phase ~= "victory" and m.phase ~= "dead" then
			local at = tonumber(m.bosses[m.next].at) or 0
			local span = at - m.prevAt
			DL.Ring(self, cx, cy, "thin", d.THIN, span > 0 and (at - (m.seconds or 0)) / span or 0, c.orange, c.orangeTrack, "ARTWORK", "OVERLAY")
		end
	end

	-- Each boss's mark on the outer ring (Dial.lua's PaintMark): the next lit,
	-- a boss alive or not, its second by it; one alive in violet (orange the
	-- final boss), pulsing (its pieces in dialPulses, the preview's OnUpdate).
	function DL.Marks(self, m, cx, cy)
		local d, c = DL.D, DL.C
		if m.length <= 0 then
			return
		end
		for index = 1, table.getn(m.bosses) do
			local boss = m.bosses[index]
			local at = tonumber(boss.at) or 0
			local turn = 2 * math.pi * math.min(1, at / m.length)
			local state = (index == m.up and "up") or (index == m.next and "next") or (m.endless and "dead") or boss.state or "due"
			local x, y = cx + d.OUT * math.sin(turn), cy + d.OUT * math.cos(turn)
			local lit = (state == "next" and c.orange) or (state == "up" and (boss.final and c.orange or c.violet)) or nil
			-- A boss alive's pieces, for its pulse: the glow first.
			local pulse = {}
			if lit then
				local glow = DL.UpAt(self, lit[1], lit[2], lit[3], 0.8, ART.."PaceGlow", "BACKGROUND", x, y, boss.final and 40 or 32)
				glow:SetBlendMode("ADD")
				table.insert(pulse, { glow, boss.final and 40 or 32 })
			end
			if boss.final then
				local shade = state == "dead" and 0.45 or 1
				table.insert(pulse, { DL.UpAt(self, shade, shade, shade, state == "dead" and 0.8 or 1, ART.."PinBoss", "ARTWORK", x, y, lit and 21 or 18), 21 })
			else
				local edge = lit or (state == "dead" and c.doneEdge) or c.dueEdge
				local fill = (state == "next" and c.nextFill) or (state == "up" and c.upFill) or c.markFill
				local size = lit and 14 or 12
				table.insert(pulse, { DL.UpAt(self, edge[1], edge[2], edge[3], 1, ART.."HeroDot", "BORDER", x, y, size * d.DOT), size * d.DOT })
				table.insert(pulse, { DL.UpAt(self, fill[1], fill[2], fill[3], 1, ART.."HeroDot", "ARTWORK", x, y, (size - 3.4) * d.DOT), (size - 3.4) * d.DOT })
				if lit then
					table.insert(pulse, { DL.UpAt(self, lit[1], lit[2], lit[3], 1, ART.."HeroDot", "OVERLAY", x, y, 5 * d.DOT), 5 * d.DOT })
				end
			end
			if state == "up" then
				table.insert(self.dialPulses, { pulse, lit })
			end
			if state == "dead" then
				DL.UpAt(self, c.tick[1], c.tick[2], c.tick[3], 1, ART.."Tick", "OVERLAY", boss.final and x + 6 or x, boss.final and y - 5 or y, 9)
			end
			if state == "next" and math.cos(turn) > -0.75 then
				local side = math.sin(turn)
				local point = (side > 0.3 and "LEFT") or (side < -0.3 and "RIGHT") or "CENTER"
				DL.Word(self, 9, "OUTLINE", c.label, TR.Clock(at)):SetPoint(point, self, "TOPLEFT", cx + d.LABEL * side, cy + d.LABEL * math.cos(turn))
			end
		end
	end

	-- The run's tags in a row of their own over the clock, together in the
	-- middle and always short (Dial.lua's Tags): the difficulty's N or
	-- numeral and endless mode's symbol, the affixes' symbols; each side
	-- shown or off by the Dial's own Difficulty and Affixes.
	function DL.Tags(self, m, cx, y)
		local db = DB()
		local shown = db.trackerDialDifficulty ~= false
		local row, heroic = {}, shown and tonumber(m.heroic)
		if heroic then
			table.insert(row, { kind = heroic > 0 and "heroic" or "normal", text = SurvivorUI_HeroicShort and SurvivorUI_HeroicShort(heroic) or tostring(heroic) })
		end
		if m.endless and shown then
			table.insert(row, { kind = "endless", symbol = ART.."Endless" })
		end
		local affixes = db.trackerDialAffixes ~= false and m.affixes or {}
		for index = 1, table.getn(affixes) do
			local affix = affixes[index]
			table.insert(row, { kind = "affix", text = not affix.symbol and SurvivorUI_T(affix.name or "?") or nil, symbol = affix.symbol })
		end
		local wide = -3
		for index = 1, table.getn(row) do
			local tag = row[index]
			tag.width = 13
			if tag.text then
				tag.word = DL.Word(self, 9, "", TR.TAG[tag.kind], tag.text)
				tag.width = math.max(13, math.floor(tag.word:GetStringWidth() + 8.5))
			end
			wide = wide + tag.width + 3
		end
		local x = math.floor(cx - wide / 2 + 0.5)
		for index = 1, table.getn(row) do
			local tag = row[index]
			local color = TR.TAG[tag.kind]
			local edge = TR.Up(self, color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1, FLAT, "BORDER")
			edge:SetWidth(tag.width)
			edge:SetHeight(13)
			edge:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
			local wash = TR.Up(self, color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 1, FLAT, "ARTWORK")
			wash:SetWidth(tag.width - 2)
			wash:SetHeight(11)
			wash:SetPoint("TOPLEFT", self, "TOPLEFT", x + 1, y - 1)
			if tag.word then
				tag.word:SetPoint("CENTER", self, "TOPLEFT", x + tag.width / 2, y - 6.5)
			else
				DL.UpAt(self, color[1], color[2], color[3], 1, tag.symbol, "OVERLAY", x + tag.width / 2, y - 6.5, 9)
			end
			x = x + tag.width + 3
		end
	end

	-- The middle (Dial.lua's Middle): the tags, the clock big, "of 16:00", and
	-- under them the run's end, a boss alive's name (fitted to the circle), or
	-- the next boss with the time until it comes.
	function DL.Middle(self, m, cx, cy)
		local c, d, phase = DL.C, DL.D, m.phase
		DL.Tags(self, m, cx, cy + 40)
		local grey = (phase == "paused" or phase == "choosing") and 0.6 or 1
		DL.Put(self, 28, "THICKOUTLINE", { c.text[1] * grey, c.text[2] * grey, c.text[3] * grey }, TR.Clock(m.seconds or 0), cx, cy + 8)
		local length = m.endless and SurvivorUI_T("Endless") or (m.length > 0 and SurvivorUI_TF("of {1}", TR.Clock(m.length)) or "")
		if phase == "paused" or phase == "choosing" then
			length = SurvivorUI_T(phase == "paused" and "Paused" or "Choosing")
		end
		DL.Put(self, 10, "OUTLINE", m.endless and c.endless or c.muted, length, cx, cy - 14)
		local name, line, color = nil, nil, c.orange
		if phase == "victory" then
			line, color = SurvivorUI_T("Victory"), { 0.30, 0.85, 0.30 }
		elseif phase == "dead" then
			line, color = SurvivorUI_T("Fallen"), { 1, 0.25, 0.25 }
		elseif m.up then
			-- Its health after its name: the run's boss's own, a sample's 63%.
			local up, share = m.bosses[m.up], ""
			local hp, hpm = tonumber(up.hp), tonumber(up.hpm)
			if hp and hpm and hpm > 0 then
				share = " "..math.floor(hp / hpm * 100 + 0.5).."%"
			elseif m.sample or m.sampledBoss then
				share = " 63%"
			end
			DL.Fit(self, { 10, 9 }, "OUTLINE", m.final and c.finalName or c.bossName, SurvivorUI_OT(up.name or "?"), cx, cy, -32, d.THIN_INNER, share)
			return
		elseif m.next then
			local boss = m.bosses[m.next]
			name, line = boss.name or "?", SurvivorUI_TF("in {1}", TR.Clock((tonumber(boss.at) or 0) - (m.seconds or 0)))
		end
		if not line then
			return
		end
		local word = DL.Put(self, 10, "OUTLINE", color, name and name.." "..line or line, cx, cy - 32)
		local room = SurvivorUI_DialRoom and SurvivorUI_DialRoom(d.THIN_INNER, -32, word:GetHeight() > 0 and word:GetHeight() or 10) or 90
		if name and word:GetStringWidth() > room then
			word:Hide()
			DL.Fit(self, { 10, 9 }, "OUTLINE", color, name, cx, cy, -30, d.THIN_INNER)
			DL.Put(self, 10, "OUTLINE", color, line, cx, cy - 43)
		end
	end

	-- The corners: the cache's coin and its price, the elites alive, the
	-- lives left.
	function DL.Corners(self, m, x0, y0)
		local db, c, d = DB(), DL.C, DL.D
		if db.trackerCoin == true and (m.cost or 0) > 0 then
			local pays = (m.gold or 0) >= m.cost
			local shade = pays and 1 or 0.42
			DL.UpAt(self, shade, shade, shade, 1, ART.."Coin", "ARTWORK", x0 + 12, y0 - 10, 18)
			if pays and db.trackerCoinShine ~= false then
				DL.UpAt(self, 1, 0.78, 0.20, 0.7, ART.."PaceGlow", "BACKGROUND", x0 + 12, y0 - 10, 49):SetBlendMode("ADD")
			end
			DL.Word(self, 11, "OUTLINE", pays and c.gold or c.goldDim, SurvivorUI_Abbrev and SurvivorUI_Abbrev(m.cost) or m.cost)
				:SetPoint("LEFT", self, "TOPLEFT", x0 + 24, y0 - 10)
		end
		local e = m.elites
		if db.trackerElites ~= false and e and not (e.total == 0 and db.trackerElitesHide) then
			local shade = e.total > 0 and 1 or 0.45
			DL.UpAt(self, 0.40 * shade, 0.88 * shade, 0.48 * shade, 1, ART.."Pip", "ARTWORK", x0 + TR.WIDTH - 9, y0 - 10, 12)
			DL.Word(self, 11, "OUTLINE", e.hurt > 0 and { 1, 1, 1 } or { 0.40 * shade, 0.88 * shade, 0.48 * shade }, e.total)
				:SetPoint("RIGHT", self, "TOPLEFT", x0 + TR.WIDTH - 19, y0 - 10)
		end
		local lives = m.lives or 0
		if lives > 0 then
			DL.Word(self, 9, "OUTLINE", c.lives, SurvivorUI_TF(lives == 1 and "{1} life left" or "{1} lives left", lives))
				:SetPoint("LEFT", self, "TOPLEFT", x0 + 2, y0 - (d.TOP + 2 * d.R - 8))
		end
	end

	-- The widest of some words at size, as the preview's words measure them
	-- (at the run tracker's text size).
	function DL.Widest(self, size, list)
		local most = 0
		for index = 1, table.getn(list) do
			local word = DL.Word(self, size, "OUTLINE", DL.C.text, list[index])
			most = math.max(most, word:GetStringWidth() or 0)
			word:Hide()
		end
		return most
	end

	-- The guardians' compass under the disc, a tile a lair (Dial.lua's Compass
	-- and PaintTile): green while up, orange in a fight (its health where the
	-- arrow stands), grey and dim slain (its clock, or with the distance off
	-- its wait); tall, how far along its foot. Each tile as wide as it needs,
	-- ROOM more while the row has it, each row in the middle.
	function DL.Compass(self, m, x0, y)
		local d, c = DL.D, DL.C
		local lairs = m.lairs or {}
		local count = table.getn(lairs)
		if DB().guardians == false or DB().trackerDialCompass == false or count == 0 then
			return
		end
		local tall = DB().trackerDialYards ~= false
		local high, gap = tall and d.TALL or d.SHORT, d.TILE_GAP
		local most = DL.Widest(self, 10, tall and { "100%" } or { "100%", "0:00", SurvivorUI_T("soon") })
		if tall then
			most = math.max(most, DL.Widest(self, 9, { SurvivorUI_TF("{1} yd", 888), "0:00", SurvivorUI_T("soon") }))
		end
		local need = math.ceil(math.max(d.ARROW, most)) + d.PAD
		local perRow = count
		if count > 6 or count * need + (count - 1) * gap > TR.WIDTH then
			perRow = math.ceil(count / 2)
		end
		local each = math.floor(math.min(need + d.ROOM, (TR.WIDTH - (perRow - 1) * gap) / perRow))
		local top = y - d.GAP
		for index = 1, count do
			local lair = lairs[index]
			local column, line = math.mod(index - 1, perRow), math.floor((index - 1) / perRow)
			local inRow = math.min(perRow, count - line * perRow)
			local x = x0 + math.floor((TR.WIDTH - inRow * each - (inRow - 1) * gap) / 2 + 0.5) + column * (each + gap)
			local ty = top - line * (high + gap)
			local empty, awake = lair.state == "empty", lair.state == "awake"
			local back, edge, text = c.upBack, c.upEdge, c.upText
			if empty then
				back, edge, text = c.slainBack, c.slainEdge, c.slainText
			elseif awake then
				back, edge, text = c.awakeBack, c.orange, c.awakeText
			end
			TR.Box(self, edge[1], edge[2], edge[3], 1, nil, "BACKGROUND", x, ty, each, high)
			TR.Box(self, back[1], back[2], back[3], 1, nil, "BORDER", x + 1, ty - 1, each - 2, high - 2)
			local hx, hy = x + each / 2, ty - d.HUB
			local big, foot
			if empty then
				local left = lair.left or -1
				local wait = left > 0 and TR.Clock(left, true) or SurvivorUI_T("soon")
				if tall then
					local full = math.max(left, SurvivorUI_DialSpan and SurvivorUI_DialSpan(lair.place) or 0, 120)
					DL.Ring(self, hx, hy, "small", d.CLOCK, left > 0 and left / full or 0, c.red, c.clockTrack, "ARTWORK", "OVERLAY")
					foot = wait
				else
					big = wait
				end
			else
				big = awake and lair.share and string.format("%d%%", lair.share * 100 + 0.5) or nil
				foot = tall and lair.yards and SurvivorUI_TF("{1} yd", math.floor(lair.yards + 0.5)) or nil
				if not big and lair.angle then
					TR.Arrow(self, hx, hy, lair.angle, 16, awake and c.orange or c.upArrow)
				end
			end
			if big then
				DL.Put(self, 10, "OUTLINE", text, big, hx, hy)
			end
			if foot then
				DL.Put(self, 9, "OUTLINE", text, foot, hx, ty - high + d.FOOT)
			end
		end
	end

	function Paint.Dial(self)
		DL.Begin(self)
		self.dialPulses = {}
		local m, d = DL.Model(self.dialBoss), DL.D
		local x0, y0 = math.floor((self:GetWidth() - TR.WIDTH) / 2), -16
		local cx, cy = x0 + TR.WIDTH / 2, y0 - d.TOP - d.R
		TR.step = 0
		-- The click's hint, but for a boss of the run's own alive; clear of
		-- LIVE PREVIEW in a wide face (Friz Quadrata).
		if not (m.up and not m.sample and not m.sampledBoss) then
			local x = self.tag and math.max(74, math.floor(self.tag:GetStringWidth() + 14.5)) or 74
			DL.Word(self, 8, "", { 0.55, 0.66, 0.50 }, self.dialBoss and "click: exploring" or "click: a boss alive"):SetPoint("TOPLEFT", self, "TOPLEFT", x, -6)
		end
		if m.sample or m.sampleTags then
			DL.Word(self, 8, "", MUTED, m.sample and "A sample run" or "Sample tags"):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		end
		TR.step = SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Run tracker") or 0
		DL.Rings(self, m, cx, cy)
		DL.Marks(self, m, cx, cy)
		DL.Middle(self, m, cx, cy)
		DL.Corners(self, m, x0, y0)
		DL.Compass(self, m, x0, y0 - d.TOP - 2 * d.R)
	end

	----------------------------------------------------------------------------
	-- The settings: the preview at the left, the Dial's own beside it; under
	-- them the Dial's own tags, then the looks the Classic lines share (the
	-- Run tracker tab's too).

	function DL.CompassOn()
		return DB().guardians ~= false and DB().trackerDialCompass ~= false
	end

	Kit.Split(tab)
	do
		local preview = Kit.Preview(tab, 238, Paint.Dial)
		preview:SetWidth(tab.width)
		-- The run's clock goes on: drawn again each second, a boss alive's
		-- mark pulsing each frame (Dial.lua's SurvivorUI_DialPulse); a click
		-- shows a boss alive, or the run exploring.
		preview:SetScript("OnUpdate", function()
			this.wait = (this.wait or 0) + arg1
			if this.wait >= 1 then
				this.wait = 0
				this:Refresh()
			end
			if SurvivorUI_DialPulse then
				for _, pulse in pairs(this.dialPulses or {}) do
					SurvivorUI_DialPulse(pulse[1], pulse[2])
				end
			end
		end)
		preview:EnableMouse(true)
		preview:SetScript("OnMouseUp", function()
			this.dialBoss = not this.dialBoss or nil
			this:Refresh()
		end)
	end
	Kit.Right(tab)
	Kit.Section(tab, "Ring", "The outer ring, the whole run filling clockwise from the top: green, or your class's color. Purple in endless mode.")
	Kit.Segments(tab, { { "green", "Green" }, { "class", "Class color" } },
		function() return DB().trackerDialRing == "class" and "class" or "green" end,
		function(look) DB().trackerDialRing = look == "class" and "class" or nil end)
	Kit.Section(tab, "Compass", "Under the dial, a tile a lair: an arrow toward it and how far. Green while its guardian is up, orange in a fight with its health in % where the arrow stands, grey and dim while slain, a red clock emptying until it is back. Each tile as small as what it holds. Hover a tile for its guardian, click a living one to target it. It stands in for the guardians' bar, and for their list while it hangs under the tracker.")
	Kit.Chips(tab, {
		{ "Compass", DL.CompassOn, function()
				if DL.CompassOn() then
					DB().trackerDialCompass = false
				else
					DB().trackerDialCompass, DB().guardians = nil, true
				end
			end,
			"The guardians under the dial. Off: none in the Tracker Ring (a list chosen in the Run tracker tab hangs under it)." },
		{ "Distance", OnUnlessOff("trackerDialYards"), Flip("trackerDialYards"),
			"How far each lair is, under its arrow. Off: the tiles shorter, a slain one's wait in place of its clock; the distance still under the mouse.",
			usable = DL.CompassOn, why = "The compass is off." },
		{ "North up", OnlyIfOn("guardiansNorth"), Call("SurvivorUI_ToggleGuardians", "north"),
			"The arrows point north up, as the minimap does. Off: they turn with you, straight up straight ahead.",
			usable = DL.CompassOn, why = "The compass is off." },
	})
	Kit.Size(tab, "Size", 0.5, 2, 0.05,
		function() return SurvivorUI_GetScale and SurvivorUI_GetScale("tracker") or 1 end,
		function(value) if SurvivorUI_SetPartScale then SurvivorUI_SetPartScale("tracker", value) end end,
		{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Section(tab, "Text size", "The dial's words, a step at a time: the run tracker's, as in its tab.")
	Kit.Stepper(tab, nil, -4, 8, 1, TR.StepGet("Run tracker"), TR.StepSet("Run tracker"), TR.StepText)
	Kit.Join(tab)

	-- The Dial's own tags: shown or off, always short (no room for words in
	-- the circle); the Run tracker tab's looks stay the Classic lines'.
	Kit.Section(tab, "Difficulty and affixes", "The tags over the clock, together in the middle and always short: the difficulty (N, or the Heroic level's numeral), endless mode's symbol, the week's affixes by their symbols. Under the mouse, each in full. The Dial's own: the Run tracker tab sets the Classic lines'.")
	Kit.Chips(tab, {
		{ "Difficulty", OnUnlessOff("trackerDialDifficulty"), Flip("trackerDialDifficulty"),
			"The run's difficulty, and endless mode's symbol once the run goes on past its end. Off: away from the Tracker Ring." },
		{ "Affixes", OnUnlessOff("trackerDialAffixes"), Flip("trackerDialAffixes"),
			"The week's affixes, a Heroic run's from III (one) and V (two). Off: away from the Tracker Ring." },
	})
	-- The looks both share, as in the Run tracker tab.
	Kit.Split(tab)
	Kit.Section(tab, "Coin", "At the top left, with the next cache's price: gold and shining while you can pay for it, dim while not.")
	Kit.Chips(tab, {
		{ "Cache coin", OnlyIfOn("trackerCoin"), function() DB().trackerCoin = not DB().trackerCoin end,
			"At the dial's top left: gold when you can pay for the next cache, dim when not, its price beside it." },
		{ "Coin shines", OnUnlessOff("trackerCoinShine"), Flip("trackerCoinShine"),
			"While you can pay, the Cache coin shines.", usable = OnlyIfOn("trackerCoin"), why = "Cache coin is off." },
	})
	Kit.Right(tab)
	Kit.Section(tab, "Elites", "At the top right: a green diamond and how many elites are alive, white once one is hurt.")
	Kit.Switch(tab, (tab.left or 0) + tab.width - 62, tab.y + 20, OnUnlessOff("trackerElites"), Flip("trackerElites"))
	Kit.Chips(tab, {
		{ "Hide when none", OnlyIfOn("trackerElitesHide"), function() DB().trackerElitesHide = not DB().trackerElitesHide end,
			"With no elite alive, the diamond goes." },
	})
	Kit.Join(tab)
	Kit.Link(tab, "The rest of the run tracker, and the Classic lines, in", "tracker")

	Kit.Foot(tab, { reset = Asked("Tracker Ring back to default?",
		"Its ring green, its compass on with the distance, its difficulty and affixes shown. The Dial stays on or off as it is; the looks both share go back in the Run tracker tab.",
		"Back to default", function()
			local db = DB()
			db.trackerDialRing, db.trackerDialCompass, db.trackerDialYards = nil, nil, nil
			db.trackerDialDifficulty, db.trackerDialAffixes = nil, nil
		end) })
end

-- No backgrounds: the windows' backgrounds taken away, each on its own.
-- Asked for to see the screen with the Tracker Ring (Lucas, 2026-11-04). The
-- switch (noBackgrounds, nil off) takes every window's dark ground away at
-- once; a window's chip off keeps its own (noBackgroundsOff[key]). Each
-- window reads the two itself and paints its ground in SurvivorUI_Grounds,
-- called here as the world loads and at every change: live, no reload. The
-- rows' own fills, the words, the icons and the bars stay; with the switch
-- off every window looks as before. Its words already wear an outline (the
-- chat's lines a shadow), so none is added. No pieces move from this tab:
-- the move outlines would hide the look it is there to show.
do
	local tab = pages.nobg
	local WINDOWS = {
		{ "build", "Build list", "Its dark ground goes. The spells' rows keep their color fills and the empty slots their faint ones; the title, the count and the columns' names stay.",
			look = "fill", colors = { { 0.25, 0.55, 1 }, { 0.95, 0.50, 0.10 }, { 0.65, 0.35, 0.90 } } },
		{ "worn", "Jewelry worn", "Its dark ground goes. Each slot's row keeps its quality's fill and edge, as the Jewelry worn tab sets them; the title stays.",
			look = "fill", colors = { { 1, 0.50, 0 }, { 0.64, 0.21, 0.93 }, { 0.12, 1, 0 } } },
		{ "meter", "Damage meter", "The shade behind the bars goes, on its extra windows too. The bars keep their dark base and their color; the title, its menu and the NOW, DPS and TOTAL strip stay.",
			look = "share", colors = { { 0.93, 0.70, 0.15 }, { 0.85, 0.20, 0.25 }, { 0.25, 0.45, 0.95 } } },
		{ "crits", "Biggest Crits", "Its dark ground goes. The crits keep their colored rows; the title, Reset and the strip of Damage, Crit and Crit Dmg stay.",
			look = "share", colors = { { 0.30, 0.75, 0.30 }, { 0.95, 0.40, 0.70 }, { 0.15, 0.70, 0.70 } } },
		{ "loot", "Loot list", "Its dark ground and the title's band go, whatever Background behind the list says (Loot list tab). Each piece keeps its quality's fill; the title and the marks stay.",
			look = "fill", colors = { { 0.64, 0.21, 0.93 }, { 0, 0.44, 0.87 }, { 0.12, 1, 0 } } },
		{ "run", "This Run", "Its dark ground goes. Each row keeps its faint wash and its line in its own color; the titles stay.",
			look = "faint", colors = { { 0.40, 0.85, 1 }, { 1, 0.86, 0.35 }, { 0.55, 0.85, 0.55 } } },
		{ "stats", "Stats panel", "The Stats panel's dark ground goes, while the panel is on; its groups' names and rows stay, washed in their group's color. The character pane's own numbers keep the pane's ground.",
			look = "faint", colors = { { 0.72, 0.45, 1 }, { 1, 0.40, 0.40 }, { 0.30, 0.65, 1 } },
			usable = function() return DB().noBackgrounds == true and SurvivorUI_StatsPanel ~= nil and SurvivorUI_StatsPanel() end,
			why = "Turn No backgrounds on first, with the switch at the top, and the Stats panel (its tab)." },
		{ "chat", "Chat", "With the Panel look, its dark ground, its edges and the line under the tabs go: the lines on the world, as with Text on the world. The tabs, the copy button, the corner grip and the typing box stay; Background (Chat tab) waits until this is off. Text on the world has no panel: it keeps its own Background as set.",
			look = "text", colors = { { 0.92, 0.92, 0.92 }, { 0.60, 0.85, 1 }, { 1, 0.82, 0.30 } } },
	}

	local function On()
		return DB().noBackgrounds == true
	end
	local function Bare(key)
		return On() and not (DB().noBackgroundsOff and DB().noBackgroundsOff[key])
	end
	-- Every window paints its ground again (BuildList.lua, Meter.lua,
	-- MeterWindows.lua, RunPanel.lua, LootLog.lua, CharacterPane.lua,
	-- Chat.lua): at every change, and as the world loads, the settings read.
	local function Apply()
		for _, Ground in pairs(SurvivorUI_Grounds or {}) do
			Ground()
		end
	end
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("PLAYER_ENTERING_WORLD")
	loader:SetScript("OnEvent", Apply)

	Kit.Head(tab, { line = "The windows without their dark ground: their words, icons and bars right on the world, to see the screen with the Tracker Ring. Each window below can keep its own.",
		isOn = On, toggle = function()
			DB().noBackgrounds = not On() or nil
			Apply()
		end })

	-- The eight windows small, on a patch of world: each one's ground drawn
	-- while it keeps it, then its title and three rows in its own manner
	-- (filled rows, bars on a dark base, faint washes, lines of chat).
	local EACH, TALL = math.floor((PAGE_WIDTH - 28 - 30) / 4), 42
	function Paint.NoBackgrounds(self)
		self:Begin()
		local world = self:Box(0.20, 0.27, 0.15, 1, nil, "BACKGROUND")
		world:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -16)
		world:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -6, 6)
		for index = 1, table.getn(WINDOWS) do
			local window = WINDOWS[index]
			local x = 14 + math.mod(index - 1, 4) * (EACH + 10)
			local y = -22 - math.floor((index - 1) / 4) * (TALL + 6)
			if not Bare(window[1]) then
				local ground = self:Box(0.04, 0.04, 0.07, 0.55, nil, "BORDER")
				ground:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
				ground:SetWidth(EACH)
				ground:SetHeight(TALL)
			end
			self:Word(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE", 1, 0.82, 0, window[2]):SetPoint("TOPLEFT", self, "TOPLEFT", x + 4, y - 4)
			for line = 1, 3 do
				local color, top, width = window.colors[line], y - 15 - (line - 1) * 9, EACH - 8
				if window.look == "text" then
					local words = self:Box(color[1], color[2], color[3], 1, nil, "OVERLAY")
					words:SetPoint("TOPLEFT", self, "TOPLEFT", x + 4, top - 3)
					words:SetWidth(math.floor(width * (0.9 - line * 0.17)))
					words:SetHeight(2)
				else
					local row = self:Box(color[1], color[2], color[3], window.look == "faint" and 0.12 or 0.75)
					if window.look == "share" then
						row:SetVertexColor(0.05, 0.05, 0.07, 0.92)
						local share = self:Box(color[1], color[2], color[3], 0.85, nil, "OVERLAY")
						share:SetPoint("TOPLEFT", self, "TOPLEFT", x + 4, top)
						share:SetWidth(math.floor(width * (1.2 - line * 0.25)))
						share:SetHeight(8)
					elseif window.look == "faint" then
						local words = self:Box(color[1], color[2], color[3], 1, nil, "OVERLAY")
						words:SetPoint("TOPLEFT", self, "TOPLEFT", x + 7, top - 3)
						words:SetWidth(28)
						words:SetHeight(2)
					end
					row:SetPoint("TOPLEFT", self, "TOPLEFT", x + 4, top)
					row:SetWidth(width)
					row:SetHeight(8)
				end
			end
		end
	end
	Kit.Preview(tab, 124, Paint.NoBackgrounds)

	Kit.Section(tab, "Without their background", "A window ticked loses its ground while the switch is on; unticked, it keeps its own. Live, no reload. Move mode and Alt still take each one by its whole box, and a click there opens its card.")
	local function Chip(window)
		local key = window[1]
		return { window[2], function() return not (DB().noBackgroundsOff and DB().noBackgroundsOff[key]) end,
			function()
				local kept = DB().noBackgroundsOff or {}
				kept[key] = not kept[key] or nil
				if next(kept) == nil then
					kept = nil
				end
				DB().noBackgroundsOff = kept
				Apply()
			end, window[3], usable = window.usable or On,
			why = window.why or "Turn No backgrounds on first, with the switch at the top." }
	end
	local chips = {}
	for index = 1, table.getn(WINDOWS) do
		table.insert(chips, Chip(WINDOWS[index]))
	end
	Kit.Chips(tab, chips)
	Kit.Link(tab, "The run tracker as a dial:", "dial")

	Kit.Foot(tab, { reset = Asked("No backgrounds back to default?",
		"The switch off and every window ticked again: each one with its ground, as before.", "Back to default",
		function()
			DB().noBackgrounds, DB().noBackgroundsOff = nil, nil
			Apply()
		end) })
end

------------------------------------------------------------------------------
-- Tooltips: the spells' (AbilityTooltip.lua) and the Biggest Crits' cards;
-- the ranks' option also the meter's.

-- Made with the kit: the preview draws a spell's tooltip as AbilityTooltip.lua
-- lays it out (as the game writes it with Ability tooltips off), and a unit's
-- where it opens, each flat or the game's, as large as in play; under it
-- where they open, their size, the ranks and the two modules.

do
	local tab = pages.tooltips
	Kit.Head(tab, { line = "Your spells' tooltips, on the action bar and the build list, and the units' and the world's: their look, where they open and their size." })

	-- The game's own faces for its tooltips, read before SurvivorUI's flat
	-- look takes them over as the world loads; its tooltip's ground and edge.
	Paint.GAME_TIP = {}
	for index, name in pairs({ "GameTooltipHeaderText", "GameTooltipText" }) do
		local object = getglobal(name)
		local font, size
		if object and object.GetFont then
			font, size = object:GetFont()
		end
		Paint.GAME_TIP[index] = { font or "Fonts\\FRIZQT__.TTF", size or (index == 1 and 14 or 12) }
	end
	Paint.TIP_LOOKS = {
		flat = { bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } },
		game = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } },
	}

	-- A tooltip in the preview: a frame of its own over it (a frame's ground
	-- draws over its parent's words, so its words are its own), laid out as
	-- the game lays one: its lines from the top left, 10 in and 2 apart, a
	-- line's right half at the right edge, a rule over a blank line as
	-- AbilityTooltip.lua's; a health bar (lines.health) along its bottom, flat,
	-- or under it, the game's. lines: { { left, r, g, b, right, r, g, b }, ...,
	-- { rule = color } }.
	function Paint.Tip(self, key, lines, flat)
		self.tips = self.tips or {}
		local tip = self.tips[key]
		if not tip then
			tip = CreateFrame("Frame", nil, self)
			tip.words, tip.rules = {}, {}
			tip.bar = tip:CreateTexture(nil, "ARTWORK")
			self.tips[key] = tip
		end
		for index = 1, table.getn(tip.words) do
			tip.words[index]:Hide()
		end
		for index = 1, table.getn(tip.rules) do
			tip.rules[index]:Hide()
		end
		tip:SetScale(1)
		local head = flat and { SurvivorUI_FONT, 13 + FONT_BUMP } or Paint.GAME_TIP[1]
		local body = flat and { SurvivorUI_FONT, 11 + FONT_BUMP } or Paint.GAME_TIP[2]
		local used, ruled, y, wide = 0, 0, -10, 0
		for index = 1, table.getn(lines) do
			local line = lines[index]
			local face = index == 1 and head or body
			local high = face[2]
			if line.rule then
				ruled = ruled + 1
				local rule = tip.rules[ruled] or tip:CreateTexture(nil, "ARTWORK")
				tip.rules[ruled] = rule
				rule:SetTexture(FLAT)
				rule:SetVertexColor(line.rule[1], line.rule[2], line.rule[3], 0.6)
				rule:SetHeight(1)
				rule:ClearAllPoints()
				rule:SetPoint("LEFT", tip, "TOPLEFT", 10, y - math.floor(high / 2))
				rule:SetPoint("RIGHT", tip, "TOPRIGHT", -10, y - math.floor(high / 2))
				rule:Show()
			else
				local across = 0
				for part = 0, line[5] and 1 or 0 do
					used = used + 1
					local word = tip.words[used] or SurvivorUI_Spoken(tip:CreateFontString(nil, "OVERLAY"))
					tip.words[used] = word
					word:SetFont(face[1], face[2], "")
					word:SetTextColor(line[part * 4 + 2], line[part * 4 + 3], line[part * 4 + 4])
					word:SetText(line[part * 4 + 1])
					word:ClearAllPoints()
					if part == 0 then
						word:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, y)
						high = math.max(high, math.ceil(word:GetHeight() or 0))
					else
						word:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, y)
						across = across + 20
					end
					word:Show()
					across = across + math.ceil(word:GetStringWidth())
				end
				wide = math.max(wide, across)
			end
			y = y - high - 2
		end
		tip:SetWidth(wide + 20)
		tip:SetHeight(-y + 8)
		tip:SetBackdrop(flat and Paint.TIP_LOOKS.flat or Paint.TIP_LOOKS.game)
		if flat then
			tip:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
			tip:SetBackdropBorderColor(0, 0, 0, 1)
		else
			tip:SetBackdropColor(0.09, 0.09, 0.19, 1)
			tip:SetBackdropBorderColor(1, 1, 1, 1)
		end
		tip.bar:Hide()
		if lines.health then
			-- Green, through yellow to red as the health goes (the game's).
			local share = lines.health
			tip.bar:SetTexture(flat and FLAT or "Interface\\TargetingFrame\\UI-StatusBar")
			tip.bar:SetVertexColor(share > 0.5 and 2 * (1 - share) or 1, share > 0.5 and 1 or 2 * share, 0, 1)
			tip.bar:ClearAllPoints()
			if flat then
				tip.bar:SetHeight(4)
				tip.bar:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", 1, 1)
			else
				tip.bar:SetHeight(8)
				tip.bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 2, -1)
			end
			tip.bar:SetWidth(math.max(1, math.floor((tip:GetWidth() - (flat and 2 or 4)) * share + 0.5)))
			tip.bar:Show()
		end
		tip:Show()
		return tip
	end

	-- The sample spell, as AbilityTooltip.lua writes one again (ours): its
	-- name in its school's color (Fire), its rank (Rank 4, or IV) muted, what
	-- it does and its cooldown, its reach and crit, the numbers in their kinds'
	-- colors, then its sections, each in its color under a rule. Else as the
	-- game writes it: its lines one under another, the lists as commas.
	function Paint.SpellLines(ours)
		local M, fire, gold, green, blue = 0.62, { 1, 0.5, 0.1 }, { 1, 0.82, 0.3 }, { 0.12, 1, 0 }, { 0.44, 0.84, 1 }
		if not ours then
			-- The game's own, as it writes them: white, the rank grey, what it
			-- does in gold, then a blank line and the lists in their colors.
			return {
				{ "Fireball", 1, 1, 1, "Rank 4", 0.5, 0.5, 0.5 },
				{ "35 yd range", 1, 1, 1 },
				{ "Automatic", 1, 1, 1, "3.4 sec cooldown", 1, 1, 1 },
				{ "Hurls a ball of fire: 128 Fire damage.", 1, 0.82, 0 },
				{ " ", 1, 1, 1 },
				{ "Upgrades: +35% damage, -10% cooldown", gold[1], gold[2], gold[3] },
				{ "Your bonuses: +12% fire damage", green[1], green[2], green[3] },
				{ "Talents: Ignite", blue[1], blue[2], blue[3] },
			}
		end
		return {
			{ "Fireball", fire[1], fire[2], fire[3], SurvivorUI_RankText and SurvivorUI_RankText(4) or "Rank 4", M, M, M },
			{ "|cffff7f19Fire damage|r \194\183 Automatic", M, M, M, "|cff8cccff3.4 sec|r cooldown", M, M, M },
			{ "|cff99f2bf35 yd|r range", M, M, M, "|cffffc2147%|r crit \194\183 |cffffc214204%|r dmg", M, M, M },
			{ rule = fire },
			{ "Hurls a ball of fire: |cffff7f19128 Fire damage|r.", 0.72, 0.72, 0.72 },
			{ rule = gold },
			{ "Upgrades", gold[1], gold[2], gold[3] },
			{ "  Damage", M, M, M, "+35%", gold[1], gold[2], gold[3] },
			{ "  Cooldown", M, M, M, "-10%", gold[1], gold[2], gold[3] },
			{ rule = green },
			{ "Your bonuses", green[1], green[2], green[3] },
			{ "  Fire damage", M, M, M, "+12%", green[1], green[2], green[3] },
			{ rule = blue },
			{ "Talents", blue[1], blue[2], blue[3] },
			{ "  Ignite", blue[1], blue[2], blue[3] },
		}
	end

	-- A unit's tooltip: your target's name and level, else a sample enemy's,
	-- in red, its health along the bottom.
	function Paint.UnitTipLines()
		local name, level, kind, share, r, g, b = "Young Wolf", 5, "Beast", 1, 1, 0.1, 0.1
		if UnitExists("target") then
			name, level = UnitName("target") or name, UnitLevel("target") or level
			kind = UnitCreatureType and UnitCreatureType("target") or nil
			local most = UnitHealthMax("target") or 0
			share = most > 0 and (UnitHealth("target") or 0) / most or 1
			if not (UnitCanAttack and UnitCanAttack("player", "target")) then
				r, g, b = 1, 1, 1
			end
		end
		local said = SurvivorUI_OTF(kind and kind ~= "" and "Level {1} {2}" or "Level {1}", level > 0 and level or "??",
			SurvivorUI_OT(kind))
		return { { name, r, g, b }, { said, 1, 1, 1 }, health = math.max(0, math.min(1, share)) }
	end

	-- The preview: the spell's tooltip at the left; at the right a unit's
	-- where it opens (left of the damage meter, at the mouse, or in the
	-- game's corner), both as large as in play, else as large as the strip
	-- lets them (it says so).
	function Paint.Tooltips(self)
		self:Begin()
		local flat = not SurvivorUI_Feature or SurvivorUI_Feature("tooltip")
		local ours = not SurvivorUI_Feature or SurvivorUI_Feature("abilityTooltip")
		local size = SurvivorUI_TooltipSize and SurvivorUI_TooltipSize() or 1
		local scale = UIParent:GetEffectiveScale() * (flat and 0.8 or 1) * size / self:GetEffectiveScale()
		local height = self:GetHeight()
		local spell = Paint.Tip(self, "spell", Paint.SpellLines(ours), flat)
		local unit = Paint.Tip(self, "unit", Paint.UnitTipLines(), flat)
		local place = SurvivorUI_TooltipPlace and SurvivorUI_TooltipPlace() or "anchor"
		local meter = place == "anchor" and 64 or 0
		-- The strip shared out: the spell's, a gap, the unit's and the meter.
		local fit = math.min(scale, (PAGE_WIDTH - 44 - meter) / (spell:GetWidth() + unit:GetWidth()),
			(height - 34) / spell:GetHeight(), (height - 80) / unit:GetHeight())
		spell:SetScale(fit)
		unit:SetScale(fit)
		spell:ClearAllPoints()
		spell:SetPoint("TOPLEFT", self, "TOPLEFT", 12 / fit, -22 / fit)
		local muted = MUTED
		local note = ours and "A sample spell, laid out again" or "A sample spell, as the game writes it"
		if fit < scale * 0.95 then
			note = note..", at "..math.floor(fit / scale * 100 + 0.5).."% of its size"
		end
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", muted[1], muted[2], muted[3], note):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		-- The unit's: its bottom right left of the meter, bottoms together;
		-- its bottom left at the mouse's point; in the game's corner.
		local right, bottom = PAGE_WIDTH - 12, -(height - 26)
		local said
		unit:ClearAllPoints()
		if place == "cursor" then
			local cursor = self:Box(1, 1, 1, 1, "Interface\\Cursor\\Point", "OVERLAY")
			cursor:SetWidth(20)
			cursor:SetHeight(20)
			local x, y = math.max(12 + spell:GetWidth() * fit + 16, right - unit:GetWidth() * fit - 20), bottom + 30
			cursor:SetPoint("TOPLEFT", self, "TOPLEFT", x - 2, y + 2)
			unit:SetPoint("BOTTOMLEFT", self, "TOPLEFT", x / fit, y / fit)
			said = "At the mouse"
		elseif place == "game" then
			unit:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", right / fit, bottom / fit)
			said = "Where the game, or another addon, puts it"
		else
			local box = Paint.RowEdged(self, right - meter, bottom + 54, meter, 54, 0.05, 0.05, 0.07)
			for index = 1, 3 do
				local share = ({ 1, 0.62, 0.35 })[index]
				local line = self:Box(({ 1, 0.4, 0.3 })[index], ({ 0.5, 0.75, 0.4 })[index], ({ 0.1, 1, 1 })[index], 0.8, nil, "ARTWORK")
				line:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -14 - (index - 1) * 12)
				line:SetWidth(math.floor((meter - 6) * share))
				line:SetHeight(9)
			end
			local title = self:Word(SurvivorUI_FONT, 8 + FONT_BUMP, "", muted[1], muted[2], muted[3], "Meter")
			title:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
			unit:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", (right - meter - 6) / fit, bottom / fit)
			said = DB().tipRight and "At its anchor, where you moved it" or "At its anchor, beside the damage meter"
		end
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", muted[1], muted[2], muted[3], said):SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8, 6)
	end
	Kit.Preview(tab, 330, Paint.Tooltips)

	Kit.Section(tab, "Opens", "The units' and the world's tooltip. At its anchor: beside the damage meter, or where you moved it (move mode, Tooltip). At the mouse: by the cursor. Left to the game: never moved, for another addon that places the tooltips.")
	Kit.Segments(tab, { { "anchor", "At its anchor" }, { "cursor", "At the mouse" }, { "game", "Left to the game" } },
		function() return SurvivorUI_TooltipPlace and SurvivorUI_TooltipPlace() or "anchor" end,
		function(value) if SurvivorUI_SetTooltipPlace then SurvivorUI_SetTooltipPlace(value) end end)
	Kit.Split(tab)
	Kit.Size(tab, "Size", 0.5, 2, 0.05, function() return SurvivorUI_TooltipSize and SurvivorUI_TooltipSize() or 1 end,
		function(value) if SurvivorUI_SetTooltipSize then SurvivorUI_SetTooltipSize(value) end end,
		{ { "S", 0.85 }, { "M", 1 }, { "L", 1.25 } })
	Kit.Right(tab)
	Kit.Section(tab, "Spell ranks", "Roman spell ranks: LXIII instead of Rank 63 in the spells' tooltips and the Biggest Crits' cards, and instead of 63 after the spells' names in the damage meter, the run's and the Run History's, and in the build list. One choice for all of them, so it stays on with Ability tooltips off; the Build list tab shows it too.")
	Kit.Segments(tab, { { "rank", "Rank 63" }, { "roman", "LXIII" } }, function() return DB().romanRanks and "roman" or "rank" end,
		function(value) DB().romanRanks = value == "roman" or nil end)
	Kit.Join(tab)

	Kit.Section(tab, "Modules", "Each a module, as in Modules. After a reload.")
	Kit.Chips(tab, {
		{ "Flat tooltips", FeatureOn("tooltip"), FeatureToggle("tooltip"),
			"Dark, flat tooltips, a fifth smaller, with a slim health bar along the bottom. Off: the game's. After a reload." },
		{ "Ability tooltips", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip"),
			"A spell's tooltip laid out again: what it does, its numbers in colors, its upgrades, bonuses and talents. Off: as the game writes it. After a reload." },
	})

	-- Its looks back as they first were; the modules and where the anchor
	-- was moved stay.
	Kit.Foot(tab, { reset = Asked("Tooltips back to default?",
		"Opening at their anchor, at their first size, the ranks as Rank 63. Flat tooltips and Ability tooltips stay as they are, and so does where you moved the anchor.", "Back to default",
		function()
			if SurvivorUI_SetTooltipPlace then
				SurvivorUI_SetTooltipPlace("anchor")
			end
			if SurvivorUI_SetTooltipSize then
				SurvivorUI_SetTooltipSize(1)
			end
			DB().tooltipSize, DB().romanRanks = nil, nil
		end) })
end

------------------------------------------------------------------------------
-- Nameplates (Survivor Plates).

-- Reworked (the kit): the preview draws a plate of each kind as Survivor
-- Plates does (SurvivorPlates_Look: its sizes, colors, rounded bars and
-- skulls) at the plates' size, an elite as your target, following the
-- choices under it: the kinds as chips in their plates' colors, the
-- enemies' and the friends', then the look, the size and the key.

do
	local tab = pages.plates
	local line = "Survivor Plates puts a plate over the enemies near your hero and over your friends, each kind in its color."
	if not PlatesThere() then
		Kit.Head(tab, { line = line })
		Note(tab, "Survivor Plates is not installed. It comes in the same download as Survivor UI.")
	else
		Kit.Head(tab, { line = line, isOn = PlatesOn, toggle = function() Plates("none") end })

		local function Look(kind)
			return SurvivorPlates_Look and SurvivorPlates_Look(kind)
		end

		-- A piece of the plates' rounded art, its left edge at left and its
		-- middle at y, from to to across the art.
		local function Piece(canvas, art, layer, r, g, b, a, left, y, width, height, from, to)
			if width < 0.5 then
				return
			end
			local piece = canvas:Box(r, g, b, a, art, layer)
			piece:SetTexCoord(from, to, 0, 1)
			piece:SetPoint("LEFT", canvas, "TOPLEFT", left, y)
			piece:SetWidth(width)
			piece:SetHeight(height)
		end

		-- A strip of it as Survivor Plates lays one (its Lay): the left end,
		-- the middle and the right end, filled across from its left.
		local function Strip(canvas, art, ends, layer, r, g, b, a, left, y, width, height, filled)
			local cap = math.min(height, width) / 2
			local first = math.min(filled, cap)
			local middle = math.min(math.max(filled - cap, 0), width - 2 * cap)
			local last = math.max(filled - (width - cap), 0)
			Piece(canvas, art, layer, r, g, b, a, left, y, first, height, 0, ends * first / cap)
			Piece(canvas, art, layer, r, g, b, a, left + cap, y, middle, height, ends, 1 - ends)
			Piece(canvas, art, layer, r, g, b, a, left + width - cap, y, last, height, 1 - ends, 1 - ends + ends * last / cap)
		end

		-- A kind's plate on the screen now (Survivor Plates' registry): its
		-- unit's name, its health's share and its color (a co-op friend's).
		local function OnScreen(kind)
			local list = SurvivorPlatesRegistry
			for index = 1, table.getn(list or {}) do
				local overlay = list[index]
				local health = overlay.stock and overlay.stock.health
				if overlay.kind == kind and overlay.lastName and health and overlay.plate:IsVisible() then
					local low, high = health:GetMinMaxValues()
					local share = 1
					if low and high and high > low then
						share = math.max(0, math.min(1, (health:GetValue() - low) / (high - low)))
					end
					return overlay.lastName, share, overlay.color
				end
			end
		end

		-- Each kind's plate: its kind, a sample name and health, its words
		-- under it, its switch; in three rows, the elite your target.
		Paint.PLATES = {
			{ "normal", "Kobold Vermin", 0.62, "Rank and file", "normal" },
			{ "elite", "Kobold Taskmaster", 0.48, "Elite", "elite" },
			{ "guardian", "Bellygrub", 0.81, "Guardian", "guardian" },
			{ "boss", "Hogger", 0.67, "Boss", "boss" },
			{ "final", "Edwin VanCleef", 0.93, "Final boss", "boss" },
			{ "party", "Jaina", 0.86, "Co-op member", "party" },
			{ "pet", "Voidwalker", 1, "Pet or summon", "pet" },
			{ "totem", "Totem", 1, "Totem", "totem" },
		}
		Paint.PLATE_ROWS = { { 1, 2, 3 }, { 4, 5 }, { 6, 7, 8 } }
		Paint.PLATE_DEBUFFS = { "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
			"Interface\\Icons\\Spell_Fire_FlameBolt", "Interface\\Icons\\Spell_Nature_Lightning" }

		-- One plate as Survivor Plates draws it (its Dress, Paint and Update),
		-- its bar's middle at x, y, at its size times the view's (zoom): the
		-- line round the bar (gold on your target) or a friend's gold rim, the
		-- dark rest, the health from the left, the share inside on the right,
		-- the name over it and the skull over that; the debuffs inside the bar,
		-- or over your target's. A kind left out, faint and bare.
		function Paint.Plate(canvas, plate, x, y, scale, zoom)
			local look = plate.look
			local width, height = look.width * scale * zoom, look.height * scale * zoom
			local left, top = x - width / 2, y + height / 2
			local a = plate.shown and (plate.target and 1 or look.fade) or 0.16
			if look.rim then
				local tall = height / (1 - 2 * look.rimShare)
				local out = (tall - height) / 2
				local shine = plate.target and 1 or 0.85
				Strip(canvas, look.gold, look.ends, "OVERLAY", shine, shine, shine, a, left - out, y, width + 2 * out, tall, width + 2 * out)
			else
				local edge = plate.target and look.target or { 0, 0, 0 }
				Strip(canvas, look.round, look.ends, "BACKGROUND", edge[1], edge[2], edge[3], a, left - 1, y, width + 2, height + 2, width + 2)
			end
			Strip(canvas, look.round, look.ends, "BORDER", 0.06, 0.06, 0.06, a, left, y, width, height, width)
			local color = plate.color
			Strip(canvas, look.round, look.ends, "ARTWORK", color[1], color[2], color[3], a, left, y, width, height,
				math.floor(plate.share * width * 2 + 0.5) / 2)
			if not plate.shown then
				return
			end
			local size = (look.share * scale + look.bump) * zoom
			local percent = math.floor(plate.share * 100 + 0.5)
			if percent == 0 and plate.share > 0 then
				percent = 1
			end
			local share = canvas:Word(look.font, size, "OUTLINE", 1, 1, 1, percent.."%")
			share:SetTextColor(1, 1, 1, a)
			share:SetPoint("RIGHT", canvas, "TOPLEFT", left + width - 3 * scale * zoom, y + size * 0.12)
			local skull = look.skull and look.skullSize * scale or 0
			if plate.named then
				local name = canvas:Word(look.font, (look.name * scale + look.bump) * zoom, "OUTLINE", 1, 1, 1, plate.name)
				name:SetTextColor(1, 1, 1, a)
				name:SetPoint("BOTTOM", canvas, "TOPLEFT", x, top + 2 * zoom)
				if look.skull then
					local art = canvas:Box(1, 1, 1, a, look.skull, "OVERLAY")
					art:SetWidth(skull * zoom)
					art:SetHeight(skull * zoom)
					art:SetPoint("BOTTOM", name, "TOP", 0, 0)
				end
			end
			local icons = Paint.PLATE_DEBUFFS
			if plate.inside then
				-- Small, left to right, clear of the share.
				local step = look.height * scale
				local room = math.min(8, math.floor((look.width * scale - look.room * scale - 2) / step))
				for index = 1, math.min(room, table.getn(icons)) do
					local icon = canvas:Box(1, 1, 1, 1, icons[index], "OVERLAY")
					icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					icon:SetWidth((step - 1) * zoom)
					icon:SetHeight((step - 1) * zoom)
					icon:SetPoint("LEFT", canvas, "TOPLEFT", left + (2 + (index - 1) * step) * zoom, y)
				end
			elseif plate.over then
				-- Over the name and its skull, each in a black edge.
				local lift = 4
				if plate.named then
					lift = lift + look.name * scale + 3 + skull
				end
				local side = look.debuffSize * zoom
				for index = 1, table.getn(icons) do
					local bx, by = left + (index - 1) * (look.debuffSize + 2) * zoom, top + lift * zoom
					local edge = canvas:Box(0, 0, 0, 1, nil, "ARTWORK")
					edge:SetPoint("BOTTOMLEFT", canvas, "TOPLEFT", bx - 1, by - 1)
					edge:SetWidth(side + 2)
					edge:SetHeight(side + 2)
					local icon = canvas:Box(1, 1, 1, 1, icons[index], "OVERLAY")
					icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					icon:SetPoint("BOTTOMLEFT", canvas, "TOPLEFT", bx, by)
					icon:SetWidth(side)
					icon:SetHeight(side)
				end
			end
		end

		-- The plates in their rows, each in a slot of its row's, as large as
		-- the plates' size has them, smaller only to fit; the names those on
		-- the screen now when there are some, else a sample's.
		function Paint.Plates(self)
			self:Begin()
			if not PlatesOn() then
				self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "No nameplates"):SetPoint("CENTER", self, "CENTER", 0, 0)
				return
			end
			if not (Look("normal") and SurvivorPlates_Shown) then
				self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "Survivor Plates 3.0.56 or later"):SetPoint("CENTER", self, "CENTER", 0, 0)
				return
			end
			local db = SurvivorPlatesDB or {}
			local scale = SurvivorPlates_GetScale and SurvivorPlates_GetScale() or 1
			local inside = db.insideDebuffs ~= false
			local always = SurvivorPlates_TargetPlate and SurvivorPlates_TargetPlate()
			local plates, rows, need, zoom, real = {}, {}, 0, 1, nil
			for row = 1, table.getn(Paint.PLATE_ROWS) do
				local slots = Paint.PLATE_ROWS[row]
				local room = (PAGE_WIDTH - 20) / table.getn(slots)
				local above, tall = 0, 0
				for slot = 1, table.getn(slots) do
					local entry = Paint.PLATES[slots[slot]]
					local look = Look(entry[1])
					local plate = { look = look, entry = entry, row = row, x = 10 + (slot - 0.5) * room }
					plate.target = entry[1] == "elite"
					plate.shown = SurvivorPlates_Shown(entry[5]) or (plate.target and always)
					local name, share, color = OnScreen(entry[1])
					if entry[1] == "pet" and not name and UnitExists("pet") then
						name = UnitName("pet")
					end
					plate.name, plate.share, plate.color = name or entry[2], share or entry[3], color or look.color
					-- What it has over its bar, at the plates' size: its name and
					-- its skull, or your target's debuffs over those.
					local named = db.names == true or entry[1] ~= "normal"
					local skull = look.skull and look.skullSize * scale or 0
					local over = plate.target and not (inside and look.inside)
					local up = named and 2 + look.name * scale + look.bump + skull or 0
					if over then
						up = 4 + (named and look.name * scale + 3 + skull or 0) + look.debuffSize
					end
					plate.named = plate.shown and named
					real = real or (name and plate.named)
					plate.over = plate.shown and over
					plate.inside = plate.shown and inside and look.inside
					above = math.max(above, up)
					local bar = look.height * scale
					if look.rim then
						bar = bar / (1 - 2 * look.rimShare)
					else
						bar = bar + 2
					end
					tall = math.max(tall, bar)
					zoom = math.min(zoom, (room - 8) / (look.width * scale + 2))
					table.insert(plates, plate)
				end
				rows[row] = { above = above, tall = tall }
				need = need + above + tall
			end
			-- The rows spread down the preview, each its words under its bars.
			local count, words = table.getn(rows), 14
			local height = self:GetHeight()
			zoom = math.min(zoom, (height - 22 - count * words - (count + 1) * 4) / need)
			self.zoom = zoom
			local gap = (height - 18 - zoom * need - count * words) / (count + 1)
			local y = -14
			for row = 1, count do
				y = y - gap
				rows[row].middle = y - zoom * (rows[row].above + rows[row].tall / 2)
				rows[row].under = y - zoom * (rows[row].above + rows[row].tall) - 3
				y = rows[row].under - words + 3
			end
			for index = 1, table.getn(plates) do
				local plate = plates[index]
				local look = plate.look
				Paint.Plate(self, plate, plate.x, rows[plate.row].middle, scale, zoom)
				local said, r, g, b = plate.entry[4], MUTED[1], MUTED[2], MUTED[3]
				if not plate.shown then
					said, r, g, b = SurvivorUI_OTF("{1}: off", SurvivorUI_OT(said)), 0.42, 0.42, 0.46
				elseif plate.target then
					said, r, g, b = SurvivorUI_OTF("{1}, your target", SurvivorUI_OT(said)), look.target[1], look.target[2], look.target[3]
				end
				self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", r, g, b, said):SetPoint("TOP", self, "TOPLEFT", plate.x, rows[plate.row].under)
			end
			local note = real and "Names from your screen" or "A sample"
			if zoom < 0.995 then
				note = note..", at "..math.floor(zoom * 100 + 0.5).."% to fit"
			end
			self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], note):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		end
		Kit.Preview(tab, 240, Paint.Plates)

		-- The kit's chips (Kit.Chips), each in a color of its own, item[5]
		-- (the page's without one): the kinds in their plates' colors.
		function Kit.PlateChips(page, items)
			local left, width = Span(page)
			local x, row = 0, 0
			local chips, top = {}, page.y
			for index = 1, table.getn(items) do
				local item = items[index]
				local chip = CreateFrame("Button", nil, page)
				table.insert(chips, chip)
				chip:SetHeight(22)
				Boxed(chip, WELL, EDGE)
				chip.tick = chip:CreateTexture(nil, "OVERLAY")
				chip.tick:SetTexture(ART.."Tick")
				chip.tick:SetWidth(10)
				chip.tick:SetHeight(10)
				chip.tick:SetPoint("LEFT", chip, "LEFT", 9, 0)
				chip.plus = Text(chip, 10, MUTED, "")
				chip.plus:SetPoint("CENTER", chip.tick, "CENTER", 0, 0)
				chip.plus:SetText("+")
				chip.label = Text(chip, 10, TEXT)
				chip.label:SetPoint("LEFT", chip, "LEFT", 24, 0)
				chip.label:SetText(item[1])
				local chipWidth = 24 + math.ceil(chip.label:GetStringWidth()) + 11
				chip:SetWidth(chipWidth)
				if x > 0 and x + chipWidth > width then
					x, row = 0, row + 1
				end
				chip:SetPoint("TOPLEFT", page, "TOPLEFT", left + x, page.y - row * 27)
				chip.row, chip.placed = row, left + x
				x = x + chipWidth + 6
				chip.name, chip.isOn, chip.toggle, chip.help = item[1], item[2], item[3], item[4]
				chip.color = item[5] or page.color
				chip:SetScript("OnClick", function()
					this.toggle()
					RefreshAll()
				end)
				chip:SetScript("OnEnter", function()
					this.hot = true
					this:Refresh()
					if this.help then
						GameTooltip:SetOwner(this, "ANCHOR_TOP")
						GameTooltip:SetText(SurvivorUI_OT(this.name), Kit.Light(this.color, 0.3))
						GameTooltip:AddLine(SurvivorUI_OT(this.help), 1, 1, 1, 1)
						GameTooltip:Show()
					end
				end)
				chip:SetScript("OnLeave", function()
					this.hot = nil
					this:Refresh()
					GameTooltip:Hide()
				end)
				function chip:Refresh()
					local color, on = self.color, self.isOn()
					if on then
						self:SetBackdropColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1)
						self:SetBackdropBorderColor(color[1], color[2], color[3], self.hot and 1 or 0.8)
						self.tick:SetVertexColor(Kit.Light(color))
						self.tick:Show()
						self.plus:Hide()
					else
						self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
						local edge = self.hot and 0.45 or EDGE[1]
						self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
						self.tick:Hide()
						self.plus:Show()
					end
					if self.hot then
						self.label:SetTextColor(1, 1, 1)
					elseif on then
						self.label:SetTextColor(Kit.Light(color, 0.6))
					else
						self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
					end
				end
				table.insert(widgets, chip)
				side.Index(page, item[1], item[4], page.y - row * 27, 22)
			end
			-- In another language, as Kit.Chips: each as wide as its new words.
			table.insert(side.fits, function() Kit.Refit(chips, page, left, top) end)
			page.y = page.y - (row + 1) * 27 - 5
		end

		-- A kind's chip: its plates on or off (Survivor Plates' show), in its
		-- plates' color.
		local function Kind(label, kind, command, help)
			local look = Look(kind)
			return { label, function() return SurvivorPlates_Shown and SurvivorPlates_Shown(kind) end,
				function() Plates(command) end, help, look and look.color }
		end

		local gold = Look("elite")
		Kit.Section(tab, "Enemies", "Within 20 yards of your hero, each kind in its color, the bosses' plates in front, then the guardians', then the elites'. A kind left out has no plate.")
		Kit.PlateChips(tab, {
			Kind("Rank and file", "normal", "normal", "The horde's rank and file, in red, a little faded behind the rest."),
			Kind("Elites", "elite", "elites", "In green, a bone skull over the name."),
			Kind("Guardians", "guardian", "guardians", "In blue, the lair's skull over the name; told from an elite of the same name by the game."),
			Kind("Bosses", "boss", "bosses", "In purple, the final boss in orange, a horned skull over the name, in front of every other plate."),
			{ "Your target, whatever its kind", function() return SurvivorPlates_TargetPlate and SurvivorPlates_TargetPlate() end,
				function() Plates("target") end, "Your target's plate, its line in gold, even when its kind is off.", gold and gold.target },
		})
		Kit.Section(tab, "Friends", "Thin plates in a gold rim, apart from the enemies'.")
		Kit.PlateChips(tab, {
			Kind("Co-op members", "party", "party", "Your friends in a co-op run, in their class's color. A friend down has none (the game gives a fallen hero no plate): the party frames show them."),
			Kind("Pets and summons", "pet", "pets", "A warlock's demons, the Water Elemental, spirit wolves, treants, a hunter's pets: in mint."),
			Kind("Totems", "totem", "totems", "A shaman's, in mint."),
		})

		Kit.Section(tab, "Look", "Every plate's: its name, its debuffs, where it stands in a crowd and whether it takes a click.")
		local looks = {
			{ "Names on every plate", function() return SurvivorPlatesDB and SurvivorPlatesDB.names == true end,
				function() Plates("names") end, "The rank and file's too. Off: only on elites, guardians, bosses and friends." },
			{ "Debuffs inside", function() return not (SurvivorPlatesDB and SurvivorPlatesDB.insideDebuffs == false) end,
				function()
					SurvivorPlatesDB = SurvivorPlatesDB or {}
					SurvivorPlatesDB.insideDebuffs = SurvivorPlatesDB.insideDebuffs == false
				end, "Small icons of the debuffs on a guardian or a boss, left to right inside its bar; an elite's while it is your target or under the mouse. Off: over your target's plate, as on the others." },
		}
		if SurvivorPlates_LayoutThere and SurvivorPlates_LayoutThere() then
			table.insert(looks, { "Overlapping", function() return SurvivorPlates_Overlapping() end,
				function() Plates("overlap") end, "Each plate stays right over its enemy, on top of each other in a crowd. Off: they move apart (the game's Nameplate Layout)." })
		end
		table.insert(looks, { "Click through", function() return SurvivorPlates_ClickThrough and SurvivorPlates_ClickThrough() end,
			function() Plates("click") end, "The camera turns from over a plate; only the plate under the mouse, in its glow, takes a click." })
		Kit.PlateChips(tab, looks)

		Kit.Split(tab)
		Kit.Size(tab, "Size", 0.5, 2, 0.05,
			function() return SurvivorPlates_GetScale and SurvivorPlates_GetScale() or 1 end,
			function(value) if SurvivorPlates_SetScale then SurvivorPlates_SetScale(value) end end,
			{ { "S", 0.8 }, { "M", 1 }, { "L", 1.25 } })
		Kit.Right(tab)
		-- The key at its title's right end, as the size's S M L; the game's
		-- V and Shift+V under it.
		Kit.Section(tab, "Key", "A key of your own for all the plates at once, as the switch above and /splates none. None by default; Key Bindings in the game's menu lists it as well.")
		local left, width = Span(tab)
		local key = Kit.Key(tab, tab.color, function() return "SURVIVORPLATES_TOGGLE" end)
		key:SetPoint("TOPLEFT", tab, "TOPLEFT", left + width - 84, tab.y + 22)
		side.Index(tab, "Plates on or off key", "key binding", tab.y + 22, 20)
		Kit.PlateChips(tab, {
			{ "Ignore V and Shift+V", function() return not (SurvivorPlates_KeysAllowed and SurvivorPlates_KeysAllowed()) end,
				function() Plates("keys") end, "The game's keys for its plates: what they turn on or off goes back to the choices here." },
		})
		Kit.Join(tab)

		Kit.Foot(tab, { reset = Asked("Nameplates back to default?",
			"The plates on: the elites', guardians', bosses' and every friend's, not the rank and file's, your target's only with its kind; a name on every plate, the debuffs inside, overlapping, clicks through, V and Shift+V ignored, the first size. The key stays.", "Back to default",
			function()
				if SurvivorPlates_Defaults then
					SurvivorPlates_Defaults()
				end
			end),
			strong = { "Suggested setup", Asked("The suggested setup?",
				"Your totems', pets' and summons' and co-op members' plates on, the enemies' off: the boss bars at the top of the screen show the bosses and guardians.", "Set it up",
				function() Plates("suggested") end) } })
	end
end

------------------------------------------------------------------------------
-- Raid marks (Marks.lua): each kind marked on its own or not, and with which;
-- the party's heroes too. The eight marks in a row from x, the one chosen
-- edged in white.

page = pages.marks
Header(page, "Raid marks", "From the game's 0.115: a mark put on its own on each kind ticked here, once the enemy is in the fight (a guardian once awake), one enemy per mark at a time, the next waiting for the one marked to fall; and one on each hero of your co-op party. The marks are the party's, seen by everyone, on the plates, the boss bars and the target's frame. To mark an enemy the game has not put in your target, the hero targets it by name for a moment. An enemy or a hero already marked is left as it is.")
local function MarkPicker(page, x, get, set, taken)
	local choices = {}
	for index = 1, table.getn(SurvivorUI_RAID_MARKS or {}) do
		table.insert(choices, SurvivorUI_RAID_MARKS[index])
	end
	-- The last box: no mark for this row.
	table.insert(choices, { 0, "No mark" })
	for index = 1, table.getn(choices) do
		local value, name = choices[index][1], choices[index][2]
		local mark = CreateFrame("Button", nil, page)
		mark:SetWidth(20)
		mark:SetHeight(ROW)
		mark:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		mark.edge = Fill(mark, "BORDER", 0.3, 0.3, 0.35, 1)
		mark.edge:SetWidth(20)
		mark.edge:SetHeight(20)
		mark.edge:SetPoint("TOPLEFT", mark, "TOPLEFT", 0, 0)
		mark.back = Fill(mark, "ARTWORK", 0.06, 0.06, 0.08, 1)
		mark.back:SetPoint("TOPLEFT", mark.edge, "TOPLEFT", 1, -1)
		mark.back:SetPoint("BOTTOMRIGHT", mark.edge, "BOTTOMRIGHT", -1, 1)
		mark.icon = mark:CreateTexture(nil, "OVERLAY")
		mark.icon:SetPoint("TOPLEFT", mark.edge, "TOPLEFT", 2, -2)
		mark.icon:SetPoint("BOTTOMRIGHT", mark.edge, "BOTTOMRIGHT", -2, 2)
		if value == 0 then
			-- A bare dash: none.
			mark.icon:SetTexture(FLAT)
			mark.icon:SetVertexColor(0.55, 0.55, 0.6, 1)
			mark.icon:ClearAllPoints()
			mark.icon:SetPoint("CENTER", mark.edge, "CENTER", 0, 0)
			mark.icon:SetWidth(8)
			mark.icon:SetHeight(2)
		elseif SurvivorUI_SetRaidMarkTexture then
			SurvivorUI_SetRaidMarkTexture(mark.icon, value)
		end
		x = x + 24
		mark:SetScript("OnClick", function()
			set(value)
			RefreshAll()
		end)
		mark:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(SurvivorUI_OT(name), 1, 1, 1)
			GameTooltip:Show()
		end)
		mark:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		function mark:Refresh()
			-- A mark another row wears is not offered.
			if value > 0 and taken and taken(value) then
				self:Hide()
				return
			end
			self:Show()
			local chosen = (get() or 0) == value
			if chosen then
				self.edge:SetVertexColor(1, 1, 1, 1)
			elseif self.hot then
				self.edge:SetVertexColor(0.7, 0.7, 0.75, 1)
			else
				self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
			end
			self.icon:SetAlpha((chosen or self.hot) and 1 or 0.55)
		end
		table.insert(widgets, mark)
	end
end

-- A kind's row: its box and name, its marks beside them.
local function MarkRow(kind, label)
	local y = page.y
	local check = Check(page, label, function() return SurvivorUI_AutoMarkOn and SurvivorUI_AutoMarkOn(kind) end,
		function() if SurvivorUI_ToggleAutoMark then SurvivorUI_ToggleAutoMark(kind) end end)
	check:SetWidth(140)
	page.y = y
	MarkPicker(page, 150, function() return SurvivorUI_AutoMarkIcon and SurvivorUI_AutoMarkIcon(kind) end,
		function(value) if SurvivorUI_SetAutoMarkIcon then SurvivorUI_SetAutoMarkIcon(kind, value) end end,
		function(value) return SurvivorUI_MarkTakenElsewhere and SurvivorUI_MarkTakenElsewhere(value, kind, nil) end)
	page.y = y - ROW - 3
end

-- A hero's row (Hero 1 to 5, the party by name in order): its mark, the
-- other heroes' not offered.
local function HeroRow(slot)
	local y = page.y
	local text = Text(page, 11, TEXT)
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 24, y - 3)
	text:SetText("Hero "..slot)
	MarkPicker(page, 150, function() return SurvivorUI_PartyMarkIcon and SurvivorUI_PartyMarkIcon(slot) end,
		function(value) if SurvivorUI_SetPartyMarkIcon then SurvivorUI_SetPartyMarkIcon(slot, value) end end,
		function(value) return SurvivorUI_MarkTakenElsewhere and SurvivorUI_MarkTakenElsewhere(value, nil, slot) end)
	page.y = y - ROW - 3
end

Subheader(page, "Co-op party")
Check(page, "Each hero a mark", function() return SurvivorUI_AutoMarkOn and SurvivorUI_AutoMarkOn("party") end,
	function() if SurvivorUI_ToggleAutoMark then SurvivorUI_ToggleAutoMark("party") end end,
	"every hero of the party, you too: easier to find a friend in the horde")
for slot = 1, 5 do
	HeroRow(slot)
end
Note(page, "The heroes take the marks by their names in alphabetical order, Hero 1 the first, so every Survivor UI in the party gives the same; a hero already marked keeps that mark. Every mark belongs to one row: picked here, it leaves the other rows; the last box, a dash, leaves a row with no mark.")
Subheader(page, "Enemies")
Check(page, "Draw the enemies' marks", function() return SurvivorUI_MarksDrawn and SurvivorUI_MarksDrawn() end,
	function() if SurvivorUI_ToggleWorld then SurvivorUI_ToggleWorld("markDrawn") end end,
	"From the game's 0.139.2: every boss, guardian and elite of a kind ticked below wears its mark at once, drawn over it, and no target is taken; only you see them. Off: the game's raid marks, one enemy a mark at a time, seen by the whole party.")
MarkRow("boss", "Bosses")
MarkRow("guardian", "Lair guardians")
MarkRow("elite", "Elites")
page.y = page.y - 6
Button(page, "Uncheck all", 150, 0, function()
	if SurvivorUI_ResetAutoMarks then
		SurvivorUI_ResetAutoMarks()
	end
	RefreshAll()
end)
page.y = page.y - 30
Note(page, "Every row off and with no mark; the marks on the heroes and on your target come off. A mark on an enemy out of reach stays until it falls.")

------------------------------------------------------------------------------
-- World markers (WorldMarks.lua): what is drawn on the world itself.

page = pages.world
Header(page, "World markers", "From the game's 0.139.2: marks drawn on the world itself, over what they point at, wherever the camera turns, with no nameplate and no target taken. Only you see them.")
do
	local function WorldCheck(label, key, note)
		Check(page, label, function() return SurvivorUI_WorldOn and SurvivorUI_WorldOn(key) end,
			function() if SurvivorUI_ToggleWorld then SurvivorUI_ToggleWorld(key) end end, note)
	end
	Subheader(page, "Co-op")
	WorldCheck("Friends down", "worldDowned", "a gold cross over a friend who is down, their name and how far; their party frame says how far too")
	Subheader(page, "The map")
	WorldCheck("Caches", "worldCaches", "a chest over each cache still there, and how far")
	WorldCheck("Light beams over caches", "worldBeams", "a column of gold light over each cache, its chest floating near the top; drawn over the world, it fades where you stand in front of it")
	WorldCheck("Lairs", "worldLairs", "the guardian's name over its lair while it sleeps, grey; awake, over the guardian itself, orange, following it; slain, back over the lair with the time until it comes back")
	WorldCheck("Arrows", "worldArrows", "for friends down, caches and lairs out of sight: an arrow on a ring round you toward the nearest few, with how far")
	-- The guardians' rings (WorldMarks.lua on the ground, MapPins.lua on the
	-- minimap), by the game's rule as its 0.139.2 has it: set in Range ring.
	Subheader(page, "Guardians")
	Note(page, "A sleeping guardian wakes when you come within 20 yards of it in its lair, or at any hit. Awake, it gives up when you, not it, go more than 97.5 yards from its lair.")
	Kit.Link(page, "Its aggro ring and reset area, their look, the warning and the minimap, in", "range")
	Subheader(page, "Your range")
	Kit.Link(page, "The range ring round you and on the minimap, its look and its key, in", "range")
	Subheader(page, "Enemies")
	WorldCheck("Explosive orbs", "worldOrbs", "in a run with the Explosive affix, a pulsing mark over each orb: only direct hits hurt them")
	WorldCheck("Bars over elites, guardians and bosses", "worldBars", "a test: their name and health over them, in their kind's color, with no nameplate")
	Note(page, "The enemies' marks are on the Raid marks tab: with \"Draw the enemies' marks\" on, they are drawn here too.")
end

------------------------------------------------------------------------------
-- Range ring (WorldMarks.lua): as far as the build's longest spell strikes,
-- round you and on the minimap; and the guardians' rings (Lucas, 2026-11-04),
-- where one wakes (the aggro ring) and how far from its lair you may go (the
-- reset area). Each ring its own look.

-- Made with the kit: the preview draws them as the game will, at one scale
-- of yards: round the hero (a circle seen from the camera: wider than tall),
-- a lair with its aggro ring and the reset area's arc near you, the warning's
-- line, and the minimap's square at its zoom with your ring and the
-- guardian's; each ring's name by it, the one picked brighter. Under it one
-- ring at a time (Lucas, 2026-11-04): Character, Minimap, Guardian aggro and
-- Guardian reset across the page, a dot on each lit in the ring's color
-- while it shows. Then the one picked: its switch and its extras on a row
-- (its yards, its shade, the warning, the guardians on the minimap), and its
-- look (type and color; size and opacity), faded and still while it is off.
-- Advanced: its gap (faded and still for a line, which has none) and the key.

do
	local tab = pages.range
	-- The page's own, in one table (the file is near Lua 5.0's 200 locals):
	-- the ring picked, the preview's pen and scale, each ring's sizes.
	local RG = {
		editing = "World",
		LINES = {},
		pen = {},
		-- Each ring: its look's name, its name here, its switch.
		RINGS = { { "World", "Character", "rangeWorld" }, { "Map", "Minimap", "rangeMinimap" },
			{ "Wake", "Guardian aggro", "leashWake" }, { "Leash", "Guardian reset", "leashReset" } },
		KEYS = { World = "rangeWorld", Map = "rangeMinimap", Wake = "leashWake", Leash = "leashReset" },
		TYPES = { { "dots", "Dots" }, { "dashes", "Dashes" }, { "line", "Line" } },
		-- Dots' size: low, high, S M L, first; gap: low, high, first.
		SIZES = {
			World = { 3, 12, { { "S", 4 }, { "M", 6 }, { "L", 9 } }, 6 }, Map = { 2, 8, { { "S", 2 }, { "M", 3 }, { "L", 5 } }, 3 },
			Wake = { 3, 12, { { "S", 3 }, { "M", 5 }, { "L", 8 } }, 5 }, Leash = { 3, 14, { { "S", 5 }, { "M", 7 }, { "L", 10 } }, 7 },
		},
		GAPS = { World = { 4, 30, 10 }, Map = { 2, 20, 6 }, Wake = { 4, 30, 12 }, Leash = { 4, 30, 9 } },
		YARD = 2.2,                    -- the preview's pixels a yard across the ground; up and down, FLAT of that
		FLAT = 0.39,
		HERO = { 150, -92 }, LAIR = { 286, -64 },
		-- The enemies round the hero: x, y from it, and whether in reach.
		FOES = { { 38, 8, true }, { -30, -12, true }, { 92, -22 }, { -80, 16 }, { -38, 38 } },
		WAKE = 20, LEASH = 97.5, RED = { 1.00, 0.28, 0.22 },
		BOX = 32,                      -- a ring's row of switch and extras, over its look
	}
	Kit.Head(tab, { line = "How far your spells reach, and where a guardian wakes and gives up.", advanced = true })

	function RG.Look(which, field, fallback)
		local value = SurvivorUI_RangeLook and SurvivorUI_RangeLook(which, field)
		if value == nil then
			return fallback
		end
		return value
	end

	function RG.Get(which, field, fallback)
		return function() return RG.Look(which, field, fallback) end
	end

	function RG.Set(which, field, whole)
		return function(value)
			if whole then
				value = math.floor(value + 0.5)
			end
			if SurvivorUI_SetRangeLook then
				SurvivorUI_SetRangeLook(which, field, value)
			end
		end
	end

	function RG.On(key)
		return SurvivorUI_WorldOn and SurvivorUI_WorldOn(key)
	end

	-- Whether a ring shows ("World", "Map", "Wake" or "Leash").
	function RG.Shown(which)
		return RG.On(RG.KEYS[which])
	end

	function RG.While(key)
		return function() return RG.On(key) end
	end

	-- The preview's dots and pieces, in the pen's color, size and layer.
	function RG.PutDot(index, x, y)
		local pen = RG.pen
		local dot = pen.canvas:Box(pen.r, pen.g, pen.b, pen.a, ART.."PaceDot", pen.layer)
		dot:SetWidth(pen.size)
		dot:SetHeight(pen.size)
		dot:SetPoint("CENTER", pen.canvas, "TOPLEFT", x, y)
	end

	function RG.PutPiece(index, x1, y1, x2, y2, thick)
		local pen = RG.pen
		local piece = pen.canvas:Box(pen.r, pen.g, pen.b, pen.a, ART.."RingLine", pen.layer)
		local x, y = SurvivorUI_RangePiece(piece, x1, y1, x2, y2, thick)
		piece:SetPoint("CENTER", pen.canvas, "TOPLEFT", x, y)
	end

	function RG.Inside(x, y, clip)
		return x >= clip[1] and x <= clip[3] and y <= clip[2] and y >= clip[4]
	end

	-- A ring in its look along an ellipse round x, y (wide across, tall up
	-- and down), from angle from to angle to (all round with none), each line
	-- with both ends inside clip { left, top, right, bottom } (left out else);
	-- pieces on the ground only, as in the game. r, g, b, a: its color and
	-- opacity, else its look's.
	function RG.Trace(self, which, count, x, y, wide, tall, from, to, clip, ground, r, g, b, a)
		local lines = RG.LINES[which] or {}
		RG.LINES[which] = lines
		from, to = from or 0, to or 2 * math.pi
		for index = 1, count do
			local line = lines[index] or {}
			lines[index] = line
			local one, two = from + (to - from) * (index - 1) / count, from + (to - from) * index / count
			line.x, line.y = x + wide * math.cos(one), y + tall * math.sin(one)
			line.dx, line.dy = x + wide * math.cos(two) - line.x, y + tall * math.sin(two) - line.y
			line.length = math.sqrt(line.dx * line.dx + line.dy * line.dy)
			line.on = not clip or RG.Inside(line.x, line.y, clip) and RG.Inside(line.x + line.dx, line.y + line.dy, clip)
		end
		local pen = RG.pen
		pen.canvas = self
		if r then
			pen.r, pen.g, pen.b = r, g, b
		else
			pen.r, pen.g, pen.b = SurvivorUI_RangeColor(which)
		end
		pen.a, pen.size = a or RG.Look(which, "Alpha", 0.8), RG.Look(which, "Size", 6)
		if ground and RG.Look(which, "Look") ~= "dots" and SurvivorUI_RangePieces then
			SurvivorUI_RangePieces(lines, count, which, 300, RG.PutPiece)
		else
			SurvivorUI_RangeAlong(lines, count, which, 300, RG.PutDot)
		end
	end

	-- A ring's name by it, as the picker names it: the ring picked brighter,
	-- ": off" after it while off.
	function RG.Name(self, text, on, which, point, x, y)
		local color = RG.editing == which and TEXT or MUTED
		local word = self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", color[1], color[2], color[3], on and text or text..": off")
		word:SetPoint(point, self, "TOPLEFT", x, y)
		return word
	end

	-- Round you: the hero, a ball of its class's color, enemies about it, its
	-- ring; a guardian's lair with its aggro ring, the reset area's arc near
	-- you (you some 20 yards inside it) and the warning's line.
	function RG.Ground(self, yards, height)
		local clip = { 4, -4, 352, -height + 4 }
		local k, flat = RG.YARD, RG.FLAT
		local hx, hy, lx, ly = RG.HERO[1], RG.HERO[2], RG.LAIR[1], RG.LAIR[2]
		for index = 1, table.getn(RG.FOES) do
			local foe = RG.FOES[index]
			local box = foe[3] and self:Box(0.75, 0.22, 0.18, 1) or self:Box(0.40, 0.15, 0.12, 1)
			box:SetWidth(10)
			box:SetHeight(10)
			box:SetPoint("CENTER", self, "TOPLEFT", hx + foe[1], hy + foe[2])
		end
		local r, g, b = Paint.HeroColor()
		local glow = self:Box(r, g, b, 0.5, ART.."PaceDot", "BORDER")
		glow:SetWidth(26)
		glow:SetHeight(26)
		glow:SetPoint("CENTER", self, "TOPLEFT", hx, hy)
		local lr, lg, lb = Kit.Light({ r, g, b }, 0.35)
		local hero = self:Box(lr, lg, lb, 1, ART.."PaceDot")
		hero:SetWidth(14)
		hero:SetHeight(14)
		hero:SetPoint("CENTER", glow, "CENTER", 0, 0)
		local skull = self:Box(1, 1, 1, 0.9, ART.."PinLair")
		skull:SetWidth(16)
		skull:SetHeight(16)
		skull:SetPoint("CENTER", self, "TOPLEFT", lx, ly + 3)
		RG.pen.layer = "BORDER"
		local worldOn, wake, reset = RG.On("rangeWorld"), RG.On("leashWake"), RG.On("leashReset")
		if worldOn then
			local wide = math.min(130, yards * k)
			RG.Trace(self, "World", 48, hx, hy, wide, wide * flat, nil, nil, clip, true)
			if RG.Look("World", "Yards") then
				self:Word(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE", RG.pen.r, RG.pen.g, RG.pen.b, yards.." yd"):SetPoint("BOTTOM", self, "TOPLEFT", hx, hy + wide * flat + RG.pen.size / 2 + 3)
			end
		end
		RG.Name(self, "Character", worldOn, "World", "BOTTOM", hx, -height + 6)
		if wake then
			RG.Trace(self, "Wake", 32, lx, ly, RG.WAKE * k, RG.WAKE * k * flat, nil, nil, clip, true)
		end
		RG.Name(self, "Guardian aggro", wake, "Wake", "TOP", lx, ly - RG.WAKE * k * flat - 5)
		if reset then
			RG.Trace(self, "Leash", 40, lx, ly, RG.LEASH * k, RG.LEASH * k * flat, 0.55 * math.pi, 1.45 * math.pi, clip, true)
			-- The warning, as a sample of its line: your last 10 yards.
			if RG.On("leashWarn") then
				local line = RG.LINES.warn or { { on = true, dx = 30, dy = 0, length = 30 } }
				RG.LINES.warn = line
				line[1].x, line[1].y = 182, -14
				local pen = RG.pen
				pen.r, pen.g, pen.b, pen.a = RG.RED[1], RG.RED[2], RG.RED[3], 1
				pen.size = RG.Look("LeashWarn", "Size", 9)
				SurvivorUI_RangePieces(line, 1, "LeashWarn", 20, RG.PutPiece)
				self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", RG.RED[1], RG.RED[2], RG.RED[3], "your last 10 yd"):SetPoint("LEFT", self, "TOPLEFT", 218, -14)
			end
		end
		-- Left of the arc, under LIVE PREVIEW.
		RG.Name(self, "Guardian reset", reset, "Leash", "LEFT", 8, -26)
	end

	-- A circle of the minimap's dots (3 wide, 5 apart, as MapPins.lua's)
	-- round dx, dy from the map's middle mx, my; only those inside its square.
	function RG.MapCircle(self, mx, my, dx, dy, radius, half, r, g, b, a)
		local count = math.max(16, math.min(120, math.floor(2 * math.pi * radius / 5)))
		for index = 1, count do
			local angle = 2 * math.pi * index / count
			local x, y = dx + radius * math.cos(angle), dy + radius * math.sin(angle)
			if math.abs(x) <= half and math.abs(y) <= half then
				local dot = self:Box(r, g, b, a, ART.."PaceDot", "OVERLAY")
				dot:SetWidth(3)
				dot:SetHeight(3)
				dot:SetPoint("CENTER", self, "TOPLEFT", mx + x, my + y)
			end
		end
	end

	-- On the minimap: its square, you in its middle, your ring at its zoom
	-- (left out, as in the game, while wider than the square), and a lair
	-- south-east of you with the guardian's rings (the aggro ring only once
	-- the zoom makes it wide enough round the lair's pin).
	function RG.Map(self, yards, height)
		local side = 112
		local mapX, mapTop = PAGE_WIDTH - 36 - side, -22
		local edge = self:Box(0, 0, 0, 1, nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", self, "TOPLEFT", mapX - 1, mapTop + 1)
		edge:SetWidth(side + 2)
		edge:SetHeight(side + 2)
		local map = self:Box(0.20, 0.26, 0.13, 1, nil, "BORDER")
		map:SetPoint("TOPLEFT", self, "TOPLEFT", mapX, mapTop)
		map:SetWidth(side)
		map:SetHeight(side)
		local cx, cy = mapX + side / 2, mapTop - side / 2
		local mapOn = RG.On("rangeMinimap")
		local across = SurvivorUI_MinimapYards and SurvivorUI_MinimapYards()
		local per = across and across > 0 and side / across
		local radius = per and yards * per
		if not mapOn then
			self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", 0.45, 0.55, 0.35, "Off"):SetPoint("CENTER", map, "CENTER", 0, 14)
		elseif not radius or 2 * radius > side or 2 * radius < 6 then
			self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", 0.45, 0.55, 0.35, "Wider than\nthis zoom"):SetPoint("CENTER", map, "CENTER", 0, 18)
		else
			if RG.Look("Map", "Shade") then
				local sr, sg, sb = SurvivorUI_RangeColor("Map")
				local shade = self:Box(sr, sg, sb, 0.3 * RG.Look("Map", "Alpha", 0.9), ART.."Disc")
				shade:SetWidth(2 * radius)
				shade:SetHeight(2 * radius)
				shade:SetPoint("CENTER", self, "TOPLEFT", cx, cy)
			end
			RG.pen.layer = "OVERLAY"
			RG.Trace(self, "Map", 64, cx, cy, radius, radius)
		end
		if per and RG.On("leashMinimap") then
			local gx, gy, half = 40 * per, -30 * per, side / 2 - 1.5
			local pin = self:Box(1, 1, 1, 1, ART.."PinLair", "OVERLAY")
			pin:SetWidth(10)
			pin:SetHeight(10)
			pin:SetPoint("CENTER", self, "TOPLEFT", cx + gx, cy + gy)
			if RG.On("leashReset") then
				local r, g, b = SurvivorUI_RangeColor("Leash")
				RG.MapCircle(self, cx, cy, gx, gy, RG.LEASH * per, half, r, g, b, RG.Look("Leash", "Alpha", 0.85))
			end
			local pinSize = SurvivorUI_PinSize and SurvivorUI_PinSize("lair") or 16
			if RG.On("leashWake") and 2 * RG.WAKE * Minimap:GetWidth() / across >= 1.6 * pinSize then
				local r, g, b = SurvivorUI_RangeColor("Wake")
				RG.MapCircle(self, cx, cy, gx, gy, RG.WAKE * per, half, r, g, b, RG.Look("Wake", "Alpha", 0.8))
			end
		end
		local you = self:Box(1, 0.82, 0.2, 1, ART.."PaceDot", "OVERLAY")
		you:SetWidth(6)
		you:SetHeight(6)
		you:SetPoint("CENTER", self, "TOPLEFT", cx, cy)
		RG.Name(self, "Minimap", mapOn, "Map", "BOTTOM", cx, -height + 6)
	end

	function Paint.Range(self)
		self:Begin()
		local height = self:GetHeight()
		if not (SurvivorUI_RangeAlong and SurvivorUI_WorldOn) then
			self:Word(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE", MUTED[1], MUTED[2], MUTED[3], "The game's 0.139.2 or later"):SetPoint("CENTER", self, "CENTER", 0, 0)
			return
		end
		-- How far: the build's longest spell in a run, else a sample.
		local yards, name
		if SurvivorUI_LongestReach then
			yards, name = SurvivorUI_LongestReach()
		end
		local said = yards and (name and SurvivorUI_OTF("{1}, {2} yd", SurvivorUI_Native(name), yards)
			or SurvivorUI_OTF("{1} yd", yards)) or "A sample: 30 yd"
		self:Word(SurvivorUI_FONT, 9 + FONT_BUMP, "", MUTED[1], MUTED[2], MUTED[3], said):SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -6)
		RG.Ground(self, yards or 30, height)
		RG.Map(self, yards or 30, height)
	end
	Kit.Preview(tab, 146, Paint.Range)

	-- Under it, which spell sets your ring's reach and why (the class's spell
	-- while the build holds it, else the longest), and the way to Spell per
	-- class, which words it (pages.rangespell.Said).
	RG.WHY = Kit.Link(tab, "The longest of your build.", "rangespell")
	function RG.WHY:Refresh()
		local said = pages.rangespell.Said and pages.rangespell.Said(true) or SurvivorUI_OT("The longest of your build.")
		self.text:SetText(said.."  |cffd8d8de"..SurvivorUI_OT(pages.rangespell.label).."  >|r")
		self:SetWidth(math.ceil(self.text:GetStringWidth()) + 4)
	end
	table.insert(widgets, RG.WHY)

	-- Faded and still: a frame's buttons and bars (theirs too) take the
	-- mouse only while on.
	function RG.Mouse(frame, on)
		local kids = { frame:GetChildren() }
		for index = 1, table.getn(kids) do
			local kid = kids[index]
			local kind = kid:GetObjectType()
			if kind == "Button" or kind == "Slider" then
				kid:EnableMouse(on)
			end
			if kind == "Slider" then
				kid:EnableMouseWheel(on)
			end
			RG.Mouse(kid, on)
		end
	end

	function RG.Still(frame, on)
		on = on and true or false
		frame:SetAlpha(on and 1 or 0.4)
		if frame.still ~= not on then
			frame.still = not on
			RG.Mouse(frame, on)
		end
	end

	-- The picker: the four across the page, each with a dot before its name,
	-- lit in the ring's color while it shows, an empty ring while off.
	function RG.Spread(holder)
		local count = table.getn(holder.parts)
		local each = math.floor((PAGE_WIDTH - 4) / count)
		for index = 1, count do
			local part = holder.parts[index]
			part:SetWidth(each)
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", holder, "TOPLEFT", 2 + (index - 1) * each, -2)
			part.label:ClearAllPoints()
			part.label:SetPoint("CENTER", part, "CENTER", 6, 0)
			part.dot = part:CreateTexture(nil, "OVERLAY")
			part.dot:SetWidth(8)
			part.dot:SetHeight(8)
			part.dot:SetPoint("RIGHT", part.label, "LEFT", -6, 0)
		end
		holder:SetWidth(2 + count * each + 2)
		local Lit = holder.Refresh
		function holder:Refresh()
			Lit(self)
			for index = 1, table.getn(self.parts) do
				local part = self.parts[index]
				if RG.Shown(part.value) and SurvivorUI_RangeColor then
					local r, g, b = SurvivorUI_RangeColor(part.value)
					part.dot:SetTexture(ART.."PaceDot")
					part.dot:SetVertexColor(r, g, b, 1)
				else
					part.dot:SetTexture(ART.."Ring")
					part.dot:SetVertexColor(MUTED[1], MUTED[2], MUTED[3], 0.9)
				end
			end
		end
	end
	Kit.Section(tab, "Ring", "Pick a ring: whether it shows, then its look. The dot on each is lit in its color while it shows. Yours reaches as far as your class's spell strikes (Spell per class) while it is in your build, else as far as your longest-reaching spell (heals, shields, buffs and the racial left out). A guardian asleep in its lair wakes when you come within 20 yards of it, or at a hit from any distance. Awake, it gives up once you, not it, go more than 97.5 yards from its lair: it heals to full, loses its debuffs and walks home.")
	RG.Spread(Kit.Segments(tab, RG.RINGS, function() return RG.editing end, function(value) RG.editing = value end))

	-- An extra of the ring's on its row: a look's own on or off (its yards,
	-- its shade), or one of the rings' switches.
	function RG.Flag(name, which, field, help)
		return { name, RG.Get(which, field, false), function() RG.Set(which, field)(not RG.Look(which, field, false)) end, help,
			usable = function() return RG.Shown(which) end, why = "The ring is off." }
	end

	function RG.Chip(name, key, help, usable, why)
		return { name, RG.While(key), function() if SurvivorUI_ToggleWorld then SurvivorUI_ToggleWorld(key) end end,
			help, usable = usable, why = why }
	end
	RG.MINIMAP = RG.Chip("On the minimap", "leashMinimap", "Both guardians' rings on the minimap too, always as dots in their color and opacity: the reset area round the awake guardian's lair, red in your last 10 yards, and the aggro ring once the zoom is close enough to read it round the lair's pin.",
		function() return RG.On("leashReset") or RG.On("leashWake") end, "Guardian aggro and Guardian reset are both off.")

	-- The ring's color: its first, the hero's class's, or another.
	function RG.Colors(page, which)
		local left = Span(page)
		Kit.Section(page, "Color")
		local list = SurvivorUI_RANGE_COLORS or {}
		for index = 1, table.getn(list) do
			local swatch = CreateFrame("Button", nil, page)
			swatch.key, swatch.name, swatch.tint = list[index][1], list[index][2], list[index][3]
			swatch:SetWidth(18)
			swatch:SetHeight(ROW)
			swatch:SetPoint("TOPLEFT", page, "TOPLEFT", left + (index - 1) * 24, page.y)
			swatch.edge = Fill(swatch, "BORDER", 0.3, 0.3, 0.35, 1)
			swatch.edge:SetWidth(18)
			swatch.edge:SetHeight(18)
			swatch.edge:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, -1)
			swatch.fill = Fill(swatch, "ARTWORK", 1, 1, 1, 1)
			swatch.fill:SetPoint("TOPLEFT", swatch.edge, "TOPLEFT", 2, -2)
			swatch.fill:SetPoint("BOTTOMRIGHT", swatch.edge, "BOTTOMRIGHT", -2, 2)
			swatch:SetScript("OnClick", function()
				RG.Set(which, "Color")(this.key)
				RefreshAll()
			end)
			swatch:SetScript("OnEnter", function()
				this.hot = true
				this:Refresh()
				GameTooltip:SetOwner(this, "ANCHOR_TOP")
				GameTooltip:SetText(SurvivorUI_OT(this.name), 1, 1, 1)
				GameTooltip:Show()
			end)
			swatch:SetScript("OnLeave", function()
				this.hot = nil
				this:Refresh()
				GameTooltip:Hide()
			end)
			function swatch:Refresh()
				if self.tint then
					self.fill:SetVertexColor(self.tint[1], self.tint[2], self.tint[3], 1)
				else
					self.fill:SetVertexColor(Paint.HeroColor())
				end
				local chosen = RG.Look(which, "Color", "ice") == self.key
				if chosen then
					self.edge:SetVertexColor(1, 1, 1, 1)
				elseif self.hot then
					self.edge:SetVertexColor(0.7, 0.7, 0.75, 1)
				else
					self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
				end
				self.fill:SetAlpha((chosen or self.hot) and 1 or 0.75)
			end
			table.insert(widgets, swatch)
		end
		page.y = page.y - ROW - 10
	end

	-- A ring's own, shown while it is the one picked: on a row its switch and
	-- extras (chips, a link at the right); under it its look, type and color
	-- on the left, size and opacity on the right, faded and still while it is
	-- off. Its height back.
	function RG.Box(which, top, extras, link)
		local sizes = RG.SIZES[which]
		local box = CreateFrame("Frame", nil, tab)
		box:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, top)
		box:SetWidth(PAGE_WIDTH)
		box.color, box.label, box.y, box.full = tab.color, tab.label, 0, PAGE_WIDTH
		Kit.Switch(box, 0, -1, function() return RG.Shown(which) end,
			function() if SurvivorUI_ToggleWorld then SurvivorUI_ToggleWorld(RG.KEYS[which]) end end)
		box.left, box.width = 92, PAGE_WIDTH - 92
		Kit.Chips(box, extras)
		box.left, box.width = nil, nil
		if link then
			local line = Kit.Link(box, link[1], link[2])
			line:ClearAllPoints()
			line:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -3)
		end
		local look = CreateFrame("Frame", nil, box)
		look:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -RG.BOX)
		look:SetWidth(PAGE_WIDTH)
		look.color, look.label, look.y, look.full = tab.color, tab.label, 0, PAGE_WIDTH
		Kit.Split(look)
		Kit.Section(look, "Type")
		Kit.Segments(look, RG.TYPES, RG.Get(which, "Look", "dots"), RG.Set(which, "Look"))
		RG.Colors(look, which)
		Kit.Right(look)
		local left, width = Span(look)
		Kit.Size(look, "Size", sizes[1], sizes[2], 1, RG.Get(which, "Size", sizes[4]), RG.Set(which, "Size", true), sizes[3], "%d px")
		Kit.Section(look, "Opacity")
		Kit.Bar(look, left, look.y - 3, width, 20, 100, 5,
			function() return math.floor(RG.Look(which, "Alpha", 0.8) * 100 + 0.5) end,
			function(value) RG.Set(which, "Alpha")(value / 100) end, "%d%%")
		look.y = look.y - 30
		Kit.Join(look)
		look:SetHeight(-look.y)
		box:SetHeight(RG.BOX - look.y)
		function box:Refresh()
			if RG.editing == which then
				self:Show()
			else
				self:Hide()
			end
			RG.Still(look, RG.Shown(which))
		end
		table.insert(widgets, box)
		return RG.BOX - look.y
	end

	local top = tab.y
	local tall = math.max(
		RG.Box("World", top, { RG.Flag("Yards", "World", "Yards", "How far it reaches, in its color, over the ring's highest point in sight.") }),
		RG.Box("Map", top, { RG.Flag("Shade inside", "Map", "Shade", "A faint fill of its color inside the ring: what is in reach.") },
			{ "Your marker on it:", "minimap" }),
		RG.Box("Wake", top, { RG.MINIMAP }),
		RG.Box("Leash", top, { RG.Chip("Warning", "leashWarn", "In your last 10 yards the ring turns into a red line that pulses, with the yards left beside it.",
			RG.While("leashReset"), "The ring is off."), RG.MINIMAP }))
	side.Index(tab, "Ring shown or hidden", "on off show hide switch character minimap guardian aggro reset", top, 22)
	side.Index(tab, "Yards", "character ring distance number", top, 22)
	side.Index(tab, "Shade inside", "minimap ring fill", top, 22)
	side.Index(tab, "Warning", "guardian reset last 10 yards red line", top, 22)
	side.Index(tab, "Guardians on the minimap", "guardian aggro reset rings minimap dots", top, 22)
	side.Index(tab, "Type", "dots dashes line", top - RG.BOX - 4, 47)
	side.Index(tab, "Color", "light blue class gold white red orange green teal purple pink", top - RG.BOX - 59, 41)
	side.Index(tab, "Size", "dot size small medium large thickness", top - RG.BOX - 4, 46)
	side.Index(tab, "Opacity", "alpha strong faint", top - RG.BOX - 54, 46)
	tab.y = top - tall - 4

	-- Advanced: the gap of the ring picked (faded and still for a line, which
	-- has none, or while it is off) on the left; the key on the right.
	function RG.Fine(box, which, top)
		local gaps = RG.GAPS[which]
		local fine = CreateFrame("Frame", nil, box)
		fine:SetPoint("TOPLEFT", box, "TOPLEFT", 0, top)
		fine:SetWidth(box.inset + box.width)
		fine:SetHeight(51)
		fine.color, fine.label, fine.y, fine.inset, fine.full = tab.color, tab.label, 0, box.inset, box.width
		Kit.Section(fine, "Gap", "Between the dots, and after each dash; a line has none.")
		local step = Kit.Stepper(fine, nil, gaps[1], gaps[2], 1, RG.Get(which, "Gap", gaps[3]), RG.Set(which, "Gap", true), "%d px")
		function fine:Refresh()
			if RG.editing == which then
				self:Show()
			else
				self:Hide()
			end
			RG.Still(step, RG.Shown(which) and RG.Look(which, "Look", "dots") ~= "line")
		end
		table.insert(widgets, fine)
	end

	do
		local box = Kit.Advanced(tab, "gap, key")
		Kit.Split(box)
		for index = 1, table.getn(RG.RINGS) do
			RG.Fine(box, RG.RINGS[index][1], box.y)
		end
		side.Index(box, "Gap", "between dots dashes", box.y - 4, 47)
		box.y = box.y - 51
		Kit.Right(box)
		-- The key at its title's right end; the minimap's button under it.
		Kit.Section(box, "Key", "Hides your two rings in one go and brings back the ones you had on, as the ring's button beside the minimap does. The guardians' rings stay.")
		local left, width = Span(box)
		local key = Kit.Key(box, tab.color, function() return "SURVIVORUI_RANGERING" end)
		key:SetPoint("TOPLEFT", box, "TOPLEFT", left + width - 84, box.y + 22)
		Kit.Link(box, "Its button:", "mapbuttons")
		Kit.Join(box)
		Kit.EndAdvanced(tab, box)
	end

	Kit.Foot(tab, { reset = Asked("Range indicator back to default?",
		"Every ring shown, in its first look: yours light blue, dots round your character and a line on the minimap, no yards or shade; the guardians' orange, dots for the aggro ring and dashes for the reset area, with the warning and on the minimap. The key stays.", "Back to default",
		function()
			if SurvivorUI_ResetRangeRings then
				SurvivorUI_ResetRangeRings()
			end
		end) })
end

------------------------------------------------------------------------------
-- Spell per class (Lucas, 2026-11-04): which spell's reach the range
-- indicator shows, one choice a class, kept for every hero of that class
-- (SurvivorUIDB.rangeSpells, the account's; BuildList.lua,
-- SurvivorUI_LongestReach): the class's spell while it is in the build, the
-- longest till then, as before.

-- Made with the kit: a line on what the indicator uses now and why, the
-- hero's class icon before it; then every class on a row, its icon and its
-- name in its color (the hero's row lit, "your hero" under its name), and
-- its choices as pills that wrap: Longest (the default), then each of the
-- class's spells the indicator can use, held or not, with its yards at its
-- first rank. The chosen one filled in the class's color; in the hero's row
-- a dot on each spell in the build now. Hover one for its reach and whether
-- the build holds it. The yards come off when the page would not hold them.

do
	local tab = pages.rangespell
	local SP = {
		-- Each class's spells as the game's 0.140 offers them, in its order (read
		-- in its exe: the classes' lists, and each spell's range, radius or cone
		-- as its tooltip shows it at its first rank): key in AZS_SPELLS, name,
		-- yards, and "radius" or "cone" for one with no range. Left out as
		-- BuildList.lua leaves them out: heals, shields, lasting buffs. Rockbiter
		-- Weapon is a Shaman's first spell with a talent.
		SPELLS = {
			WARRIOR = { { "cleave", "Cleave", 7 }, { "whirlwind", "Whirlwind", 8, "radius" }, { "thunder_clap", "Thunder Clap", 10, "radius" },
				{ "mortal_strike", "Mortal Strike", 7 }, { "execute", "Execute", 10 }, { "demo_shout", "Demoralizing Shout", 14, "radius" },
				{ "bloodthirst", "Bloodthirst", 7 }, { "rend", "Rend", 8 }, { "shield_slam", "Shield Slam", 7 }, { "bloodrage", "Bloodrage", 9, "radius" } },
			PALADIN = { { "consecration", "Consecration", 8, "radius" }, { "exorcism", "Exorcism", 25 }, { "hammer_of_wrath", "Hammer of Wrath", 28 },
				{ "holy_shock", "Holy Shock", 22 }, { "holy_wrath", "Holy Wrath", 12, "radius" }, { "judgement", "Judgement", 12 },
				{ "hammer_of_justice", "Hammer of Justice", 12 }, { "redemption", "Redemption", 8, "radius" } },
			HUNTER = { { "auto_shot", "Auto Shot", 32 }, { "arcane_shot", "Arcane Shot", 32 }, { "multi_shot", "Multi-Shot", 30 },
				{ "serpent_sting", "Serpent Sting", 30 }, { "volley", "Volley", 28 }, { "kill_command", "Kill Command", 35 },
				{ "concussive_shot", "Concussive Shot", 30 }, { "aimed_shot", "Aimed Shot", 35 }, { "immolation_trap", "Immolation Trap", 7, "radius" },
				{ "frost_trap", "Frost Trap", 10, "radius" }, { "hunters_mark", "Hunter's Mark", 8, "radius" } },
			ROGUE = { { "sinister_strike", "Sinister Strike", 8 }, { "eviscerate", "Eviscerate", 8 }, { "blade_flurry", "Blade Flurry", 7, "radius" },
				{ "rupture", "Rupture", 8 }, { "kidney_shot", "Kidney Shot", 8 }, { "gouge", "Gouge", 8 }, { "ghostly_strike", "Ghostly Strike", 8 },
				{ "backstab", "Backstab", 8 }, { "seal_fate", "Seal Fate", 8 } },
			PRIEST = { { "smite", "Smite", 28 }, { "sw_pain", "Shadow Word: Pain", 28 }, { "mind_blast", "Mind Blast", 28 },
				{ "holy_nova", "Holy Nova", 10, "radius" }, { "holy_fire", "Holy Fire", 28 }, { "mind_flay", "Mind Flay", 16, "cone" },
				{ "psychic_scream", "Psychic Scream", 10, "radius" }, { "devouring_plague", "Devouring Plague", 28 }, { "lightwell", "Lightwell", 25 } },
			SHAMAN = { { "lightning_bolt", "Lightning Bolt", 30 }, { "chain_lightning", "Chain Lightning", 28 }, { "earth_shock", "Earth Shock", 20 },
				{ "flame_shock", "Flame Shock", 20 }, { "frost_shock", "Frost Shock", 20 }, { "magma_totem", "Magma Totem", 10, "radius" },
				{ "searing_totem", "Searing Totem", 22 }, { "fire_nova", "Fire Nova", 12, "radius" }, { "stormstrike", "Stormstrike", 10 },
				{ "rockbiter", "Rockbiter Weapon", 10 } },
			MAGE = { { "fireball", "Fireball", 30 }, { "frostbolt", "Frostbolt", 30 }, { "arcane_missiles", "Arcane Missiles", 28 },
				{ "frost_nova", "Frost Nova", 10, "radius" }, { "arcane_explosion", "Arcane Explosion", 9, "radius" }, { "blizzard", "Blizzard", 30 },
				{ "flamestrike", "Flamestrike", 30 }, { "fire_blast", "Fire Blast", 22 }, { "cone_of_cold", "Cone of Cold", 12, "cone" },
				{ "blast_wave", "Blast Wave", 10, "radius" }, { "pyroblast", "Pyroblast", 35 }, { "polymorph", "Polymorph", 7, "radius" } },
			WARLOCK = { { "shadow_bolt", "Shadow Bolt", 30 }, { "corruption", "Corruption", 30 }, { "immolate", "Immolate", 30 },
				{ "curse_of_agony", "Curse of Agony", 30 }, { "rain_of_fire", "Rain of Fire", 30 }, { "hellfire", "Hellfire", 7, "radius" },
				{ "death_coil", "Death Coil", 25 }, { "searing_pain", "Searing Pain", 26 }, { "drain_life", "Drain Life", 22 }, { "fear", "Fear", 20 },
				{ "soul_fire", "Soulfire", 35 } },
			DRUID = { { "wrath", "Wrath", 30 }, { "moonfire", "Moonfire", 30 }, { "starfire", "Starfire", 32 }, { "hurricane", "Hurricane", 28 },
				{ "insect_swarm", "Insect Swarm", 28 }, { "entangling_roots", "Entangling Roots", 25 }, { "swipe", "Swipe", 7, "radius" },
				{ "faerie_fire", "Faerie Fire", 8, "radius" }, { "shred", "Shred", 7 } },
		},
		-- A pill's tooltip: its yards, by the kind of its reach.
		REACH = { range = "{1} yd range at its first rank, before bonuses.",
			radius = "{1} yd radius at its first rank, before bonuses.", cone = "{1} yd cone at its first rank, before bonuses." },
		PILL = 16, STEP = 19,          -- a pill's height, and from one line of them to the next
		NAME = 82,                     -- the class's icon and name, left of its pills
		GAP = 4,                       -- between two classes
		LOW = -(HEIGHT - 70) + 46,     -- the lowest the rows may reach, over the page's foot
		rows = {},
	}
	Kit.Head(tab, { line = "Which spell's reach the range indicator shows: one choice a class, kept for every hero of it." })

	-- The hero's class ("WARRIOR") and its name, nil out of one.
	function SP.Hero()
		local class = HeroClass()
		for index = 1, table.getn(CLASSES) do
			if CLASSES[index][1] == class then
				return class, CLASSES[index][2]
			end
		end
	end

	-- A spell's name as the page shows it, in the game's language.
	function SP.Native(name)
		return SurvivorUI_Native and SurvivorUI_Native(name) or name
	end

	function SP.Name(class, key)
		local list = SP.SPELLS[class] or {}
		for index = 1, table.getn(list) do
			if list[index][1] == key then
				return SP.Native(list[index][2])
			end
		end
		return key
	end

	-- In a run, where the rings show (WorldMarks.lua).
	function SP.Running()
		local phase = AZS_GetPhase and AZS_GetPhase()
		return phase == "playing" or phase == "choosing" or phase == "paused"
	end

	function SP.Hex(color)
		return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
	end

	-- What sets the rings' reach now and why: this page's line, with the
	-- yards, or short, the Range indicator's (it asks as it refreshes).
	function tab.Said(short)
		local class, className = SP.Hero()
		className = className and SurvivorUI_OT(className)
		local choice = class and SurvivorUI_RangeSpell and SurvivorUI_RangeSpell(class)
		local chosen = choice and SP.Name(class, choice)
		if not (class and SP.Running()) then
			if chosen then
				return short and SurvivorUI_OTF("Your choice for {1}: {2}, while it is in your build.", className, chosen)
					or SurvivorUI_OTF("In a run: {1} while it is in your build, the longest till then.", chosen)
			end
			return SurvivorUI_OT(short and "The longest of your build." or "In a run: the longest of your build.")
		end
		local yards, name, why
		if SurvivorUI_LongestReach then
			yards, name, why = SurvivorUI_LongestReach()
		end
		if why == "chosen" then
			return short and SurvivorUI_OTF("Your choice for {1}: {2}.", className, chosen)
				or SurvivorUI_OTF("Now: {1}, {2} yd.", chosen, yards)
		end
		local longest = name and yards and SurvivorUI_OTF("{1}, {2} yd", SP.Native(name), yards)
		if chosen then
			if short then
				return SurvivorUI_OTF("Your choice for {1}, {2}, isn't in your build yet: the longest.", className, chosen)
			end
			return longest and SurvivorUI_OTF("{1} isn't in your build yet: the longest, {2}.", chosen, longest)
				or SurvivorUI_OTF("{1} isn't in your build yet: the longest.", chosen)
		end
		if short then
			return SurvivorUI_OT("The longest of your build.")
		end
		return longest and SurvivorUI_OTF("Now: the longest of your build, {1}.", longest) or SurvivorUI_OT("Now: the longest of your build.")
	end

	-- The line: the hero's class icon, its name in its color, what is used now.
	do
		local now = CreateFrame("Frame", nil, tab)
		now:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, tab.y - 2)
		now:SetWidth(PAGE_WIDTH)
		now:SetHeight(18)
		now.icon = now:CreateTexture(nil, "ARTWORK")
		now.icon:SetWidth(16)
		now.icon:SetHeight(16)
		now.icon:SetPoint("LEFT", now, "LEFT", 4, 0)
		now.text = Text(now, 10, TEXT)
		now.text:SetPoint("LEFT", now.icon, "RIGHT", 6, 0)
		function now:Refresh()
			local class, className = SP.Hero()
			local texture, coords
			if class and SurvivorUI_ClassIcon then
				texture, coords = SurvivorUI_ClassIcon(class)
			end
			if coords then
				self.icon:SetTexture(texture)
				self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
				self.icon:Show()
			else
				self.icon:Hide()
			end
			local said = tab.Said() or ""
			if class and SurvivorUI_ClassColor then
				said = SP.Hex({ SurvivorUI_ClassColor(class) })..SurvivorUI_OT(className).."|r   "..said
			end
			self.text:SetText(said)
		end
		table.insert(widgets, now)
		side.Index(tab, "Now", "what the range indicator uses now your hero class build longest", tab.y, 18)
		tab.y = tab.y - 28
	end

	Kit.Section(tab, "Each class", "Pick a spell for each class, once: every hero of that class follows it. The range indicator then reaches as far as that spell strikes while it is in your build, and as far as your longest-reaching spell till then. Longest, the default, is always the longest (heals, shields, buffs and the racial left out). Each spell's yards are its first rank's, before bonuses; a dot marks the spells in your build now.")
	SP.top = tab.y

	-- A choice of a class's: a pill with its name and its yards, filled in the
	-- class's color while chosen. spell: { key, name, yards, kind }, or none
	-- for Longest.
	function SP.Tip(pill)
		local row, spell = pill.row, pill.spell
		local c = row.tint
		GameTooltip:SetOwner(pill, "ANCHOR_TOP")
		GameTooltip:SetText(pill.label:GetText(), c[1], c[2], c[3])
		if not spell then
			GameTooltip:AddLine(SurvivorUI_OT("The longest reach among your build's spells that strike: heals, shields, buffs and the racial left out. The default."), 1, 1, 1, 1)
		else
			GameTooltip:AddLine(SurvivorUI_OTF(SP.REACH[spell[4] or "range"], spell[3]), 1, 1, 1, 1)
			if row.held then
				local held, yards = false, nil
				if SurvivorUI_SpellReach then
					held, yards = SurvivorUI_SpellReach(spell[1])
				end
				if held then
					GameTooltip:AddLine(yards and SurvivorUI_OTF("In your build: {1} yd now.", yards) or SurvivorUI_OT("In your build."), Kit.Light(c, 0.4))
				else
					GameTooltip:AddLine(SurvivorUI_OT("Not in your build yet: while it is chosen, the indicator shows the longest until it is."), MUTED[1], MUTED[2], MUTED[3], 1)
				end
			end
		end
		GameTooltip:Show()
	end

	function SP.Pill(row, spell)
		local pill = CreateFrame("Button", nil, row)
		pill:SetHeight(SP.PILL)
		Boxed(pill, WELL, EDGE)
		pill.label = Text(pill, 9, TEXT)
		pill.label:SetPoint("LEFT", pill, "LEFT", 6, 0)
		pill.label:SetText(spell and SP.Native(spell[2]) or "Longest")
		pill.reach = Text(pill, 8, MUTED)
		pill.reach:SetPoint("LEFT", pill.label, "RIGHT", 3, 0)
		pill.reach:SetText(spell and tostring(spell[3]) or "")
		pill.dot = pill:CreateTexture(nil, "OVERLAY")
		pill.dot:SetTexture(ART.."PaceDot")
		pill.dot:SetWidth(6)
		pill.dot:SetHeight(6)
		pill.dot:SetPoint("CENTER", pill, "TOPRIGHT", -3, -3)
		pill.row, pill.spell, pill.key = row, spell, spell and spell[1]
		pill:SetScript("OnClick", function()
			if SurvivorUI_SetRangeSpell then
				SurvivorUI_SetRangeSpell(this.row.class, this.key)
			end
			RefreshAll()
		end)
		pill:SetScript("OnEnter", function()
			this.hot = true
			this:Refresh()
			SP.Tip(this)
		end)
		pill:SetScript("OnLeave", function()
			this.hot = nil
			this:Refresh()
			GameTooltip:Hide()
		end)
		function pill:Refresh()
			local c = self.row.tint
			local on = (SurvivorUI_RangeSpell and SurvivorUI_RangeSpell(self.row.class) or nil) == self.key
			if on then
				self:SetBackdropColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 1)
				self:SetBackdropBorderColor(c[1], c[2], c[3], 1)
				self.reach:SetTextColor(Kit.Light(c, 0.25))
			else
				self:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
				local edge = self.hot and 0.45 or EDGE[1]
				self:SetBackdropBorderColor(edge, edge, edge + 0.05, 1)
				self.reach:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
			if self.hot then
				self.label:SetTextColor(1, 1, 1)
			elseif on then
				self.label:SetTextColor(Kit.Light(c, 0.6))
			else
				self.label:SetTextColor(TEXT[1] * 0.8, TEXT[2] * 0.8, TEXT[3] * 0.82)
			end
			if self.key and self.row.held and self.row.held[self.key] then
				self.dot:SetVertexColor(Kit.Light(c, 0.3))
				self.dot:Show()
			else
				self.dot:Hide()
			end
		end
		table.insert(widgets, pill)
		table.insert(row.pills, pill)
	end

	-- A class's row: refreshed before its pills, so they know whether it is
	-- the hero's and what its build holds.
	function SP.Row(class, className)
		local row = CreateFrame("Frame", nil, tab)
		row:SetWidth(PAGE_WIDTH)
		row.class, row.pills = class, {}
		row.tint = { 1, 0.82, 0 }
		if SurvivorUI_ClassColor then
			row.tint = { SurvivorUI_ClassColor(class) }
		end
		local c = row.tint
		row.wash = Fill(row, "BACKGROUND", c[1], c[2], c[3], 0)
		row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 3)
		row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(16)
		row.icon:SetHeight(16)
		row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0)
		local texture, coords
		if SurvivorUI_ClassIcon then
			texture, coords = SurvivorUI_ClassIcon(class)
		end
		if coords then
			row.icon:SetTexture(texture)
			row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		end
		row.name = Text(row, 10, c)
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
		row.name:SetText(className)
		row.you = Text(row, 8, MUTED)
		row.you:SetPoint("TOPLEFT", row.icon, "BOTTOMLEFT", 0, -3)
		row.you:SetText("your hero")
		function row:Refresh()
			self.hero = HeroClass() == self.class
			local tint = self.tint
			self.wash:SetVertexColor(tint[1], tint[2], tint[3], self.hero and 0.10 or 0)
			if self.hero then
				self.you:Show()
			else
				self.you:Hide()
			end
			-- The keys the build holds now (the racial, last, left out).
			self.held = nil
			if self.hero and SP.Running() then
				self.held = {}
				local spells = AZS_SPELLS or {}
				for index = 1, table.getn(spells) - 1 do
					local key = spells[index].key or spells[index][1]
					if key then
						self.held[key] = true
					end
				end
			end
		end
		table.insert(widgets, row)
		SP.Pill(row, nil)
		local list = SP.SPELLS[class] or {}
		for index = 1, table.getn(list) do
			SP.Pill(row, list[index])
		end
		table.insert(SP.rows, row)
	end

	-- The spells' names in the game's language, known only once the game has
	-- told it (after this page is made): the pills named again, and laid
	-- again, as a name changes. Refreshed before the rows and their pills.
	do
		local names = CreateFrame("Frame", nil, tab)
		function names:Refresh()
			local changed
			for index = 1, table.getn(SP.rows) do
				local pills = SP.rows[index].pills
				for each = 2, table.getn(pills) do
					local name = SP.Native(pills[each].spell[2])
					if pills[each].label:GetText() ~= name then
						pills[each].label:SetText(name)
						changed = true
					end
				end
			end
			if changed then
				SP.Place()
			end
		end
		table.insert(widgets, names)
	end

	for index = 1, table.getn(CLASSES) do
		SP.Row(CLASSES[index][1], CLASSES[index][2])
	end

	-- The rows down the page, each class's pills wrapping in its room, the
	-- yards on them or not; where the last ends.
	function SP.Lay(yards)
		local y = SP.top
		local room = PAGE_WIDTH - SP.NAME
		for index = 1, table.getn(SP.rows) do
			local row = SP.rows[index]
			local x, line = 0, 0
			for each = 1, table.getn(row.pills) do
				local pill = row.pills[each]
				local width = 6 + math.ceil(pill.label:GetStringWidth()) + 6
				if yards and pill.spell then
					width = width + 3 + math.ceil(pill.reach:GetStringWidth())
					pill.reach:Show()
				else
					pill.reach:Hide()
				end
				if x > 0 and x + width > room then
					x, line = 0, line + 1
				end
				pill:SetWidth(width)
				pill:ClearAllPoints()
				pill:SetPoint("TOPLEFT", row, "TOPLEFT", SP.NAME + x, -line * SP.STEP)
				x = x + width + 3
			end
			local height = math.max((line + 1) * SP.STEP - 3, 34)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y)
			row:SetHeight(height)
			row.y, row.height = y, height
			y = y - height - SP.GAP
		end
		return y
	end
	-- The yards on them while the page holds them (both depths kept for the
	-- tests); the link to the rings under the last row, if there is room.
	function SP.Place()
		local y = SP.Lay(true)
		tab.lows = { y }
		if y < SP.LOW then
			y = SP.Lay(false)
			tab.lows[2] = y
		end
		if SP.link then
			SP.link:ClearAllPoints()
			SP.link:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y)
			if y - 20 >= SP.LOW then
				SP.link:Show()
			else
				SP.link:Hide()
			end
		end
		return y
	end
	tab.y = SP.Place()
	for index = 1, table.getn(SP.rows) do
		local row = SP.rows[index]
		local names = {}
		for each = 2, table.getn(row.pills) do
			table.insert(names, row.pills[each].spell[2])
		end
		side.Index(tab, row.name:GetText(), "longest "..table.concat(names, " "), row.y, row.height)
	end
	SP.link = Kit.Link(tab, "The rings, their look and their key, in", "range")
	SP.Place()
	-- In another language, the pills as wide as their names in it.
	table.insert(side.fits, SP.Place)

	Kit.Foot(tab, { reset = Asked("Spell per class back to default?",
		"Every class back to Longest: the range indicator reaches as far as your build's longest-reaching spell, as before.", "Back to default",
		function()
			if SurvivorUIDB then
				SurvivorUIDB.rangeSpells = nil
			end
		end) })
end

------------------------------------------------------------------------------
-- Layout.

page = pages.layout
Header(page, "Layout", "Move UI, the button at the top of this window (or a right click on the minimap button), unlocks every piece over a grid: one let go snaps to the grid, or to a neighbour's edge. Holding Alt (the move key, below) shows the same grid, and a piece dragged with it snaps too (let go of it first to put it down free). Click a piece for its card: its place, size and font, shown or hidden, reset and undo. Each tab's own pieces can be dragged while it is open, so you can play while setting them.")
Subheader(page, "Move key")
Inline(page, "Held to move", {
	{ "alt", "Alt" },
	{ "ctrl", "Ctrl" },
	{ "shift", "Shift" },
	{ "none", "None" },
}, function() return SurvivorUI_MoveKey and SurvivorUI_MoveKey() or "alt" end,
	function(value) DB().moveKey = value end)
Note(page, "The key held to see the grid and drag the pieces while you play. Another one, or none (Move UI only), when Alt is your push to talk.")
-- What stays over the cards (Mover.lua): nothing at first, the pieces ticked
-- once the switch on top is off.
Subheader(page, "While choosing cards")
Check(page, "Hide everything while choosing cards", function() return next(SurvivorUI_CardsShown()) == nil end, function()
	local shown = SurvivorUI_CardsShown()
	local hide = next(shown) ~= nil
	for index = 1, table.getn(SurvivorUI_CARD_PIECES) do
		shown[SurvivorUI_CARD_PIECES[index].key] = (not hide) or nil
	end
	SurvivorUI_RefreshCards()
end, "a level's cards and a new piece of jewelry: on a small screen they are large, and the pieces stood on them. Untick it for everything as before, or tick below only what you want over them.")
for index = 1, table.getn(SurvivorUI_CARD_PIECES) do
	local piece = SurvivorUI_CARD_PIECES[index]
	Check(page, piece.label, function() return SurvivorUI_CardsShown()[piece.key] == true end, function()
		local shown = SurvivorUI_CardsShown()
		shown[piece.key] = (not shown[piece.key]) or nil
		SurvivorUI_RefreshCards()
	end)
end
Note(page, "A piece ticked stays lit over the game's dark veil and takes its clicks there, with its tooltips. In the cards' part of the screen (the action bar, the player frame) it fades out all the same, so nothing covers a card.")
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

-- Move UI: at the sidebar's foot, beside Donate (and on the minimized bar),
-- in the Layout tab's color, filled and breathing a glow so it is seen at
-- once; "Done moving" while it is on.
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
editButton:SetWidth(98)
editButton:SetHeight(24)
editButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", SIDEBAR - 8, 46)
editButton.glow:SetWidth(140)
table.insert(widgets, editButton)

-- Change UI: over Donate and Move UI, straight to the box that picks this
-- addon or SurvivorUI Classic (ChangeUI.lua), with that one installed.
if SurvivorUI_CanChangeUI and SurvivorUI_CanChangeUI() then
	local change = CreateFrame("Button", "SurvivorUIChangeUIButton", panel)
	change:SetWidth(SIDEBAR - 18)
	change:SetHeight(22)
	change:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 76)
	change:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	change.text = Text(change, 10, TEXT)
	change.text:SetPoint("CENTER", change, "CENTER", 0, 0)
	change.text:SetText(SurvivorUI_T("Change UI"))
	change:SetScript("OnClick", function()
		panel:Hide()
		SurvivorUI_ChangeUI()
	end)
	change:SetScript("OnEnter", function()
		this.hot = true
		this:Refresh()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(SurvivorUI_T("Change UI"), ACCENT[1], ACCENT[2], ACCENT[3])
		GameTooltip:AddLine(SurvivorUI_T("Pick Survivor UI or SurvivorUI Classic. The other one runs from the next time the game starts."), 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	change:SetScript("OnLeave", function()
		this.hot = nil
		this:Refresh()
		GameTooltip:Hide()
	end)
	function change:Refresh()
		if self.hot then
			self.text:SetTextColor(1, 1, 1)
		else
			self.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		end
		self:SetBackdropColor(0.12, 0.12, 0.15, 1)
		self:SetBackdropBorderColor(0.4, 0.4, 0.45, self.hot and 1 or 0.8)
	end
	change:Refresh()
	table.insert(widgets, change)
end

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
	GameTooltip:SetText(SurvivorUI_OT("Minimize"), 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_OT("Down to Maximize, Move UI and Save & Close, to set the pieces with the screen free."), 0.8, 0.8, 0.8, 1)
	GameTooltip:Show()
end)
minimize:SetScript("OnLeave", function()
	this:Light(false)
	GameTooltip:Hide()
end)
minimize:SetScript("OnClick", Minimize)

local credit = panel:CreateFontString(nil, "OVERLAY")
credit:SetFont(SurvivorUI_FONT, 9, "")
credit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 8)
credit:SetWidth(SIDEBAR - 18)
credit:SetJustifyH("LEFT")
credit:SetTextColor(0.42, 0.42, 0.47)
credit:SetText("by morderous \194\183 GPL-3.0\ngithub.com/morderous/\nsurvivor-ui")

-- Donate, for the Ko-fi, in a light blue. The game opens no link: it shows in
-- a box, selected, for Ctrl+C.
local KOFI = "https://ko-fi.com/morderous"
local DONATE_BLUE = { 0.62, 0.84, 1.00 }

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
		linkBox:SetBackdropColor(0.03, 0.05, 0.08, 0.98)
		linkBox:SetBackdropBorderColor(DONATE_BLUE[1] * 0.75, DONATE_BLUE[2] * 0.75, DONATE_BLUE[3] * 0.75, 1)
		linkBox.title = Text(linkBox, 12, DONATE_BLUE)
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
		edit:SetBackdropBorderColor(0.28, 0.32, 0.38, 1)
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

-- The button: a box in the Run History's Left look, in a lighter blue, alive
-- as it is (RunHistory.lua's "donate": its glow breathing, its sparks
-- drifting out to the right), brighter under the mouse. A little smaller than
-- the window's other buttons (a scale, so its word shrinks with it); its place
-- in the window's own units.
local SUPPORT_SCALE = 0.8
local donate = CreateFrame("Button", nil, panel)
donate:SetScale(SUPPORT_SCALE)
donate:SetWidth(100)
donate:SetHeight(24)
-- At the sidebar's foot beside Move UI, over the credit: the groups open
-- one at a time, so the list no longer reaches down there (v3.1).
donate:SetPoint("LEFT", panel, "BOTTOMLEFT", 10 / SUPPORT_SCALE, (46 + 12) / SUPPORT_SCALE)
-- Set again each time the window opens: its width by the word in the font
-- worn by then (the global font comes after this file), the word in its
-- middle, and a burst of sparks.
local function DressDonate()
	if not donate.badge then
		return
	end
	SurvivorUI_SetResultBadge(donate.badge, "donate", nil)
	donate.badge.text:ClearAllPoints()
	donate.badge.text:SetPoint("CENTER", donate.badge, "CENTER", 0, 0)
	donate:SetWidth(donate.badge:GetWidth())
end
if SurvivorUI_ResultBadge then
	donate.badge = SurvivorUI_ResultBadge(donate)
	donate.badge:SetPoint("CENTER", donate, "CENTER", 0, 0)
	DressDonate()
end
donate:SetScript("OnShow", DressDonate)
donate:SetScript("OnEnter", function()
	if this.badge then
		this.badge.hot = true
	end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(SurvivorUI_OT("If you want to support this love project, feel free."), DONATE_BLUE[1], DONATE_BLUE[2], DONATE_BLUE[3])
	GameTooltip:Show()
end)
donate:SetScript("OnLeave", function()
	if this.badge then
		this.badge.hot = nil
	end
	GameTooltip:Hide()
end)
donate:SetScript("OnClick", function() ShowLink("Donate", KOFI) end)

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
	-- The search ends with the window, minimized or closed.
	side.going = true
	side.box:SetText("")
	side.box:ClearFocus()
	side.going = nil
	side.found = nil
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

-- The window open on a tab, by its key (Run History's and the tests' way to
-- a page): global, combat, bosses, chat...
function SurvivorUI_OpenOptions(key)
	if mini:IsShown() then
		Maximize()
	end
	if not pages[key] then
		key = current or "global"
	end
	current = key
	if panel:IsShown() then
		ShowPage(key)
	else
		panel:Show()
	end
end

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
