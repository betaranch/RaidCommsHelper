-- RaidCommsHelper Summon Panel
-- Tracks raid members who need summons based on zone

local RCH = RaidCommsHelper
RCH.SummonPanel = RCH.SummonPanel or {}

local SummonPanel = RCH.SummonPanel
local Widgets = RCH.Widgets
local GroupUtils = RCH.GroupUtils

-- Panel state
local panelFrame = nil
local listItems = {}       -- List item widgets

-- Colors
local COLORS = Widgets.COLORS

-- ============================================================================
-- INSTANCE ZONE MAPPING
-- Some raids have multiple subzones (e.g., Trial of Valor has "Halls of Valor",
-- "The Bridge", "Helheim"). Players in different subzones should still count
-- as "present" in the same instance.
-- ============================================================================

-- Map instance IDs to all valid zone names for that instance
local INSTANCE_ZONES = {
    -- Trial of Valor (instance ID 1648) - has multiple subzones
    [1648] = {
        ["Trial of Valor"] = true,
        ["Halls of Valor"] = true,  -- First boss area (shares name with dungeon)
        ["The Bridge"] = true,
        ["Helheim"] = true,
    },
    -- Add other problematic instances here if discovered
}

-- Check if a zone name counts as "present" in the current instance
local function IsPlayerInSameInstance(playerZone, myZone, myInstanceID)
    -- If zones match exactly, they are in the same place
    if playerZone == myZone then
        return true
    end

    -- If we have a zone mapping for this instance, check if both zones are valid
    if myInstanceID and INSTANCE_ZONES[myInstanceID] then
        local validZones = INSTANCE_ZONES[myInstanceID]
        -- Both player zone and my zone must be in the valid list
        if validZones[playerZone] and validZones[myZone] then
            return true
        end
    end

    return false
end

-- Event frame for roster/zone updates
local eventFrame = CreateFrame("Frame")
local pendingRefresh = false

-- ============================================================================
-- EVENT HANDLING - Auto-refresh on roster/zone changes
-- ============================================================================

eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    -- Debounce: only refresh once if multiple events fire quickly
    if not pendingRefresh and panelFrame and panelFrame:IsShown() then
        pendingRefresh = true
        C_Timer.After(0.5, function()
            pendingRefresh = false
            SummonPanel:RefreshList()
            SummonPanel:UpdateStats()
        end)
    end
end)

-- ============================================================================
-- DATA FUNCTIONS
-- ============================================================================

-- Get players who need summons (not in current zone/instance)
function SummonPanel:GetPlayersNeedingSummon()
    if not IsInRaid() then return {}, 0, 0 end

    local myZone = GetRealZoneText()
    local needSummon = {}
    local inZoneCount = 0
    local offlineCount = 0
    local numMembers = GetNumGroupMembers()

    -- Get current instance ID for multi-subzone handling
    local myInstanceID = nil
    local inInstance = IsInInstance()
    if inInstance then
        local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        myInstanceID = instanceID
    end

    for i = 1, numMembers do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role = GetRaidRosterInfo(i)

        if name then
            -- Strip realm from name (e.g., "Player-Realm" -> "Player")
            local shortName = strsplit("-", name)

            if not online then
                offlineCount = offlineCount + 1
                -- Include offline players in the list with a flag
                table.insert(needSummon, {
                    index = i,
                    name = shortName,
                    classFile = fileName,
                    zone = zone or "Unknown",
                    online = false,
                })
            elseif not IsPlayerInSameInstance(zone, myZone, myInstanceID) then
                -- Online but not in our zone/instance
                table.insert(needSummon, {
                    index = i,
                    name = shortName,
                    classFile = fileName,
                    zone = zone or "Unknown",
                    online = true,
                })
            else
                -- In zone
                inZoneCount = inZoneCount + 1
            end
        end
    end

    -- Sort: online players first, then by name
    table.sort(needSummon, function(a, b)
        if a.online ~= b.online then
            return a.online  -- Online players first
        end
        return a.name < b.name
    end)

    return needSummon, inZoneCount, offlineCount
end

-- Post summon request to raid chat
function SummonPanel:PostSummonRequest()
    local needSummon = self:GetPlayersNeedingSummon()

    -- Filter to only online players
    local names = {}
    for _, p in ipairs(needSummon) do
        if p.online then
            table.insert(names, p.name)
        end
    end

    if #names == 0 then
        RCH.Print("No online players need summons")
        return
    end

    local msg = "Please help summon: " .. table.concat(names, ", ")
    SendChatMessage(msg, "RAID")
end

-- ============================================================================
-- PANEL CREATION
-- ============================================================================

function SummonPanel:Create(parent)
    if panelFrame then return panelFrame end

    panelFrame = CreateFrame("Frame", nil, parent)
    panelFrame:SetAllPoints()
    panelFrame:Hide()

    -- ========================================================================
    -- HEADER SECTION - Stats and button
    -- ========================================================================
    local header = CreateFrame("Frame", nil, panelFrame)
    header:SetPoint("TOPLEFT", 10, -8)
    header:SetPoint("TOPRIGHT", -10, -8)
    header:SetHeight(28)

    -- Stats text (left side)
    panelFrame.statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panelFrame.statsText:SetPoint("LEFT", 0, 0)
    panelFrame.statsText:SetJustifyH("LEFT")
    panelFrame.statsText:SetTextColor(0.8, 0.8, 0.8, 1)
    panelFrame.statsText:SetText("")

    -- Post to Raid button (right side) - using success color
    local postBtn = Widgets:CreateButton(header, "Post to Raid", 100, 24)
    postBtn:SetPoint("RIGHT", 0, 0)
    postBtn:SetBackdropColor(0.25, 0.5, 0.25, 1)
    postBtn:SetScript("OnClick", function()
        SummonPanel:PostSummonRequest()
    end)
    postBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Post Summon Request", 1, 1, 1)
        GameTooltip:AddLine("Posts to raid chat:", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("\"Please help summon: Name1, Name2...\"", 0.5, 0.8, 0.5, true)
        GameTooltip:Show()
    end)
    postBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panelFrame.postBtn = postBtn

    -- ========================================================================
    -- YOUR ZONE INFO
    -- ========================================================================
    local zoneRow = CreateFrame("Frame", nil, panelFrame)
    zoneRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    zoneRow:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    zoneRow:SetHeight(20)

    panelFrame.zoneText = zoneRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelFrame.zoneText:SetPoint("LEFT", 0, 0)
    panelFrame.zoneText:SetJustifyH("LEFT")
    panelFrame.zoneText:SetTextColor(0.5, 0.5, 0.5, 1)

    -- ========================================================================
    -- MAIN LIST PANEL
    -- ========================================================================
    local listPanel = Widgets:CreateBackdropFrame(panelFrame, "RCHSummonListPanel")
    listPanel:SetPoint("TOPLEFT", zoneRow, "BOTTOMLEFT", 0, -4)
    listPanel:SetPoint("BOTTOMRIGHT", -10, 10)
    listPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)

    -- Title
    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", 8, -6)
    listTitle:SetText("NEED SUMMONS")
    listTitle:SetTextColor(COLORS.textDim[1], COLORS.textDim[2], COLORS.textDim[3], 1)

    -- Scroll frame for list
    local listScroll, listContent = Widgets:CreateScrollFrame(listPanel, "RCHSummonListScroll")
    listScroll:SetPoint("TOPLEFT", 4, -24)
    listScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    listContent:SetWidth(listScroll:GetWidth() - 5)
    panelFrame.listContent = listContent
    panelFrame.listScroll = listScroll
    panelFrame.listPanel = listPanel

    return panelFrame
end

-- ============================================================================
-- DATA REFRESH
-- ============================================================================

function SummonPanel:RefreshList()
    if not panelFrame or not panelFrame:IsShown() then return end

    local content = panelFrame.listContent

    -- Clear existing items
    for _, item in ipairs(listItems) do
        item:Hide()
        item:SetParent(nil)
    end
    listItems = {}

    local needSummon, inZoneCount, offlineCount = self:GetPlayersNeedingSummon()

    local yOffset = 0
    local itemHeight = 22

    for _, playerData in ipairs(needSummon) do
        local item = Widgets:CreateSummonListItem(content, content:GetWidth() - 10, itemHeight)
        item:SetPoint("TOPLEFT", 0, -yOffset)
        item:SetPoint("RIGHT", -5, 0)
        item:SetPlayer(playerData)

        table.insert(listItems, item)
        yOffset = yOffset + itemHeight + 1
    end

    -- Show empty state if no one needs summons
    if #needSummon == 0 then
        local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", 0, 20)
        emptyText:SetText("Everyone is here!")
        emptyText:SetTextColor(0.4, 0.8, 0.4, 1)
        table.insert(listItems, emptyText)
        yOffset = 60
    end

    content:SetHeight(math.max(yOffset + 10, 100))
end

function SummonPanel:UpdateStats()
    if not panelFrame then return end

    local needSummon, inZoneCount, offlineCount = self:GetPlayersNeedingSummon()

    -- Count online players needing summons
    local onlineNeedSummon = 0
    for _, p in ipairs(needSummon) do
        if p.online then
            onlineNeedSummon = onlineNeedSummon + 1
        end
    end

    if not IsInRaid() then
        panelFrame.statsText:SetText("Not in raid")
        panelFrame.statsText:SetTextColor(0.5, 0.5, 0.5, 1)
        panelFrame.zoneText:SetText("")
        return
    end

    -- Stats: "X need summons | Y in zone | Z offline"
    local summonColor = onlineNeedSummon > 0 and "|cffff8800" or "|cff88ff88"
    local offlineColor = offlineCount > 0 and "|cffff6666" or "|cff888888"

    local text = string.format(
        "%s%d|r need summons   |cff88ff88%d|r in zone   %s%d|r offline",
        summonColor,
        onlineNeedSummon,
        inZoneCount,
        offlineColor,
        offlineCount
    )
    panelFrame.statsText:SetText(text)

    -- Show current zone
    local myZone = GetRealZoneText() or "Unknown"
    panelFrame.zoneText:SetText("Your zone: |cffffffff" .. myZone .. "|r")
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function SummonPanel:Show()
    local parent = RCH.MainFrame and RCH.MainFrame:GetSummonContent()
    if not parent then return end

    if not panelFrame then
        self:Create(parent)
    end

    panelFrame:Show()

    -- Refresh on show
    self:RefreshList()
    self:UpdateStats()
end

function SummonPanel:Hide()
    if panelFrame then
        panelFrame:Hide()
    end
end

function SummonPanel:IsShown()
    return panelFrame and panelFrame:IsShown()
end
