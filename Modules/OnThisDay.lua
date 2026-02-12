local GH, ns = ...

local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local OnThisDay = addon:NewModule("OnThisDay", "AceEvent-3.0", "AceTimer-3.0")

function OnThisDay:OnEnable()
    if not ns.addon.db.profile.display.showOnThisDay then return end

    -- Delay the check until after login settles
    self:ScheduleTimer("CheckOnThisDay", ns.ON_THIS_DAY_DELAY)
end

function OnThisDay:OnDisable()
    self:UnregisterAllEvents()
end

function OnThisDay:CheckOnThisDay()
    local today = Utils.TimestampToDate(GetServerTime())
    local charDB = ns.addon.db.char

    -- Only show once per day per character
    if charDB.lastOnThisDayDate == today then return end
    charDB.lastOnThisDayDate = today

    local events = self:GetOnThisDayEvents()
    if #events == 0 then return end

    -- Show popup with up to 3 events
    local displayEvents = {}
    for i = 1, math.min(3, #events) do
        displayEvents[i] = events[i]
    end

    if ns.OnThisDayPopup then
        ns.OnThisDayPopup:ShowEvents(displayEvents)
    end
end

--- Find events from this day in previous years
--- @return table
function OnThisDay:GetOnThisDayEvents()
    local now = GetServerTime()
    local currentMonth, currentDay = Utils.TimestampToMonthDay(now)
    local currentYear = Utils.TimestampToYear(now)

    local guildData = Database:GetGuildData()
    if not guildData then return {} end

    local matches = {}
    for _, event in ipairs(guildData.events) do
        local eventMonth, eventDay = Utils.TimestampToMonthDay(event.timestamp)
        local eventYear = Utils.TimestampToYear(event.timestamp)

        if eventMonth == currentMonth and eventDay == currentDay and eventYear < currentYear then
            matches[#matches + 1] = {
                event = event,
                yearsAgo = currentYear - eventYear,
            }
        end
    end

    -- Sort by most recent year first
    table.sort(matches, function(a, b) return a.yearsAgo < b.yearsAgo end)

    return matches
end
