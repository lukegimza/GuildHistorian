local GH, ns = ...

local L = ns.L

local FilterBar = {}
ns.FilterBar = FilterBar

local container = nil
local searchBox = nil
local categoryChecks = {}
local clearButton = nil

local currentFilters = {
    types = nil,
    search = nil,
    startDate = nil,
    endDate = nil,
    difficultyID = nil,
}

function FilterBar:Init(parent)
    if container then return container end

    container = CreateFrame("Frame", "GuildHistorianFilterBar", parent)
    container:SetPoint("TOPLEFT", 0, 0)
    container:SetPoint("TOPRIGHT", 0, 0)
    container:SetHeight(36)

    -- Search box
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

    -- Category filter checkboxes
    local xOffset = 180
    local importantTypes = {
        { type = "BOSS_KILL",    label = L["BOSS_KILL"] },
        { type = "MEMBER_JOIN",  label = L["MEMBER_JOIN"] },
        { type = "ACHIEVEMENT",  label = L["ACHIEVEMENT"] },
        { type = "LOOT",         label = L["LOOT"] },
        { type = "MILESTONE",    label = L["MILESTONE"] },
    }

    for _, info in ipairs(importantTypes) do
        local check = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("LEFT", xOffset, 0)
        check:SetChecked(true)
        check.eventType = info.type

        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(info.label)

        local typeInfo = ns.EVENT_TYPE_INFO[info.type]
        if typeInfo then
            label:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
        end

        check:SetScript("OnClick", function()
            FilterBar:UpdateTypeFilters()
            FilterBar:ApplyFilters()
        end)

        categoryChecks[info.type] = check
        xOffset = xOffset + label:GetStringWidth() + 36
    end

    -- Clear filters button
    clearButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("RIGHT", -4, 0)
    clearButton:SetText(L["UI_CLEAR_FILTERS"])
    clearButton:SetScript("OnClick", function()
        FilterBar:ClearFilters()
    end)

    return container
end

function FilterBar:UpdateTypeFilters()
    local anyUnchecked = false
    local types = {}

    for eventType, check in pairs(categoryChecks) do
        if check:GetChecked() then
            types[eventType] = true
            -- Also include related types
            if eventType == "BOSS_KILL" then
                types["FIRST_KILL"] = true
            elseif eventType == "MEMBER_JOIN" then
                types["MEMBER_LEAVE"] = true
                types["MEMBER_RANK_CHANGE"] = true
                types["MEMBER_MAX_LEVEL"] = true
            elseif eventType == "ACHIEVEMENT" then
                types["GUILD_ACHIEVEMENT"] = true
            end
        else
            anyUnchecked = true
        end
    end

    -- Include notes always
    types["PLAYER_NOTE"] = true

    if anyUnchecked then
        currentFilters.types = types
    else
        currentFilters.types = nil  -- No filter = show all
    end
end

function FilterBar:SetDatePreset(days)
    if not days then
        currentFilters.startDate = nil
        currentFilters.endDate = nil
    else
        currentFilters.endDate = GetServerTime()
        currentFilters.startDate = currentFilters.endDate - (days * 86400)
    end
    self:ApplyFilters()
end

function FilterBar:ClearFilters()
    -- Reset search
    if searchBox then
        searchBox:SetText("")
    end
    currentFilters.search = nil

    -- Reset checkboxes
    for _, check in pairs(categoryChecks) do
        check:SetChecked(true)
    end
    currentFilters.types = nil

    -- Reset date range
    currentFilters.startDate = nil
    currentFilters.endDate = nil

    -- Reset difficulty
    currentFilters.difficultyID = nil

    self:ApplyFilters()
end

function FilterBar:GetFilters()
    -- Return nil if no filters are active
    if not currentFilters.types and not currentFilters.search
       and not currentFilters.startDate and not currentFilters.difficultyID then
        return nil
    end
    return currentFilters
end

function FilterBar:ApplyFilters()
    if ns.Timeline then
        ns.Timeline:Refresh()
    end
end
