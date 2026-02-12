local GH, ns = ...

local L = ns.L

local MainFrame = {}
ns.MainFrame = MainFrame

local frame = nil
local tabs = {}
local activeTab = nil
local TAB_TIMELINE = 1
local TAB_STATISTICS = 2
local TAB_SETTINGS = 3

local TAB_INFO = {
    { id = TAB_TIMELINE,   label = L["UI_TIMELINE"] },
    { id = TAB_STATISTICS, label = L["UI_STATISTICS"] },
    { id = TAB_SETTINGS,   label = L["UI_SETTINGS"] },
}

function MainFrame:Init()
    if frame then return end

    frame = GuildHistorianMainFrame
    if not frame then return end

    -- Set backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.1, 0.92)
    frame:SetBackdropBorderColor(0.78, 0.65, 0.35, 1)

    -- Title
    local guildName = GetGuildInfo("player") or "No Guild"
    frame.Title:SetText(format("%s \226\128\148 %s", L["UI_TITLE"], guildName))

    -- Version
    if ns.addon then
        frame.Version:SetText("v" .. (ns.addon.version or "1.0.0"))
    end

    -- Make draggable
    frame:RegisterForDrag("LeftButton")

    -- Close button
    frame.CloseButton:SetScript("OnClick", function()
        MainFrame:Hide()
    end)

    -- Create tabs
    self:CreateTabs()

    -- Save/restore position
    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)

    -- Add to special frames (close on Escape)
    tinsert(UISpecialFrames, "GuildHistorianMainFrame")

    -- Default to timeline tab
    self:SelectTab(TAB_TIMELINE)
end

function MainFrame:CreateTabs()
    local tabContainer = frame.TabContainer
    local prevTab = nil

    for i, info in ipairs(TAB_INFO) do
        local tab = CreateFrame("Button", "GuildHistorianTab" .. i, tabContainer)
        tab:SetSize(100, 28)

        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("LEFT", 4, 0)
        end

        -- Tab label
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER", 0, 0)
        tab.text:SetText(info.label)

        -- Tab background
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

        -- Active indicator
        tab.activeLine = tab:CreateTexture(nil, "OVERLAY")
        tab.activeLine:SetHeight(2)
        tab.activeLine:SetPoint("BOTTOMLEFT", 0, 0)
        tab.activeLine:SetPoint("BOTTOMRIGHT", 0, 0)
        tab.activeLine:SetColorTexture(0.78, 0.65, 0.35, 1)
        tab.activeLine:Hide()

        tab.tabID = info.id

        tab:SetScript("OnClick", function()
            MainFrame:SelectTab(info.id)
        end)

        tab:SetScript("OnEnter", function(self)
            if activeTab ~= info.id then
                self.bg:SetColorTexture(0.2, 0.2, 0.25, 0.8)
            end
        end)

        tab:SetScript("OnLeave", function(self)
            if activeTab ~= info.id then
                self.bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)
            end
        end)

        tabs[info.id] = tab
        prevTab = tab
    end
end

function MainFrame:SelectTab(tabID)
    activeTab = tabID

    -- Update tab visuals
    for id, tab in pairs(tabs) do
        if id == tabID then
            tab.bg:SetColorTexture(0.25, 0.25, 0.3, 1)
            tab.activeLine:Show()
            tab.text:SetTextColor(1, 0.84, 0)
        else
            tab.bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)
            tab.activeLine:Hide()
            tab.text:SetTextColor(1, 1, 1)
        end
    end

    -- Hide all content panels
    if ns.Timeline then ns.Timeline:Hide() end
    if ns.StatsPanel then ns.StatsPanel:Hide() end
    if ns.SettingsPanel then ns.SettingsPanel:HideInline() end

    -- Show selected panel
    if tabID == TAB_TIMELINE then
        if ns.Timeline then ns.Timeline:Show() end
    elseif tabID == TAB_STATISTICS then
        if ns.StatsPanel then ns.StatsPanel:Show() end
    elseif tabID == TAB_SETTINGS then
        if ns.SettingsPanel then ns.SettingsPanel:ShowInline() end
    end
end

function MainFrame:Show()
    if not frame then self:Init() end
    if frame then
        frame:Show()
    end
end

function MainFrame:Hide()
    if frame then
        frame:Hide()
    end
end

function MainFrame:Toggle()
    if not frame then self:Init() end
    if frame then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

function MainFrame:IsShown()
    return frame and frame:IsShown()
end

function MainFrame:GetContentFrame()
    if not frame then self:Init() end
    return frame and frame.Content
end

-- Initialize when addon loads
if ns.addon then
    ns.addon:RegisterMessage("GH_EVENTS_UPDATED", function()
        -- Refresh active tab if showing
        if MainFrame:IsShown() then
            if activeTab == TAB_TIMELINE and ns.Timeline then
                ns.Timeline:Refresh()
            elseif activeTab == TAB_STATISTICS and ns.StatsPanel then
                ns.StatsPanel:Refresh()
            end
        end
    end)
end
