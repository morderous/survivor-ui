-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the chat filtered, the alerts kept (the options, Chat).
--
-- What a run fills the chat with, read off a run's chat: six lines in ten are
-- level-ups, and most of the rest repeats what the game already shows in the
-- middle of the screen. Each kind can be kept away, by the game's own event,
-- so in every language the game speaks:
--   Levels   "Congratulations, you have reached level 12!" and the "You have
--            gained +3% damage..." line right after it (the XP bar and the
--            run tracker show the level);
--   Banners  the horde's moves, a boss or a guardian coming or slain, the
--            run's title: the game's banners show them mid-screen;
--   Yells    the bosses' lines;
--   Combat   the Combat Log window, fed thirteen lines a second whether it is
--            ever opened or not. SurvivorUI reads the fight from the game's
--            events, never from that window.
-- The loot lines are kept away by the loot list (LootLog.lua), once it has
-- read them. What stays: a new spell, an upgrade's news, the run's end.

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

-- Each kind kept away unless switched off (chatFilterLevels and so on).
function SurvivorUI_ChatFilter(kind)
	return Settings()["chatFilter"..kind] ~= false
end

local lastLevelUp = 0

local function Hidden(event, frame)
	if event == "PLAYER_LEVEL_UP" then
		lastLevelUp = GetTime()
		return SurvivorUI_ChatFilter("Levels")
	end
	if event == "CHAT_MSG_SYSTEM" then
		-- The level's gains, right after it: "+3% damage, +14 maximum health".
		return GetTime() - lastLevelUp < 1 and arg1 ~= nil and string.find(arg1, "%+%d") ~= nil
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
