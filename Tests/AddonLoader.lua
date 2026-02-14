-------------------------------------------------------------------------------
-- Addon Loader - Simulates WoW's file loading order from the .toc file
-- Loads the addon namespace and all source files in the correct order.
-------------------------------------------------------------------------------

-- Determine the addon root directory from the script path
-- When run as: lua Tests/run_tests.lua  (from GuildHistorian dir)
-- arg[0] = "Tests/run_tests.lua"
-- We need the parent of the Tests dir
local scriptPath = arg[0] or ""
local scriptDir = scriptPath:match("(.*/)") or "./"

-- The addon root is the parent of the Tests directory
local ADDON_DIR
if scriptDir:match("Tests/$") then
    ADDON_DIR = scriptDir:gsub("Tests/$", "")
    if ADDON_DIR == "" then ADDON_DIR = "./" end
elseif scriptDir:match("Tests$") then
    ADDON_DIR = scriptDir:gsub("Tests$", "")
    if ADDON_DIR == "" then ADDON_DIR = "./" end
else
    ADDON_DIR = scriptDir .. "../"
end

-- Debug: show resolved path
print("[AddonLoader] Resolved addon root: " .. ADDON_DIR)

-- The addon name and namespace table, as WoW provides via `local GH, ns = ...`
local ADDON_NAME = "GuildHistorian"
local ns = {}

--- Load a file with the addon name and namespace injected (simulating WoW's vararg)
local function loadAddonFile(relativePath)
    local fullPath = ADDON_DIR .. relativePath
    local chunk, err = loadfile(fullPath)
    if not chunk then
        print("[AddonLoader] WARNING: Could not load " .. relativePath .. ": " .. tostring(err))
        return false
    end
    -- In WoW, each file gets `local GH, ns = ...` from the addon vararg
    local ok, loadErr = pcall(chunk, ADDON_NAME, ns)
    if not ok then
        print("[AddonLoader] ERROR executing " .. relativePath .. ": " .. tostring(loadErr))
        return false
    end
    return true
end

-- Load files in the same order as GuildHistorian.toc (minus XML, Libs, and UI files)
-- UI files require WoW's frame system and cannot be loaded in test environment.
-- The load order matches the TOC:
--   Locales/enUS.lua
--   Core/Constants.lua
--   Core/Utils.lua
--   Core/DataModules.lua
--   Core/Init.lua
--   UI/MainFrame.lua       (requires XML frames - skipped in tests)
--   UI/DashboardCards.lua   (requires XML frames - skipped in tests)
--   UI/Dashboard.lua        (requires XML frames - skipped in tests)
--   UI/TimelineEntry.lua    (requires XML frames - skipped in tests)
--   UI/Timeline.lua         (requires XML frames - skipped in tests)
--   UI/FilterBar.lua        (requires XML frames - skipped in tests)
--   UI/OnThisDayPopup.lua   (requires XML frames - skipped in tests)
--   UI/SettingsPanel.lua    (requires XML frames - skipped in tests)
--   UI/MinimapButton.lua    (requires XML frames - skipped in tests)
local loadOrder = {
    -- Localization
    "Locales/enUS.lua",

    -- Core
    "Core/Constants.lua",
    "Core/Utils.lua",
    "Core/DataModules.lua",
    "Core/Init.lua",
}

print("[AddonLoader] Loading GuildHistorian addon files...")

for _, file in ipairs(loadOrder) do
    local ok = loadAddonFile(file)
    if ok then
        print(string.format("[AddonLoader]   Loaded: %s", file))
    end
end

-- Initialize the addon (simulating what WoW does after loading all files)
if ns.addon then
    ns.addon:OnInitialize()
    print("[AddonLoader] Addon initialized.")
end

print("[AddonLoader] All files loaded successfully.\n")

-- Export the namespace for tests
return ns
