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
-- The row sits a little under the hero, who stands in the middle of the screen.
--
-- Left click a frame to target it, right click for its menu. Alt-drag either
-- frame to move the whole row.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"

local BAR_BUTTONS = { 1, 2, 3, 4, 5, 6, 12 }     -- 12 is the = key
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local ROW_BELOW_CENTER = 150                    -- the row sits this far under the hero, who stands mid-screen
local SECTION_GAP = 6                           -- between a unit frame and the buttons

local FRAME_WIDTH = 150                         -- the bar part of a unit frame
local POWER_HEIGHT = 3
local HEALTH_HEIGHT = BUTTON_SIZE - POWER_HEIGHT - 1

local ENEMY = { 0.80, 0.22, 0.22 }

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
	text:SetFont(FONT, size, "OUTLINE")
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

	frame.name = Text(frame.health, 11, "LEFT", 5, 0)
	frame.name:SetWidth(FRAME_WIDTH - 82)
	frame.name:SetHeight(12)
	frame.name:SetJustifyH("LEFT")
	frame.name:SetTextColor(1, 1, 1)

	frame.value = Text(frame.health, 11, "RIGHT", -5, 0)
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
			hotkey:SetFont(FONT, 10, "OUTLINE")
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
			local _, size = chat:GetFont()
			chat:SetFont(FONT, size or 13)
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
				tabText:SetFont(FONT, 11, "OUTLINE")
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
		StyleChat()
		UpdatePortrait(player)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdatePortrait(target)
	elseif arg1 == "player" then
		UpdatePortrait(player)
	elseif arg1 == "target" then
		UpdatePortrait(target)
	end
end)
