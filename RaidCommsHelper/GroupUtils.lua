-- RaidCommsHelper Group Utilities
-- Sorting algorithms for raid composition

local RCH = RaidCommsHelper
RCH.GroupUtils = RCH.GroupUtils or {}

local GroupUtils = RCH.GroupUtils

-- Localize globals
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local SetRaidSubgroup = SetRaidSubgroup
local SwapRaidSubgroup = SwapRaidSubgroup
local IsInRaid = IsInRaid
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant

-- Sorting modes
GroupUtils.SORT_MODES = {
    EVEN_DISTRIBUTION = "even",      -- Spread high vers evenly across groups
    HIGH_VERS_G3G4 = "high_g3g4",   -- DPS only in G3+G4, tanks/healers carry G1+G2
    HIGH_VERS_G4 = "high_g4",       -- Top DPS in G4 only, rest distributed
    CUSTOM = "custom",               -- Custom group assignments
}

-- Shared sort function for vers (descending)
local function sortByVersDesc(a, b)
    return a.vers > b.vers
end

-- Get current raid roster with roles and vers
function GroupUtils:GetRaidRoster()
    if not IsInRaid() then return {} end

    local roster = {}
    local numMembers = GetNumGroupMembers()

    for i = 1, numMembers do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)

        if name then
            -- Get vers from cache
            local vers, scanned = RCH.VersCache:GetVers(name)

            -- Get assigned role (TANK, HEALER, DAMAGER, NONE)
            local assignedRole = UnitGroupRolesAssigned("raid" .. i) or "NONE"

            table.insert(roster, {
                index = i,
                name = name,
                rank = rank,  -- 0 = normal, 1 = assistant, 2 = leader
                group = subgroup,
                level = level,
                class = class,
                classFile = fileName,
                online = online,
                isDead = isDead,
                role = assignedRole,
                vers = vers,
                versScanned = scanned,
            })
        end
    end

    return roster
end

-- Get roster organized by groups
function GroupUtils:GetRosterByGroup()
    local roster = self:GetRaidRoster()
    local groups = {}

    for i = 1, 8 do
        groups[i] = {}
    end

    for _, player in ipairs(roster) do
        local groupNum = player.group or 1
        table.insert(groups[groupNum], player)
    end

    return groups
end

-- Check if we can modify raid groups
function GroupUtils:CanModifyGroups()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Generate even distribution plan
-- Spreads high vers players evenly across all groups
function GroupUtils:PlanEvenDistribution(numGroups)
    numGroups = numGroups or 4
    local roster = self:GetRaidRoster()

    -- Separate by role
    local tanks = {}
    local healers = {}
    local dps = {}

    for _, player in ipairs(roster) do
        if player.role == "TANK" then
            table.insert(tanks, player)
        elseif player.role == "HEALER" then
            table.insert(healers, player)
        else
            table.insert(dps, player)
        end
    end

    -- Sort each role by vers (descending)
    table.sort(tanks, sortByVersDesc)
    table.sort(healers, sortByVersDesc)
    table.sort(dps, sortByVersDesc)

    -- Initialize groups
    local groups = {}
    for i = 1, numGroups do
        groups[i] = { players = {}, totalVers = 0 }
    end

    -- Distribute tanks evenly (usually 2-4 tanks)
    for i, player in ipairs(tanks) do
        local groupNum = ((i - 1) % numGroups) + 1
        table.insert(groups[groupNum].players, player)
        groups[groupNum].totalVers = groups[groupNum].totalVers + player.vers
    end

    -- Distribute healers evenly
    for i, player in ipairs(healers) do
        local groupNum = ((i - 1) % numGroups) + 1
        table.insert(groups[groupNum].players, player)
        groups[groupNum].totalVers = groups[groupNum].totalVers + player.vers
    end

    -- Distribute DPS using balanced approach (assign to lowest vers group)
    for _, player in ipairs(dps) do
        -- Find group with lowest total vers that has room
        local bestGroup = 1
        local lowestVers = math.huge

        for i = 1, numGroups do
            if #groups[i].players < 5 and groups[i].totalVers < lowestVers then
                lowestVers = groups[i].totalVers
                bestGroup = i
            end
        end

        table.insert(groups[bestGroup].players, player)
        groups[bestGroup].totalVers = groups[bestGroup].totalVers + player.vers
    end

    return groups
end

-- Minimum vers threshold for high vers groups
local HIGH_VERS_MINIMUM = 200

-- Generate high vers in G3+G4 plan (for splits)
-- G3+G4: High vers DPS only (200%+ vers, self-sufficient carry group)
-- G1+G2: Tanks, Healers, and lower vers DPS (tanks/healers + some high vers carry undergeared)
function GroupUtils:PlanHighVersG3G4(numGroups)
    numGroups = numGroups or 4
    local roster = self:GetRaidRoster()

    -- Separate by role
    local tanks = {}
    local healers = {}
    local dps = {}

    for _, player in ipairs(roster) do
        if player.role == "TANK" then
            table.insert(tanks, player)
        elseif player.role == "HEALER" then
            table.insert(healers, player)
        else
            table.insert(dps, player)
        end
    end

    -- Sort each role by vers (descending)
    table.sort(tanks, sortByVersDesc)
    table.sort(healers, sortByVersDesc)
    table.sort(dps, sortByVersDesc)

    -- Initialize groups
    local groups = {}
    for i = 1, numGroups do
        groups[i] = { players = {}, totalVers = 0 }
    end

    -- Helper to add player to lowest vers group from a list of allowed groups
    local function addToLowestVersGroup(player, allowedGroups)
        local bestGroup = allowedGroups[1]
        local lowestVers = math.huge

        for _, groupNum in ipairs(allowedGroups) do
            if #groups[groupNum].players < 5 and groups[groupNum].totalVers < lowestVers then
                lowestVers = groups[groupNum].totalVers
                bestGroup = groupNum
            end
        end

        table.insert(groups[bestGroup].players, player)
        groups[bestGroup].totalVers = groups[bestGroup].totalVers + player.vers
    end

    -- ALL tanks go to G1+G2 (high vers tanks carry the undergeared)
    for _, player in ipairs(tanks) do
        addToLowestVersGroup(player, { 1, 2 })
    end

    -- ALL healers go to G1+G2 (high vers healers carry the undergeared)
    for _, player in ipairs(healers) do
        addToLowestVersGroup(player, { 1, 2 })
    end

    -- Separate DPS into eligible (200%+) and ineligible (<200%) for high vers groups
    local eligibleDps = {}
    local ineligibleDps = {}

    for _, player in ipairs(dps) do
        if player.vers >= HIGH_VERS_MINIMUM then
            table.insert(eligibleDps, player)
        else
            table.insert(ineligibleDps, player)
        end
    end

    -- Calculate how many DPS slots available in G3+G4
    local g3Slots = 5 - #groups[3].players
    local g4Slots = 5 - #groups[4].players
    local highVersSlots = g3Slots + g4Slots

    -- Fill G3+G4 with top eligible DPS (but not all - leave some for carrying G1+G2)
    local assignedToHighVers = 0
    for i, player in ipairs(eligibleDps) do
        if assignedToHighVers < highVersSlots then
            -- High vers DPS go to G3+G4
            addToLowestVersGroup(player, { 3, 4 })
            assignedToHighVers = assignedToHighVers + 1
        else
            -- Remaining high vers DPS go to G1+G2 (to help carry)
            addToLowestVersGroup(player, { 1, 2 })
        end
    end

    -- All ineligible DPS (<200% vers) go to G1+G2
    for _, player in ipairs(ineligibleDps) do
        addToLowestVersGroup(player, { 1, 2 })
    end

    return groups
end

-- Generate high vers G4 only plan (single carry group)
-- G4: Top 5 high vers DPS (200%+ vers, self-sufficient)
-- G1-G3: Everyone else distributed evenly
function GroupUtils:PlanHighVersG4(numGroups)
    numGroups = numGroups or 4
    local roster = self:GetRaidRoster()

    -- Separate by role
    local tanks = {}
    local healers = {}
    local dps = {}

    for _, player in ipairs(roster) do
        if player.role == "TANK" then
            table.insert(tanks, player)
        elseif player.role == "HEALER" then
            table.insert(healers, player)
        else
            table.insert(dps, player)
        end
    end

    -- Sort by vers (descending)
    table.sort(tanks, sortByVersDesc)
    table.sort(healers, sortByVersDesc)
    table.sort(dps, sortByVersDesc)

    -- Initialize groups
    local groups = {}
    for i = 1, numGroups do
        groups[i] = { players = {}, totalVers = 0 }
    end

    -- Helper to add player to lowest vers group from a list
    local function addToLowestVersGroup(player, allowedGroups)
        local bestGroup = allowedGroups[1]
        local lowestVers = math.huge

        for _, groupNum in ipairs(allowedGroups) do
            if #groups[groupNum].players < 5 and groups[groupNum].totalVers < lowestVers then
                lowestVers = groups[groupNum].totalVers
                bestGroup = groupNum
            end
        end

        table.insert(groups[bestGroup].players, player)
        groups[bestGroup].totalVers = groups[bestGroup].totalVers + player.vers
    end

    -- Tanks go to G1-G3 (distributed)
    for _, player in ipairs(tanks) do
        addToLowestVersGroup(player, { 1, 2, 3 })
    end

    -- Healers go to G1-G3 (distributed)
    for _, player in ipairs(healers) do
        addToLowestVersGroup(player, { 1, 2, 3 })
    end

    -- Separate DPS into eligible (200%+) and ineligible (<200%)
    local eligibleDps = {}
    local ineligibleDps = {}

    for _, player in ipairs(dps) do
        if player.vers >= HIGH_VERS_MINIMUM then
            table.insert(eligibleDps, player)
        else
            table.insert(ineligibleDps, player)
        end
    end

    -- Top 5 eligible DPS go to G4
    local assignedToG4 = 0
    for _, player in ipairs(eligibleDps) do
        if assignedToG4 < 5 then
            table.insert(groups[4].players, player)
            groups[4].totalVers = groups[4].totalVers + player.vers
            assignedToG4 = assignedToG4 + 1
        else
            -- Remaining high vers DPS distributed in G1-G3
            addToLowestVersGroup(player, { 1, 2, 3 })
        end
    end

    -- All ineligible DPS (<200% vers) go to G1-G3
    for _, player in ipairs(ineligibleDps) do
        addToLowestVersGroup(player, { 1, 2, 3 })
    end

    return groups
end

-- Generate assignment plan based on mode
function GroupUtils:GeneratePlan(mode, numGroups)
    numGroups = numGroups or 4

    if mode == self.SORT_MODES.EVEN_DISTRIBUTION then
        return self:PlanEvenDistribution(numGroups)
    elseif mode == self.SORT_MODES.HIGH_VERS_G3G4 then
        return self:PlanHighVersG3G4(numGroups)
    elseif mode == self.SORT_MODES.HIGH_VERS_G4 then
        return self:PlanHighVersG4(numGroups)
    end

    return self:PlanEvenDistribution(numGroups)
end

-- Execute a plan (move players to assigned groups)
function GroupUtils:ExecutePlan(plan)
    if not self:CanModifyGroups() then
        RCH.Print("You must be raid leader or assistant to modify groups")
        return false
    end

    local moves = {}

    -- Build list of moves needed
    for groupNum, groupData in ipairs(plan) do
        for _, player in ipairs(groupData.players) do
            if player.group ~= groupNum then
                table.insert(moves, {
                    name = player.name,
                    index = player.index,
                    fromGroup = player.group,
                    toGroup = groupNum
                })
            end
        end
    end

    -- Execute moves
    for _, move in ipairs(moves) do
        SetRaidSubgroup(move.index, move.toGroup)
    end

    if #moves > 0 then
        RCH.Print("Moved " .. #moves .. " players to new groups")
    else
        RCH.Print("No moves needed - groups already optimal")
    end

    return true
end

-- Get summary statistics for current raid
function GroupUtils:GetRaidStats()
    local roster = self:GetRaidRoster()
    local stats = {
        total = #roster,
        tanks = 0,
        healers = 0,
        dps = 0,
        avgVers = 0,
        minVers = math.huge,
        maxVers = 0,
        scannedCount = 0,
    }

    local totalVers = 0

    for _, player in ipairs(roster) do
        if player.role == "TANK" then
            stats.tanks = stats.tanks + 1
        elseif player.role == "HEALER" then
            stats.healers = stats.healers + 1
        else
            stats.dps = stats.dps + 1
        end

        if player.versScanned then
            stats.scannedCount = stats.scannedCount + 1
            totalVers = totalVers + player.vers
            if player.vers < stats.minVers then
                stats.minVers = player.vers
            end
            if player.vers > stats.maxVers then
                stats.maxVers = player.vers
            end
        end
    end

    if stats.scannedCount > 0 then
        stats.avgVers = totalVers / stats.scannedCount
    end

    if stats.minVers == math.huge then
        stats.minVers = 0
    end

    return stats
end

-- Get group summary (vers per group)
function GroupUtils:GetGroupStats()
    local groups = self:GetRosterByGroup()
    local stats = {}

    for i = 1, 8 do
        local group = groups[i]
        local totalVers = 0
        local count = 0

        for _, player in ipairs(group) do
            totalVers = totalVers + (RCH.VersCache:GetVers(player.name) or 0)
            count = count + 1
        end

        stats[i] = {
            count = count,
            totalVers = totalVers,
            avgVers = count > 0 and (totalVers / count) or 0
        }
    end

    return stats
end

-- Format vers as percentage string
function GroupUtils:FormatVers(vers)
    return string.format("%.1f%%", vers)
end

-- Get class color (uses WoW's built-in RAID_CLASS_COLORS when available)
function GroupUtils:GetClassColor(classFile)
    -- Prefer WoW's built-in class colors
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function GroupUtils:GetClassColorHex(classFile)
    local r, g, b = self:GetClassColor(classFile)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end
