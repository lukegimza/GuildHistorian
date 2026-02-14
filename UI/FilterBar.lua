local GH, ns = ...

local L = ns.L

local pairs = pairs
local ipairs = ipairs
local next = next

local FilterBar = {}
ns.FilterBar = FilterBar

local container = nil
local searchBox = nil
local categoryChecks = {}
local clearButton = nil
local dateButtons = {}
local activeDatePreset = nil

local currentFilters = {
    types = nil,
    search = nil,
    startDate = nil,
    endDate = nil,
}

local filterTypes = {
    { type = "achievement", label = L["FILTER_ACHIEVEMENTS"], color = {0.78, 0.61, 1.0} },
    { type = "news",        label = L["FILTER_NEWS"],         color = {1.0, 0.41, 0.41} },
    { type = "event_log",   label = L["FILTER_ROSTER"],       color = {0.33, 1.0, 0.33} },
}

function FilterBar:Init(parent)
    if container then return container end

    container = CreateFrame("Frame", "GuildHistorianFilterBar", parent)
    container:SetPoint("TOPLEFT", 0, 0)
    container:SetPoint("TOPRIGHT", 0, 0)
    container:SetHeight(36)

    searchBox = CreateFrame("EditBox", "GuildHistorianSearchBox", container, "SearchBoxTemplate")
    searchBox:SetSize(160, 22)
    searchBox:SetPoint("LEFT", 4, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        currentFilters.search = (text and text ~= "") and text or nil
        FilterBar:ApplyFilters()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local xOffset = 180
    for _, info in ipairs(filterTypes) do
        local check = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("LEFT", xOffset, 0)
        check:SetChecked(true)
        check.filterType = info.type

        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(info.label)
        label:SetTextColor(info.color[1], info.color[2], info.color[3])

        check:SetScript("OnClick", function()
            FilterBar:UpdateTypeFilters()
            FilterBar:ApplyFilters()
        end)

        categoryChecks[info.type] = check
        xOffset = xOffset + 90
    end

    clearButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("RIGHT", -4, 0)
    clearButton:SetText(L["UI_CLEAR_FILTERS"])
    clearButton:SetScript("OnClick", function()
        FilterBar:ClearFilters()
    end)

    local datePresets = {
        { label = "All",  days = nil,  width = 32 },
        { label = "7d",   days = 7,    width = 28 },
        { label = "30d",  days = 30,   width = 32 },
        { label = "90d",  days = 90,   width = 32 },
    }

    local prevDateBtn = clearButton
    for i = #datePresets, 1, -1 do
        local preset = datePresets[i]
        local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        btn:SetSize(preset.width, 22)
        btn:SetPoint("RIGHT", prevDateBtn, "LEFT", -4, 0)
        btn:SetText(preset.label)
        btn.presetDays = preset.days

        btn:SetScript("OnClick", function()
            FilterBar:SetDatePreset(preset.days)
        end)

        dateButtons[i] = btn
        prevDateBtn = btn
    end

    FilterBar:UpdateDateButtonHighlights()

    return container
end

function FilterBar:UpdateTypeFilters()
    local anyUnchecked = false
    local types = {}

    for filterType, check in pairs(categoryChecks) do
        if check:GetChecked() then
            types[filterType] = true
        else
            anyUnchecked = true
        end
    end

    if anyUnchecked then
        currentFilters.types = types
    else
        currentFilters.types = nil
    end
end

function FilterBar:SetDatePreset(days)
    activeDatePreset = days
    if not days then
        currentFilters.startDate = nil
        currentFilters.endDate = nil
    else
        currentFilters.endDate = GetServerTime()
        currentFilters.startDate = currentFilters.endDate - (days * 86400)
    end
    self:UpdateDateButtonHighlights()
    self:ApplyFilters()
end

function FilterBar:SetMonthDayFilter(month, day)
    if month then
        activeDatePreset = nil
        currentFilters.startDate = nil
        currentFilters.endDate = nil
        self:UpdateDateButtonHighlights()
    end
    self:ApplyFilters()
end

function FilterBar:ClearFilters()
    if searchBox then searchBox:SetText("") end
    currentFilters.search = nil
    for _, check in pairs(categoryChecks) do
        check:SetChecked(true)
    end
    currentFilters.types = nil
    currentFilters.startDate = nil
    currentFilters.endDate = nil
    activeDatePreset = nil
    self:UpdateDateButtonHighlights()
    self:ApplyFilters()
end

function FilterBar:GetFilters()
    if not currentFilters.types and not currentFilters.search and not currentFilters.startDate then
        return nil
    end
    return currentFilters
end

function FilterBar:UpdateDateButtonHighlights()
    for _, btn in ipairs(dateButtons) do
        if btn.presetDays == activeDatePreset then
            btn:GetFontString():SetTextColor(1, 0.84, 0)
        else
            btn:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

function FilterBar:ApplyFilters()
    if ns.Timeline then
        ns.Timeline:Refresh()
    end
end
