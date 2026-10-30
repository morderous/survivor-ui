-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: Change UI, the box that picks this addon or SurvivorUI Classic.
-- The two change the same frames, so only one of them runs.
--
-- In the middle of the screen, the screen shaded behind it, a card for each,
-- the one running marked: a click picks. This one closes the box; the other
-- is kept in SurvivorUI Classic's settings, this addon stands aside at its next
-- start (SurvivorUI.lua) and the box asks for the game to be closed and opened
-- again: the game loads its addons only at its start, and ReloadUI does nothing
-- in a run. With the launcher open (its mark, a SurvivorUILauncher addon that
-- is only a .toc) that is Restart game: the moment is kept in SurvivorUI
-- Classic's settings (restartAt) and the launcher, seeing the game close, opens
-- it again. Off in the game's list, SurvivorUI Classic cannot be picked: an
-- addon can only turn it on for the hero played, and each hero would have its
-- own list, so the box says where to turn it on.
--
-- Opened by the button at the options' sidebar foot (SurvivorUI_ChangeUI). It
-- also takes the place of SurvivorUI Classic's own panel while this addon is
-- the one running: that addon's first question, with both on, and its /suic.
-- Built the first time it is wanted, once every file is loaded (it wears
-- SurvivorUI_GoldButton, RunHistory.lua's).

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local WIDTH = 470
local PAD = 16
local GAP = 10
local CARD_HEIGHT = 80
local WELL = { 0.075, 0.075, 0.095 }
local EDGE = { 0.20, 0.20, 0.25 }
local TEXT = { 0.9, 0.9, 0.92 }
local MUTED = { 0.6, 0.6, 0.65 }

local shade, box, stripe, title, text, note, hint, cards, cancel, quit, later

local function Font(parent, size, color, justify)
	local line = parent:CreateFontString(nil, "OVERLAY")
	line:SetFont(SurvivorUI_FONT, size + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	line:SetTextColor(color[1], color[2], color[3])
	line:SetJustifyH(justify or "CENTER")
	return line
end

local function Accent()
	return SurvivorUI_ACCENT or { 1, 0.82, 0 }
end

-- SurvivorUI Classic's state: nil not installed, false off in the game's list,
-- true on.
local function ClassicState()
	local _, _, _, enabled, _, reason = GetAddOnInfo("SurvivorUIClassic")
	if reason == "MISSING" then
		return nil
	end
	return enabled and true or false
end

-- The launcher is there to open the game again.
local function LauncherHere()
	local _, _, _, _, _, reason = GetAddOnInfo("SurvivorUILauncher")
	return reason ~= "MISSING"
end

function SurvivorUI_CanChangeUI()
	return ClassicState() ~= nil
end

local function Close()
	if box then
		box:Hide()
		shade:Hide()
	end
end

local function PaintCard(card)
	local accent = Accent()
	local lit = card.hot and not card.locked
	if lit then
		card:SetBackdropColor(accent[1] * 0.16, accent[2] * 0.16, accent[3] * 0.16, 1)
		card:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
	elseif card.running then
		card:SetBackdropColor(WELL[1] * 1.3, WELL[2] * 1.3, WELL[3] * 1.3, 1)
		card:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.55)
	else
		card:SetBackdropColor(WELL[1], WELL[2], WELL[3], 1)
		card:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], 1)
	end
	if card.locked then
		card.name:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	elseif lit then
		card.name:SetTextColor(1, 1, 1)
	else
		card.name:SetTextColor(accent[1], accent[2], accent[3])
	end
	card.chip:SetTextColor(accent[1], accent[2], accent[3])
end

-- Cards and buttons laid out for the two faces of the box; its height follows.
local function Seat(bottom)
	box:SetHeight(14 + title:GetHeight() + 8 + text:GetHeight() + bottom)
end

local function FaceRestart()
	local db = SurvivorUIClassicDB
	local chosen = (db and db.use == "classic") and "SurvivorUI Classic" or "Survivor UI"
	local accent = Accent()
	stripe:SetVertexColor(accent[1], accent[2], accent[3], 1)
	title:SetText(SurvivorUI_T("Change UI"))
	if LauncherHere() then
		text:SetText(SurvivorUI_TF("{1} runs from the next time the game starts. The game will close and the launcher will open it again by itself.", chosen))
		quit.text:SetText(SurvivorUI_T("Restart game"))
	else
		text:SetText(SurvivorUI_TF("{1} runs from the next time the game starts. Close the game and open it again. Until then, {2} stays on.", chosen, "Survivor UI"))
		quit.text:SetText(SurvivorUI_T("Quit game"))
	end
	note:SetText("")
	hint:SetText("")
	for index = 1, 2 do
		cards[index]:Hide()
	end
	cancel:Hide()
	quit:Show()
	later:Show()
	Seat(14 + 17 + 14)
end

local function Pick()
	local use = this.use
	if this.locked then
		return
	end
	if SurvivorUIClassicDB then
		SurvivorUIClassicDB.use = use
	end
	if use == "survivorui" then
		Close()
	else
		FaceRestart()
	end
end

local function Build()
	-- The shade: the whole screen darker, its clicks kept from what is under it.
	shade = CreateFrame("Frame", "SurvivorUIChangeShade", UIParent)
	shade:SetFrameStrata("FULLSCREEN_DIALOG")
	shade:SetAllPoints(UIParent)
	shade:EnableMouse(true)
	shade.dark = shade:CreateTexture(nil, "BACKGROUND")
	shade.dark:SetTexture(FLAT)
	shade.dark:SetVertexColor(0, 0, 0, 0.55)
	shade.dark:SetAllPoints(shade)
	shade:Hide()

	box = CreateFrame("Frame", "SurvivorUIChangeBox", shade)
	box:SetFrameLevel(shade:GetFrameLevel() + 5)
	box:SetWidth(WIDTH)
	box:SetPoint("CENTER", UIParent, "CENTER", 0, -30)
	box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
	box:SetBackdropBorderColor(0, 0, 0, 1)
	box:EnableMouse(true)

	-- A strip of the addon's color along its top, as the copy box's.
	stripe = box:CreateTexture(nil, "ARTWORK")
	stripe:SetTexture(FLAT)
	stripe:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
	stripe:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -1)
	stripe:SetHeight(2)

	title = Font(box, 13, TEXT)
	title:SetPoint("TOP", box, "TOP", 0, -14)
	text = Font(box, 10, TEXT)
	text:SetWidth(WIDTH - 2 * PAD)
	text:SetPoint("TOP", title, "BOTTOM", 0, -8)

	cards = {}
	local each = (WIDTH - 2 * PAD - GAP) / 2
	local options = {
		{ use = "survivorui", name = "Survivor UI",
			about = SurvivorUI_T("Dark, flat frames of its own, a damage meter, run history and much more.") },
		{ use = "classic", name = "SurvivorUI Classic",
			about = SurvivorUI_T("The game's own look: everything movable, health numbers, a build list, the jewelry worn and a run frame.") },
	}
	for index = 1, 2 do
		local option = options[index]
		local card = CreateFrame("Button", "SurvivorUIChangeCard"..index, box)
		card:SetWidth(each)
		card:SetHeight(CARD_HEIGHT)
		card:SetPoint("TOPLEFT", text, "BOTTOMLEFT", (index - 1) * (each + GAP), -12)
		card:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		card.use = option.use
		card.name = Font(card, 12, TEXT, "LEFT")
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
		card.name:SetText(option.name)
		card.chip = Font(card, 9, TEXT, "RIGHT")
		card.chip:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -11)
		card.about = Font(card, 9, MUTED, "LEFT")
		card.about:SetWidth(each - 20)
		card.about:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -8)
		card.about:SetText(option.about)
		card:SetScript("OnClick", Pick)
		card:SetScript("OnEnter", function() this.hot = true PaintCard(this) end)
		card:SetScript("OnLeave", function() this.hot = nil PaintCard(this) end)
		cards[index] = card
	end

	note = Font(box, 9, { 1, 0.48, 0.42 })
	note:SetWidth(WIDTH - 2 * PAD)
	note:SetPoint("TOPLEFT", cards[1], "BOTTOMLEFT", 0, -8)
	hint = Font(box, 9, MUTED)
	hint:SetWidth(WIDTH - 2 * PAD)
	hint:SetPoint("BOTTOM", box, "BOTTOM", 0, 14)

	cancel = SurvivorUI_GoldButton(box, 90, nil, nil, SurvivorUI_T("Cancel"))
	cancel.icon:Hide()
	cancel.text:ClearAllPoints()
	cancel.text:SetPoint("CENTER", cancel, "CENTER", 0, 0)
	cancel:SetPoint("BOTTOM", box, "BOTTOM", 0, 12)
	cancel:SetScript("OnClick", Close)

	quit = SurvivorUI_GoldButton(box, 110, nil, nil, SurvivorUI_T("Quit game"))
	quit.icon:Hide()
	quit.text:ClearAllPoints()
	quit.text:SetPoint("CENTER", quit, "CENTER", 0, 0)
	quit:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -5, 14)
	quit:SetScript("OnClick", function()
		if LauncherHere() and SurvivorUIClassicDB then
			SurvivorUIClassicDB.restartAt = time()
		end
		if Quit then
			Quit()
		end
	end)
	later = SurvivorUI_GoldButton(box, 110, nil, nil, SurvivorUI_T("Later"))
	later.icon:Hide()
	later.text:ClearAllPoints()
	later.text:SetPoint("CENTER", later, "CENTER", 0, 0)
	later:SetPoint("BOTTOMLEFT", box, "BOTTOM", 5, 14)
	later:SetScript("OnClick", Close)

	box:SetScript("OnKeyDown", function()
		if arg1 == "ESCAPE" then
			Close()
		end
	end)

	if SurvivorUI_OnAccent then
		SurvivorUI_OnAccent(function()
			for index = 1, 2 do
				PaintCard(cards[index])
			end
		end)
	end
end

local function Open()
	if AZS_SetOnTopOfScreens then
		AZS_SetOnTopOfScreens(shade, true)
	end
	shade:Show()
	box:Show()
end

-- closable: asked from a button, with a way out; the first question has none.
local function FaceChoice(closable)
	local db = SurvivorUIClassicDB
	local state = ClassicState()
	local accent = Accent()
	stripe:SetVertexColor(accent[1], accent[2], accent[3], 1)
	title:SetText(SurvivorUI_T(closable and "Change UI" or "Choose your interface"))
	text:SetText(SurvivorUI_T("Survivor UI and SurvivorUI Classic change the same frames, so only one of them can run. Which one do you want to use?"))
	local classic = cards[2]
	cards[1].running = true
	cards[1].chip:SetText(SurvivorUI_T("In use"))
	classic.locked = not state
	classic.chip:SetText((not state and SurvivorUI_T("Off")) or (db and db.use == "classic" and SurvivorUI_T("Next start")) or "")
	classic:SetAlpha(state and 1 or 0.6)
	for index = 1, 2 do
		cards[index].hot = nil
		PaintCard(cards[index])
		cards[index]:Show()
	end
	quit:Hide()
	later:Hide()
	local room = 12 + CARD_HEIGHT + 14
	if state then
		note:SetText("")
	else
		note:SetText(SurvivorUI_T("SurvivorUI Classic is off in the game's Options, AddOns tab. Turn it on there and start the game again."))
		room = room + 8 + note:GetHeight()
	end
	if closable then
		hint:SetText("")
		cancel:Show()
		room = room + 17 + 12
	else
		hint:SetText(SurvivorUI_T("You can change it later: Change UI, in the options."))
		cancel:Hide()
		room = room + hint:GetHeight() + 14
	end
	box:EnableKeyboard(closable and true or false)
	Seat(room)
end

function SurvivorUI_ChangeUI(first)
	if not SurvivorUI_GoldButton then
		return
	end
	if not box then
		Build()
	end
	FaceChoice(not first)
	Open()
end

-- SurvivorUI Classic loads first (the .toc's OptionalDeps): with this addon the
-- one running, its panel's calls come here.
if SUIC then
	function SUIC.ShowChoice(closable)
		SurvivorUI_ChangeUI(not closable)
	end
	function SUIC.ShowRestart()
		if not box then
			Build()
		end
		box:EnableKeyboard(true)
		FaceRestart()
		Open()
	end
end
