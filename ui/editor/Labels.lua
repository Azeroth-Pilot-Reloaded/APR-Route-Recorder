local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.editorUI = {}
local UI = AprRC.editorUI

-- Dynamic names (routes, constants and game data) keep their original text.
function UI.Text(key) return rawget(L, key) or key end

function UI.Label(key)
    local label = rawget(L, "FIELD_" .. tostring(key))
    if label then return label end
    local base, number = tostring(key):match("^(ExtraLineText)(%d+)$")
    if not base then base, number = tostring(key):match("^(TrigText)(%d+)$") end
    if base then return UI.Label(base) .. " " .. number end
    return UI.Text(tostring(key):gsub("(%l)(%u)", "%1 %2"))
end
