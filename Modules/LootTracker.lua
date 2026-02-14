local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local format = format
local strmatch = strmatch
local pairs = pairs
local pcall = pcall

local LootTracker = addon:NewModule("LootTracker", "AceEvent-3.0")

local LOOT_PATTERN = "(.+) receives? loot: (.+)"

function LootTracker:OnEnable()
    if not ns.addon.db.profile.tracking.loot then return end
    self:RegisterEvent("CHAT_MSG_LOOT", "OnLootMessage")
end

function LootTracker:OnDisable()
    self:UnregisterAllEvents()
end

function LootTracker:OnLootMessage(_, msg)
    if not msg then return end
    if not IsInGuild() then return end

    local ok, err = pcall(self.ProcessLootMessage, self, msg)
    if not ok and ns.addon and ns.addon.db and ns.addon.db.profile.debug then
        ns.addon:DebugPrint("LootTracker error:", err)
    end
end

function LootTracker:ProcessLootMessage(msg)
    local playerName, itemLink = strmatch(msg, LOOT_PATTERN)
    if not playerName or not itemLink then return end

    if playerName == "You" then
        playerName = Utils.GetPlayerID()
    end

    if not self:IsGuildMember(playerName) then return end

    local itemName, _, itemQuality = GetItemInfo(itemLink)
    if not itemQuality then return end

    local minQuality = ns.addon.db.profile.tracking.lootQuality or ns.LOOT_QUALITY.EPIC
    if itemQuality < minQuality then return end

    Database:QueueEvent({
        type = ns.EVENT_TYPES.LOOT,
        timestamp = GetServerTime(),
        title = format(L["LOOT_DESC"], playerName or "Unknown", itemLink),
        description = itemLink,
        playerName = playerName,
        itemLink = itemLink,
        itemName = itemName,
        itemQuality = itemQuality,
        key1 = playerName,
        key2 = itemLink,
    })
end

function LootTracker:IsGuildMember(name)
    if not name then return false end

    local snapshot = Database:GetRosterSnapshot()
    if snapshot[name] then return true end

    local shortName = strmatch(name, "^([^-]+)")
    if shortName then
        for rosterName in pairs(snapshot) do
            if strmatch(rosterName, "^([^-]+)") == shortName then
                return true
            end
        end
    end

    return false
end
