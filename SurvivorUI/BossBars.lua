-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: boss bars.
--
-- A column of flat bars at the top of the screen, one for every boss alive,
-- the final boss on top, then every lair guardian that is awake (and, on
-- request, every elite). Each shows the whole name on the left and the health
-- left on the right, in the color of its kind; an enraged boss's name turns red;
-- its debuffs as small icons, draining as they run out, under it (or over it,
-- left or right of it, or inside it before the health); its raid mark before
-- its name. The game sends these to addons for the whole map, so a bar stays
-- live at any distance, unlike a nameplate.
--
-- Each kind on its own (the options' Boss bars tab): bosses (the final boss
-- with them), guardians and elites, each on or off, at its own size, its
-- health in its own look. In a group, your friends' debuffs can be left out,
-- or put after yours when a bar has more than it shows; the game does not say
-- whose a debuff is, so one of your own spells counts as yours.
--
-- Click a bar to target that enemy. Hold Alt and drag a bar to move the column.
-- The game's own boss bars are put away while these are on, and come back with
-- /sui bosses. Needs the game's addon API (AZS_UNITS); without it nothing shows.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local BAR_WIDTH = 220
local BAR_HEIGHT = 18
local BAR_GAP = 4
local MAX_BARS = 8              -- the most bars at once, unless chosen (bossBarsMost)

-- Each kind's color and the settings it goes by (group): the final boss's are
-- the bosses'.
local KINDS = {
	final    = { order = 1, color = { 0.95, 0.25, 0.55 }, tag = "Final", group = "Boss" },
	boss     = { order = 2, color = { 0.72, 0.32, 1.00 }, group = "Boss" },
	guardian = { order = 3, color = { 0.20, 0.75, 0.95 }, tag = "Guardian", group = "Guardian" },
	-- The item qualities' order, each a little lighter: epic, rare, uncommon.
	elite    = { order = 4, color = { 0.35, 1.00, 0.20 }, group = "Elite" },
}

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	-- On on a new install from v3.0.12 (off before, the run tracker showing
	-- the bosses' health); off again from v3.0.53, the new plates showing the
	-- bosses (Lucas, 2026-11-02). Whoever had them keeps them.
	if SurvivorUIDB.bossBars == nil then
		SurvivorUIDB.bossBars = false
	end
	return SurvivorUIDB
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- 950, 1.2k, 3.4m
-- A big number as the whole addon writes it (SurvivorUI_Abbrev): 4.9k, 1.11M, 9.27B.
local function Short(value)
	if SurvivorUI_Abbrev then
		return SurvivorUI_Abbrev(value)
	end
	return tostring(math.floor((tonumber(value) or 0) + 0.5))
end

local function Playing()
	if not (AZS_GetPhase and AZS_UNITS) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase == "playing" or phase == "choosing" or phase == "paused"
end

------------------------------------------------------------------------------
-- The bars' shape, as the settings say (the options' preview draws it the
-- same way, through SurvivorUI_BossBarsLook below).

local DEBUFF_SIZE = BAR_HEIGHT - 4   -- inside the bar
local DEBUFF_GAP = 2
local OUT_GAP = 3                    -- outside: the bar's edge to its icons' (edges 1 each)
local OUT_SIZE = 16                  -- outside icons, unless chosen (bossBarsDebuffSize)
local MAX_DEBUFFS = 6                -- a bar's, unless chosen (bossBarsDebuffMost)
local MOST_DEBUFFS = 16              -- the game sends 16 an enemy at most
local VALUE_ROOM = 38                -- the health's share at the bar's right end
local PLACES = { under = true, over = true, left = true, right = true, inside = true }
local LOOKS = { percent = true, absolute = true, both = true, absolutePercent = true, off = true }

local function Clamp(value, low, high, default)
	value = tonumber(value)
	if not value then
		return default
	end
	return math.max(low, math.min(high, value))
end

-- Into shape: place (of the debuffs), size (outside), align (under and over:
-- from the bar's left, middle or right), order (under and over: "right", the
-- first at the line's right end), most (a bar's debuffs), friends, mineFirst,
-- bars (at once), and kinds.Boss / .Guardian / .Elite, each on, size, health.
local function Shape(shape)
	local db = Settings()
	local place = db.bossBarsDebuffs
	shape.place = PLACES[place or ""] and place or "under"
	shape.size = math.floor(Clamp(db.bossBarsDebuffSize, 12, 28, OUT_SIZE) + 0.5)
	local align = db.bossBarsDebuffAlign
	shape.align = (align == "right" or align == "center") and align or "left"
	shape.order = db.bossBarsDebuffOrder == "right" and "right" or "left"
	shape.most = math.floor(Clamp(db.bossBarsDebuffMost, 1, MOST_DEBUFFS, MAX_DEBUFFS) + 0.5)
	shape.friends = db.bossBarsFriends ~= false
	shape.mineFirst = db.bossBarsMineFirst ~= false
	shape.bars = math.floor(Clamp(db.bossBarsMost, 1, 12, MAX_BARS) + 0.5)
	local health = db.bossHealth
	health = LOOKS[health or ""] and health or "absolutePercent"
	for group, kind in pairs(shape.kinds) do
		local look = db["bossBars"..group.."Health"]
		kind.health = LOOKS[look or ""] and look or health
		kind.size = Clamp(db["bossBars"..group.."Size"], 0.5, 2, 1)
	end
	shape.kinds.Boss.on = db.bossBarsBosses ~= false
	shape.kinds.Guardian.on = db.bossBarsGuardians ~= false
	shape.kinds.Elite.on = db.bossBarsElites == true
	return shape
end

-- A bar's row in the column, in the bar's own measures (its kind's size
-- times them on screen): how tall, where the bar's top stands in it, and how
-- many icons a line under or over it. A bar that can have the game's debuffs
-- (reserve) keeps a line for them under or over it even with none, so the
-- column does not jump as they come and go.
local function Row(shape, count, reserve)
	local place = shape.place
	if place == "inside" then
		return BAR_HEIGHT, 0, 1
	elseif place == "left" or place == "right" then
		local tall = math.max(BAR_HEIGHT, shape.size)
		return tall, (tall - BAR_HEIGHT) / 2, 1
	end
	local each = math.max(1, math.floor((BAR_WIDTH + DEBUFF_GAP) / (shape.size + DEBUFF_GAP)))
	local lines = math.ceil(count / each)
	if reserve and lines < 1 then
		lines = 1
	end
	if lines < 1 then
		return BAR_HEIGHT, 0, each
	end
	local band = OUT_GAP + lines * shape.size + (lines - 1) * DEBUFF_GAP
	return BAR_HEIGHT + band, place == "over" and band or 0, each
end

-- Where a bar's icon goes (its top left from the bar's top left, down
-- counted positive) and how large: inside, right to left from the health;
-- under and over, lined up from the bar's left, middle or right, a line more
-- past each (each), the count shown (count) to center and turn them; left
-- and right of it, outward from it.
local function IconAt(shape, index, each, valueRoom, count)
	local place = shape.place
	if place == "inside" then
		return BAR_WIDTH - (valueRoom or VALUE_ROOM) - index * DEBUFF_SIZE - (index - 1) * DEBUFF_GAP,
			(BAR_HEIGHT - DEBUFF_SIZE) / 2, DEBUFF_SIZE
	end
	local size = shape.size
	local step = size + DEBUFF_GAP
	if place == "left" then
		return -(OUT_GAP + index * size + (index - 1) * DEBUFF_GAP), (BAR_HEIGHT - size) / 2, size
	elseif place == "right" then
		return BAR_WIDTH + OUT_GAP + (index - 1) * step, (BAR_HEIGHT - size) / 2, size
	end
	-- The line's icons sit from the bar's left, its middle or its right
	-- (align), and run from its left end or its right (order: "right", the
	-- first at the right end; Lucas, 2026-11-05).
	local column, line = math.mod(index - 1, each), math.floor((index - 1) / each)
	local inLine = math.max(1, math.min(each, (count or index) - line * each))
	if shape.order == "right" then
		column = inLine - 1 - column
	end
	local x = column * step
	local wide = inLine * step - DEBUFF_GAP
	if shape.align == "right" then
		x = x + BAR_WIDTH - wide
	elseif shape.align == "center" then
		x = x + math.floor((BAR_WIDTH - wide) / 2 + 0.5)
	end
	if place == "over" then
		return x, -(OUT_GAP + size + line * step), size
	end
	return x, BAR_HEIGHT + OUT_GAP + line * step, size
end

-- The column's room across, in the column's measures: what the icons need
-- left of the bars, the widest bar of the kinds on, and what the icons need
-- right of them (the most a bar shows, at the largest kind's size).
local function Column(shape)
	local widest, largest = 0, 0
	for _, kind in pairs(shape.kinds) do
		if kind.on then
			widest = math.max(widest, BAR_WIDTH * kind.size)
			largest = math.max(largest, kind.size)
		end
	end
	if widest == 0 then
		widest, largest = BAR_WIDTH, 1
	end
	local room = 0
	if shape.place == "left" or shape.place == "right" then
		room = largest * (OUT_GAP + shape.most * (shape.size + DEBUFF_GAP) - DEBUFF_GAP)
	end
	return shape.place == "left" and room or 0, widest, shape.place == "right" and room or 0
end

-- The debuffs a bar shows, of the game's (each .mine set when together):
-- out of a group all are yours; in one, your friends' too or not, and yours
-- first when the most cuts.
local function Pick(list, shape, together)
	local out = {}
	local most = shape.most
	local friends = shape.friends or not together
	if together and friends and shape.mineFirst then
		for pass = 1, 2 do
			for index = 1, table.getn(list) do
				local debuff = list[index]
				if table.getn(out) >= most then
					return out
				end
				if (pass == 1) == (debuff.mine and true or false) then
					table.insert(out, debuff)
				end
			end
		end
		return out
	end
	for index = 1, table.getn(list) do
		local debuff = list[index]
		if table.getn(out) >= most then
			break
		end
		if friends or debuff.mine then
			table.insert(out, debuff)
		end
	end
	return out
end

------------------------------------------------------------------------------
-- Yours or a friend's. The game's debuffs say nothing of who laid them
-- (AZS_GetDebuffs, the game's 0.141.0): one whose spell is one of your build's
-- (AZS_SPELLS, by its key or name) counts as yours, any other as a friend's.

local SPELL_NAMES = {
	sw_pain = "Shadow Word: Pain", pw_shield = "Power Word: Shield",
	demo_shout = "Demoralizing Shout", rockbiter = "Rockbiter Weapon",
}
local mineKeys, mineFrom, mineAt, mineOf = {}, nil, 0, {}

local function Letters(text)
	return (string.gsub(string.lower(tostring(text or "")), "[^%a]", ""))
end

local function Keep(keys, text)
	local letters = Letters(text)
	if letters ~= "" then
		keys[letters] = true
	end
end

-- Your spells' keys and names in letters alone, read again as the list
-- changes (and every 2 seconds, should it change in place).
local function MineKeys()
	local now = GetTime()
	if AZS_SPELLS == mineFrom and now - mineAt < 2 then
		return mineKeys
	end
	mineFrom, mineAt, mineKeys, mineOf = AZS_SPELLS, now, {}, {}
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		local key = type(entry) == "table" and (entry.key or entry[1])
		if key then
			Keep(mineKeys, key)
			Keep(mineKeys, SPELL_NAMES[key])
			if entry.name then
				Keep(mineKeys, SurvivorUI_English and SurvivorUI_English(entry.name) or entry.name)
			end
		end
	end
	return mineKeys
end

local function Mine(debuff)
	local keys = MineKeys()
	local spell, name = debuff.spell, debuff.name
	local id = tostring(spell or "").."|"..tostring(name or "")
	local known = mineOf[id]
	if known == nil then
		known = (spell and keys[Letters(spell)]) or (name and (keys[Letters(name)]
			or (SurvivorUI_English and keys[Letters(SurvivorUI_English(name))]))) or false
		mineOf[id] = known and true or false
	end
	return known
end

local function InGroup()
	if SurvivorUI_InParty then
		return SurvivorUI_InParty() and true or false
	end
	return GetNumPartyMembers and GetNumPartyMembers() > 0
end

------------------------------------------------------------------------------
-- The column.

local holder = CreateFrame("Frame", "SurvivorUIBosses", UIParent)
holder:SetWidth(BAR_WIDTH)
-- Room for four bars at least: the area Alt outlines, though only the bars show.
local LEAST_ROOM = 4 * (BAR_HEIGHT + BAR_GAP)
holder:SetHeight(LEAST_ROOM)
holder:SetMovable(true)

-- Its first place: against the run tracker's left side, tops level (the top
-- of the screen's middle, with no tracker).
local function DefaultPlace()
	holder:ClearAllPoints()
	local tracker = getglobal("SurvivorUITracker")
	if tracker then
		-- Left of the run tracker, a little under its top (its first place
		-- since v3.0.6).
		holder:SetPoint("TOPRIGHT", tracker, "TOPLEFT", -8, -55)
	else
		holder:SetPoint("TOP", UIParent, "TOP", 0, -90)
	end
end
DefaultPlace()

local function SavePlace()
	local settings = Settings()
	settings.bossLeft = math.floor(holder:GetLeft() + 0.5)
	settings.bossTop = math.floor(holder:GetTop() + 0.5)
end

local function RestorePlace()
	local settings = Settings()
	if settings.bossLeft then
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings.bossLeft, settings.bossTop)
	else
		DefaultPlace()
	end
end

-- The column as wide as its bars and their icons, as tall as its bars.
local function Room(width, height)
	height = math.max(LEAST_ROOM, height)
	if holder.roomWidth ~= width then
		holder.roomWidth = width
		holder:SetWidth(width)
	end
	if holder.roomHeight ~= height then
		holder.roomHeight = height
		holder:SetHeight(height)
	end
end

local bars = {}
local hovered                    -- the bar under the mouse: Survivor Plates lines its enemy's plate in white

-- The enemy of the bar under the mouse, for Survivor Plates; nil for none.
local function Light(bar)
	hovered = bar
	if SurvivorPlates_Light then
		SurvivorPlates_Light(bar and bar.unitName, bar and bar.unitId)
	end
end

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end

	-- Put in its place as it is filled (Place): its kind's size is its scale.
	bar = CreateFrame("Button", nil, holder)
	bar:SetWidth(BAR_WIDTH)
	bar:SetHeight(BAR_HEIGHT)

	bar.border = bar:CreateTexture(nil, "BACKGROUND")
	bar.border:SetTexture(FLAT)
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)

	bar.backing = bar:CreateTexture(nil, "BORDER")
	bar.backing:SetTexture(FLAT)
	bar.backing:SetVertexColor(0.08, 0.08, 0.10, 0.92)
	bar.backing:SetAllPoints(bar)

	bar.health = CreateFrame("StatusBar", nil, bar)
	bar.health:SetAllPoints(bar)
	bar.health:SetStatusBarTexture(FLAT)
	bar.health:SetMinMaxValues(0, 1)

	bar.name = bar.health:CreateFontString(nil, "OVERLAY")
	bar.name:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.name:SetWidth(BAR_WIDTH - 50)
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	-- Its raid mark (Marks.lua), before its name.
	bar.markRoom = 0
	bar.raid = bar.health:CreateTexture(nil, "OVERLAY")
	bar.raid:SetWidth(BAR_HEIGHT - 2)
	bar.raid:SetHeight(BAR_HEIGHT - 2)
	bar.raid:Hide()

	bar.value = bar.health:CreateFontString(nil, "OVERLAY")
	bar.value:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	bar.value:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	bar.value:SetTextColor(1, 1, 1)

	bar:RegisterForClicks("LeftButtonUp")
	bar:SetScript("OnClick", function()
		if this.unitName and TargetByName then
			TargetByName(this.unitName, true)
		end
	end)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		if SurvivorUI_MoveKeyDown() then
			holder:StartMoving()
		end
	end)
	bar:SetScript("OnDragStop", function()
		holder:StopMovingOrSizing()
		SavePlace()
	end)
	bar:SetScript("OnEnter", function()
		Light(this)
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.unitName or "", 1, 1, 1)
		if this.kindLabel then
			GameTooltip:AddLine(SurvivorUI_T(this.kindLabel), this.color[1], this.color[2], this.color[3])
		end
		GameTooltip:AddDoubleLine(SurvivorUI_T("Health"), (this.hp or 0).." / "..(this.hpm or 0), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:AddLine(SurvivorUI_T("Click to target.").." "..SurvivorUI_MoveHint(), 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function()
		Light(nil)
		GameTooltip:Hide()
	end)

	bar.debuffs = {}
	bars[index] = bar
	return bar
end

-- A bar in the column at x, y (the column's measures), at its kind's size.
local function Place(bar, x, y, size)
	if bar.atSize ~= size then
		bar.atSize, bar.atX = size, nil
		bar:SetScale(size)
	end
	if bar.atX ~= x or bar.atY ~= y then
		bar.atX, bar.atY = x, y
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", holder, "TOPLEFT", x / size, -y / size)
	end
end

------------------------------------------------------------------------------
-- The debuffs on each enemy (AZS_GetDebuffs): small icons under its bar (or
-- where chosen). Each drains as it runs out: the time gone turns grey from
-- the top, a thin light line where it stands, the time left in the middle and
-- the stacks in the corner; edged in its dispel type's color. Hover one for
-- its name. An elite's, which the game does not send, come from your target
-- or the enemy under the mouse when it is that elite (by name, as a click on
-- the bar targets it).

local function TimeLeft(seconds)
	if seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	end
	return math.floor(seconds + 0.5)
end

-- A font string at a size of its own (with the piece's text size step on
-- it), told to EditCard.lua's walk as its own so the step is not put twice.
local function Sized(text, size)
	if text.bbSize == size then
		return
	end
	text.bbSize = size
	local path, _, flags = text:GetFont()
	local want = math.max(6, size + (SurvivorUI_PieceTextStep and SurvivorUI_PieceTextStep("Boss bars") or 0))
	text:SetFont(path or SurvivorUI_FONT, want, flags or "OUTLINE")
	text.suiBase, text.suiSize = size, want
	text.suiPath = text:GetFont()
end

local function DebuffIcon(bar, index)
	local icon = bar.debuffs[index]
	if icon then
		return icon
	end
	icon = CreateFrame("Frame", nil, bar.health)
	icon:SetFrameLevel(bar.health:GetFrameLevel() + 2)
	icon:SetWidth(DEBUFF_SIZE)
	icon:SetHeight(DEBUFF_SIZE)
	icon.size = DEBUFF_SIZE

	icon.edge = icon:CreateTexture(nil, "BACKGROUND")
	icon.edge:SetTexture(FLAT)
	icon.edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	icon.edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)

	-- The whole icon in grey, and over it the part still to run in color.
	icon.grey = icon:CreateTexture(nil, "BORDER")
	icon.grey:SetAllPoints(icon)
	icon.grey:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
	icon.art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
	icon.line = icon:CreateTexture(nil, "OVERLAY")
	icon.line:SetTexture(FLAT)
	icon.line:SetVertexColor(1, 1, 1, 0.75)
	icon.line:SetHeight(1)
	icon.line:SetPoint("BOTTOMLEFT", icon.art, "TOPLEFT", 0, 0)
	icon.line:SetPoint("BOTTOMRIGHT", icon.art, "TOPRIGHT", 0, 0)

	icon.time = icon:CreateFontString(nil, "OVERLAY")
	icon.time:SetFont(SurvivorUI_FONT, 8 + FONT_BUMP, "OUTLINE")
	icon.time.bbSize = 8 + FONT_BUMP
	icon.time:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.time:SetTextColor(1, 1, 1)
	icon.stacks = icon:CreateFontString(nil, "OVERLAY")
	icon.stacks:SetFont(SurvivorUI_FONT, 7 + FONT_BUMP, "OUTLINE")
	icon.stacks.bbSize = 7 + FONT_BUMP
	icon.stacks:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1)
	icon.stacks:SetTextColor(1, 0.85, 0.3)

	icon:EnableMouse(true)
	icon:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(this.name or "", 1, 0.3, 0.3)
		if this.dispel then
			GameTooltip:AddLine(this.dispel, 0.7, 0.7, 0.7)
		end
		if this.left then
			GameTooltip:AddLine(SurvivorUI_TF("{1} sec left", math.floor(this.left + 0.5)), 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

	bar.debuffs[index] = icon
	return icon
end

-- An icon at its size, its words a little larger on a larger icon.
local function Fit(icon, size)
	if icon.size == size then
		return
	end
	icon.size = size
	icon:SetWidth(size)
	icon:SetHeight(size)
	local words = 8 + FONT_BUMP + math.floor((size - DEBUFF_SIZE) / 4)
	Sized(icon.time, words)
	Sized(icon.stacks, words - 1)
end

-- The part of the icon still to run, from the bottom: 1 is all of it.
local function Drain(icon, share)
	local size = icon.size or DEBUFF_SIZE
	if share >= 1 then
		icon.art:SetHeight(size)
		icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon.art:Show()
		icon.line:Hide()
	elseif share <= 0 then
		icon.art:Hide()
		icon.line:Hide()
	else
		icon.art:SetHeight(size * share)
		icon.art:SetTexCoord(0.08, 0.92, 0.92 - 0.84 * share, 0.92)
		icon.art:Show()
		icon.line:Show()
	end
end

-- An enemy's debuffs, and whether they come with their names (the game's,
-- for a boss or a guardian; an elite's from the target or the mouseover).
local function DebuffList(bar, group, id)
	if group ~= "Elite" then
		if AZS_GetDebuffs and id then
			local ok, list = pcall(AZS_GetDebuffs, id)
			if ok and type(list) == "table" then
				return list, true
			end
		end
		return {}, true
	end
	local token
	if UnitExists("target") and UnitName("target") == bar.unitName then
		token = "target"
	elseif UnitExists("mouseover") and UnitName("mouseover") == bar.unitName then
		token = "mouseover"
	end
	local list = {}
	if token and UnitDebuff then
		for index = 1, MOST_DEBUFFS do
			local texture, count, dispel = UnitDebuff(token, index)
			if not texture then
				break
			end
			list[index] = { icon = texture, stacks = count, dispelType = dispel }
		end
	end
	return list, false
end

local function FillDebuffs(bar, shape, group, id)
	local list, named = DebuffList(bar, group, id)
	local together = named and InGroup()
	if together then
		for index = 1, table.getn(list) do
			list[index].mine = Mine(list[index])
		end
	end
	local shown = Pick(list, shape, together)
	local count = table.getn(shown)
	local tall, top, each = Row(shape, count, group ~= "Elite")
	bar.tall, bar.top = tall, top
	for index = 1, count do
		local debuff = shown[index]
		local icon = DebuffIcon(bar, index)
		local x, y, size = IconAt(shape, index, each, bar.valueRoom, count)
		Fit(icon, size)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
		local art = debuff.icon or ""
		if art ~= "" and not string.find(art, "\\", 1, true) then
			art = "Interface\\Icons\\"..art
		end
		if art == "" then
			art = "Interface\\Icons\\INV_Misc_QuestionMark"
		end
		icon.art:SetTexture(art)
		icon.grey:SetTexture(art)
		-- Grey where the client can; else only darker.
		if icon.grey.SetDesaturated then
			icon.grey:SetDesaturated(1)
		end
		icon.grey:SetVertexColor(0.45, 0.45, 0.45)
		icon.name, icon.dispel = debuff.name, debuff.dispelType
		local tint = debuff.dispelType and DebuffTypeColor and DebuffTypeColor[debuff.dispelType]
		if tint then
			icon.edge:SetVertexColor(tint.r, tint.g, tint.b, 1)
		else
			icon.edge:SetVertexColor(0, 0, 0, 1)
		end
		local stacks = tonumber(debuff.stacks) or 0
		icon.stacks:SetText(stacks > 1 and stacks or "")
		local left, duration = tonumber(debuff.remaining), tonumber(debuff.duration)
		if left and duration and duration > 0 and not debuff.permanent then
			icon.left = left
			Drain(icon, left / duration)
			icon.time:SetText(TimeLeft(left))
		else
			icon.left = nil
			Drain(icon, 1)
			icon.time:SetText("")
		end
		icon:Show()
	end
	for index = count + 1, table.getn(bar.debuffs) do
		bar.debuffs[index]:Hide()
	end
	-- The name gives way to the health, and to the icons inside the bar.
	local inside = shape.place == "inside" and count * (DEBUFF_SIZE + DEBUFF_GAP) or 0
	bar.name:SetWidth(BAR_WIDTH - (bar.valueRoom or VALUE_ROOM) - 8 - (bar.markRoom or 0) - inside)
end

local KIND_LABELS = { final = "Final boss", boss = "Boss", guardian = "Lair guardian", elite = "Elite" }

local function Fill(bar, unit, shape)
	local kind = Field(unit, "kind", 1) or "elite"
	local style = KINDS[kind] or KINDS.elite
	local own = shape.kinds[style.group]
	local name = Field(unit, "name", 3) or "?"
	local hp = tonumber(Field(unit, "hp", 4)) or 0
	local hpm = tonumber(Field(unit, "hpm", 5)) or 0
	local state = tonumber(Field(unit, "state", 6)) or 0
	local share = hpm > 0 and hp / hpm or 0

	bar.unitName, bar.hp, bar.hpm = name, hp, hpm
	bar.unitId = Field(unit, "id", 2)
	-- The bars move up and down as the enemies come and go: the light follows.
	if bar == hovered then
		Light(bar)
	end
	bar.color = style.color
	bar.kindLabel = KIND_LABELS[kind]
	bar.kindSize = own.size
	bar.health:SetStatusBarColor(style.color[1], style.color[2], style.color[3], 0.9)
	bar.health:SetValue(share)

	-- Its raid mark before its name, when it wears one.
	local markRoom = 0
	local raid = SurvivorUI_RaidMarkOf and SurvivorUI_RaidMarkOf(Field(unit, "id", 2))
	if SurvivorUI_SetRaidMarkTexture then
		SurvivorUI_SetRaidMarkTexture(bar.raid, raid)
	end
	if raid then
		bar.raid:SetPoint("LEFT", bar, "LEFT", 2, 0)
		markRoom = BAR_HEIGHT - 1
	end
	if bar.markRoom ~= markRoom then
		bar.markRoom = markRoom
		bar.name:SetPoint("LEFT", bar, "LEFT", 5 + markRoom, 0)
	end

	-- An enraged boss (state 1) wears its name in red.
	bar.name:SetText(name)
	if state == 1 and (kind == "boss" or kind == "final") then
		bar.name:SetTextColor(1, 0.35, 0.35)
	else
		bar.name:SetTextColor(1, 1, 1)
	end
	-- In its kind's look (the options' Boss bars tab, else /sui opt's Frames
	-- & bar): 73%, 1.2M, 1.2M / 3.4M or 1.2M | 73%; Off, the name alone.
	if own.health == "off" then
		bar.value:SetText("")
		bar.valueRoom = 4
	else
		if SurvivorUI_HealthText then
			bar.value:SetText(SurvivorUI_HealthText(hp, hpm, own.health))
		else
			bar.value:SetText(math.floor(share * 100 + 0.5).."%")
		end
		bar.valueRoom = math.max(VALUE_ROOM, math.ceil(bar.value:GetStringWidth()) + 12)
	end

	-- The target wears a white border.
	if UnitExists("target") and UnitName("target") == name then
		bar.border:SetVertexColor(1, 1, 1, 1)
	else
		bar.border:SetVertexColor(0, 0, 0, 1)
	end
	FillDebuffs(bar, shape, style.group, tonumber(Field(unit, "id", 2)))
	bar:Show()
end

local function Wanted(unit, shape)
	local kind = Field(unit, "kind", 1)
	local style = KINDS[kind or ""]
	if not (style and shape.kinds[style.group].on) then
		return false
	end
	if kind == "guardian" then
		-- A guardian asleep in its lair is not a fight yet; one already hurt
		-- is, though the game still calls it asleep (feared from the first hit).
		local hp, hpm = tonumber(Field(unit, "hp", 4)) or 0, tonumber(Field(unit, "hpm", 5)) or 0
		return (tonumber(Field(unit, "state", 6)) or 0) == 1 or (hpm > 0 and hp > 0 and hp < hpm)
	end
	return true
end

-- The kinds in their order; two of a kind by their ids, so they keep their places.
local function Before(a, b)
	local ka = KINDS[Field(a, "kind", 1) or ""] or KINDS.elite
	local kb = KINDS[Field(b, "kind", 1) or ""] or KINDS.elite
	if ka.order ~= kb.order then
		return ka.order < kb.order
	end
	return (tonumber(Field(a, "id", 2)) or 0) < (tonumber(Field(b, "id", 2)) or 0)
end

local SHAPE = { kinds = { Boss = {}, Guardian = {}, Elite = {} } }

local function Update()
	local settings = Settings()
	local shown = 0
	-- Apart from the run tracker: shown whether it shows the bosses' health or
	-- not.
	if settings.bossBars and Playing() then
		local shape = Shape(SHAPE)
		local picked = {}
		for index = 1, table.getn(AZS_UNITS) do
			local unit = AZS_UNITS[index]
			if Wanted(unit, shape) then
				table.insert(picked, unit)
			end
		end
		table.sort(picked, Before)
		-- One under the other, each in its row (its icons' room with it).
		local left, widest, right = Column(shape)
		local y = 0
		for index = 1, math.min(shape.bars, table.getn(picked)) do
			local bar = Bar(index)
			Fill(bar, picked[index], shape)
			local size = bar.kindSize or 1
			Place(bar, left, y + bar.top * size, size)
			y = y + bar.tall * size + BAR_GAP
			shown = index
		end
		Room(left + widest + right, y - BAR_GAP)
	end
	for index = shown + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].unitName = nil
		if bars[index] == hovered then
			Light(nil)
		end
	end
end

local elapsed = 0
holder:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 0.1 then
		elapsed = 0
		Update()
	end
end)

-- For the options' preview: the bars' measures and shape, as drawn here.
SurvivorUI_BossBarsLook = {
	WIDTH = BAR_WIDTH, HEIGHT = BAR_HEIGHT, GAP = BAR_GAP, VALUE_ROOM = VALUE_ROOM,
	DEBUFF_SIZE = DEBUFF_SIZE, DEBUFF_GAP = DEBUFF_GAP, KINDS = KINDS,
	Shape = function() return Shape({ kinds = { Boss = {}, Guardian = {}, Elite = {} } }) end,
	Row = Row, IconAt = IconAt, Column = Column, Pick = Pick, TimeLeft = TimeLeft,
}

------------------------------------------------------------------------------
-- The game's own boss bars: away while these are on. The setting is the game's
-- and is saved, so the addon remembers that it was the one to turn it off.

local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	-- Away while these bars or the run tracker show the bosses' health.
	if settings.bossBars or settings.trackerHealth or settings.noGameBosses then
		if AZS_IsHudShown("bosses") then
			AZS_SetHudShown("bosses", false)
			settings.hidGameBosses = true
		end
	elseif settings.hidGameBosses then
		AZS_SetHudShown("bosses", true)
		settings.hidGameBosses = nil
	end
end

-- For the options: off, the Default one, or nothing ("When off").
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.bosses = ApplyGameHud

-- For the options' Run tracker tab, as its boss health is switched.
SurvivorUI_ApplyBossHud = ApplyGameHud

function SurvivorUI_BossBars(argument)
	local settings = Settings()
	if argument == "elites" then
		settings.bossBarsElites = not settings.bossBarsElites
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: boss bars "..(settings.bossBarsElites and "list elites too." or "leave elites out."))
	else
		settings.bossBars = not settings.bossBars
		ApplyGameHud()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.bossBars and "boss bars on; the Default ones are put away." or (settings.noGameBosses and "boss bars off, and the Default ones stay away." or "boss bars off; the Default ones are back.")))
	end
	Update()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Boss bars", SavePlace, nil, function()
		DefaultPlace()
	end)
end
