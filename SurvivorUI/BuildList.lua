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
-- Under the spells, the gear: each piece of jewelry worn (neck, rings,
-- trinkets) with what it gives, read off its tooltip ("Neck  CDR · DMG"). If
-- the pieces cannot be read, what all the gear adds, from the game (AZS_STATS).
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
list:SetHeight(GEAR_TOP + 16 + table.getn(GEAR_SLOTS) * 15 + 8)
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
	{ "critical strike damage", "CRIT DMG" }, { "critical damage", "CRIT DMG" },
	{ "critical", "CRIT" }, { "crit", "CRIT" }, { "cooldown", "CDR" },
	{ "damage reduction", "DMG RED" }, { "damage taken", "DMG RED" }, { "armor", "DMG RED" },
	{ "area", "AREA" }, { "target", "TGT" }, { "twice", "ECHO" }, { "echo", "ECHO" },
	{ "movement", "SPD" }, { "speed", "SPD" }, { "per second", "REGEN" }, { "regen", "REGEN" },
	{ "health", "HP" }, { "pickup", "PICK" }, { "experience", "XP" }, { "gold", "GOLD" },
	{ "luck", "LUCK" }, { "leech", "LEECH" }, { "heal", "HEAL" }, { "thorns", "THORNS" },
	{ "live", "LIFE" }, { "damage", "DMG" },
}

-- The same short names for what all the gear adds (AZS_STATS, keys with a g).
local GEAR_TOTALS = {
	{ "gdmg", "DMG" }, { "gcd", "CDR" }, { "gcrit", "CRIT" }, { "gcm", "CRIT DMG" },
	{ "garm", "DMG RED" }, { "garea", "AREA" }, { "gcnt", "TGT" }, { "gecho", "ECHO" },
	{ "gspd", "SPD" }, { "ghp", "HP" }, { "greg", "REGEN" }, { "gpick", "PICK" },
	{ "glch", "LEECH" }, { "gheal", "HEAL" }, { "gthn", "THORNS" }, { "gliv", "LIFE" },
	{ "gxp", "XP" }, { "ggold", "GOLD" }, { "gluck", "LUCK" },
}

-- Each short name in its section's color in the character pane: Offense,
-- Reach, Defense, Utility.
local OFFENSE, REACH, DEFENSE, UTILITY = "ff7340", "b873ff", "4da6ff", "59e68c"
local TAG_COLORS = {
	["DMG"] = OFFENSE, ["CRIT"] = OFFENSE, ["CRIT DMG"] = OFFENSE, ["CDR"] = OFFENSE, ["ECHO"] = OFFENSE,
	["AREA"] = REACH, ["TGT"] = REACH, ["PICK"] = REACH,
	["HP"] = DEFENSE, ["DMG RED"] = DEFENSE, ["REGEN"] = DEFENSE, ["LEECH"] = DEFENSE,
	["HEAL"] = DEFENSE, ["THORNS"] = DEFENSE, ["LIFE"] = DEFENSE,
	["SPD"] = UTILITY, ["XP"] = UTILITY, ["GOLD"] = UTILITY, ["LUCK"] = UTILITY,
}

local function Tinted(tag, text)
	return "|cff"..(TAG_COLORS[tag] or "d0d0d0")..(text or tag).."|r"
end

local scan = CreateFrame("GameTooltip", "SurvivorUIScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

local readLinks = {}            -- [item link] = "CDR · DMG"

-- Where each total comes from: every worn piece (armor too, slots 1 to 19),
-- its stat lines read off its tooltip. Read again only when the gear changes.
local sources = {}              -- [short name] = { { name, color, value }, ... }
local sourcesKey

local function ReadSources()
	local links = {}
	for slot = 1, 19 do
		links[slot] = GetInventoryItemLink and GetInventoryItemLink("player", slot) or ""
	end
	local key = table.concat(links, "|")
	if key == sourcesKey then
		return
	end
	sourcesKey = key
	sources = {}
	for slot = 1, 19 do
		local link = links[slot]
		if link ~= "" then
			local _, _, name = string.find(link, "%[(.-)%]")
			local _, _, color = string.find(link, "|c(%x%x%x%x%x%x%x%x)")
			scan:SetOwner(WorldFrame, "ANCHOR_NONE")
			scan:ClearLines()
			scan:SetInventoryItem("player", slot)
			for index = 2, scan:NumLines() do
				local line = getglobal("SurvivorUIScanTipTextLeft"..index)
				local text = line and string.lower(line:GetText() or "") or ""
				local _, _, value = string.find(text, "([%+%-]?%d+%.?%d*%%?)")
				if value then
					for _, pair in pairs(STAT_WORDS) do
						if string.find(text, pair[1], 1, true) then
							sources[pair[2]] = sources[pair[2]] or {}
							table.insert(sources[pair[2]], { name = name or "?", color = color or "ffffffff", value = value })
							break
						end
					end
				end
			end
		end
	end
end

-- A total's tooltip: the pieces that add to it.
local function ShowSources(owner, stats)
	ReadSources()
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText("Where it comes from", 1, 0.82, 0)
	for _, stat in pairs(stats) do
		GameTooltip:AddLine(stat.text, 1, 1, 1)
		local list = sources[stat.tag]
		if list and table.getn(list) > 0 then
			for index = 1, table.getn(list) do
				local piece = list[index]
				GameTooltip:AddDoubleLine("   |c"..piece.color..piece.name.."|r", piece.value, 1, 1, 1, 0.85, 0.85, 0.85)
			end
		else
			GameTooltip:AddLine("   no worn piece names it", 0.55, 0.55, 0.55)
		end
	end
	GameTooltip:Show()
end

-- What a piece gives, from its tooltip: the lines with a number in them.
local function ItemTags(slot, link)
	if readLinks[link] then
		return readLinks[link]
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local tags, seen = {}, {}
	for index = 2, scan:NumLines() do
		local line = getglobal("SurvivorUIScanTipTextLeft"..index)
		local text = line and string.lower(line:GetText() or "") or ""
		if string.find(text, "%d") then
			for _, pair in pairs(STAT_WORDS) do
				if string.find(text, pair[1], 1, true) then
					if not seen[pair[2]] then
						seen[pair[2]] = true
						table.insert(tags, Tinted(pair[2]))
					end
					break
				end
			end
		end
	end
	readLinks[link] = table.concat(tags, " · ")
	return readLinks[link]
end

list.gearTitle = list:CreateFontString(nil, "OVERLAY")
list.gearTitle:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
list.gearTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -GEAR_TOP)
list.gearTitle:SetTextColor(1, 0.82, 0)
list.gearTitle:SetText("Gear")

local gearLines = {}
for index = 1, table.getn(GEAR_SLOTS) do
	local line = CreateFrame("Frame", nil, list)
	line:SetWidth(WIDTH)
	line:SetHeight(15)
	line:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -GEAR_TOP - 15 - (index - 1) * 15)
	line.label = line:CreateFontString(nil, "OVERLAY")
	line.label:SetFont(FONT, 8 + FONT_BUMP, "OUTLINE")
	line.label:SetPoint("LEFT", line, "LEFT", 2, 0)
	line.tags = line:CreateFontString(nil, "OVERLAY")
	line.tags:SetFont(FONT, 8 + FONT_BUMP, "OUTLINE")
	line.tags:SetPoint("RIGHT", line, "RIGHT", -4, 0)
	line.tags:SetTextColor(0.85, 0.85, 0.85)
	-- The piece's own tooltip on hover.
	line:EnableMouse(true)
	line:SetScript("OnEnter", function()
		if this.stats then
			ShowSources(this, this.stats)
			return
		end
		if this.slot and GetInventoryItemLink("player", this.slot) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetInventoryItem("player", this.slot)
			GameTooltip:Show()
		end
	end)
	line:SetScript("OnLeave", function() GameTooltip:Hide() end)
	gearLines[index] = line
end

local function Percent(value)
	if math.abs(value) < 5 then
		return string.format("%+.0f%%", value * 100)
	end
	return string.format("%+.0f", value)
end

local function DrawGear()
	local any = false
	for index = 1, table.getn(GEAR_SLOTS) do
		local slot, label = GEAR_SLOTS[index][1], GEAR_SLOTS[index][2]
		local line = gearLines[index]
		line.slot = slot
		line.stats = nil
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		if link then
			any = true
			local _, _, color = string.find(link, "|c(%x%x%x%x%x%x%x%x)")
			line.label:SetText("|c"..(color or "ffffffff")..label.."|r")
			line.tags:SetText(ItemTags(slot, link))
		else
			line.label:SetText("|cff6a6a6a"..label.."|r")
			line.tags:SetText("|cff6a6a6a-|r")
		end
		line:Show()
	end
	if any then
		list.gearTitle:SetText("Gear")
		return
	end
	-- No piece to read: what all the gear adds, two to a line.
	list.gearTitle:SetText("Gear  |cff8a8a8a(all pieces)|r")
	local stats, parts = AZS_STATS or {}, {}
	for _, pair in pairs(GEAR_TOTALS) do
		local value = tonumber(stats[pair[1]])
		if value and value ~= 0 then
			table.insert(parts, { tag = pair[2], text = Tinted(pair[2], pair[2].." "..Percent(value)) })
		end
	end
	for index = 1, table.getn(gearLines) do
		local line = gearLines[index]
		line.slot = nil
		local a, b = parts[index * 2 - 1], parts[index * 2]
		line.label:SetText(a and a.text or "")
		line.tags:SetText(b and b.text or "")
		-- Hover: which pieces add to these two.
		line.stats = a and { a, b } or nil
		if index == 1 and not a then
			line.label:SetText("|cff6a6a6anothing worn|r")
		end
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
