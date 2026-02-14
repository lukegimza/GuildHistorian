-------------------------------------------------------------------------------
-- Unit Tests: Core/Database.lua
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

local Database = ns.Database

-- Helper to reinitialize the database with fresh state
local function freshDB()
    MockState:Reset()
    Database:ResetCaches()
    local AceDB = LibStub("AceDB-3.0")
    local db = AceDB:New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    Database:Init(db)
    -- Also reset the addon db reference so PruneEvents can read maxEvents
    if ns.addon then
        ns.addon.db = db
    end
    return db
end

describe("Database.Init and Migrations", function()
    beforeEach(function()
        freshDB()
    end)

    it("should initialize the database", function()
        A.isNotNil(Database.db)
    end)

    it("should run migrations and set dbVersion", function()
        A.equals(1, Database.db.global.dbVersion)
    end)

    it("should not re-run migrations if version is current", function()
        Database.db.global.dbVersion = 1
        Database:RunMigrations()
        A.equals(1, Database.db.global.dbVersion)
    end)
end)

describe("Database.GetGuildData", function()
    beforeEach(function()
        freshDB()
    end)

    it("should return a guild data table", function()
        local data = Database:GetGuildData()
        A.isTable(data)
    end)

    it("should create default guild structure on first call", function()
        local data = Database:GetGuildData()
        A.isTable(data.events)
        A.isTable(data.firstKills)
        A.isTable(data.rosterSnapshot)
        A.isTable(data.memberHistory)
        A.equals(0, data.achievementPoints)
        A.equals(0, data.lastRosterScan)
    end)

    it("should return same table on repeated calls", function()
        local d1 = Database:GetGuildData()
        local d2 = Database:GetGuildData()
        A.isTrue(d1 == d2, "Should be the same table reference")
    end)

    it("should return nil when not in a guild", function()
        MockState.inGuild = false
        local data = Database:GetGuildData()
        A.isNil(data)
    end)
end)

describe("Database.QueueEvent", function()
    beforeEach(function()
        freshDB()
    end)

    it("should queue a valid event", function()
        local event = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Test Boss",
            key1 = "123",
        }
        local queued = Database:QueueEvent(event)
        A.isTrue(queued)
    end)

    it("should assign a dedupKey to the event", function()
        local event = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Test Boss",
            key1 = "123",
        }
        Database:QueueEvent(event)
        A.isNotNil(event.dedupKey)
        A.isNumber(event.dedupKey)
    end)

    it("should reject nil events", function()
        A.isFalse(Database:QueueEvent(nil))
    end)

    it("should reject events without type", function()
        A.isFalse(Database:QueueEvent({ timestamp = 1700000000 }))
    end)

    it("should reject events without timestamp", function()
        A.isFalse(Database:QueueEvent({ type = "BOSS_KILL" }))
    end)

    it("should reject duplicate events", function()
        local event = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Test Boss",
            key1 = "123",
        }
        A.isTrue(Database:QueueEvent(event))
        -- Queue the same event again
        local event2 = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Test Boss",
            key1 = "123",
        }
        A.isFalse(Database:QueueEvent(event2))
    end)

    it("should reject events when not in a guild", function()
        MockState.inGuild = false
        local event = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Test Boss",
        }
        A.isFalse(Database:QueueEvent(event))
    end)

    it("should use provided dedupKey if present", function()
        local event = {
            type = "BOSS_KILL",
            timestamp = 1700000000,
            dedupKey = 12345,
        }
        Database:QueueEvent(event)
        A.equals(12345, event.dedupKey)
    end)
end)

describe("Database.Flush", function()
    beforeEach(function()
        freshDB()
    end)

    it("should move queued events to the guild events array", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss A",
            key1 = "1",
        })
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000001,
            title = "Boss B",
            key1 = "2",
        })
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(2, #data.events)
    end)

    it("should insert events in descending timestamp order (newest first)", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss A",
            key1 = "1",
        })
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000010,
            title = "Boss B",
            key1 = "2",
        })
        Database:Flush()

        local data = Database:GetGuildData()
        -- Events are inserted at position 1, so last queued is first
        A.equals("Boss B", data.events[1].title)
    end)

    it("should do nothing when queue is empty", function()
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should clear the queue after flush", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss A",
            key1 = "1",
        })
        Database:Flush()
        Database:Flush() -- Second flush should be a no-op

        local data = Database:GetGuildData()
        A.equals(1, #data.events)
    end)
end)

describe("Database.PruneEvents", function()
    beforeEach(function()
        freshDB()
    end)

    it("should remove oldest events when over limit", function()
        -- Set max events to 3
        ns.addon.db.profile.data.maxEvents = 3

        for i = 1, 5 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                title = "Boss " .. i,
                key1 = tostring(i),
            })
        end
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(3, #data.events)
    end)

    it("should not prune when under limit", function()
        ns.addon.db.profile.data.maxEvents = 100

        for i = 1, 5 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                title = "Boss " .. i,
                key1 = tostring(i),
            })
        end
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(5, #data.events)
    end)
end)

describe("Database.GetEvents", function()
    beforeEach(function()
        freshDB()
        -- Add some test events
        for i = 1, 5 do
            Database:QueueEvent({
                type = i <= 3 and "BOSS_KILL" or "MEMBER_JOIN",
                timestamp = 1700000000 + i * 100,
                title = "Event " .. i,
                playerName = "Player" .. i,
                key1 = tostring(i),
            })
        end
        Database:Flush()
    end)

    it("should return all events with no filters", function()
        local events = Database:GetEvents(nil)
        A.equals(5, #events)
    end)

    it("should filter by event type", function()
        local events = Database:GetEvents({ types = { BOSS_KILL = true } })
        A.equals(3, #events)
    end)

    it("should filter by date range - startDate", function()
        local events = Database:GetEvents({ startDate = 1700000301 })
        A.isTrue(#events <= 3, "Should exclude earlier events")
    end)

    it("should filter by date range - endDate", function()
        local events = Database:GetEvents({ endDate = 1700000300 })
        A.isTrue(#events <= 3, "Should exclude later events")
    end)

    it("should filter by text search on title", function()
        local events = Database:GetEvents({ search = "Event 3" })
        A.equals(1, #events)
    end)

    it("should filter by text search on playerName", function()
        local events = Database:GetEvents({ search = "Player1" })
        A.equals(1, #events)
    end)

    it("should return empty with non-matching search", function()
        local events = Database:GetEvents({ search = "NonExistent" })
        A.equals(0, #events)
    end)

    it("should return empty array when no guild data", function()
        MockState.inGuild = false
        local events = Database:GetEvents(nil)
        A.isTable(events)
        A.equals(0, #events)
    end)
end)

describe("Database.MatchesFilters", function()
    it("should match event with empty type filter", function()
        local event = { type = "BOSS_KILL", timestamp = 1700000000 }
        A.isTrue(Database:MatchesFilters(event, { types = {} }))
    end)

    it("should match event with matching type", function()
        local event = { type = "BOSS_KILL", timestamp = 1700000000 }
        A.isTrue(Database:MatchesFilters(event, { types = { BOSS_KILL = true } }))
    end)

    it("should not match event with non-matching type", function()
        local event = { type = "MEMBER_JOIN", timestamp = 1700000000 }
        A.isFalse(Database:MatchesFilters(event, { types = { BOSS_KILL = true } }))
    end)

    it("should filter by difficulty when both event and filter have it", function()
        local event = { type = "BOSS_KILL", timestamp = 1700000000, difficultyID = 16 }
        A.isTrue(Database:MatchesFilters(event, { difficultyID = 16 }))
        A.isFalse(Database:MatchesFilters(event, { difficultyID = 15 }))
    end)

    it("should match search case-insensitively", function()
        local event = { type = "BOSS_KILL", timestamp = 1700000000, title = "Ragnaros Kill" }
        A.isTrue(Database:MatchesFilters(event, { search = "ragnaros" }))
    end)

    it("should search in description field", function()
        local event = { type = "BOSS_KILL", timestamp = 1700000000, description = "Mythic clear" }
        A.isTrue(Database:MatchesFilters(event, { search = "mythic" }))
    end)
end)

describe("Database.RecordFirstKill", function()
    beforeEach(function()
        freshDB()
    end)

    it("should record a new first kill and return true", function()
        local result = Database:RecordFirstKill(12345, 16)
        A.isTrue(result)
    end)

    it("should return false for a duplicate first kill", function()
        Database:RecordFirstKill(12345, 16)
        local result = Database:RecordFirstKill(12345, 16)
        A.isFalse(result)
    end)

    it("should allow same encounter with different difficulty", function()
        A.isTrue(Database:RecordFirstKill(12345, 16))
        A.isTrue(Database:RecordFirstKill(12345, 15))
    end)

    it("should store timestamp of first kill", function()
        MockState.serverTime = 1700099999
        Database:RecordFirstKill(12345, 16)
        local guildData = Database:GetGuildData()
        A.equals(1700099999, guildData.firstKills["12345-16"])
    end)

    it("should return false when not in a guild", function()
        MockState.inGuild = false
        A.isFalse(Database:RecordFirstKill(12345, 16))
    end)
end)

describe("Database.RosterSnapshot", function()
    beforeEach(function()
        freshDB()
    end)

    it("should save and retrieve a roster snapshot", function()
        local snapshot = {
            ["Player-Realm"] = { rank = "Officer", class = "WARRIOR" },
        }
        Database:SaveRosterSnapshot(snapshot)

        local retrieved, timestamp = Database:GetRosterSnapshot()
        A.isTable(retrieved)
        A.isNotNil(retrieved["Player-Realm"])
        A.equals("Officer", retrieved["Player-Realm"].rank)
    end)

    it("should update lastRosterScan timestamp", function()
        MockState.serverTime = 1700012345
        Database:SaveRosterSnapshot({})
        local _, timestamp = Database:GetRosterSnapshot()
        A.equals(1700012345, timestamp)
    end)

    it("should return empty table and 0 when no snapshot exists", function()
        local snapshot, timestamp = Database:GetRosterSnapshot()
        A.isTable(snapshot)
        A.equals(0, timestamp)
    end)
end)

describe("Database.UpdateMemberHistory", function()
    beforeEach(function()
        freshDB()
    end)

    it("should create history on join", function()
        MockState.serverTime = 1700000100
        Database:UpdateMemberHistory("Player-Realm", "join")
        local guildData = Database:GetGuildData()
        A.isNotNil(guildData.memberHistory["Player-Realm"])
        A.isTrue(guildData.memberHistory["Player-Realm"].isActive)
        A.equals(1700000100, guildData.memberHistory["Player-Realm"].firstSeen)
    end)

    it("should set isActive to false on leave", function()
        Database:UpdateMemberHistory("Player-Realm", "join")
        Database:UpdateMemberHistory("Player-Realm", "leave")
        local guildData = Database:GetGuildData()
        A.isFalse(guildData.memberHistory["Player-Realm"].isActive)
    end)

    it("should not overwrite firstSeen on rejoin", function()
        MockState.serverTime = 1700000100
        Database:UpdateMemberHistory("Player-Realm", "join")
        MockState.serverTime = 1700000200
        Database:UpdateMemberHistory("Player-Realm", "leave")
        MockState.serverTime = 1700000300
        Database:UpdateMemberHistory("Player-Realm", "join")
        local guildData = Database:GetGuildData()
        A.equals(1700000100, guildData.memberHistory["Player-Realm"].firstSeen)
    end)

    it("should update lastSeen on both join and leave", function()
        MockState.serverTime = 1700000100
        Database:UpdateMemberHistory("Player-Realm", "join")
        A.equals(1700000100, Database:GetGuildData().memberHistory["Player-Realm"].lastSeen)

        MockState.serverTime = 1700000200
        Database:UpdateMemberHistory("Player-Realm", "leave")
        A.equals(1700000200, Database:GetGuildData().memberHistory["Player-Realm"].lastSeen)
    end)
end)

describe("Database.GetStats", function()
    beforeEach(function()
        freshDB()
    end)

    it("should return empty stats when no data", function()
        local stats = Database:GetStats()
        A.equals(0, stats.totalEvents)
        A.equals(0, stats.firstKills)
        A.equals(0, stats.membersTracked)
        A.equals(0, stats.activeMembers)
    end)

    it("should count events correctly", function()
        for i = 1, 3 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                key1 = tostring(i),
            })
        end
        Database:Flush()

        local stats = Database:GetStats()
        A.equals(3, stats.totalEvents)
    end)

    it("should count first kills", function()
        Database:RecordFirstKill(100, 16)
        Database:RecordFirstKill(200, 16)
        local stats = Database:GetStats()
        A.equals(2, stats.firstKills)
    end)

    it("should track member history stats", function()
        Database:UpdateMemberHistory("Player1-Realm", "join")
        Database:UpdateMemberHistory("Player2-Realm", "join")
        Database:UpdateMemberHistory("Player3-Realm", "join")
        Database:UpdateMemberHistory("Player3-Realm", "leave")

        local stats = Database:GetStats()
        A.equals(3, stats.membersTracked)
        A.equals(2, stats.activeMembers)
    end)

    it("should compute events by type", function()
        Database:QueueEvent({ type = "BOSS_KILL", timestamp = 1700000001, key1 = "1" })
        Database:QueueEvent({ type = "BOSS_KILL", timestamp = 1700000002, key1 = "2" })
        Database:QueueEvent({ type = "MEMBER_JOIN", timestamp = 1700000003, key1 = "3" })
        Database:Flush()

        local stats = Database:GetStats()
        A.equals(2, stats.eventsByType["BOSS_KILL"])
        A.equals(1, stats.eventsByType["MEMBER_JOIN"])
    end)

    it("should compute most active members (top 5)", function()
        for i = 1, 10 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                playerName = "Player" .. (i % 3),
                key1 = tostring(i),
            })
        end
        Database:Flush()

        local stats = Database:GetStats()
        A.isTrue(#stats.mostActive <= 5)
        A.isTrue(#stats.mostActive > 0)
    end)

    it("should identify oldest event", function()
        Database:QueueEvent({ type = "BOSS_KILL", timestamp = 1700000500, key1 = "a" })
        Database:QueueEvent({ type = "BOSS_KILL", timestamp = 1700000100, key1 = "b" })
        Database:QueueEvent({ type = "BOSS_KILL", timestamp = 1700000300, key1 = "c" })
        Database:Flush()

        local stats = Database:GetStats()
        A.equals(1700000100, stats.oldestEvent)
    end)

    it("should return empty stats when not in a guild", function()
        MockState.inGuild = false
        local stats = Database:GetStats()
        A.equals(0, stats.totalEvents)
    end)
end)

describe("Database.GetEventCount", function()
    beforeEach(function()
        freshDB()
    end)

    it("should return 0 for empty database", function()
        A.equals(0, Database:GetEventCount())
    end)

    it("should return correct count after adding events", function()
        for i = 1, 5 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                key1 = tostring(i),
            })
        end
        Database:Flush()
        A.equals(5, Database:GetEventCount())
    end)

    it("should return 0 when not in a guild", function()
        MockState.inGuild = false
        A.equals(0, Database:GetEventCount())
    end)
end)

describe("Database.SearchEvents", function()
    beforeEach(function()
        freshDB()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000001,
            title = "Ragnaros Defeated",
            key1 = "1",
        })
        Database:QueueEvent({
            type = "MEMBER_JOIN",
            timestamp = 1700000002,
            title = "TestPlayer joined",
            playerName = "TestPlayer-Realm",
            key1 = "2",
        })
        Database:Flush()
    end)

    it("should find events by title text", function()
        local results = Database:SearchEvents("Ragnaros")
        A.equals(1, #results)
    end)

    it("should find events by player name", function()
        local results = Database:SearchEvents("TestPlayer")
        A.isTrue(#results >= 1)
    end)

    it("should return empty for non-matching search", function()
        local results = Database:SearchEvents("zzzNonExistent")
        A.equals(0, #results)
    end)

    it("should be case-insensitive", function()
        local results = Database:SearchEvents("ragnaros")
        A.equals(1, #results)
    end)
end)
