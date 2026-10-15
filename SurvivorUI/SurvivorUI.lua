-- Survivor UI: unit frames and an action bar for Azeroth Survivors, in the
-- flat, dark manner of EllesmereUI. Everything sits in one centered row at the
-- bottom of the screen:
--
--   [portrait][ player ]  [1][2][3][4][5][6][=]  [ target ][portrait]
--
--   Unit frames: a health bar in the class color (red for an enemy) on a dark
--   backing with a thin black border, the name on the left, the health on the
--   right ("439K | 100%"), a slim power bar underneath and the portrait on the
--   outer end. The target's debuffs line up above its frame. They replace the
--   stock player and target frames.
--
--   Action bar: the game only uses the first bar. Buttons 1 to 6 and the last
--   button (the = key) make the middle of the row; the rest of the bar and its
--   art are put away. The experience bar becomes a thin strip under the row.
--
--   Also: the hero's buffs and debuffs above the player frame with time left
--   and stacks, cooldown numbers on the buttons, a square minimap, a flat
--   chat panel scrolled with the mouse wheel, and the micro buttons in the
--   bottom right corner, shown when the mouse reaches them.
--
--   Friz Quadrata on every piece of interface text, a flat tooltip, and small
--   quick damage numbers in place of the engine's (/sui damage switches back).
--
-- The row sits a little under the hero, who stands in the middle of the screen.
--
-- Left click a frame to target it, right click for its menu. Alt-drag either
-- frame to move the whole row.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
-- The interface's face, shared with the addon's other files. Barlow Condensed
-- comes with the addon (Media, SIL Open Font License). A player's own
-- Expressway, dropped in SurvivorUI\Fonts, wins over it; it may not be shipped.
-- A face that does not load leaves a font string without one, so each is tried
-- on a probe first, and Friz Quadrata, the game's own, is the last resort.
local FACES = {
	{ path = "Interface\\AddOns\\SurvivorUI\\Fonts\\Expressway.ttf", mark = "expressway" },
	{ path = "Interface\\AddOns\\SurvivorUI\\Media\\BarlowCondensed-Medium.ttf", mark = "barlow", bump = 1 },
}

local function FaceLoads(face)
	local probe = UIParent:CreateFontString(nil, "OVERLAY")
	probe:SetFont(face.path, 12)
	local got = probe:GetFont()
	return got and string.find(string.lower(got), face.mark, 1, true) ~= nil
end

SurvivorUI_FONT = "Fonts\\FRIZQT__.TTF"
SurvivorUI_FONT_BUMP = 0
for index = 1, table.getn(FACES) do
	if FaceLoads(FACES[index]) then
		SurvivorUI_FONT = FACES[index].path
		-- Barlow Condensed reads small at the same size: one point up.
		SurvivorUI_FONT_BUMP = FACES[index].bump or 0
		break
	end
end
local FONT = SurvivorUI_FONT
local FONT_BUMP = SurvivorUI_FONT_BUMP

local BAR_BUTTONS = { 1, 2, 3, 4, 5, 6, 12 }     -- 12 is the = key
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local ROW_BELOW_CENTER = 150                    -- the row sits this far under the hero, who stands mid-screen
local SECTION_GAP = 6                           -- between a unit frame and the buttons

local FRAME_WIDTH = 150                         -- the bar part of a unit frame
local POWER_HEIGHT = 3
local HEALTH_HEIGHT = BUTTON_SIZE - POWER_HEIGHT - 1

local ENEMY = { 0.80, 0.22, 0.22 }

local CHAT_SIZE = 12                            -- default; /sui chat N changes it

-- Saved between sessions; the /sui command at the end of the file changes them.
local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.damageText == nil then
		SurvivorUIDB.damageText = true
	end
	SurvivorUIDB.chatSize = SurvivorUIDB.chatSize or CHAT_SIZE
	return SurvivorUIDB
end

-- 1.12 paints shamans in the paladin's pink; they wear their modern blue here.
local CLASS_OVERRIDES = {
	SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
}

local POWER_COLORS = {
	[0] = { 0.25, 0.50, 1.00 },   -- mana
	[1] = { 0.85, 0.20, 0.20 },   -- rage
	[2] = { 1.00, 0.55, 0.15 },   -- focus
	[3] = { 1.00, 0.90, 0.25 },   -- energy
}

------------------------------------------------------------------------------
-- Pieces

-- A thin black border: a flat texture one pixel larger than the frame.
local function AddBorder(frame)
	local border = frame:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(FLAT)
	border:SetVertexColor(0, 0, 0, 1)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	return border
end

local function AddBacking(frame, layer)
	local backing = frame:CreateTexture(nil, layer or "BORDER")
	backing:SetTexture(FLAT)
	backing:SetVertexColor(0.09, 0.09, 0.11, 1)
	backing:SetAllPoints(frame)
	return backing
end

local function FlatBar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)
	AddBorder(bar)
	AddBacking(bar)
	return bar
end

local function Text(parent, size, point, x, y)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, parent, point, x, y)
	return text
end

local function Hide(name)
	local object = getglobal(name)
	if object then
		object:Hide()
	end
end

-- 439K, 1.2M
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return math.floor(value / 1000 + 0.5).."K"
	end
	return value
end

------------------------------------------------------------------------------
-- The row: the buttons' holder is the anchor everything else hangs from.

local row = CreateFrame("Frame", "SurvivorUIRow", UIParent)
row:SetWidth(table.getn(BAR_BUTTONS) * (BUTTON_SIZE + BUTTON_GAP) - BUTTON_GAP)
row:SetHeight(BUTTON_SIZE)
row:SetPoint("CENTER", UIParent, "CENTER", 0, -ROW_BELOW_CENTER)
row:SetMovable(true)
row:SetFrameStrata("LOW")

-- A dark, bordered slot behind every button, so an empty one still reads as a
-- slot. These are frames of the row, not textures of the buttons: a texture
-- added to a button's own background layer draws over its icon.
for position = 1, table.getn(BAR_BUTTONS) do
	local slot = CreateFrame("Frame", nil, row)
	slot:SetWidth(BUTTON_SIZE)
	slot:SetHeight(BUTTON_SIZE)
	slot:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
	AddBorder(slot)
	AddBacking(slot)
end

------------------------------------------------------------------------------
-- Unit frames

local function HealthColor(unit)
	-- Players wear their class color; everything else on the field is an enemy.
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = class and (CLASS_OVERRIDES[class] or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
		if color then
			return color.r, color.g, color.b
		end
		return 0.6, 0.6, 0.6
	end
	return ENEMY[1], ENEMY[2], ENEMY[3]
end

-- side: "LEFT" puts the frame left of the buttons with its portrait on the far
-- left; "RIGHT" mirrors it.
local function UnitFrame(unit, name, side, dropdown)
	local left = side == "LEFT"

	local frame = CreateFrame("Button", name, UIParent)
	frame:SetWidth(FRAME_WIDTH + 1 + BUTTON_SIZE)
	frame:SetHeight(BUTTON_SIZE)
	if left then
		frame:SetPoint("RIGHT", row, "LEFT", -SECTION_GAP, 0)
	else
		frame:SetPoint("LEFT", row, "RIGHT", SECTION_GAP, 0)
	end
	frame.unit = unit

	frame.portrait = CreateFrame("Frame", nil, frame)
	frame.portrait:SetWidth(BUTTON_SIZE)
	frame.portrait:SetHeight(BUTTON_SIZE)
	frame.portrait:SetPoint(left and "LEFT" or "RIGHT", frame, left and "LEFT" or "RIGHT", 0, 0)
	AddBorder(frame.portrait)
	AddBacking(frame.portrait)
	frame.portrait.texture = frame.portrait:CreateTexture(nil, "ARTWORK")
	frame.portrait.texture:SetAllPoints(frame.portrait)
	-- The stock portrait is a disc; cropped in, it fills the square.
	frame.portrait.texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)

	frame.health = FlatBar(frame, FRAME_WIDTH, HEALTH_HEIGHT)
	frame.health:SetPoint(left and "TOPRIGHT" or "TOPLEFT", frame, left and "TOPRIGHT" or "TOPLEFT", 0, 0)

	frame.power = FlatBar(frame, FRAME_WIDTH, POWER_HEIGHT)
	frame.power:SetPoint("TOP", frame.health, "BOTTOM", 0, -1)

	frame.name = Text(frame.health, 10, "LEFT", 5, 0)
	frame.name:SetWidth(FRAME_WIDTH - 82)
	frame.name:SetHeight(12)
	frame.name:SetJustifyH("LEFT")
	frame.name:SetTextColor(1, 1, 1)

	frame.value = Text(frame.health, 10, "RIGHT", -5, 0)
	frame.value:SetTextColor(1, 1, 1)

	-- Left click targets, right click opens the stock menu, Alt-drag moves the row.
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:SetScript("OnClick", function()
		if arg1 == "RightButton" and dropdown and getglobal(dropdown) then
			ToggleDropDownMenu(1, nil, getglobal(dropdown), "cursor")
		else
			TargetUnit(this.unit)
		end
	end)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() if IsAltKeyDown() then row:StartMoving() end end)
	frame:SetScript("OnDragStop", function() row:StopMovingOrSizing() end)
	return frame
end

local function UpdatePortrait(frame)
	if UnitExists(frame.unit) then
		SetPortraitTexture(frame.portrait.texture, frame.unit)
	end
end

local function UpdateUnitFrame(frame)
	local unit = frame.unit
	if not UnitExists(unit) then
		frame:Hide()
		return
	end
	frame:Show()

	local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
	local share = healthMax > 0 and health / healthMax or 0
	local percent = math.floor(share * 100 + 0.5)
	local r, g, b = HealthColor(unit)
	frame.health:SetValue(share)
	frame.health:SetStatusBarColor(r, g, b, 1)
	frame.name:SetText(UnitName(unit))

	if UnitIsDead(unit) or UnitIsGhost(unit) then
		frame.value:SetText("Dead")
	elseif unit ~= "player" then
		-- An enemy's frame keeps to the percentage; its nameplate has the numbers.
		frame.value:SetText(percent.."%")
	else
		frame.value:SetText(Short(health).." | "..percent.."%")
	end

	local power, powerMax = UnitMana(unit), UnitManaMax(unit)
	if powerMax > 0 then
		local color = POWER_COLORS[UnitPowerType(unit)] or POWER_COLORS[0]
		frame.power:SetValue(power / powerMax)
		frame.power:SetStatusBarColor(color[1], color[2], color[3], 1)
	else
		frame.power:SetValue(0)
	end
end

local player = UnitFrame("player", "SurvivorUIPlayer", "LEFT", "PlayerFrameDropDown")
local target = UnitFrame("target", "SurvivorUITarget", "RIGHT", "TargetFrameDropDown")

-- The target's debuffs, in a row above its frame.
local DEBUFFS = 8
local debuffs = {}
for index = 1, DEBUFFS do
	local icon = CreateFrame("Frame", nil, target)
	icon:SetWidth(18)
	icon:SetHeight(18)
	icon:SetPoint("BOTTOMLEFT", target, "TOPLEFT", (index - 1) * 21, 4)
	AddBorder(icon)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	icon.count = Text(icon, 9, "BOTTOMRIGHT", -1, 1)
	icon:Hide()
	debuffs[index] = icon
end

local function UpdateDebuffs()
	for index = 1, DEBUFFS do
		local texture, count = UnitDebuff("target", index)
		local icon = debuffs[index]
		if texture then
			icon.texture:SetTexture(texture)
			icon.count:SetText(count and count > 1 and count or "")
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local elapsed = 0
local unitUpdater = CreateFrame("Frame")
unitUpdater:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	UpdateUnitFrame(player)
	UpdateUnitFrame(target)
	if UnitExists("target") then
		UpdateDebuffs()
	end
end)

local function HideStockUnitFrames()
	for _, name in pairs({ "PlayerFrame", "TargetFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:UnregisterAllEvents()
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Action bar

-- Flat look: no rounded slot art and a cropped icon; the row's slot behind it
-- supplies the border.
local function StyleButton(button)
	local name = button:GetName()
	if not name then
		return
	end

	local normal = getglobal(name.."NormalTexture")
	if normal then
		normal:SetAlpha(0)
	end

	local icon = getglobal(name.."Icon")
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	if not button.survivorStyled then
		button.survivorStyled = true

		local hotkey = getglobal(name.."HotKey")
		if hotkey then
			hotkey:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
			hotkey:ClearAllPoints()
			hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -2)
		end
	end
end

-- The stock update puts the rounded slot art back; take it off again each time.
local stockActionButtonUpdate = ActionButton_Update
if stockActionButtonUpdate then
	ActionButton_Update = function()
		stockActionButtonUpdate()
		if this and this.survivorKept then
			StyleButton(this)
		end
	end
end

local function PlaceButton(prefix, id, position)
	local button = getglobal(prefix..id)
	if not button then
		return
	end

	button:ClearAllPoints()
	if position then
		button:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
		button.survivorKept = true
		StyleButton(button)
	else
		-- Off screen rather than hidden: the stock code shows buttons on its own.
		button:SetPoint("TOP", UIParent, "BOTTOM", 0, -600)
	end
end

local function LayoutBar()
	local positions = {}
	for position = 1, table.getn(BAR_BUTTONS) do
		positions[BAR_BUTTONS[position]] = position
	end

	-- A stance bar's buttons, when a class has one, sit where the main bar's do.
	for id = 1, 12 do
		PlaceButton("ActionButton", id, positions[id])
		PlaceButton("BonusActionButton", id, positions[id])
	end

	for _, name in pairs({
		"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
		"MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
		"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber",
		"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
		"KeyRingButton", "MainMenuBarPerformanceBarFrame",
		"BonusActionBarTexture0", "BonusActionBarTexture1",
		"MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3",
		"ExhaustionTick",
	}) do
		Hide(name)
	end

	-- The experience bar: a thin flat strip under the whole row.
	local xp = getglobal("MainMenuExpBar")
	if xp then
		xp:ClearAllPoints()
		xp:SetPoint("TOP", row, "BOTTOM", 0, -5)
		xp:SetWidth(row:GetWidth() + 2 * (SECTION_GAP + FRAME_WIDTH + 1 + BUTTON_SIZE))
		xp:SetHeight(4)
		xp:SetStatusBarTexture(FLAT)
		if not xp.survivorBorder then
			xp.survivorBorder = AddBorder(xp)
			xp.survivorBack = AddBacking(xp)
		end
	end
end

------------------------------------------------------------------------------
-- The hero's buffs and debuffs, in a row above the player frame, each with
-- its time left and its stacks. Right click a buff to cancel it.

local AURA_SIZE = 22
local AURA_MAX = 12

local function TimeText(seconds)
	if seconds >= 3600 then
		return math.floor(seconds / 3600 + 0.5).."h"
	elseif seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return math.floor(seconds)
	end
	return string.format("%.1f", seconds)
end

local auras = {}
for index = 1, AURA_MAX do
	local aura = CreateFrame("Button", nil, player)
	aura:SetWidth(AURA_SIZE)
	aura:SetHeight(AURA_SIZE)
	aura:SetPoint("BOTTOMLEFT", player, "TOPLEFT", (index - 1) * (AURA_SIZE + 3), 5)
	aura.border = AddBorder(aura)

	aura.texture = aura:CreateTexture(nil, "ARTWORK")
	aura.texture:SetAllPoints(aura)
	aura.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	aura.time = Text(aura, 10, "CENTER", 0, 0)
	aura.time:SetTextColor(1, 0.95, 0.6)
	aura.count = Text(aura, 9, "BOTTOMRIGHT", -1, 1)

	aura:RegisterForClicks("RightButtonUp")
	aura:SetScript("OnClick", function() if this.helpful then CancelPlayerBuff(this.buffIndex) end end)
	aura:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetPlayerBuff(this.buffIndex)
	end)
	aura:SetScript("OnLeave", function() GameTooltip:Hide() end)
	aura:Hide()
	auras[index] = aura
end

local function UpdateAuras()
	local shown = 0
	for pass = 1, 2 do
		local filter = pass == 1 and "HELPFUL" or "HARMFUL"
		for slot = 0, 15 do
			local buffIndex = GetPlayerBuff(slot, filter)
			if buffIndex and buffIndex >= 0 and shown < AURA_MAX then
				shown = shown + 1
				local aura = auras[shown]
				aura.buffIndex = buffIndex
				aura.helpful = pass == 1
				aura.texture:SetTexture(GetPlayerBuffTexture(buffIndex))

				-- A debuff wears a red border.
				if pass == 1 then
					aura.border:SetVertexColor(0, 0, 0, 1)
				else
					aura.border:SetVertexColor(0.85, 0.10, 0.10, 1)
				end

				local left = GetPlayerBuffTimeLeft(buffIndex)
				aura.time:SetText(left and left > 0 and TimeText(left) or "")

				local count = GetPlayerBuffApplications(buffIndex)
				aura.count:SetText(count and count > 1 and count or "")
				aura:Show()
			end
		end
	end
	for index = shown + 1, AURA_MAX do
		auras[index]:Hide()
	end
end

local auraElapsed = 0
local auraUpdater = CreateFrame("Frame")
auraUpdater:SetScript("OnUpdate", function()
	auraElapsed = auraElapsed + arg1
	if auraElapsed >= 0.1 then
		auraElapsed = 0
		UpdateAuras()
	end
end)

local function HideStockBuffs()
	for _, name in pairs({ "BuffFrame", "TemporaryEnchantFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Cooldown numbers on the action buttons. OmniCC does the same job; with it
-- installed, this stands aside.

if CooldownFrame_SetTimer and not OmniCC_OnUpdate then
	local stockSetTimer = CooldownFrame_SetTimer

	local function CounterUpdate()
		local left = this.start + this.duration - GetTime()
		if left <= 0 then
			this:Hide()
			return
		end
		this.text:SetText(TimeText(left))
	end

	CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
		stockSetTimer(cooldown, start, duration, enable)

		local parent = cooldown and cooldown:GetParent()
		if not parent then
			return
		end

		local counter = parent.survivorCounter
		if not counter then
			counter = CreateFrame("Frame", nil, parent)
			counter:SetAllPoints(parent)
			counter:SetFrameLevel(cooldown:GetFrameLevel() + 3)
			counter.text = Text(counter, 14, "CENTER", 0, 0)
			counter.text:SetTextColor(1, 0.95, 0.6)
			counter:SetScript("OnUpdate", CounterUpdate)
			parent.survivorCounter = counter
		end

		-- The global cooldown's flicker is not worth a number.
		if start and start > 0 and duration and duration > 1.5 and enable and enable > 0 then
			counter.start, counter.duration = start, duration
			counter:Show()
		else
			counter:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- A square minimap with a thin border, zoomed with the mouse wheel.

local function SquareMinimap()
	if not Minimap then
		return
	end

	-- A solid texture as the mask leaves the whole square visible.
	Minimap:SetMaskTexture(FLAT)

	for _, name in pairs({
		"MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
		"MinimapToggleButton", "GameTimeFrame", "MiniMapWorldMapButton",
	}) do
		Hide(name)
	end

	if not Minimap.survivorBorder then
		local edge = CreateFrame("Frame", nil, Minimap)
		edge:SetAllPoints(Minimap)
		edge:SetFrameLevel(Minimap:GetFrameLevel() + 2)
		for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local line = edge:CreateTexture(nil, "OVERLAY")
			line:SetTexture(FLAT)
			line:SetVertexColor(0, 0, 0, 1)
			if side == "TOP" or side == "BOTTOM" then
				line:SetHeight(1)
				line:SetPoint(side.."LEFT", edge, side.."LEFT", -1, side == "TOP" and 1 or -1)
				line:SetPoint(side.."RIGHT", edge, side.."RIGHT", 1, side == "TOP" and 1 or -1)
			else
				line:SetWidth(1)
				line:SetPoint("TOP"..side, edge, "TOP"..side, side == "LEFT" and -1 or 1, 1)
				line:SetPoint("BOTTOM"..side, edge, "BOTTOM"..side, side == "LEFT" and -1 or 1, -1)
			end
		end
		Minimap.survivorBorder = edge

		Minimap:EnableMouseWheel(true)
		Minimap:SetScript("OnMouseWheel", function()
			if arg1 > 0 then
				Minimap:SetZoom(math.min(Minimap:GetZoomLevels() - 1, Minimap:GetZoom() + 1))
			else
				Minimap:SetZoom(math.max(0, Minimap:GetZoom() - 1))
			end
		end)
	end
end

------------------------------------------------------------------------------
-- The micro buttons (character, talents, map, menu, help) go to the bottom
-- right corner. The others are chained to the first, so moving it moves all.

local function MoveMicroButtons()
	local first = getglobal("CharacterMicroButton")
	if first then
		first:ClearAllPoints()
		first:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", -140, 2)
	end
end

------------------------------------------------------------------------------
-- The micro buttons stay out of sight until the mouse reaches their corner.

local MICRO_BUTTONS = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
	"SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton",
}

local microZone = CreateFrame("Frame", "SurvivorUIMicroZone", UIParent)
microZone:SetWidth(170)
microZone:SetHeight(60)
microZone:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)

local microAlpha = 0
microZone:SetScript("OnUpdate", function()
	local want = MouseIsOver(this) and 1 or 0
	if microAlpha == want then
		return
	end

	-- A quick fade either way.
	local step = arg1 * 6
	if want > microAlpha then
		microAlpha = math.min(1, microAlpha + step)
	else
		microAlpha = math.max(0, microAlpha - step)
	end
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(microAlpha)
		end
	end
end)

local function HideMicroButtons()
	microAlpha = 0
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(0)
		end
	end
end

------------------------------------------------------------------------------
-- Chat: a flat dark panel, no scroll buttons, no tab art. The mouse wheel
-- scrolls; with Shift held it jumps to the top or the bottom.

local function ChatWheel()
	if arg1 > 0 then
		if IsShiftKeyDown() then
			this:ScrollToTop()
		else
			this:ScrollUp()
		end
	else
		if IsShiftKeyDown() then
			this:ScrollToBottom()
		else
			this:ScrollDown()
		end
	end
end

local function StyleChat()
	Hide("ChatFrameMenuButton")

	for index = 1, 7 do
		local name = "ChatFrame"..index
		local chat = getglobal(name)
		if chat then
			Hide(name.."UpButton")
			Hide(name.."DownButton")
			Hide(name.."BottomButton")

			-- Plain text with a soft shadow in place of the stock look.
			chat:SetFont(FONT, Settings().chatSize)
			chat:SetShadowColor(0, 0, 0, 1)
			chat:SetShadowOffset(1, -1)

			chat:EnableMouseWheel(true)
			chat:SetScript("OnMouseWheel", ChatWheel)

			if not chat.survivorPanel then
				local panel = CreateFrame("Frame", nil, chat)
				panel:SetPoint("TOPLEFT", chat, "TOPLEFT", -6, 6)
				panel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 6, -6)
				panel:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
				local fill = panel:CreateTexture(nil, "BACKGROUND")
				fill:SetTexture(FLAT)
				fill:SetVertexColor(0.04, 0.04, 0.06, 0.55)
				fill:SetAllPoints(panel)
				-- An accent line down the left edge.
				local accent = panel:CreateTexture(nil, "BORDER")
				accent:SetTexture(FLAT)
				accent:SetVertexColor(1, 0.82, 0, 0.8)
				accent:SetWidth(2)
				accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
				accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
				chat.survivorPanel = panel
			end

			-- The tab keeps its text and loses its art.
			for _, piece in pairs({ "Left", "Middle", "Right" }) do
				local art = getglobal(name.."Tab"..piece)
				if art then
					art:SetTexture("")
				end
			end
			local tabText = getglobal(name.."TabText")
			if tabText then
				tabText:SetFont(FONT, 11 + FONT_BUMP, "OUTLINE")
			end
		end
	end

	-- The edit box: a flat field under the chat.
	local edit = getglobal("ChatFrameEditBox")
	if edit then
		for _, piece in pairs({ "Left", "Mid", "Right" }) do
			local art = getglobal("ChatFrameEditBox"..piece)
			if art then
				art:SetTexture("")
			end
		end
		if not edit.survivorBack then
			edit.survivorBack = edit:CreateTexture(nil, "BACKGROUND")
			edit.survivorBack:SetTexture(FLAT)
			edit.survivorBack:SetVertexColor(0.04, 0.04, 0.06, 0.8)
			edit.survivorBack:SetPoint("TOPLEFT", edit, "TOPLEFT", 4, -5)
			edit.survivorBack:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -4, 5)
		end
	end
end

------------------------------------------------------------------------------
-- One face everywhere (SurvivorUI_FONT). The stock interface mixes several:
-- Friz Quadrata for most things, others for chat, numbers, quest and mail text.

-- Read by the engine when the world loads, for the text it draws itself.
STANDARD_TEXT_FONT = FONT
UNIT_NAME_FONT = FONT
NAMEPLATE_FONT = FONT
DAMAGE_TEXT_FONT = FONT

local FONT_OBJECTS = {
	"GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontGreen", "GameFontRed", "GameFontBlack", "GameFontWhite",
	"GameFontNormalSmall", "GameFontHighlightSmall", "GameFontHighlightSmallOutline", "GameFontDisableSmall",
	"GameFontDarkGraySmall", "GameFontGreenSmall", "GameFontRedSmall",
	"GameFontNormalLarge", "GameFontHighlightLarge", "GameFontDisableLarge", "GameFontGreenLarge", "GameFontRedLarge",
	"GameFontNormalHuge",
	"NumberFontNormal", "NumberFontNormalYellow", "NumberFontNormalSmall", "NumberFontNormalSmallGray",
	"NumberFontNormalLarge", "NumberFontNormalHuge",
	"ChatFontNormal", "ChatFontSmall", "CombatLogFont",
	"QuestTitleFont", "QuestFont", "QuestFontNormalSmall", "QuestFontHighlight",
	"ItemTextFontNormal", "MailTextFontNormal", "InvoiceTextFontNormal", "InvoiceTextFontSmall",
	"SubSpellFont", "DialogButtonNormalText", "DialogButtonHighlightText",
	"ZoneTextFont", "SubZoneTextFont", "PVPInfoTextFont", "ErrorFont", "WorldMapTextFont",
	"TextStatusBarText", "TextStatusBarTextSmall",
	"GameTooltipText", "GameTooltipTextSmall", "GameTooltipHeaderText",
}

local function ApplyFonts()
	for _, name in pairs(FONT_OBJECTS) do
		local object = getglobal(name)
		if object and object.GetFont and object.SetFont then
			-- The stock size is kept on the first pass, so the bump is not added twice.
			if not object.survivorSize then
				local _, size, flags = object:GetFont()
				object.survivorSize, object.survivorFlags = size, flags
			end
			local size = object.survivorSize
			if size and size > 0 then
				object:SetFont(FONT, size + FONT_BUMP, object.survivorFlags)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Tooltip: a flat dark box with a hairline border, a slim health bar along its
-- bottom edge, and smaller type.

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "WorldMapTooltip" }

local TOOLTIP_BACKDROP = {
	bgFile = FLAT, edgeFile = FLAT,
	tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function PaintTooltip(tooltip)
	tooltip:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
	tooltip:SetBackdropBorderColor(0, 0, 0, 1)
end

local function StyleTooltips()
	-- The stock code repaints a tooltip from these two.
	TOOLTIP_DEFAULT_COLOR = { r = 0, g = 0, b = 0 }
	TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.05, b = 0.07 }

	for _, name in pairs(TOOLTIPS) do
		local tooltip = getglobal(name)
		if tooltip and not tooltip.survivorStyled then
			tooltip.survivorStyled = true
			tooltip:SetBackdrop(TOOLTIP_BACKDROP)
			PaintTooltip(tooltip)

			local stockShow = tooltip:GetScript("OnShow")
			tooltip:SetScript("OnShow", function()
				if stockShow then
					stockShow()
				end
				PaintTooltip(this)
			end)
		end
	end

	local header = getglobal("GameTooltipHeaderText")
	if header then
		header:SetFont(FONT, 13 + FONT_BUMP)
	end
	local body = getglobal("GameTooltipText")
	if body then
		body:SetFont(FONT, 11 + FONT_BUMP)
	end
	local small = getglobal("GameTooltipTextSmall")
	if small then
		small:SetFont(FONT, 10 + FONT_BUMP)
	end

	local bar = getglobal("GameTooltipStatusBar")
	if bar and GameTooltip then
		bar:SetStatusBarTexture(FLAT)
		bar:SetHeight(4)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 1, 1)
		bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -1, 1)
	end
end

------------------------------------------------------------------------------
-- Damage numbers: small, quick, and gone. A number pops over the enemy it hit,
-- shoots up and fades within half a second; a critical strike is larger and
-- gold. They replace the engine's own floating numbers while switched on
-- (/sui damage switches back and forth).
--
-- The addon reads hits from the combat log, which names the enemy but not
-- which one of several with that name. The number goes over one of them.

local DAMAGE_LIFE = 0.55        -- seconds on screen
local DAMAGE_RISE = 62          -- how far a number climbs
local DAMAGE_MAX = 48           -- numbers alive at once
local CRIT_SIZE = 22            -- a critical strike's number; a normal one is 14
local CRIT_POP_SIZE = 30        -- its size for the first instant
local CRIT_POP_TIME = 0.09

local damageLayer = CreateFrame("Frame", "SurvivorUIDamage", UIParent)
damageLayer:SetAllPoints(UIParent)
damageLayer:SetFrameStrata("HIGH")

local damageTexts = {}
local damageLive = 0

local function DamageText()
	for index = 1, table.getn(damageTexts) do
		if not damageTexts[index].live then
			return damageTexts[index]
		end
	end
	if table.getn(damageTexts) >= DAMAGE_MAX then
		return nil
	end
	local text = damageLayer:CreateFontString(nil, "OVERLAY")
	table.insert(damageTexts, text)
	return text
end

-- Every nameplate on screen showing this name. Survivor Plates blanks the art
-- a plate is recognized by, so its own list is used when it is installed.
local function PlatesNamed(name)
	local found = {}
	if SurvivorPlatesRegistry then
		for index = 1, table.getn(SurvivorPlatesRegistry) do
			local overlay = SurvivorPlatesRegistry[index]
			if overlay.plate:IsVisible() and overlay.stock.name:GetText() == name then
				table.insert(found, overlay.plate)
			end
		end
		return found
	end

	local children = { WorldFrame:GetChildren() }
	for index = 1, table.getn(children) do
		local plate = children[index]
		local border = plate:GetRegions()
		if plate:IsVisible() and border and border.GetTexture and border:GetObjectType() == "Texture"
			and border:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
			local regions = { plate:GetRegions() }
			for region = 1, table.getn(regions) do
				if regions[region]:GetObjectType() == "FontString" then
					if regions[region]:GetText() == name then
						table.insert(found, plate)
					end
					break
				end
			end
		end
	end
	return found
end

-- target is nil for a hit the hero took: that number rises over the hero, in red.
local function SpawnDamage(target, amount, crit, periodic)
	local text = DamageText()
	if not text then
		return
	end

	-- Over one of the enemies with that name, else in a ring around the hero.
	local x, y
	local plates = target and PlatesNamed(target) or {}
	local count = table.getn(plates)
	if not target then
		-- The camera keeps the hero in the middle of the screen.
		x = UIParent:GetWidth() / 2
		-- From the hero's feet down, ending short of the bar row (150 below).
		y = UIParent:GetHeight() / 2 - 15
	elseif count > 0 then
		local plate = plates[math.random(1, count)]
		local px, py = plate:GetCenter()
		if px and py then
			local ratio = 1
			if plate.GetEffectiveScale and UIParent.GetEffectiveScale then
				ratio = plate:GetEffectiveScale() / UIParent:GetEffectiveScale()
			end
			x, y = px * ratio, py * ratio - 10
		end
	end
	if not x then
		local angle = math.random() * 6.2832
		local reach = 90 + math.random() * 70
		x = UIParent:GetWidth() / 2 + math.cos(angle) * reach
		y = UIParent:GetHeight() / 2 + 30 + math.sin(angle) * reach * 0.6
	end

	if not target then
		text:SetFont(FONT, crit and CRIT_POP_SIZE or 14, crit and "THICKOUTLINE" or "OUTLINE")
		text:SetTextColor(1, 0.22, 0.22)
		amount = "-"..amount
	elseif crit then
		-- Lands oversized, then settles: see the update below.
		text:SetFont(FONT, CRIT_POP_SIZE, "THICKOUTLINE")
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		text:SetFont(FONT, 12 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(0.80, 0.80, 0.80)
	else
		text:SetFont(FONT, 14 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(amount)

	text.live = true
	text.crit = crit
	text.popped = nil
	text.life = crit and DAMAGE_LIFE * 1.3 or DAMAGE_LIFE
	text.age = 0
	text.x = x + (math.random() - 0.5) * 24
	text.y = y
	text.drift = (math.random() - 0.5) * 30
	text.rise = crit and DAMAGE_RISE * 1.3 or DAMAGE_RISE
	if not target then
		-- A hit the hero took falls instead, apart from the ones it deals.
		text.rise = -text.rise
	end
	text:SetAlpha(1)
	text:Show()
	damageLive = damageLive + 1
end

damageLayer:SetScript("OnUpdate", function()
	if damageLive == 0 then
		return
	end

	for index = 1, table.getn(damageTexts) do
		local text = damageTexts[index]
		if text.live then
			text.age = text.age + arg1
			local t = text.age / text.life
			if text.crit and not text.popped and text.age >= CRIT_POP_TIME then
				text.popped = true
				text:SetFont(FONT, CRIT_SIZE, "THICKOUTLINE")
			end
			if t >= 1 then
				text.live = nil
				text:Hide()
				damageLive = damageLive - 1
			else
				-- Fast at first, slowing as it tops out; fading over the last third.
				local eased = 1 - (1 - t) * (1 - t)
				text:ClearAllPoints()
				text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", text.x + text.drift * eased, text.y + text.rise * eased)
				text:SetAlpha(t > 0.66 and (1 - t) / 0.34 or 1)
			end
		end
	end
end)

local function ParseDamage(message)
	local _, _, target, amount = string.find(message, " crits (.+) for (%d+)")
	if target then
		return target, amount, true
	end
	_, _, target, amount = string.find(message, " crit (.+) for (%d+)")
	if target then
		return target, amount, true
	end
	_, _, target, amount = string.find(message, " hits (.+) for (%d+)")
	if target then
		return target, amount
	end
	_, _, target, amount = string.find(message, " hit (.+) for (%d+)")
	if target then
		return target, amount
	end
	-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
	_, _, target, amount = string.find(message, "^(.+) suffers (%d+) .+ from your ")
	if target then
		return target, amount, false, true
	end
end

-- The hits the hero takes come from the stock floating combat text's own feed.
local TAKEN_TYPES = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true }

local damageEvents = CreateFrame("Frame")
damageEvents:SetScript("OnEvent", function()
	if not Settings().damageText then
		return
	end
	if event == "COMBAT_TEXT_UPDATE" then
		if TAKEN_TYPES[arg1] and tonumber(arg2) then
			SpawnDamage(nil, arg2, arg1 == "DAMAGE_CRIT")
		end
		return
	end
	local target, amount, crit, periodic = ParseDamage(arg1 or "")
	if target then
		SpawnDamage(target, amount, crit, periodic)
	end
end)

local DAMAGE_EVENTS = {
	"CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_SPELL_PET_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "COMBAT_TEXT_UPDATE",
}

-- The stock floating combat text (Blizzard_CombatText, loaded on demand)
-- scrolls the hits the hero takes slowly, in its own face. While the quick
-- numbers are on, it leaves those to them; heals and the rest stay its own.
local function ApplyTakenText()
	if not COMBAT_TEXT_TYPE_INFO then
		return
	end
	-- "Health Low" in big letters over the fight says what the player frame
	-- already shows. Tied to a setting no one sets, so the stock refresh keeps
	-- it off.
	for _, kind in pairs({ "HEALTH_LOW", "MANA_LOW" }) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.var = "SURVIVORUI_NEVER"
			info.show = nil
		end
	end
	local on = Settings().damageText
	for kind in pairs(TAKEN_TYPES) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.show = not on and 1 or nil
		end
	end
end

local takenWatch = CreateFrame("Frame")
takenWatch:RegisterEvent("ADDON_LOADED")
takenWatch:SetScript("OnEvent", function()
	if arg1 == "Blizzard_CombatText" then
		ApplyTakenText()
	end
end)

-- The engine's numbers are on when the addon's are off, and the other way round.
local function ApplyDamageText()
	local on = Settings().damageText
	for _, event in pairs(DAMAGE_EVENTS) do
		if on then
			damageEvents:RegisterEvent(event)
		else
			damageEvents:UnregisterEvent(event)
		end
	end
	SetCVar("CombatDamage", on and "0" or "1")
	ApplyTakenText()
end

SLASH_SURVIVORUI1 = "/sui"
SlashCmdList["SURVIVORUI"] = function(msg)
	local _, _, command, argument = string.find(msg or "", "^(%S*)%s*(.*)$")
	if command == "chat" and tonumber(argument) then
		local settings = Settings()
		settings.chatSize = math.max(8, math.min(18, tonumber(argument)))
		StyleChat()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: chat text size "..settings.chatSize..".")
	elseif msg == "run" then
		if SurvivorUI_ToggleRun then
			SurvivorUI_ToggleRun()
		end
	elseif msg == "run reset" then
		if SurvivorUI_ResetRun then
			SurvivorUI_ResetRun()
		end
	elseif msg == "bosses" or msg == "bosses elites" then
		if SurvivorUI_BossBars then
			SurvivorUI_BossBars(argument)
		end
	elseif msg == "tracker" then
		if SurvivorUI_ToggleTracker then
			SurvivorUI_ToggleTracker()
		end
	elseif msg == "tally" then
		if SurvivorUI_Tally then
			SurvivorUI_Tally()
		end
	elseif msg == "meter" then
		if SurvivorUI_ToggleMeter then
			SurvivorUI_ToggleMeter()
		end
	elseif command == "scale" then
		if SurvivorUI_SetScale then
			SurvivorUI_SetScale(argument)
		end
	elseif msg == "layout" then
		if SurvivorUI_ResetLayout then
			SurvivorUI_ResetLayout()
		end
	elseif msg == "hover" then
		if SurvivorUI_ToggleHover then
			SurvivorUI_ToggleHover()
		end
	elseif msg == "center" then
		if SurvivorUI_CenterRow then
			SurvivorUI_CenterRow()
		end
	elseif msg == "damage" then
		local settings = Settings()
		settings.damageText = not settings.damageText
		ApplyDamageText()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.damageText and "quick damage numbers." or "the game's own damage numbers."))
	else
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui damage  switches between the quick damage numbers and the game's own")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui chat 12  sets the chat text size, 8 to 18")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: hold Alt to see everything that moves, and drag; /sui center puts the middle back, /sui layout puts everything back")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui bosses  switches the boss bars on or off; /sui bosses elites  lists elites too")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tally  switches between the kills and gold line under the bar and the game's own box")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui run  shows or hides the run panel (the run's numbers and biggest crits); /sui run reset clears the crits")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tracker  shows or hides the run tracker under the minimap (the clock and the bosses)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui hover  switches the white outline around what the mouse is on")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui scale 0.85  sizes the panels, 0.6 to 1.4, for smaller screens")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui meter  switches between the addon's damage meter, with the crits, and the game's own")
	end
end

------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UNIT_PORTRAIT_UPDATE")
loader:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		HideStockUnitFrames()
		HideStockBuffs()
		LayoutBar()
		SquareMinimap()
		MoveMicroButtons()
		HideMicroButtons()
		ApplyFonts()
		StyleChat()
		StyleTooltips()
		ApplyDamageText()
		UpdatePortrait(player)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdatePortrait(target)
	elseif arg1 == "player" then
		UpdatePortrait(player)
	elseif arg1 == "target" then
		UpdatePortrait(target)
	end
end)
