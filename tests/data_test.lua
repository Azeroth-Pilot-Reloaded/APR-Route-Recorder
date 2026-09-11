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
local export = AprRC:StringToTable(AprRC:TableToString(route))
assert(export[1].TakePortal.mapID == 85 and export[1].TakePortal.ZoneId == nil)
assert(export[1]._index == 1 and route[1]._index == nil)
