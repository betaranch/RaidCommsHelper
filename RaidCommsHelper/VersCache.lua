-- RaidCommsHelper Vers Cache
-- Lazy loading versatility scanner for raid members
-- Now with SavedVariables persistence!

local RCH = RaidCommsHelper
RCH.VersCache = RCH.VersCache or {}

local VersCache = RCH.VersCache

-- Localize globals
local GetNumGroupMembers = GetNumGroupMembers
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetTime = GetTime
local GetCombatRatingBonus = GetCombatRatingBonus
local GetVersatilityBonus = GetVersatilityBonus

-- Combat rating constants
local CR_VERSATILITY_DAMAGE_DONE = CR_VERSATILITY_DAMAGE_DONE or 29

-- Helper to get full player name with realm (for cross-realm consistency)
local function GetFullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    -- For same-realm players, still append our realm for consistency
    local _, myRealm = UnitName("player")
    if not realm or realm == "" then
        -- Try to get realm from GUID
        local guid = UnitGUID(unit)
        if guid then
            local _, _, _, _, _, playerName, playerRealm = GetPlayerInfoByGUID(guid)
            if playerRealm and playerRealm ~= "" then
                return name .. "-" .. playerRealm
            end
        end
    end
    return name  -- Fallback to just name if realm not available
end

-- Cache storage
local versData = {}  -- [playerName] = { vers = number, timestamp = number, guid = string }
local scanQueue = {}
local CACHE_DURATION = 300  -- 5 minutes for in-session cache validity
local PERSIST_DURATION = 86400  -- 24 hours for persisted cache validity
local scanCallback = nil

-- ============================================================================
-- SAVEDVARIABLES PERSISTENCE
-- ============================================================================

-- Save cache to SavedVariables
local function SaveToSavedVariables()
    if not RaidCommsHelperDB then return end

    RaidCommsHelperDB.versCache = RaidCommsHelperDB.versCache or {}

    -- Save each player's data with real timestamp (not session-based GetTime)
    for name, data in pairs(versData) do
        if data.scanned and data.vers > 0 then
            RaidCommsHelperDB.versCache[name] = {
                vers = data.vers,
                savedAt = time(),  -- Real timestamp for persistence
                guid = data.guid or "",
            }
        end
    end
end

-- Load cache from SavedVariables
local function LoadFromSavedVariables()
    if not RaidCommsHelperDB or not RaidCommsHelperDB.versCache then return end

    local now = time()
    local loaded = 0
    local expired = 0

    for name, savedData in pairs(RaidCommsHelperDB.versCache) do
        local age = now - (savedData.savedAt or 0)

        -- Only load if not too old (24 hours)
        if age < PERSIST_DURATION then
            versData[name] = {
                vers = savedData.vers,
                timestamp = GetTime(),  -- Use current session time
                guid = savedData.guid or "",
                scanned = true,
                cached = true,  -- Flag to indicate this is from saved cache
                cacheAge = age,
            }
            loaded = loaded + 1
        else
            -- Clean up expired entries
            RaidCommsHelperDB.versCache[name] = nil
            expired = expired + 1
        end
    end

    if loaded > 0 then
        RCH.Print(string.format("Loaded %d cached vers entries", loaded))
    end
end

-- Event frame for persistence
local persistFrame = CreateFrame("Frame")
persistFrame:RegisterEvent("PLAYER_LOGIN")
persistFrame:RegisterEvent("PLAYER_LOGOUT")

persistFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Load cached data after a short delay (ensure DB is ready)
        C_Timer.After(0.5, function()
            LoadFromSavedVariables()
        end)
    elseif event == "PLAYER_LOGOUT" then
        SaveToSavedVariables()
    end
end)

-- Get versatility from the Infinite Power buff (works for ANY unit in Legion Remix!)
-- The vers % is typically stored in the points array, but index may vary
local function GetVersatilityFromInfinitePowerBuff(unit)
    if not UnitExists(unit) then return 0, false end

    -- Try to get the Infinite Power aura
    local powerAura = nil

    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        -- Try both possible names
        powerAura = C_UnitAuras.GetAuraDataBySpellName(unit, "Infinite Power")
        if not powerAura then
            powerAura = C_UnitAuras.GetAuraDataBySpellName(unit, "Threads of Power")
        end
    end

    if powerAura then
        -- Debug: print aura info if DEBUG_SCAN is enabled
        if DEBUG_SCAN then
            RCH.Print("Aura found for " .. (UnitName(unit) or "unknown") .. " (SpellID: " .. (powerAura.spellId or "?") .. ")")
            if powerAura.points then
                local pointsStr = "  Points: "
                local hasAny = false
                for i = 1, 10 do
                    if powerAura.points[i] then
                        hasAny = true
                        pointsStr = pointsStr .. string.format("[%d]=%.2f ", i, powerAura.points[i])
                    end
                end
                if hasAny then
                    RCH.Print(pointsStr)
                else
                    RCH.Print("  Points array is EMPTY!")
                end
            else
                RCH.Print("  NO points array on aura!")
            end
        end
    else
        -- No aura found
        if DEBUG_SCAN then
            RCH.Print("NO Infinite Power aura found for " .. (UnitName(unit) or "unknown"))
        end
    end

    if powerAura and powerAura.points then
        if DEBUG_SCAN then
            RCH.Print("  Checking points for vers value...")
        end

        -- Check index 5 first (common location for high vers players)
        local p5 = powerAura.points[5]
        if p5 then
            if DEBUG_SCAN then
                RCH.Print("  points[5] = " .. tostring(p5) .. " (type: " .. type(p5) .. ")")
            end
            if p5 > 0 and p5 <= 999 then
                if DEBUG_SCAN then
                    RCH.Print("  RETURNING vers = " .. p5 .. " from index 5")
                end
                return p5, true
            end
        end

        -- For other players, check all indices
        -- Vers ranges from 0-999% in Legion Remix
        for i = 1, 10 do
            local val = powerAura.points[i]
            if val and val > 0 and val <= 999 then
                if DEBUG_SCAN then
                    RCH.Print("  RETURNING vers = " .. val .. " from index " .. i)
                end
                return val, true
            end
        end

        -- If we have points but couldn't find vers, return 0 but mark as scanned
        if DEBUG_SCAN then
            RCH.Print("  No valid vers found in points, returning 0")
        end
        return 0, true
    else
        if DEBUG_SCAN then
            RCH.Print("  powerAura or points is nil!")
        end
    end

    return 0, false
end

-- Get player's own versatility (fallback to API if buff reading fails)
local function GetPlayerVersatility()
    -- First try the Infinite Power buff method (works in Legion Remix)
    local vers, success = GetVersatilityFromInfinitePowerBuff("player")
    if success and vers > 0 then
        return vers
    end

    -- Fallback: standard API
    local ratingBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
    local versatilityBonus = 0

    if GetVersatilityBonus then
        versatilityBonus = GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
    end

    return ratingBonus + versatilityBonus
end

-- Debug flag (set to true to see scan output)
local DEBUG_SCAN = false

local function DebugPrint(...)
    if DEBUG_SCAN and RCH.Print then
        RCH.Print(...)
    end
end


-- Add player to scan queue
function VersCache:QueuePlayer(playerName, unit)
    if not playerName or not unit then return end

    -- Check if already in cache and still valid
    local cached = versData[playerName]
    if cached and (GetTime() - cached.timestamp) < CACHE_DURATION then
        return  -- Cache still valid
    end

    -- Add to queue if not already there
    for _, entry in ipairs(scanQueue) do
        if entry.name == playerName then
            return  -- Already queued
        end
    end

    table.insert(scanQueue, {
        name = playerName,
        unit = unit
    })
end

-- Process the scan queue
function VersCache:ProcessQueue()
    if #scanQueue == 0 then
        -- Queue complete
        if scanCallback then
            scanCallback(versData)
            scanCallback = nil
        end
        return
    end

    -- Get next player
    local entry = table.remove(scanQueue, 1)

    if not UnitExists(entry.unit) then
        -- Unit no longer valid, skip
        VersCache:ProcessQueue()
        return
    end

    -- Try to read vers from Infinite Power buff (works for ANY unit!)
    local vers, success = GetVersatilityFromInfinitePowerBuff(entry.unit)

    if success then
        DebugPrint("Read vers from buff for " .. entry.name .. ": " .. string.format("%.1f%%", vers))
        versData[entry.name] = {
            vers = vers,
            timestamp = GetTime(),
            guid = UnitGUID(entry.unit) or "",
            scanned = true
        }
        VersCache:ProcessQueue()
        return
    end

    -- Fallback for player: use direct API
    if UnitIsUnit(entry.unit, "player") then
        vers = GetPlayerVersatility()
        DebugPrint("Read vers from API for " .. entry.name .. ": " .. string.format("%.1f%%", vers))
        versData[entry.name] = {
            vers = vers,
            timestamp = GetTime(),
            guid = UnitGUID("player"),
            scanned = true
        }
        VersCache:ProcessQueue()
        return
    end

    -- Could not read vers from buff (player might not have Infinite Power yet)
    DebugPrint("Could not read vers for " .. entry.name .. " - no Infinite Power buff")
    versData[entry.name] = {
        vers = 0,
        timestamp = GetTime(),
        guid = UnitGUID(entry.unit) or "",
        scanned = false
    }
    VersCache:ProcessQueue()
end

-- Start scanning all raid members
function VersCache:ScanRaid(callback)
    if not IsInRaid() and not IsInGroup() then
        if callback then callback({}) end
        return
    end

    -- Wrap callback to save after scan completes
    local originalCallback = callback
    scanCallback = function(data)
        SaveToSavedVariables()
        if originalCallback then originalCallback(data) end
    end

    scanQueue = {}

    -- DON'T clear cache - preserve existing data for players not in range
    -- Just force re-scan everyone currently in group

    local numMembers = GetNumGroupMembers()

    -- Always add player first (instant, no inspect needed)
    local playerName = GetFullName("player")
    self:QueuePlayerForce(playerName, "player")

    -- Add raid/party members
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)

        -- Skip if this is the player (already added)
        if not UnitIsUnit(unit, "player") then
            local name = GetFullName(unit)
            if name then
                self:QueuePlayerForce(name, unit)
            end
        end
    end

    self:ProcessQueue()
end

-- Scan only players with missing or failed vers data
function VersCache:ScanMissing(callback)
    if not IsInRaid() and not IsInGroup() then
        if callback then callback({}) end
        return
    end

    -- Wrap callback to save after scan completes
    local originalCallback = callback
    scanCallback = function(data)
        SaveToSavedVariables()
        if originalCallback then originalCallback(data) end
    end

    scanQueue = {}

    local numMembers = GetNumGroupMembers()

    -- Check player first
    local playerName = GetFullName("player")
    local playerData = versData[playerName]
    if not playerData or not playerData.scanned then
        self:QueuePlayerForce(playerName, "player")
    end

    -- Check raid/party members
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)

        if not UnitIsUnit(unit, "player") then
            local name = GetFullName(unit)
            if name then
                local data = versData[name]
                -- Queue if not in cache OR failed to scan OR vers is 0
                if not data or not data.scanned or data.vers == 0 then
                    self:QueuePlayerForce(name, unit)
                end
            end
        end
    end

    if #scanQueue == 0 then
        -- Nothing to scan
        if callback then callback(versData) end
        return
    end

    self:ProcessQueue()
end

-- Force queue a player (bypass cache check)
function VersCache:QueuePlayerForce(playerName, unit)
    if not playerName or not unit then return end

    -- Add to queue if not already there
    for _, entry in ipairs(scanQueue) do
        if entry.name == playerName then
            return
        end
    end

    table.insert(scanQueue, {
        name = playerName,
        unit = unit
    })
end

-- Get count of players with missing/failed vers data
function VersCache:GetMissingCount()
    if not IsInRaid() and not IsInGroup() then
        return 0
    end

    local missing = 0
    local numMembers = GetNumGroupMembers()

    -- Check player
    local playerName = GetFullName("player")
    local playerData = versData[playerName]
    if not playerData or not playerData.scanned then
        missing = missing + 1
    end

    -- Check raid/party members
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)

        if not UnitIsUnit(unit, "player") then
            local name = GetFullName(unit)
            if name then
                local data = versData[name]
                if not data or not data.scanned then
                    missing = missing + 1
                end
            end
        end
    end

    return missing
end

-- Get cached vers for a player
function VersCache:GetVers(playerName)
    local data = versData[playerName]
    if data then
        return data.vers, data.scanned
    end
    return 0, false
end

-- Get all cached data
function VersCache:GetAllData()
    return versData
end

-- Clear cache
function VersCache:ClearCache()
    versData = {}
    scanQueue = {}
end

-- Check if scan is in progress
function VersCache:IsScanning()
    return #scanQueue > 0
end

-- Get scan progress
function VersCache:GetScanProgress()
    local total = 0
    local scanned = 0

    for name, data in pairs(versData) do
        total = total + 1
        if data.scanned then
            scanned = scanned + 1
        end
    end

    return scanned, total + #scanQueue
end

-- Manual vers entry (for testing or manual override)
function VersCache:SetVers(playerName, vers)
    versData[playerName] = {
        vers = vers,
        timestamp = GetTime(),
        guid = "",
        scanned = true,
        manual = true
    }
    -- Save to persistent storage
    SaveToSavedVariables()
end

-- Get sorted list of players by vers
function VersCache:GetSortedByVers(descending)
    local sorted = {}

    for name, data in pairs(versData) do
        table.insert(sorted, {
            name = name,
            vers = data.vers,
            scanned = data.scanned,
            cached = data.cached,
            cacheAge = data.cacheAge,
        })
    end

    table.sort(sorted, function(a, b)
        if descending then
            return a.vers > b.vers
        else
            return a.vers < b.vers
        end
    end)

    return sorted
end

-- Get cache statistics
function VersCache:GetCacheStats()
    local total = 0
    local fromCache = 0
    local fresh = 0

    for name, data in pairs(versData) do
        total = total + 1
        if data.cached then
            fromCache = fromCache + 1
        else
            fresh = fresh + 1
        end
    end

    return {
        total = total,
        fromCache = fromCache,
        fresh = fresh,
    }
end

-- Check if a player's data is from persistent cache (not freshly scanned this session)
function VersCache:IsFromCache(playerName)
    local data = versData[playerName]
    return data and data.cached
end

-- Force save to SavedVariables (can be called manually)
function VersCache:ForceSave()
    SaveToSavedVariables()
    RCH.Print("Vers cache saved")
end
