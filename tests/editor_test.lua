local Model = AprRC.editorModel
local originalData = AprRCData
local route = {
    name = "2393-Editor", label = "Editor test", expansion = "Midnight", mapID = 2393,
    category = "Leveling", XPConsumables = false,
    conditions = { Class = 8, MinLevel = 80 },
    parallelSteps = { { conditions = { HasSpell = 42 }, steps = { { Note = "Parallel" } } } },
    steps = { { PickUp = { 42 }, _index = 1, Coord = { x = 100, y = -200 }, Zone = 2393 },
        { Qpart = { [42] = { 1, 2 } }, _index = 2, ExtraLineText2 = "Keep numbered text" },
        { RouteCompleted = true, _index = 3 } },
}
AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
local original = AprRC:CopyData(route)
local session = Model:Open(route)
assert(not session:IsDirty() and not session:IsStale())
assert(session:Move(2, 1))
assert(route.steps[1].PickUp, "Draft edit touched live recording")
assert(session.draft.steps[1].Qpart and session.draft.steps[1]._index == 1)
assert(not session:Move(1, 3), "Moved across completion marker")
assert(not session:Insert({ RouteCompleted = true }), "Duplicate completion marker")
assert(session:Insert({ Note = "Inserted before completion" }, 3))
assert(session.draft.steps[4].RouteCompleted)
assert(session:Delete(2))
assert(session:Undo(-1) and #session.draft.steps == 4)
assert(session:Undo(1) and #session.draft.steps == 3)
assert(session:Undo(-1))
session:Insert({ Note = "New history branch" }, 1)
assert(not session:Undo(1), "Redo should be cleared after a new edit")
local restored = Model:Open(route)
assert(restored:IsDirty() and #restored.draft.steps == 5, "Draft was lost when reopened")
assert(AprRC:DeepCompare(original, route), "Opening a draft mutated stored route")

-- Raw errors survive closing/reloading and never replace saved data.
restored.raw = '{ steps = { { Note = "unfinished" '
restored:Persist()
local reopened = Model:Open(route)
assert(reopened.raw == restored.raw)
assert(not reopened:Save())
assert(AprRC:DeepCompare(original, route))
assert(not reopened:ApplyRaw())
reopened.raw = '{ { Note = "Legacy step-only import" } }'
assert(reopened:ApplyRaw())
assert(reopened.draft.label == "Editor test" and reopened.draft.XPConsumables == false)
assert(reopened.draft.parallelSteps[1].steps[1].Note == "Parallel")
assert(reopened:Save())
assert(AprRCData.CurrentRoute.steps[1].Note == "Legacy step-only import")
assert(AprRCData.CurrentRoute == AprRCData.Routes[1])
assert(AprRCData.BackupRoute[1].PickUp[1] == 42)
assert(not reopened:IsDirty() and not AprRCData.EditorDrafts[route.name])

-- A live append or an in-place update cannot be overwritten by a draft.
local current = AprRCData.CurrentRoute
local conflict = Model:Open(current)
conflict.draft.steps[1].Note = "Manual draft"
conflict:Snapshot()
current.steps[2] = { Done = { 42 } }
local saved, reason = conflict:Save()
assert(not saved and reason == "conflict")
assert(current.steps[2].Done[1] == 42)
local copy = assert(Model:NewRoute("Copy", assert(conflict:Read())))
assert(copy.name == "2393-Copy" and copy.parallelSteps[1].steps[1].Note == "Parallel")
assert(copy ~= conflict.draft and copy.steps ~= conflict.draft.steps)
assert(not Model:NewRoute("Copy"))
assert(not Model:NewRoute("  "))
conflict:Reload()
assert(not conflict:IsDirty() and #conflict.draft.steps == 2)
local sameCount = Model:Open(current)
sameCount.draft.steps[1].Note = "Draft again"
sameCount:Snapshot()
current.steps[1].Note = "Changed in place"
assert(sameCount:IsStale() and not sameCount:Save())

-- Search uses plain text, includes IDs and numbered instructions, and preserves order.
local steps = { { PickUp = { 42 } }, { Waypoint = 42 }, { Qpart = { [42] = { 1 } }, ExtraLineText2 = "100% ready" } }
local matches = Model:Filter(steps, "42", "quests")
assert(#matches == 2 and matches[1] == 1 and matches[2] == 3)
assert(Model:Filter(steps, "100%", "all")[1] == 3)
assert(#Model:Filter(steps, "%[", "all") == 0) -- literal pattern characters, never Lua patterns
local key, detail = Model:Summary({ Note = { "Line one", "Line two" } })
assert(key == "Note" and detail:find("Line two", 1, true))

-- Saved drafts contain data, never executable Lua or shared live references.
local before = AprRC:CopyData(AprRCData.CurrentRoute)
sameCount.raw = '{ steps = {} }; error("must not execute")'
assert(not sameCount:Save())
assert(AprRC:DeepCompare(before, AprRCData.CurrentRoute))

-- Explicit overwrite saves exactly the current draft, with the same data as a
-- copy, without merging background changes. Validation still applies.
sameCount.raw = nil
local expected = assert(sameCount:Read())
local liveBeforeOverwrite = AprRC:CopyData(AprRCData.CurrentRoute.steps)
assert(sameCount:Save(true))
assert(AprRC:DeepCompare(expected, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute == AprRCData.Routes[1])
assert(AprRC:DeepCompare(liveBeforeOverwrite, AprRCData.BackupRoute))
assert(not sameCount:IsDirty() and not sameCount:IsStale())
sameCount.raw = '{ steps = {'
assert(not sameCount:Save(true), "Overwrite must not bypass Lua validation")
assert(AprRC:DeepCompare(expected, AprRCData.CurrentRoute))
sameCount.raw = nil
AprRCData.Routes, AprRCData.CurrentRoute = {}, { name = "", steps = {} }
local missing, missingReason = sameCount:Save(true)
assert(not missing and missingReason == "missing", "Overwrite must not resurrect a deleted route")
AprRCData = originalData
