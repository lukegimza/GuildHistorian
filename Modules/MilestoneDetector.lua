local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local MilestoneDetector = addon:NewModule("MilestoneDetector", "AceEvent-3.0", "AceTimer-3.0")

local checkedMemberThresholds = {}
local checkedKillThresholds = {}
-- Reserved for future achievement point milestone tracking
-- local checkedAchievementThresholds = {}

function MilestoneDetector:OnEnable()
    addon:RegisterMessage("GH_EVENTS_UPDATED", function(_, _, count)
        if count and count > 0 then
            self:CheckMilestones()
        end
    end)

    -- Check anniversaries once daily
    self:ScheduleTimer("CheckAnniversaries", 30)
end

function MilestoneDetector:OnDisable()
    self:UnregisterAllEvents()
end

function MilestoneDetector:CheckMilestones()
    self:CheckMemberCountMilestones()
    self:CheckKillCountMilestones()
end

function MilestoneDetector:CheckMemberCountMilestones()
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local snapshot = guildData.rosterSnapshot or {}
    local memberCount = 0
    for _ in pairs(snapshot) do
        memberCount = memberCount + 1
    end

    local now = GetServerTime()

    for _, threshold in ipairs(ns.MEMBER_COUNT_THRESHOLDS) do
        if memberCount >= threshold and not checkedMemberThresholds[threshold] then
            checkedMemberThresholds[threshold] = true

            -- Check if we already have this milestone recorded
            local alreadyRecorded = false
            for _, event in ipairs(guildData.events) do
                if event.type == ns.EVENT_TYPES.MILESTONE and event.milestoneType == "MEMBER_COUNT"
                   and event.thresholdValue == threshold then
                    alreadyRecorded = true
                    break
                end
            end

            if not alreadyRecorded then
                Database:QueueEvent({
                    type = ns.EVENT_TYPES.MILESTONE,
                    timestamp = now,
                    title = format(L["MILESTONE_MEMBER_COUNT"], threshold),
                    description = format("Guild membership reached %d members", threshold),
                    milestoneType = "MEMBER_COUNT",
                    thresholdValue = threshold,
                    key1 = "MEMBER_COUNT",
                    key2 = tostring(threshold),
                })
            end
        end
    end
end

function MilestoneDetector:CheckKillCountMilestones()
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local killCount = 0
    for _, event in ipairs(guildData.events) do
        if event.type == ns.EVENT_TYPES.BOSS_KILL or event.type == ns.EVENT_TYPES.FIRST_KILL then
            killCount = killCount + 1
        end
    end

    local now = GetServerTime()

    for _, threshold in ipairs(ns.KILL_COUNT_THRESHOLDS) do
        if killCount >= threshold and not checkedKillThresholds[threshold] then
            checkedKillThresholds[threshold] = true

            local alreadyRecorded = false
            for _, event in ipairs(guildData.events) do
                if event.type == ns.EVENT_TYPES.MILESTONE and event.milestoneType == "KILL_COUNT"
                   and event.thresholdValue == threshold then
                    alreadyRecorded = true
                    break
                end
            end

            if not alreadyRecorded then
                Database:QueueEvent({
                    type = ns.EVENT_TYPES.MILESTONE,
                    timestamp = now,
                    title = format(L["MILESTONE_KILL_COUNT"], threshold),
                    description = format("Guild has recorded %d boss kills", threshold),
                    milestoneType = "KILL_COUNT",
                    thresholdValue = threshold,
                    key1 = "KILL_COUNT",
                    key2 = tostring(threshold),
                })
            end
        end
    end
end

function MilestoneDetector:CheckAnniversaries()
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local now = GetServerTime()
    local currentMonth, currentDay = Utils.TimestampToMonthDay(now)
    local currentYear = Utils.TimestampToYear(now)

    for name, history in pairs(guildData.memberHistory) do
        if history.isActive and history.firstSeen then
            local joinMonth, joinDay = Utils.TimestampToMonthDay(history.firstSeen)
            local joinYear = Utils.TimestampToYear(history.firstSeen)

            if joinMonth == currentMonth and joinDay == currentDay and joinYear < currentYear then
                local years = currentYear - joinYear

                -- Check if already recorded this year
                local alreadyRecorded = false
                for _, event in ipairs(guildData.events) do
                    if event.type == ns.EVENT_TYPES.MILESTONE and event.milestoneType == "ANNIVERSARY"
                       and event.playerName == name then
                        local eventYear = Utils.TimestampToYear(event.timestamp)
                        if eventYear == currentYear then
                            alreadyRecorded = true
                            break
                        end
                    end
                end

                if not alreadyRecorded then
                    Database:QueueEvent({
                        type = ns.EVENT_TYPES.MILESTONE,
                        timestamp = now,
                        title = format(L["MILESTONE_ANNIVERSARY"], name, years),
                        description = format("%s has been in the guild for %d year(s)", name, years),
                        milestoneType = "ANNIVERSARY",
                        playerName = name,
                        thresholdValue = years,
                        key1 = "ANNIVERSARY",
                        key2 = name,
                        key3 = tostring(currentYear),
                    })
                end
            end
        end
    end
end
