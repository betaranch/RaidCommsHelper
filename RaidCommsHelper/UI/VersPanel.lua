-- RaidCommsHelper Vers Panel
-- Interactive group management with vers tracking

local RCH = RaidCommsHelper
RCH.VersPanel = RCH.VersPanel or {}

local VersPanel = RCH.VersPanel
local Widgets = RCH.Widgets
local VersCache = RCH.VersCache
local GroupUtils = RCH.GroupUtils

-- Panel state
local panelFrame = nil
local groupRows = {}        -- Group row widgets (1-6)
local rankItems = {}        -- Vers ranking list items
local selectedPlayer = nil  -- Currently selected player data
local selectedSlot = nil    -- Currently selected slot widget
local NUM_GROUPS = 6        -- Max groups to show
local selectedSortMode = "even"  -- Current sort algorithm

-- Colors
local COLORS = Widgets.COLORS

-- Event frame for roster updates
local eventFrame = CreateFrame("Frame")
local pendingRefresh = false

-- ============================================================================
-- EVENT HANDLING - Auto-refresh on roster changes
-- ============================================================================

eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Debounce: only refresh once if multiple events fire quickly
        if not pendingRefresh and panelFrame and panelFrame:IsShown() then
            pendingRefresh = true
            C_Timer.After(0.1, function()
                pendingRefresh = false
                VersPanel:RefreshGroups()
                VersPanel:RefreshRanking()
                VersPanel:UpdateStats()
            end)
        end
    end
end)

-- ============================================================================
-- SELECTION AND MOVEMENT
-- ============================================================================

-- Clear current selection
local function ClearSelection()
    if selectedSlot then
        selectedSlot:SetSelected(false)
    end
    selectedPlayer = nil
    selectedSlot = nil

    -- Also clear any rank item selections
    for _, item in ipairs(rankItems) do
        if item.SetSelected then
            item:SetSelected(false)
        end
    end

    -- Update status
    if panelFrame and panelFrame.statusText then
        panelFrame.statusText:SetText("Click a player to select, then click a group to move them")
    end
end

-- Select a player
local function SelectPlayer(playerData, slotWidget)
    -- If clicking same player, deselect
    if selectedPlayer and selectedPlayer.name == playerData.name then
        ClearSelection()
        return
    end

    -- Clear previous selection
    ClearSelection()

    -- Set new selection
    selectedPlayer = playerData
    selectedSlot = slotWidget

    if slotWidget and slotWidget.SetSelected then
        slotWidget:SetSelected(true)
    end

    -- Update status
    if panelFrame and panelFrame.statusText then
        panelFrame.statusText:SetText(string.format(
            "Selected: %s (G%d, %.0f%% vers) - Click group to move",
            playerData.name,
            playerData.group or 0,
            playerData.vers or 0
        ))
    end
end

-- Move selected player to a group
local function MovePlayerToGroup(targetGroup)
    if not selectedPlayer then
        RCH.Print("No player selected")
        return
    end

    -- Check permissions
    if not GroupUtils:CanModifyGroups() then
        RCH.Print("You must be raid leader or assistant to move players")
        return
    end

    -- Check combat lockdown
    if InCombatLockdown() then
        RCH.Print("Cannot move players during combat")
        return
    end

    -- Check if already in target group
    if selectedPlayer.group == targetGroup then
        RCH.Print(selectedPlayer.name .. " is already in Group " .. targetGroup)
        ClearSelection()
        return
    end

    -- Check if target group is full (5 max)
    local roster = GroupUtils:GetRosterByGroup()
    if roster[targetGroup] and #roster[targetGroup] >= 5 then
        RCH.Print("Group " .. targetGroup .. " is full (5 players max)")
        return
    end

    -- Perform the move
    local playerIndex = selectedPlayer.index
    if playerIndex then
        SetRaidSubgroup(playerIndex, targetGroup)
        RCH.Print("Moved " .. selectedPlayer.name .. " to Group " .. targetGroup)

        -- Clear selection immediately
        ClearSelection()

        -- Force immediate refresh (GROUP_ROSTER_UPDATE will also fire)
        C_Timer.After(0.05, function()
            VersPanel:RefreshGroups()
            VersPanel:RefreshRanking()
        end)
    else
        RCH.Print("Error: Could not find player index")
    end
end

-- Swap two players between groups
local function SwapPlayers(player1, player2)
    if not player1 or not player2 then return end

    -- Check permissions
    if not GroupUtils:CanModifyGroups() then
        RCH.Print("You must be raid leader or assistant to swap players")
        return
    end

    -- Check combat lockdown
    if InCombatLockdown() then
        RCH.Print("Cannot swap players during combat")
        return
    end

    -- If same group, can't swap (WoW doesn't support reordering within group)
    if player1.group == player2.group then
        RCH.Print("Cannot reorder within the same group")
        ClearSelection()
        return
    end

    -- Perform the swap
    if player1.index and player2.index then
        SwapRaidSubgroup(player1.index, player2.index)
        RCH.Print("Swapped " .. player1.name .. " and " .. player2.name)

        -- Clear selection
        ClearSelection()

        -- Force refresh
        C_Timer.After(0.05, function()
            VersPanel:RefreshGroups()
            VersPanel:RefreshRanking()
        end)
    else
        RCH.Print("Error: Could not find player indices")
    end
end

-- ============================================================================
-- PANEL CREATION
-- ============================================================================

function VersPanel:Create(parent)
    if panelFrame then return panelFrame end

    panelFrame = CreateFrame("Frame", nil, parent)
    panelFrame:SetAllPoints()
    panelFrame:Hide()

    -- ========================================================================
    -- HEADER SECTION - Compact stats row
    -- ========================================================================
    local header = CreateFrame("Frame", nil, panelFrame)
    header:SetPoint("TOPLEFT", 10, -8)
    header:SetPoint("TOPRIGHT", -10, -8)
    header:SetHeight(24)

    -- Raid stats (left side): "20 players | T:2 H:4 D:14 | 285% avg | 18/20 scanned"
    panelFrame.statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panelFrame.statsText:SetPoint("LEFT", 0, 0)
    panelFrame.statsText:SetJustifyH("LEFT")
    panelFrame.statsText:SetTextColor(0.8, 0.8, 0.8, 1)
    panelFrame.statsText:SetText("")

    -- Scan buttons (right side of header)
    local scanMissingBtn = Widgets:CreateButton(header, "Scan Missing", 85, 22)
    scanMissingBtn:SetPoint("RIGHT", 0, 0)
    scanMissingBtn:SetScript("OnClick", function()
        VersPanel:StartScan(true)
    end)
    panelFrame.scanMissingBtn = scanMissingBtn

    local scanBtn = Widgets:CreateButton(header, "Scan All", 65, 22)
    scanBtn:SetPoint("RIGHT", scanMissingBtn, "LEFT", -5, 0)
    scanBtn:SetScript("OnClick", function()
        VersPanel:StartScan(false)
    end)
    panelFrame.scanBtn = scanBtn

    -- ========================================================================
    -- GROUP STATS ROW - Shows group averages above the grid
    -- ========================================================================
    local groupStatsRow = CreateFrame("Frame", nil, panelFrame)
    groupStatsRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    groupStatsRow:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    groupStatsRow:SetHeight(18)

    panelFrame.groupStatsText = groupStatsRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelFrame.groupStatsText:SetPoint("LEFT", 0, 0)
    panelFrame.groupStatsText:SetJustifyH("LEFT")
    panelFrame.groupStatsText:SetTextColor(0.6, 0.6, 0.6, 1)
    panelFrame.groupStatsText:SetText("")

    -- ========================================================================
    -- MAIN CONTENT - SPLIT VIEW
    -- ========================================================================
    local contentFrame = CreateFrame("Frame", nil, panelFrame)
    contentFrame:SetPoint("TOPLEFT", groupStatsRow, "BOTTOMLEFT", 0, -4)
    contentFrame:SetPoint("BOTTOMRIGHT", -10, 85)  -- Leave room for bottom panel

    -- Left Panel: Group Management (6 rows)
    local groupPanel = Widgets:CreateBackdropFrame(contentFrame, "RCHGroupPanel")
    groupPanel:SetPoint("TOPLEFT", 0, 0)
    groupPanel:SetPoint("BOTTOMLEFT", 0, 0)
    groupPanel:SetWidth(480)
    groupPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)

    -- Create 6 group rows (no title, starts immediately)
    groupRows = {}
    local rowStartY = -5
    local rowSpacing = 27

    for g = 1, NUM_GROUPS do
        local row = Widgets:CreateGroupRow(groupPanel, g, 85, 22)
        row:SetPoint("TOPLEFT", 5, rowStartY - (g - 1) * rowSpacing)
        groupRows[g] = row

        -- Wire up click handlers for each slot
        for i, slot in ipairs(row.slots) do
            slot:SetScript("OnClick", function(self)
                if self.playerData then
                    -- If we have someone selected and click another player, swap them
                    if selectedPlayer and selectedPlayer.name ~= self.playerData.name then
                        SwapPlayers(selectedPlayer, self.playerData)
                    else
                        -- Otherwise, select/deselect this player
                        SelectPlayer(self.playerData, self)
                    end
                elseif selectedPlayer then
                    -- Clicking empty slot moves player there
                    MovePlayerToGroup(g)
                end
            end)
        end

        -- Wire up group label click (move to this group)
        row.labelBtn:SetScript("OnClick", function()
            if selectedPlayer then
                MovePlayerToGroup(g)
            end
        end)
    end

    panelFrame.groupPanel = groupPanel

    -- Right Panel: Vers Ranking
    local rankPanel = Widgets:CreateBackdropFrame(contentFrame, "RCHRankPanel")
    rankPanel:SetPoint("TOPLEFT", groupPanel, "TOPRIGHT", 8, 0)
    rankPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    rankPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)

    -- Compact header: "BY VERS" on left, raid avg on right
    local rankTitle = rankPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankTitle:SetPoint("TOPLEFT", 8, -6)
    rankTitle:SetText("BY VERS")
    rankTitle:SetTextColor(unpack(COLORS.textDim))

    panelFrame.rankAvgText = rankPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelFrame.rankAvgText:SetPoint("TOPRIGHT", -8, -6)
    panelFrame.rankAvgText:SetTextColor(1, 0.82, 0)

    -- Scroll frame for ranking list
    local rankScroll, rankContent = Widgets:CreateScrollFrame(rankPanel, "RCHRankScroll")
    rankScroll:SetPoint("TOPLEFT", 4, -22)
    rankScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    rankContent:SetWidth(rankScroll:GetWidth() - 5)
    panelFrame.rankContent = rankContent
    panelFrame.rankScroll = rankScroll
    panelFrame.rankPanel = rankPanel

    -- ========================================================================
    -- BOTTOM PANEL - Sort Controls
    -- ========================================================================
    local bottomPanel = Widgets:CreateBackdropFrame(panelFrame, "RCHBottomPanel")
    bottomPanel:SetPoint("BOTTOMLEFT", 10, 10)
    bottomPanel:SetPoint("BOTTOMRIGHT", -10, 10)
    bottomPanel:SetHeight(70)
    bottomPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)

    -- Left side: Status text
    panelFrame.statusText = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelFrame.statusText:SetPoint("TOPLEFT", 10, -8)
    panelFrame.statusText:SetJustifyH("LEFT")
    panelFrame.statusText:SetTextColor(unpack(COLORS.textDim))
    panelFrame.statusText:SetText("Click player to select, click group to move")

    -- Warning count (below status)
    panelFrame.warningText = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelFrame.warningText:SetPoint("TOPLEFT", panelFrame.statusText, "BOTTOMLEFT", 0, -2)
    panelFrame.warningText:SetTextColor(1, 0.5, 0, 1)
    panelFrame.warningText:Hide()

    -- Right side: Sort controls
    local sortLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("TOPRIGHT", -10, -8)
    sortLabel:SetText("Auto-Sort Algorithm:")
    sortLabel:SetTextColor(unpack(COLORS.textDim))

    -- Apply Sort button (right side)
    local applyBtn = Widgets:CreateButton(bottomPanel, "Apply", 70, 26)
    applyBtn:SetPoint("TOPRIGHT", -10, -24)
    applyBtn:SetScript("OnClick", function()
        VersPanel:ApplyAutoSort()
    end)
    panelFrame.applyBtn = applyBtn

    -- Algorithm dropdown (left of button)
    local sortDropdown = Widgets:CreateDropdown(bottomPanel, 160)
    sortDropdown:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)
    sortDropdown:SetOptions({
        { label = "Even Distribution", value = "even" },
        { label = "High Vers: G3+G4", value = "high_g3g4" },
        { label = "High Vers: G4 Only", value = "high_g4" },
    })
    sortDropdown:SetValue(selectedSortMode)
    sortDropdown.OnValueChanged = function(self, value)
        selectedSortMode = value
    end
    panelFrame.sortDropdown = sortDropdown

    return panelFrame
end

-- ============================================================================
-- DATA REFRESH
-- ============================================================================

-- Role sort priority (lower = first)
local ROLE_PRIORITY = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

-- Sort players within a group by role, then by vers
local function SortGroupPlayers(players)
    table.sort(players, function(a, b)
        local roleA = ROLE_PRIORITY[a.role] or 4
        local roleB = ROLE_PRIORITY[b.role] or 4
        if roleA ~= roleB then
            return roleA < roleB
        end
        -- Same role: sort by vers descending
        return (a.vers or 0) > (b.vers or 0)
    end)
    return players
end

-- Refresh group display with current roster
function VersPanel:RefreshGroups()
    if not panelFrame or not panelFrame:IsShown() then return end

    local roster = GroupUtils:GetRosterByGroup()

    for g = 1, NUM_GROUPS do
        local row = groupRows[g]
        if row then
            local groupPlayers = roster[g] or {}

            -- Add vers data to each player
            for _, player in ipairs(groupPlayers) do
                local vers, scanned = VersCache:GetVers(player.name)
                player.vers = vers
                player.versScanned = scanned
            end

            -- Sort by role, then vers within each group
            SortGroupPlayers(groupPlayers)

            row:SetPlayers(groupPlayers)
        end
    end
end

-- Refresh vers ranking list
function VersPanel:RefreshRanking()
    if not panelFrame or not panelFrame:IsShown() then return end

    local content = panelFrame.rankContent

    -- Clear existing items
    for _, item in ipairs(rankItems) do
        item:Hide()
        item:SetParent(nil)
    end
    rankItems = {}

    -- Hide old summary frame if it exists
    if panelFrame.summaryFrame then
        panelFrame.summaryFrame:Hide()
    end

    -- Get ALL raid members from roster, then add vers data
    local roster = GroupUtils:GetRaidRoster()
    local playersToShow = {}

    for _, player in ipairs(roster) do
        -- Get vers from cache
        local vers, scanned = VersCache:GetVers(player.name)
        table.insert(playersToShow, {
            name = player.name,
            vers = vers,
            versScanned = scanned,
            group = player.group,
            role = player.role,
            classFile = player.classFile,
            index = player.index,
        })
    end

    -- Sort by vers descending
    table.sort(playersToShow, function(a, b)
        return (a.vers or 0) > (b.vers or 0)
    end)

    -- Find max vers for bar scaling
    local maxVers = 100
    for _, p in ipairs(playersToShow) do
        if p.vers > maxVers then maxVers = p.vers end
    end
    maxVers = math.max(maxVers, 500)  -- At least scale to 500

    local yOffset = 0
    local itemHeight = 20
    local lowVersCount = 0

    for rank, playerData in ipairs(playersToShow) do
        local item = Widgets:CreateVersRankItem(content, content:GetWidth() - 10, itemHeight)
        item:SetPoint("TOPLEFT", 0, -yOffset)
        item:SetPoint("RIGHT", -5, 0)
        item:SetPlayer(rank, playerData, maxVers)

        -- Click to select
        item:SetScript("OnClick", function(self)
            if self.playerData then
                -- Find and highlight the corresponding slot in group grid
                for g = 1, NUM_GROUPS do
                    for _, slot in ipairs(groupRows[g].slots) do
                        if slot.playerData and slot.playerData.name == self.playerData.name then
                            SelectPlayer(self.playerData, slot)
                            return
                        end
                    end
                end
                -- Fallback: select without slot reference
                SelectPlayer(self.playerData, self)
            end
        end)

        table.insert(rankItems, item)
        yOffset = yOffset + itemHeight + 1

        -- Count low vers players (only if scanned)
        if playerData.versScanned and (playerData.vers or 0) < 50 then
            lowVersCount = lowVersCount + 1
        end
    end

    content:SetHeight(yOffset + 10)

    -- Update warning count
    if lowVersCount > 0 then
        panelFrame.warningText:SetText(string.format("! %d players below 50%% vers", lowVersCount))
        panelFrame.warningText:Show()
    else
        panelFrame.warningText:Hide()
    end
end

-- Update stats display
function VersPanel:UpdateStats()
    if not panelFrame then return end

    local stats = GroupUtils:GetRaidStats()
    local groupStats = GroupUtils:GetGroupStats()

    if stats.total == 0 then
        panelFrame.statsText:SetText("Not in raid")
        panelFrame.statsText:SetTextColor(0.5, 0.5, 0.5, 1)
        if panelFrame.groupStatsText then
            panelFrame.groupStatsText:SetText("")
        end
        if panelFrame.rankAvgText then
            panelFrame.rankAvgText:SetText("")
        end
        return
    end

    -- Header stats with color coding
    -- Format: "20 players  T:2  H:4  D:14  |  285% avg  |  18/20 scanned"
    -- Color scheme: higher vers = warmer (orange/red), lower vers = cooler (blue/cyan)
    -- Range is 0-999%, so use granular thresholds
    local scanColor = stats.scannedCount == stats.total and "|cff88ff88" or "|cffff8800"
    local avgColor
    if stats.avgVers >= 500 then
        avgColor = "|cffff4444"      -- Red (500%+)
    elseif stats.avgVers >= 350 then
        avgColor = "|cffff8800"      -- Orange (350-499%)
    elseif stats.avgVers >= 200 then
        avgColor = "|cffffcc00"      -- Gold (200-349%)
    elseif stats.avgVers >= 100 then
        avgColor = "|cffffff00"      -- Yellow (100-199%)
    elseif stats.avgVers >= 50 then
        avgColor = "|cff69ccf0"      -- Cyan (50-99%)
    else
        avgColor = "|cff4499ff"      -- Blue (<50%)
    end

    local text = string.format(
        "|cffffffff%d|r players   |cff69ccf0T:%d|r  |cff00ff00H:%d|r  |cffff6666D:%d|r   %s%.0f%%|r avg   %s%d/%d|r scanned",
        stats.total,
        stats.tanks,
        stats.healers,
        stats.dps,
        avgColor,
        stats.avgVers,
        scanColor,
        stats.scannedCount,
        stats.total
    )

    panelFrame.statsText:SetText(text)

    -- Group stats row with color coding based on avg vers
    -- Color scheme: higher vers = warmer (orange/red), lower vers = cooler (blue/cyan)
    if panelFrame.groupStatsText then
        local groupTexts = {}
        for g = 1, 6 do
            if groupStats[g] and groupStats[g].count > 0 then
                local avg = groupStats[g].avgVers
                local avgColor
                if avg >= 500 then
                    avgColor = "|cffff4444"      -- Red
                elseif avg >= 350 then
                    avgColor = "|cffff8800"      -- Orange
                elseif avg >= 200 then
                    avgColor = "|cffffcc00"      -- Gold
                elseif avg >= 100 then
                    avgColor = "|cffffff00"      -- Yellow
                elseif avg >= 50 then
                    avgColor = "|cff69ccf0"      -- Cyan
                else
                    avgColor = "|cff4499ff"      -- Blue
                end
                table.insert(groupTexts, string.format(
                    "|cffaaaaaa G%d:|r %d %s(%.0f%%)|r",
                    g,
                    groupStats[g].count,
                    avgColor,
                    avg
                ))
            end
        end
        panelFrame.groupStatsText:SetText(table.concat(groupTexts, "  "))
    end

    -- Right panel header avg with color (warm=high, cool=low)
    if panelFrame.rankAvgText then
        local avgColor
        if stats.avgVers >= 500 then
            avgColor = "ff4444"      -- Red
        elseif stats.avgVers >= 350 then
            avgColor = "ff8800"      -- Orange
        elseif stats.avgVers >= 200 then
            avgColor = "ffcc00"      -- Gold
        elseif stats.avgVers >= 100 then
            avgColor = "ffff00"      -- Yellow
        elseif stats.avgVers >= 50 then
            avgColor = "69ccf0"      -- Cyan
        else
            avgColor = "4499ff"      -- Blue
        end
        panelFrame.rankAvgText:SetText(string.format("|cff%sAvg: %.0f%%|r", avgColor, stats.avgVers))
    end
end

-- ============================================================================
-- ACTIONS
-- ============================================================================

-- Start scanning raid
function VersPanel:StartScan(onlyMissing)
    if VersCache:IsScanning() then
        RCH.Print("Scan already in progress...")
        return
    end

    local btn = onlyMissing and panelFrame.scanMissingBtn or panelFrame.scanBtn
    local originalLabel = onlyMissing and "Scan Missing" or "Scan All"

    btn:SetLabel("...")
    panelFrame.statusText:SetText(onlyMissing and "Scanning missing players..." or "Scanning all raid members...")

    local scanFunc = onlyMissing and VersCache.ScanMissing or VersCache.ScanRaid

    scanFunc(VersCache, function(data)
        btn:SetLabel(originalLabel)

        local missingCount = VersCache:GetMissingCount()
        if missingCount > 0 then
            panelFrame.statusText:SetText(string.format("Done - %d still missing vers data", missingCount))
        else
            panelFrame.statusText:SetText("Scan complete! Click player to select")
        end

        VersPanel:RefreshGroups()
        VersPanel:RefreshRanking()
        VersPanel:UpdateStats()
    end)
end

-- Apply auto-sort based on selected algorithm
function VersPanel:ApplyAutoSort()
    if not GroupUtils:CanModifyGroups() then
        RCH.Print("You must be raid leader or assistant to sort groups")
        return
    end

    if InCombatLockdown() then
        RCH.Print("Cannot sort groups during combat")
        return
    end

    -- Clear any selection first
    ClearSelection()

    -- Map dropdown value to sort mode
    local modeMap = {
        ["even"] = GroupUtils.SORT_MODES.EVEN_DISTRIBUTION,
        ["high_g3g4"] = GroupUtils.SORT_MODES.HIGH_VERS_G3G4,
        ["high_g4"] = GroupUtils.SORT_MODES.HIGH_VERS_G4,
    }

    -- Read directly from dropdown widget to ensure we have current value
    local dropdownValue = panelFrame.sortDropdown:GetValue() or selectedSortMode
    local mode = modeMap[dropdownValue] or GroupUtils.SORT_MODES.EVEN_DISTRIBUTION

    -- Generate and execute plan (affects groups 1-4)
    local plan = GroupUtils:GeneratePlan(mode, 4)
    GroupUtils:ExecutePlan(plan)

    panelFrame.statusText:SetText("Sort applied! Groups 1-4 reorganized")

    -- Force refresh after a delay (allow WoW to process all SetRaidSubgroup calls)
    C_Timer.After(0.15, function()
        VersPanel:RefreshGroups()
        VersPanel:RefreshRanking()
        VersPanel:UpdateStats()
    end)
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function VersPanel:Show()
    local parent = RCH.MainFrame and RCH.MainFrame:GetVersContent()
    if not parent then return end

    if not panelFrame then
        self:Create(parent)
    end

    panelFrame:Show()
    ClearSelection()

    -- Sync dropdown value with module variable
    if panelFrame.sortDropdown then
        panelFrame.sortDropdown:SetValue(selectedSortMode)
    end

    -- Always do a full refresh on show to ensure everything is initialized
    self:RefreshGroups()
    self:RefreshRanking()
    self:UpdateStats()
end

function VersPanel:Hide()
    if panelFrame then
        ClearSelection()
        panelFrame:Hide()
    end
end

function VersPanel:IsShown()
    return panelFrame and panelFrame:IsShown()
end
