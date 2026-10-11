local E, Model, Code = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode
TestCloseWorkshop(); TestRunTimers()
local oldFollow, oldAPRFollow = E.follow, AprRC.settings.profile.followAPR
local oldRecording = AprRC.settings.profile.recordBarFrame.isRecording
local route = assert(Model:NewRoute("Save working position"))
for index = 1, 100 do route.steps[index] = { Note = "Step " .. index, Zone = 1411 } end
route.steps[100].Note = string.rep("Wide line ", 80)
route.parallelSteps = { { conditions = {}, steps = { { Note = "First group" } } }, { conditions = { HasSpell = 42 }, steps = {} } }
for index = 1, 90 do route.parallelSteps[2].steps[index] = { Note = "Parallel " .. index } end
AprRCData.CurrentRoute = route
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow, AprRC.settings.profile.followAPR = false, false
AprRC.settings.profile.recordBarFrame.isRecording = true

E:SelectStep(68)
E.query, E.filter = "Step", "other"
E.session.draft.steps[68].Note = "Step 68 edited"; E:Changed()
E.list:SetScroll(430); E.inspector:SetScroll(610)
local modes, pages = E.formModes, E.formPages
E.saveButton:Fire("OnClick")
assert(E.tab == "steps" and E:SelectedStep() == 68 and E.page == 2 and E.query == "Step" and E.filter == "other")
assert(E.list.localstatus.scrollvalue == 430 and E.inspector.localstatus.scrollvalue == 610)
assert(E.formModes == modes and E.formPages == pages and not E.session:IsDirty())
TestRunTimers(); TestRunTimers()
assert(E.list.localstatus.scrollvalue == 430 and E.inspector.localstatus.scrollvalue == 610,
    "Saving must preserve both visual scroll positions after deferred layout/recording refresh")

-- A late restore must never override navigation made immediately after Save.
assert(E:Save())
E:SelectStep(70)
TestRunTimers()
assert(E:SelectedStep() == 70 and E.inspector.localstatus.scrollvalue == 0)

E:SelectTab("parallel")
E.parallelPicker:Fire("OnValueChanged", 2); E:SelectStep(64)
E.session.draft.parallelSteps[2].steps[64].Note = "Parallel 64 edited"; E:Changed()
E:ShowStepPane("inspector")
E.list:SetScroll(340); E.inspector:SetScroll(720)
assert(E:Save())
TestRunTimers(); TestRunTimers()
assert(E.tab == "parallel" and E.session.parallelGroup == 2 and E:SelectedStep() == 64 and E.page == 2)
assert(E.list.localstatus.scrollvalue == 340 and E.inspector.localstatus.scrollvalue == 720 and E.compactPane == "inspector")

-- The same restoration applies when Save first requires a conflict choice.
E.session.draft.parallelSteps[2].steps[64].Note = "Our parallel edit"; E:Changed()
Model:Source(route.name).parallelSteps[2].steps[64].Note = "Recorded parallel edit"
E.list:SetScroll(390); E.inspector:SetScroll(680)
assert(not E:Save() and E.mergeDialog)
E.mergeLeftButton:Fire("OnClick"); E.mergeApplyButton:Fire("OnClick")
TestRunTimers(); TestRunTimers()
assert(not E.mergeDialog and E.tab == "parallel" and E.session.parallelGroup == 2 and E:SelectedStep() == 64)
assert(E.list.localstatus.scrollvalue == 390 and E.inspector.localstatus.scrollvalue == 680)
E.groupConditions:Fire("OnClick")
E.session.draft.parallelSteps[2].conditions.HasSpell = 43; E:Changed()
E.inspector:SetScroll(560)
assert(E:Save()); TestRunTimers()
assert(E.editGroupConditions and E.inspector.localstatus.scrollvalue == 560)

E:SelectTab("lua"); TestRunTimers()
local edit, raw = E.luaBox, "\n\n" .. E.luaBox:GetText() .. "\n-- Keep this formatting"
local first = raw:find("Step 80", 1, true) - 1
edit:EditText(raw, first + #"Step 80"); edit:SetFocus()
local fold
for _, candidate in ipairs(edit.folds) do if candidate.depth == 3 then fold = candidate end end
assert(fold); edit:ToggleFold(fold.start)
edit:SetCursorPosition(first + #"Step 80"); edit:HighlightText(first, first + #"Step 80")
edit.scrollFrame:SetVerticalScroll(650); edit.horizontalBar:SetValue(45)
local cursor, collapsed = edit:GetCursorPosition(), edit.collapsed
local oldControl = IsControlKeyDown
IsControlKeyDown = function() return true end
E.saveKeyboard:GetScript("OnKeyDown")(E.saveKeyboard, "S")
IsControlKeyDown = oldControl
assert(E.luaBox == edit and edit:GetText() == raw and edit:GetCursorPosition() == cursor and edit.editBox:HasFocus(),
    "Ctrl+S must keep the native editor, exact formatting, focus and source cursor")
assert(edit.collapsed == collapsed and edit.scrollFrame:GetVerticalScroll() == 650 and edit.horizontalBar:GetValue() == 45)
assert(Code:Decode(edit.editBox.text:sub(edit.editBox.selection[1] + 1, edit.editBox.selection[2])) == "Step 80")
assert(not E.session:IsDirty() and #E.session.rawHistory == 1 and E.session.rawHistory[1].cursor == cursor)
TestRunTimers(); TestRunTimers()
assert(edit:GetCursorPosition() == cursor and edit.scrollFrame:GetVerticalScroll() == 650 and edit.horizontalBar:GetValue() == 45)
local parsed, _, _, positions = AprRC:ParseLuaData(raw, true, true)
assert(E.luaStepPositions.steps[80].start == positions[parsed.steps[80]].start,
    "Following after Save must use positions in the retained source buffer")

-- Saving while recoloring is queued must keep the exact latest native edit.
edit.editBox:Insert("Saved selection replacement")
local latest, latestCursor = edit:GetText(), edit:GetCursorPosition()
assert(edit.pendingCode and E:Save())
TestRunTimers(); TestRunTimers()
assert(E.luaBox == edit and edit:GetText() == latest and edit:GetCursorPosition() == latestCursor and not E.session:IsDirty())
E:Undo(-1)
assert(edit:GetText() == latest, "Save must reset undo to the committed source without moving it")

-- Merging lines before the current source line must keep that line in view.
edit:UnfoldAll()
raw = edit:GetText():gsub('Step 75', 'Step 75 locally edited', 1)
first = raw:find('Step 75 locally edited', 1, true) - 1
edit:EditText(raw, first + 5)
local source = Model:Source(route.name)
table.insert(source.steps, 1, { Note = "Incoming inserted step" })
assert(E:Save() and not E.mergeDialog)
local merged = E.luaBox:GetText()
assert(E.luaBox:GetCursorPosition() == merged:find('Step 75 locally edited', 1, true) - 1 + 5,
    "Merged saves must map the cursor to the corresponding source line")
TestRunTimers(); TestRunTimers()
assert(E.luaBox:GetCursorPosition() == merged:find('Step 75 locally edited', 1, true) - 1 + 5)

E.session:Reload(); TestCloseWorkshop(); TestRunTimers()
E.follow, AprRC.settings.profile.followAPR = oldFollow, oldAPRFollow
AprRC.settings.profile.recordBarFrame.isRecording = oldRecording
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Save position: main/parallel pages, both panels, group conditions, Lua selection/folds/focus/formatting, pending input and merged line mapping passed.")
