-- Survivor UI: kills, gold and the next cache's price, under the experience
-- bar.
--
-- The game draws the same three numbers in a box of its own that no addon can
-- move. Where it shares them (its addon API, AZS_RUN), this line takes their
-- place inside the middle block, so they move with it, and the game's box is
-- put away. /sui tally brings the game's box back.

local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local row = getglobal("SurvivorUIRow")
if not row then
	return
end

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	if SurvivorUIDB.tally == nil then
		SurvivorUIDB.tally = true
	end
	return SurvivorUIDB
end

-- 2,054
local function Thousands(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local result = ""
	while string.len(text) > 3 do
		result = ","..string.sub(text, -3)..result
		text = string.sub(text, 1, -4)
	end
	return text..result
end

-- The line sits on a holder of its own, under the experience bar, so it can be
-- moved apart from the middle block (Mover.lua).
local holder = CreateFrame("Frame", "SurvivorUITallyFrame", UIParent)
holder:SetWidth(320)
holder:SetHeight(16)
holder:SetPoint("TOP", row, "BOTTOM", 0, -12)
holder:SetMovable(true)

local line = holder:CreateFontString("SurvivorUITally", "OVERLAY")
line:SetFont(FONT, 11 + FONT_BUMP, "OUTLINE")
line:SetPoint("CENTER", holder, "CENTER", 0, 0)
line:Hide()

local function Running()
	if not (AZS_GetPhase and AZS_RUN) then
		return false
	end
	local phase = AZS_GetPhase()
	return phase and phase ~= "ready"
end

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.2 then
		return
	end
	elapsed = 0

	if not (Settings().tally and Running()) then
		line:Hide()
		return
	end
	-- Labels muted, numbers in their colors: kills white, gold gold, the cache green.
	line:SetText("|cff9a9a9aKills|r |cffffffff"..Thousands(AZS_RUN.kills).."|r"
		.."     |cff9a9a9aGold|r |cffffd24d"..Thousands(AZS_RUN.gold).."|r"
		.."     |cff9a9a9aCache|r |cff8cd98c"..Thousands(AZS_RUN.chest).."|r")
	line:Show()
end)

-- The game's own box: away while this line is on. The setting is the game's
-- and is saved, so the addon remembers that it was the one to turn it off.
local function ApplyGameHud()
	if not (AZS_SetHudShown and AZS_IsHudShown) then
		return
	end
	local settings = Settings()
	if settings.tally then
		if AZS_IsHudShown("tally") then
			AZS_SetHudShown("tally", false)
			settings.hidGameTally = true
		end
	elseif settings.hidGameTally then
		AZS_SetHudShown("tally", true)
		settings.hidGameTally = nil
	end
end

function SurvivorUI_Tally()
	local settings = Settings()
	settings.tally = not settings.tally
	ApplyGameHud()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..(settings.tally
		and "kills, gold and cache under the bar; the game's own box is put away."
		or "the game's own kills and gold box is back."))
end

-- Its place: under the experience bar, following the middle block, until moved.
local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.tallyLeft = math.floor(holder:GetLeft() + 0.5)
	SurvivorUIDB.tallyTop = math.floor(holder:GetTop() + 0.5)
end

local function RestorePlace()
	holder:ClearAllPoints()
	if SurvivorUIDB and SurvivorUIDB.tallyLeft and SurvivorUIDB.tallyTop then
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB.tallyLeft, SurvivorUIDB.tallyTop)
	else
		holder:SetPoint("TOP", row, "BOTTOM", 0, -12)
	end
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Kills & gold", SavePlace, nil, RestorePlace)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	RestorePlace()
	ApplyGameHud()
end)
