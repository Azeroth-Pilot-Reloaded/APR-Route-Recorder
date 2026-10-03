local E, Model = AprRC.routeEditor, AprRC.editorModel
local previousAPRData, previousCatalog = APRData, APR.RouteQuestStepList
local previousActive, previousPlayer, previousGetSteps = APR.ActiveRoute, APR.PlayerID, APR.GetRouteSteps
local previousFollow, previousSetting = E.follow, AprRC.settings.profile.followAPR
local route = assert(Model:NewRoute("Follow APR playback"))
for index = 1, 85 do route.steps[index] = { Note = "Main " .. index, _index = index } end
route.parallelSteps = { { conditions = {}, steps = {} } }
for index = 1, 45 do route.parallelSteps[1].steps[index] = { Note = "Parallel " .. index, _index = index } end
AprRCData.CurrentRoute = route
TestRunTimers()
local key = assert(AprRCData.APRRouteKeys[route.name])
APRData = AprRC:CopyData(APRData)
APR.RouteQuestStepList = AprRC:CopyData(APR.RouteQuestStepList)
local definition = APR.RouteQuestStepList[key]
local effective = { definition.steps[1], definition.parallelSteps[1].steps[1], definition.steps[2],
    definition.steps[41], definition.parallelSteps[1].steps[41] }
APR.ActiveRoute, APR.PlayerID = key, "follow-test"
APRData[APR.PlayerID] = { [key] = 4 }
APR.GetRouteSteps = function(_, requested) assert(requested == APR.ActiveRoute); return effective end
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow, AprRC.settings.profile.followAPR = false, false
E.session.selected = 1
E:Tick()
assert(E.session.selected == 1, "APR following must be opt-in")
E.followAPRCheckbox:Fire("OnValueChanged", true)
assert(AprRC.settings.profile.followAPR and E.session.selected == 41 and E.page == 2)
assert(E.tab == "steps" and not E.session:IsDirty())

-- APR's second effective step belongs to the parallel group, despite _index = 1.
APRData[APR.PlayerID][key] = 2
E:Tick()
assert(E.tab == "parallel" and E.session.parallelGroup == 1 and E.session.parallelSelected == 1)
APRData[APR.PlayerID][key] = 5
E:Tick()
assert(E.tab == "parallel" and E.session.parallelSelected == 41 and E.page == 2)
APRData[APR.PlayerID][key] = 3
E:Tick()
assert(E.tab == "steps" and E.session.selected == 2 and E.page == 1)

-- APR following takes precedence over following the latest recording.
E.follow = true
E:Tick(true)
assert(E.session.selected == 2, "Recording follow displaced APR's current step")
E.follow = false

-- Clean focused controls and unsaved drafts must not be interrupted.
E.moveTo.editbox:SetFocus()
APRData[APR.PlayerID][key] = 4
E:Tick()
assert(E.session.selected == 2)
E.moveTo.editbox:ClearFocus()
E:Tick()
assert(E.session.selected == 41)
E.session.draft.steps[41].Note = "Unsaved edit"
E:Changed()
APRData[APR.PlayerID][key] = 2
E:Tick()
assert(E.tab == "steps" and E.session.selected == 41 and E.session.draft.steps[41].Note == "Unsaved edit")
E.session:Reload(); E:Tick()
assert(E.tab == "parallel" and E.session.parallelSelected == 1)

E:SelectTab("lua")
APRData[APR.PlayerID][key] = 4
E.luaBox.editBox:SetFocus()
E:Tick(); TestRunTimers()
local range = E.luaStepPositions.steps[41]
assert(E.tab == "lua" and E.luaBox.editBox:GetCursorPosition() == range.start)
assert(E.luaBox.scrollFrame:GetVerticalScroll() > 0 and not E.session:IsDirty())
local selectedLua = assert(AprRC:ParseLuaData(E.luaBox:GetText():sub(range.start + 1, range.finish)))
assert(selectedLua.Note == "Main 41")
APRData[APR.PlayerID][key] = 5
E:Tick(); TestRunTimers()
range = E.luaStepPositions.parallelSteps[1][41]
assert(E.tab == "lua" and E.luaBox.editBox:GetCursorPosition() == range.start)
assert(E.session.parallelSelected == 41 and not E.session:IsDirty())
local luaText, historyCount = E.luaBox:GetText(), #E.session.rawHistory
E:OpenLuaFind()
APRData[APR.PlayerID][key] = 1
local searchCursor = E.luaBox.editBox:GetCursorPosition()
E:Tick(); TestRunTimers()
assert(E.luaBox.editBox:GetCursorPosition() == searchCursor, "Searching must pause playback following")
E:CloseLuaFind(); E:Tick(); TestRunTimers()
assert(E.luaBox.editBox:GetCursorPosition() == E.luaStepPositions.steps[1].start)
assert(E.luaBox:GetText() == luaText and #E.session.rawHistory == historyCount and not E.session:IsDirty())
local raw = "{ steps = { -- unfinished"
E.luaBox:SetText(raw); E.luaBox:Fire("OnTextChanged", raw)
APRData[APR.PlayerID][key] = 4
E:Tick()
assert(E.tab == "lua" and E.session.raw == raw and E.luaBox:GetText() == raw)
E.session:Reload(); E:SelectTab("steps"); E:Tick()
assert(E.session.selected == 41)

-- A different key with the same label is not the same route.
APR.RouteQuestStepList.unrelated = { label = route.label, steps = definition.steps }
APR.ActiveRoute = "unrelated"
APRData[APR.PlayerID].unrelated = 1
E:Tick()
assert(E.session.selected == 41)
APR.ActiveRoute = key
APRData[APR.PlayerID][key] = 99
E:Tick()
assert(E.session.selected == 41, "Completed playback should not select an unrelated step")
APRData[APR.PlayerID] = nil
E:Tick()
assert(E.session.selected == 41)

-- Exact source names work for imported routes as well as published copies.
APR.ActiveRoute = route.name
APR.RouteQuestStepList[route.name] = definition
APRData[APR.PlayerID] = { [route.name] = 1 }
E:Tick()
assert(E.session.selected == 1)
TestCloseWorkshop(); E:Show()
assert(E.followAPRCheckbox:GetValue() == true, "APR follow preference must survive reopening")
E.followAPRCheckbox:Fire("OnValueChanged", false)
APRData[APR.PlayerID][route.name] = 4
E:Tick()
assert(E.session.selected == 1)
TestCloseWorkshop()
APRData, APR.RouteQuestStepList = previousAPRData, previousCatalog
APR.ActiveRoute, APR.PlayerID, APR.GetRouteSteps = previousActive, previousPlayer, previousGetSteps
E.follow, AprRC.settings.profile.followAPR = previousFollow, previousSetting
AprRC.aprPlaybackSelection = nil
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("APR step following: route identity, effective/parallel indexes, pagination, draft protection and preference passed.")
