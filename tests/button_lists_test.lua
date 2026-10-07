local R = AprRC.options
for _, field in ipairs({ "Button", "SpellButton" }) do
    local definition = R.step[field]
    local buttons = assert(R:Parse(definition, '{ ["30778-1"] = 81356, ["5648"] = { 67890, 12345 }, ["42-2"] = { 1515 } }'))
    assert(buttons["30778-1"] == 81356 and buttons["5648"][1] == 67890 and buttons["5648"][2] == 12345)
    assert(type(buttons["42-2"]) == "table" and buttons["42-2"][1] == 1515)
    for _, invalid in ipairs({ '{}', '0', '-1', '1.5', '"12345"', 'true', '{ 0 }', '{ 1.5 }',
        '{ "12345" }', '{ { 12345 } }', '{ [2] = 12345 }', '{ [1] = 12345, [3] = 67890 }',
        '{ itemID = 12345 }', '{ 1e999 }' }) do
        assert(not R:Parse(definition, '{ ["5648"] = ' .. invalid .. ' }'), field .. " accepted " .. invalid)
    end
    assert(not R:Parse(definition, '{ [5648] = { 12345 } }'), "Quest keys must remain strings")
    assert(not R:Parse(definition, '{ ["0-1"] = { 12345 } }'))
    local route = { name = "Button lists", steps = { { [field] = buttons } },
        parallelSteps = { { conditions = {}, steps = { { [field] = { ["42"] = { 67890, 12345 } } } } } } }
    local source = AprRC.editorModel:RouteText(route)
    local imported = assert(AprRC:ReadRouteDefinition(source, route.name))
    assert(AprRC:DeepCompare(AprRC:BuildRouteDefinition(route), AprRC:BuildRouteDefinition(imported)))
    assert(#AprRC.luaLanguage:Analyze(source, {}) == 0, "Lists must pass Lua diagnostics")
    local formatted = assert(AprRC.luaLanguage:Format(source, 0))
    assert(AprRC:DeepCompare(AprRC:ParseLuaData(source), AprRC:ParseLuaData(formatted)))
    assert(not R:Parse(definition, '{ ["5648"] = 12345, ["5648"] = { 67890, 1515 } }'),
        "The recorder must flag duplicate keys before Lua can overwrite earlier buttons")

    local step = {}
    for _, id in ipairs({ 67890, 12345, 67890, 1515 }) do assert(R:AddStepButton(step, field, "5648", id)) end
    assert(AprRC:DeepCompare(step[field]["5648"], { 67890, 12345, 1515 }))
    assert(R:AddStepButton(step, field, "42-1", 81356) and step[field]["42-1"] == 81356)
    local previous = AprRC:CopyData(step)
    assert(not R:AddStepButton(step, field, "bad", 12345))
    assert(not R:AddStepButton(step, field, "5648", 0))
    assert(AprRC:DeepCompare(previous, step), "Invalid selections must not modify buttons")
end

local Language = AprRC.luaLanguage
for _, field in ipairs({ "Button", "SpellButton" }) do
    local kind = field == "Button" and "item" or "spell"
    for _, tail in ipairs({ '123', '{ 123', '{ 12345, 123' }) do
        local source = '{ steps = {{ ' .. field .. ' = { ["5648"] = ' .. tail
        assert(Language:Context(source, #source).kind == kind, source)
    end
    local source = '{ steps = {{ ' .. field .. ' = { ["5648"] = { '
    local context = Language:Context(source, #source)
    local candidates = Language:Candidates(context, { steps = { { [field] = { ["5648"] = { 87654, 87655 } } } } })
    local seen = {}
    for _, candidate in ipairs(candidates) do seen[candidate.insert] = true end
    assert(seen["87654"] and seen["87655"], "Completion must include IDs already used in button lists")
end
print("Button and SpellButton lists: validation, selection order, export, formatting and completion passed.")
