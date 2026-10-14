-- Survivor UI: the character pane, in the manner of EllesmereUI's.
--
-- One flat dark panel: the hero and the item slots on the left, and on the
-- right the run's numbers in titled sections, in place of the stock stat rows
-- and the game's separate "Run Stats" box.
--
-- The numbers are the game's own: its interface keeps them in the global
-- AZS_STATS table, fed by the server. This file only reads that table.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

if not PaperDollFrame or not CharacterFrame then
	return
end

-- Where the stock art sits inside the 384 by 512 character frame.
local ART_LEFT, ART_TOP, ART_WIDTH, ART_HEIGHT = 11, -11, 342, 430
local STATS_WIDTH = 204
-- The list sizes itself to fit without scrolling: rows shrink as more of them
-- show, between these bounds.
local ROW_MAX, ROW_MIN = 14, 9
local HEADER_HEIGHT = 16

local function Line(parent, r, g, b, a)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(FLAT)
	line:SetVertexColor(r, g, b, a or 1)
	return line
end

------------------------------------------------------------------------------
-- The panel.

local panel = CreateFrame("Frame", "SurvivorUICharacter", PaperDollFrame)
panel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", ART_LEFT, ART_TOP)
panel:SetWidth(ART_WIDTH + STATS_WIDTH)
panel:SetHeight(ART_HEIGHT)
panel:SetFrameLevel(math.max(0, PaperDollFrame:GetFrameLevel() - 1))

local panelEdge = panel:CreateTexture(nil, "BACKGROUND")
panelEdge:SetTexture(FLAT)
panelEdge:SetVertexColor(0, 0, 0, 1)
panelEdge:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, 1)
panelEdge:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, -1)

local panelFill = panel:CreateTexture(nil, "BORDER")
panelFill:SetTexture(FLAT)
panelFill:SetVertexColor(0.05, 0.05, 0.07, 0.96)
panelFill:SetAllPoints(panel)

-- A hairline between the hero and the numbers.
local divider = Line(panel, 1, 1, 1, 0.08)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", panel, "TOPLEFT", ART_WIDTH, -8)
divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ART_WIDTH, 8)

-- The stock stone frame and the round portrait.
do
	local regions = { PaperDollFrame:GetRegions() }
	for index = 1, table.getn(regions) do
		if regions[index]:GetObjectType() == "Texture" then
			regions[index]:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Item slots: square, with a border in the item's quality color.

local SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
	"MainHand", "SecondaryHand", "Ranged", "Ammo",
}

local slotBorders = {}

for _, slotName in pairs(SLOTS) do
	local name = "Character"..slotName.."Slot"
	local slot = getglobal(name)
	if slot then
		local normal = getglobal(name.."NormalTexture")
		if normal then
			normal:SetAlpha(0)
		end
		local icon = getglobal(name.."IconTexture")
		if icon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end

	end

	-- No border for the ammo slot: it is never used here and would read as an
	-- empty square.
	if slot and slotName ~= "Ammo" then
		-- A frame behind the slot, not a texture inside it: that would cover the icon.
		local border = CreateFrame("Frame", nil, panel)
		border:SetPoint("TOPLEFT", slot, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
		border.edge = border:CreateTexture(nil, "BACKGROUND")
		border.edge:SetTexture(FLAT)
		border.edge:SetAllPoints(border)
		border.fill = border:CreateTexture(nil, "BORDER")
		border.fill:SetTexture(FLAT)
		border.fill:SetVertexColor(0.09, 0.09, 0.11, 1)
		border.fill:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
		border.fill:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
		border.slot = slot
		table.insert(slotBorders, border)
	end
end

local function UpdateSlotBorders()
	for index = 1, table.getn(slotBorders) do
		local border = slotBorders[index]
		local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", border.slot:GetID())
		local color = quality and quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if color then
			border.edge:SetVertexColor(color.r, color.g, color.b, 1)
		else
			border.edge:SetVertexColor(0, 0, 0, 1)
		end
	end
end

------------------------------------------------------------------------------
-- The model: no rotate buttons; drag it to turn the hero.

for _, name in pairs({ "CharacterModelFrameRotateLeftButton", "CharacterModelFrameRotateRightButton" }) do
	local button = getglobal(name)
	if button then
		button:Hide()
	end
end

if CharacterModelFrame then
	local model = CharacterModelFrame
	model:EnableMouse(true)
	model:SetScript("OnMouseDown", function()
		this.dragFrom = GetCursorPosition()
	end)
	model:SetScript("OnMouseUp", function()
		this.dragFrom = nil
	end)
	local stockUpdate = model:GetScript("OnUpdate")
	model:SetScript("OnUpdate", function()
		if stockUpdate then
			stockUpdate()
		end
		if this.dragFrom then
			local x = GetCursorPosition()
			this.rotation = (this.rotation or 0) + (x - this.dragFrom) * 0.01
			this.dragFrom = x
			this:SetRotation(this.rotation)
		end
	end)
end

------------------------------------------------------------------------------
-- Tabs: flat, with a gold line under the one that is open.

local tabs = {}
for index = 1, 5 do
	local name = "CharacterFrameTab"..index
	local tab = getglobal(name)
	if tab then
		for _, piece in pairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
			local art = getglobal(name..piece)
			if art then
				art:SetTexture("")
			end
		end
		local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
		if highlight then
			highlight:SetTexture("")
		end

		tab.survivorBack = tab:CreateTexture(nil, "BACKGROUND")
		tab.survivorBack:SetTexture(FLAT)
		tab.survivorBack:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -4)
		tab.survivorBack:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 6)

		tab.survivorMark = tab:CreateTexture(nil, "BORDER")
		tab.survivorMark:SetTexture(FLAT)
		tab.survivorMark:SetVertexColor(1, 0.82, 0, 1)
		tab.survivorMark:SetHeight(2)
		tab.survivorMark:SetPoint("BOTTOMLEFT", tab.survivorBack, "BOTTOMLEFT", 0, 0)
		tab.survivorMark:SetPoint("BOTTOMRIGHT", tab.survivorBack, "BOTTOMRIGHT", 0, 0)

		local text = getglobal(name.."Text")
		if text then
			text:SetFont(FONT, 11 + FONT_BUMP)
		end
		table.insert(tabs, tab)
	end
end

local function UpdateTabs()
	local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(CharacterFrame)
	for index = 1, table.getn(tabs) do
		local tab = tabs[index]
		if tab:GetID() == selected then
			tab.survivorBack:SetVertexColor(0.05, 0.05, 0.07, 0.96)
			tab.survivorMark:Show()
		else
			tab.survivorBack:SetVertexColor(0.03, 0.03, 0.04, 0.85)
			tab.survivorMark:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- The run's numbers.

local function Pct(value)
	return string.format("%+.0f%%", value * 100)
end

-- label, value(s), what it means, and for the conditional rows when to show.
local SECTIONS = {
	{ title = "Offense", color = { 1.00, 0.45, 0.25 }, rows = {
		{ "Damage",   function(s) return Pct(s.dmg - 1) end, "Every spell you cast deals this much more damage. It grows with your level, gear, talents, jewelry and buffs." },
		{ "Crit",     function(s) return string.format("%.1f%%", s.crit * 100) end, "The chance a spell strikes critically. Past 100%, the rest adds to your critical damage." },
		{ "Crit Dmg", function(s) return string.format("%.0f%%", s.cm * 100) end, "A critical strike deals this much of a spell's damage." },
		{ "Haste",    function(s) return Pct(1 - s.cd) end, "Your spells come back this much sooner." },
		{ "Echo",     function(s) return string.format("%.0f%%", s.echo * 100) end, "The chance a spell strikes twice. Past 100%, every spell strikes twice and the rest is the chance of a third." },
	} },
	{ title = "Reach", color = { 0.72, 0.45, 1.00 }, rows = {
		{ "Area",     function(s) return Pct(s.area - 1) end, "Your spells' areas and ranges are this much larger." },
		{ "Targets",  function(s) return string.format("+%d", s.cnt) end, "Every spell that picks its targets picks this many more." },
		{ "Pickup",   function(s) return string.format("%.0f yd", s.pick) end, "Experience and gold fly to you from this far." },
	} },
	{ title = "Defense", color = { 0.30, 0.65, 1.00 }, rows = {
		{ "Health",    function(s) return string.format("%.0f", s.hp) end, "The most health you can have." },
		{ "Armor",     function(s) return string.format("%.0f%%", s.arm * 100) end, "Damage you take is reduced by this much (60% at most)." },
		{ "Regen",     function(s) return string.format("%.1f", s.reg) end, "Health you regain every second." },
		{ "Lifesteal", function(s) return string.format("%.1f%%", s.lch * 100) end, "Heals you for this much of all the damage you deal." },
		{ "Kill Heal", function(s) return string.format("%.0f", s.heal) end, "Every kill heals you for this much." },
		{ "Thorns",    function(s) return string.format("%.0f%%", s.thn * 100) end, "This much of the melee damage you take is dealt back to the attacker." },
		{ "Lives",     function(s) return string.format("%d", s.liv) end, "Times you rise again instead of dying." },
	} },
	{ title = "Utility", color = { 0.35, 0.90, 0.55 }, rows = {
		{ "Speed",      function(s) return Pct(s.spd - 1) end, "You run this much faster." },
		{ "Experience", function(s) return Pct(s.xp - 1) end, "You gain this much more experience." },
		{ "Gold",       function(s) return Pct(s.gold - 1) end, "You find this much more gold." },
		{ "Luck",       function(s) return Pct(s.luck) end, "Better odds of rarer upgrades when you level up." },
		{ "Buff Power", function(s) return Pct(s.bp) end, "Your damage, haste, shield and thorns buffs are this much stronger." },
	} },
	{ title = "Damage over time", color = { 0.25, 0.85, 0.85 }, rows = {
		{ "DoT Stacks", function(s) return string.format("%d", s.dots) end, "How many of each of your damage-over-time effects one enemy carries at once." },
		{ "DoT Haste",  function(s) return Pct(s.doth) end, "Your damage-over-time effects tick this much faster." },
	} },
	{ title = "Bonus damage", color = { 1.00, 0.82, 0.00 }, rows = {
		{ "Vs Elites",     function(s) return Pct(s.big) end,  "More damage to elites and bosses.", "big" },
		{ "Execute",       function(s) return Pct(s.exe) end,  "More damage to enemies below 30% health.", "exe" },
		{ "Vs Controlled", function(s) return Pct(s.cc) end,   "More damage to rooted, stunned, slowed or fleeing enemies.", "cc" },
		{ "Vs Afflicted",  function(s) return Pct(s.dotd) end, "More damage to enemies carrying one of your damage-over-time effects.", "dotd" },
		{ "Shielded",      function(s) return Pct(s.shd) end,  "More damage while you hold an absorb shield.", "shd" },
		{ "Melee",         function(s) return Pct(s.auto) end, "Your melee swings deal this much more damage.", "auto" },
		{ "Pet Damage",    function(s) return Pct(s.pet) end,  "Your pets deal this much more damage.", "pet" },
	} },
}

-- A missing number reads as 0, so a row the game has not learned yet shows a
-- plain zero instead of breaking the panel.
local function Stats()
	if not AZS_STATS then
		return nil
	end
	return setmetatable({}, { __index = function(_, key) return AZS_STATS[key] or 0 end })
end

local stats = CreateFrame("Frame", "SurvivorUICharacterStats", panel)
stats:SetPoint("TOPLEFT", panel, "TOPLEFT", ART_WIDTH + 1, 0)
stats:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

-- The headline: the damage bonus, with the hero's health under it.
local headline = stats:CreateFontString(nil, "OVERLAY")
headline:SetFont(FONT, 20 + FONT_BUMP, "OUTLINE")
headline:SetPoint("TOP", stats, "TOP", 0, -14)
headline:SetTextColor(0.72, 0.45, 1)

local headlineCaption = stats:CreateFontString(nil, "OVERLAY")
headlineCaption:SetFont(FONT, 10 + FONT_BUMP)
headlineCaption:SetPoint("TOP", headline, "BOTTOM", 0, -3)

local scroll = CreateFrame("ScrollFrame", "SurvivorUICharacterScroll", stats)
scroll:SetPoint("TOPLEFT", stats, "TOPLEFT", 12, -54)
scroll:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", -12, 8)

local content = CreateFrame("Frame", nil, scroll)
content:SetWidth(STATS_WIDTH - 24)
content:SetHeight(10)
scroll:SetScrollChild(content)

local scrollOffset, scrollRange = 0, 0
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function()
	scrollOffset = math.max(0, math.min(scrollRange, scrollOffset - arg1 * ROW_MAX * 2))
	this:SetVerticalScroll(scrollOffset)
end)

local function RowEnter()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(this.title, 1, 1, 1)
	GameTooltip:AddLine(this.text, 1, 0.82, 0, 1)
	GameTooltip:Show()
end

local headers, rows = {}, {}

local function Header(index)
	local header = headers[index]
	if not header then
		header = CreateFrame("Frame", nil, content)
		header:SetWidth(STATS_WIDTH - 24)
		header:SetHeight(HEADER_HEIGHT)
		header.text = header:CreateFontString(nil, "OVERLAY")
		header.text:SetFont(FONT, 10 + FONT_BUMP, "OUTLINE")
		header.text:SetPoint("CENTER", header, "CENTER", 0, -2)
		header.left = Line(header, 1, 1, 1)
		header.left:SetHeight(1)
		header.left:SetPoint("LEFT", header, "LEFT", 0, -2)
		header.left:SetPoint("RIGHT", header.text, "LEFT", -6, 0)
		header.right = Line(header, 1, 1, 1)
		header.right:SetHeight(1)
		header.right:SetPoint("RIGHT", header, "RIGHT", 0, -2)
		header.right:SetPoint("LEFT", header.text, "RIGHT", 6, 0)
		headers[index] = header
	end
	return header
end

local function Row(index)
	local row = rows[index]
	if not row then
		row = CreateFrame("Frame", nil, content)
		row:SetWidth(STATS_WIDTH - 24)
		row:SetHeight(ROW_MAX)
		row:EnableMouse(true)
		row:SetScript("OnEnter", RowEnter)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.label = row:CreateFontString(nil, "OVERLAY")
		row.label:SetFont(FONT, 11 + FONT_BUMP)
		row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.label:SetTextColor(0.82, 0.82, 0.82)
		row.value = row:CreateFontString(nil, "OVERLAY")
		row.value:SetFont(FONT, 11 + FONT_BUMP)
		row.value:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		rows[index] = row
	end
	return row
end

local function UpdateStats()
	local s = Stats()

	if s then
		headline:SetText(Pct(s.dmg - 1))
		headlineCaption:SetText("|cffa0a0a0Damage  \194\183  Health:|r |cff4da6ff"..string.format("%.0f", s.hp).."|r")
	else
		headline:SetText("-")
		headlineCaption:SetText("|cffa0a0a0Start a run to see its numbers|r")
	end

	-- What shows: a section appears once one of its rows does.
	local shown = {}
	local totalRows, totalHeaders = 0, 0
	for index, section in ipairs(SECTIONS) do
		local visible = {}
		for _, entry in ipairs(section.rows) do
			if not entry[4] or (s and s[entry[4]] ~= 0) then
				table.insert(visible, entry)
			end
		end
		shown[index] = visible
		if table.getn(visible) > 0 then
			totalRows = totalRows + table.getn(visible)
			totalHeaders = totalHeaders + 1
		end
	end

	-- Rows as tall as the room allows, and the type to match.
	local room = scroll:GetHeight() - totalHeaders * HEADER_HEIGHT
	local rowHeight = ROW_MAX
	if totalRows > 0 and room > 0 then
		rowHeight = math.max(ROW_MIN, math.min(ROW_MAX, math.floor(room / totalRows)))
	end
	local fontSize = math.max(8, math.min(11, rowHeight - 3))

	local y = 0
	local headerCount, rowCount = 0, 0
	for index, section in ipairs(SECTIONS) do
		local visible = shown[index]

		if table.getn(visible) > 0 then
			local color = section.color
			headerCount = headerCount + 1
			local header = Header(headerCount)
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
			header.text:SetText(section.title)
			header.text:SetTextColor(color[1], color[2], color[3])
			header.left:SetVertexColor(color[1], color[2], color[3], 0.6)
			header.right:SetVertexColor(color[1], color[2], color[3], 0.6)
			header:Show()
			y = y + HEADER_HEIGHT

			for _, entry in ipairs(visible) do
				rowCount = rowCount + 1
				local row = Row(rowCount)
				row:SetHeight(rowHeight)
				if row.fontSize ~= fontSize then
					row.fontSize = fontSize
					row.label:SetFont(FONT, fontSize + FONT_BUMP)
					row.value:SetFont(FONT, fontSize + FONT_BUMP)
				end
				local value = s and entry[2](s) or "-"
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
				row.label:SetText(entry[1])
				row.value:SetText(value)
				row.value:SetTextColor(color[1], color[2], color[3])
				row.title = entry[1].." "..value
				row.text = entry[3]
				row:Show()
				y = y + rowHeight
			end
		end
	end

	for index = headerCount + 1, table.getn(headers) do
		headers[index]:Hide()
	end
	for index = rowCount + 1, table.getn(rows) do
		rows[index]:Hide()
	end

	content:SetHeight(math.max(10, y))
	scrollRange = math.max(0, y - scroll:GetHeight())
	if scrollOffset > scrollRange then
		scrollOffset = scrollRange
		scroll:SetVerticalScroll(scrollOffset)
	end
end

------------------------------------------------------------------------------
-- Putting the stock pieces away, and keeping everything current while open.

-- The game's own side box would sit on top of the numbers.
if AZS_UpdateMore then
	AZS_UpdateMore = function() end
end

local function HideStock()
	for _, name in pairs({ "CharacterAttributesFrame", "CharacterResistanceFrame", "AZSMoreStats", "CharacterFramePortrait" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
		end
	end
end

local closeButton = getglobal("CharacterFrameCloseButton")

panel:SetScript("OnShow", function()
	HideStock()
	UpdateSlotBorders()
	UpdateTabs()
	UpdateStats()
	if closeButton then
		closeButton:ClearAllPoints()
		closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 4, 4)
	end
end)

-- The other tabs keep the stock frame, portrait and close button.
panel:SetScript("OnHide", function()
	local portrait = getglobal("CharacterFramePortrait")
	if portrait then
		portrait:Show()
	end
	if closeButton then
		closeButton:ClearAllPoints()
		closeButton:SetPoint("CENTER", CharacterFrame, "TOPRIGHT", -44, -25)
	end
end)

local elapsed = 0
panel:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.3 then
		return
	end
	elapsed = 0
	HideStock()
	UpdateSlotBorders()
	UpdateStats()
end)

-- The tabs belong to the whole character window, whichever page is open.
local tabWatcher = CreateFrame("Frame", nil, CharacterFrame)
local tabElapsed = 0
tabWatcher:SetScript("OnUpdate", function()
	tabElapsed = tabElapsed + arg1
	if tabElapsed >= 0.1 then
		tabElapsed = 0
		UpdateTabs()
	end
end)
