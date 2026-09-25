local E, UI = AprRC.routeEditor, AprRC.editorUI
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function button(label)
    return assert(walk(E.inspector, function(w) return w.type == "Button" and w.text:GetText() == UI.Text(label) end))
end
local function field(path)
    return assert(walk(E.inspector, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function flat()
    local function cards(widget, depth)
        if widget.type == "InlineGroup" then depth = depth + 1 end
        assert(depth <= 1, "Nested conditions must not accumulate card borders")
        for _, child in ipairs(widget.children or {}) do cards(child, depth) end
    end
    cards(E.inspector, 0)
    assert(not walk(E.inspector, function(w) return w:GetUserData("navigateKey") end), "Fields must be editable without navigation")
    assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
end
local condition = { EquippedItemStat = { slot = 18, stat = "QUALITY", operator = "<", value = 7,
    precision = 1, allowMissing = true } }
local route = assert(AprRC.editorModel:NewRoute("Parallel condition layout"))
route.steps = { { Note = "Main" } }
route.parallelSteps = {
    { conditions = { AllOf = { AprRC:CopyData(condition) } }, steps = {
        { AnyOf = { { AnyOf = { AprRC:CopyData(condition) } } },
            EquippedItemStat = AprRC:CopyData(condition.EquippedItemStat),
            ItemCount = { itemIDs = { 6948 }, count = 1 }, Not = { EquippedItem = { slot = 16, itemID = 2493 } } },
        { Note = "Second parallel step" } } },
    { conditions = { Race = { "Orc" } }, steps = { { Note = "Other group" } } },
}
local original = AprRC:CopyData(route)
E:Show(); E:SelectRoute(route.name); E:SelectTab("parallel")
local session = E.session
flat()
for _, key in ipairs({ "AnyOf", "EquippedItemStat", "ItemCount", "Not" }) do
    local card = assert(walk(E.inspector, function(w)
        return w:GetUserData("sectionPath") == "route/parallelSteps/1/steps/1/" .. key
    end))
    assert(card.type == "InlineGroup", "Each condition block needs its own visible card")
end
assert(not session:IsDirty())
local path = "route/parallelSteps/1/steps/1/AnyOf/1/AnyOf/1/EquippedItemStat/"
-- Sibling and nested conditions are all available immediately, as in the report.
assert(field("route/parallelSteps/1/steps/1/EquippedItemStat/value"))
assert(field("route/parallelSteps/1/steps/1/ItemCount/count"))
assert(field("route/parallelSteps/1/steps/1/Not/EquippedItem/itemID"))
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
local groupPath = "route/parallelSteps/1/conditions/AllOf/1/EquippedItemStat/value"
local value = field(groupPath)
value:SetText("6"); value:Fire("OnTextChanged", "6")
assert(session.draft.parallelSteps[1].conditions.AllOf[1].EquippedItemStat.value == 6)
assert(session.draft.parallelSteps[1].steps[1].AnyOf[1].AnyOf[1].EquippedItemStat.value == 7)
button("Back to step"):Fire("OnClick")
assert(field(path .. "allowMissing"))
E.list.children[2]:Fire("OnClick")
assert(field("route/parallelSteps/1/steps/2/Note"))
E.parallelPicker:Fire("OnValueChanged", 2)
assert(field("route/parallelSteps/2/steps/1/Note"))
E.parallelPicker:Fire("OnValueChanged", 1)
E.list.children[1]:Fire("OnClick")

-- Depth does not reduce the usable width, in either window mode.
for _, size in ipairs({ { 880, 560 }, { 1120, 780 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    flat()
    assert(field(path .. "value").frame:GetWidth() > E.inspector.content:GetWidth() - 90,
        "Nested fields must retain the inspector width")
end
E:ToggleCompact(); E.frame:SetWidth(440); E.frame:SetHeight(680); E.frame:DoLayout()
E:ShowStepPane("inspector"); flat()
assert(field(path .. "value").frame:GetWidth() > 100)
E:ToggleCompact()

-- Structural deletion and undo must not leave setters targeting removed nodes.
local first = assert(walk(E.inspector, function(w)
    return w:GetUserData("sectionPath") == "route/parallelSteps/1/steps/1/AnyOf/1"
end))
first.children[2].children[2]:Fire("OnClick")
assert(#session.draft.parallelSteps[1].steps[1].AnyOf == 0)
E:Undo(-1)
flat()
assert(field(path .. "allowMissing"):GetValue() == false)
assert(AprRC:DeepCompare(session.draft.steps[1].Note, original.steps[1].Note))
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Open parallel condition sections, direct editing, missing-stat help, undo and full-width layout passed.")
