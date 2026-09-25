local savedData = AprRCData
local route = { name = "2393-Parallel model", steps = { { Note = "Main" }, { RouteCompleted = true } },
    parallelSteps = {
        { conditions = { HasSpell = 42 }, steps = { { Note = "First", _index = 1 }, { Note = "Second", _index = 2 } } },
        { conditions = { MinLevel = 10 }, steps = { { Done = { 42 } } } },
    } }
AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
local original = AprRC:CopyData(route)
local session = AprRC.editorModel:Open(route)
local initialDraft = AprRC:CopyData(session.draft)
assert(session:Move(1, 2, 1))
assert(session.draft.parallelSteps[1].steps[2].Note == "First")
assert(session.draft.parallelSteps[1].steps[2]._index == 2)
assert(session.selected == 1 and session.parallelSelected == 2)
assert(session:Insert({ RouteCompleted = true }, 1, 1))
assert(not session:Insert({ RouteCompleted = true }, 1, 1))
assert(not session:Move(2, 3, 1))
assert(session:Insert({ Note = "Before completion" }, 3, 1))
assert(session.draft.parallelSteps[1].steps[4].RouteCompleted)
assert(session:Delete(2, 1))
assert(session:Undo(-1) and #session:GetSteps(1) == 4)
assert(session:Undo(1) and #session:GetSteps(1) == 3)
assert(AprRC:DeepCompare(route, original), "Parallel operations changed the recording source")
assert(AprRC:DeepCompare(session.draft.steps, initialDraft.steps), "Parallel operations changed main steps")
assert(AprRC:DeepCompare(session.draft.parallelSteps[2], initialDraft.parallelSteps[2]))

session:InsertGroup(session.draft.parallelSteps[1])
assert(session.parallelGroup == 2 and #session.draft.parallelSteps == 3)
session.draft.parallelSteps[2].conditions.HasSpell = 99
session:Snapshot()
assert(session.draft.parallelSteps[1].conditions.HasSpell == 42, "Group copies must be detached")
assert(session:MoveGroup(2, 3))
assert(session:DeleteGroup(1))
assert(session.parallelGroup == 1 and #session.draft.parallelSteps == 2)
assert(session:Undo(-1) and #session.draft.parallelSteps == 3)
assert(session.parallelGroup == 3)
local restored = AprRC.editorModel:Open(route)
assert(restored.parallelGroup == 3 and restored.parallelSelected == session.parallelSelected)
assert(restored.draft.parallelSteps[3].conditions.HasSpell == 99)
assert(restored:Save())
assert(AprRCData.CurrentRoute.parallelSteps[3].conditions.HasSpell == 99)
assert(AprRC:DeepCompare(AprRCData.CurrentRoute.steps, initialDraft.steps))
assert(not restored:IsDirty())
for index = 3, 1, -1 do assert(restored:DeleteGroup(index)) end
assert(restored.draft.parallelSteps == nil and restored.parallelGroup == 1)
assert(restored:Undo(-1) and #restored.draft.parallelSteps == 1)
restored.raw = '{ steps = {} }'
assert(restored:ApplyRaw())
assert(restored.parallelGroup == 1 and restored.parallelSelected == 1)
AprRCData = savedData
