local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local format = format
local ipairs = ipairs
local pairs = pairs
local tostring = tostring

local MilestoneDetector = addon:NewModule("MilestoneDetector", "AceEvent-3.0", "AceTimer-3.0")

local checkedThresholds = {}

function MilestoneDetector:ResetCaches()
    wipe(checkedThresholds)
end

function MilestoneDetector:OnEnable()
    addon:RegisterMessage("GH_EVENTS_UPDATED", function(_, _, count)
        if count and count > 0 then
            self:CheckMilestones()
        end
    end)

    self:ScheduleTimer("CheckAnniversaries", 30)
end

function MilestoneDetector:OnDisable()
    self:UnregisterAllEvents()
end

function MilestoneDetector:CheckMilestones()
    self:CheckMemberCountMilestones()
    self:CheckKillCountMilestones()
    self:CheckAchievementPointMilestones()
end

local function HasMilestone(events, milestoneType, threshold)
    for _, event in ipairs(events) do
        if event.type == ns.EVENT_TYPES.MILESTONE
           and event.milestoneType == milestoneType
           and event.thresholdValue == threshold then
            return true
        end
    end
    return false
end

function MilestoneDetector:CheckThresholdMilestone(currentValue, milestoneType, thresholds, titleKey, descTemplate)
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local now = GetServerTime()
    local cachePrefix = milestoneType .. ":"

    for _, threshold in ipairs(thresholds) do
        local cacheKey = cachePrefix .. threshold
        if currentValue >= threshold and not checkedThresholds[cacheKey] then
            checkedThresholds[cacheKey] = true

            if not HasMilestone(guildData.events, milestoneType, threshold) then
                Database:QueueEvent({
                    type = ns.EVENT_TYPES.MILESTONE,
                    timestamp = now,
                    title = format(L[titleKey], threshold),
                    description = format(descTemplate, threshold),
                    milestoneType = milestoneType,
                    thresholdValue = threshold,
                    key1 = milestoneType,
                    key2 = tostring(threshold),
                })
            end
        end
    end
end

function MilestoneDetector:CheckMemberCountMilestones()
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local memberCount = 0
    for _ in pairs(guildData.rosterSnapshot or {}) do
        memberCount = memberCount + 1
    end

    self:CheckThresholdMilestone(
        memberCount, "MEMBER_COUNT", ns.MEMBER_COUNT_THRESHOLDS,
        "MILESTONE_MEMBER_COUNT", "Guild membership reached %d members"
    )
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

    self:CheckThresholdMilestone(
        killCount, "KILL_COUNT", ns.KILL_COUNT_THRESHOLDS,
        "MILESTONE_KILL_COUNT", "Guild has recorded %d boss kills"
    )
end

function MilestoneDetector:CheckAchievementPointMilestones()
    local guildData = Database:GetGuildData()
    if not guildData then return end

    local totalPoints = 0
    for _, event in ipairs(guildData.events) do
        if (event.type == ns.EVENT_TYPES.ACHIEVEMENT or event.type == ns.EVENT_TYPES.GUILD_ACHIEVEMENT)
           and event.achievementPoints then
            totalPoints = totalPoints + event.achievementPoints
        end
    end

    self:CheckThresholdMilestone(
        totalPoints, "ACHIEVEMENT_POINTS", ns.ACHIEVEMENT_POINT_THRESHOLDS,
        "MILESTONE_ACHIEVEMENT_POINTS", "Guild members have earned %d total achievement points"
    )
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

                local alreadyRecorded = false
                for _, event in ipairs(guildData.events) do
                    if event.type == ns.EVENT_TYPES.MILESTONE and event.milestoneType == "ANNIVERSARY"
                       and event.playerName == name then
                        if Utils.TimestampToYear(event.timestamp) == currentYear then
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
