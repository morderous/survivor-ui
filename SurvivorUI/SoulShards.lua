-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a warlock's soul shards, gems under the player frame.
--
-- The game tells addons no shard count. Soul Fire's own words say how they
-- come: "Your kills gather soul shards, at most one every 3 sec. At 5 shards a
-- free Soul Fire strikes...". So a kill (the run's kill count going up)
-- gathers one, at most one every so many seconds of the run, and Soul Fire's
-- hit in the combat log empties them: counted, not told, and set right at
-- every Soul Fire. The seconds and the five are read off Soul Fire's tooltip,
-- so a talent or a patch that changes them changes the gems too.
--
-- Counted, so it can go wrong. When Soul Fire's tooltip stops reading as
-- WORDS has it, or another of the hero's spells speaks of shards (a new
-- talent, a new spell that gathers or spends them), the gems dim and the chat
-- says once why: what to set right is then all in WORDS. It costs next to
-- nothing: the other spells are read only when the hero's spells change (one
-- learned, a rank up), Soul Fire's tooltip every 10 seconds.
--
-- In the game's other languages the count is the same (the spell's key, the
-- kills, the combat log, all English), and Soul Fire's sentence is read in
-- the game's own words for it, from LocaleData (bot\locale_build.py writes
-- them; run it again after a game update). The other spells are read for
-- shards in English only: a new spell comes to every language at once.
--
-- The gems light violet as they fill, each new one with a pulse of light, and
-- all of them flash as Soul Fire goes. Only while the hero has Soul Fire.
-- Under the player frame, going with it, until moved on their own (move
-- mode). A module of its own (Modules, Combat).

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local SIZE = 15
local GAP = 2
local CAP = 9                -- the most gems drawn, whatever a tooltip says
local GLOW = { 0.70, 0.32, 1.00 }

-- The game's words this counts by, all of them here.
local WORDS = {
	name = "^Soul Fire",                        -- its tooltip's first line (the game in English)
	every = "at most one every ([%d%.]+) sec",  -- the seconds between two shards
	most = "At (%d+) shards",                   -- how many it takes
	spent = "^Your Soul Fire [hc][ir]",         -- its hit in the combat log: all spent
	other = "shard",                            -- another spell's tooltip on them (lower case)
	notOther = "ice shard",                     -- the mage's Ice Shards are no soul shards
}

local function On()
	return not SurvivorUI_Feature or SurvivorUI_Feature("soulShards")
end

local holder = CreateFrame("Frame", "SurvivorUISoulShards", UIParent)
holder:SetHeight(SIZE)
holder:Hide()

-- The gems for so many shards, made as first needed.
local gems = {}
local function Gems(count)
	for index = table.getn(gems) + 1, count do
		local gem = CreateFrame("Frame", nil, holder)
		gem:SetWidth(SIZE)
		gem:SetHeight(SIZE)
		gem:SetPoint("LEFT", holder, "LEFT", (index - 1) * (SIZE + GAP), 0)
		gem.glow = gem:CreateTexture(nil, "BACKGROUND")
		gem.glow:SetTexture(ART.."PaceGlow")
		gem.glow:SetBlendMode("ADD")
		gem.glow:SetVertexColor(GLOW[1], GLOW[2], GLOW[3])
		gem.glow:SetWidth(SIZE * 2.6)
		gem.glow:SetHeight(SIZE * 2.6)
		gem.glow:SetPoint("CENTER", gem, "CENTER", 0, 0)
		gem.empty = gem:CreateTexture(nil, "ARTWORK")
		gem.empty:SetTexture(ART.."SoulShardEmpty")
		gem.empty:SetAllPoints(gem)
		gem.full = gem:CreateTexture(nil, "OVERLAY")
		gem.full:SetTexture(ART.."SoulShard")
		gem.full:SetAllPoints(gem)
		gem.pulse = 0
		gems[index] = gem
	end
	for index = 1, table.getn(gems) do
		if index <= count then
			gems[index]:Show()
		else
			gems[index]:Hide()
		end
	end
	holder:SetWidth(count * SIZE + (count - 1) * GAP)
end

-- Where it was moved to (move mode: "Soul shards"), its middle and top;
-- else under the player frame, centered, and going with it (under the game's
-- own with the unit frames off).
holder:SetMovable(true)
if holder.SetClampedToScreen then
	holder:SetClampedToScreen(true)
end

local function Place()
	holder:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.shardsX and db.shardsTop then
		holder:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.shardsX, db.shardsTop)
		return
	end
	local frame = getglobal("SurvivorUIPlayer")
	if not (frame and frame:IsVisible()) then
		frame = getglobal("PlayerFrame")
	end
	if frame then
		holder:SetPoint("TOP", frame, "BOTTOM", 0, -5)
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
	end
end

local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.shardsX = math.floor(holder:GetLeft() + holder:GetWidth() / 2 + 0.5)
	SurvivorUIDB.shardsTop = math.floor(holder:GetTop() + 0.5)
	Place()
end

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Soul shards", SavePlace, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.shardsX, SurvivorUIDB.shardsTop = nil, nil
		end
		Place()
	end)
end

------------------------------------------------------------------------------
-- The count.

local shards, lastAt = 0, nil   -- the shards now; the run's second the last came
local kills, clock              -- the run's kills and clock at the last look
local every, most = 3, 5        -- seconds between two shards, shards it takes (Soul Fire's tooltip)
local flash = 0                 -- Soul Fire's flash, seconds left
Gems(most)

------------------------------------------------------------------------------
-- The tooltips.

local seen, slot, mark          -- the spells as last looked at, Soul Fire's button, their mark
local due, readAt               -- when to read all the tooltips; when Soul Fire's was read
local english                   -- Soul Fire's sentence read in English: so can the others be
local reworded, rival           -- Soul Fire's words not found; another spell's name on shards
local told = {}                 -- what the chat has been told

local scan = CreateFrame("GameTooltip", "SurvivorUIShardScan", nil, "GameTooltipTemplate")

-- A button's tooltip, its lines.
local function Lines(button)
	local lines = {}
	if scan.SetAction then
		scan:SetOwner(WorldFrame, "ANCHOR_NONE")
		scan:ClearLines()
		scan:SetAction(button)
		for line = 1, scan:NumLines() do
			local text = getglobal("SurvivorUIShardScanTextLeft"..line)
			lines[line] = text and text:GetText() or ""
		end
	end
	return lines
end

-- A spell's button: the racial on the twelfth, the rest in order (as the
-- totems' counter has them).
local function Button(index, count)
	return index == count and 12 or index
end

-- Soul Fire's sentence in a tooltip line, colors aside: its seconds and its
-- count, and whether it was English. In another language, only the game's
-- own, by LocaleData's pattern for it, held to the line's start (as the
-- addon's other patterns in other scripts are: never one sought all along a
-- line).
local function Sentence(text)
	text = string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
	local _, _, seconds = string.find(text, WORDS.every)
	local _, _, count = string.find(text, WORDS.most)
	if seconds and count then
		return seconds, count, true
	end
	local language = SurvivorUI_Language and SurvivorUI_Language()
	local data = language and SurvivorUI_LOCALE and SurvivorUI_LOCALE[language]
	if data and data.shards then
		_, _, seconds, count = string.find(text, data.shards)
		if seconds and count then
			return seconds, count
		end
	end
end

-- "2,5" as well as "2.5".
local function Number(text)
	return text and tonumber((string.gsub(text, ",", ".")))
end

-- Dim, and the chat told once, while the count may be off.
local function Report()
	local why = reworded and "Soul Fire's tooltip reads differently now."
		or rival and (rival.." also speaks of soul shards.")
	holder:SetAlpha(why and 0.45 or 1)
	if why and not told[why] then
		told[why] = true
		DEFAULT_CHAT_FRAME:AddMessage("Survivor UI: "..why.." The soul shard count may be off.")
	end
end

-- Soul Fire's tooltip, every 10 seconds; with all, the other spells' too.
local function Read(all)
	if not all and readAt and GetTime() - readAt < 10 then
		return
	end
	readAt = GetTime()
	local lines = Lines(slot)
	-- Soul Fire's name, in a language known: its tooltip can be read.
	local name = lines[1] or ""
	if not (string.find(name, WORDS.name) or (SurvivorUI_English and SurvivorUI_English(name) == "Soul Fire")) then
		return
	end
	local seconds, count
	english = nil
	for line = 2, table.getn(lines) do
		if not seconds then
			seconds, count, english = Sentence(lines[line])
		end
	end
	every = Number(seconds) or every
	most = math.max(1, math.min(CAP, Number(count) or most))
	reworded = not seconds
	shards = math.min(shards, most)
	Gems(most)
	if all then
		rival = nil
	end
	if all and english then
		local total = table.getn(AZS_SPELLS or {})
		for index = 1, total do
			local button = Button(index, total)
			if button ~= slot then
				local other = Lines(button)
				for line = 2, table.getn(other) do
					local text = string.lower(other[line])
					if string.find(text, WORDS.other, 1, true) and not string.find(text, WORDS.notOther, 1, true) then
						rival = other[1]
					end
				end
			end
		end
	end
	Report()
end

-- The hero's spells, looked at when the game sends them anew: Soul Fire's
-- button, and all the tooltips read again two seconds after a spell is
-- learned or ranks up (the buttons have it by then).
local function Spells()
	if AZS_SPELLS == seen then
		return slot
	end
	seen = AZS_SPELLS
	local count = table.getn(seen or {})
	local found, sum = nil, count * 1000
	for index = 1, count do
		local entry = seen[index]
		if (entry.key or entry[1]) == "soul_fire" then
			found = Button(index, count)
		end
		sum = sum + (tonumber(entry.rank or entry[3]) or 0)
	end
	slot = found
	if sum ~= mark then
		mark = sum
		due = GetTime() + 2
	end
	return slot
end

local function RunTime()
	return AZS_GetRunTime and AZS_GetRunTime() or GetTime()
end

-- Soul Fire's hit: the shards spent.
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
events:SetScript("OnEvent", function()
	if string.find(arg1 or "", WORDS.spent) then
		if shards > 0 then
			flash = 0.7
		end
		shards = 0
	end
end)

------------------------------------------------------------------------------
-- Drawing.

local function Draw(elapsed)
	flash = math.max(0, flash - elapsed)
	for index = 1, most do
		local gem = gems[index]
		local lit = index <= shards
		gem.pulse = math.max(0, gem.pulse - elapsed)
		if lit then
			gem.full:Show()
		else
			gem.full:Hide()
		end
		-- A lit gem glows softly, a new one brightly for a moment, all of them
		-- as Soul Fire goes.
		local glow = (lit and 0.35 or 0) + gem.pulse * 1.3 + flash * 1.2
		if glow > 0 then
			gem.glow:SetAlpha(math.min(1, glow))
			gem.glow:Show()
		else
			gem.glow:Hide()
		end
	end
end

local wait = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.05 then
		return
	end
	local elapsed = wait
	wait = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	if not (On() and Spells() and (phase == "playing" or phase == "choosing" or phase == "paused")) then
		holder:Hide()
		return
	end
	-- The tooltips only while the run plays, never as the cards are picked,
	-- and first once the spells have settled.
	if phase == "playing" then
		if due and GetTime() >= due then
			due = nil
			Read(true)
		elseif readAt then
			Read(false)
		end
	end
	local now = RunTime()
	local count = tonumber(AZS_RUN and AZS_RUN.kills) or 0
	-- A new run: the clock or the kills gone back.
	if (clock and now + 3 < clock) or (kills and count < kills) then
		shards, lastAt, kills = 0, nil, nil
	end
	clock = now
	if kills and count > kills and shards < most and (not lastAt or now - lastAt >= every) then
		shards = shards + 1
		lastAt = now
		gems[shards].pulse = 0.5
	end
	kills = count
	if not holder:IsShown() then
		Place()
		holder:Show()
	end
	Draw(elapsed)
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Place)
