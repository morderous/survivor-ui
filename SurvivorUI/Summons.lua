-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: your summons over the player frame, a buff-sized icon each:
--
-- - one that stays the whole run (the Imp, a Soul Devourer's Felhunter or a
--   Soul Link's Voidwalker, a hunter's beast, a druid's Treants, a shaman's
--   Spirit Wolves, a mage's Water Elemental): its icon alone, no number, and
--   only with "Track permanent pets" on (the Summons tab; off by default);
-- - a kind that comes and goes with a limit of its own (an Infernal or a
--   Doomguard, one at a time; a Felguard or a Pit Lord, two): "out/limit" in
--   the corner and the longest time one of them has left in the middle;
-- - the Legion Gate's lesser demons (Imps, Succubi, Felhunters, Voidwalkers
--   that come and go) as one icon, the talent's own, "out/12"; hover it for
--   each kind.
--
-- The game tells them from its 0.110 (AZS_GetSummons: key, kind, name, icon,
-- permanent, remaining); before it there is nothing to show. The limits are
-- the game's rules (LIMITS, GATE_MOST), to set again when it changes them.
-- Over the buffs by default, going with the player frame, until moved on
-- its own (move mode: "Summons"). Module "Summons" (Modules, Combat).

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local SIZE = 22                 -- the buffs' icon size
local GAP = 3
local MOST = 12                 -- icons at most
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local Feature = SurvivorUI_Feature or function() return true end

-- How many of a kind the game lets out at once (its 0.110): the greater
-- demons by their talents; the rest stay for good and need none.
local LIMITS = { infernal = 1, doomguard = 1, felguard = 2, pit_lord = 2, water_elemental = 1, treant = 2, spirit_wolf = 2 }
-- The Legion Gate's lesser demons: "3 random lesser demons every 4 sec (max 12)".
local LESSER = { imp = true, succubus = true, felhunter = true, voidwalker = true }
local GATE_MOST = 12
local GATE_NAME = "Legion Gate"
local GATE_ICON = "Interface\\Icons\\INV_Weapon_ShortBlade_05"   -- the talent's icon (Sinister Strike's too)

local holder = CreateFrame("Frame", "SurvivorUISummons", UIParent)
holder:SetWidth(SIZE)
holder:SetHeight(SIZE)
holder:SetMovable(true)
holder:SetClampedToScreen(true)
holder:Hide()

local function Text(parent, size, point, x, y)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	text:SetPoint(point, parent, point, x, y)
	return text
end

local function TimeText(seconds)
	if seconds >= 3600 then
		return math.floor(seconds / 3600 + 0.5).."h"
	elseif seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return math.floor(seconds)
	end
	return string.format("%.1f", seconds)
end

------------------------------------------------------------------------------
-- The icons, made as first needed, each holding the group it shows.

local hovered                   -- the icon under the mouse, its tooltip kept current

local function Tooltip(icon)
	local group = icon.group
	if not group then
		GameTooltip:Hide()
		return
	end
	GameTooltip:SetOwner(icon, "ANCHOR_TOPLEFT")
	GameTooltip:AddLine(group.name or group.key or "?", 1, 0.82, 0)
	if group.stays then
		GameTooltip:AddLine(group.count == 1 and "Stays the whole run" or group.count.." out, the whole run", 1, 1, 1)
	else
		local line = group.count.." out"
		if group.limit then
			line = line.." of "..group.limit
		end
		GameTooltip:AddLine(line, 1, 1, 1)
	end
	-- The gate's demons by kind.
	if group.kinds then
		for index = 1, table.getn(group.kinds) do
			local kind = group.kinds[index]
			GameTooltip:AddLine(kind.count.."  "..(kind.name or kind.key), 0.9, 0.9, 0.9)
		end
	end
	-- Each one going, the longest-lived first.
	local shown = 0
	for index = 1, table.getn(group.left) do
		if shown < 8 then
			GameTooltip:AddLine(TimeText(group.left[index]).." left", 0.7, 0.7, 0.7)
			shown = shown + 1
		end
	end
	GameTooltip:Show()
end

local icons = {}
local function Icon(index)
	local icon = CreateFrame("Button", nil, holder)
	icon:SetWidth(SIZE)
	icon:SetHeight(SIZE)
	icon:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", (index - 1) * (SIZE + GAP), 0)
	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetTexture(FLAT)
	icon.border:SetVertexColor(0, 0, 0, 1)
	icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- The time left on top, the count at the foot: two lines in the icon.
	icon.time = Text(icon, 9, "TOP", 0, -1)
	icon.time:SetTextColor(1, 0.95, 0.6)
	icon.count = Text(icon, 9, "BOTTOM", 0, 0)
	icon:SetScript("OnEnter", function() hovered = this; Tooltip(this) end)
	icon:SetScript("OnLeave", function() hovered = nil; GameTooltip:Hide() end)
	icon:Hide()
	icons[index] = icon
	return icon
end

------------------------------------------------------------------------------
-- The place: over the buffs (or the player frame), until moved.

local function Place()
	holder:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.summonsLeft and db.summonsBottom then
		holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.summonsLeft, db.summonsBottom)
		return
	end
	local buffs = getglobal("SurvivorUIBuffs")
	local player = getglobal("SurvivorUIPlayer")
	if buffs and Feature("buffs") and player and player:IsVisible() then
		holder:SetPoint("BOTTOMLEFT", buffs, "TOPLEFT", 0, 4)
	elseif player and player:IsVisible() then
		holder:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 5)
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
	end
end

local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.summonsLeft = math.floor(holder:GetLeft() + 0.5)
	SurvivorUIDB.summonsBottom = math.floor(holder:GetBottom() + 0.5)
	Place()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Summons", SavePlace, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.summonsLeft, SurvivorUIDB.summonsBottom = nil, nil
		end
		Place()
	end)
end

------------------------------------------------------------------------------
-- The groups, in the order the first of each came: the ones that stay, by
-- kind; the ones that go, by kind with their limit; the gate's as one.

local function Group(groups, byKey, key, name, icon, stays)
	local group = byKey[key]
	if not group then
		group = { key = key, name = name, icon = icon, count = 0, stays = stays, left = {}, longest = nil }
		byKey[key] = group
		table.insert(groups, group)
	end
	return group
end

local function Add(group, p)
	group.count = group.count + 1
	if p.remaining then
		table.insert(group.left, p.remaining)
		if not group.longest or p.remaining > group.longest then
			group.longest = p.remaining
		end
	end
end

local function Groups()
	local groups, byKey = {}, {}
	local list = AZS_GetSummons()
	for index = 1, table.getn(list) do
		local p = list[index]
		local key = p.key or p.kind or "?"
		local stays = p.permanent or not p.remaining
		if stays then
			-- The ones that stay, only when the options ask for them (Summons tab).
			if SurvivorUIDB and SurvivorUIDB.summonsPermanent == true then
				local group = Group(groups, byKey, "stays:"..key, p.name, p.icon, true)
				group.limit = LIMITS[key]
				Add(group, p)
			end
		elseif LESSER[key] then
			local gate = Group(groups, byKey, "gate", GATE_NAME, GATE_ICON, false)
			gate.limit = GATE_MOST
			gate.kinds = gate.kinds or {}
			local kind
			for k = 1, table.getn(gate.kinds) do
				if gate.kinds[k].key == key then
					kind = gate.kinds[k]
				end
			end
			if not kind then
				kind = { key = key, name = p.name, icon = p.icon, count = 0 }
				table.insert(gate.kinds, kind)
			end
			kind.count = kind.count + 1
			Add(gate, p)
		else
			local group = Group(groups, byKey, key, p.name, p.icon, false)
			group.limit = LIMITS[key]
			Add(group, p)
		end
	end
	for index = 1, table.getn(groups) do
		table.sort(groups[index].left, function(a, b) return a > b end)
	end
	return groups
end

local function Draw(groups)
	local shown = math.min(MOST, table.getn(groups))
	for index = 1, shown do
		local group = groups[index]
		local icon = icons[index] or Icon(index)
		icon.group = group
		icon.texture:SetTexture(group.icon or FALLBACK_ICON)
		-- The number: "out/limit" where the game sets one (not for a single
		-- one that stays, the Imp or a beast), the count alone where it does
		-- not and more than one is out or they come and go.
		local count = ""
		if group.limit and (group.limit > 1 or group.count > 1 or not group.stays) then
			count = group.count.."/"..group.limit
		elseif not group.stays or group.count > 1 then
			count = tostring(group.count)
		end
		icon.count:SetFont(SurvivorUI_FONT, (string.len(count) >= 4 and 8 or 9) + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
		icon.count:SetText(count)
		icon.time:SetText(group.longest and TimeText(group.longest) or "")
		icon:Show()
	end
	for index = shown + 1, table.getn(icons) do
		icons[index]:Hide()
		icons[index].group = nil
	end
	holder:SetWidth(math.max(1, shown * (SIZE + GAP) - GAP))
	-- The tooltip follows the numbers while the mouse stays on an icon.
	if hovered then
		Tooltip(hovered)
	end
end

local wait = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.1 then
		return
	end
	wait = 0
	-- Shown from "ready" (the Imp is there before the first step) to the end.
	local phase = AZS_GetPhase and AZS_GetPhase()
	if not (AZS_GetSummons and Feature("summons")
			and (phase == "ready" or phase == "playing" or phase == "choosing" or phase == "paused")) then
		holder:Hide()
		return
	end
	local groups = Groups()
	if table.getn(groups) == 0 then
		holder:Hide()
		return
	end
	Draw(groups)
	if not holder:IsShown() then
		Place()
		holder:Show()
	end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Place)
