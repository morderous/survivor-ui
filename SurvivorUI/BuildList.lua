-- Survivor UI: the build, in the right column between the run tracker and the
-- damage meter, the same spells side by side with what they deal.
--
-- Every spell slot, filled or not: each spell with its icon, its name in the
-- same color the damage meter gives it, its rank and its share of the damage,
-- then the racial apart (it takes no slot). Empty slots show, since how many
-- are left matters at every card choice. Hover a spell for its card: rank,
-- cooldown, damage and crits. The spells run from the highest rank down, each
-- in a border of its color.
--
-- Under the spells, the jewelry worn (neck, rings, trinkets), the gear a run
-- drops: each slot filled with the piece's quality color, with what it gives in
-- short, read off its tooltip ("Neck  CDR · DMG").
--
-- From the game's addon API (AZS_SPELLS); without it nothing shows. Hold Alt
-- and drag to move; /sui build hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local WIDTH = 224
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 20
local SLOTS = 6                 -- spell slots a run has
local RACIAL_SLOT = 12          -- the action bar's last button carries the racial
local MUTED = { 0.45, 0.45, 0.45 }
local GEAR_SLOTS = {               -- inventory slot, label
	{ 2, "Neck" }, { 11, "Ring" }, { 12, "Ring" }, { 13, "Trinket" }, { 14, "Trinket" },
}
local GEAR_TOP = TITLE_HEIGHT + (SLOTS + 1) * ROW_HEIGHT + 6

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.buildList == nil then
		SurvivorUIDB.buildList = true
	end
	return SurvivorUIDB
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- "holy_wrath" as the meter and the cards name it: "Holy Wrath".
local NAMES = {
	sw_pain = "Shadow Word: Pain", pw_shield = "Power Word: Shield",
	demo_shout = "Demoralizing Shout", hunters_mark = "Hunter's Mark",
}

local function SpellName(key)
	if NAMES[key] then
		return NAMES[key]
	end
	local name = string.gsub(key or "?", "_", " ")
	return (string.gsub(name, "(%a)([%w']*)", function(first, rest) return string.upper(first)..rest end))
end

local function Running()
	if not (AZS_GetPhase and AZS_SPELLS) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

------------------------------------------------------------------------------
-- The frame.

local list = CreateFrame("Frame", "SurvivorUIBuild", UIParent)
list:SetWidth(WIDTH + 12)
list:SetHeight(GEAR_TOP + 16 + table.getn(GEAR_SLOTS) * 17 + 6)
list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -260)
list:SetBackdrop({ bgFile = FLAT })
list:SetBackdropColor(0.04, 0.04, 0.07, 0.55)
list:SetMovable(true)
list:Hide()

local function SavePlace()
	local settings = Settings()
	settings.buildLeft = math.floor(list:GetLeft() + 0.5)
	settings.buildTop = math.floor(list:GetTop() + 0.5)
end

local function RestorePlace()
	local settings = Settings()
	list:ClearAllPoints()
	if settings.buildLeft then
		list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings.buildLeft, settings.buildTop)
	elseif SurvivorUITracker then
		-- Under the run tracker, right edges together.
		list:SetPoint("TOPRIGHT", SurvivorUITracker, "BOTTOMRIGHT", 8, -14)
	else
		list:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -260)
	end
end

list.title = list:CreateFontString(nil, "OVERLAY")
list.title:SetFont(FONT, 11 + FONT_BUMP, "OUTLINE")
list.title:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -6)
list.title:SetTextColor(1, 0.82, 0)
list.title:SetText("Build")

list.count = list:CreateFontString(nil, "OVERLAY")
list.count:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
list.count:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -7)

local rows = {}

local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, list)
	row:SetWidth(WIDTH)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -TITLE_HEIGHT - (index - 1) * ROW_HEIGHT)

	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(FLAT)
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)

	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetTexture(FLAT)
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	-- A border for the highest ranks, hidden otherwise.
	row.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = row:CreateTexture(nil, "OVERLAY")
		line:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(1)
			line:SetPoint(side.."LEFT", row, side.."LEFT", 0, 0)
			line:SetPoint(side.."RIGHT", row, side.."RIGHT", 0, 0)
		else
			line:SetWidth(1)
			line:SetPoint("TOP"..side, row, "TOP"..side, 0, 0)
			line:SetPoint("BOTTOM"..side, row, "BOTTOM"..side, 0, 0)
		end
		line:Hide()
		table.insert(row.edges, line)
	end

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW_HEIGHT - 4)
	row.icon:SetHeight(ROW_HEIGHT - 4)
	row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	row.name:SetPoint("LEFT", row, "LEFT", ROW_HEIGHT + 2, 0)
	row.name:SetWidth(WIDTH - ROW_HEIGHT - 70)
	row.name:SetHeight(12)
	row.name:SetJustifyH("LEFT")

	row.share = row:CreateFontString(nil, "OVERLAY")
	row.share:SetFont(FONT, 8 + FONT_BUMP, "OUTLINE")
	row.share:SetPoint("RIGHT", row, "RIGHT", -44, 0)
	row.share:SetTextColor(0.6, 0.6, 0.6)

	row.rank = row:CreateFontString(nil, "OVERLAY")
	row.rank:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
	row.rank:SetPoint("RIGHT", row, "RIGHT", -4, 0)

	-- The spell's card, as on the damage meter: beside the list, on its left.
	row.cardFrame = list
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		if this.ability and SurvivorUI_CritCardShow then
			SurvivorUI_CritCardShow(this)
		end
	end)
	row:SetScript("OnLeave", function()
		if SurvivorUI_CritCardHide then
			SurvivorUI_CritCardHide()
		end
	end)

	rows[index] = row
	return row
end

local function Border(row, color, alpha)
	for index = 1, table.getn(row.edges) do
		local line = row.edges[index]
		if alpha and alpha > 0 then
			line:SetVertexColor(color[1], color[2], color[3], alpha)
			line:Show()
		else
			line:Hide()
		end
	end
end

-- The top spell's name and rank a point larger, a touch brighter; set only
-- when it changes, since setting a font costs the engine every time.
local function Bold(row, bold)
	if row.bold ~= bold then
		row.bold = bold
		row.name:SetFont(FONT, 9 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
		row.rank:SetFont(FONT, 10 + FONT_BUMP + (bold and 1 or 0), "OUTLINE")
	end
end

-- A spell's row filled with its color, the text light over it; an empty slot
-- or the racial only a faint wash, the text in the color.
local function Paint(row, color, alpha, filled)
	if filled then
		row.name:SetTextColor(1, 1, 1)
		row.rank:SetTextColor(1, 1, 1)
		row.share:SetTextColor(0.9, 0.9, 0.9)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.45)
	else
		row.name:SetTextColor(color[1], color[2], color[3])
		row.rank:SetTextColor(color[1], color[2], color[3])
		row.share:SetTextColor(0.6, 0.6, 0.6)
		row.wash:SetVertexColor(color[1], color[2], color[3], 0.07 * alpha)
	end
	row.rule:SetVertexColor(color[1], color[2], color[3], 0.28 * alpha)
end

local function Fill(row, entry, actionSlot, isRacial)
	local key = Field(entry, "key", 1)
	local name = SpellName(key)
	local color = SurvivorUI_MeterColor and SurvivorUI_MeterColor(name) or { 0.8, 0.8, 0.8 }
	row.ability, row.color = name, color
	row.icon:SetTexture(GetActionTexture and GetActionTexture(actionSlot) or nil)
	row.icon:SetAlpha(1)
	row.name:SetText(isRacial and name.."  |cff8a8a8a(racial)|r" or name)
	row.rank:SetText(tonumber(Field(entry, "rank", 3)) or "")
	local share = SurvivorUI_MeterShare and SurvivorUI_MeterShare(name)
	row.share:SetText(share and share >= 0.005 and math.floor(share * 100 + 0.5).."%" or "")
	Paint(row, color, isRacial and 0.5 or 1, not isRacial)
	row:Show()
end

local function Empty(row)
	row.ability, row.color = nil, nil
	row.icon:SetTexture(FLAT)
	row.icon:SetVertexColor(0.15, 0.15, 0.18)
	row.icon:SetAlpha(0.8)
	row.name:SetText("empty slot")
	row.rank:SetText("")
	row.share:SetText("")
	Paint(row, MUTED, 0.6)
	row:Show()
end

local function Draw()
	local spells = AZS_SPELLS or {}
	local count = table.getn(spells)
	-- The racial comes last in the game's list and takes no slot.
	local slotted = math.max(0, count - 1)
	-- The three highest ranks among the slotted spells, ties to the earlier
	-- slot: the first bold with a full border, the second a full border, the
	-- third a faint one; the rest plain. The list itself runs in that order.
	local order = {}
	for index = 1, slotted do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		local ra = tonumber(Field(spells[a], "rank", 3)) or 0
		local rb = tonumber(Field(spells[b], "rank", 3)) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	-- Rows from the highest rank down; each spell keeps its own action button
	-- for its icon.
	for place = 1, SLOTS do
		local row = Row(place)
		row.icon:SetVertexColor(1, 1, 1)
		local index = order[place]
		if index then
			Fill(row, spells[index], index, false)
		else
			Empty(row)
		end
	end
	-- Every spell the same border in its color; the order says the rest.
	for slot = 1, SLOTS do
		local row = rows[slot]
		if order[slot] then
			Border(row, row.color, 0.6)
		else
			Border(row, nil, 0)
		end
	end
	local racialRow = Row(SLOTS + 1)
	racialRow.icon:SetVertexColor(1, 1, 1)
	if count >= 1 then
		Fill(racialRow, spells[count], RACIAL_SLOT, true)
	else
		racialRow:Hide()
	end
	list.count:SetText((slotted >= SLOTS and "|cffff8080" or "|cffd0d0d0")..math.min(slotted, SLOTS).." / "..SLOTS.."|r")
end

------------------------------------------------------------------------------
-- The gear: each piece of jewelry and what it gives, in short.

-- Words in a tooltip line and their short names, the more specific first.
local STAT_WORDS = {
	{ "explode", "BOOM" }, { "duration", "DUR" },
	{ "critical strike damage", "CRIT DMG" }, { "critical damage", "CRIT DMG" },
	{ "damage of your critical", "CRIT DMG" },
	{ "critical", "CRIT" }, { "crit", "CRIT" }, { "cooldown", "CDR" },
	{ "damage reduction", "DMG RED" }, { "damage taken", "DMG RED" }, { "armor", "DMG RED" },
	{ "area", "AREA" }, { "target", "TGT" }, { "twice", "ECHO" }, { "echo", "ECHO" },
	{ "movement", "SPD" }, { "speed", "SPD" }, { "per second", "REGEN" }, { "regen", "REGEN" },
	{ "health", "HP" }, { "pickup", "PICK" }, { "experience", "XP" }, { "gold", "GOLD" },
	{ "luck", "LUCK" }, { "leech", "LEECH" }, { "heal", "HEAL" }, { "thorns", "THORNS" },
	{ "live", "LIFE" }, { "damage", "DMG" },
}

-- The short name a tooltip line gives: the first word of the list it names,
-- in the list's order, so "+29% critical strike damage" is CRIT DMG, not CRIT.
local function StatOf(text)
	for index = 1, table.getn(STAT_WORDS) do
		if string.find(text, STAT_WORDS[index][1], 1, true) then
			return STAT_WORDS[index][2]
		end
	end
end

-- The same short names for the jewelry collection (Jewelry.lua).
function SurvivorUI_StatOf(text)
	return StatOf(string.lower(text or ""))
end

local scan = CreateFrame("GameTooltip", "SurvivorUIScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Each worn piece, by its link: its rank, the Roman numeral that ends its name
-- ("Blackhand's Breadth IV"); the spell a legendary amulet boosts, named after
-- its colon ("Amulet of the Inferno: Consecration IV"); and what it gives, the
-- tooltip's lines with a number in them. An upgrade renames the piece, so the
-- link alone says when to read it again.
local pieces = {}               -- [item link] = { rank, spell, tags }

local function ReadPiece(slot, link)
	if pieces[link] then
		return pieces[link]
	end
	local _, _, name = string.find(link, "%[(.-)%]")
	name = name or ""
	-- Past rank X the name says "X+", and so does the row.
	local _, _, rank = string.find(name, " ([IVXL]+%+?)$")
	if rank then
		name = string.sub(name, 1, string.len(name) - string.len(rank) - 1)
	end
	-- Only a legendary amulet names a spell: one for each spell of each class.
	local spell
	if slot == 2 and string.find(link, "|cffff8000", 1, true) then
		_, _, spell = string.find(name, ": (.+)$")
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local tags, seen = {}, {}
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIScanTipTextLeft"..index)
		local text = line and string.lower(line:GetText() or "") or ""
		if string.find(text, "%d") then
			local tag = StatOf(text)
			if tag and not seen[tag] then
				seen[tag] = true
				-- With the line's number, its sign dropped: "CRIT DMG 86%".
				local _, _, value = string.find(text, "[%+%-]?(%d+%.?%d*%%?)")
				table.insert(tags, value and (tag.." "..value) or tag)
			end
		end
	end
	pieces[link] = { rank = rank or "I", spell = spell, tags = table.concat(tags, " · ") }
	return pieces[link]
end

list.gearTitle = list:CreateFontString(nil, "OVERLAY")
list.gearTitle:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
list.gearTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -GEAR_TOP)
list.gearTitle:SetTextColor(1, 0.82, 0)
list.gearTitle:SetText("Gear")

-- The jewelry worn, the gear a run drops: one row a slot, filled with the
-- piece's quality color, the slot's name and what the piece gives in short;
-- an empty slot faint. Hover a piece for its own tooltip.
local GEAR_ROW = 17

local gearLines = {}
for index = 1, table.getn(GEAR_SLOTS) do
	local line = CreateFrame("Frame", nil, list)
	line:SetWidth(WIDTH)
	line:SetHeight(GEAR_ROW - 1)
	line:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -GEAR_TOP - 15 - (index - 1) * GEAR_ROW)

	line.wash = line:CreateTexture(nil, "BACKGROUND")
	line.wash:SetTexture(FLAT)
	line.wash:SetAllPoints(line)

	line.edges = {}
	for _, side in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = line:CreateTexture(nil, "BORDER")
		edge:SetTexture(FLAT)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetHeight(1)
			edge:SetPoint(side.."LEFT", line, side.."LEFT", 0, 0)
			edge:SetPoint(side.."RIGHT", line, side.."RIGHT", 0, 0)
		else
			edge:SetWidth(1)
			edge:SetPoint("TOP"..side, line, "TOP"..side, 0, 0)
			edge:SetPoint("BOTTOM"..side, line, "BOTTOM"..side, 0, 0)
		end
		table.insert(line.edges, edge)
	end

	line.label = line:CreateFontString(nil, "OVERLAY")
	line.label:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	line.label:SetPoint("LEFT", line, "LEFT", 4, 0)
	line.tags = line:CreateFontString(nil, "OVERLAY")
	line.tags:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
	line.tags:SetPoint("RIGHT", line, "RIGHT", -4, 0)

	line:EnableMouse(true)
	line:SetScript("OnEnter", function()
		if this.slot and GetInventoryItemLink("player", this.slot) then
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetInventoryItem("player", this.slot)
			GameTooltip:Show()
		end
	end)
	line:SetScript("OnLeave", function() GameTooltip:Hide() end)
	gearLines[index] = line
end

local function PaintGear(line, r, g, b, fill, edge)
	line.wash:SetVertexColor(r, g, b, fill)
	for _, piece in pairs(line.edges) do
		piece:SetVertexColor(r, g, b, edge)
	end
end

-- A piece's bonuses beside its slot, a point or two smaller when they would
-- run into it (a legendary amulet has many). Sized again only when the text
-- changes, as a font set over and over costs.
-- A legendary amulet's spell, short, to leave room for its bonuses: several
-- words by their initials ("Hammer of Justice" HoJ), one long word cut
-- ("Consecration" Consec.). Hover the row for the whole name.
local SMALL_WORDS = { of = true, the = true, ["and"] = true }

local function Short(spell)
	local initials, words = "", 0
	for word in string.gfind(spell, "%S+") do
		words = words + 1
		local first = string.sub(word, 1, 1)
		initials = initials..(SMALL_WORDS[string.lower(word)] and string.lower(first) or string.upper(first))
	end
	if words > 1 then
		return initials
	end
	if string.len(spell) > 7 then
		return string.sub(spell, 1, 6).."."
	end
	return spell
end

local function FitTags(line, text)
	local key = (line.label:GetText() or "").."|"..text
	if line.tagText == key then
		return
	end
	line.tags:SetText(text)
	local labelWidth = line.label:GetStringWidth()
	-- A label not drawn yet measures nothing: sized again next time.
	line.tagText = labelWidth > 0 and key or nil
	local room = WIDTH - 8 - labelWidth - 10
	for size = 9, 6, -1 do
		line.tags:SetFont(FONT, size + FONT_BUMP, "OUTLINE")
		if line.tags:GetStringWidth() <= room then
			break
		end
	end
end

local function DrawGear()
	list.gearTitle:SetText("Jewelry")
	for index = 1, table.getn(GEAR_SLOTS) do
		local slot, label = GEAR_SLOTS[index][1], GEAR_SLOTS[index][2]
		local line = gearLines[index]
		line.slot = slot
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link then
			-- The quality color the link carries: "|cffa335ee" is an epic's purple.
			local _, _, rr, gg, bb = string.find(link, "|c%x%x(%x%x)(%x%x)(%x%x)")
			local r = (tonumber(rr or "cc", 16) or 204) / 255
			local g = (tonumber(gg or "cc", 16) or 204) / 255
			local b = (tonumber(bb or "cc", 16) or 204) / 255
			PaintGear(line, r, g, b, 0.45, 0.7)
			-- The slot, then the piece's rank as a Roman numeral: "Ring  II". A
			-- legendary amulet shows the spell it boosts in the slot's place.
			local piece = ReadPiece(slot, link)
			line.label:SetText((piece.spell and Short(piece.spell) or label).."  "..piece.rank)
			line.label:SetTextColor(1, 1, 1)
			FitTags(line, piece.tags ~= "" and piece.tags or "-")
			line.tags:SetTextColor(1, 1, 1)
		else
			PaintGear(line, 0.5, 0.5, 0.55, 0.06, 0.15)
			line.label:SetText(label)
			line.label:SetTextColor(0.45, 0.45, 0.5)
			FitTags(line, "empty")
			line.tags:SetTextColor(0.4, 0.4, 0.45)
		end
		line:Show()
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
	if Settings().buildList and Running() then
		Draw()
		DrawGear()
		if not list:IsShown() then
			list:Show()
		end
	elseif list:IsShown() then
		list:Hide()
	end
end)

function SurvivorUI_ToggleBuild()
	local settings = Settings()
	settings.buildList = not settings.buildList
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: build list "..(settings.buildList and "shown." or "hidden."))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", RestorePlace)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(list, "Build", SavePlace, nil, RestorePlace)
end
