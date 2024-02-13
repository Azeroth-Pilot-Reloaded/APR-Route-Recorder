local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Route-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.record = AprRC:NewModule('Recorder')

local isRecording = false
local isPaused = false
local orientation = "HORIZONTAL"

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 100
---------------------------------------------------------------------------------------
--------------------------------- Recorder Frames -------------------------------------
---------------------------------------------------------------------------------------

local RecordBarFrame = CreateFrame("Frame", "RecordBarFrame", UIParent, "BackdropTemplate")
RecordBarFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
RecordBarFrame:SetFrameStrata("MEDIUM")
RecordBarFrame:SetClampedToScreen(true)

local function UpdateRecordButton(button)
    if isRecording then
        button.icon:SetTexture("Interface\\AddOns\\assets\\stop")
    else
        button.icon:SetTexture("Interface\\AddOns\\assets\\record")
    end
end

local function CreateButton(parent, iconPath, color)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(32, 32)
    btn:SetPoint("TOPLEFT", 0, 0)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexture(iconPath)
    btn.icon:SetVertexColor(unpack(color))
    return btn
end

local recordBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\assets\\record", AprRC.Color.red)
recordBtn:SetScript("OnClick", function()
    isRecording = not isRecording
    UpdateRecordButton(recordBtn)
end)

local pauseBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\assets\\pause", AprRC.Color.white)
pauseBtn:SetScript("OnClick", function()
    isPaused = not isPaused
end)

local updateBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\assets\\settings", AprRC.Color.white)
updateBtn:SetScript("OnClick", function()
    AprRC.settings:OpenSettings(AprRC.title)
end)

local orientationBtn = CreateButton(RecordBarFrame, "Interface\\AddOns\\assets\\rotation", AprRC.Color.white)
orientationBtn:SetScript("OnClick", function()
    orientation = orientation == "HORIZONTAL" and "VERTICAL" or "HORIZONTAL"
    AprRc.record:AdjustBarOrientation(RecordBarFrame)
end)
---------------------------------------------------------------------------------------
----------------------------- Function Recorder Frames --------------------------------
---------------------------------------------------------------------------------------


function AprRC.record:FrameOnInit()
    LibWindow.RegisterConfig(RecordBarFrame, APR.settings.profile.recordBarFrame)
    RecordBarFrame.RegisteredForLibWindow = true
    LibWindow.MakeDraggable(RecordBarFrame)
    RecordBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    self:RefreshPartyFrameAnchor()
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

function AprRc.record:AdjustBarOrientation(bar)
    local buttons = { recordBtn, pauseBtn, updateBtn, orientationBtn }
    local spacing = 10
    local offsetX, offsetY = 10, -10

    for i, btn in ipairs(buttons) do
        if bar.orientation == "HORIZONTAL" then
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetX = offsetX + btn:GetWidth() + spacing
        else -- VERTICAL
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetY = offsetY - btn:GetHeight() - spacing
        end
    end
    if bar.orientation == "HORIZONTAL" then
        bar:SetHeight(FRAME_HEIGHT)
        bar:SetWidth(FRAME_WIDTH + (#buttons - 1) * spacing)
    else
        bar:SetWidth(FRAME_HEIGHT)
        bar:SetHeight(FRAME_WIDTH + (#buttons - 1) * spacing)
    end
end
