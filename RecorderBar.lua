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
RecordBarFrame:SetBackdrop({
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    tile = true,
    tileSize = 16
})
RecordBarFrame:SetBackdropColor(unpack(AprRC.Color.defaultBackdrop))

local function UpdateRecordButton(button)
    if AprRC.settings.profile.recordBarFrame.isRecording then
        button.icon:SetTexture("interface/buttons/ui-stopbutton")
    else
        button.icon:SetTexture("interface/timemanager/resetbutton")
    end
end

local function CreateButton(parent, iconPath, color)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", 0, 0)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexture(iconPath)
    btn.icon:SetVertexColor(unpack(color))

    btn:SetPushedTexture([[Interface\Buttons\heckbuttonglow]])
    btn:SetHighlightTexture([[Interface\Buttons\UI-Panel-MinimizeButton-Highlight]])
    btn:SetDisabledTexture([[Interface\Buttons\UI-Panel-QuestHideButton-disabled]])

    return btn
end

local recordBtn = CreateButton(RecordBarFrame, "interface/timemanager/resetbutton", AprRC.Color.red)
recordBtn:SetScript("OnClick", function()
    AprRC.settings.profile.recordBarFrame.isRecording = not AprRC.settings.profile.recordBarFrame.isRecording
    if AprRC.settings.profile.recordBarFrame.isRecording then
        APR.questionDialog:CreateQuestionPopup(
            "New Route?",
            function()
                AprRC.questionDialog:CreateEditBoxPopup("Route Name", function(text)
                    AprRC:InitRoute(text)
                    UpdateRecordButton(recordBtn)
                end)
            end,
            function()
                UpdateRecordButton(recordBtn)
            end,
            YES,
            NO,
            false
        )
    else
        UpdateRecordButton(recordBtn)
        AprRC:UpdateRoute()
    end
end)

local updateBtn = CreateButton(RecordBarFrame, "interface/buttons/ui-optionsbutton", AprRC.Color.white)
updateBtn:SetScript("OnClick", function()
    AprRC.settings:OpenSettings(AprRC.title)
end)

local rotationBtn = CreateButton(RecordBarFrame, "interface/buttons/ui-rotationleft-button-up",
    AprRC.Color.white)
rotationBtn:SetScript("OnClick", function()
    AprRC.settings.profile.recordBarFrame.rotation = AprRC.settings.profile.recordBarFrame.rotation == "HORIZONTAL" and
        "VERTICAL" or "HORIZONTAL"
    AprRC.record:AdjustBarRotation(RecordBarFrame)
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
    local buttons = { recordBtn, updateBtn, rotationBtn }
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
