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
-- That is their first order and look: the options' Minimap buttons tab sets
-- which show, their order, each one's color, the way they line up (up, down,
-- left or right), their size and the gap between them. A frame of their own
-- holds them all ("Minimap buttons" in move mode), so they move as one.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIconWhite"
local ACCENT = SurvivorUI_ACCENT or { 1, 0.82, 0 }   -- the addon's own color, the class's

-- Their size (the stock 22, smaller), the gap between two, and the way the
-- line grows from the first.
local function Size()
	return SurvivorUIDB and SurvivorUIDB.mapButtonSize or 16
end

local function Gap()
	return SurvivorUIDB and SurvivorUIDB.mapButtonGap or 5
end

-- Each way: its step, the holder's side the first sits against, the far side.
local WAYS = {
	up = { 0, 1, "BOTTOM", "TOP" }, down = { 0, -1, "TOP", "BOTTOM" },
	left = { -1, 0, "RIGHT", "LEFT" }, right = { 1, 0, "LEFT", "RIGHT" },
}

local function Way()
	local way = SurvivorUIDB and SurvivorUIDB.mapButtonWay
	return WAYS[way] and way or "up"
end

-- A square, flat frame around an icon: a black edge, the button's color under
-- the mouse.
local function Square(frame, icon)
	frame:SetWidth(Size())
	frame:SetHeight(Size())
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
			local tint = frame.tint or ACCENT
			frame.squareEdge:SetVertexColor(tint[1], tint[2], tint[3], 1)
		else
			frame.squareEdge:SetVertexColor(0, 0, 0, 1)
		end
	end
end

-- The colors to pick for each (the options' Minimap buttons tab): the class's
-- (the addon's own, gold if Global says so) or one of these.
SurvivorUI_MAPBUTTON_COLORS = {
	{ "class", "Class color", nil },
	{ "gold", "@color:Gold", { 1.00, 0.78, 0.15 } },
	{ "white", "White", { 1.00, 1.00, 1.00 } },
	{ "red", "Red", { 1.00, 0.28, 0.22 } },
	{ "orange", "Orange", { 1.00, 0.55, 0.15 } },
	{ "green", "Green", { 0.40, 1.00, 0.45 } },
	{ "teal", "Teal", { 0.30, 0.95, 0.90 } },
	{ "blue", "Blue", { 0.40, 0.65, 1.00 } },
	{ "purple", "Purple", { 0.72, 0.48, 1.00 } },
	{ "pink", "Pink", { 1.00, 0.50, 0.80 } },
}

-- Ours by key, each made below: { frame, the option that hides it (false),
-- its first color, its name }; and their first order, the first at the foot.
local stack = {}
local ORDER = { "options", "history", "effects", "sound", "range", "guide" }

local function Shown(key)
	return not (SurvivorUIDB and SurvivorUIDB[stack[key].option] == false)
end

-- The order kept, any key it lacks after it in its first place's turn.
local function Order()
	local order, seen = {}, {}
	local saved = SurvivorUIDB and SurvivorUIDB.mapButtonOrder
	if type(saved) == "table" then
		for index = 1, table.getn(saved) do
			local key = saved[index]
			if stack[key] and not seen[key] then
				table.insert(order, key)
				seen[key] = true
			end
		end
	end
	for index = 1, table.getn(ORDER) do
		if not seen[ORDER[index]] then
			table.insert(order, ORDER[index])
		end
	end
	return order
end

local function ColorKey(key)
	local colors = SurvivorUIDB and SurvivorUIDB.mapButtonColors
	return colors and colors[key] or stack[key].color or "class"
end

-- A button's color: r, g, b.
local function Tint(key)
	local chosen = ColorKey(key)
	for index = 1, table.getn(SurvivorUI_MAPBUTTON_COLORS) do
		local entry = SurvivorUI_MAPBUTTON_COLORS[index]
		if entry[1] == chosen and entry[3] then
			return entry[3][1], entry[3][2], entry[3][3]
		end
	end
	return ACCENT[1], ACCENT[2], ACCENT[3]
end

-- The frame that holds them all, sized to them: what moves (Move UI, or
-- dragged while the Minimap buttons tab is open). Its place is the first
-- one's middle against the minimap's (mapButtonX and mapButtonY, as the
-- button alone had it), so it follows the minimap. First, outside the
-- minimap's bottom left corner; down, its top left; right, the row ends at
-- the bottom left corner.
local holder = CreateFrame("Frame", "SurvivorUIMapButtons", Minimap or UIParent)
holder:SetFrameStrata("MEDIUM")
holder:SetWidth(16)
holder:SetHeight(16)
holder:SetMovable(true)

local function PlaceHolder()
	holder:ClearAllPoints()
	local db = SurvivorUIDB
	local way = WAYS[Way()]
	local half = Size() / 2
	if Minimap and db and db.mapButtonX and db.mapButtonY then
		holder:SetPoint(way[3], Minimap, "CENTER", db.mapButtonX - way[1] * half, db.mapButtonY - way[2] * half)
	elseif Minimap and Way() == "down" then
		holder:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, 0)
	elseif Minimap then
		holder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -5, 0)
	else
		holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
	end
end

local function SaveHolder()
	local left, bottom = holder:GetLeft(), holder:GetBottom()
	local mx, my
	if Minimap then
		mx, my = Minimap:GetCenter()
	end
	if not (left and mx) then
		return
	end
	local width, height, half = holder:GetWidth(), holder:GetHeight(), Size() / 2
	local x, y = left + width / 2, bottom + height / 2
	local way = Way()
	if way == "up" then
		y = bottom + half
	elseif way == "down" then
		y = bottom + height - half
	elseif way == "left" then
		x = left + width - half
	else
		x = left + half
	end
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.mapButtonX = math.floor(x - mx + 0.5)
	SurvivorUIDB.mapButtonY = math.floor(y - my + 0.5)
	PlaceHolder()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Minimap buttons", SaveHolder, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.mapButtonX, SurvivorUIDB.mapButtonY = nil, nil
		end
		PlaceHolder()
	end)
end

------------------------------------------------------------------------------
-- Ours.

local button = CreateFrame("Button", "SurvivorUIMinimapButton", Minimap or UIParent)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetTexture(ICON)
button.ownIcon, button.iconPath = button.icon, ICON
Square(button, button.icon)
stack.options = { frame = button, option = "optionsMapButton", title = "Survivor UI" }

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
	GameTooltip:SetText(SurvivorUI_T("Survivor UI"), this.tint[1], this.tint[2], this.tint[3])
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
-- opens Run History. Off in the options' Minimap buttons tab.

local historyButton = CreateFrame("Button", "SurvivorUIHistoryButton", Minimap or UIParent)
historyButton:SetFrameStrata("MEDIUM")
historyButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
historyButton.icon = historyButton:CreateTexture(nil, "ARTWORK")
historyButton.iconPath = "Interface\\AddOns\\SurvivorUI\\Art\\HistoryIconWhite"
historyButton.icon:SetTexture(historyButton.iconPath)
historyButton.ownIcon = historyButton.icon
Square(historyButton, historyButton.icon)
stack.history = { frame = historyButton, option = "historyMapButton", title = "Run History" }
historyButton:SetScript("OnClick", function()
	if SurvivorUI_ShowLastRuns then
		SurvivorUI_ShowLastRuns()
	end
end)
historyButton:SetScript("OnEnter", function()
	Lit(this, true)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(SurvivorUI_T("Run History"), this.tint[1], this.tint[2], this.tint[3])
	GameTooltip:AddLine(SurvivorUI_T("Click: your runs, each as it ended"), 1, 1, 1)
	GameTooltip:Show()
end)
historyButton:SetScript("OnLeave", function()
	Lit(this, false)
	GameTooltip:Hide()
end)

-- What the run's note (below) sits beside: Run History's when it shows, else
-- the first one shown, else the holder.
local function NoteAnchor()
	if Shown("history") then
		return historyButton
	end
	local order = Order()
	for index = 1, table.getn(order) do
		if Shown(order[index]) then
			return stack[order[index]].frame
		end
	end
	return holder
end

-- A note beside a button, away from the line they make: in a column, at its
-- side with the room, level with its foot; in a row, under it (over it in the
-- screen's lower half).
local function Beside(note, frame)
	note:ClearAllPoints()
	local right = SurvivorUI_RoomOnRight(frame)
	local way = Way()
	if way == "up" or way == "down" then
		if right then
			note:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 6, 0)
		else
			note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -6, 0)
		end
		return
	end
	local _, middle = frame:GetCenter()
	local low = middle and middle * frame:GetEffectiveScale() < GetScreenHeight() * UIParent:GetEffectiveScale() / 2
	local side = right and "LEFT" or "RIGHT"
	if low then
		note:SetPoint("BOTTOM"..side, frame, "TOP"..side, 0, 6)
	else
		note:SetPoint("TOP"..side, frame, "BOTTOM"..side, 0, -6)
	end
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
-- A key each too (Bindings.xml; the options' Minimap buttons tab sets them).
-- The game's pages switch them as well: each read again twice a second. Off
-- in the options' Minimap buttons tab.

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
		switch.iconPath = SWITCH_ART..switch.art..(on and "IconWhite" or "OffIconWhite")
		switch.icon:SetTexture(switch.iconPath)
	end
	local tint = switch.tint or ACCENT
	local dim = on and 1 or 0.55
	switch.icon:SetVertexColor(tint[1] * dim, tint[2] * dim, tint[3] * dim)
end

local function SwitchTip(switch)
	local on = switch.read()
	GameTooltip:SetOwner(switch, "ANCHOR_LEFT")
	local tint = switch.tint or ACCENT
	GameTooltip:SetText(SurvivorUI_T(switch.title), tint[1], tint[2], tint[3])
	GameTooltip:AddLine(SurvivorUI_T(on and switch.onLine or switch.offLine), 1, 1, 1)
	local key = GetBindingKey and GetBindingKey(switch.binding)
	GameTooltip:AddLine(key and SurvivorUI_TF("Key: {1}", key) or SurvivorUI_T("A key for it: options, Minimap buttons"), 0.7, 0.7, 0.7)
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
	stack[spec.key] = { frame = switch, option = spec.option, title = spec.title, binding = spec.binding }
	return switch
end

local effectsSwitch = Switch({ key = "effects", name = "SurvivorUIEffectsButton", art = "Effects", option = "effectsMapButton",
	binding = "SURVIVORUI_SPELLEFFECTS", read = EffectsOn, flip = FlipEffects, title = "Spell effects",
	onLine = "Shown. Click: hide them (no explosions, missiles, glows or beams)", offLine = "Hidden. Click: show them" })
local soundSwitch = Switch({ key = "sound", name = "SurvivorUISoundButton", art = "Sound", option = "soundMapButton",
	binding = "SURVIVORUI_SOUNDEFFECTS", read = SoundOn, flip = FlipSound, title = "Sound effects",
	onLine = "On. Click: mute them, the music and the ambience kept", offLine = "Muted. Click: back to their volume",
	note = "The game keeps no sound of the spells apart: the hits and the clicks go with them." })
local rangeSwitch = Switch({ key = "range", name = "SurvivorUIRangeButton", art = "Range", option = "rangeMapButton",
	binding = "SURVIVORUI_RANGERING", read = RangeOn, flip = FlipRange, title = "Range ring",
	onLine = "Shown. Click: hide it, on the minimap and round you", offLine = "Hidden. Click: show it again",
	note = "Which rings show: options, World markers." })

-- The keys (Bindings.xml): each switch as its click, said in the chat, as a
-- key gives no other sign of it.
local function KeyFlip(switch)
	switch.flip()
	PaintSwitch(switch)
	DEFAULT_CHAT_FRAME:AddMessage(SurvivorUI_TF("Survivor UI: {1} {2}.", SurvivorUI_T(switch.title),
		SurvivorUI_T(switch.read() and "on" or "off")))
end

BINDING_HEADER_SURVIVORUI = "Survivor UI"
BINDING_NAME_SURVIVORUI_SPELLEFFECTS = SurvivorUI_T("Spell effects on or off")
BINDING_NAME_SURVIVORUI_SOUNDEFFECTS = SurvivorUI_T("Sound effects on or off")
BINDING_NAME_SURVIVORUI_RANGERING = SurvivorUI_T("Range ring on or off")

function SurvivorUI_ToggleSpellEffects()
	KeyFlip(effectsSwitch)
end

function SurvivorUI_ToggleSoundEffects()
	KeyFlip(soundSwitch)
end

function SurvivorUI_ToggleRangeRing()
	KeyFlip(rangeSwitch)
end

------------------------------------------------------------------------------
-- The Guide's (Guide.lua): the same square, filled in gold with a dark mark,
-- so it stands apart from the class's colors around it: a ! that breathes
-- while a page is unread, a ? once all are read. Off, or in another color, in
-- the options' Minimap buttons tab.

local guideButton = CreateFrame("Button", "SurvivorUIGuideButton", Minimap or UIParent)
guideButton:SetFrameStrata("MEDIUM")
guideButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 5)
guideButton.icon = guideButton:CreateTexture(nil, "ARTWORK")
guideButton.icon:SetTexture(FLAT)
guideButton.ownIcon = guideButton.icon
Square(guideButton, guideButton.icon)
stack.guide = { frame = guideButton, option = "guideMapButton", color = "gold", title = "Guide" }
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
	GameTooltip:SetText(SurvivorUI_T("Guide"), this.tint[1], this.tint[2], this.tint[3])
	GameTooltip:AddLine(SurvivorUI_T("How Luck, Damage and Crit really work."), 1, 1, 1)
	if SurvivorUI_GuideUnread and SurvivorUI_GuideUnread() then
		GameTooltip:AddLine(SurvivorUI_T("Something new to read!"), this.tint[1], this.tint[2], this.tint[3])
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
		Beside(hint, guideButton)
		hint.age = 0
		hint:SetAlpha(0)
		hint:Show()
	end
end)

------------------------------------------------------------------------------
-- The game's battleground button: square, beside ours. The stock code shows it
-- and hides it as queues come and go; only its look and place change: after
-- the last of ours, a gap on (last nil: in the first one's place).

local function RestyleBattlefield(last)
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
	local way = WAYS[Way()]
	frame:ClearAllPoints()
	if last then
		frame:SetPoint(way[3], last, way[4], way[1] * Gap(), way[2] * Gap())
	else
		frame:SetPoint(way[3], holder, way[3], 0, 0)
	end
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

-- Each one in its color: ours and Run History's icons, the switches' (dimmed
-- while off), the Guide's square.
local function PaintButtons()
	for key, entry in pairs(stack) do
		local frame = entry.frame
		frame.tint = frame.tint or {}
		frame.tint[1], frame.tint[2], frame.tint[3] = Tint(key)
		if frame.read then
			PaintSwitch(frame)
		else
			frame.icon:SetVertexColor(frame.tint[1], frame.tint[2], frame.tint[3])
		end
	end
end

-- The line laid out again: the ones shown, in their order, from the holder's
-- first side on, each at its size; the holder sized to them; the
-- battleground's after the last. For the options' Minimap buttons tab too.
function SurvivorUI_PlaceMapButtons()
	local way = WAYS[Way()]
	local size, gap = Size(), Gap()
	local order = Order()
	local count, last = 0, nil
	for index = 1, table.getn(order) do
		local frame = stack[order[index]].frame
		if Shown(order[index]) then
			Square(frame, frame.ownIcon)
			frame:ClearAllPoints()
			frame:SetPoint(way[3], holder, way[3], way[1] * count * (size + gap), way[2] * count * (size + gap))
			frame:Show()
			count = count + 1
			last = frame
		else
			frame:Hide()
		end
	end
	local length = math.max(1, count) * (size + gap) - gap
	holder:SetWidth(way[1] ~= 0 and length or size)
	holder:SetHeight(way[2] ~= 0 and length or size)
	PlaceHolder()
	guideButton.mark:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, math.floor(13 * size / 16 + 0.5)))
	PaintButtons()
	SurvivorUI_PaintGuideButton()
	RestyleBattlefield(last)
end

-- For the options' tab: the keys in their order, and each one as it stands
-- (its name, its icon or the Guide's mark, dimmed while off, shown, its
-- color's key and r, g, b, the key that flips it).
function SurvivorUI_MapButtonOrder()
	return Order()
end

function SurvivorUI_MapButtonInfo(key)
	local entry = stack[key]
	if not entry then
		return nil
	end
	local frame = entry.frame
	local r, g, b = Tint(key)
	local info = { title = entry.title, icon = frame.iconPath, dim = 1, shown = Shown(key), color = ColorKey(key),
		r = r, g = g, b = b, binding = entry.binding }
	if frame.read and not frame.read() then
		info.dim = 0.55
	end
	if key == "guide" then
		info.mark = guideButton.mark:GetText() or "?"
	end
	return info
end

-- One a step toward the first (-1) or the last (1).
function SurvivorUI_MoveMapButton(key, by)
	local order = Order()
	for index = 1, table.getn(order) do
		if order[index] == key then
			local other = index + by
			if order[other] then
				order[index], order[other] = order[other], order[index]
			end
			break
		end
	end
	local first = true
	for index = 1, table.getn(ORDER) do
		first = first and order[index] == ORDER[index]
	end
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.mapButtonOrder = not first and order or nil
	SurvivorUI_PlaceMapButtons()
end

function SurvivorUI_ShowMapButton(key)
	local entry = stack[key]
	if entry then
		SurvivorUIDB = SurvivorUIDB or {}
		if Shown(key) then
			SurvivorUIDB[entry.option] = false
		else
			SurvivorUIDB[entry.option] = nil
		end
		SurvivorUI_PlaceMapButtons()
	end
end

-- One's color, or all of them (key nil), by its key in the colors above.
function SurvivorUI_SetMapButtonColor(key, color)
	SurvivorUIDB = SurvivorUIDB or {}
	local colors = SurvivorUIDB.mapButtonColors or {}
	for each, entry in pairs(stack) do
		if not key or each == key then
			colors[each] = color ~= (entry.color or "class") and color or nil
		end
	end
	SurvivorUIDB.mapButtonColors = next(colors) and colors or nil
	SurvivorUI_PlaceMapButtons()
end

-- All of them back as they came: shown, in their first order and colors, up,
-- at the first size and gap. Their place stays (Back to its place for that).
function SurvivorUI_ResetMapButtons()
	SurvivorUIDB = SurvivorUIDB or {}
	local db = SurvivorUIDB
	for _, entry in pairs(stack) do
		db[entry.option] = nil
	end
	db.mapButtonOrder, db.mapButtonColors, db.mapButtonWay, db.mapButtonSize, db.mapButtonGap = nil, nil, nil, nil, nil
	SurvivorUI_PlaceMapButtons()
end

if SurvivorUI_OnAccent then
	SurvivorUI_OnAccent(PaintButtons)
end
SurvivorUI_PlaceMapButtons()

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
loader:SetScript("OnEvent", SurvivorUI_PlaceMapButtons)

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
		math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), SurvivorUI_T(RESULT_WORDS[kind])))
	notice:SetWidth(math.max(notice.title:GetStringWidth() + 24, notice.line:GetStringWidth() + 16))
	-- Beside Run History's button, apart from the line they make.
	Beside(notice, NoteAnchor())
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
