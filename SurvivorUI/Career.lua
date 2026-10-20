-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: Career, every run Run History keeps added up.
--
-- A window of its own, opened from Run History's Career button (and back with
-- Runs), in its place: by class (its icon and color), then by map (its icon
-- and its name in green), a line each: the runs, won, fallen and left; the
-- longest, the most kills, the best DPS (between runs of 2 minutes or more,
-- as Run History's personal bests); the kills in all. Under them, all of it
-- together: the runs, the time played, the kills, the damage, the gold, the
-- talent experience. An endless run counts by its end; a run won counts as
-- won, however its endless part ended.
--
-- The runs are Run History's own (SurvivorUIDB.runHistory): as many as it
-- keeps (the options, Run History).

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local MAP_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\MapIcon"
local GOLD = { 1, 0.82, 0 }
local MUTED = { 0.6, 0.6, 0.65 }
local WHITE = { 1, 1, 1 }
local WON = { 0.35, 0.90, 0.40 }
local FELL = { 1.00, 0.38, 0.32 }
local LEFT = { 0.62, 0.82, 1.00 }
local ZONE = { 0.40, 1.00, 0.42 }

local WIDTH, PAD, ROW = 720, 12, 18
local INNER = WIDTH - 2 * PAD
-- The columns after the name: their titles, where each ends (from the left).
local COLUMNS = {
	{ "Runs", 236 }, { "Won", 290 }, { "Fallen", 344 }, { "Left", 398 },
	{ "Longest", 470 }, { "Most kills", 548 }, { "Best DPS", 626 }, { "Kills in all", INNER },
}

local function Num(value)
	return tonumber(value) or 0
end

-- A run's damage as the meter counts it, not the end screen's with the
-- overkill (RunHistory.lua's Dealt).
local function Dealt(run)
	if SurvivorUI_RunDealt then
		return SurvivorUI_RunDealt(run)
	end
	return Num(run and run.dealt)
end

local function Short(value)
	return SurvivorUI_Abbrev and SurvivorUI_Abbrev(value) or tostring(math.floor(Num(value) + 0.5))
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(Num(seconds)))
	local hours = math.floor(seconds / 3600)
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, math.floor(math.mod(seconds, 3600) / 60), math.mod(seconds, 60))
	end
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

local function Font(parent, size, color, justify)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	color = color or WHITE
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH(justify or "LEFT")
	return text
end

------------------------------------------------------------------------------
-- The window: held by its top, as Run History.

local window = CreateFrame("Frame", "SurvivorUICareer", UIParent)
window:SetWidth(WIDTH)
window:SetHeight(200)
window:SetPoint("TOP", UIParent, "TOP", 0, -60)
window:SetFrameStrata("DIALOG")
window:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
window:SetBackdropColor(0.04, 0.04, 0.07, 0.97)
window:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
window:EnableMouse(true)
window:SetMovable(true)
if window.SetClampedToScreen then
	window:SetClampedToScreen(true)
end
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", function() this:StartMoving() end)
window:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local left, top = this:GetLeft(), this:GetTop()
	if left and top then
		this:ClearAllPoints()
		this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	end
end)
window:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUICareer")
end

local title = Font(window, 16, GOLD)
title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -10)
title:SetText("Career")
local subtitle = Font(window, 9, MUTED)
subtitle:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -32)
subtitle:SetText("Every run Run History keeps, by class and by map.")

local function TextButton(label, width, onClick)
	local button = CreateFrame("Button", nil, window)
	button:SetWidth(width)
	button:SetHeight(18)
	button.text = Font(button, 12, MUTED, "CENTER")
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(label)
	button:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	button:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	button:SetScript("OnClick", onClick)
	return button
end

local close = TextButton("x", 18, function() window:Hide() end)
close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -7)
-- Back to the runs, in the same place: Run History's gold button with its
-- hourglass, the one by the minimap (RunHistory.lua's SurvivorUI_GoldButton).
local function BackToRuns()
	local history = getglobal("SurvivorUILastRuns")
	if history and window:GetLeft() then
		history:ClearAllPoints()
		history:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", window:GetLeft(), window:GetTop())
	end
	window:Hide()
	if SurvivorUI_ShowRunHistory and not (history and history:IsShown()) then
		SurvivorUI_ShowRunHistory()
	end
end

local runs
if SurvivorUI_GoldButton then
	runs = SurvivorUI_GoldButton(window, 62, "Interface\\AddOns\\SurvivorUI\\Art\\HistoryIconWhite", nil, "Runs")
	runs.icon:SetVertexColor(1, 0.85, 0.4)
	runs.tipTitle = "Run History"
	runs.tipText = "Back to the runs, one by one."
	runs:SetScript("OnClick", BackToRuns)
else
	runs = TextButton("Runs", 50, BackToRuns)
end
runs:SetPoint("RIGHT", close, "LEFT", -10, 0)

------------------------------------------------------------------------------
-- The lines: each a name (an icon before it) and its columns' values.

local lines, heads = {}, {}

local function Line(index)
	local line = lines[index]
	if line then
		return line
	end
	line = CreateFrame("Frame", nil, window)
	line:SetWidth(INNER)
	line:SetHeight(ROW)
	line.wash = line:CreateTexture(nil, "BACKGROUND")
	line.wash:SetTexture(FLAT)
	line.wash:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -1)
	line.wash:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 1)
	line.rule = line:CreateTexture(nil, "BORDER")
	line.rule:SetTexture(FLAT)
	line.rule:SetHeight(1)
	line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
	line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetWidth(ROW - 4)
	line.icon:SetHeight(ROW - 4)
	line.icon:SetPoint("LEFT", line, "LEFT", 2, 0)
	line.name = Font(line, 10, WHITE)
	line.name:SetPoint("LEFT", line, "LEFT", ROW + 2, 0)
	line.cells = {}
	for column = 1, table.getn(COLUMNS) do
		local cell = Font(line, 10, WHITE, "RIGHT")
		cell:SetPoint("RIGHT", line, "LEFT", COLUMNS[column][2] - 4, 0)
		line.cells[column] = cell
	end
	lines[index] = line
	return line
end

-- A section's title and its columns' names, over its lines.
local function Head(index)
	local head = heads[index]
	if head then
		return head
	end
	head = CreateFrame("Frame", nil, window)
	head:SetWidth(INNER)
	head:SetHeight(28)
	head.title = Font(head, 11, GOLD)
	head.title:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 2, 14)
	head.cells = {}
	for column = 1, table.getn(COLUMNS) do
		local cell = Font(head, 8, MUTED, "RIGHT")
		cell:SetPoint("BOTTOMRIGHT", head, "BOTTOMLEFT", COLUMNS[column][2] - 4, 2)
		cell:SetText(string.upper(COLUMNS[column][1]))
		head.cells[column] = cell
	end
	head.rule = head:CreateTexture(nil, "BORDER")
	head.rule:SetTexture(FLAT)
	head.rule:SetHeight(1)
	head.rule:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
	head.rule:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
	head.rule:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.35)
	heads[index] = head
	return head
end

local total = Font(window, 10, WHITE)
total:SetWidth(INNER)
local empty = Font(window, 10, MUTED)
empty:SetText("No run kept yet: play one, and it shows here.")

------------------------------------------------------------------------------
-- Adding the runs up.

-- A run's end: an endless run's, else its own.
local function Final(run)
	return run.endless or run
end

-- A group's numbers, one run more.
local function Add(groups, key, run)
	local group = groups[key]
	if not group then
		group = { key = key, runs = 0, won = 0, fell = 0, left = 0, longest = 0, kills = 0, mostKills = 0, dps = 0 }
		groups[key] = group
	end
	local final = Final(run)
	local time = Num(final.time)
	group.runs = group.runs + 1
	if run.result == "victory" then
		group.won = group.won + 1
	elseif run.result == "left" then
		group.left = group.left + 1
	else
		group.fell = group.fell + 1
	end
	group.longest = math.max(group.longest, time)
	group.kills = group.kills + Num(final.kills)
	group.mostKills = math.max(group.mostKills, Num(final.kills))
	if time >= 120 then
		group.dps = math.max(group.dps, Dealt(final) / time)
	end
	group.class = group.class or run.class
	return group
end

local function Sorted(groups)
	local list = {}
	for _, group in pairs(groups) do
		table.insert(list, group)
	end
	table.sort(list, function(a, b)
		if a.runs ~= b.runs then
			return a.runs > b.runs
		end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

local function Fill(line, group)
	local values = {
		{ group.runs, WHITE }, { group.won, WON }, { group.fell, FELL }, { group.left, LEFT },
		{ Clock(group.longest), GOLD }, { Short(group.mostKills), WHITE },
		{ group.dps > 0 and Short(group.dps) or "-", WHITE }, { Short(group.kills), MUTED },
	}
	for column = 1, table.getn(values) do
		local cell, value = line.cells[column], values[column]
		cell:SetText(value[1])
		cell:SetTextColor(value[2][1], value[2][2], value[2][3])
	end
end

local function Draw()
	local history = SurvivorUIDB and SurvivorUIDB.runHistory or {}
	local byClass, byZone = {}, {}
	local all = { runs = 0, won = 0, fell = 0, left = 0, time = 0, kills = 0, dealt = 0, gold = 0, talent = 0 }
	for _, run in pairs(history) do
		local final = Final(run)
		Add(byClass, run.classKey or run.class or "?", run)
		Add(byZone, run.zone or "?", run)
		all.runs = all.runs + 1
		if run.result == "victory" then
			all.won = all.won + 1
		elseif run.result == "left" then
			all.left = all.left + 1
		else
			all.fell = all.fell + 1
		end
		all.time = all.time + Num(final.time)
		all.kills = all.kills + Num(final.kills)
		all.dealt = all.dealt + Dealt(final)
		all.gold = all.gold + Num(final.gold)
		all.talent = all.talent + Num(run.talentXp) + (run.endless and Num(run.endless.talentXp) or 0)
	end

	local y = 50
	local used = 0
	local sections = { { "By class", Sorted(byClass), "class" }, { "By map", Sorted(byZone), "zone" } }
	for index = 1, table.getn(sections) do
		local section = sections[index]
		local head = Head(index)
		head.title:SetText(section[1])
		head:ClearAllPoints()
		head:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -y)
		head:Show()
		y = y + 30
		for place = 1, table.getn(section[2]) do
			local group = section[2][place]
			used = used + 1
			local line = Line(used)
			local color
			if section[3] == "class" then
				local r, g, b = 1, 1, 1
				if SurvivorUI_ClassColor then
					r, g, b = SurvivorUI_ClassColor(group.key)
				end
				color = { r, g, b }
				line.name:SetText(group.class or group.key)
				local texture, coords = nil, nil
				if SurvivorUI_ClassIcon then
					texture, coords = SurvivorUI_ClassIcon(group.key)
				end
				if coords then
					local cutX, cutY = (coords[2] - coords[1]) * 0.1, (coords[4] - coords[3]) * 0.1
					line.icon:SetTexture(texture)
					line.icon:SetTexCoord(coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY)
					line.icon:Show()
				else
					line.icon:Hide()
				end
			else
				color = ZONE
				line.name:SetText(group.key)
				line.icon:SetTexture(MAP_ICON)
				line.icon:SetTexCoord(0, 1, 0, 1)
				line.icon:Show()
			end
			line.name:SetTextColor(color[1], color[2], color[3])
			line.wash:SetVertexColor(color[1], color[2], color[3], 0.07)
			line.rule:SetVertexColor(color[1], color[2], color[3], 0.25)
			Fill(line, group)
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -y)
			line:Show()
			y = y + ROW
		end
		y = y + 8
	end
	for index = used + 1, table.getn(lines) do
		lines[index]:Hide()
	end

	-- All of it together.
	if all.runs == 0 then
		for _, head in pairs(heads) do
			head:Hide()
		end
		empty:ClearAllPoints()
		empty:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -56)
		empty:Show()
		total:Hide()
		window:SetHeight(90)
		return
	end
	empty:Hide()
	-- Two lines: the runs and how they ended; what they did.
	total:SetText("In all:  "..all.runs..(all.runs == 1 and " run" or " runs")
		.."  \194\183  |cff59e566"..all.won.." won|r  \194\183  |cffff6152"..all.fell.." fallen|r  \194\183  |cff9ed1ff"..all.left.." left|r\n"
		..Clock(all.time).." played  \194\183  "..Short(all.kills).." kills  \194\183  "..Short(all.dealt).." damage"
		.."  \194\183  "..Short(all.gold).." gold  \194\183  +"..Short(all.talent).." talent experience")
	total:ClearAllPoints()
	total:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -y - 4)
	total:Show()
	window:SetHeight(y + 44)
end

------------------------------------------------------------------------------
-- Opened from Run History (its Career button), in its place.

function SurvivorUI_ShowCareer(from)
	if from and from:GetLeft() then
		window:ClearAllPoints()
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", from:GetLeft(), from:GetTop())
	end
	if from then
		from:Hide()
	end
	window:Show()
	Draw()
end
