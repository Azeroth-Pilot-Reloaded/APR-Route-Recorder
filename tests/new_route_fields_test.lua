local R, Model = AprRC.options, AprRC.editorModel
local equip, cooldown = R.commands.equipitem, R.commands.skipifcooldown
assert(equip.newStep and not equip.coord and R:GetCategory(equip) == "Actions")
assert(not cooldown.newStep and not cooldown.condition and R:GetCategory(cooldown) == "Conditions")
assert(R:Parse(equip, '{ itemID = 2030, slot = 16 }'))
for _, text in ipairs({ '{}', '{ itemID = 2030 }', '{ itemID = 0, slot = 16 }',
    '{ itemID = 2030, slot = 20 }', '{ itemID = 2030, slot = 1.5 }' }) do
    assert(not R:Parse(equip, text), text)
end
local rules = assert(R:Parse(cooldown,
    '{ { itemID = 6948, operator = ">", seconds = 2.5, once = true },' ..
    ' { spellID = 8690, operator = "<", seconds = 0, once = false } }'))
for _, text in ipairs({ '{}', '{ { operator = ">", seconds = 2 } }',
    '{ { itemID = 6948, spellID = 8690, operator = ">", seconds = 2 } }',
    '{ { itemID = 6948, operator = ">=", seconds = 2 } }',
    '{ { itemID = 6948, operator = ">", seconds = -1 } }',
    '{ { itemID = 6948, operator = ">", seconds = 1e999 } }',
    '{ { itemID = 6948, operator = ">", seconds = 2, once = 1 } }' }) do
    assert(not R:Parse(cooldown, text), text)
end
assert(R:ValidateValue("step", { UseHS = 1, SkipIfCooldown = rules }))
assert(not R:ValidateValue("conditions", { SkipIfCooldown = rules }))
assert(not R:ValidateValue("conditions", { AnyOf = { { SkipIfCooldown = rules } } }))
assert(not R:ValidateValue("routeConditions", { SkipIfCooldown = rules }))
assert(not R:ValidateValue("conditions", { EquipItem = { itemID = 2030, slot = 16 } }))
local target = { level = 60, xp = -700, questLogXP = { 4901, 4508 } }
for _, key in ipairs({ "Grind", "Level", "MinLevel", "MaxLevel", "SkipForLvl" }) do
    assert(R:ValidateValue(R.step[key].schema, target), key)
    assert(not R:ValidateValue(R.step[key].schema, { level = 60, xp = 0, questLogXP = {} }))
    assert(not R:ValidateValue(R.step[key].schema, { level = 60, xp = 0, questLogXP = { 0 } }))
end
assert(not R:ValidateValue("routeConditions", { MinLevel = target }))
assert(not R:ValidateValue(R.step.BeLvl.schema, target))
local group = { repeatable = true, conditions = { ItemCount = { itemID = 2030, count = 1 } },
    steps = { { UseItem = { questID = 1, itemID = 2030, itemSpellID = 8690 } } } }
assert(R:ValidateValue(R.schemas.parallel, { group }))
assert(R:ValidateValue(R.schemas.parallel, { { repeatable = false, steps = { { Note = "Unconditional" } } } }))
assert(not R:ValidateValue(R.schemas.parallel, { { repeatable = "true", steps = {} } }))

local previousRoute, previousRecording = AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording
local route = { name = "2393-NewRouteFields", steps = {} }
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = route, true
assert(R:Apply(equip, { itemID = 2030, slot = 16 }, route))
local step = route.steps[1]
assert(Model:StepKind(step) == "EquipItem")
assert(R:Apply(cooldown, rules, route, step))
assert(#route.steps == 1 and step.EquipItem.itemID == 2030 and step.SkipIfCooldown[2].once == false)
route.steps[2] = { Grind = target }
route.parallelSteps = { group, { repeatable = false, steps = { { Note = "No conditions" } } } }
local exported = Model:RouteText(route)
local imported = assert(AprRC:ReadRouteDefinition(exported, route.name))
assert(AprRC:DeepCompare(imported.steps, route.steps))
assert(AprRC:DeepCompare(imported.parallelSteps, route.parallelSteps))
local definition = AprRC:BuildRouteDefinition(imported)
assert(definition.parallelSteps[1].repeatable == true and definition.parallelSteps[2].repeatable == false)
assert(definition.steps[2].Grind.questLogXP[2] == 4508)
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = previousRoute, previousRecording
print("New route fields: command recording, cooldown scopes, XP credit, repeatable groups and export passed.")
