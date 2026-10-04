local E, Model, Code, UI = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode, AprRC.editorUI
TestCloseWorkshop()
local route = assert(Model:NewRoute("Editor navigation and comparison"))
for i = 1, 100 do route.steps[i] = { Note = i == 50 and "Middle match" or "Step " .. i } end
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
E.follow = false
local widget, raw, history = E.luaBox, E.luaBox:GetText(), #E.session.rawHistory
local keyboard = widget.keyboardFrame
local shortcutHelp
for _, child in ipairs(widget.parent.children) do
    for _, button in ipairs(child.children or {}) do
        if button.type == "Button" and button.text:GetText() == UI.Text("Folding shortcuts") then shortcutHelp = button end
    end
end
assert(shortcutHelp)
local viewportHeight = widget.scrollFrame:GetHeight()
widget.scrollFrame:SetHeight(140)
E:OpenLuaFind(); E.luaFindInput:SetText("Middle match"); E.luaFindInput:Fire("OnTextChanged", "Middle match")
TestRunTimers()
local range = E.luaFindResults[1]
local line = Code:LineAt(widget.lines, Code:ToDisplay(widget.ranges, range.start))
local center = (line - 0.5) * widget.lineHeight - widget.scrollFrame:GetVerticalScroll()
assert(math.abs(center - widget.scrollFrame:GetHeight() / 2) < 1, "Search must center the matched line")
assert(widget:GetText() == raw and #E.session.rawHistory == history and not E.session:IsDirty())
widget.scrollFrame:SetHeight(viewportHeight)
E:CloseLuaFind()

local sections = '-- #region Route\n{\n steps = {\n {\n Note = "Target",\n Coord = {\n x = 1,\n y = 2,\n },\n },\n },\n}\n-- #endregion\n--[[\ncomment\n]]'
widget:SetText(sections); widget:Fire("OnTextChanged", sections)
history = #E.session.rawHistory
local oldControl, oldShift, oldTime = IsControlKeyDown, IsShiftKeyDown, GetTime
IsControlKeyDown = function() return true end
local function key(value, shift)
    IsShiftKeyDown = function() return not not shift end
    return TestDispatchKey({ keyboard, widget.editBox, E.luaFindInput and E.luaFindInput.editbox }, value)
end
local function keyUp(value)
    local script = widget.editBox:GetScript("OnKeyUp")
    if script then script(widget.editBox, value) end
end
local function chord(value, modifier)
    modifier = modifier or "LCTRL"
    key(modifier); key("K"); TestRunTimers(); keyUp("K")
    -- WoW emits a separate modifier event when Ctrl is pressed again.
    IsControlKeyDown = function() return false end; keyUp(modifier); TestRunTimers()
    IsControlKeyDown = function() return true end; key(modifier)
    key(value); keyUp(value)
    IsControlKeyDown = function() return false end; keyUp(modifier); TestRunTimers()
    IsControlKeyDown = function() return true end
end
widget:SetFocus()
assert(widget.editBox.keyboardEnabled and keyboard.keyboardEnabled and keyboard:GetFrameLevel() > widget.editBox:GetFrameLevel())
assert(key("K") == keyboard and widget.foldChord, "The prefix must be intercepted before native text and game bindings")
assert(shortcutHelp.text:GetText() == "Ctrl+K …", "The received prefix must have visible feedback")
key("J"); TestRunTimers()
assert(shortcutHelp.text:GetText() == UI.Text("Folding shortcuts"))
chord("0")
assert(widget.collapsed[0] and #widget.display < #sections, "Repressing Ctrl between chord steps must not cancel the shortcut")
chord("J", "RCTRL")
assert(not next(widget.collapsed) and widget.display == sections)
chord("NUMPAD0"); assert(widget.collapsed[0], "The numeric keypad must work for fold-all")
chord("J")
chord("à"); assert(widget.collapsed[0], "AZERTY's unshifted zero key must fold all")
key("k"); TestRunTimers(); key("j"); TestRunTimers()
assert(not next(widget.collapsed), "Letter key names must be case insensitive")
-- Holding Ctrl across both steps also works, including pressing Shift/Alt/Meta
-- before the next command. Pure modifier events cannot consume the sequence.
key("K"); TestRunTimers(); keyUp("K")
local deadline = widget.foldChord
for _, modifier in ipairs({ "LCTRL", "RCTRL", "LSHIFT", "RSHIFT", "LALT", "RALT", "LMETA", "RMETA" }) do
    key(modifier); keyUp(modifier)
    assert(widget.foldChord == deadline, "Modifier " .. modifier .. " must preserve the pending chord")
end
key("0"); TestRunTimers(); assert(widget.collapsed[0])
chord("J")
key("K"); TestRunTimers(); widget:ClearFocus(); widget:SetFocus(); key("0")
assert(not next(widget.collapsed) and not widget.foldChord, "Leaving the editor must cancel a pending chord")
key("K"); TestRunTimers(); key("ESCAPE")
assert(not widget.foldChord, "Escape must cancel a pending chord")
local target = sections:find("Target", 1, true) - 1
widget.editBox:SetCursorPosition(target); key("[", true); TestRunTimers()
local step
for _, fold in ipairs(widget.folds) do if fold.line == 4 then step = fold end end
assert(step and widget.collapsed[step.start])
key("]", true); TestRunTimers()
assert(not widget.collapsed[step.start])
widget.editBox:SetCursorPosition(target); chord("[")
local nested
for _, fold in ipairs(widget.folds) do if fold.line == 6 then nested = fold end end
assert(widget.collapsed[step.start] and widget.collapsed[nested.start])
chord("]")
assert(not widget.collapsed[step.start] and not widget.collapsed[nested.start])
chord("L"); assert(widget.collapsed[step.start])
chord("L"); assert(not widget.collapsed[step.start])
widget.editBox:SetCursorPosition(#sections); chord("2")
for _, fold in ipairs(widget.folds) do if fold.depth == 2 then assert(widget.collapsed[fold.start]) end end
chord("J"); chord("8"); assert(widget.collapsed[0])
chord("9"); assert(not widget.collapsed[0])
chord("/")
local comment
for _, fold in ipairs(widget.folds) do if fold.kind == "comment" then comment = fold end end
assert(widget.collapsed[comment.start])
chord("J")
key("K"); GetTime = function() return oldTime() + 5 end; key("0")
assert(not next(widget.collapsed), "Expired keyboard chords must not fold anything")
GetTime = oldTime; TestRunTimers()
-- Search owns the native focus after Ctrl+F. It must still receive fold chords,
-- without changing the query, code or undo history.
E:OpenLuaFind(); E.luaFindInput:SetText("Target"); E.luaFindInput:Fire("OnTextChanged", "Target")
local input = E.luaFindInput.editbox
assert(input:HasFocus() and not widget.editBox:HasFocus() and keyboard:GetFrameLevel() > input:GetFrameLevel())
local query = input:GetText()
assert(key("K") == keyboard and key("0") == keyboard)
TestRunTimers(); assert(widget.collapsed[0] and input:GetText() == query)
chord("J"); assert(not next(widget.collapsed) and input:GetText() == query)
key("K"); GetTime = function() return oldTime() + 5 end
keyboard:GetScript("OnUpdate")(keyboard)
assert(not widget.foldChord and not keyboard:GetScript("OnUpdate"), "Chord status must clear on timeout without another key")
assert(shortcutHelp.text:GetText() == UI.Text("Folding shortcuts"))
GetTime = oldTime
key("K"); input:ClearFocus(); keyboard:GetScript("OnUpdate")(keyboard)
assert(not widget.foldChord, "Leaving the search field must cancel a pending chord")
assert(not key("K") and keyboard.propagateKeyboardInput, "The listener must not capture game shortcuts outside the Lua inputs")
E:CloseLuaFind()
assert(widget:GetText() == sections and #E.session.rawHistory == history and E.session.raw == sections)
IsControlKeyDown, IsShiftKeyDown = oldControl, oldShift
TestCloseWorkshop()
assert(not keyboard.keyboardEnabled and keyboard.propagateKeyboardInput and not widget.foldingInput,
    "Releasing the editor must release keyboard capture and the pooled search reference")
local typing = LibStub("AceGUI-3.0"):Create("APRLuaEditor")
typing.frame:Show()
typing:SetText(sections); typing:SetCursorPosition(#sections); typing:SetFocus()
local inputs = { typing.keyboardFrame, typing.editBox }
IsControlKeyDown = function() return true end
assert(TestDispatchKey(inputs, "K") == typing.keyboardFrame)
IsControlKeyDown = function() return false end
assert(TestDispatchKey(inputs, "A", "a") == typing.editBox)
assert(typing:GetText() == sections .. "a" and not typing.foldChord,
    "An unhandled key must cancel the chord and retain native typing, even before the next frame")
IsControlKeyDown = oldControl
LibStub("AceGUI-3.0"):Release(typing)

route = assert(Model:NewRoute("Version comparison"))
route.steps = { { Note = "Old", Coord = { x = 1, y = 2 } }, { Note = "Unchanged" } }
Model:Archive(route.name, route, "Before save", Model:RouteText(route))
local first = Model:History(route.name)[1]
route.steps[1].Note = "New"
route.steps[3] = { Note = "Inserted" }
Model:Archive(route.name, route, "Before save")
local second = Model:History(route.name)[2]
AprRCData.CurrentRoute = route
E:Show(); E:SelectRoute(route.name); E:SelectTab("versions")
local original, draft = Model:RouteText(route), Model:RouteText(E.session.draft)
E:OpenVersionDiff("version:" .. first.id, "version:" .. second.id)
TestRunTimers()
local comparison = E.versionDiffComparison
local left, right = E.versionDiffLeftBox, E.versionDiffRightBox
local function checkComparisonLayout()
    local split = left.parent.parent
    assert(right.parent.parent == split)
    local point, relative, relativePoint, x, y = right.parent.frame:GetPoint(1)
    assert(point == "TOPLEFT" and relative == split.content and relativePoint == "TOPLEFT" and
        x > left.parent.frame:GetWidth() and (y or 0) == 0,
        "Comparison panes must occupy two columns instead of stacking at their default size")
    for _, box in ipairs({ left, right }) do
        assert(box.parent.frame:GetHeight() == split.content:GetHeight() and
            box.frame:GetHeight() >= box.parent.frame:GetHeight() - 8 and
            box.frame:GetWidth() == box.parent.frame:GetWidth(),
            "Both code editors must fill the space between the selectors and comparison footer")
    end
end
checkComparisonLayout()
for _, size in ipairs({ { 880, 560 }, { 1400, 900 }, { 1240, 780 } }) do
    E.versionDiffDialog:SetWidth(size[1]); E.versionDiffDialog:SetHeight(size[2]); E.versionDiffDialog:DoLayout()
    checkComparisonLayout()
end
assert(#comparison.hunks >= 2 and comparison.removed > 0 and comparison.inserted > 0)
assert(left.sourceText == first.raw and right.sourceText == Model:RouteText(second.route))
assert(#left.lines == #right.lines and #left.lines == #comparison.rows)
local missing
for _, value in pairs(left.comparisonMissing) do if value then missing = true end end
assert(missing, "Inserted lines need empty, hatched rows on the other side")
left.scrollFrame:SetVerticalScroll(100)
assert(right.scrollFrame:GetVerticalScroll() == 100, "Both sides must scroll together")
left.scrollFrame:SetHeight(140); left:SizeCode()
left.scrollFrame:SetVerticalScroll(left.scrollFrame:GetVerticalScrollRange())
assert(left.scrollFrame:GetVerticalScroll() == right.scrollFrame:GetVerticalScroll(), "Unequal viewport heights must stay aligned at the bottom")
E.versionDiffNext:Fire("OnClick"); TestRunTimers()
assert(left.scrollFrame:GetVerticalScroll() == right.scrollFrame:GetVerticalScroll(), "Change navigation must retain scroll alignment")
local hatches
for _, row in ipairs(left.rows) do if #row.hatches > 0 then hatches = true end end
assert(hatches, "Missing rows must display diagonal hatching")
E.versionDiffPrevious:Fire("OnClick")
right.editBox:GetScript("OnKeyDown")(right.editBox, "F7"); TestRunTimers()
local displayed = right:GetText()
right.editBox:Insert("must not edit")
assert(right:GetText() == displayed and Model:RouteText(route) == original and Model:RouteText(E.session.draft) == draft)
E.versionDiffRightSelect:Fire("OnValueChanged", "draft")
assert(E.versionDiffRightBox.sourceText == draft)
E.versionDiffLeftSelect:Fire("OnValueChanged", "draft")
assert(#E.versionDiffComparison.hunks == 0 and E.versionDiffNext.disabled and E.versionDiffPrevious.disabled)
E.versionDiffDialog:Hide()
assert(not E.versionDiffDialog and not E.versionDiffLeftBox)
-- Incomplete Lua can be compared without validation or applying it.
E.session.raw = "{ steps = { -- unfinished"; E.session:Persist()
E:OpenVersionDiff(); assert(E.versionDiffRightBox.sourceText == E.session.raw)
left, right = E.versionDiffLeftBox, E.versionDiffRightBox
checkComparisonLayout()
TestCloseWorkshop()
assert(not E.versionDiffDialog and #UIErrors == 0, table.concat(UIErrors, "\n"))
print("Editor navigation: centered search, VS Code folding chords, safe sections and synchronized two-version comparisons passed.")
