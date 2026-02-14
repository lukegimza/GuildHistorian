local GH, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

-- Only override keys that have translations; the rest fall back to enUS
L["ADDON_NAME"] = "Historien de Guilde"
L["NOT_IN_GUILD"] = "Vous n'\195\170tes pas dans une guilde."
L["UI_TIMELINE"] = "Chronologie"
L["UI_SETTINGS"] = "Param\195\168tres"
L["UI_NO_EVENTS"] = "Aucun \195\169v\195\169nement enregistr\195\169. L'Historien de Guilde enregistre automatiquement les nouvelles, les changements de liste et les hauts faits."
