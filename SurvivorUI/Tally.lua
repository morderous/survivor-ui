-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: kills, gold and the next cache's price, under the minimap.
--
-- The game draws the same three numbers in a box of its own that no addon can
-- move. Where it shares them (its addon API, AZS_RUN), this line takes their
-- place, under the minimap, between it and the run tracker, and the game's box
-- is put away. /sui tally brings the game's box back.

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local row = getglobal("SurvivorUIRow")
if not row then
	return
end

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.tally == nil then
		SurvivorUIDB.tally = true
	end
	return SurvivorUIDB
end

-- 2,054
local function Thousands(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local result = ""
	while string.len(text) > 3 do
		result = ","..string.sub(text, -3)..result
		text = string.sub(text, 1, -4)
	end
	return text..result
end

-- The line sits on a holder of its own, under the minimap (or under the
-- action bar, as chosen: Panels) until moved (Mover.lua).
local holder = CreateFrame("Frame", "SurvivorUITallyFrame", UIParent)
holder:SetWidth(160)
holder:SetHeight(16)
holder:SetMovable(true)

local function DefaultPlace()
	local underBar = SurvivorUIDB and SurvivorUIDB.tallyPlace == "bar"
	if Minimap and not underBar then
		holder:SetPoint("TOP", Minimap, "BOTTOM", 0, -5)
	else
		holder:SetPoint("TOP", row, "BOTTOM", 0, -12)
	end
end
DefaultPlace()

-- A red skull and the kills, then the run tracker's coin (gold only) and the
-- gold against the next cache's price: (skull) 220   (coin) 114/20. Or as
-- chosen (Kills & gold tab): the gold first, the kills or the gold alone, and the gold
-- and the cache apart, the cache's price by the minimap's chest. The line
-- keeps itself centred as the numbers grow.
local ICON_SIZE = 14
local ICON_GAP = 3              -- between an icon and its number
local GROUP_GAP = 16            -- between two icons with their numbers

local skull = holder:CreateTexture(nil, "OVERLAY")
skull:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\Kills")
skull:SetWidth(ICON_SIZE)
skull:SetHeight(ICON_SIZE)
skull:Hide()

local line = holder:CreateFontString("SurvivorUITally", "OVERLAY")
line:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
line:SetPoint("LEFT", skull, "RIGHT", ICON_GAP, 0)
line:Hide()

-- The coin's place, a square of its size: the coin sits in its middle, so its
-- swell as it shines leaves the numbers where they are.
local slot = CreateFrame("Frame", nil, holder)
slot:SetWidth(ICON_SIZE)
slot:SetHeight(ICON_SIZE)
slot:Hide()

local coin = slot:CreateTexture(nil, "ARTWORK")
coin:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\Coin")
coin:SetPoint("CENTER", slot, "CENTER", 0, 0)
coin:SetWidth(ICON_SIZE)
coin:SetHeight(ICON_SIZE)

-- Its shine, as the run tracker's coin wears it: the kill pace orb's glow and
-- spark (Pace.lua) in gold.
local glow = slot:CreateTexture(nil, "BACKGROUND")
glow:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceGlow")
glow:SetBlendMode("ADD")
glow:SetVertexColor(1, 0.78, 0.20)
glow:SetPoint("CENTER", slot, "CENTER", 0, 0)
glow:Hide()
local spark = slot:CreateTexture(nil, "OVERLAY")
spark:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PaceSpark")
spark:SetBlendMode("ADD")
spark:SetVertexColor(1, 0.95, 0.70)
spark:SetPoint("CENTER", slot, "TOPRIGHT", -2, -2)
spark:Hide()

local gold = holder:CreateFontString("SurvivorUITallyGold", "OVERLAY")
gold:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
gold:SetPoint("LEFT", slot, "RIGHT", ICON_GAP, 0)
gold:Hide()

-- The cache's price on its own, by the minimap's chest.
local chest = holder:CreateTexture(nil, "OVERLAY")
chest:SetTexture("Interface\\AddOns\\SurvivorUI\\Art\\PinCache")
chest:SetWidth(ICON_SIZE)
chest:SetHeight(ICON_SIZE)
chest:Hide()

local cache = holder:CreateFontString("SurvivorUITallyCache", "OVERLAY")
cache:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
cache:SetPoint("LEFT", chest, "RIGHT", ICON_GAP, 0)
cache:Hide()

-- The groups, an icon and its number each, and the layouts' orders.
local KILLS = { icon = skull, text = line }
local GOLD = { icon = slot, text = gold }
local CACHE = { icon = chest, text = cache }
local GROUPS = { KILLS, GOLD, CACHE }
local ORDERS = {
	killsGold = { KILLS, GOLD, CACHE },
	goldKills = { GOLD, CACHE, KILLS },
	kills = { KILLS },
	gold = { GOLD, CACHE },
}

-- While the cache can be paid the coin shines (the run tracker's switch,
-- "Shine when you can pay", is both coins'): a gold glow breathes behind it
-- and it brightens with the glow, a spark twinkles on its rim now and then,
-- and the moment the gold is first enough, a burst.
local SHINE_BREATH = 1.4            -- seconds a breath takes
local SPARK_EVERY = 2.2             -- seconds between two twinkles
local BURST = 0.7                   -- seconds the burst takes
slot:SetScript("OnUpdate", function()
	if not this.pays or (SurvivorUIDB and SurvivorUIDB.trackerCoinShine == false) then
		if not this.still then
			this.still = true
			glow:Hide()
			spark:Hide()
			coin:SetWidth(ICON_SIZE)
			coin:SetHeight(ICON_SIZE)
			coin:SetVertexColor(1, 1, 1)
		end
		return
	end
	this.still = nil
	local now = GetTime()
	local since = now - (this.paysSince or now)
	local burst = since < BURST and (1 - since / BURST) or 0
	local wave = (math.sin(now * 6.283 / SHINE_BREATH) + 1) / 2
	local size = ICON_SIZE * (2.4 + 0.6 * wave + 2.6 * burst)
	glow:SetWidth(size)
	glow:SetHeight(size)
	glow:SetAlpha(math.min(1, 0.45 + 0.45 * wave + burst))
	glow:Show()
	local grow = ICON_SIZE * (1 + 0.4 * burst)
	coin:SetWidth(grow)
	coin:SetHeight(grow)
	local bright = 0.8 + 0.2 * wave
	coin:SetVertexColor(bright, bright, bright)
	-- The twinkle: a quick flare on the rim, in the first fifth of its turn.
	local turn = math.mod(now, SPARK_EVERY) / SPARK_EVERY
	local twinkle = turn < 0.2 and math.sin(turn / 0.2 * 3.1416) or 0
	twinkle = math.max(twinkle, burst)
	if twinkle > 0.01 then
		local edge = ICON_SIZE * (0.6 + 0.9 * twinkle)
		spark:SetWidth(edge)
		spark:SetHeight(edge)
		spark:SetAlpha(twinkle)
		spark:Show()
	else
		spark:Hide()
	end
end)

-- The groups shown, in the layout's order (the cache's only with the gold and
-- the cache apart), laid out from the middle. The holder as wide as what it
-- shows: kept on the screen, a wider one under the minimap, by the screen's
-- edge, would be pushed aside, off its middle.
local function Lay(order, apart)
	local shown, total = {}, 0
	for index = 1, table.getn(order) do
		local group = order[index]
		if group ~= CACHE or apart then
			group.width = ICON_SIZE + ICON_GAP + (group.text:GetStringWidth() or 0)
			if table.getn(shown) > 0 then
				total = total + GROUP_GAP
			end
			total = total + group.width
			table.insert(shown, group)
		end
	end
	holder:SetWidth(math.floor(total + 8))
	local x = -total / 2
	for index = 1, table.getn(shown) do
		local group = shown[index]
		group.icon:ClearAllPoints()
		group.icon:SetPoint("LEFT", holder, "CENTER", x, 0)
		x = x + group.width + GROUP_GAP
	end
	return shown
end

-- Only the groups given shown; none with nil.
local function Shown(shown)
	for index = 1, table.getn(GROUPS) do
		GROUPS[index].icon:Hide()
		GROUPS[index].text:Hide()
	end
	for index = 1, table.getn(shown or {}) do
		shown[index].icon:Show()
		shown[index].text:Show()
	end
end

local function Running()
	if not (AZS_GetPhase and AZS_RUN) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.2 then
		return
	end
	elapsed = 0

	local settings = Settings()
	if not (settings.tally and Running()) then
		Shown(nil)
		return
	end
	-- The kills white; the gold bright, the cache's price a muted gold after
	-- the slash, or a pale gold by its chest.
	line:SetText("|cffffffff"..Thousands(AZS_RUN.kills).."|r")
	-- The coin shines from the moment the gold pays for the next cache.
	local cost = tonumber(AZS_RUN.chest) or 0
	local pays = cost > 0 and (tonumber(AZS_RUN.gold) or 0) >= cost
	if pays and not slot.pays then
		slot.paysSince = GetTime()
	end
	slot.pays = pays
	local apart = settings.tallySplit
	if apart then
		gold:SetText("|cffffd24d"..Thousands(AZS_RUN.gold).."|r")
		cache:SetText("|cffe6cf8f"..Thousands(AZS_RUN.chest).."|r")
	else
		gold:SetText("|cffffd24d"..Thousands(AZS_RUN.gold).."|r|cff9a9a9a/|r|cffb39a5c"..Thousands(AZS_RUN.chest).."|r")
	end
	Shown(Lay(ORDERS[settings.tallyLayout] or ORDERS.killsGold, apart))
end)

-- The game's own box: away while this line is on. The setting is the game's
-- and is saved, so the addon remembers that it was the one to turn it off.
local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.tally or settings.noGameTally then
		if AZS_IsHudShown("tally") then
			AZS_SetHudShown("tally", false)
			settings.hidGameTally = true
		end
	elseif settings.hidGameTally then
		AZS_SetHudShown("tally", true)
		settings.hidGameTally = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.tally = ApplyGameHud

function SurvivorUI_Tally()
	local settings = Settings()
	settings.tally = not settings.tally
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.tally
		and "the kills and gold line is on; the Default box is put away."
		or (settings.noGameTally and "the kills and gold line is off, and the Default box stays away." or "the Default kills and gold box is back.")))
end

-- Its place: under the minimap or the action bar, following it, until moved.
-- Moved, it is kept by the middle of its top, so it stays centred there as the
-- numbers grow (the holder is as wide as what it shows). A place saved before
-- by the left edge, when the holder was 320 wide, is read once as its middle.
local OLD_HALF = 160

local function RestorePlace()
	holder:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.tallyLeft and db.tallyTop and not db.tallyX then
		db.tallyX = db.tallyLeft + OLD_HALF
	end
	if db then
		db.tallyLeft = nil
	end
	if db and db.tallyX and db.tallyTop then
		holder:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.tallyX, db.tallyTop)
	else
		DefaultPlace()
	end
end

local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.tallyX = math.floor(holder:GetLeft() + holder:GetWidth() / 2 + 0.5)
	SurvivorUIDB.tallyTop = math.floor(holder:GetTop() + 0.5)
	SurvivorUIDB.tallyLeft = nil
	-- Seated by its middle at once: a drag leaves it held by its corner.
	RestorePlace()
end

-- Its place for the options (Kills & gold tab): "minimap", "bar" or "off". A place
-- chosen there wins over one it was dragged to.
function SurvivorUI_TallyPlace()
	local settings = Settings()
	if not settings.tally then
		return "off"
	end
	return settings.tallyPlace == "bar" and "bar" or "minimap"
end

function SurvivorUI_SetTallyPlace(place)
	local settings = Settings()
	if place == "off" then
		settings.tally = false
	else
		settings.tallyPlace = place
		settings.tallyLeft, settings.tallyX, settings.tallyTop = nil, nil, nil
		RestorePlace()
	end
	ApplyGameHud()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Kills and gold line", SavePlace, nil, RestorePlace)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)
