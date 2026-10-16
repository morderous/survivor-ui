-- Survivor UI: the options panel, /sui opt (or the minimap button).
--
-- A window with a column of tabs on the left, each in a color of its own, and
-- the tab's page on the right:
--   Panels      every panel on or off
--   Combat      how the combat numbers show, or none at all
--   Nameplates  Survivor Plates: on every enemy, the important ones, or none
--   Interface   the looks the addon gives the game's interface
--   Size        the whole interface's size and each part's own
--   Layout      move mode over a grid, the frames joined to the bar, resets
-- Panels and sizes act at once; most looks need a reload, and a change to one
-- lights the Reload button at the bottom. Move mode sits beside it, on every
-- page. Escape closes it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH, HEIGHT = 640, 500
local SIDEBAR = 150
local PAGE_X = SIDEBAR + 18               -- the pages' left edge
local PAGE_WIDTH = WIDTH - PAGE_X - 18
local ROW = 20
local MUTED = { 0.6, 0.6, 0.65 }
local TEXT = { 0.9, 0.9, 0.92 }

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
	text:SetFont(FONT, size + FONT_BUMP, flags or "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
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

local title = Text(panel, 15, { 1, 0.82, 0 })
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
	{ key = "panels", label = "Panels", color = { 1, 0.82, 0 } },
	{ key = "combat", label = "Combat", color = { 1, 0.38, 0.32 } },
	{ key = "plates", label = "Nameplates", color = { 0.38, 0.9, 0.45 } },
	{ key = "interface", label = "Interface", color = { 0.4, 0.68, 1 } },
	{ key = "size", label = "Size", color = { 0.78, 0.52, 1 } },
	{ key = "layout", label = "Layout", color = { 0.25, 0.85, 0.8 } },
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

local function Header(page, text, note)
	local header = Text(page, 13, page.color)
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	header:SetText(text)
	local rule = Fill(page, "ARTWORK", page.color[1], page.color[2], page.color[3], 0.35)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - 19)
	rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page.y - 19)
	page.y = page.y - 26
	if note then
		local hint = Text(page, 9, MUTED)
		hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
		hint:SetWidth(PAGE_WIDTH)
		hint:SetJustifyH("LEFT")
		hint:SetText(note)
		page.y = page.y - 24
	end
end

local function Subheader(page, text)
	page.y = page.y - 4
	local header = Text(page, 10, page.color)
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	header:SetText(text)
	page.y = page.y - 18
end

local function Note(page, text, lines)
	local hint = Text(page, 9, MUTED)
	hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	hint:SetWidth(PAGE_WIDTH)
	hint:SetJustifyH("LEFT")
	hint:SetText(text)
	page.y = page.y - 13 * (lines or 1) - 4
end

-- A check: a square in the page's color when on, and its label; a note in
-- grey beside it.
local function Check(page, label, isOn, toggle, note)
	local check = CreateFrame("Button", nil, page)
	check:SetWidth(PAGE_WIDTH)
	check:SetHeight(ROW)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	local color = page.color

	check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
	check.edge:SetWidth(13)
	check.edge:SetHeight(13)
	check.edge:SetPoint("LEFT", check, "LEFT", 2, 0)
	check.box = Fill(check, "ARTWORK", 0, 0, 0, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)

	check.label = Text(check, 11, TEXT)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 9, 0)
	check.label:SetText(label)
	if note then
		check.note = Text(check, 9, MUTED)
		check.note:SetPoint("LEFT", check.label, "RIGHT", 8, 0)
		check.note:SetText(note)
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
	page.y = page.y - ROW
	return check
end

-- A choice of one among several: round marks in the page's color, each
-- option with a note under it.
local function Choice(page, options, get, set)
	-- In order: pairs() walks a table in no set order in this client.
	for index = 1, table.getn(options) do
		local option = options[index]
		local value = option[1]
		local row = CreateFrame("Button", nil, page)
		row:SetWidth(PAGE_WIDTH)
		row:SetHeight(option[3] and 32 or ROW)
		row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
		local color = page.color

		row.ring = Fill(row, "BORDER", 0.3, 0.3, 0.35, 1)
		row.ring:SetWidth(13)
		row.ring:SetHeight(13)
		row.ring:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
		-- A ring: the edge, a dark inside, the mark in the middle.
		row.inner = Fill(row, "ARTWORK", 0.05, 0.05, 0.07, 1)
		row.inner:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 1, -1)
		row.inner:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -1, 1)
		row.dot = Fill(row, "OVERLAY", 0, 0, 0, 1)
		row.dot:SetPoint("TOPLEFT", row.ring, "TOPLEFT", 3, -3)
		row.dot:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -3, 3)

		row.label = Text(row, 11, TEXT)
		row.label:SetPoint("TOPLEFT", row.ring, "TOPRIGHT", 9, 0)
		row.label:SetText(option[2])
		if option[3] then
			row.note = Text(row, 9, MUTED)
			row.note:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
			row.note:SetText(option[3])
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
		page.y = page.y - (option[3] and 34 or ROW)
	end
end

-- A slider: its label, a flat track filled in the page's color up to the
-- thumb, and the value on the right. set() runs as it moves.
local function Slider(page, label, low, high, step, get, set, format)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(PAGE_WIDTH)
	holder:SetHeight(24)
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
	page.y = page.y - 26
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

------------------------------------------------------------------------------
-- Panels.

local page = pages.panels
Header(page, "Panels", "The addon's own panels. Each switches at once; hold Alt to move them, or use Layout.")
Check(page, "Run tracker", OnUnlessOff("tracker"), Call("SurvivorUI_ToggleTracker"), "the clock and the bosses, under the minimap")
Check(page, "Build list", OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild"), "spells, ranks and jewelry")
Check(page, "Damage meter", OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter"), "off: the game's own")
Check(page, "This Run", OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun"), "the run's numbers")
Check(page, "Biggest Crits", OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits"))
Check(page, "Boss bars", OnUnlessOff("bossBars"), Call("SurvivorUI_BossBars"), "with their debuffs")
Check(page, "Elites on the boss bars", OnlyIfOn("bossBarsElites"), Call("SurvivorUI_BossBars", "elites"))
Check(page, "Kills and gold line", OnUnlessOff("tally"), Call("SurvivorUI_Tally"), "off: the game's own box")
Check(page, "Loot list", OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot"), "what the run dropped")
Check(page, "Caches and lairs on the minimap", FeatureOn("mapPins"), FeatureToggle("mapPins", true))

------------------------------------------------------------------------------
-- Combat.

page = pages.combat
Header(page, "Combat text", "The numbers of the fight: the damage you deal, the hits you take and your heals.")
Choice(page, {
	{ "side", "Beside the hero", "Hits on the left, crits on the right, heals rising and damage taken falling below." },
	{ "quick", "Over the enemies", "Small and quick, over the enemy hit; crits big and gold. Your hits taken fall in red." },
	{ "game", "The game's own", "The engine's floating numbers and the game's combat text, as it shows them." },
	{ "none", "None at all", "No numbers and no floating combat text." },
}, function() return SurvivorUI_DamageMode and SurvivorUI_DamageMode() or "quick" end,
	function(mode) if SurvivorUI_SetDamageMode then SurvivorUI_SetDamageMode(mode) end end)

------------------------------------------------------------------------------
-- Nameplates.

page = pages.plates
Header(page, "Nameplates", "Survivor Plates' plates over the enemies, within 20 yards of the hero.")
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
		{ "all", "On every enemy", "Every enemy gets a plate." },
		{ "important", "Elites, guardians and bosses", "The dangerous ones only: a cleaner screen." },
		{ "none", "None", "No nameplates: the boss bars show bosses, guardians and elites (the default)." },
	}, PlatesMode, function(mode)
		local db = SurvivorPlatesDB or {}
		if (mode == "none") ~= (db.hidden == true) then
			Plates("none")
		end
		if mode ~= "none" and (mode == "important") ~= (db.important == true) then
			Plates("all")
		end
	end)
	page.y = page.y - 6
	Check(page, "Names on every plate", function() return SurvivorPlatesDB and SurvivorPlatesDB.names == true end,
		function() Plates("names") end, "off: on elites, guardians and bosses only")
	page.y = page.y - 8
	Slider(page, "Plate size", 0.6, 2, 0.05,
		function() return SurvivorPlates_GetScale and SurvivorPlates_GetScale() or 1 end,
		function(value) if SurvivorPlates_SetScale then SurvivorPlates_SetScale(value) end end)
else
	Note(page, "Survivor Plates is not installed. It comes in the same download as Survivor UI.", 2)
end

------------------------------------------------------------------------------
-- Interface.

page = pages.interface
Header(page, "Interface", "The looks the addon gives the game's interface. Most take hold after a reload.")
Check(page, "White outline under the mouse", OnUnlessOff("hover"), Call("SurvivorUI_ToggleHover"))
Check(page, "Cooldown numbers on the buttons", FeatureOn("cooldownNumbers"), FeatureToggle("cooldownNumbers"))
Check(page, "Hide key labels on the buttons", FeatureOn("hideKeys"), FeatureToggle("hideKeys"))
Check(page, "Ability tooltip, laid out again", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip"))
Check(page, "Character pane", FeatureOn("characterPane"), FeatureToggle("characterPane"))
Check(page, "Square minimap", FeatureOn("minimap"), FeatureToggle("minimap"))
Check(page, "Flat chat", FeatureOn("chat"), FeatureToggle("chat"))
Check(page, "Flat tooltips", FeatureOn("tooltip"), FeatureToggle("tooltip"))
Check(page, "One font everywhere", FeatureOn("fonts"), FeatureToggle("fonts"))
Check(page, "Menu buttons in the corner, on hover", FeatureOn("microMenu"), FeatureToggle("microMenu"))

------------------------------------------------------------------------------
-- Size.

page = pages.size
Header(page, "Size", "All sizes the whole interface; each part has its own on top of it. They act at once.")
Slider(page, "All", 0.6, 1.4, 0.05,
	function() return SurvivorUI_GetScale and SurvivorUI_GetScale() or 1 end,
	function(value) if SurvivorUI_SetScale then SurvivorUI_SetScale(value, true) end end)
Subheader(page, "Each part")
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
Button(page, "Every part back to 1", 180, 0, function()
	if SurvivorUI_ResetPartScales then
		SurvivorUI_ResetPartScales()
	end
	RefreshAll()
end)

------------------------------------------------------------------------------
-- Layout.

page = pages.layout
Header(page, "Layout", "Where everything sits. Move mode, at the bottom of this window, unlocks every piece over a grid; one let go snaps to it. Outside it, hold Alt and drag any piece.")
page.y = page.y - 16
Check(page, "Player and target frames move with the action bar",
	function() return SurvivorUI_LinkFrames and SurvivorUI_LinkFrames() end,
	function()
		if SurvivorUI_SetLinkFrames and SurvivorUI_LinkFrames then
			SurvivorUI_SetLinkFrames(not SurvivorUI_LinkFrames())
		end
	end)
page.y = page.y - 10
local half = PAGE_WIDTH / 2 - 4
Button(page, "Center the action bar", half, 0, Call("SurvivorUI_CenterRow"))
Button(page, "Every piece back in place", half, half + 8, Call("SurvivorUI_ResetLayout"))
page.y = page.y - 30

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
credit:SetFont(FONT, 8, "")
credit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
credit:SetWidth(SIDEBAR - 18)
credit:SetJustifyH("LEFT")
credit:SetTextColor(0.42, 0.42, 0.47)
credit:SetText("by morderous\ngithub.com/morderous/\nsurvivor-ui\nGPL-3.0")

------------------------------------------------------------------------------

panel:SetScript("OnShow", function()
	ShowPage(current or "panels")
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
