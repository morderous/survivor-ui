-- Survivor UI: the run so far, in one small panel.
--
--   This Run        a running count of what the game totals up on the screen
--                   that ends a run: time, level, kills, damage.
--   Biggest Crits   every ability that has crit, with its biggest critical
--                   strike; hover one for its last, average and smallest.
--
-- The addon cannot see the game's own tally, so it keeps its own from what the
-- client tells it: the hero's level, and the combat log for kills and damage.
-- The clock starts, like the game's, at the hero's first step. Two limits: it
-- keeps running while a card choice has the game paused, and damage is what the combat log reported, which can differ a
-- little from the game's total. Gold and caches are not in the log at all.
--
-- Alt-drag either title to move the panel. /sui run hides it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"

local WIDTH = 190
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 24
local CRIT_ROWS = 10

-- The game's elites and bosses, by name: three elites and five bosses a zone.
-- A lair guardian is one of the zone's elites, made stronger: its plate reads
-- "<name> (Guardian)", but its death line only "<name> dies.", the same as the
-- elite's. So the guardians on screen are watched, see WatchGuardians.
local ELITES = {
	"Kobold Taskmaster", "Gruff Swiftbite", "Bellygrub",
	"Nightbane Worgen Alpha", "Carrion Recluse", "Flesh Eating Abomination",
	"Felguard Elite", "Infernal", "Doomguard",
	"Crypt Fiend", "Bone Golem", "Death Knight Captain",
	"Gordunni Brute", "Warpwood Treant", "Ironbark Protector",
	"Gurubashi Berserker", "Zulian Crocolisk", "Gurubashi Champion",
	"Alterac Yeti Lord", "Mountain Giant", "Winterax Warlord",
	"Core Hound", "Black Drake", "Molten Giant",
	"Qiraji Champion", "Anubisath Sentinel", "Obsidian Destroyer",
}
local BOSSES = {
	"Hogger", "Mother Fang", "Rhahk'Zor", "Mr. Smite", "Edwin VanCleef",
	"Naraxis", "Mor'Ladim", "Stitches", "Lupos", "Morbent Fel",
	"Doomguard Commander", "Mannoroth's Herald", "Varimathras", "Lord Hel'nurath", "Lord Kazzak",
	"Patchwerk", "Lord Blackwood", "Baron Rivendare", "Anub'Rekhan", "Kel'Thuzad",
	"Zevrim Thornhoof", "Alzzin the Wildshaper", "Tendris Warpwood", "Immol'thar", "King Gordok",
	"High Priestess Jeklik", "High Priest Venoxis", "Bloodlord Mandokir", "Jin'do the Hexxer", "Hakkar the Soulflayer",
	"Korrak the Bloodrager", "Ivus the Forest Lord", "Lokholar the Ice Lord", "Glacius the Frozen Titan", "Azuregos",
	"General Angerforge", "Warchief Rend Blackhand", "Emperor Dagran Thaurissan", "Majordomo Executus", "Nefarian",
	"Kurinnaxx", "General Rajaxx", "Princess Huhuran", "Ossirian the Unscarred", "C'Thun",
}

local kindByName = {}
for index = 1, table.getn(ELITES) do
	kindByName[ELITES[index]] = "elites"
end
for index = 1, table.getn(BOSSES) do
	kindByName[BOSSES[index]] = "bosses"
end

-- One color per ability, handed out in the order abilities first crit.
local CRIT_PALETTE = {
	{ 0.86, 0.24, 0.24 }, { 0.26, 0.52, 0.96 }, { 0.93, 0.76, 0.20 }, { 0.30, 0.78, 0.45 },
	{ 0.70, 0.36, 0.90 }, { 0.95, 0.52, 0.18 }, { 0.25, 0.80, 0.82 }, { 0.90, 0.40, 0.65 },
	{ 0.62, 0.42, 0.24 }, { 0.60, 0.70, 0.85 },
}

------------------------------------------------------------------------------
-- The tally.

local run = {}
local critBest, critStats, critColor, critSeen = {}, {}, {}, 0
local hitStats = {}             -- [ability] = { last, sum, count }, normal hits only

local function ResetCrits()
	critBest, critStats, critColor, critSeen = {}, {}, {}, 0
	hitStats = {}
end

local function ResetRun()
	run.started = nil       -- GetTime() the clock started
	run.armed = nil         -- waiting for the hero's first step
	run.fromX = nil
	run.pausedAt = nil      -- GetTime() the clock was stopped at, while the game is paused
	run.lastSign = nil      -- GetTime() of the last step or combat log line
	run.atX = nil
	run.ended = nil         -- GetTime() the run was over
	run.kills = 0
	run.elites = 0
	run.guardians = 0
	run.bosses = 0
	run.dealt = 0
	run.taken = 0

	ResetCrits()
end
ResetRun()

local function Seconds()
	if not run.started then
		return 0
	end
	return (run.ended or run.pausedAt or GetTime()) - run.started
end

-- The game pauses on Escape and while a level's cards are up, and tells the
-- addon nothing: its clock and its frames keep running. What does stop is the
-- world. A run is never quiet, so a stretch with no step taken and no line in
-- the combat log is a pause, and the clock is wound back to where it began.
local QUIET = 1.5

local function Position()
	local x, y = GetPlayerMapPosition("player")
	if (not x or (x == 0 and y == 0)) and SetMapToCurrentZone then
		-- The world map was left on another zone: no position until it is back.
		SetMapToCurrentZone()
		x, y = GetPlayerMapPosition("player")
	end
	if not x or (x == 0 and y == 0) then
		return nil
	end
	return x, y
end

-- A sign of life: a step, or anything in the combat log.
local function Alive()
	if not run.started or run.ended then
		return
	end
	local now = GetTime()
	if run.pausedAt then
		-- The clock picks up where it stopped: the start moves by the time paused.
		run.started = run.started + (now - run.pausedAt)
		run.pausedAt = nil
	end
	run.lastSign = now
end

local function WatchPause()
	local x, y = Position()
	if x then
		if not run.atX or math.abs(x - run.atX) + math.abs(y - run.atY) > 0.0002 then
			run.atX, run.atY = x, y
			Alive()
		end
	end
	local last = run.lastSign or run.started
	if not run.pausedAt and GetTime() - last > QUIET then
		-- Stopped back at the last sign, so the quiet wait itself is not counted.
		run.pausedAt = last
	end
end

-- 950, 1k, 1.2k, 3.4m
local function Short(value)
	local short, suffix
	if value >= 1000000 then
		short, suffix = value / 1000000, "m"
	elseif value >= 1000 then
		short, suffix = value / 1000, "k"
	else
		return math.floor(value + 0.5)
	end
	local text = string.format("%.1f", short)
	text = string.gsub(text, "%.0$", "")
	return text..suffix
end

------------------------------------------------------------------------------
-- The panel.

local RUN_ROWS = {
	{ key = "time",      label = "Survived",        color = { 1.00, 0.82, 0.00 } },
	{ key = "level",     label = "Level",           color = { 0.40, 1.00, 0.40 } },
	{ key = "kills",     label = "Kills",           color = { 0.92, 0.92, 0.92 } },
	{ key = "elites",    label = "Elites slain",    color = { 1.00, 0.55, 0.10 } },
	{ key = "guardians", label = "Guardians slain", color = { 0.20, 0.75, 0.95 } },
	{ key = "bosses",    label = "Bosses slain",    color = { 0.72, 0.32, 1.00 } },
	{ key = "dealt",     label = "Damage dealt",    color = { 1.00, 0.76, 0.08 } },
	{ key = "dps",       label = "Damage / sec",    color = { 0.95, 0.60, 0.20 } },
	{ key = "taken",     label = "Damage taken",    color = { 0.90, 0.25, 0.25 } },
}

local panel = CreateFrame("Frame", "SurvivorUIRun", UIParent)
panel:SetWidth(WIDTH + 16)
panel:SetHeight(TITLE_HEIGHT + 8)
-- Above the chat, growing upward as rows join.
if ChatFrame1 then
	panel:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", -6, 30)
else
	panel:SetPoint("LEFT", UIParent, "LEFT", 30, 60)
end
panel:SetBackdrop({ bgFile = FLAT })
panel:SetBackdropColor(0.04, 0.04, 0.07, 0.88)
panel:SetMovable(true)
panel:Hide()

-- A section title. It says how to move the panel, and is a handle for doing it.
local function Title(text, tip)
	local handle = CreateFrame("Frame", nil, panel)
	handle:SetWidth(WIDTH - 46)
	handle:SetHeight(TITLE_HEIGHT - 6)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function() if IsAltKeyDown() then panel:StartMoving() end end)
	handle:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
	handle:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(text, 1, 0.82, 0)
		GameTooltip:AddLine("Hold Alt and drag to move.", 1, 1, 1)
		GameTooltip:AddLine(tip, 0.7, 0.7, 0.7, 1)
		GameTooltip:Show()
	end)
	handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

	handle.text = handle:CreateFontString(nil, "OVERLAY")
	handle.text:SetFont(FONT, 11, "OUTLINE")
	handle.text:SetPoint("LEFT", handle, "LEFT", 4, 0)
	handle.text:SetTextColor(1, 0.82, 0)
	handle.text:SetText(text)
	return handle
end

local runTitle = Title("This Run", "Counted by the addon from the combat log. A new run starts it over.")
local critTitle = Title("Biggest Crits", "Each ability's biggest critical strike this run. Hover an ability for more.")

local reset = CreateFrame("Button", nil, panel)
reset:SetWidth(40)
reset:SetHeight(14)
reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
reset.text = reset:CreateFontString(nil, "OVERLAY")
reset.text:SetFont(FONT, 9, "OUTLINE")
reset.text:SetPoint("RIGHT", reset, "RIGHT", 0, 0)
reset.text:SetText("Reset")
reset.text:SetTextColor(0.6, 0.6, 0.6)
reset:SetScript("OnEnter", function()
	this.text:SetTextColor(1, 1, 1)
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText("Clears the crits. The run's numbers stay.", 1, 1, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", function()
	this.text:SetTextColor(0.6, 0.6, 0.6)
	GameTooltip:Hide()
end)
reset:SetScript("OnClick", function() ResetCrits() end)

-- A row: a label and a value in one color, on a faint wash of that color, over
-- a rule of it.
local function MakeRow(valueSize, valueFlags)
	local row = CreateFrame("Frame", nil, panel)
	row:SetWidth(WIDTH)
	row:SetHeight(ROW_HEIGHT)

	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(FLAT)
	row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)

	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetTexture(FLAT)
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

	row.label = row:CreateFontString(nil, "OVERLAY")
	row.label:SetFont(FONT, 10, "OUTLINE")
	row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
	row.label:SetWidth(WIDTH - 66)
	row.label:SetHeight(11)
	row.label:SetJustifyH("LEFT")

	row.value = row:CreateFontString(nil, "OVERLAY")
	row.value:SetFont(FONT, valueSize, valueFlags)
	row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
	return row
end

local function Paint(row, color)
	row.label:SetTextColor(color[1], color[2], color[3])
	row.value:SetTextColor(color[1], color[2], color[3])
	row.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
	row.rule:SetVertexColor(color[1], color[2], color[3], 0.28)
end

local runRows = {}
for index = 1, table.getn(RUN_ROWS) do
	local info = RUN_ROWS[index]
	local row = MakeRow(11, "OUTLINE")
	row.label:SetText(info.label)
	Paint(row, info.color)
	runRows[info.key] = row
	runRows[index] = row
end

-- The clock is the addon's own count, not the game's: say where they can part.
runRows.time:EnableMouse(true)
runRows.time:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText("Survived", 1, 0.82, 0)
	GameTooltip:AddLine("An estimate. The game does not share its clock with addons, so this one can drift from it.", 1, 1, 1, 1)
	GameTooltip:AddLine("Starts at your first step, or your first blow if the step was missed.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Pauses after 1.5 seconds with no movement and no combat, which is how it sees Escape and the level-up cards.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Standing still out of combat is not counted either.", 0.7, 0.7, 0.7, 1)
	GameTooltip:AddLine("Stops when the run ends.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
runRows.time:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- An ability's other numbers, in a card of the panel's own: each line over a
-- rule in the ability's color, and the normal hits set apart under a heavier
-- one.
local TIP_WIDTH = 170
local TIP_ROW = 16

local critTip = CreateFrame("Frame", "SurvivorUICritTip", UIParent)
critTip:SetFrameStrata("TOOLTIP")
critTip:SetWidth(TIP_WIDTH + 16)
critTip:Hide()

critTip.edge = critTip:CreateTexture(nil, "BACKGROUND")
critTip.edge:SetTexture(FLAT)
critTip.edge:SetPoint("TOPLEFT", critTip, "TOPLEFT", -1, 1)
critTip.edge:SetPoint("BOTTOMRIGHT", critTip, "BOTTOMRIGHT", 1, -1)

critTip.fill = critTip:CreateTexture(nil, "BORDER")
critTip.fill:SetTexture(FLAT)
critTip.fill:SetVertexColor(0.05, 0.05, 0.07, 0.97)
critTip.fill:SetAllPoints(critTip)

critTip.title = critTip:CreateFontString(nil, "OVERLAY")
critTip.title:SetFont(FONT, 12, "OUTLINE")
critTip.title:SetPoint("TOPLEFT", critTip, "TOPLEFT", 8, -8)

critTip.lines = {}

-- kind: "row" label and value, "head" a section title over a heavier rule.
local function TipLine(index, kind, label, value, color)
	local line = critTip.lines[index]
	if not line then
		line = CreateFrame("Frame", nil, critTip)
		line:SetWidth(TIP_WIDTH)
		line:SetHeight(TIP_ROW)
		line.rule = line:CreateTexture(nil, "ARTWORK")
		line.rule:SetTexture(FLAT)
		line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
		line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
		line.label = line:CreateFontString(nil, "OVERLAY")
		line.label:SetFont(FONT, 10)
		line.label:SetPoint("LEFT", line, "LEFT", 2, 0)
		line.value = line:CreateFontString(nil, "OVERLAY")
		line.value:SetFont(FONT, 11, "OUTLINE")
		line.value:SetPoint("RIGHT", line, "RIGHT", -2, 0)
		critTip.lines[index] = line
	end

	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", critTip, "TOPLEFT", 8, -26 - (index - 1) * TIP_ROW)
	line.label:SetText(label)
	line.value:SetText(value or "")
	if kind == "head" then
		line.label:SetTextColor(color[1], color[2], color[3])
		line.rule:SetHeight(1)
		line.rule:SetVertexColor(color[1], color[2], color[3], 0.75)
	else
		line.label:SetTextColor(0.80, 0.80, 0.80)
		line.value:SetTextColor(1, 1, 1)
		line.rule:SetHeight(1)
		line.rule:SetVertexColor(color[1], color[2], color[3], 0.22)
	end
	line:Show()
end

local critHovered = nil

local function CritTooltip(row)
	local ability = row.ability
	local stats = ability and critStats[ability]
	if not stats then
		critTip:Hide()
		return
	end
	local color = critColor[ability]
	local hits = hitStats[ability]

	critTip.edge:SetVertexColor(color[1], color[2], color[3], 0.8)
	critTip.title:SetText(ability)
	critTip.title:SetTextColor(color[1], color[2], color[3])

	local count = 0
	local function Add(kind, label, value)
		count = count + 1
		TipLine(count, kind, label, value, color)
	end

	Add("head", "Critical strikes", stats.count)
	Add("row", "Biggest", Short(critBest[ability]))
	Add("row", "Last", Short(stats.last))
	Add("row", "Average", Short(stats.sum / stats.count))
	Add("row", "Smallest", Short(stats.least))
	Add("head", "Normal hits", hits and hits.count or 0)
	if hits then
		Add("row", "Average", Short(hits.sum / hits.count))
		Add("row", "Last", Short(hits.last))
	else
		Add("row", "None yet", "")
	end

	for index = count + 1, table.getn(critTip.lines) do
		critTip.lines[index]:Hide()
	end

	critTip:SetHeight(26 + count * TIP_ROW + 8)
	critTip:ClearAllPoints()
	critTip:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", 14, -4)
	critTip:Show()
end

local critRows = {}
for index = 1, CRIT_ROWS do
	local row = MakeRow(14, "THICKOUTLINE")
	row.label:SetFont(FONT, 9, "OUTLINE")
	row:EnableMouse(true)
	row:SetScript("OnEnter", function()
		critHovered = this
		CritTooltip(this)
	end)
	row:SetScript("OnLeave", function()
		critHovered = nil
		critTip:Hide()
	end)
	row:Hide()
	critRows[index] = row
end

local function Shown()
	return not SurvivorUIDB or SurvivorUIDB.runPanel ~= false
end

-- Lays the two sections out top to bottom and sizes the panel to them.
local function Draw()
	local y = -4

	local running = run.started ~= nil
	if running then
		runTitle:ClearAllPoints()
		runTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
		runTitle:Show()
		y = y - TITLE_HEIGHT

		local seconds = Seconds()
		local clock = string.format("%d:%02d", math.floor(seconds / 60), math.mod(math.floor(seconds), 60))
		if run.pausedAt then
			runRows.time.label:SetText("Survived (paused)")
			runRows.time.value:SetTextColor(0.6, 0.6, 0.6)
		else
			runRows.time.label:SetText("Survived")
			runRows.time.value:SetTextColor(1, 0.82, 0)
		end
		runRows.time.value:SetText(clock)
		runRows.level.value:SetText(UnitLevel("player") or 1)
		runRows.kills.value:SetText(run.kills)
		runRows.elites.value:SetText(run.elites)
		runRows.guardians.value:SetText(run.guardians)
		runRows.bosses.value:SetText(run.bosses)
		runRows.dealt.value:SetText(Short(run.dealt))
		runRows.dps.value:SetText(seconds > 0 and Short(run.dealt / seconds) or 0)
		runRows.taken.value:SetText(Short(run.taken))
	else
		runTitle:Hide()
	end
	for index = 1, table.getn(RUN_ROWS) do
		local row = runRows[index]
		if running then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
			row:Show()
			y = y - ROW_HEIGHT
		else
			row:Hide()
		end
	end

	local sorted = {}
	for ability in pairs(critBest) do
		table.insert(sorted, ability)
	end
	table.sort(sorted, function(a, b) return critBest[a] > critBest[b] end)

	if table.getn(sorted) > 0 then
		y = y - (running and 6 or 0)
		critTitle:ClearAllPoints()
		critTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
		critTitle:Show()
		-- Reset clears this section only, so it sits on its title.
		reset:ClearAllPoints()
		reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y - 4)
		reset:Show()
		y = y - TITLE_HEIGHT
	else
		critTitle:Hide()
		reset:Hide()
	end
	for index = 1, CRIT_ROWS do
		local row = critRows[index]
		local ability = sorted[index]
		if ability then
			row.ability = ability
			row.label:SetText(ability)
			row.value:SetText(Short(critBest[ability]))
			Paint(row, critColor[ability])
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
			row:Show()
			y = y - ROW_HEIGHT
		else
			row.ability = nil
			row:Hide()
		end
	end

	panel:SetHeight(-y + 8)
	return running or table.getn(sorted) > 0
end

-- [name] = GetTime() a guardian of that name was last seen: on a plate, or in
-- the game's "<name> is slain! Its lair yields treasure" announcement.
local guardianSeen = {}
local GUARDIAN_MEMORY = 5
local lastKill = {}             -- the last elite, guardian or boss counted, to set right

local function PlateNames(visit)
	if SurvivorPlatesRegistry then
		for index = 1, table.getn(SurvivorPlatesRegistry) do
			local overlay = SurvivorPlatesRegistry[index]
			if overlay.plate:IsVisible() then
				visit(overlay.stock.name:GetText())
			end
		end
		return
	end
	local children = { WorldFrame:GetChildren() }
	for index = 1, table.getn(children) do
		local plate = children[index]
		local border = plate:GetRegions()
		if plate:IsVisible() and border and border.GetTexture and border:GetObjectType() == "Texture"
			and border:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
			local regions = { plate:GetRegions() }
			for region = 1, table.getn(regions) do
				if regions[region]:GetObjectType() == "FontString" then
					visit(regions[region]:GetText())
					break
				end
			end
		end
	end
end

local function WatchGuardians()
	local now = GetTime()
	PlateNames(function(name)
		local _, _, base = string.find(name or "", "^(.+) %(Guardian%)$")
		if base then
			guardianSeen[base] = now
		end
	end)
end

local function IsGuardian(name)
	return guardianSeen[name] and GetTime() - guardianSeen[name] <= GUARDIAN_MEMORY
end

-- "Gruff Swiftbite is slain! Its lair yields treasure ..."
local function LairCleared(message)
	local _, _, name = string.find(message, "^(.+) is slain! Its lair")
	if not name then
		return
	end
	name = string.gsub(name, " %(Guardian%)$", "")
	guardianSeen[name] = GetTime()
	-- The death line came first and counted it as an elite: move it over.
	if lastKill.name == name and lastKill.kind == "elites" and GetTime() - lastKill.at <= GUARDIAN_MEMORY then
		run.elites = run.elites - 1
		run.guardians = run.guardians + 1
		lastKill.kind = "guardians"
	end
end

-- The game's own clock starts when the hero first moves, so this one does
-- too: from "Move to begin" the hero's map position is watched for a change.
local function WatchFirstStep()
	local x, y = Position()
	if not x then
		return
	end

	if not run.fromX then
		run.fromX, run.fromY = x, y
	elseif math.abs(x - run.fromX) + math.abs(y - run.fromY) > 0.0002 then
		run.armed = nil
		run.started = GetTime()
		run.ended = nil
	end
end

-- On screen from the start of a run; it stays after the run so its last
-- numbers can be read, until the next one starts.
local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	if run.armed and not run.started then
		WatchFirstStep()
	end

	if run.started and not run.ended then
		WatchPause()
	end

	-- A reset can take a row away from under the mouse; its card goes with it.
	if critTip:IsVisible() and not (critHovered and critHovered:IsVisible() and critHovered.ability) then
		critHovered = nil
		critTip:Hide()
	end

	elapsed = elapsed + arg1
	if elapsed < 0.25 then
		return
	end
	elapsed = 0

	if run.started and not run.ended then
		WatchGuardians()
	end

	if Shown() and Draw() then
		panel:Show()
	else
		panel:Hide()
	end
end)

function SurvivorUI_ToggleRun()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.runPanel = not Shown()
	DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: run panel "..(SurvivorUIDB.runPanel and "shown." or "hidden."))
end

function SurvivorUI_ResetRun()
	ResetCrits()
end

------------------------------------------------------------------------------
-- Reading the combat log.

-- A blow landed with the clock still stopped (the first step went unseen, or
-- the panel was reset mid-run): start it here.
local function Begin()
	if not run.started then
		run.armed = nil
		run.started = GetTime()
		run.ended = nil
	end
end

local function RecordCrit(ability, amount)
	amount = tonumber(amount)
	if not ability or not amount then
		return
	end
	if not critColor[ability] then
		critSeen = critSeen + 1
		critColor[ability] = CRIT_PALETTE[math.mod(critSeen - 1, table.getn(CRIT_PALETTE)) + 1]
	end

	local stats = critStats[ability]
	if not stats then
		stats = { sum = 0, count = 0, least = amount }
		critStats[ability] = stats
	end
	stats.last = amount
	stats.sum = stats.sum + amount
	stats.count = stats.count + 1
	stats.least = math.min(stats.least, amount)

	if not critBest[ability] or amount > critBest[ability] then
		critBest[ability] = amount
	end
	if critHovered and critHovered:IsVisible() then
		CritTooltip(critHovered)
	end
end

local function RecordHit(ability, amount)
	amount = tonumber(amount)
	if not ability or not amount then
		return
	end
	local stats = hitStats[ability]
	if not stats then
		stats = { sum = 0, count = 0 }
		hitStats[ability] = stats
	end
	stats.last = amount
	stats.sum = stats.sum + amount
	stats.count = stats.count + 1
	if critHovered and critHovered:IsVisible() then
		CritTooltip(critHovered)
	end
end

-- The same four shapes as a crit's line, with "hits" in place of "crits".
local function Hit(message)
	local _, _, ability, _, amount = string.find(message, "^Your (.+) hits (.+) for (%d+)")
	if not ability then
		_, _, _, amount = string.find(message, "^You hit (.+) for (%d+)")
		if amount then
			ability = "Melee"
		end
	end
	if not ability then
		_, _, _, ability, _, amount = string.find(message, "^(.+)'s (.+) hits (.+) for (%d+)")
	end
	if not ability then
		_, _, ability, _, amount = string.find(message, "^(.+) hits (.+) for (%d+)")
	end
	RecordHit(ability, amount)
end

local function Crit(message)
	-- "Your Lightning Bolt crits Kobold Vermin for 168."
	local _, _, ability, _, amount = string.find(message, "^Your (.+) crits (.+) for (%d+)")
	if not ability then
		-- "You crit Kobold Vermin for 40."
		_, _, _, amount = string.find(message, "^You crit (.+) for (%d+)")
		if amount then
			ability = "Melee"
		end
	end
	if not ability then
		-- "Magma Totem's Magma Totem crits Kobold Vermin for 90."
		_, _, _, ability, _, amount = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+)")
	end
	if not ability then
		-- "Spirit Wolf crits Kobold Vermin for 30."
		_, _, ability, _, amount = string.find(message, "^(.+) crits (.+) for (%d+)")
	end
	RecordCrit(ability, amount)
end

local function Dealt(message)
	local _, _, amount = string.find(message, " for (%d+)")
	if not amount then
		-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
		_, _, amount = string.find(message, " suffers (%d+) .+ from your ")
	end
	if not amount then
		-- "You reflect 4 Nature damage to Kobold Vermin."
		_, _, amount = string.find(message, "^You reflect (%d+) ")
	end
	if amount then
		Begin()
		run.dealt = run.dealt + tonumber(amount)
	end
end

local function Taken(message)
	-- "Kobold Vermin hits you for 5." / "You suffer 3 Nature damage from ..."
	local _, _, amount = string.find(message, " you for (%d+)")
	if not amount then
		_, _, amount = string.find(message, "^You suffer (%d+) ")
	end
	if amount then
		run.taken = run.taken + tonumber(amount)
	end
end

local function Death(message)
	-- "You have slain Kobold Vermin!" / "Kobold Vermin dies."
	local _, _, name = string.find(message, "^You have slain (.+)!")
	if not name then
		_, _, name = string.find(message, "^(.+) dies%.")
	end
	if not name or not run.started then
		return
	end

	run.kills = run.kills + 1
	local kind
	if string.find(name, "(Guardian)", 1, true) then
		kind = "guardians"
	elseif kindByName[name] == "elites" and IsGuardian(name) then
		kind = "guardians"
	else
		kind = kindByName[name]
	end
	if kind then
		run[kind] = run[kind] + 1
		lastKill.name, lastKill.kind, lastKill.at = name, kind, GetTime()
	end
end

-- Events whose hits can also be critical strikes.
local HIT_EVENTS = {
	CHAT_MSG_COMBAT_SELF_HITS = true, CHAT_MSG_SPELL_SELF_DAMAGE = true,
	CHAT_MSG_COMBAT_PET_HITS = true, CHAT_MSG_SPELL_PET_DAMAGE = true,
}
local DEALT_EVENTS = {
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = true, CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = true,
}
local TAKEN_EVENTS = {
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = true, CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = true,
	CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = true,
}

local events = CreateFrame("Frame")
for _, group in pairs({ HIT_EVENTS, DEALT_EVENTS, TAKEN_EVENTS }) do
	for event in pairs(group) do
		events:RegisterEvent(event)
	end
end
events:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
events:RegisterEvent("CHAT_MSG_MONSTER_YELL")
-- Nothing to tally in a miss, but it is the world moving: see Alive.
events:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
events:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
events:SetScript("OnEvent", function()
	local message = arg1 or ""

	-- Wherever the game puts its lair announcement.
	if string.find(message, " is slain! Its lair", 1, true) then
		LairCleared(message)
	end

	if event == "CHAT_MSG_SYSTEM" then
		-- "<hero> enters <zone>. Move to begin.": a new run.
		if string.find(message, "Move to begin", 1, true) then
			ResetRun()
			run.armed = true
		-- "Your mages earn 373 talent experience.": the run is over.
		elseif string.find(message, "talent experience", 1, true) and run.started and not run.ended then
			Alive()
			run.ended = GetTime()
		end
		return
	end

	if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		Death(message)
	elseif HIT_EVENTS[event] then
		Dealt(message)
		Crit(message)
		Hit(message)
	elseif DEALT_EVENTS[event] then
		-- The periodic event also carries other units' damage; only "your" counts.
		if event ~= "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" or string.find(message, "from your", 1, true) then
			Dealt(message)
		end
	elseif TAKEN_EVENTS[event] then
		Taken(message)
	end
	Alive()
end)
