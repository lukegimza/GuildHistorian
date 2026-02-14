-------------------------------------------------------------------------------
-- WoW API Mock Layer for Unit Testing
-- Simulates the World of Warcraft Lua environment outside the game client.
-------------------------------------------------------------------------------

-- Lua 5.4 compatibility: provide 5.1-style global functions WoW addons expect
if not bit then
    bit = {}
    function bit.band(a, b) return a & b end
    function bit.bor(a, b) return a | b end
    function bit.bxor(a, b) return a ~ b end
    function bit.lshift(a, n) return a << n end
    function bit.rshift(a, n) return a >> n end
end

if not loadstring then
    loadstring = load
end

-- WoW exposes os.date as a global `date`
if not date then
    date = os.date
end

-- WoW global string helpers (these exist as global functions in WoW)
format = string.format
strlower = string.lower
strupper = string.upper
strsub = string.sub
strlen = string.len
strfind = string.find
strmatch = string.match
strsplit = function(delimiter, str, limit)
    local parts = {}
    local pattern = "([^" .. delimiter .. "]*)" .. delimiter .. "?"
    local count = 0
    for part in str:gmatch(pattern) do
        count = count + 1
        parts[count] = part
        if limit and count >= limit then break end
    end
    return table.unpack(parts)
end
strtrim = function(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

-- Math shortcuts
max = math.max
min = math.min
floor = math.floor
ceil = math.ceil
abs = math.abs
random = math.random

-- Table helpers
tinsert = table.insert
tremove = table.remove
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
function tContains(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- Mock State - controllable from tests
-------------------------------------------------------------------------------
local MockState = {
    serverTime = 1700000000,
    playerName = "TestPlayer",
    playerRealm = "TestRealm",
    playerClass = "WARRIOR",
    inGuild = true,
    guildName = "Test Guild",
    guildRealm = nil, -- nil uses GetRealmName
    guildMembers = {},
    instanceName = "Test Instance",
    difficultyID = 16,
    groupMembers = {},
    inRaid = false,
    inGroup = false,
    numGroupMembers = 0,
    maxPlayerLevel = 80,
    achievements = {},
    items = {},
    raidClassColors = {},
    messages = {},
    events = {},
    guildNews = {},
    guildAchievements = {},
    guildEventLog = {},
    numGuildNews = 0,
    numGuildEvents = 0,
    achievementCategories = {},
}

-- Export MockState so tests can control it
_G.MockState = MockState

function MockState:Reset()
    self.serverTime = 1700000000
    self.playerName = "TestPlayer"
    self.playerRealm = "TestRealm"
    self.playerClass = "WARRIOR"
    self.inGuild = true
    self.guildName = "Test Guild"
    self.guildRealm = nil
    self.guildMembers = {}
    self.instanceName = "Test Instance"
    self.difficultyID = 16
    self.groupMembers = {}
    self.inRaid = false
    self.inGroup = false
    self.numGroupMembers = 0
    self.maxPlayerLevel = 80
    self.achievements = {}
    self.items = {}
    self.messages = {}
    self.events = {}
    self.guildNews = {}
    self.guildAchievements = {}
    self.guildEventLog = {}
    self.numGuildNews = 0
    self.numGuildEvents = 0
    self.achievementCategories = {}
end

-------------------------------------------------------------------------------
-- Core WoW API Functions
-------------------------------------------------------------------------------

function GetServerTime()
    return MockState.serverTime
end

function GetTime()
    return MockState.serverTime
end

function GetRealmName()
    return MockState.playerRealm
end

function UnitFullName(unit)
    if unit == "player" then
        return MockState.playerName, MockState.playerRealm
    end
    -- Check group members
    if MockState.groupMembers then
        for _, member in ipairs(MockState.groupMembers) do
            if member.unit == unit then
                return member.name, member.realm
            end
        end
    end
    return nil, nil
end

function UnitName(unit)
    return UnitFullName(unit)
end

function UnitClass(unit)
    if unit == "player" then
        return MockState.playerClass, MockState.playerClass
    end
    if MockState.groupMembers then
        for _, member in ipairs(MockState.groupMembers) do
            if member.unit == unit then
                return member.class, member.class
            end
        end
    end
    return "Unknown", "UNKNOWN"
end

function UnitGUID(unit)
    return "Player-1234-" .. (unit or "unknown")
end

function UnitLevel(unit)
    return MockState.maxPlayerLevel
end

function UnitGroupRolesAssigned(unit)
    if MockState.groupMembers then
        for _, member in ipairs(MockState.groupMembers) do
            if member.unit == unit then
                return member.role or "NONE"
            end
        end
    end
    return "NONE"
end

function UnitIsGroupLeader(unit)
    return unit == "player"
end

function IsInGuild()
    return MockState.inGuild
end

function IsInRaid()
    return MockState.inRaid
end

function IsInGroup()
    return MockState.inGroup
end

function IsInInstance()
    return MockState.instanceName ~= nil
end

function GetInstanceInfo()
    return MockState.instanceName, "raid", MockState.difficultyID, "Mythic", 20, 0, false, 0, 0
end

function GetDifficultyInfo(id)
    local names = {
        [1] = "Normal", [2] = "Heroic", [14] = "Normal", [15] = "Heroic",
        [16] = "Mythic", [17] = "Looking For Raid", [23] = "Mythic",
    }
    return names[id] or "Unknown"
end

function GetNumGroupMembers()
    return MockState.numGroupMembers
end

function InCombatLockdown()
    return false
end

function GetGuildInfo(unit)
    if MockState.inGuild then
        return MockState.guildName, "Guild Master", 0, MockState.guildRealm
    end
    return nil
end

function GetNumGuildMembers()
    return #MockState.guildMembers
end

function GetNumGuildNews()
    return MockState.numGuildNews
end

function GetMaxPlayerLevel()
    return MockState.maxPlayerLevel
end

function QueryGuildEventLog() end

function GetNumGuildEvents()
    return MockState.numGuildEvents
end

function GetGuildEventInfo(index)
    local entry = MockState.guildEventLog[index]
    if not entry then return nil end
    return entry.eventType, entry.playerName1, entry.playerName2, entry.rankIndex, entry.timestamp
end

function GetGuildRosterInfo(index)
    local member = MockState.guildMembers[index]
    if not member then return nil end
    return member.name,
        member.rank or "Member",
        member.rankIndex or 1,
        member.level or 80,
        member.classDisplayName or "Warrior",
        member.zone or "Orgrimmar",
        member.publicNote or "",
        member.officerNote or "",
        member.online or false,
        member.status or 0,
        member.class or "WARRIOR",
        member.achievementPoints or 0,
        member.achievementRank or 0,
        member.isMobile or false,
        member.isSoREligible or false,
        member.standingID or 0
end

function GetAchievementInfo(id)
    local ach = MockState.guildAchievements[id] or MockState.achievements[id]
    if ach then
        return id, ach.name or "Achievement", ach.points or 10,
            ach.completed or false,
            ach.month, ach.day, ach.year,
            ach.description or "", ach.flags or 0,
            ach.icon or 0, "", ach.isGuild or false,
            ach.wasEarnedByMe or false, ach.earnedBy or "", false
    end
    return id, "Achievement " .. tostring(id), 10, false, nil, nil, nil, "Description", 0, 0, "", false, false, "", false
end

function GetCategoryList()
    local ids = {}
    for _, cat in ipairs(MockState.achievementCategories) do
        ids[#ids + 1] = cat.id
    end
    return ids
end

function GetCategoryInfo(categoryID)
    for _, cat in ipairs(MockState.achievementCategories) do
        if cat.id == categoryID then
            return cat.name or "Category", cat.parentID, 0
        end
    end
    return "Unknown", nil, 0
end

function GetCategoryNumAchievements(categoryID, includeAll)
    for _, cat in ipairs(MockState.achievementCategories) do
        if cat.id == categoryID then
            return cat.numAchievements or 0, cat.numAchievements or 0, 0
        end
    end
    return 0, 0, 0
end

function GetItemInfo(link)
    if MockState.items[link] then
        local item = MockState.items[link]
        return item.name, link, item.quality or 4
    end
    -- Parse simple item links
    local name = link:match("%[(.-)%]")
    return name or "Unknown Item", link, 4
end

-------------------------------------------------------------------------------
-- WoW Constants
-------------------------------------------------------------------------------
MAX_PLAYER_LEVEL = 80
RAID_CLASS_COLORS = {
    WARRIOR = { colorStr = "ffc79c6e", r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { colorStr = "fff58cba", r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { colorStr = "ffabd473", r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { colorStr = "fffff569", r = 1.0, g = 0.96, b = 0.41 },
    PRIEST = { colorStr = "ffffffff", r = 1.0, g = 1.0, b = 1.0 },
    DEATHKNIGHT = { colorStr = "ffc41f3b", r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN = { colorStr = "ff0070de", r = 0.0, g = 0.44, b = 0.87 },
    MAGE = { colorStr = "ff69ccf0", r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { colorStr = "ff9482c9", r = 0.58, g = 0.51, b = 0.79 },
    MONK = { colorStr = "ff00ff96", r = 0.0, g = 1.0, b = 0.59 },
    DRUID = { colorStr = "ffff7d0a", r = 1.0, g = 0.49, b = 0.04 },
    DEMONHUNTER = { colorStr = "ffa330c9", r = 0.64, g = 0.19, b = 0.79 },
    EVOKER = { colorStr = "ff33937f", r = 0.2, g = 0.58, b = 0.5 },
}
ITEM_QUALITY_COLORS = {}
LE_ITEM_QUALITY_UNCOMMON = 2
LE_ITEM_QUALITY_RARE = 3
LE_ITEM_QUALITY_EPIC = 4
LE_ITEM_QUALITY_LEGENDARY = 5
SOUNDKIT = { IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840 }
Enum = {}
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_ID = 1

-------------------------------------------------------------------------------
-- C_GuildInfo and other C_ namespaces
-------------------------------------------------------------------------------
C_GuildInfo = {
    GuildRoster = function() end,
    QueryGuildNews = function() end,
    GetGuildNewsInfo = function(index)
        local entry = MockState.guildNews[index]
        if not entry then return nil end
        return entry
    end,
}

C_AddOns = {
    GetAddOnMetadata = function(addon, field)
        if field == "Version" then return "1.0.0" end
        return nil
    end,
}

C_AchievementInfo = {}
C_ChatInfo = {}
C_ClassColor = {}
C_DateAndTime = {}
C_Map = {}
C_Timer = {
    After = function(delay, callback)
        -- In tests, we can choose to call callback immediately or store it
        if callback then callback() end
    end,
}

Settings = {
    OpenToCategory = function() end,
    RegisterCanvasLayoutCategory = function(canvas, name)
        return { ID = name }
    end,
    RegisterAddOnCategory = function(category) end,
}

-------------------------------------------------------------------------------
-- Frame API Mock
-------------------------------------------------------------------------------
local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:SetSize(w, h) self._width = w; self._height = h end
function FrameMethods:SetWidth(w) self._width = w end
function FrameMethods:SetHeight(h) self._height = h end
function FrameMethods:GetWidth() return self._width or 0 end
function FrameMethods:GetHeight() return self._height or 0 end
function FrameMethods:SetPoint(...) end
function FrameMethods:ClearAllPoints() end
function FrameMethods:Show() self._visible = true end
function FrameMethods:Hide() self._visible = false end
function FrameMethods:IsShown() return self._visible or false end
function FrameMethods:IsVisible() return self._visible or false end
function FrameMethods:SetScript(name, func) self._scripts = self._scripts or {}; self._scripts[name] = func end
function FrameMethods:GetScript(name) return self._scripts and self._scripts[name] end
function FrameMethods:SetText(t) self._text = t end
function FrameMethods:GetText() return self._text or "" end
function FrameMethods:SetAlpha(a) self._alpha = a end
function FrameMethods:GetAlpha() return self._alpha or 1 end
function FrameMethods:SetMovable(m) end
function FrameMethods:EnableMouse(e) end
function FrameMethods:SetResizable(r) end
function FrameMethods:SetClampedToScreen(c) end
function FrameMethods:RegisterForDrag(...) end
function FrameMethods:SetBackdrop(b) end
function FrameMethods:SetBackdropColor(...) end
function FrameMethods:SetBackdropBorderColor(...) end
function FrameMethods:CreateTexture(name, layer)
    return CreateFrame("Texture", name, self)
end
function FrameMethods:CreateFontString(name, layer, template)
    local fs = CreateFrame("FontString", name, self)
    fs.SetFont = function(s, ...) end
    fs.SetJustifyH = function(s, ...) end
    fs.SetJustifyV = function(s, ...) end
    fs.SetWordWrap = function(s, ...) end
    return fs
end
function FrameMethods:SetTexture(...) end
function FrameMethods:SetTexCoord(...) end
function FrameMethods:SetVertexColor(...) end
function FrameMethods:SetNormalTexture(...) end
function FrameMethods:SetHighlightTexture(...) end
function FrameMethods:SetPushedTexture(...) end
function FrameMethods:SetFont(...) end
function FrameMethods:SetTextColor(...) end
function FrameMethods:SetMaxLetters(n) end
function FrameMethods:SetAutoFocus(b) end
function FrameMethods:SetMultiLine(b) end
function FrameMethods:SetCountInvisibleLetters(b) end
function FrameMethods:SetFocus() end
function FrameMethods:ClearFocus() end
function FrameMethods:HighlightText() end
function FrameMethods:Enable() self._enabled = true end
function FrameMethods:Disable() self._enabled = false end
function FrameMethods:IsEnabled() return self._enabled ~= false end
function FrameMethods:SetEnabled(e) self._enabled = e end
function FrameMethods:SetChecked(c) self._checked = c end
function FrameMethods:GetChecked() return self._checked end
function FrameMethods:SetMinMaxValues(mn, mx) self._min = mn; self._max = mx end
function FrameMethods:SetValue(v) self._value = v end
function FrameMethods:GetValue() return self._value or 0 end
function FrameMethods:SetValueStep(s) end
function FrameMethods:SetObeyStepOnDrag(b) end
function FrameMethods:RegisterEvent(e) self._registered = self._registered or {}; self._registered[e] = true end
function FrameMethods:UnregisterEvent(e) if self._registered then self._registered[e] = nil end end
function FrameMethods:UnregisterAllEvents() self._registered = {} end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:GetName() return self._name end
function FrameMethods:SetResizeBounds(...) end
function FrameMethods:SetFrameStrata(s) end
function FrameMethods:SetFrameLevel(l) end
function FrameMethods:SetToplevel(t) end
function FrameMethods:SetUserPlaced(b) end

function CreateFrame(frameType, name, parent, template, id)
    local frame = setmetatable({
        _type = frameType,
        _name = name,
        _parent = parent,
        _template = template,
        _visible = false,
        _children = {},
    }, FrameMethods)
    if name then
        _G[name] = frame
    end
    return frame
end

function CreateFromMixins(...)
    local result = {}
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        if mixin then
            for k, v in pairs(mixin) do
                result[k] = v
            end
        end
    end
    return result
end

BackdropTemplateMixin = {}
UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
GameTooltip.SetOwner = function() end
GameTooltip.ClearLines = function() end
GameTooltip.AddLine = function() end
GameTooltip.AddDoubleLine = function() end

function CreateScrollBoxListLinearView() return {} end
function CreateDataProvider(data) return { data = data or {} } end
function ScrollUtil() end

function PlaySound(id) end

function StaticPopup_Show(name) end
StaticPopupDialogs = {}

function geterrorhandler()
    return function(err)
        print("ERROR: " .. tostring(err))
    end
end

function debugprofilestop() return 0 end

function hooksecurefunc(...) end

function issecurevariable(...) return false end

function DevTools_Dump(...) end

function GetLocale() return "enUS" end

function GetBuildInfo() return "11.1.0", 57689, "Feb 4 2026", 110100 end

function GetAutoCompleteRealms() return {} end

function GetRealZoneText() return "Orgrimmar" end

function GetAchievementCriteriaInfo(achievementID, criteriaIndex) return nil end

-------------------------------------------------------------------------------
-- LibStub Mock
-------------------------------------------------------------------------------
local libs = {}
local libVersions = {}

LibStub = setmetatable({}, {
    __call = function(self, name, silent)
        if libs[name] then return libs[name], libVersions[name] end
        if silent then return nil end
        error("Cannot find a library instance of \"" .. tostring(name) .. "\".")
    end,
})

function LibStub:NewLibrary(name, version)
    local oldVersion = libVersions[name]
    if oldVersion and oldVersion >= version then return nil end
    libs[name] = libs[name] or {}
    libVersions[name] = version
    return libs[name]
end

function LibStub:GetLibrary(name, silent)
    return self(name, silent)
end

function LibStub:IterateLibraries()
    return pairs(libs)
end

-------------------------------------------------------------------------------
-- AceAddon Mock
-------------------------------------------------------------------------------
local AceAddon = LibStub:NewLibrary("AceAddon-3.0", 1)
local addons = {}

function AceAddon:NewAddon(name_or_obj, ...)
    local addonName, obj
    if type(name_or_obj) == "string" then
        addonName = name_or_obj
        obj = {}
    else
        -- name_or_obj is actually the first mixin name, the addon name came from ... vararg
        -- In WoW: local addon = LibStub("AceAddon-3.0"):NewAddon(GH, "AceConsole-3.0", ...)
        -- GH is actually the addon name string from `local GH, ns = ...`
        addonName = tostring(name_or_obj)
        obj = {}
    end

    local mixins = { ... }
    obj._name = addonName
    obj._modules = {}
    obj._messages = {}
    obj._timers = {}

    -- Mixin methods
    function obj:GetName() return self._name end

    -- AceEvent methods
    function obj:RegisterEvent(event, handler)
        self._events = self._events or {}
        self._events[event] = handler
    end
    function obj:UnregisterEvent(event)
        if self._events then self._events[event] = nil end
    end
    function obj:UnregisterAllEvents()
        self._events = {}
    end
    function obj:RegisterMessage(msg, handler)
        self._messages = self._messages or {}
        self._messages[msg] = handler
    end
    function obj:UnregisterMessage(msg)
        if self._messages then self._messages[msg] = nil end
    end
    function obj:SendMessage(msg, ...)
        -- Dispatch to all registered handlers
        for _, addon_obj in pairs(addons) do
            if addon_obj._messages and addon_obj._messages[msg] then
                local handler = addon_obj._messages[msg]
                if type(handler) == "function" then
                    handler(msg, ...)
                elseif type(handler) == "string" then
                    if addon_obj[handler] then
                        addon_obj[handler](addon_obj, msg, ...)
                    end
                end
            end
            -- Also check modules
            if addon_obj._modules then
                for _, mod in pairs(addon_obj._modules) do
                    if mod._messages and mod._messages[msg] then
                        local handler = mod._messages[msg]
                        if type(handler) == "function" then
                            handler(msg, ...)
                        elseif type(handler) == "string" then
                            if mod[handler] then
                                mod[handler](mod, msg, ...)
                            end
                        end
                    end
                end
            end
        end
    end

    -- AceConsole methods
    function obj:Print(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        table.insert(MockState.messages, table.concat(parts, " "))
    end
    function obj:RegisterChatCommand(cmd, func) end
    function obj:GetArgs(str, num)
        if not str or str == "" then return nil, nil end
        local args = {}
        for word in str:gmatch("%S+") do
            args[#args + 1] = word
        end
        if num == 2 then
            local first = args[1]
            local rest = str:match("^%S+%s+(.*)")
            return first, rest
        end
        return table.unpack(args)
    end

    -- AceTimer methods
    local timerCounter = 0
    function obj:ScheduleTimer(callback, delay)
        timerCounter = timerCounter + 1
        local id = "timer_" .. timerCounter
        obj._timers[id] = { callback = callback, delay = delay }
        return id
    end
    function obj:ScheduleRepeatingTimer(callback, interval)
        timerCounter = timerCounter + 1
        local id = "timer_" .. timerCounter
        obj._timers[id] = { callback = callback, interval = interval, repeating = true }
        return id
    end
    function obj:CancelTimer(id)
        if id then obj._timers[id] = nil end
    end
    function obj:CancelAllTimers()
        wipe(obj._timers)
    end

    -- Module system
    function obj:NewModule(name, ...)
        local mod = {}
        mod._name = name
        mod._parent = obj
        mod._messages = {}
        mod._events = {}
        mod._timers = {}

        -- Copy event/timer/message methods
        mod.RegisterEvent = obj.RegisterEvent
        mod.UnregisterEvent = obj.UnregisterEvent
        mod.UnregisterAllEvents = obj.UnregisterAllEvents
        mod.RegisterMessage = obj.RegisterMessage
        mod.UnregisterMessage = obj.UnregisterMessage
        mod.SendMessage = function(s, msg, ...) obj:SendMessage(msg, ...) end
        mod.ScheduleTimer = obj.ScheduleTimer
        mod.ScheduleRepeatingTimer = obj.ScheduleRepeatingTimer
        mod.CancelTimer = obj.CancelTimer
        mod.CancelAllTimers = obj.CancelAllTimers
        mod.Print = function(s, ...) obj:Print(...) end

        -- Store module
        obj._modules[name] = mod
        return mod
    end

    function obj:GetModule(name)
        return self._modules[name]
    end

    function obj:IterateModules()
        return pairs(self._modules)
    end

    -- Lifecycle stubs
    function obj:OnInitialize() end
    function obj:OnEnable() end
    function obj:OnDisable() end

    addons[addonName] = obj
    return obj
end

function AceAddon:GetAddon(name)
    return addons[name]
end

-------------------------------------------------------------------------------
-- AceDB Mock
-------------------------------------------------------------------------------
local AceDB = LibStub:NewLibrary("AceDB-3.0", 1)

function AceDB:New(svName, defaults, defaultProfile)
    local db = {}

    -- Deep copy defaults
    local function deepCopy(orig)
        if type(orig) ~= "table" then return orig end
        local copy = {}
        for k, v in pairs(orig) do
            copy[k] = deepCopy(v)
        end
        return copy
    end

    if defaults then
        if defaults.global then
            db.global = deepCopy(defaults.global)
        end
        if defaults.profile then
            db.profile = deepCopy(defaults.profile)
        end
        if defaults.char then
            db.char = deepCopy(defaults.char)
        end
    end

    db.global = db.global or {}
    db.profile = db.profile or {}
    db.char = db.char or {}

    return db
end

-------------------------------------------------------------------------------
-- Other library stubs
-------------------------------------------------------------------------------
LibStub:NewLibrary("AceConsole-3.0", 1)
LibStub:NewLibrary("AceEvent-3.0", 1)
LibStub:NewLibrary("AceTimer-3.0", 1)
LibStub:NewLibrary("CallbackHandler-1.0", 1)
LibStub:NewLibrary("LibDataBroker-1.1", 1)

local LDB = LibStub("LibDataBroker-1.1")
function LDB:NewDataObject(name, obj)
    return obj or {}
end

local LibDBIcon = LibStub:NewLibrary("LibDBIcon-1.0", 1)
function LibDBIcon:Register(name, obj, db) end
function LibDBIcon:Show(name) end
function LibDBIcon:Hide(name) end

print("[WoWMock] World of Warcraft API mock loaded successfully.")
