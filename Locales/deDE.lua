local GH, ns = ...
if GetLocale() ~= "deDE" then return end

local L = ns.L

-- Only override keys that have translations; the rest fall back to enUS
L["ADDON_NAME"] = "Gilden-Historiker"
L["NOT_IN_GUILD"] = "Du bist in keiner Gilde."
L["UI_TIMELINE"] = "Zeitstrahl"
L["UI_SETTINGS"] = "Einstellungen"
L["UI_NO_EVENTS"] = "Keine Ereignisse vorhanden. Gilden-Historiker zeigt Gildennachrichten, Kader\195\164nderungen und Erfolge vom Server an."
