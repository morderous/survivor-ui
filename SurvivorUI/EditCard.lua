-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a piece's card, in move mode.
--
-- A click on a piece in move mode (the S button by the minimap, or /sui opt,
-- Move mode) opens its card beside it: its name, < and > for the next piece;
-- its place, from the screen's middle, to type or to nudge by one; centered
-- across or up and down at a click; its own size; shown or hidden (the pieces
-- that can be put away); its font and the font's size; back to its first
-- place; undo; done. The arrow keys move it by one (Shift by ten), Ctrl+Z
-- undoes, Escape closes the card.
--
-- The fonts are the game's own (Friz Quadrata, Arial Narrow, Morpheus, and
-- Skurri where the client has it) and five free ones that come with the addon.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 236
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }   -- the addon's own color, the class's
local TEXT = { 0.9, 0.9, 0.92 }
local MUTED = { 0.6, 0.6, 0.65 }
local UNDO_MAX = 40

-- What each piece is besides its place, by its name: its size (Mover.lua's
-- parts), its saved places (to forget on a reset), and the switch that puts it
-- away, for those that have one.
local PIECES = {
	["Action bar"] = { part = "bar", places = { "rowX", "rowY" } },
	["Player frame"] = { part = "frames", places = { "playerLeft", "playerTop" } },
	["Target frame"] = { part = "frames", places = { "targetLeft", "targetTop" } },
	["Buffs"] = { part = "buffs", places = { "buffsLeft", "buffsBottom" } },
	["Chat"] = { places = { "chatLeft", "chatBottom" }, gameFont = true },
	["Minimap"] = { part = "minimap", places = { "mapRight", "mapTop" }, gameFont = true },
	["Tooltip"] = { places = { "tipRight", "tipBottom" }, gameFont = true },
	["Stats"] = { part = "stats", places = { "statsLeft", "statsTop" }, key = "statsPanel", offUnlessOn = true, toggle = "SurvivorUI_ToggleStatsPanel" },
	["Character pane"] = { part = "character", places = { "characterLeft", "characterTop" }, noFont = true },
	["Run tracker"] = { part = "tracker", places = { "trackerRight", "trackerTop" }, key = "tracker", toggle = "SurvivorUI_ToggleTracker" },
	["Build list"] = { part = "build", places = { "buildLeft", "buildTop" }, key = "buildList", toggle = "SurvivorUI_ToggleBuild" },
	["Damage meter"] = { part = "meter", places = { "meterRight", "meterBottom" }, key = "meter", toggle = "SurvivorUI_ToggleMeter" },
	["Boss bars"] = { part = "bosses", places = { "bossLeft", "bossTop" }, key = "bossBars", toggle = "SurvivorUI_BossBars" },
	["Loot list"] = { part = "loot", places = { "lootLeft", "lootTop" }, key = "lootLog", toggle = "SurvivorUI_ToggleLoot" },
	["This Run"] = { part = "run", places = { "runLeft", "runTop", "runBottom" }, key = "runPanel", toggle = "SurvivorUI_ToggleRun" },
	["Biggest Crits"] = { part = "crits", places = { "critsLeft", "critsTop", "critsBottom" }, key = "critBox", offUnlessOn = true, toggle = "SurvivorUI_ToggleCrits" },
	["Kills and gold line"] = { part = "tally", places = { "tallyLeft", "tallyX", "tallyTop" }, key = "tally", toggle = "SurvivorUI_Tally" },
	["Guardians"] = { part = "guardians", places = { "guardiansLeft", "guardiansTop" }, key = "guardians", toggle = "SurvivorUI_ToggleGuardians" },
	["New best crit"] = { places = { "recordLeft", "recordTop" }, key = "ctRecord", toggle = "SurvivorUI_ToggleRecord", noFont = true },
	["Damage numbers"] = { places = { "dealtLeft", "dealtTop" }, noFont = true },
	["Crit numbers"] = { places = { "critLeft", "critTop" }, noFont = true },
	["Damage taken"] = { places = { "takenLeft", "takenTop" }, key = "ctTaken", toggle = "SurvivorUI_ToggleTakenNumbers", noFont = true },
	["Healing"] = { places = { "healLeft", "healTop" }, key = "ctHeals", toggle = "SurvivorUI_ToggleHealNumbers", noFont = true },
	["Minimap button"] = { places = { "mapButtonX", "mapButtonY" }, noFont = true },
	["XP bar"] = { places = { "xpBarX", "xpBarTop" }, key = "xpBar", offUnlessOn = true, toggle = "SurvivorUI_ToggleXpBar" },
	["Level Up!"] = { part = "levelup", places = { "levelUpX", "levelUpTop" }, key = "levelUp", offUnlessOn = true, toggle = "SurvivorUI_ToggleLevelUp" },
	["Class gems"] = { places = { "shardsX", "shardsTop" }, noFont = true },
}

local selected          -- the handle (Mover.lua) whose card is open
local undo = {}         -- { handle, x, y } before each change, the last on top

------------------------------------------------------------------------------
-- Fonts.

local GAME_FONTS = {
	{ name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Skurri", path = "Fonts\\skurri.ttf" },
}

-- The free faces that come with the addon, in its Fonts folder, under the SIL
-- Open Font License (each one's license beside it). None writes Chinese,
-- Korean or Japanese; Exo and Cinzel Decorative write no Cyrillic (Russian,
-- Ukrainian), Russo One no Romanian ț: each is offered only where it can
-- write the game's language.
local OWN_FONTS = "Interface\\AddOns\\SurvivorUI\\Fonts\\"
local CYRILLIC = { ru = true, uk = true }
local ADDON_FONTS = {
	{ name = "Fira Sans", path = OWN_FONTS.."FiraSans-Medium.ttf" },
	{ name = "Noto Sans", path = OWN_FONTS.."NotoSans-Medium.ttf" },
	{ name = "Exo", path = OWN_FONTS.."Exo-SemiBold.ttf", cannot = CYRILLIC },
	{ name = "Russo One", path = OWN_FONTS.."RussoOne-Regular.ttf", cannot = { ro = true } },
	{ name = "Cinzel Decorative", path = OWN_FONTS.."CinzelDecorative-Bold.ttf", cannot = CYRILLIC },
}
local NO_FREE_FONT = { zh = true, ko = true, ja = true }

local function Writes(face)
	local language = SurvivorUI_Language and SurvivorUI_Language()
	if not language then
		return true
	end
	if NO_FREE_FONT[language] then
		return false
	end
	return not (face.cannot and face.cannot[language])
end

-- A face by its file: the addon's as Writes says, the game's always.
local function WritesPath(path)
	for _, face in pairs(ADDON_FONTS) do
		if string.lower(face.path) == string.lower(path) then
			return Writes(face)
		end
	end
	return true
end

-- Whether a face loads: set on a probe, it holds only when the file is there.
local probe = UIParent:CreateFontString(nil, "OVERLAY")
local loads = {}
local function Loads(path)
	if loads[path] == nil then
		probe:SetFont("Fonts\\FRIZQT__.TTF", 12)
		probe:SetFont(path, 12)
		local got = probe:GetFont()
		loads[path] = got ~= nil and string.lower(got) == string.lower(path)
	end
	return loads[path]
end

-- Every face to pick from. First the one a piece wears unless told (the
-- global font), or, for the global font itself (forGlobal), the face the addon
-- found as it loaded; then the game's; then the addon's that can write the
-- game's language.
function SurvivorUI_FontList(forGlobal)
	local default = string.lower(SurvivorUI_DefaultFont and SurvivorUI_DefaultFont() or SurvivorUI_DEFAULT_FONT or "")
	local first = { name = "The global font", path = nil }
	if forGlobal then
		first = { name = "Default: "..(SurvivorUI_DefaultFontName and SurvivorUI_DefaultFontName() or "Friz Quadrata"), path = nil }
	end
	local list = { first }
	for _, face in pairs(GAME_FONTS) do
		if Loads(face.path) and not (forGlobal and string.lower(face.path) == default) then
			table.insert(list, face)
		end
	end
	for _, face in pairs(ADDON_FONTS) do
		if Writes(face) and Loads(face.path) and not (forGlobal and string.lower(face.path) == default) then
			table.insert(list, face)
		end
	end
	return list
end

-- The pieces' fonts, { path, step } by name in SurvivorUIDB.pieceFonts; a
-- piece renamed (v3.0.5) keeps the font chosen under its old name.
local RENAMED = { ["Build"] = "Build list", ["Loot"] = "Loot list", ["Kills & gold"] = "Kills and gold line" }

local function PieceFonts()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.pieceFonts = SurvivorUIDB.pieceFonts or {}
	local fonts = SurvivorUIDB.pieceFonts
	for old, new in pairs(RENAMED) do
		if fonts[old] then
			fonts[new] = fonts[new] or fonts[old]
			fonts[old] = nil
		end
	end
	return fonts
end

-- A piece's font; one that cannot write the game's language is left aside.
local function PieceFont(name)
	local chosen = PieceFonts()[name]
	if chosen and chosen.path and not WritesPath(chosen.path) then
		return nil
	end
	return chosen
end

-- Every font string in a piece takes its face and its size step. Its own size
-- is kept the first time it is seen, and again whenever its file sets one of
-- its own, so the step never piles up.
local function Dress(region, face, step)
	local path, size, flags = region:GetFont()
	if not size then
		return
	end
	if region.suiSize ~= size or region.suiPath ~= path then
		region.suiBase = size
	end
	local want = math.max(6, (region.suiBase or size) + step)
	local wanted = face or SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
	if wanted ~= path or want ~= size then
		region:SetFont(wanted, want, flags)
	end
	region.suiPath, region.suiSize = region:GetFont()
	region.suiSize = want
end

local function Walk(frame, face, step)
	local regions = { frame:GetRegions() }
	for index = 1, table.getn(regions) do
		local region = regions[index]
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			Dress(region, face, step)
		end
	end
	local children = { frame:GetChildren() }
	for index = 1, table.getn(children) do
		Walk(children[index], face, step)
	end
end

local function ApplyFont(handle)
	local piece = PIECES[handle.name]
	local chosen = PieceFont(handle.name)
	if not (handle.mover and piece and not piece.gameFont and not piece.noFont) then
		return
	end
	if chosen or handle.fontWorn then
		Walk(handle.mover, chosen and chosen.path, chosen and chosen.step or 0)
		handle.fontWorn = chosen and true or nil
	end
end

-- The windows with no card, by their frames' names: the name their text size
-- goes by (the options' Run History and Jewelry tabs).
local FONT_WINDOWS = {
	{ "SurvivorUILastRuns", "Run History" }, { "SurvivorUICareer", "Run History" },
	{ "SurvivorUIJewelryPanel", "Jewelry" },
}

-- A window's text at its step (only while it is seen; worn, put back at 0).
local function WearWindows(name, always)
	for _, each in pairs(FONT_WINDOWS) do
		local frame = getglobal(each[1])
		if frame and (not name or name == each[2]) and (always or frame:IsVisible()) then
			local chosen = PieceFonts()[each[2]]
			if chosen or frame.suiFontWorn then
				Walk(frame, chosen and chosen.path, chosen and chosen.step or 0)
				frame.suiFontWorn = chosen and true or nil
			end
		end
	end
end

-- Pieces draw new words as they go: their fonts are put on again now and then.
local fonts = CreateFrame("Frame")
local fontWait = 0
fonts:SetScript("OnUpdate", function()
	fontWait = fontWait + arg1
	if fontWait < 1.5 then
		return
	end
	fontWait = 0
	if not (SurvivorUIDB and SurvivorUI_MoverHandles) then
		return
	end
	local set = PieceFonts()
	for _, handle in pairs(SurvivorUI_MoverHandles()) do
		if set[handle.name] then
			ApplyFont(handle)
		end
	end
	WearWindows()
end)

------------------------------------------------------------------------------
-- Places: a piece's middle from the screen's, in the screen's units.

local function Center(handle)
	local x, y = handle:GetCenter()
	if not x then
		return nil
	end
	return x - GetScreenWidth() / 2, y - GetScreenHeight() / 2
end

local function MoveBy(handle, dx, dy)
	local mover = handle.mover
	local left, top = mover and mover:GetLeft(), mover and mover:GetTop()
	if not (left and top) then
		return
	end
	local ratio = mover:GetEffectiveScale() / UIParent:GetEffectiveScale()
	mover:ClearAllPoints()
	mover:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx / ratio, top + dy / ratio)
	if handle.save then
		handle.save()
	end
end

local function MoveTo(handle, x, y)
	local cx, cy = Center(handle)
	if cx then
		MoveBy(handle, x - cx, y - cy)
	end
end

-- Before any change: where the piece was, for undo (Mover.lua calls it when a
-- drag starts).
function SurvivorUI_EditBefore(handle)
	local x, y = Center(handle)
	if not x then
		return
	end
	table.insert(undo, { handle = handle, x = x, y = y })
	while table.getn(undo) > UNDO_MAX do
		table.remove(undo, 1)
	end
end

------------------------------------------------------------------------------
-- The card.

local card = CreateFrame("Frame", "SurvivorUIEditCard", UIParent)
card:SetWidth(WIDTH)
card:SetHeight(244)
card:SetFrameStrata("FULLSCREEN_DIALOG")
card:SetFrameLevel(40)
card:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
card:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
card:SetBackdropBorderColor(ACCENT[1] * 0.6, ACCENT[2] * 0.6, ACCENT[3] * 0.6, 1)
card:EnableMouse(true)
if card.SetClampedToScreen then
	card:SetClampedToScreen(true)
end
card:Hide()

-- Texts in the addon's color, painted again when it changes.
local accentTexts = {}

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	if color == ACCENT then
		table.insert(accentTexts, text)
	end
	return text
end

-- A flat button in the addon's color.
local buttons = {}
local function Button(text, width, onClick)
	local button = CreateFrame("Button", nil, card)
	button:SetWidth(width)
	button:SetHeight(18)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button:SetBackdropColor(ACCENT[1] * 0.16, ACCENT[2] * 0.16, ACCENT[3] * 0.16, 1)
	button:SetBackdropBorderColor(ACCENT[1] * 0.55, ACCENT[2] * 0.55, ACCENT[3] * 0.55, 1)
	button.text = Text(button, 9, ACCENT)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(text)
	button:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	end)
	button:SetScript("OnLeave", function()
		this.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		this:SetBackdropBorderColor(ACCENT[1] * 0.55, ACCENT[2] * 0.55, ACCENT[3] * 0.55, 1)
	end)
	button:SetScript("OnClick", onClick)
	table.insert(buttons, button)
	return button
end

-- A box for a number: typed, then Enter.
local function NumberBox(onEnter)
	local box = CreateFrame("EditBox", nil, card)
	box:SetWidth(56)
	box:SetHeight(18)
	box:SetAutoFocus(false)
	box:SetMaxLetters(6)
	box:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	box:SetJustifyH("CENTER")
	box:SetTextColor(1, 1, 1)
	box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(0, 0, 0, 0.8)
	box:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
	box:SetScript("OnEnterPressed", function()
		local value = tonumber(this:GetText())
		this:ClearFocus()
		onEnter(value)
	end)
	box:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)
	-- While typed in, the box has the keys, not the card (backspace, Enter);
	-- kept by hand, as 1.12's boxes cannot say whether they have them.
	box:SetScript("OnEditFocusGained", function()
		this.focused = true
		card:EnableKeyboard(false)
	end)
	box:SetScript("OnEditFocusLost", function()
		this.focused = nil
		card:EnableKeyboard(true)
	end)
	-- Its number in the middle: 1.12's boxes write from the left, so the
	-- room before it is worked out from the number's width.
	box:SetScript("OnTextChanged", function()
		this.measure:SetText(this:GetText() or "")
		local inset = math.max(2, (this:GetWidth() - this.measure:GetStringWidth()) / 2)
		this:SetTextInsets(inset, 2, 0, 0)
	end)
	box.measure = card:CreateFontString(nil, "OVERLAY")
	box.measure:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	box.measure:Hide()
	return box
end

local Fill, Select

-- The title: < name >, and x to close.
local title = Text(card, 11, ACCENT)
title:SetPoint("TOP", card, "TOP", 0, -8)

local function Step(direction)
	local handles = SurvivorUI_MoverHandles and SurvivorUI_MoverHandles() or {}
	local list = {}
	for _, handle in pairs(handles) do
		if handle:IsShown() and not handle.disabled then
			table.insert(list, handle)
		end
	end
	local count = table.getn(list)
	if count == 0 then
		return
	end
	local at = 0
	for index = 1, count do
		if list[index] == selected then
			at = index
		end
	end
	at = math.mod(at - 1 + direction + count, count) + 1
	Select(list[at])
end

local prev = Button("<", 22, function() Step(-1) end)
prev:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
local after = Button(">", 22, function() Step(1) end)
after:SetPoint("TOPRIGHT", card, "TOPRIGHT", -30, -6)
local close = Button("x", 18, function() Select(nil) end)
close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -6)

-- The place: X and Y, each with - and + by one.
local function Changed(dx, dy)
	if not selected then
		return
	end
	SurvivorUI_EditBefore(selected)
	MoveBy(selected, dx, dy)
	Fill()
end

local placeLabel = Text(card, 9, MUTED)
placeLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -34)
placeLabel:SetText("Place, from the screen's middle")

local rows = {}
for index, axis in pairs({ "X", "Y" }) do
	local top = -50 - (index - 1) * 22
	local label = Text(card, 10, TEXT)
	label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, top - 3)
	label:SetText(axis)
	local isX = axis == "X"
	local minus = Button("-", 20, function()
		local step = IsShiftKeyDown() and 10 or 1
		if isX then Changed(-step, 0) else Changed(0, -step) end
	end)
	minus:SetPoint("TOPLEFT", card, "TOPLEFT", 28, top)
	local box = NumberBox(function(value)
		if not (selected and value) then
			Fill()
			return
		end
		local x, y = Center(selected)
		SurvivorUI_EditBefore(selected)
		if isX then MoveTo(selected, value, y) else MoveTo(selected, x, value) end
		Fill()
	end)
	box:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local plus = Button("+", 20, function()
		local step = IsShiftKeyDown() and 10 or 1
		if isX then Changed(step, 0) else Changed(0, step) end
	end)
	plus:SetPoint("LEFT", box, "RIGHT", 4, 0)
	local middle = Button(isX and "Center across" or "Center up/down", 88, function()
		if not selected then
			return
		end
		local x, y = Center(selected)
		SurvivorUI_EditBefore(selected)
		if isX then MoveTo(selected, 0, y) else MoveTo(selected, x, 0) end
		Fill()
	end)
	middle:SetPoint("LEFT", plus, "RIGHT", 6, 0)
	rows[axis] = box
end

-- The size: the piece's own, on top of the whole interface's.
local sizeLabel = Text(card, 10, TEXT)
sizeLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -103)
sizeLabel:SetText("Size")
local sizeValue = Text(card, 10, ACCENT)
sizeValue:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -103)

local slider = CreateFrame("Slider", nil, card)
slider:SetOrientation("HORIZONTAL")
slider:SetWidth(WIDTH - 110)
slider:SetHeight(14)
slider:SetPoint("TOPLEFT", card, "TOPLEFT", 50, -102)
slider:SetMinMaxValues(0.5, 2)
slider:SetValueStep(0.05)
slider:EnableMouseWheel(true)
local track = slider:CreateTexture(nil, "BACKGROUND")
track:SetTexture(FLAT)
track:SetVertexColor(0.14, 0.14, 0.18, 1)
track:SetHeight(4)
track:SetPoint("LEFT", slider, "LEFT", 0, 0)
track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
local filled = slider:CreateTexture(nil, "BORDER")
filled:SetTexture(FLAT)
filled:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
filled:SetHeight(4)
filled:SetPoint("LEFT", slider, "LEFT", 0, 0)
local thumb = slider:CreateTexture(nil, "OVERLAY")
thumb:SetTexture(FLAT)
thumb:SetVertexColor(1, 1, 1, 1)
thumb:SetWidth(8)
thumb:SetHeight(14)
slider:SetThumbTexture(thumb)
slider:SetScript("OnValueChanged", function()
	local piece = selected and PIECES[selected.name]
	local share = (this:GetValue() - 0.5) / 1.5
	filled:SetWidth(math.max(1, (this:GetWidth() - 8) * share + 4))
	sizeValue:SetText(string.format("%d%%", this:GetValue() * 100 + 0.5))
	if this.quiet or not (piece and piece.part and SurvivorUI_SetPartScale) then
		return
	end
	SurvivorUI_SetPartScale(piece.part, this:GetValue())
end)
slider:SetScript("OnMouseWheel", function()
	this:SetValue(this:GetValue() + arg1 * 0.05)
end)
local noSize = Text(card, 9, MUTED)
noSize:SetPoint("TOPLEFT", card, "TOPLEFT", 50, -104)
noSize:SetText("with the whole interface")

-- The font: a dropdown of the faces, each written in itself; its size a step
-- at a time, on the row under it.
local fontLabel = Text(card, 10, TEXT)
fontLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -127)
fontLabel:SetText("Font")
local stepLabel = Text(card, 10, TEXT)
stepLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -151)
stepLabel:SetText("Text size")
local stepText = Text(card, 10, ACCENT)
stepText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -36, -151)
stepText:SetWidth(30)
stepText:SetJustifyH("CENTER")

local function SetPieceFont(face, step)
	if not selected then
		return
	end
	local set = PieceFonts()
	if not face and (step or 0) == 0 then
		set[selected.name] = nil
	else
		set[selected.name] = { path = face, step = step or 0 }
	end
	ApplyFont(selected)
	Fill()
end

local menu = CreateFrame("Frame", nil, card)
menu:SetFrameLevel(card:GetFrameLevel() + 10)
menu:SetWidth(WIDTH - 62)
menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
menu:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
menu:SetBackdropBorderColor(ACCENT[1] * 0.6, ACCENT[2] * 0.6, ACCENT[3] * 0.6, 1)
menu:Hide()
menu.items = {}

local picker = Button("", WIDTH - 62, function()
	if menu:IsShown() then
		menu:Hide()
		return
	end
	local list = SurvivorUI_FontList()
	local chosen = selected and PieceFont(selected.name)
	for index = 1, table.getn(list) do
		local face = list[index]
		local item = menu.items[index]
		if not item then
			item = CreateFrame("Button", nil, menu)
			item:SetWidth(WIDTH - 66)
			item:SetHeight(18)
			item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (index - 1) * 18)
			item.wash = item:CreateTexture(nil, "BACKGROUND")
			item.wash:SetTexture(FLAT)
			item.wash:SetAllPoints(item)
			item.wash:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0)
			item.text = item:CreateFontString(nil, "OVERLAY")
			item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
			item:SetScript("OnEnter", function() this.wash:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.18) end)
			item:SetScript("OnLeave", function() this.wash:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], this.on and 0.12 or 0) end)
			item:SetScript("OnClick", function()
				local now = selected and PieceFont(selected.name)
				SetPieceFont(this.path, now and now.step or 0)
				menu:Hide()
			end)
			menu.items[index] = item
		end
		item.path = face.path
		-- Each face written in itself; the one chosen lit, in the addon's color.
		item.text:SetFont(face.path or SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
		item.text:SetText(face.name)
		local on = (chosen and chosen.path or nil) == face.path
		item.on = on
		item.text:SetTextColor(on and ACCENT[1] or 1, on and ACCENT[2] or 1, on and ACCENT[3] or 1)
		item.wash:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], on and 0.12 or 0)
		item:Show()
	end
	for index = table.getn(list) + 1, table.getn(menu.items) do
		menu.items[index]:Hide()
	end
	menu:SetHeight(table.getn(list) * 18 + 4)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -2)
	menu:Show()
end)
picker:SetPoint("TOPLEFT", card, "TOPLEFT", 50, -124)
picker.text:ClearAllPoints()
picker.text:SetPoint("LEFT", picker, "LEFT", 8, 0)
picker.arrow = Text(picker, 9, ACCENT)
picker.arrow:SetPoint("RIGHT", picker, "RIGHT", -6, 0)
picker.arrow:SetText("v")

local stepDown = Button("-", 18, function()
	local chosen = selected and PieceFont(selected.name)
	if selected then SetPieceFont(chosen and chosen.path, math.max(-4, (chosen and chosen.step or 0) - 1)) end
end)
stepDown:SetPoint("TOPRIGHT", card, "TOPRIGHT", -70, -148)
local stepUp = Button("+", 18, function()
	local chosen = selected and PieceFont(selected.name)
	if selected then SetPieceFont(chosen and chosen.path, math.min(8, (chosen and chosen.step or 0) + 1)) end
end)
stepUp:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -148)
local gameFont = Text(card, 9, MUTED)
gameFont:SetPoint("TOPLEFT", card, "TOPLEFT", 50, -128)
gameFont:SetText("Default")

-- Shown or hidden, for the pieces that can be put away.
local function Shown(piece)
	local db = SurvivorUIDB or {}
	if piece.offUnlessOn then
		return db[piece.key] == true
	end
	return db[piece.key] ~= false
end

local visible = Button("Shown", WIDTH - 24, function()
	local piece = selected and PIECES[selected.name]
	local toggle = piece and piece.toggle and getglobal(piece.toggle)
	if toggle then
		toggle()
		Fill()
	end
end)
visible:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -174)

-- Back to its first place, and undo.
local reset = Button("Reset (Default)", 88, function()
	if not (selected and selected.default) then
		return
	end
	SurvivorUI_EditBefore(selected)
	local piece = PIECES[selected.name]
	SurvivorUIDB = SurvivorUIDB or {}
	for _, key in pairs(piece and piece.places or {}) do
		SurvivorUIDB[key] = nil
	end
	selected.default()
	Fill()
end)
reset:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -198)

local function Undo()
	local last = table.remove(undo)
	if not last then
		return
	end
	MoveTo(last.handle, last.x, last.y)
	Select(last.handle)
end
local undoButton = Button("Undo", 56, Undo)
undoButton:SetPoint("TOPLEFT", reset, "TOPRIGHT", 6, 0)
local done = Button("Done", 56, function() Select(nil) end)
done:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -198)

local hint = Text(card, 8, MUTED)
hint:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
hint:SetWidth(WIDTH - 16)
hint:SetText("Arrows move 1, Shift 10  ·  Ctrl+Z undoes  ·  Esc closes")

------------------------------------------------------------------------------
-- Filling and placing the card.

function Fill()
	if not selected then
		return
	end
	local piece = PIECES[selected.name] or {}
	title:SetText(selected.name or "?")
	local x, y = Center(selected)
	if not rows.X.focused then
		rows.X:SetText(x and tostring(math.floor(x + 0.5)) or "")
	end
	if not rows.Y.focused then
		rows.Y:SetText(y and tostring(math.floor(y + 0.5)) or "")
	end
	if piece.part and SurvivorUI_GetScale then
		slider.quiet = true
		slider:SetValue(SurvivorUI_GetScale(piece.part))
		slider.quiet = nil
		slider:Show()
		sizeValue:Show()
		noSize:Hide()
	else
		slider:Hide()
		sizeValue:Hide()
		noSize:Show()
	end
	local chosen = PieceFont(selected.name)
	local fontRow = { picker, stepDown, stepUp }
	if piece.gameFont or piece.noFont then
		gameFont:SetText(piece.noFont and "set in Combat text" or "Default")
		for _, button in pairs(fontRow) do
			button:Hide()
		end
		menu:Hide()
		stepText:Hide()
		stepLabel:Hide()
		gameFont:Show()
	else
		for _, button in pairs(fontRow) do
			button:Show()
		end
		gameFont:Hide()
		stepLabel:Show()
		local name = "The global font"
		for _, face in pairs(SurvivorUI_FontList()) do
			if chosen and face.path == chosen.path then
				name = face.name
			end
		end
		picker.text:SetText(name)
		local step = chosen and chosen.step or 0
		stepText:SetText(step > 0 and ("+"..step) or tostring(step))
		stepText:Show()
	end
	if piece.toggle then
		visible.text:SetText(Shown(piece) and "Shown  -  click to hide" or "Hidden  -  click to show")
		visible:Enable()
	else
		visible.text:SetText("Always shown")
		visible:Disable()
	end
	undoButton.text:SetText(table.getn(undo) > 0 and ("Undo ("..table.getn(undo)..")") or "Undo")
end

-- Beside the piece: right of it where there is room, else left of it.
local function Place()
	card:ClearAllPoints()
	local right = selected:GetRight()
	if right and right + WIDTH + 12 < GetScreenWidth() then
		card:SetPoint("TOPLEFT", selected, "TOPRIGHT", 10, 0)
	else
		card:SetPoint("TOPRIGHT", selected, "TOPLEFT", -10, 0)
	end
end

-- The handle picked shows white; the others go back to the addon's color.
local function Mark(handle, on)
	if not (handle and handle.marks) then
		return
	end
	for _, mark in pairs(handle.marks) do
		if on then
			mark:SetVertexColor(1, 1, 1, 1)
		else
			mark:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.95)
		end
	end
	if handle.fill then
		handle.fill:SetVertexColor(on and 1 or ACCENT[1], on and 1 or ACCENT[2], on and 1 or ACCENT[3], on and 0.14 or 0.08)
	end
end

function Select(handle)
	menu:Hide()
	Mark(selected, false)
	selected = handle
	if not handle then
		card:Hide()
		return
	end
	Mark(handle, true)
	Place()
	Fill()
	card:Show()
end
SurvivorUI_EditSelect = Select

-- A piece back in its first place by its name (the options' Back to its
-- place), as its card's Reset does.
function SurvivorUI_ResetPiece(name)
	for _, handle in pairs(SurvivorUI_MoverHandles and SurvivorUI_MoverHandles() or {}) do
		if handle.name == name and handle.default then
			SurvivorUI_EditBefore(handle)
			local piece = PIECES[name]
			SurvivorUIDB = SurvivorUIDB or {}
			for _, key in pairs(piece and piece.places or {}) do
				SurvivorUIDB[key] = nil
			end
			handle.default()
			if selected == handle then
				Fill()
			end
			return
		end
	end
end

-- The keys while the card is open: arrows move, Ctrl+Z undoes, Escape closes.
card:EnableKeyboard(true)
card:SetScript("OnKeyDown", function()
	local key = arg1
	local step = IsShiftKeyDown() and 10 or 1
	if key == "LEFT" then
		Changed(-step, 0)
	elseif key == "RIGHT" then
		Changed(step, 0)
	elseif key == "UP" then
		Changed(0, step)
	elseif key == "DOWN" then
		Changed(0, -step)
	elseif key == "Z" and IsControlKeyDown() then
		Undo()
	elseif key == "ESCAPE" and menu:IsShown() then
		menu:Hide()
	elseif key == "ESCAPE" then
		Select(nil)
	end
end)

-- The numbers follow a piece dragged while its card is open.
local wait = 0
card:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.2 then
		return
	end
	wait = 0
	if selected then
		Fill()
	end
end)

-- Every font back to default (the options, Global): the global font the
-- game's again, and every piece back to it, at its own size. A piece that
-- wore a font of its own takes the global one again at once.
function SurvivorUI_ResetFonts()
	if SurvivorUI_SetGlobalFont then
		SurvivorUI_SetGlobalFont(nil)
	end
	if not (SurvivorUIDB and SurvivorUIDB.pieceFonts and SurvivorUI_MoverHandles) then
		if selected then
			Fill()
		end
		return
	end
	local handles = SurvivorUI_MoverHandles()
	for _, handle in pairs(handles) do
		if SurvivorUIDB.pieceFonts[handle.name] then
			handle.fontWorn = true
		end
	end
	SurvivorUIDB.pieceFonts = nil
	for _, handle in pairs(handles) do
		ApplyFont(handle)
	end
	WearWindows(nil, true)
	if selected then
		Fill()
	end
end

-- The options' Text size, in each tab: the card's step (A- and A+, -4 to +8)
-- by the piece's name, its face kept; for the windows with no card, theirs.
function SurvivorUI_PieceHasFont(name)
	local piece = PIECES[name]
	if piece then
		return not piece.gameFont and not piece.noFont
	end
	for _, each in pairs(FONT_WINDOWS) do
		if each[2] == name then
			return true
		end
	end
	return false
end

function SurvivorUI_PieceTextStep(name)
	local chosen = PieceFonts()[name]
	return chosen and chosen.step or 0
end

function SurvivorUI_SetPieceTextStep(name, step)
	local set = PieceFonts()
	local face = set[name] and set[name].path
	step = math.max(-4, math.min(8, math.floor((tonumber(step) or 0) + 0.5)))
	if not face and step == 0 then
		set[name] = nil
	else
		set[name] = { path = face, step = step }
	end
	for _, handle in pairs(SurvivorUI_MoverHandles and SurvivorUI_MoverHandles() or {}) do
		if handle.name == name then
			ApplyFont(handle)
		end
	end
	WearWindows(name, true)
	if selected and selected.name == name then
		Fill()
	end
end

-- A new class color: what took it once, as it was made, takes it again.
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function()
		card:SetBackdropBorderColor(ACCENT[1] * 0.6, ACCENT[2] * 0.6, ACCENT[3] * 0.6, 1)
		menu:SetBackdropBorderColor(ACCENT[1] * 0.6, ACCENT[2] * 0.6, ACCENT[3] * 0.6, 1)
		filled:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
		for _, button in pairs(buttons) do
			button:SetBackdropColor(ACCENT[1] * 0.16, ACCENT[2] * 0.16, ACCENT[3] * 0.16, 1)
			button:SetBackdropBorderColor(ACCENT[1] * 0.55, ACCENT[2] * 0.55, ACCENT[3] * 0.55, 1)
		end
		for _, text in pairs(accentTexts) do
			text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		end
	end)
end
