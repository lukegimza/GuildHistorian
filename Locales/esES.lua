local GH, ns = ...
if GetLocale() ~= "esES" and GetLocale() ~= "esMX" then return end

local L = ns.L

-- Only override keys that have translations; the rest fall back to enUS
L["ADDON_NAME"] = "Historiador de Hermandad"
L["NOT_IN_GUILD"] = "No est\195\161s en una hermandad."
L["UI_TIMELINE"] = "L\195\173nea de tiempo"
L["UI_SETTINGS"] = "Configuraci\195\179n"
L["UI_NO_EVENTS"] = "No hay eventos registrados a\195\186n. El Historiador de Hermandad registra autom\195\161ticamente noticias, cambios de plantilla y logros."
