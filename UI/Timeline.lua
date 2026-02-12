local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database

local Timeline = {}
ns.Timeline = Timeline

local scrollBox = nil
local dataProvider = nil
local container = nil
local noEventsText = nil
local filterBar = nil

function Timeline:Init()
    if container then return end

    local parent = ns.MainFrame:GetContentFrame()
    if not parent then return end

    container = CreateFrame("Frame", "GuildHistorianTimeline", parent)
    container:SetAllPoints()

    -- Filter bar at top
    if ns.FilterBar then
        filterBar = ns.FilterBar:Init(container)
    end

    -- "No events" text
    noEventsText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noEventsText:SetPoint("CENTER", 0, 0)
    noEventsText:SetText(L["UI_NO_EVENTS"])
    noEventsText:SetTextColor(0.5, 0.5, 0.5)
    noEventsText:Hide()

    -- Create ScrollBox
    scrollBox = CreateFrame("Frame", "GuildHistorianScrollBox", container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 0, filterBar and -40 or 0)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)

    -- Create scrollbar
    local scrollBar = CreateFrame("EventFrame", "GuildHistorianScrollBar", container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    -- Create the view
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("GuildHistorianTimelineEntryTemplate", function(button, elementData)
        if elementData.isHeader then
            -- Date header
            self:InitDateHeader(button, elementData)
        else
            -- Event entry
            ns.TimelineEntry:Init(button, elementData.event)
        end
    end)

    -- Set element extent (row height)
    view:SetElementExtentCalculator(function(_dataIndex, elementData)
        if elementData.isHeader then
            return 24
        end
        return 40
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    -- Create data provider
    dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(dataProvider)

    -- Initial load
    self:Refresh()
end

function Timeline:InitDateHeader(button, elementData)
    -- Style as a date header
    if button.Title then
        button.Title:SetText(elementData.dateLabel)
    end
    if button.Icon then button.Icon:Hide() end
    if button.Subtitle then button.Subtitle:Hide() end
    if button.Timestamp then button.Timestamp:Hide() end
    if button.Participants then button.Participants:Hide() end

    -- Create or show date label
    if not button.dateText then
        button.dateText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.dateText:SetPoint("LEFT", 12, 0)
        button.dateText:SetTextColor(0.78, 0.65, 0.35)
    end
    button.dateText:SetText(elementData.dateLabel)
    button.dateText:Show()

    -- Set background for header
    if not button.headerBg then
        button.headerBg = button:CreateTexture(nil, "BACKGROUND")
        button.headerBg:SetAllPoints()
        button.headerBg:SetColorTexture(0.1, 0.1, 0.15, 0.8)
    end
    button.headerBg:Show()

    -- Disable click
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)
end

function Timeline:Refresh()
    if not dataProvider then self:Init(); return end

    local filters = nil
    if ns.FilterBar then
        filters = ns.FilterBar:GetFilters()
    end

    local events = Database:GetEvents(filters)

    dataProvider:Flush()

    if #events == 0 then
        noEventsText:SetText(filters and next(filters) and L["UI_NO_FILTERED_EVENTS"] or L["UI_NO_EVENTS"])
        noEventsText:Show()
        return
    end

    noEventsText:Hide()

    -- Group by date and insert with headers
    local lastDate = nil
    for _, event in ipairs(events) do
        local eventDate = Utils.TimestampToDate(event.timestamp)
        if eventDate ~= lastDate then
            dataProvider:Insert({ isHeader = true, dateLabel = eventDate })
            lastDate = eventDate
        end
        dataProvider:Insert({ isHeader = false, event = event })
    end
end

function Timeline:Show()
    if not container then self:Init() end
    if container then container:Show() end
    self:Refresh()
end

function Timeline:Hide()
    if container then container:Hide() end
end

function Timeline:FilterByDate(_month, _day)
    -- Used by On This Day popup to filter timeline to a specific date
    -- TODO: Set date filter in FilterBar when implemented
    if not ns.MainFrame:IsShown() then
        ns.MainFrame:Show()
    end
    self:Refresh()
end
