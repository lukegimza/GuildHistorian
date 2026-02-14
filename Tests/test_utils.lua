-------------------------------------------------------------------------------
-- Unit Tests: Core/Utils.lua
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

describe("Utils.TimestampToDisplay", function()
    it("should return a formatted date string", function()
        local result = ns.Utils.TimestampToDisplay(1700000000)
        A.isString(result)
        A.isTrue(#result > 0)
        -- Should contain year, month, day and time
        A.isTrue(result:match("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d") ~= nil,
            "Expected YYYY-MM-DD HH:MM format, got: " .. result)
    end)

    it("should return 'Unknown' for nil input", function()
        A.equals("Unknown", ns.Utils.TimestampToDisplay(nil))
    end)
end)

describe("Utils.TimestampToDate", function()
    it("should return a date-only string", function()
        local result = ns.Utils.TimestampToDate(1700000000)
        A.isString(result)
        A.isTrue(result:match("%d%d%d%d%-%d%d%-%d%d") ~= nil,
            "Expected YYYY-MM-DD format, got: " .. result)
    end)

    it("should return 'Unknown' for nil input", function()
        A.equals("Unknown", ns.Utils.TimestampToDate(nil))
    end)
end)

describe("Utils.TimestampToMonthDay", function()
    it("should return month and day numbers", function()
        local month, day = ns.Utils.TimestampToMonthDay(1700000000)
        A.isNumber(month)
        A.isNumber(day)
        A.isTrue(month >= 1 and month <= 12, "Month should be 1-12")
        A.isTrue(day >= 1 and day <= 31, "Day should be 1-31")
    end)
end)

describe("Utils.TimestampToYear", function()
    it("should return a year number", function()
        local year = ns.Utils.TimestampToYear(1700000000)
        A.isNumber(year)
        A.isTrue(year >= 2023 and year <= 2030, "Year should be reasonable")
    end)
end)

describe("Utils.RelativeTime", function()
    beforeEach(function()
        MockState.serverTime = 1700000000
    end)

    it("should return 'just now' for very recent timestamps", function()
        local result = ns.Utils.RelativeTime(1700000000 - 30)
        A.equals("just now", result)
    end)

    it("should return minutes for timestamps < 1 hour ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 300)
        A.contains("minute", result)
    end)

    it("should handle singular minute", function()
        local result = ns.Utils.RelativeTime(1700000000 - 60)
        A.contains("1 minute ago", result)
    end)

    it("should return hours for timestamps < 1 day ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 7200)
        A.contains("hour", result)
    end)

    it("should handle singular hour", function()
        local result = ns.Utils.RelativeTime(1700000000 - 3600)
        A.contains("1 hour ago", result)
    end)

    it("should return days for timestamps < 1 week ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 172800)
        A.contains("day", result)
    end)

    it("should return weeks for timestamps < 1 month ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 1209600)
        A.contains("week", result)
    end)

    it("should return months for timestamps < 1 year ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 5184000)
        A.contains("month", result)
    end)

    it("should return years for timestamps > 1 year ago", function()
        local result = ns.Utils.RelativeTime(1700000000 - 63072000)
        A.contains("year", result)
    end)
end)

describe("Utils.GetPlayerID", function()
    beforeEach(function()
        MockState:Reset()
    end)

    it("should return Name-Realm format", function()
        local id = ns.Utils.GetPlayerID()
        A.equals("TestPlayer-TestRealm", id)
    end)

    it("should strip spaces from realm name", function()
        MockState.playerRealm = "Moon Guard"
        local id = ns.Utils.GetPlayerID()
        A.equals("TestPlayer-MoonGuard", id)
    end)

    it("should return nil when player name is unavailable", function()
        MockState.playerName = nil
        local id = ns.Utils.GetPlayerID()
        A.isNil(id)
    end)
end)

describe("Utils.GetGuildKey", function()
    beforeEach(function()
        MockState:Reset()
    end)

    it("should return GuildName-Realm format", function()
        local key = ns.Utils.GetGuildKey()
        A.isString(key)
        A.contains("Test Guild", key)
    end)

    it("should return nil when not in a guild", function()
        MockState.inGuild = false
        local key = ns.Utils.GetGuildKey()
        A.isNil(key)
    end)
end)

describe("Utils.safecall", function()
    it("should call the function and return true on success", function()
        local called = false
        local ok = ns.Utils.safecall(function() called = true end)
        A.isTrue(ok)
        A.isTrue(called)
    end)

    it("should return false for non-function input", function()
        local ok = ns.Utils.safecall("not a function")
        A.isFalse(ok)
    end)

    it("should not propagate errors from the called function", function()
        local ok = ns.Utils.safecall(function() error("test error") end)
        A.isFalse(ok)
    end)

    it("should pass arguments through", function()
        local received = nil
        ns.Utils.safecall(function(x) received = x end, 42)
        A.equals(42, received)
    end)
end)

describe("Utils.ClassColoredName", function()
    it("should return colored name for valid class", function()
        local result = ns.Utils.ClassColoredName("TestPlayer", "WARRIOR")
        A.isString(result)
        A.contains("TestPlayer", result)
        A.contains("|c", result, "Should contain color escape code")
        A.contains("|r", result, "Should contain reset code")
    end)

    it("should return plain name for unknown class", function()
        local result = ns.Utils.ClassColoredName("TestPlayer", "UNKNOWN_CLASS")
        A.equals("TestPlayer", result)
    end)

    it("should return plain name for nil class", function()
        local result = ns.Utils.ClassColoredName("TestPlayer", nil)
        A.equals("TestPlayer", result)
    end)
end)

describe("Utils.GetDifficultyName", function()
    it("should return known difficulty names", function()
        A.equals("Mythic", ns.Utils.GetDifficultyName(16))
        A.equals("Heroic", ns.Utils.GetDifficultyName(15))
        A.equals("Normal", ns.Utils.GetDifficultyName(14))
        A.equals("Looking For Raid", ns.Utils.GetDifficultyName(17))
    end)

    it("should return 'Unknown' for nil", function()
        A.equals("Unknown", ns.Utils.GetDifficultyName(nil))
    end)

    it("should fall back to GetDifficultyInfo for unknown IDs", function()
        -- ID 1 is in both ns.DIFFICULTY_NAMES and GetDifficultyInfo mock
        A.equals("Normal", ns.Utils.GetDifficultyName(1))
    end)
end)

describe("Utils.DeepCopy", function()
    it("should copy a simple table", function()
        local orig = { a = 1, b = "hello" }
        local copy = ns.Utils.DeepCopy(orig)
        A.equals(1, copy.a)
        A.equals("hello", copy.b)
    end)

    it("should produce an independent copy", function()
        local orig = { a = 1, nested = { x = 10 } }
        local copy = ns.Utils.DeepCopy(orig)
        copy.a = 2
        copy.nested.x = 20
        A.equals(1, orig.a, "Original should be unchanged")
        A.equals(10, orig.nested.x, "Original nested should be unchanged")
    end)

    it("should handle nested tables", function()
        local orig = { a = { b = { c = 42 } } }
        local copy = ns.Utils.DeepCopy(orig)
        A.equals(42, copy.a.b.c)
    end)

    it("should return non-table values as-is", function()
        A.equals(42, ns.Utils.DeepCopy(42))
        A.equals("hello", ns.Utils.DeepCopy("hello"))
        A.equals(true, ns.Utils.DeepCopy(true))
        A.isNil(ns.Utils.DeepCopy(nil))
    end)

    it("should copy arrays correctly", function()
        local orig = { 1, 2, 3 }
        local copy = ns.Utils.DeepCopy(orig)
        A.arrayLength(3, copy)
        A.equals(1, copy[1])
        A.equals(3, copy[3])
    end)
end)

describe("Utils.Truncate", function()
    it("should not truncate short strings", function()
        A.equals("hello", ns.Utils.Truncate("hello", 10))
    end)

    it("should truncate long strings with ellipsis", function()
        local result = ns.Utils.Truncate("this is a very long string", 10)
        A.equals(10, #result)
        A.isTrue(result:sub(-3) == "...", "Should end with ellipsis")
    end)

    it("should return empty string for nil input", function()
        A.equals("", ns.Utils.Truncate(nil, 10))
    end)

    it("should handle exact-length strings", function()
        A.equals("hello", ns.Utils.Truncate("hello", 5))
    end)

    it("should handle max length of 3 (minimum for ellipsis)", function()
        local result = ns.Utils.Truncate("hello", 3)
        A.equals("...", result)
    end)
end)
