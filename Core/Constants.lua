--- GuildHistorian constants and default configuration.
-- Defines news types, event log types, difficulty mappings, database defaults,
-- and shared UI backdrop settings used across the addon.
-- @module Constants

local GH, ns = ...

ns.ADDON_NAME = "GuildHistorian"

ns.ON_THIS_DAY_DELAY = 10
ns.ON_THIS_DAY_DISMISS = 30

--- Display metadata for each news type, indexed by news type ID.
-- Each entry contains label (string), icon (texture path), and color (RGB table).
ns.NEWS_TYPE_INFO = {
    [0] = { label = "Guild Achievement", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", color = {0.78, 0.61, 1.0} },
    [1] = { label = "Achievement",       icon = "Interface\\Icons\\Achievement_General",                    color = {1.0, 0.78, 0.0} },
    [2] = { label = "Boss Kill",         icon = "Interface\\Icons\\Achievement_Boss_KilJaeden",             color = {1.0, 0.41, 0.41} },
    [3] = { label = "Loot",              icon = "Interface\\Icons\\INV_Misc_Bag_10",                       color = {0.0, 0.8, 1.0} },
    [4] = { label = "Crafted",           icon = "Interface\\Icons\\Trade_BlackSmithing",                    color = {0.9, 0.7, 0.3} },
    [5] = { label = "Purchased",         icon = "Interface\\Icons\\INV_Misc_Coin_01",                      color = {0.8, 0.8, 0.4} },
    [6] = { label = "Guild Level",       icon = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention_Rank2", color = {1.0, 0.5, 0.0} },
    [7] = { label = "Guild Created",     icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",            color = {0.33, 1.0, 0.33} },
    [8] = { label = "Event",             icon = "Interface\\Icons\\INV_Misc_Note_01",                      color = {0.9, 0.9, 0.9} },
}

ns.CARD_PADDING = 8
ns.CARD_GAP = 8

--- Default saved variable structure for AceDB.
ns.DB_DEFAULTS = {
    profile = {
        minimap = { hide = false },
        display = {
            showOnThisDay = true,
        },
        cards = {
            showGuildPulse = true,
            showOnThisDay = true,
            showRecentActivity = true,
            showTopAchievers = true,
            showActivitySnapshot = true,
            showClassComposition = true,
            showAchievementProgress = true,
        },
        debug = false,
    },
    char = {
        lastOnThisDayDate = "",
    },
}

--- Shared backdrop template used by all framed UI panels.
ns.SHARED_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

ns.SHARED_BACKDROP_COLOR = { 0.05, 0.05, 0.1, 0.92 }
ns.SHARED_BACKDROP_BORDER_COLOR = { 0.78, 0.65, 0.35, 1 }
