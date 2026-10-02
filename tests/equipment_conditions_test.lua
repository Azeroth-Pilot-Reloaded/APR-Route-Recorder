local R = AprRC.options
for _, key in ipairs({ "EquippedItem", "EquippedItemStat" }) do
    local entry = key == "EquippedItem" and { slot = 16, itemID = 100, invert = true } or
        { slot = 16, stat = "QUALITY", operator = "<", value = 7, precision = 1, allowMissing = true }
    local second = AprRC:CopyData(entry)
    second.slot = 17
    local entries = { entry, second }
    assert(R:ValidateValue(R.step[key].schema, entry), "Legacy objects remain valid")
    assert(R:ValidateValue(R.step[key].schema, entries))
    assert(not R:ValidateValue(R.step[key].schema, {}))
    assert(not R:ValidateValue(R.step[key].schema, { entry, {} }))
    assert(not R:ValidateValue(R.step[key].schema, { [2] = entry }))
    local condition = { AllOf = { { [key] = entries }, { Not = { [key] = entries } } } }
    assert(R:ValidateValue("conditions", condition))
    local parsed = assert(R:Parse(R.step[key], AprRC:SerializeData(entries)))
    assert(AprRC:DeepCompare(parsed, entries))
    local route = { name = "Equipment lists", steps = { { [key] = entries } },
        parallelSteps = { { conditions = condition, steps = { { [key] = entries } } } } }
    local exported = AprRC:BuildRouteDefinition(route)
    local imported = assert(AprRC:ReadRouteDefinition(AprRC:SerializeData(exported), route.name))
    assert(AprRC:DeepCompare(exported, AprRC:BuildRouteDefinition(imported)))
end

for _, sale in ipairs({ { equippedSlots = { 16 } }, { junk = true, equippedSlots = { 16, 18 }, questID = 42 },
    { items = { 36 }, equippedSlots = { 16 }, npcID = 54 } }) do
    local parsed = assert(R:Parse(R.step.SellItems, AprRC:SerializeData(sale)))
    assert(AprRC:DeepCompare(parsed, sale))
    local route = { name = "Equipped sales", steps = { { SellItems = sale } } }
    local exported = AprRC:BuildRouteDefinition(route)
    local imported = assert(AprRC:ReadRouteDefinition(AprRC:SerializeData(exported), route.name))
    assert(AprRC:DeepCompare(exported, AprRC:BuildRouteDefinition(imported)), "Sale slots must survive export/import")
end
