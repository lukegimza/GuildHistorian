local GH, ns = ...

local Utils = ns.Utils
local Database = ns.Database
local addon = ns.addon

local ipairs = ipairs
local min = math.min

local OnThisDay = addon:NewModule("OnThisDay", "AceEvent-3.0", "AceTimer-3.0")

function OnThisDay:OnEnable()
    if not ns.addon.db.profile.display.showOnThisDay then return end
    self:ScheduleTimer("CheckOnThisDay", ns.ON_THIS_DAY_DELAY)
end

function OnThisDay:OnDisable()
    self:UnregisterAllEvents()
end

function OnThisDay:CheckOnThisDay()
    local today = Utils.TimestampToDate(GetServerTime())
    local charDB = ns.addon.db.char

    if charDB.lastOnThisDayDate == today then return end
    charDB.lastOnThisDayDate = today

    local events = self:GetOnThisDayEvents()
    if #events == 0 then return end

    local displayEvents = {}
    for i = 1, min(3, #events) do
        displayEvents[i] = events[i]
    end

    if ns.OnThisDayPopup then
        ns.OnThisDayPopup:ShowEvents(displayEvents)
    end
end

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

    table.sort(matches, function(a, b) return a.yearsAgo < b.yearsAgo end)

    return matches
end
