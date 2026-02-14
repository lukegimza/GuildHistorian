local GH, ns = ...

local L = ns.L
local addon = ns.addon

local format = format
local ipairs = ipairs
local tostring = tostring

local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local inlineContainer = nil

local CARD_TOGGLES = {
    { key = "showGuildPulse",         label = L["SETTINGS_CARD_GUILD_PULSE"],         desc = L["SETTINGS_CARD_GUILD_PULSE_DESC"] },
    { key = "showOnThisDay",          label = L["SETTINGS_CARD_ON_THIS_DAY"],         desc = L["SETTINGS_CARD_ON_THIS_DAY_DESC"] },
    { key = "showRecentActivity",     label = L["SETTINGS_CARD_RECENT_ACTIVITY"],     desc = L["SETTINGS_CARD_RECENT_ACTIVITY_DESC"] },
    { key = "showTopAchievers",       label = L["SETTINGS_CARD_TOP_ACHIEVERS"],       desc = L["SETTINGS_CARD_TOP_ACHIEVERS_DESC"] },
    { key = "showActivitySnapshot",   label = L["SETTINGS_CARD_ACTIVITY_SNAPSHOT"],   desc = L["SETTINGS_CARD_ACTIVITY_SNAPSHOT_DESC"] },
    { key = "showClassComposition",   label = L["SETTINGS_CARD_CLASS_COMPOSITION"],   desc = L["SETTINGS_CARD_CLASS_COMPOSITION_DESC"] },
    { key = "showAchievementProgress",label = L["SETTINGS_CARD_ACHIEVEMENT_PROGRESS"],desc = L["SETTINGS_CARD_ACHIEVEMENT_PROGRESS_DESC"] },
}

function SettingsPanel:Init()
    local canvas = self:BuildBlizzardCanvas()
    local category = Settings.RegisterCanvasLayoutCategory(canvas, L["ADDON_NAME"])
    category.ID = ns.ADDON_NAME
    ns.settingsCategoryID = category.ID
    Settings.RegisterAddOnCategory(category)

    self:BuildInlinePanel()
end

local function BuildSettingsContent(parent, startY)
    local yOffset = startY

    yOffset = SettingsPanel:CreateSectionHeader(parent, yOffset, L["SETTINGS_DISPLAY"])

    yOffset = SettingsPanel:CreateCheckbox(parent, yOffset,
        L["SETTINGS_MINIMAP_ICON"], L["SETTINGS_MINIMAP_ICON_DESC"],
        function() return not addon.db.profile.minimap.hide end,
        function(val)
            addon.db.profile.minimap.hide = not val
            if val then
                LibStub("LibDBIcon-1.0"):Show(ns.ADDON_NAME)
            else
                LibStub("LibDBIcon-1.0"):Hide(ns.ADDON_NAME)
            end
        end)

    yOffset = SettingsPanel:CreateCheckbox(parent, yOffset,
        L["SETTINGS_ON_THIS_DAY"], L["SETTINGS_ON_THIS_DAY_DESC"],
        function() return addon.db.profile.display.showOnThisDay end,
        function(val) addon.db.profile.display.showOnThisDay = val end)

    yOffset = yOffset - 10
    yOffset = SettingsPanel:CreateSectionHeader(parent, yOffset, L["SETTINGS_DASHBOARD_CARDS"])

    for _, toggle in ipairs(CARD_TOGGLES) do
        yOffset = SettingsPanel:CreateCheckbox(parent, yOffset,
            toggle.label, toggle.desc,
            function() return addon.db.profile.cards[toggle.key] end,
            function(val)
                addon.db.profile.cards[toggle.key] = val
                if ns.Dashboard then ns.Dashboard:Refresh() end
            end)
    end

    return yOffset
end

function SettingsPanel:BuildBlizzardCanvas()
    local canvas = CreateFrame("Frame", "GuildHistorianSettingsCanvas")
    canvas:Hide()

    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["ADDON_NAME"])
    title:SetTextColor(0.78, 0.65, 0.35)

    local desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Passively records guild milestones and presents them in a browsable in-game timeline.")

    BuildSettingsContent(canvas, -70)

    return canvas
end

function SettingsPanel:BuildInlinePanel()
    local parent = ns.MainFrame and ns.MainFrame:GetContentFrame()
    if not parent then return end

    inlineContainer = CreateFrame("Frame", "GuildHistorianSettingsInline", parent)
    inlineContainer:SetAllPoints()
    inlineContainer:Hide()

    BuildSettingsContent(inlineContainer, -8)
end

function SettingsPanel:CreateSectionHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, yOffset)
    header:SetTextColor(0.78, 0.65, 0.35)
    header:SetText(text)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, yOffset - 14)
    line:SetPoint("RIGHT", -8, 0)
    line:SetColorTexture(0.78, 0.65, 0.35, 0.3)

    return yOffset - 24
end

function SettingsPanel:CreateCheckbox(parent, yOffset, label, tooltip, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 16, yOffset)
    check:SetChecked(getter())

    local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)
    text:SetTextColor(0.9, 0.9, 0.9)

    check:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    if tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return yOffset - 28
end

function SettingsPanel:ShowInline()
    if not inlineContainer then self:BuildInlinePanel() end
    if inlineContainer then inlineContainer:Show() end
end

function SettingsPanel:HideInline()
    if inlineContainer then inlineContainer:Hide() end
end
