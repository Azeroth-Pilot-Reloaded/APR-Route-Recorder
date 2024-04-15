local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.commandsBar = AprRC:NewModule('CommandsBar')

-- Frame dimensions
local FRAME_WIDTH = 200
local FRAME_HEIGHT = 35
local BUTTON_SIZE = 24
local BUTTON_PADDING = 5

-- ---------------------------------------------------------------------------------------
-- --------------------------------- Command Frames --------------------------------------
-- ---------------------------------------------------------------------------------------

-- -- Create the frame for Command Bar
-- local CommandBarFrame = CreateFrame("Frame", "CommandBarFrame", UIParent, "BackdropTemplate")
-- CommandBarFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
-- CommandBarFrame:SetFrameStrata("MEDIUM")
-- CommandBarFrame:SetClampedToScreen(true)
-- CommandBarFrame:SetBackdrop(AprRC.Backdrop.defaut)
-- CommandBarFrame:SetBackdropColor(unpack(AprRC.Backdrop.defaultBackdrop))

-- -- Define buttons for each command
-- local commands = {
--     "achievement",
--     "button",
--     "class",
--     "donedb",
--     "eta",
--     "faction",
--     "fillers",
--     "gender",
--     "grind",
--     "noachievement",
--     "noarrow",
--     "pickupdb",
--     "qpartdb",
--     "race",
--     "range",
--     "spelltrigger",
--     "text",
--     "waypoint",
--     "zonetrigger",
-- }

-- local buttons = {}
-- for i, cmd in ipairs(commands) do
--     local btn = CreateFrame("Button", "APRCommandBarButton" .. i, CommandBarFrame, "UIPanelButtonTemplate")
--     btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
--     btn:SetPoint("TOPLEFT", 0, 0)
--     btn:SetText(cmd)
--     btn:SetScript("OnEnter", function(self)
--         GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
--         GameTooltip:AddLine(cmd, unpack(AprRC.Color.darkblue))
--         GameTooltip:Show()
--     end)
--     btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
--     btn:SetScript("OnClick", function()
--         AprRC.command:SlashCmd(cmd)
--     end)
--     table.insert(buttons, btn)
-- end

-- local rotationBtn = CreateButton(RecordBarFrame, "interface/buttons/ui-rotationleft-button-up",
--     AprRC.Color.white, "Rotate")
-- rotationBtn:SetScript("OnClick", function()
--     AprRC.settings.profile.recordBarFrame.rotation = AprRC.settings.profile.recordBarFrame.rotation == "HORIZONTAL" and
--         "VERTICAL" or "HORIZONTAL"
--     AprRC.record:AdjustBarRotation(RecordBarFrame)
-- end)


-- ---------------------------------------------------------------------------------------
-- ----------------------------- Function Command Frames ---------------------------------
-- ---------------------------------------------------------------------------------------
-- function AprRC.commandsBar:OnInit()
--     LibWindow.RegisterConfig(CommandBarFrame, AprRC.settings.profile.recordBarFrame.position)
--     RecordBarFrame.RegisteredForLibWindow = true
--     LibWindow.MakeDraggable(RecordBarFrame)
--     RecordBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

--     self:RefreshFrameAnchor()
-- end

-- function AprRC.commandsBar:RefreshFrameAnchor()
--     if not AprRC.settings.profile.enableAddon or C_PetBattles.IsInBattle() then
--         RecordBarFrame:Hide()
--         return
--     end
--     RecordBarFrame:EnableMouse(true)
--     self:AdjustBarRotation(RecordBarFrame)
--     UpdateRecordButton(recordBtn)
--     LibWindow.RestorePosition(RecordBarFrame)
--     RecordBarFrame:Show()
-- end


-- function AprRC.commandsBar:AdjustBarRotation(bar)
--     local buttons = { recordBtn, updateBtn, rotationBtn }
--     local spacing = 10
--     local offsetX, offsetY = 5, -5
--     local rotation = AprRC.settings.profile.recordBarFrame.rotation
--     for i, btn in ipairs(buttons) do
--         if rotation == "HORIZONTAL" then
--             btn:SetPoint("TOPLEFT", offsetX, offsetY)
--             offsetX = offsetX + btn:GetWidth() + spacing
--         else -- VERTICAL
--             btn:SetPoint("TOPLEFT", offsetX, offsetY)
--             offsetY = offsetY - btn:GetHeight() - spacing
--         end
--     end
--     if rotation == "HORIZONTAL" then
--         bar:SetHeight(FRAME_HEIGHT)
--         bar:SetWidth(FRAME_WIDTH + (#buttons - 1) * spacing)
--     else
--         bar:SetWidth(FRAME_HEIGHT)
--         bar:SetHeight(FRAME_WIDTH + (#buttons - 1) * spacing)
--     end
-- end

-- -- Function to update or hide buttons based on conditions
-- function AprRC.commandBar:UpdateButtons()
--     for i, btn in ipairs(buttons) do
--         btn:SetShown(AprRC.settings.profile.recordBarFrame.isRecording)
--     end
-- end
