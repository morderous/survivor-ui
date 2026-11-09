-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the chat filtered, the alerts kept (the options, Chat).
--
-- What a run fills the chat with, read off a run's chat: six lines in ten are
-- level-ups, and most of the rest repeats what the game already shows in the
-- middle of the screen. Each kind can be kept away, by the game's own event,
-- so in every language the game speaks:
--   Levels   "Congratulations, you have reached level 12!" and the "You have
--            gained +3% damage..." line that comes with each level (the XP
--            bar and the run tracker show the level);
--   Banners  the horde's moves, an elite or a guardian coming, the run's
--            title: the game's banners show them mid-screen;
--   BossBanners  a boss coming or slain (jiminee, 2026-11-05): off, the
--            game's own banner for it is written in the chat. The chat has
--            no line for a boss slain, and a new boss's coming line comes
--            before the game tells it is a boss (seen 2026-11-08): so from
--            the game's banners (AZS_RegisterBannerHandler), by their kind;
--            their "boss" says true for a guardian too;
--   Yells    the bosses' lines;
--   Combat   the Combat Log window, fed thirteen lines a second whether it is
--            ever opened or not. SurvivorUI reads the fight from the game's
--            events, never from that window.
-- The loot lines are kept away by the loot list (LootLog.lua), once it has
-- read them. What stays: a new spell, an upgrade's news, the run's end.

if SurvivorUI_Standby then return end

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

-- Each kind kept away unless switched off (chatFilterLevels and so on).
function SurvivorUI_ChatFilter(kind)
	return Settings()["chatFilter"..kind] ~= false
end

local lastLevelUp = 0

-- The level's gains in English, the game's line in any language read back
-- into it (Locale.lua). The game's 0.139 sends it with no PLAYER_LEVEL_UP
-- before it (seen 2026-11-02: eight levels, eight lines, no event).
local GAINS = "^You have gained .-%% damage, .- maximum health and .- health per second%.$"

local function Gains(text)
	if not text or not string.find(text, "%d") then
		return false
	end
	-- Its numbers come signed ("+3"), and the translation tables' numbers take
	-- no sign: read without them.
	local plain = string.gsub(text, "%+", "")
	local english = SurvivorUI_EnglishLine and SurvivorUI_EnglishLine(plain) or plain
	return string.find(english, GAINS) ~= nil
end

local function Hidden(event, frame)
	if event == "PLAYER_LEVEL_UP" then
		lastLevelUp = GetTime()
		return SurvivorUI_ChatFilter("Levels")
	end
	if event == "CHAT_MSG_SYSTEM" then
		-- The level's gains: "+3% damage, +14 maximum health", by its words, or
		-- right after a level-up.
		return (Gains(arg1) or (GetTime() - lastLevelUp < 1 and arg1 ~= nil and string.find(arg1, "%+%d") ~= nil))
			and SurvivorUI_ChatFilter("Levels")
	end
	if event == "CHAT_MSG_RAID_BOSS_EMOTE" then
		return SurvivorUI_ChatFilter("Banners")
	end
	if event == "CHAT_MSG_MONSTER_YELL" then
		return SurvivorUI_ChatFilter("Yells")
	end
	if frame == ChatFrame2 and (string.find(event, "^CHAT_MSG_COMBAT_") or string.find(event, "^CHAT_MSG_SPELL_")) then
		return SurvivorUI_ChatFilter("Combat")
	end
	return false
end

-- A boss's banner in the chat, in the color of the game's banner lines. Its
-- coming only while the game's own line for it is kept out (Banners), so it
-- is not there twice.
local BOSS_KINDS = { boss = "coming", finalboss = "coming", bossdown = "slain" }

local function OnBanner(banner)
	local kind = banner and BOSS_KINDS[banner.kind]
	if not kind or not banner.text or banner.text == "" or SurvivorUI_ChatFilter("BossBanners") then
		return
	end
	if kind == "coming" and not SurvivorUI_ChatFilter("Banners") then
		return
	end
	local color = ChatTypeInfo and ChatTypeInfo["RAID_BOSS_EMOTE"] or { r = 1, g = 0.87, b = 0 }
	DEFAULT_CHAT_FRAME:AddMessage(banner.text, color.r, color.g, color.b)
end

local bannerHook = CreateFrame("Frame")
bannerHook:RegisterEvent("PLAYER_ENTERING_WORLD")
bannerHook:SetScript("OnEvent", function()
	if not bannerHook.done and AZS_RegisterBannerHandler then
		bannerHook.done = true
		AZS_RegisterBannerHandler(OnBanner)
	end
end)

-- Each chat window shows a line through the stock handler: a line kept away
-- never reaches it, so it costs nothing more.
if ChatFrame_OnEvent then
	local stockOnEvent = ChatFrame_OnEvent
	ChatFrame_OnEvent = function(event)
		if Hidden(event, this) then
			return
		end
		return stockOnEvent(event)
	end
end
