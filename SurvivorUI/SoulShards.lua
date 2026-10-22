-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a class's gems under the player frame, as the game counts
-- them: a warlock's soul shards, a rogue's combo points.
--
-- From the game's 0.105 it tells the count itself (AZS_RUN's class proc:
-- proc "soul_fire" or "seal_fate", pv how full, pm full; asked for on
-- 2026-10-20), and the gems follow it, the one on its way lit as far as it
-- has come (the Felguard's swings give a fifth of a shard at a time). Each
-- class's gems have their own art (STYLES) and module (Modules, Combat). The
-- rest below is the soul shards' for a game that tells none, as before it:
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
-- The gems light as they fill, each new one with a pulse of light, and all
-- of them flash as they are spent (Soul Fire, a finisher). Under the player
-- frame, going with it, until moved on their own (move mode: "Class gems").

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local SIZE = 15
local GAP = 2
local CAP = 9                -- the most gems drawn, whatever a tooltip says

-- Each class's gems, by the game's proc (AZS_RUN.proc): their art, their
-- glow, their module. Our own art (scratchpad shard_art.py, combo_art.py).
local STYLES = {
	soul_fire = { full = "SoulShard", empty = "SoulShardEmpty", glow = { 0.70, 0.32, 1.00 }, feature = "soulShards" },
	seal_fate = { full = "ComboPoint", empty = "ComboPointEmpty", glow = { 1.00, 0.22, 0.16 }, feature = "comboPoints" },
	-- A priest's Lightwell: three fonts of light (Fonts, below).
	lightwell = { well = true, feature = "lightwell" },
	-- A warrior's Bloodrage: a bar of rage (Rage, below).
	bloodrage = { rage = true, feature = "bloodrage" },
}
local style = STYLES.soul_fire   -- the gems' look now

-- The game's words this counts by, all of them here.
local WORDS = {
	name = "^Soul ?Fire",                       -- its tooltip's first line (the game in English; "Soulfire" since its 0.110)
	every = "at most one every ([%d%.]+) sec",  -- the seconds between two shards
	most = "At (%d+) shards",                   -- how many it takes
	spent = "^Your Soul ?Fire [hc][ir]",        -- its hit in the combat log: all spent
	other = "shard",                            -- another spell's tooltip on them (lower case)
	notOther = "ice shard",                     -- the mage's Ice Shards are no soul shards
}

local function On()
	return not SurvivorUI_Feature or SurvivorUI_Feature(style.feature)
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
		gem.glow:SetVertexColor(style.glow[1], style.glow[2], style.glow[3])
		gem.glow:SetWidth(SIZE * 2.6)
		gem.glow:SetHeight(SIZE * 2.6)
		gem.glow:SetPoint("CENTER", gem, "CENTER", 0, 0)
		gem.empty = gem:CreateTexture(nil, "ARTWORK")
		gem.empty:SetTexture(ART..style.empty)
		gem.empty:SetAllPoints(gem)
		gem.full = gem:CreateTexture(nil, "OVERLAY")
		gem.full:SetTexture(ART..style.full)
		gem.full:SetPoint("CENTER", gem, "CENTER", 0, 0)
		gem.full:SetWidth(SIZE)
		gem.full:SetHeight(SIZE)
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

-- The gems in another class's look.
local function Dress(next)
	if next == style then
		return
	end
	style = next
	if not style.full then
		return
	end
	for index = 1, table.getn(gems) do
		local gem = gems[index]
		gem.full:SetTexture(ART..style.full)
		gem.empty:SetTexture(ART..style.empty)
		gem.glow:SetVertexColor(style.glow[1], style.glow[2], style.glow[3])
	end
end

-- Where it was moved to (move mode: "Class gems"), its middle and top;
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
	SurvivorUI_RegisterMover(holder, "Class gems", SavePlace, nil, function()
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
	if SurvivorUI_SpellSlot then
		return SurvivorUI_SpellSlot(index)
	end
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
	local why = reworded and "Soulfire's tooltip reads differently now."
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
	local english = SurvivorUI_English and SurvivorUI_English(name)
	if not (string.find(name, WORDS.name) or english == "Soul Fire" or english == "Soulfire") then
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

-- The game's own count (0.105 on): AZS_RUN's class proc, "soul_fire", how
-- full it is (pv: a fifth of a shard at a time from the Felguard's swings)
-- and full (pm). With it nothing is counted or read, and nothing is in doubt.
local exact = false               -- the game's count in use
local part = 0                    -- the next shard's share, 0 to 1 (the game's count)
local function Exact()
	local game = AZS_RUN
	local styled = game and STYLES[game.proc or ""]
	if styled and tonumber(game.pm) then
		return tonumber(game.pv) or 0, tonumber(game.pm), styled
	end
end

-- Soul Fire's hit: the shards spent (by the game's count itself, when it is there).
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
events:SetScript("OnEvent", function()
	if not exact and string.find(arg1 or "", WORDS.spent) then
		if shards > 0 then
			flash = 0.7
		end
		shards = 0
	end
end)

------------------------------------------------------------------------------
-- A priest's Lightwell: three fonts of light, one for each well that can
-- stand (the game's "up to 3 stand at once"), the newest always at the left;
-- our own art (scratchpad font_art.py; the stars, the wings and the halo bar
-- before it are kept aside in D:\WoW-Survivors\reserva). Each is a stone
-- basin, its pool aglow while its well stands, a beam of light rising from
-- it as high as the well's time left, a star at its top; out, a dark basin.
-- The game's 0 to 1 is the newest well's time left while one stands (a
-- twelfth a second at 12 sec, seen 2026-10-20), and where the cooldown
-- outlasts it, the cooldown's last part between two wells, rising: the
-- newest font drains with the one, and with the other its pool comes up dim,
-- no beam. A new well comes before the last is out from rank V, up to 3 from
-- rank XIII, never more (at XXVII one every 6 sec for 23: a new one past 3
-- takes the oldest away); the older ones are reckoned by the pace of the
-- fall. Each font fades through its well's last seconds; a new well comes
-- with a flash.

local OLDER_ROWS = 2              -- the older wells drawn, besides the newest
local FONT_W, FONT_H = 18, 24     -- a font and its beam's room
local FONT_GAP = 5
local BASIN_H = 9                 -- the basin at a font's foot
local POOL = 6                    -- its pool over the foot, the beam's root
local BEAM_W, BEAM_MAX = 7, 15    -- the beam's width, and its height at a full well
local FADE_SECONDS = 3            -- a font fades through its well's last seconds
local well = { olders = {}, standing = true, shown = 0 }
local dim = false                 -- the newest font dim, filling: the next well awaited
local fonts                       -- made as first needed

-- The game's number, and what it says: the well's time left, standing or
-- not, the older wells'.
local function WellState(value)
	local w, now = well, GetTime()
	if value ~= w.last then
		if w.last then
			local change = value - w.last
			-- Thrown up, the number is either a new well or, a well just out,
			-- the cooldown's last part (rank IV: 0.05 to 0.83): which, the next
			-- number tells, falling or rising. Till then the font waits, dim.
			local rose = w.pending
			w.pending = nil
			if rose and change < 0 and rose.from > 0.02 then
				local left = rose.from - (w.rate or 0) * (now - rose.at)
				if left > 0 then
					table.insert(w.olders, 1, left)
				end
			end
			if (rose and change < 0) or (not rose and change < 0 and not w.standing) then
				-- A new well: draining after the throw, or after filling.
				w.standing = true
				flash = 0.8
			elseif not rose and change > 0.15 then
				w.pending = { from = w.last, at = w.at }
				w.standing = false
			elseif rose then
				w.standing = false
			elseif change < 0 then
				local pace = -change / math.max(0.05, now - (w.at or now))
				w.rate = w.rate and (w.rate * 0.7 + pace * 0.3) or pace
				w.standing = true
			else
				w.standing = false
			end
		end
		w.last, w.at = value, now
	end
	-- Between the game's numbers a standing well drains on, smoothly.
	w.shown = value
	if w.standing and w.rate then
		w.shown = math.max(0, value - w.rate * (now - w.at))
	end
	-- The older wells run down at the same pace; one out, or past the game's
	-- three, is dropped.
	for index = table.getn(w.olders), 1, -1 do
		w.olders[index] = w.olders[index] - (w.rate or 0) * (now - (w.olderAt or now))
		if w.olders[index] <= 0 or index > OLDER_ROWS then
			table.remove(w.olders, index)
		end
	end
	w.olderAt = now
	dim = not w.standing
end

local function Tex(parent, layer, file, blend)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(file)
	if blend then
		texture:SetBlendMode(blend)
	end
	return texture
end

local function MakeFonts()
	fonts = {}
	for index = 1, 1 + OLDER_ROWS do
		local font = CreateFrame("Frame", nil, holder)
		font:SetWidth(FONT_W)
		font:SetHeight(FONT_H)
		font:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (FONT_W + FONT_GAP), 0)
		-- The glow about the pool, the beam rising from it, the basin over the
		-- beam's root: dark, and lit over it.
		font.glow = Tex(font, "BACKGROUND", ART.."PaceGlow", "ADD")
		font.glow:SetVertexColor(1, 0.82, 0.38)
		font.glow:SetWidth(FONT_W * 1.8)
		font.glow:SetHeight(FONT_W * 1.8)
		font.glow:SetPoint("CENTER", font, "BOTTOM", 0, POOL)
		font.beam = Tex(font, "BORDER", ART.."LightwellBeam")
		font.beam:SetWidth(BEAM_W)
		font.beam:SetPoint("BOTTOM", font, "BOTTOM", 0, POOL)
		font.off = Tex(font, "ARTWORK", ART.."LightwellFontOff")
		font.off:SetWidth(FONT_W)
		font.off:SetHeight(BASIN_H)
		font.off:SetPoint("BOTTOM", font, "BOTTOM", 0, 0)
		font.lit = Tex(font, "OVERLAY", ART.."LightwellFont")
		font.lit:SetWidth(FONT_W)
		font.lit:SetHeight(BASIN_H)
		font.lit:SetPoint("BOTTOM", font, "BOTTOM", 0, 0)
		-- The star at the beam's top and a mote rising up it, a level over.
		local top = CreateFrame("Frame", nil, font)
		top:SetAllPoints(font)
		top:SetFrameLevel(font:GetFrameLevel() + 1)
		font.star = Tex(top, "OVERLAY", ART.."LightStar", "ADD")
		font.mote = Tex(top, "OVERLAY", ART.."LightStar", "ADD")
		font.mote:SetWidth(3)
		font.mote:SetHeight(3)
		font.mote.life = index * 0.4
		fonts[index] = font
	end
end

local function Fonts(elapsed)
	if not fonts then
		MakeFonts()
	end
	for index = 1, table.getn(gems) do
		gems[index]:Hide()
	end
	local count = table.getn(fonts)
	holder:SetWidth(count * FONT_W + (count - 1) * FONT_GAP)
	holder:SetHeight(FONT_H)
	flash = math.max(0, flash - elapsed)
	local fade = math.max(0.02, FADE_SECONDS * (well.rate or 0.05))
	for index = 1, count do
		local font = fonts[index]
		font:Show()
		-- The newest well's time left, or the cooldown's while the next one is
		-- awaited; then the older wells', the newer first.
		local left, standing
		if index == 1 then
			left, standing = math.min(1, well.shown), not dim
		else
			left = well.olders[index - 1] or 0
			standing = left > 0.002
		end
		local on = 0
		if standing then
			on = math.min(1, left / fade)
		elseif index == 1 then
			on = 0.15 + 0.45 * left
		end
		if on > 0.01 then
			font.lit:SetAlpha(on)
			font.lit:Show()
		else
			font.lit:Hide()
		end
		-- The glow breathing slowly, each font on its own breath, the newest
		-- blazing at a new well.
		local breath = 0.35 + 0.08 * math.sin(GetTime() * 2.2 + index * 2)
		local glow = standing and breath * on or 0.1 * on
		if index == 1 then
			glow = glow + flash
		end
		if glow > 0.01 then
			font.glow:SetAlpha(math.min(1, glow))
			font.glow:Show()
		else
			font.glow:Hide()
		end
		-- The beam as high as the time left, the star at its top, a mote rising.
		if standing then
			local high = 2 + BEAM_MAX * left
			font.beam:SetHeight(high)
			font.beam:SetAlpha(on)
			font.beam:Show()
			local size = 6 + (index == 1 and flash * 8 or 0)
			font.star:SetWidth(size)
			font.star:SetHeight(size)
			font.star:ClearAllPoints()
			font.star:SetPoint("CENTER", font, "BOTTOM", 0, POOL + high)
			font.star:SetAlpha(math.min(1, on + flash))
			font.star:Show()
			local mote = font.mote
			mote.life = math.mod(mote.life + elapsed, 1.2)
			if high > 5 then
				local t = mote.life / 1.2
				mote:ClearAllPoints()
				mote:SetPoint("CENTER", font, "BOTTOM", 0, POOL + t * high)
				mote:SetAlpha(math.sin(t * math.pi) * 0.8 * on)
				mote:Show()
			else
				mote:Hide()
			end
		else
			font.beam:Hide()
			font.star:Hide()
			font.mote:Hide()
		end
	end
end

local function HideFonts()
	if fonts then
		for index = 1, table.getn(fonts) do
			fonts[index]:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- A warrior's Bloodrage: the game's 0 to 100 of rage, rising as he hits and
-- is hit, set off at the top and back to 0 at once (seen 2026-10-20). Charge:
-- five iron chevrons pointing ahead, a fifth each, the next one filling from
-- its back, a flare at its front; the full ones beat near the top; as it is
-- set off they blaze white for a moment, speed lines streaking back from the
-- first. Our own art (scratchpad charge_art.py; the forge, the other look
-- tried, is kept aside in D:\WoW-Survivors\reserva\bloodrage-forja).

local RAGE_W, RAGE_H = 84, 7      -- the line the chevrons stand on
local CHEVRON_W, CHEVRON_H, CHEVRON_GAP = 15, 14, 2
local BLAZE = 0.9                 -- seconds they blaze as it is set off
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local RAGE = { shown = 0, blaze = 0 }   -- its state, and its frames as made

local function MakeRage()
	local bar = CreateFrame("Frame", nil, holder)
	bar:SetWidth(RAGE_W)
	bar:SetHeight(RAGE_H)
	bar:SetPoint("TOP", holder, "TOP", 0, -7)
	-- Each chevron its glow, its iron, its blood and the blaze's white over
	-- it; the front's flare; the speed lines.
	bar.chevrons = {}
	for index = 1, 5 do
		local chevron = {}
		local x = (index - 1) * (CHEVRON_W + CHEVRON_GAP) - 0.5
		chevron.glow = Tex(bar, "BACKGROUND", ART.."PaceGlow", "ADD")
		chevron.glow:SetWidth(CHEVRON_W * 1.8)
		chevron.glow:SetHeight(CHEVRON_W * 1.8)
		chevron.glow:SetPoint("CENTER", bar, "LEFT", x + CHEVRON_W / 2, 0)
		chevron.iron = Tex(bar, "BORDER", ART.."ChevronIron")
		chevron.iron:SetWidth(CHEVRON_W)
		chevron.iron:SetHeight(CHEVRON_H)
		chevron.iron:SetPoint("LEFT", bar, "LEFT", x, 0)
		chevron.fill = Tex(bar, "ARTWORK", ART.."ChevronFill")
		chevron.fill:SetHeight(CHEVRON_H)
		chevron.fill:SetPoint("LEFT", bar, "LEFT", x, 0)
		chevron.heat = Tex(bar, "OVERLAY", ART.."ChevronFill", "ADD")
		chevron.heat:SetVertexColor(1, 0.85, 0.6)
		chevron.heat:SetWidth(CHEVRON_W)
		chevron.heat:SetHeight(CHEVRON_H)
		chevron.heat:SetPoint("LEFT", bar, "LEFT", x, 0)
		chevron.x = x
		bar.chevrons[index] = chevron
	end
	bar.front = Tex(bar, "OVERLAY", ART.."PaceGlow", "ADD")
	bar.front:SetVertexColor(1, 0.6, 0.25)
	bar.front:SetWidth(12)
	bar.front:SetHeight(12)
	bar.lines = {}
	for index = 1, 3 do
		local line = Tex(bar, "OVERLAY", FLAT, "ADD")
		line:SetVertexColor(1, 0.92, 0.75)
		line:SetHeight(1)
		line.long, line.y = index == 2 and 12 or 9 - index, index * 4 - 8
		bar.lines[index] = line
	end
	RAGE.bar = bar
end

local function Rage(elapsed, share)
	if not RAGE.bar then
		MakeRage()
	end
	local bar, state = RAGE.bar, RAGE
	for index = 1, table.getn(gems) do
		gems[index]:Hide()
	end
	holder:SetWidth(RAGE_W + 20)
	holder:SetHeight(RAGE_H + 14)
	bar:Show()
	-- Set off: from high to nothing at once.
	share = math.max(0, math.min(1, share))
	if state.last and state.last - share > 0.3 then
		state.blaze = BLAZE
	end
	state.last = share
	-- Rising smoothly to the game's number, falling at once.
	if share > state.shown then
		state.shown = math.min(share, state.shown + math.max(0.004, (share - state.shown) * math.min(1, elapsed * 8)))
	else
		state.shown = share
	end
	state.blaze = math.max(0, state.blaze - elapsed)
	local blaze, shown = state.blaze / BLAZE, state.shown
	local beat = 0.75 + 0.25 * math.sin(GetTime() * 9)
	for index = 1, 5 do
		local chevron = bar.chevrons[index]
		local part = blaze > 0 and 1 or math.max(0, math.min(1, shown * 5 - index + 1))
		if part > 0.02 then
			chevron.fill:SetWidth(CHEVRON_W * part)
			chevron.fill:SetTexCoord(0, part, 0, 1)
			chevron.fill:SetAlpha(blaze > 0 and blaze or 1)
			chevron.fill:Show()
		else
			chevron.fill:Hide()
		end
		if blaze > 0 then
			chevron.heat:SetAlpha(0.9 * blaze)
			chevron.heat:Show()
		else
			chevron.heat:Hide()
		end
		local glow = blaze > 0 and 0.7 * blaze or (part >= 1 and (shown > 0.9 and 0.45 * beat or 0.15) or 0)
		if glow > 0.01 then
			chevron.glow:SetVertexColor(1, blaze > 0 and 0.6 or 0.25, blaze > 0 and 0.3 or 0.1)
			chevron.glow:SetAlpha(glow)
			chevron.glow:Show()
		else
			chevron.glow:Hide()
		end
	end
	-- The flare at the front of the one filling.
	local lead = math.floor(shown * 5) + 1
	local part = shown * 5 - lead + 1
	if blaze <= 0 and lead <= 5 and part > 0.02 then
		bar.front:ClearAllPoints()
		bar.front:SetPoint("CENTER", bar, "LEFT", bar.chevrons[lead].x + CHEVRON_W * part, 0)
		bar.front:SetAlpha(0.7)
		bar.front:Show()
	else
		bar.front:Hide()
	end
	-- The speed lines, streaking back as the blaze fades.
	for index = 1, 3 do
		local line = bar.lines[index]
		if blaze > 0 then
			line:SetWidth(line.long * (0.5 + blaze))
			line:ClearAllPoints()
			line:SetPoint("RIGHT", bar, "LEFT", -2 - (1 - blaze) * 6, line.y)
			line:SetAlpha(blaze)
			line:Show()
		else
			line:Hide()
		end
	end
end

local function HideRage()
	if RAGE.bar then
		RAGE.bar:Hide()
	end
end

-- The procs drawn their own way, the Lightwell and Bloodrage: true when one
-- is drawn, else theirs put away.
local function Special(value, full, elapsed)
	if not (value and (style.well or style.rage)) then
		HideFonts()
		HideRage()
		return false
	end
	exact = true
	holder:SetAlpha(1)
	if not holder:IsShown() then
		Place()
		holder:Show()
	end
	if style.well then
		HideRage()
		WellState(value / math.max(0.001, full))
		Fonts(elapsed)
	else
		HideFonts()
		Rage(elapsed, value / math.max(0.001, full))
	end
	return true
end

------------------------------------------------------------------------------
-- Drawing.

local function Draw(elapsed)
	flash = math.max(0, flash - elapsed)
	for index = 1, most do
		local gem = gems[index]
		local lit = index <= shards
		gem.pulse = math.max(0, gem.pulse - elapsed)
		if lit then
			gem.full:SetAlpha(1)
			gem.full:Show()
		elseif index == shards + 1 and part > 0.01 then
			-- The one on its way, lit as far as it has come.
			gem.full:SetAlpha(0.2 + part * 0.5)
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
	local value, full, styled = Exact()
	-- The game's proc's look, or the soul shards' counted.
	Dress(styled or STYLES.soul_fire)
	if not (On() and (value or Spells()) and (phase == "playing" or phase == "choosing" or phase == "paused")) then
		holder:Hide()
		return
	end
	if Special(value, full, elapsed) then
		return
	end
	holder:SetHeight(SIZE)
	if value then
		-- The game's count: each whole one come lights its gem with a pulse,
		-- all of them flash as they go (Soul Fire, a finisher).
		exact = true
		holder:SetAlpha(1)
		full = math.max(1, math.min(CAP, full))
		if full ~= most then
			most = full
			Gems(most)
		end
		local whole = math.min(most, math.floor(value + 0.001))
		if whole > shards then
			for index = shards + 1, whole do
				gems[index].pulse = 0.5
			end
		elseif whole < shards then
			flash = 0.7
		end
		shards = whole
		part = whole < most and value - whole or 0
	else
		exact, part = false, 0
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
	end
	if not holder:IsShown() then
		Place()
		holder:Show()
	end
	Draw(elapsed)
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", Place)
