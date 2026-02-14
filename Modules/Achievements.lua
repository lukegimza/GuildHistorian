local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local format = format
local tostring = tostring
local bit_band = bit.band

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

    if flags and bit_band(flags, ns.GUILD_ACHIEVEMENT_FLAG) > 0 then
        return
    end

    local playerID = Utils.GetPlayerID()

    Database:QueueEvent({
        type = ns.EVENT_TYPES.ACHIEVEMENT,
        timestamp = GetServerTime(),
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

    Database:QueueEvent({
        type = ns.EVENT_TYPES.GUILD_ACHIEVEMENT,
        timestamp = GetServerTime(),
        title = format(L["GUILD_ACHIEVEMENT_DESC"], name),
        description = description or "",
        achievementID = achievementID,
        achievementName = name,
        achievementPoints = points,
        key1 = tostring(achievementID),
    })
end

function Achievements:OnGuildAchievementChat(_, message, playerName, _, _, _, _, _, _, _, _, _, _, achievementID)
    if not playerName or not achievementID then return end
    if not IsInGuild() then return end

    local myID = Utils.GetPlayerID()
    local senderID = playerName
    if not senderID:find("-") then
        senderID = senderID .. "-" .. GetRealmName():gsub("%s+", "")
    end
    if senderID == myID then return end

    local id, name, points, _, _, _, _, description, flags = GetAchievementInfo(achievementID)
    if not id then return end

    if flags and bit_band(flags, ns.GUILD_ACHIEVEMENT_FLAG) > 0 then return end

    Database:QueueEvent({
        type = ns.EVENT_TYPES.ACHIEVEMENT,
        timestamp = GetServerTime(),
        title = format(L["ACHIEVEMENT_DESC"], senderID, name),
        description = description or "",
        achievementID = achievementID,
        achievementName = name,
        achievementPoints = points,
        playerName = senderID,
        key1 = tostring(achievementID),
        key2 = senderID,
    })
end
