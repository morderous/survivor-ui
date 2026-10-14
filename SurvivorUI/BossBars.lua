-- Survivor UI: boss bars.
--
-- A column of flat bars at the top of the screen, one for every boss alive,
-- the final boss on top, then every lair guardian that is awake (and, on
-- request, every elite). Each shows the whole name on the left and the health
-- left on the right, in the color of its kind; an enraged boss's name turns red. The game sends these to
-- addons for the whole map, so a bar stays live at any distance, unlike a
-- nameplate.
--
-- Click a bar to target that enemy. Hold Alt and drag a bar to move the column.
-- The game's own boss bars are put away while these are on, and come back with
-- /sui bosses. Needs the game's addon API (AZS_UNITS); without it nothing shows.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"

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
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
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
holder:SetPoint("TOP", UIParent, "TOP", 0, -90)
holder:SetMovable(true)

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
	bar.name:SetFont(FONT, 10, "OUTLINE")
	bar.name:SetPoint("LEFT", bar, "LEFT", 5, 0)
	bar.name:SetWidth(BAR_WIDTH - 50)
	bar.name:SetHeight(12)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1)

	bar.value = bar.health:CreateFontString(nil, "OVERLAY")
	bar.value:SetFont(FONT, 10, "OUTLINE")
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

	bars[index] = bar
	return bar
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

	-- An enraged boss (state 1) wears its name in red.
	bar.name:SetText(name)
	if state == 1 and (kind == "boss" or kind == "final") then
		bar.name:SetTextColor(1, 0.35, 0.35)
	else
		bar.name:SetTextColor(1, 1, 1)
	end
	bar.value:SetText(math.floor(share * 100 + 0.5).."%")

	-- The target wears a white border.
	if UnitExists("target") and UnitName("target") == name then
		bar.border:SetVertexColor(1, 1, 1, 1)
	else
		bar.border:SetVertexColor(0, 0, 0, 1)
	end
	bar:Show()
end

local function Wanted(unit, elites)
	local kind = Field(unit, "kind", 1)
	if kind == "final" or kind == "boss" then
		return true
	elseif kind == "guardian" then
		-- A guardian asleep in its lair is not a fight yet.
		return (tonumber(Field(unit, "state", 6)) or 0) == 1
	end
	return elites and kind == "elite"
end

local function Update()
	local settings = Settings()
	local shown = 0
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
	if settings.bossBars then
		if AZS_IsHudShown("bosses") then
			AZS_SetHudShown("bosses", false)
			settings.hidGameBosses = true
		end
	elseif settings.hidGameBosses then
		AZS_SetHudShown("bosses", true)
		settings.hidGameBosses = nil
	end
end

function SurvivorUI_BossBars(argument)
	local settings = Settings()
	if argument == "elites" then
		settings.bossBarsElites = not settings.bossBarsElites
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: boss bars "..(settings.bossBarsElites and "list elites too." or "leave elites out."))
	else
		settings.bossBars = not settings.bossBars
		ApplyGameHud()
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.bossBars and "boss bars on; the game's own are put away." or "boss bars off; the game's own are back."))
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
		holder:ClearAllPoints()
		holder:SetPoint("TOP", UIParent, "TOP", 0, -90)
	end)
end
