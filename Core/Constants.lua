--- GuildHistorian constants and default configuration.
-- Defines news types, event log types, difficulty mappings, database defaults,
-- and shared UI backdrop settings used across the addon.
-- @module Constants

local GH, ns = ...

ns.ADDON_NAME = "GuildHistorian"
ns.ADDON_PREFIX = "GH"

ns.ON_THIS_DAY_DELAY = 10
ns.ON_THIS_DAY_DISMISS = 30

--- Maps guild news type IDs to their integer constants.
-- Values correspond to WoW's internal guild news type enum.
ns.NEWS_TYPES = {
    GUILD_ACHIEVEMENT   = 0,
    PLAYER_ACHIEVEMENT  = 1,
    DUNGEON_ENCOUNTER   = 2,
    ITEM_LOOT           = 3,
    ITEM_CRAFT          = 4,
    ITEM_PURCHASE       = 5,
    GUILD_LEVEL         = 6,
    GUILD_CREATE        = 7,
    EVENT               = 8,
}

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

--- Maps guild event log type strings used by GetGuildEventInfo.
ns.EVENT_LOG_TYPES = {
    INVITE  = "invite",
    JOIN    = "join",
    PROMOTE = "promote",
    DEMOTE  = "demote",
    REMOVE  = "remove",
    QUIT    = "quit",
}

ns.GUILD_ACHIEVEMENT_CATEGORY = 15076
ns.DB_VERSION = 1
ns.CARD_PADDING = 8
ns.CARD_GAP = 8

--- Maps WoW dungeon difficulty IDs to human-readable names.
ns.DIFFICULTY_NAMES = {
    [1]  = "Normal",
    [2]  = "Heroic",
    [3]  = "10 Player",
    [4]  = "25 Player",
    [5]  = "10 Player (Heroic)",
    [6]  = "25 Player (Heroic)",
    [7]  = "Looking For Raid",
    [8]  = "Mythic Keystone",
    [9]  = "40 Player",
    [14] = "Normal",
    [15] = "Heroic",
    [16] = "Mythic",
    [17] = "Looking For Raid",
    [23] = "Mythic",
    [24] = "Timewalking",
    [33] = "Timewalking",
}

--- Default saved variable structure for AceDB.
ns.DB_DEFAULTS = {
    profile = {
        minimap = { hide = false },
        display = {
            showOnThisDay = true,
            defaultTab = 1,
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
