local previousData, previousAPRData = AprRCData, APRData
local previousCatalog, previousConfig = APR.RouteQuestStepList, APR.routeconfig
local previousTimers, previousPending = TestTimers, AprRC.pendingAPRRoutes
TestTimers, AprRC.pendingAPRRoutes = {}, nil
AprRCData = { Routes = {}, CurrentRoute = { name = "", steps = {} }, QuestLookup = {} }
APRData = { CustomRoute = {} }
local original = { label = "Original", expansion = "Midnight", category = "Leveling", mapID = 2393,
    futureMetadata = { enabled = false },
    nextRoute = { "next" }, requiredRoute = { "intro" }, XPConsumables = false,
    conditions = { Faction = "Horde" }, gameVersion = "retail",
    steps = { { PickUp = { 42 } } }, parallelSteps = { { conditions = { HasSpell = 42 }, steps = { { Note = "Parallel" } } } } }
APR.RouteQuestStepList = { original = original, legacy = { { Note = "Legacy" } } }
local notifications = 0
APR.routeconfig = { SendMessage = function() notifications = notifications + 1 end }
local route = assert(AprRC:ImportAPRRoute("original"))
assert(route.name == "original" and route.mapID == 2393 and route.XPConsumables == false)
assert(route.parallelSteps[1].steps[1]._index == 1)
route.steps[1].PickUp[1] = 43
assert(original.steps[1].PickUp[1] == 42, "Import changed the APR source")
TestRunTimers()
local key = AprRCData.APRRouteKeys[route.name]
assert(key == "original - Custom" and notifications == 1)
local saved = APRData.CustomRoute[key]
assert(saved.mapID == 2393 and saved.nextRoute[1] == "next" and saved.XPConsumables == false)
assert(saved.expansion == "Custom" and saved.label == key)
APR.RouteQuestStepList[key].steps[1].PickUp[1] = 999
assert(saved.steps[1].PickUp[1] == 43 and route.steps[1].PickUp[1] == 43)
assert(not AprRC:GetImportableAPRRoutes()[key], "Recorder copies must not feed back into import")
assert(AprRC:ImportAPRRoute("original").name == "original (2)")
assert(AprRC:ImportAPRRoute("legacy").steps[1].Note == "Legacy")
assert(not AprRC:ImportAPRRoute("missing"))
TestRunTimers()

local session = AprRC.editorModel:Open(route)
session.draft.steps[1].PickUp[1] = 44
session:Snapshot()
AprRC:RequestAPRRouteSync(route.name)
TestRunTimers()
assert(APRData.CustomRoute[key].steps[1].PickUp[1] == 43, "Uncommitted draft leaked into APR")
assert(session:Save())
TestRunTimers()
assert(APRData.CustomRoute[key].steps[1].PickUp[1] == 44)
assert(APRData.CustomRoute[key].futureMetadata.enabled == false)
-- Unknown/new fields and legacy values survive an unrelated edit, but invalid
-- new values entered in Lua must still be rejected.
local legacy = { name = "84-Legacy", steps = { { Qpart = { [42] = {} }, _future = { value = 1 }, Note = "Original" } } }
local changed = AprRC:CopyData(legacy)
changed.steps[1].Note = "Edited"
assert(AprRC:ReadRouteDefinition(AprRC:SerializeData(changed), legacy.name, legacy))
changed.steps[1].Qpart = { [42] = { -1 } }
assert(not AprRC:ReadRouteDefinition(AprRC:SerializeData(changed), legacy.name, legacy))
changed.steps[1].Qpart = legacy.steps[1].Qpart
changed.steps[1]._future.value = 2
assert(not AprRC:ReadRouteDefinition(AprRC:SerializeData(changed), legacy.name, legacy))
local count = notifications
AprRC:RequestAPRRouteSync(route.name)
AprRC:RequestAPRRouteSync(route.name)
TestRunTimers()
assert(notifications == count, "Unchanged routes must not refresh APR")

-- CurrentRoute can be a detached SavedVariables table after reload.
AprRCData.CurrentRoute = AprRC:CopyData(AprRCData.Routes[1])
AprRC:GetLastStep().Note = "Recorded in place"
TestRunTimers()
assert(APRData.CustomRoute[key].steps[1].Note == "Recorded in place")
local activeSession = AprRC.editorModel:Open(AprRCData.CurrentRoute)
activeSession.draft.steps[1].Note = "Saved active route"
assert(activeSession:Save())
TestRunTimers()
assert(APRData.CustomRoute[key].steps[1].Note == "Saved active route")

-- Startup republishes every saved route without needing the workshop.
APRData.CustomRoute, APR.RouteQuestStepList = {}, { original = original }
local previousRegister = AprRC.RegisterEvent
function AprRC:RegisterEvent(event, callback) assert(event == "PLAYER_LOGOUT" and callback == "FlushAPRRouteSync") end
AprRC:InitializeAPRRouteSync()
AprRC.RegisterEvent = previousRegister
TestRunTimers()
for _, entry in ipairs(AprRCData.Routes) do assert(APRData.CustomRoute[AprRCData.APRRouteKeys[entry.name]]) end

-- An existing manual custom route is never silently overwritten.
APRData.CustomRoute["84-Collision - Custom"] = { steps = { { Note = "Keep" } } }
local collision = assert(AprRC.editorModel:NewRoute("84-Collision"))
TestRunTimers()
assert(APRData.CustomRoute["84-Collision - Custom"].steps[1].Note == "Keep")
assert(AprRCData.APRRouteKeys[collision.name] == "84-Collision - Custom (Recorder 2)")

APR.RouteQuestStepList.delve = { label = "Delve", scenarios = {
    { scenarioID = 2311, steps = { { Note = "Scenario" } } } } }
local delve = assert(AprRC:ImportAPRRoute("delve"))
assert(delve.delve and delve.scenarios[1].steps[1].Note == "Scenario")
assert(AprRC.editorModel:Open(delve):Save())
TestRunTimers()
assert(APRData.CustomRoute[AprRCData.APRRouteKeys.delve].scenarios[1].scenarioID == 2311)

AprRCData, APRData = previousData, previousAPRData
APR.RouteQuestStepList, APR.routeconfig = previousCatalog, previousConfig
TestTimers, AprRC.pendingAPRRoutes = previousTimers, previousPending
print("APR import, automatic publication, drafts, collisions and playback isolation passed.")
