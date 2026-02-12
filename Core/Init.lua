local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database

local addon = LibStub("AceAddon-3.0"):NewAddon(GH, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    Database:Init(self.db)

    -- Store version from TOC
    self.version = C_AddOns.GetAddOnMetadata(GH, "Version") or "1.0.0"

    -- Register slash commands
    self:RegisterChatCommand("gh", "SlashCommand")
    self:RegisterChatCommand("guildhistorian", "SlashCommand")

    -- Start flush timer
    self.flushTimer = self:ScheduleRepeatingTimer("FlushWriteQueue", ns.FLUSH_INTERVAL)
end

function addon:OnEnable()
    if not IsInGuild() then
        self:DebugPrint(L["NOT_IN_GUILD"])
        return
    end

    self:Print(format(L["ADDON_LOADED"], self.version))

    -- Request initial guild roster data
    C_GuildInfo.GuildRoster()
end

function addon:OnDisable()
    -- Final flush on disable
    Database:Flush()
    if self.flushTimer then
        self:CancelTimer(self.flushTimer)
    end
end

function addon:FlushWriteQueue()
    Database:Flush()
end

function addon:SlashCommand(input)
    local cmd, args = self:GetArgs(input, 2)
    cmd = cmd and strlower(cmd) or ""

    if cmd == "" or cmd == "toggle" then
        if ns.MainFrame then
            ns.MainFrame:Toggle()
        end
    elseif cmd == "note" then
        if not args or args == "" then
            self:Print(L["NOTE_EMPTY"])
            return
        end
        if #args > ns.MAX_NOTE_LENGTH then
            self:Print(L["NOTE_TOO_LONG"])
            return
        end
        local event = {
            type = ns.EVENT_TYPES.PLAYER_NOTE,
            timestamp = GetServerTime(),
            title = "Note",
            description = args,
            playerName = Utils.GetPlayerID(),
            key1 = Utils.GetPlayerID(),
            key2 = tostring(GetServerTime()),
        }
        if Database:QueueEvent(event) then
            Database:Flush()
            self:Print(L["NOTE_ADDED"])
        end
    elseif cmd == "search" then
        if not args or args == "" then
            self:Print("Usage: /gh search <text>")
            return
        end
        local results = Database:SearchEvents(args)
        if #results == 0 then
            self:Print(format(L["SEARCH_NO_RESULTS"], args))
        else
            self:Print(format(L["SEARCH_RESULTS"], #results, args))
            for i = 1, math.min(10, #results) do
                local e = results[i]
                self:Print(format("  %s - %s: %s",
                    Utils.TimestampToDisplay(e.timestamp),
                    e.type,
                    e.title or e.description or ""))
            end
        end
    elseif cmd == "stats" then
        local stats = Database:GetStats()
        self:Print("--- Guild Historian Statistics ---")
        self:Print(format("  %s: %d", L["STATS_TOTAL_EVENTS"], stats.totalEvents))
        self:Print(format("  %s: %d", L["STATS_FIRST_KILLS"], stats.firstKills))
        self:Print(format("  %s: %d (active: %d)", L["STATS_MEMBERS_TRACKED"],
            stats.membersTracked, stats.activeMembers))
        if stats.oldestEvent then
            self:Print(format("  " .. L["STATS_SINCE"], Utils.TimestampToDisplay(stats.oldestEvent)))
        end
    elseif cmd == "export" then
        if ns.ExportFrame then
            ns.ExportFrame:Show()
        end
    elseif cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print(self.db.profile.debug and L["DEBUG_ENABLED"] or L["DEBUG_DISABLED"])
    elseif cmd == "config" or cmd == "settings" then
        Settings.OpenToCategory(ns.settingsCategoryID)
    elseif cmd == "purge" then
        StaticPopup_Show("GUILDHISTORIAN_PURGE_CONFIRM")
    else
        self:Print(L["SLASH_HELP"])
    end
end

function addon:DebugPrint(...)
    if self.db and self.db.profile.debug then
        self:Print("|cff888888[Debug]|r", ...)
    end
end

-- Static popup for purge confirmation
StaticPopupDialogs["GUILDHISTORIAN_PURGE_CONFIRM"] = {
    text = "Are you sure you want to purge all Guild Historian data for this guild?\n\nType PURGE to confirm:",
    button1 = "Confirm",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        if text == "PURGE" then
            if Database:PurgeGuildData() then
                local guildKey = Utils.GetGuildKey() or "Unknown"
                ns.addon:Print(format(L["PURGE_SUCCESS"], guildKey))
            end
        else
            ns.addon:Print(L["PURGE_CANCELLED"])
        end
    end,
    OnShow = function(self)
        self.button1:Disable()
        self.editBox:SetText("")
    end,
    EditBoxOnTextChanged = function(self)
        local parent = self:GetParent()
        if self:GetText() == "PURGE" then
            parent.button1:Enable()
        else
            parent.button1:Disable()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
