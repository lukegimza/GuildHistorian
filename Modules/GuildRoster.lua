local GH, ns = ...

local L = ns.L
local Database = ns.Database
local addon = ns.addon

local GuildRoster = addon:NewModule("GuildRoster", "AceEvent-3.0", "AceTimer-3.0")

local debounceTimer = nil
local lastFullScan = 0

function GuildRoster:OnEnable()
    if not ns.addon.db.profile.tracking.roster then return end

    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")

    -- Request initial roster
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
    -- Debounce: wait for burst to settle
    if debounceTimer then
        self:CancelTimer(debounceTimer)
    end
    debounceTimer = self:ScheduleTimer("DebouncedRosterScan", ns.ROSTER_DEBOUNCE)
end

function GuildRoster:DebouncedRosterScan()
    debounceTimer = nil

    -- Throttle: don't do a full scan more than once per ROSTER_SCAN_INTERVAL
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

    local oldSnapshot, _ = Database:GetRosterSnapshot()

    -- First scan: just save the snapshot, don't generate events
    if not next(oldSnapshot) then
        Database:SaveRosterSnapshot(newSnapshot)
        -- Initialize member history for all current members
        for name in pairs(newSnapshot) do
            Database:UpdateMemberHistory(name, "join")
        end
        addon:DebugPrint("Initial roster snapshot saved with " .. numMembers .. " members.")
        return
    end

    -- Compare snapshots
    local now = GetServerTime()

    -- Check for new members (in new but not old)
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

            -- Check for rank changes
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

            -- Check for max level reached
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

    -- Check for departed members (in old but not new)
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

    -- Save updated snapshot
    Database:SaveRosterSnapshot(newSnapshot)
end

-- Detect join/leave from system messages as backup
local JOIN_PATTERN = "(.+) has joined the guild."
local LEAVE_PATTERN = "(.+) has left the guild."
local REMOVE_PATTERN = "(.+) has been kicked .+"

function GuildRoster:OnSystemMessage(_, msg)
    if not msg then return end

    local joined = strmatch(msg, JOIN_PATTERN)
    if joined then
        -- Schedule a roster update soon to get the details
        C_GuildInfo.GuildRoster()
        return
    end

    local left = strmatch(msg, LEAVE_PATTERN)
    if not left then
        left = strmatch(msg, REMOVE_PATTERN)
    end
    if left then
        C_GuildInfo.GuildRoster()
    end
end
