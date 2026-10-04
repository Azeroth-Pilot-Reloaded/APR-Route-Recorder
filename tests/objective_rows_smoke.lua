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
for _, name in ipairs({ "Qpart", "QpartPart", "Fillers" }) do
    local quest = field("step/" .. name .. "/questID")
    local objectives = quest.parent.parent.children[2].children[1]
    assert(quest.parent.parent == objectives.parent.parent)
    assert(quest.parent.parent.frame:GetHeight() == 44, "Valid objective rows must fit on one line")
end
local quest, objectives = field("step/Qpart/questID"), field("step/Qpart/42")
quest:SetFocus(); enter(quest, "126")
assert(quest.editbox:HasFocus() and E.session.draft.steps[1].Qpart[126][2] == 2)
assert(not E.session.draft.steps[1].Qpart[42] and route.steps[1].Qpart[42])
enter(objectives, "2, 3")
assert(E.session.draft.steps[1].Qpart[126][2] == 3)
enter(objectives, "")
assert(not AprRC.options:ValidateValue("step", E.session.draft.steps[1]))
enter(objectives, "1, 2"); GUI:ClearFocus()
E:DrawInspector()
local body = field("step/Qpart/126").parent.parent.parent.parent
local newRow = body.children[#body.children]
local columns = newRow.children[1]
enter(columns.children[1].children[1], "168")
enter(columns.children[2].children[1], "1, 2")
newRow.children[2]:Fire("OnClick")
assert(E.session.draft.steps[1].Qpart[168][2] == 2)
local deleteRow = field("step/Qpart/168").parent.parent.parent
deleteRow.children[2]:Fire("OnClick")
assert(not E.session.draft.steps[1].Qpart[168])
E:Undo(-1)
assert(E.session.draft.steps[1].Qpart[168][2] == 2)
assert(E:Save() and AprRC.editorModel:Source(route.name).steps[1].Qpart[126][2] == 2)
TestCloseWorkshop()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Compact quest/objective rows: layout, ID edits, validation, insertion, deletion and undo passed.")
