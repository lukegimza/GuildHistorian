local GH, ns = ...

local L = ns.L
local Database = ns.Database

local MinimapButton = {}
ns.MinimapButton = MinimapButton

function MinimapButton:Init()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataObj = LDB:NewDataObject(ns.ADDON_NAME, {
        type = "data source",
        text = L["ADDON_NAME"],
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ns.MainFrame then
                    ns.MainFrame:Toggle()
                end
            elseif button == "RightButton" then
                if ns.settingsCategoryID then
                    Settings.OpenToCategory(ns.settingsCategoryID)
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(format("%s |cff888888v%s|r",
                L["MINIMAP_TOOLTIP_TITLE"],
                ns.addon and ns.addon.version or "1.0.0"))

            local count = Database:GetEventCount()
            tooltip:AddLine(format(L["MINIMAP_TOOLTIP_EVENTS"], count), 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"])
            tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"])
        end,
    })

    LDBIcon:Register(ns.ADDON_NAME, dataObj, ns.addon.db.profile.minimap)
end
