local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.record = AprRC:NewModule("Recorder")
local Recorder = AprRC.record

-- One persistent launcher. Recording controls live in the route workshop.
local button = CreateFrame("Button", "RecordBarFrame", UIParent, "BackdropTemplate")
Recorder.frame = button
button:SetSize(40, 40)
button:SetFrameStrata("MEDIUM")
button:SetClampedToScreen(true)
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
button:SetBackdropColor(0.07, 0.055, 0.035, 0.95)
button:SetBackdropBorderColor(0.72, 0.58, 0.34, 1)
button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetPoint("TOPLEFT", 5, -5)
button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
button.icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\logo")
button.indicator = button:CreateTexture(nil, "OVERLAY")
button.indicator:SetSize(8, 8)
button.indicator:SetPoint("TOPRIGHT", -3, -3)
button.indicator:SetColorTexture(1, 0.2, 0.2, 1)

button:SetScript("OnMouseDown", function(self) self.dragged = false end)
button:SetScript("OnDragStart", function(self)
    self.dragged = true
    self:StartMoving()
    GameTooltip:Hide()
end)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    LibWindow.SavePosition(self)
end)
button:SetScript("OnClick", function(self)
    if self.dragged then self.dragged = false; return end
    AprRC.routeEditor:Show()
end)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Open route workshop"], 1, 0.82, 0.4)
    GameTooltip:AddLine(L["Drag to move"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L[AprRC.settings.profile.recordBarFrame.isRecording and "Recording" or "Recording stopped"], 1, 1, 1)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function Recorder:OnInit()
    local profile = AprRC.settings.profile
    profile.recordBarFrame = profile.recordBarFrame or {}
    profile.recordBarFrame.position = profile.recordBarFrame.position or {}
    LibWindow.RegisterConfig(button, profile.recordBarFrame.position)
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if profile.recordBarFrame.position.point then LibWindow.RestorePosition(button) end
    self:UpdateRecordButton()
end

function Recorder:RefreshFrameAnchor()
    local active = AprRC.settings.profile.recordBarFrame.isRecording
    if active then button.indicator:Show() else button.indicator:Hide() end
    if not AprRC.settings.profile.enableAddon or (C_PetBattles and C_PetBattles.IsInBattle()) then
        button:Hide()
    else
        button:Show()
    end
    AprRC.CommandBar:RefreshFrameAnchor()
end

function Recorder:UpdateRecordButton()
    AprRC:ResetRecordingSession()
    APR.settings.profile.enableAddon = not AprRC.settings.profile.recordBarFrame.isRecording
    APR.settings:ToggleAddon()
    if AprRC.questID then AprRC.questID:RefreshVisibility() end
    self:RefreshFrameAnchor()
end

function Recorder:StopRecord()
    AprRC.settings.profile.recordBarFrame.isRecording = false
    self:UpdateRecordButton()
    AprRC:UpdateRoute()
end
