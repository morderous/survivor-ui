-- Survivor UI: the options panel, /sui opt (or the minimap button).
--
-- Every piece and every look on or off with a click, in two columns: the
-- panels, combat, nameplates on the left; the interface's looks and the layout
-- on the right. The layout part has the configuration mode, which unlocks every
-- piece without Alt and lays a grid over the screen, a piece let go snapping to
-- it. The panels' switches act at once; most looks need a reload, and a change
-- to one lights the Reload button. Escape closes it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local COLUMN = 280              -- each column's width
local ROW = 19
local GOLD = { 1, 0.82, 0 }
local MUTED = { 0.6, 0.6, 0.65 }

local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function OnUnlessOff(key)
	return function() return DB()[key] ~= false end
end

local function OnlyIfOn(key)
	return function() return DB()[key] == true end
end

local function Call(name, argument)
	return function()
		local command = getglobal(name)
		if command then
			command(argument)
		end
	end
end

-- A look the addon gives the game's interface (SurvivorUI_Feature).
local needsReload = false

local function FeatureOn(key)
	return function() return not SurvivorUI_Feature or SurvivorUI_Feature(key) end
end

local function FeatureToggle(key)
	return function()
		if SurvivorUI_SetFeature and SurvivorUI_Feature then
			SurvivorUI_SetFeature(key, not SurvivorUI_Feature(key))
			needsReload = true
		end
	end
end

-- Survivor Plates' own two choices, through its own command.
local function PlatesOn(key, onWhen)
	return function() return SurvivorPlatesDB and (SurvivorPlatesDB[key] == true) == onWhen end
end

local function PlatesToggle(command)
	return function()
		if SlashCmdList and SlashCmdList["SURVIVORPLATES"] then
			SlashCmdList["SURVIVORPLATES"](command)
		end
	end
end

local SECTIONS = {
	{ column = 1, title = "Panels", rows = {
		{ "Run tracker", OnUnlessOff("tracker"), Call("SurvivorUI_ToggleTracker") },
		{ "Build list", OnUnlessOff("buildList"), Call("SurvivorUI_ToggleBuild") },
		{ "Damage meter (off: the game's own)", OnUnlessOff("meter"), Call("SurvivorUI_ToggleMeter") },
		{ "This Run panel", OnUnlessOff("runPanel"), Call("SurvivorUI_ToggleRun") },
		{ "Biggest Crits box", OnlyIfOn("critBox"), Call("SurvivorUI_ToggleCrits") },
		{ "Boss bars", OnUnlessOff("bossBars"), Call("SurvivorUI_BossBars") },
		{ "Elites on the boss bars", OnlyIfOn("bossBarsElites"), Call("SurvivorUI_BossBars", "elites") },
		{ "Kills and gold line", OnUnlessOff("tally"), Call("SurvivorUI_Tally") },
		{ "Loot list", OnUnlessOff("lootLog"), Call("SurvivorUI_ToggleLoot") },
	} },
	{ column = 1, title = "Combat", rows = {
		{ "Quick damage numbers", OnUnlessOff("damageText"), Call("SurvivorUI_ToggleDamage") },
		{ "Numbers beside the hero (test)", OnlyIfOn("damageSide"), Call("SurvivorUI_ToggleDamageSide") },
	} },
	{ column = 1, title = "Nameplates", plates = true, rows = {
		{ "Plates on every enemy", PlatesOn("important", false), PlatesToggle("all") },
		{ "Names on every plate", PlatesOn("names", true), PlatesToggle("names") },
	} },
	{ column = 2, title = "Interface", rows = {
		{ "White outline under the mouse", OnUnlessOff("hover"), Call("SurvivorUI_ToggleHover") },
		{ "Cooldown numbers on the buttons", FeatureOn("cooldownNumbers"), FeatureToggle("cooldownNumbers") },
		{ "Hide key labels on the buttons", FeatureOn("hideKeys"), FeatureToggle("hideKeys") },
		{ "Ability tooltip, laid out again", FeatureOn("abilityTooltip"), FeatureToggle("abilityTooltip") },
		{ "Character pane", FeatureOn("characterPane"), FeatureToggle("characterPane") },
		{ "Square minimap", FeatureOn("minimap"), FeatureToggle("minimap") },
		-- At once, no reload: the pins look at it every update.
		{ "Caches and lairs on the minimap", FeatureOn("mapPins"), function()
			SurvivorUI_SetFeature("mapPins", not SurvivorUI_Feature("mapPins"))
		end },
		{ "Flat chat", FeatureOn("chat"), FeatureToggle("chat") },
		{ "Flat tooltips", FeatureOn("tooltip"), FeatureToggle("tooltip") },
		{ "One font everywhere", FeatureOn("fonts"), FeatureToggle("fonts") },
		{ "Menu buttons in the corner, on hover", FeatureOn("microMenu"), FeatureToggle("microMenu") },
	} },
}

------------------------------------------------------------------------------
-- The panel.

local panel = CreateFrame("Frame", "SurvivorUIOptions", UIParent)
panel:SetWidth(COLUMN * 2 + 12)
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
panel:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
panel:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
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

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	return text
end

local title = Text(panel, 13, GOLD)
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
title:SetText("Survivor UI")

local version = Text(panel, 9, MUTED)
version:SetPoint("LEFT", title, "RIGHT", 8, -1)
if GetAddOnMetadata then
	version:SetText("v"..(GetAddOnMetadata("SurvivorUI", "Version") or ""))
end

local close = CreateFrame("Button", nil, panel)
close:SetWidth(18)
close:SetHeight(18)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
close.text = Text(close, 12, MUTED)
close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
close.text:SetText("x")
close:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
close:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
close:SetScript("OnClick", function() panel:Hide() end)

-- Where the next row goes: the column's left edge, and its own y.
local colX = 12
local columnY = { -34, -34 }
local y = -34

local function UseColumn(column)
	colX = column == 1 and 12 or 12 + COLUMN
	y = columnY[column]
end

local function EndColumn(column)
	columnY[column] = y
end

local function Header(text)
	local header = Text(panel, 10, GOLD)
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, y)
	header:SetText(text)
	local rule = panel:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(FLAT)
	rule:SetVertexColor(1, 0.82, 0, 0.25)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, y - 14)
	rule:SetPoint("TOPRIGHT", panel, "TOPLEFT", colX + COLUMN - 16, y - 14)
	y = y - 20
end

local checks = {}
local reloadButton              -- set below, lit when a look waits for a reload

local function RefreshAll()
	for index = 1, table.getn(checks) do
		checks[index]:Refresh()
	end
	if reloadButton then
		reloadButton:Refresh()
	end
end

-- A check: a flat square, gold when on, and its label.
local function Check(label, isOn, toggle)
	local check = CreateFrame("Button", nil, panel)
	check:SetWidth(COLUMN - 16)
	check:SetHeight(ROW)
	check:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, y)

	check.box = check:CreateTexture(nil, "ARTWORK")
	check.box:SetTexture(FLAT)
	check.box:SetWidth(11)
	check.box:SetHeight(11)
	check.box:SetPoint("LEFT", check, "LEFT", 2, 0)

	check.edge = check:CreateTexture(nil, "BORDER")
	check.edge:SetTexture(FLAT)
	check.edge:SetVertexColor(0.35, 0.35, 0.4, 1)
	check.edge:SetPoint("TOPLEFT", check.box, "TOPLEFT", -1, 1)
	check.edge:SetPoint("BOTTOMRIGHT", check.box, "BOTTOMRIGHT", 1, -1)

	check.label = Text(check, 10, { 0.9, 0.9, 0.9 })
	check.label:SetPoint("LEFT", check.box, "RIGHT", 8, 0)
	check.label:SetText(label)

	check.isOn = isOn
	check:SetScript("OnClick", function()
		toggle()
		RefreshAll()
	end)
	check:SetScript("OnEnter", function() this.label:SetTextColor(1, 1, 1) end)
	check:SetScript("OnLeave", function() this:Refresh() end)
	function check:Refresh()
		if self.isOn() then
			self.box:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
			self.label:SetTextColor(0.92, 0.92, 0.92)
		else
			self.box:SetVertexColor(0.12, 0.12, 0.15, 1)
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end

	table.insert(checks, check)
	y = y - ROW
	return check
end

local function FlatButton(text, width, x, onClick)
	local button = CreateFrame("Button", nil, panel)
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", colX + x, y)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(0.16, 0.14, 0.08, 1)
	button:SetBackdropBorderColor(0.45, 0.38, 0.12, 1)
	button.text = Text(button, 10, GOLD)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	button:SetScript("OnLeave", function() this.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
	button:SetScript("OnClick", onClick)
	return button
end

for _, section in pairs(SECTIONS) do
	-- Survivor Plates is a separate addon: its section only when it is there.
	if not section.plates or (SlashCmdList and SlashCmdList["SURVIVORPLATES"]) then
		UseColumn(section.column)
		Header(section.title)
		for _, row in pairs(section.rows) do
			Check(row[1], row[2], row[3])
		end
		y = y - 6
		EndColumn(section.column)
	end
end

------------------------------------------------------------------------------
-- Layout, under the interface's looks: configuration mode, the panels' size,
-- the reload, back to the first places.

UseColumn(2)
Header("Layout")
local INNER = COLUMN - 16

Check("Unit frames move with the action bar", function() return SurvivorUI_LinkFrames and SurvivorUI_LinkFrames() end, function()
	if SurvivorUI_SetLinkFrames and SurvivorUI_LinkFrames then
		SurvivorUI_SetLinkFrames(not SurvivorUI_LinkFrames())
	end
end)
y = y - 4

local editButton
editButton = FlatButton("Move mode (grid)", INNER, 0, function()
	local on = not (SurvivorUI_EditMode and SurvivorUI_EditMode())
	if SurvivorUI_SetEditMode then
		SurvivorUI_SetEditMode(on)
	end
	editButton:Refresh()
end)
function editButton:Refresh()
	local on = SurvivorUI_EditMode and SurvivorUI_EditMode()
	self.text:SetText(on and "Done moving" or "Move mode (grid)")
	if on then
		self:SetBackdropColor(0.35, 0.28, 0.05, 1)
	else
		self:SetBackdropColor(0.16, 0.14, 0.08, 1)
	end
end
y = y - 26

local hint = Text(panel, 9, MUTED)
hint:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, y)
hint:SetWidth(INNER)
hint:SetJustifyH("LEFT")
hint:SetText("Drag any outlined piece: it snaps to the grid. Outside this mode, hold Alt to move.")
y = y - 26

local scaleLabel = Text(panel, 10, { 0.9, 0.9, 0.9 })
scaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", colX + 2, y - 5)

local function ShowScale()
	scaleLabel:SetText(string.format("Panel size  %.2f", DB().panelScale or 1))
end

local function StepScale(step)
	local value = math.floor(((DB().panelScale or 1) + step) * 100 + 0.5) / 100
	if SurvivorUI_SetScale then
		SurvivorUI_SetScale(value)
	end
	ShowScale()
end

FlatButton("-", 26, INNER - 58, function() StepScale(-0.05) end)
FlatButton("+", 26, INNER - 28, function() StepScale(0.05) end)
y = y - 28

FlatButton("Reset layout", INNER / 2 - 3, 0, function()
	if SurvivorUI_ResetLayout then
		SurvivorUI_ResetLayout()
	end
end)
FlatButton("Center action bar", INNER / 2 - 3, INNER / 2 + 3, function()
	if SurvivorUI_CenterRow then
		SurvivorUI_CenterRow()
	end
end)
y = y - 28

reloadButton = FlatButton("Reload to apply", INNER, 0, function() ReloadUI() end)
function reloadButton:Refresh()
	if needsReload then
		self.text:SetText("Reload to apply the changes")
		self:SetBackdropColor(0.45, 0.15, 0.10, 1)
	else
		self.text:SetText("Reload interface")
		self:SetBackdropColor(0.16, 0.14, 0.08, 1)
	end
end
y = y - 30
EndColumn(2)

-- Under the columns, who made it and where it lives.
panel:SetHeight(-math.min(columnY[1], columnY[2]) + 6 + 16)
local credit = panel:CreateFontString(nil, "OVERLAY")
credit:SetFont(FONT, 9, "")
credit:SetPoint("BOTTOM", panel, "BOTTOM", 0, 7)
credit:SetTextColor(0.5, 0.5, 0.55)
local version = GetAddOnMetadata and GetAddOnMetadata("SurvivorUI", "Version")
credit:SetText("Survivor UI"..(version and " v"..version or "").." by morderous  ·  github.com/morderous/survivor-ui  ·  GPL-3.0")

panel:SetScript("OnShow", function()
	RefreshAll()
	editButton:Refresh()
	ShowScale()
end)
-- Closing the panel ends configuration mode.
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

-- Open, with configuration mode on and the grid laid out (the minimap button).
function SurvivorUI_OpenOptionsMoving()
	panel:Show()
	if SurvivorUI_SetEditMode then
		SurvivorUI_SetEditMode(true)
	end
	editButton:Refresh()
end
