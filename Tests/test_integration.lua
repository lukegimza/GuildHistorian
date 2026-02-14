-------------------------------------------------------------------------------
-- Integration Tests: End-to-End Workflow Simulation
-- These tests simulate real WoW player workflows from start to finish.
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

local Database = ns.Database
local Utils = ns.Utils

local function freshDB()
    MockState:Reset()
    Database:ResetCaches()
    local AceDB = LibStub("AceDB-3.0")
    local db = AceDB:New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    Database:Init(db)
    if ns.addon then
        ns.addon.db = db
    end
    return db
end

-------------------------------------------------------------------------------
-- Full Lifecycle: Login → Track Events → View Stats → Export
-------------------------------------------------------------------------------
describe("Integration: Full Addon Lifecycle", function()
    beforeEach(function()
        freshDB()
        MockState.messages = {}
    end)

    it("should handle a complete player session lifecycle", function()
        -- 1. Addon initializes
        local addon = ns.addon
        A.isNotNil(addon)
        A.isNotNil(addon.db)
        A.equals(1, addon.db.global.dbVersion)

        -- 2. Guild roster first scan (25 members)
        local GuildRosterMod = addon:GetModule("GuildRoster")
        MockState.guildMembers = {}
        for i = 1, 25 do
            MockState.guildMembers[i] = {
                name = "Player" .. i .. "-TestRealm",
                rank = i == 1 and "Guild Master" or "Member",
                rankIndex = i == 1 and 0 or 2,
                level = 70 + (i % 11),
                class = "WARRIOR",
                classDisplayName = "Warrior",
            }
        end
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        -- Snapshot saved, no events on first scan
        local snapshot, _ = Database:GetRosterSnapshot()
        A.isNotNil(snapshot["Player1-TestRealm"])
        A.equals(0, Database:GetEventCount())

        -- 3. Second scan: a new member joins
        MockState.serverTime = 1700001000
        MockState.guildMembers[26] = {
            name = "NewPlayer-TestRealm",
            rank = "Initiate",
            rankIndex = 3,
            level = 45,
            class = "MAGE",
            classDisplayName = "Mage",
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        A.isTrue(Database:GetEventCount() >= 1, "Should record the join event")

        -- 4. Boss kill in a raid
        MockState.serverTime = 1700002000
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20
        local BossKills = addon:GetModule("BossKills")
        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        local stats = Database:GetStats()
        A.isTrue(stats.totalEvents >= 2, "Should have join + boss kill events")
        A.equals(1, stats.firstKills, "Should record first kill")

        -- 5. Achievement earned
        MockState.serverTime = 1700003000
        MockState.achievements[99001] = {
            name = "Cutting Edge: Ragnaros",
            points = 10,
            description = "Defeat Ragnaros on Mythic",
            flags = 0,
        }
        local AchievementsMod = addon:GetModule("Achievements")
        AchievementsMod:OnAchievementEarned(nil, 99001)
        Database:Flush()

        -- 6. Epic loot drop
        MockState.serverTime = 1700004000
        MockState.items["[Sulfuras, Hand of Ragnaros]"] = {
            name = "Sulfuras, Hand of Ragnaros",
            quality = 5,  -- Legendary
        }
        local LootMod = addon:GetModule("LootTracker")
        LootMod:OnLootMessage(nil, "Player1-TestRealm receives loot: [Sulfuras, Hand of Ragnaros]")
        Database:Flush()

        -- 7. Player adds a note
        MockState.serverTime = 1700005000
        addon:SlashCommand("note Great raid night! Our first Ragnaros kill!")
        Database:Flush()

        -- 8. Check stats
        stats = Database:GetStats()
        A.isTrue(stats.totalEvents >= 5, "Should have all event types recorded")
        A.isTrue(stats.firstKills >= 1)

        -- 9. Search events
        local results = Database:SearchEvents("Ragnaros")
        A.isTrue(#results >= 1, "Should find Ragnaros events via search")

        -- 10. Filter events by type
        local bossEvents = Database:GetEvents({ types = { BOSS_KILL = true, FIRST_KILL = true } })
        A.isTrue(#bossEvents >= 1)

        local joinEvents = Database:GetEvents({ types = { MEMBER_JOIN = true } })
        A.isTrue(#joinEvents >= 1)

        -- 11. Print stats via slash command
        MockState.messages = {}
        addon:SlashCommand("stats")
        A.isTrue(#MockState.messages > 0, "Stats command should produce output")
    end)
end)

-------------------------------------------------------------------------------
-- Multi-Guild Isolation
-------------------------------------------------------------------------------
describe("Integration: Multi-Guild Data Isolation", function()
    beforeEach(function()
        freshDB()
    end)

    it("should keep data separate between guilds", function()
        -- Record events for Guild A
        MockState.guildName = "Guild Alpha"
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000001,
            title = "Alpha Boss Kill",
            key1 = "guild_a_1",
        })
        Database:Flush()

        local countA = Database:GetEventCount()
        A.equals(1, countA)

        -- Switch to Guild B
        MockState.guildName = "Guild Beta"
        Database:QueueEvent({
            type = "MEMBER_JOIN",
            timestamp = 1700000002,
            title = "Beta Member Join",
            key1 = "guild_b_1",
        })
        Database:QueueEvent({
            type = "MEMBER_JOIN",
            timestamp = 1700000003,
            title = "Beta Member Join 2",
            key1 = "guild_b_2",
        })
        Database:Flush()

        local countB = Database:GetEventCount()
        A.equals(2, countB, "Guild Beta should have 2 events")

        -- Switch back to Guild A
        MockState.guildName = "Guild Alpha"
        A.equals(1, Database:GetEventCount(), "Guild Alpha should still have 1 event")
    end)
end)

-------------------------------------------------------------------------------
-- Deduplication Under Rapid Events
-------------------------------------------------------------------------------
describe("Integration: Event Deduplication", function()
    beforeEach(function()
        freshDB()
    end)

    it("should deduplicate identical events from rapid-fire sources", function()
        -- Simulate ENCOUNTER_END and BOSS_KILL both firing for the same kill
        local BossKills = ns.addon:GetModule("BossKills")
        BossKills:ResetRecentKills()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20

        -- First event from ENCOUNTER_END
        BossKills:RecordBossKill(55555, "Twin Emps", 16, 20)
        -- Second event from BOSS_KILL (same encounter, same timestamp)
        BossKills:RecordBossKill(55555, "Twin Emps", 16, 20)
        Database:Flush()

        -- Should only have 1 event thanks to the recent-kill guard
        local data = Database:GetGuildData()
        local killCount = 0
        for _, e in ipairs(data.events) do
            if e.encounterID == 55555 then
                killCount = killCount + 1
            end
        end
        A.equals(1, killCount, "Should deduplicate identical boss kill events")
    end)

    it("should allow same boss with different timestamps outside window", function()
        local BossKills = ns.addon:GetModule("BossKills")
        BossKills:ResetRecentKills()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20

        MockState.serverTime = 1700010000
        BossKills:RecordBossKill(55555, "Twin Emps", 16, 20)
        -- 10,000 seconds later - well outside the 10-second dedup window
        MockState.serverTime = 1700020000
        BossKills:RecordBossKill(55555, "Twin Emps", 16, 20)
        Database:Flush()

        local data = Database:GetGuildData()
        local killCount = 0
        for _, e in ipairs(data.events) do
            if e.encounterID == 55555 then
                killCount = killCount + 1
            end
        end
        A.isTrue(killCount >= 2, "Different timestamps should create separate events")
    end)
end)

-------------------------------------------------------------------------------
-- Roster Change Detection Flow
-------------------------------------------------------------------------------
describe("Integration: Roster Change Workflow", function()
    beforeEach(function()
        freshDB()
    end)

    it("should detect join, promote, then leave in sequence", function()
        local GR = ns.addon:GetModule("GuildRoster")

        -- Initial roster
        MockState.guildMembers = {
            { name = "Leader-Realm", rank = "GM", rankIndex = 0, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GR:FullRosterScan()
        Database:Flush()

        -- New member joins
        MockState.serverTime = 1700010000
        MockState.guildMembers[2] = {
            name = "Recruit-Realm", rank = "Initiate", rankIndex = 4, level = 60, class = "MAGE", classDisplayName = "Mage",
        }
        GR:FullRosterScan()
        Database:Flush()

        -- Recruit gets promoted
        MockState.serverTime = 1700020000
        MockState.guildMembers[2] = {
            name = "Recruit-Realm", rank = "Officer", rankIndex = 1, level = 60, class = "MAGE", classDisplayName = "Mage",
        }
        GR:FullRosterScan()
        Database:Flush()

        -- Recruit leaves
        MockState.serverTime = 1700030000
        MockState.guildMembers[2] = nil
        GR:FullRosterScan()
        Database:Flush()

        -- Verify the full timeline
        local events = Database:GetEvents()
        local join, promote, leave = false, false, false
        for _, e in ipairs(events) do
            if e.type == "MEMBER_JOIN" and e.playerName == "Recruit-Realm" then join = true end
            if e.type == "MEMBER_RANK_CHANGE" and e.playerName == "Recruit-Realm" then promote = true end
            if e.type == "MEMBER_LEAVE" and e.playerName == "Recruit-Realm" then leave = true end
        end
        A.isTrue(join, "Should record join event")
        A.isTrue(promote, "Should record rank change event")
        A.isTrue(leave, "Should record leave event")

        -- Verify member history
        local guildData = Database:GetGuildData()
        local history = guildData.memberHistory["Recruit-Realm"]
        A.isNotNil(history)
        A.isFalse(history.isActive, "Should be marked inactive after leave")
        A.isNotNil(history.firstSeen)
    end)
end)

-------------------------------------------------------------------------------
-- Notes Workflow
-------------------------------------------------------------------------------
describe("Integration: Notes Workflow", function()
    beforeEach(function()
        freshDB()
    end)

    it("should create standalone note and note-on-event", function()
        -- Create a boss kill event first
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000100,
            title = "Ragnaros Defeated",
            key1 = "notes_integration_1",
        })
        Database:Flush()

        -- Add a note to the event
        local NotesMod = ns.addon:GetModule("Notes")
        local result = NotesMod:AddNoteToEvent(1, "Close fight! Tank died at 2%")
        A.isTrue(result)

        -- Add a standalone note via slash command
        MockState.serverTime = 1700000200
        ns.addon:SlashCommand("note Recording our weekly raid schedule")
        Database:Flush()

        -- Verify both notes exist
        local events = Database:GetEvents()
        A.isTrue(#events >= 2, "Should have boss kill + player note")

        local bossEvent = nil
        for _, e in ipairs(events) do
            if e.type == "BOSS_KILL" then bossEvent = e; break end
        end
        A.isNotNil(bossEvent.notes)
        A.equals(1, #bossEvent.notes)
        A.contains("2%", bossEvent.notes[1].text)

        -- Find the standalone note
        local noteEvents = Database:GetEvents({ types = { PLAYER_NOTE = true } })
        A.isTrue(#noteEvents >= 1)
    end)
end)

-------------------------------------------------------------------------------
-- Flush Timer Simulation
-------------------------------------------------------------------------------
describe("Integration: Write Queue and Flush Cycle", function()
    beforeEach(function()
        freshDB()
    end)

    it("should batch multiple events in write queue then flush together", function()
        -- Queue several events without flushing
        for i = 1, 10 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                title = "Boss " .. i,
                key1 = "batch_" .. tostring(i),
            })
        end

        -- Before flush: events should not be in the DB
        local data = Database:GetGuildData()
        A.equals(0, #data.events, "Events should be queued, not yet in DB")

        -- Flush (simulating the timer firing)
        Database:Flush()

        -- After flush: all 10 events should be present
        A.equals(10, #data.events, "All 10 events should be flushed at once")
    end)

    it("should handle interleaved queue and flush cycles", function()
        -- Cycle 1
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000001,
            title = "Boss A",
            key1 = "cycle_1",
        })
        Database:Flush()

        -- Cycle 2
        Database:QueueEvent({
            type = "MEMBER_JOIN",
            timestamp = 1700000002,
            title = "Join B",
            key1 = "cycle_2",
        })
        Database:Flush()

        -- Cycle 3
        Database:QueueEvent({
            type = "LOOT",
            timestamp = 1700000003,
            title = "Loot C",
            key1 = "cycle_3",
        })
        Database:Flush()

        A.equals(3, Database:GetEventCount(), "All events from separate flush cycles")
    end)
end)
