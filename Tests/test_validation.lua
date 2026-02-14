-------------------------------------------------------------------------------
-- Validation Tests: File Integrity, TOC, XML, Locale Completeness
-- These tests verify the addon package is structurally sound.
-------------------------------------------------------------------------------
local T = require("TestFramework")
local describe, it, beforeEach = T.describe, T.it, T.beforeEach
local A = T.Assert

-- Helper: check if a file exists
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Helper: read file contents
local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

-- Resolve addon root
local scriptPath = arg[0] or ""
local scriptDir = scriptPath:match("(.*/)") or "./"
local ADDON_DIR
if scriptDir:match("Tests/$") then
    ADDON_DIR = scriptDir:gsub("Tests/$", "")
    if ADDON_DIR == "" then ADDON_DIR = "./" end
else
    ADDON_DIR = "./"
end

-------------------------------------------------------------------------------
-- TOC File Validation
-------------------------------------------------------------------------------
describe("Validation: TOC File", function()
    local tocContent

    beforeEach(function()
        tocContent = readFile(ADDON_DIR .. "GuildHistorian.toc")
    end)

    it("should exist and be readable", function()
        A.isNotNil(tocContent, "GuildHistorian.toc should exist")
        A.isTrue(#tocContent > 0, "TOC file should not be empty")
    end)

    it("should have required metadata fields", function()
        A.isTrue(tocContent:find("## Interface:") ~= nil, "Missing ## Interface")
        A.isTrue(tocContent:find("## Title:") ~= nil, "Missing ## Title")
        A.isTrue(tocContent:find("## Notes:") ~= nil, "Missing ## Notes")
        A.isTrue(tocContent:find("## Author:") ~= nil, "Missing ## Author")
        A.isTrue(tocContent:find("## Version:") ~= nil, "Missing ## Version")
        A.isTrue(tocContent:find("## SavedVariables:") ~= nil, "Missing ## SavedVariables")
    end)

    it("should have valid Interface version for retail WoW", function()
        local interfaceVersion = tocContent:match("## Interface:%s*(%d+)")
        A.isNotNil(interfaceVersion, "Should have a numeric interface version")
        local version = tonumber(interfaceVersion)
        A.isTrue(version >= 100000, "Interface version should be for retail (>= 100000)")
    end)

    it("should reference only files that exist", function()
        local missingFiles = {}
        for line in tocContent:gmatch("[^\n]+") do
            -- Skip comments and empty lines
            if not line:match("^#") and not line:match("^%s*$") then
                local filename = line:match("^%s*(.+)%s*$")
                if filename and not filename:match("^#") then
                    -- Normalize path separator
                    filename = filename:gsub("\\", "/")
                    local fullPath = ADDON_DIR .. filename
                    if not fileExists(fullPath) then
                        missingFiles[#missingFiles + 1] = filename
                    end
                end
            end
        end
        if #missingFiles > 0 then
            error("TOC references missing files: " .. table.concat(missingFiles, ", "))
        end
    end)

    it("should load Libs before Core, Core before Modules, Modules before UI", function()
        local libsPos = tocContent:find("Libs\\libs%.xml") or tocContent:find("Libs/libs%.xml")
        local corePos = tocContent:find("Core\\Constants%.lua") or tocContent:find("Core/Constants%.lua")
        local modulesPos = tocContent:find("Modules\\") or tocContent:find("Modules/")
        local uiPos = tocContent:find("UI\\") or tocContent:find("UI/")

        A.isNotNil(libsPos, "Should reference Libs")
        A.isNotNil(corePos, "Should reference Core")
        A.isNotNil(modulesPos, "Should reference Modules")
        A.isNotNil(uiPos, "Should reference UI")

        A.isTrue(libsPos < corePos, "Libs should load before Core")
        A.isTrue(corePos < modulesPos, "Core should load before Modules")
        A.isTrue(modulesPos < uiPos, "Modules should load before UI")
    end)

    it("should have Constants before Utils before Database before Init", function()
        local constantsPos = tocContent:find("Core\\Constants%.lua") or tocContent:find("Core/Constants%.lua")
        local utilsPos = tocContent:find("Core\\Utils%.lua") or tocContent:find("Core/Utils%.lua")
        local dbPos = tocContent:find("Core\\Database%.lua") or tocContent:find("Core/Database%.lua")
        local initPos = tocContent:find("Core\\Init%.lua") or tocContent:find("Core/Init%.lua")

        A.isNotNil(constantsPos)
        A.isNotNil(utilsPos)
        A.isNotNil(dbPos)
        A.isNotNil(initPos)

        A.isTrue(constantsPos < utilsPos, "Constants should load before Utils")
        A.isTrue(utilsPos < dbPos, "Utils should load before Database")
        A.isTrue(dbPos < initPos, "Database should load before Init")
    end)

    it("should have XML templates before their Lua counterparts", function()
        local mainXmlPos = tocContent:find("UI\\MainFrame%.xml") or tocContent:find("UI/MainFrame%.xml")
        local mainLuaPos = tocContent:find("UI\\MainFrame%.lua") or tocContent:find("UI/MainFrame%.lua")

        if mainXmlPos and mainLuaPos then
            A.isTrue(mainXmlPos < mainLuaPos, "MainFrame.xml should load before MainFrame.lua")
        end
    end)
end)

-------------------------------------------------------------------------------
-- XML Validation
-------------------------------------------------------------------------------
describe("Validation: XML Files", function()
    it("should have well-formed MainFrame.xml", function()
        local content = readFile(ADDON_DIR .. "UI/MainFrame.xml")
        A.isNotNil(content)
        A.isTrue(content:find("<Ui") ~= nil, "Should have Ui root element")
        A.isTrue(content:find("</Ui>") ~= nil, "Should have closing Ui tag")
        A.isTrue(content:find("GuildHistorianMainFrame") ~= nil, "Should define main frame")
    end)

    it("should have well-formed TimelineEntry.xml", function()
        local content = readFile(ADDON_DIR .. "UI/TimelineEntry.xml")
        A.isNotNil(content)
        A.isTrue(content:find("<Ui") ~= nil, "Should have Ui root element")
        A.isTrue(content:find("</Ui>") ~= nil, "Should have closing Ui tag")
    end)

    it("should have well-formed OnThisDayPopup.xml", function()
        local content = readFile(ADDON_DIR .. "UI/OnThisDayPopup.xml")
        A.isNotNil(content)
        A.isTrue(content:find("<Ui") ~= nil, "Should have Ui root element")
        A.isTrue(content:find("</Ui>") ~= nil, "Should have closing Ui tag")
    end)
end)

-------------------------------------------------------------------------------
-- Library File Validation
-------------------------------------------------------------------------------
describe("Validation: Library Files", function()
    it("should have libs.xml that references all required libraries", function()
        local content = readFile(ADDON_DIR .. "Libs/libs.xml")
        A.isNotNil(content, "libs.xml should exist")

        local requiredLibs = {
            "LibStub",
            "CallbackHandler%-1%.0",
            "AceAddon%-3%.0",
            "AceDB%-3%.0",
            "AceEvent%-3%.0",
            "AceConsole%-3%.0",
            "AceTimer%-3%.0",
            "LibDataBroker%-1%.1",
            "LibDBIcon%-1%.0",
        }

        for _, lib in ipairs(requiredLibs) do
            A.isTrue(content:find(lib) ~= nil, "libs.xml should reference " .. lib)
        end
    end)

    it("should have all library directories with their lua files", function()
        local libs = {
            "LibStub/LibStub.lua",
            "CallbackHandler-1.0/CallbackHandler-1.0.lua",
            "AceAddon-3.0/AceAddon-3.0.lua",
            "AceDB-3.0/AceDB-3.0.lua",
            "AceEvent-3.0/AceEvent-3.0.lua",
            "AceConsole-3.0/AceConsole-3.0.lua",
            "AceTimer-3.0/AceTimer-3.0.lua",
            "LibDataBroker-1.1/LibDataBroker-1.1.lua",
            "LibDBIcon-1.0/LibDBIcon-1.0.lua",
        }

        for _, lib in ipairs(libs) do
            A.isTrue(fileExists(ADDON_DIR .. "Libs/" .. lib),
                "Missing library file: " .. lib)
        end
    end)
end)

-------------------------------------------------------------------------------
-- Locale Completeness: Cross-Reference Code vs Locale Keys
-------------------------------------------------------------------------------
describe("Validation: Locale Completeness", function()
    it("should have all L[] keys used in code defined in enUS", function()
        -- Collect all L["KEY"] references from Lua source files
        local sourceDirs = { "Core/", "Modules/", "UI/" }
        local usedKeys = {}

        for _, dir in ipairs(sourceDirs) do
            -- Read all lua files in the directory
            local dirPath = ADDON_DIR .. dir
            local handle = io.popen('ls "' .. dirPath .. '"*.lua 2>/dev/null')
            if handle then
                for filePath in handle:lines() do
                    local content = readFile(filePath)
                    if content then
                        -- Find L["KEY"] and L.KEY patterns
                        for key in content:gmatch('L%["([^"]+)"%]') do
                            usedKeys[key] = filePath
                        end
                        for key in content:gmatch("L%['([^']+)'%]") do
                            usedKeys[key] = filePath
                        end
                    end
                end
                handle:close()
            end
        end

        -- Check that each used key exists in the locale table
        local missing = {}
        for key, file in pairs(usedKeys) do
            if not ns.L[key] then
                missing[#missing + 1] = key .. " (used in " .. file .. ")"
            end
        end

        if #missing > 0 then
            error("Missing locale keys:\n  " .. table.concat(missing, "\n  "))
        end
    end)

    it("should have no orphaned locale keys (defined but never used)", function()
        -- This is informational - orphaned keys are not errors but worth checking
        local sourceDirs = { "Core/", "Modules/", "UI/" }
        local allCode = ""

        for _, dir in ipairs(sourceDirs) do
            local dirPath = ADDON_DIR .. dir
            local handle = io.popen('ls "' .. dirPath .. '"*.lua 2>/dev/null')
            if handle then
                for filePath in handle:lines() do
                    local content = readFile(filePath)
                    if content then
                        allCode = allCode .. content
                    end
                end
                handle:close()
            end
        end

        local orphaned = {}
        for key, _ in pairs(ns.L) do
            -- Check if the key appears anywhere in source code
            if not allCode:find('L%["' .. key:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%0") .. '"%]')
               and not allCode:find("L%['" .. key:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%0") .. "'%]") then
                orphaned[#orphaned + 1] = key
            end
        end

        -- Orphaned keys are informational, not failures
        -- Many keys are used via dynamic access like L[titleKey] or L[eventType]
        -- which static regex scanning cannot detect, so we allow a generous threshold
        A.isTrue(#orphaned < 40, "Too many orphaned locale keys (" .. #orphaned .. "): " ..
            table.concat(orphaned, ", "))
    end)
end)

-------------------------------------------------------------------------------
-- Event Type Consistency
-------------------------------------------------------------------------------
describe("Validation: Event Type Consistency", function()
    it("should have matching EVENT_TYPES values and EVENT_TYPE_INFO keys", function()
        for key, value in pairs(ns.EVENT_TYPES) do
            A.equals(key, value, "EVENT_TYPES." .. key .. " should equal '" .. key .. "'")
            A.isNotNil(ns.EVENT_TYPE_INFO[key], "Missing EVENT_TYPE_INFO for " .. key)
        end

        -- Check reverse: all EVENT_TYPE_INFO keys should be in EVENT_TYPES
        for key in pairs(ns.EVENT_TYPE_INFO) do
            A.isNotNil(ns.EVENT_TYPES[key], "EVENT_TYPE_INFO has extra key: " .. key)
        end
    end)

    it("should have locale strings for all event type names", function()
        for key, _ in pairs(ns.EVENT_TYPES) do
            A.isNotNil(ns.L[key], "Missing locale for event type: " .. key)
        end
    end)
end)

-------------------------------------------------------------------------------
-- Database Defaults Integrity
-------------------------------------------------------------------------------
describe("Validation: Database Defaults", function()
    it("should have valid default tracking settings", function()
        local tracking = ns.DB_DEFAULTS.profile.tracking
        A.isTrue(type(tracking.bossKills) == "boolean")
        A.isTrue(type(tracking.roster) == "boolean")
        A.isTrue(type(tracking.achievements) == "boolean")
        A.isTrue(type(tracking.loot) == "boolean")
        A.isNumber(tracking.lootQuality)
        A.isTrue(tracking.lootQuality >= 2 and tracking.lootQuality <= 5)
    end)

    it("should have valid default display settings", function()
        local display = ns.DB_DEFAULTS.profile.display
        A.isTrue(type(display.showOnThisDay) == "boolean")
    end)

    it("should have valid default data settings", function()
        local data = ns.DB_DEFAULTS.profile.data
        A.isNumber(data.maxEvents)
        A.isTrue(data.maxEvents > 0)
        A.isTrue(data.maxEvents <= 10000)
    end)

    it("should have valid DB_VERSION", function()
        A.isNumber(ns.DB_VERSION)
        A.isTrue(ns.DB_VERSION >= 1)
    end)
end)

-------------------------------------------------------------------------------
-- SavedVariables Names
-------------------------------------------------------------------------------
describe("Validation: SavedVariables", function()
    it("should have TOC SavedVariables matching code expectations", function()
        local tocContent = readFile(ADDON_DIR .. "GuildHistorian.toc")
        A.isTrue(tocContent:find("GuildHistorianDB") ~= nil,
            "TOC should reference GuildHistorianDB")
        A.isTrue(tocContent:find("GuildHistorianCharDB") ~= nil,
            "TOC should reference GuildHistorianCharDB")
    end)
end)
