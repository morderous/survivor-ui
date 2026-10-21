-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: loot log.
--
-- A small list of what the run has dropped, newest on top, each with the run
-- second it came: the left column's last, under This Run and Biggest Crits,
-- and only once something has dropped. The game's addon API says nothing
-- about loot, so this reads the chat window's "You receive loot: [item]" lines.
--
-- Hover an item for its tooltip, once the hero has worn it in a run (the
-- game's loot line has no details). Hold Alt and drag to move; /sui loot
-- hides it.
-- Its tab in the options: the background behind it, how many lines.

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
-- then a row per item, filled with its quality's color in a black edge, its
-- name and the run second white over it.

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


------------------------------------------------------------------------------
-- The pieces the hero has worn in a run, by name, with their links: the game's
-- loot line names a drop without its details, so its tooltip comes from here
-- once the piece has been worn. Kept for the account, in SurvivorUIDB, since a
-- piece found on one hero is worn on another; a line with a link adds it too.

local function Known()
	local db = Settings()
	db.itemLinks = db.itemLinks or {}
	return db.itemLinks
end

local EVERY_SLOT = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
-- The jewelry: neck, rings, trinkets, the only pieces a run changes.
local JEWELRY_SLOTS = { 2, 11, 12, 13, 14 }

local function LearnWorn(slots)
	if not (GetInventoryItemLink and SurvivorUIDB) then
		return
	end
	local known = Known()
	for index = 1, table.getn(slots) do
		local link = GetInventoryItemLink("player", slots[index])
		if link then
			local _, _, item = string.find(link, "|H(item:[%d:%-]+)|h")
			local _, _, name = string.find(link, "%[(.-)%]")
			if item and name then
				known[name] = item
			end
		end
	end
end

-- Every piece once, as the run begins: the gear stays as it is through a run.
-- Then only the jewelry, as it changes.
local learner = CreateFrame("Frame")
learner:RegisterEvent("PLAYER_ENTERING_WORLD")
learner:RegisterEvent("UNIT_INVENTORY_CHANGED")
learner:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		LearnWorn(EVERY_SLOT)
	elseif arg1 == "player" then
		LearnWorn(JEWELRY_SLOTS)
	end
end)

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

	-- Each row a solid bar in a black edge, as up to v2.10.
	bar.border = bar:CreateTexture(nil, "BACKGROUND")
	bar.border:SetTexture(FLAT)
	bar.border:SetVertexColor(0, 0, 0, 1)
	bar.border:SetAllPoints(bar)

	bar.wash = bar:CreateTexture(nil, "BORDER")
	bar.wash:SetTexture(FLAT)
	bar.wash:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
	bar.wash:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 1)

	bar.name = bar:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.name:SetWidth(WIDTH - 48)
	bar.name:SetHeight(11)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	bar.at = bar:CreateFontString(nil, "OVERLAY")
	bar.at:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
	bar.at:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	bar.at:SetTextColor(0.88, 0.88, 0.88)

	-- The count and "new" after the name, never cut with it.
	bar.extra = bar:CreateFontString(nil, "OVERLAY")
	bar.extra:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.extra:SetTextColor(1, 1, 1)

	-- Its tooltip: the line's link, or the one kept from wearing it; else its
	-- name and quality, and that its details come once it has been worn.
	bar:SetScript("OnEnter", function()
		local link = this.item or (this.itemName and Known()[this.itemName])
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		if link then
			GameTooltip:SetHyperlink(link)
		else
			local color = this.color or { 1, 1, 1 }
			GameTooltip:SetText(this.itemName or "?", color[1], color[2], color[3])
			if this.qualityName then
				GameTooltip:AddLine(string.upper(string.sub(this.qualityName, 1, 1))..string.sub(this.qualityName, 2), color[1], color[2], color[3])
			end
			GameTooltip:AddLine("Not yet seen equipped in a run: its details show here once you have worn it in one.", 0.62, 0.62, 0.68, 1)
		end
		GameTooltip:Show()
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

-- The quality by its color, as the game's links have them.
local QUALITIES = {
	ff9d9d9d = "poor", ffffffff = "common", ff1eff00 = "uncommon", ff0070dd = "rare",
	ffa335ee = "epic", ffff8000 = "legendary", ffe6cc80 = "artifact",
}

local function Draw()
	local settings = Settings()
	-- Its background, unless switched off (the options, Loot list).
	local back = settings.lootBackground ~= false
	if log.back ~= back then
		log.back = back
		log:SetBackdropColor(0.04, 0.04, 0.07, back and 0.55 or 0)
	end
	local count = math.min(settings.lootLines or MAX_LINES, table.getn(entries))
	for index = 1, count do
		local entry = entries[index]
		local bar = Bar(index)
		local color = QualityColor(entry.color)
		bar.item = entry.item
		bar.itemName = entry.name
		bar.color = color
		bar.qualityName = QUALITIES[string.lower(entry.color or "")]
		-- Filled with its quality's color, strong, the words white over it.
		bar.wash:SetVertexColor(color[1], color[2], color[3], 0.75)
		local extra = ""
		if entry.count and entry.count > 1 then
			extra = "  x"..entry.count
		end
		if entry.new then
			extra = extra.."  |cff7dff7dnew|r"
		end
		bar.extra:SetText(extra)
		local extraWidth = extra ~= "" and bar.extra:GetStringWidth() or 0
		-- The count and "new" after the name, the name giving them room: a
		-- long one is cut, they are not.
		local room = WIDTH - 48 - extraWidth
		if bar.room ~= room then
			bar.room = room
			bar.name:SetWidth(room)
		end
		bar.name:SetText(entry.name)
		local nameWidth = math.min(bar.name:GetStringWidth(), room)
		bar.extra:ClearAllPoints()
		bar.extra:SetPoint("LEFT", bar, "LEFT", 5 + nameWidth, 0)
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
-- German, Portuguese, Spanish, French, Turkish, Russian, Chinese, Korean, and
-- from its 0.97 Romanian, Ukrainian and Japanese.
local RECEIVE = {
	"You receive loot:", "Otrzymujesz łup:", "Du erhältst Beute:", "Você recebe saque:",
	"Recibes botín:", "Vous recevez du butin :", "Ganimet aldın:", "Вы получаете добычу:",
	"你获得了战利品：", "전리품을 받았습니다:",
	"Primești pradă:", "Ви отримуєте здобич:", "戦利品を入手：",
}
local NEW = {
	"New in your collection", "Nowość w kolekcji", "Neu in deiner Sammlung", "Novo na sua coleção",
	"Nuevo en tu colección", "Nouveau dans votre collection", "Koleksiyonunda yeni",
	"Новое в вашей коллекции", "收藏新增", "수집품에 새로 추가",
	"Nou în colecția ta", "Нове у вашій колекції", "コレクションに新しく追加",
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

	if item then
		Known()[name] = item
	end
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
		-- Read, a loot line can stay out of the chat: the list has it
		-- (the options, Chat; ChatFilter.lua).
		if text and Settings().lootLog and SurvivorUI_ChatFilter and SurvivorUI_ChatFilter("Loot") and Received(text) then
			return
		end
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
		-- Drawn again at each look, for a setting changed in the options.
		Draw()
		if not log:IsShown() then
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
	if settings.lootLog or settings.noGameLoot then
		if AZS_IsHudShown("loot") then
			AZS_SetHudShown("loot", false)
			settings.hidGameLoot = true
		end
	elseif settings.hidGameLoot then
		AZS_SetHudShown("loot", true)
		settings.hidGameLoot = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.loot = ApplyGameHud

-- For the last runs (RunHistory.lua): the run's loot, the newest first, at
-- most this many: { name, color, count, new, at, item } each.
function SurvivorUI_LootList(most)
	local list = {}
	for index = 1, math.min(most or 12, table.getn(entries)) do
		local entry = entries[index]
		table.insert(list, {
			name = entry.name, color = entry.color, count = entry.count, new = entry.new,
			at = entry.at, item = entry.item or Known()[entry.name],
		})
	end
	return list
end

-- An item's quality by its link's color ("ffa335ee": "epic"), and the link
-- kept for a piece worn in a run, by its name.
function SurvivorUI_QualityName(hex)
	return QUALITIES[string.lower(hex or "")]
end

function SurvivorUI_KnownItem(name)
	return name and Known()[name]
end

function SurvivorUI_ToggleLoot()
	local settings = Settings()
	settings.lootLog = not settings.lootLog
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.lootLog
		and "loot list shown; the Default loot notices are put away."
		or (settings.noGameLoot and "loot list hidden, and the Default loot notices stay away." or "loot list hidden; the Default loot notices are back.")))
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(log, "Loot list", SavePlace, nil, function()
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
