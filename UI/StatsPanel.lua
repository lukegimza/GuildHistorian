local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database

local StatsPanel = {}
ns.StatsPanel = StatsPanel

local container = nil

function StatsPanel:Init()
    if container then return end

    local parent = ns.MainFrame:GetContentFrame()
    if not parent then return end

    container = CreateFrame("Frame", "GuildHistorianStatsPanel", parent)
    container:SetAllPoints()
    container:Hide()

    -- Title
    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -8)
    title:SetText(L["UI_STATISTICS"])
    title:SetTextColor(0.78, 0.65, 0.35)

    -- Stats will be laid out in two columns
    container.leftColumn = CreateFrame("Frame", nil, container)
    container.leftColumn:SetPoint("TOPLEFT", 16, -36)
    container.leftColumn:SetPoint("BOTTOMLEFT", 16, 8)
    container.leftColumn:SetWidth(280)

    container.rightColumn = CreateFrame("Frame", nil, container)
    container.rightColumn:SetPoint("TOPLEFT", container.leftColumn, "TOPRIGHT", 20, 0)
    container.rightColumn:SetPoint("BOTTOMRIGHT", -16, 8)

    -- Create stat display elements
    container.statLabels = {}

    self:Refresh()
end

function StatsPanel:CreateStatLine(parent, yOffset, label, value)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, yOffset)
    labelText:SetTextColor(0.7, 0.7, 0.7)
    labelText:SetText(label)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    valueText:SetPoint("TOPLEFT", 0, yOffset - 16)
    valueText:SetTextColor(1, 1, 1)
    valueText:SetText(tostring(value))

    return valueText, yOffset - 44
end

function StatsPanel:CreateSectionHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, yOffset)
    header:SetTextColor(0.78, 0.65, 0.35)
    header:SetText(text)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, yOffset - 14)
    line:SetPoint("TOPRIGHT", 0, yOffset - 14)
    line:SetColorTexture(0.78, 0.65, 0.35, 0.3)

    return yOffset - 24
end

function StatsPanel:Refresh()
    if not container then self:Init(); return end

    -- Clear existing dynamic content
    for _, child in ipairs(container.statLabels) do
        child:SetText("")
    end
    container.statLabels = {}

    local stats = Database:GetStats()

    -- Remove old children by re-creating columns
    container.leftColumn:Hide()
    container.rightColumn:Hide()

    container.leftColumn = CreateFrame("Frame", nil, container)
    container.leftColumn:SetPoint("TOPLEFT", 16, -36)
    container.leftColumn:SetPoint("BOTTOMLEFT", 16, 8)
    container.leftColumn:SetWidth(280)

    container.rightColumn = CreateFrame("Frame", nil, container)
    container.rightColumn:SetPoint("TOPLEFT", container.leftColumn, "TOPRIGHT", 20, 0)
    container.rightColumn:SetPoint("BOTTOMRIGHT", -16, 8)

    local left = container.leftColumn
    local right = container.rightColumn

    -- Left column: Overview stats
    local y = 0
    y = self:CreateSectionHeader(left, y, "Overview")

    local val
    val, y = self:CreateStatLine(left, y, L["STATS_TOTAL_EVENTS"], stats.totalEvents)
    container.statLabels[#container.statLabels + 1] = val

    val, y = self:CreateStatLine(left, y, L["STATS_FIRST_KILLS"], stats.firstKills)
    container.statLabels[#container.statLabels + 1] = val

    val, y = self:CreateStatLine(left, y, L["STATS_MEMBERS_TRACKED"],
        format("%d (active: %d)", stats.membersTracked, stats.activeMembers))
    container.statLabels[#container.statLabels + 1] = val

    if stats.oldestEvent then
        val, y = self:CreateStatLine(left, y, "Tracking Since",
            Utils.TimestampToDisplay(stats.oldestEvent))
        container.statLabels[#container.statLabels + 1] = val
    end

    -- Events by type breakdown
    y = y - 10
    y = self:CreateSectionHeader(left, y, L["STATS_BY_TYPE"])

    for eventType, count in pairs(stats.eventsByType) do
        local typeInfo = ns.EVENT_TYPE_INFO[eventType]
        local typeName = L[eventType] or eventType

        local label = left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 0, y)
        if typeInfo then
            label:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
        end
        label:SetText(format("%s: %d", typeName, count))
        container.statLabels[#container.statLabels + 1] = label
        y = y - 16
    end

    -- Right column: Most active and longest serving
    y = 0
    y = self:CreateSectionHeader(right, y, L["STATS_MOST_ACTIVE"])

    for i, entry in ipairs(stats.mostActive) do
        local label = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 0, y)
        label:SetText(format("%d. %s (%d events)", i, entry.name, entry.count))
        label:SetTextColor(0.9, 0.9, 0.9)
        container.statLabels[#container.statLabels + 1] = label
        y = y - 20
    end

    if #stats.mostActive == 0 then
        local label = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 0, y)
        label:SetText("No data yet")
        label:SetTextColor(0.5, 0.5, 0.5)
        container.statLabels[#container.statLabels + 1] = label
        y = y - 20
    end

    y = y - 10
    y = self:CreateSectionHeader(right, y, L["STATS_LONGEST_SERVING"])

    for i, entry in ipairs(stats.longestServing) do
        local label = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 0, y)
        local since = Utils.TimestampToDisplay(entry.firstSeen)
        label:SetText(format("%d. %s (since %s)", i, entry.name, since))
        label:SetTextColor(0.9, 0.9, 0.9)
        container.statLabels[#container.statLabels + 1] = label
        y = y - 20
    end

    if #stats.longestServing == 0 then
        local label = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 0, y)
        label:SetText("No data yet")
        label:SetTextColor(0.5, 0.5, 0.5)
        container.statLabels[#container.statLabels + 1] = label
    end
end

function StatsPanel:Show()
    if not container then self:Init() end
    if container then
        container:Show()
        self:Refresh()
    end
end

function StatsPanel:Hide()
    if container then container:Hide() end
end
