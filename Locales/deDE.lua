local GH, ns = ...
if GetLocale() ~= "deDE" then return end

local L = ns.L

-- Only override keys that have translations; the rest fall back to enUS
L["ADDON_NAME"] = "Gilden-Historiker"
L["NOT_IN_GUILD"] = "Du bist in keiner Gilde."
L["UI_TIMELINE"] = "Zeitstrahl"
L["UI_SETTINGS"] = "Einstellungen"
L["UI_NO_EVENTS"] = "Noch keine Ereignisse aufgezeichnet. Gilden-Historiker zeichnet automatisch Gildennachrichten, Kader\195\164nderungen und Erfolge auf."
