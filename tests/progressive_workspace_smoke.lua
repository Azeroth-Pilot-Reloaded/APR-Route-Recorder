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
local preferences = AprRC.settings.profile.editorFrame
preferences.disclosures = preferences.disclosures or {}
for _, key in ipairs({ "Step content", "Position and guidance", "Options", "Conditions" }) do
    preferences.disclosures["step/" .. key] = false
end
preferences.disclosures.stepActions = false
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
local before = Model:RouteText(E.session.draft)
local widget = input("step/HasSpell")
assert(not find(E.inspector, function(w) return w:GetUserData("disclosureKey") end),
    "Step details must stay visible even with old collapsed preferences")
assert(E.stepActions:GetUserData("disclosureKey") == nil and E.stepActions.frame:IsShown())
local copies, serializations = 0, 0
local copy, serialize = AprRC.CopyData, AprRC.SerializeData
AprRC.CopyData = function(self, ...) copies = copies + 1; return copy(self, ...) end
AprRC.SerializeData = function(self, ...) serializations = serializations + 1; return serialize(self, ...) end
E.routeActions.toggle:Fire("OnClick"); E.routeActions.toggle:Fire("OnClick")
assert(widget == input("step/HasSpell"), "Route action folding preserves the exact step input widget")
assert(copies == 0 and serializations == 0, "Folding must never scan/copy/serialize route data")
AprRC.CopyData, AprRC.SerializeData = copy, serialize
assert(not E.session:IsDirty() and Model:RouteText(E.session.draft) == before)

-- An incomplete numeric input survives folding route actions.
widget:SetText("incomplete"); widget:Fire("OnTextChanged", "incomplete"); widget:SetFocus()
local typedText, typedCursor = E.session.draftText, E.session.cursor
E.routeActions.toggle:Fire("OnClick"); E.routeActions.toggle:Fire("OnClick")
assert(input("step/HasSpell") == widget and widget:GetText() == "incomplete")
assert(E.session.draft.steps[1].HasSpell == "incomplete" and
    E.session.draftText == typedText and E.session.cursor == typedCursor,
    "Folding must preserve even an invalid edit without creating another snapshot")
widget:SetText("42"); widget:Fire("OnTextChanged", "42")
assert(not E.session:IsDirty())
assert(E.saveButton.parent == E.routeActions.children[1] and
    E.undoButton.parent == E.saveButton.parent and E.redoButton.parent == E.saveButton.parent)
assert(E.positionButton.parent == E.stepActions and E.duplicate.parent == E.stepActions)

-- Newly added step fields are immediately visible without a disclosure.
local picker = assert(find(E.inspector, function(w)
    return w.type == "APRSearchSelect" and w.entries and w.entries.MinLevel
end))
picker:Fire("OnValueChanged", "MinLevel")
assert(not find(E.inspector, function(w) return w:GetUserData("disclosureKey") end))
local level = input("step/MinLevel/variant")
level:SetText("10"); level:Fire("OnTextChanged", "10")
assert(E.session.draft.steps[1].MinLevel == 10 and route.steps[1].MinLevel == nil)
E:Undo(-1); E:Undo(-1)
assert(not E.session:IsDirty())

-- Legacy Zone-only steps keep their position inputs directly accessible.
E.session.draft.steps[1].Coord = nil
E:DrawInspector()
assert(input("step/Zone"))
E.session:Reload()
E:SelectTab("route")
local details = section("route/Route details")
details.toggle:Fire("OnClick")
E:SelectTab("steps"); E:SelectTab("route")
assert(not section("route/Route details"):GetUserData("expanded"), "Route section state survives tab changes")
section("route/Route details").toggle:Fire("OnClick")

-- Parallel activation and contents are separate, reachable views in compact mode.
E:SelectTab("parallel")
assert(not find(E.inspector, function(w) return w:GetUserData("disclosureKey") end),
    "Parallel step details also stay visible")
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

local function invalidated(change, message)
    local previous = scans
    change(); E:DrawList()
    assert(scans == previous + 1, message)
    local matches, positions = E:StepMatches()
    assert(scans == previous + 1 and #E.list.children <= 40)
    for position, index in ipairs(matches) do assert(positions[index] == position) end
end
invalidated(function() E.filter = "travel" end, "Category changes invalidate the cache")
invalidated(function() E.session.draft.steps = AprRC:CopyData(E:Steps()) end, "Replacing steps invalidates the cache")
invalidated(function() E.session.draft = AprRC:CopyData(E.session.draft) end, "Replacing a draft invalidates the cache")
-- A delayed item name must reveal an actual search result through the event
-- handler, even if navigation happens before the deferred inspector refresh.
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function() end
E.session.draft.steps[20000].EquipItem = { itemID = 42, slot = 16 }
E.query, E.filter = "Late inventory name", "all"
E:Changed()
assert(#E:StepMatches() == 0 and Model.pendingItemNames[42])
invalidated(function()
    C_Item.GetItemInfo = function() return "Late inventory name" end
    TestEvent("GET_ITEM_INFO_RECEIVED", 42, true)
end, "Async description changes invalidate search before the next refresh")
assert(E:StepMatches()[1] == 20000 and #E.list.children == 1)
local previous = scans
E:Refresh()
assert(scans == previous, "Description refresh reuses the newly built index")
C_Item.GetItemInfo = itemInfo
E.query, E.filter = "", "all"; E:DrawList()
previous = scans
E:HandleStepKey("UP"); E:HandleStepKey("DOWN")
assert(scans == previous, "Keyboard navigation also reuses the cached positions")
E.session:Reload(); E:DrawList()
assert(scans == previous + 1, "Reload invalidates the draft index")
Model.Filter = filter
E.session:Reload(); TestCloseWorkshop(); TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Progressive sections, visible new fields, parallel stages and cached 20,000-step navigation passed.")
