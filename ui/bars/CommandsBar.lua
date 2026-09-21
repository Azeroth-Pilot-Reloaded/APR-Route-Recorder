local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")
AprRC.CommandBar = AprRC:NewModule("CommandBar")
local Bar = AprRC.CommandBar
Bar.btnList = {}

local frame = CreateFrame("Frame", "CommandBarFrame", UIParent, "BackdropTemplate")
Bar.frame = frame
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(300)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
frame:SetBackdropColor(0.07, 0.055, 0.035, 0.96)
frame:SetBackdropBorderColor(0.72, 0.58, 0.34, 1)

local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", 5, -3)
header:SetPoint("TOPRIGHT", -85, -3)
header:SetHeight(24)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); LibWindow.SavePosition(frame) end)
header:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Drag the header to move the bar."], 1, 1, 1)
    GameTooltip:Show()
end)
header:SetScript("OnLeave", function() GameTooltip:Hide() end)
local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetAllPoints(header)
title:SetJustifyH("LEFT")
title:SetTextColor(0.93, 0.76, 0.42)
title:SetText(L["Commands"])

local function headerButton(text, offset, tooltip, callback)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(24, 22)
    button:SetPoint("TOPRIGHT", offset, -4)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end
Bar.settingsButton = headerButton("", -5, L["Bar settings"], function() AprRC.CommandBarSetting:Show(true) end)
local settingsIcon = Bar.settingsButton:CreateTexture(nil, "ARTWORK")
settingsIcon:SetSize(18, 18)
settingsIcon:SetPoint("CENTER")
settingsIcon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\icons\\settings")
Bar.nextButton = headerButton(">", -31, L["Next"], function() Bar.page = (Bar.page or 1) + 1; Bar:UpdateFrame() end)
Bar.previousButton = headerButton("<", -57, L["Previous"], function() Bar.page = math.max(1, (Bar.page or 1) - 1); Bar:UpdateFrame() end)

function Bar:GetCommands()
    if AprRCData.CommandBarCommands == nil then AprRCData.CommandBarCommands = AprRC.options:GetDefaultToolbarCommands() end
    AprRCData.CommandBarCommands = AprRC.options:NormalizeToolbarCommands(AprRCData.CommandBarCommands)
    return AprRCData.CommandBarCommands
end

function Bar:Run(command)
    local allowed, reason = AprRC.options:CanEdit(AprRCData.CurrentRoute)
    if not allowed then APR:PrintError(reason); return false end
    AprRC.command:SlashCmd(command)
    if AprRC.routeEditor then AprRC.routeEditor:UpdateStatus() end
    return true
end

local function commandButton()
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    button:SetBackdropColor(0.18, 0.15, 0.10, 1)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(26, 26)
    button.icon:SetPoint("LEFT", 3, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 34, 0)
    button.text:SetPoint("RIGHT", -4, 0)
    button.text:SetJustifyH("LEFT")
    button:SetScript("OnClick", function(self) Bar:Run(self.command) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.label, 1, 0.82, 0.4)
        GameTooltip:AddLine("/aprrc " .. self.command, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function Bar:UpdateFrame()
    local profile = AprRC.settings.profile.commandBarFrame
    local commands = self:GetCommands()
    local width = profile.showLabels and 156 or 32
    local requested = profile.rotation == "VERTICAL" and 1 or math.max(1, math.floor(tonumber(profile.buttonsPerRow) or 6))
    local columns = math.max(1, math.min(requested, math.max(1, #commands), math.floor((UIParent:GetWidth() - 20) / (width + 5))))
    local maxRows = math.max(1, math.floor((UIParent:GetHeight() - 80) / 37))
    local capacity = columns * maxRows
    local pages = math.max(1, math.ceil(#commands / capacity))
    self.page = math.min(math.max(1, self.page or 1), pages)
    local first = (self.page - 1) * capacity + 1
    local count = math.max(0, math.min(capacity, #commands - first + 1))
    for index = 1, count do
        local entry = commands[first + index - 1]
        local button = self.btnList[index]
        if not button then button = commandButton(); self.btnList[index] = button end
        button.command, button.label = entry.command, entry.label
        button.icon:SetTexture(entry.texture)
        button.text:SetText(entry.label)
        if profile.showLabels then button.text:Show() else button.text:Hide() end
        button:SetSize(width, 32)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 6 + ((index - 1) % columns) * (width + 5), -32 - math.floor((index - 1) / columns) * 37)
        button:Show()
    end
    for index = count + 1, #self.btnList do self.btnList[index]:Hide() end
    frame:SetSize(math.max(180, columns * (width + 5) + 7), 38 + math.ceil(count / columns) * 37)
    if pages > 1 then
        self.nextButton:Show(); self.previousButton:Show()
        if self.page < pages then self.nextButton:Enable() else self.nextButton:Disable() end
        if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    else self.nextButton:Hide(); self.previousButton:Hide() end
end

function Bar:OnInit()
    local profile = AprRC.settings.profile
    profile.commandBarFrame = profile.commandBarFrame or {}
    profile.commandBarFrame.position = profile.commandBarFrame.position or {}
    LibWindow.RegisterConfig(frame, profile.commandBarFrame.position)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
    if profile.commandBarFrame.position.point then LibWindow.RestorePosition(frame) end
    self:RefreshFrameAnchor()
end

function Bar:ResetToDefault()
    AprRCData.CommandBarCommands = AprRC.options:GetDefaultToolbarCommands()
    local profile = AprRC.settings.profile.commandBarFrame
    profile.rotation, profile.enabled, profile.showLabels, profile.buttonsPerRow = "HORIZONTAL", true, false, 6
    self.page = 1
    self:RefreshFrameAnchor()
end

function Bar:RefreshFrameAnchor()
    local profile = AprRC.settings.profile
    if not profile.enableAddon or not profile.recordBarFrame.isRecording or profile.commandBarFrame.enabled == false
        or (C_PetBattles and C_PetBattles.IsInBattle()) then frame:Hide(); return end
    self:UpdateFrame()
    local editor = AprRC.routeEditor
    if editor and editor.frame then frame:SetFrameLevel(editor.frame.frame:GetFrameLevel() + 200) end
    frame:Show()
    frame:Raise()
end

-- Retain the old entry point for integrations; geometry now uses a wrapping grid.
function Bar:AdjustBarRotation() self:UpdateFrame() end
