local E = AprRC.routeEditor
local route = assert(AprRC.editorModel:NewRoute("Step keyboard"))
for index = 1, 45 do route.steps[index] = { Note = index % 2 == 0 and "Match" or "Other" } end
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
if E.compact then E:ToggleCompact() end
local function press(key)
    local frame = E.stepsSplit.frame
    frame:GetScript("OnKeyDown")(frame, key)
    return not frame.propagateKeyboardInput
end
assert(press("DOWN") and E.session.selected == 2)
assert(press("UP") and E.session.selected == 1)
E:SelectStep(40)
assert(press("DOWN") and E.session.selected == 41 and E.page == 2)
assert(press("UP") and E.session.selected == 40 and E.page == 1)
E.query = "Match"; E:DrawList()
assert(press("DOWN") and E.session.selected == 42 and E.query == "Match")
assert(press("UP") and E.session.selected == 40)
E:ToggleCompact(); E:ShowStepPane("list")
assert(press("LEFT") and E.compactPane == "inspector")
E.moveTo:SetFocus()
assert(not press("RIGHT") and E.compactPane == "inspector")
assert(not press("DOWN") and E.session.selected == 40)
E.moveTo:ClearFocus()
assert(press("RIGHT") and E.compactPane == "list", "Right: " .. tostring(E.compactPane) .. "/" .. tostring(E.moveTo.editbox:HasFocus()))
assert(press("DOWN") and E.session.selected == 42 and E.compactPane == "list")
local oldFocus = GetCurrentKeyBoardFocus
GetCurrentKeyBoardFocus = function() return {} end
assert(not press("LEFT") and E.compactPane == "list")
GetCurrentKeyBoardFocus = oldFocus
E:ToggleCompact()
assert(not press("RIGHT") and not press("A"))
assert(not E.session:IsDirty())
local frame = E.stepsSplit.frame
E:SelectTab("route")
assert(not frame.keyboardEnabled and not frame:GetScript("OnKeyDown") and frame.propagateKeyboardInput)
TestCloseWorkshop()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Step keyboard: filtered navigation, pagination, panes, field focus and script pooling passed.")
