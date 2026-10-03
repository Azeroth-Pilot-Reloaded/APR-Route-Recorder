local E = AprRC.routeEditor
E:Show()
local route = assert(AprRC.editorModel:NewRoute("Overwrite UI"))
route.steps = { { Note = "Original" } }
E:RefreshRoutes()
E:SelectRoute(route.name)
E.session.draft.steps[1].Note = "Draft to keep"
E.session:Snapshot()
route.steps[1].Note = "Background edit"
route.steps[2] = { Note = "Background capture" }
E.saveButton:Fire("OnClick")
assert(route.steps[2] and E.session:IsDirty() and E.mergeDialog, "Normal save must open conflict resolution")
local modifier = IsModifierKeyDown
IsModifierKeyDown = function() return true end
E.saveButton:Fire("OnClick")
IsModifierKeyDown = modifier
assert(E.mergeDialog and #route.steps == 2, "Modifiers must not bypass conflict resolution")
E.mergeLeftButton:Fire("OnClick")
E.mergeApplyButton:Fire("OnClick")
local saved = AprRC.editorModel:Source(route.name)
assert(#saved.steps == 2 and saved.steps[1].Note == "Draft to keep" and saved.steps[2].Note == "Background capture")
assert(not E.session:IsDirty() and not E.session:IsStale())
TestCloseWorkshop()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Save button conflict resolution preserves background recording; modifiers cannot overwrite it.")
