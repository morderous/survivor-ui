-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: loot log.
--
-- A small list of what the run has dropped, newest on top, each with the run
-- second it came: the left column's last, under This Run and Biggest Crits,
-- and only once something has dropped. The game's addon API says nothing
-- about loot, so this reads the chat window's "You receive loot: [item]" lines.
--
-- Hover an item for its tooltip. Hold Alt and drag to move; /sui loot hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 220               -- the rows, as This Run's
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
-- The frame, in This Run's manner (RunPanel.lua): a dark box, a gold title,
-- then a row per item, its name and the run second in its quality's color
-- over a faint wash of it, a thin line of it under each.

local ROW_HEIGHT = 18
local TITLE_HEIGHT = 24
local TOP = 4                   -- room over the title, and under the last row
local EPIC = { 0.64, 0.21, 0.93 }

local log = CreateFrame("Frame", "SurvivorUILoot", UIParent)
log:SetWidth(WIDTH + 16)
log:SetHeight(TOP + TITLE_HEIGHT + TOP)
log:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
log:SetBackdrop({ bgFile = FLAT })
-- The left column's shade, This Run's.
log:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
log:SetMovable(true)
log:EnableMouse(true)
log:RegisterForDrag("LeftButton")
log:Hide()

local function SavePlace()
	local settings = Settings()
	settings.lootLeft = math.floor(log:GetLeft() + 0.5)
	settings.lootTop = math.floor(log:GetTop() + 0.5)
end

-- Its first place, the left column's last: under Biggest Crits, or under
-- This Run while the crits are away, or the top left corner with neither
-- (RunPanel.lua). Followed as they come and go, until the list is moved.
local function DefaultPlace(again)
	local crits, run = getglobal("SurvivorUICrits"), getglobal("SurvivorUIRun")
	local under = UIParent
	if crits and crits:IsShown() then
		under = crits
	elseif run and run:IsShown() then
		under = run
	end
	if under == log.under and not again then
		return
	end
	log.under = under
	log:ClearAllPoints()
	if under == UIParent then
		log:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
	else
		log:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -10)
	end
end

log:SetScript("OnDragStart", function() if IsAltKeyDown() then log:StartMoving() end end)
log:SetScript("OnDragStop", function() log:StopMovingOrSizing() SavePlace() end)

log.title = log:CreateFontString(nil, "OVERLAY")
log.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
log.title:SetPoint("LEFT", log, "TOPLEFT", 8, -TOP - (TITLE_HEIGHT - 6) / 2)
log.title:SetTextColor(1, 0.82, 0)
log.title:SetText("Loot")


local entries = {}              -- newest first: { item, name, color, count, new, at }
local bars = {}

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end
	bar = CreateFrame("Button", nil, log)
	bar:SetWidth(WIDTH)
	bar:SetHeight(ROW_HEIGHT)
	bar:SetPoint("TOPLEFT", log, "TOPLEFT", 8, -TOP - TITLE_HEIGHT - (index - 1) * ROW_HEIGHT)

	bar.wash = bar:CreateTexture(nil, "BACKGROUND")
	bar.wash:SetTexture(FLAT)
	bar.wash:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
	bar.wash:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 1)

	bar.rule = bar:CreateTexture(nil, "BORDER")
	bar.rule:SetTexture(FLAT)
	bar.rule:SetHeight(1)
	bar.rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bar.rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.name:SetWidth(WIDTH - 48)
	bar.name:SetHeight(11)
	bar.name:SetJustifyH("LEFT")

	bar.at = bar:CreateFontString(nil, "OVERLAY")
	bar.at:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
	bar.at:SetPoint("RIGHT", bar, "RIGHT", -5, 0)

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
		-- In its quality's color, as This Run's rows are in theirs.
		bar.name:SetTextColor(color[1], color[2], color[3])
		bar.at:SetTextColor(color[1], color[2], color[3])
		bar.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
		bar.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
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
	log:SetHeight(TOP + TITLE_HEIGHT + math.max(1, count) * ROW_HEIGHT + TOP)
end
------------------------------------------------------------------------------
-- Reading the chat. The game's loot line does not come as the stock loot
-- event with an item link, so the addon reads what the chat window shows,
-- whatever brought it there: "You receive loot: [Judgement Pauldrons] New in
-- your collection!". The item's color and link are kept when the line has
-- them; a name in brackets is enough.

local lastAdded, lastAddedAt = nil, 0

-- The line as the game writes it in each of its languages: English, Polish,
-- German, Portuguese, Spanish, French, Turkish, Russian, Chinese, Korean.
local RECEIVE = {
	"You receive loot:", "Otrzymujesz łup:", "Du erhältst Beute:", "Você recebe saque:",
	"Recibes botín:", "Vous recevez du butin :", "Ganimet aldın:", "Вы получаете добычу:",
	"你获得了战利品：", "전리품을 받았습니다:",
}
local NEW = {
	"New in your collection", "Nowość w kolekcji", "Neu in deiner Sammlung", "Novo na sua coleção",
	"Nuevo en tu colección", "Nouveau dans votre collection", "Koleksiyonunda yeni",
	"Новое в вашей коллекции", "收藏新增", "수집품에 새로 추가",
}

-- What follows "You receive loot:" (or its own words), or nil.
local function Received(message)
	for _, words in pairs(RECEIVE) do
		local _, last = string.find(message, words, 1, true)
		if last then
			return string.sub(message, last + 1)
		end
	end
	local _, _, rest = string.find(message, "You receive [%a ]+: (.+)")
	return rest
end

local function IsNew(rest)
	for _, words in pairs(NEW) do
		if string.find(rest, words, 1, true) then
			return true
		end
	end
	return false
end

local function Add(message)
	local rest = Received(message)
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
		new = IsNew(rest),
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
	elseif string.find(text, "[", 1, true) then
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

	if not Settings().lootLeft then
		DefaultPlace()
	end
	-- Shown once something has dropped, and kept until a new run starts.
	if Settings().lootLog and table.getn(entries) > 0 then
		if not log:IsShown() then
			Draw()
			log:Show()
		end
	elseif log:IsShown() then
		log:Hide()
	end
end)

-- The game's own loot notices, the cards a boss's drop pops up mid-screen:
-- away while this list is on. The setting is the game's and is saved, so the
-- addon remembers that it was the one to turn it off.
local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.lootLog then
		if AZS_IsHudShown("loot") then
			AZS_SetHudShown("loot", false)
			settings.hidGameLoot = true
		end
	elseif settings.hidGameLoot then
		AZS_SetHudShown("loot", true)
		settings.hidGameLoot = nil
	end
end

function SurvivorUI_ToggleLoot()
	local settings = Settings()
	settings.lootLog = not settings.lootLog
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.lootLog
		and "loot list shown; the game's own loot notices are put away."
		or "loot list hidden; the game's own loot notices are back."))
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(log, "Loot", SavePlace, nil, function()
		DefaultPlace(true)
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	Watch(DEFAULT_CHAT_FRAME)
	ApplyGameHud()
	local settings = Settings()
	if settings.lootLeft then
		log.under = nil
		log:ClearAllPoints()
		log:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings.lootLeft, settings.lootTop)
	else
		DefaultPlace(true)
	end
end)
