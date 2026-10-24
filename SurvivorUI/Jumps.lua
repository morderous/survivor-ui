-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: jumps, a fun stat (asked for on Discord by Skum, 2026-10-24).
--
-- The jump key calls the game's Jump() (its binding JUMP, read 2026-10-24):
-- it is wrapped here to count. A press while the hero is still in the air
-- calls it as well, so a jump counts only GAP seconds after the last (five
-- quick presses made five calls and one jump). Only in a run, while it plays,
-- and not while down in a co-op party.
--
-- Kept for the account (SurvivorUIDB.jumps): this run's, the most in one run
-- (the record) and all of them. This Run shows the run's in a row of its own
-- (RunPanel.lua), Run History keeps each run's.
--
-- Beating the record (one of RECORD_FROM jumps or more), once a run: NEW JUMP
-- RECORD over an effect of its own (Effects.lua, the Records tab; fire unless
-- chosen), under the new best crit (SurvivorUIRecord) or where it was moved
-- to (move mode: "New jump record"). The number climbs on while it shows.
--
-- A gamepad's jump may go another way than Jump(): not counted then.

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local GAP = 0.7                 -- seconds between two counted jumps
local RECORD_FROM = 10          -- a record under this is beaten quietly
local HOLD, FADE = 3.2, 0.7     -- the notice: seconds it holds (unless set), seconds it fades
local POP, POP_SIZE, SIZE = 0.14, 44, 32
-- A winged foot: the game's Sprint icon, for a jump.
local ICON = "Interface\\Icons\\Ability_Rogue_Sprint"
local NUMBER_Y = -6             -- the number's middle, from the notice's

local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	local jumps = SurvivorUIDB.jumps
	if type(jumps) ~= "table" then
		jumps = { run = 0, best = 0, total = 0 }
		SurvivorUIDB.jumps = jumps
	end
	return jumps
end

local function NoticeOn()
	return not SurvivorUIDB or SurvivorUIDB.jumpRecord ~= false
end

-- The Records tab's: how long it holds, its size, its icon.
local function Hold()
	return tonumber(SurvivorUIDB and SurvivorUIDB.jumpRecordHold) or HOLD
end

local function Scale()
	return tonumber(SurvivorUIDB and SurvivorUIDB.jumpRecordSize) or 1
end

local function IconOn()
	return not SurvivorUIDB or SurvivorUIDB.jumpRecordIcon ~= false
end

-- For This Run and Run History: this run's jumps, the record, all of them.
function SurvivorUI_RunJumps()
	local jumps = DB()
	return jumps.run or 0, jumps.best or 0, jumps.total or 0
end

------------------------------------------------------------------------------
-- The notice.

local notice = CreateFrame("Frame", "SurvivorUIJumpRecord", UIParent)
notice:SetFrameStrata("HIGH")
notice:SetWidth(200)
notice:SetHeight(70)
notice:SetMovable(true)
notice:Hide()

-- Under the new best crit, where it stands or was moved to; else where it
-- was moved to itself.
local function Place()
	notice:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.jumpRecordX and db.jumpRecordTop then
		notice:SetPoint("TOP", UIParent, "BOTTOMLEFT", db.jumpRecordX, db.jumpRecordTop)
		return
	end
	local crit = getglobal("SurvivorUIRecord")
	if crit then
		notice:SetPoint("TOP", crit, "BOTTOM", 0, -2)
	else
		notice:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 223, -340)
	end
end

local function SavePlace()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.jumpRecordX = math.floor((notice:GetLeft() + notice:GetRight()) / 2 + 0.5)
	SurvivorUIDB.jumpRecordTop = math.floor(notice:GetTop() + 0.5)
	Place()
end

-- The number and its label, a level over the effect's back (Effects.lua: its
-- particles go over all).
local text = CreateFrame("Frame", nil, notice)
text:SetAllPoints(notice)
text:SetFrameLevel(notice:GetFrameLevel() + 2)
notice.number = text:CreateFontString(nil, "OVERLAY")
notice.number:SetPoint("CENTER", notice, "CENTER", 0, NUMBER_Y)
notice.label = text:CreateFontString(nil, "OVERLAY")
notice.label:SetPoint("BOTTOM", notice.number, "TOP", 0, 2)
notice.label:SetTextColor(1, 0.9, 0.7)
notice.icon = text:CreateTexture(nil, "OVERLAY")
notice.icon:SetTexture(ICON)
notice.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
notice.icon:SetPoint("RIGHT", notice.number, "LEFT", -4, 0)
notice.icon:Hide()

local function SetNumber(count)
	notice.number:SetText(count)
end

local function Show(count)
	Place()
	local scale = Scale()
	notice.scale, notice.hold = scale, Hold()
	notice:SetWidth(200 * scale)
	notice:SetHeight(70 * scale)
	notice.age = 0
	notice.popped = nil
	notice.number:SetFont(SurvivorUI_FONT, POP_SIZE * scale + FONT_BUMP, "THICKOUTLINE")
	notice.number:SetTextColor(1, 0.75, 0.2)
	notice.label:SetFont(SurvivorUI_FONT, 10 * math.max(0.8, scale) + FONT_BUMP, "OUTLINE")
	notice.label:SetText("NEW JUMP RECORD")
	SetNumber(count)
	if IconOn() then
		notice.icon:SetWidth(26 * scale)
		notice.icon:SetHeight(26 * scale)
		notice.icon:Show()
	else
		notice.icon:Hide()
	end
	if SurvivorUI_RecordFxStart then
		SurvivorUI_RecordFxStart(notice, SurvivorUI_RecordFxKind("jump"), scale, NUMBER_Y, notice.hold + FADE)
	end
	notice:SetAlpha(1)
	notice:Show()
end

-- For the options and /sui record: the notice at once, with the record.
function SurvivorUI_ShowJumpRecord()
	local _, best = SurvivorUI_RunJumps()
	Show(math.max(best, RECORD_FROM) + 1)
end

notice:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	local age = this.age
	local hold = this.hold or HOLD
	if age >= hold + FADE then
		this:Hide()
		if SurvivorUI_RecordFxStop then
			SurvivorUI_RecordFxStop(this)
		end
		return
	end
	if not this.popped and age >= POP then
		this.popped = true
		this.number:SetFont(SurvivorUI_FONT, SIZE * (this.scale or 1) + FONT_BUMP, "THICKOUTLINE")
	end
	if SurvivorUI_RecordFxUpdate then
		SurvivorUI_RecordFxUpdate(this, age, arg1, age < hold)
	end
	this:SetAlpha(age > hold and (1 - (age - hold) / FADE) or math.min(1, age / 0.06))
end)

------------------------------------------------------------------------------
-- The count.

local lastAt                    -- GetTime() of the last jump counted

local function Playing()
	if not (AZS_GetPhase and AZS_GetPhase() == "playing") then
		return false
	end
	return not (SurvivorUI_IsDown and SurvivorUI_IsDown())
end

local function Count()
	if not SurvivorUIDB or not Playing() then
		return
	end
	local now = GetTime()
	if lastAt and now - lastAt < GAP then
		return
	end
	lastAt = now
	local jumps = DB()
	jumps.run = (jumps.run or 0) + 1
	jumps.total = (jumps.total or 0) + 1
	if jumps.run > (jumps.best or 0) then
		if not jumps.announced and (jumps.best or 0) >= RECORD_FROM and NoticeOn() then
			jumps.announced = true
			Show(jumps.run)
		elseif notice:IsShown() then
			SetNumber(jumps.run)
		end
		jumps.best = jumps.run
	end
end

-- The game's Jump is protected (its protected.rs, as 1.12): called from an
-- addon's function, the game blocks it and the hero does not jump ("blocked
-- from an action only available to the Blizzard UI", 2026-10-24, with Jump
-- wrapped). So it is not wrapped: it leaves the globals, and the key's
-- binding, looking it up, finds it through the globals' __index, which
-- counts and hands back the game's own Jump, called by the binding itself.
local stockJump = Jump
if stockJump then
	local globals = getfenv(0)
	local meta = getmetatable(globals) or {}
	local before = meta.__index
	rawset(globals, "Jump", nil)
	meta.__index = function(table, key)
		if key == "Jump" then
			Count()
			return stockJump
		end
		if type(before) == "function" then
			return before(table, key)
		elseif before then
			return before[key]
		end
	end
	setmetatable(globals, meta)
end

-- A new run starts the count over: the game back at its start ("ready"), or
-- its clock gone back.
local lastTime
local wait = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.5 then
		return
	end
	wait = 0
	if not (SurvivorUIDB and AZS_GetPhase) then
		return
	end
	local phase = AZS_GetPhase()
	local time = AZS_GetRunTime and AZS_GetRunTime()
	if phase == "ready" or (time and lastTime and time + 3 < lastTime) then
		local jumps = DB()
		if (jumps.run or 0) > 0 or jumps.announced then
			jumps.run, jumps.announced = 0, nil
		end
	end
	lastTime = time
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	Place()
	if not this.registered and SurvivorUI_RegisterMover then
		this.registered = true
		SurvivorUI_RegisterMover(notice, "New jump record", SavePlace, nil, function()
			if SurvivorUIDB then
				SurvivorUIDB.jumpRecordX, SurvivorUIDB.jumpRecordTop = nil, nil
			end
			Place()
		end)
	end
end)
