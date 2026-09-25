local E, UI = AprRC.routeEditor, AprRC.editorUI
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function button(parent, label)
    return assert(walk(parent, function(w) return w.type == "Button" and w.text:GetText() == UI.Text(label) end), label)
end
local function input(parent, label)
    return assert(walk(parent, function(w)
        return (w.type == "EditBox" or w.type == "MultiLineEditBox") and w.label:GetText() == label
    end), label)
end
local function fits(group)
    local used = math.max(0, #group.children - 1) * 8
    for _, child in ipairs(group.children) do used = used + child.frame:GetHeight() end
    assert(used <= group.content:GetHeight() + 1,
        "Parallel controls overlap: " .. used .. " > " .. group.content:GetHeight())
end
local route = assert(AprRC.editorModel:NewRoute("Parallel UI"))
route.steps = { { Note = "Main first" }, { Note = "Main second" } }
E:Show()
E:SelectRoute(route.name)
E:SelectTab("steps")
E.list.children[2]:Fire("OnClick")
E:SelectTab("parallel")
assert(not E.list and E.groupConditions.disabled)
E.addGroup:Fire("OnClick")
assert(E.list and E.session.draft.parallelSteps[1].conditions)
E.addType = "Note"
E:DrawTab()
button(E.listPanel, "Add"):Fire("OnClick")
local note = input(E.inspector, UI.Label("Note"))
note:SetText("Parallel edit"); note:Fire("OnTextChanged", "Parallel edit")
assert(E.session.draft.parallelSteps[1].steps[1].Note == "Parallel edit")
assert(not route.parallelSteps and #E.session.draft.steps == 2)
E.duplicate:Fire("OnClick")
assert(#E:Steps() == 2 and E:SelectedStep() == 2)
E.moveUp:Fire("OnClick")
assert(E:SelectedStep() == 1)
E.groupConditions:Fire("OnClick")
assert(E.editGroupConditions and E.duplicate.disabled and E.moveTo.disabled)
local fields = assert(walk(E.inspector, function(w) return w.type == "APRSearchSelect" end))
fields:Fire("OnValueChanged", "HasSpell")
assert(E.session.draft.parallelSteps[1].conditions.HasSpell == 0)
local condition = input(E.inspector, UI.Label("HasSpell"))
condition:SetText("42"); condition:Fire("OnTextChanged", "42")
assert(E.session.draft.parallelSteps[1].conditions.HasSpell == 42)
E.duplicateGroup:Fire("OnClick")
assert(#E.session.draft.parallelSteps == 2 and E.session.parallelGroup == 2)
E.groupUp:Fire("OnClick")
assert(E.session.parallelGroup == 1)
E.parallelPicker:Fire("OnValueChanged", 2)
assert(E.session.parallelGroup == 2 and E:SelectedStep() == 1)
E:SelectTab("steps")
assert(E.session.selected == 2 and #E.list.children == 2)
E:SelectTab("parallel")
assert(E.session.parallelGroup == 2 and E:Steps()[1].Note == "Parallel edit")
E.delete:Fire("OnClick")
button(E.confirm, YES):Fire("OnClick")
assert(#E:Steps() == 1)
E:Undo(-1)
assert(#E:Steps() == 2)
E.deleteGroup:Fire("OnClick")
button(E.confirm, YES):Fire("OnClick")
assert(#E.session.draft.parallelSteps == 1)
E:Undo(-1)
assert(#E.session.draft.parallelSteps == 2)
assert(E:Save())
assert(AprRC:FindRouteByName(route.name).parallelSteps[2].conditions.HasSpell == 42)
E:SelectTab("lua")
assert(E.luaBox:GetText():find("Parallel edit", 1, true))
E:SelectTab("parallel")

-- Following a recording refreshes source data without taking over this tab.
local oldCurrent, oldFollow = AprRCData.CurrentRoute, E.follow
AprRCData.CurrentRoute = AprRC:FindRouteByName(route.name)
E.follow = true
E.query = "Parallel edit"
E:DrawList()
E.list:SetScroll(17)
local selected = E:SelectedStep()
table.insert(AprRCData.CurrentRoute.steps, { Note = "Recorded main step" })
LibStub("AceGUI-3.0"):ClearFocus()
E:Refresh()
assert(#E.session.draft.steps == 3)
assert(E.session.parallelGroup == 2 and E:SelectedStep() == selected and E.query == "Parallel edit")
assert(E.list.localstatus.scrollvalue == 17)
AprRCData.CurrentRoute, E.follow = oldCurrent, oldFollow
E.query = ""

-- Pagination, search and form pickers must use the selected group's collection.
for index = 3, 85 do E.session:Insert({ Note = "Parallel " .. index }, nil, 2) end
E:DrawTab()
assert(#E.list.children == 40)
E.nextButton:Fire("OnClick")
assert(E.page == 2 and #E.list.children == 40)
local search = input(E.listPanel, UI.Text("Search steps"))
search:SetText("Parallel 85"); search:Fire("OnTextChanged", "Parallel 85")
assert(#E.list.children == 1)
E.list.children[1]:Fire("OnClick")
assert(E:SelectedStep() == 85)
assert(E:FormContext().valueAt("route/parallelSteps/2/steps/85/Note") == "Parallel 85")

-- The extra group toolbar must fit alongside the existing step controls.
if E.compact then E:ToggleCompact() end
for _, size in ipairs({ { 880, 560 }, { 1120, 780 }, { 1400, 900 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    fits(E.frame); fits(E.stepsSplit.parent); fits(E.listPanel); fits(E.inspector.parent)
    assert(E.list.frame:GetHeight() > 0 and E.inspector.frame:GetHeight() > 0)
end
E:ToggleCompact()
for _, size in ipairs({ { 440, 680 }, { 560, 780 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    E:ShowStepPane("list"); fits(E.listPanel)
    E.list.children[1]:Fire("OnClick")
    assert(E.compactPane == "inspector" and E.stepsSplit.children[2].frame:IsShown())
    fits(E.inspector.parent); fits(E.stepsSplit.parent); fits(E.frame)
end
E:ToggleCompact()
E:Hide()
E:Show()
assert(E.tab == "parallel" and #E:Steps() == 85 and E.session.parallelGroup == 2)
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Parallel group and step editing, conditions, undo, save, search and layout checks passed.")
