-- SurvivorUI - Custom banners.
--
-- Game banner events (including guardian deaths) come from
-- AZS_RegisterBannerHandler(). Guardian arrivals are detected separately
-- from AZSLAIRS updates: a lair changing from "empty" to "asleep".
--
-- Saved settings:
--   customBanners       true to replace the game's banners
--   bannersHold         seconds to show a banner (2..15, default 6)
--   bannersLayout       "center" or "stack"
--   bannersTextSize     text-size step (-4..8; default 0)
--   bannersUseGlobalFont true to use Global font (default); false for local font
--   bannersFont         selected font path when using a local banner font
--   bannersBoss         false to hide boss banners
--   bannersGuardian     false to hide guardian arrival/death banners
--   bannersAchievement false to hide achievement/unlock banners
--   bannersLoot         false to hide loot/cache/rune banners
--   bannersParty        false to hide party banners

if SurvivorUI_Standby then return end

-- Return the addon's saved settings table, creating it if needed.
local function DB()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

local handlerRegistered = false
-- Cache error text is remembered briefly so only its matching native red
-- error line can be removed after the custom banner has taken responsibility.
local cacheErrorWindow = 2.0
local pendingCacheErrors = {}
local nativeErrorHookInstalled = false
local lairStates = {}
local lairStateReady = false
local frames = {}
local frameSerial = 0
-- Hold native error messages briefly so cache callbacks have time to identify duplicates.
local nativeErrorQueue = {}
local nativeErrorQueueDelay = 0.25

-- Write useful handler-registration errors to the player's chat window.
local function BannerLog(message)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[SurvivorUI Banners]|r " .. tostring(message))
	end
end

-- Remember only cache text that the custom renderer is actually going to show.
-- The short expiry prevents a later, unrelated error with identical wording
-- from being swallowed after the cache interaction has finished.
local function RememberCacheError(message)
	local now = GetTime()
	local entry = pendingCacheErrors[message]
	if not entry or (now - entry.time) > cacheErrorWindow then
		entry = { time = now, count = 0 }
		pendingCacheErrors[message] = entry
	end
	entry.time = now
	entry.count = entry.count + 1
end

-- Consume one matching cache event; all other error text passes through.
local function ConsumeCacheError(message)
	local entry = pendingCacheErrors[message]
	if not entry then return false end

	local now = GetTime()
	if (now - entry.time) > cacheErrorWindow or entry.count < 1 then
		pendingCacheErrors[message] = nil
		return false
	end

	entry.count = entry.count - 1
	if entry.count <= 0 then
		pendingCacheErrors[message] = nil
	end

	return true
end

-- UIErrorsFrame is the separate red-text path seen with cache purchase errors.
-- Wrap its AddMessage method rather than hiding the whole frame, so ordinary
-- combat warnings and unrelated game errors remain visible.
local originalUIErrorsAddMessage = nil

-- Create a lightweight frame that processes delayed native error messages.
local nativeErrorQueueFrame = CreateFrame("Frame")

-- Display queued messages in their original order after the cache callback
-- has had time to identify duplicates.
local function ProcessNativeErrorQueue()
	local now = GetTime()

	-- Process the oldest message first to preserve the game's message order.
	while table.getn(nativeErrorQueue) > 0 do
		local entry = nativeErrorQueue[1]

		-- Stop when the oldest message has not waited long enough yet.
		if now - entry.queuedAt < nativeErrorQueueDelay then
			break
		end

		-- If custom banners were disabled while waiting, restore native behavior.
		if DB().customBanners ~= true then
			originalUIErrorsAddMessage(
				entry.frame,
				entry.message,
				entry.r,
				entry.g,
				entry.b,
				entry.id,
				entry.holdTime
			)
		-- Otherwise suppress only an exact cache message claimed by our banner.
		elseif not (type(entry.message) == "string"
			and ConsumeCacheError(entry.message)) then

			-- Replay unrelated messages with their original arguments.
			originalUIErrorsAddMessage(
				entry.frame,
				entry.message,
				entry.r,
				entry.g,
				entry.b,
				entry.id,
				entry.holdTime
			)
		end

		-- Remove the message after it has been processed.
		table.remove(nativeErrorQueue, 1)
	end

	-- Stop updating when there are no messages left to process.
	if table.getn(nativeErrorQueue) == 0 then
		nativeErrorQueueFrame:SetScript("OnUpdate", nil)
	end
end

-- Install a narrow filter for the native red cache error notifications.
local function InstallNativeErrorFilter()
	if nativeErrorHookInstalled then return true end

	if not UIErrorsFrame or type(UIErrorsFrame.AddMessage) ~= "function" then
		return false
	end

	-- Preserve the original method so unrelated errors can still be displayed.
	originalUIErrorsAddMessage = UIErrorsFrame.AddMessage

	-- Queue native messages briefly instead of displaying them immediately.
	UIErrorsFrame.AddMessage = function(frame, message, r, g, b, id, holdTime)
		-- Leave native behavior unchanged when custom banners are disabled.
		if DB().customBanners ~= true then
			return originalUIErrorsAddMessage(
				frame, message, r, g, b, id, holdTime
			)
		end

		-- Save the complete message so it can be replayed if it is not a cache duplicate.
		table.insert(nativeErrorQueue, {
			frame = frame,
			message = message,
			r = r,
			g = g,
			b = b,
			id = id,
			holdTime = holdTime,
			queuedAt = GetTime()
		})

		-- Start processing while messages are waiting.
		nativeErrorQueueFrame:SetScript("OnUpdate", function()
			ProcessNativeErrorQueue()
		end)
	end

	nativeErrorHookInstalled = true
	return true
end

-- Check whether the custom banner replacement is switched on.
local function Enabled()
	return DB().customBanners == true
end

-- Read and clamp the configured banner display duration.
local function HoldTime()
	local value = tonumber(DB().bannersHold) or 6
	if value < 2 then value = 2 end
	if value > 15 then value = 15 end
	return value
end

-- Check whether the player's settings allow this banner category.
local function Allowed(kind)
	local setting = nil
	if kind == "boss" or kind == "finalboss" or kind == "bossdown" then
		setting = "bannersBoss"
	elseif kind == "guardian" or kind == "guardianArrival" then
		setting = "bannersGuardian"
	elseif kind == "achievement" or kind == "unlocked" then
		setting = "bannersAchievement"
	elseif kind == "magnet" or kind == "cache" or kind == "rune" then
		setting = "bannersLoot"
	elseif kind == "downed" or kind == "frienddown" or kind == "revived" then
		setting = "bannersParty"
	else
		return true
	end
	return DB()[setting] ~= false
end

-- Choose a readable text color for the banner category.
local function BannerColor(kind, bossStyle)
	-- The game marks any banner it considers large/red with banner.boss.
	-- Respect that flag even when the event kind is something like "cache".
	if bossStyle == true or kind == "boss" or kind == "finalboss" or kind == "bossdown" then
		return 1, 0.25, 0.18
	elseif kind == "guardian" or kind == "guardianArrival" then
		return 1, 0.78, 0.22
	elseif kind == "achievement" or kind == "unlocked" then
		return 0.35, 1, 0.55
	end
	return 1, 0.9, 0.55
end

-- Resolve a saved font preference through the addon's language-aware helpers.
-- FontFor handles languages with a dedicated fallback; FontList also catches
-- an older saved choice that is no longer offered in the current language.
function SurvivorUI_BannerFontFor(preferred)
	local resolved = SurvivorUI_FontFor and SurvivorUI_FontFor(preferred) or preferred
	local list = SurvivorUI_FontList and SurvivorUI_FontList(true)

	if list then
		local defaultPath = SurvivorUI_DefaultFont and SurvivorUI_DefaultFont()
			or SurvivorUI_DEFAULT_FONT or SurvivorUI_FONT
		local allowed = false

		-- The first list entry is the addon's language-aware default face.
		if resolved and defaultPath
			and string.lower(resolved) == string.lower(defaultPath) then
			allowed = true
		end

		-- Every other listed path is known to write the active game language.
		local index
		for index = 1, table.getn(list) do
			local path = list[index].path
			if path and resolved and string.lower(path) == string.lower(resolved) then
				allowed = true
				break
			end
		end

		if not allowed then
			-- Prefer a language-approved face over a stale saved font path.
			for index = 1, table.getn(list) do
				if list[index].path then
					return list[index].path
				end
			end
			return (SurvivorUI_FontFor and SurvivorUI_FontFor(nil))
				or defaultPath or SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
		end
	end

	-- Keep a fallback for older addon versions without the font-list helper.
	return resolved or (SurvivorUI_FontFor and SurvivorUI_FontFor(nil))
		or SurvivorUI_FONT or SurvivorUI_DEFAULT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Resolve the selected Global or local font only when a banner is displayed.
-- This leaves the saved preference untouched when a language needs a fallback.
local function BannerFontPath()
	local db = DB()
	local preferred

	if db.bannersUseGlobalFont ~= false then
		preferred = SurvivorUI_GlobalFont and SurvivorUI_GlobalFont()
	else
		-- A local banner font takes priority; otherwise follow the Global face.
		preferred = db.bannersFont or (SurvivorUI_GlobalFont and SurvivorUI_GlobalFont())
	end

	return SurvivorUI_BannerFontFor(preferred)
end

-- Banner phrases use the addon's shared language dictionaries in Locale_zh.lua
-- and Locale_ru.lua, rather than keeping a second set of translations here.
-- Read SurvivorUI_WORDS directly so banners can translate as soon as the client
-- language is known, even before zone-based helpers are ready.
function SurvivorUI_BannerText(template, ...)
	local language = SurvivorUI_Language and SurvivorUI_Language()
	local words = language and SurvivorUI_WORDS and SurvivorUI_WORDS[language]
	local translated = words and words[template]
	local text = translated or template or ""
	local values = arg

	-- Keep numbered placeholders compatible with the shared locale dictionaries.
	return (string.gsub(text, "{(%d)}", function(index)
		local value = values[tonumber(index)]
		return value ~= nil and tostring(value) or ""
	end))
end

-- Read the saved text-size step, keeping the same range as other text controls.
local function BannerTextSizeStep()
	local value = tonumber(DB().bannersTextSize) or 0
	value = math.floor(value + 0.5)	-- Keep saved values on whole-point steps.
	if value < -4 then value = -4 end
	if value > 8 then value = 8 end
	return value
end

-- Apply the selected size while preserving the game's banner font and outline.
local function ApplyBannerTextSize(frame)
	if not frame or not frame.label or not frame.baseFont then
		return
	end
	-- Re-resolve the path each time, so the current Global font is respected.
	frame.baseFont = BannerFontPath()
	local size = math.max(6, frame.baseFontSize + BannerTextSizeStep())
	frame.label:SetFont(frame.baseFont, size, frame.baseFontFlags)
end

-- Create one reusable on-screen banner frame.
local function MakeBanner(index)
	local frameName = "SurvivorUIBannerFrame" .. tostring(index)
	local frame = CreateFrame("Frame", frameName, UIParent)
	frame:SetWidth(620)
	frame:SetHeight(48)
	frame:SetFrameStrata("HIGH")
	frame:Hide()

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("CENTER", frame, "CENTER", 0, 0)
	label:SetWidth(600)
	label:SetHeight(42)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")	-- Keep the banner text centered vertically and horizontally.
	frame.label = label
	-- Save the template's original font settings as the slider's baseline.
	frame.baseFont, frame.baseFontSize, frame.baseFontFlags = label:GetFont()
	if not frame.baseFont then
		frame.baseFont = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
		frame.baseFontSize = 16
		frame.baseFontFlags = "OUTLINE"
	end
	frame.baseFontSize = tonumber(frame.baseFontSize) or 16
	ApplyBannerTextSize(frame)
	frame.remaining = 0
	frame.born = 0

	-- Keep the frame at its normal HIGH strata; do not force it above game screens.
	frame:SetScript("OnUpdate", function()
		local elapsed = arg1 or 0
		if frame.remaining > 0 then
			frame.remaining = frame.remaining - elapsed
			if frame.remaining <= 0 then
				frame.remaining = 0
				frame:Hide()
			end
		end
	end)

	frames[index] = frame
	return frame
end

-- Reuse an existing banner frame or create it on demand.
local function GetFrame(index)
	if not frames[index] then
		return MakeBanner(index)
	end
	return frames[index]
end

-- Position a banner according to the selected layout.
local function LayoutFrame(frame, index)
	frame:ClearAllPoints()
	local layout = DB().bannersLayout or "center"
	if layout == "stack" then
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 270 - ((index - 1) * 26))
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 270)
	end
end

-- Choose a free frame, or recycle the oldest stacked banner.
local function ChooseFrame()
	local layout = DB().bannersLayout or "center"
	if layout ~= "stack" then
		return GetFrame(1), 1
	end

	local i
	for i = 1, 4 do
		local frame = GetFrame(i)
		if not frame:IsShown() then
			return frame, i
		end
	end

	local oldestIndex = 1
	local oldestBorn = frames[1].born or 0
	for i = 2, 4 do
		if (frames[i].born or 0) < oldestBorn then
			oldestBorn = frames[i].born or 0
			oldestIndex = i
		end
	end
	return GetFrame(oldestIndex), oldestIndex
end

-- Filter and display a banner received from a real game event.
local function ShowBanner(banner)
	if type(banner) ~= "table" then
		return
	end


	if not Enabled() then
		return
	end

	if not Allowed(banner.kind) then
		return
	end

	local message = banner.text
	if not message or message == "" then
		message = banner.name or tostring(banner.kind or "Banner")
	end
	if not message or message == "" then
		return
	end

	-- The cache callback and red UI error use the same localized string.
	-- Remember it only when this custom banner will really be displayed.
	if banner.kind == "cache" then
		RememberCacheError(message)
	end

	local frame, index = ChooseFrame()
	-- Refresh the font and size before reusing a frame for this new message.
	ApplyBannerTextSize(frame)
	local r, g, b = BannerColor(banner.kind, banner.boss)
	frame.label:SetText(message)
	frame.label:SetTextColor(r, g, b)
	LayoutFrame(frame, index)
	frame.remaining = HoldTime()
	frame.born = GetTime()
	frame:Show()
end

-- Keep the game's original HUD preference so disabling custom banners does
-- not accidentally turn on a HUD the player had already hidden.
-- Synchronize the game's built-in banner HUD with the custom-banner setting.
function SurvivorUI_BannersRefresh()
	-- Refresh the font and size on every frame that has already been created.
	local index
	local visibleFrames = {}
	for index = 1, 4 do
		local frame = frames[index]
		if frame then
			ApplyBannerTextSize(frame)
			if frame:IsShown() then
				table.insert(visibleFrames, frame)
			end
		end
	end

	-- Reflow banners immediately when the player changes Center/Stack layout.
	-- Center is a single-banner layout, so keep the newest visible message and
	-- hide older stacked messages rather than placing several on top of each other.
	if (DB().bannersLayout or "center") == "center" then
		local newestFrame = nil
		local newestBorn = -1
		for index = 1, table.getn(visibleFrames) do
			local frame = visibleFrames[index]
			local born = frame.born or 0
			if born >= newestBorn then
				newestBorn = born
				newestFrame = frame
			end
		end

		for index = 1, table.getn(visibleFrames) do
			local frame = visibleFrames[index]
			if frame == newestFrame then
				LayoutFrame(frame, 1)
			else
				frame:Hide()
				frame.remaining = 0
			end
		end
	else
		-- Keep surviving stack entries compact, in their original age order.
		-- This avoids empty gaps when an earlier banner has already expired.
		table.sort(visibleFrames, function(a, b)
			return (a.born or 0) < (b.born or 0)
		end)
		for index = 1, table.getn(visibleFrames) do
			LayoutFrame(visibleFrames[index], index)
		end
	end

	-- Font changes are independent of the game's HUD visibility API.
	if not AZS_SetHudShown or not AZS_IsHudShown then
		return
	end

	if Enabled() then
		if not DB().hidGameBanners then
			DB().gameBannersWereShown = AZS_IsHudShown("banners")
			DB().hidGameBanners = true
		end
		AZS_SetHudShown("banners", false)
	else
		if DB().hidGameBanners then
			local wasShown = DB().gameBannersWereShown
			if wasShown == nil then wasShown = true end
			AZS_SetHudShown("banners", wasShown)
			DB().hidGameBanners = nil
			DB().gameBannersWereShown = nil
		end
	end
end

-- Read current lair data from the documented API or global table.
local function ReadLairs()
	if AZS_GetLairs then
		return AZS_GetLairs()
	end
	return AZS_LAIRS
end

-- Count lairs using the legacy-compatible table API.
local function LairCount(lairs)
	if type(lairs) ~= "table" then return 0 end
	if table.getn then return table.getn(lairs) end
	return 0
end

-- Record current lair states without announcing existing Guardians.
local function SeedLairStates()
	local lairs = ReadLairs()
	if type(lairs) ~= "table" then
		return false
	end

	lairStates = {}
	local count = LairCount(lairs)
	local i
	for i = 1, count do
		local lair = lairs[i]
		if type(lair) == "table" then
			local key = lair.index or i
			lairStates[key] = lair.state
		end
	end
	lairStateReady = true
	return true
end

-- Display an arrival banner for a newly occupied lair.
local function GuardianArrived(lair)
	local name = lair.name
	if not name or name == "" then
		name = "Guardian"
	end

	-- Keep the original all-caps English style, but do not force uppercase on
	-- Chinese or Russian names when their own translated sentence is used.
	local language = SurvivorUI_Language and SurvivorUI_Language()
	local displayName = tostring(name)
	if language ~= "zh" and language ~= "ru" then
		displayName = string.upper(displayName)
	end

	ShowBanner({
		kind = "guardianArrival",
		name = name,
		text = SurvivorUI_BannerText("{1} HAS APPEARED!", displayName)
	})
end

-- Compare current lair states with the previous snapshot.
local function CheckLairs()
	local phase = AZS_GetPhase and AZS_GetPhase() or (AZS_RUN and AZS_RUN.ph)
	if phase ~= "playing" then
		if lairStateReady then
			lairStates = {}
			lairStateReady = false
		end
		return
	end

	local lairs = ReadLairs()
	if type(lairs) ~= "table" then
		return
	end

	-- The first snapshot is a baseline, not a spawn event.
	if not lairStateReady then
		SeedLairStates()
		return
	end

	local count = LairCount(lairs)
	local i
	for i = 1, count do
		local lair = lairs[i]
		if type(lair) == "table" then
			local key = lair.index or i
			local previous = lairStates[key]
			local current = lair.state

			-- This transition indicates a fresh Guardian spawn in the lair.
			if previous == "empty" and current == "asleep" then
				GuardianArrived(lair)
			end

			lairStates[key] = current
		end
	end
end

-- Register our callback for the game's normal banner events.
local function RegisterBannerHandler()
	if handlerRegistered then return end
	if type(AZS_RegisterBannerHandler) ~= "function" then
		return
	end

	local ok, err = pcall(AZS_RegisterBannerHandler, ShowBanner)
	if ok then
		handlerRegistered = true
	else
		BannerLog("ERROR registering game banner handler: " .. tostring(err))
	end
end

-- Listen for world entry and the add-on message events used for lair updates.
-- The native error filter is installed here, once the standard UI error frame
-- exists; it remains narrowly scoped to exact, recent cache-banner text.
local bannerEvents = CreateFrame("Frame")
bannerEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
bannerEvents:RegisterEvent("CHAT_MSG_ADDON")
-- This legacy client exposes event arguments through global arg variables.
bannerEvents:SetScript("OnEvent", function()
	local eventName = event

	if eventName == "PLAYER_ENTERING_WORLD" then
		RegisterBannerHandler()
		InstallNativeErrorFilter()
		SurvivorUI_BannersRefresh()

		local phase = AZS_GetPhase and AZS_GetPhase() or (AZS_RUN and AZS_RUN.ph)
		if phase == "playing" then
			SeedLairStates()
		else
			lairStates = {}
			lairStateReady = false
		end
		return
	end

	if eventName == "CHAT_MSG_ADDON" then
		local prefix = arg1
		if prefix == "AZSLAIRS" then
			CheckLairs()
		elseif prefix == "AZSRUN" then
			local phase = AZS_GetPhase and AZS_GetPhase() or (AZS_RUN and AZS_RUN.ph)
			if phase ~= "playing" then
				lairStates = {}
				lairStateReady = false
			elseif not lairStateReady then
				-- The first run-state update gives us a clean baseline before
				-- subsequent lair updates announce new spawns.
				SeedLairStates()
			end
		end
	end
end)
