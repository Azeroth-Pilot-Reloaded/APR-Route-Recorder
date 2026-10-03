local E, Model, UI = AprRC.routeEditor, AprRC.editorModel, AprRC.editorUI
local previousFollow, previousAPRFollow = E.follow, AprRC.settings.profile.followAPR
local previousControl, previousShift = IsControlKeyDown, IsShiftKeyDown
local route = assert(Model:NewRoute("Lua search"))
route.steps = { { Note = "Alpha [one]" }, { Note = "alpha [two]" } }
route.parallelSteps = { { conditions = {}, steps = { { Note = "Alpha [three]" } } } }
E.follow, AprRC.settings.profile.followAPR = false, false
E.luaFindQuery = ""
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
local widget, text, history = E.luaBox, E.luaBox:GetText(), #E.session.rawHistory
local originalKey = E.luaKeyDown
IsControlKeyDown = function() return true end
widget.editBox:GetScript("OnKeyDown")(widget.editBox, "F")
IsControlKeyDown = previousControl
assert(E.luaFindBar and E.luaFindInput.editbox:HasFocus(), "Ctrl+F must open and focus Lua search")
local function query(value)
    E.luaFindInput:SetText(value)
    E.luaFindInput:Fire("OnTextChanged", value)
end
query("ALPHA")
assert(#E.luaFindResults == 3 and E.luaFindIndex == 1, "Search must ignore ASCII case")
assert(E.luaFindStatus.label:GetText() == "1 / 3")
local function selected()
    local range = widget.editBox.selection
    return widget:GetText():sub(range[1] + 1, range[2])
end
assert(selected() == "Alpha")
E.luaFindNext:Fire("OnClick")
assert(E.luaFindIndex == 2 and selected() == "alpha")
E.luaFindPrevious:Fire("OnClick")
assert(E.luaFindIndex == 1)
E.luaFindPrevious:Fire("OnClick")
assert(E.luaFindIndex == 3, "Previous must wrap to the last match")
E.luaFindInput:Fire("OnEnterPressed")
assert(E.luaFindIndex == 1, "Enter must advance and wrap")
IsShiftKeyDown = function() return true end
E.luaFindInput:Fire("OnEnterPressed")
IsShiftKeyDown = previousShift
assert(E.luaFindIndex == 3, "Shift+Enter must go to the previous match")
query("[")
assert(#E.luaFindResults == 3 and selected() == "[", "Search must treat Lua pattern characters literally")
query("no match [")
assert(#E.luaFindResults == 0 and E.luaFindStatus.label:GetText() == UI.Text("No matches"))
assert(E.luaFindNext.disabled and E.luaFindPrevious.disabled)
query("")
assert(#E.luaFindResults == 0 and E.luaFindStatus.label:GetText() == "")
assert(widget:GetText() == text and #E.session.rawHistory == history and not E.session:IsDirty(),
    "Search and cursor movement must not change the route or undo history")

-- Search also works on incomplete drafts and refreshes after editing/undo.
local raw = '{ steps = { { Note = "Alpha Alpha" } -- unfinished'
widget:SetText(raw); widget:Fire("OnTextChanged", raw)
query("alpha")
assert(#E.luaFindResults == 2 and E.session.raw == raw)
local edited = raw .. " Alpha"
widget:SetText(edited); widget:Fire("OnTextChanged", edited)
assert(#E.luaFindResults == 3)
E:Undo(-1)
assert(#E.luaFindResults == 2 and E.session.raw == raw)
E:Undo(1)
assert(#E.luaFindResults == 3 and E.session.raw == edited)

-- Search stays usable at the workshop's minimum full and compact sizes.
for _, compact in ipairs({ false, true }) do
    if E.compact ~= compact then E:ToggleCompact() end
    E.frame:SetWidth(compact and 440 or 880)
    E.frame:SetHeight(compact and 680 or 560)
    E.frame:DoLayout()
    assert(E.luaBox.frame:GetHeight() > 100 and E.luaFindInput.frame:GetWidth() > 150)
end
local input, escape = E.luaFindInput, E.luaFindEscape
input.editbox:GetScript("OnEscapePressed")(input.editbox)
assert(not E.luaFindBar and widget.editBox:HasFocus(), "Escape must close search and return to Lua")
assert(input.editbox:GetScript("OnEscapePressed") == escape, "Closing must restore pooled input scripts")
assert(E.session.raw == edited)
E:OpenLuaFind()
input, escape = E.luaFindInput, E.luaFindEscape
E:Hide()
assert(input.editbox:GetScript("OnEscapePressed") == escape)
assert(widget.editBox:GetScript("OnKeyDown") == originalKey)
assert(not E.luaFindInput and not E.luaBox)
E.follow, AprRC.settings.profile.followAPR = previousFollow, previousAPRFollow
IsControlKeyDown, IsShiftKeyDown = previousControl, previousShift
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Lua search: Ctrl+F, literal/case-insensitive matches, wrap, Enter/Shift+Enter, drafts, undo and pooled scripts passed.")
