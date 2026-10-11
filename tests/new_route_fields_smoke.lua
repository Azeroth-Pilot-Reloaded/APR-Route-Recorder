local E, UI = AprRC.routeEditor, AprRC.editorUI
local function find(widget, path)
    if widget:GetUserData("fieldPath") == path then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = find(child, path)
        if found then return found end
    end
end
local route = assert(AprRC.editorModel:NewRoute("New route fields UI"))
route.steps = { { EquipItem = { itemID = 2030, slot = 16 } } }
route.parallelSteps = { { repeatable = false, steps = {
    { UseItem = { questID = 1, itemID = 2030, itemSpellID = 8690 } } } } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("parallel")
E.groupConditions:Fire("OnClick")
local repeatable = assert(find(E.inspector, "route/parallelSteps/1/repeatable"))
assert(repeatable.type == "CheckBox")
repeatable:Fire("OnValueChanged", true)
assert(E.session.draft.parallelSteps[1].repeatable == true)
assert(route.parallelSteps[1].repeatable == false, "Editing must stay in the draft")
assert(E.session:Read(), "Optional group conditions must save correctly")
assert(E.session:Undo(-1) and E.session.draft.parallelSteps[1].repeatable == false)
assert(UI.Pickers:Resolve("ids", "step/Grind/variant/questLogXP").kind == "quest")

local parent = AprRC:CreateWidget("SimpleGroup")
local value = { { spellID = 8690, operator = "<", seconds = 2.5, once = false } }
local context = { modes = {}, pages = {}, inlineSections = true, changed = function() end }
local function render()
    parent:ReleaseChildren()
    UI.Form:Render(parent, AprRC.options.schemas.skipIfCooldown, value, function(updated) value = updated end,
        context, "step/SkipIfCooldown", UI.Label("SkipIfCooldown"))
end
context.redraw = render
render()
local seconds = assert(find(parent, "step/SkipIfCooldown/1/variant/seconds"))
seconds:SetText("3.5"); seconds:Fire("OnTextChanged", "3.5")
assert(value[1].seconds == 3.5 and value[1].spellID == 8690 and value[1].once == false)
LibStub("AceGUI-3.0"):Release(parent)
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("New route forms: repeatable drafts/undo, quest XP picker and spell cooldown editing passed.")
