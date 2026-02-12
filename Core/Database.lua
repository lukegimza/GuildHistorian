local GH, ns = ...

local Database = {}
ns.Database = Database

local Utils = ns.Utils

-- Write queue for batched flushes
local writeQueue = {}
local dedupCache = {}

--- Initialize the database module
function Database:Init(db)
    self.db = db
    self:RunMigrations()
end

--- Get the guild data table for the current guild, creating if needed
--- @return table|nil
function Database:GetGuildData()
    local key = Utils.GetGuildKey()
    if not key then return nil end

    local guilds = self.db.global.guilds
    if not guilds[key] then
        guilds[key] = {
            events = {},
            firstKills = {},
            rosterSnapshot = {},
            memberHistory = {},
            achievementPoints = 0,
            lastRosterScan = 0,
        }
    end
    return guilds[key]
end

--- Get the guild key (pass-through for convenience)
--- @return string|nil
function Database:GetGuildKey()
    return Utils.GetGuildKey()
end

--- Queue an event for writing
--- @param event table The event data
--- @return boolean Whether the event was queued (false if duplicate)
function Database:QueueEvent(event)
    if not event or not event.type or not event.timestamp then
        return false
    end

    -- Build dedup key
    local dedupKey = event.dedupKey
    if not dedupKey then
        dedupKey = Utils.BuildDedupKey(event.type, event.timestamp,
            event.key1, event.key2, event.key3)
        event.dedupKey = dedupKey
    end

    -- Check dedup cache (in-memory)
    if dedupCache[dedupKey] then
        return false
    end

    -- Check existing events
    local guildData = self:GetGuildData()
    if not guildData then return false end

    for _, existing in ipairs(guildData.events) do
        if existing.dedupKey == dedupKey then
            dedupCache[dedupKey] = true
            return false
        end
    end

    dedupCache[dedupKey] = true
    writeQueue[#writeQueue + 1] = event
    return true
end

--- Flush the write queue to the database
function Database:Flush()
    if #writeQueue == 0 then return end

    local guildData = self:GetGuildData()
    if not guildData then
        wipe(writeQueue)
        return
    end

    local events = guildData.events
    for _, event in ipairs(writeQueue) do
        -- Insert at the beginning (descending timestamp order)
        tinsert(events, 1, event)
    end

    local flushed = #writeQueue
    wipe(writeQueue)

    -- Prune if over limit
    self:PruneEvents(guildData)

    -- Fire update notification
    if ns.addon then
        ns.addon:SendMessage("GH_EVENTS_UPDATED", flushed)
    end
end

--- Prune events to stay under the max limit
--- @param guildData table
function Database:PruneEvents(guildData)
    if not guildData then return end
    local maxEvents = ns.addon and ns.addon.db.profile.data.maxEvents or ns.MAX_EVENTS_DEFAULT
    local events = guildData.events
    while #events > maxEvents do
        tremove(events)  -- Remove oldest (last item since sorted descending)
    end
end

--- Get all events, optionally filtered
--- @param filters table|nil Optional filter criteria
--- @return table Array of events
function Database:GetEvents(filters)
    local guildData = self:GetGuildData()
    if not guildData then return {} end

    local events = guildData.events
    if not filters then return events end

    local filtered = {}
    for _, event in ipairs(events) do
        if self:MatchesFilters(event, filters) then
            filtered[#filtered + 1] = event
        end
    end
    return filtered
end

--- Check if an event matches the given filters
--- @param event table
--- @param filters table
--- @return boolean
function Database:MatchesFilters(event, filters)
    -- Type filter
    if filters.types and next(filters.types) then
        if not filters.types[event.type] then
            return false
        end
    end

    -- Date range filter
    if filters.startDate and event.timestamp < filters.startDate then
        return false
    end
    if filters.endDate and event.timestamp > filters.endDate then
        return false
    end

    -- Difficulty filter
    if filters.difficultyID and event.difficultyID then
        if event.difficultyID ~= filters.difficultyID then
            return false
        end
    end

    -- Text search filter
    if filters.search and filters.search ~= "" then
        local searchLower = strlower(filters.search)
        local title = event.title and strlower(event.title) or ""
        local desc = event.description and strlower(event.description) or ""
        local player = event.playerName and strlower(event.playerName) or ""
        if not (strfind(title, searchLower, 1, true) or
                strfind(desc, searchLower, 1, true) or
                strfind(player, searchLower, 1, true)) then
            return false
        end
    end

    return true
end

--- Record a first kill
--- @param encounterID number
--- @param difficultyID number
--- @return boolean Whether this is actually a first kill
function Database:RecordFirstKill(encounterID, difficultyID)
    local guildData = self:GetGuildData()
    if not guildData then return false end

    local key = encounterID .. "-" .. difficultyID
    if guildData.firstKills[key] then
        return false
    end
    guildData.firstKills[key] = GetServerTime()
    return true
end

--- Save a roster snapshot
--- @param snapshot table
function Database:SaveRosterSnapshot(snapshot)
    local guildData = self:GetGuildData()
    if not guildData then return end
    guildData.rosterSnapshot = snapshot
    guildData.lastRosterScan = GetServerTime()
end

--- Get the last roster snapshot
--- @return table, number snapshot and timestamp
function Database:GetRosterSnapshot()
    local guildData = self:GetGuildData()
    if not guildData then return {}, 0 end
    return guildData.rosterSnapshot or {}, guildData.lastRosterScan or 0
end

--- Update member history tracking
--- @param name string "Name-Realm"
--- @param action string "join" or "leave"
function Database:UpdateMemberHistory(name, action)
    local guildData = self:GetGuildData()
    if not guildData then return end

    if not guildData.memberHistory[name] then
        guildData.memberHistory[name] = {}
    end

    local history = guildData.memberHistory[name]
    if action == "join" then
        history.firstSeen = history.firstSeen or GetServerTime()
        history.lastSeen = GetServerTime()
        history.isActive = true
    elseif action == "leave" then
        history.lastSeen = GetServerTime()
        history.isActive = false
    end
end

--- Get statistics for the Statistics panel
--- @return table
function Database:GetStats()
    local guildData = self:GetGuildData()
    if not guildData then
        return {
            totalEvents = 0,
            firstKills = 0,
            membersTracked = 0,
            activeMembers = 0,
            eventsByType = {},
            mostActive = {},
            longestServing = {},
            oldestEvent = nil,
        }
    end

    local stats = {
        totalEvents = #guildData.events,
        firstKills = 0,
        membersTracked = 0,
        activeMembers = 0,
        eventsByType = {},
        mostActive = {},
        longestServing = {},
        oldestEvent = nil,
    }

    -- Count first kills
    for _ in pairs(guildData.firstKills) do
        stats.firstKills = stats.firstKills + 1
    end

    -- Count members
    local memberEventCount = {}
    for _, history in pairs(guildData.memberHistory) do
        stats.membersTracked = stats.membersTracked + 1
        if history.isActive then
            stats.activeMembers = stats.activeMembers + 1
        end
    end

    -- Events by type and member activity
    for _, event in ipairs(guildData.events) do
        stats.eventsByType[event.type] = (stats.eventsByType[event.type] or 0) + 1

        if event.playerName then
            memberEventCount[event.playerName] = (memberEventCount[event.playerName] or 0) + 1
        end

        -- Track oldest event
        if not stats.oldestEvent or event.timestamp < stats.oldestEvent then
            stats.oldestEvent = event.timestamp
        end
    end

    -- Most active members (top 5)
    local activeList = {}
    for name, count in pairs(memberEventCount) do
        activeList[#activeList + 1] = { name = name, count = count }
    end
    table.sort(activeList, function(a, b) return a.count > b.count end)
    for i = 1, math.min(5, #activeList) do
        stats.mostActive[i] = activeList[i]
    end

    -- Longest serving members (top 5)
    local servingList = {}
    for name, history in pairs(guildData.memberHistory) do
        if history.firstSeen then
            servingList[#servingList + 1] = { name = name, firstSeen = history.firstSeen }
        end
    end
    table.sort(servingList, function(a, b) return a.firstSeen < b.firstSeen end)
    for i = 1, math.min(5, #servingList) do
        stats.longestServing[i] = servingList[i]
    end

    return stats
end

--- Purge all data for the current guild
function Database:PurgeGuildData()
    local key = Utils.GetGuildKey()
    if not key then return false end

    self.db.global.guilds[key] = nil
    wipe(writeQueue)
    wipe(dedupCache)

    if ns.addon then
        ns.addon:SendMessage("GH_EVENTS_UPDATED", 0)
    end
    return true
end

--- Run database migrations
function Database:RunMigrations()
    local currentVersion = self.db.global.dbVersion or 0
    if currentVersion >= ns.DB_VERSION then return end

    -- Migration v0 -> v1: initial structure (no changes needed for fresh installs)
    if currentVersion < 1 then
        self.db.global.dbVersion = 1
    end
end

--- Get the total event count for the current guild
--- @return number
function Database:GetEventCount()
    local guildData = self:GetGuildData()
    if not guildData then return 0 end
    return #guildData.events
end

--- Search events by text
--- @param query string
--- @return table
function Database:SearchEvents(query)
    return self:GetEvents({ search = query })
end
