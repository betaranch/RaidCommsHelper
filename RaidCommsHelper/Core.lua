-- RaidCommsHelper Core
-- Main addon initialization, event handling, slash commands

local ADDON_NAME = "RaidCommsHelper"

-- Create addon namespace
RaidCommsHelper = RaidCommsHelper or {}
local RCH = RaidCommsHelper

-- Localize frequently used globals
local pairs, ipairs = pairs, ipairs
local print = print
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local SendChatMessage = SendChatMessage
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant

-- Addon color for print messages
local ADDON_COLOR = "|cff00ccff"
local function AddonPrint(...)
    print(ADDON_COLOR .. "[RCH]|r", ...)
end
RCH.Print = AddonPrint

-- Keybind localization strings are in Locales.lua (must load first)

-- Default SavedVariables structure
local DEFAULT_DB = {
    activeFolder = "General",
    folders = {},  -- Will be populated from DefaultMessages.lua on first run
}

-- Initialize SavedVariables
local function InitializeDB()
    RaidCommsHelperDB = RaidCommsHelperDB or {}

    -- Merge defaults
    for key, value in pairs(DEFAULT_DB) do
        if RaidCommsHelperDB[key] == nil then
            RaidCommsHelperDB[key] = value
        end
    end

    -- Load default messages if folders is empty (first run)
    if not next(RaidCommsHelperDB.folders) then
        if RCH_DefaultMessages then
            for folderName, folderData in pairs(RCH_DefaultMessages) do
                RaidCommsHelperDB.folders[folderName] = {
                    order = folderData.order or 99,
                    messages = {}
                }
                for i, msg in ipairs(folderData.messages) do
                    table.insert(RaidCommsHelperDB.folders[folderName].messages, {
                        name = msg.name,
                        text = msg.text,
                        chatType = msg.chatType or "RAID_WARNING",
                    })
                end
            end
        end
    end

    -- Ensure activeFolder exists
    if not RaidCommsHelperDB.folders[RaidCommsHelperDB.activeFolder] then
        -- Pick the first available folder
        for folderName, _ in pairs(RaidCommsHelperDB.folders) do
            RaidCommsHelperDB.activeFolder = folderName
            break
        end
    end

    RCH.db = RaidCommsHelperDB
end

-- Get appropriate chat type based on context
function RCH:GetChatType(requestedType)
    requestedType = requestedType or "RAID_WARNING"

    if IsInRaid() then
        if requestedType == "RAID_WARNING" then
            -- Check if we have permission for raid warning
            if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
                return "RAID_WARNING"
            else
                return "RAID"  -- Fall back to raid chat
            end
        end
        return requestedType
    elseif IsInGroup() then
        return "PARTY"
    else
        return "SAY"  -- Solo testing
    end
end

-- Send a message from the active folder by index
function RCH:SendMessageByIndex(index)
    local db = self.db
    if not db then return end

    local folderName = db.activeFolder
    local folder = db.folders[folderName]

    if not folder or not folder.messages then
        return
    end

    local message = folder.messages[index]
    if not message then
        return  -- Index out of bounds, do nothing
    end

    -- Process template and send
    local chatType = self:GetChatType(message.chatType)
    self.TemplateEngine:Send(message.text, chatType)
end

-- Global function called from Bindings.xml
function RaidCommsHelper_SendSlot(slotNum)
    RCH:SendMessageByIndex(slotNum)
end

-- Global function to toggle main window
function RaidCommsHelper_ToggleWindow()
    if RCH.MainFrame then
        RCH.MainFrame:Toggle()
    end
end

-- Global function to open directly to Vers panel
function RaidCommsHelper_OpenVersPanel()
    if RCH.MainFrame then
        RCH.MainFrame:Show()
        RCH.MainFrame:SwitchTab("VERS")
    end
end

-- Slash command handler
local function SlashHandler(msg)
    local cmd, arg = strsplit(" ", msg or "", 2)
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "config" or cmd == "options" or cmd == "show" then
        if RCH.MainFrame then
            RCH.MainFrame:Show()
        else
            AddonPrint("UI not loaded yet. Try again after /reload")
        end

    elseif cmd == "hide" then
        if RCH.MainFrame then
            RCH.MainFrame:Hide()
        end

    elseif cmd == "toggle" then
        if RCH.MainFrame then
            RCH.MainFrame:Toggle()
        end

    elseif cmd == "folder" and arg then
        -- Switch active folder
        if RCH.db.folders[arg] then
            RCH.db.activeFolder = arg
            AddonPrint("Active folder: " .. arg)
            if RCH.MainFrame and RCH.MainFrame:IsShown() then
                RCH.MainFrame:RefreshFolderList()
                RCH.MainFrame:RefreshMessageList()
            end
        else
            AddonPrint("Folder not found: " .. arg)
        end

    elseif cmd == "list" then
        -- List all folders
        AddonPrint("Folders:")
        for folderName, folder in pairs(RCH.db.folders) do
            local marker = (folderName == RCH.db.activeFolder) and " > " or "   "
            print(marker .. folderName .. " (" .. #folder.messages .. " messages)")
        end

    elseif cmd == "test" and arg then
        -- Test template processing without sending
        local processed = RCH.TemplateEngine:Process(arg)
        print("Processed: " .. processed)

    elseif cmd == "send" then
        -- Send message by index from active folder
        local index = tonumber(arg)
        if index then
            RCH:SendMessageByIndex(index)
        else
            AddonPrint("Usage: /rc send <number>")
        end

    elseif cmd == "reset" then
        -- Reset to defaults
        RaidCommsHelperDB = nil
        InitializeDB()
        AddonPrint("Settings reset to defaults. /reload to apply.")

    elseif cmd == "debug" then
        -- Debug: show vers info for target or self
        local unit = UnitExists("target") and "target" or "player"
        local name = UnitName(unit)
        AddonPrint("Debug vers for: " .. name .. " (" .. unit .. ")")

        -- Read vers from Infinite Power buff (works for ANY unit in Legion Remix)
        print("  === Infinite Power Buff ===")
        if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            local powerAura = C_UnitAuras.GetAuraDataBySpellName(unit, "Infinite Power")
            if not powerAura then
                powerAura = C_UnitAuras.GetAuraDataBySpellName(unit, "Threads of Power")
            end

            if powerAura then
                print("    Found buff (Spell ID: " .. (powerAura.spellId or "?") .. ")")
                print("    Stacks: " .. (powerAura.applications or 0))

                -- Show ALL points values
                if powerAura.points then
                    print("    Points array:")
                    local foundAny = false
                    for i = 1, 10 do
                        if powerAura.points[i] then
                            foundAny = true
                            local val = powerAura.points[i]
                            local marker = ""
                            if val > 0 and val <= 999 then
                                marker = " |cff00ff00<-- likely vers|r"
                            end
                            print(string.format("      [%d] = %.2f%s", i, val, marker))
                        end
                    end
                    if not foundAny then
                        print("      |cffff8800(empty)|r")
                    end
                else
                    print("    |cffff8800No points array|r")
                end
            else
                print("    |cffff0000Infinite Power buff NOT found|r")
            end
        else
            print("    C_UnitAuras.GetAuraDataBySpellName not available")
        end

        -- Show cached data
        if RCH.VersCache then
            local vers, scanned = RCH.VersCache:GetVers(name)
            print("  === Cached Data ===")
            print("    Vers: " .. string.format("%.1f%%", vers) .. " (scanned: " .. tostring(scanned) .. ")")
        end

    elseif cmd == "setvers" then
        -- Manually set vers for a player
        local playerName, versValue = strsplit(" ", arg or "", 2)
        local vers = tonumber(versValue)
        if playerName and vers then
            if RCH.VersCache then
                RCH.VersCache:SetVers(playerName, vers)
                AddonPrint("Set " .. playerName .. " vers to " .. vers .. "%")
                -- Refresh UI if open
                if RCH.VersPanel and RCH.VersPanel:IsShown() then
                    RCH.VersPanel:RefreshRoster()
                    RCH.VersPanel:RefreshPreview()
                end
            end
        else
            AddonPrint("Usage: /rch setvers PlayerName 15.5")
        end

    else
        AddonPrint("Commands:")
        print("  /rch - Open main window")
        print("  /rch folder <name> - Switch active folder")
        print("  /rch list - List all folders")
        print("  /rch send <n> - Send message #n from active folder")
        print("  /rch test <template> - Test template expansion")
        print("  /rch debug - Debug vers for target/self")
        print("  /rch setvers Name ## - Manually set player vers")
        print("  /rch reset - Reset to defaults")
    end
end

-- Register slash commands
SLASH_RAIDCOMMSHELPER1 = "/rch"
SLASH_RAIDCOMMSHELPER2 = "/raidcomms"
SLASH_RAIDCOMMSHELPER3 = "/comms"
SlashCmdList["RAIDCOMMSHELPER"] = SlashHandler

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitializeDB()
            AddonPrint("v1.0.0 loaded. Type /rc to open.")
        end

    elseif event == "PLAYER_LOGIN" then
        -- Additional initialization after player is fully logged in
        -- Nothing needed for now
    end
end)

-- Store reference to addon namespace
_G["RaidCommsHelper"] = RCH
