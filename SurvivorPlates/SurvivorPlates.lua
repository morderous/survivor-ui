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
-- By default every enemy carries a plate, and only elites, guardians and
-- bosses carry a name on it.
--
-- Slash commands:
--   /splates all        plates on every enemy, or only on elites, guardians and bosses
--   /splates names      names only on elites, guardians and bosses (default), or on every plate
--   /splates none       no nameplates at all (the default), or back
--   /splates scale N    plate size, 0.6 to 2 (default 1)

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
-- Survivor UI's face when it is installed: a player's own Expressway, else its
-- Barlow Condensed, else Friz Quadrata. This addon loads first, so it tries
-- them itself, each on a probe, since a face that does not load leaves none.
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
	elite    = { width = 130, height = 11, nameSize = 11, color = { 1.00, 0.55, 0.10 } },
	guardian = { width = 150, height = 12, nameSize = 12, color = { 0.20, 0.75, 0.95 } },
	boss     = { width = 170, height = 14, nameSize = 13, color = { 0.72, 0.32, 1.00 } },
}
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
-- list changes. kindsVersion tells the plates to look again.
local liveKind = {}
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
	for index = 1, table.getn(AZS_UNITS) do
		local unit = AZS_UNITS[index]
		local name = Field(unit, "name", 3)
		local kind = Field(unit, "kind", 1)
		kind = (kind == "final" or kind == "boss") and "boss" or "elite"
		if name and not kindByName[name] and liveKind[name] ~= kind then
			liveKind[name] = kind
			changed = true
		end
	end
	if changed then
		kindsVersion = kindsVersion + 1
	end
end

local function Classify(name)
	if not name then
		return "normal"
	end
	return kindByName[name] or liveKind[name] or "normal"
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
	db.scale = db.scale or 1
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
	overlay.name:SetFont(FONT, style.nameSize * scale + FONT_BUMP, "OUTLINE")
	overlay.health:SetFont(FONT, math.max(8, (style.height - 1) * scale) + FONT_BUMP, "OUTLINE")

	overlay.named = settings.names or kind ~= "normal"
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
				icon.count:SetFont(FONT, 9 + FONT_BUMP, "OUTLINE")
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

local function UpdatePlate()
	local overlay = this
	local stock = overlay.stock

	-- The client dims every plate but the target's.
	local isTarget = UnitExists("target") and overlay.plate:GetAlpha() == 1

	local name = stock.name:GetText()
	if name ~= overlay.lastName or overlay.kindsVersion ~= kindsVersion then
		overlay.lastName = name
		overlay.kindsVersion = kindsVersion
		overlay.name:SetText(name)
		overlay.baseKind = Classify(name)
	end
	-- Only the target can be told apart as a guardian; it goes back to an elite
	-- when it is no longer the target.
	local kind = overlay.baseKind
	if isTarget and overlay.targetKind == "guardian" then
		kind = "guardian"
	end
	if kind ~= overlay.kind then
		ApplyKind(overlay, kind)
	end

	-- The rank and file go without a plate, unless one of them is the target.
	if overlay.kind == "normal" and Settings().important and not isTarget then
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
	end

	local low, high = stock.health:GetMinMaxValues()
	local value = stock.health:GetValue()
	local share = high > low and (value - low) / (high - low) or 0
	local percent = math.floor(share * 100 + 0.5)
	overlay.bar:SetValue(share)

	-- A 0 to 100 bar means the client only knows the percentage; anything else
	-- is the unit's real health.
	if high - low == 100 or high <= 1 then
		overlay.health:SetText(percent.."%")
	elseif overlay.kind == "normal" then
		overlay.health:SetText(Short(value))
	else
		overlay.health:SetText(Short(value).." / "..Short(high).."  "..percent.."%")
	end

	local color = overlay.style.color
	if share <= EXECUTE_RANGE then
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
	-- font strings come in that order; the raid icon is the last texture.
	local regions = { plate:GetRegions() }
	local count = table.getn(regions)
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

	overlay.health = overlay.bar:CreateFontString(nil, "OVERLAY")
	overlay.health:SetPoint("RIGHT", overlay.bar, "RIGHT", -2, 0)
	overlay.health:SetTextColor(1, 1, 1)

	ApplyKind(overlay, "normal")
	overlay:SetScript("OnUpdate", UpdatePlate)
	table.insert(overlays, overlay)
end

-- New plates only ever get appended to WorldFrame's children.
local scanned = 0
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	RefreshLiveKinds()
	-- The target's kind, asked once a frame for every plate to read.
	local targetKind = TargetKind()
	for index = 1, table.getn(overlays) do
		overlays[index].targetKind = targetKind
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

-- Enemy nameplates are off by default; a run is unreadable without them. Off
-- again for whoever chose no plates at all (/splates none).
local function ApplyShown()
	if Settings().hidden then
		HideNameplates()
		NAMEPLATES_ON = nil
	else
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
end

scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
scanner:SetScript("OnEvent", ApplyShown)

local function Restyle()
	for index = 1, table.getn(overlays) do
		ApplyKind(overlays[index], overlays[index].kind or "normal")
	end
end

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("Survivor Plates: "..text)
end

SLASH_SURVIVORPLATES1 = "/splates"
SlashCmdList["SURVIVORPLATES"] = function(msg)
	local settings = Settings()
	local _, _, command, argument = string.find(msg or "", "^(%S*)%s*(.*)$")
	local number = tonumber(argument)

	if command == "all" then
		settings.important = not settings.important
		Say(settings.important and "plates on elites, guardians and bosses only." or "plates on every enemy.")
	elseif command == "names" then
		settings.names = not settings.names
		Say("names on "..(settings.names and "every plate" or "elites, guardians and bosses only")..".")
	elseif command == "none" then
		settings.hidden = not settings.hidden
		ApplyShown()
		Say(settings.hidden and "no nameplates." or "nameplates back.")
	elseif command == "scale" and number then
		settings.scale = math.max(0.6, math.min(2, number))
		Say("scale "..settings.scale..".")
	else
		Say("/splates all | names | none | scale 0.6-2")
		return
	end
	Restyle()
end

-- For Survivor UI's options: the plates' size and whether they show, quietly.
function SurvivorPlates_GetScale()
	return Settings().scale or 1
end

function SurvivorPlates_SetScale(value)
	value = tonumber(value)
	if value then
		Settings().scale = math.max(0.6, math.min(2, math.floor(value * 100 + 0.5) / 100))
		Restyle()
	end
end
