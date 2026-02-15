-------------------------------------------------------------------------------
-- Unit Tests: Core/DataModules.lua
-- Tests for AchievementScanner, NewsReader, RosterReader, EventLogReader
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

-------------------------------------------------------------------------------
-- AchievementScanner
-------------------------------------------------------------------------------

describe("AchievementScanner:Scan", function()
    beforeEach(function()
        MockState:Reset()
        ns.AchievementScanner:Invalidate()
        -- Set up two categories with guild achievements
        MockState.achievementCategories = {
            {
                id = 15076, name = "Guild", numAchievements = 3,
                achievementIDs = {5362, 5363, 5364},
            },
        }
        MockState.guildAchievements = {
            [5362] = { name = "Stay Classy", points = 25, completed = true, month = 6, day = 15, year = 23, description = "Have classy members", icon = 100, isGuild = true },
            [5363] = { name = "Guild Level 5", points = 10, completed = true, month = 1, day = 10, year = 24, description = "Reach guild level 5", icon = 101, isGuild = true },
            [5364] = { name = "Horde Slayer", points = 50, completed = false, month = nil, day = nil, year = nil, description = "Kill horde", icon = 102, isGuild = true },
        }
    end)

    it("should return completed guild achievements", function()
        local results = ns.AchievementScanner:Scan()
        A.isTable(results)
        A.arrayLength(2, results)
    end)

    it("should sort by timestamp descending (newest first)", function()
        local results = ns.AchievementScanner:Scan()
        A.isTrue(results[1].timestamp > results[2].timestamp,
            "First result should have a newer timestamp than second")
        A.equals("Guild Level 5", results[1].name)
        A.equals("Stay Classy", results[2].name)
    end)

    it("should include real completion dates from API", function()
        local results = ns.AchievementScanner:Scan()
        -- Guild Level 5 is first (newer)
        A.isTrue(results[1].timestamp > 0, "Timestamp should be > 0")
        A.equals(1, results[1].month)
        A.equals(10, results[1].day)
        A.equals(24, results[1].year)
    end)

    it("should include achievement details", function()
        local results = ns.AchievementScanner:Scan()
        local ach = results[1]
        A.equals("Guild Level 5", ach.name)
        A.equals(10, ach.points)
        A.equals("Reach guild level 5", ach.description)
        A.equals(101, ach.icon)
        A.isNumber(ach.id)
    end)

    it("should cache results on second call", function()
        local r1 = ns.AchievementScanner:Scan()
        -- Modify mock data; cached result should persist
        MockState.guildAchievements[5362].name = "Changed"
        local r2 = ns.AchievementScanner:Scan()
        A.equals(r1, r2, "Second call should return same cached table")
        A.equals("Stay Classy", r2[2].name, "Should still have original name from cache")
    end)

    it("should re-scan on forceRefresh", function()
        ns.AchievementScanner:Scan()
        MockState.guildAchievements[5362].name = "Changed"
        local results = ns.AchievementScanner:Scan(true)
        A.equals("Changed", results[2].name, "Should have updated name after force refresh")
    end)

    it("should return empty when not in guild", function()
        MockState.inGuild = false
        local results = ns.AchievementScanner:Scan()
        A.arrayLength(0, results)
    end)
end)

describe("AchievementScanner:GetStats", function()
    beforeEach(function()
        MockState:Reset()
        ns.AchievementScanner:Invalidate()
        MockState.achievementCategories = {
            {
                id = 15076, name = "Guild", numAchievements = 3,
                achievementIDs = {5362, 5363, 5364},
            },
        }
        MockState.guildAchievements = {
            [5362] = { name = "Stay Classy", points = 25, completed = true, month = 6, day = 15, year = 23, description = "desc", icon = 100, isGuild = true },
            [5363] = { name = "Guild Level 5", points = 10, completed = true, month = 1, day = 10, year = 24, description = "desc", icon = 101, isGuild = true },
            [5364] = { name = "Horde Slayer", points = 50, completed = false, description = "desc", icon = 102, isGuild = true },
        }
    end)

    it("should return total and earned points", function()
        local stats = ns.AchievementScanner:GetStats()
        A.equals(85, stats.totalPoints)
        A.equals(35, stats.earnedPoints)
    end)

    it("should return total and earned counts", function()
        local stats = ns.AchievementScanner:GetStats()
        A.equals(3, stats.totalCount)
        A.equals(2, stats.earnedCount)
    end)

    it("should return completion percentage", function()
        local stats = ns.AchievementScanner:GetStats()
        A.equals(66, stats.completionPct, "2/3 = 66%")
    end)
end)

describe("AchievementScanner:GetOnThisDay", function()
    beforeEach(function()
        MockState:Reset()
        ns.AchievementScanner:Invalidate()

        -- Get today's month and day from the mock server time
        local now = MockState.serverTime
        local d = os.date("*t", now)
        local todayMonth = d.month
        local todayDay = d.day

        MockState.achievementCategories = {
            {
                id = 15076, name = "Guild", numAchievements = 2,
                achievementIDs = {5362, 5363},
            },
        }
        -- Achievement completed on this day but a previous year
        -- year field in WoW is year-2000, so for e.g. 2022 it's 22
        MockState.guildAchievements = {
            [5362] = {
                name = "Old Achievement", points = 10, completed = true,
                month = todayMonth, day = todayDay, year = 20,
                description = "From 2020", icon = 100, isGuild = true,
            },
            [5363] = {
                name = "Different Day", points = 10, completed = true,
                month = 1, day = 1, year = 20,
                description = "Jan 1", icon = 101, isGuild = true,
            },
        }
    end)

    it("should find achievements completed on today's date in a previous year", function()
        local matches = ns.AchievementScanner:GetOnThisDay()
        -- Only 5362 should match (same month/day, different year)
        -- 5363 might match if today is Jan 1 but we check at least 5362 is found
        local found = false
        for _, m in ipairs(matches) do
            if m.name == "Old Achievement" then
                found = true
                A.isTrue(m.yearsAgo > 0, "yearsAgo should be positive")
            end
        end
        A.isTrue(found, "Should find the achievement from a previous year on this date")
    end)

    it("should include yearsAgo in results", function()
        local matches = ns.AchievementScanner:GetOnThisDay()
        for _, m in ipairs(matches) do
            if m.name == "Old Achievement" then
                A.isNumber(m.yearsAgo)
                A.isTrue(m.yearsAgo > 0)
            end
        end
    end)
end)

describe("AchievementScanner:GetCategoryProgress", function()
    beforeEach(function()
        MockState:Reset()
        ns.AchievementScanner:Invalidate()
        MockState.achievementCategories = {
            {
                id = 15076, name = "Guild",
                numAchievements = 2,
                achievementIDs = {5362, 5363},
            },
            {
                id = 15077, name = "PvP",
                numAchievements = 1,
                achievementIDs = {5364},
            },
        }
        MockState.guildAchievements = {
            [5362] = { name = "A1", points = 10, completed = true, month = 1, day = 1, year = 23, isGuild = true },
            [5363] = { name = "A2", points = 10, completed = false, isGuild = true },
            [5364] = { name = "A3", points = 10, completed = true, month = 2, day = 2, year = 23, isGuild = true },
        }
    end)

    it("should return category progress sorted by pct descending", function()
        local progress = ns.AchievementScanner:GetCategoryProgress()
        A.isTable(progress)
        A.arrayLength(2, progress)
        -- PvP has 100% (1/1), Guild has 50% (1/2)
        A.equals("PvP", progress[1].categoryName)
        A.equals(100, progress[1].pct)
        A.equals("Guild", progress[2].categoryName)
        A.equals(50, progress[2].pct)
    end)

    it("should include earned and total counts", function()
        local progress = ns.AchievementScanner:GetCategoryProgress()
        A.equals(1, progress[1].earned)
        A.equals(1, progress[1].total)
        A.equals(1, progress[2].earned)
        A.equals(2, progress[2].total)
    end)
end)

-------------------------------------------------------------------------------
-- NewsReader
-------------------------------------------------------------------------------

describe("NewsReader:Read", function()
    beforeEach(function()
        MockState:Reset()
        ns.NewsReader:Invalidate()
        MockState.numGuildNews = 3
        MockState.guildNews = {
            [1] = { newsType = 0, whoText = "Player1", whatText = "Stay Classy", newsDataID = 5362, year = 0, month = 0, day = 1, guildMembersPresent = 5 },
            [2] = { newsType = 2, whoText = "Player2", whatText = "Ragnaros", newsDataID = 100, year = 0, month = 0, day = 2, guildMembersPresent = 20 },
            [3] = { newsType = 3, whoText = "Player3", whatText = "Thunderfury", newsDataID = 200, year = 0, month = 0, day = 3, guildMembersPresent = 1 },
        }
    end)

    it("should return all news entries", function()
        local results = ns.NewsReader:Read()
        A.isTable(results)
        A.arrayLength(3, results)
    end)

    it("should include news entry fields", function()
        local results = ns.NewsReader:Read()
        local entry = results[1]
        A.equals(0, entry.newsType)
        A.equals("Player1", entry.who)
        A.equals("Stay Classy", entry.what)
        A.equals(5362, entry.dataID)
        A.isNumber(entry.timestamp)
        -- News was 1 day ago, so timestamp = serverTime - 86400
        A.equals(MockState.serverTime - 86400, entry.timestamp)
        A.equals(5, entry.membersPresent)
    end)

    it("should map API field names correctly", function()
        local results = ns.NewsReader:Read()
        local entry = results[1]
        -- Production code maps whoText->who, whatText->what, newsDataID->dataID, guildMembersPresent->membersPresent
        A.equals("Player1", entry.who)
        A.equals("Stay Classy", entry.what)
    end)

    it("should include typeInfo from NEWS_TYPE_INFO", function()
        local results = ns.NewsReader:Read()
        A.isNotNil(results[1].typeInfo)
        A.equals("Guild Achievement", results[1].typeInfo.label)
    end)

    it("should cache results on second call", function()
        local r1 = ns.NewsReader:Read()
        MockState.guildNews[1].whoText = "Changed"
        local r2 = ns.NewsReader:Read()
        A.equals(r1, r2, "Should return cached table")
        A.equals("Player1", r2[1].who)
    end)

    it("should re-read on forceRefresh", function()
        ns.NewsReader:Read()
        MockState.guildNews[1].whoText = "Changed"
        local results = ns.NewsReader:Read(true)
        A.equals("Changed", results[1].who)
    end)

    it("should return empty when not in guild", function()
        MockState.inGuild = false
        local results = ns.NewsReader:Read()
        A.arrayLength(0, results)
    end)
end)

describe("NewsReader:GetSummary", function()
    beforeEach(function()
        MockState:Reset()
        ns.NewsReader:Invalidate()
        MockState.numGuildNews = 4
        MockState.guildNews = {
            [1] = { newsType = 0, whoText = "P1", year = 0, month = 0, day = 1 },
            [2] = { newsType = 0, whoText = "P2", year = 0, month = 0, day = 2 },
            [3] = { newsType = 2, whoText = "P3", year = 0, month = 0, day = 3 },
            [4] = { newsType = 3, whoText = "P4", year = 0, month = 0, day = 4 },
        }
    end)

    it("should count news entries by type", function()
        local summary = ns.NewsReader:GetSummary()
        A.equals(2, summary[0])
        A.equals(1, summary[2])
        A.equals(1, summary[3])
    end)
end)

-------------------------------------------------------------------------------
-- RosterReader
-------------------------------------------------------------------------------

describe("RosterReader:Read", function()
    beforeEach(function()
        MockState:Reset()
        ns.RosterReader:Invalidate()
        MockState.guildMembers = {
            { name = "Tank-Realm", rank = "Officer", rankIndex = 1, level = 80, classDisplayName = "Warrior", zone = "Orgrimmar", publicNote = "", officerNote = "", online = true, status = 0, class = "WARRIOR", achievementPoints = 5000 },
            { name = "Healer-Realm", rank = "Member", rankIndex = 2, level = 80, classDisplayName = "Priest", zone = "Stormwind", publicNote = "", officerNote = "", online = true, status = 0, class = "PRIEST", achievementPoints = 8000 },
            { name = "DPS-Realm", rank = "Member", rankIndex = 2, level = 70, classDisplayName = "Rogue", zone = "Ironforge", publicNote = "", officerNote = "", online = false, status = 0, class = "ROGUE", achievementPoints = 3000 },
            { name = "AltTank-Realm", rank = "Member", rankIndex = 2, level = 80, classDisplayName = "Paladin", zone = "Orgrimmar", publicNote = "", officerNote = "", online = false, status = 0, class = "PALADIN", achievementPoints = 6000 },
        }
    end)

    it("should return all guild members", function()
        local results = ns.RosterReader:Read()
        A.isTable(results)
        A.arrayLength(4, results)
    end)

    it("should include member fields", function()
        local results = ns.RosterReader:Read()
        local m = results[1]
        A.equals("Tank-Realm", m.name)
        A.equals("Officer", m.rank)
        A.equals(1, m.rankIndex)
        A.equals(80, m.level)
        A.equals("Warrior", m.classDisplayName)
        A.equals("WARRIOR", m.class)
        A.equals(true, m.online)
        A.equals(5000, m.achievementPoints)
    end)

    it("should cache results", function()
        local r1 = ns.RosterReader:Read()
        MockState.guildMembers[1].name = "Changed"
        local r2 = ns.RosterReader:Read()
        A.equals(r1, r2)
        A.equals("Tank-Realm", r2[1].name)
    end)

    it("should return empty when not in guild", function()
        MockState.inGuild = false
        local results = ns.RosterReader:Read()
        A.arrayLength(0, results)
    end)
end)

describe("RosterReader:GetOnlineMaxLevel", function()
    beforeEach(function()
        MockState:Reset()
        ns.RosterReader:Invalidate()
        MockState.maxPlayerLevel = 80
        MockState.guildMembers = {
            { name = "Tank", level = 80, online = true, class = "WARRIOR", achievementPoints = 5000 },
            { name = "Healer", level = 80, online = true, class = "PRIEST", achievementPoints = 8000 },
            { name = "Leveler", level = 70, online = true, class = "ROGUE", achievementPoints = 1000 },
            { name = "Offline", level = 80, online = false, class = "MAGE", achievementPoints = 7000 },
        }
    end)

    it("should return only online max-level members", function()
        local results = ns.RosterReader:GetOnlineMaxLevel()
        A.arrayLength(2, results)
        A.equals("Tank", results[1].name)
        A.equals("Healer", results[2].name)
    end)
end)

describe("RosterReader:GetClassComposition", function()
    beforeEach(function()
        MockState:Reset()
        ns.RosterReader:Invalidate()
        MockState.maxPlayerLevel = 80
        MockState.guildMembers = {
            { name = "T1", level = 80, online = true, class = "WARRIOR", achievementPoints = 0 },
            { name = "T2", level = 80, online = true, class = "WARRIOR", achievementPoints = 0 },
            { name = "H1", level = 80, online = true, class = "PRIEST", achievementPoints = 0 },
            { name = "Off", level = 80, online = false, class = "MAGE", achievementPoints = 0 },
        }
    end)

    it("should group online max-level members by class", function()
        local comp = ns.RosterReader:GetClassComposition()
        A.equals(2, comp["WARRIOR"])
        A.equals(1, comp["PRIEST"])
        A.isNil(comp["MAGE"], "Offline members should not be included")
    end)
end)

describe("RosterReader:GetTopAchievers", function()
    beforeEach(function()
        MockState:Reset()
        ns.RosterReader:Invalidate()
        MockState.guildMembers = {
            { name = "Low", achievementPoints = 1000, class = "WARRIOR" },
            { name = "High", achievementPoints = 9000, class = "PRIEST" },
            { name = "Mid", achievementPoints = 5000, class = "MAGE" },
            { name = "Top", achievementPoints = 12000, class = "ROGUE" },
        }
    end)

    it("should return top N members sorted by achievement points", function()
        local top = ns.RosterReader:GetTopAchievers(3)
        A.arrayLength(3, top)
        A.equals("Top", top[1].name)
        A.equals(12000, top[1].achievementPoints)
        A.equals("High", top[2].name)
        A.equals("Mid", top[3].name)
    end)

    it("should handle count larger than roster", function()
        local top = ns.RosterReader:GetTopAchievers(100)
        A.arrayLength(4, top)
    end)
end)

describe("RosterReader:GetCounts", function()
    beforeEach(function()
        MockState:Reset()
        ns.RosterReader:Invalidate()
        MockState.guildMembers = {
            { name = "A", online = true, class = "WARRIOR" },
            { name = "B", online = false, class = "PRIEST" },
            { name = "C", online = true, class = "MAGE" },
        }
    end)

    it("should return total and online counts", function()
        local counts = ns.RosterReader:GetCounts()
        A.equals(3, counts.total)
        A.equals(2, counts.online)
    end)
end)

-------------------------------------------------------------------------------
-- EventLogReader
-------------------------------------------------------------------------------

describe("EventLogReader:Read", function()
    beforeEach(function()
        MockState:Reset()
        ns.EventLogReader:Invalidate()
        MockState.numGuildEvents = 3
        MockState.guildEventLog = {
            [1] = { eventType = "join", playerName1 = "NewPlayer", playerName2 = nil, rankIndex = 0, yearsAgo = 0, monthsAgo = 0, daysAgo = 1, hoursAgo = 2 },
            [2] = { eventType = "promote", playerName1 = "Officer", playerName2 = "NewPlayer", rankIndex = 3, yearsAgo = 0, monthsAgo = 0, daysAgo = 2, hoursAgo = 5 },
            [3] = { eventType = "quit", playerName1 = "Quitter", playerName2 = nil, rankIndex = 0, yearsAgo = 0, monthsAgo = 0, daysAgo = 3, hoursAgo = 0 },
        }
    end)

    it("should return all event log entries", function()
        local results = ns.EventLogReader:Read()
        A.isTable(results)
        A.arrayLength(3, results)
    end)

    it("should include event fields", function()
        local results = ns.EventLogReader:Read()
        local e = results[1]
        A.equals("join", e.eventType)
        A.equals("NewPlayer", e.playerName)
        -- Event was 1 day 2 hours ago, so timestamp = serverTime - (86400 + 7200)
        local expected = MockState.serverTime - (1 * 86400 + 2 * 3600)
        A.equals(expected, e.timestamp)
    end)

    it("should format join text correctly", function()
        local results = ns.EventLogReader:Read()
        A.equals("NewPlayer joined the guild", results[1].formattedText)
    end)

    it("should format promote text correctly", function()
        local results = ns.EventLogReader:Read()
        A.equals("Officer was promoted to rank 3", results[2].formattedText)
    end)

    it("should format quit text correctly", function()
        local results = ns.EventLogReader:Read()
        A.equals("Quitter left the guild", results[3].formattedText)
    end)

    it("should cache results", function()
        local r1 = ns.EventLogReader:Read()
        MockState.guildEventLog[1].eventType = "invite"
        local r2 = ns.EventLogReader:Read()
        A.equals(r1, r2)
        A.equals("join", r2[1].eventType)
    end)

    it("should return empty when not in guild", function()
        MockState.inGuild = false
        local results = ns.EventLogReader:Read()
        A.arrayLength(0, results)
    end)
end)

describe("EventLogReader formatted text variants", function()
    beforeEach(function()
        MockState:Reset()
        ns.EventLogReader:Invalidate()
    end)

    it("should format invite text", function()
        MockState.numGuildEvents = 1
        MockState.guildEventLog = {
            [1] = { eventType = "invite", playerName1 = "Inviter", playerName2 = "Invitee", rankIndex = 0, daysAgo = 1, hoursAgo = 0 },
        }
        local results = ns.EventLogReader:Read()
        A.equals("Inviter invited Invitee to the guild", results[1].formattedText)
    end)

    it("should format demote text", function()
        MockState.numGuildEvents = 1
        MockState.guildEventLog = {
            [1] = { eventType = "demote", playerName1 = "Officer", playerName2 = "Demoted", rankIndex = 5, daysAgo = 2, hoursAgo = 0 },
        }
        local results = ns.EventLogReader:Read()
        A.equals("Officer was demoted to rank 5", results[1].formattedText)
    end)

    it("should format remove text", function()
        MockState.numGuildEvents = 1
        MockState.guildEventLog = {
            [1] = { eventType = "remove", playerName1 = "Officer", playerName2 = "Removed", rankIndex = 0, daysAgo = 3, hoursAgo = 0 },
        }
        local results = ns.EventLogReader:Read()
        A.equals("Removed was removed from the guild by Officer", results[1].formattedText)
    end)
end)
