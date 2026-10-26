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
            # Lossy shell encodings replace Unicode characters with literal '?'.
            # Preserve normal question punctuation while rejecting damaged words.
            assert not re.search(r"\?{2,}|\w\?[\w-]", value), (locale, key, "Damaged Unicode translation")
            assert re.findall(r"%[sd]", value) == re.findall(r"%[sd]", english[key]), (locale, key)
    for folder in ("core", "config", "commands", "recording", "utils", "ui"):
        for path in (ROOT / folder).rglob("*.lua"):
            source = path.read_text(encoding="utf-8")
            for key in re.findall(r'\bL\["([^"\n]+)"\]|\bT\("([^"\n]+)"\)|\bAprRC:APRText\("([^"\n]+)"\)', source):
                literal = next(part for part in key if part)
                assert literal in english, (path, literal)
            # Shared catalog lookups must use APRText; dynamic route-text
            # lookups remain optional through rawget or iteration.
            for alias in re.findall(r'local\s+(\w+)\s*=\s*LibStub\("AceLocale-3.0"\):GetLocale\("APR"\)', source):
                assert not re.search(r'\b' + alias + r'\s*(?:\[|\.\w+)', source), (path, "Unprotected APR locale lookup")
    print(f"Localization coverage and format parameters passed: {len(english)} strings in {len(locales)} locales.")
    run_shared_ui()


def run_shared_ui():
    """Exercise settings/minimap callbacks with real, non-silent AceLocale."""
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path):
        lua.execute((ROOT / path).read_text(encoding="utf-8"), name=str(path))

    load("tests/stubs.lua")
    lua.execute('''
        LibStub = nil
        GetLocale = function() return "frFR" end
        LocaleErrors = {}
        geterrorhandler = function() return function(message) LocaleErrors[#LocaleErrors + 1] = message end end
    ''')
    load("libs/LibStub/LibStub.lua")
    load("libs/AceLocale-3.0/AceLocale-3.0.lua")
    lua.execute('LibStub("AceLocale-3.0"):NewLocale("APR", "enUS", true)')
    load("locales/enUS.lua")
    load("locales/frFR.lua")
    load("utils/Utils.lua")
    lua.execute('''
        local config = LibStub:NewLibrary("AceConfig-3.0", 1)
        function config:RegisterOptionsTable(name, options) if name == AprRC.title then TestOptions = options end end
        local dialog = LibStub:NewLibrary("AceConfigDialog-3.0", 1)
        function dialog:AddToBlizOptions() return {} end
        local profiles = LibStub:NewLibrary("AceDBOptions-3.0", 1)
        function profiles:GetOptionsTable() return {} end
        local broker = LibStub:NewLibrary("LibDataBroker-1.1", 1)
        function broker:NewDataObject(_, object) TestBroker = object; return object end
        local icons = LibStub:NewLibrary("LibDBIcon-1.0", 1)
        function icons:Register() end
        Settings = { RegisterCanvasLayoutCategory = function() return {} end }
        CLOSE = "Fermer"
        AprRC.title, AprRC.version = "Recorder", "test"
        AprRC.discord, AprRC.github = "discord", "github"
        AprRC.Color = { white = {1, 1, 1} }
        AprRC.textStyle = { CreateOptions = function() return {} end }
        local recorder = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
        AprRC.editorUI = { Text = function(key) return recorder[key] end }
        function AprRC:AddTooltipLine(tooltip, text) tooltip[#tooltip + 1] = text end
        APR.questionDialog = {
            CreateEditBoxPopup = function(_, text, close) TestPopup = {text, close} end,
            CreateQuestionPopup = function(_, text) TestConfirmation = text end,
        }
    ''')
    load("config/Settings.lua")
    load("tests/shared_localization_smoke.lua")


if __name__ == "__main__":
    run()
