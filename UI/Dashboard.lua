--- Dashboard tab container with scrollable two-column card layout.
-- Hosts the seven dashboard cards (Guild Pulse, On This Day, Recent Activity,
-- Top Achievers, Activity Snapshot, Class Composition, Achievement Progress)
-- arranged in a responsive grid inside a scroll frame.
-- @module Dashboard

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local Dashboard = {}
ns.Dashboard = Dashboard

local container = nil
local scrollFrame = nil
local scrollChild = nil
local cardFrames = {}

--- Create the scroll frame container and build the initial card layout.
-- Anchored inside the MainFrame content area. Safe to call multiple times.
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
    local sfWidth = scrollFrame:GetWidth()
    scrollChild:SetWidth(sfWidth > 0 and sfWidth or 600)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    self:BuildCards()
end

--- Lay out dashboard cards in a two-column grid, respecting visibility settings.
-- Cards are positioned top-down; each row's height is the tallest card in the pair.
function Dashboard:BuildCards()
    if not scrollChild then return end

    local GAP = ns.CARD_GAP
    local scWidth = scrollChild:GetWidth()
    local totalWidth = scWidth > 0 and scWidth or 600
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

--- Tear down existing cards and rebuild the layout from scratch.
-- Called when card visibility settings change or when data modules are refreshed.
-- Reuses the same scrollChild by hiding and releasing old card frames to
-- prevent frame object accumulation across repeated refreshes.
function Dashboard:Refresh()
    if not container then return end
    for i = #cardFrames, 1, -1 do
        local card = cardFrames[i]
        card:Hide()
        card:ClearAllPoints()
        card:SetParent(nil)
        cardFrames[i] = nil
    end
    self:BuildCards()
end

--- Show the dashboard panel, initialising it if needed, and refresh card data.
function Dashboard:Show()
    if not container then self:Init() end
    if container then container:Show() end
    self:Refresh()
end

--- Hide the dashboard panel.
function Dashboard:Hide()
    if container then container:Hide() end
end
