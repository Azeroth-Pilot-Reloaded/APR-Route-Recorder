local E = AprRC.routeEditor
E:Show()
local route = assert(AprRC.editorModel:NewRoute("Overwrite UI"))
route.steps = { { Note = "Original" } }
E:RefreshRoutes()
E:SelectRoute(route.name)
E.session.draft.steps[1].Note = "Draft to keep"
E.session:Snapshot()
route.steps[2] = { Note = "Background capture" }
E.saveButton:Fire("OnClick")
assert(route.steps[2] and E.session:IsDirty(), "Normal save must retain the conflict guard")
local modifier = IsModifierKeyDown
IsModifierKeyDown = function() return true end
E.saveButton:Fire("OnClick")
IsModifierKeyDown = modifier
local saved = AprRC.editorModel:Source(route.name)
assert(#saved.steps == 1 and saved.steps[1].Note == "Draft to keep")
assert(not E.session:IsDirty() and not E.session:IsStale())
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Save button modifier overwrite and ordinary conflict protection passed.")
