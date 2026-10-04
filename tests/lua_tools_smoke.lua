local E, Model, Code, Language, GUI = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode, AprRC.luaLanguage, LibStub("AceGUI-3.0")
TestCloseWorkshop(); TestRunTimers()
local oldControl, oldShift, oldAlt = IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown
local function key(listener, value, control, shift, alt)
    IsControlKeyDown = function() return control or false end
    IsShiftKeyDown = function() return shift or false end
    IsAltKeyDown = function() return alt or false end
    listener:GetScript("OnKeyDown")(listener, value)
    IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown = oldControl, oldShift, oldAlt
end
local function selected(edit)
    local range = edit.editBox.selection
    return Code:Decode(edit.editBox.text:sub(range[1] + 1, range[2]))
end
local route = assert(Model:NewRoute("Lua tools"))
route.steps = { { Note = "Alpha" }, { Note = "alpha alphabet" } }
route.parallelSteps = { { conditions = {}, steps = { { Note = "Parallel" } } } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua"); E.follow = false; TestRunTimers()
local edit, saved, savedRoute = E.luaBox, E.luaBox:GetText(), Model:RouteText(route)
edit:SetFocus()
local first = edit:GetText():find('Note = "Alpha"', 1, true)
edit:SetCursorPosition(first)
key(edit.keyboardFrame, "L", true)
assert(selected(edit):find('Note = "Alpha",\n', 1, true) and not edit.keyboardFrame.propagateKeyboardInput)
local line = selected(edit)
key(edit.keyboardFrame, "L", true)
assert(#selected(edit) > #line and not E.session:IsDirty(), "Repeated Ctrl+L must extend selection without editing")
-- Ctrl+K Ctrl+L remains folding, even with the new single-key line command.
edit:SetCursorPosition(first)
key(edit.keyboardFrame, "K", true); key(edit.keyboardFrame, "L", true)
assert(next(edit.collapsed)); edit:UnfoldAll()

key(edit.keyboardFrame, "H", true)
assert(E.luaFindBar and E.luaReplaceBar and E.luaReplaceInput.editbox:HasFocus())
E.luaFindInput:SetText("Alpha"); E.luaFindInput:Fire("OnTextChanged", "Alpha")
assert(#E.luaFindResults == 3)
E.luaCaseCheck:SetValue(true); E.luaCaseCheck:Fire("OnValueChanged", true)
assert(#E.luaFindResults == 1)
E.luaCaseCheck:SetValue(false); E.luaCaseCheck:Fire("OnValueChanged", false)
E.luaWordCheck:SetValue(true); E.luaWordCheck:Fire("OnValueChanged", true)
assert(#E.luaFindResults == 2)
E.luaReplaceInput:SetText("%1|é"); E.luaReplaceInput:Fire("OnTextChanged", "%1|é")
local history = #E.session.rawHistory
E.luaReplaceAllButton:Fire("OnClick")
assert(edit:GetText():find('Note = "%1|é"', 1, true) and edit:GetText():find('%1|é alphabet', 1, true))
assert(#E.session.rawHistory == history + 1 and Model:RouteText(route) == savedRoute)
E:Undo(-1); assert(edit:GetText() == saved)
E:Undo(1); assert(edit:GetText():find('%1|é alphabet', 1, true))
E:Undo(-1)
-- Replace current must honor a navigated result rather than restarting at #1.
E.luaFindAnchor = 0; E:FindLua(0, true)
E.luaFindNext:Fire("OnClick")
E.luaReplaceInput:SetText("Selected"); E.luaReplaceInput:Fire("OnTextChanged", "Selected")
E.luaReplaceButton:Fire("OnClick")
assert(edit:GetText():find('Note = "Alpha"', 1, true) and edit:GetText():find('Note = "Selected alphabet"', 1, true))
local replacement, escape = E.luaReplaceInput, E.luaReplaceEscape
E:Undo(-1); E:CloseLuaFind(); TestRunTimers()
assert(replacement.editbox:GetScript("OnEscapePressed") == escape)
E.luaMatchCase, E.luaWholeWord = false, false

assert(#E.luaOutline == 3 and E.luaOutline[3].group == 1)
E.luaOutlineSelect:Select(3)
assert(edit:GetCursorPosition() == E.luaOutline[3].start and edit.editBox:HasFocus())
key(edit.keyboardFrame, "O", true, true)
assert(E.luaOutlineSelect.editbox:HasFocus() and E.luaOutlineSelect.open)
edit:SetFocus()

-- Whitespace formatting is one undo step, with the same comments and values.
local compact = '{\nsteps={\n{Note="Alpha",Coord={x=-1,y=2}}, -- unchanged\n},\n}'
edit:EditText(compact, compact:find("Coord", 1, true)); TestRunTimers()
local parsed = AprRC:ParseLuaData(compact)
history = #E.session.rawHistory
key(edit.keyboardFrame, "F", false, true, true)
assert(edit:GetText():find('    steps = {', 1, true) and edit:GetText():find('-- unchanged', 1, true))
assert(AprRC:DeepCompare(parsed, AprRC:ParseLuaData(edit:GetText())) and #E.session.rawHistory == history + 1)
E:Undo(-1); assert(edit:GetText() == compact)

-- Parse/validation never run from a native keystroke; idle diagnostics are
-- clickable in both the footer and the line gutter, without saving anything.
local invalid = '{\nsteps = {{\n    Note = "A",\n    Zone = "wrong",\n    NoArrow = 123,\n}}\n}'
edit:EditText(invalid, #invalid); TestRunTimers()
assert(#E.luaDiagnostics == 2 and E.luaDiagnostics[1].location.line == 4 and E.luaDiagnostics[2].location.line == 5)
local analyze, count = Language.Analyze, 0
Language.Analyze = function(self, ...) count = count + 1; return analyze(self, ...) end
edit.editBox:Insert(" ")
assert(count == 0 and E.luaOutlineSelect.disabled and E.session.raw == invalid .. " ")
local caret = edit:GetCursorPosition()
TestRunTimers()
assert(count == 1 and edit:GetCursorPosition() == caret)
Language.Analyze = analyze
E.luaDiagnosticLabel:Fire("OnClick")
assert(edit:GetCursorPosition() == E.luaDiagnostics[1].location.position - 1 and selected(edit) == "Z")
key(edit.keyboardFrame, "F8")
assert(edit:GetCursorPosition() == E.luaDiagnostics[2].location.position - 1)
local row
edit.scrollFrame:SetVerticalScroll(0); edit:DrawGutter()
for _, candidate in ipairs(edit.rows) do if candidate.diagnostic and candidate.diagnostic.location.line == 4 then row = candidate end end
assert(row); row.frame:GetScript("OnClick")()
assert(edit:GetCursorPosition() == E.luaDiagnostics[1].location.position - 1)
local broken = '{\nsteps = {{ Note = }}\n}'
edit:EditText(broken, #broken); TestRunTimers()
assert(#E.luaDiagnostics == 1 and E.luaDiagnostics[1].location.line == 2)
E:FormatLua(); assert(edit:GetText() == broken, "Invalid formatting must never replace source data")

-- Completion uses APR fields plus client data, replaces source byte ranges,
-- remembers item/spell choices and remains undoable without dispatching commands.
local oldQuests, oldItems, oldBags, oldSpells, oldBook = C_QuestLog, C_Item, C_Container, C_Spell, C_SpellBook
local oldBank, oldRecent = Enum.SpellBookSpellBank, AprRCRecentChoices
C_QuestLog = { GetNumQuestLogEntries = function() return 1 end, GetInfo = function() return { questID = 4242, title = "Guardian" } end,
    GetTitleForQuestID = function() return "Guardian" end }
C_Item = { GetItemInfo = function() return "Pie" end }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemID = function() return 888 end }
C_Spell = { GetSpellInfo = function() return { name = "Bolt" } end }
C_SpellBook = { GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemType = function() return "SPELL", 999 end, GetSpellBookItemName = function() return "Bolt" end }
Enum.SpellBookSpellBank = { Player = 0 }; AprRCRecentChoices = {}
local partial = '{ steps = {{ N }} }'
edit:EditText(partial, partial:find('N', 1, true)); edit:SetFocus(); E:CloseLuaCompletion()
edit.editBox:Insert('o')
assert(not E.luaCompletion, "Native typing must hide old suggestions without calculating a new menu")
TestRunTimers()
assert(E.luaCompletion and E.luaCompletion.context.prefix == 'No', "Field completion must appear after the input pause")
key(edit.keyboardFrame, 'ESCAPE')
assert(not E.luaCompletion and edit.editBox:HasFocus())
local function complete(raw, prefix, insert, finish)
    edit:EditText(raw, raw:find(prefix, 1, true) + #prefix - 1); edit:SetFocus()
    key(edit.keyboardFrame, "SPACE", true)
    assert(E.luaCompletion and E.luaCompletionFrame:IsShown())
    assert(E.luaCompletionFrame:GetFrameStrata() == edit.frame:GetFrameStrata(), "Completion must be above the workshop, not behind its fullscreen layer")
    local completion = E.luaCompletion
    for index, item in ipairs(completion.items) do if item.insert == insert then completion.index = index end end
    assert(completion.items[completion.index].insert == insert)
    history = #E.session.rawHistory
    key(edit.keyboardFrame, "TAB")
    assert(edit:GetText() == finish and #E.session.rawHistory == history + 1 and not E.luaCompletion)
    E:Undo(-1); assert(edit:GetText() == raw)
end
complete('{ steps = {{ No }} }', 'No', 'Note', '{ steps = {{ Note =  }} }')
complete('{ steps = {{ PickUp = { Guar } }} }', 'Guar', '4242', '{ steps = {{ PickUp = { 4242 } }} }')
complete('{ steps = {{ LearnSkill = { spellID = Bol } }} }', 'Bol', '999', '{ steps = {{ LearnSkill = { spellID = 999 } }} }')
complete('{ steps = {{ Use = { itemID = Pi } }} }', 'Pi', '888', '{ steps = {{ Use = { itemID = 888 } }} }')
assert(AprRC.recentChoices:Get("spell")[1].id == 999 and AprRC.recentChoices:Get("item")[1].id == 888)
C_QuestLog, C_Item, C_Container, C_Spell, C_SpellBook = oldQuests, oldItems, oldBags, oldSpells, oldBook
Enum.SpellBookSpellBank, AprRCRecentChoices = oldBank, oldRecent

-- Ctrl+S follows the normal save/merge workflow and is scoped to the workshop.
edit:EditText('{ steps = {{ Note = "Shortcut save" }} }', 0); edit:SetFocus()
key(E.saveKeyboard, "S", true)
assert(not E.session.raw and Model:Source(route.name).steps[1].Note == "Shortcut save" and not E.saveKeyboard.propagateKeyboardInput)
edit = E.luaBox; TestRunTimers()
edit:EditText('{ steps = {{ Note = "Shortcut draft" }} }', 0); edit:SetFocus()
Model:Source(route.name).steps[1].Note = "Concurrent recording"
key(E.saveKeyboard, "S", true)
assert(E.mergeDialog and Model:Source(route.name).steps[1].Note == "Concurrent recording")
E.mergeLeftButton:Fire("OnClick"); E.mergeApplyButton:Fire("OnClick")
assert(not E.mergeDialog and Model:Source(route.name).steps[1].Note == "Shortcut draft")
local outside = CreateFrame("EditBox", nil, UIParent)
outside:SetFocus(); key(E.saveKeyboard, "S", true)
assert(E.saveKeyboard.propagateKeyboardInput)
outside:ClearFocus()
local keyboard = E.saveKeyboard
TestCloseWorkshop(); TestRunTimers()
assert(not keyboard.keyboardEnabled and not keyboard:GetScript("OnKeyDown"))
assert(not E.luaCompletion and not E.luaBox and #UIErrors == 0, table.concat(UIErrors, "\n"))
local reused = GUI:Create("APRSearchSelect")
assert(reused.label:IsShown() and not reused.disabled and not reused.maxResults and not reused.editbox:GetScript("OnEnter"))
GUI:Release(reused)
print("Lua tools: save/merge shortcuts, line selection, case/word replacement, safe formatting, live clickable diagnostics, parallel outline and APR completion/undo passed.")
