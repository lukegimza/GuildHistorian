-------------------------------------------------------------------------------
-- Lightweight Test Framework for GuildHistorian
-- Provides describe/it/assert patterns with setup/teardown support.
-------------------------------------------------------------------------------

local TestFramework = {}

-- State tracking
local suites = {}
local currentSuite = nil
local results = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = {},
}

--- Define a test suite
--- @param name string Suite name
--- @param func function Suite body containing it() calls
function TestFramework.describe(name, func)
    currentSuite = {
        name = name,
        tests = {},
        beforeEach = nil,
        afterEach = nil,
        beforeAll = nil,
        afterAll = nil,
    }
    suites[#suites + 1] = currentSuite

    -- Execute the suite body to register tests
    func()

    currentSuite = nil
end

--- Register a setup function that runs before each test in the current suite
--- @param func function
function TestFramework.beforeEach(func)
    if currentSuite then
        currentSuite.beforeEach = func
    end
end

--- Register a teardown function that runs after each test in the current suite
--- @param func function
function TestFramework.afterEach(func)
    if currentSuite then
        currentSuite.afterEach = func
    end
end

--- Register a setup function that runs once before all tests in the suite
--- @param func function
function TestFramework.beforeAll(func)
    if currentSuite then
        currentSuite.beforeAll = func
    end
end

--- Register a teardown function that runs once after all tests in the suite
--- @param func function
function TestFramework.afterAll(func)
    if currentSuite then
        currentSuite.afterAll = func
    end
end

--- Define a single test case
--- @param name string Test name
--- @param func function Test body
function TestFramework.it(name, func)
    if not currentSuite then
        error("it() must be called inside describe()")
    end
    currentSuite.tests[#currentSuite.tests + 1] = {
        name = name,
        func = func,
    }
end

-------------------------------------------------------------------------------
-- Assertion Library
-------------------------------------------------------------------------------
local Assert = {}
TestFramework.Assert = Assert

function Assert.isTrue(value, msg)
    if not value then
        error(msg or string.format("Expected truthy, got %s", tostring(value)), 2)
    end
end

function Assert.isFalse(value, msg)
    if value then
        error(msg or string.format("Expected falsy, got %s", tostring(value)), 2)
    end
end

function Assert.isNil(value, msg)
    if value ~= nil then
        error(msg or string.format("Expected nil, got %s", tostring(value)), 2)
    end
end

function Assert.isNotNil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value, got nil", 2)
    end
end

function Assert.equals(expected, actual, msg)
    if expected ~= actual then
        error(msg or string.format("Expected %s, got %s", tostring(expected), tostring(actual)), 2)
    end
end

function Assert.notEquals(expected, actual, msg)
    if expected == actual then
        error(msg or string.format("Expected values to differ, both are %s", tostring(expected)), 2)
    end
end

function Assert.greaterThan(threshold, actual, msg)
    if not (actual > threshold) then
        error(msg or string.format("Expected %s > %s", tostring(actual), tostring(threshold)), 2)
    end
end

function Assert.greaterThanOrEqual(threshold, actual, msg)
    if not (actual >= threshold) then
        error(msg or string.format("Expected %s >= %s", tostring(actual), tostring(threshold)), 2)
    end
end

function Assert.lessThan(threshold, actual, msg)
    if not (actual < threshold) then
        error(msg or string.format("Expected %s < %s", tostring(actual), tostring(threshold)), 2)
    end
end

function Assert.isType(expected, value, msg)
    local actual = type(value)
    if actual ~= expected then
        error(msg or string.format("Expected type %s, got %s", expected, actual), 2)
    end
end

function Assert.isTable(value, msg)
    Assert.isType("table", value, msg)
end

function Assert.isString(value, msg)
    Assert.isType("string", value, msg)
end

function Assert.isNumber(value, msg)
    Assert.isType("number", value, msg)
end

function Assert.isFunction(value, msg)
    Assert.isType("function", value, msg)
end

function Assert.tableLength(expected, tbl, msg)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    if count ~= expected then
        error(msg or string.format("Expected table length %d, got %d", expected, count), 2)
    end
end

function Assert.arrayLength(expected, tbl, msg)
    if #tbl ~= expected then
        error(msg or string.format("Expected array length %d, got %d", expected, #tbl), 2)
    end
end

function Assert.contains(needle, haystack, msg)
    if type(haystack) == "string" then
        if not haystack:find(needle, 1, true) then
            error(msg or string.format("Expected string to contain '%s'", needle), 2)
        end
    elseif type(haystack) == "table" then
        for _, v in pairs(haystack) do
            if v == needle then return end
        end
        error(msg or string.format("Expected table to contain %s", tostring(needle)), 2)
    end
end

function Assert.tableHasKey(key, tbl, msg)
    if tbl[key] == nil then
        error(msg or string.format("Expected table to have key '%s'", tostring(key)), 2)
    end
end

function Assert.throws(func, msg)
    local ok, err = pcall(func)
    if ok then
        error(msg or "Expected function to throw an error, but it didn't", 2)
    end
    return err
end

function Assert.doesNotThrow(func, msg)
    local ok, err = pcall(func)
    if not ok then
        error(msg or string.format("Expected function not to throw, but got: %s", tostring(err)), 2)
    end
end

-------------------------------------------------------------------------------
-- Test Runner
-------------------------------------------------------------------------------

function TestFramework.run()
    results.total = 0
    results.passed = 0
    results.failed = 0
    results.errors = {}

    local startTime = os.clock()

    for _, suite in ipairs(suites) do
        print(string.format("\n  %s", suite.name))
        print(string.rep("-", 60))

        if suite.beforeAll then
            local ok, err = pcall(suite.beforeAll)
            if not ok then
                print(string.format("    [FAIL] beforeAll: %s", err))
            end
        end

        for _, test in ipairs(suite.tests) do
            results.total = results.total + 1

            if suite.beforeEach then
                local ok, err = pcall(suite.beforeEach)
                if not ok then
                    results.failed = results.failed + 1
                    print(string.format("    [FAIL] beforeEach for '%s': %s", test.name, err))
                    goto continue
                end
            end

            local ok, err = xpcall(test.func, function(e)
                return debug.traceback(e, 2)
            end)

            if ok then
                results.passed = results.passed + 1
                print(string.format("    [PASS] %s", test.name))
            else
                results.failed = results.failed + 1
                -- Extract just the error message without full traceback for concise output
                local shortErr = tostring(err):match("^(.-)\n") or tostring(err)
                print(string.format("    [FAIL] %s", test.name))
                print(string.format("           %s", shortErr))
                results.errors[#results.errors + 1] = {
                    suite = suite.name,
                    test = test.name,
                    error = err,
                }
            end

            if suite.afterEach then
                pcall(suite.afterEach)
            end

            ::continue::
        end

        if suite.afterAll then
            pcall(suite.afterAll)
        end
    end

    local elapsed = os.clock() - startTime

    print("\n" .. string.rep("=", 60))
    print(string.format("  RESULTS: %d total, %d passed, %d failed (%.3fs)",
        results.total, results.passed, results.failed, elapsed))
    print(string.rep("=", 60))

    if results.failed > 0 then
        print(string.format("\n  FAILURES (%d):", results.failed))
        for _, e in ipairs(results.errors) do
            print(string.format("\n  [%s] %s:", e.suite, e.test))
            print(string.format("  %s", e.error))
        end
        print("")
    end

    -- Return success/failure for CI
    return results.failed == 0
end

--- Reset the framework state (useful between test file loads)
function TestFramework.reset()
    suites = {}
    currentSuite = nil
    results = {
        total = 0,
        passed = 0,
        failed = 0,
        errors = {},
    }
end

return TestFramework
