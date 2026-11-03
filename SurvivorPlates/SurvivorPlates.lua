-- Survivor Plates - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor Plates: nameplates for Azeroth Survivors, in the manner of the old
-- plates (SurvivorUI Classic's, brought here in v3.0.53 with its corners less
-- round, Lucas 2026-11-02): a thin black line round the bar, the name over it,
-- the health's share small inside. The rank and file in red; the elites, the
-- lair guardians, the bosses and the final boss in the item qualities' colors
-- (uncommon, rare, epic, legendary), each a little larger, with a skull over
-- the name, each meaner. The bosses' plates in front, then the guardians',
-- then the elites', the rank and file a little faded behind. Your target's
-- line is gold, its debuffs over it; the boss bar under the mouse (Survivor
-- UI's) lines its enemy's in white. The plate under the mouse glows, comes to
-- the front of the others and takes the click: with clicks going through the
-- plates it is the only one that does. A friend's plate is thinner, in a gold
-- rim: a member of a co-op run's party in the class's color, told by its name
-- among party1 to party4, every other friend (pets, summons, totems) in mint.
-- A friend down has no plate: the client gives a fallen hero none (seen
-- 2026-10-23), and Survivor UI's party frames say DOWN.
--
-- Each enemy's kind is the game's: the world anchors of the elites, lair
-- guardians and bosses alive (the game's 0.139.2), read four times a second
-- and put on the screen ten times, each claiming the nearest plate of its
-- name (the client seats a plate's middle on its unit's overhead spot, 4
-- points off at most, seen 2026-11-02); and the target's from AZS_UnitKind. A
-- lair guardian is named as its zone's elites, so the name alone can't tell
-- the two. A plate no anchor claims (the layout Stacking moves plates apart)
-- goes by its name: the anchors', the game's list of the run's units
-- (AZS_UNITS, a guardian by its health against an elite of the same name),
-- and the lists below.
--
-- The 1.12 client owns the nameplate frames: they are unnamed children of
-- WorldFrame, recognized by their border texture. Each one is skinned once,
-- its stock art blanked and our own drawn on it from the stock health bar's
-- values. The client keeps a pool of plates and hands them from unit to unit
-- as the enemies come within 20 yards, go and die: in a crowd, every moment.
-- So each plate is read again every frame (its name, its bar's color and
-- health), else one handed on shows its last unit's look for a moment.
--
-- The bars sit exactly where the client seats its plates: position and
-- stacking are the client's own, its Nameplate Layout (the game's 0.131,
-- Options, Nameplates) set to Overlapping once for everyone, and from then on
-- as chosen there or here.
--
-- A raid mark (the game's 0.115; Survivor UI's Raid marks put them on their
-- own) is the client's own icon, the plate's last region, left of the bar: the
-- client hangs it off its wider stock plate's edge, far from the bar. The
-- marks Survivor UI draws on the enemies (its Raid marks, "Draw the enemies'
-- marks") go there too, on a plate its anchor claimed; its World markers then
-- leave that enemy to the plate (SurvivorPlates_PlateShows).
--
-- Each kind is chosen on its own (/splates, or Survivor UI's options): the
-- enemies' four, normal, elites, guardians and bosses (all but the rank and
-- file by default, as SurvivorUI Classic's; a kind left out shows as your
-- target only with /splates target: the game moves the target on its own,
-- and with the rank and file left out its plate jumps from one to the next,
-- asked for by Klopp), and the friends' three, your pets and summons and your
-- totems (asked for on Discord by Sedz and Amarolk, with a warlock's many
-- demons about) and the members of a co-op run's party (the game's 0.113;
-- asked for by Klopp and ChaoticBon), all on by default. A plate left out has
-- its bar hidden, the plate itself untouched: the client keeps it, and its
-- target's light (the target's plate the one at full alpha).
--
-- Slash commands:
--   /splates none       no nameplates at all, or back (the default)
--   /splates normal | elites | guardians | bosses     each enemy kind, on or off
--   /splates pets | totems | party                    each friend's, on or off
--   /splates target     the target's plate though its kind is left out, or not (the default)
--   /splates names      names on every plate (the default), or only on elites, guardians, bosses and friends
--   /splates keys       V and Shift+V ignored (default), or let them work as the game has them
--   /splates click      clicks go through the plates but the one under the mouse (default), or every plate takes them
--   /splates overlap    plates stay right over their enemies (default), or move apart in a crowd
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
local ART = "Interface\\AddOns\\SurvivorPlates\\Art\\"
-- Our rounded bar (bot\ferramentas\make_plate_round.py --plates), drawn in
-- three pieces: the left end, the middle, the right end.
local ROUND = ART.."PlateRound"
local END = 0.25                 -- each round end's share of the art across
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

-- Each kind's plate, SurvivorUI Classic's: the enemies' names a fifth smaller
-- and their bars a tenth than its first ones (Lucas, 2026-11-02). A skull over
-- the name, three of them, each meaner: our plain bone one over an elite's,
-- the minimap's for lairs over a guardian's, our infernal one over a boss's.
-- Each kind's plate raised over the rest by `rise` frame levels (Lucas: the
-- bosses in front, then the guardians, then the elites).
local KINDS = {
	normal   = { width = 81,  height = 8,  name = 8,  share = 7, color = { 0.77, 0.12, 0.12 } },
	elite    = { width = 95,  height = 9,  name = 9,  share = 7, color = { 0.12, 0.72, 0.12 },
		skull = "EliteSkull", skullSize = 14, rise = 10 },
	guardian = { width = 106, height = 10, name = 9,  share = 8, color = { 0.00, 0.44, 0.87 },
		skull = "MinimapSkull", skullSize = 16, rise = 20 },
	boss     = { width = 119, height = 11, name = 10, share = 8, color = { 0.64, 0.21, 0.93 },
		skull = "BossSkull", skullSize = 22, rise = 30 },
	final    = { width = 128, height = 11, name = 10, share = 8, color = { 1.00, 0.50, 0.00 },
		skull = "BossSkull", skullSize = 22, rise = 30 },
	-- The friends' bars 30% thinner and their names a fifth smaller, in a
	-- gold rim (Lucas, 2026-11-02): the party in the class's color (this one
	-- only with the class unknown), the pets, summons and totems in mint,
	-- apart from the elites' green.
	party    = { width = 81,  height = 5.5, name = 6.4, share = 5, rim = true, color = { 0.45, 0.78, 1.00 } },
	pet      = { width = 81,  height = 5.5, name = 6.4, share = 5, rim = true, color = { 0.30, 0.88, 0.62 } },
	totem    = { width = 81,  height = 5.5, name = 6.4, share = 5, rim = true, color = { 0.30, 0.88, 0.62 } },
}
local FRIEND_KINDS = { pet = true, totem = true, party = true }
local FADE = 0.75                -- the rank and file's colors, behind the rest
-- Each enemy kind's switch (the final boss's is the bosses'), and its mark's
-- in Survivor UI's Raid marks.
local SWITCH = { normal = "normal", elite = "elite", guardian = "guardian", boss = "boss", final = "boss" }
local MARKED = { elite = "elite", guardian = "guardian", boss = "boss", final = "boss" }
-- The kinds as the anchors, AZS_UNITS and AZS_UnitKind name them.
local KIND_OF = { elite = "elite", guardian = "guardian", boss = "boss", finalBoss = "final", final = "final",
	normal = "normal" }
local QUERY = { kinds = { "elite", "guardian", "boss", "finalBoss" }, states = { "alive" } }
local READ_EVERY = 0.25          -- the anchors' catalog
local CLAIM_EVERY = 0.1          -- their spots on the screen
local CLAIM_LASTS = 0.6          -- a plate's claim, unclaimed since
local NEAR = 24                  -- the farthest a plate sits from its unit's overhead spot
local HOVER_RISE = 40            -- the plate under the mouse, over the others

-- The line round the bar: black, your target's gold, the one the boss bar
-- lines white. A friend's a rim of gold in its place (PlateGold), to tell
-- them from the enemies: the rim RIM of its art's height on each side, the
-- bar in its hollow.
local EDGES = { none = { 0, 0, 0 }, target = { 1, 0.82, 0 }, lit = { 1, 1, 1 } }
local RIM = 5 / 32

local function ClassColor(class)
	if SurvivorUI_ClassColor then
		local r, g, b = SurvivorUI_ClassColor(class)
		return r and { r, g, b } or nil
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
			kind = (kind == "final" or kind == "boss") and kind or "elite"
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
	-- From v3.0.53 the new plates, on once for everyone with SurvivorUI
	-- Classic's defaults (Lucas, 2026-11-02): the rank and file off; elites,
	-- guardians, bosses and every friend on; a name on every plate; a target
	-- of a kind left out without one.
	if db.defaults < 4 then
		db.defaults = 4
		db.hidden = nil
		db.show.normal = false
		db.show.elite, db.show.guardian, db.show.boss = true, true, true
		db.show.pet, db.show.totem, db.show.party = true, true, true
		db.friendsChosen = true
		db.names = true
		db.targetPlate = false
	end
	db.scale = db.scale or 1
	-- From v3.0.36 clicks go through the plates, as asked on Discord.
	if db.clickThrough == nil then
		db.clickThrough = true
	end
	return db
end

local overlays = {}
local visible, shownCount = {}, 0 -- the plates on the screen, this frame
local anchors, named = {}, {}    -- the anchors alive; their kinds by name
local lit, litId, litOverlay     -- the enemy to line: its name, its unit's id, its plate
local hovered                    -- the plate under the mouse
local targetName, targetKind

-- Other addons find the plates here: the art a plate is recognized by is
-- blanked once it is skinned. Each entry has .plate and .stock.name.
SurvivorPlatesRegistry = overlays

-- A name's kind in a list, "mixed" for a name two kinds share.
local function Mark(list, name, kind)
	if list[name] and list[name] ~= kind then
		list[name] = "mixed"
	else
		list[name] = kind
	end
end

local function ReadAnchors()
	local found, kinds, cursor = {}, {}, nil
	for page = 1, 4 do
		local ok, result = pcall(AZS_GetWorldAnchors, QUERY, cursor, 256)
		if not ok or not result or not result.entries then
			return
		end
		for index = 1, table.getn(result.entries) do
			local entry = result.entries[index]
			local kind = KIND_OF[entry.kind or ""]
			if kind and entry.name and entry.anchorId then
				table.insert(found, { id = entry.anchorId, kind = kind, name = entry.name,
					unit = entry.unitId and tostring(entry.unitId) })
				Mark(kinds, entry.name, kind)
			end
		end
		if not result.hasMore or not result.nextCursor then
			break
		end
		cursor = result.nextCursor
	end
	anchors, named = found, kinds
end

-- Each anchor on the screen claims the nearest plate of its name, one plate
-- each, in WorldFrame's units (the plates are its children).
local function Claim()
	local count = table.getn(anchors)
	if count == 0 or count > 256 or shownCount == 0 then
		return
	end
	local requests = {}
	for index = 1, count do
		requests[index] = { anchorId = anchors[index].id, attachment = "overhead", offset = { x = 0, y = 0, z = 0 } }
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, requests)
	local entries = ok and result and result.entries
	if not entries then
		return
	end
	local world, now, taken = WorldFrame:GetEffectiveScale(), GetTime(), {}
	for index = 1, count do
		local spot, anchor = entries[index], anchors[index]
		if spot and spot.state == "onScreen" and spot.x then
			local best, bestFar
			for each = 1, shownCount do
				local overlay = visible[each]
				if overlay.lastName == anchor.name and not taken[overlay] then
					local x, y = overlay.plate:GetCenter()
					if x then
						local scale = overlay.plate:GetEffectiveScale() / world
						local dx, dy = x * scale - spot.x, y * scale - spot.y
						local far = dx * dx + dy * dy
						if far <= NEAR * NEAR and (not bestFar or far < bestFar) then
							best, bestFar = overlay, far
						end
					end
				end
			end
			if best then
				taken[best] = true
				best.claim, best.claimName, best.claimAt, best.unit = anchor.kind, anchor.name, now, anchor.unit
			end
		end
	end
end

-- Whether a unit's plate is on the screen with its bar drawn, by its unit's
-- id (an anchor's unitId, as a string): Survivor UI's World markers leave
-- that enemy to the plate.
function SurvivorPlates_PlateShows(unit)
	local now = GetTime()
	for index = 1, shownCount do
		local overlay = visible[index]
		if overlay.unit == unit and overlay.shown and overlay.claimName == overlay.lastName
				and now - overlay.claimAt < CLAIM_LASTS then
			return true
		end
	end
	return false
end

-- The enemy Survivor UI's boss bar under the mouse is, by its name and its
-- unit's id; nil for none.
function SurvivorPlates_Light(name, id)
	lit = name
	litId = name and id and tostring(id) or nil
end

-- Three pieces of the rounded art: the left end, the middle, the right end.
local function Strip(parent, layer, art)
	local strip = {}
	for index = 1, 3 do
		strip[index] = parent:CreateTexture(nil, layer)
		strip[index]:SetTexture(art or ROUND)
	end
	strip[2]:SetTexCoord(END, 1 - END, 0, 1)
	return strip
end

local function Tint(strip, r, g, b, a)
	for index = 1, 3 do
		strip[index]:SetVertexColor(r, g, b, a)
	end
end

-- Every piece's color at the plate's own alpha: the rank and file a little
-- faded behind the rest, your target never. The client dims every plate but
-- the target's with the plate's alpha, and in this game a frame's alpha takes
-- the place of its children's, not multiplied: so the fading is in the colors.
local function Paint(overlay)
	local a, edge = overlay.fade, EDGES[overlay.edge]
	local color = overlay.color or overlay.style.color
	Tint(overlay.line, edge[1], edge[2], edge[3], a)
	-- The rim a little dull, bright on your target.
	local shine = overlay.edge == "target" and 1 or 0.85
	Tint(overlay.gold, shine, shine, shine, a)
	Tint(overlay.back, 0.06, 0.06, 0.06, a)
	Tint(overlay.fill, color[1], color[2], color[3], a)
	overlay.name:SetTextColor(1, 1, 1, a)
	overlay.share:SetTextColor(1, 1, 1, a)
	overlay.skull:SetVertexColor(1, 1, 1, a)
	overlay.painted = true
end

local function Piece(piece, holder, left, width, height, from, to)
	if width < 0.5 then
		piece:Hide()
		return
	end
	piece:ClearAllPoints()
	piece:SetPoint("LEFT", holder, "LEFT", left, 0)
	piece:SetWidth(width)
	piece:SetHeight(height)
	if from then
		piece:SetTexCoord(from, to, 0, 1)
	end
	piece:Show()
end

-- A strip `width` across and `height` tall, `left` from its holder's left
-- edge, drawn `filled` across from its left: the ends as the art has them, a
-- fill short of the right end cut square.
local function Lay(strip, holder, left, width, height, filled)
	local cap = math.min(height, width) / 2
	local first = math.min(filled, cap)
	local middle = math.min(math.max(filled - cap, 0), width - 2 * cap)
	local last = math.max(filled - (width - cap), 0)
	Piece(strip[1], holder, left, first, height, 0, END * first / cap)
	Piece(strip[2], holder, left + cap, middle, height)
	Piece(strip[3], holder, left + width - cap, last, height, 1 - END, 1 - END + END * last / cap)
end

-- Debuffs on the target's plate, with their stacks. The 1.12 client only tells
-- an addon about the debuffs of a unit it can name, and of all the plates on
-- screen only the target's can be told apart (it alone keeps full alpha).
local PLATE_DEBUFFS = 6
local DEBUFF_SIZE = 15

-- The bosses' plates over the guardians', theirs over the elites', and those
-- over the rest: in a crowd the plate that matters is in front; the one under
-- the mouse over them all. The game draws every frame by its own strata and
-- level, and a frame's level does not carry down to its children, so each one
-- is raised.
local function Raise(overlay)
	local rise = overlay.level + (overlay.style.rise or 0) + (overlay == hovered and HOVER_RISE or 0)
	overlay.plate:SetFrameLevel(rise)
	overlay:SetFrameLevel(rise + 1)
	overlay.bar:SetFrameLevel(rise + 2)
	local icons = overlay.debuffs
	if icons then
		for index = 1, PLATE_DEBUFFS do
			if icons[index] then
				icons[index]:SetFrameLevel(rise + 3)
			end
		end
	end
end

-- The soft glow round the bar of the plate under the mouse, as far out as
-- the bar is tall (the art's hollow is half its height).
local function Glow(overlay, on)
	if on then
		local width, height = overlay.width, overlay.height
		Lay(overlay.glow, overlay.bar, -height / 2, width + height, height * 2, width + height)
	else
		for index = 1, 3 do
			overlay.glow[index]:Hide()
		end
	end
end

-- The client's raid icon and the mark Survivor UI draws, left of the bar, as
-- tall as the bar and a little more. The client sets its icon's anchor again
-- when the window changes size, so it is put back each time a mark shows.
local function PlaceMarks(overlay)
	local size = math.max(14, (overlay.style.height + 8) * Settings().scale)
	local raid = overlay.stock.raid
	if raid then
		raid:ClearAllPoints()
		raid:SetPoint("RIGHT", overlay.bar, "LEFT", -3, 0)
		raid:SetWidth(size)
		raid:SetHeight(size)
	end
	overlay.mark:SetWidth(size)
	overlay.mark:SetHeight(size)
end

local function Dress(overlay, kind)
	local style = KINDS[kind]
	local settings = Settings()
	local scale = settings.scale
	local width, height = style.width * scale, style.height * scale
	overlay.kind, overlay.style = kind, style
	overlay.width, overlay.height = width, height
	overlay.bar:SetWidth(width)
	overlay.bar:SetHeight(height)
	local face = SurvivorUI_FONT or FONT
	overlay.name:SetFont(face, style.name * scale + FONT_BUMP, "OUTLINE")
	if style.rim then
		local tall = height / (1 - 2 * RIM)
		local out = (tall - height) / 2
		Lay(overlay.gold, overlay.bar, -out, width + 2 * out, tall, width + 2 * out)
		Lay(overlay.line, overlay.bar, -1, width + 2, height + 2, 0)
	else
		Lay(overlay.gold, overlay.bar, 0, width, height, 0)
		Lay(overlay.line, overlay.bar, -1, width + 2, height + 2, width + 2)
	end
	Lay(overlay.back, overlay.bar, 0, width, height, width)
	-- In the bar's middle up and down: the digits sit low in their line, an
	-- eighth of the font's size (seen 2026-11-02, the friends' thin bars).
	local share = style.share * scale + FONT_BUMP
	overlay.share:SetFont(face, share, "OUTLINE")
	overlay.share:ClearAllPoints()
	overlay.share:SetPoint("RIGHT", overlay.bar, "RIGHT", -3 * scale, share * 0.12)
	overlay.named = settings.names or kind ~= "normal"
	if overlay.named then
		overlay.name:Show()
	else
		overlay.name:Hide()
	end
	if style.skull and overlay.named then
		local size = style.skullSize * scale
		overlay.skull:SetTexture(ART..style.skull)
		overlay.skull:SetWidth(size)
		overlay.skull:SetHeight(size)
		overlay.skull:Show()
	else
		overlay.skull:Hide()
	end
	Raise(overlay)
	Glow(overlay, overlay == hovered)
	PlaceMarks(overlay)
	overlay.across, overlay.percent, overlay.painted = nil, nil, nil
end

local function UpdatePlateDebuffs(overlay, isTarget, settings)
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

	-- Over the name and its skull.
	local style, scale = overlay.style, settings.scale
	local lift = 4
	if overlay.named then
		lift = lift + style.name * scale + 3
		if style.skull then
			lift = lift + style.skullSize * scale
		end
	end
	for index = 1, PLATE_DEBUFFS do
		local texture, count = UnitDebuff("target", index)
		local icon = icons[index]
		if texture then
			if not icon then
				icon = CreateFrame("Frame", nil, overlay.bar)
				icon:SetFrameLevel(overlay.bar:GetFrameLevel() + 1)
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

local function Update(overlay, settings, hasTarget, now)
	local stock = overlay.stock

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
		local known = low and high and high - low ~= 100 and high > 1
		overlay.baseKind = friend and FriendKind(name) or Classify(name, known and high or nil)
		overlay.color = overlay.baseKind == "party" and ClassColor(PartyClass(name)) or nil
		overlay.painted = nil
	end

	-- The target's plate: the one at full alpha, the others dimmed. With the
	-- target out of the plates' reach the client leaves them all at full
	-- alpha (seen 2026-11-02), so it takes being the only one, and its name.
	local isTarget = hasTarget and overlay.plate:GetAlpha() == 1 and name == targetName
	-- An enemy's kind: its anchor's, else the target's as the game tells it,
	-- else its name's.
	local kind, sure = overlay.baseKind, false
	if not FRIEND_KINDS[kind] then
		if overlay.claim and overlay.claimName == name and now - overlay.claimAt < CLAIM_LASTS then
			kind, sure = overlay.claim, true
		elseif isTarget and targetKind then
			kind = targetKind
		elseif named[name] and named[name] ~= "mixed" then
			kind = named[name]
		end
	end
	if kind ~= overlay.kind then
		Dress(overlay, kind)
	end

	-- A kind left out goes without its bar; an enemy's still shows as the
	-- target if asked, and always as the one the boss bar under the mouse lines.
	local switch = SWITCH[kind]
	local shown
	if switch then
		shown = settings.show[switch] or overlay == litOverlay or (isTarget and settings.targetPlate ~= false)
	else
		shown = settings.show[kind]
	end
	shown = shown and true or false
	if shown ~= overlay.shown then
		overlay.shown = shown
		if shown then
			overlay.bar:Show()
		else
			overlay.bar:Hide()
		end
		if stock.raid then
			stock.raid:SetAlpha(shown and 1 or 0)
		end
	end
	if not shown then
		return
	end

	local share = 0
	if low and high and high > low then
		share = math.max(0, math.min(1, (stock.health:GetValue() - low) / (high - low)))
	end
	local across = math.floor(share * overlay.width * 2 + 0.5) / 2
	if across ~= overlay.across then
		overlay.across = across
		Lay(overlay.fill, overlay.bar, 0, overlay.width, overlay.height, across)
	end
	local percent = math.floor(share * 100 + 0.5)
	if percent == 0 and share > 0 then
		percent = 1
	end
	if percent ~= overlay.percent then
		overlay.percent = percent
		overlay.share:SetText(percent.."%")
	end

	local edge = (overlay == litOverlay and "lit") or (isTarget and "target") or "none"
	local fade = (kind == "normal" and not isTarget and overlay ~= litOverlay) and FADE or 1
	if edge ~= overlay.edge or fade ~= overlay.fade or not overlay.painted then
		overlay.edge, overlay.fade = edge, fade
		Paint(overlay)
	end

	local marked = stock.raid and stock.raid:IsShown() and true or false
	if marked and not overlay.marked then
		PlaceMarks(overlay)
	end
	overlay.marked = marked
	-- The mark Survivor UI draws on this kind, on a plate its anchor claimed
	-- (its World markers leave that enemy to the plate then), unless the
	-- client's own shows.
	local drawn = sure and not marked and MARKED[kind] and SurvivorUI_MarksDrawn and SurvivorUI_MarksDrawn()
		and SurvivorUI_AutoMarkOn(MARKED[kind]) and SurvivorUI_AutoMarkIcon(MARKED[kind]) or nil
	if drawn ~= overlay.drawn then
		overlay.drawn = drawn
		if drawn and SurvivorUI_SetRaidMarkTexture then
			SurvivorUI_SetRaidMarkTexture(overlay.mark, drawn)
			overlay.mark:Show()
		else
			overlay.mark:Hide()
		end
	end
	UpdatePlateDebuffs(overlay, isTarget, settings)
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
	overlay.level = plate:GetFrameLevel()
	plate.survivorOverlay = overlay

	overlay.bar = CreateFrame("Frame", nil, overlay)
	overlay.bar:SetPoint("CENTER", overlay, "CENTER", 0, -4)
	overlay.line = Strip(overlay.bar, "BACKGROUND")
	overlay.back = Strip(overlay.bar, "BORDER")
	overlay.fill = Strip(overlay.bar, "ARTWORK")
	-- Under the bar (on the frame below it), its light added
	-- (make_plate_glow.py --plates).
	overlay.glow = Strip(overlay, "BACKGROUND", ART.."PlateGlow")
	for index = 1, 3 do
		overlay.glow[index]:SetBlendMode("ADD")
		overlay.glow[index]:SetVertexColor(1, 0.92, 0.70, 0.9)
		overlay.glow[index]:Hide()
	end
	-- Over the bar's edge, the bar in its hollow (make_plate_gold.py --plates).
	overlay.gold = Strip(overlay.bar, "OVERLAY", ART.."PlateGold")

	overlay.name = overlay.bar:CreateFontString(nil, "OVERLAY")
	overlay.name:SetPoint("BOTTOM", overlay.bar, "TOP", 0, 2)
	overlay.share = overlay.bar:CreateFontString(nil, "OVERLAY")
	overlay.share:SetShadowOffset(0, 0)
	overlay.skull = overlay.bar:CreateTexture(nil, "OVERLAY")
	overlay.skull:SetPoint("BOTTOM", overlay.name, "TOP", 0, 0)
	overlay.skull:Hide()
	-- The mark Survivor UI draws, where the client's raid icon goes.
	overlay.mark = overlay.bar:CreateTexture(nil, "OVERLAY")
	overlay.mark:SetPoint("RIGHT", overlay.bar, "LEFT", -3, 0)
	overlay.mark:Hide()

	overlay.shown, overlay.edge, overlay.fade, overlay.claimAt = true, "none", 1, 0
	Dress(overlay, "normal")
	table.insert(overlays, overlay)
end

-- The plate to line: the one its unit's anchor claimed, else the first of
-- its name.
local function Lit()
	if not lit then
		return nil
	end
	local first
	for index = 1, shownCount do
		local overlay = visible[index]
		if litId and overlay.unit == litId and overlay.claimName == overlay.lastName then
			return overlay
		end
		if not first and overlay.lastName == lit then
			first = overlay
		end
	end
	return first
end

-- The plate under the mouse, read by hand: with clicks going through the plates
-- none of them hears it. The nearest to the mouse, of those with their bar
-- drawn whose bar or name it is on; none with the mouse on a window. Asked 20
-- times a second.
local hoverWait = 0

local function PlateUnderMouse()
	local focus = GetMouseFocus and GetMouseFocus()
	if focus and focus ~= WorldFrame and not focus.survivorOverlay then
		return nil
	end
	local x, y = GetCursorPosition()
	local best, bestGap
	for index = 1, shownCount do
		local overlay = visible[index]
		if overlay.shown then
			local scale = overlay.bar:GetEffectiveScale()
			local atX, atY = x / scale, y / scale
			local left, right = overlay.bar:GetLeft(), overlay.bar:GetRight()
			local bottom, top = overlay.bar:GetBottom(), overlay.bar:GetTop()
			if left and bottom then
				if overlay.named then
					top = overlay.name:GetTop() or top
				end
				if atX >= left - 2 and atX <= right + 2 and atY >= bottom - 2 and atY <= top + 2 then
					local gap = math.abs(atX - (left + right) / 2) + math.abs(atY - (top + bottom) / 2)
					if not bestGap or gap < bestGap then
						best, bestGap = overlay, gap
					end
				end
			end
		end
	end
	return best
end

local function SetHovered(overlay)
	if overlay == hovered then
		return
	end
	local was = hovered
	hovered = overlay
	if was then
		Glow(was, false)
		Raise(was)
		if Settings().clickThrough then
			was.plate:EnableMouse(false)
		end
	end
	if overlay then
		Glow(overlay, true)
		Raise(overlay)
		overlay.plate:EnableMouse(true)
	end
end

-- The tests find the plate under the mouse here.
function SurvivorPlates_HoveredPlate()
	return hovered
end

-- The game's Nameplate Layout (its 0.131): nil on a game without it.
local function Layout()
	local known, value = pcall(GetCVar, "nameplateLayout")
	return known and value or nil
end

function SurvivorPlates_Overlapping()
	return Layout() == "overlap"
end

function SurvivorPlates_LayoutThere()
	return Layout() ~= nil
end

function SurvivorPlates_SetOverlapping(on)
	if Layout() then
		SetCVar("nameplateLayout", on and "overlap" or "stack")
	end
end

-- New plates only ever get appended to WorldFrame's children.
local scanned = 0
local partyCount = 0
local readWait, claimWait = READ_EVERY, CLAIM_EVERY
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	RefreshLiveKinds()

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

	shownCount = 0
	local bright = 0
	for index = 1, table.getn(overlays) do
		local plate = overlays[index].plate
		if plate:IsVisible() then
			shownCount = shownCount + 1
			visible[shownCount] = overlays[index]
			if plate:GetAlpha() == 1 then
				bright = bright + 1
			end
		end
	end
	if AZS_GetWorldAnchors and AZS_ProjectWorldAnchors then
		readWait = readWait + arg1
		if readWait >= READ_EVERY then
			readWait = 0
			ReadAnchors()
		end
		claimWait = claimWait + arg1
		if claimWait >= CLAIM_EVERY then
			claimWait = 0
			Claim()
		end
	end
	local hasTarget = UnitExists("target") and bright == 1
	targetName = hasTarget and UnitName("target") or nil
	targetKind = hasTarget and AZS_UnitKind and KIND_OF[AZS_UnitKind("target") or ""] or nil
	litOverlay = Lit()
	local settings, now = Settings(), GetTime()
	for index = 1, shownCount do
		Update(visible[index], settings, hasTarget, now)
	end

	hoverWait = hoverWait + arg1
	if hoverWait >= 0.05 then
		hoverWait = 0
		SetHovered(PlateUnderMouse())
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
	-- Overlapping for everyone, once; after that it is whoever's choice.
	if not Settings().layoutSet and Layout() then
		Settings().layoutSet = true
		SurvivorPlates_SetOverlapping(true)
	end
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
-- it lands on. The client lets no addon start the camera's turn
-- (TurnOrActionStart is its own) nor let one button through and not the
-- other, and it gives every plate its mouse back as a camera turn ends: taken
-- away again every frame, but from the plate the mouse is on, which targets.
local mouseWatch = CreateFrame("Frame")
mouseWatch:SetScript("OnUpdate", function()
	if not Settings().clickThrough then
		return
	end
	for index = 1, table.getn(overlays) do
		local plate = overlays[index].plate
		if plate:IsMouseEnabled() and overlays[index] ~= hovered then
			plate:EnableMouse(false)
		end
	end
end)

local function Restyle()
	for index = 1, table.getn(overlays) do
		Dress(overlays[index], overlays[index].kind or "normal")
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
		-- The setup Survivor UI's options once suggested: the friends' plates
		-- only, the boss bars following the bosses, elites and guardians.
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
	elseif command == "overlap" then
		SurvivorPlates_SetOverlapping(not SurvivorPlates_Overlapping())
		Say(SurvivorPlates_Overlapping() and "plates stay right over their enemies, on top of each other in a crowd."
			or "plates move apart in a crowd.")
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
				if overlay.shown then
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
		Say("names on "..(settings.names and "every plate" or "elites, guardians, bosses and friends only")..".")
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
