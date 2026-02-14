local GH, ns = ...

ns.ADDON_NAME = "GuildHistorian"
ns.ADDON_PREFIX = "GH"

ns.EVENT_TYPES = {
    BOSS_KILL           = "BOSS_KILL",
    FIRST_KILL          = "FIRST_KILL",
    MEMBER_JOIN         = "MEMBER_JOIN",
    MEMBER_LEAVE        = "MEMBER_LEAVE",
    MEMBER_RANK_CHANGE  = "MEMBER_RANK_CHANGE",
    MEMBER_MAX_LEVEL    = "MEMBER_MAX_LEVEL",
    ACHIEVEMENT         = "ACHIEVEMENT",
    GUILD_ACHIEVEMENT   = "GUILD_ACHIEVEMENT",
    LOOT                = "LOOT",
    MILESTONE           = "MILESTONE",
    PLAYER_NOTE         = "PLAYER_NOTE",
}

ns.EVENT_TYPE_INFO = {
    BOSS_KILL = {
        icon  = "Interface\\Icons\\Achievement_Boss_KilJaeden",
        color = { 1.0, 0.41, 0.41 },
    },
    FIRST_KILL = {
        icon  = "Interface\\Icons\\Achievement_Boss_RagnarosFirelands",
        color = { 1.0, 0.84, 0.0 },
    },
    MEMBER_JOIN = {
        icon  = "Interface\\Icons\\Ability_Warrior_RallyingCry",
        color = { 0.33, 1.0, 0.33 },
    },
    MEMBER_LEAVE = {
        icon  = "Interface\\Icons\\Ability_Rogue_FeignDeath",
        color = { 0.6, 0.6, 0.6 },
    },
    MEMBER_RANK_CHANGE = {
        icon  = "Interface\\Icons\\INV_Misc_GroupNeedMore",
        color = { 0.53, 0.81, 0.98 },
    },
    MEMBER_MAX_LEVEL = {
        icon  = "Interface\\Icons\\Achievement_Level_80",
        color = { 1.0, 0.96, 0.41 },
    },
    ACHIEVEMENT = {
        icon  = "Interface\\Icons\\Achievement_General",
        color = { 1.0, 0.78, 0.0 },
    },
    GUILD_ACHIEVEMENT = {
        icon  = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
        color = { 0.78, 0.61, 1.0 },
    },
    LOOT = {
        icon  = "Interface\\Icons\\INV_Misc_Bag_10",
        color = { 0.0, 0.8, 1.0 },
    },
    MILESTONE = {
        icon  = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention_Rank2",
        color = { 1.0, 0.5, 0.0 },
    },
    PLAYER_NOTE = {
        icon  = "Interface\\Icons\\INV_Misc_Note_01",
        color = { 0.9, 0.9, 0.9 },
    },
}

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

ns.FLUSH_INTERVAL = 5
ns.ROSTER_DEBOUNCE = 2
ns.ROSTER_SCAN_INTERVAL = 300
ns.ON_THIS_DAY_DELAY = 10
ns.ON_THIS_DAY_DISMISS = 30

ns.MAX_EVENTS_DEFAULT = 5000
ns.MAX_NOTE_LENGTH = 500

ns.MEMBER_COUNT_THRESHOLDS = { 10, 25, 50, 100, 150, 200, 300, 400, 500, 750, 1000 }
ns.KILL_COUNT_THRESHOLDS = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
ns.ACHIEVEMENT_POINT_THRESHOLDS = { 100, 250, 500, 1000, 2000, 3000, 5000, 7500, 10000 }

ns.GUILD_ACHIEVEMENT_FLAG = 0x4000

ns.LOOT_QUALITY = {
    UNCOMMON  = 2,
    RARE      = 3,
    EPIC      = 4,
    LEGENDARY = 5,
}

ns.DB_VERSION = 1

ns.DB_DEFAULTS = {
    global = {
        guilds = {},
        dbVersion = 0,
    },
    profile = {
        minimap = {
            hide = false,
        },
        tracking = {
            bossKills       = true,
            roster          = true,
            achievements    = true,
            loot            = true,
            lootQuality     = 4,
        },
        display = {
            showOnThisDay   = true,
        },
        data = {
            maxEvents       = 5000,
        },
        debug = false,
    },
    char = {
        lastOnThisDayDate = "",
    },
}

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
