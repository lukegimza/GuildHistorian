local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local LootTracker = addon:NewModule("LootTracker", "AceEvent-3.0")

-- Pattern to match loot messages
-- "PlayerName receives loot: [Item Link]x2."
-- "You receive loot: [Item Link]."
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

    -- Parse the loot message
    local playerName, itemLink = strmatch(msg, LOOT_PATTERN)
    if not playerName or not itemLink then return end

    -- Handle "You" as the local player
    if playerName == "You" then
        playerName = Utils.GetPlayerID()
    end

    -- Verify the player is a guild member
    if not self:IsGuildMember(playerName) then return end

    -- Get item info from the link
    local itemName, _, itemQuality = GetItemInfo(itemLink)
    if not itemQuality then return end

    -- Filter by quality threshold
    local minQuality = ns.addon.db.profile.tracking.lootQuality or ns.LOOT_QUALITY.EPIC
    if itemQuality < minQuality then return end

    local now = GetServerTime()

    Database:QueueEvent({
        type = ns.EVENT_TYPES.LOOT,
        timestamp = now,
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

--- Check if a player name is in the current guild roster
--- @param name string
--- @return boolean
function LootTracker:IsGuildMember(name)
    if not name then return false end

    local snapshot = Database:GetRosterSnapshot()
    if snapshot[name] then return true end

    -- Also check without realm suffix
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
