-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the Level Up! button.
--
-- With the game's Store Level-Ups on (its Options, Controls; or the options'
-- Level Up! tab), a level-up no longer stops the fight: the levels wait, and
-- a button opens them, one card choice after another. The game's own button
-- sits over the game's action bars, where Survivor UI's compact bar is not, so
-- the addon draws its own in its place (AZS_SetHudShown("levels", false)):
-- over the action bar, how many levels wait, breathing a gold glow; a click
-- opens them (AZS_OpenStoredLevels). Off until chosen (Modules): on a touch
-- screen the game's button takes a tap and the addon's does not, and the
-- addon cannot tell a touch screen; off, the game's shows.
-- The levels waiting also show by the level, in the run tracker and on the XP
-- bar (Tracker.lua, XpBar.lua).

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local GOLD = { 1, 0.82, 0 }
local NAME = "Level Up!"

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local function On()
	return Settings().levelUp == true
end

-- The levels waiting: 0 with Store Level-Ups off, or on a game without it.
function SurvivorUI_StoredLevels()
	return AZS_GetStoredLevels and tonumber(AZS_GetStoredLevels()) or 0
end

local function Phase()
	return AZS_GetPhase and AZS_GetPhase()
end

------------------------------------------------------------------------------
-- The button.

local button = CreateFrame("Button", "SurvivorUILevelUp", UIParent)
button:SetWidth(150)
button:SetHeight(30)
button:SetFrameStrata("MEDIUM")
button:SetMovable(true)
button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
button:SetBackdropColor(0.16, 0.12, 0.02, 0.95)
button:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
button:Hide()

-- The glow behind it, as Move UI's: it breathes, brighter under the mouse.
button.glow = button:CreateTexture(nil, "BACKGROUND")
button.glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
button.glow:SetBlendMode("ADD")
button.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
button.glow:SetWidth(230)
button.glow:SetHeight(72)
button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)

button.text = button:CreateFontString(nil, "OVERLAY")
button.text:SetFont(SurvivorUI_FONT, 13 + FONT_BUMP, "OUTLINE")
button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
button.text:SetTextColor(1, 0.88, 0.35)

button.age = 0
button:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local breath = 0.5 + 0.5 * math.sin(this.age * 3)
	this.glow:SetAlpha((this.hot and 0.7 or 0.35) + 0.3 * breath)
end)

button:SetScript("OnClick", function()
	if SurvivorUI_StoredLevels() > 0 and AZS_OpenStoredLevels then
		AZS_OpenStoredLevels()
	end
end)

button:SetScript("OnEnter", function()
	this.hot = true
	this:SetBackdropBorderColor(1, 1, 1, 1)
	local stored = SurvivorUI_StoredLevels()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(stored == 1 and "1 level waiting" or stored.." levels waiting", GOLD[1], GOLD[2], GOLD[3])
	GameTooltip:AddLine("Click to choose them, one after another.", 1, 1, 1, 1)
	GameTooltip:AddLine("Store Level-Ups: the game's Options, Controls, or /sui opt, Level Up!", 0.6, 0.6, 0.65, 1)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
	this.hot = nil
	this:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
	GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- Shown while levels wait and the fight goes on; a sample while it is being
-- placed (move mode, Alt, or its tab open), so it can be seen where it goes.

local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local stored = SurvivorUI_StoredLevels()
	local placing = SurvivorUI_Placing and SurvivorUI_Placing(NAME)
	if On() and (placing or (stored > 0 and Phase() == "playing")) then
		button.text:SetText("LEVEL UP!  |cffffffffx"..(stored > 0 and stored or 2).."|r")
		button:Show()
	else
		button:Hide()
	end
end)

------------------------------------------------------------------------------
-- The game's own button: away while the addon's stands in for it. The setting
-- is the game's and is saved, so the addon remembers that it was the one to
-- turn it off.

local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown and AZS_GetStoredLevels) then
		return
	end
	local settings = Settings()
	if On() or settings.noGameLevels then
		if AZS_IsHudShown("levels") then
			AZS_SetHudShown("levels", false)
			settings.hidGameLevels = true
		end
	elseif settings.hidGameLevels then
		AZS_SetHudShown("levels", true)
		settings.hidGameLevels = nil
	end
end

-- For the options: the Default tick in Modules, as the other parts the game
-- has its own of.
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.levels = ApplyGameHud

function SurvivorUI_ToggleLevelUp()
	local settings = Settings()
	settings.levelUp = not On()
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the Level Up! button "..(On() and "is Survivor UI's."
		or (settings.noGameLevels and "is off, the game's too." or "is the game's again.")))
end

-- Which button: "ours", "game" or "off" (none at all).
function SurvivorUI_LevelUpButton()
	if On() then
		return "ours"
	end
	return Settings().noGameLevels and "off" or "game"
end

function SurvivorUI_SetLevelUpButton(choice)
	local settings = Settings()
	settings.levelUp = choice == "ours"
	settings.noGameLevels = choice == "off" or nil
	ApplyGameHud()
end

------------------------------------------------------------------------------
-- Its place: over the action bar, in the middle, until moved; once moved,
-- kept by the middle of its top.

local function DefaultPlace()
	local row = getglobal("SurvivorUIRow")
	if row then
		button:SetPoint("BOTTOM", row, "TOP", 0, 30)
	else
		button:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
	end
end

local function RestorePlace()
	button:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.levelUpX and db.levelUpTop then
		button:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.levelUpX, db.levelUpTop)
	else
		DefaultPlace()
	end
end

local function SavePlace()
	local db = Settings()
	db.levelUpX = math.floor(button:GetLeft() + button:GetWidth() / 2 + 0.5)
	db.levelUpTop = math.floor(button:GetTop() + 0.5)
	RestorePlace()
end

DefaultPlace()
if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(button, NAME, SavePlace, nil, function()
		local db = Settings()
		db.levelUpX, db.levelUpTop = nil, nil
		RestorePlace()
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)
