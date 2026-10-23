-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the Level Up! button.
--
-- With the game's Store Level-Ups on (its Options, Controls; or the options'
-- Level Up! tab), a level-up no longer stops the fight: the levels wait, and
-- a button opens them, one card choice after another. The game's own button
-- sits over the game's action bars, where Survivor UI's compact bar is not, so
-- the addon draws its own in its place (AZS_SetHudShown("levels", false)):
-- over the action bar, how many levels wait, breathing a gold glow; a click
-- opens them (AZS_OpenStoredLevels), as the game's key does (Y, from 0.102),
-- shown as a key cap on its right. On for a new install (v3.0.12; off until
-- chosen before): on a touch screen the game's button takes a tap and the
-- addon's does not, and the addon cannot tell a touch screen; off, the
-- game's shows.
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

-- The button's color (the Level Up! tab, Look): the class's unless chosen,
-- gold or one of these. The fill, the glow, the edge, the key cap and the
-- sparks take it.
SurvivorUI_LEVELUP_COLORS = {
	{ "class", "Class color", nil },
	{ "gold", "Gold", { 1.00, 0.82, 0.00 } },
	{ "white", "White", { 1.00, 1.00, 1.00 } },
	{ "red", "Red", { 1.00, 0.28, 0.22 } },
	{ "orange", "Orange", { 1.00, 0.55, 0.15 } },
	{ "green", "Green", { 0.40, 1.00, 0.45 } },
	{ "teal", "Teal", { 0.30, 0.95, 0.90 } },
	{ "blue", "Blue", { 0.40, 0.65, 1.00 } },
	{ "purple", "Purple", { 0.72, 0.48, 1.00 } },
	{ "pink", "Pink", { 1.00, 0.50, 0.80 } },
}

function SurvivorUI_LevelUpColor()
	local key = Settings().levelUpColor or "class"
	if key == "class" and SurvivorUI_ClassColor then
		local _, class = UnitClass("player")
		if class then
			return SurvivorUI_ClassColor(class)
		end
	end
	for index = 1, table.getn(SurvivorUI_LEVELUP_COLORS) do
		local entry = SurvivorUI_LEVELUP_COLORS[index]
		if entry[1] == key and entry[3] then
			return entry[3][1], entry[3][2], entry[3][3]
		end
	end
	return GOLD[1], GOLD[2], GOLD[3]
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

-- The game's key for it (from 0.102: Open Level-Ups, Y unless changed in the
-- game's Key Bindings), as a key cap on its right, in the middle of its
-- height; the words move over to leave it room.
button.cap = CreateFrame("Frame", nil, button)
button.cap:SetHeight(20)
button.cap:SetPoint("RIGHT", button, "RIGHT", -6, 0)
button.cap:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
button.cap:SetBackdropColor(0, 0, 0, 0.45)
button.cap:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.75)
button.cap:Hide()
-- The key in the middle of its cap, held by its own center alone, as Run
-- History's run number in its box (the same size of type and of box): the
-- game lays a text held by two corners from the top of their box, whatever
-- SetJustifyV says, so a box the text's own size is never in the middle.
-- A pixel to the right: a letter's own room ends in a little space after it,
-- so its ink sits that much left of the room's middle (measured on a
-- screenshot, 2026-10-19).
button.key = button.cap:CreateFontString(nil, "OVERLAY")
button.key:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
button.key:SetPoint("CENTER", button.cap, "CENTER", 1, 0)
button.key:SetJustifyH("CENTER")
button.key:SetTextColor(1, 0.95, 0.80)
-- A glow behind the cap, breathing with the button's.
button.capGlow = button:CreateTexture(nil, "ARTWORK")
button.capGlow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
button.capGlow:SetBlendMode("ADD")
button.capGlow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
button.capGlow:SetPoint("CENTER", button.cap, "CENTER", 0, 0)
button.capGlow:Hide()

-- The key cap shown with its key (as wide as it needs), or away.
local function ShowKey(key)
	if key == button.shownKey then
		return
	end
	button.shownKey = key
	if key then
		button.key:SetText(key)
		local measured = button.key:GetStringWidth()
		-- Not drawn yet, a text measures nothing: measured again next time.
		if measured == 0 then
			button.shownKey = nil
		end
		-- Square for one letter; wider for a longer key, always an even width
		-- so its middle falls on a whole pixel.
		local width = math.max(20, math.ceil(measured) + 10)
		width = width + math.mod(width, 2)
		button.cap:SetWidth(width)
		button.cap:Show()
		button.capGlow:SetWidth(width + 26)
		button.capGlow:SetHeight(44)
		button.capGlow:Show()
		button.text:SetPoint("CENTER", button, "CENTER", -math.floor((width + 6) / 2), 0)
	else
		button.cap:Hide()
		button.capGlow:Hide()
		button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	end
end

local function Key()
	local key = GetBindingKey and GetBindingKey("AZS_OPENLEVELS")
	return key and key ~= "" and key or nil
end

-- The button in a color, as Run History's result box wears its own: filled
-- with the color darkened (breathing, in OnUpdate), a light edge, white
-- words, the glow in the color itself; the key cap and the sparks too.
local function Paint(b, r, g, bl)
	b.cr, b.cg, b.cb = r, g, bl
	b.fr, b.fg, b.fb = r * 0.55, g * 0.55, bl * 0.55
	b.er, b.eg, b.eb = r + (1 - r) * 0.55, g + (1 - g) * 0.55, bl + (1 - bl) * 0.55
	b.glow:SetVertexColor(r, g, bl)
	b.capGlow:SetVertexColor(r, g, bl)
	if not b.hot then
		b:SetBackdropBorderColor(b.er, b.eg, b.eb, 1)
	end
	b.text:SetTextColor(1, 1, 1)
	if b.sparkle and SurvivorUI_SparkleTint then
		SurvivorUI_SparkleTint(b.sparkle, r, g, bl)
	end
end

button.age = 0
button:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local breath = 0.5 + 0.5 * math.sin(this.age * 3)
	-- The color chosen (the Level Up! tab), whenever it changes.
	local r, g, bl = SurvivorUI_LevelUpColor()
	if r ~= this.cr or g ~= this.cg or bl ~= this.cb then
		Paint(this, r, g, bl)
	end
	-- The glow swells and brightens with the breath, the fill lifts, as the
	-- result box's do.
	this.glow:SetAlpha(math.min(1, (this.hot and 0.75 or 0.4) + 0.35 * breath))
	this.glow:SetWidth(this:GetWidth() + 56 + 16 * breath)
	this.glow:SetHeight(this:GetHeight() + 38 + 10 * breath)
	local lift = 0.82 + 0.18 * breath + (this.hot and 0.18 or 0)
	this:SetBackdropColor(math.min(1, this.fr * lift), math.min(1, this.fg * lift), math.min(1, this.fb * lift), 1)
	-- Alive as Run History's Victory box: sparks rising, stars and a shine
	-- (RunHistory.lua, loaded after this file: taken when it is there).
	local sparks = Settings().levelUpSparks ~= false
	if sparks and not this.sparkle and SurvivorUI_Sparkle then
		this.sparkle = SurvivorUI_Sparkle(this, "levelup")
		if SurvivorUI_SparkleTint then
			SurvivorUI_SparkleTint(this.sparkle, r, g, bl)
		end
	end
	if this.sparkle then
		if sparks then
			this.sparkle:Show()
		else
			this.sparkle:Hide()
		end
	end
	-- The key cap: its glow breathing too, and every 3 seconds a tap, as if
	-- pressed: a pixel down, its edge and key lit white.
	if this.cap:IsShown() then
		local tap = math.mod(this.age, 3) < 0.16
		this.capGlow:SetAlpha(0.2 + 0.3 * breath + (tap and 0.45 or 0))
		if tap ~= this.tapped then
			this.tapped = tap
			this.cap:SetPoint("RIGHT", this, "RIGHT", -6, tap and -1 or 0)
			if tap then
				this.cap:SetBackdropBorderColor(1, 1, 1, 1)
				this.key:SetTextColor(1, 1, 1)
			else
				local r, g, bl = this.cr or GOLD[1], this.cg or GOLD[2], this.cb or GOLD[3]
				this.cap:SetBackdropBorderColor(r, g, bl, 0.75)
				this.key:SetTextColor(r + (1 - r) * 0.8, g + (1 - g) * 0.8, bl + (1 - bl) * 0.8)
			end
		end
	end
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
	GameTooltip:SetText(stored == 1 and "1 level waiting" or stored.." levels waiting",
		this.cr or GOLD[1], this.cg or GOLD[2], this.cb or GOLD[3])
	GameTooltip:AddLine("Click to choose them, one after another"..(Key() and ", or press "..Key().."." or "."), 1, 1, 1, 1)
	GameTooltip:AddLine("Store Level-Ups: the game's Options, Controls, or /sui opt, Level Up!", 0.6, 0.6, 0.65, 1)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
	this.hot = nil
	this:SetBackdropBorderColor(this.er or GOLD[1], this.eg or GOLD[2], this.eb or GOLD[3], 1)
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
		ShowKey(Key())
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
