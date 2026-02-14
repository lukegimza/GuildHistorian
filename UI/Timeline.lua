local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local ipairs = ipairs
local format = format

local Timeline = {}
ns.Timeline = Timeline

local container = nil
local scrollFrame = nil
local scrollChild = nil
local noEventsText = nil
local filterBar = nil

local entryPool = {}
local headerPool = {}
local activeEntries = {}
local activeHeaders = {}

local ENTRY_HEIGHT = 40
local HEADER_HEIGHT = 24

local function AcquireEntry()
    local frame = tremove(entryPool)
    if not frame then
        frame = CreateFrame("Button", nil, scrollChild)
        frame:SetHeight(ENTRY_HEIGHT)
        frame:RegisterForClicks("LeftButtonUp")
        ns.TimelineEntry:EnsureElements(frame)
    end
    frame:Show()
    activeEntries[#activeEntries + 1] = frame
    return frame
end

local function AcquireHeader()
    local frame = tremove(headerPool)
    if not frame then
        frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetHeight(HEADER_HEIGHT)

        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAllPoints()
        frame.bg:SetColorTexture(0.1, 0.1, 0.15, 0.8)

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text:SetPoint("LEFT", 12, 0)
        frame.text:SetTextColor(0.78, 0.65, 0.35)
    end
    frame:Show()
    activeHeaders[#activeHeaders + 1] = frame
    return frame
end

local function ReleaseAll()
    for i = #activeEntries, 1, -1 do
        local f = activeEntries[i]
        f:Hide()
        f:ClearAllPoints()
        entryPool[#entryPool + 1] = f
        activeEntries[i] = nil
    end
    for i = #activeHeaders, 1, -1 do
        local f = activeHeaders[i]
        f:Hide()
        f:ClearAllPoints()
        headerPool[#headerPool + 1] = f
        activeHeaders[i] = nil
    end
end

function Timeline:GetMergedEvents()
    local events = {}

    -- Guild achievements (historical)
    local achievements = ns.AchievementScanner and ns.AchievementScanner:Scan() or {}
    for _, ach in ipairs(achievements) do
        events[#events + 1] = {
            type = "achievement",
            title = ach.name,
            description = ach.description,
            timestamp = ach.timestamp,
            icon = (ns.NEWS_TYPE_INFO[0] or {}).icon,
            color = (ns.NEWS_TYPE_INFO[0] or {}).color or {0.78, 0.61, 1.0},
        }
    end

    -- Guild news (recent)
    local news = ns.NewsReader and ns.NewsReader:Read() or {}
    for _, entry in ipairs(news) do
        local info = entry.typeInfo or {}
        events[#events + 1] = {
            type = "news",
            title = (info.label or "Event") .. ": " .. entry.what,
            description = entry.who,
            timestamp = entry.timestamp,
            icon = info.icon,
            color = info.color,
            newsType = entry.newsType,
        }
    end

    -- Event log (recent roster changes)
    local eventLog = ns.EventLogReader and ns.EventLogReader:Read() or {}
    for _, evt in ipairs(eventLog) do
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

function Timeline:Init()
    if container then return end

    local parent = ns.MainFrame:GetContentFrame()
    if not parent then return end

    container = CreateFrame("Frame", "GuildHistorianTimeline", parent)
    container:SetAllPoints()

    if ns.FilterBar then
        filterBar = ns.FilterBar:Init(container)
    end

    noEventsText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noEventsText:SetPoint("CENTER", 0, 0)
    noEventsText:SetText(L["UI_NO_EVENTS"])
    noEventsText:SetTextColor(0.5, 0.5, 0.5)
    noEventsText:Hide()

    scrollFrame = CreateFrame("ScrollFrame", "GuildHistorianScrollFrame", container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, filterBar and -40 or 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    scrollChild = CreateFrame("Frame", "GuildHistorianScrollChild", scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 400)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    self:Refresh()
end

function Timeline:Refresh()
    if not scrollChild then self:Init(); return end

    ReleaseAll()

    local allEvents = self:GetMergedEvents()

    -- Apply filters
    local filters = nil
    if ns.FilterBar then
        filters = ns.FilterBar:GetFilters()
    end

    local events = allEvents
    if filters then
        events = {}
        for _, event in ipairs(allEvents) do
            local pass = true
            -- Type filter
            if filters.types and not filters.types[event.type] then
                pass = false
            end
            -- Search filter
            if pass and filters.search then
                local search = strlower(filters.search)
                local title = strlower(event.title or "")
                local desc = strlower(event.description or "")
                if not strfind(title, search, 1, true) and not strfind(desc, search, 1, true) then
                    pass = false
                end
            end
            -- Date range filter
            if pass and filters.startDate and event.timestamp < filters.startDate then
                pass = false
            end
            if pass and filters.endDate and event.timestamp > filters.endDate then
                pass = false
            end
            if pass then
                events[#events + 1] = event
            end
        end
    end

    if #events == 0 then
        noEventsText:SetText(filters and next(filters) and L["UI_NO_FILTERED_EVENTS"] or L["UI_NO_EVENTS"])
        noEventsText:Show()
        scrollChild:SetHeight(1)
        return
    end

    noEventsText:Hide()

    local yOffset = 0
    local lastDate = nil

    for _, event in ipairs(events) do
        local eventDate = Utils.TimestampToDate(event.timestamp)

        if eventDate ~= lastDate then
            local header = AcquireHeader()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
            header:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
            header.text:SetText(eventDate)
            yOffset = yOffset + HEADER_HEIGHT
            lastDate = eventDate
        end

        local entry = AcquireEntry()
        entry:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        entry:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        ns.TimelineEntry:Init(entry, event)
        yOffset = yOffset + ENTRY_HEIGHT
    end

    scrollChild:SetHeight(yOffset)
end

function Timeline:Show()
    if not container then self:Init() end
    if container then container:Show() end
    self:Refresh()
end

function Timeline:Hide()
    if container then container:Hide() end
end

function Timeline:FilterByDate(month, day)
    if not ns.MainFrame:IsShown() then
        ns.MainFrame:Show()
    end
    if ns.FilterBar and month and day then
        ns.FilterBar:SetMonthDayFilter(month, day)
    else
        self:Refresh()
    end
end
