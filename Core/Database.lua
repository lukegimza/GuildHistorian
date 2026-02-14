local GH, ns = ...

local Database = {}
ns.Database = Database

local Utils = ns.Utils

local format = format
local ipairs = ipairs
local pairs = pairs
local strlower = strlower
local strfind = strfind
local tostring = tostring

local writeQueue = {}
local dedupIndex = {}

function Database:Init(db)
    self.db = db
    self:RunMigrations()
end

function Database:ResetCaches()
    wipe(writeQueue)
    wipe(dedupIndex)
end

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

function Database:GetGuildKey()
    return Utils.GetGuildKey()
end

function Database:BuildDedupIndex(guildData)
    wipe(dedupIndex)
    for _, event in ipairs(guildData.events) do
        if event.dedupKey then
            dedupIndex[event.dedupKey] = true
        end
    end
end

function Database:QueueEvent(event)
    if not event or not event.type or not event.timestamp then
        return false
    end

    local dedupKey = event.dedupKey
    if not dedupKey then
        dedupKey = Utils.BuildDedupKey(event.type, event.timestamp,
            event.key1, event.key2, event.key3)
        event.dedupKey = dedupKey
    end

    if dedupIndex[dedupKey] then
        return false
    end

    local guildData = self:GetGuildData()
    if not guildData then return false end

    if not next(dedupIndex) and #guildData.events > 0 then
        self:BuildDedupIndex(guildData)
        if dedupIndex[dedupKey] then
            return false
        end
    end

    dedupIndex[dedupKey] = true
    writeQueue[#writeQueue + 1] = event
    return true
end

function Database:Flush()
    if #writeQueue == 0 then return end

    local guildData = self:GetGuildData()
    if not guildData then
        wipe(writeQueue)
        return
    end

    local events = guildData.events
    for _, event in ipairs(writeQueue) do
        tinsert(events, 1, event)
    end

    if ns.addon then
        for _, event in ipairs(writeQueue) do
            if event.type == ns.EVENT_TYPES.MILESTONE and event.title then
                ns.addon:Print(format("|cffff8000[Guild Historian]|r %s", event.title))
            elseif event.type == ns.EVENT_TYPES.FIRST_KILL and event.title then
                ns.addon:Print(format("|cffffd700[Guild Historian]|r %s", event.title))
            end
        end
    end

    local flushed = #writeQueue
    wipe(writeQueue)

    self:PruneEvents(guildData)

    if ns.addon then
        ns.addon:SendMessage("GH_EVENTS_UPDATED", flushed)
    end
end

function Database:PruneEvents(guildData)
    if not guildData then return end
    local maxEvents = ns.addon and ns.addon.db.profile.data.maxEvents or ns.MAX_EVENTS_DEFAULT
    local events = guildData.events
    while #events > maxEvents do
        tremove(events)
    end
end

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

function Database:MatchesFilters(event, filters)
    if filters.types and next(filters.types) then
        if not filters.types[event.type] then
            return false
        end
    end

    if filters.startDate and event.timestamp < filters.startDate then
        return false
    end
    if filters.endDate and event.timestamp > filters.endDate then
        return false
    end

    if filters.difficultyID and event.difficultyID then
        if event.difficultyID ~= filters.difficultyID then
            return false
        end
    end

    if filters.filterMonth and filters.filterDay then
        local eventMonth, eventDay = Utils.TimestampToMonthDay(event.timestamp)
        if eventMonth ~= filters.filterMonth or eventDay ~= filters.filterDay then
            return false
        end
    end

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

function Database:RecordFirstKill(encounterID, difficultyID)
    local guildData = self:GetGuildData()
    if not guildData then return false end

    local key = encounterID .. "-" .. (difficultyID or 0)
    if guildData.firstKills[key] then
        return false
    end
    guildData.firstKills[key] = GetServerTime()
    return true
end

function Database:SaveRosterSnapshot(snapshot)
    local guildData = self:GetGuildData()
    if not guildData then return end
    guildData.rosterSnapshot = snapshot
    guildData.lastRosterScan = GetServerTime()
end

function Database:GetRosterSnapshot()
    local guildData = self:GetGuildData()
    if not guildData then return {}, 0 end
    return guildData.rosterSnapshot or {}, guildData.lastRosterScan or 0
end

function Database:UpdateMemberHistory(name, action)
    local guildData = self:GetGuildData()
    if not guildData then return end

    if not guildData.memberHistory[name] then
        guildData.memberHistory[name] = {}
    end

    local history = guildData.memberHistory[name]
    local now = GetServerTime()

    if action == "join" then
        history.firstSeen = history.firstSeen or now
        history.lastSeen = now
        history.isActive = true
    elseif action == "leave" then
        history.lastSeen = now
        history.isActive = false
    end
end

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

    for _ in pairs(guildData.firstKills) do
        stats.firstKills = stats.firstKills + 1
    end

    local memberEventCount = {}
    for _, history in pairs(guildData.memberHistory) do
        stats.membersTracked = stats.membersTracked + 1
        if history.isActive then
            stats.activeMembers = stats.activeMembers + 1
        end
    end

    for _, event in ipairs(guildData.events) do
        stats.eventsByType[event.type] = (stats.eventsByType[event.type] or 0) + 1

        if event.playerName then
            memberEventCount[event.playerName] = (memberEventCount[event.playerName] or 0) + 1
        end

        if not stats.oldestEvent or event.timestamp < stats.oldestEvent then
            stats.oldestEvent = event.timestamp
        end
    end

    local activeList = {}
    for name, count in pairs(memberEventCount) do
        activeList[#activeList + 1] = { name = name, count = count }
    end
    table.sort(activeList, function(a, b) return a.count > b.count end)
    for i = 1, math.min(5, #activeList) do
        stats.mostActive[i] = activeList[i]
    end

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

function Database:RunMigrations()
    local currentVersion = self.db.global.dbVersion or 0
    if currentVersion >= ns.DB_VERSION then return end

    if currentVersion < 1 then
        self.db.global.dbVersion = 1
    end
end

function Database:GetEventCount()
    local guildData = self:GetGuildData()
    if not guildData then return 0 end
    return #guildData.events
end

function Database:SearchEvents(query)
    return self:GetEvents({ search = query })
end
