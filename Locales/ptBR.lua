local GH, ns = ...
if GetLocale() ~= "ptBR" then return end

local L = ns.L

-- Only override keys that have translations; the rest fall back to enUS
L["ADDON_NAME"] = "Historiador da Guilda"
L["NOT_IN_GUILD"] = "Voc\195\170 n\195\163o est\195\161 em uma guilda."
L["UI_TIMELINE"] = "Linha do tempo"
L["UI_SETTINGS"] = "Configura\195\167\195\181es"
L["UI_NO_EVENTS"] = "Nenhum evento para exibir. O Historiador da Guilda mostra not\195\173cias, mudan\195\167as no elenco e conquistas do servidor."
