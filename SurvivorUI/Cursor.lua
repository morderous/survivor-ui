-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the mouse cursor in a color of yours (the options, Global:
-- Mouse cursor).
--
-- Two shapes:
--   Gauntlet  the game's own cursors (its gauntlet, its sword over an enemy,
--             its glowing gauntlet while a spell waits for its target), read
--             from the game's own files and drawn by the addon over
--             everything, tinted, in any size; the game's cursor made clear
--   Arrow     an arrow of ours, handed to the game as its cursor (a 32 x 32
--             picture, the click at its top left pixel; drawn ahead in each
--             color and size, Art\Cursor\<Size><Color>.tga)
-- The game writes its cursor again on every frame the mouse is over the
-- world, so ours is handed over on every frame too. While the cursor holds
-- something, the game's own shows.
--
-- And a few touches in the same color, in the records' manner (Effects.lua):
-- a soft glow breathing round it, motes trailing off as it moves, a ring and
-- sparks where it clicks the world.

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local GAME = "Interface\\Cursor\\"
local BLANK = ART.."Cursor\\Blank"
local MOTES = 24
local SPARKS = 10

-- For the options.
SurvivorUI_CURSOR_SHAPES = {
	{ key = "gauntlet", name = "Gauntlet", note = "the game's" },
	{ key = "arrow", name = "Arrow", note = "ours" },
}
SurvivorUI_CURSOR_COLORS = {
	{ key = "White", name = "White", color = { 0.93, 0.93, 0.95 } },
	{ key = "Gold", name = "Gold", color = { 1.00, 0.78, 0.16 } },
	{ key = "Green", name = "Green", color = { 0.35, 0.90, 0.55 } },
	{ key = "Blue", name = "Blue", color = { 0.31, 0.71, 1.00 } },
	{ key = "Red", name = "Red", color = { 1.00, 0.33, 0.29 } },
	{ key = "Purple", name = "Purple", color = { 0.69, 0.43, 1.00 } },
	{ key = "class", name = "Class color" },
}
SurvivorUI_CURSOR_SIZES = {
	{ key = "Small", name = "Small" },
	{ key = "Medium", name = "Medium" },
	{ key = "Large", name = "Large" },
}
-- The gauntlet's size on screen, in pixels (the game's own is 32).
local GAUNTLET_PIXELS = { Small = 26, Medium = 32, Large = 46 }

-- The arrow's file for a class, by the game's class token.
local CLASS_FILES = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
	SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

function SurvivorUI_CursorOn()
	return Settings().cursorOn == true
end

function SurvivorUI_CursorShape()
	return Settings().cursorShape or "gauntlet"
end

function SurvivorUI_CursorColor()
	return Settings().cursorColor or "White"
end

function SurvivorUI_CursorSize()
	return Settings().cursorSize or "Medium"
end

function SurvivorUI_CursorFx()
	return Settings().cursorFx ~= false
end

local tint = { 1, 1, 1 }        -- the color: the gauntlet's tint, the touches' light
local arrowPath                 -- the arrow's picture, once worked out
local handed                    -- the game's cursor is ours (to give back when it stops)

local function WorkOut()
	local color = SurvivorUI_CursorColor()
	local file = color
	if color == "class" then
		local _, class = UnitClass("player")
		tint[1], tint[2], tint[3] = SurvivorUI_ClassColor(class)
		file = class and CLASS_FILES[class] or "White"
	elseif color == "White" then
		-- The gauntlet as the game draws it.
		tint[1], tint[2], tint[3] = 1, 1, 1
	else
		for index = 1, table.getn(SurvivorUI_CURSOR_COLORS) do
			local entry = SurvivorUI_CURSOR_COLORS[index]
			if entry.key == color then
				tint[1], tint[2], tint[3] = entry.color[1], entry.color[2], entry.color[3]
			end
		end
	end
	arrowPath = ART.."Cursor\\"..SurvivorUI_CursorSize()..file
	-- A tint darkens the silver it lies on: its strongest part brought up to
	-- full, so a deep color (the warlock's) keeps the gauntlet bright.
	local top = math.max(tint[1], tint[2], tint[3])
	if top > 0 then
		tint[1], tint[2], tint[3] = tint[1] / top, tint[2] / top, tint[3] / top
	end
end

------------------------------------------------------------------------------
-- The pieces, over everything: the gauntlet, the glow, the motes, the sparks
-- and the ring, placed in UIParent's units.

local layer = CreateFrame("Frame", "SurvivorUICursor", UIParent)
layer:SetFrameStrata("TOOLTIP")
layer:SetAllPoints(UIParent)
layer:Hide()

local function Piece(art, drawLayer, add)
	local texture = layer:CreateTexture(nil, drawLayer)
	texture:SetTexture(art)
	if add then
		texture:SetBlendMode("ADD")
	end
	texture:Hide()
	return texture
end

local glow = Piece(ART.."PaceGlow", "BACKGROUND", true)
local hand = Piece(GAME.."Point", "OVERLAY", false)
local ring = Piece(ART.."Ring", "ARTWORK", true)
local motes, sparks = {}, {}
for index = 1, MOTES do
	motes[index] = Piece(ART.."PaceDot", "ARTWORK", true)
end
for index = 1, SPARKS do
	sparks[index] = Piece(ART.."LightStar", "ARTWORK", true)
end

-- Pixels on screen to UIParent's units: the window's height in pixels from
-- the game's own setting, else 1080.
local function PixelsPerUnit()
	local _, _, height = string.find(GetCVar and GetCVar("gxResolution") or "", "%d+x(%d+)")
	return (tonumber(height) or 1080) / GetScreenHeight()
end

local function Light(amount)
	return tint[1] + (1 - tint[1]) * amount, tint[2] + (1 - tint[2]) * amount, tint[3] + (1 - tint[3]) * amount
end

-- A mote or a spark: the first one free of its pool.
local function Free(pool)
	for index = 1, table.getn(pool) do
		if not pool[index].p then
			return pool[index]
		end
	end
end

local function Fly(pool, elapsed, unit)
	for index = 1, table.getn(pool) do
		local texture = pool[index]
		local p = texture.p
		if p then
			p.life = p.life + elapsed
			local part = p.life / p.length
			if part >= 1 then
				texture.p = nil
				texture:Hide()
			else
				p.vx, p.vy = p.vx * (1 - 2.5 * elapsed), p.vy * (1 - 2.5 * elapsed) + p.lift * elapsed
				p.x, p.y = p.x + p.vx * elapsed, p.y + p.vy * elapsed
				local size = p.size * (1 - 0.5 * part) / unit
				texture:SetWidth(size)
				texture:SetHeight(size)
				texture:ClearAllPoints()
				texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
				texture:SetVertexColor(Light(p.light))
				texture:SetAlpha((1 - part * part) * p.alpha)
				texture:Show()
			end
		end
	end
end

local last = {}                 -- the cursor's last place, for the motes
local clock, owed = 0, 0        -- the glow's breath; motes owed for the way moved
local burst                     -- a click to answer: its place

local function Touches(x, y, elapsed, unit, middleX, middleY)
	clock = clock + elapsed
	local size = 54 / unit
	glow:SetWidth(size)
	glow:SetHeight(size)
	glow:ClearAllPoints()
	glow:SetPoint("CENTER", UIParent, "BOTTOMLEFT", middleX, middleY)
	glow:SetVertexColor(tint[1], tint[2], tint[3])
	glow:SetAlpha(0.20 + 0.08 * math.sin(clock * 2.4))
	glow:Show()

	-- A mote for every few pixels moved, from the tip, drifting up a little.
	if last.x then
		local dx, dy = (x - last.x) * unit, (y - last.y) * unit
		owed = math.min(6, owed + math.sqrt(dx * dx + dy * dy) / 14)
		while owed >= 1 do
			owed = owed - 1
			local texture = Free(motes)
			if not texture then
				break
			end
			texture.p = { x = x + (math.random() - 0.5) * 6 / unit, y = y + (math.random() - 0.5) * 6 / unit,
				vx = (math.random() - 0.5) * 30 / unit, vy = (math.random() - 0.2) * 30 / unit, lift = 20 / unit,
				life = 0, length = 0.45 + math.random() * 0.35, size = 5 + math.random() * 4, light = 0.45, alpha = 0.9 }
		end
	end
	last.x, last.y = x, y

	if burst then
		ring.life = 0
		ring.x, ring.y = burst.x, burst.y
		for index = 1, SPARKS do
			local texture = sparks[index]
			local angle = (index / SPARKS) * 6.283 + math.random() * 0.5
			local speed = (90 + math.random() * 70) / unit
			texture.p = { x = burst.x, y = burst.y, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
				lift = -30 / unit, life = 0, length = 0.35 + math.random() * 0.2, size = 9 + math.random() * 5,
				light = 0.3, alpha = 1 }
		end
		burst = nil
	end
	if ring.life then
		ring.life = ring.life + elapsed
		local part = ring.life / 0.35
		if part >= 1 then
			ring.life = nil
			ring:Hide()
		else
			local width = (8 + 46 * part) / unit
			ring:SetWidth(width)
			ring:SetHeight(width)
			ring:ClearAllPoints()
			ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ring.x, ring.y)
			ring:SetVertexColor(Light(0.2))
			ring:SetAlpha(1 - part)
			ring:Show()
		end
	end
	Fly(motes, elapsed, unit)
	Fly(sparks, elapsed, unit)
end

local function HideTouches()
	glow:Hide()
	ring:Hide()
	ring.life = nil
	for index = 1, MOTES do
		motes[index].p = nil
		motes[index]:Hide()
	end
	for index = 1, SPARKS do
		sparks[index].p = nil
		sparks[index]:Hide()
	end
	last.x = nil
end

------------------------------------------------------------------------------
-- Every frame.

-- What only the game's own cursor shows: something held.
local function Holding()
	return (CursorHasItem and CursorHasItem())
		or (CursorHasSpell and CursorHasSpell())
		or (CursorHasMoney and CursorHasMoney())
end

-- The game draws its own screens over every addon's (paused, the cards, the
-- end of a run): the gauntlet drawn here would be under them, so it is drawn
-- only while the run is played or about to be (the arrow, the game's own
-- cursor, shows over them).
local function Played()
	local phase = AZS_RUN and AZS_RUN.ph
	return phase == "playing" or phase == "ready"
end

local function GiveBack()
	if handed then
		handed = nil
		ResetCursor()
	end
	hand:Hide()
	HideTouches()
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	local gauntlet = SurvivorUI_CursorShape() == "gauntlet"
	local targeting = SpellIsTargeting and SpellIsTargeting()
	-- The arrow has no look for a spell's target: the game's own then.
	if Holding() or not UIParent:IsVisible() or (targeting and not gauntlet) or (gauntlet and not Played()) then
		GiveBack()
		return
	end
	if not SetCursor(gauntlet and BLANK or arrowPath) then
		-- A picture the game would not take: the game's cursor, and no more tries.
		this:Hide()
		GiveBack()
		layer:Hide()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: the cursor's picture did not load.")
		return
	end
	handed = true

	local unit = PixelsPerUnit()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	x, y = x / scale, y / scale
	local size = 32 / unit
	if gauntlet then
		local file = "Point"
		if targeting then
			file = "Cast"
		elseif UnitExists("mouseover") and UnitCanAttack("player", "mouseover") then
			file = "Attack"
		end
		if hand.file ~= file then
			hand.file = file
			hand:SetTexture(GAME..file)
		end
		size = GAUNTLET_PIXELS[SurvivorUI_CursorSize()] / unit
		hand:SetWidth(size)
		hand:SetHeight(size)
		hand:ClearAllPoints()
		hand:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		hand:SetVertexColor(tint[1], tint[2], tint[3])
		hand:Show()
	else
		hand:Hide()
	end
	if SurvivorUI_CursorFx() then
		Touches(x, y, arg1, unit, x + size * 0.42, y - size * 0.42)
	else
		HideTouches()
	end
end)

-- A click on the world (WorldFrame hears it and lets it through): the ring.
if WorldFrame then
	local stockDown = WorldFrame:GetScript("OnMouseDown")
	WorldFrame:SetScript("OnMouseDown", function()
		if stockDown then
			stockDown()
		end
		if driver:IsShown() and SurvivorUI_CursorFx() then
			local x, y = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			burst = { x = x / scale, y = y / scale }
		end
	end)
end

local function Apply()
	if SurvivorUI_CursorOn() then
		WorkOut()
		layer:Show()
		driver:Show()
	else
		driver:Hide()
		GiveBack()
		layer:Hide()
	end
end

function SurvivorUI_SetCursorOn(on)
	Settings().cursorOn = on and true or nil
	Apply()
end

function SurvivorUI_SetCursorShape(key)
	Settings().cursorShape = key ~= "gauntlet" and key or nil
	hand:Hide()
	Apply()
end

function SurvivorUI_SetCursorColor(key)
	Settings().cursorColor = key ~= "White" and key or nil
	Apply()
end

function SurvivorUI_SetCursorSize(key)
	Settings().cursorSize = key ~= "Medium" and key or nil
	Apply()
end

function SurvivorUI_SetCursorFx(on)
	Settings().cursorFx = (not on) and false or nil
	Apply()
end

-- The class is known once the world is in.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Apply)
