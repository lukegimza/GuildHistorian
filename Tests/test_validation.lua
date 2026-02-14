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

    it("should have XML templates before their Lua counterparts", function()
        local mainXmlPos = tocContent:find("UI\\MainFrame%.xml") or tocContent:find("UI/MainFrame%.xml")
        local mainLuaPos = tocContent:find("UI\\MainFrame%.lua") or tocContent:find("UI/MainFrame%.lua")

        if mainXmlPos and mainLuaPos then
            A.isTrue(mainXmlPos < mainLuaPos, "MainFrame.xml should load before MainFrame.lua")
        end
    end)

    it("should list all required v2 files", function()
        local requiredFiles = {
            "Locales\\enUS.lua",
            "Core\\Constants.lua",
            "Core\\Utils.lua",
            "Core\\DataModules.lua",
            "Core\\Init.lua",
            "UI\\MainFrame.xml",
            "UI\\MainFrame.lua",
            "UI\\DashboardCards.lua",
            "UI\\Dashboard.lua",
            "UI\\TimelineEntry.xml",
            "UI\\TimelineEntry.lua",
            "UI\\Timeline.lua",
            "UI\\FilterBar.lua",
            "UI\\OnThisDayPopup.xml",
            "UI\\OnThisDayPopup.lua",
            "UI\\SettingsPanel.lua",
            "UI\\MinimapButton.lua",
        }

        for _, file in ipairs(requiredFiles) do
            A.isTrue(tocContent:find(file, 1, true) ~= nil,
                "TOC should list " .. file)
        end
    end)

    it("should not reference old v1 files", function()
        local oldFiles = {
            "Database.lua",
            "Modules\\",
            "DetailPanel",
            "ExportFrame",
            "StatsPanel",
            "GuildRoster",
            "BossKills",
            "LootTracker",
            "MilestoneDetector",
            "Notes.lua",
        }

        for _, old in ipairs(oldFiles) do
            A.isTrue(tocContent:find(old, 1, true) == nil,
                "TOC should NOT reference old v1 file: " .. old)
        end
    end)

    it("should have DashboardCards.lua before Dashboard.lua", function()
        local cardsPos = tocContent:find("DashboardCards%.lua")
        local dashPos = tocContent:find("Dashboard%.lua")
        A.isNotNil(cardsPos, "Should list DashboardCards.lua")
        A.isNotNil(dashPos, "Should list Dashboard.lua")
        A.isTrue(cardsPos < dashPos, "DashboardCards.lua should load before Dashboard.lua")
    end)
end)

-------------------------------------------------------------------------------
-- File Existence: All TOC-listed files should exist on disk
-------------------------------------------------------------------------------
describe("Validation: TOC File Existence", function()
    it("should have all Lua files listed in TOC on disk", function()
        local tocContent = readFile(ADDON_DIR .. "GuildHistorian.toc")
        A.isNotNil(tocContent)

        local missing = {}
        for line in tocContent:gmatch("[^\n]+") do
            -- Skip comments and metadata
            if not line:match("^#") and not line:match("^%s*$") then
                -- Normalize backslashes to forward slashes
                local file = line:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
                if file ~= "" then
                    if not fileExists(ADDON_DIR .. file) then
                        missing[#missing + 1] = file
                    end
                end
            end
        end

        if #missing > 0 then
            error("Files listed in TOC but missing on disk:\n  " .. table.concat(missing, "\n  "))
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
        local sourceDirs = { "Core/", "UI/" }
        local usedKeys = {}

        for _, dir in ipairs(sourceDirs) do
            local dirPath = ADDON_DIR .. dir
            local handle = io.popen('ls "' .. dirPath .. '"*.lua 2>/dev/null')
            if handle then
                for filePath in handle:lines() do
                    local content = readFile(filePath)
                    if content then
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
        local sourceDirs = { "Core/", "UI/" }
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
            if not allCode:find('L%["' .. key:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%0") .. '"%]')
               and not allCode:find("L%['" .. key:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%0") .. "'%]") then
                orphaned[#orphaned + 1] = key
            end
        end

        -- Allow a small number of orphaned keys (some may be used dynamically)
        A.isTrue(#orphaned < 10, "Too many orphaned locale keys (" .. #orphaned .. "): " ..
            table.concat(orphaned, ", "))
    end)
end)

-------------------------------------------------------------------------------
-- News Type Consistency (v2 replaces EVENT_TYPES with NEWS_TYPES)
-------------------------------------------------------------------------------
describe("Validation: News Type Consistency", function()
    it("should have NEWS_TYPE_INFO for all NEWS_TYPES values", function()
        for key, value in pairs(ns.NEWS_TYPES) do
            A.isNotNil(ns.NEWS_TYPE_INFO[value], "Missing NEWS_TYPE_INFO for " .. key .. " (value=" .. tostring(value) .. ")")
        end
    end)

    it("should have label and icon for each NEWS_TYPE_INFO entry", function()
        for id, info in pairs(ns.NEWS_TYPE_INFO) do
            A.isNotNil(info.label, "Missing label for NEWS_TYPE_INFO[" .. tostring(id) .. "]")
            A.isNotNil(info.icon, "Missing icon for NEWS_TYPE_INFO[" .. tostring(id) .. "]")
        end
    end)

    it("should have EVENT_LOG_TYPES defined", function()
        A.isNotNil(ns.EVENT_LOG_TYPES)
        A.isNotNil(ns.EVENT_LOG_TYPES.INVITE)
        A.isNotNil(ns.EVENT_LOG_TYPES.JOIN)
        A.isNotNil(ns.EVENT_LOG_TYPES.QUIT)
    end)
end)

-------------------------------------------------------------------------------
-- Database Defaults Integrity
-------------------------------------------------------------------------------
describe("Validation: Database Defaults", function()
    it("should have valid default display settings", function()
        local display = ns.DB_DEFAULTS.profile.display
        A.isTrue(type(display.showOnThisDay) == "boolean")
    end)

    it("should have valid default minimap settings", function()
        local minimap = ns.DB_DEFAULTS.profile.minimap
        A.isTrue(type(minimap.hide) == "boolean")
    end)

    it("should have valid default cards settings", function()
        local cards = ns.DB_DEFAULTS.profile.cards
        A.isNotNil(cards, "Should have cards settings")
        A.isTrue(type(cards.showGuildPulse) == "boolean")
        A.isTrue(type(cards.showOnThisDay) == "boolean")
    end)

    it("should have valid DB_VERSION", function()
        A.isNumber(ns.DB_VERSION)
        A.isTrue(ns.DB_VERSION >= 1)
    end)

    it("should have char defaults", function()
        A.isNotNil(ns.DB_DEFAULTS.char)
        A.isNotNil(ns.DB_DEFAULTS.char.lastOnThisDayDate)
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

-------------------------------------------------------------------------------
-- No Old v1 Files
-------------------------------------------------------------------------------
describe("Validation: No Old v1 Files", function()
    it("should not have old Database.lua in Core", function()
        A.isFalse(fileExists(ADDON_DIR .. "Core/Database.lua"),
            "Old Core/Database.lua should not exist")
    end)

    it("should not have old v1 UI files", function()
        local oldUI = { "DetailPanel.lua", "ExportFrame.lua", "StatsPanel.lua" }
        for _, file in ipairs(oldUI) do
            A.isFalse(fileExists(ADDON_DIR .. "UI/" .. file),
                "Old UI/" .. file .. " should not exist")
        end
    end)
end)
