local E, Model, Code = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode
TestCloseWorkshop()
local route = assert(Model:NewRoute("Colored editor"))
route.steps = { { Note = "Original" }, { Note = "Second" } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
local widget, raw = E.luaBox, E.luaBox:GetText()
assert(widget.type == "APRLuaEditor" and widget.editBox.text:find("|cff9cdcfe", 1, true))
local history = #E.session.rawHistory
local fold = widget.folds[2]
assert(fold)
widget:ToggleFold(fold.start)
assert(widget:GetText() == raw and #E.session.rawHistory == history and not E.session:IsDirty())
assert(#widget.display < #raw)
-- Inserting outside a collapsed table retains its complete hidden contents.
widget.editBox:SetCursorPosition(#raw)
widget.editBox:Insert("\n-- added")
assert(widget:GetText() == raw .. "\n-- added" and E.session.raw == widget:GetText())
assert(widget.collapsed[fold.start])
E:Undo(-1)
assert(widget:GetText() == raw)
-- Search opens a folded block before selecting its source byte range.
widget:ToggleFold(widget.folds[2].start)
E:OpenLuaFind(); E.luaFindInput:SetText("Original"); E.luaFindInput:Fire("OnTextChanged", "Original")
assert(not next(widget.collapsed) and E.luaFindResults[1])
assert(Code:Decode(widget.editBox.text:sub(widget.editBox.selection[1] + 1, widget.editBox.selection[2])) == "Original")
E:CloseLuaFind()
-- Native input exposes plain source/history immediately; recoloring waits.
widget:SetText('{ steps = { { Note = "é |cffff0000literal|r" } } }')
widget:Fire("OnTextChanged", widget:GetText())
widget.editBox:SetCursorPosition(#widget:GetText()); widget.editBox:Insert("\n-- comment")
assert(E.session.raw == '{ steps = { { Note = "é |cffff0000literal|r" } } }\n-- comment')
assert(Code:Decode(widget.editBox.text) == E.session.raw)
local literal = widget:GetText():find("literal", 1, true) - 1
widget:HighlightText(literal, literal + 7); widget.editBox:Insert("changed")
assert(widget:GetText():find("|cffff0000changed|r", 1, true), "Native selection replacement must use source offsets")
TestCloseWorkshop()

-- Two conflicts: choices stay visible; custom and invalid edits survive navigation.
route = assert(Model:NewRoute("Editable conflict result"))
route.steps = { { Note = "Base", Range = 1 } }
AprRCData.CurrentRoute = route
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.session.draft.steps[1].Note, E.session.draft.steps[1].Range = "Ours", 2
E:Changed()
route.steps[1].Note, route.steps[1].Range = "Theirs", 3
assert(not E:Save() and #E.mergePlan.conflicts == 2)
assert(E.mergeResultBox:GetText() == '"Ours"')
E.mergeRightButton:Fire("OnClick")
assert(E.mergeResultBox:GetText() == '"Theirs"', "Choosing must keep the selected result visible")
E.mergeResultBox.editBox:SetCursorPosition(#E.mergeResultBox:GetText())
local parse, diff = AprRC.ParseLuaData, E.mergeResultBox.SetDiff
local parses, diffs = 0, 0
AprRC.ParseLuaData = function(self, ...) parses = parses + 1; return parse(self, ...) end
E.mergeResultBox.SetDiff = function(self, ...) diffs = diffs + 1; return diff(self, ...) end
E.mergeResultBox.editBox:Insert(" ")
assert(parses == 0 and diffs == 0 and E.mergeApplyButton.disabled and not E.mergeChoices[1],
    "Manual conflict input must defer parsing/diff and invalidate the previous choice immediately")
TestRunTimers()
assert(parses == 1 and diffs == 1 and E.mergeChoices[1].value == "Theirs")
AprRC.ParseLuaData, E.mergeResultBox.SetDiff = parse, diff
E.mergeResultBox:UndoCode(-1)
assert(E.mergeResultBox:GetText() == '"Theirs"')
E.mergeResultBox:UndoCode(1)
assert(E.mergeResultBox:GetText() == '"Theirs" ')
assert(E.mergeLeftBox.changedLines[1] and E.mergeRightBox.changedLines[1])
E.mergeResultBox:SetText('"Corrected"'); E.mergeResultBox:Fire("OnTextChanged", '"Corrected"')
assert(E.mergeChoices[1].custom and E.mergeChoices[1].value == "Corrected")
local function find(widget, label)
    if widget.type == "Button" and widget.text:GetText() == AprRC.editorUI.Text(label) then return widget end
    for _, child in ipairs(widget.children or {}) do local result = find(child, label); if result then return result end end
end
find(E.mergeDialog, "Next"):Fire("OnClick")
E.mergeResultBox:SetText("{"); E.mergeResultBox:Fire("OnTextChanged", "{")
assert(E.mergeApplyButton.disabled and not E.mergeChoices[2])
find(E.mergeDialog, "Previous"):Fire("OnClick")
assert(E.mergeResultBox:GetText() == '"Corrected"')
find(E.mergeDialog, "Next"):Fire("OnClick")
assert(E.mergeResultBox:GetText() == "{", "Invalid corrections must also survive navigation")
E.mergeResultBox:SetText("4"); E.mergeResultBox:Fire("OnTextChanged", "4")
assert(not E.mergeApplyButton.disabled)
E.mergeApplyButton:Fire("OnClick")
assert(not E.mergeDialog and AprRCData.CurrentRoute.steps[1].Note == "Corrected" and AprRCData.CurrentRoute.steps[1].Range == 4)
TestCloseWorkshop()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Colored editor: native typing, safe folds, search/undo, diff backgrounds and editable conflict results passed.")
