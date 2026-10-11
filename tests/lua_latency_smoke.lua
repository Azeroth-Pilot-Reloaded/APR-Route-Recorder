local E, Model, Code, Language, GUI = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode, AprRC.luaLanguage, LibStub("AceGUI-3.0")
TestCloseWorkshop(); TestRunTimers()
local route = assert(Model:NewRoute("Lua frame budget"))
for index = 1, 1200 do
    route.steps[index] = { Note = "Step " .. index, Coord = { x = index, y = -index }, Zone = 1411 }
end
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua"); E.follow = false; TestRunTimers()
local edit, box = E.luaBox, E.luaBox.editBox
local baseline = edit:GetText()
edit:SetCursorPosition(baseline:find('Step 600', 1, true) + #'Step 600' - 1); edit:SetFocus()

-- A deterministic profiler forces real coroutine pauses without depending on
-- machine speed. Zero-delay callbacks run on the next simulated game frame.
local oldAfter, oldClock = C_Timer.After, debugprofilestop
local now, ticks, timers = 0, 0, {}
debugprofilestop = function() ticks = ticks + 2; return ticks end
C_Timer.After = function(delay, callback) timers[#timers + 1] = { due = now + delay, callback = callback } end
local function frame(seconds)
    now = now + (seconds or 0.016)
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do
        if timer.due <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end
local function drain()
    for _ = 1, 2000 do
        if #timers == 0 then return end
        frame()
        assert(not box.text:find("\239\128\128", 1, true), "Selection markers must never remain between frames")
    end
    error("Lua background work did not finish")
end

local labels, clears, writes, analyses = 0, 0, 0, 0
local setLabel, setDiagnostics, analyze = E.luaDiagnosticLabel.SetText, edit.SetDiagnostics, Language.Analyze
E.luaDiagnosticLabel.SetText = function(self, ...) labels = labels + 1; return setLabel(self, ...) end
edit.SetDiagnostics = function(self, ...) clears = clears + 1; return setDiagnostics(self, ...) end
Language.Analyze = function(self, ...) analyses = analyses + 1; return analyze(self, ...) end
local onTextSet = box:GetScript("OnTextSet")
box:SetScript("OnTextSet", function() writes = writes + 1 end)

for _ = 1, 8 do box:Insert("x"); frame(0.03) end
assert(labels == 1 and clears == 1 and analyses == 0 and writes == 0,
    "A typing burst must invalidate diagnostics once, without analysis or relayout on each key")
frame(0.41)
assert(edit.pendingCode and writes == 0, "Preparing a long document must yield before rewriting native text")
box:Insert("y") -- Cancel rendering that is already suspended.
frame(0.1)
assert(edit.pendingCode and writes == 0 and analyses == 0, "Cancelled rendering must never publish stale text")
local expected, cursor = edit:GetText(), edit:GetCursorPosition()
local native = getmetatable(box).__index
native.HighlightText(box, box.cursor - 1, box.cursor)
drain()
assert(writes == 1 and analyses == 1 and labels == 2 and clears == 2)
assert(edit:GetText() == expected and E.session.raw == expected and E.luaAnalysisText == expected)
assert(edit:GetCursorPosition() == cursor and Code:Decode(box.text:sub(box.selection[1] + 1, box.selection[2])) == "y",
    "Asynchronous coloring must preserve the latest native caret and selection")
assert(#E.luaOutline == 1200 and #E.luaDiagnostics == 0)

-- Parser failures after a pause must still report source positions under Lua
-- 5.1, whose pcall cannot directly contain a coroutine yield.
local invalid = expected .. "\n!"
edit:EditText(invalid, #invalid)
assert(E.luaAnalysisToken and E.luaAnalysisText == nil, "Live validation must yield even for explicit edits")
drain()
assert(#E.luaDiagnostics == 1 and E.luaDiagnostics[1].location.position == #invalid)
local synchronous = analyze(Language, invalid, E.luaAnalysisBaseline)
assert(E.luaDiagnostics[1].message == synchronous[1].message)

-- A new edit cancels a parser already in flight, and F8 can force a fresh,
-- synchronous result without letting that old job overwrite the diagnostics.
edit:EditText(invalid .. "!", #invalid + 1)
assert(E.luaAnalysisToken)
edit:EditText(baseline, 0)
E:NavigateLuaDiagnostic(1)
assert(#E.luaDiagnostics == 0 and E.luaAnalysisText == baseline)
drain()
assert(#E.luaDiagnostics == 0 and E.luaAnalysisText == baseline and not E.session:IsDirty())

-- Suspending work must also be harmless when AceGUI releases and reuses the
-- native widget for another editor.
box:Insert(" "); frame(0.41)
assert(edit.pendingCode)
E.luaDiagnosticLabel.SetText, edit.SetDiagnostics, Language.Analyze = setLabel, setDiagnostics, analyze
box:SetScript("OnTextSet", onTextSet)
TestCloseWorkshop()
local reused = GUI:Create("APRLuaEditor")
reused:SetText('"Other editor"')
drain()
assert(reused:GetText() == '"Other editor"' and not reused.pendingCode)
GUI:Release(reused)
C_Timer.After, debugprofilestop = oldAfter, oldClock
TestRunTimers()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Lua latency: frame budgets, single invalidation, cancelled rendering/parsing, exact errors, native selection and widget reuse passed.")
