"""Run workspace callbacks against bundled AceGUI and a small native frame stub."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def run():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def load(path):
        lua.execute((ROOT / path).read_text(encoding="utf-8"), name=str(path))

    load("tests/stubs.lua")
    load("tests/ui_runtime.lua")
    load("libs/LibStub/LibStub.lua")
    load("libs/AceLocale-3.0/AceLocale-3.0.lua")
    lua.execute('LibStub("AceLocale-3.0"):NewLocale("APR", "enUS", true, true)')
    load("locales/enUS.lua")
    load("locales/frFR.lua")
    for path in ("utils/Utils.lua", "utils/LuaData.lua", "utils/Coordinates.lua", "core/RouteManagement.lua",
                 "core/RouteDefinition.lua", "commands/Registry.lua", "commands/Schema.lua", "recording/Session.lua"):
        load(path)
    for path in sorted((ROOT / "commands/options").glob("*.lua")):
        load(path)
    load("libs/AceGUI-3.0/AceGUI-3.0.lua")
    for name in ("Container-Frame", "Container-SimpleGroup", "Container-InlineGroup", "Container-ScrollFrame",
                 "Container-TabGroup", "Widget-Label", "Widget-Heading", "Widget-Button", "Widget-CheckBox",
                 "Widget-EditBox", "Widget-MultiLineEditBox", "Widget-DropDown", "Widget-DropDown-Items"):
        load("libs/AceGUI-3.0/widgets/AceGUI" + name + ".lua")
    for name in ("Model", "Labels", "Widgets", "Forms", "Workspace", "Views"):
        load("ui/editor/" + name + ".lua")
    load("ui/dialogs/ExportRoute.lua")
    lua.execute('''
        local window = LibStub:NewLibrary("LibWindow-1.1", 999)
        function window.RegisterConfig(frame, config) frame.windowConfig = config end
        function window.RestorePosition(frame) frame.restored = true end
        function window.SavePosition(frame) frame.positionSaved = true end
        APR.settings = { profile = {}, ToggleAddon = function() end }
        AprRC.settings.profile.commandBarFrame = { position = {} }
    ''')
    load("ui/bars/CommandsBar.lua")
    load("ui/bars/CommandsBarSetting.lua")
    lua.execute('AprRC.CommandBar:OnInit()')
    load("tests/ui_smoke.lua")
    load("ui/bars/RecorderBar.lua")
    load("tests/recorder_button_smoke.lua")
    load("tests/commands_bar_smoke.lua")
    load("tests/compact_ui_smoke.lua")
    load("tests/workshop_controls_smoke.lua")


if __name__ == "__main__":
    run()
