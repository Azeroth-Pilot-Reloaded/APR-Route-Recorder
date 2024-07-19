local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.record = AprRC:NewModule('Recorder')

local FRAME_WIDTH = 80
local FRAME_HEIGHT = 35
---------------------------------------------------------------------------------------
--------------------------------- Recorder Frames -------------------------------------
---------------------------------------------------------------------------------------

local RecordBarFrame = CreateFrame("Frame", "RecordBarFrame", UIParent, "BackdropTemplate")
RecordBarFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
RecordBarFrame:SetFrameStrata("MEDIUM")
RecordBarFrame:SetClampedToScreen(true)
RecordBarFrame:SetBackdrop(AprRC.Backdrop.defaut)
RecordBarFrame:SetBackdropColor(unpack(AprRC.Backdrop.defaultBackdrop))

local function UpdateRecordButton(button)
    if AprRC.settings.profile.recordBarFrame.isRecording then
        button.icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\icons\\stop")
    else
        button.icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\icons\\rec")
    end
    AprRC.CommandBar:RefreshFrameAnchor()
end

local function CreateButton(parent, iconPath, message)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", 0, 0)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexture(iconPath)
    btn.icon:SetVertexColor(unpack(AprRC.Color.white))
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(message, unpack(AprRC.Color.darkblue))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn:SetDisabledTexture("Interface\\Buttons\\UI-Panel-QuestHideButton-disabled")

    return btn
end

local recordBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\rec", "Record/Stop")
recordBtn:SetScript("OnClick", function()
    AprRC.settings.profile.recordBarFrame.isRecording = not AprRC.settings.profile.recordBarFrame.isRecording
    if AprRC.settings.profile.recordBarFrame.isRecording then
        if not AprRC:IsTableEmpty(AprRCData.Routes) then
            APR.questionDialog:CreateQuestionPopup(
                "Continue route " .. AprRCData.CurrentRoute.name .. "?",
                function()
                    UpdateRecordButton(recordBtn)
                end,
                function()
                    AprRC.SelectRoute:Show()
                end,
                YES,
                NO,
                false
            )
        else
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Route Name", function(text)
                AprRC:InitRoute(text)
                UpdateRecordButton(recordBtn)
            end)
        end
    else
        AprRC.record:StopRecord()
    end
end)

local rotationBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\rotate", "Rotate")
rotationBtn:SetScript("OnClick", function()
    AprRC.settings.profile.recordBarFrame.rotation = AprRC.settings.profile.recordBarFrame.rotation == "HORIZONTAL" and
        "VERTICAL" or "HORIZONTAL"
    AprRC.record:AdjustBarRotation(RecordBarFrame)
end)

local settingsBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\settings", "Settings")
settingsBtn:SetScript("OnClick", function()
    AprRC.settings:OpenSettings(AprRC.title)
end)

---------------------------------------------------------------------------------------
----------------------------- Function Recorder Frames --------------------------------
---------------------------------------------------------------------------------------

function AprRC.record:OnInit()
    LibWindow.RegisterConfig(RecordBarFrame, AprRC.settings.profile.recordBarFrame.position)
    RecordBarFrame.RegisteredForLibWindow = true
    LibWindow.MakeDraggable(RecordBarFrame)
    RecordBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    self:RefreshFrameAnchor()
end

function AprRC.record:RefreshFrameAnchor()
    if not AprRC.settings.profile.enableAddon or C_PetBattles.IsInBattle() then
        RecordBarFrame:Hide()
        return
    end
    RecordBarFrame:EnableMouse(true)
    self:AdjustBarRotation(RecordBarFrame)
    UpdateRecordButton(recordBtn)
    LibWindow.RestorePosition(RecordBarFrame)
    RecordBarFrame:Show()
end

function AprRC.record:AdjustBarRotation(bar)
    local buttons = { recordBtn, rotationBtn, settingsBtn }
    local spacing = 10
    local offsetX, offsetY = 5, -5
    local rotation = AprRC.settings.profile.recordBarFrame.rotation
    for i, btn in ipairs(buttons) do
        if rotation == "HORIZONTAL" then
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetX = offsetX + btn:GetWidth() + spacing
        else -- VERTICAL
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetY = offsetY - btn:GetHeight() - spacing
        end
    end
    if rotation == "HORIZONTAL" then
        bar:SetHeight(FRAME_HEIGHT)
        bar:SetWidth(FRAME_WIDTH + (#buttons - 1) * spacing)
    else
        bar:SetWidth(FRAME_HEIGHT)
        bar:SetHeight(FRAME_WIDTH + (#buttons - 1) * spacing)
    end
end

function AprRC.record:StopRecord()
    UpdateRecordButton(recordBtn)
    AprRC:UpdateRoute()
end

function AprRC.record:UpdateRecordButton()
    UpdateRecordButton(recordBtn)
end
