local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local Dashboard = {}
ns.Dashboard = Dashboard

local container = nil
local scrollFrame = nil
local scrollChild = nil
local cardFrames = {}

function Dashboard:Init()
    if container then return end

    local parent = ns.MainFrame:GetContentFrame()
    if not parent then return end

    container = CreateFrame("Frame", "GuildHistorianDashboard", parent)
    container:SetAllPoints()

    scrollFrame = CreateFrame("ScrollFrame", "GuildHistorianDashboardScroll", container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    scrollChild = CreateFrame("Frame", "GuildHistorianDashboardScrollChild", scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 600)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    self:BuildCards()
end

function Dashboard:BuildCards()
    if not scrollChild then return end

    local GAP = ns.CARD_GAP
    local totalWidth = scrollChild:GetWidth() or 600
    local halfWidth = (totalWidth - GAP * 3) / 2
    local fullWidth = totalWidth - GAP * 2

    local Cards = ns.DashboardCards
    if not Cards then return end

    local yOffset = -GAP
    local profile = ns.addon and ns.addon.db and ns.addon.db.profile

    -- Row 1: Guild Pulse (left) | On This Day (right)
    local row1Left, row1Right
    if not profile or profile.cards.showGuildPulse then
        row1Left = Cards:CreateGuildPulse(scrollChild, halfWidth)
        if row1Left then
            row1Left:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP, yOffset)
            cardFrames[#cardFrames + 1] = row1Left
        end
    end
    if not profile or profile.cards.showOnThisDay then
        row1Right = Cards:CreateOnThisDay(scrollChild, halfWidth)
        if row1Right then
            row1Right:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP + halfWidth + GAP, yOffset)
            cardFrames[#cardFrames + 1] = row1Right
        end
    end
    local row1Height = math.max(
        row1Left and row1Left:GetHeight() or 0,
        row1Right and row1Right:GetHeight() or 0
    )
    if row1Height > 0 then yOffset = yOffset - row1Height - GAP end

    -- Row 2: Recent Activity (full width)
    if not profile or profile.cards.showRecentActivity then
        local card = Cards:CreateRecentActivity(scrollChild, fullWidth)
        if card then
            card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP, yOffset)
            cardFrames[#cardFrames + 1] = card
            yOffset = yOffset - card:GetHeight() - GAP
        end
    end

    -- Row 3: Top Achievers (left) | Activity Snapshot (right)
    local row3Left, row3Right
    if not profile or profile.cards.showTopAchievers then
        row3Left = Cards:CreateTopAchievers(scrollChild, halfWidth)
        if row3Left then
            row3Left:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP, yOffset)
            cardFrames[#cardFrames + 1] = row3Left
        end
    end
    if not profile or profile.cards.showActivitySnapshot then
        row3Right = Cards:CreateActivitySnapshot(scrollChild, halfWidth)
        if row3Right then
            row3Right:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP + halfWidth + GAP, yOffset)
            cardFrames[#cardFrames + 1] = row3Right
        end
    end
    local row3Height = math.max(
        row3Left and row3Left:GetHeight() or 0,
        row3Right and row3Right:GetHeight() or 0
    )
    if row3Height > 0 then yOffset = yOffset - row3Height - GAP end

    -- Row 4: Class Composition (full width)
    if not profile or profile.cards.showClassComposition then
        local card = Cards:CreateClassComposition(scrollChild, fullWidth)
        if card then
            card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP, yOffset)
            cardFrames[#cardFrames + 1] = card
            yOffset = yOffset - card:GetHeight() - GAP
        end
    end

    -- Row 5: Achievement Progress (full width)
    if not profile or profile.cards.showAchievementProgress then
        local card = Cards:CreateAchievementProgress(scrollChild, fullWidth)
        if card then
            card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", GAP, yOffset)
            cardFrames[#cardFrames + 1] = card
            yOffset = yOffset - card:GetHeight() - GAP
        end
    end

    scrollChild:SetHeight(math.abs(yOffset))
end

function Dashboard:Refresh()
    if not container then return end
    -- Clear existing cards
    for _, card in ipairs(cardFrames) do
        card:Hide()
        card:ClearAllPoints()
    end
    wipe(cardFrames)
    self:BuildCards()
end

function Dashboard:Show()
    if not container then self:Init() end
    if container then container:Show() end
    self:Refresh()
end

function Dashboard:Hide()
    if container then container:Hide() end
end
