-- Keep the public entry point used by the recorder bar, slash commands and dialogs.
AprRC.export = AprRC:NewModule("Export")

function AprRC.export:Hide()
    AprRC.routeEditor:Hide()
end

function AprRC.export.Show()
    AprRC.routeEditor:Show()
end
