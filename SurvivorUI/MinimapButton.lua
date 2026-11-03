-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a square button outside the minimap's bottom left corner, with
-- the addon's own icon in the class's color (Art\SurvivorIconWhite.tga,
-- tinted), that opens the options (each tab's pieces movable while it is
-- open); a right click moves the whole UI (the grid laid out, every piece
-- unlocked). Over it, Run History's, in the same square: an hourglass; over
-- that, two switches with a key each: the game's spell effects (sparkles)
-- and its sound effects (a speaker), on or off. Other minimap buttons stack
-- over them, upward, in the same square look: the game's battleground button
-- (the crossed swords). On top of the switches, the Guide's: the one square
-- filled in gold, whatever the class.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIconWhite"
local SIZE = 16              -- the stock 22, smaller
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }   -- the addon's own color, the class's

-- A square, flat frame around an icon: a black edge, the addon's color under
-- the mouse.
local function Square(frame, icon)
	frame:SetWidth(SIZE)
	frame:SetHeight(SIZE)
	if not frame.squareEdge then
		frame.squareEdge = frame:CreateTexture(nil, "BACKGROUND")
		frame.squareEdge:SetTexture(FLAT)
		frame.squareEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
		frame.squareEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
		frame.squareEdge:SetVertexColor(0, 0, 0, 1)
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(frame)
		-- A game icon has a rim to crop; ours is drawn to the edge.
		if icon ~= frame.ownIcon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	end
end

local function Lit(frame, lit)
	if frame.squareEdge then
		if lit then
			frame.squareEdge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		else
			frame.squareEdge:SetVertexColor(0, 0, 0, 1)
		end
	end
end

------------------------------------------------------------------------------
-- Ours.

local button = CreateFrame("Button", "SurvivorUIMinimapButton", Minimap or UIParent)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
-- Outside the minimap, its bottom left corner; the stack grows upward. Moved
-- (the Frames & bar tab, or Move UI), it keeps its place against the minimap's
-- middle, so it follows the minimap.
local function PlaceButton()
	button:ClearAllPoints()
	local db = SurvivorUIDB
	if Minimap and db and db.mapButtonX and db.mapButtonY then
		button:SetPoint("CENTER", Minimap, "CENTER", db.mapButtonX, db.mapButtonY)
	elseif Minimap then
		button:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -5, 0)
	else
		button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
	end
end
PlaceButton()
button:SetMovable(true)

local function SaveButton()
	local x, y = button:GetCenter()
	local mx, my
	if Minimap then
		mx, my = Minimap:GetCenter()
	end
	if not (x and mx) then
		return
	end
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.mapButtonX = math.floor(x - mx + 0.5)
	SurvivorUIDB.mapButtonY = math.floor(y - my + 0.5)
	PlaceButton()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(button, "Minimap button", SaveButton, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.mapButtonX, SurvivorUIDB.mapButtonY = nil, nil
		end
		PlaceButton()
	end)
end
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(ICON)
button.ownIcon = button.icon
Square(button, button.icon)
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function() button.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
end

button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetScript("OnClick", function()
	local options = getglobal("SurvivorUIOptions")
	local mini = getglobal("SurvivorUIOptionsMini")
	if mini and mini:IsShown() and arg1 ~= "RightButton" then
		SurvivorUI_ToggleOptions()
	elseif options and options:IsShown() then
		options:Hide()
	elseif arg1 == "RightButton" then
		if SurvivorUI_OpenOptionsMoving then
			SurvivorUI_OpenOptionsMoving()
		end
	elseif SurvivorUI_ToggleOptions then
		SurvivorUI_ToggleOptions()
	end
end)
button:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(SurvivorUI_T("Survivor UI"), ACCENT[1], ACCENT[2], ACCENT[3])
	GameTooltip:AddLine(SurvivorUI_T("Click: options"), 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T("Right click: move the whole UI"), 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- Run History's: the same square over ours, an hourglass in its frame
-- (Art\HistoryIconWhite, ours with the S taken out, tinted as ours); a click
-- opens Run History. Off with "Run History button" (the options' Minimap tab).

local historyButton = CreateFrame("Button", "SurvivorUIHistoryButton", Minimap or UIParent)
historyButton:SetFrameStrata("MEDIUM")
historyButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
historyButton:SetPoint("BOTTOM", button, "TOP", 0, 5)
historyButton.icon = historyButton:CreateTexture(nil, "ARTWORK")
historyButton.icon:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\HistoryIconWhite")
historyButton.ownIcon = historyButton.icon
Square(historyButton, historyButton.icon)
if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function() historyButton.icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
end
historyButton:SetScript("OnClick", function()
	if SurvivorUI_ShowLastRuns then
		SurvivorUI_ShowLastRuns()
	end
end)
historyButton:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(SurvivorUI_T("Run History"), ACCENT[1], ACCENT[2], ACCENT[3])
	GameTooltip:AddLine(SurvivorUI_T("Click: your runs, each as it ended"), 1, 1, 1)
	GameTooltip:Show()
end)
historyButton:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

-- Shown or not by its option; what stacks over it then sits over it.
local function HistoryShown()
	return not (SurvivorUIDB and SurvivorUIDB.historyMapButton == false)
end

-- Run History's when it shows, else ours: the note's level (below), and the
-- switches' foot.
local function HistoryTop()
	return HistoryShown() and historyButton or button
end

------------------------------------------------------------------------------
-- Two of the game's own settings in a click (from tomlrd's pull request),
-- each in the same square over Run History's, its icon drawn as Run
-- History's (Art\EffectsIconWhite, Art\SoundIconWhite, tinted as ours);
-- while off, struck through (their Off twins) and dimmed:
-- - the spell effects: the game's No Spell Effects (its Graphics page, the
--   noSpellEffects setting): no explosions, missiles, glows or beams;
-- - the sound effects: the game's Sound Volume down to nothing, and back to
--   where it was. The game keeps no sound of the spells apart, so the hits
--   and the clicks go with them; the music and the ambience stay.
-- A key each too (Bindings.xml; the options' Minimap tab sets them). The
-- game's pages switch them as well: each read again twice a second. Off with
-- "Spell effects button" and "Sound effects button" (the options' Minimap
-- tab).

local SWITCH_ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local switches = {}

-- No Spell Effects: on (effects drawn) unless "1".
local function EffectsOn()
	return GetCVar("noSpellEffects") ~= "1"
end

-- The sound effects' volume: on above nothing.
local function SoundOn()
	return (tonumber(GetCVar("SoundVolume")) or 1) > 0
end

local function FlipEffects()
	SetCVar("noSpellEffects", EffectsOn() and "1" or "0")
end

-- Muted, the volume it had is kept for the way back.
local function FlipSound()
	SurvivorUIDB = SurvivorUIDB or {}
	if SoundOn() then
		SurvivorUIDB.soundVolume = GetCVar("SoundVolume")
		SetCVar("SoundVolume", "0")
	else
		SetCVar("SoundVolume", SurvivorUIDB.soundVolume or "1")
		SurvivorUIDB.soundVolume = nil
	end
end

-- The range rings (WorldMarks.lua), the minimap's and the ground's: on while
-- either is. Off, the ones that were on are kept, and the way back brings
-- those (both when none was kept).
local RANGE_KEYS = { "rangeMinimap", "rangeWorld" }

local function RangeOn()
	if not SurvivorUI_WorldOn then
		return false
	end
	return SurvivorUI_WorldOn("rangeMinimap") or SurvivorUI_WorldOn("rangeWorld")
end

local function FlipRange()
	if not SurvivorUI_ToggleWorld then
		return
	end
	SurvivorUIDB = SurvivorUIDB or {}
	local db = SurvivorUIDB
	if RangeOn() then
		db.rangeKept = {}
		for _, key in pairs(RANGE_KEYS) do
			if SurvivorUI_WorldOn(key) then
				db.rangeKept[key] = true
				SurvivorUI_ToggleWorld(key)
			end
		end
	else
		local kept = db.rangeKept
		if not (kept and next(kept)) then
			kept = { rangeMinimap = true, rangeWorld = true }
		end
		for key in pairs(kept) do
			if not SurvivorUI_WorldOn(key) then
				SurvivorUI_ToggleWorld(key)
			end
		end
		db.rangeKept = nil
	end
end

local function PaintSwitch(switch)
	local on = switch.read()
	if switch.shownOn ~= on then
		switch.shownOn = on
		switch.icon:SetTexture(SWITCH_ART..switch.art..(on and "IconWhite" or "OffIconWhite"))
	end
	local dim = on and 1 or 0.55
	switch.icon:SetVertexColor(ACCENT[1] * dim, ACCENT[2] * dim, ACCENT[3] * dim)
end

local function SwitchTip(switch)
	local on = switch.read()
	GameTooltip:SetOwner(switch, "ANCHOR_LEFT")
	GameTooltip:SetText(SurvivorUI_T(switch.title), ACCENT[1], ACCENT[2], ACCENT[3])
	GameTooltip:AddLine(SurvivorUI_T(on and switch.onLine or switch.offLine), 1, 1, 1)
	local key = GetBindingKey and GetBindingKey(switch.binding)
	GameTooltip:AddLine(key and SurvivorUI_TF("Key: {1}", key) or SurvivorUI_T("A key for it: options, Minimap"), 0.7, 0.7, 0.7)
	if switch.note then
		GameTooltip:AddLine(SurvivorUI_T(switch.note), 0.6, 0.6, 0.65, 1)
	end
	GameTooltip:Show()
end

-- One switch: its setting read and flipped, its option and key, its words.
local function Switch(spec)
	local switch = CreateFrame("Button", spec.name, Minimap or UIParent)
	switch:SetFrameStrata("MEDIUM")
	switch:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
	switch.icon = switch:CreateTexture(nil, "ARTWORK")
	switch.ownIcon = switch.icon
	Square(switch, switch.icon)
	for key, value in pairs(spec) do
		switch[key] = value
	end
	switch:SetScript("OnClick", function()
		this.flip()
		PaintSwitch(this)
		SwitchTip(this)
	end)
	switch:SetScript("OnEnter", function()
		Lit(this, true)
		SwitchTip(this)
	end)
	switch:SetScript("OnLeave", function()
		Lit(this, false)
		GameTooltip:Hide()
	end)
	switch.wait = 0
	switch:SetScript("OnUpdate", function()
		this.wait = this.wait + arg1
		if this.wait >= 0.5 then
			this.wait = 0
			PaintSwitch(this)
		end
	end)
	PaintSwitch(switch)
	table.insert(switches, switch)
	return switch
end

local effectsSwitch = Switch({ name = "SurvivorUIEffectsButton", art = "Effects", option = "effectsMapButton",
	binding = "SURVIVORUI_SPELLEFFECTS", read = EffectsOn, flip = FlipEffects, title = "Spell effects",
	onLine = "Shown. Click: hide them (no explosions, missiles, glows or beams)", offLine = "Hidden. Click: show them" })
local soundSwitch = Switch({ name = "SurvivorUISoundButton", art = "Sound", option = "soundMapButton",
	binding = "SURVIVORUI_SOUNDEFFECTS", read = SoundOn, flip = FlipSound, title = "Sound effects",
	onLine = "On. Click: mute them, the music and the ambience kept", offLine = "Muted. Click: back to their volume",
	note = "The game keeps no sound of the spells apart: the hits and the clicks go with them." })
local rangeSwitch = Switch({ name = "SurvivorUIRangeButton", art = "Range", option = "rangeMapButton",
	binding = "SURVIVORUI_RANGERING", read = RangeOn, flip = FlipRange, title = "Range ring",
	onLine = "Shown. Click: hide it, on the minimap and round you", offLine = "Hidden. Click: show it again",
	note = "Which rings show: options, World markers." })

if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(function()
		for index = 1, table.getn(switches) do
			PaintSwitch(switches[index])
		end
	end)
end

local function SwitchShown(switch)
	return not (SurvivorUIDB and SurvivorUIDB[switch.option] == false)
end

-- The keys (Bindings.xml): each switch as its click, said in the chat, as a
-- key gives no other sign of it.
local function KeyFlip(switch)
	switch.flip()
	PaintSwitch(switch)
	DEFAULT_CHAT_FRAME:AddMessage(SurvivorUI_TF("Survivor UI: {1} {2}.", SurvivorUI_T(switch.title),
		SurvivorUI_T(switch.read() and "on" or "off")))
end

BINDING_HEADER_SURVIVORUI = "Survivor UI"
BINDING_NAME_SURVIVORUI_SPELLEFFECTS = "Spell effects on or off"
BINDING_NAME_SURVIVORUI_SOUNDEFFECTS = "Sound effects on or off"
BINDING_NAME_SURVIVORUI_RANGERING = "Range ring on or off"

function SurvivorUI_ToggleSpellEffects()
	KeyFlip(effectsSwitch)
end

function SurvivorUI_ToggleSoundEffects()
	KeyFlip(soundSwitch)
end

function SurvivorUI_ToggleRangeRing()
	KeyFlip(rangeSwitch)
end

-- The top of the switches: the last one shown, else Run History's, else ours.
local function SwitchTop()
	local top = HistoryTop()
	for index = 1, table.getn(switches) do
		if SwitchShown(switches[index]) then
			top = switches[index]
		end
	end
	return top
end

------------------------------------------------------------------------------
-- The Guide's (Guide.lua): the same square, filled in gold with a dark mark,
-- so it stands apart from the class's colors around it: a ! that breathes
-- while a page is unread, a ? once all are read. Off with "Guide button" (the
-- options' Minimap tab).

local GUIDE_GOLD = { 1, 0.78, 0.15 }
local guideButton = CreateFrame("Button", "SurvivorUIGuideButton", Minimap or UIParent)
guideButton:SetFrameStrata("MEDIUM")
guideButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
guideButton.icon = guideButton:CreateTexture(nil, "ARTWORK")
guideButton.icon:SetTexture(FLAT)
guideButton.icon:SetVertexColor(GUIDE_GOLD[1], GUIDE_GOLD[2], GUIDE_GOLD[3])
guideButton.ownIcon = guideButton.icon
Square(guideButton, guideButton.icon)
guideButton.mark = guideButton:CreateFontString(nil, "OVERLAY")
guideButton.mark:SetFont("Fonts\\FRIZQT__.TTF", 13)
guideButton.mark:SetTextColor(0.13, 0.08, 0)
guideButton.mark:SetPoint("CENTER", guideButton, "CENTER", 0, 0)
guideButton.wait = 0
guideButton:SetScript("OnClick", function()
	if SurvivorUI_ToggleGuide then
		GameTooltip:Hide()
		if SurvivorUIGuideHint then
			SurvivorUIGuideHint:Hide()
		end
		SurvivorUI_ToggleGuide()
	end
end)
guideButton:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(SurvivorUI_T("Guide"), GUIDE_GOLD[1], GUIDE_GOLD[2], GUIDE_GOLD[3])
	GameTooltip:AddLine(SurvivorUI_T("How Luck, Damage and Crit really work."), 1, 1, 1)
	if SurvivorUI_GuideUnread and SurvivorUI_GuideUnread() then
		GameTooltip:AddLine(SurvivorUI_T("Something new to read!"), GUIDE_GOLD[1], GUIDE_GOLD[2], GUIDE_GOLD[3])
	end
	GameTooltip:Show()
end)
guideButton:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

-- Its mark, as the pages stand.
function SurvivorUI_PaintGuideButton()
	local unread = SurvivorUI_GuideUnread and SurvivorUI_GuideUnread()
	guideButton.unread = unread
	guideButton.mark:SetText(unread and "!" or "?")
	if not unread then
		guideButton.icon:SetAlpha(1)
	end
end

guideButton:SetScript("OnUpdate", function()
	if this.unread then
		this.wait = this.wait + arg1
		this.icon:SetAlpha(0.8 + 0.2 * math.sin(this.wait * 4))
	end
end)

local function GuideShown()
	return not (SurvivorUIDB and SurvivorUIDB.guideMapButton == false)
end

-- A note beside the button, once for each player, some seconds into their
-- first run with it: as Run History's note below, the result box in the Guide's
-- gold, alive. A click opens the Guide; it goes by itself after a while.
local HINT_DELAY, HINT_SECONDS = 5, 25

local hint = CreateFrame("Button", "SurvivorUIGuideHint", UIParent)
hint:SetFrameStrata("HIGH")
hint:SetWidth(120)
hint:SetHeight(32)
hint:Hide()

-- Made the first time: the box is Run History's, which loads after this file.
local function HintParts()
	if hint.face then
		return
	end
	if SurvivorUI_ResultBadge then
		hint.look = SurvivorUI_ResultBadge(hint)
		hint.look:SetAllPoints(hint)
		hint.look.text:Hide()
		hint.look.time:Hide()
		SurvivorUI_SetResultBadge(hint.look, "guide", nil)
	else
		hint:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		hint:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
	end
	local face = CreateFrame("Frame", nil, hint)
	face:SetAllPoints(hint)
	face:SetFrameLevel(hint:GetFrameLevel() + 10)
	hint.face = face
	hint.title = face:CreateFontString(nil, "OVERLAY")
	hint.title:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	hint.title:SetPoint("TOPLEFT", face, "TOPLEFT", 7, -5)
	hint.title:SetTextColor(1, 1, 1)
	hint.title:SetText(SurvivorUI_T("Questions about a mechanic?"))
	hint.line = face:CreateFontString(nil, "OVERLAY")
	hint.line:SetFont(SurvivorUI_FONT, 7 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	hint.line:SetPoint("TOPLEFT", hint.title, "BOTTOMLEFT", 0, -3)
	hint.line:SetTextColor(1, 0.92, 0.65)
	hint.line:SetText(SurvivorUI_T("Click: the Guide explains it"))
	local close = CreateFrame("Button", nil, face)
	close:SetWidth(12)
	close:SetHeight(12)
	close:SetPoint("TOPRIGHT", face, "TOPRIGHT", -1, -1)
	close.text = close:CreateFontString(nil, "OVERLAY")
	close.text:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.text:SetText(SurvivorUI_T("x"))
	close.text:SetTextColor(0.85, 0.85, 0.9)
	close:SetScript("OnClick", function() hint:Hide() end)
	close:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	close:SetScript("OnLeave", function() this.text:SetTextColor(0.85, 0.85, 0.9) end)
end

hint:SetScript("OnClick", function()
	this:Hide()
	if SurvivorUI_ToggleGuide then
		SurvivorUI_ToggleGuide()
	end
end)
hint:SetScript("OnEnter", function()
	if this.look then
		this.look.hot = true
	end
end)
hint:SetScript("OnLeave", function()
	if this.look then
		this.look.hot = nil
	end
end)
hint:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local left = HINT_SECONDS - this.age
	if left <= 0 or (AZS_GetPhase and AZS_GetPhase() == "choosing") then
		this:Hide()
	else
		this:SetAlpha(math.min(1, this.age * 3, left * 3))
	end
end)

local hintWatch = CreateFrame("Frame")
local hintWait, hintPlayed = 0, 0
hintWatch:SetScript("OnUpdate", function()
	hintWait = hintWait + arg1
	if hintWait < 1 then
		return
	end
	hintWait = 0
	if not SurvivorUIDB then
		return
	end
	if SurvivorUIDB.guideHintSeen then
		this:SetScript("OnUpdate", nil)
		return
	end
	local history = getglobal("SurvivorUIHistoryNotice")
	if SurvivorUIDB.guideMapButton == false or not guideButton:IsVisible() or (history and history:IsShown())
		or not AZS_GetPhase or AZS_GetPhase() ~= "playing" then
		return
	end
	hintPlayed = hintPlayed + 1
	if hintPlayed >= HINT_DELAY then
		SurvivorUIDB.guideHintSeen = true
		HintParts()
		hint:SetWidth(math.max(hint.title:GetStringWidth() + 24, hint.line:GetStringWidth() + 16))
		hint:ClearAllPoints()
		if SurvivorUI_RoomOnRight(guideButton) then
			hint:SetPoint("BOTTOMLEFT", guideButton, "BOTTOMRIGHT", 6, 0)
		else
			hint:SetPoint("BOTTOMRIGHT", guideButton, "BOTTOMLEFT", -6, 0)
		end
		hint.age = 0
		hint:SetAlpha(0)
		hint:Show()
	end
end)

-- The top of the stack: the Guide's when it shows, else the switches'.
local function StackTop()
	return GuideShown() and guideButton or SwitchTop()
end

------------------------------------------------------------------------------
-- The game's battleground button: square, beside ours. The stock code shows it
-- and hides it as queues come and go; only its look and place change.

local function RestyleBattlefield()
	local frame = getglobal("MiniMapBattlefieldFrame")
	if not frame then
		return
	end
	local border = getglobal("MiniMapBattlefieldBorder")
	if border then
		border:Hide()
		border:SetAlpha(0)
	end
	Square(frame, getglobal("MiniMapBattlefieldIcon"))
	-- Over ours (and Run History's), in the stack outside the minimap.
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", StackTop(), "TOP", 0, 5)
	if not frame.squareHooked then
		frame.squareHooked = true
		local stockEnter, stockLeave = frame:GetScript("OnEnter"), frame:GetScript("OnLeave")
		frame:SetScript("OnEnter", function()
			Lit(this, true)
			if stockEnter then
				stockEnter()
			end
		end)
		frame:SetScript("OnLeave", function()
			Lit(this, false)
			if stockLeave then
				stockLeave()
			end
		end)
	end
end

-- The stack laid out again: Run History's shown or not, the switches shown
-- over it, the battleground's over the top. For the options' Minimap tab too.
function SurvivorUI_PlaceMapButtons()
	if HistoryShown() then
		historyButton:Show()
	else
		historyButton:Hide()
	end
	local under = HistoryTop()
	for index = 1, table.getn(switches) do
		local switch = switches[index]
		switch:ClearAllPoints()
		switch:SetPoint("BOTTOM", under, "TOP", 0, 5)
		if SwitchShown(switch) then
			switch:Show()
			under = switch
		else
			switch:Hide()
		end
	end
	guideButton:ClearAllPoints()
	guideButton:SetPoint("BOTTOM", under, "TOP", 0, 5)
	if GuideShown() then
		guideButton:Show()
	else
		guideButton:Hide()
	end
	SurvivorUI_PaintGuideButton()
	RestyleBattlefield()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
loader:SetScript("OnEvent", function()
	PlaceButton()
	SurvivorUI_PlaceMapButtons()
end)

------------------------------------------------------------------------------
-- A note beside Run History's button as a run begins, when the last run kept
-- was won or went on in endless mode: "Last run summary is available!", and
-- the zone (green), its time (white) and the result (its color). The whole note is the result's box as Run
-- History has it (RunHistory.lua's), alive: its color, its breathing glow, its
-- sparks (Victory green, sparks rising and a shine; Endless purple, sparks
-- circling). Level with Run History's button at its foot. A click opens Run
-- History on it; it goes by itself after a while, and comes once for each
-- run kept.

local NOTICE_SECONDS = 25
-- Each result's word color: its box's edge.
local RESULT_COLORS = { victory = { 0.62, 1.00, 0.66 }, endless = { 0.86, 0.66, 1.00 }, left = { 0.62, 0.82, 1.00 },
	dead = { 1.00, 0.55, 0.48 } }
local RESULT_WORDS = { victory = "VICTORY", endless = "ENDLESS", left = "LEFT", dead = "FALLEN" }
-- The results that bring the note (an endless run's always does).
local NOTICE_RESULTS = { victory = true }

local notice = CreateFrame("Button", "SurvivorUIHistoryNotice", UIParent)
notice:SetFrameStrata("HIGH")
notice:SetWidth(120)
notice:SetHeight(32)
notice:Hide()

-- The box and the words over it, made the first time: the box is Run
-- History's, which loads after this file.
local function NoticeParts()
	if notice.face then
		return
	end
	if SurvivorUI_ResultBadge then
		notice.look = SurvivorUI_ResultBadge(notice)
		notice.look:SetAllPoints(notice)
		notice.look.text:Hide()
		notice.look.time:Hide()
	else
		notice:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		notice:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
	end
	local face = CreateFrame("Frame", nil, notice)
	face:SetAllPoints(notice)
	face:SetFrameLevel(notice:GetFrameLevel() + 10)
	notice.face = face
	notice.title = face:CreateFontString(nil, "OVERLAY")
	notice.title:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	notice.title:SetPoint("TOPLEFT", face, "TOPLEFT", 7, -5)
	notice.title:SetTextColor(1, 1, 1)
	notice.title:SetText(SurvivorUI_T("Last run summary is available!"))
	notice.line = face:CreateFontString(nil, "OVERLAY")
	notice.line:SetFont(SurvivorUI_FONT, 7 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	notice.line:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -3)
	notice.line:SetTextColor(0.95, 0.95, 1)
	local close = CreateFrame("Button", nil, face)
	close:SetWidth(12)
	close:SetHeight(12)
	close:SetPoint("TOPRIGHT", face, "TOPRIGHT", -1, -1)
	close.text = close:CreateFontString(nil, "OVERLAY")
	close.text:SetFont(SurvivorUI_FONT, 8 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.text:SetText(SurvivorUI_T("x"))
	close.text:SetTextColor(0.85, 0.85, 0.9)
	close:SetScript("OnClick", function() notice:Hide() end)
	close:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	close:SetScript("OnLeave", function() this.text:SetTextColor(0.85, 0.85, 0.9) end)
end

notice:SetScript("OnClick", function()
	this:Hide()
	local history = getglobal("SurvivorUILastRuns")
	if SurvivorUI_ShowLastRuns and not (history and history:IsShown()) then
		SurvivorUI_ShowLastRuns()
	end
end)
-- Under the mouse the box glows brighter, as Run History's does.
notice:SetScript("OnEnter", function()
	if this.look then
		this.look.hot = true
	end
end)
notice:SetScript("OnLeave", function()
	if this.look then
		this.look.hot = nil
	end
end)
-- In over a third of a second, out the same way after its time.
notice:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local left = NOTICE_SECONDS - this.age
	if left <= 0 then
		this:Hide()
	else
		this:SetAlpha(math.min(1, this.age * 3, left * 3))
	end
end)

local function MinSec(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

-- The note for the newest run kept, when it was won or went endless: once
-- each (or always, asked by hand: /script SurvivorUI_HistoryNotice(true)).
-- A look of a result to see it in (victory, endless, left, dead): with the
-- newest run's zone and time, the run not marked as seen.
function SurvivorUI_HistoryNotice(force, look)
	local run = SurvivorUI_NewestRun and SurvivorUI_NewestRun()
	if not run then
		return
	end
	local kind = look or (run.endless and "endless" or (NOTICE_RESULTS[run.result] and run.result or nil))
	SurvivorUIDB = SurvivorUIDB or {}
	if not kind or not RESULT_WORDS[kind] or (not force and SurvivorUIDB.historyNoticed == run.at) then
		return
	end
	if not look then
		SurvivorUIDB.historyNoticed = run.at
	end
	NoticeParts()
	local color = RESULT_COLORS[kind]
	local seconds = kind == "endless" and run.endless and run.endless.time or run.time
	if notice.look then
		SurvivorUI_SetResultBadge(notice.look, kind, nil)
	end
	-- "Elwynn Forest 20:50 - ENDLESS": the zone green, the time white, the result its color.
	notice.line:SetText(string.format("|cff4dff70%s|r  |cffffffff%s|r  -  |cff%02x%02x%02x%s|r",
		run.zone or "", MinSec(seconds),
		math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), RESULT_WORDS[kind]))
	notice:SetWidth(math.max(notice.title:GetStringWidth() + 24, notice.line:GetStringWidth() + 16))
	-- Level with Run History's button at its foot, growing up: apart from ours.
	notice:ClearAllPoints()
	notice:SetPoint("BOTTOMRIGHT", HistoryTop(), "BOTTOMLEFT", -6, 0)
	notice.age = 0
	notice:SetAlpha(0)
	notice:Show()
end

-- As a run begins: playing, its clock in its first seconds, after no run.
local noticePhase
local noticeWatch = CreateFrame("Frame")
local noticeWait = 0
noticeWatch:SetScript("OnUpdate", function()
	noticeWait = noticeWait + arg1
	if noticeWait < 0.5 then
		return
	end
	noticeWait = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	local now = AZS_GetRunTime and AZS_GetRunTime()
	if phase == "playing" and noticePhase ~= "playing" and noticePhase ~= "choosing" and noticePhase ~= "paused"
		and now and now < 15 then
		SurvivorUI_HistoryNotice()
	end
	noticePhase = phase
end)
