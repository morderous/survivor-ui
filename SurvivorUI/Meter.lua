-- Survivor UI: the damage meter.
--
-- The game's own meter, drawn again from the numbers it shares (its addon API,
-- AZS_GetMeter): one flat bar per source of damage, the most first, each in a
-- color of its own and a talent's or amulet's own damage in blue, as in the
-- game's (its card says it is a proc). Hover a line for its card: its damage, share and damage per second,
-- and its critical strikes and normal hits from the combat log.
--
-- Reset clears the crits; the damage is the game's, for the whole run. Its
-- size holds through a run: up to ten lines, fewer on a small screen. Hold Alt
-- and drag to move. The game's own meter is put away while this one is on;
-- /sui meter brings it back. Needs the API; without it nothing shows.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 228
local BAR_HEIGHT = 16
local BAR_GAP = 2
local MAX_LINES = 10

-- One color per source, handed out in the order they first show.
local PALETTE = {
	{ 0.86, 0.24, 0.24 }, { 0.26, 0.52, 0.96 }, { 0.93, 0.76, 0.20 }, { 0.30, 0.78, 0.45 },
	{ 0.70, 0.36, 0.90 }, { 0.95, 0.52, 0.18 }, { 0.25, 0.80, 0.82 }, { 0.90, 0.40, 0.65 },
	{ 0.62, 0.42, 0.24 }, { 0.60, 0.70, 0.85 },
}
local PROC_COLOR = { 0.44, 0.84, 1.00 }

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.meter == nil then
		SurvivorUIDB.meter = true
	end
	return SurvivorUIDB
end

local function Num(value)
	return tonumber(value) or 0
end

-- 950, 1.2k, 3.4m
local function Short(value)
	if value >= 1000000 then
		return string.format("%.2fm", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
end

local function Running()
	if not (AZS_GetPhase and AZS_GetMeter) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

-- On, and the game sharing its meter: the run panel asks, to leave its crit
-- list out.
function SurvivorUI_MeterActive()
	return Settings().meter and AZS_GetMeter ~= nil
end

------------------------------------------------------------------------------
-- The frame: a title line, then room for every bar from the start, so its size
-- holds through a run. At the bottom of the right column, under the run panel.

local meter = CreateFrame("Frame", "SurvivorUIMeter", UIParent)
meter:SetWidth(WIDTH + 8)
meter:SetHeight(24 + MAX_LINES * (BAR_HEIGHT + BAR_GAP))
meter:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
meter:SetBackdrop({ bgFile = FLAT })
-- The right column's one shade, as the tracker and the run panel wear it.
meter:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
meter:SetMovable(true)
meter:EnableMouse(true)
meter:RegisterForDrag("LeftButton")
meter:Hide()

local function SavePlace()
	local settings = Settings()
	settings.meterRight = math.floor(meter:GetRight() + 0.5)
	settings.meterBottom = math.floor(meter:GetBottom() + 0.5)
end

local shownLines = MAX_LINES

local function SetLines(count)
	if count ~= shownLines then
		shownLines = count
		meter:SetHeight(24 + count * (BAR_HEIGHT + BAR_GAP))
	end
end

-- The saved place, with every line; else the right column, under the run panel
-- (or the run tracker), with as many lines as fit above the screen's bottom,
-- three at least. A small screen gets a shorter meter rather than an overlap.
-- The size follows the layout, never the numbers, so it holds through a run.
-- What the meter hangs from, last time: it is seated again only when that
-- changes, so a drag in progress is never pulled back.
local seatedOn

local function Seat(key, point, relative, relativePoint, x, y)
	if seatedOn ~= key then
		seatedOn = key
		meter:ClearAllPoints()
		meter:SetPoint(point, relative, relativePoint, x, y)
	end
end

local function Fit()
	local settings = Settings()
	if settings.meterRight then
		Seat("saved"..settings.meterRight..","..settings.meterBottom, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", settings.meterRight, settings.meterBottom)
		SetLines(MAX_LINES)
		return
	end
	local run, tracker = SurvivorUIRun, SurvivorUITracker
	local above, shift = nil, 0
	if run and run:IsShown() and run:GetBottom() then
		above = run
	elseif tracker and tracker:GetBottom() then
		above, shift = tracker, 8
	end
	if not above then
		Seat("screen", "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -12, 40)
		SetLines(MAX_LINES)
		return
	end
	Seat(above:GetName(), "TOPRIGHT", above, "BOTTOMRIGHT", shift, -10)
	local room = above:GetBottom() - 10 - 8
	local fit = math.floor((room - 24) / (BAR_HEIGHT + BAR_GAP))
	SetLines(math.max(3, math.min(MAX_LINES, fit)))
end

local function StartMove()
	if IsAltKeyDown() then
		meter:StartMoving()
	end
end

local function StopMove()
	meter:StopMovingOrSizing()
	SavePlace()
end

meter:SetScript("OnDragStart", StartMove)
meter:SetScript("OnDragStop", StopMove)

meter.title = meter:CreateFontString(nil, "OVERLAY")
meter.title:SetFont(FONT, 11 + FONT_BUMP, "OUTLINE")
meter.title:SetPoint("TOPLEFT", meter, "TOPLEFT", 5, -5)
meter.title:SetTextColor(1, 0.82, 0)
meter.title:SetText("Damage Done")

-- The title says what this meter leaves to the game's: healing and boss damage.
local titleHover = CreateFrame("Frame", nil, meter)
titleHover:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, 0)
titleHover:SetWidth(110)
titleHover:SetHeight(20)
titleHover:EnableMouse(true)
titleHover:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText("Damage Done", 1, 0.82, 0)
	GameTooltip:AddLine("The game's own numbers, for the whole run. Hover a line for its crits.", 1, 1, 1, 1)
	GameTooltip:AddLine("Healing and damage to bosses are in the game's own meter: type /sui meter to switch to it, and again to come back.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Hold Alt and drag to move.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
titleHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
titleHover:RegisterForDrag("LeftButton")
titleHover:SetScript("OnDragStart", StartMove)
titleHover:SetScript("OnDragStop", StopMove)
meter.total = meter:CreateFontString(nil, "OVERLAY")
meter.total:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
meter.total:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -42, -6)
meter.total:SetTextColor(0.7, 0.7, 0.7)

local reset = CreateFrame("Button", nil, meter)
reset:SetWidth(32)
reset:SetHeight(12)
reset:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -5, -5)
reset.text = reset:CreateFontString(nil, "OVERLAY")
reset.text:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
reset.text:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
reset.text:SetText("Reset")
reset.text:SetTextColor(0.6, 0.6, 0.6)
reset:SetScript("OnEnter", function()
	this.text:SetTextColor(1, 1, 1)
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText("Clears the crits.", 1, 1, 1)
	GameTooltip:AddLine("The damage is the game's own, for the whole run.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)
reset:SetScript("OnClick", function()
	if SurvivorUI_ResetRun then
		SurvivorUI_ResetRun()
	end
end)

------------------------------------------------------------------------------
-- The bars.

local colors = {}               -- [source] = palette entry
local colorsGiven = 0
local bars = {}

local function ColorOf(name, proc)
	if proc then
		return PROC_COLOR
	end
	if not colors[name] then
		colorsGiven = colorsGiven + 1
		colors[name] = PALETTE[math.mod(colorsGiven - 1, table.getn(PALETTE)) + 1]
	end
	return colors[name]
end

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("StatusBar", nil, meter)
	bar:SetWidth(WIDTH)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)

	bar.backing = bar:CreateTexture(nil, "BACKGROUND")
	bar.backing:SetTexture(FLAT)
	bar.backing:SetVertexColor(0.10, 0.10, 0.13, 0.9)
	bar.backing:SetAllPoints(bar)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
	-- Room for the numbers on the right: damage and share.
	bar.name:SetWidth(WIDTH - 76)
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	bar.value = bar:CreateFontString(nil, "OVERLAY")
	bar.value:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.value:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	bar.value:SetTextColor(1, 1, 1)

	-- The crit card sits beside the whole meter, on its left, tops together.
	bar.cardFrame = meter
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function()
		if SurvivorUI_CritCardShow then
			SurvivorUI_CritCardShow(this)
		end
	end)
	bar:SetScript("OnLeave", function()
		if SurvivorUI_CritCardHide then
			SurvivorUI_CritCardHide()
		end
	end)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", StartMove)
	bar:SetScript("OnDragStop", StopMove)

	bars[index] = bar
	return bar
end

local function Draw()
	local lines, total, dps = AZS_GetMeter()
	lines = lines or {}
	meter.total:SetText(Short(Num(total)).."  |cffffffff"..Short(Num(dps)).."|r dps")

	local count = math.min(shownLines, table.getn(lines))
	local top = count > 0 and Num(lines[1].dmg) or 0
	for index = 1, count do
		local line = lines[index]
		local name = line.name or "?"
		local proc = Num(line.proc) == 1
		local color = ColorOf(name, proc)
		local bar = Bar(index)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -20 - (index - 1) * (BAR_HEIGHT + BAR_GAP))
		bar:SetValue(top > 0 and Num(line.dmg) / top or 0)
		bar:SetStatusBarColor(color[1], color[2], color[3], 0.85)
		bar.ability = name
		bar.color = color

		-- A talent's or amulet's own damage says so, as the game's meter does.
		bar.name:SetText(index..". "..name..(proc and "  |cffc8e8ffproc|r" or ""))
		bar.value:SetText(Short(Num(line.dmg)).."  |cffb0b0b0"..math.floor(Num(line.share) * 100 + 0.5).."%|r")
		bar:Show()
	end
	for index = count + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].ability = nil
	end
end

local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	Fit()
	if Settings().meter and Running() then
		Draw()
		if not meter:IsShown() then
			meter:Show()
		end
	elseif meter:IsShown() then
		meter:Hide()
	end
end)

------------------------------------------------------------------------------
-- The game's own meter: away while this one is on. The setting is the game's
-- and is saved, so the addon remembers that it was the one to turn it off.

local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.meter then
		if AZS_IsHudShown("meter") then
			AZS_SetHudShown("meter", false)
			settings.hidGameMeter = true
		end
	elseif settings.hidGameMeter then
		AZS_SetHudShown("meter", true)
		settings.hidGameMeter = nil
	end
end

function SurvivorUI_ToggleMeter()
	local settings = Settings()
	settings.meter = not settings.meter
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.meter
		and "damage meter on; the game's own meter is put away."
		or "damage meter off; the game's own is back, with its healing and boss damage."))
end

-- The game's tooltip for units and the world sits by default in the bottom
-- right corner, where the meter is: while the meter shows, it opens beside it,
-- on its left, bottoms together.
local stockDefaultAnchor = GameTooltip_SetDefaultAnchor
if stockDefaultAnchor then
	GameTooltip_SetDefaultAnchor = function(tooltip, parent)
		stockDefaultAnchor(tooltip, parent)
		if meter:IsVisible() and tooltip then
			tooltip:ClearAllPoints()
			tooltip:SetPoint("BOTTOMRIGHT", meter, "BOTTOMLEFT", -6, 0)
		end
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	seatedOn = nil
	Fit()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(meter, "Damage meter", SavePlace, nil, function()
		seatedOn = nil
		Fit()
	end)
end
