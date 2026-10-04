local E, GUI = AprRC.routeEditor, LibStub("AceGUI-3.0")
local route = assert(AprRC.editorModel:NewRoute("Compact objective rows"))
route.steps = { { Qpart = { [42] = { 1, 2 }, [84] = { 1 } },
    QpartPart = { [42] = { 2 } }, Fillers = { [84] = { 1 } } } }
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end
local function field(path)
    return assert(find(E.inspector, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function enter(widget, text) widget:SetText(text); widget:Fire("OnTextChanged", text) end
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
if E.compact then E:ToggleCompact() end
E.frame:SetWidth(1120); E.frame:DoLayout()
E.stepsSplit:SetRatio(0.49)
for _, name in ipairs({ "Qpart", "QpartPart", "Fillers" }) do
    local quest = field("step/" .. name .. "/" .. (name == "Fillers" and 84 or 42) .. "/questID")
    local objectives = quest.parent.parent.children[2].children[1]
    assert(quest.parent.parent == objectives.parent.parent)
    assert(quest.parent.parent.frame:GetHeight() == 44, "Valid objective rows must fit on one line")
    local columns, row = quest.parent.parent, quest.parent.parent.parent
    local trash = row.children[2]
    local _, target, anchor, offset = trash.frame:GetPoint()
    assert(target == row.content and anchor == "TOPRIGHT" and offset == 0, "Trash belongs at the row's right edge")
    assert(columns.frame:GetWidth() + trash.frame:GetWidth() + 8 <= row.content:GetWidth() + 1)
    local _, _, _, objectiveLeft = objectives.parent.frame:GetPoint()
    assert(objectiveLeft >= quest.parent.frame:GetWidth() + 12, "Input columns must have breathing room")
    for _, input in ipairs({ quest, objectives }) do
        local actions = input.parent.children[#input.parent.children]
        assert(input.frame:GetWidth() + actions.frame:GetWidth() + 8 <= input.parent.content:GetWidth() + 1)
    end
end
local quest, objectives = field("step/Qpart/42/questID"), field("step/Qpart/42")
quest:SetFocus(); enter(quest, "126")
assert(quest.editbox:HasFocus() and E.session.draft.steps[1].Qpart[126][2] == 2)
assert(not E.session.draft.steps[1].Qpart[42] and route.steps[1].Qpart[42])
enter(objectives, "2, 3")
assert(E.session.draft.steps[1].Qpart[126][2] == 3)
enter(objectives, "")
assert(not AprRC.options:ValidateValue("step", E.session.draft.steps[1]))
enter(objectives, "1, 2"); GUI:ClearFocus()
E:DrawInspector()
local add = assert(find(E.inspector, function(w) return w:GetUserData("addEntryPath") == "step/Qpart" end))
local _, relative, anchor, offset = add.frame:GetPoint()
assert(anchor == "TOPRIGHT" and relative == add.parent.content and offset == 0)
add:Fire("OnClick")
local pending = field("step/Qpart/0/questID")
assert(pending.editbox:HasFocus() and pending:GetText() == "" and E.session.draft.steps[1].Qpart[0])
local before = #E.inspector.children
find(E.inspector, function(w) return w:GetUserData("addEntryPath") == "step/Qpart" end):Fire("OnClick")
assert(field("step/Qpart/0/questID") == pending and #E.inspector.children == before)
local pendingObjectives = field("step/Qpart/0")
pendingObjectives.parent.children[#pendingObjectives.parent.children].children[1]:Fire("OnClick")
assert(not E.fieldPicker, "Choose a quest before opening its objectives")
assert(not AprRC.options:ValidateValue("step", E.session.draft.steps[1]), "An unfinished row must not be saved")
enter(pending, "168")
enter(field("step/Qpart/0"), "1, 2")
assert(E.session.draft.steps[1].Qpart[168][2] == 2)
GUI:ClearFocus(); E:DrawInspector()
local deleteRow = field("step/Qpart/168").parent.parent.parent
deleteRow.children[2]:Fire("OnClick")
assert(not E.session.draft.steps[1].Qpart[168])
E:Undo(-1)
assert(E.session.draft.steps[1].Qpart[168][2] == 2)
assert(E:Save() and AprRC.editorModel:Source(route.name).steps[1].Qpart[126][2] == 2)
E:ToggleCompact(); E.frame:SetWidth(440); E.frame:DoLayout(); E:ShowStepPane("inspector")
local narrowQuest = field("step/Qpart/126/questID")
local narrowObjectives = field("step/Qpart/126")
local narrowColumns = narrowQuest.parent.parent
assert(narrowColumns.frame:GetHeight() > 44, "Narrow rows wrap instead of squeezing their fields")
local _, _, _, _, objectiveTop = narrowObjectives.parent.frame:GetPoint()
assert(-objectiveTop >= narrowQuest.parent.frame:GetHeight() + 8)
assert(narrowQuest.frame:GetWidth() >= 100 and narrowObjectives.frame:GetWidth() >= 120)
E:ToggleCompact()
TestCloseWorkshop()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Compact quest/objective rows: layout, ID edits, validation, insertion, deletion and undo passed.")
