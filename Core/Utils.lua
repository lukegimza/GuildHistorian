local GH, ns = ...

local Utils = {}
ns.Utils = Utils

local format = format
local date = date
local strlower = strlower
local strfind = strfind
local strsub = strsub
local strmatch = strmatch
local tostring = tostring
local type = type
local select = select
local sbyte = string.byte
local floor = math.floor
local min = math.min

function Utils.HashKey(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + sbyte(str, i)) % 2147483647
    end
    return hash
end

function Utils.BuildDedupKey(eventType, timestamp, ...)
    local key = eventType .. ":" .. tostring(timestamp)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then
            key = key .. ":" .. tostring(v)
        end
    end
    return Utils.HashKey(key)
end

function Utils.TimestampToDisplay(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

function Utils.TimestampToDate(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d", timestamp)
end

function Utils.TimestampToMonthDay(timestamp)
    local d = date("*t", timestamp)
    return d.month, d.day
end

function Utils.TimestampToYear(timestamp)
    local d = date("*t", timestamp)
    return d.year
end

function Utils.RelativeTime(timestamp)
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

function Utils.GetPlayerID()
    local name, realm = UnitFullName("player")
    if not name then return nil end
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    if realm then
        realm = realm:gsub("%s+", "")
    end
    return name .. "-" .. (realm or "Unknown")
end

function Utils.GetGuildKey()
    if not IsInGuild() then return nil end
    local guildName, _, _, guildRealm = GetGuildInfo("player")
    if not guildName then return nil end
    if not guildRealm or guildRealm == "" then
        guildRealm = GetRealmName()
    end
    if guildRealm then
        guildRealm = guildRealm:gsub("%s+", "")
    end
    return guildName .. "-" .. (guildRealm or "Unknown")
end

function Utils.safecall(func, ...)
    if type(func) ~= "function" then return false end
    return xpcall(func, geterrorhandler(), ...)
end

function Utils.ClassColoredName(name, class)
    if not class or not RAID_CLASS_COLORS[class] then
        return name
    end
    local color = RAID_CLASS_COLORS[class]
    return format("|c%s%s|r", color.colorStr or "ffffffff", name)
end

function Utils.GetDifficultyName(difficultyID)
    if not difficultyID then return "Unknown" end
    return ns.DIFFICULTY_NAMES[difficultyID] or GetDifficultyInfo(difficultyID) or "Unknown"
end

function Utils.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

function Utils.Truncate(str, maxLen)
    if not str then return "" end
    if #str <= maxLen then return str end
    return strsub(str, 1, maxLen - 3) .. "..."
end

function Utils.CreateNoteEvent(text, playerID)
    return {
        type = ns.EVENT_TYPES.PLAYER_NOTE,
        timestamp = GetServerTime(),
        title = "Note",
        description = text,
        playerName = playerID,
        key1 = playerID,
        key2 = tostring(GetServerTime()),
    }
end

function Utils.ApplySharedBackdrop(frame, alpha)
    frame:SetBackdrop(ns.SHARED_BACKDROP)
    local bg = ns.SHARED_BACKDROP_COLOR
    frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha or bg[4])
    local border = ns.SHARED_BACKDROP_BORDER_COLOR
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end
