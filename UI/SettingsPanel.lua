local GH, ns = ...

local L = ns.L
local addon = ns.addon

local format = format
local ipairs = ipairs
local tostring = tostring

local SettingsPanel = {}
ns.SettingsPanel = SettingsPanel

local inlineContainer = nil

function SettingsPanel:Init()
    local canvas = self:BuildBlizzardCanvas()
    local category = Settings.RegisterCanvasLayoutCategory(canvas, L["ADDON_NAME"])
    category.ID = ns.ADDON_NAME
    ns.settingsCategoryID = category.ID
    Settings.RegisterAddOnCategory(category)

    self:BuildInlinePanel()
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

    local yOffset = -70

    yOffset = self:CreateSectionHeader(canvas, yOffset, L["SETTINGS_TRACKING"])

    yOffset = self:CreateCheckbox(canvas, yOffset,
        L["SETTINGS_TRACK_BOSS_KILLS"], L["SETTINGS_TRACK_BOSS_KILLS_DESC"],
        function() return addon.db.profile.tracking.bossKills end,
        function(val) addon.db.profile.tracking.bossKills = val end)

    yOffset = self:CreateCheckbox(canvas, yOffset,
        L["SETTINGS_TRACK_ROSTER"], L["SETTINGS_TRACK_ROSTER_DESC"],
        function() return addon.db.profile.tracking.roster end,
        function(val) addon.db.profile.tracking.roster = val end)

    yOffset = self:CreateCheckbox(canvas, yOffset,
        L["SETTINGS_TRACK_ACHIEVEMENTS"], L["SETTINGS_TRACK_ACHIEVEMENTS_DESC"],
        function() return addon.db.profile.tracking.achievements end,
        function(val) addon.db.profile.tracking.achievements = val end)

    yOffset = self:CreateCheckbox(canvas, yOffset,
        L["SETTINGS_TRACK_LOOT"], L["SETTINGS_TRACK_LOOT_DESC"],
        function() return addon.db.profile.tracking.loot end,
        function(val) addon.db.profile.tracking.loot = val end)

    yOffset = yOffset - 4
    local qualityLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", 20, yOffset)
    qualityLabel:SetText(L["SETTINGS_LOOT_QUALITY"])
    qualityLabel:SetTextColor(0.8, 0.8, 0.8)

    local qualities = {
        { label = L["QUALITY_UNCOMMON"],  value = 2 },
        { label = L["QUALITY_RARE"],      value = 3 },
        { label = L["QUALITY_EPIC"],      value = 4 },
        { label = L["QUALITY_LEGENDARY"], value = 5 },
    }

    local qualityBtns = {}
    local qxOffset = 160
    for _, q in ipairs(qualities) do
        local btn = CreateFrame("Button", nil, canvas)
        btn:SetSize(80, 20)
        btn:SetPoint("TOPLEFT", qxOffset, yOffset)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(q.label)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.value = q.value

        btn:SetScript("OnClick", function()
            addon.db.profile.tracking.lootQuality = q.value
            SettingsPanel:UpdateQualityButtons(qualityBtns)
        end)

        qualityBtns[#qualityBtns + 1] = btn
        qxOffset = qxOffset + 84
    end
    self:UpdateQualityButtons(qualityBtns)
    yOffset = yOffset - 30

    yOffset = yOffset - 10
    yOffset = self:CreateSectionHeader(canvas, yOffset, L["SETTINGS_DISPLAY"])

    yOffset = self:CreateCheckbox(canvas, yOffset,
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

    yOffset = self:CreateCheckbox(canvas, yOffset,
        L["SETTINGS_ON_THIS_DAY"], L["SETTINGS_ON_THIS_DAY_DESC"],
        function() return addon.db.profile.display.showOnThisDay end,
        function(val) addon.db.profile.display.showOnThisDay = val end)

    yOffset = yOffset - 10
    yOffset = self:CreateSectionHeader(canvas, yOffset, L["SETTINGS_DATA"])

    local maxEventsLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxEventsLabel:SetPoint("TOPLEFT", 20, yOffset)
    maxEventsLabel:SetText(L["SETTINGS_MAX_EVENTS"])
    maxEventsLabel:SetTextColor(0.8, 0.8, 0.8)

    local maxEventsValue = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxEventsValue:SetPoint("TOPLEFT", 200, yOffset)
    maxEventsValue:SetText(tostring(addon.db.profile.data.maxEvents))
    maxEventsValue:SetTextColor(1, 1, 1)

    local presets = { 1000, 2500, 5000, 10000 }
    local pxOffset = 260
    for _, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
        btn:SetSize(50, 20)
        btn:SetPoint("TOPLEFT", pxOffset, yOffset + 4)
        btn:SetText(tostring(preset))
        btn:SetScript("OnClick", function()
            addon.db.profile.data.maxEvents = preset
            maxEventsValue:SetText(tostring(preset))
        end)
        pxOffset = pxOffset + 56
    end

    return canvas
end

function SettingsPanel:BuildInlinePanel()
    local parent = ns.MainFrame and ns.MainFrame:GetContentFrame()
    if not parent then return end

    inlineContainer = CreateFrame("Frame", "GuildHistorianSettingsInline", parent)
    inlineContainer:SetAllPoints()
    inlineContainer:Hide()

    local yOffset = -8

    yOffset = self:CreateSectionHeader(inlineContainer, yOffset, L["SETTINGS_TRACKING"])

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
        L["SETTINGS_TRACK_BOSS_KILLS"], L["SETTINGS_TRACK_BOSS_KILLS_DESC"],
        function() return addon.db.profile.tracking.bossKills end,
        function(val) addon.db.profile.tracking.bossKills = val end)

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
        L["SETTINGS_TRACK_ROSTER"], L["SETTINGS_TRACK_ROSTER_DESC"],
        function() return addon.db.profile.tracking.roster end,
        function(val) addon.db.profile.tracking.roster = val end)

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
        L["SETTINGS_TRACK_ACHIEVEMENTS"], L["SETTINGS_TRACK_ACHIEVEMENTS_DESC"],
        function() return addon.db.profile.tracking.achievements end,
        function(val) addon.db.profile.tracking.achievements = val end)

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
        L["SETTINGS_TRACK_LOOT"], L["SETTINGS_TRACK_LOOT_DESC"],
        function() return addon.db.profile.tracking.loot end,
        function(val) addon.db.profile.tracking.loot = val end)

    yOffset = yOffset - 4
    local qualityLabel = inlineContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", 20, yOffset)
    qualityLabel:SetText(L["SETTINGS_LOOT_QUALITY"])
    qualityLabel:SetTextColor(0.8, 0.8, 0.8)

    local qualities = {
        { label = L["QUALITY_UNCOMMON"],  value = 2 },
        { label = L["QUALITY_RARE"],      value = 3 },
        { label = L["QUALITY_EPIC"],      value = 4 },
        { label = L["QUALITY_LEGENDARY"], value = 5 },
    }

    local qualityBtns = {}
    local qxOffset = 160
    for _, q in ipairs(qualities) do
        local btn = CreateFrame("Button", nil, inlineContainer)
        btn:SetSize(80, 20)
        btn:SetPoint("TOPLEFT", qxOffset, yOffset)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(q.label)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.value = q.value

        btn:SetScript("OnClick", function()
            addon.db.profile.tracking.lootQuality = q.value
            SettingsPanel:UpdateQualityButtons(qualityBtns)
        end)

        qualityBtns[#qualityBtns + 1] = btn
        qxOffset = qxOffset + 84
    end
    self:UpdateQualityButtons(qualityBtns)
    yOffset = yOffset - 30

    yOffset = yOffset - 10
    yOffset = self:CreateSectionHeader(inlineContainer, yOffset, L["SETTINGS_DISPLAY"])

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
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

    yOffset = self:CreateCheckbox(inlineContainer, yOffset,
        L["SETTINGS_ON_THIS_DAY"], L["SETTINGS_ON_THIS_DAY_DESC"],
        function() return addon.db.profile.display.showOnThisDay end,
        function(val) addon.db.profile.display.showOnThisDay = val end)

    yOffset = yOffset - 10
    yOffset = self:CreateSectionHeader(inlineContainer, yOffset, L["SETTINGS_DATA"])

    local maxEventsLabel = inlineContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxEventsLabel:SetPoint("TOPLEFT", 20, yOffset)
    maxEventsLabel:SetText(L["SETTINGS_MAX_EVENTS"])
    maxEventsLabel:SetTextColor(0.8, 0.8, 0.8)

    local maxEventsValue = inlineContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxEventsValue:SetPoint("TOPLEFT", 200, yOffset)
    maxEventsValue:SetText(tostring(addon.db.profile.data.maxEvents))
    maxEventsValue:SetTextColor(1, 1, 1)

    local presets = { 1000, 2500, 5000, 10000 }
    local pxOffset = 260
    for _, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, inlineContainer, "UIPanelButtonTemplate")
        btn:SetSize(50, 20)
        btn:SetPoint("TOPLEFT", pxOffset, yOffset + 4)
        btn:SetText(tostring(preset))
        btn:SetScript("OnClick", function()
            addon.db.profile.data.maxEvents = preset
            maxEventsValue:SetText(tostring(preset))
        end)
        pxOffset = pxOffset + 56
    end
end

function SettingsPanel:UpdateQualityButtons(buttons)
    local current = addon.db.profile.tracking.lootQuality
    for _, btn in ipairs(buttons) do
        if btn.value == current then
            btn.bg:SetColorTexture(0.3, 0.3, 0.1, 0.8)
            btn.text:SetTextColor(1, 0.84, 0)
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.2, 0.6)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
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
