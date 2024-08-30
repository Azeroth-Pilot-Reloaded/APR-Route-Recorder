local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.CommandBar = AprRC:NewModule('CommandBar')
AprRC.CommandBar.btnList = {}
AprRC.CommandBar.settingTutoFrameID = nil

local FRAME_WIDTH = 80
local FRAME_HEIGHT = 35

local defaultCommands = {
    { command = "waypoint",  label = "Waypoint",      texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Waypoint" },
    { command = "coord",     label = "Coord",         texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Coord" },
    { command = "range",     label = "Range",         texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Range" },
    { command = "noarrow",   label = "NoArrow",       texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\NoArrow" },
    { command = "text",      label = "ExtraLineText", texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\ExtraLineText" },
    { command = "btn",       label = "Button",        texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Button" },
    { command = "filler",    label = "Fillers",       texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Fillers" },
    { command = "qpartpart", label = "QpartPart",     texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\QpartPart" },
}

---------------------------------------------------------------------------------------
--------------------------------- CommandBar Frames -----------------------------------
---------------------------------------------------------------------------------------
local CommandBarFrame = CreateFrame("Frame", "CommandBarFrame", UIParent, "BackdropTemplate")
CommandBarFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
CommandBarFrame:SetFrameStrata("MEDIUM")
CommandBarFrame:SetClampedToScreen(true)
CommandBarFrame:SetBackdrop(AprRC.Backdrop.defaut)
CommandBarFrame:SetBackdropColor(unpack(AprRC.Backdrop.defaultBackdrop))


local function CreateButton(parent, texture, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", 0, 0)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexture(texture)
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(tooltipText, unpack(AprRC.Color.darkblue))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    btn:SetScript("OnClick", onClick)

    return btn
end

function AprRC.CommandBar:UpdateFrame()
    for _, child in ipairs({ CommandBarFrame:GetChildren() }) do
        child:Hide()
    end
    AprRC.CommandBar.btnList = {}

    -- Check if the commands are still the default commands
    AprRCData.CommandBarCommands = AprRCData.CommandBarCommands or defaultCommands

    for _, commandData in ipairs(AprRCData.CommandBarCommands) do
        local btn = CreateButton(CommandBarFrame, commandData.texture, commandData.label, function()
            AprRC.command:SlashCmd(commandData.command)
        end)
        tinsert(AprRC.CommandBar.btnList, btn)
    end

    -- Create ZoneDoneSave button
    local zoneDoneSaveBtn = CreateButton(CommandBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\ZoneDoneSave",
        "Add the last step (ZoneDoneSave) of the route so it can be marked as completed")
    zoneDoneSaveBtn:SetScript("OnClick", function()
        AprRC.command:SlashCmd('save')
    end)

    -- Create rotation button
    local rotationBtn = CreateButton(CommandBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\rotate", "Rotate",
        function()
            AprRC.settings.profile.commandBarFrame.rotation = AprRC.settings.profile.commandBarFrame.rotation ==
                "HORIZONTAL" and
                "VERTICAL" or "HORIZONTAL"
            AprRC.CommandBar:AdjustBarRotation(CommandBarFrame)
        end)

    -- Create settings button
    local settingsBtn = CreateButton(CommandBarFrame, "Interface\\AddOns\\APR-Recorder\\assets\\icons\\settings",
        "Commands Settings", function()
            AprRC.CommandBarSetting:Show()
            AprRC.settings.profile.commandBarFrame.tutorialShown = false
            AprRC.TutoFrame:HideCustomTutorialFrame(AprRC.CommandBar.settingTutoFrameID)
        end)

    tinsert(AprRC.CommandBar.btnList, zoneDoneSaveBtn)
    tinsert(AprRC.CommandBar.btnList, rotationBtn)
    tinsert(AprRC.CommandBar.btnList, settingsBtn)
    AprRC.CommandBar:AdjustBarRotation(CommandBarFrame)
    -- Show the tutorial if we are using the default commands
    if AprRC.settings.profile.commandBarFrame.tutorialShown then
        AprRC.CommandBar.settingTutoFrameID = AprRC.TutoFrame:ShowCustomTutorialFrame(
            "You can add more commands in the Commands Settings panel", TutorialPointerFrame.Direction.UP, settingsBtn)
    end
end

---------------------------------------------------------------------------------------
----------------------------- Function CommandBar Frames -----------------------------
---------------------------------------------------------------------------------------

function AprRC.CommandBar:OnInit()
    LibWindow.RegisterConfig(CommandBarFrame, AprRC.settings.profile.commandBarFrame.position)
    CommandBarFrame.RegisteredForLibWindow = true
    LibWindow.MakeDraggable(CommandBarFrame)
    LibWindow.RestorePosition(CommandBarFrame)
    CommandBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)


    self:RefreshFrameAnchor()
end

function AprRC.CommandBar:RefreshFrameAnchor()
    if not AprRC.settings.profile.enableAddon or not AprRC.settings.profile.recordBarFrame.isRecording or C_PetBattles.IsInBattle() then
        CommandBarFrame:Hide()
        AprRC.TutoFrame:HideCustomTutorialFrame(AprRC.CommandBar.settingTutoFrameID)
        return
    end
    CommandBarFrame:Show()
    CommandBarFrame:EnableMouse(true)
    LibWindow.RestorePosition(CommandBarFrame)
    self:UpdateFrame()
end

function AprRC.CommandBar:AdjustBarRotation(bar)
    local buttons = AprRC.CommandBar.btnList
    local spacing = 10
    local offsetX, offsetY = 5, -5
    local rotation = AprRC.settings.profile.commandBarFrame.rotation

    for i, btn in ipairs(buttons) do
        if rotation == "HORIZONTAL" then
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetX = offsetX + btn:GetWidth() + spacing
        else -- VERTICAL
            btn:SetPoint("TOPLEFT", offsetX, offsetY)
            offsetY = offsetY - btn:GetHeight() - spacing
        end
    end

    local totalButtonWidth = (#buttons * (buttons[1]:GetWidth() + spacing)) - spacing
    local totalButtonHeight = (#buttons * (buttons[1]:GetHeight() + spacing)) - spacing

    if rotation == "HORIZONTAL" then
        bar:SetHeight(FRAME_HEIGHT)
        bar:SetWidth(totalButtonWidth + 10)
    else
        bar:SetWidth(FRAME_HEIGHT)
        bar:SetHeight(totalButtonHeight + 10)
    end
end
