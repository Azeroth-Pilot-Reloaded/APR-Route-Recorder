local E, Model = AprRC.routeEditor, AprRC.editorModel
local oldTime, oldFollow, oldAPRFollow = GetTime, E.follow, AprRC.settings.profile.followAPR
local oldRecording = AprRC.settings.profile.recordBarFrame.isRecording
local oldActive, oldPlayer, oldData, oldGetSteps = APR.ActiveRoute, APR.PlayerID, APRData, APR.GetRouteSteps
local now = 0
GetTime = function() return now end
local route = assert(Model:NewRoute("Periodic follow"))
for index = 1, 50 do route.steps[index] = { Note = "Step " .. index, _index = index } end
AprRCData.CurrentRoute = route
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow, AprRC.settings.profile.followAPR = true, false
AprRC.settings.profile.recordBarFrame.isRecording = true
now = 5
E:Tick(true)
assert(E:SelectedStep() == 50)
E:SelectStep(2)
now = 9; E:Tick()
assert(E:SelectedStep() == 2)
now = 10; E:Tick()
assert(E:SelectedStep() == 50 and E.page == 2)

-- Editing latches the pause, including undoing back to the saved data.
E:SelectStep(2)
E.session.draft.steps[2].Note = "Edited"
E:Changed()
now = 15; E:Tick()
assert(E:SelectedStep() == 2 and E.session.followPaused)
E:Undo(-1)
assert(not E.session:IsDirty() and E.session.followPaused)
E:SelectStep(2)
now = 20; E:Tick()
assert(E:SelectedStep() == 2)
assert(E:Save())
now = 25; E:Tick()
assert(E:SelectedStep() == 50 and not E.session.followPaused)

TestRunTimers()
local key = assert(AprRCData.APRRouteKeys[route.name])
local definition = APR.RouteQuestStepList[key]
APR.ActiveRoute, APR.PlayerID = key, "periodic-follow"
APRData = { [APR.PlayerID] = { [key] = 41 } }
APR.GetRouteSteps = function() return definition.steps end
AprRC.settings.profile.followAPR = true
E:Tick(true)
assert(E:SelectedStep() == 41)
E:SelectStep(3)
now = 29; E:Tick()
assert(E:SelectedStep() == 3)
now = 30; E:Tick()
assert(E:SelectedStep() == 41)
E:SelectStep(3); E.moveTo:SetFocus()
now = 35; E:Tick()
assert(E:SelectedStep() == 3)
E.moveTo:ClearFocus()
now = 40; E:Tick()
assert(E:SelectedStep() == 41)

-- A selected step can be scrolled out of view without changing selection.
E.list:SetScroll(1000)
now = 45; E:Tick()
assert(E.list.localstatus.scrollvalue == 0)
TestCloseWorkshop()
GetTime, E.follow, AprRC.settings.profile.followAPR = oldTime, oldFollow, oldAPRFollow
AprRC.settings.profile.recordBarFrame.isRecording = oldRecording
APR.ActiveRoute, APR.PlayerID, APRData, APR.GetRouteSteps = oldActive, oldPlayer, oldData, oldGetSteps
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Five-second capture/APR recentering, edit pause through undo, save resume and focused controls passed.")
