local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local ipairs = ipairs

local DetailPanel = {}
ns.DetailPanel = DetailPanel

local panel = nil
local currentEvent = nil

function DetailPanel:Init()
    if panel then return end

    panel = CreateFrame("Frame", "GuildHistorianDetailPanel", UIParent, "BackdropTemplate")
    panel:SetSize(380, 450)
    panel:SetPoint("CENTER", 200, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")

    Utils.ApplySharedBackdrop(panel, 0.95)

    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -14)
    panel.title:SetPoint("TOPRIGHT", -32, -14)
    panel.title:SetJustifyH("LEFT")

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(40, 40)
    panel.icon:SetPoint("TOPLEFT", 16, -44)

    panel.typeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.typeLabel:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 10, 0)
    panel.typeLabel:SetJustifyH("LEFT")

    panel.timestamp = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.timestamp:SetPoint("TOPLEFT", panel.icon, "BOTTOMRIGHT", 10, 8)
    panel.timestamp:SetTextColor(0.5, 0.5, 0.5)

    panel.description = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.description:SetPoint("TOPLEFT", 16, -100)
    panel.description:SetPoint("RIGHT", -16, 0)
    panel.description:SetJustifyH("LEFT")
    panel.description:SetWordWrap(true)
    panel.description:SetTextColor(0.9, 0.9, 0.9)

    panel.rosterFrame = CreateFrame("Frame", nil, panel)
    panel.rosterFrame:SetPoint("TOPLEFT", 16, -160)
    panel.rosterFrame:SetPoint("BOTTOMRIGHT", -16, 50)
    panel.rosterFrame:Hide()

    panel.rosterTitle = panel.rosterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.rosterTitle:SetPoint("TOPLEFT", 0, 0)
    panel.rosterTitle:SetText("Participants:")
    panel.rosterTitle:SetTextColor(0.78, 0.65, 0.35)

    panel.rosterText = panel.rosterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.rosterText:SetPoint("TOPLEFT", 0, -18)
    panel.rosterText:SetPoint("RIGHT", 0, 0)
    panel.rosterText:SetJustifyH("LEFT")
    panel.rosterText:SetWordWrap(true)

    panel.notesTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.notesTitle:SetPoint("BOTTOMLEFT", 16, 80)
    panel.notesTitle:SetText("Notes:")
    panel.notesTitle:SetTextColor(0.78, 0.65, 0.35)
    panel.notesTitle:Hide()

    panel.notesText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.notesText:SetPoint("TOPLEFT", panel.notesTitle, "BOTTOMLEFT", 0, -4)
    panel.notesText:SetPoint("RIGHT", -16, 0)
    panel.notesText:SetJustifyH("LEFT")
    panel.notesText:SetWordWrap(true)
    panel.notesText:Hide()

    panel.addNoteBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.addNoteBtn:SetSize(100, 24)
    panel.addNoteBtn:SetPoint("BOTTOMLEFT", 16, 14)
    panel.addNoteBtn:SetText(L["UI_ADD_NOTE"])
    panel.addNoteBtn:SetScript("OnClick", function()
        DetailPanel:PromptAddNote()
    end)

    panel:Hide()
    tinsert(UISpecialFrames, "GuildHistorianDetailPanel")
end

function DetailPanel:ShowEvent(event)
    if not panel then self:Init() end
    if not event then return end

    currentEvent = event

    local typeInfo = ns.EVENT_TYPE_INFO[event.type]

    panel.title:SetText(event.title or event.type)
    if typeInfo then
        panel.title:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
    end

    if typeInfo then
        panel.icon:SetTexture(typeInfo.icon)
    end

    local typeName = L[event.type] or event.type
    panel.typeLabel:SetText(typeName)
    if typeInfo then
        panel.typeLabel:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
    end

    local timeStr = Utils.TimestampToDisplay(event.timestamp)
    local relStr = Utils.RelativeTime(event.timestamp)
    panel.timestamp:SetText(timeStr .. " (" .. relStr .. ")")

    panel.description:SetText(event.description or "")

    if event.roster and #event.roster > 0 then
        local lines = {}
        for _, member in ipairs(event.roster) do
            local name = Utils.ClassColoredName(member.name, member.class)
            local role = member.role and (" - " .. member.role) or ""
            lines[#lines + 1] = "  " .. name .. role
        end
        panel.rosterText:SetText(table.concat(lines, "\n"))
        panel.rosterFrame:Show()
    else
        panel.rosterFrame:Hide()
    end

    if event.notes and #event.notes > 0 then
        local noteLines = {}
        for _, note in ipairs(event.notes) do
            noteLines[#noteLines + 1] = format("[%s] %s: %s",
                Utils.TimestampToDisplay(note.timestamp),
                note.author or "Unknown",
                note.text)
        end
        panel.notesText:SetText(table.concat(noteLines, "\n"))
        panel.notesTitle:Show()
        panel.notesText:Show()
    else
        panel.notesTitle:Hide()
        panel.notesText:Hide()
    end

    panel:Show()
end

StaticPopupDialogs["GUILDHISTORIAN_ADD_NOTE"] = {
    text = "Add a note to this event:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 300,
    maxLetters = ns.MAX_NOTE_LENGTH,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        if text and text ~= "" then
            local guildData = ns.Database:GetGuildData()
            if guildData then
                for i, event in ipairs(guildData.events) do
                    if event == currentEvent then
                        local NotesMod = ns.addon:GetModule("Notes")
                        if NotesMod then
                            NotesMod:AddNoteToEvent(i, text)
                            DetailPanel:ShowEvent(currentEvent)
                        end
                        break
                    end
                end
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function DetailPanel:PromptAddNote()
    if not currentEvent then return end
    StaticPopup_Show("GUILDHISTORIAN_ADD_NOTE")
end

function DetailPanel:Hide()
    if panel then panel:Hide() end
end
