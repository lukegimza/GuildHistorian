--- General-purpose utility functions for GuildHistorian.
-- Provides time formatting, string helpers, class colouring,
-- and shared UI backdrop application.
-- @module Utils

local GH, ns = ...

local Utils = {}
ns.Utils = Utils

local format = format
local date = date
local strsub = strsub
local tostring = tostring
local floor = math.floor
local time = time

--- Format a Unix timestamp as "YYYY-MM-DD HH:MM".
---@param timestamp number Unix epoch seconds
---@return string formatted Formatted date-time string, or "Unknown" if nil
function Utils.TimestampToDisplay(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

--- Format a Unix timestamp as "YYYY-MM-DD".
---@param timestamp number Unix epoch seconds
---@return string formatted Date string, or "Unknown" if nil
function Utils.TimestampToDate(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d", timestamp)
end

--- Extract the month and day components from a Unix timestamp.
---@param timestamp number Unix epoch seconds
---@return number month Month (1-12)
---@return number day Day of month (1-31)
function Utils.TimestampToMonthDay(timestamp)
    local d = date("*t", timestamp)
    return d.month, d.day
end

--- Extract the year component from a Unix timestamp.
---@param timestamp number Unix epoch seconds
---@return number year Four-digit year
function Utils.TimestampToYear(timestamp)
    local d = date("*t", timestamp)
    return d.year
end

--- Convert a WoW achievement date (month, day, two-digit year) to a Unix timestamp.
-- WoW returns year as an offset from 2000 (e.g. 24 = 2024).
---@param month number Month (1-12)
---@param day number Day of month (1-31)
---@param year number Two-digit year offset from 2000
---@return number timestamp Unix epoch seconds, or 0 if any parameter is nil
function Utils.DateToTimestamp(month, day, year)
    if not month or not day or not year then return 0 end
    local realYear = year + 2000
    return time({ year = realYear, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

--- Convert a Unix timestamp to a human-readable relative time string.
-- Returns phrases like "just now", "5 minutes ago", "3 days ago", etc.
---@param timestamp number Unix epoch seconds
---@return string relative Relative time description
function Utils.RelativeTime(timestamp)
    if not timestamp or timestamp == 0 then return "Unknown" end
    local diff = GetServerTime() - timestamp

    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local m = floor(diff / 60)
        return m .. (m == 1 and " minute ago" or " minutes ago")
    elseif diff < 86400 then
        local h = floor(diff / 3600)
        return h .. (h == 1 and " hour ago" or " hours ago")
    elseif diff < 604800 then
        local d = floor(diff / 86400)
        return d .. (d == 1 and " day ago" or " days ago")
    elseif diff < 2592000 then
        local w = floor(diff / 604800)
        return w .. (w == 1 and " week ago" or " weeks ago")
    elseif diff < 31536000 then
        local mo = floor(diff / 2592000)
        return mo .. (mo == 1 and " month ago" or " months ago")
    else
        local y = floor(diff / 31536000)
        return y .. (y == 1 and " year ago" or " years ago")
    end
end

--- Format a large number with SI suffixes (K, M).
---@param n number The number to format
---@return string formatted Compact string representation (e.g. "1.5K", "2.3M")
function Utils.FormatNumber(n)
    if not n then return "0" end
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return format("%.1fK", n / 1000)
    end
    return tostring(n)
end

--- Wrap a player name in the WoW class colour escape sequence.
---@param name string Player name to colourise
---@param class string Uppercase English class token (e.g. "WARRIOR")
---@return string coloured Colour-escaped name, or plain name if class is unknown
function Utils.ClassColoredName(name, class)
    if not class or not RAID_CLASS_COLORS[class] then
        return name
    end
    local color = RAID_CLASS_COLORS[class]
    return format("|c%s%s|r", color.colorStr or "ffffffff", name)
end

--- Truncate a string to a maximum length, appending "..." if shortened.
---@param str string The string to truncate
---@param maxLen number Maximum allowed length including the ellipsis
---@return string result Truncated string
function Utils.Truncate(str, maxLen)
    if not str then return "" end
    if #str <= maxLen then return str end
    return strsub(str, 1, maxLen - 3) .. "..."
end

--- Apply the shared dark-gold backdrop to a BackdropTemplate frame.
---@param frame Frame A frame inheriting BackdropTemplate
---@param alpha number|nil Optional background alpha override (defaults to 0.92)
function Utils.ApplySharedBackdrop(frame, alpha)
    frame:SetBackdrop(ns.SHARED_BACKDROP)
    local bg = ns.SHARED_BACKDROP_COLOR
    frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha or bg[4])
    local border = ns.SHARED_BACKDROP_BORDER_COLOR
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end
