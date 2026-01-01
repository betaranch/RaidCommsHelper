-- RaidCommsHelper Vers Sync
-- Addon communication to share versatility data between players

local RCH = RaidCommsHelper
RCH.VersSync = RCH.VersSync or {}

local VersSync = RCH.VersSync

-- Addon message prefix (max 16 chars)
local ADDON_PREFIX = "RCHVersSync"

-- Localize globals
local C_ChatInfo = C_ChatInfo
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local UnitName = UnitName
local GetTime = GetTime
local C_Timer = C_Timer

-- Register addon prefix
local registered = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Get player's own versatility
local function GetMyVersatility()
    -- Try multiple methods to get vers
    local vers = 0

    -- Method 1: GetCombatRatingBonus (standard)
    local rating = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE or 29) or 0
    local bonus = GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE or 29) or 0
    vers = rating + bonus

    -- Method 2: If vers is still 0, try scanning character sheet text
    -- (Legion Remix stores vers differently)
    if vers == 0 then
        -- Try getting from character stats frame if available
        if CharacterStatsPane and CharacterStatsPane.statsFramePool then
            -- This is complex, skip for now
        end
    end

    return vers
end

-- Broadcast our vers to the group
function VersSync:BroadcastVers()
    if not IsInGroup() and not IsInRaid() then return end

    local vers = GetMyVersatility()
    local playerName = UnitName("player")

    -- Format: "VERS:PlayerName:VersValue"
    local message = string.format("VERS:%s:%.2f", playerName, vers)

    local chatType = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, chatType)

    -- Also update our own cache
    if RCH.VersCache then
        RCH.VersCache:SetVers(playerName, vers)
    end
end

-- Request vers from all group members
function VersSync:RequestVers()
    if not IsInGroup() and not IsInRaid() then return end

    local chatType = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "REQUEST", chatType)
end

-- Handle incoming addon messages
local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    -- Remove realm name if present
    local senderName = strsplit("-", sender)

    if message == "REQUEST" then
        -- Someone requested vers, broadcast ours after small delay (avoid spam)
        C_Timer.After(math.random() * 2, function()
            VersSync:BroadcastVers()
        end)

    elseif message:find("^VERS:") then
        -- Parse vers data: "VERS:PlayerName:VersValue"
        local _, playerName, versStr = strsplit(":", message)
        local vers = tonumber(versStr) or 0

        if playerName and vers > 0 and RCH.VersCache then
            RCH.VersCache:SetVers(playerName, vers)

            -- Refresh UI if open
            if RCH.VersPanel and RCH.VersPanel:IsShown() then
                RCH.VersPanel:RefreshRoster()
                RCH.VersPanel:RefreshPreview()
                RCH.VersPanel:UpdateStats()
            end
        end
    end
end

-- Handle events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Broadcast our vers when group changes
        C_Timer.After(2, function()
            VersSync:BroadcastVers()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Broadcast vers shortly after logging in/reloading
        C_Timer.After(5, function()
            if IsInGroup() or IsInRaid() then
                VersSync:BroadcastVers()
                -- Also request from others
                C_Timer.After(1, function()
                    VersSync:RequestVers()
                end)
            end
        end)
    end
end)

-- Manual sync trigger
function VersSync:Sync()
    RCH.Print("Syncing vers with group...")
    VersSync:BroadcastVers()
    C_Timer.After(0.5, function()
        VersSync:RequestVers()
    end)
end
