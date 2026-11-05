-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a small gold hourglass at the foot of a spell's action button
-- while its cooldown is at the game's floor, as quick as it gets: more haste
-- or a cooldown card does nothing for it then (Lucas, 2026-11-05).
--
-- The game's rule (its exe 0.141.0, read 2026-11-05): a spell's cooldown is
-- its base x 1.4 x its cards x its talents x the haste, never under a floor
-- of 0.25 sec; Hellfire's is 0.5, Divine Shield's max(10 - v, 4), v the
-- shield's length, at most 6 (5.6 at a run's start, so 4.4; with any bonus
-- to its length 4). Eight spells (the game's family 11, its spell table's
-- byte 0x75: OWN_WAY, below) work theirs out another way, a least of their
-- own over how often they proc, which can go under 0.25: no floor is told
-- for them, and no hourglass.
--
-- The cooldown the game sends (AZS_SPELLS, the 5th field) has the floor in,
-- but written to one decimal, a tie to the even: 0.25 comes as 0.2, 0.75 as
-- 0.8. No other spell goes under 0.25, so a 0.2 is exactly the floor's 0.25,
-- and the build list writes it so (SurvivorUI_TrueCooldown). Hellfire's 0.5
-- is its floor or up to 0.05 over it (0.5 to 0.55 all come as 0.5). Divine
-- Shield's floor over 4 sec (4.4) goes with the shield's length, which the
-- game does not tell for sure, so its hourglass is only at 4.0, the lowest
-- it can be (its cooldown, 44.8 sec at first, seldom gets there).
--
-- The hourglass hangs from the button's bottom edge, mostly over the button,
-- so it pushes nothing under the bar (the kills and gold, the class gems);
-- the counters stay over the top (DotCounter.lua). On or off in the options,
-- with the counters (Counters: Hourglass).

if SurvivorUI_Standby then return end

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"

local FLOOR = 0.25
local FLOORS = { hellfire = 0.5, divine_shield = 4 }
-- The game's family 11, the whole of it (its table of 115 spells walked):
-- each its own least, over its proc rate (bloodrage 8, lightwell 6,
-- soul_fire 3, polymorph 3, seal_fate 2, hunters_mark 2); redemption and
-- faerie_fire have no cooldown (0 sent).
local OWN_WAY = {
	bloodrage = true, lightwell = true, soul_fire = true, polymorph = true,
	seal_fate = true, hunters_mark = true, redemption = true, faerie_fire = true,
}

local SIZE = 14         -- the hourglass's side, at the bar's own size
local BELOW = 3         -- how far it reaches under the button's bottom edge

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

-- A spell's cooldown, by its key in AZS_SPELLS and the cdmax the game sent,
-- as near as the game tells it, and its floor while it is at it (else nil):
-- a 0.2 is the floor's 0.25. Unknown keys (nil) and OWN_WAY's as sent.
function SurvivorUI_TrueCooldown(key, cdmax)
	cdmax = tonumber(cdmax) or 0
	if not key or cdmax <= 0 or OWN_WAY[key] then
		return cdmax, nil
	end
	local floor = FLOORS[key] or FLOOR
	-- At the floor, sent rounded to a decimal: 0.25 as 0.2, 0.5, 4.0.
	if cdmax < floor + 0.001 then
		return floor, floor
	end
	return cdmax, nil
end

local function On()
	local db = SurvivorUIDB
	return not db or (db.counters ~= false and db.floorHourglass ~= false)
end

local function Running()
	if not (AZS_GetPhase and AZS_SPELLS) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

-- "holy_wrath" as the build list names it, "Holy Wrath" (BuildList.lua).
local function NameOf(key)
	if SurvivorUI_SpellKeyName then
		return SurvivorUI_SpellKeyName(key)
	end
	return (string.gsub(key or "?", "_", " "))
end

local function Tip()
	local mark = this
	mark.over = true
	-- Over the button, clear of a counter over it (DotCounter.lua): placed by
	-- hand, as the game's ANCHOR_TOP put it at the left, over the hero's frame.
	GameTooltip:SetOwner(mark, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", mark:GetParent(), "TOP", 0, 22)
	GameTooltip:AddLine(SurvivorUI_Native(NameOf(mark.key)), 1, 0.82, 0)
	local seconds = SurvivorUI_CooldownText and SurvivorUI_CooldownText(mark.floor) or (mark.floor.."s")
	GameTooltip:AddLine(SurvivorUI_TF("At its fastest: {1}, the game's floor. More haste or cooldown cards do nothing for this spell.", seconds), 1, 1, 1, 1)
	GameTooltip:Show()
end

local function Untip()
	if this.over then
		this.over = nil
		GameTooltip:Hide()
	end
end

local marks = {}        -- [action button] = its hourglass

local function Mark(button)
	local mark = marks[button]
	if mark then
		return mark
	end
	mark = CreateFrame("Frame", nil, button)
	mark:SetWidth(SIZE)
	mark:SetHeight(SIZE)
	mark:SetPoint("BOTTOM", button, "BOTTOM", 0, -BELOW)
	-- Over the button's cooldown sweep, which is a frame of its own.
	mark:SetFrameLevel(button:GetFrameLevel() + 4)
	mark.art = mark:CreateTexture(nil, "OVERLAY")
	mark.art:SetAllPoints(mark)
	mark.art:SetTexture(ART.."FloorHourglass")
	mark:EnableMouse(true)
	mark:SetScript("OnEnter", Tip)
	mark:SetScript("OnLeave", Untip)
	mark:SetScript("OnHide", Untip)
	mark:Hide()
	marks[button] = mark
	return mark
end

local frame = CreateFrame("Frame")
local wait = 0
frame:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.25 then
		return
	end
	wait = 0
	local lit = {}
	if On() and Running() then
		local count = table.getn(AZS_SPELLS)
		for index = 1, count do
			local entry = AZS_SPELLS[index] or {}
			local key = Field(entry, "key", 1)
			local _, floor = SurvivorUI_TrueCooldown(key, Field(entry, "cdmax", 5))
			local slot = SurvivorUI_SpellSlot and SurvivorUI_SpellSlot(index) or index
			local button = floor and getglobal("ActionButton"..slot)
			if button and button:IsVisible() then
				local mark = Mark(button)
				mark.key, mark.floor = key, floor
				mark:Show()
				lit[mark] = true
			end
		end
	end
	for _, mark in pairs(marks) do
		if not lit[mark] then
			mark:Hide()
		end
	end
end)
