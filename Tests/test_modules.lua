-------------------------------------------------------------------------------
-- Unit Tests: All Modules
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

local Database = ns.Database

-- Helper to reinitialize everything fresh
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
-- BossKills Module
-------------------------------------------------------------------------------
describe("BossKills Module", function()
    local BossKills

    beforeEach(function()
        freshDB()
        BossKills = ns.addon:GetModule("BossKills")
        BossKills:ResetRecentKills()
    end)

    it("should exist as a module", function()
        A.isNotNil(BossKills)
    end)

    it("should have RecordBossKill method", function()
        A.isFunction(BossKills.RecordBossKill)
    end)

    it("should record a boss kill event", function()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20
        MockState.serverTime = 1700000100

        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)

        local event = data.events[1]
        A.isTrue(event.type == "FIRST_KILL" or event.type == "BOSS_KILL")
        A.equals(12345, event.encounterID)
        A.equals("Ragnaros", event.encounterName)
        A.equals(16, event.difficultyID)
    end)

    it("should detect first kills", function()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20

        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals("FIRST_KILL", data.events[1].type)
        A.isTrue(data.events[1].isFirstKill)
    end)

    it("should record subsequent kills as BOSS_KILL", function()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20

        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        -- Second kill (different timestamp to avoid dedup)
        MockState.serverTime = 1700000200
        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        local data = Database:GetGuildData()
        -- Find the second event (should be BOSS_KILL, not FIRST_KILL)
        local found = false
        for _, event in ipairs(data.events) do
            if event.type == "BOSS_KILL" and event.encounterID == 12345 then
                found = true
                A.isFalse(event.isFirstKill)
            end
        end
        A.isTrue(found, "Should have found a BOSS_KILL event")
    end)

    it("should not record when not in a guild", function()
        MockState.inGuild = false
        MockState.inRaid = true
        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        -- Not in guild, so GetGuildData returns nil - no events saved
        MockState.inGuild = true
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should not record when not in a group or raid", function()
        MockState.inRaid = false
        MockState.inGroup = false
        BossKills:RecordBossKill(12345, "Ragnaros", 16, 20)
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should not record with nil encounterID", function()
        MockState.inRaid = true
        BossKills:RecordBossKill(nil, "Ragnaros", 16, 20)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should not record with nil encounterName", function()
        MockState.inRaid = true
        BossKills:RecordBossKill(12345, nil, 16, 20)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should build a group roster", function()
        MockState.inRaid = true
        MockState.numGroupMembers = 2
        MockState.groupMembers = {
            { unit = "raid1", name = "Tank", realm = "TestRealm", class = "WARRIOR", role = "TANK" },
            { unit = "raid2", name = "Healer", realm = "TestRealm", class = "PRIEST", role = "HEALER" },
        }

        local roster = BossKills:BuildGroupRoster()
        A.isTable(roster)
        A.equals(2, #roster)
        A.equals("Tank-TestRealm", roster[1].name)
        A.equals("WARRIOR", roster[1].class)
        A.equals("TANK", roster[1].role)
    end)

    it("should handle OnEncounterEnd with success=0 (wipe)", function()
        MockState.inRaid = true
        BossKills:OnEncounterEnd(nil, 12345, "Boss", 16, 20, 0)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events, "Should not record wipes")
    end)

    it("should handle OnEncounterEnd with success=1 (kill)", function()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20
        MockState.serverTime = 1700099000
        BossKills:OnEncounterEnd(nil, 99999, "TestBoss", 16, 20, 1)
        Database:Flush()
        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
    end)
end)

-------------------------------------------------------------------------------
-- GuildRoster Module
-------------------------------------------------------------------------------
describe("GuildRoster Module", function()
    local GuildRosterMod

    beforeEach(function()
        freshDB()
        GuildRosterMod = ns.addon:GetModule("GuildRoster")
    end)

    it("should exist as a module", function()
        A.isNotNil(GuildRosterMod)
    end)

    it("should have FullRosterScan method", function()
        A.isFunction(GuildRosterMod.FullRosterScan)
    end)

    it("should save initial snapshot on first scan without generating events", function()
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Guild Master", rankIndex = 0, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
            { name = "Player2-Realm", rank = "Officer", rankIndex = 1, level = 75, class = "MAGE", classDisplayName = "Mage" },
        }

        GuildRosterMod:FullRosterScan()
        Database:Flush()

        -- Should have snapshot but no events on first scan
        local snapshot, _ = Database:GetRosterSnapshot()
        A.isNotNil(snapshot["Player1-Realm"])
        A.isNotNil(snapshot["Player2-Realm"])

        local data = Database:GetGuildData()
        A.equals(0, #data.events, "First scan should not generate events")
    end)

    it("should detect new members joining", function()
        -- First scan
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        -- Second scan with new member
        MockState.serverTime = 1700001000
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
            { name = "Player3-Realm", rank = "Initiate", rankIndex = 3, level = 60, class = "ROGUE", classDisplayName = "Rogue" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        local data = Database:GetGuildData()
        local joinEvent = nil
        for _, event in ipairs(data.events) do
            if event.type == "MEMBER_JOIN" then
                joinEvent = event
                break
            end
        end
        A.isNotNil(joinEvent, "Should have a MEMBER_JOIN event")
        A.contains("Player3-Realm", joinEvent.title)
    end)

    it("should detect members leaving", function()
        -- First scan with two members
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
            { name = "Player2-Realm", rank = "Member", rankIndex = 2, level = 80, class = "MAGE", classDisplayName = "Mage" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        -- Second scan with one member gone
        MockState.serverTime = 1700001000
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        local data = Database:GetGuildData()
        local leaveEvent = nil
        for _, event in ipairs(data.events) do
            if event.type == "MEMBER_LEAVE" then
                leaveEvent = event
                break
            end
        end
        A.isNotNil(leaveEvent, "Should have a MEMBER_LEAVE event")
        A.contains("Player2-Realm", leaveEvent.title)
    end)

    it("should detect rank changes", function()
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        MockState.serverTime = 1700001000
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Officer", rankIndex = 1, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        local data = Database:GetGuildData()
        local rankEvent = nil
        for _, event in ipairs(data.events) do
            if event.type == "MEMBER_RANK_CHANGE" then
                rankEvent = event
                break
            end
        end
        A.isNotNil(rankEvent, "Should have a MEMBER_RANK_CHANGE event")
    end)

    it("should detect max level reached", function()
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 79, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        MockState.serverTime = 1700001000
        MockState.guildMembers = {
            { name = "Player1-Realm", rank = "Member", rankIndex = 2, level = 80, class = "WARRIOR", classDisplayName = "Warrior" },
        }
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        local data = Database:GetGuildData()
        local levelEvent = nil
        for _, event in ipairs(data.events) do
            if event.type == "MEMBER_MAX_LEVEL" then
                levelEvent = event
                break
            end
        end
        A.isNotNil(levelEvent, "Should have a MEMBER_MAX_LEVEL event")
    end)

    it("should not generate events when not in a guild", function()
        MockState.inGuild = false
        GuildRosterMod:FullRosterScan()
        Database:Flush()

        MockState.inGuild = true
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should not generate events when guild has 0 members", function()
        MockState.guildMembers = {}
        GuildRosterMod:FullRosterScan()
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)
end)

-------------------------------------------------------------------------------
-- Achievements Module
-------------------------------------------------------------------------------
describe("Achievements Module", function()
    local AchievementsMod

    beforeEach(function()
        freshDB()
        AchievementsMod = ns.addon:GetModule("Achievements")
    end)

    it("should exist as a module", function()
        A.isNotNil(AchievementsMod)
    end)

    it("should record a personal achievement", function()
        MockState.achievements[99999] = {
            name = "Test Achievement",
            points = 10,
            description = "A test achievement",
            flags = 0,
        }

        AchievementsMod:OnAchievementEarned(nil, 99999)
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
        A.equals("ACHIEVEMENT", data.events[1].type)
        A.equals(99999, data.events[1].achievementID)
    end)

    it("should not record guild achievements in OnAchievementEarned", function()
        MockState.achievements[88888] = {
            name = "Guild Achievement",
            points = 10,
            description = "A guild achievement",
            flags = 0x4000, -- GUILD_ACHIEVEMENT_FLAG
        }

        AchievementsMod:OnAchievementEarned(nil, 88888)
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(0, #data.events, "Guild achievements should be skipped in OnAchievementEarned")
    end)

    it("should record guild achievements via OnGuildAchievementEarned", function()
        MockState.achievements[77777] = {
            name = "Guild First Kill",
            points = 25,
            description = "Guild achievement desc",
            flags = 0x4000,
        }

        AchievementsMod:OnGuildAchievementEarned(nil, 77777)
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
        A.equals("GUILD_ACHIEVEMENT", data.events[1].type)
    end)

    it("should not record when not in a guild (personal)", function()
        MockState.inGuild = false
        MockState.achievements[99999] = { name = "Test", points = 10, flags = 0 }

        AchievementsMod:OnAchievementEarned(nil, 99999)
        Database:Flush()

        MockState.inGuild = true
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should handle nil achievementID", function()
        AchievementsMod:OnAchievementEarned(nil, nil)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should handle nil achievementID in guild achievement", function()
        AchievementsMod:OnGuildAchievementEarned(nil, nil)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)
end)

-------------------------------------------------------------------------------
-- LootTracker Module
-------------------------------------------------------------------------------
describe("LootTracker Module", function()
    local LootMod

    beforeEach(function()
        freshDB()
        LootMod = ns.addon:GetModule("LootTracker")
        -- Set up a roster snapshot so guild member check works
        Database:SaveRosterSnapshot({
            ["TestPlayer-TestRealm"] = { rank = "Member", class = "WARRIOR" },
            ["Healer-TestRealm"] = { rank = "Officer", class = "PRIEST" },
        })
    end)

    it("should exist as a module", function()
        A.isNotNil(LootMod)
    end)

    it("should record epic loot from a guild member", function()
        MockState.items["[Epic Sword]"] = { name = "Epic Sword", quality = 4 }

        LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Epic Sword]")
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
        A.equals("LOOT", data.events[1].type)
    end)

    it("should not record loot below quality threshold", function()
        MockState.items["[Green Trash]"] = { name = "Green Trash", quality = 2 }

        LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Green Trash]")
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(0, #data.events, "Uncommon loot should be below Epic threshold")
    end)

    it("should record loot meeting quality threshold", function()
        ns.addon.db.profile.tracking.lootQuality = 3 -- Rare
        MockState.items["[Rare Helm]"] = { name = "Rare Helm", quality = 3 }

        LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Rare Helm]")
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
    end)

    it("should not record loot from non-guild members", function()
        MockState.items["[Epic Sword]"] = { name = "Epic Sword", quality = 4 }

        LootMod:OnLootMessage(nil, "RandomPerson-OtherRealm receives loot: [Epic Sword]")
        Database:Flush()

        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should handle 'You' as local player", function()
        MockState.items["[Legendary Staff]"] = { name = "Legendary Staff", quality = 5 }

        LootMod:OnLootMessage(nil, "You receive loot: [Legendary Staff]")
        Database:Flush()

        local data = Database:GetGuildData()
        A.isTrue(#data.events >= 1)
    end)

    it("should handle nil message", function()
        LootMod:OnLootMessage(nil, nil)
        Database:Flush()
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should not record when not in a guild", function()
        MockState.inGuild = false
        MockState.items["[Epic Sword]"] = { name = "Epic Sword", quality = 4 }

        LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Epic Sword]")
        Database:Flush()

        MockState.inGuild = true
        local data = Database:GetGuildData()
        A.equals(0, #data.events)
    end)

    it("should correctly identify guild members", function()
        A.isTrue(LootMod:IsGuildMember("TestPlayer-TestRealm"))
        A.isTrue(LootMod:IsGuildMember("Healer-TestRealm"))
        A.isFalse(LootMod:IsGuildMember("Unknown-OtherRealm"))
    end)

    it("should match guild members by short name", function()
        -- IsGuildMember also checks short name (without realm)
        A.isTrue(LootMod:IsGuildMember("TestPlayer"))
    end)

    it("should return false for nil name in IsGuildMember", function()
        A.isFalse(LootMod:IsGuildMember(nil))
    end)
end)

-------------------------------------------------------------------------------
-- MilestoneDetector Module
-------------------------------------------------------------------------------
describe("MilestoneDetector Module", function()
    local MilestoneMod

    beforeEach(function()
        freshDB()
        MilestoneMod = ns.addon:GetModule("MilestoneDetector")
        MilestoneMod:ResetCaches()
    end)

    it("should exist as a module", function()
        A.isNotNil(MilestoneMod)
    end)

    it("should detect member count milestone (10 members)", function()
        local snapshot = {}
        for i = 1, 12 do
            snapshot["Player" .. i .. "-Realm"] = { rank = "Member", class = "WARRIOR" }
        end
        Database:SaveRosterSnapshot(snapshot)

        MilestoneMod:CheckMemberCountMilestones()
        Database:Flush()

        local data = Database:GetGuildData()
        local milestoneEvent = nil
        for _, event in ipairs(data.events) do
            if event.type == "MILESTONE" and event.milestoneType == "MEMBER_COUNT" then
                milestoneEvent = event
                break
            end
        end
        A.isNotNil(milestoneEvent, "Should detect 10-member milestone")
        A.equals(10, milestoneEvent.thresholdValue)
    end)

    it("should not duplicate milestones", function()
        local snapshot = {}
        for i = 1, 12 do
            snapshot["Player" .. i .. "-Realm"] = { rank = "Member", class = "WARRIOR" }
        end
        Database:SaveRosterSnapshot(snapshot)

        MilestoneMod:CheckMemberCountMilestones()
        Database:Flush()
        MilestoneMod:CheckMemberCountMilestones()
        Database:Flush()

        local data = Database:GetGuildData()
        local count = 0
        for _, event in ipairs(data.events) do
            if event.type == "MILESTONE" and event.milestoneType == "MEMBER_COUNT"
               and event.thresholdValue == 10 then
                count = count + 1
            end
        end
        A.equals(1, count, "Should not duplicate milestone events")
    end)

    it("should detect kill count milestones", function()
        -- Add enough boss kill events to trigger the 10-kill milestone
        for i = 1, 12 do
            Database:QueueEvent({
                type = "BOSS_KILL",
                timestamp = 1700000000 + i,
                key1 = tostring(i),
            })
        end
        Database:Flush()

        MilestoneMod:CheckKillCountMilestones()
        Database:Flush()

        local data = Database:GetGuildData()
        local killMilestone = nil
        for _, event in ipairs(data.events) do
            if event.type == "MILESTONE" and event.milestoneType == "KILL_COUNT" then
                killMilestone = event
                break
            end
        end
        A.isNotNil(killMilestone, "Should detect 10-kill milestone")
        A.equals(10, killMilestone.thresholdValue)
    end)

    it("should detect member anniversaries", function()
        -- Set up a member who joined exactly 1 year ago today
        local now = MockState.serverTime
        local oneYearAgo = now - 365 * 86400

        -- Ensure the month/day match
        local currentMonth, currentDay = ns.Utils.TimestampToMonthDay(now)
        local joinMonth, joinDay = ns.Utils.TimestampToMonthDay(oneYearAgo)

        -- Only run assertion if dates actually line up (they should in most cases)
        if currentMonth == joinMonth and currentDay == joinDay then
            Database:UpdateMemberHistory("OldMember-Realm", "join")
            local guildData = Database:GetGuildData()
            guildData.memberHistory["OldMember-Realm"].firstSeen = oneYearAgo
            guildData.memberHistory["OldMember-Realm"].isActive = true

            MilestoneMod:CheckAnniversaries()
            Database:Flush()

            local found = false
            for _, event in ipairs(guildData.events) do
                if event.type == "MILESTONE" and event.milestoneType == "ANNIVERSARY"
                   and event.playerName == "OldMember-Realm" then
                    found = true
                end
            end
            A.isTrue(found, "Should detect anniversary")
        end
    end)

    it("should handle no guild data gracefully", function()
        MockState.inGuild = false
        -- Should not error
        A.doesNotThrow(function()
            MilestoneMod:CheckMemberCountMilestones()
            MilestoneMod:CheckKillCountMilestones()
            MilestoneMod:CheckAnniversaries()
        end)
    end)
end)

-------------------------------------------------------------------------------
-- OnThisDay Module
-------------------------------------------------------------------------------
describe("OnThisDay Module", function()
    local OnThisDayMod

    beforeEach(function()
        freshDB()
        OnThisDayMod = ns.addon:GetModule("OnThisDay")
    end)

    it("should exist as a module", function()
        A.isNotNil(OnThisDayMod)
    end)

    it("should return empty for no matching events", function()
        local events = OnThisDayMod:GetOnThisDayEvents()
        A.isTable(events)
        A.equals(0, #events)
    end)

    it("should find events from same day in previous years", function()
        local now = MockState.serverTime
        local currentMonth, currentDay = ns.Utils.TimestampToMonthDay(now)
        local currentYear = ns.Utils.TimestampToYear(now)

        -- Create an event exactly 1 year ago on the same month/day
        -- We need to construct a timestamp for the same month/day but previous year
        local lastYear = os.time({
            year = currentYear - 1,
            month = currentMonth,
            day = currentDay,
            hour = 12,
        })

        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = lastYear,
            title = "Last Year's Boss Kill",
            key1 = "oty1",
        })
        Database:Flush()

        local events = OnThisDayMod:GetOnThisDayEvents()
        A.isTrue(#events >= 1, "Should find last year's event")
        A.equals(1, events[1].yearsAgo)
    end)

    it("should not find events from today (same year)", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = MockState.serverTime,
            title = "Today's Kill",
            key1 = "today1",
        })
        Database:Flush()

        local events = OnThisDayMod:GetOnThisDayEvents()
        A.equals(0, #events, "Should not include same-year events")
    end)

    it("should sort results by most recent year first", function()
        local now = MockState.serverTime
        local currentMonth, currentDay = ns.Utils.TimestampToMonthDay(now)
        local currentYear = ns.Utils.TimestampToYear(now)

        local twoYearsAgo = os.time({
            year = currentYear - 2,
            month = currentMonth,
            day = currentDay,
            hour = 12,
        })
        local oneYearAgo = os.time({
            year = currentYear - 1,
            month = currentMonth,
            day = currentDay,
            hour = 12,
        })

        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = twoYearsAgo,
            title = "Two Years Ago",
            key1 = "oty2a",
        })
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = oneYearAgo,
            title = "One Year Ago",
            key1 = "oty1a",
        })
        Database:Flush()

        local events = OnThisDayMod:GetOnThisDayEvents()
        if #events >= 2 then
            A.isTrue(events[1].yearsAgo < events[2].yearsAgo,
                "Should sort most recent first")
        end
    end)

    it("should handle no guild data gracefully", function()
        MockState.inGuild = false
        local events = OnThisDayMod:GetOnThisDayEvents()
        A.isTable(events)
        A.equals(0, #events)
    end)
end)

-------------------------------------------------------------------------------
-- Notes Module
-------------------------------------------------------------------------------
describe("Notes Module", function()
    local NotesMod

    beforeEach(function()
        freshDB()
        NotesMod = ns.addon:GetModule("Notes")
    end)

    it("should exist as a module", function()
        A.isNotNil(NotesMod)
    end)

    it("should add a note to an existing event", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss Kill",
            key1 = "note_test_1",
        })
        Database:Flush()

        local result = NotesMod:AddNoteToEvent(1, "Great kill!")
        A.isTrue(result)

        local data = Database:GetGuildData()
        A.isNotNil(data.events[1].notes)
        A.equals(1, #data.events[1].notes)
        A.equals("Great kill!", data.events[1].notes[1].text)
    end)

    it("should include author and timestamp in the note", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss Kill",
            key1 = "note_test_2",
        })
        Database:Flush()

        MockState.serverTime = 1700000999
        NotesMod:AddNoteToEvent(1, "A note")

        local note = Database:GetGuildData().events[1].notes[1]
        A.equals(1700000999, note.timestamp)
        A.isNotNil(note.author)
    end)

    it("should reject empty notes", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss",
            key1 = "note_test_3",
        })
        Database:Flush()

        A.isFalse(NotesMod:AddNoteToEvent(1, ""))
        A.isFalse(NotesMod:AddNoteToEvent(1, nil))
    end)

    it("should reject notes exceeding max length", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss",
            key1 = "note_test_4",
        })
        Database:Flush()

        local longNote = string.rep("x", ns.MAX_NOTE_LENGTH + 1)
        A.isFalse(NotesMod:AddNoteToEvent(1, longNote))
    end)

    it("should accept notes at exactly max length", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss",
            key1 = "note_test_5",
        })
        Database:Flush()

        local exactNote = string.rep("x", ns.MAX_NOTE_LENGTH)
        A.isTrue(NotesMod:AddNoteToEvent(1, exactNote))
    end)

    it("should return false for invalid event index", function()
        A.isFalse(NotesMod:AddNoteToEvent(999, "Note"))
    end)

    it("should allow multiple notes on the same event", function()
        Database:QueueEvent({
            type = "BOSS_KILL",
            timestamp = 1700000000,
            title = "Boss",
            key1 = "note_test_6",
        })
        Database:Flush()

        NotesMod:AddNoteToEvent(1, "First note")
        NotesMod:AddNoteToEvent(1, "Second note")

        local notes = Database:GetGuildData().events[1].notes
        A.equals(2, #notes)
        A.equals("First note", notes[1].text)
        A.equals("Second note", notes[2].text)
    end)

    it("should return false when no guild data", function()
        MockState.inGuild = false
        A.isFalse(NotesMod:AddNoteToEvent(1, "Note"))
    end)
end)

-------------------------------------------------------------------------------
-- Constants Validation
-------------------------------------------------------------------------------
describe("Constants", function()
    it("should have all event types defined", function()
        A.isNotNil(ns.EVENT_TYPES.BOSS_KILL)
        A.isNotNil(ns.EVENT_TYPES.FIRST_KILL)
        A.isNotNil(ns.EVENT_TYPES.MEMBER_JOIN)
        A.isNotNil(ns.EVENT_TYPES.MEMBER_LEAVE)
        A.isNotNil(ns.EVENT_TYPES.MEMBER_RANK_CHANGE)
        A.isNotNil(ns.EVENT_TYPES.MEMBER_MAX_LEVEL)
        A.isNotNil(ns.EVENT_TYPES.ACHIEVEMENT)
        A.isNotNil(ns.EVENT_TYPES.GUILD_ACHIEVEMENT)
        A.isNotNil(ns.EVENT_TYPES.LOOT)
        A.isNotNil(ns.EVENT_TYPES.MILESTONE)
        A.isNotNil(ns.EVENT_TYPES.PLAYER_NOTE)
    end)

    it("should have display info for all event types", function()
        for key, _ in pairs(ns.EVENT_TYPES) do
            A.isNotNil(ns.EVENT_TYPE_INFO[key],
                "Missing EVENT_TYPE_INFO for " .. key)
            A.isNotNil(ns.EVENT_TYPE_INFO[key].icon,
                "Missing icon for " .. key)
            A.isNotNil(ns.EVENT_TYPE_INFO[key].color,
                "Missing color for " .. key)
        end
    end)

    it("should have valid color arrays (3 components)", function()
        for key, info in pairs(ns.EVENT_TYPE_INFO) do
            A.equals(3, #info.color, "Color for " .. key .. " should have 3 components")
        end
    end)

    it("should have timing constants", function()
        A.isNumber(ns.FLUSH_INTERVAL)
        A.isNumber(ns.ROSTER_DEBOUNCE)
        A.isNumber(ns.ROSTER_SCAN_INTERVAL)
        A.isNumber(ns.ON_THIS_DAY_DELAY)
        A.isNumber(ns.ON_THIS_DAY_DISMISS)
    end)

    it("should have data limits", function()
        A.isNumber(ns.MAX_EVENTS_DEFAULT)
        A.isNumber(ns.MAX_NOTE_LENGTH)
        A.isTrue(ns.MAX_EVENTS_DEFAULT > 0)
        A.isTrue(ns.MAX_NOTE_LENGTH > 0)
    end)

    it("should have milestone thresholds sorted ascending", function()
        for i = 2, #ns.MEMBER_COUNT_THRESHOLDS do
            A.isTrue(ns.MEMBER_COUNT_THRESHOLDS[i] > ns.MEMBER_COUNT_THRESHOLDS[i - 1])
        end
        for i = 2, #ns.KILL_COUNT_THRESHOLDS do
            A.isTrue(ns.KILL_COUNT_THRESHOLDS[i] > ns.KILL_COUNT_THRESHOLDS[i - 1])
        end
    end)

    it("should have DB_DEFAULTS with required sections", function()
        A.isTable(ns.DB_DEFAULTS.global)
        A.isTable(ns.DB_DEFAULTS.profile)
        A.isTable(ns.DB_DEFAULTS.char)
        A.isTable(ns.DB_DEFAULTS.profile.tracking)
        A.isTable(ns.DB_DEFAULTS.profile.display)
        A.isTable(ns.DB_DEFAULTS.profile.data)
    end)

    it("should have loot quality levels", function()
        A.equals(2, ns.LOOT_QUALITY.UNCOMMON)
        A.equals(3, ns.LOOT_QUALITY.RARE)
        A.equals(4, ns.LOOT_QUALITY.EPIC)
        A.equals(5, ns.LOOT_QUALITY.LEGENDARY)
    end)
end)

-------------------------------------------------------------------------------
-- Localization Validation
-------------------------------------------------------------------------------
describe("Localization (enUS)", function()
    it("should have all required locale strings", function()
        local requiredKeys = {
            "ADDON_NAME", "ADDON_LOADED", "SLASH_HELP", "NOT_IN_GUILD",
            "DEBUG_ENABLED", "DEBUG_DISABLED",
            "NOTE_ADDED", "NOTE_TOO_LONG", "NOTE_EMPTY",
            "SEARCH_NO_RESULTS", "SEARCH_RESULTS",
            "BOSS_KILL", "FIRST_KILL", "MEMBER_JOIN", "MEMBER_LEAVE",
            "MEMBER_RANK_CHANGE", "MEMBER_MAX_LEVEL", "ACHIEVEMENT",
            "GUILD_ACHIEVEMENT", "LOOT", "MILESTONE", "PLAYER_NOTE",
            "UI_TITLE", "UI_TIMELINE", "UI_STATISTICS", "UI_SETTINGS",
        }
        for _, key in ipairs(requiredKeys) do
            A.isNotNil(ns.L[key], "Missing locale string: " .. key)
            A.isString(ns.L[key], "Locale string should be a string: " .. key)
        end
    end)

    it("should have format strings with %s or %d placeholders where expected", function()
        A.isTrue(ns.L["ADDON_LOADED"]:find("%%s") ~= nil, "ADDON_LOADED should have %s")
        A.isTrue(ns.L["BOSS_KILL_DESC"]:find("%%s") ~= nil, "BOSS_KILL_DESC should have %s")
        A.isTrue(ns.L["MILESTONE_MEMBER_COUNT"]:find("%%d") ~= nil, "MILESTONE_MEMBER_COUNT should have %d")
    end)
end)

-------------------------------------------------------------------------------
-- Init / SlashCommand Tests
-------------------------------------------------------------------------------
describe("Addon Init and Slash Commands", function()
    beforeEach(function()
        freshDB()
        MockState.messages = {}
    end)

    it("should have registered the addon", function()
        A.isNotNil(ns.addon)
    end)

    it("should have a version", function()
        A.isNotNil(ns.addon.version)
        A.isString(ns.addon.version)
    end)

    it("should handle empty slash command (toggle)", function()
        -- Should not error even without MainFrame
        A.doesNotThrow(function()
            ns.addon:SlashCommand("")
        end)
    end)

    it("should handle 'note' command without args", function()
        ns.addon:SlashCommand("note")
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'note' command with text", function()
        ns.addon:SlashCommand("note This is a test note")
        -- Should add the note
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'note' command with too-long text", function()
        local longNote = "note " .. string.rep("x", ns.MAX_NOTE_LENGTH + 1)
        ns.addon:SlashCommand(longNote)
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'search' command without args", function()
        ns.addon:SlashCommand("search")
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'search' command with query", function()
        ns.addon:SlashCommand("search Ragnaros")
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'stats' command", function()
        ns.addon:SlashCommand("stats")
        A.isTrue(#MockState.messages > 0)
    end)

    it("should handle 'debug' command toggle", function()
        local wasDeb = ns.addon.db.profile.debug
        ns.addon:SlashCommand("debug")
        A.notEquals(wasDeb, ns.addon.db.profile.debug)

        ns.addon:SlashCommand("debug")
        A.equals(wasDeb, ns.addon.db.profile.debug)
    end)

    it("should handle unknown command gracefully", function()
        ns.addon:SlashCommand("unknowncommand")
        A.isTrue(#MockState.messages > 0)
    end)

    it("should have DebugPrint that respects debug flag", function()
        ns.addon.db.profile.debug = false
        MockState.messages = {}
        ns.addon:DebugPrint("test message")
        A.equals(0, #MockState.messages, "Should not print when debug is off")

        ns.addon.db.profile.debug = true
        ns.addon:DebugPrint("test message")
        A.isTrue(#MockState.messages > 0, "Should print when debug is on")
    end)
end)
