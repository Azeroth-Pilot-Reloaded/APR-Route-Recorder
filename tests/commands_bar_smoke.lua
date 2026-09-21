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
assert(not Bar.btnList[1].text, "Legacy label preferences must not restore text on the icon bar")
assert(Bar.frame:GetWidth() == 68, "Two 32px icons and a 4px gap should have no panel padding")
-- Settings is the next grid item, including when the next item wraps a row.
local _, _, _, settingsX, settingsY = Bar.settingsButton:GetPoint()
local commandCount = #Bar:GetCommands()
assert(settingsX == (commandCount % 2) * 36 and settingsY == -math.floor(commandCount / 2) * 36)
-- Dragging an icon saves the bar position without executing the command.
dispatched = nil
firstButton:GetScript("OnMouseDown")(firstButton)
firstButton:GetScript("OnDragStart")(firstButton)
firstButton:GetScript("OnDragStop")(firstButton)
firstButton:GetScript("OnClick")(firstButton)
assert(not dispatched and Bar.frame.positionSaved)
firstButton:GetScript("OnMouseDown")(firstButton)
firstButton:GetScript("OnClick")(firstButton)
assert(dispatched == firstButton.command)
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
assert(Bar.settingsButton:IsShown() and Bar.frame:GetWidth() == 32 and Bar.frame:GetHeight() == 32)
Bar:ResetToDefault()
assert(#Bar:GetCommands() > 0)

-- The embedded size slider updates buttons and icons immediately and persists.
Settings:Show(true)
local function findSlider(widget)
    if widget.type == "Slider" then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = findSlider(child)
        if found then return found end
    end
end
local slider = assert(findSlider(Settings.panel))
for _, size in ipairs({ 16, 48, 64 }) do
    slider.slider:SetValue(size)
    assert(AprRC.settings.profile.commandBarFrame.buttonSize == size)
    assert(Bar.btnList[1]:GetWidth() == size and Bar.btnList[1].icon:GetWidth() == size - 4)
    assert(Bar.settingsButton:GetWidth() == size)
end
Settings:Show(false); Settings:Show(true)
assert(findSlider(Settings.panel):GetValue() == 64)

-- Pagination bounds the bar even with a large favorite list and vertical orientation.
AprRCData.CommandBarCommands = AprRC.options:GetToolbarCatalog()
AprRC.settings.profile.commandBarFrame.rotation = "VERTICAL"
Bar:UpdateFrame()
assert(Bar.frame:GetHeight() <= UIParent:GetHeight())
assert(Bar.frame:GetWidth() == 64, "A vertical bar must be exactly one icon wide")
assert(Bar.nextButton:IsShown())
Bar.nextButton:GetScript("OnClick")(Bar.nextButton)
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
