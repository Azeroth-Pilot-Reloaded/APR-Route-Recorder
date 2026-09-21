local E, UI, Settings, Bar = AprRC.routeEditor, AprRC.editorUI, AprRC.CommandBarSetting, AprRC.CommandBar
local GUI = LibStub("AceGUI-3.0")
local route = assert(AprRC.editorModel:NewRoute("Workshop controls"))
route.steps = { { Waypoint = 123, Range = 5, Coord = { x = 12, y = 34 }, Note = "Long note" } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
if E.compact then E:ToggleCompact() end
assert(E.compactButton.type == "APRIconButton")
assert(E.compactButton.frame:GetPoint() == "TOPRIGHT")
assert(E.compactButton.tooltip == UI.Text("Compact mode"))
assert(E.reloadButton.type == "APRIconButton" and E.reloadButton.tooltip == UI.Text("Reload saved route"))

-- Divider responds to the native mouse path and persists its proportion.
local split = E.stepsSplit
TestMouseDown = true
TestCursorX = (split.content:GetWidth() - 14) * 0.64
split.divider:GetScript("OnMouseDown")(split.divider, "LeftButton")
split.divider:GetScript("OnUpdate")(split.divider, 0.016)
assert(math.abs(split.ratio - 0.64) < 0.001)
assert(split.children[1].frame:GetWidth() > split.children[2].frame:GetWidth())
assert(AprRC.settings.profile.editorFrame.stepPaneRatio == split.ratio)
TestMouseDown = false
split.divider:GetScript("OnMouseUp")(split.divider)
assert(not split.dragging and not split.divider:GetScript("OnUpdate"))
E:ToggleCompact()
assert(not E.stepsSplit.divider:IsShown())
E:ToggleCompact()
assert(math.abs(E.stepsSplit.ratio - 0.64) < 0.001)
E:Hide(); E:Show()
assert(math.abs(E.stepsSplit.ratio - 0.64) < 0.001)

-- Single inputs retain an adjacent trash icon; compound and multiline entries
-- allocate the full content width and put their trash icon underneath.
local holder = GUI:Create("SimpleGroup")
holder:SetWidth(420); holder:SetLayout("Flow")
local value = { Waypoint = 123, Range = 5, Coord = { x = 12, y = 34 }, Note = "Long note" }
UI.Form:Render(holder, "step", value, function(v) value = v end,
    { modes = {}, pages = {}, changed = function() end, redraw = function() end, error = error }, "step", "Step")
local noteGroup = UI.Group(holder)
noteGroup:SetLayout("APRField")
local noteBody = UI.Group(noteGroup)
UI.Form:Render(noteBody, "text", "Long note", function() end,
    { modes = {}, pages = {}, changed = function() end, redraw = function() end, error = error }, "Note", "Note")
UI.Form:RemoveButton(noteGroup, noteBody, function() end)
holder:DoLayout()
local scalar, compound, multiline
for _, group in ipairs(holder.children) do
    local body = group.children and group.children[1]
    local row = body and body.children and body.children[#body.children]
    if row and row:GetUserData("pickerActions") then
        assert(group:GetUserData("compound") and #row.children == 2)
        local _, _, point, offset = row.children[1].frame:GetPoint()
        assert(point == "TOPRIGHT" and offset == -34, "Picker and Remove must share a right-aligned action row")
        if body.children[1].type == "MultiLineEditBox" then multiline = row.children[2] end
    end
    if group.children and group.children[2] and group.children[2].type == "APRIconButton" then
        local body, action = group.children[1], group.children[2]
        local first = body.children[1]
        local _, relative, anchor, _, y = action.frame:GetPoint()
        if first.type == "EditBox" and not group:GetUserData("compound") then
            scalar = action
            assert(not group:GetUserData("compound") and relative == first.editbox and anchor == "RIGHT" and y == 0,
                "Trash must be centered on the input, excluding its label")
            assert(body.frame:GetWidth() < group.content:GetWidth())
        elseif first.type == "InlineGroup" then
            compound = action
            assert(group:GetUserData("compound") and y <= -body.frame:GetHeight())
        elseif first.type == "MultiLineEditBox" then
            multiline = action
            assert(group:GetUserData("compound") and y <= -body.frame:GetHeight())
        end
    end
end
assert(scalar and compound and multiline)
scalar:Fire("OnClick")
assert(value.Range == nil and value.Coord.x == 12 and value.Note == "Long note")
GUI:Release(holder)

-- Exercise the real recorder path while the workshop remains open.
AprRC.settings.profile.recordBarFrame.isRecording = false
AprRC.settings.profile.commandBarFrame.enabled = true
Bar:ResetToDefault()
E:ToggleRecording()
assert(AprRC.settings.profile.recordBarFrame.isRecording and Bar.frame:IsShown())
assert(Bar.frame:GetFrameStrata() == E.frame.frame:GetFrameStrata())
assert(Bar.frame:GetFrameLevel() > E.frame.frame:GetFrameLevel())

Settings.query = ""
Settings:Show(false)
local entry = Settings.available.children[1].entry
local before = #Bar:GetCommands()
local function drag(row, target, y)
    TestMouseDown, TestMouseOver, TestCursorY = true, target, y or 1000
    row.frame:GetScript("OnDragStart")(row.frame)
    assert(Settings.dragging)
    Settings.ghost:GetScript("OnUpdate")(Settings.ghost, 0.016)
    TestMouseDown = false
    row.frame:GetScript("OnDragStop")(row.frame)
    assert(not Settings.dragging and not Settings.ghost:IsShown())
end
drag(Settings.available.children[1], Settings.selected.frame)
assert(#Bar:GetCommands() == before + 1 and Settings:Find(entry.command) == 1)
-- Reorder downward, accounting for the source being removed before insertion.
drag(Settings.selected.children[1], Settings.selected.frame, 0)
assert(Settings:Find(entry.command) == #Bar:GetCommands())
drag(Settings.selected.children[#Settings.selected.children], Settings.available.frame)
assert(not Settings:Find(entry.command) and #Bar:GetCommands() == before)
local snapshot = AprRC:CopyData(Bar:GetCommands())
drag(Settings.selected.children[1], nil)
assert(AprRC:DeepCompare(Bar:GetCommands(), snapshot), "Dropping outside must cancel")
-- Empty bars, duplicates and closure during a drag must not lose commands.
AprRCData.CommandBarCommands = {}
Settings:DrawResults()
drag(Settings.available.children[1], Settings.selected.frame)
assert(#Bar:GetCommands() == 1)
local first = Bar:GetCommands()[1]
Settings:ApplyDrop(first, "selected", 1)
assert(#Bar:GetCommands() == 1)
Settings:StartDrag(Settings.selected.children[1])
E:SelectTab("steps")
assert(not Settings.dragging and not Settings.ghost:GetScript("OnUpdate"))
Settings:Show(false)
-- A future API failure is reported once and cancels the native update handler.
local dropTarget = Settings.DropTarget
Settings.DropTarget = function() error("Simulated drag failure") end
TestMouseDown = true
Settings:StartDrag(Settings.selected.children[1])
Settings.ghost:GetScript("OnUpdate")(Settings.ghost, 0.016)
assert(not Settings.dragging and not Settings.ghost:GetScript("OnUpdate"))
assert(not Settings.ghost:IsShown() and not Settings.dropLine:IsShown())
assert(#UIErrors == 1 and UIErrors[1]:find("Simulated drag failure", 1, true))
table.remove(UIErrors)
Settings.DropTarget = dropTarget
TestMouseDown = false
Settings:Show(true)
-- Expanded settings fit in the same tab at both supported minimum widths.
for _, compact in ipairs({ false, true }) do
    if E.compact ~= compact then E:ToggleCompact() end
    E.frame:SetWidth(compact and 440 or 880)
    E.frame:SetHeight(compact and 680 or 560)
    E.frame:DoLayout()
    local used = (#Settings.panel.children - 1) * 8
    for _, child in ipairs(Settings.panel.children) do used = used + child.frame:GetHeight() end
    assert(used <= Settings.panel.content:GetHeight() + 1, "Command settings overflow their tab")
end
E:ToggleRecording()
assert(not AprRC.settings.profile.recordBarFrame.isRecording and not Bar.frame:IsShown())
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Icon placement, native divider/command dragging, persisted widths and recording visibility passed.")
