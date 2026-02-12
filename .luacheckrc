std = "lua51"
max_line_length = 120
codes = true
self = false

exclude_files = {
    "Libs/",
}

ignore = {
    "211/GH",       -- GH from `local GH, ns = ...` unused in most files
    "211/_.*",      -- unused variables starting with underscore
    "212/self",     -- unused self parameter
    "212/_.*",      -- unused arguments starting with underscore
    "213/_.*",      -- unused loop variables starting with underscore
    "432",          -- shadowing upvalue 'self' in callbacks is intentional
}

globals = {
    "GuildHistorian",
    "GuildHistorianDB",
    "GuildHistorianCharDB",
    "SlashCmdList",
    "SLASH_GUILDHISTORIAN1",
    "SLASH_GUILDHISTORIAN2",
    "StaticPopupDialogs",
    "hash_SlashCmdList",
    -- Created by XML templates
    "GuildHistorianMainFrame",
    "GuildHistorianOnThisDayPopup",
}

read_globals = {
    -- WoW API
    "GetLocale",
    "C_AddOns",
    "C_AchievementInfo",
    "C_ChatInfo",
    "C_ClassColor",
    "C_DateAndTime",
    "C_GuildInfo",
    "C_Map",
    "C_Timer",
    "CreateFrame",
    "CreateFromMixins",
    "CreateScrollBoxListLinearView",
    "CreateDataProvider",
    "DevTools_Dump",
    "GameTooltip",
    "GetAchievementInfo",
    "GetAchievementCriteriaInfo",
    "GetAddOnMetadata",
    "GetAutoCompleteRealms",
    "GetBuildInfo",
    "GetDifficultyInfo",
    "GetGuildInfo",
    "GetGuildRosterInfo",
    "GetInstanceInfo",
    "GetItemInfo",
    "GetNumGroupMembers",
    "GetNumGuildMembers",
    "GetRealZoneText",
    "GetRealmName",
    "GetServerTime",
    "GetTime",
    "GuildRoster",
    "InCombatLockdown",
    "IsInGuild",
    "IsInInstance",
    "IsInRaid",
    "IsInGroup",
    "ScrollUtil",
    "Settings",
    "UnitClass",
    "UnitFullName",
    "UnitGroupRolesAssigned",
    "UnitGUID",
    "UnitIsGroupLeader",
    "UnitName",
    "UnitLevel",
    "UIParent",
    "UISpecialFrames",
    "BackdropTemplateMixin",
    "StaticPopup_Show",
    "PlaySound",
    "SOUNDKIT",
    "date",
    "debugprofilestop",
    "format",
    "geterrorhandler",
    "hooksecurefunc",
    "issecurevariable",
    "strsplit",
    "strtrim",
    "strsub",
    "strlen",
    "strfind",
    "strmatch",
    "strlower",
    "strupper",
    "tinsert",
    "tremove",
    "tContains",
    "wipe",
    "time",
    "difftime",
    "bit",
    "max",
    "min",
    "floor",
    "ceil",
    "abs",
    "random",

    -- WoW Constants
    "MAX_PLAYER_LEVEL",
    "RAID_CLASS_COLORS",
    "ITEM_QUALITY_COLORS",
    "LE_ITEM_QUALITY_EPIC",
    "LE_ITEM_QUALITY_LEGENDARY",
    "LE_ITEM_QUALITY_RARE",
    "LE_ITEM_QUALITY_UNCOMMON",
    "Enum",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_ID",

    -- Lua standard
    "string",
    "table",
    "math",
    "pairs",
    "ipairs",
    "type",
    "tostring",
    "tonumber",
    "select",
    "unpack",
    "pcall",
    "xpcall",
    "error",
    "assert",
    "print",
    "rawget",
    "rawset",
    "setmetatable",
    "getmetatable",
    "next",
    "loadstring",
    "coroutine",

    -- Libraries
    "LibStub",
}
