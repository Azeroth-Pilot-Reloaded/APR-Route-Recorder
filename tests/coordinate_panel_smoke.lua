local frame, aprFrame = assert(_G.AprRC_CoordinateScreenPanel), APR.coordinate.Frame
assert(frame ~= aprFrame and _G.CoordinateScreenPanel == aprFrame,
    "Loading the recorder must not replace APR's coordinate panel")
local profile = AprRC.settings.profile
local savedPosition = {point = "TOPRIGHT", x = -10, y = -20, scale = 1}
profile.coordinateFrame, profile.coordinateShow, profile.enableAddon = savedPosition, false, true
aprFrame:Show()
AprRC.coordinate:OnInit()
assert(frame.windowConfig == savedPosition and frame.draggable and frame.RegisteredForLibWindow,
    "The recorder keeps its saved position and drag configuration")
assert(not frame:IsShown() and aprFrame:IsShown(), "Disabling the recorder panel leaves APR's panel visible")
profile.coordinateShow = true
AprRC.coordinate:RefreshFrameAnchor()
assert(frame:IsShown() and frame.restored, "Reopening restores the recorder's saved position")
aprFrame:Hide()
assert(frame:IsShown(), "Hiding APR's panel leaves the recorder panel visible")

-- Methods retain their own frame even if another addon replaces the APR global later.
local lateAPRFrame = CreateFrame("Frame", "CoordinateScreenPanel", UIParent)
profile.enableAddon = false
AprRC.coordinate:RefreshFrameAnchor()
assert(not frame:IsShown() and lateAPRFrame:IsShown())
profile.enableAddon = true
AprRC.coordinate:RefreshFrameAnchor()
assert(frame:IsShown() and _G.CoordinateScreenPanel == lateAPRFrame)

local originalPosition, originalRound = UnitPosition, APR.coordinate.RoundCoords
local x, y, reads, formats, writes = 10, 20, 0, 0, 0
UnitPosition = function() reads = reads + 1; return y, x end
function APR.coordinate:RoundCoords(...)
    formats = formats + 1
    return originalRound(self, ...)
end
local setText = frame.Text.SetText
function frame.Text:SetText(text) writes = writes + 1; setText(self, text) end
local update = frame:GetScript("OnUpdate")
for _ = 1, 600 do update(frame, 1 / 60) end
assert(reads >= 49 and reads <= 50, "The recorder samples coordinates at 5 Hz")
assert(formats == 1 and writes == 1, "Idle coordinates call APR's formatter and update the label once")
x = 11
update(frame, 0.2)
assert(frame.Text:GetText() == "11.00, 20.00" and formats == 2 and writes == 2)
x = 11.001
update(frame, 0.2)
assert(writes == 2, "Movement below displayed precision cannot rewrite identical text")
x, y = nil, nil
update(frame, 0.2)
update(frame, 0.2)
assert(frame.Text:GetText() == "--------" and writes == 3, "Unavailable coordinates clear stale text once")
x, y = 11, 20
update(frame, 0.2)
assert(frame.Text:GetText() == "11.00, 20.00" and writes == 4)
update(frame, 3)
local afterStall = reads
for _ = 1, 6 do update(frame, 1 / 60) end
assert(reads <= afterStall + 1, "A stalled frame cannot trigger catch-up sampling on every frame")

local originalDialog = APR.questionDialog
local copied
APR.questionDialog = {CreateEditBoxPopup = function(_, _, _, text) copied = text end}
frame:GetScript("OnMouseDown")(frame, "RightButton")
assert(copied == frame.Text:GetText(), "Right-click still copies the recorder's coordinates")
APR.questionDialog = originalDialog
UnitPosition, APR.coordinate.RoundCoords = originalPosition, originalRound
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Recorder coordinates: independent frames/settings, saved position, 5 Hz sampling, idle cache and recovery passed.")
