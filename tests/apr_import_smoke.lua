local E, UI = AprRC.routeEditor, AprRC.editorUI
local original = { label = "Import source", steps = { { Note = "Original" } }, mapID = 84 }
APR.RouteQuestStepList["84-Import-source"] = original
E:Show()
local recordingRoute = AprRCData.CurrentRoute
E.importButton:Fire("OnClick")
local dialog = assert(E.importDialog)
local picker, submit
for _, child in ipairs(dialog.children) do
    if child.type == "APRSearchSelect" then picker = child end
    if child.type == "Button" and child.text:GetText() == UI.Text("Import from APR") then submit = child end
end
assert(picker and submit)
submit:Fire("OnClick") -- No selection must leave the dialog open.
assert(E.importDialog == dialog)
picker:Select("84-Import-source")
submit:Fire("OnClick")
assert(not E.importDialog and E.session.name == "84-Import-source")
assert(AprRCData.CurrentRoute == recordingRoute, "Import changed the recording target")
E.session.draft.steps[1].Note = "Edited copy"
E:Changed()
assert(E:Save())
TestRunTimers()
assert(original.steps[1].Note == "Original")
assert(APRData.CustomRoute["84-Import-source - Custom"].steps[1].Note == "Edited copy")
E.importButton:Fire("OnClick")
E:Hide()
assert(not E.importDialog, "Import dialog leaked after workshop close")
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("APR import dialog selection, draft editing, publication and close lifecycle passed.")
