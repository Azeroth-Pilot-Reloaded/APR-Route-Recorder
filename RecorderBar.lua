local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.record = AprRC:NewModule('Recorder')

local isRecording = false
local isPaused = false
local orientation = "HORIZONTAL"

local FRAME_WIDTH = 105
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
    if isRecording then
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

    -- btn:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
    btn:SetPushedTexture([[Interface\Buttons\UI-Panel-QuestHideButton]])
    -- btn:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)
    btn:SetHighlightTexture([[Interface\Buttons\UI-Panel-MinimizeButton-Highlight]])
    btn:SetDisabledTexture([[Interface\Buttons\UI-Panel-QuestHideButton-disabled]])

    return btn
end

local recordBtn = CreateButton(RecordBarFrame, "interface/timemanager/resetbutton", AprRC.Color.red)
recordBtn:SetScript("OnClick", function()
    isRecording = not isRecording
    if not isRecording then
        isPaused = false
    end
    UpdateRecordButton(recordBtn)
end)

local pauseBtn = CreateButton(RecordBarFrame, "interface/timemanager/pausebutton", AprRC.Color.white)
pauseBtn:SetScript("OnClick", function()
    if isRecording then
        isPaused = not isPaused
    end
end)

local updateBtn = CreateButton(RecordBarFrame, "interface/buttons/ui-optionsbutton", AprRC.Color.white)
updateBtn:SetScript("OnClick", function()
    AprRC.settings:OpenSettings(AprRC.title)
end)

local orientationBtn = CreateButton(RecordBarFrame, "interface/buttons/ui-rotationleft-button-up",
    AprRC.Color.white)
orientationBtn:SetScript("OnClick", function()
    orientation = orientation == "HORIZONTAL" and "VERTICAL" or "HORIZONTAL"
    AprRC.record:AdjustBarOrientation(RecordBarFrame)
end)
---------------------------------------------------------------------------------------
----------------------------- Function Recorder Frames --------------------------------
---------------------------------------------------------------------------------------


function AprRC.record:OnInit()
    LibWindow.RegisterConfig(RecordBarFrame, AprRC.settings.profile.recordBarFrame)
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
    self:AdjustBarOrientation(RecordBarFrame)
    UpdateRecordButton(recordBtn)
    LibWindow.RestorePosition(RecordBarFrame)
    RecordBarFrame:Show()
end

function AprRC.record:AdjustBarOrientation(bar)
    local buttons = { recordBtn, pauseBtn, updateBtn, orientationBtn }
    local spacing = 10
    local offsetX, offsetY = 5, -5

    for i, btn in ipairs(buttons) do
        if orientation == "HORIZONTAL" then
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetX = offsetX + btn:GetWidth() + spacing
        else -- VERTICAL
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetY = offsetY - btn:GetHeight() - spacing
        end
    end
    if orientation == "HORIZONTAL" then
        bar:SetHeight(FRAME_HEIGHT)
        bar:SetWidth(FRAME_WIDTH + (#buttons - 1) * spacing)
    else
        bar:SetWidth(FRAME_HEIGHT)
        bar:SetHeight(FRAME_WIDTH + (#buttons - 1) * spacing)
    end
end
