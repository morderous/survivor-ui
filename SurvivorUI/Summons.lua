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
-- permanent, remaining); before it there is nothing to show.
--
-- And the talents' clocks, from its 0.115 (AZS_GetTimers: name, icon, kind,
-- duration, remaining, ready): a summon's (Butcher's next Felguard, Pact of
-- the Annihilan's next Pit Lord, Legion Gate's next wave) on its demons'
-- icon, a bar under it filling to the next one; none out yet, the icon
-- dimmed, counting down. A cooldown's (a proc's, a heal's, a second life's
-- wait), from MIN_COOLDOWN seconds long, an icon of its own, dimmed and
-- counting while it waits, bright when ready ("Talent cooldowns", on). The limits are
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
-- A summoning talent's clock, by its name: the group its demons are in.
local TIMER_GROUP = { ["Butcher"] = "felguard", ["Pact of the Annihilan"] = "pit_lord", ["Legion Gate"] = "gate" }
local MIN_COOLDOWN = 5          -- a shorter wait, a proc's limit (Nightfall's half second, Daybreak's 3, Hallowed Ground's 4), is not shown
local NEXT_COLOR = { 0.78, 0.55, 1 }

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
	GameTooltip:AddLine(SurvivorUI_Native(group.name or group.key or "?"), 1, 0.82, 0)
	-- A talent's clock: its next one, or its cooldown.
	if group.cooldown then
		GameTooltip:AddLine(group.next > 0 and SurvivorUI_TF("Ready in {1} sec", TimeText(group.next)) or SurvivorUI_T("Ready"), 1, 1, 1)
		GameTooltip:AddLine(SurvivorUI_TF("Every {1} sec at most", TimeText(group.wait)), 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end
	if group.next then
		GameTooltip:AddLine(SurvivorUI_TF("Next one in {1} sec, every {2} sec ({3})", TimeText(group.next), TimeText(group.wait), SurvivorUI_Native(group.timer)),
			NEXT_COLOR[1], NEXT_COLOR[2], NEXT_COLOR[3])
	end
	if group.waiting then
		GameTooltip:AddLine(SurvivorUI_T("None out yet"), 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end
	if group.stays then
		GameTooltip:AddLine(group.count == 1 and SurvivorUI_T("Stays the whole run") or SurvivorUI_TF("{1} out, the whole run", group.count), 1, 1, 1)
	else
		local line = group.limit and SurvivorUI_TF("{1} out of {2}", group.count, group.limit) or SurvivorUI_TF("{1} out", group.count)
		GameTooltip:AddLine(line, 1, 1, 1)
	end
	-- The gate's demons by kind.
	if group.kinds then
		for index = 1, table.getn(group.kinds) do
			local kind = group.kinds[index]
			GameTooltip:AddLine(kind.count.."  "..SurvivorUI_Native(kind.name or kind.key), 0.9, 0.9, 0.9)
		end
	end
	-- Each one going, the longest-lived first.
	local shown = 0
	for index = 1, table.getn(group.left) do
		if shown < 8 then
			GameTooltip:AddLine(SurvivorUI_TF("{1} left", TimeText(group.left[index])), 0.7, 0.7, 0.7)
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
	-- Under it, a talent's clock: a slim bar filling to the next one.
	icon.next = CreateFrame("StatusBar", nil, icon)
	icon.next:SetStatusBarTexture(FLAT)
	icon.next:SetMinMaxValues(0, 1)
	icon.next:SetHeight(2)
	icon.next:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -2)
	icon.next:SetPoint("TOPRIGHT", icon, "BOTTOMRIGHT", 0, -2)
	icon.next.back = icon.next:CreateTexture(nil, "BACKGROUND")
	icon.next.back:SetTexture(FLAT)
	icon.next.back:SetVertexColor(0, 0, 0, 0.8)
	icon.next.back:SetPoint("TOPLEFT", icon.next, "TOPLEFT", -1, 1)
	icon.next.back:SetPoint("BOTTOMRIGHT", icon.next, "BOTTOMRIGHT", 1, -1)
	icon.next:Hide()
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
	local out = {}              -- [group key] = how many are out, the ones that stay too
	local list = AZS_GetSummons()
	for index = 1, table.getn(list) do
		local p = list[index]
		local key = p.key or p.kind or "?"
		local outKey = LESSER[key] and "gate" or key
		out[outKey] = (out[outKey] or 0) + 1
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
	-- The talents' clocks (the game's 0.115).
	local timers = AZS_GetTimers and AZS_GetTimers() or {}
	for index = 1, table.getn(timers) do
		local t = timers[index]
		local icon = t.icon and t.icon ~= "" and ("Interface\\Icons\\"..t.icon) or FALLBACK_ICON
		if t.kind == "summon" then
			local key = TIMER_GROUP[t.name] or ("next:"..tostring(t.name))
			local group = byKey[key]
			if not group then
				-- Its demons not shown (none out, or ones that stay with
				-- "Track permanent pets" off): the talent's icon, with how
				-- many are out; dimmed while none is.
				group = Group(groups, byKey, key, t.name, icon, false)
				group.count = out[key] or 0
				group.waiting = group.count == 0
				group.limit = LIMITS[key] or (key == "gate" and GATE_MOST) or nil
			end
			if key == "gate" then
				group.icon = icon
			end
			group.next, group.wait, group.timer = t.remaining or 0, t.duration or 0, t.name
		elseif t.kind == "cooldown" and (t.duration or 0) >= MIN_COOLDOWN
				and not (SurvivorUIDB and SurvivorUIDB.summonsTimers == false) then
			local group = Group(groups, byKey, "cd:"..tostring(t.name), t.name, icon, false)
			group.cooldown = true
			group.next, group.wait = t.remaining or 0, t.duration or 0
		end
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
		icon.time:SetTextColor(1, 0.95, 0.6)
		icon.texture:SetVertexColor(1, 1, 1)
		if group.cooldown then
			-- Its wait: dimmed and counting, bright when ready.
			count = ""
			local waiting = group.next > 0
			icon.texture:SetVertexColor(waiting and 0.4 or 1, waiting and 0.4 or 1, waiting and 0.4 or 1)
			icon.time:SetText(waiting and TimeText(group.next) or "")
		elseif group.waiting then
			-- None out yet: dimmed, counting down to the first.
			icon.texture:SetVertexColor(0.5, 0.5, 0.5)
			icon.time:SetTextColor(NEXT_COLOR[1], NEXT_COLOR[2], NEXT_COLOR[3])
			icon.time:SetText(group.next and TimeText(group.next) or "")
		elseif group.longest then
			icon.time:SetText(TimeText(group.longest))
		else
			-- Out for good, a talent's clock on it: the next one's seconds.
			icon.time:SetTextColor(NEXT_COLOR[1], NEXT_COLOR[2], NEXT_COLOR[3])
			icon.time:SetText(group.next and TimeText(group.next) or "")
		end
		icon.count:SetText(count)
		if group.next and group.wait and group.wait > 0 then
			icon.next:SetValue(1 - math.min(1, group.next / group.wait))
			if group.cooldown then
				icon.next:SetStatusBarColor(1, 0.82, 0.3, 1)
			else
				icon.next:SetStatusBarColor(NEXT_COLOR[1], NEXT_COLOR[2], NEXT_COLOR[3], 1)
			end
			icon.next:Show()
		else
			icon.next:Hide()
		end
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
