-- RaidCommsHelper Template Engine
-- Processes placeholders in message templates

local RCH = RaidCommsHelper

-- Localize globals
local pairs, ipairs = pairs, ipairs
local table = table
local string = string
local strsplit = strsplit
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitName = UnitName
local UnitExists = UnitExists
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local SendChatMessage = SendChatMessage

local TemplateEngine = {}

-- Raid marker icons - use {rtX} format which is processed server-side
-- Note: Texture escapes |T...|t are blocked by Blizzard in SendChatMessage
-- The {rtX} format is universal across all client locales
local RAID_ICONS = {
    ["{star}"]     = "{rt1}",
    ["{circle}"]   = "{rt2}",
    ["{diamond}"]  = "{rt3}",
    ["{triangle}"] = "{rt4}",
    ["{moon}"]     = "{rt5}",
    ["{square}"]   = "{rt6}",
    ["{cross}"]    = "{rt7}",
    ["{x}"]        = "{rt7}",
    ["{skull}"]    = "{rt8}",
}

-- Get players in a specific raid group (1-8)
local function GetGroupMembers(groupNum)
    local members = {}

    if IsInRaid() then
        for i = 1, 40 do
            local name, _, subgroup, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and subgroup == groupNum and online then
                -- Strip realm name for cleaner display
                local shortName = strsplit("-", name)
                table.insert(members, shortName)
            end
        end
    else
        -- In party, everyone is in "group 1"
        if groupNum == 1 then
            for i = 1, GetNumGroupMembers() do
                local unit = (i == GetNumGroupMembers()) and "player" or ("party" .. i)
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    if name then
                        table.insert(members, name)
                    end
                end
            end
        end
    end

    return members
end

-- Get players by combat role (TANK, HEALER, DAMAGER)
local function GetPlayersByRole(role)
    local members = {}

    if IsInRaid() then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, online, _, _, _, combatRole = GetRaidRosterInfo(i)
            if name and combatRole == role and online then
                local shortName = strsplit("-", name)
                table.insert(members, shortName)
            end
        end
    else
        -- Party mode - check using UnitGroupRolesAssigned
        for i = 1, GetNumGroupMembers() do
            local unit
            if i == GetNumGroupMembers() then
                unit = "player"
            else
                unit = "party" .. i
            end

            if UnitExists(unit) then
                local unitRole = UnitGroupRolesAssigned(unit)
                if unitRole == role then
                    local name = UnitName(unit)
                    if name then
                        table.insert(members, name)
                    end
                end
            end
        end
    end

    return members
end

-- Get Main Tank / Main Assist players
local function GetPlayersWithRaidRole(raidRole)
    local members = {}

    if IsInRaid() then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, online, _, role = GetRaidRosterInfo(i)
            if name and online then
                -- role is "maintank", "mainassist", or nil (note lowercase)
                if (raidRole == "MAINTANK" and role == "maintank") or
                   (raidRole == "MAINASSIST" and role == "mainassist") then
                    local shortName = strsplit("-", name)
                    table.insert(members, shortName)
                end
            end
        end
    end

    return members
end

-- Process all placeholders in a template string
function TemplateEngine:Process(template)
    local result = template

    -- Strip "/rw " prefix if present (we control chat type separately)
    result = result:gsub("^/rw%s+", "")
    result = result:gsub("^/raid%s+", "")

    -- Convert raid icons to texture escape sequences (case insensitive)
    for placeholder, texture in pairs(RAID_ICONS) do
        result = result:gsub(placeholder, texture)
        result = result:gsub(placeholder:upper(), texture)
    end

    -- Group member placeholders {G1} through {G8}
    for g = 1, 8 do
        local pattern = "{G" .. g .. "}"
        if result:find(pattern, 1, true) then
            local members = GetGroupMembers(g)
            local memberStr = table.concat(members, ", ")
            result = result:gsub(pattern, memberStr)
        end
        -- Also lowercase
        local patternLower = "{g" .. g .. "}"
        if result:find(patternLower, 1, true) then
            local members = GetGroupMembers(g)
            local memberStr = table.concat(members, ", ")
            result = result:gsub(patternLower, memberStr)
        end
    end

    -- Role placeholders
    result = result:gsub("{TANKS}", function()
        return table.concat(GetPlayersByRole("TANK"), ", ")
    end)
    result = result:gsub("{tanks}", function()
        return table.concat(GetPlayersByRole("TANK"), ", ")
    end)

    result = result:gsub("{HEALERS}", function()
        return table.concat(GetPlayersByRole("HEALER"), ", ")
    end)
    result = result:gsub("{healers}", function()
        return table.concat(GetPlayersByRole("HEALER"), ", ")
    end)

    result = result:gsub("{DPS}", function()
        return table.concat(GetPlayersByRole("DAMAGER"), ", ")
    end)
    result = result:gsub("{dps}", function()
        return table.concat(GetPlayersByRole("DAMAGER"), ", ")
    end)

    -- Raid role placeholders (Main Tank, Main Assist)
    result = result:gsub("{MT}", function()
        return table.concat(GetPlayersWithRaidRole("MAINTANK"), ", ")
    end)
    result = result:gsub("{mt}", function()
        return table.concat(GetPlayersWithRaidRole("MAINTANK"), ", ")
    end)

    result = result:gsub("{MA}", function()
        return table.concat(GetPlayersWithRaidRole("MAINASSIST"), ", ")
    end)
    result = result:gsub("{ma}", function()
        return table.concat(GetPlayersWithRaidRole("MAINASSIST"), ", ")
    end)

    -- Target placeholder
    if result:find("{target}", 1, true) or result:find("{TARGET}", 1, true) then
        local targetName = ""
        if UnitExists("target") then
            targetName = UnitName("target") or ""
        end
        result = result:gsub("{target}", targetName)
        result = result:gsub("{TARGET}", targetName)
    end

    -- Focus placeholder
    if result:find("{focus}", 1, true) or result:find("{FOCUS}", 1, true) then
        local focusName = ""
        if UnitExists("focus") then
            focusName = UnitName("focus") or ""
        end
        result = result:gsub("{focus}", focusName)
        result = result:gsub("{FOCUS}", focusName)
    end

    -- Raid count
    result = result:gsub("{raidcount}", tostring(GetNumGroupMembers()))
    result = result:gsub("{RAIDCOUNT}", tostring(GetNumGroupMembers()))

    return result
end

-- Send a processed message to chat
-- Handles multi-line messages by sending each line separately
function TemplateEngine:Send(template, chatType)
    chatType = chatType or "RAID_WARNING"

    local processed = self:Process(template)

    -- Split by newlines and send each line
    local lines = { strsplit("\n", processed) }

    for _, line in ipairs(lines) do
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")

        -- Skip empty lines
        if line and line ~= "" then
            -- IMPORTANT: Pipe character | causes "Invalid escape code" error
            -- Replace pipes used as separators with dashes
            line = line:gsub(" | ", " - ")
            line = line:gsub("^|", "")  -- Remove leading pipe
            line = line:gsub("|$", "")  -- Remove trailing pipe

            -- Truncate if too long (255 byte limit)
            if #line > 255 then
                line = line:sub(1, 252) .. "..."
            end

            SendChatMessage(line, chatType)
        end
    end
end

-- Preview a template (process but don't send)
function TemplateEngine:Preview(template)
    return self:Process(template)
end

-- Attach to addon namespace
RCH.TemplateEngine = TemplateEngine
