-- Survivor UI: the jewelry each class has found.
--
-- Every neck, ring and trinket a character wears is written down, run after
-- run: its name, slot, quality, the ranks seen, and for each bonus the lowest
-- and highest value seen, overall and by rank. One book per class, kept for
-- the whole game folder (SurvivorUIJewelryBook): the game is offline, so
-- everyone who plays on it, on any account, fills the same books.
-- The game shares no card offers with addons: only the pieces worn count,
-- and every piece picked from a card is worn at once.
--
-- The book opens from its own button on the minimap, or /sui jewelry: a slim
-- list to read at a glance, even in a fight.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local SLOTS = { [2] = "Neck", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket" }
local SLOT_ORDER = { Neck = 1, Ring = 2, Trinket = 3 }

-- The quality a link's color names, for sorting: grey up to orange.
local QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

-- The books, by class ("PALADIN"), and where the list was left.
local function Books()
	SurvivorUIJewelryBook = SurvivorUIJewelryBook or {}
	SurvivorUIJewelryBook.classes = SurvivorUIJewelryBook.classes or {}
	return SurvivorUIJewelryBook
end

local function ClassName()
	local name, class = UnitClass("player")
	return class or "UNKNOWN", name or "?"
end

-- Two records of a bonus (or a rank's), as one: the lowest and highest of both.
local function Widen(into, from)
	into.min = math.min(into.min or from.min, from.min)
	into.max = math.max(into.max or from.max, from.max)
end

-- A piece written in a character's own book (before v2.8's shared books)
-- joins the class book.
local function MergeItem(book, base, old)
	local item = book.items[base]
	if not item then
		book.items[base] = old
		return
	end
	item.found = (item.found or 0) + (old.found or 0)
	if (old.quality or 0) > (item.quality or 0) then
		item.quality, item.color = old.quality, old.color
	end
	for rank in pairs(old.ranks or {}) do
		item.ranks[rank] = true
	end
	for each = 1, table.getn(old.stats or {}) do
		local stat = old.stats[each]
		local mine
		for other = 1, table.getn(item.stats) do
			if item.stats[other].pattern == stat.pattern then
				mine = item.stats[other]
			end
		end
		if mine then
			Widen(mine, stat)
			for rank, values in pairs(stat.ranks or {}) do
				mine.ranks[rank] = mine.ranks[rank] or {}
				Widen(mine.ranks[rank], values)
			end
		else
			table.insert(item.stats, stat)
		end
	end
end

-- This character's class book.
local function Book()
	local books = Books()
	local class = ClassName()
	local book = books.classes[class]
	if not book then
		book = { items = {} }
		books.classes[class] = book
	end
	if SurvivorUIJewelry and SurvivorUIJewelry.items then
		for base, old in pairs(SurvivorUIJewelry.items) do
			MergeItem(book, base, old)
		end
		SurvivorUIJewelry.items = nil
	end
	return book
end

------------------------------------------------------------------------------
-- Reading what is worn.

local scan = CreateFrame("GameTooltip", "SurvivorUIJewelryScan", nil, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

local worn = {}                 -- [slot] = link, as last read
local firstLook = true          -- the pieces worn at login were found before

-- A bonus line, as a pattern with its number taken out, the number and its
-- unit: "Increases your luck by #%", 70, "%".
local function Bonus(text)
	local _, _, number, percent = string.find(text, "(%d+%.?%d*)(%%?)")
	if not number then
		return nil
	end
	local pattern = string.gsub(text, "%d+%.?%d*", "#", 1)
	return pattern, tonumber(number), percent
end

local function Record(slot, link)
	local _, _, color, name = string.find(link, "|cff(%x%x%x%x%x%x).-%[(.-)%]")
	if not name then
		return
	end
	color = string.lower(color or "ffffff")
	local base, rank = name, nil
	local _, _, found = string.find(name, " ([IVXL]+%+?)$")
	if found then
		rank = found
		base = string.sub(name, 1, string.len(name) - string.len(found) - 1)
	end
	rank = rank or "I"

	local book = Book()
	local item = book.items[base]
	if not item then
		item = { slot = SLOTS[slot], found = 0, ranks = {}, stats = {}, first = time() }
		book.items[base] = item
	end
	item.slot = SLOTS[slot]
	item.last = time()
	item.texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or item.texture
	-- The best quality seen names its color.
	local quality = QUALITY[color] or 1
	if not item.quality or quality > item.quality then
		item.quality, item.color = quality, color
	end
	item.ranks[rank] = true
	local _, _, spell = string.find(base, ": (.+)$")
	if spell and quality == 5 and SLOTS[slot] == "Neck" then
		item.spell = spell
	end

	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	-- At login the game may not have the piece's text yet: nothing to read,
	-- and it is read again on the next look.
	local read = false
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIJewelryScanTextLeft"..index)
		if line and line:GetText() and string.find(line:GetText(), "%d") then
			read = true
		end
	end
	if not read then
		return base, false
	end
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIJewelryScanTextLeft"..index)
		local text = line and line:GetText()
		local pattern, value, unit = Bonus(text or "")
		if pattern then
			local stat
			for each = 1, table.getn(item.stats) do
				if item.stats[each].pattern == pattern then
					stat = item.stats[each]
				end
			end
			if not stat then
				stat = { pattern = pattern, unit = unit, ranks = {},
					tag = SurvivorUI_StatOf and SurvivorUI_StatOf(text) or nil }
				table.insert(item.stats, stat)
			end
			stat.min = math.min(stat.min or value, value)
			stat.max = math.max(stat.max or value, value)
			local byRank = stat.ranks[rank] or {}
			byRank.min = math.min(byRank.min or value, value)
			byRank.max = math.max(byRank.max or value, value)
			stat.ranks[rank] = byRank
		end
	end
	return base, true
end

local bases = {}                -- [slot] = the base name worn there

local function Look()
	for slot in pairs(SLOTS) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link ~= worn[slot] then
			worn[slot] = link
			if link then
				local base, read = Record(slot, link)
				if not read then
					-- Not read yet: looked at again in two seconds.
					worn[slot] = nil
				end
				-- A piece new to its slot (not an upgrade of the one there) is
				-- one more found; not those already worn at login.
				local item = base and Book().items[base]
				if item and base ~= bases[slot] and (not firstLook or item.found == 0) then
					item.found = item.found + 1
				end
				bases[slot] = base
			else
				bases[slot] = nil
			end
		end
	end
	firstLook = false
	if SurvivorUIJewelryPanel and SurvivorUIJewelryPanel:IsShown() then
		SurvivorUIJewelryPanel.Draw()
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_INVENTORY_CHANGED")
watcher:SetScript("OnEvent", function()
	if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
		return
	end
	Look()
end)
-- An upgrade from a card can change a piece without an inventory event: a
-- look every two seconds too.
local elapsed = 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 2 then
		elapsed = 0
		Look()
	end
end)

------------------------------------------------------------------------------
-- The book: a slim list, in the loot list's manner, to read at a glance in a
-- fight. The slots one under the other (necks, rings, trinkets), each piece a
-- thin bar in its quality's color: icon and name on the left, its bonuses with
-- the range seen on the right. Hover one for its bonuses written out. Drag it
-- anywhere; it stays where it is left.

local WIDTH = 420
local ROW = 17
local MAX_ROWS = 26             -- more than this: the mouse wheel scrolls
local SLOT_LIST = { "Neck", "Ring", "Trinket" }
local SLOT_COLORS = { Neck = { 1, 0.6, 0.2 }, Ring = { 0.4, 0.68, 1 }, Trinket = { 0.78, 0.52, 1 } }
local MUTED = { 0.6, 0.6, 0.65 }

local panel = CreateFrame("Frame", "SurvivorUIJewelryPanel", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(60)
panel:SetFrameStrata("MEDIUM")
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 280, -120)
panel:SetBackdrop({ bgFile = FLAT })
panel:SetBackdropColor(0.04, 0.04, 0.07, 0.85)
panel:EnableMouse(true)
panel:EnableMouseWheel(true)
panel:SetMovable(true)
if panel.SetClampedToScreen then
	panel:SetClampedToScreen(true)
end
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local books = Books()
	books.left = math.floor(this:GetLeft() + 0.5)
	books.top = math.floor(this:GetTop() + 0.5)
end)
panel:Hide()

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	return text
end

local function Fill(parent, layer, r, g, b, a)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(FLAT)
	texture:SetVertexColor(r, g, b, a)
	return texture
end

local title = Text(panel, 10, { 1, 0.82, 0 })
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)

local close = CreateFrame("Button", nil, panel)
close:SetWidth(16)
close:SetHeight(16)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
close.text = Text(close, 10, MUTED)
close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
close.text:SetText("x")
close:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.35, 0.3) end)
close:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
close:SetScript("OnClick", function() panel:Hide() end)

local empty = Text(panel, 9, MUTED)
empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -22)
empty:SetWidth(WIDTH - 10)
empty:SetJustifyH("LEFT")
empty:SetText("Nothing yet: every neck, ring and trinket worn by this class, on any character of this game, is written here.")

-- "29%" or "29-86%".
local function Range(low, high, unit)
	local function Number(value)
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.1f", value)
	end
	if low == high then
		return Number(low)..unit
	end
	return Number(low).."-"..Number(high)..unit
end

-- The lines, made as they are needed: a slot's header, or a piece.
local lines = {}

local function Line(index)
	local line = lines[index]
	if line then
		return line
	end
	line = CreateFrame("Button", nil, panel)
	line:SetWidth(WIDTH - 8)
	line:SetHeight(ROW - 1)
	line.wash = Fill(line, "BACKGROUND", 1, 1, 1, 0)
	line.wash:SetAllPoints(line)
	line.edge = Fill(line, "BORDER", 1, 1, 1, 0)
	line.edge:SetWidth(2)
	line.edge:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
	line.edge:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetWidth(ROW - 3)
	line.icon:SetHeight(ROW - 3)
	line.icon:SetPoint("LEFT", line, "LEFT", 4, 0)
	line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	line.name = Text(line, 9, { 1, 1, 1 })
	line.name:SetJustifyH("LEFT")
	line.stats = Text(line, 9, { 1, 1, 1 })
	line.stats:SetPoint("RIGHT", line, "RIGHT", -4, 0)
	line.stats:SetJustifyH("RIGHT")
	line:EnableMouseWheel(true)
	line:SetScript("OnMouseWheel", function() panel:GetScript("OnMouseWheel")() end)
	line:RegisterForDrag("LeftButton")
	line:SetScript("OnDragStart", function() panel:GetScript("OnDragStart")() end)
	line:SetScript("OnDragStop", function() panel:GetScript("OnDragStop")() end)
	line:SetScript("OnEnter", function()
		local item = this.item
		if not item then
			return
		end
		this.wash:SetAlpha(0.55)
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.base, this.color[1], this.color[2], this.color[3])
		GameTooltip:AddLine(item.slot.."  ·  found "..item.found.." time"..(item.found == 1 and "" or "s"), 0.7, 0.7, 0.7)
		for each = 1, table.getn(item.stats) do
			local stat = item.stats[each]
			GameTooltip:AddLine((string.gsub(stat.pattern, "#", Range(stat.min, stat.max, ""))), 0.3, 1, 0.4, 1)
		end
		GameTooltip:Show()
	end)
	line:SetScript("OnLeave", function()
		if this.item then
			this.wash:SetAlpha(1)
		end
		GameTooltip:Hide()
	end)
	lines[index] = line
	return line
end

local function Header(line, slot, count)
	local color = SLOT_COLORS[slot]
	line.item = nil
	line.wash:SetVertexColor(color[1], color[2], color[3], 0)
	line.edge:SetVertexColor(color[1], color[2], color[3], 0)
	line.icon:Hide()
	line.name:ClearAllPoints()
	line.name:SetPoint("LEFT", line, "LEFT", 1, -1)
	line.name:SetText(slot.."  |cff8a8a90"..count.."|r")
	line.name:SetTextColor(color[1], color[2], color[3])
	line.stats:SetText("")
end

-- A piece: its bar filled with its quality's color, the bonuses on the right
-- a point or two smaller when long (a legendary amulet has many).
local function Piece(line, base, item)
	local hex = item.color or "ffffff"
	local r = tonumber(string.sub(hex, 1, 2), 16) / 255
	local g = tonumber(string.sub(hex, 3, 4), 16) / 255
	local b = tonumber(string.sub(hex, 5, 6), 16) / 255
	line.item, line.base, line.color = item, base, { r, g, b }
	line.wash:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, 0.45)
	line.wash:SetAlpha(1)
	line.edge:SetVertexColor(r, g, b, 1)
	line.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	line.icon:Show()
	line.name:ClearAllPoints()
	line.name:SetPoint("LEFT", line.icon, "RIGHT", 5, 0)
	-- A legendary amulet goes by the spell it boosts: shorter, and what counts.
	local name = item.spell or base
	line.name:SetText(name)
	line.name:SetTextColor(1, 1, 1)

	local parts = {}
	for each = 1, table.getn(item.stats) do
		local stat = item.stats[each]
		table.insert(parts, (stat.tag or "?").." "..Range(stat.min, stat.max, stat.unit))
	end
	local text = table.concat(parts, " · ")
	if line.statsText ~= text then
		line.statsText = text
		line.stats:SetText(text)
		local room = WIDTH - 8 - 4 - (ROW - 3) - 5 - line.name:GetStringWidth() - 14
		for size = 9, 6, -1 do
			line.stats:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
			if line.stats:GetStringWidth() <= room then
				break
			end
		end
	end
end

local offset = 0

function panel.Draw()
	local book = Book()
	local bySlot, total = { Neck = {}, Ring = {}, Trinket = {} }, 0
	for base, item in pairs(book.items) do
		if bySlot[item.slot] then
			table.insert(bySlot[item.slot], { base = base, item = item })
			total = total + 1
		end
	end
	-- Each slot's pieces, the best quality first, then by name.
	local entries = {}
	for index = 1, table.getn(SLOT_LIST) do
		local slot = SLOT_LIST[index]
		local list = bySlot[slot]
		if table.getn(list) > 0 then
			table.sort(list, function(a, b)
				if (a.item.quality or 0) ~= (b.item.quality or 0) then
					return (a.item.quality or 0) > (b.item.quality or 0)
				end
				return a.base < b.base
			end)
			table.insert(entries, { header = slot, count = table.getn(list) })
			for each = 1, table.getn(list) do
				table.insert(entries, list[each])
			end
		end
	end

	local count = table.getn(entries)
	offset = math.max(0, math.min(offset, count - MAX_ROWS))
	local shown = math.min(MAX_ROWS, count)
	for index = 1, shown do
		local line, entry = Line(index), entries[offset + index]
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -20 - (index - 1) * ROW)
		if entry.header then
			Header(line, entry.header, entry.count)
		else
			Piece(line, entry.base, entry.item)
		end
		line:Show()
	end
	for index = shown + 1, table.getn(lines) do
		lines[index]:Hide()
	end

	local _, name = ClassName()
	title:SetText("Jewelry  |cff8a8a90"..name.."  ·  "..total..(count > MAX_ROWS and ("  ·  "..(offset + 1).."-"..(offset + shown).." of "..count) or "").."|r")
	if total == 0 then
		empty:Show()
		panel:SetHeight(44)
	else
		empty:Hide()
		panel:SetHeight(24 + shown * ROW)
	end
end

panel:SetScript("OnMouseWheel", function()
	offset = offset - (arg1 or 0) * 3
	panel.Draw()
end)
panel:SetScript("OnShow", function()
	local books = Books()
	if books.left and books.top then
		this:ClearAllPoints()
		this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", books.left, books.top)
	end
	Look()
	panel.Draw()
end)

function SurvivorUI_ToggleJewelry()
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end
