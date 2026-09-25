local E, UI = AprRC.routeEditor, AprRC.editorUI
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function open(key)
    assert(walk(E.inspector, function(w) return w:GetUserData("navigateKey") == key end), tostring(key)):Fire("OnClick")
end
local function button(label)
    return assert(walk(E.inspector, function(w) return w.type == "Button" and w.text:GetText() == UI.Text(label) end))
end
local function field(path)
    return assert(walk(E.inspector, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function flat()
    assert(not walk(E.inspector, function(w) return w.type == "InlineGroup" end), "Parallel conditions still nest frames")
    assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
end
local condition = { EquippedItemStat = { slot = 18, stat = "QUALITY", operator = "<", value = 7,
    precision = 1, allowMissing = true } }
local route = assert(AprRC.editorModel:NewRoute("Parallel condition layout"))
route.steps = { { Note = "Main" } }
route.parallelSteps = {
    { conditions = { AllOf = { AprRC:CopyData(condition) } }, steps = {
        { AnyOf = { { AnyOf = { AprRC:CopyData(condition) } } } }, { Note = "Second parallel step" } } },
    { conditions = { Race = { "Orc" } }, steps = { { Note = "Other group" } } },
}
local original = AprRC:CopyData(route)
E:Show(); E:SelectRoute(route.name); E:SelectTab("parallel")
local session = E.session
flat()
assert(not session:IsDirty())
open("AnyOf"); open(1); open("AnyOf"); open(1); open("EquippedItemStat"); flat()
local path = "route/parallelSteps/1/steps/1/AnyOf/1/AnyOf/1/EquippedItemStat/"
local allow = field(path .. "allowMissing")
local captured, previousLine = {}, AprRC.AddTooltipLine
AprRC.AddTooltipLine = function(_, _, text) captured[#captured + 1] = text end
allow:Fire("OnEnter")
AprRC.AddTooltipLine = previousLine
assert(captured[1] == UI.Label("allowMissing") and captured[2] == UI.Text("HELP_allowMissing"))
allow:Fire("OnLeave")
allow:Fire("OnValueChanged", false)
assert(session.draft.parallelSteps[1].steps[1].AnyOf[1].AnyOf[1].EquippedItemStat.allowMissing == false)
assert(route.parallelSteps[1].steps[1].AnyOf[1].AnyOf[1].EquippedItemStat.allowMissing == true)
E:Undo(-1)
assert(field(path .. "allowMissing"):GetValue() == true)
E:Undo(1)
assert(field(path .. "allowMissing"):GetValue() == false)
assert(E:Save()); flat()

-- Switching between the group condition and step must open independent roots.
E.groupConditions:Fire("OnClick"); flat()
assert(#E.parallelFormTrail == 0)
open("AllOf"); open(1); open("EquippedItemStat"); flat()
local groupPath = "route/parallelSteps/1/conditions/AllOf/1/EquippedItemStat/value"
local value = field(groupPath)
value:SetText("6"); value:Fire("OnTextChanged", "6")
assert(session.draft.parallelSteps[1].conditions.AllOf[1].EquippedItemStat.value == 6)
assert(session.draft.parallelSteps[1].steps[1].AnyOf[1].AnyOf[1].EquippedItemStat.value == 7)
button("Back to step"):Fire("OnClick")
assert(#E.parallelFormTrail == 0)
open("AnyOf"); open(1)
E.list.children[2]:Fire("OnClick")
assert(#E.parallelFormTrail == 0 and field("route/parallelSteps/1/steps/2/Note"))
E.parallelPicker:Fire("OnValueChanged", 2)
assert(#E.parallelFormTrail == 0 and field("route/parallelSteps/2/steps/1/Note"))
E.parallelPicker:Fire("OnValueChanged", 1)
open("AnyOf"); open(1); open("AnyOf"); open(1); open("EquippedItemStat")
button("Step overview"):Fire("OnClick")
assert(#E.parallelFormTrail == 0)
open("AnyOf"); open(1); open("AnyOf"); open(1); open("EquippedItemStat")

-- Depth does not reduce the usable width, in either window mode.
for _, size in ipairs({ { 880, 560 }, { 1120, 780 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    flat()
    assert(field(path .. "value").frame:GetWidth() > 100)
end
E:ToggleCompact(); E.frame:SetWidth(440); E.frame:SetHeight(680); E.frame:DoLayout()
E:ShowStepPane("inspector"); flat()
assert(field(path .. "value").frame:GetWidth() > 100)
E:ToggleCompact()

-- Structural deletion and undo must not leave setters targeting removed nodes.
button("Step overview"):Fire("OnClick")
open("AnyOf")
local first = assert(walk(E.inspector, function(w) return w:GetUserData("navigateKey") == 1 end))
first.parent.parent.children[2]:Fire("OnClick")
assert(#session.draft.parallelSteps[1].steps[1].AnyOf == 0)
E:Undo(-1)
open(1); open("AnyOf"); open(1); open("EquippedItemStat"); flat()
assert(field(path .. "allowMissing"):GetValue() == false)
assert(AprRC:DeepCompare(session.draft.steps[1].Note, original.steps[1].Note))
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Parallel condition navigation, missing-stat help, isolated edits, undo and compact layout passed.")
