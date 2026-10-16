-- Survivor UI: loot log.
--
-- A small list in the top left corner of what the run has dropped, newest on
-- top, each with the run second it came. The game's addon API says nothing
-- about loot, so this reads the chat window's "You receive loot: [item]" lines.
--
-- Hover an item for its tooltip. Hold Alt and drag to move; /sui loot hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 200
local MAX_LINES = 8

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.lootLog == nil then
		SurvivorUIDB.lootLog = true
	end
	return SurvivorUIDB
end

local function RunSeconds()
	if AZS_GetRunTime then
		local seconds = AZS_GetRunTime()
		if seconds then
			return seconds
		end
	end
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

------------------------------------------------------------------------------
-- The frame: a small title, then a flat bar per item in its quality's color,
-- like the boss bars, with the name inside and the run second on the right.

local BAR_HEIGHT = 18
local BAR_GAP = 3
local EPIC = { 0.64, 0.21, 0.93 }

local log = CreateFrame("Frame", "SurvivorUILoot", UIParent)
log:SetWidth(WIDTH)
log:SetHeight(16)
log:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
log:SetMovable(true)
log:EnableMouse(true)
log:RegisterForDrag("LeftButton")
log:Hide()

local function SavePlace()
	local settings = Settings()
	settings.lootLeft = math.floor(log:GetLeft() + 0.5)
	settings.lootTop = math.floor(log:GetTop() + 0.5)
end

log:SetScript("OnDragStart", function() if IsAltKeyDown() then log:StartMoving() end end)
log:SetScript("OnDragStop", function() log:StopMovingOrSizing() SavePlace() end)

log.title = log:CreateFontString(nil, "OVERLAY")
log.title:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
log.title:SetPoint("TOPLEFT", log, "TOPLEFT", 1, 0)
log.title:SetTextColor(0.75, 0.75, 0.75)
log.title:SetText("Loot")

log.empty = log:CreateFontString(nil, "OVERLAY")
log.empty:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
log.empty:SetPoint("TOPLEFT", log, "TOPLEFT", 1, -14)
log.empty:SetTextColor(0.5, 0.5, 0.5)
log.empty:SetText("Nothing yet")

local entries = {}              -- newest first: { item, name, color, count, new, at }
local bars = {}

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("Button", nil, log)
	bar:SetWidth(WIDTH)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetPoint("TOPLEFT", log, "TOPLEFT", 0, -15 - (index - 1) * (BAR_HEIGHT + BAR_GAP))

	bar.border = bar:CreateTexture(nil, "BACKGROUND")
	bar.border:SetTexture(FLAT)
	bar.border:SetVertexColor(0, 0, 0, 1)
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)

	bar.fill = bar:CreateTexture(nil, "BORDER")
	bar.fill:SetTexture(FLAT)
	bar.fill:SetAllPoints(bar)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.name:SetWidth(WIDTH - 48)
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	bar.at = bar:CreateFontString(nil, "OVERLAY")
	bar.at:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	bar.at:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	bar.at:SetTextColor(0.85, 0.85, 0.85)

	bar:SetScript("OnEnter", function()
		if this.item then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(this.item)
			GameTooltip:Show()
		end
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() if IsAltKeyDown() then log:StartMoving() end end)
	bar:SetScript("OnDragStop", function() log:StopMovingOrSizing() SavePlace() end)
	bars[index] = bar
	return bar
end

-- "ffa335ee" into 0.64, 0.21, 0.93; purple, an epic's color, when unknown.
local function QualityColor(hex)
	if not hex or string.len(hex) ~= 8 then
		return EPIC
	end
	local function Part(from)
		return (tonumber(string.sub(hex, from, from + 1), 16) or 0) / 255
	end
	return { Part(3), Part(5), Part(7) }
end

local function Draw()
	local count = math.min(MAX_LINES, table.getn(entries))
	for index = 1, count do
		local entry = entries[index]
		local bar = Bar(index)
		local color = QualityColor(entry.color)
		bar.item = entry.item
		bar.fill:SetVertexColor(color[1], color[2], color[3], 0.75)
		local text = entry.name
		if entry.count and entry.count > 1 then
			text = text.."  x"..entry.count
		end
		if entry.new then
			text = text.."  |cff7dff7dnew|r"
		end
		bar.name:SetText(text)
		bar.at:SetText(entry.at and Clock(entry.at) or "")
		bar:Show()
	end
	for index = count + 1, table.getn(bars) do
		bars[index]:Hide()
	end
	if count == 0 then
		log.empty:Show()
		log:SetHeight(26)
	else
		log.empty:Hide()
		log:SetHeight(15 + count * (BAR_HEIGHT + BAR_GAP))
	end
end
------------------------------------------------------------------------------
-- Reading the chat. The game's loot line does not come as the stock loot
-- event with an item link, so the addon reads what the chat window shows,
-- whatever brought it there: "You receive loot: [Judgement Pauldrons] New in
-- your collection!". The item's color and link are kept when the line has
-- them; a name in brackets is enough.

local lastAdded, lastAddedAt = nil, 0

local function Add(message)
	local _, _, rest = string.find(message, "You receive [%a ]+: (.+)")
	if not rest then
		return
	end
	local _, _, name = string.find(rest, "%[(.-)%]")
	if not name then
		return
	end
	local _, _, color = string.find(rest, "|c(%x%x%x%x%x%x%x%x)[^%[]*%[")
	local _, _, item = string.find(rest, "|H(item:[%d:%-]+)|h")
	local _, _, count = string.find(rest, "%]|?h?|?r?x(%d+)")

	-- The same line can arrive twice, by the event and by the window.
	local now = GetTime()
	if lastAdded == rest and now - lastAddedAt < 1 then
		return
	end
	lastAdded, lastAddedAt = rest, now

	table.insert(entries, 1, {
		item = item, name = name, color = color, count = tonumber(count),
		new = string.find(rest, "New in your collection", 1, true) ~= nil,
		at = RunSeconds(),
	})
	while table.getn(entries) > 30 do
		table.remove(entries)
	end
	Draw()
end

local lastSeconds

-- Two ways in, whichever the game's line takes: the chat events, and every
-- line the main chat window shows.
local function Seen(text)
	if not (text and Settings().lootLog) then
		return
	end
	-- "<hero> enters <zone>. Move to begin.": a new run, an empty list.
	if string.find(text, "Move to begin", 1, true) then
		entries = {}
		Draw()
	elseif string.find(text, "You receive", 1, true) then
		Add(text)
	end
end

local events = CreateFrame("Frame")
for _, name in pairs({ "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_EMOTE" }) do
	events:RegisterEvent(name)
end
events:SetScript("OnEvent", function() Seen(arg1) end)

local function Watch(frame)
	if not frame or frame.survivorLootWatched then
		return
	end
	frame.survivorLootWatched = true
	local stock = frame.AddMessage
	frame.AddMessage = function(self, text, r, g, b, id, hold)
		Seen(text)
		return stock(self, text, r, g, b, id, hold)
	end
end
-- Shown during a run (or while it holds loot), hidden by /sui loot.
local watcher = CreateFrame("Frame")
local elapsed = 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	elapsed = 0

	-- The game's clock going back means a new run.
	local seconds = RunSeconds()
	if seconds and lastSeconds and seconds + 3 < lastSeconds then
		entries = {}
		Draw()
	end
	lastSeconds = seconds

	local phase = AZS_GetPhase and AZS_GetPhase()
	local inRun = phase and phase ~= "ready"
	if Settings().lootLog and (inRun or table.getn(entries) > 0) then
		if not log:IsShown() then
			Draw()
			log:Show()
		end
	elseif log:IsShown() then
		log:Hide()
	end
end)

function SurvivorUI_ToggleLoot()
	local settings = Settings()
	settings.lootLog = not settings.lootLog
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: loot log "..(settings.lootLog and "shown." or "hidden."))
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(log, "Loot", SavePlace, nil, function()
		log:ClearAllPoints()
		log:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	Watch(DEFAULT_CHAT_FRAME)
	local settings = Settings()
	if settings.lootLeft then
		log:ClearAllPoints()
		log:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings.lootLeft, settings.lootTop)
	end
end)
