-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: boss bars.
--
-- A column of flat bars at the top of the screen, one for every boss alive,
-- the final boss on top, then every lair guardian that is awake (and, on
-- request, every elite). Each shows the whole name on the left and the health
-- left on the right, in the color of its kind; an enraged boss's name turns red;
-- its debuffs as small icons inside it, draining as they run out. The game sends these to
-- addons for the whole map, so a bar stays live at any distance, unlike a
-- nameplate.
--
-- Click a bar to target that enemy. Hold Alt and drag a bar to move the column.
-- The game's own boss bars are put away while these are on, and come back with
-- /sui bosses. Needs the game's addon API (AZS_UNITS); without it nothing shows.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local BAR_WIDTH = 220
local BAR_HEIGHT = 18
local BAR_GAP = 4
local MAX_BARS = 8

local KINDS = {
	final    = { order = 1, color = { 0.95, 0.25, 0.55 }, tag = "Final" },
	boss     = { order = 2, color = { 0.72, 0.32, 1.00 } },
	guardian = { order = 3, color = { 0.20, 0.75, 0.95 }, tag = "Guardian" },
	elite    = { order = 4, color = { 1.00, 0.55, 0.10 } },
}

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	-- On on a new install (from v3.0.12; off before, the run tracker showing
	-- the bosses' health, which a new install now leaves to these bars).
	if SurvivorUIDB.bossBars == nil then
		SurvivorUIDB.bossBars = true
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
-- The column.

local holder = CreateFrame("Frame", "SurvivorUIBosses", UIParent)
holder:SetWidth(BAR_WIDTH)
-- Room for four bars: the area Alt outlines, though only the bars show.
holder:SetHeight(4 * (BAR_HEIGHT + BAR_GAP))
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

local bars = {}

local function Bar(index)
	local bar = bars[index]
	if bar then
		return bar
	end

	bar = CreateFrame("Button", nil, holder)
	bar:SetWidth(BAR_WIDTH)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(index - 1) * (BAR_HEIGHT + BAR_GAP))

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

	-- A guardian's lair mark (Guardians.lua), before its name.
	bar.mark = bar.health:CreateTexture(nil, "OVERLAY")
	bar.mark:SetWidth(BAR_HEIGHT - 2)
	bar.mark:SetHeight(BAR_HEIGHT - 2)
	bar.mark:SetPoint("LEFT", bar, "LEFT", 2, 0)
	bar.mark:Hide()
	bar.markRoom = 0

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
		if IsAltKeyDown() then
			holder:StartMoving()
		end
	end)
	bar:SetScript("OnDragStop", function()
		holder:StopMovingOrSizing()
		SavePlace()
	end)
	bar:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.unitName or "", 1, 1, 1)
		if this.kindLabel then
			GameTooltip:AddLine(this.kindLabel, this.color[1], this.color[2], this.color[3])
		end
		GameTooltip:AddDoubleLine("Health", (this.hp or 0).." / "..(this.hpm or 0), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:AddLine("Click to target. Hold Alt and drag to move.", 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

	bar.debuffs = {}
	bars[index] = bar
	return bar
end

------------------------------------------------------------------------------
-- The debuffs on each enemy (AZS_GetDebuffs): small icons inside its bar, at
-- the right, before the health. Each drains as it runs out: the time gone
-- turns grey from the top, a thin light line where it stands, the time left
-- in the middle and the stacks in the corner; edged in its dispel type's
-- color. Hover one for its name.

local DEBUFF_SIZE = BAR_HEIGHT - 4
local DEBUFF_GAP = 2
local MAX_DEBUFFS = 6
local VALUE_ROOM = 38           -- the health's share at the bar's right end

local function TimeLeft(seconds)
	if seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	end
	return math.floor(seconds + 0.5)
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
	icon.time:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.time:SetTextColor(1, 1, 1)
	icon.stacks = icon:CreateFontString(nil, "OVERLAY")
	icon.stacks:SetFont(SurvivorUI_FONT, 7 + FONT_BUMP, "OUTLINE")
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
			GameTooltip:AddLine(math.floor(this.left + 0.5).." sec left", 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

	bar.debuffs[index] = icon
	return icon
end

-- The part of the icon still to run, from the bottom: 1 is all of it.
local function Drain(icon, share)
	if share >= 1 then
		icon.art:SetHeight(DEBUFF_SIZE)
		icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon.art:Show()
		icon.line:Hide()
	elseif share <= 0 then
		icon.art:Hide()
		icon.line:Hide()
	else
		icon.art:SetHeight(DEBUFF_SIZE * share)
		icon.art:SetTexCoord(0.08, 0.92, 0.92 - 0.84 * share, 0.92)
		icon.art:Show()
		icon.line:Show()
	end
end

local function FillDebuffs(bar, id)
	local list = (AZS_GetDebuffs and id) and AZS_GetDebuffs(id) or {}
	local count = math.min(MAX_DEBUFFS, table.getn(list))
	for index = 1, count do
		local debuff = list[index]
		local icon = DebuffIcon(bar, index)
		-- Left of the health, however wide its numbers.
		icon:ClearAllPoints()
		icon:SetPoint("RIGHT", bar, "RIGHT", -(bar.valueRoom or VALUE_ROOM) - (index - 1) * (DEBUFF_SIZE + DEBUFF_GAP), 0)
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
	-- The name gives way to the icons.
	bar.name:SetWidth(BAR_WIDTH - (bar.valueRoom or VALUE_ROOM) - 8 - (bar.markRoom or 0) - count * (DEBUFF_SIZE + DEBUFF_GAP))
end

local KIND_LABELS = { final = "Final boss", boss = "Boss", guardian = "Lair guardian", elite = "Elite" }

local function Fill(bar, unit)
	local kind = Field(unit, "kind", 1) or "elite"
	local style = KINDS[kind] or KINDS.elite
	local name = Field(unit, "name", 3) or "?"
	local hp = tonumber(Field(unit, "hp", 4)) or 0
	local hpm = tonumber(Field(unit, "hpm", 5)) or 0
	local state = tonumber(Field(unit, "state", 6)) or 0
	local share = hpm > 0 and hp / hpm or 0

	bar.unitName, bar.hp, bar.hpm = name, hp, hpm
	bar.color = style.color
	bar.kindLabel = KIND_LABELS[kind]
	bar.health:SetStatusBarColor(style.color[1], style.color[2], style.color[3], 0.9)
	bar.health:SetValue(share)

	-- A guardian wears its lair's mark, the one of its stretch in the tracker
	-- and its pin on the minimap.
	local mark = kind == "guardian" and SurvivorUI_GuardianMark and SurvivorUI_GuardianMark(Field(unit, "id", 2))
	if SurvivorUI_SetLairMark then
		SurvivorUI_SetLairMark(bar.mark, mark)
	end
	local markRoom = mark and BAR_HEIGHT - 2 or 0
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
	-- As the option reads it (/sui opt, Unit frames): 73%, 1.2M, 1.2M / 3.4M or 1.2M | 73%.
	if SurvivorUI_HealthText then
		bar.value:SetText(SurvivorUI_HealthText(hp, hpm, Settings().bossHealth or "absolutePercent"))
	else
		bar.value:SetText(math.floor(share * 100 + 0.5).."%")
	end
	bar.valueRoom = math.max(VALUE_ROOM, math.ceil(bar.value:GetStringWidth()) + 12)

	-- The target wears a white border.
	if UnitExists("target") and UnitName("target") == name then
		bar.border:SetVertexColor(1, 1, 1, 1)
	else
		bar.border:SetVertexColor(0, 0, 0, 1)
	end
	FillDebuffs(bar, tonumber(Field(unit, "id", 2)))
	bar:Show()
end

local function Wanted(unit, elites)
	local kind = Field(unit, "kind", 1)
	if kind == "final" or kind == "boss" then
		return true
	elseif kind == "guardian" then
		-- A guardian asleep in its lair is not a fight yet; one already hurt
		-- is, though the game still calls it asleep (feared from the first hit).
		local hp, hpm = tonumber(Field(unit, "hp", 4)) or 0, tonumber(Field(unit, "hpm", 5)) or 0
		return (tonumber(Field(unit, "state", 6)) or 0) == 1 or (hpm > 0 and hp > 0 and hp < hpm)
	end
	return elites and kind == "elite"
end

local function Update()
	local settings = Settings()
	local shown = 0
	-- Apart from the run tracker: shown whether it shows the bosses' health or
	-- not.
	if settings.bossBars and Playing() then
		local picked = {}
		for index = 1, table.getn(AZS_UNITS) do
			local unit = AZS_UNITS[index]
			if Wanted(unit, settings.bossBarsElites) then
				table.insert(picked, unit)
			end
		end
		table.sort(picked, function(a, b)
			local ka = KINDS[Field(a, "kind", 1)] or KINDS.elite
			local kb = KINDS[Field(b, "kind", 1)] or KINDS.elite
			return ka.order < kb.order
		end)
		for index = 1, math.min(MAX_BARS, table.getn(picked)) do
			Fill(Bar(index), picked[index])
			shown = index
		end
	end
	for index = shown + 1, table.getn(bars) do
		bars[index]:Hide()
		bars[index].unitName = nil
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
