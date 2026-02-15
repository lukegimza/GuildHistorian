--- API-driven data reader modules for GuildHistorian.
-- Provides four stateless reader classes that cache results from WoW's
-- server-side APIs: AchievementScanner, NewsReader, RosterReader, and
-- EventLogReader. Each module exposes a Read/Scan entry point, filtered
-- view methods, and an Invalidate method to force a cache refresh.
-- @module DataModules

local GH, ns = ...

local Utils = ns.Utils
local floor = math.floor
local date = date
local time = time
local tinsert = tinsert
local ipairs = ipairs
local pairs = pairs
local format = format

-------------------------------------------------------------------------------
-- AchievementScanner
-- Scans guild achievement categories and builds a cached, sorted list of
-- completed guild achievements with real completion dates.
-------------------------------------------------------------------------------
local AchievementScanner = {}
ns.AchievementScanner = AchievementScanner

local achievementCache = nil
local statsCache = nil

--- Scan all guild achievement categories and return completed achievements.
-- Results are sorted by timestamp descending (newest first) and cached
-- until Invalidate is called or forceRefresh is true.
---@param forceRefresh boolean|nil When true, discard the cache and re-scan
---@return table[] achievements Array of {id, name, description, points, icon, timestamp, month, day, year}
function AchievementScanner:Scan(forceRefresh)
    if achievementCache and not forceRefresh then
        return achievementCache
    end

    if not IsInGuild() then
        achievementCache = {}
        statsCache = nil
        return achievementCache
    end

    local results = {}
    local totalPoints = 0
    local earnedPoints = 0
    local totalCount = 0
    local earnedCount = 0

    local categoryIDs = GetCategoryList()
    for _, catID in ipairs(categoryIDs) do
        local numAchievements = GetCategoryNumAchievements(catID, true)
        for i = 1, numAchievements do
            local achievementID = GetCategoryAchievementID(catID, i)
            if achievementID then
                local id, name, points, completed, month, day, year,
                      description, flags, icon, _, isGuild = GetAchievementInfo(achievementID)
                if isGuild then
                    totalCount = totalCount + 1
                    totalPoints = totalPoints + (points or 0)
                    if completed then
                        earnedCount = earnedCount + 1
                        earnedPoints = earnedPoints + (points or 0)
                        local timestamp = Utils.DateToTimestamp(month, day, year)
                        tinsert(results, {
                            id = id,
                            name = name,
                            description = description,
                            points = points,
                            icon = icon,
                            timestamp = timestamp,
                            month = month,
                            day = day,
                            year = year,
                        })
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return a.timestamp > b.timestamp
    end)

    achievementCache = results
    statsCache = {
        totalPoints = totalPoints,
        earnedPoints = earnedPoints,
        totalCount = totalCount,
        earnedCount = earnedCount,
        completionPct = totalCount > 0 and floor((earnedCount / totalCount) * 100) or 0,
    }

    return achievementCache
end

--- Return aggregate achievement statistics for the guild.
-- Triggers a scan if the cache is empty.
---@return table stats {totalPoints, earnedPoints, totalCount, earnedCount, completionPct}
function AchievementScanner:GetStats()
    if not statsCache then
        self:Scan()
    end
    return statsCache
end

--- Find guild achievements completed on today's calendar date in prior years.
---@return table[] matches Array of {name, description, points, icon, yearsAgo, timestamp}
function AchievementScanner:GetOnThisDay()
    local cache = self:Scan()
    local now = GetServerTime()
    local todayMonth, todayDay = Utils.TimestampToMonthDay(now)
    local thisYear = Utils.TimestampToYear(now)

    local matches = {}
    for _, ach in ipairs(cache) do
        local achMonth, achDay = Utils.TimestampToMonthDay(ach.timestamp)
        local achYear = Utils.TimestampToYear(ach.timestamp)
        if achMonth == todayMonth and achDay == todayDay and achYear < thisYear then
            tinsert(matches, {
                name = ach.name,
                description = ach.description,
                points = ach.points,
                icon = ach.icon,
                yearsAgo = thisYear - achYear,
                timestamp = ach.timestamp,
            })
        end
    end

    return matches
end

--- Compute per-category completion percentages for guild achievements.
-- Results are sorted by completion percentage descending.
---@return table[] categories Array of {categoryName, earned, total, pct}
function AchievementScanner:GetCategoryProgress()
    if not IsInGuild() then return {} end

    local categories = {}
    local categoryIDs = GetCategoryList()

    for _, catID in ipairs(categoryIDs) do
        local catName = GetCategoryInfo(catID)
        local numAchievements = GetCategoryNumAchievements(catID, true)
        local earned = 0
        local total = 0

        for i = 1, numAchievements do
            local achievementID = GetCategoryAchievementID(catID, i)
            if achievementID then
                local _, _, _, completed, _, _, _, _, _, _, _, isGuild = GetAchievementInfo(achievementID)
                if isGuild then
                    total = total + 1
                    if completed then
                        earned = earned + 1
                    end
                end
            end
        end

        if total > 0 then
            tinsert(categories, {
                categoryName = catName,
                earned = earned,
                total = total,
                pct = floor((earned / total) * 100),
            })
        end
    end

    table.sort(categories, function(a, b)
        return a.pct > b.pct
    end)

    return categories
end

--- Clear the achievement and stats caches, forcing a fresh scan on next access.
function AchievementScanner:Invalidate()
    achievementCache = nil
    statsCache = nil
end

-------------------------------------------------------------------------------
-- NewsReader
-- Reads the guild news feed from WoW API.
-------------------------------------------------------------------------------
local NewsReader = {}
ns.NewsReader = NewsReader

local newsCache = nil

--- Read the guild news feed and return formatted entries.
-- Calls QueryGuildNews() to request data, then reads via C_GuildInfo.GetGuildNewsInfo.
---@param forceRefresh boolean|nil When true, discard the cache and re-query
---@return table[] entries Array of {newsType, who, what, dataID, timestamp, membersPresent, typeInfo}
function NewsReader:Read(forceRefresh)
    if newsCache and not forceRefresh then
        return newsCache
    end

    if not IsInGuild() then
        newsCache = {}
        return newsCache
    end

    QueryGuildNews()

    local results = {}
    local numNews = GetNumGuildNews()
    for i = 1, numNews do
        local entry = C_GuildInfo.GetGuildNewsInfo(i)
        if entry then
            local timestamp = 0
            if entry.month and entry.day and entry.year then
                timestamp = Utils.DateToTimestamp(entry.month, entry.day, entry.year)
            end

            local typeInfo = nil
            if ns.NEWS_TYPE_INFO and entry.newsType then
                typeInfo = ns.NEWS_TYPE_INFO[entry.newsType]
            end

            tinsert(results, {
                newsType = entry.newsType,
                who = entry.whoText or "",
                what = entry.whatText or "",
                dataID = entry.newsDataID,
                timestamp = timestamp,
                membersPresent = entry.guildMembersPresent or 0,
                typeInfo = typeInfo,
            })
        end
    end

    newsCache = results
    return newsCache
end

--- Summarise the current news cache by counting entries per news type.
---@return table<number, number> summary Map of newsType ID to occurrence count
function NewsReader:GetSummary()
    local cache = self:Read()
    local summary = {}
    for _, entry in ipairs(cache) do
        local nt = entry.newsType
        summary[nt] = (summary[nt] or 0) + 1
    end
    return summary
end

--- Clear the news cache, forcing a fresh query on next access.
function NewsReader:Invalidate()
    newsCache = nil
end

-------------------------------------------------------------------------------
-- RosterReader
-- Reads the guild roster and provides filtered views.
-------------------------------------------------------------------------------
local RosterReader = {}
ns.RosterReader = RosterReader

local rosterCache = nil

--- Read the full guild roster into a cached array.
---@param forceRefresh boolean|nil When true, discard the cache and re-read
---@return table[] members Array of member records with name, rank, level, class, etc.
function RosterReader:Read(forceRefresh)
    if rosterCache and not forceRefresh then
        return rosterCache
    end

    if not IsInGuild() then
        rosterCache = {}
        return rosterCache
    end

    local results = {}
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, rank, rankIndex, level, classDisplayName, zone,
              publicNote, officerNote, online, status, class,
              achievementPoints = GetGuildRosterInfo(i)
        if name then
            tinsert(results, {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
                level = level,
                classDisplayName = classDisplayName,
                zone = zone,
                publicNote = publicNote,
                officerNote = officerNote,
                online = online,
                status = status,
                class = class,
                achievementPoints = achievementPoints,
            })
        end
    end

    rosterCache = results
    return rosterCache
end

--- Return only online members at max level.
---@return table[] members Filtered subset of the roster cache
function RosterReader:GetOnlineMaxLevel()
    local cache = self:Read()
    local maxLevel = GetMaxPlayerLevel()
    local results = {}
    for _, member in ipairs(cache) do
        if member.online and member.level == maxLevel then
            tinsert(results, member)
        end
    end
    return results
end

--- Count online max-level members grouped by class token.
---@return table<string, number> composition Map of class token to member count
function RosterReader:GetClassComposition()
    local online = self:GetOnlineMaxLevel()
    local composition = {}
    for _, member in ipairs(online) do
        local cls = member.class
        composition[cls] = (composition[cls] or 0) + 1
    end
    return composition
end

--- Return the top N guild members ranked by achievement points.
---@param count number|nil Number of members to return (default 5)
---@return table[] achievers Sorted array of member records, highest points first
function RosterReader:GetTopAchievers(count)
    local cache = self:Read()
    local sorted = {}
    for _, member in ipairs(cache) do
        tinsert(sorted, member)
    end
    table.sort(sorted, function(a, b)
        return a.achievementPoints > b.achievementPoints
    end)
    local results = {}
    for i = 1, math.min(count or 5, #sorted) do
        tinsert(results, sorted[i])
    end
    return results
end

--- Return total and online member counts.
---@return table counts {total: number, online: number}
function RosterReader:GetCounts()
    local cache = self:Read()
    local online = 0
    for _, member in ipairs(cache) do
        if member.online then
            online = online + 1
        end
    end
    return {
        total = #cache,
        online = online,
    }
end

--- Clear the roster cache, forcing a fresh read on next access.
function RosterReader:Invalidate()
    rosterCache = nil
end

-------------------------------------------------------------------------------
-- EventLogReader
-- Reads the guild event log.
-------------------------------------------------------------------------------
local EventLogReader = {}
ns.EventLogReader = EventLogReader

local eventLogCache = nil

--- Build a human-readable description for a guild event log entry.
---@param eventType string Event type key ("invite", "join", "promote", etc.)
---@param playerName string|nil Name of the acting player
---@param targetName string|nil Name of the affected player (invites, removes)
---@param rankIndex number|nil Guild rank index for promotions/demotions
---@return string text Formatted event description
local function formatEventText(eventType, playerName, targetName, rankIndex)
    if eventType == "invite" then
        return format("%s invited %s to the guild", playerName or "Unknown", targetName or "Unknown")
    elseif eventType == "join" then
        return format("%s joined the guild", playerName or "Unknown")
    elseif eventType == "promote" then
        return format("%s was promoted to rank %d", playerName or "Unknown", rankIndex or 0)
    elseif eventType == "demote" then
        return format("%s was demoted to rank %d", playerName or "Unknown", rankIndex or 0)
    elseif eventType == "remove" then
        return format("%s was removed from the guild by %s", targetName or "Unknown", playerName or "Unknown")
    elseif eventType == "quit" then
        return format("%s left the guild", playerName or "Unknown")
    else
        return format("%s: %s", eventType or "unknown", playerName or "Unknown")
    end
end

--- Read the guild event log and return formatted entries.
-- Queries QueryGuildEventLog and caches the result until invalidated.
---@param forceRefresh boolean|nil When true, discard the cache and re-read
---@return table[] events Array of {eventType, playerName, targetName, rankIndex, timestamp, formattedText}
function EventLogReader:Read(forceRefresh)
    if eventLogCache and not forceRefresh then
        return eventLogCache
    end

    if not IsInGuild() then
        eventLogCache = {}
        return eventLogCache
    end

    QueryGuildEventLog()

    local results = {}
    local numEvents = GetNumGuildEvents()
    for i = 1, numEvents do
        local eventType, playerName, targetName, rankIndex, timestamp = GetGuildEventInfo(i)
        if eventType then
            tinsert(results, {
                eventType = eventType,
                playerName = playerName,
                targetName = targetName,
                rankIndex = rankIndex,
                timestamp = timestamp,
                formattedText = formatEventText(eventType, playerName, targetName, rankIndex),
            })
        end
    end

    eventLogCache = results
    return eventLogCache
end

--- Clear the event log cache, forcing a fresh read on next access.
function EventLogReader:Invalidate()
    eventLogCache = nil
end
