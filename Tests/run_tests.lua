#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- GuildHistorian Test Runner
-- Loads the WoW mock, addon files, and all test suites, then runs them.
--
-- Usage: lua Tests/run_tests.lua
-- Run from the GuildHistorian directory.
-------------------------------------------------------------------------------

-- Resolve paths
local scriptDir = arg[0]:match("(.*/)") or "./"
local addonDir = scriptDir:gsub("Tests/", "")
if addonDir == "" then addonDir = "../" end

-- Add the Tests directory to the module search path
package.path = scriptDir .. "?.lua;" .. package.path

print("============================================================")
print("  GuildHistorian Test Suite")
print("============================================================")
print(string.format("  Lua version: %s", _VERSION))
print(string.format("  Test dir:    %s", scriptDir))
print(string.format("  Addon dir:   %s", addonDir))
print("")

-- Step 1: Load WoW API mock
print("[Runner] Loading WoW API mock...")
dofile(scriptDir .. "WoWMock.lua")

-- Step 2: Load the addon files through AddonLoader
print("[Runner] Loading addon files...")
local ns = dofile(scriptDir .. "AddonLoader.lua")

-- Make ns globally accessible for test files
_G.ns = ns

-- Step 3: Load test framework
print("[Runner] Loading test framework...")
local T = require("TestFramework")

-- Step 4: Load all test files
print("[Runner] Loading test suites...")

dofile(scriptDir .. "test_utils.lua")
print("[Runner]   Loaded: test_utils.lua")

dofile(scriptDir .. "test_database.lua")
print("[Runner]   Loaded: test_database.lua")

dofile(scriptDir .. "test_modules.lua")
print("[Runner]   Loaded: test_modules.lua")

dofile(scriptDir .. "test_integration.lua")
print("[Runner]   Loaded: test_integration.lua")

dofile(scriptDir .. "test_stress.lua")
print("[Runner]   Loaded: test_stress.lua")

dofile(scriptDir .. "test_validation.lua")
print("[Runner]   Loaded: test_validation.lua")

dofile(scriptDir .. "test_wow12_compat.lua")
print("[Runner]   Loaded: test_wow12_compat.lua")

-- Step 5: Run all tests
print("\n[Runner] Executing tests...\n")
local success = T.run()

print("")
if success then
    print("  ALL TESTS PASSED")
    os.exit(0)
else
    print("  SOME TESTS FAILED")
    os.exit(1)
end
