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
--
-- The same piece again in a run is one row, x2. On the band over the list, the
-- run's marks: hover them for each boss's, one under the other.

if SurvivorUI_Standby then return end

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

-- Marks as the game writes them: 20, 22.5.
local function Amount(value)
	local whole = math.floor(value + 0.05)
	if math.abs(value - whole) < 0.05 then
		return tostring(whole)
	end
	return string.format("%.1f", value)
end

------------------------------------------------------------------------------
-- The frame, in This Run's manner (RunPanel.lua): a dark box, a gold title,
-- then a row per item, filled with its quality's color in a black edge, its
-- name and the run second white over it.

local ROW_HEIGHT = 18
local BAND_HEIGHT = 20          -- the title's band, as wide as the rows
local TITLE_HEIGHT = BAND_HEIGHT + 4
local TOP = 4                   -- room over the band, and under the last row
local BAND_MIDDLE = -TOP - BAND_HEIGHT / 2
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

log:SetScript("OnDragStart", function() if SurvivorUI_MoveKeyDown() then log:StartMoving() end end)
log:SetScript("OnDragStop", function() log:StopMovingOrSizing() SavePlace() end)

-- The title on a band in the panels' shade, as wide as the rows, the run's
-- marks at its other end.
local band = log:CreateTexture(nil, "BORDER")
band:SetTexture(FLAT)
band:SetVertexColor(0.04, 0.04, 0.07, 0.55)
band:SetPoint("TOPLEFT", log, "TOPLEFT", 8, -TOP)
band:SetPoint("TOPRIGHT", log, "TOPRIGHT", -8, -TOP)
band:SetHeight(BAND_HEIGHT)

log.title = log:CreateFontString(nil, "OVERLAY")
log.title:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
log.title:SetPoint("LEFT", log, "TOPLEFT", 13, BAND_MIDDLE)
log.title:SetTextColor(1, 0.82, 0)
log.title:SetText(SurvivorUI_T("Loot list"))

log.marks = log:CreateFontString(nil, "OVERLAY")
log.marks:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
log.marks:SetPoint("RIGHT", log, "TOPLEFT", WIDTH + 3, BAND_MIDDLE)
log.marks:SetTextColor(1, 0.82, 0)

-- Only the marks answer the mouse, so the outline (Hover.lua) sits on them.
local head = CreateFrame("Frame", nil, log)
head:SetPoint("RIGHT", log.marks, "RIGHT", 4, 0)
head:SetHeight(16)
head:SetWidth(20)
head:EnableMouse(true)
head:RegisterForDrag("LeftButton")
head:SetScript("OnDragStart", function() if SurvivorUI_MoveKeyDown() then log:StartMoving() end end)
head:SetScript("OnDragStop", function() log:StopMovingOrSizing() SavePlace() end)

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
local earned = { total = 0 }    -- the run's marks, oldest first: { amount, at, when, paid, boss }
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
			GameTooltip:AddLine(SurvivorUI_T("Not yet seen equipped in a run: its details show here once you have worn it in one."), 0.62, 0.62, 0.68, 1)
		end
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() if SurvivorUI_MoveKeyDown() then log:StartMoving() end end)
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

-- Its background, unless switched off (the options, Loot list); and none at
-- all, the title's band too, with No backgrounds on (the options' No
-- backgrounds, Experimental) and the list not kept there: the rows keep their
-- quality fills. Painted as the world loads and as the options change it.
local function Ground()
	local db = Settings()
	local bare = db.noBackgrounds and not (db.noBackgroundsOff and db.noBackgroundsOff.loot)
	local back = db.lootBackground ~= false and not bare
	if log.back ~= back then
		log.back = back
		log:SetBackdropColor(0.04, 0.04, 0.07, back and 0.55 or 0)
	end
	if bare then
		band:Hide()
	else
		band:Show()
	end
end
SurvivorUI_Grounds = SurvivorUI_Grounds or {}
SurvivorUI_Grounds.loot = Ground

local function Draw()
	local settings = Settings()
	log.marks:SetText(SurvivorUI_TF("Marks: {1}", Amount(earned.total)))
	head:SetWidth(math.max(14, log.marks:GetStringWidth()) + 8)
	Ground()
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
			extra = extra.."  |cff7dff7d"..SurvivorUI_T("new").."|r"
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
	log:SetHeight(TOP + TITLE_HEIGHT + count * ROW_HEIGHT + TOP)
end
------------------------------------------------------------------------------
-- Reading the chat. The game's loot line does not come as the stock loot
-- event with an item link, so the addon reads what the chat window shows,
-- whatever brought it there: "You receive loot: [Judgement Pauldrons] New in
-- your collection!". The item's color and link are kept when the line has
-- them; a name in brackets is enough.

-- The line as the game writes it in each of its languages: English, Polish,
-- German, Portuguese, Spanish, French, Turkish, Russian, Chinese, Korean, and
-- from its 0.97 Romanian, Ukrainian and Japanese, then Czech.
local RECEIVE = {
	"You receive loot:", "Otrzymujesz łup:", "Du erhältst Beute:", "Você recebe saque:",
	"Recibes botín:", "Vous recevez du butin :", "Ganimet aldın:", "Вы получаете добычу:",
	"你获得了战利品：", "전리품을 받았습니다:",
	"Primești pradă:", "Ви отримуєте здобич:", "戦利品を入手：", "Získáváš kořist:",
}
local NEW = {
	"New in your collection", "Nowość w kolekcji", "Neu in deiner Sammlung", "Novo na sua coleção",
	"Nuevo en tu colección", "Nouveau dans votre collection", "Koleksiyonunda yeni",
	"Новое в вашей коллекции", "收藏新增", "수집품에 새로 추가",
	"Nou în colecția ta", "Нове у вашій колекції", "コレクションに新しく追加", "Novinka ve tvé sbírce",
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

------------------------------------------------------------------------------
-- The run's marks. Two lines bring them, paid apart by the game (read in its
-- 0.138): a boss's, "You earn 20 marks (340 in all).", and a piece already
-- collected, its loot line ending "+0.5 marks". Neither names the boss, so the
-- bosses and guardians alive are watched (AZS_UNITS, as the boss bars), and one
-- gone a moment from a boss's line is that line's. A row a boss, the repeats
-- dropped with it inside; repeats on their own, a row of their own.

local FELL_WINDOW = 3           -- seconds between a boss's fall and its line
local DROP_WINDOW = 5           -- seconds a repeat joins the row before it
local HISTORY = 24              -- the rows the title's tooltip has room for

-- Each language's line: what the boss gave, and what the hero's class has now.
local EARNED = {
	"You earn ([%d%.,]+) marks %(([%d%.,]+) in all%)", "Zdobywasz znaki: ([%d%.,]+) %(łącznie ([%d%.,]+)%)",
	"Získáváš známky: ([%d%.,]+) %(celkem ([%d%.,]+)%)", "Du erhältst ([%d%.,]+) Marken %(insgesamt ([%d%.,]+)%)",
	"Você ganha ([%d%.,]+) marcas %(([%d%.,]+) no total%)", "Ganas ([%d%.,]+) marcas %(([%d%.,]+) en total%)",
	"Vous gagnez ([%d%.,]+) marques %(([%d%.,]+) au total%)", "Câștigi ([%d%.,]+) însemne %(([%d%.,]+) în total%)",
	"([%d%.,]+) nişan kazandın %(toplam ([%d%.,]+)%)", "Вы получаете знаки: ([%d%.,]+) %(всего ([%d%.,]+)%)",
	"Ви отримуєте знаки: ([%d%.,]+) %(усього ([%d%.,]+)%)", "你获得了([%d%.,]+)枚印记（共([%d%.,]+)枚）",
	"([%d%.,]+)マークを獲得（合計([%d%.,]+)）", "징표 ([%d%.,]+)개를 얻었습니다 %(총 ([%d%.,]+)개%)",
}

local function Number(text)
	return tonumber((string.gsub(text or "", ",", ".")))
end

-- The marks a boss's line gives and what the class has now, or nil.
local function MarksEarned(text)
	if not string.find(text, "%d") then
		return nil
	end
	for _, words in pairs(EARNED) do
		local _, _, amount, total = string.find(text, words)
		if amount then
			return Number(amount), Number(total)
		end
	end
end

local standing, fallen = {}, {} -- the bosses alive, [id] = name; those just gone, oldest first

-- One just gone: the name for a boss's line that came first, else kept for
-- the line to come.
local function Fell(name)
	local now = GetTime()
	for index = math.max(1, table.getn(earned) - 3), table.getn(earned) do
		local row = earned[index]
		if row.paid and not row.boss and now - row.when <= FELL_WINDOW then
			row.boss = name
			return
		end
	end
	table.insert(fallen, { name = name, when = now })
end

-- The oldest boss gone a moment ago that no line has taken.
local function Claim(now)
	while fallen[1] do
		local one = table.remove(fallen, 1)
		if now - one.when <= FELL_WINDOW then
			return one.name
		end
	end
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function LookAtBosses()
	if not AZS_UNITS then
		return
	end
	local seen = {}
	for index = 1, table.getn(AZS_UNITS) do
		local unit = AZS_UNITS[index]
		local kind = Field(unit, "kind", 1)
		if (kind == "final" or kind == "boss" or kind == "guardian") and (tonumber(Field(unit, "hp", 4)) or 0) > 0 then
			seen[Field(unit, "id", 2)] = Field(unit, "name", 3)
		end
	end
	for id, name in pairs(standing) do
		if not seen[id] then
			Fell(name)
		end
	end
	standing = seen
	local now = GetTime()
	while fallen[1] and now - fallen[1].when > FELL_WINDOW do
		table.remove(fallen, 1)
	end
end

-- Whichever line comes first opens the boss's row; two bosses' lines, two rows.
local function AddMarks(amount, paid)
	local now, row = GetTime(), earned[table.getn(earned)]
	if row and now - row.when <= DROP_WINDOW and not (paid and row.paid) then
		row.amount = row.amount + amount
	else
		row = { amount = amount, at = RunSeconds(), when = now }
		table.insert(earned, row)
	end
	if paid then
		row.paid = true
		row.boss = Claim(now)
	end
	earned.total = earned.total + amount
end

-- What each class has, as the game last said: kept for the account, since the
-- game tells it only as a boss falls. A repeat after that line adds to it.
local function Stocks()
	local db = Settings()
	db.classMarks = db.classMarks or {}
	return db.classMarks
end

local function ClassKey()
	local _, class = UnitClass("player")
	return class or "?"
end

local function Stock(total, amount)
	local stocks, class = Stocks(), ClassKey()
	if total then
		stocks[class] = total
	elseif stocks[class] then
		stocks[class] = stocks[class] + amount
	end
end

-- The marks a row each, in a card in the manner of the XP bar's luck card.
local CARD_WIDTH, CARD_TOP, CARD_ROW = 230, 30, 15
local card = CreateFrame("Frame", "SurvivorUIMarksCard", UIParent)
card:SetFrameStrata("TOOLTIP")
card:SetWidth(CARD_WIDTH)
card:Hide()
if card.SetClampedToScreen then
	card:SetClampedToScreen(true)
end
card.back = card:CreateTexture(nil, "BACKGROUND")
card.back:SetTexture(FLAT)
card.back:SetVertexColor(0.05, 0.05, 0.07, 0.94)
card.back:SetAllPoints(card)
card.edge = card:CreateTexture(nil, "BORDER")
card.edge:SetTexture(FLAT)
card.edge:SetVertexColor(0.6, 0.49, 0, 1)
card.edge:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
card.edge:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
card.edge:SetHeight(2)

local function CardText(size, r, g, b)
	local text = card:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(r, g, b)
	text:SetJustifyH("LEFT")
	return text
end

card.title = CardText(12, 1, 0.82, 0)
card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -9)
card.rows = {}
card.stock = CardText(10, 0.8, 0.8, 0.84)
card.stockValue = CardText(10, 1, 0.82, 0)
card.stockValue:SetPoint("TOPRIGHT", card.stock, "TOPLEFT", CARD_WIDTH - 20, 0)
card.stockValue:SetJustifyH("RIGHT")

local function CardRow(index)
	local row = card.rows[index]
	if row then
		return row
	end
	local y = -CARD_TOP - (index - 1) * CARD_ROW
	row = { at = CardText(9, 0.55, 0.55, 0.6), name = CardText(10, 1, 1, 1), amount = CardText(10, 1, 0.82, 0) }
	row.at:SetPoint("TOPLEFT", card, "TOPLEFT", 10, y - 1)
	row.name:SetPoint("TOPLEFT", card, "TOPLEFT", 44, y)
	row.name:SetWidth(CARD_WIDTH - 44 - 58)
	row.name:SetHeight(12)
	row.amount:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, y)
	row.amount:SetJustifyH("RIGHT")
	card.rows[index] = row
	return row
end

-- A run's marks in the card, { total, class, rows } with the rows oldest
-- first: the run's own, or a run the Run History kept (RunHistory.lua).
local function FillCard(marks)
	local rows = marks.rows or {}
	local count = table.getn(rows)
	card.title:SetText(SurvivorUI_TF("{1} marks this run", Amount(marks.total or 0)))
	local first = math.max(1, count - HISTORY + 1)
	for index = first, count do
		local each = rows[index]
		local row = CardRow(index - first + 1)
		row.at:SetText(each.at and Clock(each.at) or "")
		row.name:SetText(each.boss or SurvivorUI_T(each.paid and "A boss" or "Repeated loot"))
		row.amount:SetText("+"..Amount(each.amount))
		row.at:Show()
		row.name:Show()
		row.amount:Show()
	end
	local shown = count - first + 1
	for index = shown + 1, table.getn(card.rows) do
		local row = card.rows[index]
		row.at:Hide()
		row.name:Hide()
		row.amount:Hide()
	end
	-- Under them, what the hero's class has, once the game has said.
	local stock = marks.class
	local foot = 0
	if stock then
		foot = 20
		card.stock:ClearAllPoints()
		card.stock:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -CARD_TOP - shown * CARD_ROW - 6)
		card.stock:SetText(SurvivorUI_T("Class total"))
		card.stockValue:SetText(Amount(stock))
		card.stock:Show()
		card.stockValue:Show()
	else
		card.stock:Hide()
		card.stockValue:Hide()
	end
	card:SetHeight(CARD_TOP + shown * CARD_ROW + foot + 6)
end

local function RunMarks()
	return { total = earned.total, class = Stocks()[ClassKey()], rows = earned }
end

head:SetScript("OnEnter", function()
	if table.getn(earned) == 0 then
		return
	end
	card:SetScale(log:GetEffectiveScale() / UIParent:GetEffectiveScale())
	card:ClearAllPoints()
	if SurvivorUI_RoomOnRight(log) then
		card:SetPoint("TOPLEFT", log, "TOPRIGHT", 6, 0)
	else
		card:SetPoint("TOPRIGHT", log, "TOPLEFT", -6, 0)
	end
	FillCard(RunMarks())
	card:Show()
end)
head:SetScript("OnLeave", function() card:Hide() end)
log:SetScript("OnHide", function() card:Hide() end)

-- The same line can arrive twice, by the event and by the window, and the same
-- piece twice in a moment twice by each: a line counts only when the way that
-- has brought it most brings it once more. Each line kept apart for a second,
-- as a boss's two lines can come in by the two ways one across the other.
local recent = {}

local function Fresh(text, way)
	local now = GetTime()
	for line, seen in pairs(recent) do
		if now - seen.at >= 1 then
			recent[line] = nil
		end
	end
	local seen = recent[text]
	if not seen then
		seen = { at = now, event = 0, window = 0 }
		recent[text] = seen
	end
	seen[way] = seen[way] + 1
	return seen[way] > seen[way == "event" and "window" or "event"]
end

local function Add(message, way)
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

	if not Fresh(rest, way) then
		return
	end

	if item then
		Known()[name] = item
	end
	-- A piece already collected: its marks, gold at the line's end, in every
	-- language with a plus before them.
	local _, _, worth = string.find(rest, "|cffffd100[^|]-%+([%d%.,]+)")
	if worth then
		AddMarks(Number(worth) or 0)
		Stock(nil, Number(worth) or 0)
	end
	-- The same piece again: its one row, counted, on top again.
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		if entry.name == name then
			table.remove(entries, index)
			entry.count = (entry.count or 1) + (tonumber(count) or 1)
			entry.item = entry.item or item
			entry.new = entry.new or IsNew(rest)
			entry.at = RunSeconds()
			table.insert(entries, 1, entry)
			Draw()
			return
		end
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

local function NewRun()
	entries = {}
	earned = { total = 0 }
	fallen = {}
	Draw()
end

-- Two ways in, whichever the game's line takes: the chat events, and every
-- line the main chat window shows.
local function Seen(text, way)
	if not (text and Settings().lootLog) then
		return
	end
	-- "<hero> enters <zone>. Move to begin.": a new run, an empty list.
	if string.find(text, "Move to begin", 1, true) then
		NewRun()
	elseif string.find(text, "[", 1, true) then
		Add(text, way)
	else
		local amount, total = MarksEarned(text)
		if amount and Fresh(text, way) then
			AddMarks(amount, true)
			Stock(total)
			Draw()
		end
	end
end

local events = CreateFrame("Frame")
for _, name in pairs({ "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_EMOTE" }) do
	events:RegisterEvent(name)
end
events:SetScript("OnEvent", function() Seen(arg1, "event") end)

local function Watch(frame)
	if not frame or frame.survivorLootWatched then
		return
	end
	frame.survivorLootWatched = true
	local stock = frame.AddMessage
	frame.AddMessage = function(self, text, r, g, b, id, hold)
		Seen(text, "window")
		-- Read, a loot line can stay out of the chat: the list has it
		-- (the options, Chat; ChatFilter.lua).
		if text and Settings().lootLog and SurvivorUI_ChatFilter and SurvivorUI_ChatFilter("Loot")
			and (Received(text) or MarksEarned(text)) then
			return
		end
		return stock(self, text, r, g, b, id, hold)
	end
end
-- Shown during a run (or while it holds loot), hidden by /sui loot.
local watcher = CreateFrame("Frame")
local elapsed, looked = 0, 0
watcher:SetScript("OnUpdate", function()
	-- The bosses often: a boss's marks come a moment from its fall.
	looked = looked + arg1
	if looked >= 0.2 then
		looked = 0
		if Settings().lootLog then
			LookAtBosses()
		end
	end
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	elapsed = 0

	-- The game's clock going back means a new run.
	local seconds = RunSeconds()
	if seconds and lastSeconds and seconds + 3 < lastSeconds then
		NewRun()
	end
	lastSeconds = seconds

	if not Settings().lootLeft then
		DefaultPlace()
	end
	-- Shown once something has dropped, and kept until a new run starts.
	if Settings().lootLog and (table.getn(entries) > 0 or earned.total > 0) then
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

-- And the run's marks, as the title's card has them: { total, class, rows },
-- a row { amount, at, boss, paid } each, the oldest first. Nil with the list
-- switched off, as nothing is read then.
function SurvivorUI_RunMarks()
	if not Settings().lootLog then
		return nil
	end
	local marks = RunMarks()
	local rows, count = {}, table.getn(earned)
	for index = math.max(1, count - HISTORY + 1), count do
		local each = earned[index]
		table.insert(rows, { amount = each.amount, at = each.at, boss = each.boss, paid = each.paid })
	end
	marks.rows = rows
	return marks
end

-- A kept run's marks in the same card, as big as `owner` and put by `place`
-- (RunHistory.lua); and the card away.
function SurvivorUI_MarksCardShow(marks, owner, place)
	card:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
	card:ClearAllPoints()
	place(card)
	FillCard(marks)
	card:Show()
end

function SurvivorUI_MarksCardHide()
	card:Hide()
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
