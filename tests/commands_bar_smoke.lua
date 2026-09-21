local Bar, Settings, Editor = AprRC.CommandBar, AprRC.CommandBarSetting, AprRC.routeEditor
local dispatched
AprRC.command = { SlashCmd = function(_, command) dispatched = command end }
AprRC.settings.profile.recordBarFrame.isRecording = true
Bar:RefreshFrameAnchor()
assert(Bar.frame:IsShown() and #Bar.btnList > 0)
local firstButton = Bar.btnList[1]
firstButton:GetScript("OnClick")(firstButton)
assert(dispatched == AprRCData.CommandBarCommands[1].command)
local count = #Bar.btnList
for _ = 1, 5 do Bar:RefreshFrameAnchor() end
assert(count == #Bar.btnList and firstButton == Bar.btnList[1], "Refreshing must reuse native buttons")
AprRC.settings.profile.commandBarFrame.showLabels = true
AprRC.settings.profile.commandBarFrame.buttonsPerRow = 2
Bar:UpdateFrame()
assert(Bar.btnList[1].text:IsShown())
assert(Bar.frame:GetWidth() < 400)
Settings:Show()
assert(Editor.frame and Editor.tab == "commands" and Settings:IsVisible())
assert(Settings.available and Settings.selected and #Settings.runButtons > 0)
local command = Settings.runButtons[1]:GetUserData("command")
Settings.runButtons[1]:Fire("OnClick")
assert(dispatched == command)
local entry = AprRC.options:GetToolbarCatalog()[1]
local position = Settings:Find(entry.command)
Settings:ToggleFavorite(entry)
assert((Settings:Find(entry.command) ~= nil) == (position == nil))
Settings:ToggleFavorite(entry)
assert((Settings:Find(entry.command) ~= nil) == (position ~= nil))

-- Search includes unpinned commands without discarding focus or opening a settings frame.
Settings.search:SetText("bankdeposit")
Settings.search:Fire("OnTextChanged", "bankdeposit")
assert(#Settings.available.children == 1)
assert(Settings.available.children[1].entry.command == "bankdeposit")
assert(#Settings.selected.children == #Bar:GetCommands(), "Search must not hide selected commands")
local favoriteOrder = AprRC:CopyData(AprRCData.CommandBarCommands)
local second = favoriteOrder[2].command
Settings:Move(second, -1)
assert(AprRCData.CommandBarCommands[1].command == second)
Settings:Move(second, 1)
assert(AprRCData.CommandBarCommands[2].command == second)
AprRCData.CommandBarCommands = {}
Bar:UpdateFrame()
assert(#Bar:GetCommands() == 0 and not Bar.btnList[1]:IsShown(), "An intentionally empty bar must stay empty")
Settings:Show(false)
assert(#Bar:GetCommands() == 0)
Bar:ResetToDefault()
assert(#Bar:GetCommands() > 0)

-- Pagination bounds the bar even with a large favorite list and vertical orientation.
AprRCData.CommandBarCommands = AprRC.options:GetToolbarCatalog()
AprRC.settings.profile.commandBarFrame.rotation = "VERTICAL"
Bar:UpdateFrame()
assert(Bar.frame:GetHeight() <= UIParent:GetHeight())
assert(Bar.nextButton:IsShown())
Bar.nextButton:GetScript("OnClick")()
assert(Bar.page == 2)
AprRC.settings.profile.recordBarFrame.isRecording = false
Bar:RefreshFrameAnchor()
Editor:UpdateStatus()
assert(not Bar.frame:IsShown())
for _, button in ipairs(Settings.runButtons) do assert(button.disabled) end
assert(not Bar:Run("bankdeposit"))
Editor:Hide()
-- The settings module must not access pooled widgets after closing or switching tabs.
Settings:DrawResults()
Settings:RefreshRunState()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Integrated command search, favorites, ordering, button reuse and recording guards passed.")
