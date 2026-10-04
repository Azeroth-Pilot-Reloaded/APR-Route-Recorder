local input = {
    Note = 'Keep spaces, "quotes", -- dashes\nand lines',
    PreviewImages = { "routeHelper\\86644.jpg" },
    Qpart = { [12345] = { 1, 2 } },
    Button = { ["12345-1"] = 42 },
    XPConsumables = false
}
local encoded = AprRC:SerializeData(input)
local decoded, err = AprRC:ParseLuaData(encoded)
assert(decoded, err)
assert(AprRC:DeepCompare(input, decoded), encoded)
assert(AprRC:ParseLuaData('{ -- comment\n Note = "Open the map" }').Note == "Open the map")
assert(AprRC:ParseLuaData('APR.REPUTATION_TYPE.Renown') == "renown")
for _, invalid in ipairs({ '{ x = function() end }', '(function() while true do end end)()',
    '{ x = 1, x = 2 }', '{ [true] = 1 }', '{1} trailing', '1e999' }) do
    assert(AprRC:ParseLuaData(invalid) == nil, invalid)
end
local route = { { Note = "Keep this text", TakePortal = { questID = 42, mapID = 85 } } }
-- Syntax diagnostics preserve byte offsets for the editor and count visible
-- UTF-8 columns across Windows and Unix line endings.
local invalid = '{\r\n    Note = "é",\r\n    Zone = }'
local value, message, comments, location = AprRC:ParseLuaData(invalid, true)
assert(not value and not comments and location.position == #invalid)
assert(location.line == 3 and location.column == 12 and not message:find("LuaData.lua", 1, true))
local _, _, _, unicode = AprRC:ParseLuaData('{ Note = "é", Zone = }')
assert(unicode.column == #'{ Note = "é", Zone = }' - 1)
local prefix = '{ steps = { { Note = '
local broken = prefix .. string.rep(" ", 16035 - #prefix - 1) .. '} } }'
local _, detail, _, exact = AprRC:ParseLuaData(broken)
assert(exact.position == 16035 and exact.column == 16035 and detail:find("16035", 1, true))
local _, _, _, eof = AprRC:ParseLuaData('{ Note = "unfinished')
assert(eof.position == #'{ Note = "unfinished' + 1)
local export = AprRC:StringToTable(AprRC:TableToString(route))
assert(export[1].TakePortal.mapID == 85 and export[1].TakePortal.ZoneId == nil)
assert(export[1]._index == 1 and route[1]._index == nil)

-- Keep one field per line, with all nested step data compact and importable.
local compactSteps = {
    { PickUp = { 91281 }, NoArrow = true, Zones = { 84, 85, 2339 }, _index = 1 },
    { Qpart = { [88719] = { 1 } }, Button = { ["88719-1"] = 239151 },
        Coords = { { Zone = 85, x = -4436, y = 1590.3 }, { Zone = 2339, x = -2462.1, y = 2813.4 } },
        Faction = "Horde", _index = 2 },
}
local compactText = AprRC:TableToString(compactSteps)
assert(compactText == [[{
    {
        PickUp = { 91281 },
        NoArrow = true,
        Zones = { 84, 85, 2339 },
        _index = 1,
    },
    {
        Qpart = { [88719] = { 1 } },
        Coords = { { Zone = 85, x = -4436, y = 1590.3 }, { Zone = 2339, x = -2462.1, y = 2813.4 } },
        Button = { ["88719-1"] = 239151 },
        Faction = "Horde",
        _index = 2,
    },
}]], compactText)
assert(AprRC:DeepCompare(compactSteps, assert(AprRC:ParseLuaData(compactText))))

local definition = { steps = compactSteps, parallelSteps = { { steps = {
    { Qpart = { [88719] = { 2 } }, Coord = { x = -4509.5, y = 11124.7 },
        AnyOf = { { HasSpell = { 42, 43 } }, { Not = { HasQuest = 88719 } } },
        Button = {}, Note = input.Note, XPConsumables = false },
} } } }
local definitionText = AprRC:SerializeData(definition)
assert(definitionText:find('            PickUp = { 91281 },\n', 1, true), definitionText)
assert(definitionText:find('                    Qpart = { [88719] = { 2 } },\n', 1, true), definitionText)
assert(definitionText:find('Coord = { x = -4509.5, y = 11124.7 },\n', 1, true), definitionText)
assert(definitionText:find('AnyOf = { { HasSpell = { 42, 43 } }, { Not = { HasQuest = 88719 } } },\n', 1, true), definitionText)
assert(definitionText:find('Button = {},\n', 1, true), definitionText)
assert(AprRC:DeepCompare(definition, assert(AprRC:ParseLuaData(definitionText))))

local conditions = {
    EquippedItem = { invert = true, itemID = 5387, slot = 15 },
    EquippedItemStat = { allowMissing = true, operator = "<", precision = 1, slot = 15, stat = "QUALITY", value = 7 },
    ItemCount = { count = 1, itemID = 5387 },
}
definition.conditions = conditions
definition.parallelSteps[1].conditions = AprRC:CopyData(conditions)
definition.nextRoute = { "2393-Next", { route = "2393-Conditional", conditions = { ItemCount = conditions.ItemCount } } }
definition.prefab = { speedrun = { index = 10, conditions = { Class = { "MAGE", "WARLOCK" } } } }
definitionText = AprRC:SerializeData(definition)
local function conditionBlock(indent)
    return "conditions = {\n" .. indent .. [[    EquippedItem = { invert = true, itemID = 5387, slot = 15 },]] .. "\n" ..
        indent .. [[    EquippedItemStat = { allowMissing = true, operator = "<", precision = 1, slot = 15, stat = "QUALITY", value = 7 },]] .. "\n" ..
        indent .. [[    ItemCount = { count = 1, itemID = 5387 },]] .. "\n" .. indent .. "},"
end
assert(definitionText:find(conditionBlock("    "), 1, true), definitionText)
assert(definitionText:find(conditionBlock("            "), 1, true), definitionText)
assert(definitionText:find([[nextRoute = { "2393-Next", { conditions = { ItemCount = { count = 1, itemID = 5387 } }, route = "2393-Conditional" } },]], 1, true), definitionText)
assert(definitionText:find('Class = { "MAGE", "WARLOCK" },\n', 1, true), definitionText)
local prefabPosition = assert(definitionText:find("    prefab = {\n", 1, true))
local parallelPosition = assert(definitionText:find("    parallelSteps = {\n", 1, true))
assert(prefabPosition < parallelPosition, definitionText)
assert(AprRC:DeepCompare(definition, assert(AprRC:ParseLuaData(definitionText))))
