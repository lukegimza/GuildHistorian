local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local TimelineEntry = {}
ns.TimelineEntry = TimelineEntry

--- Initialize a timeline entry button from the template
--- @param button Frame The button frame from template
--- @param event table The event data
function TimelineEntry:Init(button, event)
    if not button or not event then return end

    -- Store event data on the button
    button.eventData = event

    -- Set icon
    local typeInfo = ns.EVENT_TYPE_INFO[event.type]
    if typeInfo and button.Icon then
        button.Icon:SetTexture(typeInfo.icon)
    end

    -- Set title with type-specific color
    if button.Title then
        local title = event.title or event.type
        button.Title:SetText(title)
        if typeInfo then
            button.Title:SetTextColor(typeInfo.color[1], typeInfo.color[2], typeInfo.color[3])
        end
    end

    -- Set subtitle
    if button.Subtitle then
        local subtitle = event.description or ""
        button.Subtitle:SetText(Utils.Truncate(subtitle, 80))
    end

    -- Set timestamp
    if button.Timestamp then
        button.Timestamp:SetText(Utils.RelativeTime(event.timestamp))
    end

    -- Set participant count for boss kills
    if button.Participants then
        if event.roster and #event.roster > 0 then
            button.Participants:SetText(format(L["UI_PARTICIPANTS"], #event.roster))
            button.Participants:Show()
        else
            button.Participants:Hide()
        end
    end

    -- Tooltip
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

    -- Click to open detail panel
    button:SetScript("OnClick", function(self)
        if ns.DetailPanel then
            ns.DetailPanel:ShowEvent(self.eventData)
        end
    end)
end
