local E, Model, Code, GUI = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode, LibStub("AceGUI-3.0")
TestCloseWorkshop(); TestRunTimers()
local route = assert(Model:NewRoute("Lua input stability"))
for i = 1, 600 do route.steps[i] = { Note = "Step " .. i, Coord = { x = -i, y = i }, Zone = 1411 } end
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
E.follow = false; TestRunTimers()
local widget, box = E.luaBox, E.luaBox.editBox
local saved, raw = Model:RouteText(route), widget:GetText()
E:OpenLuaFind(); E.luaFindInput:SetText("Step"); E.luaFindInput:Fire("OnTextChanged", "Step")
local matches = #E.luaFindResults
widget:SetCursorPosition(raw:find("Step 300", 1, true) + #"Step 300" - 1); widget:SetFocus()

-- A due-time scheduler exercises an actual quiet interval. Existing smoke
-- tests deliberately drain timers regardless of delay.
local oldAfter, now, timers = C_Timer.After, 0, {}
C_Timer.After = function(delay, callback) timers[#timers + 1] = { due = now + delay, callback = callback } end
local function advance(seconds)
    now = now + seconds
    while true do
        local index
        for i, timer in ipairs(timers) do
            if timer.due <= now and (not index or timer.due < timers[index].due) then index = i end
        end
        if not index then return end
        table.remove(timers, index).callback()
    end
end
local scans, encodes, sizes, writes = 0, 0, 0, 0
local scan, encode, size = Code.Scan, Code.Encode, widget.SizeCode
Code.Scan = function(self, ...) scans = scans + 1; return scan(self, ...) end
Code.Encode = function(self, ...) encodes = encodes + 1; return encode(self, ...) end
widget.SizeCode = function(self, ...) sizes = sizes + 1; return size(self, ...) end
local textSet = box:GetScript("OnTextSet")
box:SetScript("OnTextSet", function() writes = writes + 1 end)
local native = getmetatable(box).__index
local expected = widget:GetText()
local function hardware(text, backspace, delete)
    local first, last = box.cursor, box.cursor
    if backspace then first = first - backspace end
    if delete then
        -- Native Delete skips invisible color sequences at a token boundary.
        while box.text:sub(first + 1, first + 2) == "|c" or box.text:sub(first + 1, first + 2) == "|r" do
            first = first + (box.text:sub(first + 1, first + 2) == "|c" and 10 or 2)
        end
        last = first + delete
    end
    local displayFirst = select(2, Code:Decode(box.text:sub(1, first)))
    local displayLast = select(2, Code:Decode(box.text:sub(1, last)))
    local from, to = Code:ToRaw(widget.ranges, displayFirst), Code:ToRaw(widget.ranges, displayLast)
    expected = expected:sub(1, from) .. text .. expected:sub(to + 1)
    local inserted = text:gsub("|", "||")
    box.text = box.text:sub(1, first) .. inserted .. box.text:sub(last + 1)
    -- WoW may fire text changes before updating its native caret. No addon
    -- buffer rewrite or cursor move is allowed in that event.
    local oldCursor = box.cursor
    box:GetScript("OnTextChanged")(box, true)
    assert(box.cursor == oldCursor, "Text events must let WoW finish moving its own caret")
    native.SetCursorPosition(box, first + #inserted)
    assert(widget:GetText() == expected and E.session.raw == expected and
        AprRCData.EditorDrafts[route.name].raw == expected, "Every input must persist the exact source immediately")
    local displayCursor = select(2, Code:Decode(box.text:sub(1, box.cursor)))
    assert(widget:GetCursorPosition() == Code:ToRaw(widget.ranges, displayCursor), "Incremental caret mapping must match native bytes")
end

for _, text in ipairs({ "a", "a", "a", "é", "|", "b" }) do hardware(text); advance(0.1) end
hardware("", 1); advance(0.1)
hardware("c"); advance(0.1)
assert(scans == 0 and encodes == 0 and sizes == 0 and writes == 0,
    "Continuous typing must not tokenize, measure every line or rewrite the native buffer")
assert(Model:RouteText(route) == saved and not expected:find("\239\128\128", 1, true))
local cursor, vertical = widget:GetCursorPosition(), widget.scrollFrame:GetVerticalScroll()
-- Mouse/Shift selection made after the last keystroke must survive recoloring.
native.HighlightText(box, box.cursor - 1, box.cursor)
advance(0.29)
assert(writes == 0, "Each key must restart the 400 ms quiet interval")
advance(0.02)
assert(scans == 1 and encodes == 1 and writes == 1 and not widget.pendingCode)
assert(widget:GetCursorPosition() == cursor and widget.scrollFrame:GetVerticalScroll() == vertical)
assert(Code:Decode(box.text:sub(box.selection[1] + 1, box.selection[2])) == "c",
    "Idle coloring must preserve the actual native selection")
assert(widget:GetText() == expected and not widget:GetText():find("\239\128\128", 1, true))
assert(#E.luaFindResults == matches, "Search must refresh after the pause without selecting another result")

-- Enter and successive backspaces in an indented line remain native edits.
widget:SetCursorPosition(expected:find('Note = "Step 400"', 1, true) + #'Note = "Step 400",' - 1)
scans, encodes, sizes, writes = 0, 0, 0, 0
local history = #E.session.rawHistory
hardware("\n")
local enter = widget:GetCursorPosition()
advance(0)
local indent = widget:GetText():sub(enter + 1, widget:GetCursorPosition())
assert(indent:match("^ +$") and #E.session.rawHistory == history + 1,
    "Indentation must wait for the native cursor and remain part of one undo step: " ..
    tostring(enter) .. " -> " .. tostring(widget:GetCursorPosition()) .. ", indent=" .. string.format("%q", indent) ..
    ", history=" .. history .. " -> " .. #E.session.rawHistory)
expected = widget:GetText()
hardware(" "); hardware("x"); hardware("y"); hardware("", 1); hardware("", 1)
assert(writes == 0 and scans == 0 and encodes == 0)
local afterEnter = widget:GetCursorPosition()
advance(0.41)
assert(widget:GetCursorPosition() == afterEnter and widget:GetText() == expected)
assert(AprRC:ParseLuaData(expected), "Native typing/Enter/backspace must retain valid Lua data")

-- Delete in a colored number and rapid typing after a re-render retain bytes.
local number = expected:find("1411", 1, true) - 1
widget:SetCursorPosition(number)
scans, encodes, sizes, writes = 0, 0, 0, 0
hardware("", nil, 1); hardware("2"); hardware("3"); hardware("", 1)
assert(writes == 0 and scans == 0 and encodes == 0)
advance(0.41)
assert(widget:GetText() == expected and AprRC:ParseLuaData(expected))

Code.Scan, Code.Encode, widget.SizeCode = scan, encode, size
box:SetScript("OnTextSet", textSet)
E:CloseLuaFind()
-- Timers from an old editor cannot recolor a newly acquired pooled widget.
hardware(" ")
TestCloseWorkshop()
local reused = GUI:Create("APRLuaEditor")
reused:SetText('"New editor"')
advance(1)
assert(reused:GetText() == '"New editor"' and not reused.pendingCode)
GUI:Release(reused)
C_Timer.After = oldAfter

-- Errors in long drafts reveal the source byte rather than an addon stack line.
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua"); TestRunTimers()
local prefix = '{ steps = { { Note = '
local invalid = prefix .. string.rep("\n", 16035 - #prefix - 1) .. '} } }'
E.luaBox:SetText(invalid); E.luaBox:Fire("OnTextChanged", invalid)
assert(not E:Save() and not E.mergeDialog and E.session.raw == invalid)
assert(E.luaBox:GetCursorPosition() == 16034)
assert(Code:Decode(E.luaBox.editBox.text:sub(E.luaBox.editBox.selection[1] + 1, E.luaBox.editBox.selection[2])) == "}")
assert(not E.notice:find("LuaData.lua", 1, true))
E:SelectTab("steps")
assert(E.tab == "lua" and E.luaBox:GetCursorPosition() == 16034 and E.session.raw == invalid,
    "A rejected visual tab conversion must reveal the same error after rebuilding the Lua editor")
TestCloseWorkshop(); TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Lua input: idle rendering, delayed native caret, rapid edits, selection/scroll preservation, Enter, deletion, search and timer pooling passed.")
