local GH, ns = ...

local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local Notes = addon:NewModule("Notes", "AceEvent-3.0")

function Notes:OnEnable()
    -- Notes module is always active; slash command is handled in Init.lua
end

function Notes:OnDisable()
    -- Nothing to clean up
end

--- Add a note to an existing event
--- @param eventIndex number Index in the events array
--- @param noteText string
--- @return boolean
function Notes:AddNoteToEvent(eventIndex, noteText)
    if not noteText or noteText == "" then return false end
    if #noteText > ns.MAX_NOTE_LENGTH then return false end

    local guildData = Database:GetGuildData()
    if not guildData then return false end

    local event = guildData.events[eventIndex]
    if not event then return false end

    if not event.notes then
        event.notes = {}
    end

    event.notes[#event.notes + 1] = {
        text = noteText,
        author = Utils.GetPlayerID(),
        timestamp = GetServerTime(),
    }

    addon:SendMessage("GH_EVENTS_UPDATED", 0)
    return true
end
