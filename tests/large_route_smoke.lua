local E, Model = AprRC.routeEditor, AprRC.editorModel
local route = assert(Model:NewRoute("Large route performance"))
for index = 1, 5000 do
    route.steps[index] = { Waypoint = index, Coord = { x = index, y = -index }, Zone = 2393 }
end
route.parallelSteps = { { conditions = { HasSpell = 42 }, steps = { { Note = "Parallel" } } } }
AprRCData.CurrentRoute = route
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow = false
TestRunTimers(); TestRunTimers()

-- Count expensive operations instead of asserting machine-dependent timings.
local copies, serializations, summaries = 0, 0, 0
local copy, serialize, summary = AprRC.CopyData, AprRC.SerializeData, Model.Summary
AprRC.CopyData = function(self, ...)
    copies = copies + 1
    return copy(self, ...)
end
AprRC.SerializeData = function(self, ...)
    serializations = serializations + 1
    return serialize(self, ...)
end
Model.Summary = function(self, ...)
    summaries = summaries + 1
    return summary(self, ...)
end
local function reset() copies, serializations, summaries = 0, 0, 0 end
local function idle()
    reset()
    for _ = 1, 30 do E:Tick() end
    assert(copies == 0 and serializations == 0 and summaries == 0,
        "Idle refresh must not copy, serialize or summarize the route")
end
idle()
E:DrawList()
assert(#E.list.children == 40 and summaries == 40 and serializations == 0,
    "An unfiltered page must only summarize its visible rows")
reset()
assert(#Model:Filter(route.steps, "", "travel") == 5000)
assert(summaries == 0 and serializations == 0, "Category-only filters need no descriptions or Lua text")
E.nextButton:Fire("OnClick")
assert(E.page == 2 and #E.list.children == 40)

-- A notified in-place update is detected even when the route length is stable.
route.steps[2500].Note = "Recorded change"
AprRC:NotifyRouteChanged(route.name)
TestRunTimers()
assert(E.session.draft.steps[2500].Note == "Recorded change")
idle()

-- GetLastStep is also used by legacy recording handlers without NotifyRouteChanged.
AprRC:GetLastStep().Note = "Legacy recording change"
TestRunTimers(); E:Tick()
assert(E.session.draft.steps[5000].Note == "Legacy recording change")
idle()

-- No-op recording notifications must not cause repeated full-route scans.
AprRC:NotifyRouteChanged(route.name)
TestRunTimers()
idle()
route.parallelSteps[1].conditions.HasSpell = 43
AprRC:NotifyRouteChanged(route.name)
TestRunTimers()
assert(E.session.draft.parallelSteps[1].conditions.HasSpell == 43)

-- The cached dirty state follows edits, undo/redo and edits back to the baseline.
E.session.draft.steps[1].Note = "Local edit"
E:Changed()
assert(E.session:IsDirty())
idle()
assert(E.session:Undo(-1) and not E.session:IsDirty())
assert(E.session:Undo(1) and E.session:IsDirty())
E.session.draft.steps[1].Note = nil
E:Changed()
assert(not E.session:IsDirty())
idle()

-- Save retains its full conflict check, even for unannounced external mutations.
route.steps[2500].Note = "External change without notification"
local saved, reason = E.session:Save()
assert(not saved and reason == "conflict")
E.session:Reload()
route.steps[5001] = { Note = "External append" }
E:Tick()
assert(#E.session.draft.steps == 5001)

E:SelectTab("lua")
idle()
E.luaBox:SetText("{ steps = { -- unfinished")
E.luaBox:Fire("OnTextChanged", E.luaBox:GetText())
assert(E.session:IsDirty())
idle()
route.steps[5002] = { Note = "Keep the draft" }
AprRC:NotifyRouteChanged(route.name)
TestRunTimers()
assert(E.session.raw == "{ steps = { -- unfinished" and #E.session.draft.steps == 5001)
AprRC.CopyData, AprRC.SerializeData, Model.Summary = copy, serialize, summary
E.session:Reload(); E:Hide(); TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("5,000-step routes: idle work, pagination, recording, undo/redo and save conflicts passed.")
