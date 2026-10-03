local E, UI, Model = AprRC.routeEditor, AprRC.editorUI, AprRC.editorModel
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function addStep(key)
    E.addType = key
    E:DrawTab()
    local add = assert(walk(E.listPanel, function(widget)
        return widget.type == "Button" and widget.text:GetText() == UI.Text("Add")
    end))
    add:Fire("OnClick")
end
local previousFollow, previousAPRFollow = E.follow, AprRC.settings.profile.followAPR
local route = assert(Model:NewRoute("Manual step scrolling"))
for index = 1, 100 do route.steps[index] = { Note = "Step " .. index } end
AprRCData.CurrentRoute = route
AprRC.settings.profile.recordBarFrame.isRecording = true
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow, AprRC.settings.profile.followAPR = false, false

-- Visual insertion reveals the selected row, including page boundaries.
E.session.selected, E.page = 39, 1
addStep("Note")
assert(E.session.selected == 40 and E.page == 1)
assert(E.list.localstatus.scrollvalue == 1000 and E.session:IsDirty())
TestRunTimers()
assert(E.list.localstatus.scrollvalue == 1000)
E.duplicate:Fire("OnClick")
assert(E.session.selected == 41 and E.page == 2)
assert(E.list.children[1]:GetUserData("stepIndex") == 41)
assert(E.list.localstatus.scrollvalue == 0)
TestRunTimers()

-- A middle insertion scrolls to that row after layout settles, not the page end.
E.session.selected = 60
addStep("Note")
local list, row = E.list, E.list.children[21]
local getTop, contentHeight, viewportHeight = row.frame.GetTop, list.content.GetHeight, list.scrollframe.GetHeight
row.frame.GetTop = function() return list.content:GetTop() - 600 end
list.content.GetHeight = function() return 1400 end
list.scrollframe.GetHeight = function() return 400 end
TestRunTimers()
assert(E.session.selected == 61 and E.list.localstatus.scrollvalue == 600)
row.frame.GetTop, list.content.GetHeight, list.scrollframe.GetHeight = getTop, contentHeight, viewportHeight

-- Completion is appended even when an earlier step was selected.
E.session.selected, E.page = 1, 1
E.query, E.filter = "no matching steps", "quests"
addStep("RouteCompleted")
assert(E.session.selected == #E.session.draft.steps and E.page == 3)
assert(E.query == "" and E.filter == "all" and E.list.localstatus.scrollvalue == 1000)
E.session:Reload(); E:DrawTab(); TestRunTimers()

-- The same Add button also reveals new steps inside a parallel group.
E:SelectTab("parallel"); E.addGroup:Fire("OnClick")
for index = 1, 39 do E.session:Insert({ Note = "Parallel " .. index }, nil, 1) end
addStep("Note")
assert(E.session.parallelSelected == 40 and E.page == 1)
assert(E.list.localstatus.scrollvalue == 1000)
E.duplicate:Fire("OnClick")
assert(E.session.parallelSelected == 41 and E.page == 2)
assert(#E.list.children == 1 and E.list.children[1]:GetUserData("stepIndex") == 41)
E.session:Reload(); E:SelectTab("steps"); TestRunTimers()

-- Legacy commands reveal new steps just like registered commands and buttons.
E.session.selected, E.page = 1, 1
E:DrawTab()
AprRC.command:SlashCmd("addreset")
TestRunTimers(); TestRunTimers()
assert(E.session.selected == #route.steps and E.page == 3)
assert(E.session.draft.steps[E.session.selected].ResetRoute and E.list.localstatus.scrollvalue == 1000)

-- Lua targets the actual added step, even if automatic capture appends after it.
E:SelectTab("lua")
E.luaBox.editBox:SetFocus()
AprRC.command:SlashCmd("note Manual Lua step")
local manualIndex = #route.steps
AprRC:NewStep({ Note = "Automatic next step" })
TestRunTimers()
local box, range = E.luaBox, E.luaStepPositions.steps[manualIndex]
assert(E.session.selected == manualIndex and E.luaBox.editBox:HasFocus())
assert(box.editBox:GetCursorPosition() == range.start and box.scrollFrame:GetVerticalScroll() > 0)
local selected = assert(AprRC:ParseLuaData(box:GetText():sub(range.start + 1, range.finish)))
assert(selected.Note == "Manual Lua step")
-- Simulate a scroll reset between initial rendering and the next-frame callback.
box.scrollFrame:SetVerticalScroll(0)
TestRunTimers()
assert(box.editBox:GetCursorPosition() == range.start and box.scrollFrame:GetVerticalScroll() > 0)

-- A manual command must still preserve an incomplete unsaved Lua draft.
local raw = "{ steps = { -- unfinished manual draft"
box:SetText(raw); box:Fire("OnTextChanged", raw)
AprRC.command:SlashCmd("note Preserve manual draft")
TestRunTimers(); TestRunTimers()
assert(E.luaBox:GetText() == raw and E.session.raw == raw and not E.pendingManualStep)
E.session:Reload(); E.luaBox.editBox:ClearFocus(); E:SelectTab("steps")

-- Switching routes cancels a queued jump before the refresh callback runs.
AprRC.command:SlashCmd("note Before route switch")
local other = assert(Model:NewRoute("Manual scroll other route"))
other.steps = { { Note = "Other first" }, { Note = "Other second" } }
E:SelectRoute(other.name)
TestRunTimers(); TestRunTimers()
assert(E.session.name == other.name and E.session.selected == 1 and not E.pendingManualStep)
TestCloseWorkshop(); TestRunTimers()
E.follow, AprRC.settings.profile.followAPR = previousFollow, previousAPRFollow
AprRC.settings.profile.recordBarFrame.isRecording = false
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Manual Add/duplicate, main/parallel pagination, command jumps and deferred Lua scrolling passed.")
