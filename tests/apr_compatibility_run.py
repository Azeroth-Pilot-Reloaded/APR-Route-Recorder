"""Exercise real APR routes and its registration API from a neighboring checkout.

Usage: python tests/apr_compatibility_run.py [path/to/azeroth-pilot-reloaded]
Game coordinate conversion is stubbed; this checks data integration, not navigation.
"""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
APR_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "azeroth-pilot-reloaded"
lua = LuaRuntime(unpack_returned_tuples=True)


def load(path):
    lua.execute(path.read_text(encoding="utf-8-sig"), name=str(path))


load(ROOT / "tests/stubs.lua")
load(APR_ROOT / "APR-Core/data/models/Enums.lua")
load(APR_ROOT / "APR-Core/data/models/Classes.lua")
for name in ("utils/Utils.lua", "utils/LuaData.lua", "core/RouteManagement.lua", "core/RouteDefinition.lua",
             "core/APRIntegration.lua", "commands/Registry.lua", "commands/Schema.lua"):
    load(ROOT / name)
for path in (ROOT / "commands/options").glob("*.lua"):
    load(path)
load(ROOT / "ui/editor/Merge.lua")
load(ROOT / "ui/editor/Model.lua")
load(APR_ROOT / "APR-Core/utils/RouteUtils.lua")
lua.execute('function APR:NewModule() return {} end')
load(APR_ROOT / "APR-Core/features/navigation/WorldCoordinateConverter.lua")
lua.execute('''
APR.RouteQuestStepList = {}
APRData = { CustomRoute = {} }
APR.worldCoordinateConverter.ConvertMapCoordinate = function() return { x = 1, y = 2 } end
''')
for name in ("Routes/Midnight/Midnight-Speedrun-alt.lua", "Routes/Midnight/Midnight-Eversong-Woods.lua", "Routes/delves.lua"):
    load(APR_ROOT / name)
for path in sorted((APR_ROOT / "Routes/Forever").glob("*.lua")):
    load(path)
lua.execute('''
local entries = AprRC:GetImportableAPRRoutes()
local count = 0
local function SameStepData(a, b)
    if type(a) ~= type(b) then return false end
    -- Indexes are regenerated; Lua 5.1's tostring rounds the final coordinate digits.
    if type(a) == "number" then return math.abs(a - b) <= 0.00000001 end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if key ~= "_index" and not SameStepData(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if key ~= "_index" and a[key] == nil then return false end
    end
    return true
end
for key in pairs(entries) do
    local source = AprRC:CopyData(APR.RouteQuestStepList[key])
    local expected = AprRC:NormalizeRouteClasses(AprRC:CopyData(source))
    local route = assert(AprRC:ImportAPRRoute(key))
    local session = AprRC.editorModel:Open(route)
    session.raw = session.raw or AprRC.editorModel:RouteText(session.draft)
    assert(session:Save())
    -- Exercise validation of an actual raw edit while retaining legacy fields.
    local edited = AprRC:CopyData(session.draft)
    edited.label = edited.label .. " (edited)"
    session.raw = AprRC.editorModel:RouteText(edited)
    assert(session:Save())
    TestRunTimers()
    assert(AprRC:DeepCompare(source, APR.RouteQuestStepList[key]), "Import mutated its source")
    local saved = APRData.CustomRoute[AprRCData.APRRouteKeys[route.name]]
    assert(#saved.steps == #(source.steps or {}))
    assert(SameStepData(saved.steps or {}, expected.steps or {}), "Editor changed step data for " .. key)
    assert(SameStepData(saved.parallelSteps or {}, expected.parallelSteps or {}), "Editor changed parallel steps for " .. key)
    for index, step in ipairs(source.steps or {}) do
        assert(saved.steps[index].SkipForPrimaryProfessions == step.SkipForPrimaryProfessions)
    end
    assert(AprRC:DeepCompare(saved.scenarios, expected.scenarios))
    assert(saved.mapID == source.mapID)
    assert(AprRC:DeepCompare(saved.nextRoute, expected.nextRoute))
    -- Imported legacy fields also survive concurrent recording and a rebase.
    session.draft.label = session.draft.label .. " (merged)"
    session:Snapshot()
    route = AprRC:FindRouteByName(route.name)
    route.steps[#route.steps + 1] = { Note = "Captured while editing an APR import" }
    AprRC:NotifyRouteChanged(route.name)
    local plan = assert(session:MergePlan())
    assert(#plan.conflicts == 0 and session:ApplyMerge(plan, {}, false))
    assert(session:IsDirty() and not session:IsStale())
    assert(session:Save())
    TestRunTimers()
    local merged = AprRC:FindRouteByName(route.name)
    assert(#merged.steps == #(source.steps or {}) + 1)
    for index, step in ipairs(expected.steps or {}) do
        assert(SameStepData(merged.steps[index], step), "Merge changed legacy step data for " .. key)
    end
    assert(SameStepData(merged.parallelSteps or {}, expected.parallelSteps or {}))
    count = count + 1
end
APR.RouteQuestStepList = {}
APR:LoadCustomRoutes()
for key, saved in pairs(APRData.CustomRoute) do
    local restored = APR.RouteQuestStepList[key]
    assert(restored.mapID == saved.mapID)
    assert(AprRC:DeepCompare(restored.parallelSteps, saved.parallelSteps))
    assert(AprRC:DeepCompare(restored.scenarios, saved.scenarios))
    assert(AprRC:DeepCompare(restored.nextRoute, saved.nextRoute))
end
print("Real APR routes: import, save, edit, automatic publication and reload passed for " .. count .. " routes.")
''')

load(APR_ROOT / "APR-Core/utils/RouteManager.lua")
load(APR_ROOT / "APR-Core/utils/StepUtils.lua")
lua.execute('''
APR.IsRouteCompatibleWithClient = function() return true end
APR.IsDelveRoute = function() return false end
APR.AreConditionalFiltersMet = function() return false end
APR.ActiveRoute, APR.PlayerID = "playback", "playback-test"
local route = { steps = { { Note = "Main 1", _index = 1 }, { Note = "Main 2", _index = 2 } },
    parallelSteps = { { conditions = {}, steps = {} },
        { conditions = {}, steps = { { Note = "Parallel", _index = 1 } } } } }
APR.RouteQuestStepList.playback = route
AprRCData.APRRouteKeys["Recorder playback"] = "playback"
APRData[APR.PlayerID] = { playback = 2,
    ["playback-ParallelStepsState"] = { groups = { [1] = { activationOrder = 1, effectiveBeforeIndex = 2 } } } }
local index, group = AprRC:GetAPRPlaybackSelection("Recorder playback")
assert(index == 1 and group == 2, "Real APR insertion must map back to the original parallel group")
local runtime = APR:GetStep(2)
runtime.Note = "Navigation runtime copy"
index, group = AprRC:GetAPRPlaybackSelection("Recorder playback")
assert(index == 1 and group == 2, "Runtime playback mutations must not affect following")
APRData[APR.PlayerID].playback = 3
index, group = AprRC:GetAPRPlaybackSelection("Recorder playback")
assert(index == 2 and group == nil, "Main indexes must not include inserted parallel steps")
APR.ActiveRoute = "legacy-playback"
APR.RouteQuestStepList[APR.ActiveRoute] = { { Note = "Legacy 1" }, { Note = "Legacy 2" } }
APRData[APR.PlayerID][APR.ActiveRoute] = 2
index, group = AprRC:GetAPRPlaybackSelection(APR.ActiveRoute)
assert(index == 2 and group == nil)
print("Real APR playback: effective indexes, empty/active parallel groups, runtime copies and legacy routes passed.")
''')
