local GUI, UI, E = LibStub("AceGUI-3.0"), AprRC.editorUI, AprRC.routeEditor
local function event(frame, name, ...)
    local script = assert(frame:GetScript(name), name)
    script(frame, ...)
end
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = find(child, predicate)
        if found then return found end
    end
end
local function field(label)
    return assert(find(E.frame, function(w)
        return w.type == "APRSearchSelect" and w.label:GetText() == UI.Text(label)
    end), label)
end
local widget = AprRC:CreateWidget("APRSearchSelect")
local entries = { Quest = "Quête spéciale", Spell = "Sort" }
for i = 1, 90 do entries["ID" .. i] = string.format("Étape %03d", i) end
widget:SetList(entries)
widget:SetValue("Quest")
widget.frame:Show()
local selected, calls
calls = 0
widget:SetCallback("OnValueChanged", function(_, _, value) selected = value; calls = calls + 1 end)
widget:SetFocus()
assert(widget.open and #widget.matches == 92, "Focus must show the entire list, including with a selected value")
assert(calls == 0 and widget:GetValue() == "Quest", "Focus must not change the selection")
assert(widget.pullout.frame:GetHeight() <= 320, "Long lists must scroll")
widget.editbox:SetText("quete speciale")
assert(#widget.matches == 1 and widget.matches[1] == "Quest", "Search must accept accents and multiple words")
assert(widget:GetValue() == nil, "An unfinished query is not a selected value")
event(widget.editbox, "OnEnterPressed")
assert(selected == "Quest" and widget:GetValue() == "Quest" and not widget.open)
widget:SetFocus()
assert(#widget.matches == 92)
widget.editbox:SetText("iD90")
assert(#widget.matches == 1 and widget.matches[1] == "ID90", "Technical keys are searchable")
event(widget.pullout.items[1].frame, "OnClick", "LeftButton")
assert(selected == "ID90" and not widget.open)
widget:SetFocus()
widget.editbox:SetText("[no literal match]")
assert(#widget.matches == 0 and widget.pullout.items[1].disabled)
local before = calls
event(widget.editbox, "OnEnterPressed")
assert(calls == before and not widget:GetValue())
widget.editbox:SetText("")
assert(#widget.matches == 92, "Clearing the query must restore all entries")
event(widget.editbox, "OnArrowPressed", "DOWN")
local second = widget.matches[2]
event(widget.editbox, "OnEnterPressed")
assert(selected == second)
widget:SetFocus()
for _ = 1, 91 do event(widget.editbox, "OnArrowPressed", "DOWN") end
assert(widget.active == 92 and widget.pullout.scrollStatus.offset > 0, "Keyboard navigation must scroll to the result")
event(widget.editbox, "OnEscapePressed")
assert(not widget.open and not widget.editbox:HasFocus())
widget:SetFocus()
TestMouseOver, TestMouseDown = UIParent, true
event(widget.frame, "OnUpdate")
TestMouseOver, TestMouseDown = nil, nil
assert(not widget.open)
widget:SetFocus()
local popup = widget.pullout.frame
GUI:Release(widget)
assert(not popup:IsShown())
local reused = AprRC:CreateWidget("APRSearchSelect")
reused:SetList({ Fresh = "Fresh" })
reused:SetFocus()
assert(#reused.matches == 1 and not reused:GetValue())
GUI:Release(reused)

-- Exercise both real forms: typing must never mutate a route.
local live = AprRC:CopyData(AprRCData.CurrentRoute)
E:Show()
local route = assert(AprRC.editorModel:NewRoute("Search select tests"))
route.steps = { { Waypoint = 42, Coord = { x = 1, y = 2 }, Range = 5 } }
local original = AprRC:CopyData(route)
E:RefreshRoutes(); E:SelectRoute(route.name); E:SelectTab("steps")
local addStep = field("Add a step")
addStep:SetFocus()
addStep.editbox:SetText("No such step")
local addButton = assert(find(addStep.parent, function(w)
    return w.type == "Button" and w.text:GetText() == UI.Text("Add")
end))
assert(addButton.disabled)
addButton:Fire("OnClick")
assert(#E.session.draft.steps == 1)
addStep.editbox:SetText("PickUp")
event(addStep.editbox, "OnEnterPressed")
assert(not addButton.disabled)
addButton:Fire("OnClick")
assert(#E.session.draft.steps == 2 and E.session.draft.steps[2].PickUp)
local property = field("Add a field")
property:SetFocus()
property.editbox:SetText("HasAchievement")
assert(#property.matches == 1 and not E.session.draft.steps[2].HasAchievement)
popup = property.pullout.frame
event(property.pullout.items[1].frame, "OnClick", "LeftButton")
assert(E.session.draft.steps[2].HasAchievement ~= nil and not popup:IsShown())
property = field("Add a field")
property:SetFocus()
assert(not property.entries.HasAchievement, "Existing properties must not be suggested again")
popup = property.pullout.frame
E:Hide()
assert(not popup:IsShown(), "Closing the workshop must close detached menus")
assert(AprRC:DeepCompare(route, original))
assert(AprRC:DeepCompare(live, AprRCData.CurrentRoute))
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Search selects: focus, localized/key filtering, scroll, keyboard, lifecycle and both editor forms passed.")
