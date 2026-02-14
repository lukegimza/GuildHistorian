local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local format = format
local tostring = tostring
local pcall = pcall

local BossKills = addon:NewModule("BossKills", "AceEvent-3.0")

local recentKills = {}
local RECENT_KILL_WINDOW = 10

function BossKills:ResetRecentKills()
    wipe(recentKills)
end

function BossKills:OnEnable()
    if not ns.addon.db.profile.tracking.bossKills then return end

    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("BOSS_KILL", "OnBossKill")
end

function BossKills:OnDisable()
    self:UnregisterAllEvents()
end

function BossKills:OnEncounterEnd(_, encounterID, encounterName, difficultyID, groupSize, success)
    if success ~= 1 then return end
    self:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
end

function BossKills:OnBossKill(_, encounterID, encounterName)
    if not encounterID then return end

    local ok, _, _, difficultyID = pcall(GetInstanceInfo)
    if not ok then difficultyID = nil end
    local groupSize = GetNumGroupMembers()

    self:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
end

function BossKills:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
    if not encounterID or not encounterName then return end
    if not IsInGuild() then return end
    if not IsInRaid() and not IsInGroup() then return end

    local now = GetServerTime()

    local recentKey = tostring(encounterID)
    if recentKills[recentKey] and (now - recentKills[recentKey]) < RECENT_KILL_WINDOW then
        return
    end
    recentKills[recentKey] = now

    local difficultyName = Utils.GetDifficultyName(difficultyID)

    local iOk, instanceName = pcall(GetInstanceInfo)
    if not iOk then instanceName = nil end

    local isFirstKill = Database:RecordFirstKill(encounterID, difficultyID)
    local eventType = isFirstKill and ns.EVENT_TYPES.FIRST_KILL or ns.EVENT_TYPES.BOSS_KILL
    local titleKey = isFirstKill and "FIRST_KILL_DESC" or "BOSS_KILL_DESC"

    Database:QueueEvent({
        type = eventType,
        timestamp = now,
        title = format(L[titleKey], encounterName, instanceName or "Unknown", difficultyName),
        description = format("%s (%s) - %d players", encounterName, difficultyName, groupSize or 0),
        encounterID = encounterID,
        encounterName = encounterName,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        instanceName = instanceName,
        groupSize = groupSize,
        roster = self:BuildGroupRoster(),
        isFirstKill = isFirstKill,
        key1 = tostring(encounterID),
        key2 = tostring(difficultyID),
    })
end

function BossKills:BuildGroupRoster()
    local roster = {}
    local numMembers = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, numMembers do
        local unit = prefix .. i

        local ok, name, realm = pcall(UnitName, unit)
        if not ok then name = nil end

        if name then
            if not realm or realm == "" then
                realm = GetRealmName()
            end
            if realm then
                realm = realm:gsub("%s+", "")
            end
            local fullName = name .. "-" .. (realm or "Unknown")

            local cOk, _, className = pcall(UnitClass, unit)
            if not cOk then className = nil end

            local rOk, role = pcall(UnitGroupRolesAssigned, unit)
            if not rOk then role = "NONE" end

            roster[#roster + 1] = {
                name = fullName,
                class = className,
                role = role ~= "NONE" and role or nil,
            }
        end
    end

    return roster
end
