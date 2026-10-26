-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the chat's panel (the options, Chat: Look).
--
-- One dark panel holds the docked chat windows. Along its top, their names as
-- tabs: the one shown in the addon's color with a line under it, the others
-- dimmed, lit under the mouse, white with a dot when a line comes to them
-- unseen. A right-click on a tab opens the game's menu for that window. At
-- the top right, a button for the shown window's last lines in a box, to
-- select and copy (the chat itself can't be selected). At the bottom right, a
-- grip to size it, the size kept. The typing box hangs under the panel, in
-- its look. Locked, the panel stands alone: no tabs' row, no buttons, no
-- grip, no edges.
--
-- The game's own tabs and the backdrop it fades in under the mouse are put
-- away while the panel shows. The other look, "Text on the world", is the
-- chat as it was (SurvivorUI.lua: StyleChat, with its Background).

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT_BUMP = SurvivorUI_FONT_BUMP or 0

local PAD = 6                   -- the panel's room around the text
local HEAD = 13                 -- the tabs' row, over the text
local TAB_SIZE = 5.5            -- the tabs' names
local KEPT = 200                -- a window's lines kept for the copy box
local SMALLEST = { 260, 60 }    -- the chat's size, at least and at most
local LARGEST = { 1000, 600 }
local LOWEST = 34               -- the chat's foot over the screen's: room for the typing box
local FILL = { 0.035, 0.035, 0.045 }
local DIM = { 0.55, 0.55, 0.60 }
local LIT = { 0.92, 0.92, 0.92 }

local function Settings()
	SurvivorUIDB = SurvivorUIDB or {}
	return SurvivorUIDB
end

-- "panel" (the default) or "text".
function SurvivorUI_ChatLook()
	return Settings().chatLook == "text" and "text" or "panel"
end

function SurvivorUI_ChatPanelAlpha()
	return tonumber(Settings().chatPanelAlpha) or 0.8
end

-- Locked (the options, Chat: Lock the chat): the panel alone, no tabs, no
-- buttons, no grip, no edges.
function SurvivorUI_ChatLocked()
	return Settings().chatLocked == true
end

------------------------------------------------------------------------------
-- What each window was told, for the copy box: the game's chat keeps no
-- readable record, so each line is kept on its way in, the last KEPT.

local lines = {}                -- [window name] = { at = next slot, [1..KEPT] }

local function Keep(window, text)
	if not text then
		return
	end
	local name = window:GetName()
	local kept = lines[name]
	if not kept then
		kept = { at = 1 }
		lines[name] = kept
	end
	kept[kept.at] = text
	kept.at = math.mod(kept.at, KEPT) + 1
end

for index = 1, NUM_CHAT_WINDOWS or 7 do
	local window = getglobal("ChatFrame"..index)
	if window and window.AddMessage then
		local stockAdd = window.AddMessage
		window.AddMessage = function(self, text, r, g, b, id, hold)
			Keep(self, text)
			return stockAdd(self, text, r, g, b, id, hold)
		end
	end
end

-- The plain words: no colors, a link as its name, no icons.
local function Plain(text)
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	text = string.gsub(text, "|T.-|t", "")
	return text
end

-- A window's kept lines, oldest first, one to a line.
local function Told(window)
	local kept = lines[window:GetName()]
	if not kept then
		return ""
	end
	local out = {}
	for step = 0, KEPT - 1 do
		local text = kept[math.mod(kept.at - 1 + step, KEPT) + 1]
		if text then
			table.insert(out, Plain(text))
		end
	end
	return table.concat(out, "\n")
end

------------------------------------------------------------------------------
-- The pieces.

local panel, rule, underline, copy, grip
local tabs = {}
local unread = {}               -- [window name] = true: a line came to it unseen
local hider = CreateFrame("Frame")
hider:Hide()

local function Shown()
	return SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1
end

-- A box's four sides, one pixel each, made on a frame round it or round one
-- of its pieces.
local function Edges(owner, layer, frame)
	frame = frame or owner
	local sides = {}
	for index = 1, 4 do
		local side = owner:CreateTexture(nil, layer or "BORDER")
		side:SetTexture(FLAT)
		sides[index] = side
	end
	sides[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	sides[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	sides[1]:SetHeight(1)
	sides[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	sides[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	sides[2]:SetHeight(1)
	sides[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	sides[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	sides[3]:SetWidth(1)
	sides[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	sides[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	sides[4]:SetWidth(1)
	return sides
end

local function ColorEdges(sides, r, g, b, a)
	for index = 1, 4 do
		sides[index]:SetVertexColor(r, g, b, a)
	end
end

local function Paint()
	if not panel then
		return
	end
	local accent = SurvivorUI_ACCENT or { 1, 0.82, 0 }
	local shown = Shown()
	underline:Hide()
	for index = 1, table.getn(tabs) do
		local tab = tabs[index]
		if tab:IsShown() then
			local color = DIM
			if tab.window == shown then
				color = accent
				underline:ClearAllPoints()
				underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
				underline:SetWidth(tab.text:GetStringWidth())
				underline:SetVertexColor(accent[1], accent[2], accent[3], 1)
				underline:Show()
			elseif tab.hover or unread[tab.window:GetName()] then
				color = LIT
			end
			tab.text:SetTextColor(color[1], color[2], color[3])
			if unread[tab.window:GetName()] and tab.window ~= shown then
				tab.dot:SetVertexColor(accent[1], accent[2], accent[3], 1)
				tab.dot:Show()
			else
				tab.dot:Hide()
			end
		end
	end
end

local function Strength()
	if not panel then
		return
	end
	local alpha = SurvivorUI_ChatPanelAlpha()
	panel.fill:SetVertexColor(FILL[1], FILL[2], FILL[3], alpha)
	local edged = SurvivorUI_ChatLocked() and 0 or 1
	ColorEdges(panel.edges, 0, 0, 0, math.min(1, alpha + 0.15) * edged)
	rule:SetVertexColor(1, 1, 1, 0.07 * alpha * edged)
	local edit = ChatFrameEditBox
	if edit and edit.survivorBack and edit.survivorEdges then
		edit.survivorBack:SetVertexColor(FILL[1], FILL[2], FILL[3], math.max(alpha, 0.92))
		ColorEdges(edit.survivorEdges, 0, 0, 0, 1)
	end
end

local function TabClick()
	local window = this.window
	if arg1 == "RightButton" then
		-- The game's own menu for the window: font size, colors, name, filters.
		local menu = getglobal(window:GetName().."TabDropDown")
		if menu then
			ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
		end
		return
	end
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	SELECTED_CHAT_FRAME = window
	unread[window:GetName()] = nil
	if window.isDocked and FCF_SelectDockFrame then
		FCF_SelectDockFrame(window)
	end
	Paint()
end

local function NewTab(index)
	local tab = CreateFrame("Button", "SurvivorUIChatTab"..index, panel)
	tab:SetHeight(HEAD)
	tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- Small: a shadow reads better than an outline at this size.
	tab.text = tab:CreateFontString(nil, "OVERLAY")
	tab.text:SetFont(SurvivorUI_FONT, TAB_SIZE + FONT_BUMP / 2, "")
	tab.text:SetShadowColor(0, 0, 0, 1)
	tab.text:SetShadowOffset(1, -1)
	tab.text:SetPoint("LEFT", tab, "LEFT", 4, 0)
	tab.dot = tab:CreateTexture(nil, "OVERLAY")
	tab.dot:SetTexture(FLAT)
	tab.dot:SetWidth(3)
	tab.dot:SetHeight(3)
	tab.dot:SetPoint("LEFT", tab.text, "RIGHT", 2, 2)
	tab.dot:Hide()
	tab:SetScript("OnClick", TabClick)
	-- Lit under the mouse already: no outline round it (Hover.lua).
	tab.noHoverOutline = true
	tab:SetScript("OnEnter", function()
		this.hover = true
		Paint()
	end)
	tab:SetScript("OnLeave", function()
		this.hover = nil
		Paint()
	end)
	tabs[index] = tab
	return tab
end

local function TabName(window)
	local name = window.GetID and GetChatWindowInfo and GetChatWindowInfo(window:GetID())
	if name and name ~= "" then
		return name
	end
	local stock = getglobal(window:GetName().."Tab")
	return stock and stock:GetText() or window:GetName()
end

-- A tab for each docked window but the Combat Log while the chat filter keeps
-- it empty (unless it is the one shown).
local function Listed(window)
	if window == ChatFrame2 and window ~= Shown() and SurvivorUI_ChatFilter and SurvivorUI_ChatFilter("Combat") then
		return false
	end
	return true
end

-- The game's sizing edges of an unlocked window (unseen, their art emptied
-- below), which would take the grip's drag.
local GRIPS = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right" }

-- The game's tabs of the docked windows away while the panel shows, its
-- sizing edges deaf, and the backdrop it fades in under the mouse emptied
-- (its file kept to give back).
local function StockAway(away)
	for index = 1, NUM_CHAT_WINDOWS or 7 do
		local window = getglobal("ChatFrame"..index)
		local stock = getglobal("ChatFrame"..index.."Tab")
		if window and stock then
			local hidden = away and window.isDocked
			if hidden then
				stock:SetParent(hider)
			elseif stock:GetParent() == hider then
				stock:SetParent(UIParent)
				stock:SetFrameStrata("LOW")
			end
			for _, side in pairs(GRIPS) do
				local edge = getglobal("ChatFrame"..index.."Resize"..side)
				if edge then
					edge:EnableMouse(not hidden)
				end
			end
			for _, piece in pairs(CHAT_FRAME_TEXTURES or {}) do
				local art = getglobal("ChatFrame"..index..piece)
				if art then
					if hidden then
						art.survivorFile = art.survivorFile or art:GetTexture()
						art:SetTexture("")
					elseif art.survivorFile then
						art:SetTexture(art.survivorFile)
					end
				end
			end
		end
	end
end

local function Refresh()
	if not (panel and panel:IsShown()) then
		return
	end
	local count, x = 0, 4
	local docked = DOCKED_CHAT_FRAMES or { ChatFrame1 }
	local locked = SurvivorUI_ChatLocked()
	for index = 1, table.getn(docked) do
		local window = docked[index]
		if Listed(window) and not locked then
			count = count + 1
			local tab = tabs[count] or NewTab(count)
			tab.window = window
			tab.text:SetText(TabName(window))
			local width = tab.text:GetStringWidth() + 10
			tab:SetWidth(width)
			tab:ClearAllPoints()
			tab:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -1)
			tab:Show()
			x = x + width + 2
		end
	end
	for index = count + 1, table.getn(tabs) do
		tabs[index]:Hide()
	end
	StockAway(true)
	Paint()
end

-- The typing box under the panel, in its look: its own art away, a flat field
-- edge to edge with the panel, two pixels under it, its words (the "Say:"
-- too) as large as the chat's and the field as tall as they need. A chat so
-- low the box would leave the screen has it over it instead, looked at each
-- time it opens.
local function PlaceEdit()
	local edit = ChatFrameEditBox
	if not (edit and edit.survivorBack) then
		return
	end
	local onPanel = panel and panel:IsShown()
	local over = onPanel and panel or ChatFrame1
	-- The box's sides and its top under the panel (or the chat): the field is
	-- 4 in from the box's sides and 5 from its top and foot.
	local side, gap = onPanel and 4 or 5, onPanel and 3 or -2
	local bottom = over:GetBottom()
	edit:ClearAllPoints()
	if bottom and bottom + gap - edit:GetHeight() + 5 < 0 then
		edit:SetPoint("BOTTOMLEFT", over, "TOPLEFT", -side, -gap)
		edit:SetPoint("BOTTOMRIGHT", over, "TOPRIGHT", side, -gap)
	else
		edit:SetPoint("TOPLEFT", over, "BOTTOMLEFT", -side, gap)
		edit:SetPoint("TOPRIGHT", over, "BOTTOMRIGHT", side, gap)
	end
end

local function DressEdit(onPanel)
	local edit = ChatFrameEditBox
	if not edit then
		return
	end
	if not edit.survivorBack then
		-- SurvivorUI.lua's StyleChat makes it; the panel needs it from here on.
		return
	end
	if not edit.survivorEdges then
		edit.survivorEdges = Edges(edit, "BORDER", edit.survivorBack)
	end
	-- The game's art has a middle piece with no name, between its Left and
	-- Right: known by its file.
	local regions = { edit:GetRegions() }
	for index = 1, table.getn(regions) do
		local region = regions[index]
		local file = region.GetTexture and region:GetTexture()
		if type(file) == "string" and string.find(string.lower(file), "chatinputborder", 1, true) then
			region:SetTexture("")
		end
	end
	local size = tonumber(Settings().chatSize) or 10
	edit:SetFont(SurvivorUI_FONT, size)
	local header = getglobal("ChatFrameEditBoxHeader")
	if header then
		header:SetFont(SurvivorUI_FONT, size)
	end
	-- The field is the box less 5 at its top and foot.
	edit:SetHeight(size + 20)
	if not onPanel then
		edit.survivorBack:SetVertexColor(0.04, 0.04, 0.06, 0.8)
		ColorEdges(edit.survivorEdges, 0, 0, 0, 0)
	end
	if not edit.survivorPlaced then
		edit.survivorPlaced = true
		local stockShow = edit:GetScript("OnShow")
		edit:SetScript("OnShow", function()
			if stockShow then
				stockShow()
			end
			PlaceEdit()
		end)
	end
	PlaceEdit()
end

------------------------------------------------------------------------------
-- The copy box: the shown window's last lines, selected, for Ctrl+C.

local copyBox

local function BuildCopyBox()
	copyBox = CreateFrame("Frame", "SurvivorUIChatCopy", UIParent)
	copyBox:SetFrameStrata("DIALOG")
	copyBox:SetWidth(560)
	copyBox:SetHeight(320)
	copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	copyBox:EnableMouse(true)
	copyBox:SetMovable(true)
	copyBox:RegisterForDrag("LeftButton")
	copyBox:SetScript("OnDragStart", function() this:StartMoving() end)
	copyBox:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	local back = copyBox:CreateTexture(nil, "BACKGROUND")
	back:SetTexture(FLAT)
	back:SetVertexColor(FILL[1], FILL[2], FILL[3], 0.97)
	back:SetAllPoints(copyBox)
	ColorEdges(Edges(copyBox), 0, 0, 0, 1)
	copyBox.top = copyBox:CreateTexture(nil, "BORDER")
	copyBox.top:SetTexture(FLAT)
	copyBox.top:SetPoint("TOPLEFT", copyBox, "TOPLEFT", 1, -1)
	copyBox.top:SetPoint("TOPRIGHT", copyBox, "TOPRIGHT", -1, -1)
	copyBox.top:SetHeight(2)
	SurvivorUI_OnAccent(function()
		local accent = SurvivorUI_ACCENT or { 1, 0.82, 0 }
		copyBox.top:SetVertexColor(accent[1], accent[2], accent[3], 1)
	end)

	copyBox.title = copyBox:CreateFontString(nil, "OVERLAY")
	copyBox.title:SetFont(SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
	copyBox.title:SetPoint("TOPLEFT", copyBox, "TOPLEFT", 12, -12)
	copyBox.hint = copyBox:CreateFontString(nil, "OVERLAY")
	copyBox.hint:SetFont(SurvivorUI_FONT, 9 + FONT_BUMP, "OUTLINE")
	copyBox.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
	copyBox.hint:SetPoint("BOTTOMLEFT", copyBox, "BOTTOMLEFT", 12, 10)
	copyBox.hint:SetText("Selected: Ctrl+C copies it. Drag over a part to copy just that.")

	local shut = CreateFrame("Button", nil, copyBox)
	shut:SetWidth(18)
	shut:SetHeight(18)
	shut:SetPoint("TOPRIGHT", copyBox, "TOPRIGHT", -6, -7)
	shut.text = shut:CreateFontString(nil, "OVERLAY")
	shut.text:SetFont(SurvivorUI_FONT, 12 + FONT_BUMP, "OUTLINE")
	shut.text:SetTextColor(DIM[1], DIM[2], DIM[3])
	shut.text:SetPoint("CENTER", shut, "CENTER", 0, 0)
	shut.text:SetText("x")
	shut:SetScript("OnEnter", function() this.text:SetTextColor(1, 1, 1) end)
	shut:SetScript("OnLeave", function() this.text:SetTextColor(DIM[1], DIM[2], DIM[3]) end)
	shut:SetScript("OnClick", function() copyBox:Hide() end)

	-- The lines: a box as tall as its text in a frame that scrolls it.
	local field = CreateFrame("Frame", nil, copyBox)
	field:SetPoint("TOPLEFT", copyBox, "TOPLEFT", 10, -34)
	field:SetPoint("BOTTOMRIGHT", copyBox, "BOTTOMRIGHT", -10, 28)
	local fieldBack = field:CreateTexture(nil, "BACKGROUND")
	fieldBack:SetTexture(FLAT)
	fieldBack:SetVertexColor(0, 0, 0, 0.6)
	fieldBack:SetAllPoints(field)
	ColorEdges(Edges(field), 0.22, 0.22, 0.26, 1)

	local scroll = CreateFrame("ScrollFrame", "SurvivorUIChatCopyScroll", field)
	scroll:SetPoint("TOPLEFT", field, "TOPLEFT", 6, -5)
	scroll:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", -6, 5)
	local edit = CreateFrame("EditBox", "SurvivorUIChatCopyText", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(560 - 32)
	edit:SetFont(SurvivorUI_FONT, 11 + FONT_BUMP, "")
	edit:SetTextColor(0.9, 0.9, 0.9)
	scroll:SetScrollChild(edit)
	copyBox.scroll = scroll
	copyBox.edit = edit

	local function Range()
		return math.max(0, (edit:GetHeight() or 0) - (scroll:GetHeight() or 0))
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function()
		local at = this:GetVerticalScroll() - arg1 * 40
		this:SetVerticalScroll(math.max(0, math.min(Range(), at)))
	end)
	-- What it shows stays as it is, whatever is typed; Escape closes.
	edit:SetScript("OnTextChanged", function()
		if this.told and this:GetText() ~= this.told then
			this:SetText(this.told)
			this:HighlightText()
		end
	end)
	edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
	copyBox:SetScript("OnHide", function() edit:ClearFocus() end)
	-- The newest lines in view once the box has its height.
	copyBox:SetScript("OnUpdate", function()
		if this.toBottom then
			this.toBottom = this.toBottom - 1
			scroll:SetVerticalScroll(Range())
			if this.toBottom <= 0 then
				this.toBottom = nil
			end
		end
	end)
	copyBox:Hide()
	if UISpecialFrames then
		table.insert(UISpecialFrames, "SurvivorUIChatCopy")
	end
end

local function ShowCopy()
	if not copyBox then
		BuildCopyBox()
	end
	local window = Shown()
	local told = Told(window)
	copyBox.title:SetText("Copy chat: "..TabName(window))
	copyBox.edit.told = told
	copyBox.edit:SetText(told)
	copyBox:Show()
	copyBox.edit:SetFocus()
	copyBox.edit:HighlightText()
	copyBox.toBottom = 3
end

------------------------------------------------------------------------------
-- The panel.

local function CopyButton()
	local button = CreateFrame("Button", nil, panel)
	button:SetWidth(HEAD)
	button:SetHeight(HEAD)
	button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -1)
	-- Two sheets, one over the other, drawn on the button itself (a frame
	-- inside it would take the mouse from it).
	local under = button:CreateTexture(nil, "BACKGROUND")
	under:SetTexture(FLAT)
	under:SetVertexColor(0, 0, 0, 0)
	under:SetWidth(5)
	under:SetHeight(6)
	under:SetPoint("CENTER", button, "CENTER", 1.5, 1.5)
	local over = button:CreateTexture(nil, "ARTWORK")
	over:SetTexture(FLAT)
	over:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	over:SetWidth(5)
	over:SetHeight(6)
	over:SetPoint("CENTER", button, "CENTER", -0.5, -0.5)
	button.sheets = { Edges(button, "BORDER", under), Edges(button, "OVERLAY", over) }
	local function Light(lit)
		local color = lit and LIT or DIM
		ColorEdges(button.sheets[1], color[1], color[2], color[3], lit and 0.8 or 0.6)
		ColorEdges(button.sheets[2], color[1], color[2], color[3], 1)
	end
	Light(false)
	button:SetScript("OnEnter", function()
		Light(true)
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText("Copy chat", 1, 1, 1)
		GameTooltip:AddLine("The shown tab's last lines in a box, to copy.", 0.8, 0.8, 0.8, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		Light(false)
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", ShowCopy)
	button.noHoverOutline = true
	return button
end

-- The chat's size, kept: put on as the chat is styled, saved as a drag ends.
local function ApplySize()
	local width, height = tonumber(Settings().chatWidth), tonumber(Settings().chatHeight)
	if width and height then
		ChatFrame1:SetWidth(width)
		ChatFrame1:SetHeight(height)
	end
end

-- A drag of the grip ended: the chat set back on its bottom left corner as
-- Move UI keeps it (Mover.lua's chatLeft and chatBottom), and its size and
-- place saved.
local function SizeDone()
	local chat = ChatFrame1
	if not chat.survivorSizing then
		return
	end
	chat.survivorSizing = nil
	chat:StopMovingOrSizing()
	chat.resizing = nil
	local left, bottom = chat:GetLeft(), chat:GetBottom()
	if not (left and bottom) then
		return
	end
	-- Pulled below LOWEST, the foot comes back up and the top stays.
	local height = chat:GetHeight()
	if bottom < LOWEST then
		height = height - (LOWEST - bottom)
		bottom = LOWEST
	end
	local settings = Settings()
	settings.chatLeft = math.floor(left + 0.5)
	settings.chatBottom = math.floor(bottom + 0.5)
	settings.chatWidth = math.floor(math.max(SMALLEST[1], math.min(LARGEST[1], chat:GetWidth())) + 0.5)
	settings.chatHeight = math.floor(math.max(SMALLEST[2], math.min(LARGEST[2], height)) + 0.5)
	chat:ClearAllPoints()
	chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.chatLeft, settings.chatBottom)
	ApplySize()
	if FCF_DockUpdate then
		FCF_DockUpdate()
	end
end

-- The grip: six dots in a stair in the bottom right corner.
local function Grip()
	local grip = CreateFrame("Button", nil, panel)
	grip:SetWidth(12)
	grip:SetHeight(12)
	grip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
	local spots = { { 3, 3 }, { 6, 3 }, { 9, 3 }, { 3, 6 }, { 6, 6 }, { 3, 9 } }
	grip.dots = {}
	for index = 1, table.getn(spots) do
		local dot = grip:CreateTexture(nil, "OVERLAY")
		dot:SetTexture(FLAT)
		dot:SetWidth(1.5)
		dot:SetHeight(1.5)
		dot:SetPoint("CENTER", grip, "BOTTOMRIGHT", -spots[index][1], spots[index][2])
		grip.dots[index] = dot
	end
	local function Light(lit)
		local color = lit and LIT or DIM
		for index = 1, table.getn(grip.dots) do
			grip.dots[index]:SetVertexColor(color[1], color[2], color[3], lit and 1 or 0.7)
		end
	end
	Light(false)
	grip:SetScript("OnEnter", function()
		Light(true)
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetText("Size the chat", 1, 1, 1)
		GameTooltip:AddLine("Drag this corner; the size is kept.", 0.8, 0.8, 0.8, 1)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function()
		Light(false)
		GameTooltip:Hide()
	end)
	grip:SetScript("OnMouseDown", function()
		if arg1 ~= "LeftButton" then
			return
		end
		GameTooltip:Hide()
		ChatFrame1.survivorSizing = true
		-- The game's own dock follows a resizing chat (FCF_OnUpdate).
		ChatFrame1.resizing = 1
		ChatFrame1:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", SizeDone)
	grip:SetScript("OnHide", SizeDone)
	grip.noHoverOutline = true
	return grip
end

local function Build()
	panel = CreateFrame("Frame", "SurvivorUIChatPanel", UIParent)
	panel:SetFrameStrata("BACKGROUND")
	panel:SetFrameLevel(0)
	panel:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", -PAD, HEAD + PAD)
	panel:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMRIGHT", PAD, -PAD)
	panel.fill = panel:CreateTexture(nil, "BACKGROUND")
	panel.fill:SetTexture(FLAT)
	panel.fill:SetAllPoints(panel)
	panel.edges = Edges(panel)
	-- The tabs' row, ruled off from the text.
	rule = panel:CreateTexture(nil, "BORDER")
	rule:SetTexture(FLAT)
	rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -(HEAD + 1))
	rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -(HEAD + 1))
	rule:SetHeight(1)
	underline = panel:CreateTexture(nil, "ARTWORK")
	underline:SetTexture(FLAT)
	underline:SetHeight(1)
	underline:Hide()
	copy = CopyButton()
	grip = Grip()
	ChatFrame1:SetResizable(true)
	ChatFrame1:SetMinResize(SMALLEST[1], SMALLEST[2])
	ChatFrame1:SetMaxResize(LARGEST[1], LARGEST[2])

	-- The text over the panel: the docked windows a level above it.
	for index = 1, NUM_CHAT_WINDOWS or 7 do
		local window = getglobal("ChatFrame"..index)
		if window and window:GetFrameLevel() < 2 then
			window:SetFrameLevel(2)
		end
	end

	SurvivorUI_OnAccent(Paint)

	-- The game redraws its dock on a select, a dock, a rename: so do the tabs.
	if FCF_DockUpdate then
		local stockDockUpdate = FCF_DockUpdate
		FCF_DockUpdate = function()
			stockDockUpdate()
			Refresh()
		end
	end
	if FCF_FlashTab then
		local stockFlash = FCF_FlashTab
		FCF_FlashTab = function()
			stockFlash()
			if panel:IsShown() and this and this.isDocked and this ~= Shown() then
				unread[this:GetName()] = true
				Paint()
			end
		end
	end
	-- Once a second, for what reaches no hook: the chat filter switched, a
	-- window renamed from its menu.
	local wait = 0
	panel:SetScript("OnUpdate", function()
		wait = wait + arg1
		if wait >= 1 then
			wait = 0
			Refresh()
		end
	end)
end

-- The panel round the text, its tabs' row over it unless locked; the buttons
-- only unlocked.
local function Fit()
	local locked = SurvivorUI_ChatLocked()
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", -PAD, locked and PAD or HEAD + PAD)
	panel:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMRIGHT", PAD, -PAD)
	if locked then
		copy:Hide()
		grip:Hide()
	else
		copy:Show()
		grip:Show()
	end
end

-- Called by SurvivorUI.lua's StyleChat (Flat chat on), and on a look change.
function SurvivorUI_StyleChatPanel()
	if not ChatFrame1 then
		return
	end
	ApplySize()
	if SurvivorUI_ChatLook() == "panel" then
		if not panel then
			Build()
		end
		panel:Show()
		Fit()
		DressEdit(true)
		Strength()
		Refresh()
	elseif panel then
		panel:Hide()
		StockAway(false)
		DressEdit(false)
	end
end

function SurvivorUI_SetChatPanelAlpha(alpha)
	Settings().chatPanelAlpha = math.max(0, math.min(1, alpha))
	Strength()
end

function SurvivorUI_SetChatLocked(on)
	Settings().chatLocked = on and true or nil
	if panel then
		Fit()
		Strength()
		Refresh()
	end
end
