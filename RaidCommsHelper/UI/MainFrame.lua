-- RaidCommsHelper Main Frame
-- Primary UI window with tabs for Comms and Vers

local RCH = RaidCommsHelper
local Widgets = RCH.Widgets

local MainFrame = {}

-- Frame dimensions
local FRAME_WIDTH = 750
local FRAME_HEIGHT = 500
local FOLDER_WIDTH = 150
local MESSAGE_ROW_HEIGHT = 28
local PREVIEW_HEIGHT = 60

-- Tab state
local activeTab = "COMMS"

-- Expanded messages tracking (by folder and index)
local expandedMessages = {}

-- Drag and drop state
local dragState = {
    isDragging = false,
    sourceIndex = nil,
    targetIndex = nil,
    targetFolder = nil,  -- Target folder name when dragging to folder
    indicator = nil,     -- Visual drop indicator line
    sourceRow = nil,     -- Reference to the dragged row
}

-- Color scheme - refined dark theme with golden accents
local COLORS = {
    -- Primary accent - warm gold/amber for a premium feel
    accent = { 0.85, 0.65, 0.25, 1 },
    accentBright = { 1.0, 0.78, 0.35, 1 },
    accentDim = { 0.55, 0.42, 0.15, 1 },
    -- Secondary accent - cool cyan for interactive elements
    interactive = { 0.35, 0.75, 0.9, 1 },
    interactiveBright = { 0.5, 0.85, 1.0, 1 },
    -- Tab colors
    tabActive = { 0.75, 0.55, 0.18, 1 },
    tabInactive = { 0.18, 0.18, 0.2, 1 },
    tabHover = { 0.28, 0.28, 0.32, 1 },
    -- Backgrounds with subtle warmth
    headerBg = { 0.1, 0.095, 0.09, 1 },
    panelBg = { 0.065, 0.06, 0.055, 0.98 },
    panelBgAlt = { 0.08, 0.075, 0.07, 0.98 },
    -- Row states
    rowHover = { 0.16, 0.15, 0.13, 1 },
    rowSelected = { 0.22, 0.18, 0.12, 1 },
    previewBg = { 0.045, 0.042, 0.04, 1 },
    -- Borders
    borderSubtle = { 0.25, 0.23, 0.2, 1 },
    borderActive = { 0.85, 0.65, 0.25, 1 },
}

-- Create tab button with refined styling
local function CreateTabButton(parent, text, tabId)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(72, 26)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- Top accent line (shows when active)
    btn.accentLine = btn:CreateTexture(nil, "OVERLAY")
    btn.accentLine:SetPoint("TOPLEFT", 1, -1)
    btn.accentLine:SetPoint("TOPRIGHT", -1, -1)
    btn.accentLine:SetHeight(2)
    btn.accentLine:SetColorTexture(unpack(COLORS.accent))
    btn.accentLine:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER", 0, -1)
    btn.text:SetText(text)

    btn.tabId = tabId

    function btn:SetActive(isActive)
        if isActive then
            self:SetBackdropColor(unpack(COLORS.panelBg))
            self:SetBackdropBorderColor(unpack(COLORS.borderSubtle))
            self.text:SetTextColor(unpack(COLORS.accentBright))
            self.accentLine:Show()
        else
            self:SetBackdropColor(unpack(COLORS.tabInactive))
            self:SetBackdropBorderColor(0.22, 0.22, 0.24, 1)
            self.text:SetTextColor(0.55, 0.52, 0.48, 1)
            self.accentLine:Hide()
        end
    end

    btn:SetScript("OnEnter", function(self)
        if activeTab ~= self.tabId then
            self:SetBackdropColor(unpack(COLORS.tabHover))
            self.text:SetTextColor(0.8, 0.75, 0.65, 1)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetActive(activeTab == self.tabId)
    end)

    return btn
end

-- Create the main frame
local function CreateMainFrame()
    local frame = Widgets:CreateBackdropFrame(UIParent, "RaidCommsHelperMainFrame")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Register with ESC key handler so ESC closes the window
    tinsert(UISpecialFrames, "RaidCommsHelperMainFrame")

    -- Title bar with refined styling
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(34)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(unpack(COLORS.headerBg))
    titleBar:SetBackdropBorderColor(0.18, 0.17, 0.16, 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Bottom accent line on title bar
    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("BOTTOMLEFT", 0, 0)
    titleAccent:SetPoint("BOTTOMRIGHT", 0, 0)
    titleAccent:SetHeight(1)
    titleAccent:SetColorTexture(unpack(COLORS.accentDim))

    -- Title with styled text
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 14, 0)
    title:SetText("RCH")
    title:SetTextColor(unpack(COLORS.accent))

    -- Subtitle
    local subtitle = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 6, 0)
    subtitle:SetText("Raid Comms Helper")
    subtitle:SetTextColor(0.5, 0.48, 0.44, 1)

    -- Tab buttons
    local commsTab = CreateTabButton(titleBar, "COMMS", "COMMS")
    commsTab:SetPoint("LEFT", subtitle, "RIGHT", 20, 0)
    frame.commsTab = commsTab

    local versTab = CreateTabButton(titleBar, "VERS", "VERS")
    versTab:SetPoint("LEFT", commsTab, "RIGHT", 4, 0)
    frame.versTab = versTab

    local summonTab = CreateTabButton(titleBar, "SUMMON", "SUMMON")
    summonTab:SetPoint("LEFT", versTab, "RIGHT", 4, 0)
    frame.summonTab = summonTab

    -- Close button
    local closeBtn = Widgets:CreateButton(titleBar, "X", 24, 20)
    closeBtn:SetPoint("RIGHT", -6, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- ============ COMMS TAB CONTENT ============
    local commsContent = CreateFrame("Frame", nil, frame)
    commsContent:SetPoint("TOPLEFT", 4, -38)
    commsContent:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.commsContent = commsContent

    -- Folder panel (left side)
    local folderPanel = Widgets:CreateBackdropFrame(commsContent)
    folderPanel:SetPoint("TOPLEFT", 0, 0)
    folderPanel:SetPoint("BOTTOMLEFT", 0, 0)
    folderPanel:SetWidth(FOLDER_WIDTH)
    frame.folderPanel = folderPanel

    local folderLabel = folderPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    folderLabel:SetPoint("TOPLEFT", 8, -8)
    folderLabel:SetText("FOLDERS")
    folderLabel:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Folder scroll frame
    local folderScroll, folderContent = Widgets:CreateScrollFrame(folderPanel, "RCHFolderScroll")
    folderScroll:SetPoint("TOPLEFT", 4, -28)
    folderScroll:SetPoint("BOTTOMRIGHT", -22, 36)
    folderContent:SetWidth(FOLDER_WIDTH - 26)
    frame.folderContent = folderContent
    frame.folderItems = {}

    -- Add Folder button
    local addFolderBtn = Widgets:CreateButton(folderPanel, "+ Folder", FOLDER_WIDTH - 8, 24)
    addFolderBtn:SetPoint("BOTTOMLEFT", 4, 4)
    addFolderBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    addFolderBtn:SetScript("OnClick", function()
        MainFrame:ShowAddFolderDialog()
    end)

    -- Message panel (right side)
    local messagePanel = Widgets:CreateBackdropFrame(commsContent)
    messagePanel:SetPoint("TOPLEFT", folderPanel, "TOPRIGHT", 4, 0)
    messagePanel:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.messagePanel = messagePanel

    local messageLabel = messagePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    messageLabel:SetPoint("TOPLEFT", 8, -8)
    messageLabel:SetText("MESSAGES")
    messageLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    frame.messageLabel = messageLabel

    -- Message scroll frame
    local messageScroll, messageContent = Widgets:CreateScrollFrame(messagePanel, "RCHMessageScroll")
    messageScroll:SetPoint("TOPLEFT", 4, -28)
    messageScroll:SetPoint("BOTTOMRIGHT", -22, 36)
    messageContent:SetWidth(FRAME_WIDTH - FOLDER_WIDTH - 40)
    frame.messageScroll = messageScroll
    frame.messageContent = messageContent
    frame.messageItems = {}

    -- Bottom buttons for messages
    local addMsgBtn = Widgets:CreateButton(messagePanel, "+ Add Message", 110, 24)
    addMsgBtn:SetPoint("BOTTOMLEFT", 4, 4)
    addMsgBtn:SetScript("OnClick", function()
        MainFrame:ShowEditMessageDialog(nil)
    end)

    -- Reload UI button
    local reloadBtn = Widgets:CreateButton(messagePanel, "RL", 28, 24)  -- Reload
    reloadBtn:SetPoint("BOTTOMRIGHT", -200, 4)
    reloadBtn:SetBackdropColor(0.3, 0.3, 0.5, 1)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)
    reloadBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reload UI", 1, 1, 1)
        GameTooltip:AddLine("Saves your edits and reloads the interface", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    reloadBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Load from File button
    local loadFileBtn = Widgets:CreateButton(messagePanel, "Load File", 60, 24)
    loadFileBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 4, 0)
    loadFileBtn:SetBackdropColor(0.4, 0.4, 0.1, 1)
    loadFileBtn:SetScript("OnClick", function()
        MainFrame:LoadFromFile()
    end)
    loadFileBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Load from File", 1, 1, 1)
        GameTooltip:AddLine("Loads messages from DefaultMessages.lua", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Edit the file externally, then click Reload + this", 0.5, 0.8, 0.5, true)
        GameTooltip:Show()
    end)
    loadFileBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Export button (show current data for copying)
    local exportBtn = Widgets:CreateButton(messagePanel, "Export", 55, 24)
    exportBtn:SetPoint("LEFT", loadFileBtn, "RIGHT", 4, 0)
    exportBtn:SetBackdropColor(0.1, 0.4, 0.4, 1)
    exportBtn:SetScript("OnClick", function()
        MainFrame:ExportToExternal()
    end)
    exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Export Messages", 1, 1, 1)
        GameTooltip:AddLine("Shows messages in a format you can copy", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("into DefaultMessages.lua", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ============ VERS TAB CONTENT ============
    local versContent = CreateFrame("Frame", nil, frame)
    versContent:SetPoint("TOPLEFT", 4, -38)
    versContent:SetPoint("BOTTOMRIGHT", -4, 4)
    versContent:Hide()
    frame.versContent = versContent

    -- Placeholder for vers panel (will be populated by VersPanel.lua)
    local versPlaceholder = versContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    versPlaceholder:SetPoint("CENTER")
    versPlaceholder:SetText("Vers Panel Loading...")
    versPlaceholder:SetTextColor(0.5, 0.5, 0.5, 1)
    frame.versPlaceholder = versPlaceholder

    -- ============ SUMMON TAB CONTENT ============
    local summonContent = CreateFrame("Frame", nil, frame)
    summonContent:SetPoint("TOPLEFT", 4, -38)
    summonContent:SetPoint("BOTTOMRIGHT", -4, 4)
    summonContent:Hide()
    frame.summonContent = summonContent

    -- Placeholder for summon panel (will be populated by SummonPanel.lua)
    local summonPlaceholder = summonContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    summonPlaceholder:SetPoint("CENTER")
    summonPlaceholder:SetText("Summon Panel Loading...")
    summonPlaceholder:SetTextColor(0.5, 0.5, 0.5, 1)
    frame.summonPlaceholder = summonPlaceholder

    -- Tab click handlers
    commsTab:SetScript("OnClick", function()
        activeTab = "COMMS"
        commsTab:SetActive(true)
        versTab:SetActive(false)
        summonTab:SetActive(false)
        commsContent:Show()
        versContent:Hide()
        summonContent:Hide()
        if RCH.VersPanel then RCH.VersPanel:Hide() end
        if RCH.SummonPanel then RCH.SummonPanel:Hide() end
    end)

    versTab:SetScript("OnClick", function()
        activeTab = "VERS"
        commsTab:SetActive(false)
        versTab:SetActive(true)
        summonTab:SetActive(false)
        commsContent:Hide()
        versContent:Show()
        summonContent:Hide()
        -- Show vers panel content
        if RCH.VersPanel then
            frame.versPlaceholder:Hide()
            RCH.VersPanel:Show()
        end
        if RCH.SummonPanel then RCH.SummonPanel:Hide() end
    end)

    summonTab:SetScript("OnClick", function()
        activeTab = "SUMMON"
        commsTab:SetActive(false)
        versTab:SetActive(false)
        summonTab:SetActive(true)
        commsContent:Hide()
        versContent:Hide()
        summonContent:Show()
        if RCH.VersPanel then RCH.VersPanel:Hide() end
        -- Show summon panel content
        if RCH.SummonPanel then
            frame.summonPlaceholder:Hide()
            RCH.SummonPanel:Show()
        end
    end)

    -- Set initial tab state
    commsTab:SetActive(true)
    versTab:SetActive(false)
    summonTab:SetActive(false)

    frame.mainFrame = frame
    return frame
end

-- Get expand key for a message
local function GetExpandKey(folderName, msgIndex)
    return folderName .. ":" .. msgIndex
end

-- Clear folder drag highlights
function MainFrame:ClearFolderHighlights()
    local frame = self.frame
    if not frame or not frame.folderItems then return end

    for _, item in ipairs(frame.folderItems) do
        if item.dragHighlight then
            item.dragHighlight:Hide()
        end
        -- Restore normal appearance
        local db = RCH.db
        if item.folderName then
            local isActive = (item.folderName == db.activeFolder)
            item:SetSelected(isActive)
        end
    end
end

-- Refresh the folder list
function MainFrame:RefreshFolderList()
    local frame = self.frame
    local content = frame.folderContent
    local db = RCH.db

    -- Clear existing items
    for _, item in ipairs(frame.folderItems) do
        item:Hide()
        item:SetParent(nil)
    end
    wipe(frame.folderItems)

    -- Sort folders by order
    local sortedFolders = {}
    for name, data in pairs(db.folders) do
        table.insert(sortedFolders, { name = name, order = data.order or 99 })
    end
    table.sort(sortedFolders, function(a, b) return a.order < b.order end)

    -- Create folder items
    local yOffset = 0
    for _, folderInfo in ipairs(sortedFolders) do
        local item = Widgets:CreateListItem(content, 26)
        item:SetPoint("TOPLEFT", 0, -yOffset)
        item:SetPoint("RIGHT", 0, 0)

        local isActive = (folderInfo.name == db.activeFolder)
        local prefix = isActive and "> " or "   "
        item:SetLabel(prefix .. folderInfo.name)
        item:SetSelected(isActive)

        item.folderName = folderInfo.name

        -- Create drag highlight overlay (hidden by default)
        local dragHighlight = item:CreateTexture(nil, "OVERLAY")
        dragHighlight:SetAllPoints()
        dragHighlight:SetColorTexture(0.85, 0.65, 0.25, 0.25)  -- Gold accent tint for drop target
        dragHighlight:Hide()
        item.dragHighlight = dragHighlight

        -- Handle drag hover for moving messages to folders
        -- Use cursor position checking instead of IsMouseOver() for reliable drag detection
        item:SetScript("OnUpdate", function(self)
            if not dragState.isDragging then
                if self.dragHighlight:IsShown() then
                    self.dragHighlight:Hide()
                end
                return
            end

            -- Don't allow dropping on the current folder
            if self.folderName == db.activeFolder then
                if self.dragHighlight:IsShown() then
                    self.dragHighlight:Hide()
                end
                return
            end

            -- Check if cursor is over this folder item using position calculations
            -- (IsMouseOver() doesn't work reliably during drag operations)
            local cursorX, cursorY = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            cursorX, cursorY = cursorX / scale, cursorY / scale

            local left, bottom, width, height = self:GetRect()
            if left and bottom and width and height then
                local right = left + width
                local top = bottom + height

                local isOver = cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top

                if isOver then
                    self.dragHighlight:Show()
                    dragState.targetFolder = self.folderName
                    dragState.targetIndex = nil  -- Clear reorder target when over folder
                    -- Hide the message reorder indicator when over a folder
                    if dragState.indicator then
                        dragState.indicator:Hide()
                    end
                else
                    self.dragHighlight:Hide()
                    -- Clear target folder if we moved away
                    if dragState.targetFolder == self.folderName then
                        dragState.targetFolder = nil
                    end
                end
            end
        end)

        -- Right-click context menu
        item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        item:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                db.activeFolder = self.folderName
                MainFrame:RefreshFolderList()
                MainFrame:RefreshMessageList()
            elseif button == "RightButton" then
                MainFrame:ShowFolderContextMenu(self.folderName)
            end
        end)

        table.insert(frame.folderItems, item)
        yOffset = yOffset + 26
    end

    content:SetHeight(yOffset)
end

-- Refresh the message list for the active folder
function MainFrame:RefreshMessageList()
    local frame = self.frame
    local content = frame.messageContent
    local db = RCH.db

    local folder = db.folders[db.activeFolder]
    local folderName = db.activeFolder or ""

    -- Update label
    frame.messageLabel:SetText("MESSAGES - " .. folderName)

    -- Reset drag state on any refresh (prevents stale state)
    dragState.isDragging = false
    dragState.sourceIndex = nil
    dragState.targetIndex = nil
    dragState.targetFolder = nil
    dragState.sourceRow = nil
    if dragState.indicator then
        dragState.indicator:Hide()
    end
    SetCursor(nil)
    MainFrame:ClearFolderHighlights()

    -- Clear existing items - thoroughly clean up to prevent ghosts
    for _, item in ipairs(frame.messageItems) do
        -- Remove OnUpdate to stop any running handlers
        item:SetScript("OnUpdate", nil)
        item:SetAlpha(1)
        item:Hide()
        item:ClearAllPoints()
        item:SetParent(nil)
    end
    wipe(frame.messageItems)

    if not folder or not folder.messages then
        return
    end

    -- Create drop indicator line fresh each time (prevents stale references)
    if dragState.indicator then
        dragState.indicator:Hide()
        dragState.indicator:SetParent(nil)
    end
    dragState.indicator = CreateFrame("Frame", nil, content, "BackdropTemplate")
    dragState.indicator:SetHeight(3)
    dragState.indicator:SetPoint("LEFT", 0, 0)
    dragState.indicator:SetPoint("RIGHT", 0, 0)
    dragState.indicator:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    dragState.indicator:SetBackdropColor(unpack(COLORS.accent))  -- Gold accent line
    dragState.indicator:SetFrameLevel(content:GetFrameLevel() + 10)
    dragState.indicator:Hide()

    -- Store the active folder name for validation during drag
    local activeFolderForDrag = folderName

    -- Helper to reorder messages (uses fresh db reference)
    local function MoveMessage(fromIndex, toIndex)
        -- Validate we're still on the same folder (user might have switched)
        local currentDb = RCH.db
        if currentDb.activeFolder ~= activeFolderForDrag then
            RCH:Print("Drag cancelled - folder changed")
            return
        end

        -- Get fresh folder reference
        local currentFolder = currentDb.folders[currentDb.activeFolder]
        if not currentFolder or not currentFolder.messages then return end

        local messages = currentFolder.messages
        local numMessages = #messages

        -- Validate indices
        if fromIndex < 1 or fromIndex > numMessages then return end
        if toIndex < 1 or toIndex > numMessages + 1 then return end
        if fromIndex == toIndex or fromIndex == toIndex - 1 then return end

        -- Make a copy of the item to move (defensive copy)
        local itemToMove = messages[fromIndex]
        if not itemToMove then return end

        local itemCopy = {
            name = itemToMove.name,
            text = itemToMove.text,
            chatType = itemToMove.chatType,
        }

        -- Remove item from original position
        table.remove(messages, fromIndex)

        -- Adjust target index if we removed from before it
        if toIndex > fromIndex then
            toIndex = toIndex - 1
        end

        -- Clamp to valid range
        toIndex = math.max(1, math.min(toIndex, #messages + 1))

        -- Insert copy at new position
        table.insert(messages, toIndex, itemCopy)

        -- Reset drag state before refresh
        dragState.isDragging = false
        dragState.sourceIndex = nil
        dragState.targetIndex = nil

        MainFrame:RefreshMessageList()
    end

    -- Create message items
    local yOffset = 0
    local contentWidth = FRAME_WIDTH - FOLDER_WIDTH - 40
    local rowPositions = {}  -- Track y positions for drop targeting

    for i, msg in ipairs(folder.messages) do
        local expandKey = GetExpandKey(folderName, i)
        local isExpanded = expandedMessages[expandKey]

        -- Calculate row height based on expansion
        local rowHeight = MESSAGE_ROW_HEIGHT
        if isExpanded then
            rowHeight = MESSAGE_ROW_HEIGHT + PREVIEW_HEIGHT + 4
        end

        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetPoint("RIGHT", 0, 0)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        row:SetBackdropColor(0, 0, 0, 0)

        -- Expand/collapse toggle
        local toggleBtn = CreateFrame("Button", nil, row)
        toggleBtn:SetSize(20, 20)
        toggleBtn:SetPoint("LEFT", 4, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)

        local toggleText = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toggleText:SetPoint("CENTER")
        toggleText:SetText(isExpanded and "-" or "+")  -- Use simple ASCII characters
        toggleText:SetTextColor(0.6, 0.6, 0.6, 1)

        local function toggleExpand()
            expandedMessages[expandKey] = not expandedMessages[expandKey]
            MainFrame:RefreshMessageList()
        end

        toggleBtn:SetScript("OnClick", toggleExpand)
        toggleBtn:SetScript("OnEnter", function()
            toggleText:SetTextColor(1, 1, 1, 1)
        end)
        toggleBtn:SetScript("OnLeave", function()
            toggleText:SetTextColor(0.6, 0.6, 0.6, 1)
        end)

        -- Index number (keybind slot) - also serves as drag handle
        local dragHandle = CreateFrame("Button", nil, row)
        dragHandle:SetSize(24, MESSAGE_ROW_HEIGHT)
        dragHandle:SetPoint("LEFT", 24, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetMovable(false)  -- The handle itself doesn't move

        local indexLabel = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        indexLabel:SetPoint("CENTER")
        indexLabel:SetText("[" .. i .. "]")
        indexLabel:SetTextColor(0.4, 0.4, 0.4, 1)

        -- Store row position for drop targeting
        local msgIndex = i
        local rowY = yOffset
        rowPositions[i] = { y = yOffset, height = rowHeight }

        dragHandle:SetScript("OnEnter", function()
            indexLabel:SetTextColor(unpack(COLORS.accent))
            SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
        end)
        dragHandle:SetScript("OnLeave", function()
            if not dragState.isDragging then
                indexLabel:SetTextColor(0.4, 0.38, 0.35, 1)
                SetCursor(nil)
            end
        end)

        dragHandle:SetScript("OnDragStart", function()
            dragState.isDragging = true
            dragState.sourceIndex = msgIndex
            dragState.sourceRow = row
            dragState.targetFolder = nil
            row:SetAlpha(0.5)  -- Dim the dragged row

            -- Show indicator
            dragState.indicator:SetPoint("TOPLEFT", 0, -rowY)
            dragState.indicator:SetPoint("RIGHT", 0, 0)
            dragState.indicator:Show()
        end)

        dragHandle:SetScript("OnDragStop", function()
            if dragState.isDragging then
                if dragState.targetFolder then
                    -- Move to different folder
                    MainFrame:MoveMessageToFolder(dragState.sourceIndex, dragState.targetFolder)
                elseif dragState.targetIndex then
                    -- Reorder within folder
                    MoveMessage(dragState.sourceIndex, dragState.targetIndex)
                end
            end

            -- Reset state
            dragState.isDragging = false
            dragState.sourceIndex = nil
            dragState.targetIndex = nil
            dragState.targetFolder = nil
            dragState.sourceRow = nil
            dragState.indicator:Hide()
            row:SetAlpha(1)
            SetCursor(nil)

            -- Clear folder highlights
            MainFrame:ClearFolderHighlights()
        end)

        -- Track mouse position during drag to update indicator
        row:SetScript("OnUpdate", function(self)
            if not dragState.isDragging then return end
            if dragState.sourceIndex == msgIndex then return end  -- Skip source row

            -- Check if mouse is over this row
            if self:IsMouseOver() then
                local _, mouseY = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                mouseY = mouseY / scale

                local top = self:GetTop()
                local midpoint = top - (MESSAGE_ROW_HEIGHT / 2)

                -- Determine if dropping above or below this row
                if mouseY > midpoint then
                    -- Drop above this row
                    dragState.targetIndex = msgIndex
                    dragState.indicator:ClearAllPoints()
                    dragState.indicator:SetPoint("TOPLEFT", 0, -rowY)
                    dragState.indicator:SetPoint("RIGHT", 0, 0)
                else
                    -- Drop below this row
                    dragState.targetIndex = msgIndex + 1
                    dragState.indicator:ClearAllPoints()
                    dragState.indicator:SetPoint("TOPLEFT", 0, -(rowY + rowHeight))
                    dragState.indicator:SetPoint("RIGHT", 0, 0)
                end
            end
        end)

        -- Message name (clickable to expand)
        local nameBtn = CreateFrame("Button", nil, row)
        nameBtn:SetPoint("LEFT", 50, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        nameBtn:SetSize(contentWidth - 220, MESSAGE_ROW_HEIGHT)

        local nameLabel = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("LEFT", 0, 0)
        nameLabel:SetText(msg.name or "Unnamed")
        nameLabel:SetWidth(contentWidth - 220)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetWordWrap(false)
        nameLabel:SetTextColor(unpack(COLORS.accent))  -- Gold accent for message names

        nameBtn:SetScript("OnClick", toggleExpand)
        nameBtn:SetScript("OnEnter", function()
            nameLabel:SetTextColor(unpack(COLORS.accentBright))  -- Bright on hover
        end)
        nameBtn:SetScript("OnLeave", function()
            nameLabel:SetTextColor(unpack(COLORS.accent))  -- Back to accent
        end)

        -- Chat type indicator - label and color based on type
        local chatLabel, chatColor
        if msg.chatType == "RAID_WARNING" then
            chatLabel = "RW"
            chatColor = { 0.8, 0.2, 0.2, 1 }  -- Red
        elseif msg.chatType == "PARTY" then
            chatLabel = "P"
            chatColor = { 0.2, 0.4, 0.8, 1 }  -- Blue
        else  -- RAID
            chatLabel = "R"
            chatColor = { 0.8, 0.5, 0.1, 1 }  -- Orange
        end

        local chatTypeBtn = Widgets:CreateButton(row, chatLabel, 28, 18)
        chatTypeBtn:SetPoint("RIGHT", -140, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        chatTypeBtn:SetBackdropColor(unpack(chatColor))

        chatTypeBtn:SetScript("OnClick", function()
            -- Cycle: RAID_WARNING -> RAID -> PARTY -> RAID_WARNING
            if msg.chatType == "RAID_WARNING" then
                msg.chatType = "RAID"
            elseif msg.chatType == "RAID" then
                msg.chatType = "PARTY"
            else
                msg.chatType = "RAID_WARNING"
            end
            MainFrame:RefreshMessageList()
        end)

        -- Copy/Duplicate button
        local copyBtn = Widgets:CreateButton(row, "Copy", 36, 18)
        copyBtn:SetPoint("RIGHT", -98, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        copyBtn:SetBackdropColor(0.3, 0.3, 0.5, 1)
        copyBtn:SetScript("OnClick", function()
            MainFrame:DuplicateMessage(msgIndex)
        end)
        copyBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Duplicate Message", 1, 1, 1)
            GameTooltip:AddLine("Creates a copy in this folder.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Drag the [#] handle to move to another folder.", 0.5, 0.8, 0.5)
            GameTooltip:Show()
        end)
        copyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Edit button
        local editBtn = Widgets:CreateButton(row, "Edit", 36, 18)
        editBtn:SetPoint("RIGHT", -56, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        editBtn:SetScript("OnClick", function()
            MainFrame:ShowEditMessageDialog(msgIndex)
        end)

        -- Send button - success green
        local sendBtn = Widgets:CreateButton(row, "Send", 44, 18)
        sendBtn:SetPoint("RIGHT", -6, isExpanded and (PREVIEW_HEIGHT/2 + 2) or 0)
        sendBtn:SetBackdropColor(0.25, 0.5, 0.25, 1)
        sendBtn:SetScript("OnClick", function()
            local chatType = RCH:GetChatType(msg.chatType)
            RCH.TemplateEngine:Send(msg.text, chatType)
        end)

        -- Preview area (if expanded)
        if isExpanded then
            local previewBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
            previewBg:SetPoint("TOPLEFT", 26, -MESSAGE_ROW_HEIGHT)
            previewBg:SetPoint("RIGHT", -6, 0)
            previewBg:SetHeight(PREVIEW_HEIGHT)
            previewBg:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            previewBg:SetBackdropColor(unpack(COLORS.previewBg))
            previewBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

            local previewText = previewBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            previewText:SetPoint("TOPLEFT", 8, -6)
            previewText:SetPoint("BOTTOMRIGHT", -8, 6)
            previewText:SetJustifyH("LEFT")
            previewText:SetJustifyV("TOP")
            previewText:SetWordWrap(true)

            -- Truncate long messages for preview
            local previewContent = msg.text or ""
            if #previewContent > 200 then
                previewContent = previewContent:sub(1, 200) .. "..."
            end
            previewText:SetText(previewContent)
            previewText:SetTextColor(0.8, 0.8, 0.8, 1)
        end

        -- Hover highlight
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLORS.rowHover))
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)

        table.insert(frame.messageItems, row)
        yOffset = yOffset + rowHeight + 2
    end

    content:SetHeight(math.max(yOffset, 100))
end

-- Duplicate a message in the current folder
function MainFrame:DuplicateMessage(msgIndex)
    local db = RCH.db
    local folder = db.folders[db.activeFolder]
    if not folder or not folder.messages or not folder.messages[msgIndex] then
        return
    end

    local original = folder.messages[msgIndex]
    local copy = {
        name = original.name .. " (copy)",
        text = original.text,
        chatType = original.chatType,
    }

    -- Insert copy right after the original
    table.insert(folder.messages, msgIndex + 1, copy)

    RCH.Print("Duplicated: " .. original.name)
    self:RefreshMessageList()
end

-- Move a message to a different folder
function MainFrame:MoveMessageToFolder(msgIndex, targetFolderName)
    local db = RCH.db
    local sourceFolder = db.folders[db.activeFolder]
    local targetFolder = db.folders[targetFolderName]

    if not sourceFolder or not targetFolder then return end
    if not sourceFolder.messages or not sourceFolder.messages[msgIndex] then return end
    if db.activeFolder == targetFolderName then return end  -- Same folder, no move needed

    -- Copy the message
    local msg = sourceFolder.messages[msgIndex]
    local msgCopy = {
        name = msg.name,
        text = msg.text,
        chatType = msg.chatType,
    }

    -- Add to target folder
    targetFolder.messages = targetFolder.messages or {}
    table.insert(targetFolder.messages, msgCopy)

    -- Remove from source folder
    table.remove(sourceFolder.messages, msgIndex)

    RCH.Print("Moved \"" .. msg.name .. "\" to " .. targetFolderName)
    self:RefreshMessageList()
end

-- Show edit message dialog
function MainFrame:ShowEditMessageDialog(msgIndex)
    local db = RCH.db
    local folder = db.folders[db.activeFolder]
    if not folder then return end

    -- Close any existing dialog first
    if _G["RCHEditMessageDialog"] then
        _G["RCHEditMessageDialog"]:Hide()
        _G["RCHEditMessageDialog"]:SetParent(nil)
        _G["RCHEditMessageDialog"] = nil
    end

    local isNew = (msgIndex == nil)
    local msg = isNew and { name = "", text = "", chatType = "RAID_WARNING" } or folder.messages[msgIndex]

    -- Create dialog
    local dialog = Widgets:CreateBackdropFrame(UIParent, "RCHEditMessageDialog")
    dialog:SetSize(520, 420)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, dialog)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() dialog:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)

    -- ESC key to close dialog
    dialog:SetPropagateKeyboardInput(true)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            self:SetParent(nil)
            _G["RCHEditMessageDialog"] = nil
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(isNew and "Add Message" or "Edit Message")
    title:SetTextColor(unpack(COLORS.accent))

    -- Name field
    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 20, -50)
    nameLabel:SetText("Name:")

    local nameEdit = Widgets:CreateEditBox(dialog, 460, 26)
    nameEdit:SetPoint("TOPLEFT", 20, -70)
    nameEdit:SetText(msg.name)

    -- Message field
    local msgLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOPLEFT", 20, -108)
    msgLabel:SetText("Message (placeholders: {G1}-{G8}, {TANKS}, {HEALERS}, {skull}, etc.):")

    local msgEdit = Widgets:CreateMultiLineEditBox(dialog, 480, 160)
    msgEdit:SetPoint("TOPLEFT", 20, -128)
    msgEdit:SetText(msg.text)

    -- Chat type dropdown
    local chatLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chatLabel:SetPoint("TOPLEFT", 20, -305)
    chatLabel:SetText("Chat Type:")

    local chatDropdown = Widgets:CreateDropdown(dialog, 150)
    chatDropdown:SetPoint("LEFT", chatLabel, "RIGHT", 10, 0)
    chatDropdown:SetFrameLevel(105)
    chatDropdown:SetOptions({
        { label = "Raid Warning", value = "RAID_WARNING" },
        { label = "Raid", value = "RAID" },
        { label = "Party", value = "PARTY" },
    })
    chatDropdown:SetValue(msg.chatType)

    -- Save button - success green
    local saveBtn = Widgets:CreateButton(dialog, "Save", 80, 28)
    saveBtn:SetPoint("BOTTOMRIGHT", -100, 20)
    saveBtn:SetBackdropColor(0.25, 0.5, 0.25, 1)
    saveBtn:SetScript("OnClick", function()
        local newName = nameEdit:GetText()
        local newText = msgEdit:GetText()
        local newChatType = chatDropdown:GetValue()

        if newName == "" then
            RCH:Print("Message name cannot be empty")
            return
        end

        if isNew then
            table.insert(folder.messages, {
                name = newName,
                text = newText,
                chatType = newChatType,
            })
        else
            msg.name = newName
            msg.text = newText
            msg.chatType = newChatType
        end

        dialog:Hide()
        dialog:SetParent(nil)
        MainFrame:RefreshMessageList()
    end)

    -- Cancel button
    local cancelBtn = Widgets:CreateButton(dialog, "Cancel", 80, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", -15, 20)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
        dialog:SetParent(nil)
    end)

    -- Delete button (only for existing messages) - danger red
    if not isNew then
        local deleteBtn = Widgets:CreateButton(dialog, "Delete", 80, 28)
        deleteBtn:SetPoint("BOTTOMLEFT", 15, 20)
        deleteBtn:SetBackdropColor(0.55, 0.2, 0.18, 1)
        deleteBtn:SetScript("OnClick", function()
            table.remove(folder.messages, msgIndex)
            dialog:Hide()
            dialog:SetParent(nil)
            MainFrame:RefreshMessageList()
        end)
    end
end

-- Show add folder dialog
function MainFrame:ShowAddFolderDialog()
    local db = RCH.db

    -- Close any existing dialog first
    if _G["RCHAddFolderDialog"] then
        _G["RCHAddFolderDialog"]:Hide()
        _G["RCHAddFolderDialog"]:SetParent(nil)
        _G["RCHAddFolderDialog"] = nil
    end

    local dialog = Widgets:CreateBackdropFrame(UIParent, "RCHAddFolderDialog")
    dialog:SetSize(300, 130)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, dialog)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() dialog:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)

    -- ESC key to close dialog
    dialog:SetPropagateKeyboardInput(true)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            self:SetParent(nil)
            _G["RCHAddFolderDialog"] = nil
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Add Folder")
    title:SetTextColor(unpack(COLORS.accent))

    local nameEdit = Widgets:CreateEditBox(dialog, 260, 26)
    nameEdit:SetPoint("TOP", 0, -50)
    nameEdit:SetText("")

    local saveBtn = Widgets:CreateButton(dialog, "Create", 80, 26)
    saveBtn:SetPoint("BOTTOMRIGHT", -90, 15)
    saveBtn:SetBackdropColor(0.25, 0.5, 0.25, 1)
    saveBtn:SetScript("OnClick", function()
        local name = nameEdit:GetText()
        if name == "" then
            RCH:Print("Folder name cannot be empty")
            return
        end
        if db.folders[name] then
            RCH:Print("Folder already exists: " .. name)
            return
        end

        local maxOrder = 0
        for _, f in pairs(db.folders) do
            if f.order and f.order > maxOrder then
                maxOrder = f.order
            end
        end

        db.folders[name] = {
            order = maxOrder + 1,
            messages = {},
        }

        dialog:Hide()
        dialog:SetParent(nil)
        MainFrame:RefreshFolderList()
    end)

    local cancelBtn = Widgets:CreateButton(dialog, "Cancel", 80, 26)
    cancelBtn:SetPoint("BOTTOMRIGHT", -5, 15)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
        dialog:SetParent(nil)
    end)
end

-- Show folder context menu
function MainFrame:ShowFolderContextMenu(folderName)
    local db = RCH.db

    local menu = Widgets:CreateBackdropFrame(UIParent)
    menu:SetSize(120, 60)
    menu:SetPoint("CENTER")
    menu:SetFrameStrata("TOOLTIP")
    menu:EnableMouse(true)

    local renameBtn = Widgets:CreateListItem(menu, 24)
    renameBtn:SetPoint("TOPLEFT", 4, -4)
    renameBtn:SetPoint("RIGHT", -4, 0)
    renameBtn:SetLabel("Rename")
    renameBtn:SetScript("OnClick", function()
        menu:Hide()
        RCH:Print("Rename not implemented yet. Delete and recreate folder.")
    end)

    local deleteBtn = Widgets:CreateListItem(menu, 24)
    deleteBtn:SetPoint("TOPLEFT", 4, -28)
    deleteBtn:SetPoint("RIGHT", -4, 0)
    deleteBtn:SetLabel("Delete")
    deleteBtn.text:SetTextColor(1, 0.3, 0.3, 1)
    deleteBtn:SetScript("OnClick", function()
        menu:Hide()
        db.folders[folderName] = nil
        if db.activeFolder == folderName then
            for name, _ in pairs(db.folders) do
                db.activeFolder = name
                break
            end
        end
        MainFrame:RefreshFolderList()
        MainFrame:RefreshMessageList()
    end)

    C_Timer.After(0.1, function()
        local closeFrame = CreateFrame("Frame", nil, UIParent)
        closeFrame:SetAllPoints()
        closeFrame:SetFrameStrata("DIALOG")
        closeFrame:EnableMouse(true)
        closeFrame:SetScript("OnMouseDown", function()
            menu:Hide()
            menu:SetParent(nil)
            closeFrame:Hide()
            closeFrame:SetParent(nil)
        end)
        menu:SetFrameStrata("TOOLTIP")
    end)
end

-- Switch to a specific tab
function MainFrame:SwitchTab(tabId)
    local frame = self.frame
    if not frame then return end

    activeTab = tabId
    frame.commsTab:SetActive(tabId == "COMMS")
    frame.versTab:SetActive(tabId == "VERS")
    frame.summonTab:SetActive(tabId == "SUMMON")

    if tabId == "COMMS" then
        frame.commsContent:Show()
        frame.versContent:Hide()
        frame.summonContent:Hide()
        if RCH.VersPanel then RCH.VersPanel:Hide() end
        if RCH.SummonPanel then RCH.SummonPanel:Hide() end
    elseif tabId == "VERS" then
        frame.commsContent:Hide()
        frame.versContent:Show()
        frame.summonContent:Hide()
        frame.versPlaceholder:Hide()
        if RCH.VersPanel then RCH.VersPanel:Show() end
        if RCH.SummonPanel then RCH.SummonPanel:Hide() end
    elseif tabId == "SUMMON" then
        frame.commsContent:Hide()
        frame.versContent:Hide()
        frame.summonContent:Show()
        frame.summonPlaceholder:Hide()
        if RCH.VersPanel then RCH.VersPanel:Hide() end
        if RCH.SummonPanel then RCH.SummonPanel:Show() end
    end
end

-- Load messages from DefaultMessages.lua file
function MainFrame:LoadFromFile()
    if not RCH_DefaultMessages or not next(RCH_DefaultMessages) then
        RCH:Print("No messages found in DefaultMessages.lua")
        return
    end

    local db = RCH.db
    local importCount = 0
    local folderCount = 0

    -- Overwrite folders from file
    for folderName, folderData in pairs(RCH_DefaultMessages) do
        db.folders[folderName] = {
            order = folderData.order or 99,
            messages = {},
        }
        if folderData.messages then
            for _, msg in ipairs(folderData.messages) do
                table.insert(db.folders[folderName].messages, {
                    name = msg.name or "Unnamed",
                    text = msg.text or "",
                    chatType = msg.chatType or "RAID_WARNING",
                })
                importCount = importCount + 1
            end
        end
        folderCount = folderCount + 1
    end

    -- Ensure active folder exists
    if not db.folders[db.activeFolder] then
        for name, _ in pairs(db.folders) do
            db.activeFolder = name
            break
        end
    end

    RCH:Print("Loaded " .. importCount .. " messages in " .. folderCount .. " folders from file")
    self:RefreshFolderList()
    self:RefreshMessageList()
end

-- Export current messages to external format (shows in a copyable dialog)
function MainFrame:ExportToExternal()
    local db = RCH.db

    -- Build the export string
    local lines = {}
    table.insert(lines, "RCH_ExternalMessages = {")

    -- Sort folders by order
    local sortedFolders = {}
    for name, data in pairs(db.folders) do
        table.insert(sortedFolders, { name = name, data = data })
    end
    table.sort(sortedFolders, function(a, b)
        return (a.data.order or 99) < (b.data.order or 99)
    end)

    for _, folder in ipairs(sortedFolders) do
        local folderName = folder.name
        local folderData = folder.data

        table.insert(lines, '    ["' .. folderName .. '"] = {')
        table.insert(lines, '        order = ' .. (folderData.order or 99) .. ',')
        table.insert(lines, '        messages = {')

        if folderData.messages then
            for _, msg in ipairs(folderData.messages) do
                -- Escape quotes and newlines in text
                local escapedText = (msg.text or ""):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
                local line = '            { name = "' .. (msg.name or "") .. '", text = "' .. escapedText .. '", chatType = "' .. (msg.chatType or "RAID_WARNING") .. '" },'
                table.insert(lines, line)
            end
        end

        table.insert(lines, '        },')
        table.insert(lines, '    },')
    end

    table.insert(lines, "}")

    local exportText = table.concat(lines, "\n")

    -- Show in a dialog with copyable text
    MainFrame:ShowExportDialog(exportText)
end

-- Show export dialog with copyable text
function MainFrame:ShowExportDialog(text)
    -- Close any existing dialog
    if _G["RCHExportDialog"] then
        _G["RCHExportDialog"]:Hide()
        _G["RCHExportDialog"]:SetParent(nil)
        _G["RCHExportDialog"] = nil
    end

    local dialog = Widgets:CreateBackdropFrame(UIParent, "RCHExportDialog")
    dialog:SetSize(600, 450)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, dialog)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() dialog:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)

    -- ESC key to close dialog
    dialog:SetPropagateKeyboardInput(true)
    dialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            self:SetParent(nil)
            _G["RCHExportDialog"] = nil
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Export - Copy to DefaultMessages.lua")
    title:SetTextColor(unpack(COLORS.accent))

    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -4)
    instructions:SetText("Select all (Ctrl+A), copy (Ctrl+C), paste into your file")
    instructions:SetTextColor(0.6, 0.6, 0.6, 1)

    local editBoxContainer = Widgets:CreateMultiLineEditBox(dialog, 560, 350)
    editBoxContainer:SetPoint("TOP", 0, -55)
    editBoxContainer:SetText(text)
    editBoxContainer.editBox:HighlightText()
    editBoxContainer.editBox:SetFocus()

    local closeBtn = Widgets:CreateButton(dialog, "Close", 80, 28)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetScript("OnClick", function()
        dialog:Hide()
        dialog:SetParent(nil)
    end)
end

-- Initialize the main frame
function MainFrame:Initialize()
    self.frame = CreateMainFrame()

    self.frame:SetScript("OnShow", function()
        MainFrame:RefreshFolderList()
        MainFrame:RefreshMessageList()
    end)
end

-- Show/Hide/Toggle functions
function MainFrame:Show()
    if not self.frame then
        self:Initialize()
    end
    self.frame:Show()
end

function MainFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MainFrame:Toggle()
    if not self.frame then
        self:Initialize()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function MainFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

-- Get the vers content frame for VersPanel to populate
function MainFrame:GetVersContent()
    if self.frame then
        return self.frame.versContent
    end
    return nil
end

-- Get the summon content frame for SummonPanel to populate
function MainFrame:GetSummonContent()
    if self.frame then
        return self.frame.summonContent
    end
    return nil
end

-- Attach to addon namespace
RCH.MainFrame = MainFrame

-- Initialize on load
C_Timer.After(0, function()
    MainFrame:Initialize()
end)
