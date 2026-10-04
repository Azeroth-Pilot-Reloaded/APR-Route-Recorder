local Model = AprRC.editorModel
local previousData, previousCategory = AprRCData, APR.CATEGORIES.Leveling
-- Categories are localized values; exports must use the public enum name.
APR.CATEGORIES.Leveling = "Quêtes"
local route = {
    name = "1411-Route Lua", label = "Starting Zone Troll/Orc - NEO WIP",
    expansion = "WoW Forever", gameVersion = "forever", category = "Quêtes", mapID = 1411,
    conditions = { Race = { "Troll", "Orc" } },
    nextRoute = {
        { route = "Forever-Generated-Horde-Tirisfal-Glades", conditions = {
            Race = "Orc", Class = { "MAGE", "ROGUE", "WARLOCK", "WARRIOR" } } },
        { route = "Forever-Generated-Horde-The-Barrens", conditions = {
            Race = "Orc", Class = { "HUNTER", "SHAMAN" } } },
        { route = "Forever-Generated-Horde-Tirisfal-Glades", conditions = {
            Race = "Troll", Class = { "MAGE", "PRIEST", "ROGUE", "WARLOCK", "WARRIOR" } } },
        { route = "Forever-Generated-Horde-The-Barrens", conditions = {
            Race = "Troll", Class = { "HUNTER", "SHAMAN" } } },
    },
    prefab = { leveling = { index = 3 }, speedrun = { index = 3 }, starting_zone = 3 },
    steps = { { PickUp = { 1 }, Race = "Troll", Class = "MAGE", Event = "Remix", _index = 1,
        Note = "-- this is text, not a comment" } },
}
local original = AprRC:CopyData(route)
local text, ranges = Model:RouteText(route, true)
local expectedHeader = [[{
    label = "Starting Zone Troll/Orc - NEO WIP",
    expansion = APR.EXPANSIONS.Forever,
    gameVersion = APR.GAME_VERSIONS.Forever,
    category = APR.CATEGORIES.Leveling,
    mapID = 1411,
    conditions = { Race = { APR.RACES.Troll, APR.RACES.Orc } },
    nextRoute = {
        { route = "Forever-Generated-Horde-Tirisfal-Glades", conditions = { Race = APR.RACES.Orc, Class = { APR.Classes.Mage, APR.Classes.Rogue, APR.Classes.Warlock, APR.Classes.Warrior } } },
        { route = "Forever-Generated-Horde-The-Barrens", conditions = { Race = APR.RACES.Orc, Class = { APR.Classes.Hunter, APR.Classes.Shaman } } },
        { route = "Forever-Generated-Horde-Tirisfal-Glades", conditions = { Race = APR.RACES.Troll, Class = { APR.Classes.Mage, APR.Classes.Priest, APR.Classes.Rogue, APR.Classes.Warlock, APR.Classes.Warrior } } },
        { route = "Forever-Generated-Horde-The-Barrens", conditions = { Race = APR.RACES.Troll, Class = { APR.Classes.Hunter, APR.Classes.Shaman } } },
    },
    prefab = { [APR.PREFAB_TYPES.Leveling] = { index = 3 }, [APR.PREFAB_TYPES.Speedrun] = { index = 3 }, [APR.PREFAB_TYPES.StartingZone] = 3 },
]]
assert(text:sub(1, #expectedHeader) == expectedHeader, text)
assert(AprRC:DeepCompare(route, original), "Export must not mutate saved data")
local range = ranges.steps[1]
local stepText = text:sub(range.start + 1, range.finish)
assert(stepText == AprRC:SerializeData(route.steps[1], 2, "fields", nil, nil, "step"),
    "Editor and standalone step formatting must match")
assert(AprRC:DeepCompare(assert(AprRC:ReadRouteDefinition(text, route.name)), route))
assert(AprRC:RouteToString(route):find(expectedHeader, 1, true) == 1)

-- Nested metadata supports logical conditions and enums with non-identifier keys.
local nested = AprRC:CopyData(route)
nested.nextRoute[1].conditions = { AnyOf = { { Class = "DEATHKNIGHT" }, { Not = { Race = "Orc" } } },
    ClassSpec = 64, Event = "Remix" }
local nestedText = Model:RouteText(nested)
assert(nestedText:find('Class = APR.Classes["Death Knight"]', 1, true), nestedText)
assert(nestedText:find('Not = { Race = APR.RACES.Orc }', 1, true), nestedText)
assert(nestedText:find('ClassSpec = APR.Specs["Mage - Frost"]', 1, true), nestedText)
assert(nestedText:find('Event = APR.EVENTS.Remix', 1, true), nestedText)
assert(AprRC:DeepCompare(assert(AprRC:ReadRouteDefinition(nestedText, route.name)), nested))
local unknown = Model:RouteText({ steps = {}, expansion = "Future Expansion" })
assert(unknown:find('expansion = "Future Expansion"', 1, true), unknown)

-- Comments survive the editor's raw -> form -> save -> reopen lifecycle.
AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
local session = Model:Open(route)
session.raw = "--route µ\n" .. text:gsub('    label =', '    --label µ\n    label =', 1)
    :gsub('            PickUp =', '            --step µ\n            PickUp =', 1)
    :gsub('    conditions = { Race =', '    conditions = { --race µ\n Race =', 1)
    :gsub('    mapID = 1411,', '    mapID = 1411, --map µ', 1)
    .. "\n--end µ"
assert(session:ApplyRaw())
assert(session:IsDirty(), "Adding comments must count as an edit")
assert(AprRC:DeepCompare(session.draft.steps, original.steps), "Comments must not become step fields")
assert(session:Save())
local saved = AprRC:FindRouteByName(route.name)
local reopened = Model:Open(saved)
assert(not reopened:IsDirty() and not reopened:IsStale())
local commentedText, commentedRanges = Model:RouteText(reopened.draft, true)
for _, comment in ipairs({ "--route µ", "--label µ", "--step µ", "--race µ", "--map µ", "--end µ" }) do
    assert(commentedText:find(comment, 1, true), commentedText)
end
assert(commentedText:find('mapID = 1411, --map µ\n', 1, true), commentedText)
local commentedRange = commentedRanges.steps[1]
assert(AprRC:DeepCompare(assert(AprRC:ParseLuaData(commentedText:sub(commentedRange.start + 1,
    commentedRange.finish))), original.steps[1]), "Comments must not break step byte ranges")
reopened.draft.label = "Changed through the form"
reopened:Snapshot()
assert(reopened:Save())
assert(Model:RouteText(reopened.draft):find("--step µ", 1, true))
local plan = assert(reopened:MergePlan())
assert(#plan.conflicts == 0, "Commented baselines must merge without false conflicts")
assert(AprRC:BuildRouteDefinition(saved).steps[1]._luaComments == nil)
-- APR receives only runtime route data, without the recorder's comment storage.
AprRC:SyncRouteToAPR(AprRC:FindRouteByName(route.name))
local key = AprRCData.APRRouteKeys and AprRCData.APRRouteKeys[route.name]
if key then assert(APRData.CustomRoute[key]._luaComments == nil) end
-- A comment is removable by deleting it from the Lua editor.
reopened.raw = Model:RouteText(route)
assert(reopened:Save())
assert(reopened.draft._luaComments == nil)

assert(AprRC:ParseLuaData('APR.GAME_VERSIONS.Forever') == "forever")
assert(AprRC:ParseLuaData('{ --comment µ\r value = 3 }').value == 3)
local block = assert(AprRC:ReadRouteDefinition('--[=[before µ]=]\n{ steps = { --[[inside]]\n' ..
    '{ Note = "literal --µ" } } } --[==[after]==]', route.name))
local blockText = Model:RouteText(block)
assert(blockText:find('--[=[before µ]=]', 1, true) and blockText:find('--[[inside]]', 1, true))
assert(blockText:find('--[==[after]==]', 1, true))
assert(AprRC:ParseLuaData('{ steps = {} } --[=[unfinished') == nil)
assert(AprRC:ParseLuaData('{ x = APR.GAME_VERSIONS.Forever() }') == nil)
local booleans, _, booleanComments = AprRC:ParseLuaData('{ true --once\n, false }', true)
local booleanText = AprRC:SerializeData(booleans, 0, nil, nil, nil, nil, booleanComments)
local _, occurrences = booleanText:gsub('%-%-once', '')
assert(occurrences == 1, "Identifier lookahead must not duplicate comments")
assert(AprRC:DeepCompare(booleans, assert(AprRC:ParseLuaData(booleanText))))
local legacy = assert(AprRC:ReadRouteDefinition('--legacy µ\n{ { Note = "Replacement" } } --end legacy',
    route.name, saved))
local legacyText = Model:RouteText(legacy)
assert(legacyText:find('--route µ', 1, true) and legacyText:find('--legacy µ', 1, true), legacyText)
assert(not legacyText:find('--step µ', 1, true), "Replacing legacy steps must replace their comments too")
assert(AprRC:ReadRouteDefinition(legacyText, route.name, legacy))
APR.CATEGORIES.Leveling, AprRCData = previousCategory, previousData
print("Route Lua constants, ordering, unchanged steps and persistent comments passed.")
