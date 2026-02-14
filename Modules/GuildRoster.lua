local GH, ns = ...

local L = ns.L
local Database = ns.Database
local addon = ns.addon

local format = format
local pairs = pairs
local tostring = tostring
local strmatch = strmatch

local GuildRoster = addon:NewModule("GuildRoster", "AceEvent-3.0", "AceTimer-3.0")

local debounceTimer = nil
local lastFullScan = 0

function GuildRoster:OnEnable()
    if not ns.addon.db.profile.tracking.roster then return end

    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")

    C_GuildInfo.GuildRoster()
end

function GuildRoster:OnDisable()
    self:UnregisterAllEvents()
    if debounceTimer then
        self:CancelTimer(debounceTimer)
        debounceTimer = nil
    end
end

function GuildRoster:OnGuildRosterUpdate()
    if debounceTimer then
        self:CancelTimer(debounceTimer)
    end
    debounceTimer = self:ScheduleTimer("DebouncedRosterScan", ns.ROSTER_DEBOUNCE)
end

function GuildRoster:DebouncedRosterScan()
    debounceTimer = nil

    local now = GetServerTime()
    if (now - lastFullScan) < ns.ROSTER_SCAN_INTERVAL then
        return
    end

    self:FullRosterScan()
end

function GuildRoster:FullRosterScan()
    if not IsInGuild() then return end

    lastFullScan = GetServerTime()
    local numMembers = GetNumGuildMembers()
    if numMembers == 0 then return end

    local newSnapshot = {}
    for i = 1, numMembers do
        local name, rankName, rankIndex, level, classDisplayName,
              _zone, _publicNote, _officerNote, _isOnline, _status,
              class = GetGuildRosterInfo(i)

        if name then
            newSnapshot[name] = {
                rank = rankName,
                rankIndex = rankIndex,
                level = level,
                class = class,
                classDisplayName = classDisplayName,
            }
        end
    end

    local oldSnapshot = Database:GetRosterSnapshot()

    if not next(oldSnapshot) then
        Database:SaveRosterSnapshot(newSnapshot)
        for name in pairs(newSnapshot) do
            Database:UpdateMemberHistory(name, "join")
        end
        return
    end

    local now = GetServerTime()

    for name, info in pairs(newSnapshot) do
        if not oldSnapshot[name] then
            Database:QueueEvent({
                type = ns.EVENT_TYPES.MEMBER_JOIN,
                timestamp = now,
                title = format(L["MEMBER_JOIN_DESC"], name),
                description = format("%s (%s, %s)", name, info.classDisplayName or "Unknown", info.rank or ""),
                playerName = name,
                key1 = name,
            })
            Database:UpdateMemberHistory(name, "join")
        else
            local oldInfo = oldSnapshot[name]

            if oldInfo.rankIndex ~= info.rankIndex then
                local oldRank = oldInfo.rank or "Unknown"
                local newRank = info.rank or "Unknown"
                Database:QueueEvent({
                    type = ns.EVENT_TYPES.MEMBER_RANK_CHANGE,
                    timestamp = now,
                    title = format(L["MEMBER_RANK_CHANGE_DESC"], name, oldRank, newRank),
                    description = format("%s rank changed from %s to %s", name, oldRank, newRank),
                    playerName = name,
                    key1 = name,
                    key2 = tostring(info.rankIndex),
                })
            end

            if info.level and oldInfo.level and info.level > oldInfo.level then
                local maxLevel = MAX_PLAYER_LEVEL or 80
                if info.level >= maxLevel and oldInfo.level < maxLevel then
                    Database:QueueEvent({
                        type = ns.EVENT_TYPES.MEMBER_MAX_LEVEL,
                        timestamp = now,
                        title = format(L["MEMBER_MAX_LEVEL_DESC"], name),
                        description = format("%s reached level %d", name, info.level),
                        playerName = name,
                        key1 = name,
                    })
                end
            end
        end
    end

    for name, info in pairs(oldSnapshot) do
        if not newSnapshot[name] then
            Database:QueueEvent({
                type = ns.EVENT_TYPES.MEMBER_LEAVE,
                timestamp = now,
                title = format(L["MEMBER_LEAVE_DESC"], name),
                description = format("%s (%s) left the guild", name, info.classDisplayName or "Unknown"),
                playerName = name,
                key1 = name,
            })
            Database:UpdateMemberHistory(name, "leave")
        end
    end

    Database:SaveRosterSnapshot(newSnapshot)
end

local JOIN_PATTERN = "(.+) has joined the guild."
local LEAVE_PATTERN = "(.+) has left the guild."
local REMOVE_PATTERN = "(.+) has been kicked .+"

function GuildRoster:OnSystemMessage(_, msg)
    if not msg then return end

    if strmatch(msg, JOIN_PATTERN) or strmatch(msg, LEAVE_PATTERN) or strmatch(msg, REMOVE_PATTERN) then
        C_GuildInfo.GuildRoster()
    end
end
