"""Run recorder regression tests with Python and lupa (Lua 5.1)."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/stubs.lua").read_text(encoding="utf-8"))
for name in ("utils/Utils.lua", "utils/LuaData.lua", "utils/Coordinates.lua", "core/RouteManagement.lua", "core/RouteDefinition.lua"):
    lua.execute((ROOT / name).read_text(encoding="utf-8"))
for name in ("commands/Registry.lua", "commands/Schema.lua"):
    if (ROOT / name).exists():
        lua.execute((ROOT / name).read_text(encoding="utf-8"))
for name in sorted((ROOT / "commands/options").glob("*.lua")):
    lua.execute(name.read_text(encoding="utf-8"))
for name in ("commands/Commands.lua", "commands/UseItem.lua", "recording/Session.lua", "recording/Events.lua", "recording/Merchant.lua",
             "recording/Chromie.lua", "recording/Treasure.lua", "recording/Flight.lua", "recording/DroppedQuest.lua"):
    lua.execute((ROOT / name).read_text(encoding="utf-8"))
for name in sorted((ROOT / "tests").glob("*_test.lua")):
    lua.execute(name.read_text(encoding="utf-8"))
for folder in ("core", "config", "commands", "recording", "utils", "ui", "data"):
    for name in (ROOT / folder).rglob("*.lua"):
        result = lua.globals().loadstring(name.read_text(encoding="utf-8"), str(name))
        if isinstance(result, tuple):
            raise AssertionError(result[1])
for line in (ROOT / "APR-Recorder.toc").read_text(encoding="utf-8").splitlines():
    if line and not line.startswith("#"):
        assert (ROOT / line).is_file(), line
print("Regression tests, Lua 5.1 syntax and TOC paths passed.")
