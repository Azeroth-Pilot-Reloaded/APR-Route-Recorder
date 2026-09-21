local Recorder = AprRC.record
local button = Recorder.frame
local opens, resets = 0, 0
local oldShow, oldReset = AprRC.routeEditor.Show, AprRC.ResetRecordingSession
AprRC.routeEditor.Show = function() opens = opens + 1 end
AprRC.ResetRecordingSession = function() resets = resets + 1 end
local position = { point = "CENTER", x = 23, y = 45 }
AprRC.settings.profile.recordBarFrame.position = position
Recorder:OnInit()
assert(button:GetWidth() == 40 and button:GetHeight() == 40)
assert(button.windowConfig == position and button.restored)
assert(not button.indicator:IsShown())
button:GetScript("OnClick")(button)
assert(opens == 1 and not AprRC.settings.profile.recordBarFrame.isRecording)
button:GetScript("OnMouseDown")(button)
button:GetScript("OnDragStart")(button)
button:GetScript("OnDragStop")(button)
button:GetScript("OnClick")(button)
assert(opens == 1 and button.positionSaved, "Dragging should save position without opening the workshop")
button:GetScript("OnMouseDown")(button)
button:GetScript("OnClick")(button)
assert(opens == 2)
local before = resets
Recorder:RefreshFrameAnchor()
Recorder:RefreshFrameAnchor()
assert(resets == before, "Refreshing the launcher must not reset recording")
AprRC.settings.profile.recordBarFrame.isRecording = true
Recorder:UpdateRecordButton()
assert(button.indicator:IsShown() and not APR.settings.profile.enableAddon)
Recorder:StopRecord()
assert(not button.indicator:IsShown() and APR.settings.profile.enableAddon)
AprRC.settings.profile.enableAddon = false
Recorder:RefreshFrameAnchor()
assert(not button:IsShown())
AprRC.settings.profile.enableAddon = true
Recorder:RefreshFrameAnchor()
assert(button:IsShown())
AprRC.routeEditor.Show, AprRC.ResetRecordingSession = oldShow, oldReset
-- Integration refreshes can fail after the recording flag changes. Our own
-- bar and indicator must already match the new state, including on stop.
local oldToggle, oldQuestID = APR.settings.ToggleAddon, AprRC.questID
for _, dependency in ipairs({ "session", "APR", "questID" }) do
    local function fail() error("Simulated " .. dependency .. " refresh failure") end
    AprRC.ResetRecordingSession = dependency == "session" and fail or oldReset
    APR.settings.ToggleAddon = dependency == "APR" and fail or oldToggle
    AprRC.questID = dependency == "questID" and { RefreshVisibility = fail } or nil
    AprRC.settings.profile.recordBarFrame.isRecording = true
    local ok = pcall(Recorder.UpdateRecordButton, Recorder)
    assert(not ok)
    assert(AprRC.CommandBar.frame:IsShown() and button.indicator:IsShown(),
        "Recording controls stayed hidden after " .. dependency .. " failed")
    AprRC.settings.profile.recordBarFrame.isRecording = false
    ok = pcall(Recorder.UpdateRecordButton, Recorder)
    assert(not ok)
    assert(not AprRC.CommandBar.frame:IsShown() and not button.indicator:IsShown(),
        "Recording controls stayed visible after " .. dependency .. " failed")
end
AprRC.ResetRecordingSession, APR.settings.ToggleAddon, AprRC.questID = oldReset, oldToggle, oldQuestID
print("Recorder launcher click, drag, position and recording state checks passed.")
