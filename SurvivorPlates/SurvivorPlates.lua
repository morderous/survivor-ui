-- Survivor Plates: nameplates in the manner of Plater, for Azeroth Survivors.
-- A flat health bar on a dark backing with a thin black border, the name above
-- it, the unit's health on it, an execute-range marker, and a highlighted
-- target with its debuffs. Elites, guardians and bosses get larger plates in their own colors.
--
-- The 1.12 client owns the nameplate frames: they are unnamed children of
-- WorldFrame, recognized by their border texture. Each one is skinned once,
-- its stock art blanked and an overlay drawn from the stock health bar's
-- values. The client recycles a plate for another unit, so the overlay
-- re-reads the name every frame.
--
-- The client seats a plate on its unit's head every frame, unsmoothed, so a
-- crowd of plates shakes and overlaps. The bars here are laid out by the addon
-- instead: each one follows its plate with a little lag, and bars that would
-- overlap are stacked upward.
--
-- Slash commands:
--   /splates names      names on every plate, or only on elites and bosses
--   /splates scale N    plate size, 0.6 to 2 (default 1)
--   /splates stack      stacking and smoothing on or off
--   /splates smooth N   how closely a bar follows its unit, 2 (calm) to 30 (tight), default 9
--   /splates spread N   room between stacked bars, 0.8 to 3 (default 1.2)

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"
local BORDER_TEXTURE = "Interface\\Tooltips\\Nameplate-Border"

local EXECUTE_RANGE = 0.30      -- the game's execute effects start below this share of health
local DEADZONE = 1.5            -- a unit's plate may drift this far before its bar follows

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

-- The elites of each zone's horde.
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

local function Classify(name)
	if not name then
		return "normal"
	end
	-- A guardian's plate reads "<name> (Guardian)".
	if string.find(name, "(Guardian)", 1, true) then
		return "guardian"
	end
	return kindByName[name] or "normal"
end

local function Settings()
	SurvivorPlatesDB = SurvivorPlatesDB or {}
	local db = SurvivorPlatesDB
	if db.names == nil then
		db.names = true
	end
	if db.stack == nil then
		db.stack = true
	end
	db.scale = db.scale or 1
	db.smooth = db.smooth or 9
	db.spread = db.spread or 1.2
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
	overlay.name:SetFont(FONT, style.nameSize * scale, "OUTLINE")
	overlay.health:SetFont(FONT, math.max(8, (style.height - 1) * scale), "OUTLINE")

	overlay.named = settings.names or kind ~= "normal"
	if overlay.named then
		overlay.name:Show()
	else
		overlay.name:Hide()
	end

	-- The room the bar and its name take, for stacking.
	overlay.boxWidth = style.width * scale + 8
	overlay.boxHeight = style.height * scale + 4 + (overlay.named and (style.nameSize * scale + 3) or 0)
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
				icon.count:SetFont(FONT, 9, "OUTLINE")
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

	local name = stock.name:GetText()
	if name ~= overlay.lastName then
		overlay.lastName = name
		overlay.name:SetText(name)
		ApplyKind(overlay, Classify(name))
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

	-- The client dims every plate but the target's.
	local isTarget = UnitExists("target") and overlay.plate:GetAlpha() == 1
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
	-- A recycled plate starts where its new unit is, not where the last one was.
	overlay:SetScript("OnShow", function() this.x = nil end)
	table.insert(overlays, overlay)
end

------------------------------------------------------------------------------
-- Layout: every visible bar follows its plate with a little lag, and bars that
-- would overlap are stacked upward, nearest the bottom of the screen first.

local visible = {}

local function ByHeight(a, b)
	if a.wantY ~= b.wantY then
		return a.wantY < b.wantY
	end
	return a.wantX < b.wantX
end

local function Layout(elapsed)
	local settings = Settings()

	local count = 0
	for index = 1, table.getn(overlays) do
		local overlay = overlays[index]
		if overlay:IsVisible() then
			local x, y = overlay.plate:GetCenter()
			if x and y then
				-- Small drifts are ignored: a walking unit's head bobs every frame.
				if not overlay.wantX or math.abs(x - overlay.wantX) > DEADZONE or math.abs(y - overlay.wantY) > DEADZONE then
					overlay.wantX, overlay.wantY = x, y
				end
				count = count + 1
				visible[count] = overlay
			end
		end
	end
	for index = count + 1, table.getn(visible) do
		visible[index] = nil
	end
	if count == 0 then
		return
	end

	table.sort(visible, ByHeight)

	-- Each bar takes the lowest spot at or above its unit that clears the bars already placed.
	for index = 1, count do
		local overlay = visible[index]
		local x, y = overlay.wantX, overlay.wantY
		local moved = true
		local guard = 0
		while moved and guard < 12 do
			moved = false
			guard = guard + 1
			for other = 1, index - 1 do
				local placed = visible[other]
				local reachX = (overlay.boxWidth + placed.boxWidth) / 2
				local reachY = (overlay.boxHeight + placed.boxHeight) / 2 * settings.spread
				if math.abs(x - placed.placeX) < reachX and math.abs(y - placed.placeY) < reachY then
					y = placed.placeY + reachY
					moved = true
				end
			end
		end
		overlay.placeX, overlay.placeY = x, y
	end

	local follow = math.min(1, elapsed * settings.smooth)
	for index = 1, count do
		local overlay = visible[index]
		if not overlay.x then
			overlay.x, overlay.y = overlay.placeX, overlay.placeY
		else
			overlay.x = overlay.x + (overlay.placeX - overlay.x) * follow
			overlay.y = overlay.y + (overlay.placeY - overlay.y) * follow
		end
		overlay.bar:ClearAllPoints()
		overlay.bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", overlay.x, overlay.y - 4)
		overlay.laidOut = true
	end
end

-- Back to the client's seat, for when the layout is switched off.
local function Unlayout()
	for index = 1, table.getn(overlays) do
		local overlay = overlays[index]
		if overlay.laidOut then
			overlay.laidOut = nil
			overlay.x = nil
			overlay.bar:ClearAllPoints()
			overlay.bar:SetPoint("CENTER", overlay, "CENTER", 0, -4)
		end
	end
end

-- New plates only ever get appended to WorldFrame's children.
local scanned = 0
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
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

	if Settings().stack then
		Layout(arg1)
	end
end)

-- Enemy nameplates are off by default; a run is unreadable without them.
scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
scanner:SetScript("OnEvent", function()
	ShowNameplates()
	NAMEPLATES_ON = 1
end)

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

	if command == "names" then
		settings.names = not settings.names
		Say("names on "..(settings.names and "every plate" or "elites, guardians and bosses only")..".")
	elseif command == "scale" and number then
		settings.scale = math.max(0.6, math.min(2, number))
		Say("scale "..settings.scale..".")
	elseif command == "stack" then
		settings.stack = not settings.stack
		if not settings.stack then
			Unlayout()
		end
		Say("stacking and smoothing "..(settings.stack and "on" or "off")..".")
	elseif command == "smooth" and number then
		settings.smooth = math.max(2, math.min(30, number))
		Say("smooth "..settings.smooth.." (lower is calmer).")
	elseif command == "spread" and number then
		settings.spread = math.max(0.8, math.min(3, number))
		Say("spread "..settings.spread..".")
	else
		Say("/splates names | scale 0.6-2 | stack | smooth 2-30 | spread 0.8-3")
		return
	end
	Restyle()
end
