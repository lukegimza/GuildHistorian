--- Dashboard card factory methods.
-- Each Create* method returns a self-sizing BackdropTemplate frame populated
-- with data from the relevant data module. Cards are consumed by Dashboard:BuildCards.
-- Spawning UI abominations since 2024. Hail Satan.
-- @module DashboardCards

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local ipairs = ipairs
local pairs = pairs
local max = math.max
local floor = math.floor

local DashboardCards = {}
ns.DashboardCards = DashboardCards

--- Create a reusable card frame with a title bar and separator line.
---@param parent Frame Parent frame to attach the card to
---@param width number Card width in pixels
---@param title string Display title rendered in gold at the top of the card
---@return Frame card A BackdropTemplate frame with _contentStart set to the y-offset below the title
local function CreateCardFrame(parent, width, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetWidth(width)
    Utils.ApplySharedBackdrop(card, 0.7)

    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        local bg = ns.SHARED_BACKDROP_COLOR
        self:SetBackdropColor(bg[1] + 0.05, bg[2] + 0.05, bg[3] + 0.05, 0.8)
    end)
    card:SetScript("OnLeave", function(self)
        local bg = ns.SHARED_BACKDROP_COLOR
        self:SetBackdropColor(bg[1], bg[2], bg[3], 0.7)
    end)

    local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 10, -8)
    titleText:SetText(title)
    titleText:SetTextColor(0.78, 0.65, 0.35)

    local line = card:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, -24)
    line:SetPoint("TOPRIGHT", -8, -24)
    line:SetColorTexture(0.78, 0.65, 0.35, 0.3)

    card._contentStart = -32
    return card
end

--- Create the Guild Pulse card showing member counts, achievement points, and a progress bar.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Guild Pulse card
function DashboardCards:CreateGuildPulse(parent, width)
    local card = CreateCardFrame(parent, width, L["CARD_GUILD_PULSE"])
    local y = card._contentStart

    local counts = ns.RosterReader and ns.RosterReader:GetCounts() or {total=0, online=0}
    local stats = ns.AchievementScanner and ns.AchievementScanner:GetStats() or {totalPoints=0, earnedPoints=0, totalCount=0, earnedCount=0, completionPct=0}

    local membersText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    membersText:SetPoint("TOPLEFT", 10, y)
    membersText:SetText(format(L["CARD_MEMBERS_ONLINE"], counts.total, counts.online))
    membersText:SetTextColor(1, 1, 1)
    y = y - 22

    local pointsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pointsText:SetPoint("TOPLEFT", 10, y)
    pointsText:SetText(format(L["CARD_ACHIEVEMENT_POINTS"], Utils.FormatNumber(stats.earnedPoints)))
    pointsText:SetTextColor(0.9, 0.9, 0.9)
    y = y - 18

    local earnedText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    earnedText:SetPoint("TOPLEFT", 10, y)
    earnedText:SetText(format(L["CARD_ACHIEVEMENTS_EARNED"], stats.earnedCount, stats.totalCount, floor(stats.completionPct)))
    earnedText:SetTextColor(0.7, 0.7, 0.7)
    y = y - 18

    local barBg = card:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", 10, y)
    barBg:SetSize(width - 20, 12)
    barBg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

    local barFill = card:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
    local fillWidth = max(1, (width - 20) * (stats.completionPct / 100))
    barFill:SetSize(fillWidth, 12)
    barFill:SetColorTexture(0.78, 0.65, 0.35, 1)
    y = y - 20

    card:SetHeight(math.abs(y) + 8)
    return card
end

--- Create the On This Day card listing achievements earned on this date in past years.
-- Returns nil if there are no matching achievements.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame|nil card Populated card, or nil when there are no On This Day matches
function DashboardCards:CreateOnThisDay(parent, width)
    local matches = ns.AchievementScanner and ns.AchievementScanner:GetOnThisDay() or {}
    if #matches == 0 then return nil end

    local card = CreateCardFrame(parent, width, L["CARD_ON_THIS_DAY"])
    local y = card._contentStart

    for _, match in ipairs(matches) do
        local yearText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        yearText:SetPoint("TOPLEFT", 10, y)
        yearText:SetText(format(L["CARD_YEARS_AGO"], match.yearsAgo))
        yearText:SetTextColor(1, 0.84, 0)
        y = y - 16

        local achText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        achText:SetPoint("TOPLEFT", 16, y)
        achText:SetText("Guild earned \"" .. (match.name or "Unknown") .. "\"")
        achText:SetTextColor(0.9, 0.9, 0.9)
        y = y - 18
    end

    local hint = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 10, y - 4)
    hint:SetText(L["CARD_VIEW_TIMELINE"] .. " \226\134\146")
    hint:SetTextColor(0.6, 0.6, 0.6)
    y = y - 20

    card:SetHeight(math.abs(y) + 8)

    card:SetScript("OnMouseDown", function()
        local now = GetServerTime()
        local month, day = Utils.TimestampToMonthDay(now)
        if ns.Timeline then
            ns.Timeline:FilterByDate(month, day)
        end
    end)

    return card
end

--- Create the Recent Activity card showing the latest guild news entries.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Recent Activity card
function DashboardCards:CreateRecentActivity(parent, width)
    local entries = ns.NewsReader and ns.NewsReader:Read() or {}
    local card = CreateCardFrame(parent, width, L["CARD_RECENT_ACTIVITY"])
    local y = card._contentStart

    if #entries == 0 then
        local noActivity = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noActivity:SetPoint("TOPLEFT", 10, y)
        noActivity:SetText(L["CARD_NO_ACTIVITY"])
        noActivity:SetTextColor(0.5, 0.5, 0.5)
        y = y - 20
    else
        local count = math.min(8, #entries)
        for i = 1, count do
            local entry = entries[i]
            local info = entry.typeInfo or {}

            local icon = card:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", 10, y - 2)
            if info.icon then icon:SetTexture(info.icon) end

            local desc = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", 30, y)
            desc:SetPoint("RIGHT", card, "RIGHT", -80, 0)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(false)
            local label = info.label or "Event"
            local text = entry.who ~= "" and (entry.who .. " - " .. label .. ": " .. entry.what) or (label .. ": " .. entry.what)
            desc:SetText(text)
            if info.color then
                desc:SetTextColor(info.color[1], info.color[2], info.color[3])
            else
                desc:SetTextColor(0.9, 0.9, 0.9)
            end

            local timeText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            timeText:SetPoint("TOPRIGHT", -10, y)
            timeText:SetJustifyH("RIGHT")
            timeText:SetText(Utils.RelativeTime(entry.timestamp))
            timeText:SetTextColor(0.5, 0.5, 0.5)

            y = y - 20
        end
    end

    local viewMore = CreateFrame("Button", nil, card)
    viewMore:SetSize(width - 20, 16)
    viewMore:SetPoint("TOPLEFT", 10, y - 4)
    local viewMoreText = viewMore:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    viewMoreText:SetPoint("LEFT", 0, 0)
    viewMoreText:SetText("\226\134\146 " .. L["CARD_VIEW_TIMELINE"])
    viewMoreText:SetTextColor(0.6, 0.6, 0.6)
    viewMore:SetScript("OnClick", function()
        if ns.MainFrame then
            ns.MainFrame:SelectTab(2)
        end
    end)
    viewMore:SetScript("OnEnter", function()
        viewMoreText:SetTextColor(1, 0.84, 0)
    end)
    viewMore:SetScript("OnLeave", function()
        viewMoreText:SetTextColor(0.6, 0.6, 0.6)
    end)
    y = y - 20

    card:SetHeight(math.abs(y) + 8)
    return card
end

--- Create the Top Achievers card ranking guild members by achievement points.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Top Achievers card
function DashboardCards:CreateTopAchievers(parent, width)
    local achievers = ns.RosterReader and ns.RosterReader:GetTopAchievers(5) or {}
    local card = CreateCardFrame(parent, width, L["CARD_TOP_ACHIEVERS"])
    local y = card._contentStart

    for i, member in ipairs(achievers) do
        local rankText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankText:SetPoint("TOPLEFT", 10, y)
        rankText:SetText(tostring(i) .. ".")
        rankText:SetTextColor(0.7, 0.7, 0.7)

        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 30, y)
        local coloredName = Utils.ClassColoredName(member.name, member.class)
        nameText:SetText(coloredName)

        local pointsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pointsText:SetPoint("TOPRIGHT", -10, y)
        pointsText:SetJustifyH("RIGHT")
        pointsText:SetText(Utils.FormatNumber(member.achievementPoints) .. " pts")
        pointsText:SetTextColor(0.8, 0.8, 0.8)

        y = y - 20
    end

    card:SetHeight(max(80, math.abs(y) + 8))
    return card
end

--- Create the Activity Snapshot card summarising news counts by category.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Activity Snapshot card
function DashboardCards:CreateActivitySnapshot(parent, width)
    local summary = ns.NewsReader and ns.NewsReader:GetSummary() or {}
    local card = CreateCardFrame(parent, width, L["CARD_ACTIVITY_SNAPSHOT"])
    local y = card._contentStart

    local displayOrder = {
        { newsType = 2, label = "Boss Kills" },
        { newsType = 1, label = "Achievements" },
        { newsType = 0, label = "Guild Achievements" },
        { newsType = 3, label = "Notable Loot" },
    }

    for _, item in ipairs(displayOrder) do
        local count = summary[item.newsType] or 0
        local info = ns.NEWS_TYPE_INFO[item.newsType]

        local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 10, y)
        label:SetText(item.label)
        if info and info.color then
            label:SetTextColor(info.color[1], info.color[2], info.color[3])
        else
            label:SetTextColor(0.9, 0.9, 0.9)
        end

        local countText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countText:SetPoint("TOPRIGHT", -10, y)
        countText:SetJustifyH("RIGHT")
        countText:SetText(tostring(count))
        countText:SetTextColor(1, 1, 1)

        y = y - 20
    end

    card:SetHeight(max(80, math.abs(y) + 8))
    return card
end

--- Create the Class Composition card showing online max-level members grouped by class.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Class Composition card
function DashboardCards:CreateClassComposition(parent, width)
    local composition = ns.RosterReader and ns.RosterReader:GetClassComposition() or {}
    local onlineMaxLevel = ns.RosterReader and ns.RosterReader:GetOnlineMaxLevel() or {}
    local totalOnlineMax = #onlineMaxLevel

    local card = CreateCardFrame(parent, width, format(L["CARD_CLASS_COMPOSITION"], totalOnlineMax))
    local y = card._contentStart

    local xOffset = 10
    local maxX = width - 10

    local sorted = {}
    for class, count in pairs(composition) do
        sorted[#sorted + 1] = { class = class, count = count }
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    for _, entry in ipairs(sorted) do
        local color = RAID_CLASS_COLORS[entry.class]
        local displayName = entry.class:sub(1,1) .. entry.class:sub(2):lower()

        local classText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        classText:SetPoint("TOPLEFT", xOffset, y)
        classText:SetText(format("[%s x%d]", displayName, entry.count))
        if color then
            classText:SetTextColor(color.r, color.g, color.b)
        end

        xOffset = xOffset + 100
        if xOffset + 90 > maxX then
            xOffset = 10
            y = y - 18
        end
    end

    if #sorted == 0 then
        local noData = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noData:SetPoint("TOPLEFT", 10, y)
        noData:SetText("No max-level members online")
        noData:SetTextColor(0.5, 0.5, 0.5)
    end

    y = y - 18
    card:SetHeight(max(60, math.abs(y) + 8))
    return card
end

--- Create the Mythic+ Leaderboard card ranking guild members by M+ rating.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Mythic+ Leaderboard card
function DashboardCards:CreateMythicPlus(parent, width)
    local leaders = ns.RosterReader and ns.RosterReader:GetTopMythicPlus(10) or {}
    local card = CreateCardFrame(parent, width, L["CARD_MYTHIC_PLUS_TITLE"])
    local y = card._contentStart

    if #leaders == 0 then
        local noData = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noData:SetPoint("TOPLEFT", 10, y)
        noData:SetText(L["CARD_MYTHIC_PLUS_EMPTY"])
        noData:SetTextColor(0.5, 0.5, 0.5)
        y = y - 20
    else
        for i, member in ipairs(leaders) do
            local rankText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rankText:SetPoint("TOPLEFT", 10, y)
            rankText:SetText(tostring(i) .. ".")
            rankText:SetTextColor(0.7, 0.7, 0.7)

            local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("TOPLEFT", 30, y)
            local coloredName = Utils.ClassColoredName(member.name, member.class)
            nameText:SetText(coloredName)

            local scoreText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            scoreText:SetPoint("TOPRIGHT", -10, y)
            scoreText:SetJustifyH("RIGHT")
            scoreText:SetText(tostring(member.score))
            scoreText:SetTextColor(1, 0.84, 0)

            y = y - 20
        end
    end

    card:SetHeight(max(80, math.abs(y) + 8))
    return card
end

--- Create the Achievement Progress card with per-category progress bars.
---@param parent Frame Parent frame
---@param width number Card width in pixels
---@return Frame card Populated Achievement Progress card
function DashboardCards:CreateAchievementProgress(parent, width)
    local progress = ns.AchievementScanner and ns.AchievementScanner:GetCategoryProgress() or {}
    local card = CreateCardFrame(parent, width, L["CARD_ACHIEVEMENT_PROGRESS"])
    local y = card._contentStart
    local barWidth = width - 120

    for _, cat in ipairs(progress) do
        local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 10, y)
        label:SetText(format("%s  %d/%d", cat.categoryName, cat.earned, cat.total))
        label:SetTextColor(0.9, 0.9, 0.9)

        local pctText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pctText:SetPoint("TOPRIGHT", -10, y)
        pctText:SetJustifyH("RIGHT")
        pctText:SetText(format("%d%%", floor(cat.pct)))
        pctText:SetTextColor(0.78, 0.65, 0.35)

        y = y - 14

        local barBg = card:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("TOPLEFT", 10, y)
        barBg:SetSize(barWidth, 8)
        barBg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

        local fillWidth = max(1, barWidth * (cat.pct / 100))
        local barFill = card:CreateTexture(nil, "ARTWORK")
        barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
        barFill:SetSize(fillWidth, 8)
        barFill:SetColorTexture(0.78, 0.65, 0.35, 1)

        y = y - 16
    end

    card:SetHeight(max(60, math.abs(y) + 8))
    return card
end
