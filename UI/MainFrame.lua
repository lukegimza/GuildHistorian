--- Main application window with tabbed navigation.
-- Manages the top-level frame created in MainFrame.xml, provides tab
-- switching between Dashboard, Timeline, and Settings panels.
-- The throne room. Kneel before the main frame, mortals.
-- @module MainFrame

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local pairs = pairs
local ipairs = ipairs

local MainFrame = {}
ns.MainFrame = MainFrame

local frame = nil
local tabs = {}
local activeTab = nil

local TAB_DASHBOARD = 1
local TAB_TIMELINE = 2
local TAB_SETTINGS = 3

local TAB_INFO = {
    { id = TAB_DASHBOARD, label = L["UI_DASHBOARD"] },
    { id = TAB_TIMELINE,  label = L["UI_TIMELINE"] },
    { id = TAB_SETTINGS,  label = L["UI_SETTINGS"] },
}

--- Initialise the main frame from its XML template.
-- Applies the shared backdrop, wires up the close button, creates tabs,
-- and defaults to the Dashboard tab. Safe to call multiple times.
function MainFrame:Init()
    if frame then return end

    frame = GuildHistorianMainFrame
    if not frame then return end

    Utils.ApplySharedBackdrop(frame)

    local guildName = GetGuildInfo("player") or "No Guild"
    frame.Title:SetText(format("%s \226\128\148 %s", L["UI_TITLE"], guildName))

    if ns.addon then
        frame.Version:SetText("v" .. (ns.addon.version or "2.0.0"))
    end

    frame:RegisterForDrag("LeftButton")

    frame.CloseButton:SetScript("OnClick", function()
        MainFrame:Hide()
    end)

    self:CreateTabs()

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)

    tinsert(UISpecialFrames, "GuildHistorianMainFrame")

    self:SelectTab(TAB_DASHBOARD)
end

--- Build the tab buttons inside the TabContainer region.
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

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER", 0, 0)
        tab.text:SetText(info.label)

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

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

--- Switch to a specific tab, hiding all other panels.
---@param tabID number Tab constant (TAB_DASHBOARD, TAB_TIMELINE, or TAB_SETTINGS)
function MainFrame:SelectTab(tabID)
    activeTab = tabID

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

    if ns.Dashboard then ns.Dashboard:Hide() end
    if ns.Timeline then ns.Timeline:Hide() end
    if ns.SettingsPanel then ns.SettingsPanel:HideInline() end

    if tabID == TAB_DASHBOARD then
        if ns.Dashboard then ns.Dashboard:Show() end
    elseif tabID == TAB_TIMELINE then
        if ns.Timeline then ns.Timeline:Show() end
    elseif tabID == TAB_SETTINGS then
        if ns.SettingsPanel then ns.SettingsPanel:ShowInline() end
    end
end

--- Show the main frame, initialising it first if needed.
function MainFrame:Show()
    if not frame then self:Init() end
    if frame then frame:Show() end
end

--- Hide the main frame.
function MainFrame:Hide()
    if frame then frame:Hide() end
end

--- Toggle the main frame's visibility.
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

--- Return whether the main frame is currently visible.
---@return boolean shown True if shown
function MainFrame:IsShown()
    return frame and frame:IsShown()
end

--- Return the Content child frame used to host tab panels.
---@return Frame|nil content The content frame, or nil if not initialised
function MainFrame:GetContentFrame()
    if not frame then self:Init() end
    return frame and frame.Content
end
