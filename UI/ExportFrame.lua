local GH, ns = ...

local L = ns.L
local Utils = ns.Utils
local Database = ns.Database

local ExportFrame = {}
ns.ExportFrame = ExportFrame

local frame = nil

function ExportFrame:Init()
    if frame then return end

    frame = CreateFrame("Frame", "GuildHistorianExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(550, 450)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.78, 0.65, 0.35, 1)

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L["UI_EXPORT_TITLE"])
    title:SetTextColor(0.78, 0.65, 0.35)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPLEFT", 16, -38)
    instructions:SetText(L["UI_EXPORT_INSTRUCTIONS"])
    instructions:SetTextColor(0.6, 0.6, 0.6)

    -- Scrollable EditBox
    local scrollFrame = CreateFrame("ScrollFrame", "GuildHistorianExportScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -58)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 14)

    local editBox = CreateFrame("EditBox", "GuildHistorianExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scrollFrame:SetScrollChild(editBox)

    frame.editBox = editBox
    frame.scrollFrame = scrollFrame

    frame:Hide()
    tinsert(UISpecialFrames, "GuildHistorianExportFrame")
end

function ExportFrame:Show()
    if not frame then self:Init() end

    local events = Database:GetEvents()
    if #events == 0 then
        if ns.addon then
            ns.addon:Print(L["EXPORT_NO_DATA"])
        end
        return
    end

    -- Build export text
    local lines = {}
    local guildKey = Utils.GetGuildKey() or "Unknown"

    lines[#lines + 1] = "=== Guild Historian Export ==="
    lines[#lines + 1] = format("Guild: %s", guildKey)
    lines[#lines + 1] = format("Exported: %s", Utils.TimestampToDisplay(GetServerTime()))
    lines[#lines + 1] = format("Total Events: %d", #events)
    lines[#lines + 1] = "=============================="
    lines[#lines + 1] = ""

    for _, event in ipairs(events) do
        local timestamp = Utils.TimestampToDisplay(event.timestamp)
        local typeName = L[event.type] or event.type
        local title = event.title or ""
        local desc = event.description or ""

        lines[#lines + 1] = format("[%s] [%s] %s", timestamp, typeName, title)
        if desc ~= "" and desc ~= title then
            lines[#lines + 1] = format("  %s", desc)
        end

        if event.roster and #event.roster > 0 then
            local names = {}
            for _, member in ipairs(event.roster) do
                names[#names + 1] = member.name
            end
            lines[#lines + 1] = format("  Participants: %s", table.concat(names, ", "))
        end

        if event.notes and #event.notes > 0 then
            for _, note in ipairs(event.notes) do
                lines[#lines + 1] = format("  Note (%s): %s", note.author or "Unknown", note.text)
            end
        end

        lines[#lines + 1] = ""
    end

    local exportText = table.concat(lines, "\n")

    frame.editBox:SetText(exportText)
    frame.editBox:SetWidth(frame.scrollFrame:GetWidth())
    frame:Show()

    -- Select all text for easy copy
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function ExportFrame:Hide()
    if frame then frame:Hide() end
end
