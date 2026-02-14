local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database

local format = format
local strlower = strlower
local tostring = tostring

local addon = LibStub("AceAddon-3.0"):NewAddon(GH, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildHistorianDB", ns.DB_DEFAULTS, true)
    Database:Init(self.db)

    self.version = C_AddOns.GetAddOnMetadata(GH, "Version") or "1.0.0"

    self:RegisterChatCommand("gh", "SlashCommand")
    self:RegisterChatCommand("guildhistorian", "SlashCommand")

    self.flushTimer = self:ScheduleRepeatingTimer("FlushWriteQueue", ns.FLUSH_INTERVAL)
end

function addon:OnEnable()
    if not IsInGuild() then
        self:DebugPrint(L["NOT_IN_GUILD"])
        return
    end

    self:Print(format(L["ADDON_LOADED"], self.version))

    C_GuildInfo.GuildRoster()

    ns.MinimapButton:Init()
    ns.SettingsPanel:Init()
end

function addon:OnDisable()
    Database:Flush()
    if self.flushTimer then
        self:CancelTimer(self.flushTimer)
    end
end

function addon:FlushWriteQueue()
    Database:Flush()
end

local function SubmitNote(text)
    if not text or text == "" then
        addon:Print(L["NOTE_EMPTY"])
        return false
    end
    if #text > ns.MAX_NOTE_LENGTH then
        addon:Print(L["NOTE_TOO_LONG"])
        return false
    end
    local event = Utils.CreateNoteEvent(text, Utils.GetPlayerID())
    if Database:QueueEvent(event) then
        Database:Flush()
        addon:Print(L["NOTE_ADDED"])
        return true
    end
    return false
end

function addon:SlashCommand(input)
    local cmd, args = self:GetArgs(input, 2)
    cmd = cmd and strlower(cmd) or ""

    if cmd == "" or cmd == "toggle" then
        if ns.MainFrame then
            ns.MainFrame:Toggle()
        end
    elseif cmd == "note" then
        SubmitNote(args)
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
    else
        self:Print(L["SLASH_HELP"])
    end
end

function addon:DebugPrint(...)
    if self.db and self.db.profile.debug then
        self:Print("|cff888888[Debug]|r", ...)
    end
end

StaticPopupDialogs["GUILDHISTORIAN_QUICK_NOTE"] = {
    text = "Add a note to guild history:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 300,
    maxLetters = ns.MAX_NOTE_LENGTH,
    OnAccept = function(self)
        SubmitNote(self.editBox:GetText())
    end,
    OnShow = function(self)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local text = self:GetText()
        if text and text ~= "" then
            parent.button1:Click()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
