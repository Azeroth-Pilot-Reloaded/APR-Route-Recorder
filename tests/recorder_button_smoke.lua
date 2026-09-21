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
print("Recorder launcher click, drag, position and recording state checks passed.")
