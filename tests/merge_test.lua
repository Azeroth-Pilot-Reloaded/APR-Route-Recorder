local Merge, Model = AprRC.routeMerge, AprRC.editorModel
local function route(steps) return { name = "2393-Merge", steps = steps } end
local function same(a, b) assert(AprRC:DeepCompare(a, b), AprRC:SerializeData(a)) end
local base = route({ { Waypoint = 1, Note = "Original", Coord = { x = 1, y = 2 }, _index = 1 },
    { Waypoint = 2, _index = 2 }, { Waypoint = 3, _index = 3 } })
local left, right = AprRC:CopyData(base), AprRC:CopyData(base)
left.steps[1].Note = "Manual"
right.steps[1].Coord.y = 8
right.steps[4] = { Done = { 42 } }
local merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 0 and #merged.steps == 4)
assert(merged.steps[1].Note == "Manual" and merged.steps[1].Coord.y == 8)
assert(base.steps[1].Note == "Original" and base.steps[1].Coord.y == 2)

-- A real value conflict must not hide compatible incoming changes.
right.steps[1].Note = "Automatic"
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 1 and conflicts[1].path == "route.steps[1].Note" and not conflicts[1].resolved)
same(conflicts[1].base, "Original")
merged, conflicts = Merge:Routes(base, left, right, { "left" })
assert(conflicts[1].resolved and merged.steps[1].Note == "Manual" and #merged.steps == 4)
merged = Merge:Routes(base, left, right, { "right" })
assert(merged.steps[1].Note == "Automatic" and merged.steps[1].Coord.y == 8)
local _, invalidChoices = Merge:Routes(base, left, right, { "anything" })
assert(not invalidChoices[1].resolved)
merged, conflicts = Merge:Routes(base, left, right, { { custom = true, value = "Corrected manually" } })
assert(conflicts[1].resolved and merged.steps[1].Note == "Corrected manually" and #merged.steps == 4)
merged, conflicts = Merge:Routes(base, left, right, { { custom = true } })
assert(conflicts[1].resolved and merged.steps[1].Note == nil, "A custom nil explicitly deletes the field")

-- Deletes, insertions and moves use ancestor positions, not current indexes.
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
table.remove(left.steps, 1)
right.steps[3].Note = "Changed third step"
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 0 and #merged.steps == 2)
assert(merged.steps[1].Waypoint == 2 and merged.steps[2].Note == "Changed third step")
right.steps[1].Note = "Changed deleted step"
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 1, "Delete versus edit must be resolved explicitly")
merged = Merge:Routes(base, left, right, { "right" })
assert(#merged.steps == 3 and merged.steps[1].Note == "Changed deleted step")
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
table.insert(left.steps, 2, { Note = "Inserted manually" })
right.steps[2].Range = 5
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 0 and #merged.steps == 4 and merged.steps[3].Range == 5)
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
table.insert(left.steps, 1, table.remove(left.steps, 3))
right.steps[4] = { Note = "Recorded tail" }
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 0 and merged.steps[1].Waypoint == 3 and merged.steps[4].Note == "Recorded tail")

-- Two inserts at the same boundary need an ordering choice.
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
left.steps[4], right.steps[4] = { Note = "Left tail" }, { Note = "Right tail" }
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 1 and conflicts[1].insertion)
merged = Merge:Routes(base, left, right, { "both" })
assert(#merged.steps == 5 and merged.steps[4].Note == "Left tail" and merged.steps[5].Note == "Right tail")
merged, conflicts = Merge:Routes(base, left, right, { { custom = true, value = { { Note = "Combined manually" } } } })
assert(conflicts[1].resolved and #merged.steps == 4 and merged.steps[4].Note == "Combined manually")
_, conflicts = Merge:Routes(base, left, right, { { custom = true, value = "not a step list" } })
assert(not conflicts[1].resolved, "Manual structural corrections require a list of tables")

-- Parallel groups, metadata, nested fields and explicit false values merge too.
base.conditions = { HasSpell = 1 }
base.XPConsumables = true
base.parallelSteps = { { conditions = { HasSpell = 2 }, steps = { { Note = "Parallel" } } } }
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
left.XPConsumables = false
left.parallelSteps[1].conditions.HasSpell = 3
right.conditions.HasSpell = 4
right.parallelSteps[1].steps[1].Note = "Recorded parallel"
merged, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 0 and merged.XPConsumables == false and merged.conditions.HasSpell == 4)
assert(merged.parallelSteps[1].conditions.HasSpell == 3 and merged.parallelSteps[1].steps[1].Note == "Recorded parallel")

-- Ordered options are atomic; merging quest-objective arrays as maps is unsafe.
base.steps[1].Done = { 10 }
left, right = AprRC:CopyData(base), AprRC:CopyData(base)
left.steps[1].Done, right.steps[1].Done = { 10, 11 }, { 10, 12 }
_, conflicts = Merge:Routes(base, left, right)
assert(#conflicts == 1 and conflicts[1].path == "route.steps[1].Done")

-- Bounded diff handles wholesale rewrites without unbounded quadratic work.
local large = route({})
for i = 1, 250 do large.steps[i] = { Waypoint = i } end
left, right = AprRC:CopyData(large), AprRC:CopyData(large)
for i = 1, 250 do left.steps[i].Waypoint = i + 1000 end
right.steps[251] = { Note = "Latest capture" }
_, conflicts = Merge:Routes(large, left, right)
assert(#conflicts == 1 and #conflicts[1].right == 251)

-- Exercise rebase and commit against the real model, including draft reloads.
local previousData = AprRCData
local live = route({ { Note = "Baseline" }, { Waypoint = 2 } })
AprRCData = { CurrentRoute = live, Routes = { live }, QuestLookup = {} }
local session = Model:Open(live)
session.draft.steps[1].Note = "Correction"; session:Snapshot()
live.steps[3] = { Note = "Last hour of work" }
local plan = assert(session:MergePlan())
assert(#plan.conflicts == 0)
assert(session:ApplyMerge(plan, {}, false))
assert(session:IsDirty() and not session:IsStale() and #session.draft.steps == 3)
assert(live.steps[1].Note == "Baseline", "Rebase must not commit the draft")
assert(session:Undo(-1) and not session:IsDirty() and #session.draft.steps == 3)
assert(session:Undo(1) and session:IsDirty())
local restored = Model:Open(live)
assert(restored.draft.steps[1].Note == "Correction" and #restored.draft.steps == 3)
assert(restored:Save() and #AprRCData.CurrentRoute.steps == 3)

-- A preview is only applicable to its exact source and draft.
live = AprRCData.CurrentRoute
session = Model:Open(live)
session.draft.steps[1].Note = "Another correction"; session:Snapshot()
plan = assert(session:MergePlan())
live.steps[4] = { Note = "Arrived during resolution" }
local ok, reason = session:ApplyMerge(plan, {}, true)
assert(not ok and reason == "changed" and #live.steps == 4)
plan = assert(session:MergePlan())
session.draft.steps[2].Note = "Edited during resolution"; session:Snapshot()
ok, reason = session:ApplyMerge(plan, {}, true)
assert(not ok and reason == "changed")
session.raw = "{ steps = { -- incomplete"; session:Persist()
assert(not session:MergePlan(), "Merge must not bypass Lua validation")
session:Reload()
local archived = Model:History(live.name)
local rawVersion = archived[#archived]
assert(rawVersion.raw == "{ steps = { -- incomplete")
local recovered, recoverySession = Model:RecoveryCopy(live.name, rawVersion)
assert(recovered.name ~= live.name and recoverySession.raw == rawVersion.raw)
assert(AprRCData.CurrentRoute == live and #live.steps == 4)
assert(AprRCData.EditorDrafts[recovered.name].raw == rawVersion.raw)

-- Force-save's recovery survives opening this route or another route afterward.
session.draft.steps = { { Note = "Replacement" } }; session:Snapshot()
assert(session:Save(true))
local backup = AprRCData.BackupRoute
Model:Open(AprRCData.CurrentRoute)
Model:Open(recovered)
assert(AprRCData.BackupRoute == backup and #backup == 4)
local kept = false
for _, version in ipairs(Model:History(live.name)) do
    if #version.route.steps == 4 and version.route.steps[3].Note == "Last hour of work" then kept = true end
end
assert(kept, "Recording recovery was overwritten by opening another editor session")
-- Manual corrections go through route validation before mutating either side.
local manual = route({ { Range = 1, Note = "Initial" } })
local mergeFixture = AprRCData
AprRCData = { CurrentRoute = manual, Routes = { manual }, QuestLookup = {} }
local manualSession = Model:Open(manual)
manualSession.draft.steps[1].Range = 2; manualSession:Snapshot()
manual.steps[1].Range = 3
local manualPlan = assert(manualSession:MergePlan())
ok, reason = manualSession:ApplyMerge(manualPlan, { { custom = true, value = "invalid range" } }, true)
assert(not ok and reason and manual.steps[1].Range == 3 and manualSession.draft.steps[1].Range == 2)
assert(manualSession:ApplyMerge(manualPlan, { { custom = true, value = 4 } }, false))
assert(manualSession.draft.steps[1].Range == 4 and manual.steps[1].Range == 3 and manualSession:IsDirty())
-- Preserve the recovery fixture used by the remaining history checks.
AprRCData = mergeFixture
-- Adding a parallel group shifts display indexes, not existing step identities.
local parallel = { name = "2393-Parallel identities", steps = { { Note = "Main" } },
    parallelSteps = { { conditions = {}, steps = { { Note = "A" }, { Note = "B" } } } } }
table.insert(AprRCData.Routes, parallel)
local groupSession = Model:Open(parallel)
groupSession:InsertGroup()
assert(groupSession:MoveGroup(2, 1))
groupSession.draft.parallelSteps[1].steps = { { Note = "X" }, { Note = "Y" }, { Note = "Z" } }
assert(groupSession:Insert({ Note = "Manual parallel insertion" }, 0, 2))
groupSession.draft.parallelSteps[2].steps[2].Note = "Manual parallel A"; groupSession:Snapshot()
parallel.parallelSteps[1].steps[2].Note = "Recorded parallel B"
local groupPlan = assert(groupSession:MergePlan())
assert(#groupPlan.conflicts == 0, "Shifted group positions must not create a false step conflict")
assert(groupSession:ApplyMerge(groupPlan, {}, false))
assert(groupSession.draft.parallelSteps[2].steps[1].Note == "Manual parallel insertion")
assert(groupSession.draft.parallelSteps[2].steps[2].Note == "Manual parallel A")
assert(groupSession.draft.parallelSteps[2].steps[3].Note == "Recorded parallel B")
for i = 1, 50 do Model:Archive(live.name, route({ { Note = tostring(i) } }), "Before save") end
assert(#Model:History(live.name) == 40 and #Model:History(recovered.name) == 0)
AprRCData = previousData
print("Three-way route merges, structural conflicts, rebases and per-route recovery passed.")
