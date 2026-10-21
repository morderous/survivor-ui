-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the ability tooltip, laid out again.
--
-- The game writes an ability's tooltip itself: the name and rank, how it is
-- cast and its cooldown, a description, then "Upgrades: ...", "Your bonuses:
-- ..." and "Talents: ..." as comma lists, and the crit chance. This file reads
-- those lines back once the game has written them and lays them out again:
-- a summary under the name, the numbers of the description in white, each
-- upgrade, bonus and talent on a line of its own, and a rule between the
-- sections. The tooltip stays where the game placed it.
--
-- The game rewrites the tooltip a few times a second while the mouse stays,
-- so the layout is redone whenever its text changes. A tooltip it cannot read
-- is left as the game wrote it.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local DOT = " \194\183 "

-- Upgrades come from the level-up cards (gold, as theirs), bonuses from what
-- is worn (green), talents from the talent tree (blue).
local SECTIONS = {
	{ prefix = "Upgrades: ",     title = "Upgrades",     color = { 1.00, 0.82, 0.30 } },
	{ prefix = "Your bonuses: ", title = "Your bonuses", color = { 0.12, 1.00, 0.00 } },
	{ prefix = "Talents: ",      title = "Talents",      color = { 0.44, 0.84, 1.00 } },
}

local DESCRIPTION_COLOR = { 0.72, 0.72, 0.72 }   -- neutral, so the school's color stands out
local HEAL_HEX = "|cff4dff70"                     -- a heal's amount, green
local RACE_COLOR = { 1.00, 0.82, 0.00 }

-- An ability wears the color of its school: the one its description names
-- ("29 Holy damage"), else its own (a heal or a buff names none), else
-- physical, red.
local SCHOOL_COLORS = {
	Holy     = { 1.00, 0.78, 0.15 },
	Fire     = { 1.00, 0.50, 0.10 },
	Frost    = { 0.30, 0.72, 1.00 },
	Nature   = { 0.30, 0.88, 0.25 },
	Shadow   = { 0.66, 0.38, 1.00 },
	Arcane   = { 1.00, 0.40, 0.85 },
	Physical = { 0.95, 0.27, 0.24 },
}
local SCHOOL_OF = {}
for school, names in pairs({
	Holy = { "Consecration", "Exorcism", "Hammer of Wrath", "Holy Shock", "Holy Wrath", "Judgement",
		"Hammer of Justice", "Holy Light", "Divine Shield", "Holy Shield", "Redemption", "Smite", "Holy Nova",
		"Power Word: Shield", "Renew", "Holy Fire", "Lightwell" },
	Shadow = { "Shadow Word: Pain", "Mind Blast", "Mind Flay", "Psychic Scream", "Devouring Plague", "Shadow Bolt",
		"Corruption", "Curse of Agony", "Death Coil", "Drain Life", "Fear", "Shadowmeld" },
	Fire = { "Flame Shock", "Magma Totem", "Searing Totem", "Fire Nova", "Call of Flame", "Fireball", "Flamestrike",
		"Fire Blast", "Blast Wave", "Pyroblast", "Immolate", "Rain of Fire", "Hellfire", "Searing Pain", "Soul Fire",
		"Explosive Trap", "Immolation Trap" },
	Frost = { "Frost Shock", "Frostbolt", "Frost Nova", "Blizzard", "Cone of Cold", "Ice Barrier", "Frost Trap" },
	Arcane = { "Arcane Missiles", "Arcane Explosion", "Polymorph", "Arcane Shot", "Moonfire", "Starfire",
		"Hunter's Mark", "Volley" },
	Nature = { "Lightning Bolt", "Chain Lightning", "Earth Shock", "Lightning Shield", "Healing Wave", "Wrath",
		"Hurricane", "Insect Swarm", "Entangling Roots", "Rejuvenation", "Regrowth", "Thorns", "Faerie Fire",
		"Serpent Sting" },
}) do
	for index = 1, table.getn(names) do
		SCHOOL_OF[names[index]] = school
	end
end

-- Each kind of number in a color of its own, the same in the summary and in
-- the description, so it reads at a glance: time blue, distance mint, a share
-- gold, damage its school's, a heal or a shield green, a count white. The
-- game's own rules (the same for everyone) take a dim shade of their kind's
-- color, so the eye goes to what the build changes. The words stay muted.
local COOLDOWN_HEX = "|cff8cccff"   -- light blue: seconds
local REACH_HEX = "|cff99f2bf"      -- mint: yards
local CRIT_HEX = "|cffffc214"       -- gold: a share, a critical strike's
local MUTED = { 0.62, 0.62, 0.62 }
local CODE = "|c%x%x%x%x%x%x%x%x"
local FIXED = {
	{ "(enemies are within )"..CODE.."([%d%.]+ yd)|r", "%1|cff5f9a80%2|r" },
	{ "(below )"..CODE.."([%d%.]+%%)|r( health)", "%1|cffa3842e%2|r%3" },
	{ CODE.."([%d%.]+%%)|r( weaker with each jump)", "|cffa3842e%1|r%2" },
}
-- What an ability does, by how its description begins: the second line says
-- it ("Nature heal", "Buff"), a buff's name in amber.
local KINDS = {
	{ "^Heals you", "heal" }, { "^Absorbs", "shield" }, { "^Shields you", "shield" },
	{ "^Makes you immune", "immunity" }, { "^Increases all your damage", "buff" },
	{ "^Your cooldowns recover", "buff" }, { "^For [%d%.]+ sec, enemies that hit you", "thorns" },
	{ "flee for", "control" }, { "^Roots", "control" }, { "^Stuns", "control" },
}
local BUFF_COLOR = { 1.00, 0.76, 0.30 }
local HEAL_COLOR = { 0.30, 1.00, 0.44 }

------------------------------------------------------------------------------
-- Rules: thin lines drawn across the tooltip, each over a blank line.

local rules = {}
local rulesUsed = 0

local function HideRules()
	for index = 1, table.getn(rules) do
		rules[index]:Hide()
	end
	rulesUsed = 0
end

local function Rule(line, color)
	rulesUsed = rulesUsed + 1
	local rule = rules[rulesUsed]
	if not rule then
		rule = GameTooltip:CreateTexture(nil, "ARTWORK")
		rule:SetTexture(FLAT)
		rule:SetHeight(1)
		rules[rulesUsed] = rule
	end
	local text = getglobal("GameTooltipTextLeft"..line)
	rule:ClearAllPoints()
	rule:SetPoint("LEFT", text, "LEFT", 0, 0)
	rule:SetPoint("RIGHT", GameTooltip, "RIGHT", -10, 0)
	rule:SetVertexColor(color[1], color[2], color[3], 0.6)
	rule:Show()
end

------------------------------------------------------------------------------
-- Reading what the game wrote.

local function Plain(text)
	text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	return text
end

local function Signature()
	local parts = {}
	for line = 1, GameTooltip:NumLines() do
		local left = getglobal("GameTooltipTextLeft"..line)
		local right = getglobal("GameTooltipTextRight"..line)
		table.insert(parts, (left and left:GetText() or "").."~"..(right and right:IsShown() and right:GetText() or ""))
	end
	return table.concat(parts, "^")
end

-- "a, b, c" into { "a", "b", "c" }
local function List(text)
	local items = {}
	for item in string.gfind(text, "[^,]+") do
		item = string.gsub(item, "^%s+", "")
		item = string.gsub(item, "%s+$", "")
		if item ~= "" then
			table.insert(items, item)
		end
	end
	return items
end

-- Returns the tooltip's pieces, or nil when it is not an ability's.
local function Read()
	local count = GameTooltip:NumLines()
	if count < 2 then
		return nil
	end

	local ability = { stats = {}, description = {}, sections = {}, other = {} }
	local title = getglobal("GameTooltipTextLeft1")
	local rank = getglobal("GameTooltipTextRight1")
	ability.title = Plain(title:GetText())
	ability.rank = rank:IsShown() and Plain(rank:GetText()) or nil

	-- The line saying how it is cast: "Automatic" or "Passive", with the
	-- cooldown on its right. Lines above it are short stats ("11 yd radius").
	local castLine
	for line = 2, count do
		local left = Plain(getglobal("GameTooltipTextLeft"..line):GetText())
		local right = getglobal("GameTooltipTextRight"..line)
		local rightText = right:IsShown() and Plain(right:GetText()) or ""
		if string.find(rightText, "cooldown", 1, true) or left == "Automatic" or left == "Passive" then
			castLine = line
			ability.cast = left
			ability.cooldown = rightText ~= "" and rightText or nil
			break
		end
	end
	if not castLine then
		return nil
	end
	for line = 2, castLine - 1 do
		local text = Plain(getglobal("GameTooltipTextLeft"..line):GetText())
		if text ~= "" then
			table.insert(ability.stats, text)
		end
	end

	-- Everything below, one piece per line of text.
	for line = castLine + 1, count do
		local left = getglobal("GameTooltipTextLeft"..line)
		local r, g, b = left:GetTextColor()
		for piece in string.gfind((left:GetText() or "").."\n", "([^\n]*)\n") do
			local text = Plain(piece)
			local section
			for index = 1, table.getn(SECTIONS) do
				if string.sub(text, 1, string.len(SECTIONS[index].prefix)) == SECTIONS[index].prefix then
					section = SECTIONS[index]
					break
				end
			end
			local _, _, critChance, critDamage = string.find(text, "^(%d+%%) chance to crit for (%d+%%) damage")
			if section then
				table.insert(ability.sections, { info = section, items = List(string.sub(text, string.len(section.prefix) + 1)) })
			elseif critChance then
				ability.crit = critChance.." crit"..DOT..critDamage.." dmg"
			elseif text ~= "" then
				-- The description is the first text below the cast line; the
				-- rest ("Not learned yet", a racial's note) keep their color.
				if table.getn(ability.sections) == 0 and not ability.crit and table.getn(ability.other) == 0
					and (table.getn(ability.description) == 0 or ability.descriptionColor == r..g..b) then
					table.insert(ability.description, text)
					ability.descriptionColor = r..g..b
				else
					table.insert(ability.other, { text = text, color = { r, g, b } })
				end
			end
		end
	end

	-- Only an ability's tooltip has a rank, its upgrade lists or a crit line.
	if not (ability.rank and string.find(ability.rank, "^Rank")) and table.getn(ability.sections) == 0 and not ability.crit then
		return nil
	end
	return ability
end

------------------------------------------------------------------------------
-- Writing it again.

local function Capital(text)
	return string.upper(string.sub(text, 1, 1))..string.sub(text, 2)
end

-- What it does, in a few words, its color, and the school its damage names
-- ("193 Arcane damage", "294 Physical damage"), whose numbers take the color:
-- "Arcane damage"; else a heal or a shield of its spell's school ("Nature
-- heal", "Nature thorns"), a buff, an immunity or control; else (a description in another
-- language) its spell's school.
local function What(ability)
	for index = 1, table.getn(ability.description) do
		for word in string.gfind(ability.description[index], "(%a+) damage") do
			if SCHOOL_COLORS[word] then
				return word.." damage", SCHOOL_COLORS[word], word
			end
		end
	end
	local name = SurvivorUI_English and SurvivorUI_English(ability.title) or ability.title
	local own = SCHOOL_OF[name]
	local first = ability.description[1] or ""
	for index = 1, table.getn(KINDS) do
		if string.find(first, KINDS[index][1]) then
			local kind = KINDS[index][2]
			if kind == "heal" or kind == "shield" or kind == "thorns" then
				return own and own.." "..kind or Capital(kind), own and SCHOOL_COLORS[own] or HEAL_COLOR, nil
			end
			return Capital(kind), own and SCHOOL_COLORS[own] or BUFF_COLOR, nil
		end
	end
	return own or "Physical", SCHOOL_COLORS[own or "Physical"], nil
end

local function Hex(color)
	return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

-- The description's numbers in their kind's color (seconds, yards, a share,
-- the damage of the ability's school, "29 Holy" with its unit), a heal or a
-- shield's amount green, the game's fixed rules back in the text's grey.
local function Highlight(text, school, schoolColor)
	text = string.gsub(text, "(%d[%d%.]*)(%%?)( ?)(%a*)", function(number, percent, space, word)
		if percent ~= "" then
			return CRIT_HEX..number.."%|r"..space..word
		elseif school and word == school then
			return Hex(schoolColor)..number..space..word.."|r"
		elseif word == "sec" then
			return COOLDOWN_HEX..number..space..word.."|r"
		elseif word == "yd" then
			return REACH_HEX..number..space..word.."|r"
		end
		return "|cffffffff"..number.."|r"..space..word
	end)
	if school then
		-- "29 Holy" took the color; "damage" after it joins in.
		text = string.gsub(text, school.."|r damage", school.." damage|r")
	end
	-- What it heals or shields, in green: "Heals you for 136", "for 50%".
	for _, lead in pairs({ "[Hh]eals you for ", "Absorbs the next ", "Absorbs up to ", "Shields you against ", "Restores " }) do
		text = string.gsub(text, "("..lead..")"..CODE, "%1"..HEAL_HEX)
	end
	-- Damage that names no school (thorns: "take 75 damage"), and the damage
	-- of a whole cast ("181 in all"): the ability's color.
	text = string.gsub(text, "|cffffffff([%d%.]+)|r damage", Hex(schoolColor).."%1 damage|r")
	text = string.gsub(text, "|cffffffff([%d%.]+)|r in all", Hex(schoolColor).."%1|r in all")
	for index = 1, table.getn(FIXED) do
		text = string.gsub(text, FIXED[index][1], FIXED[index][2])
	end
	return text
end

local function Spacer(color)
	GameTooltip:AddLine(" ")
	Rule(GameTooltip:NumLines(), color)
end

local function Write(ability)
	HideRules()
	GameTooltip:ClearLines()
	local what, tint, school = What(ability)

	if ability.rank then
		-- "Rank 2", or a Roman numeral, II, as set (the options, Tooltips).
		local _, _, number = string.find(ability.rank, "^Rank (%d+)$")
		local rank = number and SurvivorUI_RankText and SurvivorUI_RankText(number) or ability.rank
		GameTooltip:AddDoubleLine(ability.title, rank, tint[1], tint[2], tint[3], MUTED[1], MUTED[2], MUTED[3])
	else
		GameTooltip:AddLine(ability.title, tint[1], tint[2], tint[3])
	end
	-- "Physical damage · Automatic", what it does in its color; "3.4 sec"
	-- cooldown, "28 yd" range, "7%" crit "204%" damage.
	local cooldown = string.gsub(ability.cooldown or " ", "^([%d%.]+ sec)", COOLDOWN_HEX.."%1|r")
	GameTooltip:AddDoubleLine(Hex(tint)..what.."|r"..DOT..ability.cast, cooldown,
		MUTED[1], MUTED[2], MUTED[3], MUTED[1], MUTED[2], MUTED[3])
	if table.getn(ability.stats) > 0 or ability.crit then
		local reach = string.gsub(table.concat(ability.stats, DOT), "([%d%.]+ yd)", REACH_HEX.."%1|r")
		local crit = string.gsub(ability.crit or " ", "(%d+%%)", CRIT_HEX.."%1|r")
		GameTooltip:AddDoubleLine(reach, crit, MUTED[1], MUTED[2], MUTED[3], MUTED[1], MUTED[2], MUTED[3])
	end

	if table.getn(ability.description) > 0 then
		Spacer(tint)
		for index = 1, table.getn(ability.description) do
			GameTooltip:AddLine(Highlight(ability.description[index], school, tint),
				DESCRIPTION_COLOR[1], DESCRIPTION_COLOR[2], DESCRIPTION_COLOR[3], 1)
		end
	end

	for index = 1, table.getn(ability.sections) do
		local section = ability.sections[index]
		local color = section.info.color
		Spacer(color)
		GameTooltip:AddLine(section.info.title, color[1], color[2], color[3])
		for item = 1, table.getn(section.items) do
			local text = section.items[item]
			-- "+35% damage" as "Damage ... +35%"; a talent is a name alone.
			local _, _, value, label = string.find(text, "^([%+%-]?[%d%.]+%%?) (.+)$")
			if value then
				GameTooltip:AddDoubleLine("  "..Capital(label), value, MUTED[1], MUTED[2], MUTED[3], color[1], color[2], color[3])
			else
				GameTooltip:AddLine("  "..text, color[1], color[2], color[3])
			end
		end
	end

	local racial
	if table.getn(ability.other) > 0 then
		Spacer(MUTED)
		for index = 1, table.getn(ability.other) do
			local other = ability.other[index]
			GameTooltip:AddLine(other.text, other.color[1], other.color[2], other.color[3], 1)
			racial = racial or string.find(other.text, "^Racial")
		end
	end

	-- The racial: the race's traits too, as the game told them in the chat at
	-- a run's start (BuildList.lua).
	local race, traits
	if racial and SurvivorUI_Racials then
		race, traits = SurvivorUI_Racials()
	end
	if traits and table.getn(traits) > 0 then
		Spacer(RACE_COLOR)
		GameTooltip:AddLine((race or "Race").."'s traits", RACE_COLOR[1], RACE_COLOR[2], RACE_COLOR[3])
		for index = 1, table.getn(traits) do
			GameTooltip:AddLine("|cffffd100"..traits[index].name.."|r  "..traits[index].text,
				DESCRIPTION_COLOR[1], DESCRIPTION_COLOR[2], DESCRIPTION_COLOR[3], 1)
		end
	end

	-- Shown again to fit the new lines, where the game placed it.
	GameTooltip:Show()
end

------------------------------------------------------------------------------
-- An item's tooltip, laid out again (the character pane, the jewelry, the
-- loot): the bind line goes, as nothing is traded in a run; the health a
-- piece gives in green; each "Equip:" effect a line of its own under a green
-- rule, without the word, its numbers in their colors as an ability's. It is
-- told by what it says, a bind line or an effect, as the game fills some of
-- these tooltips itself (the character pane's slots); the words are the
-- game's global strings (ITEM_BIND_ON_PICKUP...), in any language, else
-- English's.

local WHITE = { 1, 1, 1 }
local EFFECT_COLOR = { 0.12, 1.00, 0.00 }
local BIND_WORDS = {
	ITEM_BIND_ON_PICKUP = "Binds when picked up", ITEM_BIND_ON_EQUIP = "Binds when equipped",
	ITEM_BIND_ON_USE = "Binds when used", ITEM_SOULBOUND = "Soulbound",
}

-- Its lines: those before its first effect, its effects, those after; nil
-- when it is not an item's (no bind line, no effect) or carries a price.
local function ReadItem()
	local count = GameTooltip:NumLines()
	if count < 2 or (GameTooltipMoneyFrame and GameTooltipMoneyFrame:IsShown()) then
		return nil
	end
	local binds = {}
	for key, english in pairs(BIND_WORDS) do
		binds[getglobal(key) or english] = true
		binds[english] = true
	end
	local equip = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:").." "
	local item = { before = {}, effects = {}, after = {} }
	for line = 1, count do
		local left = getglobal("GameTooltipTextLeft"..line)
		local right = getglobal("GameTooltipTextRight"..line)
		local text = left:GetText() or ""
		local plain = Plain(text)
		if binds[plain] then
			item.bound = true
		elseif string.sub(plain, 1, string.len(equip)) == equip then
			table.insert(item.effects, string.sub(plain, string.len(equip) + 1))
		else
			local r, g, b = left:GetTextColor()
			local entry = { text = text, color = { r, g, b } }
			if right:IsShown() and (right:GetText() or "") ~= "" then
				local rr, rg, rb = right:GetTextColor()
				entry.right, entry.rightColor = right:GetText(), { rr, rg, rb }
			end
			table.insert(table.getn(item.effects) > 0 and item.after or item.before, entry)
		end
	end
	if not (item.bound or table.getn(item.effects) > 0) then
		return nil
	end
	return item
end

local function ItemLine(entry, first)
	local text = entry.text
	-- "+64 Health": the health in green, the other numbers white.
	if not first then
		text = string.gsub(text, "^(%+?[%d%.]+)( [Hh]ealth)$", HEAL_HEX.."%1|r%2")
	end
	local color = entry.color
	if entry.right then
		local right = entry.rightColor
		GameTooltip:AddDoubleLine(text, entry.right, color[1], color[2], color[3], right[1], right[2], right[3])
	else
		GameTooltip:AddLine(text, color[1], color[2], color[3], not first and 1 or nil)
	end
end

local function WriteItem(item)
	HideRules()
	GameTooltip:ClearLines()
	for index = 1, table.getn(item.before) do
		ItemLine(item.before[index], index == 1)
	end
	if table.getn(item.effects) > 0 then
		Spacer(EFFECT_COLOR)
		for index = 1, table.getn(item.effects) do
			GameTooltip:AddLine(Highlight(item.effects[index], nil, WHITE),
				DESCRIPTION_COLOR[1], DESCRIPTION_COLOR[2], DESCRIPTION_COLOR[3], 1)
		end
	end
	if table.getn(item.after) > 0 then
		Spacer(MUTED)
		for index = 1, table.getn(item.after) do
			ItemLine(item.after[index])
		end
	end
	GameTooltip:Show()
end

------------------------------------------------------------------------------
-- Watching for the game's text.

local written                   -- the signature of the last layout written

local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	if not GameTooltip:IsVisible() then
		return
	end
	-- Each switched off as a module: the game's own layout stays.
	local abilities = not SurvivorUI_Feature or SurvivorUI_Feature("abilityTooltip")
	local items = not SurvivorUI_Feature or SurvivorUI_Feature("itemTooltip")
	if not (abilities or items) then
		return
	end
	local signature = Signature()
	if signature == written then
		return
	end
	HideRules()
	written = nil
	local ok, ability = false, nil
	if abilities then
		ok, ability = pcall(Read)
	end
	if ok and ability then
		if pcall(Write, ability) then
			written = Signature()
		end
	elseif items then
		local fine, item = pcall(ReadItem)
		if fine and item and pcall(WriteItem, item) then
			written = Signature()
		end
	end
end)

-- An item's tooltip laid out at once, as the game fills it: the character
-- pane fills its slot's again every frame, so a layout a frame later would
-- never show. The game's answers (hasItem, hasCooldown...) are passed on.
local function ItemNow()
	if SurvivorUI_Feature and not SurvivorUI_Feature("itemTooltip") then
		return
	end
	local fine, item = pcall(ReadItem)
	if fine and item and pcall(WriteItem, item) then
		written = Signature()
	end
end
for _, method in pairs({ "SetInventoryItem", "SetHyperlink", "SetBagItem", "SetLootItem", "SetLootRollItem",
		"SetMerchantItem", "SetQuestItem", "SetQuestLogItem", "SetTradePlayerItem", "SetInboxItem" }) do
	local stock = GameTooltip[method]
	if stock then
		GameTooltip[method] = function(self, a, b, c, d)
			local x, y, z = stock(self, a, b, c, d)
			ItemNow()
			return x, y, z
		end
	end
end

-- For finding out why a tooltip is left as the game wrote it: typed with the
-- mouse still over it, /script SurvivorUI_TooltipDebug() says in the chat
-- which tooltips are up, what the game's has, and how it was read.
function SurvivorUI_TooltipDebug()
	local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100tip|r "..text) end
	for _, name in pairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
		local tip = getglobal(name)
		if tip then
			say(name..(tip:IsVisible() and " shown, " or " hidden, ")..(tip.NumLines and tip:NumLines() or "?").." lines")
		end
	end
	say("money frame: "..tostring(GameTooltipMoneyFrame and GameTooltipMoneyFrame:IsShown()))
	for line = 1, math.min(8, GameTooltip:NumLines()) do
		local left = getglobal("GameTooltipTextLeft"..line)
		say(line..": ["..string.gsub(left and left:GetText() or "", "|", "!").."]")
	end
	local ok, ability = pcall(Read)
	say("as an ability: "..(ok and (ability and "yes" or "no") or ("error "..tostring(ability))))
	local fine, item = pcall(ReadItem)
	say("as an item: "..(fine and (item and (table.getn(item.effects).." effects, bound "..tostring(item.bound)) or "no")
		or ("error "..tostring(item))))
	if fine and item then
		local wrote, problem = pcall(WriteItem, item)
		say("written: "..(wrote and "yes" or ("error "..tostring(problem))))
	end
end

-- Rules belong to this layout only: they go when the tooltip closes.
local stockHide = GameTooltip:GetScript("OnHide")
GameTooltip:SetScript("OnHide", function()
	HideRules()
	written = nil
	if stockHide then
		stockHide()
	end
end)
