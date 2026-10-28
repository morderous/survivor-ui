-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: a friend's build and gear, from their own Survivor UI.
--
-- The game tells addons nothing of a friend's build but their top spell, so
-- each Survivor UI in a party sends the others its hero's own on the party's
-- addon line (prefix SUIBUILD):
-- - the spells (SurvivorUI_BuildSnapshot) as the damage meter has them, the
--   most damage first, then by rank, the racial last; each with its damage,
--   its share and its biggest crit (SurvivorUI_CritBest);
-- - the jewelry as the build list reads it (SurvivorUI_GearSnapshot), and the
--   rest worn, slot by slot, with its stars as its tooltip says them (shown
--   after its name: "Frostfire Gloves +3");
-- - the hero's numbers (AZS_STATS), drawn as the Stats panel's;
-- - the best run Run History keeps: a victory (an endless run's too) over a
--   run that was not, then the hardest zone (the game opens them in an order:
--   Naxxramas at Heroic I is harder than Ahn'Qiraj at Heroic V), then the
--   higher Heroic level, then the longer.
-- Not the talents: the game tells addons none of the talent tree's choices
-- (the 1.12 talent calls know only the spells a talent of its own once gave).
-- Sent again as it changes (looked at each second; the damage, the crits and
-- the numbers every 10 seconds at most), and when a friend asks: one joining
-- asks everyone. A line a message, its fields split by "~", between a B (the
-- protocol's version) and an E:
--
--   B~1                                       a build begins
--   S~icon~rank~racial~name~dmg~share~crit    a spell (its icon under Interface\Icons)
--   J~color~item~label~tags~name              a piece of jewelry (an empty slot: no item)
--   I~slot~color~icon~item~name~stars         another piece worn
--   A~key=value;key=value                     the numbers, a few lines of them
--   R~zone~heroic~result~class~classKey~time  the best run (none: no R)
--   E                                         it ends: the build is theirs
--   ?                                         send me yours
--   X                                         forget mine (no longer shared)
--
-- A friend whose build came has an icon beside their party frame (Party.lua);
-- a click opens it beside them: their name, their best run under it, then on
-- the left their spells (ranks, damage, share, biggest crit), their jewelry
-- and what they wear, on the right their numbers, each with its tooltip. A
-- click anywhere else closes it. Dragged anywhere, by any of it, it opens
-- there from then on. Only a friend with this Survivor UI sends one, so only
-- they have the icon. While the party frames are placed, two of the samples
-- have one, made up, and the third none.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0
local PREFIX = "SUIBUILD"
local VERSION = "1"
local ICONS = "Interface\\Icons\\"
local WORN = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18 }   -- the jewelry's slots apart
local MUTED = { 0.45, 0.45, 0.45 }
local SOFT = { 0.8, 0.8, 0.8 }
local GOLD = { 1, 0.82, 0 }

-- The window's measures, in one table (the game's Lua 5.0 lets a function
-- reach 32 of the file's locals): the build's column on the left, the
-- numbers' on the right; a spell's columns from its row's right end.
local SIZE = { LEFT = 300, RIGHT = 180, PAD = 8, GAP = 14, TOP = 40, ROW = 16, HEAD = 18, LINE = 14,
	SHARE = -42, DMG = -78, RANK = -124 }
SIZE.WIDTH = SIZE.PAD * 2 + SIZE.LEFT + SIZE.GAP + SIZE.RIGHT

-- A piece's stars, its tooltip's "Upgraded: 3/5 stars" ("Not upgraded: 0/5
-- stars"): its n/of with the word for stars, in each of the game's languages.
local STAR_WORDS = {
	"star", "\195\169toile", "Stern", "estrel", "gwiazd", "hv\196\155zd", "stele", "y\196\177ld\196\177z",
	"\208\183\209\150\209\128", "\208\183\208\178\209\145\208\183\208\180", "\230\152\159", "\236\132\177",
}

-- The zones in the order the game opens them, the hardest last (its own
-- numbers for them, Affixes.lua's ZONES), each by its name in every language
-- the game speaks, as Run History keeps a run's zone.
local ZONES = {
	{ "Elwynn Forest", "Las Elwynn", "Elwynnský les", "Wald von Elwynn", "Floresta de Elwynn", "Bosque de Elwynn", "Forêt d'Elwynn", "Элвиннский лес", "Елвінський ліс", "艾尔文森林", "エルウィンの森", "엘윈 숲" },   -- elwynn
	{ "Duskwood", "Dämmerwald", "Floresta do Crepúsculo", "Bosque del Ocaso", "Bois de la Pénombre", "Сумеречный лес", "Сутінковий ліс", "暮色森林", "ダスクウッド", "그늘숲" },   -- duskwood
	{ "Warsong Gulch", "Wąwóz Pieśni Wojny", "Roklina Válečné písně", "Kriegshymnenschlucht", "Ravina Brado Guerreiro", "Garganta Grito de Guerra", "Goulet des Chanteguerres", "Ущелье Песни Войны", "Ущелина Пісні Війни", "战歌峡谷", "ウォーソング渓谷", "전쟁노래 협곡" },   -- wsg
	{ "Un'Goro Crater", "Krater Un'Goro", "Kráter Un'Goro", "Krater von Un'Goro", "Cratera Un'Goro", "Cráter de Un'Goro", "Cratère d'Un'Goro", "Кратер Ун'Горо", "Кратер Ун'Ґоро", "安戈洛环形山", "アンゴロ・クレーター", "운고로 분화구" },   -- ungoro
	{ "Arathi Basin", "Kotlina Arathi", "Arathská pánev", "Arathibecken", "Bacia Arathi", "Cuenca de Arathi", "Bassin Arathi", "Низина Арати", "Низина Араті", "阿拉希盆地", "アラシ盆地", "아라시 분지" },   -- ab
	{ "Feralas", "Féralas", "Фералас", "菲拉斯", "フェララス", "페랄라스" },   -- feralas
	{ "Gurubashi Arena", "Arena Gurubashi", "Aréna Gurubashi", "Arena der Gurubashi", "Arène des Gurubashi", "Арена Гурубаши", "Арена Ґурубаші", "古拉巴什竞技场", "グルバシ闘技場", "구루바시 투기장" },   -- arena
	{ "Scarlet Monastery", "Szkarłatny Klasztor", "Šarlatový klášter", "Scharlachrotes Kloster", "Monastério Escarlate", "Monasterio Escarlata", "Monastère Écarlate", "Монастырь Алого ордена", "Багряний монастир", "血色修道院", "スカーレット修道院", "붉은십자군 수도원" },   -- sm
	{ "Alterac Valley", "Dolina Alterac", "Alteracké údolí", "Alteractal", "Vale Alterac", "Valle de Alterac", "Vallée d'Alterac", "Альтеракская долина", "Альтеракська долина", "奥特兰克山谷", "アルタラック・ヴァレー", "알터랙 계곡" },   -- av
	{ "Blackrock Mountain", "Góra Czarnej Skały", "Hora Černé skály", "Der Schwarzfels", "Montanha Rocha Negra", "Montaña Roca Negra", "Mont Rochenoire", "Черная гора", "Гора Чорної Скелі", "黑石山", "ブラックロック山", "검은바위 산" },   -- brm
	{ "Gates of Ahn'Qiraj", "Wrota Ahn'Qiraj", "Brány Ahn'Qiraj", "Tore von Ahn'Qiraj", "Portões de Ahn'Qiraj", "Puertas de Ahn'Qiraj", "Portes d'Ahn'Qiraj", "Porțile Ahn'Qiraj", "Врата Ан'Киража", "Брама Ан'Кіраджа", "安其拉之门", "アン・キラージの門", "안퀴라즈 성문" },   -- aq
	{ "Naxxramas", "Наксрамас", "纳克萨玛斯", "ナクスラーマス", "낙스라마스" },   -- naxx
}
local ZONE_RANK = {}
for rank = 1, table.getn(ZONES) do
	for _, name in pairs(ZONES[rank]) do
		ZONE_RANK[name] = rank
	end
end

local builds = {}               -- [name] = { spells, jewelry, worn, stats, best }
local pending = {}              -- [name] = the build coming in, until its E
local queue = {}                -- our lines waiting to go
local sentLines, sentSignature, sentAt
local asked                     -- a friend asked for ours
local inParty

local function Members()
	local ok, count = pcall(GetNumPartyMembers)
	return ok and tonumber(count) or 0
end

-- "~" splits the fields: in a name or a tag it becomes "-".
local function Clean(text)
	return (string.gsub(tostring(text or ""), "~", "-"))
end

local function ShortIcon(texture)
	return Clean((string.gsub(texture or "", "^[Ii]nterface\\[Ii]cons\\", "")))
end

local function Hex(color)
	return string.format("%02x%02x%02x", math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function Color(hex)
	if not hex or string.len(hex) ~= 6 then
		return MUTED
	end
	return { (tonumber(string.sub(hex, 1, 2), 16) or 115) / 255, (tonumber(string.sub(hex, 3, 4), 16) or 115) / 255,
		(tonumber(string.sub(hex, 5, 6), 16) or 115) / 255 }
end

local function Short(value)
	return SurvivorUI_Abbrev and SurvivorUI_Abbrev(value) or tostring(math.floor((tonumber(value) or 0) + 0.5))
end

------------------------------------------------------------------------------
-- Ours, as lines.

-- What changes a build, cheap to read each second: the game's spells and
-- their ranks, and the links worn. The lines themselves are made only when
-- it changes, or every 10 seconds (the damage, the crits, the numbers, the
-- best run, and a piece's rank or stars in its tooltip alone).
local function Signature()
	local parts = {}
	local spells = AZS_SPELLS or {}
	for index = 1, table.getn(spells) do
		local entry = spells[index]
		table.insert(parts, tostring(entry.key or entry[1]).."="..tostring(entry.rank or entry[3]))
	end
	for slot = 1, 19 do
		table.insert(parts, GetInventoryItemLink("player", slot) or "")
	end
	return table.concat(parts, ";")
end

-- Our spells as the damage meter has them: the most damage first, those with
-- none yet by rank, the racial last; each with its damage, share and biggest
-- crit.
local function Spells()
	local spells = SurvivorUI_BuildSnapshot and SurvivorUI_BuildSnapshot() or {}
	local dealt = {}
	local meter = AZS_GetMeter and AZS_GetMeter() or {}
	for index = 1, table.getn(meter) do
		local line = meter[index]
		dealt[SurvivorUI_English and SurvivorUI_English(line.name) or line.name] = line
	end
	for index = 1, table.getn(spells) do
		local spell = spells[index]
		local line = dealt[spell.name]
		spell.dmg = line and tonumber(line.dmg) or 0
		spell.share = line and tonumber(line.share) or 0
		spell.crit = SurvivorUI_CritBest and SurvivorUI_CritBest(spell.name) or nil
		spell.racial = spell.racial and true or false
		spell.order = index
	end
	table.sort(spells, function(a, b)
		if a.racial ~= b.racial then
			return b.racial
		end
		if a.dmg ~= b.dmg then
			return a.dmg > b.dmg
		end
		return a.order < b.order
	end)
	return spells
end

-- A piece worn's stars, off its tooltip (a tooltip of the addon's own,
-- unseen); nil for one with none (jewelry, a piece not of the armory).
local scan = CreateFrame("GameTooltip", "SurvivorUIPartyScan", nil, "GameTooltipTemplate")

local function Stars(slot)
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local stars
	for line = 2, scan:NumLines() do
		local text = getglobal("SurvivorUIPartyScanTextLeft"..line)
		text = text and text:GetText() or ""
		local _, _, n = string.find(text, "(%d+)/%d+")
		if n and not stars then
			for _, word in pairs(STAR_WORDS) do
				if string.find(text, word, 1, true) then
					stars = tonumber(n)
					break
				end
			end
		end
	end
	scan:Hide()
	return stars
end

-- Whether a run's place (won, zone, Heroic, length) comes before another's.
local function Before(a, b)
	for part = 1, table.getn(a) do
		if a[part] ~= b[part] then
			return a[part] > b[part]
		end
	end
	return false
end

-- The best run Run History keeps (the order at the top), or nil; of two
-- alike, the newer.
local function BestRun()
	local runs = SurvivorUIDB and SurvivorUIDB.runHistory or {}
	local best, bestPlace
	for index = 1, table.getn(runs) do
		local run = runs[index]
		local endless = run.endless and tonumber(run.endless.time)
		local place = { (run.result == "victory" or endless) and 1 or 0, ZONE_RANK[run.zone or ""] or 0,
			tonumber(run.heroic) or 0, endless or tonumber(run.time) or 0 }
		if not bestPlace or Before(place, bestPlace) then
			best, bestPlace = run, place
		end
	end
	return best
end

-- The numbers, by their names in order, a few lines of them.
local function Numbers(lines)
	local keys = {}
	for key, value in pairs(AZS_STATS or {}) do
		if type(value) == "number" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local chunk = ""
	for index = 1, table.getn(keys) do
		local pair = keys[index].."="..string.format("%.5g", AZS_STATS[keys[index]])
		if string.len(chunk) + string.len(pair) > 200 then
			table.insert(lines, "A~"..chunk)
			chunk = ""
		end
		chunk = chunk == "" and pair or chunk..";"..pair
	end
	if chunk ~= "" then
		table.insert(lines, "A~"..chunk)
	end
end

local function Lines()
	local lines = { "B~"..VERSION }
	local spells = Spells()
	for index = 1, table.getn(spells) do
		local spell = spells[index]
		table.insert(lines, "S~"..ShortIcon(spell.icon).."~"..(spell.rank or "").."~"..(spell.racial and "1" or "")
			.."~"..Clean(spell.name).."~"..string.format("%.0f", spell.dmg).."~"..string.format("%.3f", spell.share)
			.."~"..(spell.crit and string.format("%.0f", spell.crit) or ""))
	end
	local jewelry = SurvivorUI_GearSnapshot and SurvivorUI_GearSnapshot() or {}
	for index = 1, table.getn(jewelry) do
		local piece = jewelry[index]
		if piece.empty then
			table.insert(lines, "J~~~"..Clean(piece.label).."~~")
		else
			table.insert(lines, "J~"..Hex(piece.color).."~"..(piece.item or "").."~"..Clean(piece.label)
				.."~"..Clean(piece.tags).."~"..Clean(piece.name))
		end
	end
	for index = 1, table.getn(WORN) do
		local slot = WORN[index]
		local link = GetInventoryItemLink("player", slot)
		if link then
			local _, _, color = string.find(link, "|c%x%x(%x%x%x%x%x%x)")
			local _, _, item = string.find(link, "|H(item:[%d:%-]+)|h")
			local _, _, name = string.find(link, "%[(.-)%]")
			table.insert(lines, "I~"..slot.."~"..(color or "").."~"..ShortIcon(GetInventoryItemTexture("player", slot))
				.."~"..(item or "").."~"..Clean(name).."~"..(Stars(slot) or ""))
		end
	end
	Numbers(lines)
	local best = BestRun()
	if best then
		local endless = best.endless and tonumber(best.endless.time)
		table.insert(lines, "R~"..Clean(best.zone).."~"..(tonumber(best.heroic) or 0).."~"
			..(endless and "endless" or Clean(best.result)).."~"..Clean(best.class).."~"..Clean(best.classKey).."~"
			..string.format("%.0f", endless or tonumber(best.time) or 0))
	end
	table.insert(lines, "E")
	return lines
end

------------------------------------------------------------------------------
-- Theirs, line by line.

local viewer
local Draw

local function Fields(rest)
	local fields = {}
	for field in string.gfind(rest.."~", "([^~]*)~") do
		table.insert(fields, field)
	end
	return fields
end

local function Receive(message, sender)
	if message == "?" then
		asked = true
		return
	elseif message == "X" then
		builds[sender], pending[sender] = nil, nil
		if viewer:IsShown() and viewer.name == sender and not viewer.sample then
			viewer:Hide()
		end
		return
	end
	local kind, fields = string.sub(message, 1, 1), Fields(string.sub(message, 3))
	if kind == "B" then
		pending[sender] = fields[1] == VERSION and { spells = {}, jewelry = {}, worn = {}, stats = {} } or nil
		return
	end
	local build = pending[sender]
	if not build then
		return
	end
	if kind == "S" then
		table.insert(build.spells, { icon = fields[1], rank = tonumber(fields[2]), racial = fields[3] == "1",
			name = fields[4], dmg = tonumber(fields[5]) or 0, share = tonumber(fields[6]) or 0, crit = tonumber(fields[7]) })
	elseif kind == "J" then
		table.insert(build.jewelry, { color = fields[1], item = fields[2], label = fields[3], tags = fields[4],
			name = fields[5] })
	elseif kind == "I" then
		table.insert(build.worn, { slot = tonumber(fields[1]), color = fields[2], icon = fields[3], item = fields[4],
			name = fields[5], stars = tonumber(fields[6]) })
	elseif kind == "R" then
		build.best = { zone = fields[1], heroic = tonumber(fields[2]) or 0, result = fields[3], class = fields[4],
			classKey = fields[5], time = tonumber(fields[6]) or 0 }
	elseif kind == "A" then
		for key, value in string.gfind(fields[1] or "", "(%w+)=([^;]*)") do
			build.stats[key] = tonumber(value)
		end
	elseif kind == "E" then
		pending[sender] = nil
		builds[sender] = build
		if viewer:IsShown() and viewer.name == sender and not viewer.sample then
			Draw()
		end
	end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function()
	if arg1 == PREFIX and arg4 and arg4 ~= UnitName("player") then
		Receive(arg2, arg4)
	end
end)

-- Those who left the party taken away.
local function Forget()
	local here = {}
	for index = 1, 4 do
		local name = UnitName("party"..index)
		if name then
			here[name] = true
		end
	end
	for name in pairs(builds) do
		if not here[name] then
			builds[name] = nil
		end
	end
end

------------------------------------------------------------------------------
-- Each second: in a party, ours sent again when it changed or was asked for
-- (and every one asked for theirs as we join); a few lines a tenth of a
-- second, never a flood. Ours goes only while it is shared (the Party tab,
-- "Share my build with the party", on unless turned off); turned off, the
-- friends are told to forget it (X).

local function Sharing()
	return not (SurvivorUIDB and SurvivorUIDB.shareBuild == false)
end

local wait, flush = 0, 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	flush = flush + arg1
	if flush >= 0.1 then
		flush = 0
		for _ = 1, 4 do
			local line = table.remove(queue, 1)
			if not line then
				break
			end
			if SendAddonMessage and Members() > 0 then
				SendAddonMessage(PREFIX, line, "PARTY")
			end
		end
	end
	wait = wait + arg1
	if wait < 1 then
		return
	end
	wait = 0
	Forget()
	if Members() == 0 then
		inParty, sentLines, sentSignature, asked = nil, nil, nil, nil
		queue = {}
		return
	end
	local joining = not inParty
	inParty = true
	if not Sharing() then
		if sentLines then
			queue = { "X" }
			sentLines, sentSignature = nil, nil
		end
		if joining then
			table.insert(queue, "?")
		end
		asked = nil
		return
	end
	local signature = Signature()
	if asked or joining or not sentLines or signature ~= sentSignature or GetTime() - (sentAt or 0) > 10 then
		local lines = Lines()
		local joined = table.concat(lines, "\n")
		if asked or joined ~= sentLines then
			queue = lines
			sentLines = joined
		end
		if joining then
			table.insert(queue, "?")
		end
		sentSignature, sentAt, asked = signature, GetTime(), nil
	end
end)

------------------------------------------------------------------------------
-- The window, beside the friend's icon: their build. Dragged anywhere, by any
-- of it, it stays there.

viewer = CreateFrame("Frame", "SurvivorUIPartyBuild", UIParent)
viewer:SetWidth(SIZE.WIDTH)
viewer:SetHeight(80)
viewer:SetFrameStrata("DIALOG")
viewer:SetClampedToScreen(true)
viewer:SetMovable(true)
viewer:EnableMouse(true)
viewer:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
viewer:SetBackdropColor(0.04, 0.04, 0.07, 0.97)
viewer:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUIPartyBuild")
end

-- Its place: where it was dragged to, held by its top left; else beside the
-- friend's icon, on the side away from the screen's edge.
local function Place(anchor)
	viewer:ClearAllPoints()
	local db = SurvivorUIDB
	if db and db.partyBuildLeft and db.partyBuildTop then
		viewer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.partyBuildLeft, db.partyBuildTop)
	elseif (anchor:GetLeft() or 0) > SIZE.WIDTH + 12 then
		viewer:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -6, 0)
	else
		viewer:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 6, 0)
	end
end

local function DragStart()
	viewer:StartMoving()
end

local function DragStop()
	viewer:StopMovingOrSizing()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.partyBuildLeft = math.floor(viewer:GetLeft() + 0.5)
	SurvivorUIDB.partyBuildTop = math.floor(viewer:GetTop() + 0.5)
	viewer:ClearAllPoints()
	viewer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", SurvivorUIDB.partyBuildLeft, SurvivorUIDB.partyBuildTop)
end

viewer:RegisterForDrag("LeftButton")
viewer:SetScript("OnDragStart", DragStart)
viewer:SetScript("OnDragStop", DragStop)

-- A click anywhere else closes it: a sheet over the rest of the screen, under
-- it, there only while it shows.
local catcher = CreateFrame("Button", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("HIGH")
catcher:EnableMouse(true)
catcher:SetScript("OnMouseDown", function() viewer:Hide() end)
catcher:Hide()
viewer:SetScript("OnShow", function() catcher:Show() end)
viewer:SetScript("OnHide", function() catcher:Hide() end)

local function Text(parent, size, point, x, y)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_FONT, size + FONT_BUMP, "OUTLINE")
	text:SetPoint(point, parent, point, x, y)
	return text
end

viewer.title = Text(viewer, 12, "TOPLEFT", SIZE.PAD, -7)
-- Under the name, their best run.
viewer.best = Text(viewer, 9, "TOPLEFT", SIZE.PAD, -23)

local close = CreateFrame("Button", nil, viewer)
close:SetWidth(14)
close:SetHeight(14)
close:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", -3, -3)
close.text = Text(close, 10, "CENTER", 0, 0)
close.text:SetText(SurvivorUI_T("x"))
close.text:SetTextColor(0.85, 0.85, 0.9)
close:SetScript("OnClick", function() viewer:Hide() end)
close:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
close:SetScript("OnLeave", function() this.text:SetTextColor(0.85, 0.85, 0.9) end)

-- A row's tooltip: a piece's own (its link; a sample's, its name), a spell's
-- numbers, a number's meaning.
local function RowTip()
	local tip = this.tip
	if not tip then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOMLEFT", this, "TOPRIGHT", 4, 0)
	if tip.name then
		local ok = tip.item and pcall(GameTooltip.SetHyperlink, GameTooltip, tip.item)
		if not ok or GameTooltip:NumLines() == 0 then
			GameTooltip:SetText(tip.name, 1, 1, 1)
		end
	elseif tip.spell then
		local spell = tip.spell
		GameTooltip:SetText(spell.name or "?", 1, 1, 1)
		if spell.rank then
			GameTooltip:AddLine(SurvivorUI_RankText and SurvivorUI_RankText(spell.rank)
				or SurvivorUI_TF("Rank {1}", spell.rank), GOLD[1], GOLD[2], GOLD[3])
		end
		if spell.dmg > 0 then
			GameTooltip:AddDoubleLine(SurvivorUI_T("Damage this run"), Short(spell.dmg).."  ("
				..math.floor(spell.share * 100 + 0.5).."%)", SOFT[1], SOFT[2], SOFT[3], 1, 1, 1)
		end
		if spell.crit then
			GameTooltip:AddDoubleLine(SurvivorUI_T("Biggest crit"), Short(spell.crit), SOFT[1], SOFT[2], SOFT[3], 1, 1, 1)
		end
	else
		GameTooltip:SetText(tip.title or "?", tip.color[1], tip.color[2], tip.color[3])
		if tip.text then
			GameTooltip:AddLine(tip.text, 0.62, 0.62, 0.68, 1)
		end
	end
	GameTooltip:Show()
end

local rows = {}
local used = 0

local function Row(index)
	if rows[index] then
		return rows[index]
	end
	local row = CreateFrame("Button", nil, viewer)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(SIZE.ROW - 2)
	row.icon:SetHeight(SIZE.ROW - 2)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.left = Text(row, 9, "LEFT", 0, 0)
	row.right = Text(row, 9, "RIGHT", 0, 0)
	-- A spell's rank, damage and share, each right-aligned in its column.
	row.cols = { Text(row, 9, "RIGHT", SIZE.RANK, 0), Text(row, 9, "RIGHT", SIZE.DMG, 0),
		Text(row, 9, "RIGHT", SIZE.SHARE, 0) }
	row:SetScript("OnEnter", RowTip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Dragged by a row too, the window goes.
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", DragStart)
	row:SetScript("OnDragStop", DragStop)
	rows[index] = row
	return row
end

-- One line at x, y down from the top, width wide: { icon, left, color, right,
-- rightColor, cols (a spell's), height, tip }; down by its height.
local function Line(x, y, width, line)
	used = used + 1
	local row = Row(used)
	local height = line.height or SIZE.ROW
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", viewer, "TOPLEFT", x, -y)
	row:SetWidth(width)
	row:SetHeight(height)
	row.tip = line.tip
	row.left:ClearAllPoints()
	if line.icon then
		row.icon:SetTexture(line.icon)
		row.icon:Show()
		row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	else
		row.icon:Hide()
		row.left:SetPoint("LEFT", row, "LEFT", 0, 0)
	end
	local color, other = line.color or SOFT, line.rightColor or SOFT
	row.left:SetText(line.left or "")
	row.left:SetTextColor(color[1], color[2], color[3])
	row.right:SetText(line.right or "")
	row.right:SetTextColor(other[1], other[2], other[3])
	local cols = line.cols or {}
	for index = 1, 3 do
		row.cols[index]:SetText(cols[index] or "")
		row.cols[index]:SetTextColor(other[1], other[2], other[3])
	end
	row:Show()
	return y + height
end

-- The left column: the spells as the damage meter has them, the jewelry,
-- what they wear. The bottom comes back.
local function DrawBuild(build, x, width)
	local y = SIZE.TOP
	y = Line(x, y, width, { left = SurvivorUI_T("Spells"), color = GOLD, height = SIZE.HEAD, rightColor = MUTED,
		right = SurvivorUI_T("Crit"), cols = { SurvivorUI_T("Rank"), SurvivorUI_T("Damage"), "%" } })
	if table.getn(build.spells) == 0 then
		y = Line(x, y, width, { left = SurvivorUI_T("None yet"), color = MUTED })
	end
	for index = 1, table.getn(build.spells) do
		local spell = build.spells[index]
		local rank = spell.rank and (SurvivorUI_RankText and SurvivorUI_RankText(spell.rank, true) or tostring(spell.rank))
		y = Line(x, y, width, { icon = spell.icon ~= "" and ICONS..spell.icon or nil,
			left = spell.racial and SurvivorUI_TF("{1} (racial)", spell.name) or spell.name,
			color = spell.racial and { 0.45, 0.75, 1 } or { 1, 1, 1 },
			cols = { rank, spell.dmg > 0 and Short(spell.dmg) or "-", spell.dmg > 0 and math.floor(spell.share * 100 + 0.5).."%" or "" },
			right = spell.crit and Short(spell.crit) or "-", rightColor = SOFT, tip = { spell = spell } })
	end
	y = Line(x, y + 4, width, { left = SurvivorUI_T("Jewelry"), color = GOLD, height = SIZE.HEAD })
	for index = 1, table.getn(build.jewelry) do
		local piece = build.jewelry[index]
		local empty = piece.item == ""
		y = Line(x, y, width, { left = piece.label, color = empty and MUTED or Color(piece.color),
			right = empty and "-" or piece.tags, tip = not empty and { item = piece.item, name = piece.name } or nil })
	end
	if table.getn(build.worn) > 0 then
		y = Line(x, y + 4, width, { left = SurvivorUI_T("Gear"), color = GOLD, height = SIZE.HEAD })
		for index = 1, table.getn(build.worn) do
			local piece = build.worn[index]
			-- Its stars after its name: "Frostfire Gloves +3".
			local stars = piece.stars and piece.stars > 0 and " +"..piece.stars or ""
			y = Line(x, y, width, { icon = piece.icon ~= "" and ICONS..piece.icon or nil, left = piece.name..stars,
				color = Color(piece.color), tip = { item = piece.item, name = piece.name } })
		end
	end
	return y
end

-- The right column: their numbers as the Stats panel draws them (its groups,
-- its colors, a number at 0 left out). The bottom comes back.
local function DrawStats(build, x, width)
	local y = SIZE.TOP
	local sections = SurvivorUI_StatList and SurvivorUI_StatList() or {}
	local kept = build.stats
	local stats = setmetatable({}, { __index = function(_, key) return kept[key] or 0 end })
	for index = 1, table.getn(sections) do
		local section = sections[index]
		local lines = {}
		for each = 1, table.getn(section.rows) do
			local entry = section.rows[each]
			local ok, text = pcall(entry[2], stats)
			text = ok and text and tostring(text)
			if text and string.find(text, "[1-9]") then
				table.insert(lines, { entry[1], text, entry[3] })
			end
		end
		if table.getn(lines) > 0 then
			local color = section.color
			y = Line(x, y + (y > SIZE.TOP and 4 or 0), width, { left = string.upper(SurvivorUI_T(section.title)),
				color = color, height = SIZE.HEAD })
			for each = 1, table.getn(lines) do
				local label = SurvivorUI_StatName and SurvivorUI_StatName(lines[each][1]) or lines[each][1]
				y = Line(x, y, width, { left = label, color = color, right = lines[each][2], rightColor = color,
					height = SIZE.LINE, tip = { title = label.." "..lines[each][2], text = lines[each][3], color = color } })
			end
		end
	end
	if y == SIZE.TOP then
		y = Line(x, y, width, { left = SurvivorUI_T("No numbers yet"), color = MUTED })
	end
	return y
end

-- How each run ended, its word and color (Run History's).
local RESULTS = {
	victory = { "Victory", "9effa8" }, endless = { "Endless", "dba8ff" },
	dead = { "Fallen", "ff8c7a" }, left = { "Left", "9ed1ff" },
}

-- Under the name, their best run: "Best run  Naxxramas  Heroic I  Victory 20:16
-- Mage", the map green, the level gold, the end in its color, the class in its.
local function BestLine(best)
	if not best then
		return "|cff9a9aa0"..SurvivorUI_T("Best run: none kept yet").."|r"
	end
	local result = RESULTS[best.result] or { best.result or "?", "ffffff" }
	local r, g, b = 1, 1, 1
	if SurvivorUI_ClassColor and best.classKey ~= "" then
		r, g, b = SurvivorUI_ClassColor(best.classKey)
	end
	local seconds = math.floor(best.time)
	return string.format("|cff9a9aa0%s|r  |cff4dff70%s|r  |cffffd100%s|r  |cff%s%s %d:%02d|r  |cff%02x%02x%02x%s|r",
		SurvivorUI_T("Best run"), best.zone, SurvivorUI_HeroicName and SurvivorUI_HeroicName(best.heroic) or "",
		result[2], SurvivorUI_T(result[1]), math.floor(seconds / 60), math.mod(seconds, 60),
		math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), best.class or "")
end

-- The party frames' samples' builds while they are placed (Party.lua):
-- Friend's and Another's, every part of the window shown; Healer has none, as
-- a friend without Survivor UI.
local DOT = " \194\183 "
local SAMPLES = {
	Friend = {
		best = { zone = "Gates of Ahn'Qiraj", heroic = 3, result = "victory", class = "Warrior", classKey = "WARRIOR",
			time = 1200 },
		spells = {
			{ icon = "Ability_Whirlwind", rank = 18, name = "Whirlwind", dmg = 96400, share = 0.21, crit = 4210 },
			{ icon = "Ability_Warrior_Cleave", rank = 15, name = "Cleave", dmg = 51200, share = 0.11, crit = 2930 },
			{ icon = "Spell_Nature_ThunderClap", rank = 12, name = "Thunder Clap", dmg = 20800, share = 0.05, crit = 1480 },
			{ icon = "Ability_Warrior_BattleShout", rank = 9, name = "Battle Shout", dmg = 0, share = 0 },
			{ icon = "Racial_Orc_BerserkerStrength", rank = 1, racial = true, name = "Blood Fury", dmg = 0, share = 0 },
		},
		jewelry = {
			{ color = "ff8000", label = "WW  V", tags = "DMG"..DOT.."CRIT", name = "Amulet of the Storm: Whirlwind" },
			{ color = "a335ee", label = "Ring  X", tags = "HASTE", name = "Band of Fury" },
			{ color = "0070dd", label = "Ring  VII", tags = "CRIT", name = "Signet of Strength" },
			{ color = "a335ee", label = "Trinket  IX", tags = "AREA", name = "Earthstrike" },
			{ item = "", label = "Trinket" },
		},
		worn = {
			{ color = "a335ee", icon = "INV_Helmet_03", name = "Helm of Wrath", stars = 4 },
			{ color = "a335ee", icon = "INV_Shoulder_29", name = "Pauldrons of Wrath", stars = 5 },
			{ color = "a335ee", icon = "INV_Chest_Plate06", name = "Breastplate of Wrath", stars = 5 },
			{ color = "0070dd", icon = "INV_Gauntlets_04", name = "Gauntlets of Wrath", stars = 2 },
		},
		stats = { crit = 0.18, cm = 2.1, dmg = 2.4, cd = 0.78, echo = 0.08, hp = 2350, reg = 14.5, lch = 0.02, arm = 0.38,
			area = 1.25, cnt = 1, pick = 9, spd = 1.3, xp = 1.15, gold = 1.2, luck = 0.4, big = 0.25, auto = 0.3 },
	},
	Another = {
		best = { zone = "Naxxramas", heroic = 1, result = "endless", class = "Mage", classKey = "MAGE", time = 1870 },
		spells = {
			{ icon = "Spell_Holy_Excorcism_02", rank = 20, name = "Blast Wave", dmg = 225800, share = 0.19, crit = 17400 },
			{ icon = "Spell_Fire_SelfDestruct", rank = 15, name = "Flamestrike", dmg = 104300, share = 0.09, crit = 3620 },
			{ icon = "Spell_Fire_FlameBolt", rank = 7, name = "Fireball", dmg = 12600, share = 0.01, crit = 9080 },
			{ icon = "Spell_Frost_FrostNova", rank = 5, name = "Frost Nova", dmg = 0, share = 0 },
			{ icon = "Ability_Rogue_Trip", rank = 1, racial = true, name = "Escape Artist", dmg = 0, share = 0 },
		},
		jewelry = {
			{ color = "ff8000", label = "BW  V", tags = "CDR"..DOT.."DMG", name = "Heart of the Earthbreaker: Blast Wave" },
			{ color = "a335ee", label = "Ring  X+", tags = "ECHO", name = "Ring of Accuria" },
			{ color = "a335ee", label = "Ring  VIII", tags = "CRIT", name = "Band of the Inevitable" },
			{ color = "0070dd", label = "Trinket  VI", tags = "AREA", name = "Talisman of Ephemeral Power" },
			{ color = "a335ee", label = "Trinket  VII", tags = "DMG", name = "Mind Quickening Gem" },
		},
		worn = {
			{ color = "a335ee", icon = "INV_Helmet_29", name = "Frostfire Circlet", stars = 3 },
			{ color = "a335ee", icon = "INV_Chest_Cloth_05", name = "Frostfire Robe", stars = 4 },
			{ color = "a335ee", icon = "INV_Gauntlets_14", name = "Frostfire Gloves", stars = 3 },
			{ color = "0070dd", icon = "INV_Pants_08", name = "Frostfire Leggings", stars = 1 },
			{ color = "1eff00", icon = "INV_Boots_05", name = "Frostfire Sandals" },
		},
		stats = { crit = 0.33, cm = 5.8, dmg = 4.9, cd = 0.62, echo = 0.22, hp = 980, reg = 6.2, arm = 0.12, area = 1.4,
			cnt = 2, pick = 12, spd = 1.45, xp = 1.3, gold = 1.35, luck = 1.1, dots = 3, doth = 0.2, dotd = 0.15 },
	},
}

-- The build shown: a friend's as it came, or a sample's.
local function ShownBuild()
	if viewer.sample then
		return SAMPLES[viewer.name]
	end
	return builds[viewer.name]
end

Draw = function()
	local build = ShownBuild()
	if not build then
		viewer:Hide()
		return
	end
	used = 0
	viewer.best:SetText(BestLine(build.best))
	local left = DrawBuild(build, SIZE.PAD, SIZE.LEFT)
	local bottom = math.max(left, DrawStats(build, SIZE.PAD + SIZE.LEFT + SIZE.GAP, SIZE.RIGHT))
	for index = used + 1, table.getn(rows) do
		rows[index]:Hide()
	end
	viewer:SetHeight(bottom + 6)
end

------------------------------------------------------------------------------
-- For the party frames (Party.lua).

-- A friend's build as their Survivor UI sent it, or a sample's (sample: the
-- party frames' samples); nil without one.
function SurvivorUI_PartyBuildOf(name, sample)
	if sample then
		return SAMPLES[name]
	end
	return name and builds[name]
end

-- Open a friend's build (or a sample's) beside their icon (anchor), in their
-- class's color; again, closed.
function SurvivorUI_TogglePartyBuild(name, anchor, class, sample)
	if viewer:IsShown() and viewer.name == name then
		viewer:Hide()
		return
	end
	if not SurvivorUI_PartyBuildOf(name, sample) then
		return
	end
	viewer.name, viewer.sample = name, sample
	local r, g, b = 1, 0.82, 0
	if SurvivorUI_ClassColor then
		r, g, b = SurvivorUI_ClassColor(class)
	end
	viewer.title:SetText(name)
	viewer.title:SetTextColor(r, g, b)
	viewer:SetBackdropBorderColor(r, g, b, 0.8)
	Place(anchor)
	Draw()
	viewer:Show()
end
