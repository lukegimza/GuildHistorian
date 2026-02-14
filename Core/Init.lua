local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local strlower = strlower

local addon = LibStub("AceAddon-3.0"):NewAddon(GH, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    self.version = C_AddOns.GetAddOnMetadata(GH, "Version") or "2.0.0"
    self:RegisterChatCommand("gh", "SlashCommand")
    self:RegisterChatCommand("guildhistorian", "SlashCommand")
end

function addon:OnEnable()
    if not IsInGuild() then
        self:DebugPrint(L["NOT_IN_GUILD"])
        return
    end

    self:Print(format(L["ADDON_LOADED"], self.version))

    C_GuildInfo.GuildRoster()
    C_GuildInfo.QueryGuildNews()
    QueryGuildEventLog()

    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("GUILD_NEWS_UPDATE", "OnNewsUpdate")
    self:RegisterEvent("GUILD_EVENT_LOG_UPDATE", "OnEventLogUpdate")

    ns.MinimapButton:Init()
    ns.SettingsPanel:Init()

    self:ScheduleTimer("CheckOnThisDay", ns.ON_THIS_DAY_DELAY)
end

function addon:OnRosterUpdate()
    if ns.RosterReader then ns.RosterReader:Invalidate() end
    if ns.Dashboard then ns.Dashboard:Refresh() end
end

function addon:OnNewsUpdate()
    if ns.NewsReader then ns.NewsReader:Invalidate() end
    if ns.Dashboard then ns.Dashboard:Refresh() end
end

function addon:OnEventLogUpdate()
    if ns.EventLogReader then ns.EventLogReader:Invalidate() end
end

function addon:CheckOnThisDay()
    if not self.db.profile.display.showOnThisDay then return end
    local today = date("%Y-%m-%d")
    if self.db.char.lastOnThisDayDate == today then return end
    self.db.char.lastOnThisDayDate = today
    if ns.OnThisDayPopup then
        ns.OnThisDayPopup:Show()
    end
end

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

function addon:DebugPrint(...)
    if self.db and self.db.profile.debug then
        self:Print("|cff888888[Debug]|r", ...)
    end
end
