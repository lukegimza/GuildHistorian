local GH, ns = ...

local L = ns.L

local OnThisDayPopup = {}
ns.OnThisDayPopup = OnThisDayPopup

local popup = nil
local dismissTimer = nil

function OnThisDayPopup:Init()
    if popup then return end

    popup = GuildHistorianOnThisDayPopup
    if not popup then return end

    -- Set backdrop
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    popup:SetBackdropBorderColor(0.78, 0.65, 0.35, 1)

    -- Make draggable
    popup:RegisterForDrag("LeftButton")

    -- Title
    popup.Title:SetText(L["ON_THIS_DAY_TITLE"])

    -- Click hint
    popup.ClickHint:SetText(L["ON_THIS_DAY_CLICK"])

    -- Click to open timeline
    popup:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            OnThisDayPopup:OnClick()
        end
    end)

    -- Close button dismisses
    popup.CloseButton:SetScript("OnClick", function()
        OnThisDayPopup:Dismiss()
    end)
end

function OnThisDayPopup:ShowEvents(events)
    if not popup then self:Init() end
    if not popup then return end
    if not events or #events == 0 then return end

    -- Build content text
    local lines = {}
    for _, entry in ipairs(events) do
        lines[#lines + 1] = format("|cffffd700%s|r", format(L["ON_THIS_DAY_YEARS_AGO"], entry.yearsAgo))
        lines[#lines + 1] = entry.event.title or entry.event.description or "Unknown event"
        lines[#lines + 1] = ""
    end

    popup.Content:SetText(table.concat(lines, "\n"))

    -- Adjust height based on content
    local contentHeight = popup.Content:GetStringHeight()
    popup:SetHeight(math.max(140, contentHeight + 80))

    popup:Show()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)

    -- Auto-dismiss timer
    if dismissTimer then
        dismissTimer:Cancel()
    end
    dismissTimer = C_Timer.NewTimer(ns.ON_THIS_DAY_DISMISS, function()
        OnThisDayPopup:Dismiss()
    end)
end

function OnThisDayPopup:OnClick()
    self:Dismiss()

    -- Open main frame with timeline
    if ns.MainFrame then
        ns.MainFrame:Show()
    end
end

function OnThisDayPopup:Dismiss()
    if popup then
        popup:Hide()
    end
    if dismissTimer then
        dismissTimer:Cancel()
        dismissTimer = nil
    end
end
