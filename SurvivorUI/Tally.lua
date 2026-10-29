-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: kills, gold and the next cache's price, under the minimap.
--
-- The game draws the same three numbers in a box of its own that no addon can
-- move. Where it shares them (its addon API, AZS_RUN), this line takes their
-- place, under the minimap, between it and the run tracker, and the game's box
-- is put away. /sui tally brings the game's box back.

if SurvivorUI_Standby then return end

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

-- Coins falling (Sounds\CoinShower.wav, our own, unless another is chosen)
-- each time the gold comes to pay for one cache more, bought or not: the next
-- at its price, the one after
-- at the price that follows, and so on; with the line off too (A coin drops
-- when you can pay: /sui opt, Kills & gold). On the change only: a reload with
-- the gold already there, or a price not told yet, says nothing.
-- The sound as chosen there (its Sound list): ours first (a shower of coins,
-- the default; one coin dropped, Sounds\CoinDrop.wav), then the game's
-- own coin and auction house sounds (in its patch.MPQ: played from there,
-- never shipped with the addon), each named for the list.
SurvivorUI_COIN_SOUNDS = {
	{ key = "hoard", name = "Survivor's Hoard", note = "ours, a pile of coins", path = "Interface\\AddOns\\SurvivorUI\\Sounds\\CoinShower.wav" },
	{ key = "ours", name = "Survivor's Coin", note = "ours, one coin", path = "Interface\\AddOns\\SurvivorUI\\Sounds\\CoinDrop.wav" },
	{ key = "auction", name = "Auctioneer's Farewell", note = "auction house, closing", path = "Sound\\interface\\AuctionWindowClose.wav" },
	{ key = "auctionOpen", name = "Auctioneer's Welcome", note = "auction house, opening", path = "Sound\\interface\\AuctionWindowOpen.wav" },
	{ key = "lootLarge", name = "Pile of Coins", note = "loot, many coins", path = "Sound\\interface\\LootCoinLarge.wav" },
	{ key = "lootSmall", name = "Handful of Coins", note = "loot, a few coins", path = "Sound\\interface\\LootCoinSmall.wav" },
	{ key = "purseOpen", name = "Purse Opens", note = "money window, opening", path = "Sound\\interface\\iMoneyDialogOpen.wav" },
	{ key = "purseClose", name = "Purse Snaps Shut", note = "money window, closing", path = "Sound\\interface\\iMoneyDialogClose.wav" },
}

-- The sound given (a key of the list), else the one chosen.
function SurvivorUI_CoinDrop(key)
	if not PlaySoundFile then
		return
	end
	key = key or Settings().coinSound
	local path = SurvivorUI_COIN_SOUNDS[1].path
	for index = 1, table.getn(SurvivorUI_COIN_SOUNDS) do
		if SurvivorUI_COIN_SOUNDS[index].key == key then
			path = SurvivorUI_COIN_SOUNDS[index].path
		end
	end
	PlaySoundFile(path)
end

-- And a rain of coins over the gold (Effects.lua's coins: the crit record's
-- Radiant, in gold coins), with the sound or on its own (Coins rain on the
-- gold: Kills & gold): over this line's coin and number (where the line
-- stands, out of a run), else the run tracker's coin, else over the hero.
local RAIN_HOLD = 1.3               -- seconds new coins keep falling
local RAIN_FADE = 0.5
local rain = CreateFrame("Frame", "SurvivorUICoinRain", UIParent)
rain:SetWidth(200)
rain:SetHeight(64)
rain:Hide()
rain:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local age = this.age
	if age >= RAIN_HOLD + RAIN_FADE then
		this:Hide()
		if SurvivorUI_RecordFxStop then
			SurvivorUI_RecordFxStop(this)
		end
		return
	end
	if SurvivorUI_RecordFxUpdate then
		SurvivorUI_RecordFxUpdate(this, age, arg1, age < RAIN_HOLD)
	end
	this:SetAlpha(age > RAIN_HOLD and 1 - (age - RAIN_HOLD) / RAIN_FADE or 1)
end)

-- onTop (the options' Try it): over every window, the options' too.
function SurvivorUI_CoinRain(onTop)
	if not SurvivorUI_RecordFxStart then
		return
	end
	local anchor, x, size = nil, 0, 1
	if slot:IsVisible() then
		anchor, x = slot, (ICON_GAP + (gold:GetStringWidth() or 0)) / 2
	elseif Settings().tally and holder:IsVisible() then
		anchor = holder
	else
		local tracker = getglobal("SurvivorUITracker")
		if tracker and tracker.coin and tracker.coin:IsVisible() then
			anchor, size = tracker.coin, 1.25
		end
	end
	rain:ClearAllPoints()
	if anchor then
		-- At the gold's size, under its numbers (the coins come over them).
		rain:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
		rain:SetFrameStrata(anchor:GetFrameStrata())
		rain:SetFrameLevel(math.max(0, anchor:GetFrameLevel() - 2))
		rain:SetPoint("CENTER", anchor, "CENTER", x, 0)
	else
		rain:SetScale(1)
		rain:SetFrameStrata("MEDIUM")
		rain:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		size = 1.5
	end
	if onTop then
		rain:SetFrameStrata("TOOLTIP")
	end
	rain.age = 0
	rain:SetAlpha(1)
	SurvivorUI_RecordFxStart(rain, "coins", size, 0, RAIN_HOLD + RAIN_FADE)
	rain:Show()
end

-- A value as the game's 32-bit floats hold it (rounded to 24 bits, a tie to
-- the even one).
local function Float32(value)
	if value == 0 then
		return 0
	end
	local mantissa, exponent = math.frexp(value)
	local scaled = mantissa * 16777216
	local whole = math.floor(scaled)
	local rest = scaled - whole
	if rest > 0.5 or (rest == 0.5 and math.mod(whole, 2) == 1) then
		whole = whole + 1
	end
	return math.ldexp(whole, exponent - 24)
end

-- A cache bought, the next one's price: the price times 1.3 plus 5, its
-- fraction dropped, in the game's 32-bit floats (read in its 0.119), so a
-- price of 90 makes 121 as in the game (the plain sum makes 122).
local RISE = 1.2999999523162842     -- 1.3 as a 32-bit float
local function NextPrice(price)
	return math.floor(Float32(Float32(price * RISE) + 5))
end

-- The caches the gold pays for, one after another at the rising price.
local function Payable(gold, price)
	local count = 0
	while price > 0 and gold >= price and count < 99 do
		gold = gold - price
		price = NextPrice(price)
		count = count + 1
	end
	return count
end

local payable                       -- at the last look; nil: not known yet
local function WatchCoin(running)
	local cost = running and tonumber(AZS_RUN.chest) or 0
	if cost <= 0 then
		payable = nil
		return
	end
	local count = Payable(tonumber(AZS_RUN.gold) or 0, cost)
	if payable and count > payable then
		if Settings().coinDrop ~= false then
			SurvivorUI_CoinDrop()
		end
		if Settings().coinRain ~= false then
			SurvivorUI_CoinRain()
		end
	end
	payable = count
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
	local running = Running()
	WatchCoin(running)
	if not (settings.tally and running) then
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
