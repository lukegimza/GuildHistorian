--- Login popup showing guild achievements earned on today's date in past years.
-- Renders a draggable notification frame from OnThisDayPopup.xml,
-- auto-dismisses after a configurable timeout, and navigates to
-- the Timeline tab on click.
-- @module OnThisDayPopup

local GH, ns = ...

local L = ns.L
local Utils = ns.Utils

local format = format
local ipairs = ipairs
local max = math.max

local OnThisDayPopup = {}
ns.OnThisDayPopup = OnThisDayPopup

local popup = nil
local dismissTimer = nil

--- Initialise the popup frame from its XML template.
-- Applies the shared backdrop, wires up drag behaviour and the close button.
function OnThisDayPopup:Init()
    if popup then return end

    popup = GuildHistorianOnThisDayPopup
    if not popup then return end

    Utils.ApplySharedBackdrop(popup, 0.95)

    popup:RegisterForDrag("LeftButton")

    popup.Title:SetText(L["ON_THIS_DAY_TITLE"])
    popup.ClickHint:SetText(L["ON_THIS_DAY_CLICK"])

    popup:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            OnThisDayPopup:OnClick()
        end
    end)

    popup.CloseButton:SetScript("OnClick", function()
        OnThisDayPopup:Dismiss()
    end)
end

--- Show the popup if there are On This Day matches.
-- Populates the content text and starts the auto-dismiss timer.
function OnThisDayPopup:Show()
    if not popup then self:Init() end
    if not popup then return end

    local matches = ns.AchievementScanner and ns.AchievementScanner:GetOnThisDay() or {}
    if #matches == 0 then return end

    local lines = {}
    for _, match in ipairs(matches) do
        lines[#lines + 1] = format("|cffffd700%s|r", format(L["CARD_YEARS_AGO"], match.yearsAgo))
        lines[#lines + 1] = "Guild earned \"" .. (match.name or "Unknown") .. "\""
        lines[#lines + 1] = ""
    end

    popup.Content:SetText(table.concat(lines, "\n"))

    local contentHeight = popup.Content:GetStringHeight()
    popup:SetHeight(max(140, contentHeight + 80))

    popup:Show()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)

    if dismissTimer then
        dismissTimer:Cancel()
    end
    dismissTimer = C_Timer.NewTimer(ns.ON_THIS_DAY_DISMISS, function()
        OnThisDayPopup:Dismiss()
    end)
end

--- Handle a click on the popup: dismiss it and open the Timeline tab.
function OnThisDayPopup:OnClick()
    self:Dismiss()
    local now = GetServerTime()
    local month, day = Utils.TimestampToMonthDay(now)
    if ns.MainFrame then
        ns.MainFrame:SelectTab(2)
    end
end

--- Hide the popup and cancel the auto-dismiss timer.
function OnThisDayPopup:Dismiss()
    if popup then popup:Hide() end
    if dismissTimer then
        dismissTimer:Cancel()
        dismissTimer = nil
    end
end
