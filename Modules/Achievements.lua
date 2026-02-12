local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local Achievements = addon:NewModule("Achievements", "AceEvent-3.0")

function Achievements:OnEnable()
    if not ns.addon.db.profile.tracking.achievements then return end

    self:RegisterEvent("ACHIEVEMENT_EARNED", "OnAchievementEarned")
    self:RegisterEvent("GUILD_ACHIEVEMENT_EARNED", "OnGuildAchievementEarned")
    self:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT", "OnGuildAchievementChat")
end

function Achievements:OnDisable()
    self:UnregisterAllEvents()
end

function Achievements:OnAchievementEarned(_, achievementID)
    if not achievementID then return end
    if not IsInGuild() then return end

    local id, name, points, _, _, _, _, description, flags = GetAchievementInfo(achievementID)
    if not id then return end

    -- Check if this is a guild achievement via flags
    local isGuildAchievement = flags and bit.band(flags, ns.GUILD_ACHIEVEMENT_FLAG) > 0
    if isGuildAchievement then
        -- Will be handled by GUILD_ACHIEVEMENT_EARNED
        return
    end

    local playerID = Utils.GetPlayerID()
    local now = GetServerTime()

    Database:QueueEvent({
        type = ns.EVENT_TYPES.ACHIEVEMENT,
        timestamp = now,
        title = format(L["ACHIEVEMENT_DESC"], playerID or "Unknown", name),
        description = description or "",
        achievementID = achievementID,
        achievementName = name,
        achievementPoints = points,
        playerName = playerID,
        key1 = tostring(achievementID),
        key2 = playerID,
    })
end

function Achievements:OnGuildAchievementEarned(_, achievementID)
    if not achievementID then return end

    local id, name, points, _, _, _, _, description = GetAchievementInfo(achievementID)
    if not id then return end

    local now = GetServerTime()

    Database:QueueEvent({
        type = ns.EVENT_TYPES.GUILD_ACHIEVEMENT,
        timestamp = now,
        title = format(L["GUILD_ACHIEVEMENT_DESC"], name),
        description = description or "",
        achievementID = achievementID,
        achievementName = name,
        achievementPoints = points,
        key1 = tostring(achievementID),
    })
end

function Achievements:OnGuildAchievementChat(_, msg, playerName)
    -- Backup detection from chat messages
    -- This fires when another guild member earns an achievement
    if not msg or not playerName then return end
    if not IsInGuild() then return end

    -- Extract achievement from chat - the message is the achievement name
    -- This is a supplementary source; primary detection via events above
end
