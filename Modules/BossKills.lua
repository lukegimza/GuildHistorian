local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local BossKills = addon:NewModule("BossKills", "AceEvent-3.0")

function BossKills:OnEnable()
    if not ns.addon.db.profile.tracking.bossKills then return end

    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("BOSS_KILL", "OnBossKill")
end

function BossKills:OnDisable()
    self:UnregisterAllEvents()
end

function BossKills:OnEncounterEnd(_, encounterID, encounterName, difficultyID, groupSize, success)
    -- Only record successful kills
    if success ~= 1 then return end
    self:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
end

function BossKills:OnBossKill(_, encounterID, encounterName)
    -- Fallback: BOSS_KILL doesn't provide difficulty/group info, get from instance
    if not encounterID then return end

    local _, _, difficultyID = GetInstanceInfo()
    local groupSize = GetNumGroupMembers()

    self:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
end

function BossKills:RecordBossKill(encounterID, encounterName, difficultyID, groupSize)
    if not encounterID or not encounterName then return end
    if not IsInGuild() then return end

    -- Must be in a group
    if not IsInRaid() and not IsInGroup() then return end

    local now = GetServerTime()
    local difficultyName = Utils.GetDifficultyName(difficultyID)
    local instanceName = GetInstanceInfo()

    -- Check for first kill
    local isFirstKill = Database:RecordFirstKill(encounterID, difficultyID)

    local eventType = isFirstKill and ns.EVENT_TYPES.FIRST_KILL or ns.EVENT_TYPES.BOSS_KILL
    local titleKey = isFirstKill and "FIRST_KILL_DESC" or "BOSS_KILL_DESC"

    -- Build roster of guild members in the group
    local roster = self:BuildGroupRoster()

    local event = {
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
        roster = roster,
        isFirstKill = isFirstKill,
        key1 = tostring(encounterID),
        key2 = tostring(difficultyID),
    }

    Database:QueueEvent(event)
end

--- Build a roster of guild members currently in the group
--- @return table
function BossKills:BuildGroupRoster()
    local roster = {}
    local numMembers = GetNumGroupMembers()

    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, numMembers do
        local unit = prefix .. i
        local name, realm = UnitName(unit)
        if name then
            if not realm or realm == "" then
                realm = GetRealmName()
            end
            if realm then
                realm = realm:gsub("%s+", "")
            end
            local fullName = name .. "-" .. (realm or "Unknown")
            local _, className = UnitClass(unit)
            local role = UnitGroupRolesAssigned(unit)

            roster[#roster + 1] = {
                name = fullName,
                class = className,
                role = role ~= "NONE" and role or nil,
            }
        end
    end

    return roster
end
