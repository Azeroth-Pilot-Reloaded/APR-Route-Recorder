local E, UI, Model = AprRC.routeEditor, AprRC.editorUI, AprRC.editorModel
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end
local function section(key)
    return assert(find(E.frame, function(w) return w:GetUserData("disclosureKey") == key end), key)
end
local function input(path)
    return assert(find(E.inspector, function(w) return w:GetUserData("fieldPath") == path end), path)
end

TestCloseWorkshop(); TestRunTimers()
local route = assert(Model:NewRoute("Progressive workspace"))
route.steps = { { Note = "Keep this text", HasSpell = 42, Coord = { x = 10, y = 20 }, Zone = 2393 } }
route.parallelSteps = { { conditions = {}, steps = { { Note = "Parallel activity" } } } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
local before = Model:RouteText(E.session.draft)
local widget = input("step/HasSpell")
local conditions = section("step/Conditions")
local copies, serializations = 0, 0
local copy, serialize = AprRC.CopyData, AprRC.SerializeData
AprRC.CopyData = function(self, ...) copies = copies + 1; return copy(self, ...) end
AprRC.SerializeData = function(self, ...) serializations = serializations + 1; return serialize(self, ...) end
conditions.toggle:Fire("OnClick")
assert(not conditions:GetUserData("expanded") and not conditions.children[2].frame:IsShown())
conditions.toggle:Fire("OnClick")
assert(conditions:GetUserData("expanded") and conditions.children[2].frame:IsShown())
assert(widget == input("step/HasSpell"), "Folding preserves the exact input widget")
E.routeActions.toggle:Fire("OnClick"); E.routeActions.toggle:Fire("OnClick")
E.stepActions.toggle:Fire("OnClick"); E.stepActions.toggle:Fire("OnClick")
assert(copies == 0 and serializations == 0, "Folding must never scan/copy/serialize route data")
AprRC.CopyData, AprRC.SerializeData = copy, serialize
assert(not E.session:IsDirty() and Model:RouteText(E.session.draft) == before)

-- A field inserted into a collapsed section is immediately visible.
conditions.toggle:Fire("OnClick")
local picker = assert(find(E.inspector, function(w)
    return w.type == "APRSearchSelect" and w.entries and w.entries.MinLevel
end))
picker:Fire("OnValueChanged", "MinLevel")
assert(section("step/Conditions"):GetUserData("expanded"))
local level = input("step/MinLevel/variant")
level:SetText("10"); level:Fire("OnTextChanged", "10")
assert(E.session.draft.steps[1].MinLevel == 10 and route.steps[1].MinLevel == nil)
E:Undo(-1); E:Undo(-1)
assert(not E.session:IsDirty())

-- Parallel activation and contents are separate, reachable views in compact mode.
E:SelectTab("parallel")
assert(E.parallelHint.label:GetText() == UI.Text("Always active"))
E.groupSteps:Fire("OnClick"); E.duplicate:Fire("OnClick")
assert(E.parallelPicker.list[1] == E:ParallelLabel(E.session.draft.parallelSteps[1], 1),
    "Parallel counts must update without rebuilding the inspector")
E:Undo(-1)
if not E.compact then E:ToggleCompact() end
E:ShowStepPane("list"); E.groupSteps:Fire("OnClick")
assert(E.compactPane == "inspector" and E.inspector.parent.frame:IsShown())
E.groupConditions:Fire("OnClick")
local add = assert(find(E.inspector, function(w) return w.type == "APRSearchSelect" end))
add:Fire("OnValueChanged", "HasSpell")
assert(E.parallelHint.label:GetText() == "1 " .. UI.Text("Conditions"), "Activation summary must update after editing")
E:Undo(-1)
assert(E.parallelHint.label:GetText() == UI.Text("Always active"))
E:ToggleCompact()
E.session:Reload(); TestCloseWorkshop(); TestRunTimers()

-- A 20,000-step route still creates 40 rows. Selection/paging reuse the same
-- index; edits, query changes and async names explicitly invalidate it.
local large = assert(Model:NewRoute("Large workspace navigation"))
for index = 1, 20000 do large.steps[index] = { Note = "Waypoint " .. index } end
E:Show(); E:SelectRoute(large.name); E:SelectTab("steps"); E.follow = false
TestRunTimers()
local filter, scans = Model.Filter, 0
Model.Filter = function(self, ...) scans = scans + 1; return filter(self, ...) end
for index = 2, 21 do E:SelectStep(index) end
E.nextButton:Fire("OnClick")
assert(scans == 0 and #E.list.children == 40, "Navigation must reuse its route index")
E.query = "Waypoint 20000"; E:DrawList()
assert(scans == 1 and #E.list.children == 1)
E:SelectStep(20000)
assert(scans == 1, "Filtered selection must not search the whole route again")
E.session.draft.steps[20000].Note = "Changed last waypoint"; E:Changed()
assert(scans == 2 and E.list.children[1].type == "Label", "Edits invalidate search results")
Model.Filter = filter
E.session:Reload(); TestCloseWorkshop(); TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Progressive sections, visible new fields, parallel stages and cached 20,000-step navigation passed.")
