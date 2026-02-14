local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local ipairs = ipairs

local TimelineEntry = {}
ns.TimelineEntry = TimelineEntry

function TimelineEntry:EnsureElements(button)
    if button._elementsCreated then return end
    button._elementsCreated = true

    button.Highlight = button:CreateTexture(nil, "BACKGROUND")
    button.Highlight:SetAllPoints()
    button.Highlight:SetColorTexture(1, 1, 1, 0.05)
    button.Highlight:SetAlpha(0)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(28, 28)
    button.Icon:SetPoint("LEFT", 8, 0)

    button.Title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Title:SetPoint("TOPLEFT", button.Icon, "TOPRIGHT", 8, 0)
    button.Title:SetPoint("RIGHT", button, "RIGHT", -100, 0)
    button.Title:SetJustifyH("LEFT")
    button.Title:SetWordWrap(false)

    button.Subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Subtitle:SetPoint("BOTTOMLEFT", button.Icon, "BOTTOMRIGHT", 8, 0)
    button.Subtitle:SetPoint("RIGHT", button, "RIGHT", -100, 0)
    button.Subtitle:SetJustifyH("LEFT")
    button.Subtitle:SetWordWrap(false)
    button.Subtitle:SetTextColor(0.7, 0.7, 0.7)

    button.Timestamp = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Timestamp:SetPoint("TOPRIGHT", -8, -4)
    button.Timestamp:SetJustifyH("RIGHT")
    button.Timestamp:SetTextColor(0.5, 0.5, 0.5)

    button.Participants = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Participants:SetPoint("BOTTOMRIGHT", -8, 4)
    button.Participants:SetJustifyH("RIGHT")
    button.Participants:SetTextColor(0.6, 0.6, 0.6)
end

function TimelineEntry:Init(button, event)
    if not button or not event then return end

    self:EnsureElements(button)

    button.eventData = event

    local typeInfo = ns.EVENT_TYPE_INFO[event.type]
    if typeInfo and button.Icon then
        button.Icon:SetTexture(typeInfo.icon)
        button.Icon:Show()
    end

    if button.Title then
        button.Title:SetText(event.title or event.type)
        if typeInfo then
            button.Title:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
        end
        button.Title:Show()
    end

    if button.Subtitle then
        button.Subtitle:SetText(Utils.Truncate(event.description or "", 80))
        button.Subtitle:Show()
    end

    if button.Timestamp then
        button.Timestamp:SetText(Utils.RelativeTime(event.timestamp))
        button.Timestamp:Show()
    end

    if button.Participants then
        if event.roster and #event.roster > 0 then
            button.Participants:SetText(format(L["UI_PARTICIPANTS"], #event.roster))
            button.Participants:Show()
        else
            button.Participants:Hide()
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.Highlight then self.Highlight:SetAlpha(1) end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        if typeInfo then
            GameTooltip:AddLine(event.title or event.type, typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
        else
            GameTooltip:AddLine(event.title or event.type)
        end

        if event.description then
            GameTooltip:AddLine(event.description, 1, 1, 1, true)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(Utils.TimestampToDisplay(event.timestamp), 0.5, 0.5, 0.5)

        if event.difficultyName then
            GameTooltip:AddLine("Difficulty: " .. event.difficultyName, 0.7, 0.7, 0.7)
        end

        if event.roster and #event.roster > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Participants:", 0.78, 0.65, 0.35)
            for _, member in ipairs(event.roster) do
                local name = Utils.ClassColoredName(member.name, member.class)
                local role = member.role and (" (" .. member.role .. ")") or ""
                GameTooltip:AddLine("  " .. name .. role, 1, 1, 1)
            end
        end

        if event.notes and #event.notes > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Notes:", 0.78, 0.65, 0.35)
            for _, note in ipairs(event.notes) do
                GameTooltip:AddLine("  " .. note.text, 0.8, 0.8, 0.8, true)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for details", 0.4, 0.4, 0.4)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        if self.Highlight then self.Highlight:SetAlpha(0) end
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        if ns.DetailPanel then
            ns.DetailPanel:ShowEvent(self.eventData)
        end
    end)
end
