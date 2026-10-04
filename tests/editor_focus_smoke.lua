local E, Model, UI, GUI = AprRC.routeEditor, AprRC.editorModel, AprRC.editorUI, LibStub("AceGUI-3.0")
TestCloseWorkshop(); TestRunTimers()
local oldTime, oldFollow, oldAPRFollow = GetTime, E.follow, AprRC.settings.profile.followAPR
local oldRecording = AprRC.settings.profile.recordBarFrame.isRecording
local now = 0
GetTime = function() return now end
local route = assert(Model:NewRoute("Editor focus"))
for index = 1, 80 do route.steps[index] = { Note = "Step " .. index } end
AprRCData.CurrentRoute = route
AprRC.settings.profile.recordBarFrame.isRecording = false
AprRC.settings.profile.followAPR, E.follow = false, true
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E:SelectStep(3)
now = 100; E:Tick(true); TestRunTimers()
assert(E:SelectedStep() == 3, "Stopped capture must never move the selected step")
E.tabs:Fire("OnGroupSelected", "steps")
now = 200; E:Tick(true); TestRunTimers()
assert(E:SelectedStep() == 3, "Opening Steps must preserve selection while capture is stopped")
E:FollowRecordingStep()
assert(E:SelectedStep() == 3)

AprRC.settings.profile.recordBarFrame.isRecording = true
E:SelectStep(4)
now = 204; E:Tick(true)
assert(E:SelectedStep() == 4, "Forced refresh must still respect recent navigation")
now = 205; E:Tick()
assert(E:SelectedStep() == 80)
E:SelectStep(4)
now = 209
E.list.scrollframe:GetScript("OnMouseWheel")(E.list.scrollframe, -1)
now = 213; E:Tick(true)
assert(E:SelectedStep() == 4, "Mouse wheel navigation extends the idle delay")
now = 214; E:Tick()
assert(E:SelectedStep() == 80)
E:SelectStep(4); E.moveTo:SetFocus()
now = 230; E:Tick(true)
assert(E:SelectedStep() == 4, "Focused inputs block automatic capture follow")
E.moveTo:ClearFocus()
now = 234; E:Tick(true); assert(E:SelectedStep() == 4)
now = 235; E:Tick(); assert(E:SelectedStep() == 80)
E:SelectStep(4)
TestMouseDown, TestMouseOver = true, E.frame.frame
now = 250; E:Tick(true); assert(E:SelectedStep() == 4)
TestMouseDown, TestMouseOver = false, nil
now = 254; E:Tick(true); assert(E:SelectedStep() == 4)
now = 255; E:Tick(); assert(E:SelectedStep() == 80)

-- Stopping capture also cancels an already scheduled Lua follow callback.
E:SelectTab("lua"); TestRunTimers()
E:ScrollToLatest()
AprRC.settings.profile.recordBarFrame.isRecording = false
E.luaBox.editBox:SetCursorPosition(12)
E.luaBox.scrollFrame:SetVerticalScroll(30)
E:ScrollToLatest(); E:FollowRecordingStep(); E:Tick(true); TestRunTimers()
assert(E.luaBox.editBox:GetCursorPosition() == 12 and E.luaBox.scrollFrame:GetVerticalScroll() == 30)

-- Both status labels share the controls' vertical center, including longer
-- localized text. They never wrap onto another toolbar row.
E.frame:SetWidth(1120); E:UpdateStatus(); E.frame:DoLayout()
local header = E.recordStatus.parent
for _, widget in ipairs({ E.recordStatus, E.summary, E.recordButton, E.routeDropdown }) do
    local _, _, _, _, top = widget.frame:GetPoint(1)
    assert(math.abs(-top + widget.frame:GetHeight() / 2 - header.frame:GetHeight() / 2) < 0.1)
end
assert(header.frame:GetHeight() <= 32 and not E.recordStatus.label.wordWrap and not E.summary.label.wordWrap)
E.frame:SetWidth(440); E.frame:DoLayout()
assert(not E.recordStatus.frame:IsShown() and not E.summary.frame:IsShown())
E.frame:SetWidth(1120); E.frame:DoLayout()

-- A raised workshop owns both confirmation variants; pooling clears ownership.
E.frame.frame:SetFrameLevel(600)
E:Confirm("Confirm", function() end)
local confirmation = E.confirm
assert(confirmation.frame:GetParent() == E.frame.frame)
assert(confirmation.frame:GetFrameStrata() == E.frame.frame:GetFrameStrata())
assert(confirmation.frame:GetFrameLevel() > E.frame.frame:GetFrameLevel())
E.frame.frame:SetFrameLevel(900); confirmation:Show()
assert(confirmation.frame:GetFrameLevel() > 900)
confirmation:Hide()
local pooled = AprRC:CreateWidget("APRConfirmation")
assert(not pooled.owner and pooled.frame:GetParent() == UIParent)
GUI:Release(pooled)
E.luaBox:EditText('{ steps = {{ Note = "Changed" }} }', 0)
E:Hide()
assert(E.closeDialog and E.closeDialog.frame:GetParent() == E.frame.frame)
assert(E.closeDialog.frame:GetFrameLevel() > E.frame.frame:GetFrameLevel())
E.closeCancelButton:Fire("OnClick")
E.session:Reload(); TestCloseWorkshop(); TestRunTimers()
local container = AprRC:CreateWidget("SimpleGroup")
local label = UI.LabelWidget(container, "Ordinary label")
assert(label.label.wordWrap ~= false, "Compact status wrapping must not leak into pooled labels")
GUI:Release(container)
GetTime, E.follow, AprRC.settings.profile.followAPR = oldTime, oldFollow, oldAPRFollow
AprRC.settings.profile.recordBarFrame.isRecording = oldRecording
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Stopped capture, idle follow after navigation, focused editing, centered status and foreground confirmations passed.")
