-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the party, in the game's co-op runs (its 0.113).
--
-- - Party frames: a flat row for each friend in the party (party1 to
--   party4), in the player frame's look: the class's icon, the health in the
--   class's color with the name and the share left, DOWN in red while the
--   friend is down, a gold fill while you bring them back (AZS_GetRevive's
--   reviving and rshare), "Reviving you" on the friend bringing you back.
--   Hover one for their damage this run (AZS_GetPartyMeter); click to
--   target. The game's own party frames (the stock 1.12 ones) are put away
--   while these are on. Left of your frame, party1 at the bottom and each
--   next one over it, or each next one under it (the Party tab, "Order":
--   SurvivorUIDB.partyDown), until moved (move mode: "Party frames"): the
--   party takes the room of a full one either way, top to bottom starting
--   where the fourth friend stands bottom to top. Module "Party frames".
-- - Revive bar: while you are down, how far a friend has brought you back
--   and who; while you bring one back, how far. Under the hero until moved
--   (move mode: "Revive bar"). From the game's 0.115 on by default, the
--   game's own (a slim bar and its "you are down" line) put away while it
--   shows (AZS_SetHudShown("revive")), back as the game closes. Before
--   0.115 the game's could not be put away: off then unless chosen
--   (SurvivorUIDB.reviveBar), two bars being too many. Module "Revive bar".
-- - SurvivorUI_PartySnapshot: the party as the run ended, for Run History.
--
-- Out of a party, or with a game before 0.113, nothing shows. Being placed
-- (move mode, Alt, the Party tab), each shows a sample.
--
-- In the game's 0.113, UnitIsDead throws for a party unit: every unit call
-- here that is not the stock 1.12 set (name, class, health) goes through
-- pcall.

if SurvivorUI_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local Feature = SurvivorUI_Feature or function() return true end

local ICON = 24                  -- the class's icon: a square as high as the row
local BAR_WIDTH = 140
local ROW_HEIGHT = 24
local ROW_GAP = 5
local MOST = 4                   -- party1 to party4: five heroes at most
local ROW_WIDTH = ICON + 1 + BAR_WIDTH
local REVIVE_WIDTH, REVIVE_HEIGHT = 240, 16
local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"

local DOWN_FILL = { 0.30, 0.07, 0.07 }
local DOWN_TEXT = { 1.00, 0.36, 0.30 }
local GOLD = { 1.00, 0.82, 0.00 }
local REVIVE_FILL = { 1.00, 0.76, 0.18 }
local RESCUE_FILL = { 0.36, 0.90, 0.42 }

local function Num(value)
	return tonumber(value) or 0
end

local function Short(value)
	return SurvivorUI_Abbrev and SurvivorUI_Abbrev(value) or tostring(math.floor(Num(value) + 0.5))
end

local function Percent(share)
	return math.floor(Num(share) * 100 + 0.5).."%"
end

-- A field of AZS_REVIVE or of a party line that may be empty ("" for nobody).
local function Named(value)
	if value ~= nil and value ~= "" and value ~= 0 then
		return tostring(value)
	end
end

-- A unit call that may throw in this engine: its answer, or nil.
local function Safe(call, unit)
	if not call then
		return nil
	end
	local ok, value = pcall(call, unit)
	if ok then
		return value
	end
end

local function ClassColor(class)
	if SurvivorUI_ClassColor then
		return SurvivorUI_ClassColor(class)
	end
	return 0.6, 0.6, 0.6
end

-- The game's party lines ({ name, class, dmg, dps, share, top, topdps }), and
-- the last ones it sent this run, should they be gone as it ends.
local lastLines, lastLinesAt

local function PartyLines()
	if AZS_PARTY and table.getn(AZS_PARTY) > 0 then
		return AZS_PARTY
	end
	if lastLines and lastLinesAt and GetTime() - lastLinesAt < 60 then
		return lastLines
	end
	return nil
end

local function LineOf(name)
	local lines = PartyLines()
	if not (lines and name) then
		return nil
	end
	for index = 1, table.getn(lines) do
		if lines[index].name == name then
			return lines[index]
		end
	end
end

local function Revive()
	return (AZS_GetRevive and AZS_GetRevive()) or {}
end

local function Members()
	local count = Safe(GetNumPartyMembers) or 0
	return math.min(MOST, Num(count))
end

local function Text(parent, size, point, x, y)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, parent, point, x, y)
	return text
end

-- The player frame's look: a black line round it, a dark backing.
local function Border(frame)
	local border = frame:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(FLAT)
	border:SetVertexColor(0, 0, 0, 1)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	local backing = frame:CreateTexture(nil, "BORDER")
	backing:SetTexture(FLAT)
	backing:SetVertexColor(0.09, 0.09, 0.11, 1)
	backing:SetAllPoints(frame)
end

local function FlatBar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(FLAT)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- The class's icon (the character creation's), cut inside its round edge.
local function SetClassIcon(texture, class)
	local art, coords = nil, nil
	if SurvivorUI_ClassIcon then
		art, coords = SurvivorUI_ClassIcon(class)
	end
	if coords then
		local cutX, cutY = (coords[2] - coords[1]) * 0.1, (coords[4] - coords[3]) * 0.1
		texture:SetTexture(art)
		texture:SetTexCoord(coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY)
	else
		texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
end

------------------------------------------------------------------------------
-- The party frames.

local holder = CreateFrame("Frame", "SurvivorUIParty", UIParent)
holder:SetWidth(ROW_WIDTH)
holder:SetHeight(ROW_HEIGHT)
holder:SetMovable(true)
holder:SetClampedToScreen(true)
holder:Hide()

local rows = {}

-- A friend's card: the class, the health, the damage this run.
local function Tip(row)
	local unit = row.unit
	local name, class, race = row.sample and row.sample.name, row.sample and row.sample.class, nil
	if not row.sample then
		if not UnitExists(unit) then
			return
		end
		name, race = UnitName(unit), UnitRace(unit)
		local _, token = UnitClass(unit)
		class = token
	end
	local r, g, b = ClassColor(class)
	GameTooltip:SetOwner(row, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 6)
	GameTooltip:SetText(name or "?", r, g, b)
	local kind = (race and (race.." ") or "")..(row.className or "")
	if kind ~= "" then
		GameTooltip:AddLine(kind, 0.8, 0.8, 0.8)
	end
	if not row.sample then
		GameTooltip:AddDoubleLine(SurvivorUI_T("Health"), Short(UnitHealth(unit)).." / "..Short(UnitHealthMax(unit)), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	local line = row.sample or LineOf(name)
	if line and line.dmg then
		GameTooltip:AddDoubleLine(SurvivorUI_T("Damage this run"), Short(line.dmg).."  ("..Percent(line.share)..")", 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine(SurvivorUI_T("Damage per second"), Short(line.dps), 0.8, 0.8, 0.8, 1, 1, 1)
		if Named(line.top) then
			GameTooltip:AddDoubleLine(SurvivorUI_T("Top spell"), SurvivorUI_TF("{1}  ({2} dps)", SurvivorUI_Native(line.top), Short(line.topdps)), 0.8, 0.8, 0.8, 1, 0.82, 0)
		end
	end
	if row.sample then
		GameTooltip:AddLine(SurvivorUI_T("A sample: your friends show here in a party."), 0.6, 0.6, 0.65, 1)
	else
		GameTooltip:AddLine(SurvivorUI_T("Click to target."), 0.6, 0.6, 0.65)
	end
	GameTooltip:Show()
end

local function Row(index)
	if rows[index] then
		return rows[index]
	end
	local row = CreateFrame("Button", nil, holder)
	row:SetWidth(ROW_WIDTH)
	row:SetHeight(ROW_HEIGHT)
	row.index = index
	row.unit = "party"..index

	row.icon = CreateFrame("Frame", nil, row)
	row.icon:SetWidth(ICON)
	row.icon:SetHeight(ICON)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	Border(row.icon)
	row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
	row.icon.texture:SetAllPoints(row.icon)
	-- The party's leader (the co-op host): the stock crown at the icon's corner.
	row.leader = row.icon:CreateTexture(nil, "OVERLAY")
	row.leader:SetTexture(LEADER_ICON)
	row.leader:SetWidth(13)
	row.leader:SetHeight(13)
	row.leader:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -5, 6)
	row.leader:Hide()

	row.health = FlatBar(row, BAR_WIDTH, ROW_HEIGHT)
	row.health:SetPoint("LEFT", row.icon, "RIGHT", 1, 0)
	Border(row.health)
	-- How far you have brought the friend back, over the health.
	row.revive = FlatBar(row.health, BAR_WIDTH, ROW_HEIGHT)
	row.revive:SetAllPoints(row.health)
	row.revive:SetFrameLevel(row.health:GetFrameLevel() + 1)
	row.revive:SetStatusBarColor(REVIVE_FILL[1], REVIVE_FILL[2], REVIVE_FILL[3], 0.85)
	row.revive:Hide()
	row.texts = CreateFrame("Frame", nil, row.health)
	row.texts:SetAllPoints(row.health)
	row.texts:SetFrameLevel(row.health:GetFrameLevel() + 2)
	row.name = Text(row.texts, 10, "LEFT", 5, 0)
	row.name:SetHeight(12)
	row.name:SetJustifyH("LEFT")
	row.value = Text(row.texts, 10, "RIGHT", -5, 0)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function()
		if not this.sample and UnitExists(this.unit) then
			TargetUnit(this.unit)
		end
	end)
	row:SetScript("OnEnter", function() Tip(this) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[index] = row
	return row
end

-- Top to bottom (the Party tab's Order), or bottom to top.
local function Down()
	return SurvivorUIDB and SurvivorUIDB.partyDown == true
end

-- The first friend by your frame, each next one over it (or under it, top to
-- bottom), so a friend joining never moves the others.
local function PlaceRow(row, down)
	if row.down == down then
		return
	end
	row.down = down
	local step = (row.index - 1) * (ROW_HEIGHT + ROW_GAP)
	row:ClearAllPoints()
	if down then
		row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -step)
	else
		row:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, step)
	end
end

-- The name in the room the value leaves; too long, by its first word.
local function SetName(row, name, room)
	if row.shownName == name and row.nameRoom == room then
		return
	end
	row.shownName, row.nameRoom = name, room
	row.name:SetWidth(0)
	row.name:SetText(name)
	if row.name:GetStringWidth() > room then
		local _, _, first = string.find(name, "^(%S+)")
		row.name:SetText(first or name)
	end
	row.name:SetWidth(room)
end

-- One friend's row: { name, class, className, health, most, down, offline,
-- leader, rescue (0 to 1 while you bring them back), saving (bringing you
-- back) }.
local function Paint(row, friend)
	row.className = friend.className
	if row.classShown ~= friend.class then
		row.classShown = friend.class
		SetClassIcon(row.icon.texture, friend.class)
	end
	local r, g, b = ClassColor(friend.class)
	local share = friend.most > 0 and friend.health / friend.most or 0
	local value, color = Percent(share), { 1, 1, 1 }
	if friend.offline then
		row.health:SetValue(1)
		row.health:SetStatusBarColor(0.25, 0.25, 0.28, 1)
		value, color = "Offline", { 0.6, 0.6, 0.65 }
	elseif friend.down then
		row.health:SetValue(1)
		row.health:SetStatusBarColor(DOWN_FILL[1], DOWN_FILL[2], DOWN_FILL[3], 1)
		value, color = "DOWN", DOWN_TEXT
	else
		row.health:SetValue(share)
		row.health:SetStatusBarColor(r, g, b, 1)
	end
	if friend.down and friend.rescue then
		row.revive:SetValue(friend.rescue)
		row.revive:Show()
		value, color = "Reviving "..Percent(friend.rescue), { 1, 1, 1 }
	else
		row.revive:Hide()
	end
	if friend.saving then
		value, color = "Reviving you", GOLD
	end
	row.value:SetText(value)
	row.value:SetTextColor(color[1], color[2], color[3])
	SetName(row, friend.name or "?", BAR_WIDTH - 14 - row.value:GetStringWidth())
	-- Down: the name in red, but white over the gold while brought back.
	if friend.down then
		if friend.rescue then
			row.name:SetTextColor(1, 1, 1)
		else
			row.name:SetTextColor(DOWN_TEXT[1], DOWN_TEXT[2], DOWN_TEXT[3])
		end
		row.icon.texture:SetVertexColor(0.55, 0.4, 0.4)
	else
		row.name:SetTextColor(1, 1, 1)
		row.icon.texture:SetVertexColor(1, 1, 1)
	end
	if friend.leader then
		row.leader:Show()
	else
		row.leader:Hide()
	end
	row:Show()
end

local function Friend(index, revive)
	local unit = "party"..index
	if not UnitExists(unit) then
		return nil
	end
	local name = UnitName(unit)
	local className, class = UnitClass(unit)
	local friend = {
		name = name, class = class, className = className,
		health = Num(UnitHealth(unit)), most = Num(UnitHealthMax(unit)),
		leader = Safe(UnitIsPartyLeader, unit) and true or false,
	}
	local ok, connected = pcall(UnitIsConnected, unit)
	friend.offline = ok and not connected
	local rescuing = Named(revive.reviving)
	-- Down: no health left (its most known), dead to the client, or the one
	-- you stand over bringing back.
	friend.down = (friend.most > 0 and friend.health <= 0) or (Safe(UnitIsDead, unit) and true)
		or (rescuing ~= nil and rescuing == name)
	if rescuing and rescuing == name then
		friend.rescue = math.max(0, math.min(1, Num(revive.rshare)))
	end
	local by = Named(revive.by)
	friend.saving = by ~= nil and by == name and Num(revive.down) == 1
	return friend
end

-- Being placed with no party: three friends as samples, one down and being
-- brought back.
local SAMPLES = {
	{ name = "Friend", class = "WARRIOR", className = "Warrior", health = 820, most = 1000, leader = true,
		dmg = 182000, dps = 640, share = 0.36, top = "Whirlwind", topdps = 310 },
	{ name = "Another", class = "MAGE", className = "Mage", health = 0, most = 700, down = true, rescue = 0.45,
		dmg = 151000, dps = 530, share = 0.30, top = "Frostbolt", topdps = 280 },
	{ name = "Healer", class = "PRIEST", className = "Priest", health = 350, most = 760,
		dmg = 64000, dps = 225, share = 0.13, top = "Holy Fire", topdps = 120 },
}

local function Placing(name)
	return SurvivorUI_Placing and SurvivorUI_Placing(name)
end

-- The revive bar: as chosen (the Party tab, Modules), else on where the game
-- lets its own be put away (0.115 on), off before.
local function GameCanHide()
	return AZS_HUD_CVARS ~= nil and AZS_HUD_CVARS.revive ~= nil and AZS_SetHudShown ~= nil
end

local function ReviveOn()
	if not SurvivorUIDB then
		return false
	end
	if SurvivorUIDB.reviveBar ~= nil then
		return SurvivorUIDB.reviveBar == true
	end
	return GameCanHide()
end

function SurvivorUI_ReviveOn()
	return ReviveOn()
end

-- The game's own revive bar: away while ours shows (or the options' "The
-- game's" is unticked), back otherwise; the mark says the addon put it away.
local function ApplyGameHud()
	if not (GameCanHide() and AZS_IsHudShown and SurvivorUIDB) then
		return
	end
	local settings = SurvivorUIDB
	if ReviveOn() or settings.noGameRevive then
		if AZS_IsHudShown("revive") then
			AZS_SetHudShown("revive", false)
			settings.hidGameRevive = true
		end
	elseif settings.hidGameRevive then
		AZS_SetHudShown("revive", true)
		settings.hidGameRevive = nil
	end
end
SurvivorUI_GameHud = SurvivorUI_GameHud or {}
SurvivorUI_GameHud.revive = ApplyGameHud

function SurvivorUI_ToggleRevive()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.reviveBar = not ReviveOn()
	ApplyGameHud()
end

local PlaceFrames                -- the holder's place, set below

local function DrawFrames(revive)
	local count = Members()
	local samples = count == 0 and Placing("Party frames")
	local shown = 0
	local down = Down()
	if holder.down ~= down then
		holder.down = down
		PlaceFrames()
	end
	if samples then
		for index = 1, table.getn(SAMPLES) do
			local row = Row(index)
			row.sample = SAMPLES[index]
			PlaceRow(row, down)
			Paint(row, SAMPLES[index])
			shown = index
		end
	else
		for index = 1, count do
			local friend = Friend(index, revive)
			if friend then
				shown = shown + 1
				local row = Row(shown)
				row.sample = nil
				row.unit = "party"..index
				PlaceRow(row, down)
				Paint(row, friend)
			end
		end
	end
	for index = shown + 1, table.getn(rows) do
		rows[index]:Hide()
	end
	if shown > 0 then
		holder:SetHeight(shown * (ROW_HEIGHT + ROW_GAP) - ROW_GAP)
		holder:Show()
	else
		holder:SetHeight(ROW_HEIGHT)
		holder:Hide()
	end
end

-- The room a full party takes: four friends, one over the other.
local FULL = MOST * ROW_HEIGHT + (MOST - 1) * ROW_GAP

-- Left of your frame, the party's room level with the frame's bottom, until
-- moved: bottom to top, held by its bottom, it grows upward as friends join;
-- top to bottom, held by the room's top (where the fourth friend stands bottom
-- to top), it grows downward. The place kept is the room's bottom left
-- (partyLeft, partyBottom), so the order changes nothing else.
PlaceFrames = function()
	holder:ClearAllPoints()
	local db = SurvivorUIDB
	local down = Down()
	if db and db.partyLeft and db.partyBottom then
		if down then
			holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.partyLeft, db.partyBottom + FULL)
		else
			holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.partyLeft, db.partyBottom)
		end
		return
	end
	local player = getglobal("SurvivorUIPlayer")
	if player and player:IsVisible() then
		if down then
			holder:SetPoint("TOPRIGHT", player, "BOTTOMLEFT", -14, FULL)
		else
			holder:SetPoint("BOTTOMRIGHT", player, "BOTTOMLEFT", -14, 0)
		end
	elseif down then
		holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 12, 260 + FULL)
	else
		holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 260)
	end
end

-- For the sizes (Mover.lua) and the Party tab's Order.
function SurvivorUI_PlacePartyFrames()
	PlaceFrames()
end

local function SaveFrames()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.partyLeft = math.floor(holder:GetLeft() + 0.5)
	if Down() then
		SurvivorUIDB.partyBottom = math.floor(holder:GetTop() - FULL + 0.5)
	else
		SurvivorUIDB.partyBottom = math.floor(holder:GetBottom() + 0.5)
	end
	PlaceFrames()
end

-- The game's party frames, away while these are on: under a hidden parent,
-- so the stock code showing them changes nothing; back under UIParent when
-- these go off.
local stockAway = CreateFrame("Frame")
stockAway:Hide()
local stockHidden

local function StockFrames(away)
	if stockHidden == away then
		-- Shown again some other way (an engine without SetParent): hidden.
		if away then
			for index = 1, MOST do
				local frame = getglobal("PartyMemberFrame"..index)
				if frame and frame:IsVisible() then
					frame:Hide()
				end
			end
		end
		return
	end
	stockHidden = away
	for index = 1, MOST do
		local frame = getglobal("PartyMemberFrame"..index)
		if frame and frame.SetParent then
			if away then
				frame:SetParent(stockAway)
			else
				frame:SetParent(UIParent)
				if UnitExists("party"..index) then
					frame:Show()
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- The revive bar.

local bar = CreateFrame("Frame", "SurvivorUIRevive", UIParent)
bar:SetWidth(REVIVE_WIDTH)
bar:SetHeight(REVIVE_HEIGHT)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:Hide()
bar.fill = FlatBar(bar, REVIVE_WIDTH, REVIVE_HEIGHT)
bar.fill:SetAllPoints(bar)
Border(bar.fill)
bar.texts = CreateFrame("Frame", nil, bar.fill)
bar.texts:SetAllPoints(bar.fill)
bar.texts:SetFrameLevel(bar.fill:GetFrameLevel() + 2)
bar.text = Text(bar.texts, 9, "CENTER", 0, 0)
bar.text:SetTextColor(1, 1, 1)
bar.title = bar:CreateFontString(nil, "OVERLAY")
bar.title:SetFont(SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
bar.title:SetPoint("BOTTOM", bar, "TOP", 0, 4)

local function DrawBar(revive)
	local down = Num(revive.down) == 1
	local rescuing = Named(revive.reviving)
	local share, title, text, fill, titleColor
	if not (down or rescuing) and Placing("Revive bar") then
		down, revive = true, { by = "Friend", share = 0.6 }
	end
	if down then
		share = Num(revive.share)
		local by = Named(revive.by)
		title, titleColor, fill = SurvivorUI_T("YOU ARE DOWN"), DOWN_TEXT, REVIVE_FILL
		if by then
			text = SurvivorUI_TF("{1} is bringing you back  {2}", by, Percent(share))
		elseif share > 0 then
			text = SurvivorUI_TF("Being brought back  {1}", Percent(share))
		else
			text = SurvivorUI_T("A friend must stand next to you")
		end
	elseif rescuing then
		share = Num(revive.rshare)
		title, titleColor, fill = SurvivorUI_TF("BRINGING {1} BACK", string.upper(rescuing)), RESCUE_FILL, RESCUE_FILL
		text = Percent(share)
	else
		bar:Hide()
		return
	end
	bar.title:SetText(title)
	bar.title:SetTextColor(titleColor[1], titleColor[2], titleColor[3])
	bar.fill:SetValue(math.max(0, math.min(1, share)))
	bar.fill:SetStatusBarColor(fill[1], fill[2], fill[3], 0.9)
	bar.text:SetText(text)
	bar:Show()
end

-- Under the hero, who stands mid-screen, until moved: just over the game's
-- own revive bar (a slim one, shown only while someone is brought back, that
-- cannot be put away: its 0.113). Over the hero, the game's banners ("Hogger
-- approaches!") covered it.
local function PlaceBar()
	bar:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.reviveX and db.reviveTop then
		bar:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.reviveX, db.reviveTop)
	else
		bar:SetPoint("TOP", UIParent, "CENTER", 0, -62)
	end
end

local function SaveBar()
	SurvivorUIDB = SurvivorUIDB or {}
	local left, right = bar:GetLeft(), bar:GetRight()
	SurvivorUIDB.reviveX = math.floor((left + right) / 2 + 0.5)
	SurvivorUIDB.reviveTop = math.floor(bar:GetTop() + 0.5)
	PlaceBar()
end

------------------------------------------------------------------------------
-- For the other pieces: you are down (a co-op run's: not the run's end), and
-- you are in a party. While a hero of a party is down, the game's phase says
-- dead and its end message (AZS_END, result defeat) comes every 0.2 s (0.113,
-- seen 2026-10-23), the run going on: Run History holds it (RunHistory.lua).

function SurvivorUI_IsDown()
	return Num(Revive().down) == 1
end

function SurvivorUI_InParty()
	return Members() > 0 or (AZS_PARTY ~= nil and table.getn(AZS_PARTY) > 0) or SurvivorUI_IsDown()
end

------------------------------------------------------------------------------
-- The party for Run History: each hero's line as the game's party meter last
-- had it this run, the friends with no line yet by their units; nil out of a
-- party.

function SurvivorUI_PartySnapshot()
	local me = UnitName("player")
	local out, seen = {}, {}
	local lines = PartyLines() or {}
	for index = 1, table.getn(lines) do
		local line = lines[index]
		if line.name and not seen[line.name] then
			seen[line.name] = true
			table.insert(out, {
				name = line.name, class = string.upper(tostring(line.class or "")),
				dmg = Num(line.dmg), dps = Num(line.dps), share = Num(line.share),
				top = Named(line.top), topdps = Num(line.topdps), me = (line.name == me) or nil,
			})
		end
	end
	for index = 1, MOST do
		local unit = "party"..index
		if UnitExists(unit) then
			local name = UnitName(unit)
			if name and not seen[name] then
				seen[name] = true
				local _, class = UnitClass(unit)
				table.insert(out, { name = name, class = class })
			end
		end
	end
	if not seen[me] and table.getn(out) > 0 then
		local _, class = UnitClass("player")
		table.insert(out, { name = me, class = class, me = true })
	end
	if table.getn(out) < 2 then
		return nil
	end
	return out
end

------------------------------------------------------------------------------
-- Ten times a second: the frames, the bar, the game's frames away.

local elapsed = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	if AZS_PARTY and table.getn(AZS_PARTY) > 0 then
		lastLines, lastLinesAt = AZS_PARTY, GetTime()
	end
	local revive = Revive()
	local framesOn = Feature("partyFrames")
	StockFrames(framesOn)
	if framesOn then
		DrawFrames(revive)
	elseif holder:IsShown() then
		holder:Hide()
	end
	if ReviveOn() then
		DrawBar(revive)
	elseif bar:IsShown() then
		bar:Hide()
	end
	-- Off, nothing to move: its handle away in move mode.
	if bar.handle then
		bar.handle.disabled = not ReviveOn() or nil
	end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	PlaceFrames()
	PlaceBar()
	ApplyGameHud()
end)

if SurvivorUI_RegisterMover then
	SurvivorUI_RegisterMover(holder, "Party frames", SaveFrames, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.partyLeft, SurvivorUIDB.partyBottom = nil, nil
		end
		PlaceFrames()
	end)
	bar.handle = SurvivorUI_RegisterMover(bar, "Revive bar", SaveBar, nil, function()
		if SurvivorUIDB then
			SurvivorUIDB.reviveX, SurvivorUIDB.reviveTop = nil, nil
		end
		PlaceBar()
	end)
end
