-- Survivor Plates - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor Plates: nameplates in the manner of Plater, for Azeroth Survivors.
-- A flat health bar on a dark backing with a thin black border, the name above
-- it, the unit's health on it, an execute-range marker, and a highlighted
-- target with its debuffs. Elites and bosses get larger plates in their own colors.
-- A lair guardian is an elite to the client, under its elite's name; the game
-- tells addons which one it is only for the target, whose plate turns blue.
--
-- Where the game shares its run (its addon API: AZS_UNITS, AZS_UnitKind), the
-- elites and bosses it lists are told apart by that too, beyond the lists below.
--
-- The 1.12 client owns the nameplate frames: they are unnamed children of
-- WorldFrame, recognized by their border texture. Each one is skinned once,
-- its stock art blanked and an overlay drawn from the stock health bar's
-- values. The client recycles a plate for another unit, so the overlay
-- re-reads the name every frame.
--
-- The bars sit exactly where the client seats its plates: position and
-- stacking are the client's own.
--
-- A raid mark (the game's 0.115; Survivor UI's Raid marks put them on their
-- own) is the client's own icon, the plate's last region, left of the bar: the
-- client hangs it off its wider stock plate's edge, far from the bar.
--
-- Each kind is chosen on its own (/splates, or Survivor UI's options): the
-- enemies' four, normal, elites, guardians and bosses (all of them by
-- default; a kind left out still shows as your target, unless /splates
-- target: the game moves the target on its own, and with the rank and file
-- left out its plate jumps from one to the next, asked for by Klopp), and the friends'
-- three, your pets and summons and your totems (asked for on Discord by
-- Sedz and Amarolk, with a warlock's many demons about) and the members of a
-- co-op run's party (the game's 0.113; asked for by Klopp and ChaoticBon),
-- none by default. Only elites, guardians and bosses carry a name, unless names
-- are on every plate. The friends' plates are the client's friendly ones,
-- told from an enemy's by the color it gives them, drawn small with the
-- name and icon; a party member's, told by its name among party1 to party4,
-- in the class's color with the class's icon and the health left. A friend
-- down has no plate: the client gives a fallen hero none (seen 2026-10-23),
-- and Survivor UI's party frames say DOWN.
--
-- Slash commands:
--   /splates none       no nameplates at all (the default), or back
--   /splates normal | elites | guardians | bosses     each enemy kind, on or off
--   /splates pets | totems | party                    each friend's, on or off
--   /splates target     the target's plate though its kind is left out (default), or not
--   /splates names      names only on elites, guardians and bosses (default), or on every plate
--   /splates keys       V and Shift+V ignored (default), or let them work as the game has them
--   /splates click      clicks go through the plates (default), or a click on one targets it
--   /splates count      the plates on screen now, by kind (a check)
--   /splates scale N    plate size, 0.5 to 2 (default 1)
--
-- A key of one's own turns all the plates on and off as /splates none does
-- (Key Bindings, Survivor Plates; or Survivor UI's options, Nameplates).

-- With SurvivorUI Classic chosen (its choice panel), the plates stand aside
-- with Survivor UI: the file ends here. SurvivorUI Classic loads first (the
-- .toc's OptionalDeps), so its choice is known; without it nothing changes.
SurvivorPlates_Standby = SurvivorUIClassicDB and SurvivorUIClassicDB.use == "classic" or nil
if SurvivorPlates_Standby then return end

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
-- Survivor UI's face when it is installed: a player's own Expressway, else its
-- Barlow Condensed, else Friz Quadrata. This addon loads first, so it tries
-- them itself, each on a probe, since a face that does not load leaves none.
-- Survivor UI's global font, once it is there, takes the place of all three.
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = 0              -- Barlow Condensed reads small: one point up
local FACES = {
	{ path = "Interface\\AddOns\\SurvivorUI\\Fonts\\Expressway.ttf", mark = "expressway" },
	{ path = "Interface\\AddOns\\SurvivorUI\\Media\\BarlowCondensed-Medium.ttf", mark = "barlow", bump = 1 },
}
for index = 1, table.getn(FACES) do
	local face = FACES[index]
	local probe = UIParent:CreateFontString(nil, "OVERLAY")
	probe:SetFont(face.path, 12)
	local got = probe:GetFont()
	if got and string.find(string.lower(got), face.mark, 1, true) then
		FONT = face.path
		FONT_BUMP = face.bump or 0
		break
	end
end
local BORDER_TEXTURE = "Interface\\Tooltips\\Nameplate-Border"

local EXECUTE_RANGE = 0.30      -- the game's execute effects start below this share of health

local KINDS = {
	normal   = { width = 100, height = 9,  nameSize = 9,  color = { 0.84, 0.20, 0.20 } },
	-- Elites, guardians and bosses in the item qualities' order, each a
	-- little lighter: uncommon's lime (not the pets' mint), rare, epic.
	elite    = { width = 130, height = 11, nameSize = 11, color = { 0.35, 1.00, 0.20 } },
	guardian = { width = 150, height = 12, nameSize = 12, color = { 0.20, 0.75, 0.95 } },
	boss     = { width = 170, height = 14, nameSize = 13, color = { 0.72, 0.32, 1.00 } },
	-- A friend's plate, small and always named: your pets and summons green,
	-- your totems blue.
	pet       = { width = 80,  height = 6,  nameSize = 9,  color = { 0.25, 0.85, 0.35 } },
	totem     = { width = 80,  height = 6,  nameSize = 9,  color = { 0.30, 0.65, 1.00 } },
	-- A co-op friend's: a little larger, in the class's color (this one only
	-- with the class unknown).
	party     = { width = 110, height = 8,  nameSize = 10, color = { 0.45, 0.78, 1.00 } },
}
local FRIEND_KINDS = { pet = true, totem = true, party = true }

-- The classes' icons (the character creation's) and colors, for a co-op
-- friend's plate; the shaman in its modern blue, as Survivor UI has it.
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

local function ClassColor(class)
	if SurvivorUI_ClassColor then
		local r, g, b = SurvivorUI_ClassColor(class)
		return { r, g, b }
	end
	if class == "SHAMAN" then
		return { 0.00, 0.44, 0.87 }
	end
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	return color and { color.r, color.g, color.b } or nil
end

-- A party member's class by its name (party1 to party4), nil for anyone else.
local function PartyClass(name)
	if not name then
		return nil
	end
	for index = 1, 4 do
		local unit = "party"..index
		if UnitExists(unit) and UnitName(unit) == name then
			local _, class = UnitClass(unit)
			return class or "?"
		end
	end
end
local EXECUTE_COLOR = { 1.00, 0.86, 0.25 }

-- The five bosses of each zone.
local BOSSES = {
	-- Elwynn Forest
	"Hogger", "Mother Fang", "Rhahk'Zor", "Mr. Smite", "Edwin VanCleef",
	-- Duskwood
	"Naraxis", "Mor'Ladim", "Stitches", "Lupos", "Morbent Fel",
	-- Warsong Gulch
	"Doomguard Commander", "Mannoroth's Herald", "Varimathras", "Lord Hel'nurath", "Lord Kazzak",
	-- Arathi Basin
	"Patchwerk", "Lord Blackwood", "Baron Rivendare", "Anub'Rekhan", "Kel'Thuzad",
	-- Feralas
	"Zevrim Thornhoof", "Alzzin the Wildshaper", "Tendris Warpwood", "Immol'thar", "King Gordok",
	-- Gurubashi Arena
	"High Priestess Jeklik", "High Priest Venoxis", "Bloodlord Mandokir", "Jin'do the Hexxer", "Hakkar the Soulflayer",
	-- Alterac Valley
	"Korrak the Bloodrager", "Ivus the Forest Lord", "Lokholar the Ice Lord", "Glacius the Frozen Titan", "Azuregos",
	-- Blackrock Mountain
	"General Angerforge", "Warchief Rend Blackhand", "Emperor Dagran Thaurissan", "Majordomo Executus", "Nefarian",
	-- Gates of Ahn'Qiraj
	"Kurinnaxx", "General Rajaxx", "Princess Huhuran", "Ossirian the Unscarred", "C'Thun",
}

-- The elites of each zone's horde: the three enemies the game's own tables
-- flag as elite in every zone.
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

local kindByName = {}
for index = 1, table.getn(ELITES) do
	kindByName[ELITES[index]] = "elite"
end
for index = 1, table.getn(BOSSES) do
	kindByName[BOSSES[index]] = "boss"
end

-- The elites and bosses the game lists right now, by name, rebuilt when the
-- list changes; its guardians apart, with their health, since a zone's
-- guardians are named as its elites (Elwynn's three). kindsVersion tells the
-- plates to look again.
local liveKind = {}
local guardians = {}              -- [name] = the max health of each one alive
local guardiansSeen = ""
local liveUpdated
local kindsVersion = 0

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function RefreshLiveKinds()
	if not AZS_UNITS or AZS_UNITS_UPDATED == liveUpdated then
		return
	end
	liveUpdated = AZS_UNITS_UPDATED
	local changed = false
	local found, seen = {}, ""
	for index = 1, table.getn(AZS_UNITS) do
		local unit = AZS_UNITS[index]
		local name = Field(unit, "name", 3)
		local kind = Field(unit, "kind", 1)
		if name and kind == "guardian" then
			local most = tonumber(Field(unit, "hpm", 5)) or 0
			found[name] = found[name] or {}
			table.insert(found[name], most)
			seen = seen..name..most..";"
		elseif name and not kindByName[name] then
			kind = (kind == "final" or kind == "boss") and "boss" or "elite"
			if liveKind[name] ~= kind then
				liveKind[name] = kind
				changed = true
			end
		end
	end
	if seen ~= guardiansSeen then
		guardians, guardiansSeen = found, seen
		changed = true
	end
	if changed then
		kindsVersion = kindsVersion + 1
	end
end

-- An enemy's kind by its name, and its max health when the client knows it
-- (most): a guardian the game lists, by its health against an elite of the
-- same name.
local function Classify(name, most)
	if not name then
		return "normal"
	end
	local named = kindByName[name] or liveKind[name]
	local lair = guardians[name]
	if lair then
		for index = 1, table.getn(lair) do
			if most and math.abs(most - lair[index]) <= 1 then
				return "guardian"
			end
		end
		if not named then
			return "guardian"
		end
	end
	return named or "normal"
end

-- The target's kind as the game has it, "guardian" included; nil without the API.
local function TargetKind()
	if AZS_UnitKind and UnitExists("target") then
		return AZS_UnitKind("target")
	end
end

local function Settings()
	SurvivorPlatesDB = SurvivorPlatesDB or {}
	local db = SurvivorPlatesDB
	-- The defaults: a plate on every enemy, a name only on elites, guardians and
	-- bosses. Settings saved under the earlier defaults start over once.
	if (db.defaults or 0) < 2 then
		db.important = false
		db.names = false
	end
	-- From v2.8 no plates by default: Survivor UI's boss bars show the bosses,
	-- guardians and elites. Once for everyone; whoever wants plates turns them on.
	if (db.defaults or 0) < 3 then
		db.defaults = 3
		db.hidden = true
	end
	-- Each kind on its own (v3.0.18), from what was chosen before: "only the
	-- dangerous ones" leaves the rank and file out, and the pets' plates are
	-- as /splates friends had them.
	if not db.show then
		db.show = { normal = not db.important, elite = true, guardian = true, boss = true,
			pet = db.friends == true, totem = false }
		db.friendsChosen = db.friends ~= nil
	end
	-- The companions had plates of their own for a day: the game gives them none.
	db.show.companion = nil
	db.scale = db.scale or 1
	-- From v3.0.36 clicks go through the plates, as asked on Discord.
	if db.clickThrough == nil then
		db.clickThrough = true
	end
	return db
end

-- 1234, 12.3k, 1.2m
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
end

local overlays = {}

-- Other addons find the plates here: the art a plate is recognized by is
-- blanked once it is skinned. Each entry has .plate and .stock.name.
SurvivorPlatesRegistry = overlays

-- The client's raid icon, left of the bar, as tall as the bar and a little
-- more. The client sets its anchor again when the window changes size, so it
-- is put back each time a mark shows.
local function PlaceRaidIcon(overlay)
	local raid = overlay.stock.raid
	if not raid or not overlay.style then
		return
	end
	local size = math.max(14, (overlay.style.height + 8) * Settings().scale)
	raid:ClearAllPoints()
	raid:SetPoint("RIGHT", overlay.bar, "LEFT", -3, 0)
	raid:SetWidth(size)
	raid:SetHeight(size)
end

local function ApplyKind(overlay, kind)
	local style = KINDS[kind]
	local settings = Settings()
	local scale = settings.scale
	overlay.kind = kind
	overlay.style = style
	overlay.bar:SetWidth(style.width * scale)
	overlay.bar:SetHeight(style.height * scale)
	overlay.marker:SetHeight(style.height * scale)
	overlay.marker:SetPoint("LEFT", overlay.bar, "LEFT", style.width * scale * EXECUTE_RANGE, 0)
	overlay.name:SetFont(SurvivorUI_FONT or FONT, style.nameSize * scale + FONT_BUMP, "OUTLINE")
	overlay.health:SetFont(SurvivorUI_FONT or FONT, math.max(8, (style.height - 1) * scale) + FONT_BUMP, "OUTLINE")

	overlay.named = settings.names or kind ~= "normal"
	PlaceRaidIcon(overlay)
	if FRIEND_KINDS[kind] then
		overlay.marker:Hide()
	end
	if overlay.named and not overlay.put then
		overlay.name:Show()
	else
		overlay.name:Hide()
	end

end

-- Debuffs on the target's plate, with their stacks. The 1.12 client only tells
-- an addon about the debuffs of a unit it can name, and of all the plates on
-- screen only the target's can be told apart (it alone keeps full alpha).
local PLATE_DEBUFFS = 6
local DEBUFF_SIZE = 15

local function UpdatePlateDebuffs(overlay, isTarget)
	local icons = overlay.debuffs
	if not isTarget then
		if icons and overlay.debuffsShown then
			for index = 1, PLATE_DEBUFFS do
				if icons[index] then
					icons[index]:Hide()
				end
			end
			overlay.debuffsShown = nil
		end
		return
	end

	if not icons then
		icons = {}
		overlay.debuffs = icons
	end
	overlay.debuffsShown = true

	local lift = overlay.named and (overlay.style.nameSize * Settings().scale + 7) or 4
	for index = 1, PLATE_DEBUFFS do
		local texture, count = UnitDebuff("target", index)
		local icon = icons[index]
		if texture then
			if not icon then
				icon = CreateFrame("Frame", nil, overlay.bar)
				icon:SetWidth(DEBUFF_SIZE)
				icon:SetHeight(DEBUFF_SIZE)
				icon.edge = icon:CreateTexture(nil, "BACKGROUND")
				icon.edge:SetTexture(FLAT)
				icon.edge:SetVertexColor(0, 0, 0, 1)
				icon.edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
				icon.edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
				icon.texture = icon:CreateTexture(nil, "ARTWORK")
				icon.texture:SetAllPoints(icon)
				icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				icon.count = icon:CreateFontString(nil, "OVERLAY")
				icon.count:SetFont(SurvivorUI_FONT or FONT, 9 + FONT_BUMP, "OUTLINE")
				icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
				icons[index] = icon
			end
			icon:ClearAllPoints()
			icon:SetPoint("BOTTOMLEFT", overlay.bar, "TOPLEFT", (index - 1) * (DEBUFF_SIZE + 2), lift)
			icon.texture:SetTexture(texture)
			icon.count:SetText(count and count > 1 and count or "")
			icon:Show()
		elseif icon then
			icon:Hide()
		end
	end
end

-- A friend's plate, told by the color the client gives its stock bar: green
-- for a friendly creature (seen 2026-10-20: the warlock's demons, 0 1 0; the
-- enemies 1 0 0), blue for a friendly player.
local function IsFriend(stock)
	local r, g, b = stock.health:GetStatusBarColor()
	return r and g and b and r < 0.2 and (g > 0.8 or b > 0.8)
end

-- A name in English, the game in any language (Survivor UI's, when there).
local function English(name)
	return SurvivorUI_English and SurvivorUI_English(name) or name
end

-- A friend's kind: a member of the party (a co-op run's), a totem (the game
-- names every one plainly "Totem", seen 2026-10-20; "Searing Totem" too,
-- should it name them), or (all the rest) a pet or summon.
local function FriendKind(name)
	if PartyClass(name) then
		return "party"
	end
	local english = English(name or "")
	if english == "Totem" or string.find(english, " Totem$") then
		return "totem"
	end
	return "pet"
end

-- A plain "Totem"'s icon: the hero's one totem spell's, or a totem's when the
-- hero has more than one (the plate can't tell which).
local TOTEM_ICON = "Interface\\Icons\\Spell_Nature_StoneClawTotem"
local function TotemIcon()
	local found
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		local key = entry.key or entry[1] or ""
		if string.find(key, "_totem$") then
			if found then
				return TOTEM_ICON
			end
			found = key
		end
	end
	-- "searing_totem" as its name, "Searing Totem".
	local spell = found and string.gsub(string.gsub(found, "_", " "), "(%a)(%a*)",
		function(first, rest) return string.upper(first)..rest end)
	return spell and SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(spell) or TOTEM_ICON
end

-- A friend's icon beside its name, Survivor UI's (its meter's), when it is there.
local function FriendIcon(overlay, name)
	local icon
	-- A party member: the class's icon, cut inside its round edge.
	if overlay.kind == "party" then
		local coords = CLASS_ICON_COORDS[PartyClass(name) or ""]
		if coords then
			local cutX, cutY = (coords[2] - coords[1]) * 0.1, (coords[4] - coords[3]) * 0.1
			overlay.icon:SetTexture(CLASS_ICONS)
			overlay.icon:SetTexCoord(coords[1] + cutX, coords[2] - cutX, coords[3] + cutY, coords[4] - cutY)
			overlay.icon:Show()
		else
			overlay.icon:Hide()
		end
		return
	end
	overlay.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if overlay.kind == "totem" and English(name or "") == "Totem" then
		icon = TotemIcon()
	elseif FRIEND_KINDS[overlay.kind] then
		icon = SurvivorUI_MeterIcon and SurvivorUI_MeterIcon(name)
	end
	if icon then
		overlay.icon:SetTexture(icon)
		overlay.icon:Show()
	else
		overlay.icon:Hide()
	end
end

local function UpdatePlate()
	local overlay = this
	local stock = overlay.stock

	-- The client dims every plate but the target's.
	local isTarget = UnitExists("target") and overlay.plate:GetAlpha() == 1

	-- The client fills a plate in over a frame or two as it hands it to
	-- another unit: its name, then its bar's color and health. So the kind is
	-- read again whenever any of them changes, not the name alone: a totem
	-- read while its bar was still the last enemy's red stayed an enemy (and
	-- hidden with the rank and file), until the game's list of units changed.
	local name = stock.name:GetText()
	local low, high = stock.health:GetMinMaxValues()
	local friend = IsFriend(stock) and true or false
	if name ~= overlay.lastName or friend ~= overlay.lastFriend or high ~= overlay.lastHigh
		or overlay.kindsVersion ~= kindsVersion then
		overlay.lastName, overlay.lastFriend, overlay.lastHigh = name, friend, high
		overlay.kindsVersion = kindsVersion
		overlay.name:SetText(name)
		local known = high - low ~= 100 and high > 1
		overlay.baseKind = friend and FriendKind(name) or Classify(name, known and high or nil)
		overlay.iconFor = nil
		overlay.classColor = overlay.baseKind == "party" and ClassColor(PartyClass(name)) or nil
	end
	-- The target's kind as the game tells it, an enemy's: a guardian and an
	-- elite of the same name told apart for sure.
	local kind = overlay.baseKind
	if isTarget and not FRIEND_KINDS[kind] then
		local told = overlay.targetKind
		if told == "final" or told == "boss" then
			kind = "boss"
		elseif told == "guardian" or told == "elite" or told == "normal" then
			kind = told
		end
	end
	if kind ~= overlay.kind then
		ApplyKind(overlay, kind)
		overlay.iconFor = nil
	end
	if overlay.iconFor ~= name then
		overlay.iconFor = name
		FriendIcon(overlay, name)
	end
	local marked = stock.raid and stock.raid:IsShown() and true or false
	if marked and not overlay.marked then
		PlaceRaidIcon(overlay)
	end
	overlay.marked = marked

	-- A kind left out goes without a plate; an enemy's still shows as the
	-- target, unless that is off too.
	local settings = Settings()
	if not settings.show[overlay.kind]
		and not (isTarget and settings.targetPlate ~= false and not FRIEND_KINDS[overlay.kind]) then
		overlay.icon:Hide()
		if not overlay.put then
			overlay.put = true
			overlay.bar:Hide()
			overlay.name:Hide()
		end
		return
	elseif overlay.put then
		overlay.put = nil
		overlay.bar:Show()
		if overlay.named then
			overlay.name:Show()
		end
		overlay.iconFor = nil
	end

	local value = stock.health:GetValue()
	local share = high > low and (value - low) / (high - low) or 0
	local percent = math.floor(share * 100 + 0.5)
	overlay.bar:SetValue(share)

	-- A 0 to 100 bar means the client only knows the percentage; anything else
	-- is the unit's real health. A party member: what is left of it.
	if overlay.kind == "party" then
		overlay.health:SetText(percent.."%")
	elseif FRIEND_KINDS[overlay.kind] then
		overlay.health:SetText("")
	elseif high - low == 100 or high <= 1 then
		overlay.health:SetText(percent.."%")
	elseif overlay.kind == "normal" then
		overlay.health:SetText(Short(value))
	else
		overlay.health:SetText(Short(value).." / "..Short(high).."  "..percent.."%")
	end

	local color = overlay.classColor or overlay.style.color
	if FRIEND_KINDS[overlay.kind] then
		-- No execute mark on a friend.
	elseif share <= EXECUTE_RANGE then
		color = EXECUTE_COLOR
		overlay.marker:Hide()
	else
		overlay.marker:Show()
	end
	overlay.bar:SetStatusBarColor(color[1], color[2], color[3], 1)

	if isTarget then
		overlay.border:SetVertexColor(1, 1, 1, 1)
	else
		overlay.border:SetVertexColor(0, 0, 0, 1)
	end
	UpdatePlateDebuffs(overlay, isTarget)
end

local function IsNameplate(frame)
	local region = frame:GetRegions()
	return region and region.GetObjectType and region:GetObjectType() == "Texture"
		and region:GetTexture() == BORDER_TEXTURE
end

local function Blank(object)
	local kind = object:GetObjectType()
	if kind == "Texture" then
		object:SetTexture("")
		object:SetTexCoord(0, 0, 0, 0)
	elseif kind == "FontString" then
		object:SetWidth(0.001)
	end
end

local function SkinPlate(plate)
	local stock = {}
	stock.health = plate:GetChildren()
	if not stock.health or not stock.health.GetMinMaxValues then
		return
	end

	-- Stock regions: border, glow, name, level, level icon, raid icon. The two
	-- font strings come in that order; the raid icon is the last texture, kept.
	local regions = { plate:GetRegions() }
	local count = table.getn(regions)
	if count > 0 and regions[count]:GetObjectType() == "Texture" then
		stock.raid = regions[count]
	end
	for index = 1, count do
		local region = regions[index]
		if region:GetObjectType() == "FontString" then
			if not stock.name then
				stock.name = region
			else
				stock.level = region
			end
			Blank(region)
		elseif index < count then
			Blank(region)
		end
	end
	if not stock.name then
		return
	end
	stock.health:SetStatusBarTexture("")

	local overlay = CreateFrame("Frame", nil, plate)
	overlay:SetAllPoints(plate)
	overlay.plate = plate
	overlay.stock = stock

	overlay.bar = CreateFrame("StatusBar", nil, overlay)
	overlay.bar:SetPoint("CENTER", overlay, "CENTER", 0, -4)
	overlay.bar:SetStatusBarTexture(FLAT)
	overlay.bar:SetMinMaxValues(0, 1)

	overlay.border = overlay.bar:CreateTexture(nil, "BACKGROUND")
	overlay.border:SetTexture(FLAT)
	overlay.border:SetPoint("TOPLEFT", overlay.bar, "TOPLEFT", -1, 1)
	overlay.border:SetPoint("BOTTOMRIGHT", overlay.bar, "BOTTOMRIGHT", 1, -1)

	overlay.backing = overlay.bar:CreateTexture(nil, "BORDER")
	overlay.backing:SetTexture(FLAT)
	overlay.backing:SetVertexColor(0.10, 0.10, 0.12, 1)
	overlay.backing:SetAllPoints(overlay.bar)

	overlay.marker = overlay.bar:CreateTexture(nil, "OVERLAY")
	overlay.marker:SetTexture(FLAT)
	overlay.marker:SetVertexColor(1, 1, 1, 0.7)
	overlay.marker:SetWidth(1)

	overlay.name = overlay:CreateFontString(nil, "OVERLAY")
	overlay.name:SetPoint("BOTTOM", overlay.bar, "TOP", 0, 3)
	overlay.name:SetTextColor(1, 1, 1)

	-- A pet's icon, left of its name (PetIcon).
	overlay.icon = overlay:CreateTexture(nil, "OVERLAY")
	overlay.icon:SetWidth(12)
	overlay.icon:SetHeight(12)
	overlay.icon:SetPoint("RIGHT", overlay.name, "LEFT", -2, 0)
	overlay.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	overlay.icon:Hide()

	overlay.health = overlay.bar:CreateFontString(nil, "OVERLAY")
	overlay.health:SetPoint("RIGHT", overlay.bar, "RIGHT", -2, 0)
	overlay.health:SetTextColor(1, 1, 1)

	ApplyKind(overlay, "normal")
	overlay:SetScript("OnUpdate", UpdatePlate)
	table.insert(overlays, overlay)
end

-- New plates only ever get appended to WorldFrame's children.
local scanned = 0
local partyCount = 0
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	RefreshLiveKinds()
	-- The target's kind, asked once a frame for every plate to read.
	local targetKind = TargetKind()
	for index = 1, table.getn(overlays) do
		overlays[index].targetKind = targetKind
	end

	-- The party changed (a friend joined or left): every plate looks again, a
	-- friend's plate read before the party knew them was a pet's.
	local members = GetNumPartyMembers and GetNumPartyMembers() or 0
	if members ~= partyCount then
		partyCount = members
		kindsVersion = kindsVersion + 1
	end

	local count = WorldFrame:GetNumChildren()
	if count ~= scanned then
		local children = { WorldFrame:GetChildren() }
		for index = scanned + 1, count do
			local child = children[index]
			if child and IsNameplate(child) then
				SkinPlate(child)
			end
		end
		scanned = count
	end
end)

-- Whether any kind of the enemies' (friends false) or the friends' is on.
local function AnyShown(friends)
	for kind, on in pairs(Settings().show) do
		if on and (FRIEND_KINDS[kind] == true) == friends then
			return true
		end
	end
	return false
end

-- The client's enemy plates wanted: while any enemy kind is on; with every
-- one off, while an enemy is your target and Your target always is on, so
-- its plate is there to show (the rest stay hidden, their kinds being off).
-- None for whoever chose no plates at all, /splates none.
local function EnemiesWanted()
	local settings = Settings()
	if settings.hidden then
		return false
	end
	if AnyShown(false) then
		return true
	end
	return settings.targetPlate ~= false and UnitExists("target") and UnitCanAttack("player", "target") and true or false
end

-- The client's enemy plates as wanted; its friendly plates while any
-- friend's is, and left as the game has them until one was chosen.
local function ApplyShown()
	local settings = Settings()
	if not EnemiesWanted() then
		HideNameplates()
		NAMEPLATES_ON = nil
	else
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
	if not settings.hidden and AnyShown(true) and ShowFriendNameplates then
		ShowFriendNameplates()
		FRIENDNAMEPLATES_ON = 1
	elseif settings.friendsChosen and HideFriendNameplates then
		HideFriendNameplates()
		FRIENDNAMEPLATES_ON = nil
	end
end

scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
scanner:RegisterEvent("PARTY_MEMBERS_CHANGED")
scanner:RegisterEvent("PLAYER_TARGET_CHANGED")
scanner:SetScript("OnEvent", function()
	if event == "PARTY_MEMBERS_CHANGED" then
		kindsVersion = kindsVersion + 1
		return
	end
	-- A new target: the enemy plates on or off for it (EnemiesWanted), unless
	-- V and Shift+V are left to the player.
	if event == "PLAYER_TARGET_CHANGED" and Settings().keysAllowed then
		return
	end
	ApplyShown()
end)

-- V and Shift+V are the client's own keys, out of any addon's reach. With
-- them ignored (the default; /splates keys, or Options, Nameplates), the
-- plates are put back as chosen here every half second; the friends' plates
-- only once a friend's kind was chosen.
local guardWait = 0
local guard = CreateFrame("Frame")
guard:SetScript("OnUpdate", function()
	guardWait = guardWait + arg1
	if guardWait < 0.5 then
		return
	end
	guardWait = 0
	if Settings().keysAllowed then
		return
	end
	-- Said again every time, not only when it seems to differ: this engine has
	-- no plate CVar and no way to ask whether its plates are on, and it clears
	-- them itself as the world is entered (a game opened with the plates
	-- chosen showed none until a setting was switched, 2026-10-26). The same
	-- word twice changes nothing on its side.
	ApplyShown()
end)

-- Clicks through the plates (the default from v3.0.36): the camera turns
-- from over a plate, and a click goes to the world, where it targets what
-- it lands on; a click on a plate no longer targets. The client lets no
-- addon start the camera's turn (TurnOrActionStart is its own) nor let
-- one button through and not the other, and it gives every plate its
-- mouse back as a camera turn ends: taken away again every frame.
local mouseWatch = CreateFrame("Frame")
mouseWatch:SetScript("OnUpdate", function()
	if not Settings().clickThrough then
		return
	end
	for index = 1, table.getn(overlays) do
		local plate = overlays[index].plate
		if plate:IsMouseEnabled() then
			plate:EnableMouse(false)
		end
	end
end)

local function Restyle()
	for index = 1, table.getn(overlays) do
		ApplyKind(overlays[index], overlays[index].kind or "normal")
	end
end

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("Survivor Plates: "..text)
end

-- Each kind's command (all, friends: the earlier ones) and its name.
local COMMAND_KINDS = { normal = "normal", all = "normal", elites = "elite", guardians = "guardian", bosses = "boss",
	pets = "pet", friends = "pet", totems = "totem", party = "party", coop = "party" }
local KIND_NAMES = { normal = "The rank and file", elite = "Elites", guardian = "Guardians", boss = "Bosses",
	pet = "Your pets and summons", totem = "Your totems", party = "Co-op members" }

BINDING_HEADER_SURVIVORPLATES = "Survivor Plates"
BINDING_NAME_SURVIVORPLATES_TOGGLE = "Nameplates on or off"

SLASH_SURVIVORPLATES1 = "/splates"
SlashCmdList["SURVIVORPLATES"] = function(msg)
	local settings = Settings()
	local _, _, command, argument = string.find(msg or "", "^(%S*)%s*(.*)$")
	local number = tonumber(argument)

	local kind = COMMAND_KINDS[command]
	if kind then
		settings.show[kind] = not settings.show[kind]
		if FRIEND_KINDS[kind] then
			settings.friendsChosen = true
		end
		ApplyShown()
		Say(KIND_NAMES[kind]..(settings.show[kind] and ": plates on." or ": plates off."))
	elseif command == "suggested" then
		-- The setup Survivor UI's options suggest: the friends' plates only.
		-- Enemy plates stack badly on this old engine among so many enemies;
		-- the boss bars follow the bosses, elites and guardians.
		for enemy in pairs(KIND_NAMES) do
			settings.show[enemy] = FRIEND_KINDS[enemy] == true
		end
		settings.friendsChosen = true
		settings.hidden = nil
		ApplyShown()
		Say("the suggested setup: your totems, pets and summons and co-op members' plates on, the enemies' off (the boss bars follow the bosses, elites and guardians).")
	elseif command == "keys" then
		settings.keysAllowed = not settings.keysAllowed
		Say(settings.keysAllowed and "V and Shift+V turn the plates on and off again, as the game has them."
			or "V and Shift+V ignored: the plates stay as chosen here.")
		ApplyShown()
		return
	elseif command == "click" then
		settings.clickThrough = not settings.clickThrough
		-- Off: each plate takes the mouse again at once.
		if not settings.clickThrough then
			for index = 1, table.getn(overlays) do
				overlays[index].plate:EnableMouse(true)
			end
		end
		Say(settings.clickThrough and "clicks go through the plates: the camera turns from over one, and a click on one goes to the world."
			or "a click on a plate targets its enemy again; the camera does not turn from over one.")
		return
	elseif command == "count" then
		-- The plates the client has on screen now, by kind, and how many of them
		-- are drawn: a check of whether it holds back plates past some number.
		local total, drawn, byKind = 0, 0, {}
		for index = 1, table.getn(overlays) do
			local overlay = overlays[index]
			if overlay.plate:IsVisible() then
				total = total + 1
				local kind = overlay.kind or "?"
				byKind[kind] = (byKind[kind] or 0) + 1
				if not overlay.put then
					drawn = drawn + 1
				end
			end
		end
		local parts = {}
		for kind, count in pairs(byKind) do
			table.insert(parts, kind.." "..count)
		end
		Say(total.." plates on screen, "..drawn.." drawn: "..(table.getn(parts) > 0 and table.concat(parts, ", ") or "none")..".")
		return
	elseif command == "target" then
		settings.targetPlate = settings.targetPlate == false
		ApplyShown()
		Say(settings.targetPlate and "your target's plate shows, whatever its kind."
			or "your target's plate only when its kind is on.")
	elseif command == "names" then
		settings.names = not settings.names
		Say("names on "..(settings.names and "every plate" or "elites, guardians and bosses only")..".")
	elseif command == "none" then
		settings.hidden = not settings.hidden
		ApplyShown()
		Say(settings.hidden and "no nameplates." or "nameplates back.")
	elseif command == "scale" and number then
		settings.scale = math.max(0.5, math.min(2, number))
		Say("scale "..settings.scale..".")
	else
		Say("/splates none | normal | elites | guardians | bosses | pets | totems | party | suggested | target | names | keys | click | count | scale 0.5-2")
		return
	end
	Restyle()
end

-- For Survivor UI's options: whether a kind's plates show (normal, elite,
-- guardian, boss, pet, totem, party), the plates' size, quietly.
function SurvivorPlates_Shown(kind)
	return Settings().show[kind] == true
end

-- The key (Bindings.xml): all the plates off, or back, as /splates none.
function SurvivorPlates_Toggle()
	SlashCmdList["SURVIVORPLATES"]("none")
end

function SurvivorPlates_TargetPlate()
	return Settings().targetPlate ~= false
end

function SurvivorPlates_KeysAllowed()
	return Settings().keysAllowed == true
end

function SurvivorPlates_ClickThrough()
	return Settings().clickThrough == true
end

function SurvivorPlates_GetScale()
	return Settings().scale or 1
end

function SurvivorPlates_SetScale(value)
	value = tonumber(value)
	if value then
		Settings().scale = math.max(0.5, math.min(2, math.floor(value * 100 + 0.5) / 100))
		Restyle()
	end
end
