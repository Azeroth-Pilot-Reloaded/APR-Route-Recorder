local R = AprRC.options
local count = 0
for command, definition in pairs(R.commands) do
    local value, err = R:Parse(definition, definition.example)
    assert(value ~= nil, command .. ": " .. tostring(err))
    local restored = AprRC:ParseLuaData(AprRC:SerializeData(value))
    assert(AprRC:DeepCompare(value, restored), command)
    count = count + 1
end
assert(count >= 100, "Missing route syntax commands")
local function value(command, input)
    return R:Parse(assert(R.commands[command], command), input)
end
assert(value("hasspell", "34090") == 34090)
assert(value("hasspell", "{ 34090 }") == nil)
assert(value("minlevel", "MidnightDelves") == "MidnightDelves")
assert(value("grind", "87.5") == 87.5)
assert(value("skipforlvl", "89.18") == 89.18)
assert(value("xpconsumables", "false") == false)
assert(value("note", "Open the map") == "Open the map")
assert(value("classspec", 'APR.Specs["Mage - Frost"]') == 64)
assert(value("minlevel", "MisspelledProfile") == nil)
assert(value("route conditions", '{ MinLevel = "MidnightDelves" }') == nil)
assert(value("route conditions", '{ IsQuestOnQuest = 42 }') == nil)
assert(value("route conditions", '{ AnyOf = { { Level = 80 } } }') == nil)
assert(value("route conditions", '{ Class = { 8 } }') == nil)
assert(value("anyof", '{ { IsQuestOnQuest = 42 }, { IsQuestUncompleted = 43 } }'))
assert(value("lootitems", '{ { itemID = 42, quantity = 0 } }') == nil)
assert(value("isquestonquest", "0") == nil)
assert(value("invehicle", "3") == nil)
assert(value("reputation", '{ factionID = 72, type = "standard", level = 9 }') == nil)
assert(R.step.Qpart and R:Parse(R.step.Qpart, '{ [12345] = { 1, 2 } }')[12345][2] == 2)
assert(value("spellbutton", '{ ["12345-1"] = 42 }')["12345-1"] == 42)
assert(value("spellbutton", '{ ["0-1"] = 42 }') == nil)
assert(value("takeportal", '{ questID = 42, mapID = 85 }').mapID == 85)
assert(value("takeportal", '{ questID = 42, ZoneId = 85 }') == nil)
assert(R.commands.qpart == nil and R.step.Qpart and R:Parse(R.step.Qpart, '{ [12345] = { 1, 2 } }')[12345][2] == 2)
for _, command in ipairs({
    "pickup", "done", "qpart", "seths", "usehs", "usedalahs", "usegarrisonhs", "getfp",
    "learnprofession", "warmode", "vehicleexit", "mountvehicle", "gossipoptionids",
    "extraactionb", "useglider", "raidicon", "achievementstep", "leavequests", "treasure",
    "emote", "buymerchant", "chromiepick"
}) do
    assert(R.commands[command] == nil, "Auto-managed command is still exposed: " .. command)
end
local route = {
    name = "2393-Test",
    label = "My route",
    expansion = "Midnight",
    category = "Leveling",
    XPConsumables = false,
    steps = { { Note = "Open the map" }, { RouteCompleted = true } },
    parallelSteps = { { conditions = { IsQuestReadyForTurnIn = 42 }, steps = { { Done = { 42 } } } } }
}
local exported = AprRC:BuildRouteDefinition(route)
local imported, err = AprRC:ReadRouteDefinition(AprRC:SerializeData(exported), route.name)
assert(imported, err)
assert(imported.XPConsumables == false and imported.parallelSteps[1].steps[1].Done[1] == 42)
assert(imported.label == "My route" and route.steps[1]._index == nil)
local old = assert(AprRC:ReadRouteDefinition('{ { Note = "New text" } }', route.name, route))
assert(old.XPConsumables == false and old.label == "My route" and old.steps[1].Note == "New text")
assert(AprRC:ReadRouteDefinition('{ { RouteCompleted = true }, { Note = "Too late" } }', route.name) == nil)
AprRCData.CurrentRoute = route
local ok, why = R:Apply(R.commands["route label"], "A new label", route)
assert(ok, why)
assert(route.label == "A new label")
AprRC.settings.profile.recordBarFrame.isRecording = false
assert(not R:Apply(R.commands["route label"], "Wrong label", route))
AprRC.settings.profile.recordBarFrame.isRecording = true
AprRCData.CurrentRoute = { name = "Other", steps = {} }
assert(not R:Apply(R.commands["route label"], "Wrong label", route))
assert(route.label == "A new label")
