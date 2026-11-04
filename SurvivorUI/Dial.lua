-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the Tracker Ring, a look of the run tracker (the options,
-- Experimental: Tracker Ring; the Classic lines by default).
--
-- Drawn in the tracker's own frame (Tracker.lua's SurvivorUITracker) in place
-- of its lines, so it keeps the tracker's place, size, move mode, switch and
-- "While choosing cards": a round dial for the run's time and its spawns. Its
-- outer ring is the whole run, from 0:00 at the top clockwise to the run's
-- length, filling as time goes (green, or the class's color; purple in
-- endless mode); each boss a mark on it at its second: slain dimmed with a
-- tick, the next glowing orange with its second by it, one alive pulsing in
-- violet (orange for the final boss), the final boss its horned skull. The
-- thin ring inside empties until the next boss comes, a boss alive or not. In
-- the middle the run's tags, always short (the difficulty's numeral, endless
-- mode's symbol, the affixes' symbols; each side shown or off on the Tracker Ring
-- page, apart from the Classic lines' own looks), the clock big, "of 16:00",
-- and the next boss with the time until it comes; while a boss is alive its
-- name and its health in % in that line ("Ragnaros 63%"), and the disc a
-- shade of violet. No health ring (Lucas, 2026-11-04): the nameplates and the
-- boss bars have it. A name too long for its place in the circle goes
-- smaller, down to a floor, then short, the % always whole after it.
--
-- Under the dial, the guardians' compass (the Dial's Compass, on by default):
-- a tile a lair (Guardians.lua's SurvivorUI_GuardianCompass), an arrow toward
-- it (as the guardians' bar turns it, North up as chosen) and how far (the
-- Dial's Distance, on by default); green while its guardian is up, orange in a
-- fight with its health in % where the arrow stands, grey and dim while slain,
-- a red clock emptying until it is back (with the distance off, the wait in
-- its place). A tile as wide and as tall as what it holds, each row in the
-- middle; narrower to fit, two rows past six lairs or when one row cannot hold
-- them. The guardians' bar and the list hung under the tracker give way to
-- it. In the corners the cache's coin (the tracker's own: Cache coin, Coin
-- shines; dim while the gold falls short) with its price, the elites alive (a
-- green diamond and the count, as the Elites), the lives left and the kill
-- pace's orb.
--
-- The rings are our own art (make_dial_rings.py: whole and half, smooth at
-- any size). A track is the whole ring in one quad; a fill two quads, the
-- right and the left half of the ring's box, each the half ring turned by
-- SetTexCoord's eight corners: up to half way the right one turned to end at
-- the fill's end, past it the right one whole and the left one turned. Every
-- corner maps inside the art's inner circle (0.707 of a quad's half), so a
-- turn never reaches past the art (the game repeats it there).

if SurvivorUI_Standby then return end

local head = getglobal("SurvivorUITracker")
if not head then return end

local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"

-- Sizes, in the tracker's own pixels (its Size scales them all).
local D = {
	WIDTH = 220, RADIUS = 82, TOP = 8, GAP = 8,
	OUT = 72,              -- the run's ring (DialRing: 7 thick)
	THIN = 62,             -- the next boss's countdown (DialRingThin: 2.5 thick)
	THIN_INNER = 60.5,     -- inside it, the words' room
	RIM = 81,              -- the disc's rim (DialRingThin)
	CLOCK = 7,             -- a slain guardian's clock (DialRingSmall: 2 thick)
	LABEL = 91,            -- the next boss's second, out from the middle
	CELLS = 8,             -- the arrows' sheet: 8 x 8
	DOT = 64 / 60,         -- Art\HeroDot's disc, of its box
	PULSE = 1.2,           -- a boss alive's mark: a swell each, in seconds
	-- The compass's tiles: TALL with the distance, SHORT without; the arrow
	-- (the clock, the health) at HUB from a tile's top, the distance at FOOT
	-- from its foot. A tile its words' width and PAD (its edges, a little
	-- air), ROOM more while the row has it.
	TALL = 34, SHORT = 24, HUB = 12, FOOT = 8, PAD = 8, ROOM = 2, TILE_GAP = 6,
	ARROW = 20,            -- an arrow's shadow, the least a tile holds
}

-- The rings' art (make_dial_rings.py): each ring's middle radius, of the
-- art's width, its outer edge at 0.346; a quad's half maps onto 0.35355 of it.
SurvivorUI_DIAL_RINGS = {
	main = { file = ART.."DialRing", rho = 0.346 / (1 + 7 / 144) },
	thin = { file = ART.."DialRingThin", rho = 0.346 / (1 + 2.5 / 124) },
	small = { file = ART.."DialRingSmall", rho = 0.346 / (1 + 2 / 14) },
}
local HALF = 0.35355

-- The proposal's colors.
local C = {
	green = { 0.40, 0.88, 0.48 }, endless = { 0.70, 0.40, 1.00 }, track = { 0.14, 0.19, 0.125 },
	orange = { 1.00, 0.60, 0.24 }, orangeTrack = { 0.20, 0.16, 0.09 }, violet = { 0.72, 0.52, 1.00 },
	red = { 1.00, 0.35, 0.28 }, clockTrack = { 0.22, 0.12, 0.11 },
	doneEdge = { 0.36, 0.42, 0.32 }, tick = { 0.61, 0.83, 0.54 }, dueEdge = { 0.43, 0.42, 0.38 },
	markFill = { 0.045, 0.05, 0.04 }, nextFill = { 0.10, 0.07, 0.03 }, upFill = { 0.11, 0.06, 0.15 },
	disc = { 0.055, 0.07, 0.047 }, discEdge = { 0.18, 0.23, 0.16 },
	discBoss = { 0.07, 0.05, 0.085 }, discBossEdge = { 0.23, 0.165, 0.28 },
	text = { 0.95, 0.945, 0.91 }, muted = { 0.60, 0.61, 0.56 }, label = { 1.00, 0.75, 0.50 },
	victory = { 0.30, 0.85, 0.30 }, fallen = { 1.00, 0.25, 0.25 }, lives = { 1.00, 0.50, 0.50 },
	gold = { 1.00, 0.82, 0.30 }, goldDim = { 0.62, 0.56, 0.44 }, elite = { 0.40, 0.88, 0.48 },
	-- The compass: up (green, the guardians' own), in a fight (orange), slain
	-- (grey and dim, its time in red).
	upBack = { 0.045, 0.10, 0.05 }, upEdge = { 0.24, 0.70, 0.32 }, upArrow = { 0.45, 1.00, 0.52 }, upText = { 0.55, 0.92, 0.58 },
	awakeBack = { 0.114, 0.075, 0.035 }, awakeText = { 1.00, 0.75, 0.50 },
	slainBack = { 0.055, 0.055, 0.06 }, slainEdge = { 0.22, 0.22, 0.24 }, slainText = { 1.00, 0.38, 0.32 },
	bossName = { 0.85, 0.76, 1.00 }, finalName = { 1.00, 0.75, 0.50 },
	ahead = { 1.00, 0.85, 0.25 },
	-- The tags, as the tracker's own (Tracker.lua's TAG_COLORS).
	tag = { normal = { 0.62, 0.62, 0.66 }, heroic = { 1.00, 0.48, 0.18 }, endless = { 0.82, 0.50, 1.00 }, affix = { 1.00, 0.35, 0.29 } },
}

local S = { marks = {}, tiles = {}, full = {}, nbMost = 0 }   -- the dial's pieces and what it saw

local function Num(value)
	return tonumber(value) or 0
end

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

-- The tracker in the Dial's look, and on.
function SurvivorUI_DialOn()
	local db = SurvivorUIDB
	return db and db.trackerLook == "dial" and db.tracker ~= false and true or false
end

-- The Dial with its compass: the guardians' bar and their hung list give way
-- to it (Guardians.lua).
function SurvivorUI_DialCompass()
	return SurvivorUI_DialOn() and SurvivorUIDB.trackerDialCompass ~= false
end

------------------------------------------------------------------------------
-- The rings. Shared with the options' preview: a ring's box's half size for a
-- middle radius, and a half quad's corners.

function SurvivorUI_DialQuad(kind, radius)
	return radius * HALF / SurvivorUI_DIAL_RINGS[kind].rho
end

-- A quad of half the ring's box (q: the box's half size), side 1 the right,
-- -1 the left: its art turned clockwise by turn (of a whole turn), each
-- corner's offset turned back onto the art (v down).
function SurvivorUI_DialHalf(texture, q, side, turn)
	local a = 2 * math.pi * turn
	local c, s, k = math.cos(a), math.sin(a), HALF / q
	local x0, x1 = side > 0 and 0 or -q, side > 0 and q or 0
	texture:SetTexCoord(
		0.5 + k * (x0 * c - q * s), 0.5 - k * (x0 * s + q * c),
		0.5 + k * (x0 * c + q * s), 0.5 - k * (x0 * s - q * c),
		0.5 + k * (x1 * c - q * s), 0.5 - k * (x1 * s + q * c),
		0.5 + k * (x1 * c + q * s), 0.5 - k * (x1 * s - q * c))
end

-- A boss alive's mark, pulsing: its glow and the mark itself swelling, the
-- glow fading as it shrinks, a swell each D.PULSE seconds. parts: { texture,
-- size } each, the glow first (in color); each frame, here and in the
-- options' preview.
function SurvivorUI_DialPulse(parts, color)
	local wave = 0.5 + 0.5 * math.sin(GetTime() * 2 * math.pi / D.PULSE)
	for index = 1, table.getn(parts) do
		local grown = parts[index][2] * (index == 1 and 0.8 + 0.7 * wave or 1 + 0.25 * wave)
		parts[index][1]:SetWidth(grown)
		parts[index][1]:SetHeight(grown)
	end
	parts[1][1]:SetVertexColor(color[1], color[2], color[3], 0.3 + 0.7 * wave)
end

-- A ring round at's middle: its track (the whole ring, one quad, in its
-- layer) and its fill (two half quads, a layer up).
local function NewRing(parent, at, kind, radius, layer, fillLayer)
	return { parent = parent, at = at, art = SurvivorUI_DIAL_RINGS[kind].file, q = SurvivorUI_DialQuad(kind, radius),
		layer = layer, fillLayer = fillLayer }
end

local function Quad(ring, layer)
	local texture = ring.parent:CreateTexture(nil, layer)
	texture:Hide()
	return texture
end

local function Art(texture, path)
	if texture.path ~= path then
		texture:SetTexture(path)
		texture.path = path
	end
end

local function Track(ring, color)
	local track = ring.track
	if not track then
		track = Quad(ring, ring.layer)
		Art(track, ring.art)
		track:SetTexCoord(0.5 - HALF, 0.5 + HALF, 0.5 - HALF, 0.5 + HALF)
		track:SetWidth(2 * ring.q)
		track:SetHeight(2 * ring.q)
		track:SetPoint("CENTER", ring.at, "CENTER", 0, 0)
		ring.track = track
	end
	if ring.trackColor ~= color then
		track:SetVertexColor(color[1], color[2], color[3], 1)
		ring.trackColor = color
	end
	track:Show()
end

-- The fill from the top clockwise to share (0 to 1).
local function Fill(ring, share, color)
	local right, left = ring.right, ring.left
	if not right then
		right, left = Quad(ring, ring.fillLayer), Quad(ring, ring.fillLayer)
		for _, half in pairs({ right, left }) do
			half:SetWidth(ring.q)
			half:SetHeight(2 * ring.q)
		end
		right:SetPoint("TOPLEFT", ring.at, "CENTER", 0, ring.q)
		left:SetPoint("TOPRIGHT", ring.at, "CENTER", 0, ring.q)
		ring.right, ring.left = right, left
	end
	share = math.max(0, math.min(1, share or 0))
	if ring.fillColor ~= color then
		right:SetVertexColor(color[1], color[2], color[3], 1)
		left:SetVertexColor(color[1], color[2], color[3], 1)
		ring.fillColor = color
	end
	if share < 0.002 then
		right:Hide()
		left:Hide()
		return
	end
	if math.abs(share - (ring.share or -1)) > 0.0004 then
		ring.share = share
		if share <= 0.5 then
			Art(right, ring.art.."Half")
			SurvivorUI_DialHalf(right, ring.q, 1, share - 0.5)
		else
			Art(right, ring.art)
			SurvivorUI_DialHalf(right, ring.q, 1, 0)
			if share >= 0.998 then
				Art(left, ring.art)
				SurvivorUI_DialHalf(left, ring.q, -1, 0)
			else
				Art(left, ring.art.."Half")
				SurvivorUI_DialHalf(left, ring.q, -1, share - 0.5)
			end
		end
	end
	right:Show()
	if share > 0.5 then
		left:Show()
	else
		left:Hide()
	end
end

-- A ring shown: its track and its fill.
local function PaintRing(ring, share, color, trackColor)
	Track(ring, trackColor)
	Fill(ring, share, color)
end

local function HideRing(ring)
	if ring.track then
		ring.track:Hide()
	end
	if ring.right then
		ring.right:Hide()
		ring.left:Hide()
	end
end

------------------------------------------------------------------------------
-- The frame: in the tracker, at its top, the disc, then the compass.

local dial = CreateFrame("Frame", nil, head)
dial:SetWidth(D.WIDTH)
dial:SetHeight(D.TOP + 2 * D.RADIUS)
dial:SetPoint("TOP", head, "TOP", 0, 0)
dial:Hide()
S.dial = dial

-- The disc's middle, where the rings and the words hang from.
local hub = CreateFrame("Frame", nil, dial)
hub:SetWidth(1)
hub:SetHeight(1)
hub:SetPoint("CENTER", dial, "TOP", 0, -(D.TOP + D.RADIUS))
S.hub = hub

-- Over the rings the bosses' marks, over those the words.
local marks = CreateFrame("Frame", nil, dial)
marks:SetAllPoints(dial)
marks:SetFrameLevel(dial:GetFrameLevel() + 1)
local words = CreateFrame("Frame", nil, dial)
words:SetAllPoints(dial)
words:SetFrameLevel(dial:GetFrameLevel() + 2)
S.marksFrame, S.words = marks, words

-- The disc, its edge under its rim.
S.disc = dial:CreateTexture(nil, "BORDER")
S.disc:SetTexture(ART.."HeroDot")
S.disc:SetWidth(2 * (D.RADIUS - 0.5) * D.DOT)
S.disc:SetHeight(2 * (D.RADIUS - 0.5) * D.DOT)
S.disc:SetPoint("CENTER", hub, "CENTER", 0, 0)

S.rim = NewRing(dial, hub, "thin", D.RIM, "ARTWORK", "OVERLAY")
S.out = NewRing(dial, hub, "main", D.OUT, "ARTWORK", "OVERLAY")
S.thin = NewRing(dial, hub, "thin", D.THIN, "ARTWORK", "OVERLAY")

local function Words(size, flags, justify)
	local text = words:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, flags or "OUTLINE")
	text:SetJustifyH(justify or "CENTER")
	text.size = size
	return text
end

-- A set of the same words at sizes going down, the first that fits shown.
local function Sizes(flags, ...)
	local set = {}
	for index = 1, table.getn(arg) do
		set[index] = Words(arg[index], flags)
	end
	return set
end

-- The middle: the clock big, "of 16:00", under them the next boss, or a boss
-- alive's name (on one line, or two when long).
S.clock = Words(28, "THICKOUTLINE")
S.of = Words(10)
S.next1 = Sizes(nil, 10, 9)
S.next2 = Words(10)
-- The next boss's second, by its mark.
S.label = Words(9)
S.label:SetTextColor(C.label[1], C.label[2], C.label[3])
-- The corners: the cache's price, the elites, the lives left.
S.price = Words(11)
S.lives = Words(9, nil, "LEFT")
S.lives:SetTextColor(C.lives[1], C.lives[2], C.lives[3])

-- The run's tags (made by Tracker.lua's SurvivorUI_NewTag, drawn here in the
-- Dial's own way), in a row of their own over the clock.
S.tagRow = CreateFrame("Frame", nil, words)
S.tagRow:SetWidth(160)
S.tagRow:SetHeight(13)
S.tagRow:SetPoint("CENTER", hub, "CENTER", 0, 34)
if SurvivorUI_NewTag then
	S.tags = { difficulty = SurvivorUI_NewTag(S.tagRow), endless = SurvivorUI_NewTag(S.tagRow), affixes = {} }
end

-- The elites alive, at the top right: a green diamond and the count.
S.elites = CreateFrame("Frame", nil, words)
S.elites:SetWidth(44)
S.elites:SetHeight(18)
S.elites:SetPoint("TOPRIGHT", dial, "TOPRIGHT", 0, 0)
S.elites.diamond = S.elites:CreateTexture(nil, "ARTWORK")
S.elites.diamond:SetTexture(ART.."Pip")
S.elites.diamond:SetWidth(12)
S.elites.diamond:SetHeight(12)
S.elites.diamond:SetPoint("CENTER", S.elites, "TOPRIGHT", -9, -10)
S.elites.count = S.elites:CreateFontString(nil, "OVERLAY")
S.elites.count:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "OUTLINE")
S.elites.count:SetPoint("RIGHT", S.elites.diamond, "LEFT", -4, 0)
S.elites:EnableMouse(true)
S.elites:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(SurvivorUI_T("Elites"), C.elite[1], C.elite[2], C.elite[3])
	GameTooltip:AddLine(SurvivorUI_TF("{1} alive", this.total or 0), 1, 1, 1)
	if (this.hurt or 0) > 0 then
		GameTooltip:AddLine(SurvivorUI_TF("{1} fighting", this.hurt), 0.35, 1, 0.2)
	end
	GameTooltip:Show()
end)
S.elites:SetScript("OnLeave", function() GameTooltip:Hide() end)
S.elites:Hide()

------------------------------------------------------------------------------
-- Words in the circle: as wide as the ring leaves at their height.

-- The room across inside a ring's inner edge for words centered at y, so
-- tall, a little in from the edge. Shared with the options' preview.
function SurvivorUI_DialRoom(inner, y, tall)
	local reach = math.abs(y) + tall / 2
	if reach >= inner then
		return 0
	end
	return 2 * math.sqrt(inner * inner - reach * reach) - 8
end
local Room = SurvivorUI_DialRoom

-- A word's first letter when it is a capital, Latin or Cyrillic (А to Я, Ё:
-- two bytes in UTF-8), else nil.
local function Initial(word)
	if string.find(word, "^%u") then
		return string.sub(word, 1, 1)
	elseif string.find(word, "^\208[\129\144-\175]") then
		return string.sub(word, 1, 2)
	end
end

-- Words too wide for room made short on text (a FontString): the first word
-- and the others' initials ("Ossirian U."), the first word alone, then cut,
-- whole characters only; tail (a boss's " 63%") after them, kept whole.
-- Shared with the options' preview.
function SurvivorUI_DialShorten(text, words, room, tail)
	tail = tail or ""
	if text:GetStringWidth() <= room then
		return
	end
	local list = {}
	for word in string.gfind(words, "%S+") do
		table.insert(list, word)
	end
	local short = list[1] or words
	for each = 2, table.getn(list) do
		local first = Initial(list[each])
		if first then
			short = short.." "..first.."."
		end
	end
	local cut = short
	text:SetText(cut..tail)
	if text:GetStringWidth() > room then
		cut = list[1] or words
		text:SetText(cut..tail)
	end
	while text:GetStringWidth() > room and string.len(cut) > 2 do
		cut = string.gsub(cut, "[%z\1-\127\194-\244][\128-\191]*%.?%.?$", "")
		text:SetText(cut..".."..tail)
	end
end

local function HideSet(set)
	for index = 1, table.getn(set) do
		set[index]:Hide()
	end
end

-- The words of a set at y in its room: whole at each size, going down; at the
-- smallest, the first word and the others' initials ("Ossirian U."), the first
-- word alone, then cut, whole characters only, tail (a boss's " 63%") always
-- whole after them. The one shown comes back.
local function FitIn(set, text, y, inner, color, tail)
	HideSet(set)
	tail = tail or ""
	local count = table.getn(set)
	for index = 1, count do
		local shown = set[index]
		shown:SetText(text..tail)
		local tall = shown:GetHeight()
		if not tall or tall <= 0 then
			tall = shown.size + FONT_BUMP
		end
		if shown:GetStringWidth() <= Room(inner, y, tall) or index == count then
			SurvivorUI_DialShorten(shown, text, Room(inner, y, tall), tail)
			shown:ClearAllPoints()
			shown:SetPoint("CENTER", hub, "CENTER", 0, y)
			shown:SetTextColor(color[1], color[2], color[3])
			shown:Show()
			return shown
		end
	end
end

------------------------------------------------------------------------------
-- The bosses' marks on the outer ring.

local function Mark(index)
	local mark = S.marks[index]
	if mark then
		return mark
	end
	mark = {}
	mark.glow = marks:CreateTexture(nil, "BACKGROUND")
	mark.glow:SetTexture(ART.."PaceGlow")
	mark.glow:SetBlendMode("ADD")
	mark.outer = marks:CreateTexture(nil, "BORDER")
	mark.outer:SetTexture(ART.."HeroDot")
	mark.inner = marks:CreateTexture(nil, "ARTWORK")
	mark.inner:SetTexture(ART.."HeroDot")
	mark.core = marks:CreateTexture(nil, "OVERLAY")
	mark.skull = marks:CreateTexture(nil, "ARTWORK")
	mark.skull:SetTexture(ART.."PinBoss")
	S.marks[index] = mark
	return mark
end

local function Place(texture, x, y, size)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", hub, "CENTER", x, y)
	texture:SetWidth(size)
	texture:SetHeight(size)
	texture:Show()
end

local function HideMark(mark)
	mark.glow:Hide()
	mark.outer:Hide()
	mark.inner:Hide()
	mark.core:Hide()
	mark.skull:Hide()
	mark.state, mark.lit, mark.pulse = nil, nil, nil
end

-- A mark at x, y: state "dead" (dimmed, a tick), "next" (glowing orange),
-- "due", "up" (glowing in color, its kind's, pulsing: mark.pulse, the dial's
-- OnUpdate); final, the horned skull.
local function PaintMark(mark, state, final, x, y, color)
	if mark.state == state and mark.final == final and mark.x == x and mark.y == y and mark.color == color then
		return
	end
	mark.state, mark.final, mark.x, mark.y, mark.color = state, final, x, y, color
	local lit = (state == "next" and C.orange) or (state == "up" and color) or nil
	mark.lit = lit
	if lit then
		Place(mark.glow, x, y, final and 40 or 32)
		mark.glow:SetVertexColor(lit[1], lit[2], lit[3], 0.8)
	else
		mark.glow:Hide()
	end
	mark.core:Hide()
	if final then
		mark.outer:Hide()
		mark.inner:Hide()
		Place(mark.skull, x, y, lit and 21 or 18)
		local shade = state == "dead" and 0.45 or 1
		mark.skull:SetVertexColor(shade, shade, shade, state == "dead" and 0.8 or 1)
	else
		mark.skull:Hide()
		local edge = lit or (state == "dead" and C.doneEdge) or C.dueEdge
		local fill = (state == "next" and C.nextFill) or (state == "up" and C.upFill) or C.markFill
		local size = lit and 14 or 12
		Place(mark.outer, x, y, size * D.DOT)
		mark.outer:SetVertexColor(edge[1], edge[2], edge[3], 1)
		Place(mark.inner, x, y, (size - 3.4) * D.DOT)
		mark.inner:SetVertexColor(fill[1], fill[2], fill[3], 1)
	end
	if lit and not final then
		mark.core:SetTexture(ART.."HeroDot")
		Place(mark.core, x, y, 5 * D.DOT)
		mark.core:SetVertexColor(lit[1], lit[2], lit[3], 1)
	elseif state == "dead" then
		mark.core:SetTexture(ART.."Tick")
		Place(mark.core, final and x + 6 or x, final and y - 5 or y, 9)
		mark.core:SetVertexColor(C.tick[1], C.tick[2], C.tick[3], 1)
	end
	mark.pulse = nil
	if state == "up" then
		if final then
			mark.pulse = { { mark.glow, 40 }, { mark.skull, 21 } }
		else
			mark.pulse = { { mark.glow, 32 }, { mark.outer, 14 * D.DOT }, { mark.inner, (14 - 3.4) * D.DOT }, { mark.core, 5 * D.DOT } }
		end
	end
end

------------------------------------------------------------------------------
-- The compass's tiles, a lair each.

-- An arrow turned by angle (radians, clockwise from up): the sheet's cell
-- nearest to it, set only as it changes.
local function Point(texture, angle)
	local cells = D.CELLS * D.CELLS
	local k = math.mod(math.floor(angle / (2 * math.pi) * cells + 0.5), cells)
	if k < 0 then
		k = k + cells
	end
	if texture.cell ~= k then
		texture.cell = k
		local column, line = math.mod(k, D.CELLS), math.floor(k / D.CELLS)
		texture:SetTexCoord(column / D.CELLS, (column + 1) / D.CELLS, line / D.CELLS, (line + 1) / D.CELLS)
	end
end

local function TileTip()
	local lair = this.lair
	if not lair then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(lair.name or SurvivorUI_T("Guardians"), 1, 0.82, 0)
	if lair.state == "empty" then
		GameTooltip:AddLine(lair.left and lair.left > 0 and Clock(lair.left + 0.5) or SurvivorUI_T("soon"), C.red[1], C.red[2], C.red[3])
	elseif lair.state == "awake" then
		GameTooltip:AddLine(lair.share and string.format("%d%%", lair.share * 100 + 0.5) or SurvivorUI_T("AWAKE"), C.orange[1], C.orange[2], C.orange[3])
	else
		GameTooltip:AddLine(SurvivorUI_T("SPAWNED"), 0.30, 1.00, 0.40)
	end
	if lair.yards then
		GameTooltip:AddLine(SurvivorUI_TF("{1} yd", math.floor(lair.yards + 0.5)), C.muted[1], C.muted[2], C.muted[3])
	end
	GameTooltip:Show()
end

local function Tile(index)
	local tile = S.tiles[index]
	if tile then
		return tile
	end
	tile = CreateFrame("Button", nil, dial)
	tile:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	-- Where the arrow, the clock or the health stands: a tall tile's upper
	-- middle, a short one's middle.
	tile.hub = CreateFrame("Frame", nil, tile)
	tile.hub:SetWidth(1)
	tile.hub:SetHeight(1)
	tile.hub:SetPoint("CENTER", tile, "TOP", 0, -D.HUB)
	tile.glow = tile:CreateTexture(nil, "BORDER")
	tile.glow:SetTexture(ART.."PaceGlow")
	tile.glow:SetBlendMode("ADD")
	tile.glow:SetVertexColor(C.ahead[1], C.ahead[2], C.ahead[3], 0.8)
	tile.glow:SetWidth(36)
	tile.glow:SetHeight(36)
	tile.glow:SetPoint("CENTER", tile.hub, "CENTER", 0, 0)
	tile.glow:Hide()
	tile.shadow = tile:CreateTexture(nil, "ARTWORK")
	tile.shadow:SetTexture(ART.."GuardianArrow")
	tile.shadow:SetVertexColor(0, 0, 0, 0.85)
	tile.shadow:SetWidth(D.ARROW)
	tile.shadow:SetHeight(D.ARROW)
	tile.shadow:SetPoint("CENTER", tile.hub, "CENTER", 0, 0)
	tile.arrow = tile:CreateTexture(nil, "OVERLAY")
	tile.arrow:SetTexture(ART.."GuardianArrow")
	tile.arrow:SetWidth(16)
	tile.arrow:SetHeight(16)
	tile.arrow:SetPoint("CENTER", tile.hub, "CENTER", 0, 0)
	-- Where the arrow stands, in its place: the health in a fight; with the
	-- distance off, a slain one's wait.
	tile.big = tile:CreateFontString(nil, "OVERLAY")
	tile.big:SetFont(SurvivorUI_FONT, 10 + FONT_BUMP, "OUTLINE")
	tile.big:SetPoint("CENTER", tile.hub, "CENTER", 0, 0)
	-- Along a tall tile's foot: how far, or a slain one's wait.
	tile.words = tile:CreateFontString(nil, "OVERLAY")
	tile.words:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	tile.words:SetPoint("CENTER", tile, "BOTTOM", 0, D.FOOT)
	tile.clock = NewRing(tile, tile.hub, "small", D.CLOCK, "ARTWORK", "OVERLAY")
	tile:SetScript("OnEnter", TileTip)
	tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- A click on a living one targets it (by its name, the only way 1.12 has).
	tile:SetScript("OnClick", function()
		if this.target and TargetByName then
			TargetByName(this.target, true)
		end
	end)
	S.tiles[index] = tile
	return tile
end

-- Words shown, or none.
local function Say(text, said)
	if said then
		text:SetText(said)
		text:Show()
	else
		text:SetText("")
		text:Hide()
	end
end

-- A tile in its lair's state: green while its guardian is up, orange in a
-- fight (its health where the arrow stands), grey and dim while slain (its
-- clock, or with the distance off its wait); tall, how far along its foot.
local function PaintTile(tile, lair, tall)
	tile.lair, tile.place = lair, lair.place
	local back, edge, text = C.upBack, C.upEdge, C.upText
	local empty, awake = lair.state == "empty", lair.state == "awake"
	if empty then
		back, edge, text = C.slainBack, C.slainEdge, C.slainText
	elseif awake then
		back, edge, text = C.awakeBack, C.orange, C.awakeText
	end
	tile:SetBackdropColor(back[1], back[2], back[3], 0.92)
	tile:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
	tile.words:SetTextColor(text[1], text[2], text[3])
	tile.big:SetTextColor(text[1], text[2], text[3])
	tile.target = (not empty) and lair.name or nil
	local big, foot
	if empty then
		-- The time until it is back: a red clock emptying (its whole span the
		-- longest time seen since it fell), the time under it; short, the
		-- time alone.
		local left = lair.left or -1
		S.full[lair.place] = math.max(S.full[lair.place] or 0, left)
		local full = S.full[lair.place]
		local wait = left > 0 and Clock(left + 0.5) or SurvivorUI_T("soon")
		if tall then
			PaintRing(tile.clock, full > 0 and left / full or 0, C.red, C.clockTrack)
			foot = wait
		else
			HideRing(tile.clock)
			big = wait
		end
	else
		S.full[lair.place] = nil
		HideRing(tile.clock)
		big = awake and lair.share and string.format("%d%%", lair.share * 100 + 0.5) or nil
		foot = tall and lair.yards and SurvivorUI_TF("{1} yd", math.floor(lair.yards + 0.5)) or nil
	end
	Say(tile.big, big)
	Say(tile.words, foot)
	-- The arrow, while nothing stands in its place.
	if not empty and not big and lair.angle then
		local color = lair.ahead and C.ahead or (awake and C.orange) or C.upArrow
		tile.arrow:SetVertexColor(color[1], color[2], color[3], 1)
		tile.arrow:Show()
		tile.shadow:Show()
		if lair.ahead then
			tile.glow:Show()
		else
			tile.glow:Hide()
		end
	else
		tile.arrow:Hide()
		tile.shadow:Hide()
		tile.glow:Hide()
	end
end

-- The widest of some words, as text (a FontString) measures them at its size.
local function Widest(text, list)
	local most = 0
	for index = 1, table.getn(list) do
		text:SetText(list[index])
		most = math.max(most, text:GetStringWidth() or 0)
	end
	return most
end

-- What a tile needs across: an arrow, a health, a slain one's wait, and tall
-- the farthest a lair stands, measured by tile's own words (the tracker's
-- text size on them), and its PAD. Its words are put back by PaintTile.
local function TileNeed(tile, tall)
	local most = Widest(tile.big, tall and { "100%" } or { "100%", "0:00", SurvivorUI_T("soon") })
	if tall then
		most = math.max(most, Widest(tile.words, { SurvivorUI_TF("{1} yd", 888), "0:00", SurvivorUI_T("soon") }))
	end
	return math.ceil(math.max(D.ARROW, most)) + D.PAD
end

-- A slain guardian's whole wait, as seen (for the options' preview).
function SurvivorUI_DialSpan(place)
	return S.full[place]
end

-- The compass under the disc, at y; its foot comes back (y itself with none).
-- Its tiles as wide as they need and ROOM more while the row has it, each row
-- in the middle; two rows past six lairs, or when one cannot hold them.
local function Compass(y)
	local db = SurvivorUIDB
	local lairs = db and db.trackerDialCompass ~= false and SurvivorUI_GuardianCompass
		and SurvivorUI_GuardianCompass() or {}
	local count = table.getn(lairs)
	for index = count + 1, table.getn(S.tiles) do
		S.tiles[index]:Hide()
		S.tiles[index].place = nil
	end
	if count == 0 then
		return y
	end
	local tall = db.trackerDialYards ~= false
	local high, gap = tall and D.TALL or D.SHORT, D.TILE_GAP
	local need = TileNeed(Tile(1), tall)
	local perRow = count
	if count > 6 or count * need + (count - 1) * gap > D.WIDTH then
		perRow = math.ceil(count / 2)
	end
	local each = math.floor(math.min(need + D.ROOM, (D.WIDTH - (perRow - 1) * gap) / perRow))
	local top = y - D.GAP
	for index = 1, count do
		local tile = Tile(index)
		local column, line = math.mod(index - 1, perRow), math.floor((index - 1) / perRow)
		local inRow = math.min(perRow, count - line * perRow)
		local left = math.floor((D.WIDTH - inRow * each - (inRow - 1) * gap) / 2 + 0.5)
		tile:SetWidth(each)
		tile:SetHeight(high)
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", dial, "TOPLEFT", left + column * (each + gap), top - line * (high + gap))
		PaintTile(tile, lairs[index], tall)
		tile:Show()
	end
	local rows = math.ceil(count / perRow)
	return top - rows * high - (rows - 1) * gap
end

-- Every frame, a boss alive's mark pulsing, and each arrow at the way the
-- guardians' arrows point now (Guardians.lua turns them smoothly).
dial:SetScript("OnUpdate", function()
	for index = 1, table.getn(S.marks) do
		local mark = S.marks[index]
		if mark.pulse and mark.lit then
			SurvivorUI_DialPulse(mark.pulse, mark.lit)
		end
	end
	if not SurvivorUI_GuardianAngle then
		return
	end
	for index = 1, table.getn(S.tiles) do
		local tile = S.tiles[index]
		if tile.place and tile.arrow:IsShown() then
			local angle = SurvivorUI_GuardianAngle(tile.place)
			if angle then
				Point(tile.arrow, angle)
				Point(tile.shadow, angle)
			end
		end
	end
end)

------------------------------------------------------------------------------
-- The run as the dial reads it, each draw (kept in one table).

local M = {}

-- The boss alive under this name, for its kind (the final boss's).
local function LiveBoss(name)
	local units = AZS_UNITS or {}
	for index = 1, table.getn(units) do
		local unit = units[index]
		local kind = Field(unit, "kind", 1)
		if (kind == "boss" or kind == "final") and Field(unit, "name", 3) == name then
			return unit
		end
	end
end

local function Read(game, phase)
	local zone = AZS_ZONE or {}
	M.phase = phase
	M.seconds = (AZS_GetRunTime and AZS_GetRunTime()) or Num(game.t)
	local length = Num(zone.len)
	if length <= 0 and AZS_GetRunLength then
		length = Num(AZS_GetRunLength())
	end
	if length <= 0 then
		length = Num(game.fin)
	end
	M.length, M.endless = length, Num(game.endl) == 1
	M.heroic = zone.heroic
	-- The bosses: the next to come, the one alive, the second the last came.
	local schedule = AZS_SCHEDULE or {}
	M.schedule, M.next, M.up, M.prevAt = schedule, nil, nil, 0
	for index = 1, table.getn(schedule) do
		local entry = schedule[index]
		local state = M.endless and "dead" or Field(entry, "state", 5) or "due"
		if state == "up" and not M.up then
			M.up = index
		elseif state == "due" and not M.next then
			M.next = index
		end
		if not M.next and state ~= "due" then
			M.prevAt = Num(Field(entry, "at", 2))
		end
	end
	M.unit = M.up and LiveBoss(Field(schedule[M.up], "name", 3))
	M.final = M.up and (Num(Field(schedule[M.up], "final", 4)) == 1 or (M.unit and Field(M.unit, "kind", 1) == "final")) or nil
	M.nb = tonumber(game.nb) or -1
end

-- The ring's color: green, or the class's (the Dial's Ring); purple in
-- endless mode.
local function RingColor()
	if M.endless then
		return C.endless
	end
	if SurvivorUIDB and SurvivorUIDB.trackerDialRing == "class" and SurvivorUI_ClassColor and UnitClass then
		local _, class = UnitClass("player")
		if class then
			local r, g, b = SurvivorUI_ClassColor(class)
			if not (S.class and S.class[1] == r and S.class[2] == g and S.class[3] == b) then
				S.class = { r, g, b }
			end
			return S.class
		end
	end
	return C.green
end

-- The rings and the disc: the run, then the next boss's countdown, a boss
-- alive or not (the dial is for the run's time and its spawns); the disc a
-- shade of violet while a boss is alive.
local function Rings()
	local boss = M.up ~= nil
	local disc, edge = boss and C.discBoss or C.disc, boss and C.discBossEdge or C.discEdge
	S.disc:SetVertexColor(disc[1], disc[2], disc[3], 0.93)
	Track(S.rim, edge)
	PaintRing(S.out, M.endless and 1 or (M.length > 0 and M.seconds / M.length or 0), RingColor(), C.track)
	-- The time left to the next boss, of the stretch since the last one came
	-- (in endless mode, of the longest wait seen since one came).
	local share
	if M.endless and M.nb >= 0 then
		if M.nb > (S.nbLast or -1) + 1 then
			S.nbMost = M.nb
		end
		S.nbLast = M.nb
		S.nbMost = math.max(S.nbMost, M.nb)
		share = S.nbMost > 0 and M.nb / S.nbMost or 0
	elseif M.next then
		local at = Num(Field(M.schedule[M.next], "at", 2))
		local span = at - M.prevAt
		share = span > 0 and (at - M.seconds) / span or 0
	end
	if share and M.phase ~= "victory" and M.phase ~= "dead" then
		PaintRing(S.thin, share, C.orange, C.orangeTrack)
	else
		HideRing(S.thin)
	end
end

-- Each boss's mark at its second, one alive in violet (orange the final
-- boss); the next lit, a boss alive or not, its second by it.
local function Marks()
	local count = table.getn(M.schedule)
	S.label:Hide()
	for index = 1, count do
		local entry = M.schedule[index]
		local mark = Mark(index)
		if M.length > 0 then
			local at = Num(Field(entry, "at", 2))
			local turn = 2 * math.pi * math.min(1, at / M.length)
			local final = Num(Field(entry, "final", 4)) == 1
			local state = M.endless and "dead" or Field(entry, "state", 5) or "due"
			if index == M.next then
				state = "next"
			end
			local x, y = math.floor(D.OUT * math.sin(turn) * 10 + 0.5) / 10, math.floor(D.OUT * math.cos(turn) * 10 + 0.5) / 10
			PaintMark(mark, state, final, x, y, (final or (index == M.up and M.final)) and C.orange or C.violet)
			-- Its second outside the disc, where the compass leaves room.
			if state == "next" and math.cos(turn) > -0.75 then
				local side = math.sin(turn)
				S.label:SetText(Clock(at))
				S.label:ClearAllPoints()
				local point = (side > 0.3 and "LEFT") or (side < -0.3 and "RIGHT") or "CENTER"
				S.label:SetPoint(point, hub, "CENTER", D.LABEL * side, D.LABEL * math.cos(turn))
				S.label:Show()
			end
		else
			HideMark(mark)
		end
	end
	for index = count + 1, table.getn(S.marks) do
		HideMark(S.marks[index])
	end
end

local function Put(text, y, color)
	text:ClearAllPoints()
	text:SetPoint("CENTER", hub, "CENTER", 0, y)
	if color then
		text:SetTextColor(color[1], color[2], color[3])
	end
	text:Show()
end

-- "of 16:00", or Endless.
local function OfLength()
	if M.endless then
		return SurvivorUI_T("Endless"), C.endless
	end
	if M.length > 0 then
		return SurvivorUI_TF("of {1}", Clock(M.length)), C.muted
	end
	return "", C.muted
end

-- A boss alive's health after its name, " 63%", as the tracker's lines read
-- it (the game's AZS_UNITS); nothing while the game has not told it.
local function Health()
	local hpm = M.unit and Num(Field(M.unit, "hpm", 5)) or 0
	if hpm <= 0 then
		return ""
	end
	return " "..math.floor(Num(Field(M.unit, "hp", 4)) / hpm * 100 + 0.5).."%"
end

-- The middle: the clock, "of 16:00", under them the run's end, a boss alive's
-- name and health, or the next boss with the time until it comes.
local function Middle()
	local still = M.phase == "paused" or M.phase == "choosing"
	S.clock:SetText(Clock(M.seconds))
	local grey = still and 0.6 or 1
	S.clock:SetTextColor(C.text[1] * grey, C.text[2] * grey, C.text[3] * grey)
	Put(S.clock, 8)
	local said, color = OfLength()
	if M.phase == "paused" then
		said, color = SurvivorUI_T("Paused"), C.muted
	elseif M.phase == "choosing" then
		said, color = SurvivorUI_T("Choosing"), C.muted
	end
	S.of:SetText(said)
	Put(S.of, -14, color)
	local line, name, color2, tail
	if M.phase == "victory" then
		line, color2 = SurvivorUI_T("Victory"), C.victory
	elseif SurvivorUI_IsDown and SurvivorUI_IsDown() then
		line, color2 = SurvivorUI_T("Down"), C.fallen
	elseif M.phase == "dead" then
		line, color2 = SurvivorUI_T("Fallen"), C.fallen
	elseif M.up then
		line, color2, tail = Field(M.schedule[M.up], "name", 3) or "?", M.final and C.finalName or C.bossName, Health()
	elseif M.endless and M.nb >= 0 then
		name, line, color2 = SurvivorUI_T("Next boss"), SurvivorUI_TF("in {1}", Clock(M.nb)), C.orange
	elseif M.next then
		local entry = M.schedule[M.next]
		name = Field(entry, "name", 3) or "?"
		line, color2 = SurvivorUI_TF("in {1}", Clock(Num(Field(entry, "at", 2)) - M.seconds)), C.orange
	end
	S.next2:Hide()
	HideSet(S.next1)
	if not line then
		return
	end
	if not name then
		FitIn(S.next1, line, -32, D.THIN_INNER, color2, tail)
		return
	end
	-- On one line when it fits at its size, else the name over the time.
	local one = S.next1[1]
	one:SetText(name.." "..line)
	if one:GetStringWidth() <= Room(D.THIN_INNER, -32, one:GetHeight() > 0 and one:GetHeight() or 10) then
		Put(one, -32, color2)
		return
	end
	FitIn(S.next1, name, -30, D.THIN_INNER, color2)
	S.next2:SetText(line)
	Put(S.next2, -43, color2)
end

-- A tag in its words or its symbol, in its kind's colors (as Tracker.lua
-- paints its own); its width comes back.
local function PaintTag(tag, text, kind, symbol)
	local color = C.tag[kind] or C.tag.normal
	tag.tipColor = color
	tag:SetBackdropColor(color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 0.9)
	tag:SetBackdropBorderColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1)
	local width = 13
	if symbol then
		tag.text:Hide()
		tag.icon:SetTexture(symbol)
		tag.icon:SetVertexColor(color[1], color[2], color[3], 1)
		tag.icon:Show()
	else
		tag.icon:Hide()
		tag.text:SetText(text)
		tag.text:SetTextColor(color[1], color[2], color[3])
		tag.text:Show()
		width = math.max(13, math.floor(tag.text:GetStringWidth() + 8.5))
	end
	tag:SetWidth(width)
	tag:ClearAllPoints()
	tag:Show()
	return width
end

-- The run's tags over the clock, together in the middle and always short
-- (no room for words in the circle): the difficulty (N, or the Heroic
-- level's numeral) and endless mode's symbol, then the week's affixes by
-- their symbols. Each side shown or off by the Dial's own Difficulty and
-- Affixes (trackerDialDifficulty, trackerDialAffixes), the Classic lines
-- keeping their looks; each in full under the mouse.
local function Tags()
	if not S.tags then
		return
	end
	local db, tags, row = SurvivorUIDB or {}, S.tags, {}
	local shown = db.trackerDialDifficulty ~= false
	local heroic = shown and tonumber(M.heroic) or nil
	if heroic then
		tags.difficulty.tip = SurvivorUI_HeroicName and SurvivorUI_HeroicName(heroic) or nil
		table.insert(row, { tags.difficulty, PaintTag(tags.difficulty, SurvivorUI_HeroicShort and SurvivorUI_HeroicShort(heroic)
			or tostring(heroic), heroic > 0 and "heroic" or "normal") })
	else
		tags.difficulty:Hide()
	end
	if shown and M.endless then
		tags.endless.tip = SurvivorUI_T("Endless")
		table.insert(row, { tags.endless, PaintTag(tags.endless, nil, "endless", ART.."Endless") })
	else
		tags.endless:Hide()
	end
	local affixes = db.trackerDialAffixes ~= false and SurvivorUI_RunAffixes and SurvivorUI_RunAffixes() or nil
	affixes = affixes or {}
	local count = table.getn(affixes)
	for index = 1, count do
		local tag = tags.affixes[index]
		if not tag then
			tag = SurvivorUI_NewTag(S.tagRow)
			if SurvivorUI_AffixTip then
				SurvivorUI_AffixTip(tag)
			end
			tags.affixes[index] = tag
		end
		local entry = affixes[index]
		tag.affix = entry
		table.insert(row, { tag, PaintTag(tag, not entry.symbol and SurvivorUI_T(entry.name or "?") or nil, "affix", entry.symbol) })
	end
	for index = count + 1, table.getn(tags.affixes) do
		tags.affixes[index]:Hide()
	end
	local wide = -3
	for index = 1, table.getn(row) do
		wide = wide + row[index][2] + 3
	end
	local x = math.floor((S.tagRow:GetWidth() - wide) / 2 + 0.5)
	for index = 1, table.getn(row) do
		row[index][1]:SetPoint("TOPLEFT", S.tagRow, "TOPLEFT", x, 0)
		x = x + row[index][2] + 3
	end
end

------------------------------------------------------------------------------
-- The corners.

-- The cache's coin at the top left, the tracker's own: gold, and shining
-- (its own OnUpdate, Tracker.lua) while the gold pays for the next cache; dim
-- while not; its price beside it.
local function Coin(game)
	local coin = head.coin
	local gold, cost = Num(game.gold), Num(game.chest)
	if not (coin and cost > 0 and SurvivorUIDB and SurvivorUIDB.trackerCoin == true) then
		if coin then
			coin.pays = nil
			coin:Hide()
		end
		S.price:Hide()
		return
	end
	local pays = gold >= cost
	if pays and not coin.pays then
		coin.paysSince = GetTime()
	end
	if not pays and coin.pays ~= false then
		coin.icon:SetWidth(18)
		coin.icon:SetHeight(18)
		coin.icon:SetVertexColor(0.42, 0.42, 0.42)
	elseif SurvivorUIDB.trackerCoinShine == false then
		coin.icon:SetWidth(18)
		coin.icon:SetHeight(18)
		coin.icon:SetVertexColor(1, 1, 1)
	end
	coin.pays = pays
	coin:Show()
	local color = pays and C.gold or C.goldDim
	S.price:SetText(SurvivorUI_Abbrev and SurvivorUI_Abbrev(cost) or tostring(cost))
	S.price:SetTextColor(color[1], color[2], color[3])
	S.price:Show()
end

-- The elites alive at the top right, as the Elites: off, or gone with none
-- when chosen.
local function Elites()
	if SurvivorUIDB and SurvivorUIDB.trackerElites == false then
		S.elites:Hide()
		return
	end
	local total, hurt = 0, 0
	local units = AZS_UNITS or {}
	for index = 1, table.getn(units) do
		local unit = units[index]
		if Field(unit, "kind", 1) == "elite" then
			local hp, hpm = Num(Field(unit, "hp", 4)), Num(Field(unit, "hpm", 5))
			if hp > 0 then
				total = total + 1
				if hpm > 0 and hp < hpm then
					hurt = hurt + 1
				end
			end
		end
	end
	if total == 0 and SurvivorUIDB and SurvivorUIDB.trackerElitesHide then
		S.elites:Hide()
		return
	end
	S.elites.total, S.elites.hurt = total, hurt
	local shade = total > 0 and 1 or 0.45
	S.elites.diamond:SetVertexColor(C.elite[1] * shade, C.elite[2] * shade, C.elite[3] * shade, 1)
	S.elites.count:SetText(total)
	if hurt > 0 then
		S.elites.count:SetTextColor(1, 1, 1)
	else
		S.elites.count:SetTextColor(C.elite[1] * shade, C.elite[2] * shade, C.elite[3] * shade)
	end
	S.elites:Show()
end

-- The lives left at the bottom left.
local function Lives(game)
	local lives = Num(game.lives)
	if lives > 0 then
		S.lives:SetText(SurvivorUI_TF(lives == 1 and "{1} life left" or "{1} lives left", lives))
		S.lives:Show()
	else
		S.lives:Hide()
	end
end

------------------------------------------------------------------------------
-- For the tracker (Tracker.lua), in place of its lines.

-- Into the Dial's look: the coin to the top left corner, and the clock's
-- place (where the kill pace's orb hangs, Pace.lua) to the bottom right one.
local function Enter()
	dial:Show()
	local coin = head.coin
	if coin then
		coin:ClearAllPoints()
		coin:SetPoint("CENTER", dial, "TOPLEFT", 12, -10)
		coin:SetFrameLevel(words:GetFrameLevel() + 1)
		-- Gold always here: dimmed, not red, while the gold falls short.
		coin.icon:SetTexture(ART.."Coin")
		coin.pays = nil
	end
	S.price:ClearAllPoints()
	S.price:SetPoint("LEFT", dial, "TOPLEFT", 24, -10)
	S.lives:ClearAllPoints()
	S.lives:SetPoint("LEFT", dial, "TOPLEFT", 2, -(D.TOP + 2 * D.RADIUS - 8))
	if head.clock then
		head.clock:SetText("")
		head.clock:ClearAllPoints()
		head.clock:SetPoint("RIGHT", dial, "TOPRIGHT", -30, -(D.TOP + 2 * D.RADIUS - 8))
	end
end

-- Drawn: the dial in its frame, the run's facts as they stand. The tracker's
-- content height comes back (under it, its hung list).
function SurvivorUI_DrawDial(game, phase)
	if not dial:IsShown() then
		Enter()
	end
	Read(game, phase)
	Rings()
	Marks()
	Tags()
	Middle()
	Coin(game)
	Elites()
	Lives(game)
	local foot = Compass(-(D.TOP + 2 * D.RADIUS))
	local height = math.floor(-foot + 2.5)
	dial:SetHeight(height)
	return height
end

-- Out of it (Classic again): the coin back to its own state, for the lines to
-- draw it as theirs (Tracker.lua puts it back by the clock).
function SurvivorUI_HideDial()
	dial:Hide()
	local coin = head.coin
	if coin then
		coin.pays = nil
		coin.icon:SetWidth(18)
		coin.icon:SetHeight(18)
		coin.icon:SetVertexColor(1, 1, 1)
		coin:SetFrameLevel(head:GetFrameLevel() + 1)
	end
end
