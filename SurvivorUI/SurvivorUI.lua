-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
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
-- The interface's face, shared with the addon's other files: Friz Quadrata, the
-- game's own, unless a face is dropped in: Expressway in SurvivorUI\Fonts, or
-- Barlow Condensed in SurvivorUI\Media (neither is shipped).
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

local CHAT_SIZE = 10                            -- default; /sui chat N changes it

-- Saved between sessions; the /sui command at the end of the file changes them.
-- Every look the addon gives the game's interface can be switched off in the
-- options panel (/sui opt): SurvivorUIDB.features[key] = false. Most take hold
-- at the next /reload, as they are laid on when the world loads.
function SurvivorUI_Feature(key)
	local features = SurvivorUIDB and SurvivorUIDB.features
	return not features or features[key] ~= false
end

function SurvivorUI_SetFeature(key, on)
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.features = SurvivorUIDB.features or {}
	SurvivorUIDB.features[key] = on and true or false
end

local Feature = SurvivorUI_Feature

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.damageText == nil then
		SurvivorUIDB.damageText = true
	end
	-- From v2.8 the numbers beside the hero are the default: switched on once
	-- for everyone who has the addon's own numbers, and kept as each one sets
	-- them after that.
	if (SurvivorUIDB.damageDefaults or 0) < 2 then
		if SurvivorUIDB.damageText and not SurvivorUIDB.damageNone then
			SurvivorUIDB.damageSide = true
		end
	end
	-- From v2.9 the numbers beside the hero with icons are the default: once for everyone with
	-- the numbers beside the hero, kept as each one sets it after that.
	if (SurvivorUIDB.damageDefaults or 0) < 3 then
		SurvivorUIDB.damageDefaults = 3
		if SurvivorUIDB.damageText and SurvivorUIDB.damageSide and not SurvivorUIDB.damageNone then
			SurvivorUIDB.damageModern = true
		end
	end
	-- From v2.9 the chat's default is 10, not 12: the old default moves once.
	if (SurvivorUIDB.chatDefaults or 0) < 2 then
		SurvivorUIDB.chatDefaults = 2
		if SurvivorUIDB.chatSize == 12 then
			SurvivorUIDB.chatSize = nil
		end
	end
	SurvivorUIDB.chatSize = SurvivorUIDB.chatSize or CHAT_SIZE
	return SurvivorUIDB
end

-- 1.12 paints shamans in the paladin's pink; they wear their modern blue here.
local CLASS_OVERRIDES = {
	SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
}

-- A class's color, as the unit frames wear it (the shaman's blue): r, g, b.
function SurvivorUI_ClassColor(class)
	local color = class and (CLASS_OVERRIDES[class] or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if color then
		return color.r, color.g, color.b
	end
	return 1, 0.82, 0
end

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

-- 950, 1k, 1.1k, 15.3k, 2M, 2.2M, 1.5B: one decimal at most, none when round.
local SIZES = { { 1000000000, "B" }, { 1000000, "M" }, { 1000, "k" } }
function SurvivorUI_Abbrev(value)
	value = tonumber(value) or 0
	for index = 1, table.getn(SIZES) do
		if value >= SIZES[index][1] then
			local size = SIZES[index]
			local scaled = math.floor(value / size[1] * 10 + 0.5) / 10
			-- 999,960 rounds to 1000k: the next size up says it.
			if scaled >= 1000 and index > 1 then
				size = SIZES[index - 1]
				scaled = math.floor(value / size[1] * 10 + 0.5) / 10
			end
			local text = string.gsub(string.format("%.1f", scaled), "%.0$", "")
			return text..size[2]
		end
	end
	return tostring(math.floor(value + 0.5))
end

-- A health as an option reads it: "percent" 73%, "absolute" 1.2M, "both"
-- 1.2M / 3.4M, "absolutePercent" 1.2M | 73% (as the player's frame).
function SurvivorUI_HealthText(hp, hpm, style)
	hp, hpm = tonumber(hp) or 0, tonumber(hpm) or 0
	if style == "absolute" then
		return SurvivorUI_Abbrev(hp)
	elseif style == "both" then
		return SurvivorUI_Abbrev(hp).." / "..SurvivorUI_Abbrev(hpm)
	elseif style == "absolutePercent" then
		return SurvivorUI_Abbrev(hp).." | "..(hpm > 0 and math.floor(hp / hpm * 100 + 0.5) or 0).."%"
	end
	return (hpm > 0 and math.floor(hp / hpm * 100 + 0.5) or 0).."%"
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
	-- The player's health reads "524 | 100%", a target's only "67%": the target's
	-- name gets the room the numbers leave.
	frame.nameRoom = unit == "player" and FRAME_WIDTH - 82 or FRAME_WIDTH - 44
	frame.name:SetWidth(frame.nameRoom)
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
	local r, g, b = HealthColor(unit)
	frame.health:SetValue(share)
	frame.health:SetStatusBarColor(r, g, b, 1)
	-- The health as the option reads it (/sui opt, Unit frames): the player's
	-- "1.2k | 100%" by default, a target's "73%". The game's API has an enemy's
	-- numbers (AZS_TARGET); the client alone only its share. The name gets the
	-- room the numbers leave.
	local hp, hpm, style = health, healthMax, nil
	if unit == "player" then
		style = SurvivorUIDB and SurvivorUIDB.playerHealth or "absolutePercent"
	else
		style = SurvivorUIDB and SurvivorUIDB.targetHealth or "percent"
		if AZS_TARGET and AZS_TARGET.name == UnitName(unit) and (tonumber(AZS_TARGET.hpm) or 0) > 0 then
			hp, hpm = AZS_TARGET.hp, AZS_TARGET.hpm
		elseif healthMax == 100 then
			style = "percent"
		end
	end
	local room = FRAME_WIDTH - 44
	if style == "both" or style == "absolutePercent" then
		room = FRAME_WIDTH - 82
	elseif style == "absolute" then
		room = FRAME_WIDTH - 52
	end
	if room ~= frame.nameRoom then
		frame.nameRoom = room
		frame.shownName = nil
	end
	-- A name too long for its room goes by its first word, not cut short.
	local name = UnitName(unit) or ""
	if name ~= frame.shownName then
		frame.shownName = name
		frame.name:SetWidth(0)
		frame.name:SetText(name)
		if frame.name:GetStringWidth() > frame.nameRoom then
			local _, _, first = string.find(name, "^(%S+)")
			frame.name:SetText(first or name)
		end
		frame.name:SetWidth(frame.nameRoom)
	end

	if UnitIsDead(unit) or UnitIsGhost(unit) then
		frame.value:SetText("Dead")
	else
		frame.value:SetText(SurvivorUI_HealthText(hp, hpm, style))
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

		-- No key labels: the spells cast themselves. Made clear rather than hidden,
		-- since the stock code shows and fills them again on its own.
		local hotkey = getglobal(name.."HotKey")
		if hotkey then
			hotkey:SetAlpha(Feature("hideKeys") and 0 or 1)
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

-- The bags: a run has nothing to keep in them, so B and Shift+B open none.
for _, name in pairs({ "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag", "OpenAllBags", "ToggleKeyRing" }) do
	if getglobal(name) then
		setglobal(name, function() end)
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

	-- The bar the client puts in the experience bar's place at the top level
	-- (99), and the reputation bar: shown again by the stock code on every
	-- update, so kept away for good.
	for _, name in pairs({ "MainMenuBarMaxLevelBar", "ReputationWatchBar" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
			frame.Show = function() end
		end
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

-- The buffs sit on a holder of their own, over the player frame, so they can be
-- moved apart from the middle block (Mover.lua).
local buffHolder = CreateFrame("Frame", "SurvivorUIBuffs", UIParent)
buffHolder:SetWidth(AURA_MAX * (AURA_SIZE + 3) - 3)
buffHolder:SetHeight(AURA_SIZE)
buffHolder:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 5)
buffHolder:SetMovable(true)

local auras = {}
for index = 1, AURA_MAX do
	local aura = CreateFrame("Button", nil, buffHolder)
	aura:SetWidth(AURA_SIZE)
	aura:SetHeight(AURA_SIZE)
	aura:SetPoint("BOTTOMLEFT", buffHolder, "BOTTOMLEFT", (index - 1) * (AURA_SIZE + 3), 0)
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

	-- The last two seconds count down in red.
	local function CounterUpdate()
		local left = this.start + this.duration - GetTime()
		if left <= 0 then
			this:Hide()
			return
		end
		this.text:SetText(TimeText(left))
		local soon = left <= 2
		if soon ~= this.soon then
			this.soon = soon
			if soon then
				this.text:SetTextColor(1, 0.25, 0.25)
			else
				this.text:SetTextColor(1, 0.95, 0.6)
			end
		end
	end

	CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
		stockSetTimer(cooldown, start, duration, enable)

		local parent = cooldown and cooldown:GetParent()
		if not parent then
			return
		end
		if not Feature("cooldownNumbers") then
			if parent.survivorCounter then
				parent.survivorCounter:Hide()
			end
			return
		end

		local counter = parent.survivorCounter
		if not counter then
			counter = CreateFrame("Frame", nil, parent)
			counter:SetAllPoints(parent)
			counter:SetFrameLevel(cooldown:GetFrameLevel() + 3)
			-- A button cooling down is dimmed under its count.
			counter.dim = counter:CreateTexture(nil, "BACKGROUND")
			counter.dim:SetTexture(FLAT)
			counter.dim:SetVertexColor(0, 0, 0, 0.45)
			counter.dim:SetAllPoints(counter)
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

-- The game's right click menus (a chat tab's, a unit frame's): a fifth
-- smaller, as the tooltips.
local function SizeMenus()
	for level = 1, 3 do
		local menu = getglobal("DropDownList"..level)
		-- The stock code sets a menu's size each time it opens: a fifth off
		-- whatever it set, once (not again on a size already made smaller).
		local size = menu and menu:GetScale()
		if size and not (menu.survivorSize and math.abs(size - menu.survivorSize) < 0.001) then
			menu.survivorSize = size * 0.8
			menu:SetScale(menu.survivorSize)
		end
	end
end

-- After the stock opens one.
if ToggleDropDownMenu then
	local stockToggle = ToggleDropDownMenu
	ToggleDropDownMenu = function(a1, a2, a3, a4, a5, a6, a7, a8)
		stockToggle(a1, a2, a3, a4, a5, a6, a7, a8)
		if Feature("tooltip") then
			SizeMenus()
		end
	end
end

local function StyleTooltips()
	-- The stock code repaints a tooltip from these two.
	TOOLTIP_DEFAULT_COLOR = { r = 0, g = 0, b = 0 }
	TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.05, b = 0.07 }

	SizeMenus()
	for _, name in pairs(TOOLTIPS) do
		local tooltip = getglobal(name)
		if tooltip and not tooltip.survivorStyled then
			tooltip.survivorStyled = true
			tooltip:SetBackdrop(TOOLTIP_BACKDROP)
			-- A fifth smaller than the stock size: it covers less of the fight.
			tooltip:SetScale(0.8)
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
	-- The source's icon, left of the number (beside the hero, with icons).
	text.icon = damageLayer:CreateTexture(nil, "OVERLAY")
	text.icon:SetPoint("RIGHT", text, "LEFT", -3, 0)
	text.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	text.icon:Hide()
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
-- A pooled number changes size and outline only when it must: setting the same
-- face again still costs the engine a font lookup, many times a second.
------------------------------------------------------------------------------
-- Survivor's combat text, as the player sets it (the options, Combat text):
-- where the numbers go, how they look and what shows. The first time, the
-- choices of the earlier versions carry over.

local CT_DEFAULTS = {
	ctLayout = "sides", ctDistance = 160, ctRise = 190, ctCritColumn = true,
	ctIcons = true, ctMeterColors = true, ctSize = 0.85,
	ctPeriodic = true, ctHeals = true, ctTaken = true,
}

local function CT()
	local db = Settings()
	if (db.ctVersion or 0) < 1 then
		db.ctVersion = 1
		for key, value in pairs(CT_DEFAULTS) do
			if db[key] == nil then
				db[key] = value
			end
		end
		db.ctLayout = (db.damageSide or db.damageModern) and "sides" or "enemies"
		db.ctIcons = db.damageModern and true or false
		db.ctMeterColors = db.damageModern and true or false
	end
	return db
end

local function Face(text, size, flags)
	local share = CT().ctSize or 0.85
	local key = size..flags..share
	if text.faceKey ~= key then
		text.faceKey = key
		text:SetFont(FONT, math.max(6, math.floor(size * share + 0.5)), flags)
	end
end

------------------------------------------------------------------------------
-- Beside the hero (/sui damage side, or the option): the numbers scroll in
-- columns by the hero instead of popping over the enemies. The damage dealt
-- climbs on the left in white, its crits on the right in gold; under the hero
-- the healing rises up to it, in green, and the damage
-- taken falls from under the hero, in red. Hits that come together start a
-- line apart, so the column reads.

local SIDE_LIFE = 1.3
local SIDE_RISE = 190
local SIDE_GAP = 15             -- between numbers that start together
-- The hits dealt in two columns, the plain ones left of the hero, the crits
-- right of it, so one never covers the other.
local SIDE_COLUMNS = {
	-- Five grid squares out (the move mode's lines are 32 apart).
	dealt = { x = -160, y = 0, rise = 1 },
	crit = { x = 160, y = 0, rise = 1 },
	-- Under the hero, kept above the action bar (some 150 below it): the hits
	-- taken fall a little, left of the middle; the heals rise up to the hero,
	-- right of it, so the two never cross.
	taken = { x = -30, y = -35, rise = -1, reach = 70, spread = -1 },
	heal = { x = 30, y = -105, rise = 1, reach = 70, spread = 1 },
}
local sideStack = {}            -- [column] = { at = time, count = numbers started together }
local SPREAD = { 0, 40, 80, 120, 160 }

local function SideOn()
	return CT().ctLayout == "sides"
end

-- Beside the hero, with icons: each hit with its source's icon, in
-- the color the damage meter gives that source. A melee hit shows the weapon
-- in hand; a shot the ranged weapon (a hunter's bow, a wand).
local OWN_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\SurvivorIcon"
local RANGED = { ["Auto Shot"] = true, ["Shoot"] = true, ["Shot"] = true, ["Auto Shoot"] = true }
local iconCache, iconCacheAt = {}, 0

local function SourceIcon(source)
	if source == "Melee" then
		return GetInventoryItemTexture("player", 16) or OWN_ICON, false
	elseif RANGED[source] then
		return GetInventoryItemTexture("player", 18) or GetInventoryItemTexture("player", 16) or OWN_ICON, false
	end
	-- The meter's lookup goes through the spellbook, the talents and the
	-- items: kept a while, so a fight of many hits asks once per source.
	if GetTime() - iconCacheAt > 30 then
		iconCache, iconCacheAt = {}, GetTime()
	end
	if iconCache[source] == nil then
		iconCache[source] = (SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(source)) or false
	end
	if iconCache[source] then
		return iconCache[source], false
	end
	return OWN_ICON, true
end

-- A hit dealt in the meter's color and with its source's icon, as chosen;
-- false when neither.
local function Dress(text, dealt, crit, source)
	local ct = CT()
	local colored = dealt and source and ct.ctMeterColors
	if colored then
		local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(source) or { 1, 1, 1 }
		text:SetTextColor(color[1], color[2], color[3])
	end
	if dealt and source and ct.ctIcons then
		local icon, whole = SourceIcon(source)
		text.icon:SetTexture(icon)
		if whole then
			text.icon:SetTexCoord(0, 1, 0, 1)
		else
			text.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		-- The icon sized with the type.
		local edge = math.floor((crit and 22 or 16) * (ct.ctSize or 0.85) + 0.5)
		text.icon:SetWidth(edge)
		text.icon:SetHeight(edge)
		text.icon:SetAlpha(1)
		text.icon:Show()
	else
		text.icon:Hide()
	end
	return colored
end

local function SpawnSide(kind, amount, crit, periodic, source)
	local text = DamageText()
	if not text then
		return
	end
	local dealt = kind == "dealt"
	local ct = CT()
	-- The crits in a column of their own, on the right, or with the rest.
	if kind == "dealt" and crit and ct.ctCritColumn then
		kind = "crit"
	end
	local column = SIDE_COLUMNS[kind]
	local columnX = column.x
	if kind == "dealt" then
		columnX = -(ct.ctDistance or 160)
	elseif kind == "crit" then
		columnX = ct.ctDistance or 160
	end
	local now = GetTime()
	local stack = sideStack[kind] or { at = 0, count = 0 }
	sideStack[kind] = stack
	if now - stack.at < 0.12 then
		stack.count = math.mod(stack.count + 1, 5)
	else
		stack.count = 0
	end
	stack.at = now

	local size = crit and CRIT_POP_SIZE or ((periodic and 12 or 14) + FONT_BUMP)
	Face(text, size, crit and "THICKOUTLINE" or "OUTLINE")
	if kind == "taken" then
		text:SetTextColor(1, 0.22, 0.22)
		amount = "-"..amount
	elseif kind == "heal" then
		text:SetTextColor(0.3, 1, 0.4)
		amount = "+"..amount
	elseif crit then
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		text:SetTextColor(0.80, 0.80, 0.80)
	else
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(amount)
	Dress(text, dealt, crit, source)

	text.live = true
	text.crit = crit
	text.popped = nil
	text.life = crit and SIDE_LIFE * 1.2 or SIDE_LIFE
	text.age = 0
	text.side = true
	-- Numbers that start together line up, the later ones a line further on.
	text.x = UIParent:GetWidth() / 2 + columnX
	text.y = UIParent:GetHeight() / 2 + column.y - column.rise * stack.count * SIDE_GAP
	if column.spread then
		-- Under the hero, numbers that start together go side by side, outward,
		-- not closer and closer to the bar.
		text.x = text.x + column.spread * SPREAD[stack.count + 1]
		text.y = UIParent:GetHeight() / 2 + column.y
	end
	text.drift = 0
	text.rise = (column.reach or ct.ctRise or SIDE_RISE) * column.rise
	text:SetAlpha(1)
	text:Show()
	damageLive = damageLive + 1
end

local function SpawnDamage(target, amount, crit, periodic, source)
	local ct = CT()
	if (periodic and not ct.ctPeriodic) or (not target and not ct.ctTaken) then
		return
	end
	if SideOn() then
		SpawnSide(target and "dealt" or "taken", amount, crit, periodic, source)
		return
	end
	local text = DamageText()
	if not text then
		return
	end
	text.side = nil

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
		Face(text, crit and CRIT_POP_SIZE or 14, crit and "THICKOUTLINE" or "OUTLINE")
		text:SetTextColor(1, 0.22, 0.22)
		amount = "-"..amount
	elseif crit then
		-- Lands oversized, then settles: see the update below.
		Face(text, CRIT_POP_SIZE, "THICKOUTLINE")
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		Face(text, 12 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(0.80, 0.80, 0.80)
	else
		Face(text, 14 + FONT_BUMP, "OUTLINE")
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(amount)
	Dress(text, target ~= nil, crit, source)

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
				Face(text, CRIT_SIZE, "THICKOUTLINE")
			end
			if t >= 1 then
				text.live = nil
				text:Hide()
				text.icon:Hide()
				damageLive = damageLive - 1
			else
				-- Fast at first, slowing as it tops out; fading over the last third.
				-- Beside the hero, a steadier scroll, so a column reads.
				local eased = text.side and (1 - (1 - t) * (1 - t) * 0.5 - 0.5 * (1 - t)) or (1 - (1 - t) * (1 - t))
				text:ClearAllPoints()
				text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", text.x + text.drift * eased, text.y + text.rise * eased)
				text:SetAlpha(t > 0.66 and (1 - t) / 0.34 or 1)
				text.icon:SetAlpha(text:GetAlpha())
			end
		end
	end
end)

-- The hit's source, as the damage meter names it: "Your Fireball" is
-- Fireball, "You" Melee, a pet its own name.
local function SourceOf(who)
	local _, _, spell = string.find(who or "", "^Your (.+)$")
	if spell then
		return spell
	elseif who == "You" then
		return "Melee"
	end
	return who
end

local function ParseDamage(message)
	local _, _, who, target, amount = string.find(message, "^(.-) crits (.+) for (%d+)")
	if target then
		return target, amount, true, false, SourceOf(who)
	end
	_, _, who, target, amount = string.find(message, "^(.-) crit (.+) for (%d+)")
	if target then
		return target, amount, true, false, SourceOf(who)
	end
	_, _, who, target, amount = string.find(message, "^(.-) hits (.+) for (%d+)")
	if target then
		return target, amount, false, false, SourceOf(who)
	end
	_, _, who, target, amount = string.find(message, "^(.-) hit (.+) for (%d+)")
	if target then
		return target, amount, false, false, SourceOf(who)
	end
	-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
	local spell
	_, _, target, amount, spell = string.find(message, "^(.+) suffers (%d+) .+ from your (.-)%.?$")
	if target then
		return target, amount, false, true, spell
	end
end

-- The hits the hero takes come from the stock floating combat text's own feed.
local TAKEN_TYPES = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true }
-- And the heals, beside the hero only.
local HEAL_TYPES = { HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true }

local damageEvents = CreateFrame("Frame")
damageEvents:SetScript("OnEvent", function()
	if not Settings().damageText then
		return
	end
	if event == "COMBAT_TEXT_UPDATE" then
		if TAKEN_TYPES[arg1] and tonumber(arg2) then
			SpawnDamage(nil, arg2, arg1 == "DAMAGE_CRIT")
		elseif HEAL_TYPES[arg1] and CT().ctHeals then
			-- A heal: arg2 the healer, arg3 the health it gave.
			local amount = tonumber(arg3) or tonumber(arg2)
			if amount and amount > 0 then
				SpawnSide("heal", math.floor(amount + 0.5), arg1 == "HEAL_CRIT", arg1 == "PERIODIC_HEAL")
			end
		end
		return
	end
	local target, amount, crit, periodic, source = ParseDamage(arg1 or "")
	if target then
		SpawnDamage(target, amount, crit, periodic, source)
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
-- Each kind's own "show", as the stock code set it, to give back after "no
-- combat text at all".
local stockShow

local function ApplyTakenText()
	if not COMBAT_TEXT_TYPE_INFO then
		return
	end
	if not stockShow then
		stockShow = {}
		for kind, info in pairs(COMBAT_TEXT_TYPE_INFO) do
			stockShow[kind] = info.show
		end
	end
	-- No combat text at all (/sui damage none): every kind of the stock
	-- floating text silenced; back as it was when switched off.
	local none = Settings().damageNone
	for kind, info in pairs(COMBAT_TEXT_TYPE_INFO) do
		if none then
			info.show = nil
		elseif info.var ~= "SURVIVORUI_NEVER" then
			info.show = stockShow[kind]
		end
	end
	if none then
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
	-- Beside the hero, the heals are the addon's too.
	-- The heals are the addon's in its own mode, shown or not as chosen.
	local heals = on
	for kind in pairs(HEAL_TYPES) do
		local info = COMBAT_TEXT_TYPE_INFO[kind]
		if info then
			info.show = not heals and 1 or nil
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
	local none = Settings().damageNone
	local on = Settings().damageText and not none
	for _, event in pairs(DAMAGE_EVENTS) do
		if on then
			damageEvents:RegisterEvent(event)
		else
			damageEvents:UnregisterEvent(event)
		end
	end
	-- The engine's own numbers: only when the game's are the ones chosen.
	SetCVar("CombatDamage", (on or none) and "0" or "1")
	ApplyTakenText()
end

function SurvivorUI_ToggleDamage()
	local settings = Settings()
	settings.damageText = not settings.damageText
	settings.damageNone = nil
	ApplyDamageText()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.damageText and "quick damage numbers." or "the game's own damage numbers."))
end

-- How the combat numbers show, for the options: "quick" (over the enemies),
-- "side" (beside the hero), "game" (the game's own) or "none" (no combat text).
function SurvivorUI_DamageMode()
	local settings = Settings()
	if settings.damageNone then
		return "none"
	elseif not settings.damageText then
		return "game"
	end
	return "survivor"
end

function SurvivorUI_SetDamageMode(mode)
	local settings = Settings()
	settings.damageNone = mode == "none"
	settings.damageText = mode == "survivor"
	ApplyDamageText()
end

-- For the options: one of Survivor's combat text settings, and its change.
function SurvivorUI_CT(key)
	return CT()[key]
end

function SurvivorUI_SetCT(key, value)
	CT()[key] = value
	ApplyDamageText()
end

-- Survivor's own look: beside the hero, with icons and the meter's colors.
function SurvivorUI_CTDefaults()
	local ct = CT()
	for key, value in pairs(CT_DEFAULTS) do
		ct[key] = value
	end
	SurvivorUI_SetDamageMode("survivor")
end

-- The numbers beside the hero, or over the enemies again.
function SurvivorUI_ToggleDamageSide()
	local settings = Settings()
	local ct = CT()
	ct.ctLayout = ct.ctLayout == "sides" and "enemies" or "sides"
	settings.damageSide = ct.ctLayout == "sides"
	settings.damageText = true
	settings.damageNone = nil
	ApplyDamageText()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: damage numbers "..(settings.damageSide and "beside the hero." or "over the enemies."))
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
	elseif msg == "pace" or msg == "pace reset" or msg == "pace class" then
		if SurvivorUI_TogglePace then
			SurvivorUI_TogglePace(argument)
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
	elseif msg == "loot" then
		if SurvivorUI_ToggleLoot then
			SurvivorUI_ToggleLoot()
		end
	elseif msg == "opt" or msg == "options" or msg == "config" then
		if SurvivorUI_ToggleOptions then
			SurvivorUI_ToggleOptions()
		end
	elseif msg == "build" then
		if SurvivorUI_ToggleBuild then
			SurvivorUI_ToggleBuild()
		end
	elseif msg == "crits" then
		if SurvivorUI_ToggleCrits then
			SurvivorUI_ToggleCrits()
		end
	elseif msg == "collection" or msg == "jewelry" then
		if SurvivorUI_ToggleJewelry then
			SurvivorUI_ToggleJewelry()
		end
	elseif msg == "collection reset" then
		if SurvivorUI_ResetCollection then
			SurvivorUI_ResetCollection()
		end
	elseif msg == "pins" then
		if SurvivorUI_PinsReport then
			SurvivorUI_PinsReport()
		end
	elseif msg == "center" then
		if SurvivorUI_CenterRow then
			SurvivorUI_CenterRow()
		end
	elseif msg == "damage" then
		SurvivorUI_ToggleDamage()
	elseif msg == "damage side" then
		SurvivorUI_ToggleDamageSide()
	elseif msg == "damage modern" or msg == "damage icons" then
		local on = not CT().ctIcons
		CT().ctIcons, CT().ctMeterColors = on, on
		SurvivorUI_SetDamageMode("survivor")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: damage numbers "..(on and "with their source's icon, in its damage meter color." or "without icons, in the classic colors."))
	elseif msg == "damage none" then
		local none = SurvivorUI_DamageMode() ~= "none"
		SurvivorUI_SetDamageMode(none and "none" or "survivor")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(none and "no combat text at all." or "quick damage numbers."))
	else
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui opt  opens the options: every piece on or off, panel size, and a move mode with a grid")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui damage  switches between the quick damage numbers and the game's own")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui damage side  puts the damage numbers beside the hero, or back over the enemies")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui pins  prints what the minimap's cache and lair pins read")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui collection  the Jewelry Collection: every amulet, ring and trinket found, and what is left to find; /sui collection reset  forgets it all")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui chat 10  sets the chat text size, 8 to 18 (default 10)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: hold Alt to see everything that moves, and drag; /sui center puts the middle back, /sui layout puts everything back")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui bosses  switches the boss bars on or off; /sui bosses elites  lists elites too")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tally  switches between the kills and gold line under the bar and the game's own box")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui pace  shows or hides the kill pace, the orb by the run tracker's clock; /sui pace class  against this class's runs only, or every class's; /sui pace reset  forgets the runs it holds against")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui run  shows or hides the run panel (the run's numbers and biggest crits); /sui run reset clears the crits")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui tracker  shows or hides the run tracker under the minimap (the clock and the bosses)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui build  shows or hides the build list (spells, ranks, slots)")
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: /sui crits  shows or hides the Biggest Crits box (off by default)")
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
		if Feature("minimap") then
			SquareMinimap()
		end
		if Feature("microMenu") then
			MoveMicroButtons()
			HideMicroButtons()
		end
		if Feature("fonts") then
			ApplyFonts()
		end
		if Feature("chat") then
			StyleChat()
		end
		if Feature("tooltip") then
			StyleTooltips()
		end
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
