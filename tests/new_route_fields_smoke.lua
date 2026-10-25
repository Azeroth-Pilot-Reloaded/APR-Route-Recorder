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

local fields = UI.Form:Fields("routeConditions", {})
assert(fields.InterfaceVersionExact == "id" and fields.AnyOf == AprRC.options.step.AnyOf.schema)
assert(fields.MinLevel == "positive" and fields.KillNPC == nil)
assert(UI.Form:Fields("route", {}).legacyLabels == "strings")
assert(UI.Pickers:Resolve("text", "step/Dungeon").kind == "dungeon")
assert(UI.Pickers:Resolve("text", "step/KillNPC/dungeonKey").kind == "dungeon")
assert(UI.Pickers:Resolve("id", "route/sojournerAchievementID").kind == "achievement")

local originalCatalog, originalShow = APR.DungeonData, AprRC.autocomplete.ShowAutoComplete
APR.DungeonData = { forever = { SYNTHETIC = { name = "Practice dungeon", instanceID = 42 } } }
local selectedKey, hidden
AprRC.autocomplete.ShowAutoComplete = function(_, _, entries, accept)
    assert(entries.SYNTHETIC == "Practice dungeon")
    local frame = { Hide = function() hidden = true end }
    accept("", "SYNTHETIC", frame)
    return frame
end
UI.Pickers:Open({ kind = "dungeon" }, {}, function(value) selectedKey = value end)
assert(selectedKey == "SYNTHETIC" and hidden)
AprRC.autocomplete.ShowAutoComplete = function(_, _, entries, accept)
    assert(not next(entries))
    local frame = { Hide = function() end }
    accept("  OTHER_CLIENT  ", nil, frame)
    return frame
end
APR.DungeonData = nil
UI.Pickers:Open({ kind = "dungeon" }, {}, function(value) selectedKey = value end)
assert(selectedKey == "OTHER_CLIENT", "Absent client catalogs must still allow explicit dungeon keys")
APR.DungeonData, AprRC.autocomplete.ShowAutoComplete = originalCatalog, originalShow

local spells = { ["7-1"] = "Healing Touch" }
local spellForm = AprRC:CreateWidget("SimpleGroup")
UI.Form:Render(spellForm, AprRC.options.schemas.spellButtons, spells, function(value) spells = value end,
    { modes = {}, pages = {}, changed = function() end, redraw = function() end,
        error = function(message) error(message) end }, "step/SpellButton", "Spells")
local spellInput = assert(find(spellForm, "step/SpellButton/7-1"))
spellInput:Fire("OnTextChanged", "Healing Touch, 2050")
assert(spells["7-1"][1] == "Healing Touch" and spells["7-1"][2] == 2050)
LibStub("AceGUI-3.0"):Release(spellForm)
print("Wiki forms: route eligibility fields, loaded/manual dungeon keys and mixed spell buttons passed.")
