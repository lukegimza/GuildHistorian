-------------------------------------------------------------------------------
-- WoW 12.0 (Midnight) Compatibility Tests
-- Tests that pcall protections work when WoW APIs throw secret-value errors
-- during active encounters / restricted states.
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach, afterEach = T.describe, T.it, T.beforeEach, T.afterEach
local A = T.Assert

local Database = ns.Database

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

-- Store original WoW API functions so we can restore them
local origUnitName = UnitName
local origUnitClass = UnitClass
local origUnitGroupRolesAssigned = UnitGroupRolesAssigned
local origGetInstanceInfo = GetInstanceInfo
local origGetItemInfo = GetItemInfo

local function restoreAPIs()
    UnitName = origUnitName
    UnitClass = origUnitClass
    UnitGroupRolesAssigned = origUnitGroupRolesAssigned
    GetInstanceInfo = origGetInstanceInfo
    GetItemInfo = origGetItemInfo
end

-- Simulate secret value errors (WoW 12.0 restricted state)
local function makeAPIThrow(funcName)
    return function()
        error("Attempt to read a restricted value: " .. funcName)
    end
end

-------------------------------------------------------------------------------
-- BossKills: BuildGroupRoster with secret values
-------------------------------------------------------------------------------
describe("WoW 12.0: BossKills Secret Value Protection", function()
    local BossKills

    beforeEach(function()
        freshDB()
        BossKills = ns.addon:GetModule("BossKills")
        BossKills:ResetRecentKills()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 5
        MockState.groupMembers = {
            { unit = "raid1", name = "Tank", realm = "TestRealm", class = "WARRIOR", role = "TANK" },
            { unit = "raid2", name = "Healer", realm = "TestRealm", class = "PRIEST", role = "HEALER" },
            { unit = "raid3", name = "DPS1", realm = "TestRealm", class = "MAGE", role = "DAMAGER" },
            { unit = "raid4", name = "DPS2", realm = "TestRealm", class = "ROGUE", role = "DAMAGER" },
            { unit = "raid5", name = "DPS3", realm = "TestRealm", class = "HUNTER", role = "DAMAGER" },
        }
    end)

    afterEach(function()
        restoreAPIs()
    end)

    it("should build roster normally when APIs work", function()
        local roster = BossKills:BuildGroupRoster()
        A.isTrue(#roster >= 1, "Should build roster with group members")
    end)

    it("should not crash when UnitName throws secret value error", function()
        UnitName = makeAPIThrow("UnitName")
        local roster = BossKills:BuildGroupRoster()
        A.isNotNil(roster, "Roster should still be a table")
        A.equals(0, #roster, "Roster should be empty when UnitName is restricted")
    end)

    it("should not crash when UnitClass throws secret value error", function()
        UnitClass = makeAPIThrow("UnitClass")
        local roster = BossKills:BuildGroupRoster()
        A.isTrue(#roster >= 1, "Should still build roster entries")
        -- Class should be nil but entry should exist
        for _, member in ipairs(roster) do
            A.isNil(member.class, "Class should be nil when UnitClass is restricted")
        end
    end)

    it("should not crash when UnitGroupRolesAssigned throws secret value error", function()
        UnitGroupRolesAssigned = makeAPIThrow("UnitGroupRolesAssigned")
        local roster = BossKills:BuildGroupRoster()
        A.isTrue(#roster >= 1, "Should still build roster entries")
        -- Role should fallback to nil (since "NONE" maps to nil)
        for _, member in ipairs(roster) do
            A.isNil(member.role, "Role should be nil when UnitGroupRolesAssigned is restricted")
        end
    end)

    it("should not crash when ALL unit APIs throw simultaneously", function()
        UnitName = makeAPIThrow("UnitName")
        UnitClass = makeAPIThrow("UnitClass")
        UnitGroupRolesAssigned = makeAPIThrow("UnitGroupRolesAssigned")
        local roster = BossKills:BuildGroupRoster()
        A.isNotNil(roster)
        A.equals(0, #roster, "Empty roster when all unit APIs are restricted")
    end)

    it("should still record boss kill event when GetInstanceInfo throws", function()
        GetInstanceInfo = makeAPIThrow("GetInstanceInfo")
        BossKills:RecordBossKill(99999, "Test Boss", 16, 20)
        Database:Flush()

        local events = Database:GetEvents()
        A.isTrue(#events >= 1, "Should still record boss kill event")
        A.isNil(events[1].instanceName, "Instance name should be nil when GetInstanceInfo is restricted")
    end)

    it("should record boss kill with partial roster when some units are restricted", function()
        -- Only make UnitName throw for raid3+
        local callCount = 0
        UnitName = function(unit)
            callCount = callCount + 1
            if callCount > 2 then
                error("Attempt to read a restricted value: UnitName")
            end
            return origUnitName(unit)
        end

        local roster = BossKills:BuildGroupRoster()
        A.isTrue(#roster >= 1, "Should have partial roster")
        A.isTrue(#roster < 5, "Should not have all 5 members")
    end)

    it("should handle OnBossKill with restricted GetInstanceInfo", function()
        GetInstanceInfo = makeAPIThrow("GetInstanceInfo")
        -- OnBossKill wraps GetInstanceInfo in pcall
        BossKills:OnBossKill(nil, 88888, "Restricted Boss")
        Database:Flush()

        local count = Database:GetEventCount()
        A.isTrue(count >= 1, "Should still record event via OnBossKill fallback")
    end)
end)

-------------------------------------------------------------------------------
-- LootTracker: ProcessLootMessage with secret values
-------------------------------------------------------------------------------
describe("WoW 12.0: LootTracker Secret Value Protection", function()
    local LootMod

    beforeEach(function()
        freshDB()
        LootMod = ns.addon:GetModule("LootTracker")
        -- Set up a guild member in roster snapshot
        local snapshot = { ["TestPlayer-TestRealm"] = { class = "WARRIOR" } }
        Database:SaveRosterSnapshot(snapshot)
    end)

    afterEach(function()
        restoreAPIs()
    end)

    it("should not crash when loot message parsing throws", function()
        -- Simulate a KString message that throws on string operations
        local badMsg = setmetatable({}, {
            __tostring = function() error("Attempt to read a restricted KString") end,
        })
        -- pcall should catch it
        A.doesNotThrow(function()
            LootMod:OnLootMessage(nil, badMsg)
        end, "Should not propagate KString errors")
    end)

    it("should not crash when GetItemInfo throws during restricted state", function()
        GetItemInfo = makeAPIThrow("GetItemInfo")
        A.doesNotThrow(function()
            LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Epic Sword]")
        end, "Should not crash when GetItemInfo is restricted")
    end)

    it("should not crash when strmatch throws on restricted message", function()
        -- Replace strmatch temporarily to simulate restricted state
        local origStrmatch = strmatch
        strmatch = makeAPIThrow("strmatch")
        A.doesNotThrow(function()
            LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Sword]")
        end, "Should not crash when strmatch is restricted")
        strmatch = origStrmatch
    end)

    it("should still process normal loot messages correctly", function()
        MockState.items["[Epic Sword]"] = { name = "Epic Sword", quality = 4 }
        LootMod:OnLootMessage(nil, "TestPlayer-TestRealm receives loot: [Epic Sword]")
        Database:Flush()
        A.isTrue(Database:GetEventCount() >= 1, "Should record loot event normally")
    end)
end)

-------------------------------------------------------------------------------
-- Full Integration: Boss Kill During Restricted State
-------------------------------------------------------------------------------
describe("WoW 12.0: Full Boss Kill During Restricted State", function()
    beforeEach(function()
        freshDB()
        local BossKills = ns.addon:GetModule("BossKills")
        BossKills:ResetRecentKills()
        MockState.inRaid = true
        MockState.inGroup = true
        MockState.numGroupMembers = 20
    end)

    afterEach(function()
        restoreAPIs()
    end)

    it("should record complete boss kill flow when APIs are partially restricted", function()
        -- Simulate: GetInstanceInfo works but UnitName/UnitClass are restricted
        UnitName = makeAPIThrow("UnitName")
        UnitClass = makeAPIThrow("UnitClass")

        local BossKills = ns.addon:GetModule("BossKills")
        BossKills:RecordBossKill(77777, "Restricted Encounter", 16, 20)
        Database:Flush()

        local events = Database:GetEvents()
        A.isTrue(#events >= 1, "Should record the boss kill")

        local event = events[1]
        A.equals("Restricted Encounter", event.encounterName)
        A.equals(16, event.difficultyID)
        A.equals(20, event.groupSize)
        -- Roster should be empty since UnitName was restricted
        A.isNotNil(event.roster)
        A.equals(0, #event.roster, "Roster should be empty when unit APIs are restricted")
    end)

    it("should record complete boss kill flow when ALL APIs are restricted", function()
        UnitName = makeAPIThrow("UnitName")
        UnitClass = makeAPIThrow("UnitClass")
        UnitGroupRolesAssigned = makeAPIThrow("UnitGroupRolesAssigned")
        GetInstanceInfo = makeAPIThrow("GetInstanceInfo")

        local BossKills = ns.addon:GetModule("BossKills")
        BossKills:RecordBossKill(77778, "Fully Restricted Boss", 16, 20)
        Database:Flush()

        local events = Database:GetEvents()
        A.isTrue(#events >= 1, "Should still record boss kill even with all APIs restricted")

        local event = events[1]
        A.equals("Fully Restricted Boss", event.encounterName)
        A.isNil(event.instanceName, "Instance name should be nil")
        A.equals(0, #event.roster, "Roster should be empty")
    end)

    it("should handle ENCOUNTER_END → BOSS_KILL sequence under restrictions", function()
        GetInstanceInfo = makeAPIThrow("GetInstanceInfo")

        local BossKills = ns.addon:GetModule("BossKills")

        -- ENCOUNTER_END fires first (has all args)
        BossKills:OnEncounterEnd(nil, 66666, "Sequenced Boss", 16, 20, 1)

        -- BOSS_KILL fires second (needs GetInstanceInfo which is restricted)
        BossKills:OnBossKill(nil, 66666, "Sequenced Boss")

        Database:Flush()

        -- Should only have 1 event (dedup should prevent the second)
        local data = Database:GetGuildData()
        local count = 0
        for _, e in ipairs(data.events) do
            if e.encounterID == 66666 then count = count + 1 end
        end
        A.equals(1, count, "Dedup should prevent duplicate even under restrictions")
    end)
end)
