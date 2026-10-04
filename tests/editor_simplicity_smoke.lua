local E, Model, Code, GUI = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode, LibStub("AceGUI-3.0")
TestCloseWorkshop(); TestRunTimers()
local route = assert(Model:NewRoute("Editor simplicity"))
route.steps = { { Note = "Saved" }, { Note = "Second" } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua"); E.follow = false; TestRunTimers()
local edit, saved = E.luaBox, E.luaBox:GetText()

-- Typing then undoing to the source must remove the persisted draft, without
-- requiring another Save; whitespace-only edits reconcile after the pause.
edit:EditText(saved .. "\n", #saved + 1); TestRunTimers()
assert(not E.session:IsDirty() and not AprRCData.EditorDrafts[route.name])
E:Undo(-1); TestRunTimers()
assert(not E.session:IsDirty() and not E.session.raw)
edit:EditText(saved:gsub('"Saved"', '"Changed"'), 0); TestRunTimers()
assert(E.session:IsDirty() and AprRCData.EditorDrafts[route.name])
E:Undo(-1); TestRunTimers()
assert(not E.session:IsDirty() and not AprRCData.EditorDrafts[route.name])
-- Old persisted no-op drafts are cleaned on reopening too.
AprRCData.EditorDrafts[route.name] = { draft = AprRC:CopyData(E.session.draft), base = E.session.base, raw = saved .. "\n" }
local reopened = Model:Open(route)
assert(not reopened:IsDirty() and not AprRCData.EditorDrafts[route.name])

local backup = Model:History(route.name)
local count = #backup
Model:Archive(route.name, route, "Recording checkpoint")
Model:Archive(route.name, route, "Before close")
Model:Archive(route.name, route, "Before save")
assert(#Model:History(route.name) == count + 1, "Repeated checks must not create identical recovery versions")

-- The actual button expands a compact route; undo restores the exact text.
local compact = '{steps={{Note="Saved"},{Note="Second"}}}'
edit:EditText(compact, #compact); TestRunTimers()
E.luaFormatButton:Fire("OnClick")
assert(edit:GetText():find('    steps = {', 1, true) and #Code:Lines(edit:GetText()) > 6)
assert(AprRC:DeepCompare(AprRC:ParseLuaData(compact), AprRC:ParseLuaData(edit:GetText())))
E:Undo(-1); assert(edit:GetText() == compact)

-- The whole Lua header fits on one row, at wide and half-width sizes.
for _, width in ipairs({ 1120, 440 }) do
    E.frame:SetWidth(width); E.frame:DoLayout()
    assert(E.luaToolbar.frame:GetHeight() <= 32)
    local edge = 0
    for _, child in ipairs(E.luaToolbar.children) do
        local _, _, _, left = child.frame:GetPoint(1)
        edge = math.max(edge, left + child.frame:GetWidth())
    end
    assert(edge <= E.luaToolbar.content:GetWidth() + 1, "Lua tools must fit the available width")
end
E.frame:SetWidth(1120); E.frame:DoLayout()

local oldControl, oldShift, oldAlt = IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
local function key(value, shift)
    IsShiftKeyDown = function() return shift or false end
    local handled = TestDispatchKey({ edit.keyboardFrame, edit.editBox }, value)
    assert(handled == edit.keyboardFrame, "Navigation must be handled before native colored-text movement")
end
-- Syntax color codes and varying line lengths cannot make arrows skip lines.
local text = '{\n    Note = "one",\n    Zone = 1411,\n    PickUp = { 804 },\n}'
edit:EditText(text, text:find('one', 1, true)); edit:SetFocus(); E:CloseLuaCompletion()
local start = edit:GetCursorPosition()
local lines = Code:Lines(text)
key("DOWN"); assert(Code:LineAt(lines, edit:GetCursorPosition()) == 3)
key("DOWN"); assert(Code:LineAt(lines, edit:GetCursorPosition()) == 4)
key("UP"); key("UP"); assert(edit:GetCursorPosition() == start)
key("RIGHT"); assert(edit:GetCursorPosition() == start + 1)
key("LEFT"); assert(edit:GetCursorPosition() == start)
key("RIGHT", true)
assert(Code:Decode(edit.editBox.text:sub(edit.editBox.selection[1] + 1, edit.editBox.selection[2])) == text:sub(start + 1, start + 1))
-- Navigation also works between keystrokes, without recoloring the buffer.
edit:SetCursorPosition(start); edit:SetFocus(); edit.editBox:Insert("x")
assert(edit.pendingCode)
local before, cursor = edit.editBox.text, edit:GetCursorPosition()
key("DOWN"); key("UP"); assert(edit:GetCursorPosition() == cursor and edit.editBox.text == before)
key("LEFT"); assert(edit:GetCursorPosition() == cursor - 1 and edit.editBox.text == before)
TestRunTimers()
-- UTF-8 and literal pipes are one character, not decoration to jump over.
edit:EditText('"é|a"', 1); edit:SetFocus()
key("RIGHT"); assert(edit:GetCursorPosition() == 3)
key("RIGHT"); assert(edit:GetCursorPosition() == 4)
key("LEFT"); assert(edit:GetCursorPosition() == 3)

-- Passive completion is inline, never edits the source and never consumes
-- normal arrows or Enter. Tab explicitly applies it as one undo action.
local partial = '{ steps = {{ N'
edit:EditText(partial, #partial); edit:SetFocus(); E:CloseLuaCompletion()
edit.editBox:Insert("o"); TestRunTimers()
assert(E.luaCompletion and E.luaCompletionGhost:IsShown() and (not E.luaCompletionFrame or not E.luaCompletionFrame:IsShown()))
assert(edit:GetText() == partial .. "o" and not E:HandleLuaCommand("ENTER"))
key("LEFT"); assert(edit:GetCursorPosition() == #partial and not E.luaCompletion)
key("RIGHT"); E:CompleteLua(false)
for index, item in ipairs(E.luaCompletion.items) do if item.insert == "Note" then E.luaCompletion.index = index end end
key("TAB"); assert(edit:GetText() == '{ steps = {{ Note = ')
E:Undo(-1); assert(edit:GetText() == partial .. "o")
edit:SetFocus(); E:CompleteLua(false); assert(E.luaCompletion)
edit.editBox:ClearFocus(); assert(not E.luaCompletion and not E.luaCompletionGhost:IsShown())
IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown = oldControl, oldShift, oldAlt

-- Saved current routes close even when another route has an invalid draft.
local other = assert(Model:NewRoute("Another pending draft"))
local pending = Model:Open(other); pending:SetRaw("{ steps = {"); pending:Persist()
E.session:Reload(); E:DrawTab(); E:Hide()
assert(not E.frame and not E.closeDialog and AprRCData.EditorDrafts[other.name])
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua"); TestRunTimers()
edit = E.luaBox; edit:EditText('{ steps = {{ Note = "Unfinished" }} }', 0)
E:Hide()
assert(E.closeDialog and E.closeDialog.type == "APRConfirmation" and #E.closeDialog.children == 2)
assert(E.closeSaveButton and E.closeKeepButton and E.closeCancelButton)
E.closeCancelButton:Fire("OnClick"); assert(E.frame and not E.closeDialog)
E:Hide(); E.closeKeepButton:Fire("OnClick")
assert(not E.frame and AprRCData.EditorDrafts[route.name])
TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Editor simplicity: clean close, draft/history deduplication, compact icons, button formatting, stable arrows and inline completion passed.")
