-- RaidCommsHelper UI Widgets
-- Reusable UI components

local RCH = RaidCommsHelper
RCH.Widgets = RCH.Widgets or {}

local Widgets = RCH.Widgets

-- Colors - refined dark theme with warm golden accents
local COLORS = {
    -- Backgrounds
    background = { 0.065, 0.06, 0.055, 0.98 },
    backgroundAlt = { 0.08, 0.075, 0.07, 0.98 },
    backgroundDark = { 0.045, 0.042, 0.04, 0.98 },
    -- Borders
    border = { 0.28, 0.26, 0.22, 1 },
    borderSubtle = { 0.22, 0.2, 0.18, 1 },
    borderActive = { 0.85, 0.65, 0.25, 1 },
    -- Highlights and selections
    highlight = { 0.16, 0.15, 0.13, 1 },
    selected = { 0.22, 0.18, 0.12, 1 },
    -- Text
    text = { 0.95, 0.92, 0.88, 1 },
    textDim = { 0.55, 0.52, 0.48, 1 },
    textMuted = { 0.4, 0.38, 0.35, 1 },
    -- Accents
    accent = { 0.85, 0.65, 0.25, 1 },
    accentBright = { 1.0, 0.78, 0.35, 1 },
    accentDim = { 0.55, 0.42, 0.15, 1 },
    -- Interactive (secondary)
    interactive = { 0.35, 0.75, 0.9, 1 },
    -- States
    warning = { 0.95, 0.6, 0.15, 1 },
    success = { 0.35, 0.7, 0.35, 1 },
    danger = { 0.75, 0.25, 0.2, 1 },
}
Widgets.COLORS = COLORS

-- Create a basic backdrop frame
function Widgets:CreateBackdropFrame(parent, name)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(unpack(COLORS.background))
    frame:SetBackdropBorderColor(unpack(COLORS.border))

    return frame
end

-- Create a refined button with subtle styling
function Widgets:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 80, height or 24)

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    button:SetBackdropColor(0.14, 0.13, 0.12, 1)
    button:SetBackdropBorderColor(unpack(COLORS.borderSubtle))

    -- Subtle top highlight for depth
    button.highlight = button:CreateTexture(nil, "ARTWORK")
    button.highlight:SetPoint("TOPLEFT", 1, -1)
    button.highlight:SetPoint("TOPRIGHT", -1, -1)
    button.highlight:SetHeight(1)
    button.highlight:SetColorTexture(1, 1, 1, 0.03)

    -- Store custom color for hover restoration
    button.customColor = nil

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "")
    button.text:SetTextColor(0.88, 0.85, 0.8, 1)

    -- Override SetBackdropColor to track custom colors
    local originalSetBackdropColor = button.SetBackdropColor
    function button:SetBackdropColor(r, g, b, a)
        self.customColor = { r, g, b, a or 1 }
        originalSetBackdropColor(self, r, g, b, a)
    end

    button:SetScript("OnEnter", function(self)
        -- Brighten the current color on hover
        if self.customColor then
            local r, g, b, a = unpack(self.customColor)
            originalSetBackdropColor(self, math.min(r + 0.1, 1), math.min(g + 0.1, 1), math.min(b + 0.1, 1), a)
        else
            originalSetBackdropColor(self, 0.22, 0.2, 0.18, 1)
        end
        self:SetBackdropBorderColor(unpack(COLORS.border))
        self.text:SetTextColor(1, 0.95, 0.88, 1)
    end)

    button:SetScript("OnLeave", function(self)
        -- Restore original color
        if self.customColor then
            originalSetBackdropColor(self, unpack(self.customColor))
        else
            originalSetBackdropColor(self, 0.14, 0.13, 0.12, 1)
        end
        self:SetBackdropBorderColor(unpack(COLORS.borderSubtle))
        self.text:SetTextColor(0.88, 0.85, 0.8, 1)
    end)

    button:SetScript("OnMouseDown", function(self)
        -- Darken on click
        if self.customColor then
            local r, g, b, a = unpack(self.customColor)
            originalSetBackdropColor(self, math.max(r - 0.08, 0), math.max(g - 0.08, 0), math.max(b - 0.08, 0), a)
        else
            originalSetBackdropColor(self, 0.1, 0.09, 0.08, 1)
        end
    end)

    button:SetScript("OnMouseUp", function(self)
        -- Restore to hover state (since mouse is still over)
        if self.customColor then
            local r, g, b, a = unpack(self.customColor)
            originalSetBackdropColor(self, math.min(r + 0.1, 1), math.min(g + 0.1, 1), math.min(b + 0.1, 1), a)
        else
            originalSetBackdropColor(self, 0.22, 0.2, 0.18, 1)
        end
    end)

    function button:SetLabel(newText)
        self.text:SetText(newText)
    end

    return button
end

-- Create a scroll frame with content
function Widgets:CreateScrollFrame(parent, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")

    -- Style the scroll bar
    local scrollBar = scrollFrame.ScrollBar or _G[name .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 16)
    end

    -- Create scroll child (content container)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame.content = scrollChild

    return scrollFrame, scrollChild
end

-- Create a list item row with refined styling
function Widgets:CreateListItem(parent, height)
    local item = CreateFrame("Button", nil, parent, "BackdropTemplate")
    item:SetHeight(height or 28)

    item:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    item:SetBackdropColor(0, 0, 0, 0)

    -- Left accent bar (shows when selected)
    item.accentBar = item:CreateTexture(nil, "ARTWORK")
    item.accentBar:SetPoint("TOPLEFT", 0, -2)
    item.accentBar:SetPoint("BOTTOMLEFT", 0, 2)
    item.accentBar:SetWidth(2)
    item.accentBar:SetColorTexture(unpack(COLORS.accent))
    item.accentBar:Hide()

    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.text:SetPoint("LEFT", 10, 0)
    item.text:SetJustifyH("LEFT")
    item.text:SetTextColor(0.75, 0.72, 0.68, 1)

    -- Highlight on hover
    item:SetScript("OnEnter", function(self)
        if not self.selected then
            self:SetBackdropColor(unpack(COLORS.highlight))
            self.text:SetTextColor(0.92, 0.88, 0.82, 1)
        end
    end)

    item:SetScript("OnLeave", function(self)
        if not self.selected then
            self:SetBackdropColor(0, 0, 0, 0)
            self.text:SetTextColor(0.75, 0.72, 0.68, 1)
        end
    end)

    function item:SetSelected(selected)
        self.selected = selected
        if selected then
            self:SetBackdropColor(unpack(COLORS.selected))
            self.text:SetTextColor(unpack(COLORS.accentBright))
            self.accentBar:Show()
        else
            self:SetBackdropColor(0, 0, 0, 0)
            self.text:SetTextColor(0.75, 0.72, 0.68, 1)
            self.accentBar:Hide()
        end
    end

    function item:SetLabel(text)
        self.text:SetText(text)
    end

    return item
end

-- Create an edit box (single line) with refined styling
function Widgets:CreateEditBox(parent, width, height)
    local editBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    editBox:SetSize(width or 200, height or 24)

    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 4, right = 4, top = 2, bottom = 2 }
    })
    editBox:SetBackdropColor(0.08, 0.075, 0.07, 1)
    editBox:SetBackdropBorderColor(unpack(COLORS.borderSubtle))

    editBox:SetFontObject(GameFontHighlight)
    editBox:SetTextColor(0.95, 0.92, 0.88, 1)
    editBox:SetTextInsets(8, 8, 0, 0)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetCursorPosition(0)

    -- Highlight border when focused
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.accent))  -- Gold border when focused
        self:HighlightText(0, 0)  -- Clear any highlight, show cursor
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.borderSubtle))
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    return editBox
end

-- Create a multi-line edit box using InputScrollFrameTemplate (WoW's native editable scroll box)
function Widgets:CreateMultiLineEditBox(parent, width, height)
    local container = self:CreateBackdropFrame(parent)
    container:SetSize(width or 300, height or 100)
    container:SetBackdropColor(0.08, 0.075, 0.07, 1)
    container:SetBackdropBorderColor(unpack(COLORS.borderSubtle))

    -- Use InputScrollFrameTemplate - WoW's built-in template for scrollable editable text
    -- This handles cursor positioning, text selection, and scrolling natively
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "InputScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -6, 6)

    -- InputScrollFrameTemplate creates its own EditBox as scrollFrame.EditBox
    local editBox = scrollFrame.EditBox
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetAutoFocus(false)
    editBox:SetWidth(width - 16)

    -- Hide the character count if present
    if scrollFrame.CharCount then
        scrollFrame.CharCount:Hide()
    end

    container.editBox = editBox
    container.scrollFrame = scrollFrame

    -- Highlight border when focused
    editBox:HookScript("OnEditFocusGained", function(self)
        container:SetBackdropBorderColor(unpack(COLORS.accent))  -- Gold border when focused
    end)

    editBox:HookScript("OnEditFocusLost", function(self)
        container:SetBackdropBorderColor(unpack(COLORS.borderSubtle))
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    function container:GetText()
        return self.editBox:GetText()
    end

    function container:SetText(text)
        self.editBox:SetText(text or "")
    end

    function container:ClearFocus()
        self.editBox:ClearFocus()
    end

    return container
end

-- Create a dropdown (simple version) with refined styling
function Widgets:CreateDropdown(parent, width)
    local dropdown = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width or 120, 24)

    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(0.14, 0.13, 0.12, 1)
    dropdown:SetBackdropBorderColor(unpack(COLORS.borderSubtle))

    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdown.text:SetPoint("LEFT", 10, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetTextColor(0.92, 0.88, 0.82, 1)

    dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdown.arrow:SetPoint("RIGHT", -10, 0)
    dropdown.arrow:SetText("v")
    dropdown.arrow:SetTextColor(unpack(COLORS.textDim))

    dropdown.options = {}
    dropdown.selectedValue = nil

    -- Create menu frame
    dropdown.menu = self:CreateBackdropFrame(dropdown)
    dropdown.menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    dropdown.menu:SetFrameStrata("DIALOG")
    dropdown.menu:Hide()

    dropdown:EnableMouse(true)
    dropdown:SetScript("OnMouseDown", function(self)
        if self.menu:IsShown() then
            self.menu:Hide()
        else
            self:ShowMenu()
        end
    end)

    function dropdown:SetOptions(options)
        self.options = options

        -- Clear old menu items
        for _, child in ipairs({ self.menu:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        -- Create new menu items
        local menuHeight = 4
        for i, opt in ipairs(options) do
            local item = Widgets:CreateListItem(self.menu, 22)
            item:SetPoint("TOPLEFT", 2, -menuHeight)
            item:SetPoint("RIGHT", -2, 0)
            item:SetLabel(opt.label)
            item.value = opt.value

            item:SetScript("OnClick", function()
                dropdown:SetValue(opt.value)
                dropdown.menu:Hide()
                if dropdown.OnValueChanged then
                    dropdown:OnValueChanged(opt.value)
                end
            end)

            menuHeight = menuHeight + 22
        end

        self.menu:SetSize(self:GetWidth(), menuHeight + 4)
    end

    function dropdown:ShowMenu()
        self.menu:Show()

        -- Close menu when clicking elsewhere
        local closeFrame = CreateFrame("Frame", nil, UIParent)
        closeFrame:SetAllPoints()
        closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        closeFrame:EnableMouse(true)
        closeFrame:SetScript("OnMouseDown", function(self)
            dropdown.menu:Hide()
        end)

        -- Store reference so we can clean up when menu hides
        dropdown.closeFrame = closeFrame

        -- Put menu above close frame
        self.menu:SetFrameStrata("TOOLTIP")
    end

    -- Clean up close frame whenever menu hides (item selected OR clicked outside)
    dropdown.menu:SetScript("OnHide", function()
        if dropdown.closeFrame then
            dropdown.closeFrame:Hide()
            dropdown.closeFrame:SetParent(nil)
            dropdown.closeFrame = nil
        end
    end)

    function dropdown:SetValue(value)
        self.selectedValue = value
        for _, opt in ipairs(self.options) do
            if opt.value == value then
                self.text:SetText(opt.label)
                return
            end
        end
    end

    function dropdown:GetValue()
        return self.selectedValue
    end

    return dropdown
end

-- Create a simple label
function Widgets:CreateLabel(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    label:SetText(text or "")
    return label
end

-- ============================================================================
-- VERS TRACKER WIDGETS
-- ============================================================================

-- Get background color based on versatility percentage (heat map: blue → red)
function Widgets:GetVersBackgroundColor(vers)
    vers = vers or 0
    if vers < 50 then
        -- Dark blue (very weak) - warning territory
        return 0.12, 0.18, 0.30, 0.95
    elseif vers < 100 then
        -- Blue-cyan (weak)
        return 0.12, 0.25, 0.38, 0.95
    elseif vers < 200 then
        -- Teal-green (adequate)
        return 0.15, 0.32, 0.28, 0.95
    elseif vers < 300 then
        -- Yellow-green (good)
        return 0.28, 0.35, 0.15, 0.95
    elseif vers < 500 then
        -- Orange (strong)
        return 0.42, 0.28, 0.10, 0.95
    else
        -- Red (very strong)
        return 0.48, 0.15, 0.12, 0.95
    end
end

-- Get class color from WoW's built-in colors
function Widgets:GetClassColor(classFile)
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 0.7, 0.7, 0.7  -- Default gray
end

-- Create a compact player slot for the group grid
-- Shows: [ClassBar | Name] with vers-colored background
function Widgets:CreatePlayerSlot(parent, width, height)
    width = width or 90
    height = height or 22

    local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
    slot:SetSize(width, height)

    -- Main background (vers gradient)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    slot:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Class color bar (left edge)
    slot.classBar = slot:CreateTexture(nil, "ARTWORK")
    slot.classBar:SetPoint("TOPLEFT", 1, -1)
    slot.classBar:SetPoint("BOTTOMLEFT", 1, 1)
    slot.classBar:SetWidth(4)
    slot.classBar:SetColorTexture(0.5, 0.5, 0.5, 1)

    -- Player name
    slot.nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.nameText:SetPoint("LEFT", slot.classBar, "RIGHT", 4, 0)
    slot.nameText:SetPoint("RIGHT", -4, 0)
    slot.nameText:SetJustifyH("LEFT")
    slot.nameText:SetText("")
    slot.nameText:SetTextColor(1, 1, 1, 1)

    -- Selection highlight border
    slot.selectBorder = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    slot.selectBorder:SetAllPoints()
    slot.selectBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    slot.selectBorder:SetBackdropBorderColor(0, 0.7, 1, 1)
    slot.selectBorder:Hide()

    -- Warning icon for low vers (<50%)
    slot.warningIcon = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slot.warningIcon:SetPoint("RIGHT", -2, 0)
    slot.warningIcon:SetText("!")
    slot.warningIcon:SetTextColor(1, 0.4, 0, 1)
    slot.warningIcon:Hide()

    -- State
    slot.playerData = nil
    slot.isEmpty = true
    slot.isSelected = false

    -- Hover effect
    slot:SetScript("OnEnter", function(self)
        if not self.isEmpty then
            self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
            -- Show tooltip with full info
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.playerData then
                local p = self.playerData
                GameTooltip:AddLine(p.name, 1, 1, 1)
                GameTooltip:AddLine(string.format("Vers: %.1f%%", p.vers or 0), 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Group " .. (p.group or "?"), 0.6, 0.6, 0.6)
                GameTooltip:AddLine("Click to select", 0, 0.8, 1)
            end
            GameTooltip:Show()
        end
    end)

    slot:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        GameTooltip:Hide()
    end)

    -- Set player data and update display
    function slot:SetPlayer(playerData)
        self.playerData = playerData

        if playerData and playerData.name then
            self.isEmpty = false

            -- Truncate name if needed
            local displayName = playerData.name
            if #displayName > 10 then
                displayName = displayName:sub(1, 9) .. "…"
            end
            self.nameText:SetText(displayName)

            -- Class color bar
            local r, g, b = Widgets:GetClassColor(playerData.classFile)
            self.classBar:SetColorTexture(r, g, b, 1)

            -- Vers background color
            local vr, vg, vb, va = Widgets:GetVersBackgroundColor(playerData.vers or 0)
            self:SetBackdropColor(vr, vg, vb, va)

            -- Warning for very low vers
            if (playerData.vers or 0) < 50 then
                self.warningIcon:Show()
            else
                self.warningIcon:Hide()
            end
        else
            self:Clear()
        end
    end

    -- Clear the slot (empty state)
    function slot:Clear()
        self.playerData = nil
        self.isEmpty = true
        self.nameText:SetText("")
        self.classBar:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
        self.warningIcon:Hide()
        self:SetSelected(false)
    end

    -- Selection state
    function slot:SetSelected(selected)
        self.isSelected = selected
        if selected then
            self.selectBorder:Show()
            self:SetBackdropBorderColor(0, 0.7, 1, 1)
        else
            self.selectBorder:Hide()
            if not self.isEmpty then
                self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
        end
    end

    return slot
end

-- Create an empty/placeholder slot that can receive players
function Widgets:CreateEmptySlot(parent, width, height)
    width = width or 90
    height = height or 22

    local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
    slot:SetSize(width, height)

    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slot:SetBackdropColor(0.08, 0.08, 0.08, 0.4)
    slot:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.4)

    -- Dashed/dotted indicator that this is a drop target
    slot.plusIcon = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.plusIcon:SetPoint("CENTER")
    slot.plusIcon:SetText("+")
    slot.plusIcon:SetTextColor(0.4, 0.4, 0.4, 0.6)

    slot.isEmpty = true
    slot.groupNum = nil

    -- Hover highlight when player is selected (valid drop target)
    slot:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.15, 0.25, 0.15, 0.6)
        self:SetBackdropBorderColor(0.3, 0.5, 0.3, 0.8)
    end)

    slot:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.08, 0.08, 0.08, 0.4)
        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.4)
    end)

    return slot
end

-- Create a group row (label + 5 player slots)
function Widgets:CreateGroupRow(parent, groupNum, slotWidth, slotHeight)
    slotWidth = slotWidth or 85
    slotHeight = slotHeight or 22
    local spacing = 3
    local labelWidth = 28

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(slotHeight + 4)

    -- Group label
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetWidth(labelWidth)
    row.label:SetText("G" .. groupNum)
    row.label:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Clickable label area (for moving player to this group)
    row.labelBtn = CreateFrame("Button", nil, row)
    row.labelBtn:SetPoint("TOPLEFT")
    row.labelBtn:SetSize(labelWidth, slotHeight + 4)
    row.labelBtn.groupNum = groupNum

    row.labelBtn:SetScript("OnEnter", function(self)
        row.label:SetTextColor(0, 0.8, 1, 1)
    end)
    row.labelBtn:SetScript("OnLeave", function(self)
        row.label:SetTextColor(0.6, 0.6, 0.6, 1)
    end)

    -- 5 player slots
    row.slots = {}
    for i = 1, 5 do
        local slot = Widgets:CreatePlayerSlot(row, slotWidth, slotHeight)
        slot:SetPoint("LEFT", labelWidth + (i - 1) * (slotWidth + spacing), 0)
        slot.slotIndex = i
        slot.groupNum = groupNum
        row.slots[i] = slot
    end

    row.groupNum = groupNum

    -- Calculate total width
    local totalWidth = labelWidth + 5 * slotWidth + 4 * spacing
    row:SetWidth(totalWidth)

    -- Set players for this row
    function row:SetPlayers(players)
        for i = 1, 5 do
            local slot = self.slots[i]
            if players and players[i] then
                slot:SetPlayer(players[i])
            else
                slot:Clear()
            end
        end
    end

    -- Clear all slots
    function row:ClearAll()
        for i = 1, 5 do
            self.slots[i]:Clear()
        end
    end

    return row
end

-- Create a vers ranking list item (for right panel)
function Widgets:CreateVersRankItem(parent, width, height)
    width = width or 200
    height = height or 20

    local item = CreateFrame("Button", nil, parent, "BackdropTemplate")
    item:SetSize(width, height)

    item:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    item:SetBackdropColor(0, 0, 0, 0)

    -- Rank number
    item.rankText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.rankText:SetPoint("LEFT", 4, 0)
    item.rankText:SetWidth(20)
    item.rankText:SetJustifyH("RIGHT")
    item.rankText:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Class color bar
    item.classBar = item:CreateTexture(nil, "ARTWORK")
    item.classBar:SetPoint("LEFT", item.rankText, "RIGHT", 4, 0)
    item.classBar:SetSize(3, height - 4)
    item.classBar:SetColorTexture(0.5, 0.5, 0.5, 1)

    -- Vers bar (background fill based on vers)
    item.versBar = item:CreateTexture(nil, "BACKGROUND")
    item.versBar:SetPoint("TOPLEFT", item.classBar, "TOPRIGHT", 2, 0)
    item.versBar:SetPoint("BOTTOMLEFT", item.classBar, "BOTTOMRIGHT", 2, 0)
    item.versBar:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Player name
    item.nameText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.nameText:SetPoint("LEFT", item.classBar, "RIGHT", 6, 0)
    item.nameText:SetJustifyH("LEFT")

    -- Vers percentage
    item.versText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.versText:SetPoint("RIGHT", -4, 0)
    item.versText:SetJustifyH("RIGHT")

    -- Warning icon
    item.warningIcon = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.warningIcon:SetPoint("RIGHT", item.versText, "LEFT", -2, 0)
    item.warningIcon:SetText("!")
    item.warningIcon:SetTextColor(1, 0.4, 0, 1)
    item.warningIcon:Hide()

    -- Selection border
    item.selectBorder = CreateFrame("Frame", nil, item, "BackdropTemplate")
    item.selectBorder:SetAllPoints()
    item.selectBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    item.selectBorder:SetBackdropBorderColor(0, 0.7, 1, 1)
    item.selectBorder:Hide()

    item.playerData = nil
    item.isSelected = false

    -- Hover
    item:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    end)
    item:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end)

    -- Set player data
    function item:SetPlayer(rank, playerData, maxVers)
        self.playerData = playerData
        maxVers = maxVers or 500

        self.rankText:SetText(tostring(rank))

        if playerData then
            -- Name with class color
            local r, g, b = Widgets:GetClassColor(playerData.classFile)
            self.classBar:SetColorTexture(r, g, b, 1)
            self.nameText:SetText(playerData.name)
            self.nameText:SetTextColor(r, g, b, 1)

            -- Vers display
            local vers = playerData.vers or 0
            self.versText:SetText(string.format("%.0f%%", vers))

            -- Vers bar width (relative to panel width)
            local barWidth = math.min((vers / maxVers) * 80, 80)
            self.versBar:SetWidth(math.max(barWidth, 2))

            -- Color the vers bar based on value
            local vr, vg, vb = Widgets:GetVersBackgroundColor(vers)
            self.versBar:SetColorTexture(vr, vg, vb, 0.4)

            -- Warning for low vers
            if vers < 50 then
                self.warningIcon:Show()
            else
                self.warningIcon:Hide()
            end
        end
    end

    function item:SetSelected(selected)
        self.isSelected = selected
        if selected then
            self.selectBorder:Show()
            self:SetBackdropColor(0.1, 0.2, 0.3, 0.5)
        else
            self.selectBorder:Hide()
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end

    return item
end

-- Create a summon list item (for summon panel)
-- Shows: [Class Bar] Name ... Zone (Offline)
function Widgets:CreateSummonListItem(parent, width, height)
    width = width or 300
    height = height or 22

    local item = CreateFrame("Button", nil, parent, "BackdropTemplate")
    item:SetSize(width, height)

    item:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    item:SetBackdropColor(0, 0, 0, 0)

    -- Class color bar
    item.classBar = item:CreateTexture(nil, "ARTWORK")
    item.classBar:SetPoint("LEFT", 4, 0)
    item.classBar:SetSize(3, height - 4)
    item.classBar:SetColorTexture(0.5, 0.5, 0.5, 1)

    -- Player name
    item.nameText = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.nameText:SetPoint("LEFT", item.classBar, "RIGHT", 6, 0)
    item.nameText:SetJustifyH("LEFT")

    -- Zone text (right side)
    item.zoneText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.zoneText:SetPoint("RIGHT", -4, 0)
    item.zoneText:SetJustifyH("RIGHT")
    item.zoneText:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Offline indicator
    item.offlineText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.offlineText:SetPoint("RIGHT", item.zoneText, "LEFT", -6, 0)
    item.offlineText:SetText("(Offline)")
    item.offlineText:SetTextColor(0.6, 0.3, 0.3, 1)
    item.offlineText:Hide()

    item.playerData = nil

    -- Hover
    item:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
        if self.playerData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.playerData.name, 1, 1, 1)
            GameTooltip:AddLine("Zone: " .. (self.playerData.zone or "Unknown"), 0.7, 0.7, 0.7)
            if not self.playerData.online then
                GameTooltip:AddLine("Player is offline", 0.8, 0.4, 0.4)
            end
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
    end)

    -- Set player data
    function item:SetPlayer(playerData)
        self.playerData = playerData

        if playerData then
            -- Name with class color
            local r, g, b = Widgets:GetClassColor(playerData.classFile)
            self.classBar:SetColorTexture(r, g, b, 1)
            self.nameText:SetText(playerData.name)
            self.nameText:SetTextColor(r, g, b, 1)

            -- Zone
            self.zoneText:SetText(playerData.zone or "Unknown")

            -- Offline indicator
            if not playerData.online then
                self.offlineText:Show()
                self.nameText:SetTextColor(r * 0.5, g * 0.5, b * 0.5, 1)  -- Dim the name
            else
                self.offlineText:Hide()
            end
        end
    end

    return item
end
