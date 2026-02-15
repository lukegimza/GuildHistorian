--- Timeline entry row renderer.
-- Handles lazy creation of sub-elements (icon, title, subtitle, timestamp)
-- on pooled Button frames and populates them from a normalised event record.
-- Tombstones for your guild's achievements. R.I.P.
-- @module TimelineEntry

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local ipairs = ipairs

local TimelineEntry = {}
ns.TimelineEntry = TimelineEntry

--- Lazily create the icon, title, subtitle, timestamp, and highlight elements on a button.
-- Idempotent; does nothing if elements already exist.
---@param button Button The pooled timeline row frame
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
end

--- Populate a timeline row with data from a normalised event record.
-- Sets the icon, title colour, subtitle, timestamp, and hover tooltip.
---@param button Button The pooled timeline row frame (must have had EnsureElements called)
---@param event table Normalised event {type, title, description, timestamp, icon, color}
function TimelineEntry:Init(button, event)
    if not button or not event then return end

    self:EnsureElements(button)

    button.eventData = event

    if event.icon and button.Icon then
        button.Icon:SetTexture(event.icon)
        button.Icon:Show()
    end

    if button.Title then
        button.Title:SetText(event.title or "Unknown")
        if event.color then
            button.Title:SetTextColor(event.color[1], event.color[2], event.color[3])
        else
            button.Title:SetTextColor(1, 1, 1)
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

    button:SetScript("OnEnter", function(self)
        if self.Highlight then self.Highlight:SetAlpha(1) end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        if event.color then
            GameTooltip:AddLine(event.title or "Unknown", event.color[1], event.color[2], event.color[3])
        else
            GameTooltip:AddLine(event.title or "Unknown")
        end

        if event.description and event.description ~= "" then
            GameTooltip:AddLine(event.description, 1, 1, 1, true)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(Utils.TimestampToDisplay(event.timestamp), 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        if self.Highlight then self.Highlight:SetAlpha(0) end
        GameTooltip:Hide()
    end)
end
