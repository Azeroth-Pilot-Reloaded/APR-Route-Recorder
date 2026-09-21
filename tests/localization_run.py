"""Check every bundled locale without allowing fallback to hide missing strings."""
from pathlib import Path
import re
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def run():
    locales = {}
    for path in sorted((ROOT / "locales").glob("*.lua")):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("Values = {}; LibStub = function() return { NewLocale = function() return Values end } end")
        lua.execute(path.read_text(encoding="utf-8"), name=str(path))
        locales[path.stem] = {key: value for key, value in lua.globals().Values.items() if isinstance(value, str)}
    english = locales["enUS"]
    for locale, strings in locales.items():
        assert strings.keys() == english.keys(), (locale, english.keys() - strings.keys())
        for key, value in strings.items():
            assert value.strip() and "\ufffd" not in value and "ZXQ" not in value, (locale, key)
            assert re.findall(r"%[sd]", value) == re.findall(r"%[sd]", english[key]), (locale, key)
    for folder in ("core", "config", "commands", "recording", "utils", "ui"):
        for path in (ROOT / folder).rglob("*.lua"):
            source = path.read_text(encoding="utf-8")
            for key in re.findall(r'\bL\["([^"\n]+)"\]|\bT\("([^"\n]+)"\)', source):
                literal = key[0] or key[1]
                assert literal in english, (path, literal)
    print(f"Localization coverage and format parameters passed: {len(english)} strings in {len(locales)} locales.")


if __name__ == "__main__":
    run()
