# Guild Historian v2.0 Implementation Plan

**Goal:** Transform Guild Historian from a local event recorder into a real-time guild dashboard and achievement browser powered entirely by WoW's server-side APIs.

**Architecture:** Four API reader modules (AchievementScanner, NewsReader, RosterReader, EventLogReader) replace the old Database/write-queue/event-recording stack. Dashboard is the home screen with 7 cards. Timeline is a drill-down view merging achievements + news + event log. All core data comes from WoW APIs, not local storage.

**Tech Stack:** Lua 5.1 (WoW), Ace3 (AceAddon, AceDB, AceEvent, AceTimer), LibDataBroker/LibDBIcon, WoW Frame API, BackdropTemplate.

**Design doc:** `docs/plans/2026-02-14-v2-redesign.md`

---

## Phase 1: Foundation (Mock + Constants + Utils)

### Task 1: Update WoW Mock with Guild News, Achievement Scanning, and Event Log APIs

The existing WoWMock.lua needs new API mocks that the v2 data modules will call.

**Files:**
- Modify: `Tests/WoWMock.lua`

**Step 1:** Add to MockState these new fields:

```lua
guildNews = {},          -- array of {newsType, whoText, whatText, newsDataID, data, weekday, day, month, year, guildMembersPresent}
guildAchievements = {},  -- map of achievementID -> {name, points, completed, month, day, year, description, icon, isGuild}
guildEventLog = {},      -- array of {eventType, playerName1, playerName2, rankIndex, timestamp}
numGuildNews = 0,
numGuildEvents = 0,
achievementCategories = {},  -- array of {id, numAchievements}
```

Also add these to `MockState:Reset()`.

**Step 2:** Add these global mock functions:

```lua
function GetNumGuildNews()
    return MockState.numGuildNews
end

function GetMaxPlayerLevel()
    return MockState.maxPlayerLevel
end

-- Update C_GuildInfo table:
C_GuildInfo.QueryGuildNews = function() end
C_GuildInfo.GetGuildNewsInfo = function(index)
    local entry = MockState.guildNews[index]
    if not entry then return nil end
    return entry
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
```

**Step 3:** Update `GetAchievementInfo` mock to support full guild achievement scanning:

```lua
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

function GetAchievementCriteriaInfo(achievementID, criteriaIndex)
    return nil
end
```

**Step 4:** Update `GetGuildRosterInfo` to return all fields needed by RosterReader (add achievementPoints, lastOnline):

```lua
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
```

**Step 5:** Add `Settings.RegisterCanvasLayoutCategory` mock:

```lua
Settings.RegisterCanvasLayoutCategory = function(canvas, name)
    return { ID = name }
end
Settings.RegisterAddOnCategory = function(category) end
```

**Step 6:** Run tests to ensure existing tests still pass with the updated mock:

```bash
lua Tests/run_tests.lua
```

Expected: All 267 tests still pass (mock is backwards-compatible).

**Step 7:** Commit.

---

### Task 2: Rewrite Core/Constants.lua

Remove event recording constants, add dashboard card configuration, keep shared styling.

**Files:**
- Modify: `Core/Constants.lua`

**Changes:**

Remove: `EVENT_TYPES`, `EVENT_TYPE_INFO`, `FLUSH_INTERVAL`, `ROSTER_DEBOUNCE`, `ROSTER_SCAN_INTERVAL`, `MAX_EVENTS_DEFAULT`, `MAX_NOTE_LENGTH`, `MEMBER_COUNT_THRESHOLDS`, `KILL_COUNT_THRESHOLDS`, `ACHIEVEMENT_POINT_THRESHOLDS`, `GUILD_ACHIEVEMENT_FLAG`, `LOOT_QUALITY`, `DB_VERSION`, all tracking/data defaults from `DB_DEFAULTS`.

Keep: `ADDON_NAME`, `ADDON_PREFIX`, `ON_THIS_DAY_DELAY`, `ON_THIS_DAY_DISMISS`, `DIFFICULTY_NAMES`, `SHARED_BACKDROP*`, minimap defaults, display defaults.

Add:

```lua
ns.NEWS_TYPES = {
    GUILD_ACHIEVEMENT   = 0,
    PLAYER_ACHIEVEMENT  = 1,
    DUNGEON_ENCOUNTER   = 2,
    ITEM_LOOT           = 3,
    ITEM_CRAFT          = 4,
    ITEM_PURCHASE       = 5,
    GUILD_LEVEL         = 6,
    GUILD_CREATE        = 7,
    EVENT               = 8,
}

ns.NEWS_TYPE_INFO = {
    [0] = { label = "Guild Achievement", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", color = {0.78, 0.61, 1.0} },
    [1] = { label = "Achievement",       icon = "Interface\\Icons\\Achievement_General",                    color = {1.0, 0.78, 0.0} },
    [2] = { label = "Boss Kill",         icon = "Interface\\Icons\\Achievement_Boss_KilJaeden",             color = {1.0, 0.41, 0.41} },
    [3] = { label = "Loot",              icon = "Interface\\Icons\\INV_Misc_Bag_10",                       color = {0.0, 0.8, 1.0} },
    [4] = { label = "Crafted",           icon = "Interface\\Icons\\Trade_BlackSmithing",                    color = {0.9, 0.7, 0.3} },
    [5] = { label = "Purchased",         icon = "Interface\\Icons\\INV_Misc_Coin_01",                      color = {0.8, 0.8, 0.4} },
    [6] = { label = "Guild Level",       icon = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention_Rank2", color = {1.0, 0.5, 0.0} },
    [7] = { label = "Guild Created",     icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",            color = {0.33, 1.0, 0.33} },
    [8] = { label = "Event",             icon = "Interface\\Icons\\INV_Misc_Note_01",                      color = {0.9, 0.9, 0.9} },
}

ns.EVENT_LOG_TYPES = {
    INVITE  = "invite",
    JOIN    = "join",
    PROMOTE = "promote",
    DEMOTE  = "demote",
    REMOVE  = "remove",
    QUIT    = "quit",
}

ns.GUILD_ACHIEVEMENT_CATEGORY = 15076
ns.CARD_PADDING = 8
ns.CARD_GAP = 8
```

Update `DB_DEFAULTS`:

```lua
ns.DB_DEFAULTS = {
    profile = {
        minimap = { hide = false },
        display = {
            showOnThisDay = true,
            defaultTab = 1,
        },
        cards = {
            showGuildPulse = true,
            showOnThisDay = true,
            showRecentActivity = true,
            showTopAchievers = true,
            showActivitySnapshot = true,
            showClassComposition = true,
            showAchievementProgress = true,
        },
        debug = false,
    },
    char = {
        lastOnThisDayDate = "",
    },
}
```

**Step:** Write the updated Constants.lua in full. Run tests (they will fail — that's expected since old modules reference removed constants). Commit.

---

### Task 3: Rewrite Core/Utils.lua

Remove dedup/storage helpers (HashKey, BuildDedupKey, CreateNoteEvent). Keep display helpers. Add new helpers for news/achievement formatting.

**Files:**
- Modify: `Core/Utils.lua`

**Remove:** `HashKey`, `BuildDedupKey`, `CreateNoteEvent`

**Keep:** `TimestampToDisplay`, `TimestampToDate`, `TimestampToMonthDay`, `TimestampToYear`, `RelativeTime`, `GetPlayerID`, `GetGuildKey`, `safecall`, `ClassColoredName`, `GetDifficultyName`, `DeepCopy`, `Truncate`, `ApplySharedBackdrop`

**Add:**

```lua
function Utils.DateToTimestamp(month, day, year)
    if not month or not day or not year then return 0 end
    local realYear = year + 2000
    return time({ year = realYear, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

function Utils.FormatNumber(n)
    if not n then return "0" end
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return format("%.1fK", n / 1000)
    end
    return tostring(n)
end
```

**Step:** Write the updated Utils.lua. Commit.

---

## Phase 2: Data Modules

### Task 4: Create Core/DataModules.lua — AchievementScanner

Scans all guild achievements using WoW API. Builds a cached, sorted list of completed guild achievements with real dates.

**Files:**
- Create: `Core/DataModules.lua`
- Create: `Tests/test_data_modules.lua`

**Step 1:** Write failing tests for AchievementScanner in `Tests/test_data_modules.lua`:

```lua
describe("AchievementScanner", function()
    beforeEach(function()
        MockState:Reset()
        MockState.inGuild = true
        MockState.achievementCategories = {
            { id = 15076, name = "Guild", numAchievements = 3, parentID = nil },
        }
        MockState.guildAchievements = {
            [5362] = { name = "Stay Classy", points = 25, completed = true, month = 3, day = 15, year = 24, description = "Have members of races and classes", isGuild = true, icon = 123 },
            [5363] = { name = "Guild Level 5", points = 10, completed = true, month = 1, day = 5, year = 22, description = "Reach guild level 5", isGuild = true, icon = 124 },
            [5364] = { name = "Not Yet", points = 10, completed = false, isGuild = true, icon = 125 },
        }
    end)

    it("should return completed guild achievements sorted newest first", ...)
    it("should include real completion dates from API", ...)
    it("should cache results and not re-scan on second call", ...)
    it("should support force refresh", ...)
    it("should return empty table when not in a guild", ...)
    it("should calculate total points and completion percentage", ...)
    it("should find On This Day matches", ...)
end)
```

**Step 2:** Run tests — they should fail (module doesn't exist yet).

**Step 3:** Implement AchievementScanner in `Core/DataModules.lua`:

The module structure:

```lua
local GH, ns = ...
local Utils = ns.Utils

-- AchievementScanner
local AchievementScanner = {}
ns.AchievementScanner = AchievementScanner

local achievementCache = nil
local statsCache = nil

function AchievementScanner:Scan(forceRefresh)
    if achievementCache and not forceRefresh then return achievementCache end
    -- iterate guild achievement categories
    -- for each achievement: GetAchievementInfo
    -- build sorted list of completed achievements
    -- cache and return
end

function AchievementScanner:GetStats()
    -- returns { totalPoints, earnedPoints, totalCount, earnedCount, completionPct }
end

function AchievementScanner:GetOnThisDay()
    -- returns array of { achievement, yearsAgo } for today's date
end

function AchievementScanner:GetCategoryProgress()
    -- returns array of { categoryName, earned, total, pct }
end

function AchievementScanner:Invalidate()
    achievementCache = nil
    statsCache = nil
end
```

The key implementation detail: iterate `GetCategoryList()`, for each guild-related category, iterate achievements 1..`GetCategoryNumAchievements(catID)`, call `GetAchievementInfo(achID)`, filter completed ones, convert month/day/year to timestamp via `Utils.DateToTimestamp`.

**Step 4:** Run tests — they should pass.

**Step 5:** Commit.

---

### Task 5: Add NewsReader to Core/DataModules.lua

Reads the guild news feed from WoW API. Provides formatted activity entries.

**Files:**
- Modify: `Core/DataModules.lua`
- Modify: `Tests/test_data_modules.lua`

**Step 1:** Write failing tests:

```lua
describe("NewsReader", function()
    beforeEach(function()
        MockState:Reset()
        MockState.inGuild = true
        MockState.numGuildNews = 3
        MockState.guildNews = {
            [1] = { newsType = 2, whoText = "PlayerA", whatText = "Fyrakk", newsDataID = 100, data = {16}, weekday = 3, day = 14, month = 2, year = 126, guildMembersPresent = 20 },
            [2] = { newsType = 1, whoText = "PlayerB", whatText = "Keystone Hero", newsDataID = 200, data = {}, weekday = 2, day = 13, month = 2, year = 126, guildMembersPresent = 0 },
            [3] = { newsType = 3, whoText = "PlayerC", whatText = "[Fyr'alath]", newsDataID = 300, data = {5}, weekday = 1, day = 12, month = 2, year = 126, guildMembersPresent = 0 },
        }
    end)

    it("should return all news entries", ...)
    it("should format entries with who, what, type label, and timestamp", ...)
    it("should return empty when not in guild", ...)
    it("should cache results until invalidated", ...)
    it("should summarize by news type for activity snapshot", ...)
end)
```

**Step 2:** Implement NewsReader:

```lua
local NewsReader = {}
ns.NewsReader = NewsReader

local newsCache = nil

function NewsReader:Read(forceRefresh)
    if newsCache and not forceRefresh then return newsCache end
    C_GuildInfo.QueryGuildNews()
    local entries = {}
    local count = GetNumGuildNews()
    for i = 1, count do
        local info = C_GuildInfo.GetGuildNewsInfo(i)
        if info and not info.isHeader then
            entries[#entries + 1] = {
                newsType = info.newsType,
                who = info.whoText or "",
                what = info.whatText or "",
                dataID = info.newsDataID,
                timestamp = Utils.DateToTimestamp(info.month, info.day, info.year),
                membersPresent = info.guildMembersPresent or 0,
                typeInfo = ns.NEWS_TYPE_INFO[info.newsType],
            }
        end
    end
    newsCache = entries
    return entries
end

function NewsReader:GetSummary()
    local entries = self:Read()
    local counts = {}
    for _, entry in ipairs(entries) do
        counts[entry.newsType] = (counts[entry.newsType] or 0) + 1
    end
    return counts
end

function NewsReader:Invalidate()
    newsCache = nil
end
```

**Step 3:** Run tests, verify pass. Commit.

---

### Task 6: Add RosterReader to Core/DataModules.lua

Reads guild roster. Provides filtered views for dashboard cards.

**Files:**
- Modify: `Core/DataModules.lua`
- Modify: `Tests/test_data_modules.lua`

**Step 1:** Write failing tests:

```lua
describe("RosterReader", function()
    beforeEach(function()
        MockState:Reset()
        MockState.inGuild = true
        MockState.maxPlayerLevel = 80
        MockState.guildMembers = {
            { name = "Tank-Realm", class = "WARRIOR", level = 80, online = true, zone = "Nerub-ar Palace", achievementPoints = 15000, rank = "Officer" },
            { name = "Healer-Realm", class = "PRIEST", level = 80, online = true, zone = "Dornogal", achievementPoints = 12000, rank = "Member" },
            { name = "Lowbie-Realm", class = "MAGE", level = 30, online = true, zone = "Stormwind", achievementPoints = 500, rank = "Initiate" },
            { name = "Offline-Realm", class = "ROGUE", level = 80, online = false, zone = "", achievementPoints = 20000, rank = "Raider" },
        }
    end)

    it("should return all guild members", ...)
    it("should filter online members", ...)
    it("should filter max-level online members", ...)
    it("should group online max-level by class", ...)
    it("should return top achievers sorted by points", ...)
    it("should return total and online member counts", ...)
    it("should return empty when not in guild", ...)
end)
```

**Step 2:** Implement RosterReader. Key methods:

- `RosterReader:Read(forceRefresh)` — caches full roster
- `RosterReader:GetOnlineMaxLevel()` — filters online + max level
- `RosterReader:GetClassComposition()` — groups GetOnlineMaxLevel by class, returns `{WARRIOR=2, PRIEST=1, ...}`
- `RosterReader:GetTopAchievers(count)` — sorts all members by achievementPoints, returns top N
- `RosterReader:GetCounts()` — returns `{total, online}`

**Step 3:** Run tests, verify pass. Commit.

---

### Task 7: Add EventLogReader to Core/DataModules.lua

Reads guild event log (joins, leaves, promotions).

**Files:**
- Modify: `Core/DataModules.lua`
- Modify: `Tests/test_data_modules.lua`

**Step 1:** Write failing tests:

```lua
describe("EventLogReader", function()
    beforeEach(function()
        MockState:Reset()
        MockState.inGuild = true
        MockState.numGuildEvents = 2
        MockState.guildEventLog = {
            { eventType = "join", playerName1 = "NewPlayer", playerName2 = nil, rankIndex = nil, timestamp = 1700000000 },
            { eventType = "promote", playerName1 = "OldPlayer", playerName2 = nil, rankIndex = 3, timestamp = 1699999000 },
        }
    end)

    it("should return all event log entries", ...)
    it("should format entries with type, player, and timestamp", ...)
    it("should return empty when not in guild", ...)
end)
```

**Step 2:** Implement EventLogReader. Simple wrapper around `GetGuildEventInfo(index)`.

**Step 3:** Run tests, verify pass. Commit.

---

## Phase 3: Core Init Rewrite

### Task 8: Rewrite Core/Init.lua

Remove write queue, flush timer, note system. Simplify to: init DB for preferences, register data refresh events, slash commands.

**Files:**
- Modify: `Core/Init.lua`

**Key changes:**

- Remove: `FlushWriteQueue`, `SubmitNote`, `StaticPopupDialogs["GUILDHISTORIAN_QUICK_NOTE"]`, note-related slash commands
- Keep: `OnInitialize` (AceDB for preferences only), `OnEnable` (minimap + settings init + data refresh), slash commands (toggle, debug, config)
- Add: Event registration for `GUILD_ROSTER_UPDATE`, `GUILD_NEWS_UPDATE`, `GUILD_EVENT_LOG_UPDATE` to invalidate data module caches
- Add: Trigger initial data load in `OnEnable`: `C_GuildInfo.GuildRoster()`, `C_GuildInfo.QueryGuildNews()`, `QueryGuildEventLog()`

Simplified `OnEnable`:

```lua
function addon:OnEnable()
    if not IsInGuild() then
        self:DebugPrint(L["NOT_IN_GUILD"])
        return
    end

    self:Print(format(L["ADDON_LOADED"], self.version))

    C_GuildInfo.GuildRoster()
    C_GuildInfo.QueryGuildNews()
    QueryGuildEventLog()

    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("GUILD_NEWS_UPDATE", "OnNewsUpdate")
    self:RegisterEvent("GUILD_EVENT_LOG_UPDATE", "OnEventLogUpdate")

    ns.MinimapButton:Init()
    ns.SettingsPanel:Init()

    self:ScheduleTimer("CheckOnThisDay", ns.ON_THIS_DAY_DELAY)
end
```

Simplified slash commands (only: toggle, debug, config/settings):

```lua
function addon:SlashCommand(input)
    local cmd = self:GetArgs(input, 1)
    cmd = cmd and strlower(cmd) or ""

    if cmd == "" or cmd == "toggle" then
        if ns.MainFrame then ns.MainFrame:Toggle() end
    elseif cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print(self.db.profile.debug and L["DEBUG_ENABLED"] or L["DEBUG_DISABLED"])
    elseif cmd == "config" or cmd == "settings" then
        Settings.OpenToCategory(ns.settingsCategoryID)
    else
        self:Print(L["SLASH_HELP"])
    end
end
```

**Step:** Rewrite Init.lua. Run build to check for syntax. Commit.

---

## Phase 4: Remove Old Modules

### Task 9: Delete old modules and old tests

**Files to delete:**
- `Modules/BossKills.lua`
- `Modules/LootTracker.lua`
- `Modules/GuildRoster.lua`
- `Modules/Achievements.lua`
- `Modules/MilestoneDetector.lua`
- `Modules/Notes.lua`
- `Modules/OnThisDay.lua` (logic moves into AchievementScanner:GetOnThisDay)
- `Core/Database.lua`
- `UI/DetailPanel.lua`
- `UI/ExportFrame.lua`
- `UI/StatsPanel.lua`

**Test files to delete/replace:**
- `Tests/test_database.lua` — delete entirely
- `Tests/test_modules.lua` — delete entirely
- `Tests/test_integration.lua` — delete, rewrite later
- `Tests/test_stress.lua` — delete, rewrite later
- `Tests/test_wow12_compat.lua` — delete (no longer relevant — we don't use pcall wrappers for boss kill recording)

**Test files to rewrite:**
- `Tests/test_utils.lua` — remove tests for HashKey, BuildDedupKey, CreateNoteEvent

**Step:** Delete all listed files. Update `Tests/test_utils.lua` to remove deleted function tests. Run tests — only `test_utils.lua` and `test_data_modules.lua` and `test_validation.lua` should run. Commit.

---

## Phase 5: UI Overhaul

### Task 10: Update MainFrame for Dashboard-first navigation

**Files:**
- Modify: `UI/MainFrame.xml` (no changes needed — parentKey already fixed)
- Modify: `UI/MainFrame.lua`

**Key changes:**

- Tab 1 becomes "Dashboard" (was "Timeline")
- Tab 2 stays "Timeline"
- Tab 3 stays "Settings"
- Remove Export and Add Note toolbar buttons
- `SelectTab` shows/hides Dashboard, Timeline, or Settings
- Default tab on open: Dashboard

Update `TAB_INFO`:

```lua
local TAB_DASHBOARD = 1
local TAB_TIMELINE = 2
local TAB_SETTINGS = 3

local TAB_INFO = {
    { id = TAB_DASHBOARD, label = L["UI_DASHBOARD"] },
    { id = TAB_TIMELINE,  label = L["UI_TIMELINE"] },
    { id = TAB_SETTINGS,  label = L["UI_SETTINGS"] },
}
```

Update `SelectTab` to show/hide `ns.Dashboard` instead of old panels.

Remove `CreateToolbarButtons` entirely (no Export/Add Note).

**Step:** Rewrite MainFrame.lua. Commit.

---

### Task 11: Create UI/Dashboard.lua and UI/DashboardCards.lua

This is the largest UI task. The Dashboard creates a scrollable container with cards.

**Files:**
- Create: `UI/Dashboard.lua`
- Create: `UI/DashboardCards.lua`

**Dashboard.lua** — Layout controller:

```lua
local Dashboard = {}
ns.Dashboard = Dashboard

local container = nil
local scrollFrame = nil
local scrollChild = nil
local cards = {}

function Dashboard:Init()
    -- Create scrollframe inside MainFrame content area
    -- Create scrollChild
    -- Call DashboardCards to create each card
    -- Layout cards in 2-column grid
end

function Dashboard:Refresh()
    -- Refresh all visible cards from data modules
end

function Dashboard:Show()
    if not container then self:Init() end
    if container then container:Show() end
    self:Refresh()
end

function Dashboard:Hide()
    if container then container:Hide() end
end
```

**DashboardCards.lua** — Individual card implementations. Each card is a frame with consistent styling:

```lua
local DashboardCards = {}
ns.DashboardCards = DashboardCards

function DashboardCards:CreateCard(parent, width, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, 10)  -- height auto-sizes
    Utils.ApplySharedBackdrop(card, 0.7)
    -- create title fontstring with gold color
    -- create separator line
    -- return card, yOffset for content below title
end
```

Then one method per card:

- `DashboardCards:CreateGuildPulse(parent, width)` — uses `ns.RosterReader:GetCounts()` and `ns.AchievementScanner:GetStats()`
- `DashboardCards:CreateOnThisDay(parent, width)` — uses `ns.AchievementScanner:GetOnThisDay()`
- `DashboardCards:CreateRecentActivity(parent, width)` — uses `ns.NewsReader:Read()`, shows top 8
- `DashboardCards:CreateTopAchievers(parent, width)` — uses `ns.RosterReader:GetTopAchievers(5)`
- `DashboardCards:CreateActivitySnapshot(parent, width)` — uses `ns.NewsReader:GetSummary()`
- `DashboardCards:CreateClassComposition(parent, width)` — uses `ns.RosterReader:GetClassComposition()`
- `DashboardCards:CreateAchievementProgress(parent, width)` — uses `ns.AchievementScanner:GetCategoryProgress()`

Each `Create*` method returns the card frame. Dashboard:Init() lays them out.

**Layout algorithm:**

```
left column:  x = CARD_GAP
right column: x = CARD_GAP + halfWidth + CARD_GAP
full width:   x = CARD_GAP, width = totalWidth - 2*CARD_GAP

Row 1: GuildPulse (half) | OnThisDay (half)
Row 2: RecentActivity (full)
Row 3: TopAchievers (half) | ActivitySnapshot (half)
Row 4: ClassComposition (full)
Row 5: AchievementProgress (full)
```

Cards are positioned top-down. Each row's Y offset is based on the tallest card in the previous row + CARD_GAP.

Cards respect `addon.db.profile.cards.show*` settings — if false, skip that card and reclaim its space.

**Step:** Write both files. Commit.

---

### Task 12: Rewrite UI/Timeline.lua

Timeline now reads from DataModules instead of Database. Merges three data sources into one sorted list.

**Files:**
- Modify: `UI/Timeline.lua`

**Key changes:**

Replace `Database:GetEvents(filters)` with a merge of:
1. `ns.AchievementScanner:Scan()` — mapped to timeline entry format
2. `ns.NewsReader:Read()` — mapped to timeline entry format
3. `ns.EventLogReader:Read()` — mapped to timeline entry format

All three are merged into a single array, sorted by timestamp descending, then displayed using the existing frame pool pattern.

```lua
function Timeline:GetMergedEvents()
    local events = {}

    for _, ach in ipairs(ns.AchievementScanner:Scan()) do
        events[#events + 1] = {
            type = "achievement",
            title = ach.name,
            description = ach.description,
            timestamp = ach.timestamp,
            icon = ach.icon,
            color = ns.NEWS_TYPE_INFO[0].color,
        }
    end

    for _, news in ipairs(ns.NewsReader:Read()) do
        local info = news.typeInfo or {}
        events[#events + 1] = {
            type = "news",
            title = (info.label or "Event") .. ": " .. news.what,
            description = news.who,
            timestamp = news.timestamp,
            icon = info.icon,
            color = info.color,
            newsType = news.newsType,
        }
    end

    for _, evt in ipairs(ns.EventLogReader:Read()) do
        events[#events + 1] = {
            type = "event_log",
            title = evt.formattedText,
            description = "",
            timestamp = evt.timestamp,
            icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",
            color = {0.33, 1.0, 0.33},
        }
    end

    table.sort(events, function(a, b) return a.timestamp > b.timestamp end)
    return events
end
```

FilterBar integration: filter by type ("achievement", "news", "event_log"), search by title/description, date range.

**Step:** Rewrite Timeline.lua. Commit.

---

### Task 13: Update UI/FilterBar.lua

Adapt filters for the new event types (achievement, news, event_log) instead of old types (BOSS_KILL, MEMBER_JOIN, etc.).

**Files:**
- Modify: `UI/FilterBar.lua`

**Key changes:**

Replace `importantTypes` with:
```lua
local filterTypes = {
    { type = "achievement", label = L["FILTER_ACHIEVEMENTS"] },
    { type = "news",        label = L["FILTER_NEWS"] },
    { type = "event_log",   label = L["FILTER_ROSTER"] },
}
```

Remove news sub-type filtering (keep it simple). Search and date filters stay the same.

**Step:** Rewrite FilterBar.lua. Commit.

---

### Task 14: Rewrite UI/OnThisDayPopup.lua

Now uses AchievementScanner:GetOnThisDay() instead of querying stored events.

**Files:**
- Modify: `UI/OnThisDayPopup.lua`

**Key changes:**

Replace the old event-query logic with:

```lua
function OnThisDayPopup:ShowEvents()
    local matches = ns.AchievementScanner:GetOnThisDay()
    if not matches or #matches == 0 then return end
    -- format and display (same UI as before)
end
```

The `Init:CheckOnThisDay` timer in Init.lua calls this.

**Step:** Rewrite OnThisDayPopup.lua. Commit.

---

### Task 15: Update UI/SettingsPanel.lua

Replace tracking settings with card visibility toggles.

**Files:**
- Modify: `UI/SettingsPanel.lua`

**Key changes:**

Remove: All tracking checkboxes (boss kills, roster, achievements, loot), loot quality selector, max events setting.

Add: Card visibility section:
```
Display
  ☑ Show Minimap Icon
  ☑ Show 'On This Day' Popup

Dashboard Cards
  ☑ Guild Pulse
  ☑ On This Day
  ☑ Recent Activity
  ☑ Top Achievers
  ☑ Activity Snapshot
  ☑ Class Composition
  ☑ Achievement Progress
```

Each checkbox toggles `addon.db.profile.cards.show*` and triggers `ns.Dashboard:Refresh()`.

**Step:** Rewrite SettingsPanel.lua (both Blizzard canvas and inline panel). Commit.

---

### Task 16: Update UI/MinimapButton.lua

Update tooltip to show data from API instead of Database:GetEventCount().

**Files:**
- Modify: `UI/MinimapButton.lua`

**Changes:**

```lua
OnTooltipShow = function(tooltip)
    tooltip:AddLine(format("%s |cff888888v%s|r", L["MINIMAP_TOOLTIP_TITLE"], ns.addon.version))
    local counts = ns.RosterReader and ns.RosterReader:GetCounts() or {total=0, online=0}
    tooltip:AddLine(format(L["MINIMAP_TOOLTIP_MEMBERS"], counts.total, counts.online), 1, 1, 1)
    tooltip:AddLine(" ")
    tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"])
    tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"])
end,
```

**Step:** Update MinimapButton.lua. Commit.

---

### Task 17: Update UI/TimelineEntry.lua

Minor update — the entry now gets its icon/color from the merged event format instead of ns.EVENT_TYPE_INFO.

**Files:**
- Modify: `UI/TimelineEntry.lua`

**Changes:** Instead of looking up `ns.EVENT_TYPE_INFO[event.type]`, use `event.icon` and `event.color` directly (already set during merge in Timeline:GetMergedEvents).

**Step:** Update TimelineEntry.lua. Commit.

---

## Phase 6: Locales, TOC, Docs

### Task 18: Update Locales

**Files:**
- Modify: `Locales/enUS.lua`

**Remove:** All strings for removed features (NOTE_*, SEARCH_*, EXPORT_*, STATS_*, SETTINGS_TRACK_*, SETTINGS_LOOT_*, SETTINGS_MAX_EVENTS_*, QUALITY_*, BOSS_KILL_DESC through MILESTONE_*, MEMBER_JOIN through PLAYER_NOTE event type labels).

**Add:**

```lua
L["UI_DASHBOARD"] = "Dashboard"
L["FILTER_ACHIEVEMENTS"] = "Achievements"
L["FILTER_NEWS"] = "Activity"
L["FILTER_ROSTER"] = "Roster"
L["CARD_GUILD_PULSE"] = "Guild Pulse"
L["CARD_ON_THIS_DAY"] = "On This Day"
L["CARD_RECENT_ACTIVITY"] = "Recent Activity"
L["CARD_TOP_ACHIEVERS"] = "Top Achievers"
L["CARD_ACTIVITY_SNAPSHOT"] = "Activity Snapshot"
L["CARD_CLASS_COMPOSITION"] = "Online at Max Level"
L["CARD_ACHIEVEMENT_PROGRESS"] = "Achievement Progress"
L["CARD_MEMBERS_ONLINE"] = "%d Members  %d Online"
L["CARD_ACHIEVEMENT_POINTS"] = "%s Achievement Points"
L["CARD_ACHIEVEMENTS_EARNED"] = "Achievements: %d/%d (%d%%)"
L["CARD_YEARS_AGO"] = "%d year(s) ago:"
L["CARD_VIEW_TIMELINE"] = "View full timeline"
L["CARD_NO_ACTIVITY"] = "No recent activity"
L["MINIMAP_TOOLTIP_MEMBERS"] = "%d members (%d online)"
L["SETTINGS_CARDS"] = "Dashboard Cards"
L["SLASH_HELP"] = "Commands: toggle, debug, config"
```

**Step:** Update enUS.lua. Update other locale files (deDE, frFR, esES, ptBR) to at minimum have the keys (values can stay English as fallback). Commit.

---

### Task 19: Update GuildHistorian.toc

**Files:**
- Modify: `GuildHistorian.toc`

New file list:

```toc
## Interface: 120001
## Title: Guild Historian
## Notes: Real-time guild dashboard and achievement browser. See your guild's pulse, recent activity, and full achievement history at a glance.
## Author: GIMZWARE
## Version: 2.0.0
## SavedVariables: GuildHistorianDB
## SavedVariablesPerCharacter: GuildHistorianCharDB
## IconTexture: Interface\AddOns\GuildHistorian\Assets\logo_400x400

# Libraries
Libs\libs.xml

# Localization
Locales\enUS.lua
Locales\deDE.lua
Locales\frFR.lua
Locales\esES.lua
Locales\ptBR.lua

# Core
Core\Constants.lua
Core\Utils.lua
Core\DataModules.lua
Core\Init.lua

# UI (XML templates first, then Lua)
UI\MainFrame.xml
UI\TimelineEntry.xml
UI\OnThisDayPopup.xml
UI\MainFrame.lua
UI\DashboardCards.lua
UI\Dashboard.lua
UI\TimelineEntry.lua
UI\Timeline.lua
UI\FilterBar.lua
UI\OnThisDayPopup.lua
UI\SettingsPanel.lua
UI\MinimapButton.lua
```

**Step:** Update TOC. Commit.

---

### Task 20: Update README.md

**Files:**
- Modify: `README.md`

Rewrite to reflect v2:

- New description: "Real-time guild dashboard and achievement browser for World of Warcraft"
- Feature list: Dashboard cards, achievement timeline, guild news feed, On This Day, class composition
- Remove references to event recording, notes, export, local storage
- Keep installation instructions
- Update slash commands (only: toggle, debug, config)
- Update version to 2.0.0

**Step:** Rewrite README. Commit.

---

### Task 21: Update AddonLoader and test_validation, write new integration tests

**Files:**
- Modify: `Tests/AddonLoader.lua` — update file loading to match new TOC
- Modify: `Tests/test_validation.lua` — update TOC validation, locale validation, remove old event type checks
- Create: `Tests/test_integration.lua` — new integration tests for the full v2 flow

**New integration tests:**

```lua
describe("Integration: Dashboard Data Flow", function()
    it("should populate dashboard from API data on first load", ...)
    it("should refresh when GUILD_ROSTER_UPDATE fires", ...)
    it("should merge achievements + news + event log in timeline", ...)
end)

describe("Integration: On This Day from API", function()
    it("should find matching guild achievements for today's date", ...)
    it("should return empty when no achievements match today", ...)
end)
```

**Step:** Update all test infrastructure. Run full test suite. All tests should pass. Commit.

---

### Task 22: Final build and verification

**Step 1:** Run `bash build.sh` — all tests pass, dist folder created.

**Step 2:** Verify dist contents match new file structure (no old files like Database.lua, BossKills.lua, etc.).

**Step 3:** Verify package size is reasonable.

**Step 4:** Final commit with updated CHANGELOG.md.

---

## Task Dependency Graph

```
Task 1 (Mock) → Task 4-7 (DataModules) → Task 8 (Init) → Task 9 (Delete old)
                                                          → Task 10-17 (UI)
                                                          → Task 18-19 (Locales/TOC)
Task 2-3 (Constants/Utils) → Task 4-7 (DataModules)
Task 9 (Delete old) + Task 10-17 (UI) → Task 20-21 (Docs/Tests) → Task 22 (Build)
```

Phases are sequential. Within a phase, tasks can be done in order listed.
