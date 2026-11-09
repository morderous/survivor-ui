-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the performance monitor, /sui perf (or /suiperf).
--
-- To find what makes the game lag, and where. Switched on, it wraps the
-- OnUpdate and OnEvent of every frame of every addon (and of the game's own
-- interface) with a stopwatch: the time each script takes (its own, without
-- the scripts it sets off), how often it runs, its worst run and the Lua
-- memory it leaves behind as garbage. Events are summed the same way, by
-- name. Each frame of the game is timed too: the frames over 50 ms are kept
-- with the addon time spent in them and the heaviest script there.
--
-- The clock is debugprofilestop, real milliseconds in this game (a live clock,
-- not GetTime's per frame one), read against one debugprofilestart made when
-- the monitor starts; gcinfo gives the Lua memory in KB. New frames and new
-- scripts are found by walking EnumerateFrames, a few hundred frames a tick.
-- While it runs, every new frame's file and line (debugstack) is counted, for
-- frames made over and over. Off, the stopwatches pass straight through.
--
-- Its numbers are saved in SurvivorUIDB.perf on Report and when the game
-- closes with it on, so a run's numbers can be read after the game.
--
-- This file loads before SurvivorUI.lua, to know which file made each frame.

local P = {
	on = false, loading = true, sort = "ms", tab = "frames",
	entries = {}, list = {}, wrappers = {}, events = {}, created = {},
	sites = setmetatable({}, { __mode = "k" }), mine = {}, early = {},
	spikes = {}, childMs = 0, childKb = 0,
}
SurvivorUI_Perf = P

local SLOW = 50         -- ms: a frame slower than this is a spike
local STEP = 250        -- frames looked at per tick, looking for new scripts
local ROWS = 15
local SCRIPTS = { "OnUpdate", "OnEvent" }

local function Clock()
	if debugprofilestop then
		return debugprofilestop()
	end
	return GetTime() * 1000
end

local function T(text)
	return SurvivorUI_T and SurvivorUI_T(text) or text
end

local function TF(text, a, b, c, d, e)
	if SurvivorUI_TF then
		return SurvivorUI_TF(text, a, b, c, d, e)
	end
	return text
end

-- Where a frame was made: "SurvivorUI", "Meter.lua:123", from the stack.
local function Site()
	if not debugstack then
		return nil
	end
	local ok, stack = pcall(debugstack, 2, 5, 0)
	if not ok or type(stack) ~= "string" then
		return nil
	end
	for line in string.gfind(stack, "[^\n]+") do
		local _, _, addon, file, number = string.find(line, "AddOns[\\/]([^\\/]+)[\\/](.-%.lua)%D(%d+)")
		if addon and file ~= "Perf.lua" then
			local _, _, short = string.find(file, "([^\\/]+)$")
			return addon, (short or file)..":"..number
		end
	end
	return nil
end

-- Every new frame is told apart by where it was made, while loading and
-- while the monitor runs (then also counted, for frames made over and over).
local MakeFrame = CreateFrame
CreateFrame = function(a, b, c, d, e)
	local frame = MakeFrame(a, b, c, d, e)
	if P.loading or P.on then
		local addon, where = Site()
		if addon and frame then
			P.sites[frame] = { addon, where }
			if P.on then
				local key = addon.." "..where
				P.created[key] = (P.created[key] or 0) + 1
			end
		end
	end
	return frame
end

-- The frames already there as this file loads: the game's interface and the
-- addons loaded before this one.
if EnumerateFrames then
	local frame = EnumerateFrames()
	while frame do
		P.early[frame] = true
		frame = EnumerateFrames(frame)
	end
end

-- Whose a frame is, by where it was made, else by its name or a parent's.
local OWNERS = {
	{ "^SurvivorPlates", "SurvivorPlates" }, { "^SurvivorUIClassic", "SurvivorUIClassic" },
	{ "^SUIC", "SurvivorUIClassic" }, { "^SurvivorUI", "SurvivorUI" },
	{ "^SurvivorDebug", "SurvivorDebug" }, { "^SurvivorBot", "SurvivorBot" },
}

function P.Label(frame)
	local site = P.sites[frame]
	local name = frame.GetName and frame:GetName()
	local holder, owner = frame, nil
	local depth = 0
	while holder and not owner and depth < 6 do
		local held = holder.GetName and holder:GetName()
		if held then
			for _, rule in ipairs(OWNERS) do
				if string.find(held, rule[1]) then
					owner = rule[2]
					break
				end
			end
			if depth > 0 and not name then
				name = "("..(frame.GetObjectType and frame:GetObjectType() or "Frame").." in "..held..")"
			end
		end
		holder = holder.GetParent and holder:GetParent()
		depth = depth + 1
	end
	if site then
		owner = site[1]
		name = name and (name.."  "..site[2]) or site[2]
	end
	if not owner and P.early[frame] then
		owner = T("Game or earlier addon")
	end
	return name or "("..(frame.GetObjectType and frame:GetObjectType() or "Frame")..")", owner or "?"
end

function P.Wrap(entry, orig)
	return function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
		if not P.on then
			orig(a1, a2, a3, a4, a5, a6, a7, a8, a9)
			return
		end
		local outerMs, outerKb = P.childMs, P.childKb
		P.childMs, P.childKb = 0, 0
		local m0 = gcinfo()
		local t0 = Clock()
		orig(a1, a2, a3, a4, a5, a6, a7, a8, a9)
		local ms = Clock() - t0
		local kb = gcinfo() - m0
		if ms < 0 then ms = 0 end
		if kb < 0 then kb = 0 end
		local own, ownKb = ms - P.childMs, kb - P.childKb
		P.childMs, P.childKb = outerMs + ms, outerKb + kb
		if own < 0 then own = 0 end
		if ownKb < 0 then ownKb = 0 end
		entry.calls = entry.calls + 1
		entry.ms = entry.ms + own
		entry.kb = entry.kb + ownKb
		if own > entry.max then
			entry.max = own
		end
		P.frameMs = P.frameMs + own
		if own > P.frameTopMs then
			P.frameTopMs, P.frameTop = own, entry
		end
		if entry.script == "OnEvent" then
			local name = event or "?"
			local ev = P.events[name]
			if not ev then
				ev = { label = name, owner = "", calls = 0, ms = 0, max = 0, kb = 0 }
				P.events[name] = ev
			end
			ev.calls = ev.calls + 1
			ev.ms = ev.ms + own
			ev.kb = ev.kb + ownKb
			if own > ev.max then
				ev.max = own
			end
		end
	end
end

-- Puts a stopwatch on one frame's scripts, a new one each time a script is
-- set anew; the numbers stay the frame's.
function P.Watch(frame)
	if P.mine[frame] then
		return
	end
	for _, script in ipairs(SCRIPTS) do
		local ok, handler = pcall(frame.GetScript, frame, script)
		if ok and handler and not P.wrappers[handler] then
			local byScript = P.entries[frame]
			if not byScript then
				byScript = {}
				P.entries[frame] = byScript
			end
			local entry = byScript[script]
			if not entry then
				local label, owner = P.Label(frame)
				entry = { label = label, owner = owner, script = script, calls = 0, ms = 0, max = 0, kb = 0 }
				byScript[script] = entry
				table.insert(P.list, entry)
			end
			entry.frame, entry.orig = frame, handler
			entry.wrapper = P.Wrap(entry, handler)
			P.wrappers[entry.wrapper] = entry
			frame:SetScript(script, entry.wrapper)
		end
	end
end

function P.Scan()
	if not EnumerateFrames then
		return
	end
	local frame = P.cursor
	for _ = 1, STEP do
		frame = EnumerateFrames(frame)
		if not frame then
			P.passes = (P.passes or 0) + 1
			break
		end
		P.Watch(frame)
	end
	P.cursor = frame
end

function P.Reset()
	for _, entry in ipairs(P.list) do
		entry.calls, entry.ms, entry.max, entry.kb = 0, 0, 0, 0
	end
	P.events, P.created, P.spikes = {}, {}, {}
	P.started = Clock()
	P.frames, P.frameSum, P.worst, P.slow = 0, 0, 0, 0
	P.addonSum, P.alloc, P.gcs, P.selfMs = 0, 0, 0, 0
	P.frameMs, P.frameTopMs, P.frameTop = 0, 0, nil
	P.lastKb = gcinfo()
	P.childMs, P.childKb = 0, 0
end

function P.Start()
	if P.on then
		return
	end
	if debugprofilestart then
		debugprofilestart()
	end
	P.on = true
	P.cursor = nil
	P.Reset()
	P.Ticker():Show()
	DEFAULT_CHAT_FRAME:AddMessage(T("Survivor UI: performance monitor on. It times every addon's OnUpdate and OnEvent; /sui perf hides or shows the window, /sui perf off stops it."))
end

function P.Stop()
	if not P.on then
		return
	end
	P.on = false
	for frame, byScript in pairs(P.entries) do
		for script, entry in pairs(byScript) do
			if frame:GetScript(script) == entry.wrapper then
				frame:SetScript(script, entry.orig)
			end
		end
	end
	P.entries, P.list, P.wrappers = {}, {}, {}
	if P.window then
		P.window:Hide()
	end
	P.Ticker():Hide()
	DEFAULT_CHAT_FRAME:AddMessage(T("Survivor UI: performance monitor off."))
end

-- Each frame of the game: its time, the addons' share of it, the garbage.
function P.Tick(elapsed)
	local t0 = Clock()
	local ms = (elapsed or 0) * 1000
	P.frames = P.frames + 1
	P.frameSum = P.frameSum + ms
	P.addonSum = P.addonSum + P.frameMs
	if ms > P.worst then
		P.worst = ms
	end
	if ms > SLOW and P.frames > 1 then
		P.slow = P.slow + 1
		local top = P.frameTop
		table.insert(P.spikes, 1, {
			at = (t0 - P.started) / 1000, ms = ms, addons = P.frameMs,
			label = top and top.label or "-", owner = top and top.owner or "",
			topMs = P.frameTopMs,
		})
		if table.getn(P.spikes) > 60 then
			table.remove(P.spikes)
		end
	end
	P.frameMs, P.frameTopMs, P.frameTop = 0, 0, nil
	local kb = gcinfo()
	if kb < P.lastKb then
		P.gcs = P.gcs + 1
	else
		P.alloc = P.alloc + kb - P.lastKb
	end
	P.lastKb = kb
	P.Scan()
	P.wait = (P.wait or 0) - (elapsed or 0)
	if P.wait <= 0 and P.window and P.window:IsVisible() then
		P.wait = 1
		P.Draw()
	end
	local spent = Clock() - t0
	if spent > 0 then
		P.selfMs = P.selfMs + spent
	end
	P.lastKb = gcinfo()
end

function P.Ticker()
	if not P.ticker then
		P.ticker = MakeFrame("Frame")
		P.mine[P.ticker] = true
		P.ticker:Hide()
		P.ticker:SetScript("OnUpdate", function()
			P.Tick(arg1)
		end)
	end
	return P.ticker
end

------------------------------------------------------------------------------
-- The numbers, sorted, per second of watching.

function P.Seconds()
	return math.max(0.001, (Clock() - (P.started or Clock())) / 1000)
end

local function Sorted(items, key)
	table.sort(items, function(a, b)
		if a[key] == b[key] then
			return a.ms > b.ms
		end
		return a[key] > b[key]
	end)
	return items
end

function P.Rows(tab, key)
	local rows = {}
	if tab == "frames" then
		for _, entry in ipairs(P.list) do
			if entry.calls > 0 then
				table.insert(rows, entry)
			end
		end
	elseif tab == "events" then
		for _, ev in pairs(P.events) do
			table.insert(rows, ev)
		end
	elseif tab == "addons" then
		local by = {}
		for _, entry in ipairs(P.list) do
			if entry.calls > 0 then
				local sum = by[entry.owner]
				if not sum then
					sum = { label = entry.owner, owner = "", calls = 0, ms = 0, max = 0, kb = 0, scripts = 0 }
					by[entry.owner] = sum
					table.insert(rows, sum)
				end
				sum.calls = sum.calls + entry.calls
				sum.ms = sum.ms + entry.ms
				sum.kb = sum.kb + entry.kb
				sum.scripts = sum.scripts + 1
				if entry.max > sum.max then
					sum.max = entry.max
				end
			end
		end
	elseif tab == "created" then
		for key, count in pairs(P.created) do
			local _, _, addon, where = string.find(key, "^(%S+) (.*)$")
			table.insert(rows, { label = where or key, owner = addon or "", calls = count, ms = count, max = 0, kb = 0 })
		end
		return Sorted(rows, "calls")
	elseif tab == "spikes" then
		return P.spikes
	end
	return Sorted(rows, key)
end

function P.Totals()
	local seconds = P.Seconds()
	local frames = math.max(1, P.frames)
	local avg = P.frameSum / frames
	return {
		seconds = seconds, fps = GetFramerate and GetFramerate() or frames / seconds,
		frameAvg = avg, worst = P.worst, slow = P.slow,
		addonPerFrame = P.addonSum / frames,
		addonShare = avg > 0 and 100 * P.addonSum / P.frameSum or 0,
		memory = gcinfo() / 1024, garbage = P.alloc / seconds, gcs = P.gcs,
		selfPerFrame = P.selfMs / frames,
		scripts = table.getn(P.list),
	}
end

------------------------------------------------------------------------------
-- The window.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local COLUMNS = {
	{ key = "label", width = 250, left = true },
	{ key = "owner", width = 110, left = true },
	{ key = "calls", width = 56, sort = "calls" },
	{ key = "ms", width = 56, sort = "ms" },
	{ key = "avg", width = 56, sort = "avg" },
	{ key = "max", width = 56, sort = "max" },
	{ key = "kb", width = 56, sort = "kb" },
}
local HEADS = {
	frames = { "Script", "Addon", "Calls/s", "ms/s", "Avg ms", "Max ms", "KB/s" },
	addons = { "Addon", "Scripts", "Calls/s", "ms/s", "Avg ms", "Max ms", "KB/s" },
	events = { "Event", "", "Calls/s", "ms/s", "Avg ms", "Max ms", "KB/s" },
	created = { "Made at", "Addon", "Frames", "Per min", "", "", "" },
	spikes = { "Heaviest script in the frame", "Addon", "At (s)", "Frame ms", "Addons ms", "Its ms", "" },
}
local TABS = { { "frames", "Scripts" }, { "addons", "Addons" }, { "events", "Events" }, { "spikes", "Slow frames" }, { "created", "New frames" } }

local function Text(parent, size, justify)
	local line = parent:CreateFontString(nil, "OVERLAY")
	line:SetFont(SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF", size + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	line:SetJustifyH(justify or "LEFT")
	line:SetTextColor(0.9, 0.88, 0.82)
	return line
end

local function Button(parent, label, width, onClick)
	local button
	if SurvivorUI_GoldButton then
		button = SurvivorUI_GoldButton(parent, width, nil, nil, label)
		button.icon:Hide()
		button.text:ClearAllPoints()
		button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	else
		button = MakeFrame("Button", nil, parent, "UIPanelButtonTemplate")
		button:SetWidth(width)
		button:SetHeight(18)
		button:SetText(label)
	end
	P.mine[button] = true
	button:SetScript("OnClick", onClick)
	return button
end

local function Number(value, places)
	if not value or value == 0 then
		return "0"
	end
	return string.format("%."..(places or 1).."f", value)
end

function P.Build()
	local window = MakeFrame("Frame", "SurvivorUIPerf", UIParent)
	P.window = window
	P.mine[window] = true
	window:SetWidth(680)
	window:SetHeight(110 + ROWS * 15)
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	window:SetFrameStrata("DIALOG")
	window:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	window:SetBackdropColor(0.05, 0.05, 0.06, 0.94)
	window:SetBackdropBorderColor(0.85, 0.68, 0.3, 0.7)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function() this:StartMoving() end)
	window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	if UISpecialFrames then
		table.insert(UISpecialFrames, "SurvivorUIPerf")
	end

	local title = Text(window, 12)
	title:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -8)
	title:SetTextColor(1, 0.82, 0.4)
	title:SetText(T("Survivor UI performance"))
	P.line1 = Text(window, 10)
	P.line1:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -26)
	P.line2 = Text(window, 10)
	P.line2:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -40)
	P.line3 = Text(window, 9)
	P.line3:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -54)
	P.line3:SetTextColor(0.6, 0.6, 0.6)

	local close = Button(window, T("Close"), 56, function() P.window:Hide() end)
	close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -8, -6)
	local stop = Button(window, T("Stop"), 56, function() P.Stop() end)
	stop:SetPoint("RIGHT", close, "LEFT", -6, 0)
	local report = Button(window, T("Report"), 64, function() P.Report(true) end)
	report:SetPoint("RIGHT", stop, "LEFT", -6, 0)
	local reset = Button(window, T("Reset"), 56, function() P.Reset() P.Draw() end)
	reset:SetPoint("RIGHT", report, "LEFT", -6, 0)

	P.tabs = {}
	local last
	for _, tab in ipairs(TABS) do
		local key = tab[1]
		local button = Button(window, T(tab[2]), 90, function()
			P.tab = key
			P.Draw()
		end)
		if last then
			button:SetPoint("LEFT", last, "RIGHT", 4, 0)
		else
			button:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -70)
		end
		button.key = key
		table.insert(P.tabs, button)
		last = button
	end

	P.heads, P.cells = {}, {}
	local x = 10
	for index, column in ipairs(COLUMNS) do
		local head = MakeFrame("Button", nil, window)
		P.mine[head] = true
		head:SetWidth(column.width)
		head:SetHeight(14)
		head:SetPoint("TOPLEFT", window, "TOPLEFT", x, -92)
		head.text = Text(head, 9, column.left and "LEFT" or "RIGHT")
		head.text:SetAllPoints(head)
		head.text:SetTextColor(1, 0.82, 0.4)
		local sort = column.sort
		head:SetScript("OnClick", function()
			if sort then
				P.sort = sort
				P.Draw()
			end
		end)
		P.heads[index] = head
		for row = 1, ROWS do
			local cell = Text(window, 9, column.left and "LEFT" or "RIGHT")
			cell:SetWidth(column.width - 4)
			cell:SetHeight(14)
			cell:SetPoint("TOPLEFT", window, "TOPLEFT", x, -92 - row * 15)
			P.cells[row] = P.cells[row] or {}
			P.cells[row][index] = cell
		end
		x = x + column.width
	end
end

local function Fill(cells, values)
	for index, cell in ipairs(cells) do
		cell:SetText(values[index] or "")
	end
end

function P.Draw()
	if not P.window then
		return
	end
	local t = P.Totals()
	P.line1:SetText(TF("FPS {1}   Frame {2} ms on average, worst {3} ms   Slow frames (over 50 ms): {4}",
		Number(t.fps, 0), Number(t.frameAvg), Number(t.worst, 0), t.slow))
	P.line2:SetText(TF("Addon scripts {1} ms of each frame ({2}%)   Lua memory {3} MB, garbage {4} KB/s, collections {5}",
		Number(t.addonPerFrame, 2), Number(t.addonShare), Number(t.memory), Number(t.garbage, 0), t.gcs))
	P.line3:SetText(TF("{1} scripts watched for {2} s; the monitor itself {3} ms a frame. Click a column to sort.",
		t.scripts, Number(t.seconds, 0), Number(t.selfPerFrame, 2)))
	for _, button in ipairs(P.tabs) do
		button.lit = button.key == P.tab
		if button.Light then
			button:Light(false)
		end
	end
	local heads = HEADS[P.tab]
	for index, head in ipairs(P.heads) do
		local word = heads[index] ~= "" and T(heads[index]) or ""
		if COLUMNS[index].sort == P.sort and (P.tab == "frames" or P.tab == "addons" or P.tab == "events") then
			word = "|cffffffff"..word.."|r"
		end
		head.text:SetText(word)
	end
	local sortKey = P.sort == "avg" and "avg" or P.sort
	local rows = P.Rows(P.tab, P.sort == "avg" and "ms" or sortKey)
	if P.sort == "avg" and P.tab ~= "spikes" and P.tab ~= "created" then
		for _, row in ipairs(rows) do
			row.avg = row.calls > 0 and row.ms / row.calls or 0
		end
		rows = Sorted(rows, "avg")
	end
	local seconds = t.seconds
	for index = 1, ROWS do
		local row = rows[index]
		local cells = P.cells[index]
		if not row then
			Fill(cells, {})
		elseif P.tab == "spikes" then
			Fill(cells, { row.label, row.owner, Number(row.at, 0), Number(row.ms, 0), Number(row.addons), Number(row.topMs) })
		elseif P.tab == "created" then
			Fill(cells, { row.label, row.owner, row.calls, Number(row.calls * 60 / seconds) })
		else
			local owner = P.tab == "addons" and row.scripts or (P.tab == "frames" and row.owner.." "..string.sub(row.script, 3) or "")
			Fill(cells, {
				row.label, owner, Number(row.calls / seconds), Number(row.ms / seconds, 2),
				Number(row.calls > 0 and row.ms / row.calls or 0, 3), Number(row.max, 1), Number(row.kb / seconds),
			})
		end
	end
end

------------------------------------------------------------------------------
-- The report: the numbers kept in SurvivorUIDB.perf, the top in the chat.

local function Copy(rows, count, seconds)
	local out = {}
	for index = 1, math.min(count, table.getn(rows)) do
		local row = rows[index]
		table.insert(out, {
			label = row.label, owner = row.owner, script = row.script, calls = row.calls,
			perSec = row.calls and row.calls / seconds, ms = row.ms, msPerSec = row.ms and row.ms / seconds,
			max = row.max, kb = row.kb, kbPerSec = row.kb and row.kb / seconds,
			at = row.at, addons = row.addons, topMs = row.topMs, scripts = row.scripts,
		})
	end
	return out
end

function P.Report(tell)
	if not P.on then
		return
	end
	local t = P.Totals()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.perf = {
		when = date and date("%Y-%m-%d %H:%M:%S"), seconds = t.seconds, fps = t.fps,
		frameAvg = t.frameAvg, worst = t.worst, slow = t.slow, addonPerFrame = t.addonPerFrame,
		addonShare = t.addonShare, memoryMB = t.memory, garbageKBs = t.garbage, gcs = t.gcs,
		selfPerFrame = t.selfPerFrame, scripts = t.scripts,
		byTime = Copy(P.Rows("frames", "ms"), 40, t.seconds),
		byGarbage = Copy(P.Rows("frames", "kb"), 20, t.seconds),
		byWorst = Copy(P.Rows("frames", "max"), 20, t.seconds),
		addons = Copy(P.Rows("addons", "ms"), 20, t.seconds),
		events = Copy(P.Rows("events", "ms"), 30, t.seconds),
		spikes = Copy(P.spikes, 60, t.seconds),
		created = Copy(P.Rows("created"), 20, t.seconds),
	}
	if tell then
		DEFAULT_CHAT_FRAME:AddMessage(T("Survivor UI: performance report saved; the game writes it to SavedVariables when it closes. The heaviest scripts:"))
		local rows = P.Rows("frames", "ms")
		for index = 1, math.min(5, table.getn(rows)) do
			local row = rows[index]
			DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s (%s %s): %.2f ms/s, %.1f calls/s, max %.1f ms, %.1f KB/s",
				row.label, row.owner, row.script, row.ms / t.seconds, row.calls / t.seconds, row.max, row.kb / t.seconds))
		end
	end
end

-- /sui perf: on and shown; again, hidden or shown (it keeps timing); off, stops.
function SurvivorUI_TogglePerf(argument)
	if argument == "off" or argument == "stop" then
		P.Stop()
		return
	end
	if argument == "reset" then
		if P.on then
			P.Reset()
		end
		return
	end
	if argument == "report" then
		P.Report(true)
		return
	end
	if not P.on then
		P.Start()
	elseif P.window and P.window:IsVisible() then
		P.window:Hide()
		return
	end
	if not P.window then
		P.Build()
	end
	P.window:Show()
	P.wait = 0
end

SLASH_SURVIVORUIPERF1 = "/suiperf"
SlashCmdList["SURVIVORUIPERF"] = function(msg)
	SurvivorUI_TogglePerf(msg)
end

-- Frames made after the interface loads are told apart only while it runs;
-- with it on as the game closes, its numbers are kept.
local watcher = MakeFrame("Frame")
P.mine[watcher] = true
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_LOGOUT")
watcher:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		P.loading = false
	elseif event == "PLAYER_LOGOUT" and P.on then
		P.Report(false)
	end
end)
