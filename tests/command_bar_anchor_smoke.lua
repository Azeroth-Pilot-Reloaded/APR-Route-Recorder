local Bar, Settings, Editor = AprRC.CommandBar, AprRC.CommandBarSetting, AprRC.routeEditor
local profile = AprRC.settings.profile.commandBarFrame
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local function dropdown(widget, key)
    if widget.type == "Dropdown" and widget.label:GetText() == L[key] then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = dropdown(child, key)
        if found then return found end
    end
end
local function anchor(point, relative, relativePoint, x, y)
    local p, r, rp, px, py = Bar.frame:GetPoint()
    assert(p == point and r == relative and rp == relativePoint and px == x and py == y)
    assert(Bar.frame:GetNumPoints() == 1)
end
Bar:ResetToDefault()
AprRC.settings.profile.recordBarFrame.isRecording = true
Settings:Show(true)
local orientation = assert(dropdown(Settings.panel, "Orientation"))
local count = assert(dropdown(Settings.panel, "Buttons per row"))
count:Fire("OnValueChanged", 2)
orientation:Fire("OnValueChanged", "VERTICAL")
assert(count.label:GetText() == L["Buttons per column"])
local _, _, _, x, y = Bar.btnList[3]:GetPoint()
assert(x == 36 and y == 0)
assert(Bar.frame:GetHeight() == 68)
local total = #Bar:GetCommands() + 1
local _, _, _, sx, sy = Bar.settingsButton:GetPoint()
assert(sx == math.floor((total - 1) / 2) * 36 and sy == -((total - 1) % 2) * 36)
orientation:Fire("OnValueChanged", "HORIZONTAL")
assert(count.label:GetText() == L["Buttons per row"])
assert(Bar.frame:GetWidth() == 68)

local snap = assert(dropdown(Settings.panel, "Snap to route workshop"))
local expected = {
    LEFT = { "RIGHT", "LEFT", -6, 0 }, RIGHT = { "LEFT", "RIGHT", 6, 0 },
    TOP = { "BOTTOM", "TOP", 0, 6 }, BOTTOM = { "TOP", "BOTTOM", 0, -6 },
}
local workshop = Editor.frame.frame
local position = AprRC:CopyData(profile.position)
for side, points in pairs(expected) do
    snap:Fire("OnValueChanged", side)
    assert(profile.snap == side and Bar.snappedTo == workshop)
    anchor(points[1], workshop, points[2], points[3], points[4])
    assert(Bar.frame:GetParent() == UIParent, "Snapping must not reparent the bar")
end
snap:Fire("OnValueChanged", "NONE")
anchor("CENTER", UIParent, "CENTER", 0, -80)
snap:Fire("OnValueChanged", "RIGHT")
Editor:ToggleCompact()
anchor("LEFT", workshop, "RIGHT", 6, 0)
Editor:ToggleCompact()
anchor("LEFT", workshop, "RIGHT", 6, 0)
Editor:Hide()
assert(not Bar.snappedTo and Bar.frame:IsShown())
assert(profile.snap == "RIGHT", "Closing must preserve the snap preference")
anchor("CENTER", UIParent, "CENTER", 0, -80)
for key, value in pairs(position) do assert(profile.position[key] == value) end

-- The released AceGUI frame can belong to another window without moving the bar.
local other = AprRC:CreateWidget("Frame")
anchor("CENTER", UIParent, "CENTER", 0, -80)
Settings:Show(true)
assert(Bar.snappedTo == Editor.frame.frame and Bar.snappedTo ~= other.frame)
anchor("LEFT", Editor.frame.frame, "RIGHT", 6, 0)
assert(dropdown(Settings.panel, "Snap to route workshop"):GetValue() == "RIGHT")
LibStub("AceGUI-3.0"):Release(other)

-- Free movement with the workshop closed must retain each configured snap side.
for side, points in pairs(expected) do
    dropdown(Settings.panel, "Snap to route workshop"):Fire("OnValueChanged", side)
    Editor:Hide()
    assert(not Bar.snappedTo and profile.snap == side)
    local freeButton = Bar.btnList[1]
    freeButton:GetScript("OnMouseDown")(freeButton)
    freeButton:GetScript("OnDragStart")(freeButton)
    freeButton:GetScript("OnDragStop")(freeButton)
    assert(profile.snap == side, "Moving the closed workshop's free bar must preserve snapping")
    AprRC.CommandBar:RefreshFrameAnchor()
    assert(not Bar.snappedTo)
    Settings:Show(true)
    anchor(points[1], Editor.frame.frame, points[2], points[3], points[4])
    assert(dropdown(Settings.panel, "Snap to route workshop"):GetValue() == side)
end

-- Dragging away from an open workshop remains an explicit detach.
local button = Bar.btnList[1]
button:GetScript("OnMouseDown")(button)
button:GetScript("OnDragStart")(button)
assert(profile.snap == "NONE" and not Bar.snappedTo)
button:GetScript("OnDragStop")(button)
assert(dropdown(Settings.panel, "Snap to route workshop"):GetValue() == "NONE")
Editor:Hide()
AprRC.settings.profile.recordBarFrame.isRecording = false
Bar:ResetToDefault()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Command bar column wrapping, snap settings, workshop lifecycle and drag detachment passed.")
