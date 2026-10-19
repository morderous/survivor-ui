-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: one box to ask before anything goes, for the whole addon.
--
-- In the middle of the screen, the screen shaded behind it: a title, what
-- goes and how much of it, and two buttons (the red one says what it does,
-- Cancel). Two kinds: a part, or settings back to default, asked once (Enter
-- or the red button); everything of a kind (every run, the whole collection)
-- asked for a word typed first (clear, forget), the red button lit only then.
-- Escape or Cancel leaves it. Built the first time it is wanted, once every
-- file is loaded (it wears SurvivorUI_GoldButton, RunHistory.lua's).
--
--   SurvivorUI_Confirm({ title = "Clear all runs?", text = "...", word = "clear",
--       yes = "Clear all", onYes = function() ... end })
--   SurvivorUI_ConfirmClose()

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local TRASH = "Interface\\AddOns\\SurvivorUI\\Art\\Trash"
local RED = { edge = { 1, 0.40, 0.34 }, body = { 0.34, 0.08, 0.07 }, text = { 1, 0.74, 0.70 } }

local box, shade, title, text, input, yes, no
local asked                       -- the spec shown: { title, text, word, yes, onYes }

local function Font(parent, size, color, justify)
	local line = parent:CreateFontString(nil, "OVERLAY")
	line:SetFont(SurvivorUI_FONT, size + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	line:SetTextColor(color[1], color[2], color[3])
	line:SetJustifyH(justify or "CENTER")
	return line
end

-- Whether the red button may go: always without a word, with one once typed.
local function Ready()
	local ready = asked and (not asked.word or string.lower(input:GetText() or "") == asked.word)
	yes:SetAlpha(ready and 1 or 0.35)
	return ready
end

function SurvivorUI_ConfirmClose()
	if not box then
		return
	end
	asked = nil
	input:ClearFocus()
	box:Hide()
	shade:Hide()
end

local function Go()
	if not Ready() then
		return
	end
	local onYes = asked.onYes
	SurvivorUI_ConfirmClose()
	if onYes then
		onYes()
	end
end

local function Build()
	-- The shade: the whole screen darker, its clicks kept from what is under it.
	shade = CreateFrame("Frame", nil, UIParent)
	shade:SetFrameStrata("FULLSCREEN_DIALOG")
	shade:SetAllPoints(UIParent)
	shade:EnableMouse(true)
	shade.dark = shade:CreateTexture(nil, "BACKGROUND")
	shade.dark:SetTexture(FLAT)
	shade.dark:SetVertexColor(0, 0, 0, 0.5)
	shade.dark:SetAllPoints(shade)
	shade:Hide()

	box = CreateFrame("Frame", "SurvivorUIConfirm", UIParent)
	box:SetFrameStrata("FULLSCREEN_DIALOG")
	box:SetFrameLevel(shade:GetFrameLevel() + 5)
	box:SetWidth(360)
	box:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(0.06, 0.03, 0.04, 0.98)
	box:SetBackdropBorderColor(RED.edge[1], RED.edge[2], RED.edge[3], 0.85)
	box:EnableMouse(true)
	box:Hide()

	title = Font(box, 13, { 1, 0.48, 0.42 })
	title:SetPoint("TOP", box, "TOP", 0, -12)
	text = Font(box, 10, { 1, 1, 1 })
	text:SetWidth(330)
	text:SetPoint("TOP", title, "BOTTOM", 0, -8)

	input = CreateFrame("EditBox", nil, box)
	input:SetWidth(110)
	input:SetHeight(20)
	input:SetPoint("TOP", text, "BOTTOM", 0, -8)
	input:SetAutoFocus(false)
	input:SetMaxLetters(12)
	input:SetFont(SurvivorUI_FONT, 11 + (SurvivorUI_FONT_BUMP or 0), "OUTLINE")
	input:SetJustifyH("CENTER")
	input:SetTextColor(1, 1, 1)
	input:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	input:SetBackdropColor(0, 0, 0, 0.6)
	input:SetBackdropBorderColor(RED.edge[1], RED.edge[2], RED.edge[3], 0.6)
	input:SetScript("OnTextChanged", function() Ready() end)
	input:SetScript("OnEnterPressed", function() Go() end)
	input:SetScript("OnEscapePressed", function() SurvivorUI_ConfirmClose() end)

	yes = SurvivorUI_GoldButton(box, 90, TRASH, nil, "Delete", RED)
	yes.icon:SetVertexColor(1, 0.66, 0.62)
	yes:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -5, 12)
	yes:SetScript("OnClick", function() Go() end)
	no = SurvivorUI_GoldButton(box, 90, nil, nil, "Cancel")
	no.icon:Hide()
	no.text:ClearAllPoints()
	no.text:SetPoint("CENTER", no, "CENTER", 0, 0)
	no:SetPoint("BOTTOMLEFT", box, "BOTTOM", 5, 12)
	no:SetScript("OnClick", function() SurvivorUI_ConfirmClose() end)

	-- Without a word to type, the keys reach the box: Enter goes, Escape leaves.
	box:SetScript("OnKeyDown", function()
		if arg1 == "ESCAPE" then
			SurvivorUI_ConfirmClose()
		elseif arg1 == "ENTER" then
			Go()
		end
	end)
	box:SetScript("OnHide", function()
		input:ClearFocus()
		shade:Hide()
	end)
end

function SurvivorUI_Confirm(spec)
	if not SurvivorUI_GoldButton then
		-- Never before every file is loaded; then, as before the box: at once.
		if spec.onYes then
			spec.onYes()
		end
		return
	end
	if not box then
		Build()
	end
	asked = spec
	title:SetText(spec.title or "Are you sure?")
	text:SetText(spec.text or "")
	yes.text:SetText(spec.yes or "Delete")
	yes:SetWidth(yes.text:GetStringWidth() + 30)
	input:SetText("")
	local height = 12 + title:GetHeight() + 8 + text:GetHeight() + 12 + 17 + 12
	if spec.word then
		input:Show()
		box:EnableKeyboard(false)
		height = height + 28
	else
		input:Hide()
		box:EnableKeyboard(true)
	end
	box:SetHeight(height)
	Ready()
	shade:Show()
	box:Show()
	if spec.word then
		input:SetFocus()
	end
end
