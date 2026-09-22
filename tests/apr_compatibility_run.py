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
load(ROOT / "ui/editor/Model.lua")
load(APR_ROOT / "APR-Core/utils/RouteUtils.lua")
lua.execute('''
APR.RouteQuestStepList = {}
APRData = { CustomRoute = {} }
APR.worldCoordinateConverter = { ConvertMapCoordinate = function() return { x = 1, y = 2 } end }
''')
for name in ("Routes/Midnight/Midnight-Speedrun-alt.lua", "Routes/Midnight/Midnight-Eversong-Woods.lua", "Routes/delves.lua"):
    load(APR_ROOT / name)
lua.execute('''
local entries = AprRC:GetImportableAPRRoutes()
local count = 0
for key in pairs(entries) do
    local source = AprRC:CopyData(APR.RouteQuestStepList[key])
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
    assert(AprRC:DeepCompare(saved.scenarios, source.scenarios))
    assert(saved.mapID == source.mapID)
    assert(AprRC:DeepCompare(saved.nextRoute, source.nextRoute))
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
