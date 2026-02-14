local GH, ns = ...

local L = ns.L

local format = format

local MinimapButton = {}
ns.MinimapButton = MinimapButton

function MinimapButton:Init()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataObj = LDB:NewDataObject(ns.ADDON_NAME, {
        type = "data source",
        text = L["ADDON_NAME"],
        icon = "Interface\\AddOns\\GuildHistorian\\Assets\\logo_400x400",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ns.MainFrame then ns.MainFrame:Toggle() end
            elseif button == "RightButton" then
                if ns.settingsCategoryID then
                    Settings.OpenToCategory(ns.settingsCategoryID)
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(format("%s |cff888888v%s|r", L["MINIMAP_TOOLTIP_TITLE"], ns.addon and ns.addon.version or "2.0.0"))
            local counts = ns.RosterReader and ns.RosterReader:GetCounts() or {total=0, online=0}
            tooltip:AddLine(format(L["MINIMAP_TOOLTIP_MEMBERS"], counts.total, counts.online), 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"])
            tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"])
        end,
    })

    LDBIcon:Register(ns.ADDON_NAME, dataObj, ns.addon.db.profile.minimap)
end
