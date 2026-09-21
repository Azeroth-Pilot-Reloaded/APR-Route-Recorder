local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")
AprRC.CommandBar = AprRC:NewModule("CommandBar")
local Bar = AprRC.CommandBar
Bar.btnList = {}

local frame = CreateFrame("Frame", "CommandBarFrame", UIParent)
Bar.frame = frame
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(300)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
-- Only the icon hit areas receive mouse input; there is no header or panel.
local function iconButton(texture, label, callback)
    local button = CreateFrame("Button", nil, frame)
    button.label = label
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function(self) self.dragged = nil end)
    button:SetScript("OnDragStart", function(self)
        self.dragged = true
        frame:StartMoving()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        LibWindow.SavePosition(frame)
    end)
    button:SetScript("OnClick", function(self)
        if self.dragged then self.dragged = nil; return end
        callback(self)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.label, 1, 0.82, 0.4)
        if self.command then GameTooltip:AddLine("/aprrc " .. self.command, 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(L["Drag to move"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnHide", function(self)
        if self.dragged then frame:StopMovingOrSizing(); self.dragged = nil end
    end)
    return button
end

Bar.settingsButton = iconButton("Interface\\AddOns\\APR-Recorder\\assets\\icons\\settings", L["Bar settings"],
    function() AprRC.CommandBarSetting:Show(true) end)
Bar.nextButton = iconButton("Interface\\AddOns\\APR-Recorder\\assets\\ui\\next", L["Next"],
    function() Bar.page = (Bar.page or 1) + 1; Bar:UpdateFrame() end)
Bar.previousButton = iconButton("Interface\\AddOns\\APR-Recorder\\assets\\ui\\previous", L["Previous"],
    function() Bar.page = math.max(1, (Bar.page or 1) - 1); Bar:UpdateFrame() end)

function Bar:GetButtonSize()
    return math.max(16, math.min(64, math.floor(tonumber(AprRC.settings.profile.commandBarFrame.buttonSize) or 32)))
end

function Bar:SetButtonSize(size)
    AprRC.settings.profile.commandBarFrame.buttonSize = math.max(16, math.min(64, math.floor(tonumber(size) or 32)))
    self:RefreshFrameAnchor()
end

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

function Bar:UpdateFrame()
    local profile = AprRC.settings.profile.commandBarFrame
    local commands = self:GetCommands()
    local size = self:GetButtonSize()
    local gap = math.max(2, math.floor(size / 8))
    local requested = profile.rotation == "VERTICAL" and 1 or math.max(1, math.floor(tonumber(profile.buttonsPerRow) or 6))
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local maxColumns = math.max(1, math.floor((UIParent:GetWidth() / scale - 20 + gap) / (size + gap)))
    local maxRows = math.max(1, math.floor((UIParent:GetHeight() / scale - 20 + gap) / (size + gap)))
    local columns = math.max(1, math.min(requested, #commands + 1, maxColumns))
    local capacity = math.max(1, columns * maxRows - 1) -- reserve the settings icon
    if #commands > capacity then capacity = math.max(1, columns * maxRows - 3) end -- and page controls
    local pages = math.max(1, math.ceil(#commands / capacity))
    self.page = math.min(math.max(1, self.page or 1), pages)
    local first = (self.page - 1) * capacity + 1
    local count = math.max(0, math.min(capacity, #commands - first + 1))
    local function place(button, index)
        button:SetSize(size, size)
        button.icon:SetSize(size - 4, size - 4)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", ((index - 1) % columns) * (size + gap),
            -math.floor((index - 1) / columns) * (size + gap))
        button:Show()
    end
    for index = 1, count do
        local entry = commands[first + index - 1]
        local button = self.btnList[index]
        if not button then
            button = iconButton(nil, nil, function(self) Bar:Run(self.command) end)
            self.btnList[index] = button
        end
        button.command, button.label = entry.command, entry.label
        button.icon:SetTexture(entry.texture)
        place(button, index)
    end
    for index = count + 1, #self.btnList do self.btnList[index]:Hide() end
    place(self.settingsButton, count + 1)
    local total = count + 1
    if pages > 1 then
        place(self.previousButton, count + 2)
        place(self.nextButton, count + 3)
        total = total + 2
        if self.page < pages then self.nextButton:Enable() else self.nextButton:Disable() end
        if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
        self.nextButton.icon:SetAlpha(self.page < pages and 1 or 0.3)
        self.previousButton.icon:SetAlpha(self.page > 1 and 1 or 0.3)
    else self.nextButton:Hide(); self.previousButton:Hide() end
    frame:SetSize(math.min(columns, total) * (size + gap) - gap, math.ceil(total / columns) * (size + gap) - gap)
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
    profile.rotation, profile.enabled, profile.buttonSize, profile.buttonsPerRow = "HORIZONTAL", true, 32, 6
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
