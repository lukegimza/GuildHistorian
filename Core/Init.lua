--- Addon initialisation and lifecycle management.
-- Creates the AceAddon instance, registers saved variables, slash commands,
-- WoW events, and delegates to sub-modules on startup.
-- The summoning circle. 666 lines of startup bullshit.
-- @module Init

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local strlower = strlower

local addon = LibStub("AceAddon-3.0"):NewAddon(GH, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.addon = addon

--- Ace3 lifecycle hook: runs once when the addon object is created.
-- Initialises the saved variable database and registers slash commands.
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    self.version = C_AddOns.GetAddOnMetadata(GH, "Version") or "2.0.0"
    self:RegisterChatCommand("gh", "SlashCommand")
    self:RegisterChatCommand("guildhistorian", "SlashCommand")
end

--- Ace3 lifecycle hook: runs when the addon is enabled (login / reload).
-- Requests initial data from the server, registers events, and schedules
-- the On This Day popup check. The demon awakens.
function addon:OnEnable()
    if not IsInGuild() then
        self:DebugPrint(L["NOT_IN_GUILD"])
        return
    end

    self:Print(format(L["ADDON_LOADED"], self.version))

    C_GuildInfo.GuildRoster()
    if QueryGuildNews then QueryGuildNews() end
    if QueryGuildEventLog then QueryGuildEventLog() end

    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("GUILD_NEWS_UPDATE", "OnNewsUpdate")
    self:RegisterEvent("GUILD_EVENT_LOG_UPDATE", "OnEventLogUpdate")

    ns.MinimapButton:Init()
    ns.SettingsPanel:Init()

    self:ScheduleTimer("CheckOnThisDay", ns.ON_THIS_DAY_DELAY)
end

--- Handle GUILD_ROSTER_UPDATE by invalidating the roster cache and refreshing the dashboard.
function addon:OnRosterUpdate()
    if ns.RosterReader then ns.RosterReader:Invalidate() end
    if ns.Dashboard then ns.Dashboard:Refresh() end
end

--- Handle GUILD_NEWS_UPDATE by invalidating the news cache and refreshing the dashboard.
function addon:OnNewsUpdate()
    if ns.NewsReader then ns.NewsReader:Invalidate() end
    if ns.Dashboard then ns.Dashboard:Refresh() end
end

--- Handle GUILD_EVENT_LOG_UPDATE by invalidating the event log cache and refreshing the dashboard.
function addon:OnEventLogUpdate()
    if ns.EventLogReader then ns.EventLogReader:Invalidate() end
    if ns.Dashboard then ns.Dashboard:Refresh() end
end

--- Check whether there are On This Day achievements to display.
-- Runs once per calendar day, gated by the character-level saved variable.
function addon:CheckOnThisDay()
    if not self.db.profile.display.showOnThisDay then return end
    local today = date("%Y-%m-%d")
    if self.db.char.lastOnThisDayDate == today then return end
    self.db.char.lastOnThisDayDate = today
    if ns.OnThisDayPopup then
        ns.OnThisDayPopup:Show()
    end
end

--- Process slash command input (/gh, /guildhistorian).
---@param input string Raw command arguments
function addon:SlashCommand(input)
    local cmd = self:GetArgs(input, 1)
    cmd = cmd and strlower(cmd) or ""

    if cmd == "" or cmd == "toggle" then
        if ns.MainFrame then ns.MainFrame:Toggle() end
    elseif cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print(self.db.profile.debug and L["DEBUG_ENABLED"] or L["DEBUG_DISABLED"])
    elseif cmd == "config" or cmd == "settings" then
        Settings.OpenToCategory(ns.settingsCategoryID)
    else
        self:Print(L["SLASH_HELP"])
    end
end

--- Print a message to chat only when debug mode is enabled.
---@param ... any Values to print, passed through to AceConsole:Print
function addon:DebugPrint(...)
    if self.db and self.db.profile.debug then
        self:Print("|cff888888[Debug]|r", ...)
    end
end
