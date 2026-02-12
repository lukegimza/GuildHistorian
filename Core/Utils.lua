local GH, ns = ...

local Utils = {}
ns.Utils = Utils

--- djb2 hash function for deduplication keys
--- @param str string
--- @return number
function Utils.HashKey(str)
    local hash = 5381
    for i = 1, #str do
        hash = hash * 33 + string.byte(str, i)
        hash = hash % 2147483647  -- keep within 32-bit range
    end
    return hash
end

--- Build a deduplication key from event type + timestamp + key fields
--- @param eventType string
--- @param timestamp number
--- @param ... string Additional key fields
--- @return number
function Utils.BuildDedupKey(eventType, timestamp, ...)
    local parts = { eventType, tostring(timestamp) }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then
            parts[#parts + 1] = tostring(v)
        end
    end
    return Utils.HashKey(table.concat(parts, ":"))
end

--- Convert a timestamp to a display-friendly date string
--- @param timestamp number
--- @return string "YYYY-MM-DD HH:MM"
function Utils.TimestampToDisplay(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

--- Convert a timestamp to a date-only string
--- @param timestamp number
--- @return string "YYYY-MM-DD"
function Utils.TimestampToDate(timestamp)
    if not timestamp then return "Unknown" end
    return date("%Y-%m-%d", timestamp)
end

--- Convert a timestamp to month/day for On This Day
--- @param timestamp number
--- @return number, number month, day
function Utils.TimestampToMonthDay(timestamp)
    local d = date("*t", timestamp)
    return d.month, d.day
end

--- Get the year from a timestamp
--- @param timestamp number
--- @return number
function Utils.TimestampToYear(timestamp)
    local d = date("*t", timestamp)
    return d.year
end

--- Get a relative time string
--- @param timestamp number
--- @return string
function Utils.RelativeTime(timestamp)
    local now = GetServerTime()
    local diff = now - timestamp

    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local m = math.floor(diff / 60)
        return m .. (m == 1 and " minute ago" or " minutes ago")
    elseif diff < 86400 then
        local h = math.floor(diff / 3600)
        return h .. (h == 1 and " hour ago" or " hours ago")
    elseif diff < 604800 then
        local d = math.floor(diff / 86400)
        return d .. (d == 1 and " day ago" or " days ago")
    elseif diff < 2592000 then
        local w = math.floor(diff / 604800)
        return w .. (w == 1 and " week ago" or " weeks ago")
    elseif diff < 31536000 then
        local mo = math.floor(diff / 2592000)
        return mo .. (mo == 1 and " month ago" or " months ago")
    else
        local y = math.floor(diff / 31536000)
        return y .. (y == 1 and " year ago" or " years ago")
    end
end

--- Get the current player's identifier ("Name-Realm")
--- @return string|nil
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

--- Get the guild key ("GuildName-RealmName")
--- @return string|nil
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

--- Safe function call wrapper
--- @param func function
--- @param ... any
--- @return boolean, any
function Utils.safecall(func, ...)
    if type(func) ~= "function" then return false end
    return xpcall(func, geterrorhandler(), ...)
end

--- Format a class-colored name
--- @param name string
--- @param class string English class name (e.g. "WARRIOR")
--- @return string
function Utils.ClassColoredName(name, class)
    if not class or not RAID_CLASS_COLORS[class] then
        return name
    end
    local color = RAID_CLASS_COLORS[class]
    return format("|c%s%s|r", color.colorStr or "ffffffff", name)
end

--- Get the difficulty name for display
--- @param difficultyID number
--- @return string
function Utils.GetDifficultyName(difficultyID)
    if not difficultyID then return "Unknown" end
    if ns.DIFFICULTY_NAMES[difficultyID] then
        return ns.DIFFICULTY_NAMES[difficultyID]
    end
    local name = GetDifficultyInfo(difficultyID)
    return name or "Unknown"
end

--- Deep copy a table
--- @param orig table
--- @return table
function Utils.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

--- Truncate a string to max length with ellipsis
--- @param str string
--- @param maxLen number
--- @return string
function Utils.Truncate(str, maxLen)
    if not str then return "" end
    if #str <= maxLen then return str end
    return strsub(str, 1, maxLen - 3) .. "..."
end
