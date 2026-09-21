local R = AprRC.options
local function parse(command, input)
    return R:Parse(assert(R.commands[command], command), input)
end
local function valid(command, input)
    local value, reason = parse(command, input)
    assert(value ~= nil, command .. ": " .. tostring(reason))
    return value
end
local function invalid(command, input)
    assert(parse(command, input) == nil, command .. " accepted " .. input)
end

-- Absolute XP supports signed integer offsets, while numeric/profile forms survive.
for _, command in ipairs({ "grind", "level", "minlevel", "maxlevel", "skipforlvl" }) do
    for _, xp in ipairs({ -700, 0, 325 }) do
        local value = valid(command, "{ level = 4, xp = " .. xp .. " }")
        assert(value.level == 4 and value.xp == xp)
    end
    assert(valid(command, "87.5") == 87.5)
    assert(valid(command, "MidnightDelves") == "MidnightDelves")
    for _, input in ipairs({ '{ level = 0, xp = 1 }', '{ level = 3.5, xp = 1 }',
        '{ level = 3, xp = 1.5 }', '{ level = 3 }', '{ level = 3, xp = 1e999 }',
        '{ level = 3, xp = "325" }', '{ level = 3, xp = 325, extra = 1 }' }) do
        invalid(command, input)
    end
end
invalid("belvl", '{ level = 3, xp = 325 }')
invalid("route conditions", '{ MinLevel = { level = 3, xp = 325 } }')
assert(not R:ValidateValue("level", { level = 3, xp = 0 / 0 }))

for _, operator in ipairs({ "<", "<=", ">", ">=", "==", "~=" }) do
    valid("money", '{ copper = 0, operator = "' .. operator .. '" }')
    valid("itemcount", '{ itemID = 6948, count = 0, operator = "' .. operator .. '" }')
    valid("equippeditemstat", '{ slot = 16, stat = "QUALITY", value = 0, operator = "' .. operator .. '" }')
    valid("skill", '{ skillID = 185, rank = 0, operator = "' .. operator .. '" }')
end
valid("itemcount", '{ itemIDs = { 6948, 4371 }, count = 2, includeBank = true, includeUsableToys = true }')
valid("equippeditemstat", '{ slot = 16, stat = "LEVEL", value = 3.5, precision = 1, allowMissing = true }')
assert(valid("hardcore", "false") == false)
valid("skill", '{ skill = 185, maximum = true, rank = 75 }')
valid("skill", '{ name = "Cuisine", rank = 50 }')
valid("equippeditem", '{ slot = 16, invert = true }')
valid("collection", '{ itemID = 5465 }')
valid("lootitems", '{ { itemID = 5465 } }')
valid("sellitems", '{ junk = true, text = "Sell grey items" }')
valid("learnskill", '{ spellID = 6673 }')
valid("learnskill", '{ allAvailable = true, npcID = 911 }')
valid("spelleta", '{ itemID = 6948, seconds = 30 }')
for _, command in ipairs({ "bankdeposit", "bankwithdraw", "destroyitems" }) do
    valid(command, '{ items = { 4371 }, text = "Handle these items" }')
    invalid(command, '{ items = { 4371 }, quantity = 1 }')
    invalid(command, '{ items = {} }')
end
for _, case in ipairs({
    { "money", '{ copper = -1 }' }, { "money", '{ copper = 10, operator = "=" }' },
    { "itemcount", '{ count = 1 }' }, { "itemcount", '{ itemIDs = {}, count = 1 }' },
    { "itemcount", '{ itemID = 6948, count = -1 }' },
    { "equippeditemstat", '{ slot = 16, value = 1 }' },
    { "equippeditemstat", '{ slot = 16, stat = "QUALITY", value = 1, precision = 0.5 }' },
    { "skill", '{ rank = 50 }' }, { "skill", '{ skill = "cooking", rank = -1 }' },
    { "collection", '{ itemID = 5465, quantity = 0 }' },
    { "sellitems", '{}' }, { "sellitems", '{ junk = false }' },
    { "learnskill", '{}' }, { "learnskill", '{ allAvailable = true }' },
    { "spelleta", '{ seconds = 30 }' }, { "spelleta", '{ spellID = 123, seconds = -1 }' },
    { "tamebeast", '{ npcID = 0 }' }, { "hardcore", '0' },
    { "allof", '{ { SellItems = { junk = true } } }' }, { "not", '{ Note = "Action" }' },
    { "route gameversion", 'unknown' },
    { "route nextroute", '{ { route = "Next", conditions = { Unknown = true } } }' },
    { "route prefab", '{ unknown = 10 }' },
}) do invalid(case[1], case[2]) end

local conditions = valid("not", [[{
    AnyOf = { { Hardcore = false }, { Money = { copper = 10000 } } },
    AllOf = {
        { IsQuestNotOnQuest = 10 }, { IsQuestNotOnQuest = 20 },
        { Not = { Collection = { itemID = 5465, quantity = 50 } } },
    },
}]])
assert(conditions.AnyOf[1].Hardcore == false)
assert(R:ValidateValue("conditions", conditions))
assert(not R:ValidateValue("routeConditions", conditions))
local recursive = {}
recursive.Not = recursive
assert(not R:ValidateValue("conditions", recursive), "Missing nesting limit")
for _, key in ipairs({ "Money", "ItemCount", "EquippedItemStat", "Hardcore", "AllOf", "Not", "Skill", "EquippedItem", "Collection" }) do
    local definition = R.step[key]
    local value = assert(definition).example
    local parsed = R:Parse(definition, value)
    assert(not R:ValidateValue("routeConditions", { [key] = parsed }), key .. " is a step filter")
end

-- Full import/export preserves defaults, false values and nested conditional links.
local route = {
    name = "2393-Wiki", gameVersion = "forever", steps = {},
    nextRoute = { "Shared", { route = "Class", conditions = { Class = "MAGE", Hardcore = false } } },
    prefab = { [APR.PREFAB_TYPES.Speedrun] = { index = 10, conditions = { Race = { "Orc", "Troll" } } } },
    parallelSteps = { { conditions = conditions, steps = { { Grind = { level = 4, xp = -700 } } } } },
}
for _, key in ipairs({ "ExitTutorial", "LeaveQuest", "DeathSkip", "SellItems", "LearnSkill", "BankDeposit",
    "BankWithdraw", "DestroyItems", "TameBeast", "SpellETA", "EmoteETA", "Bloodlust", "MerchantNPC",
    "NoAutoAccept", "NoAutoTurnIn", "ExtraLine", "Gossip", "Hardcore" }) do
    local definition = assert(R.step[key], key)
    local parsed, reason = R:Parse(definition, definition.example)
    assert(parsed ~= nil, reason)
    route.steps[#route.steps + 1] = { [key] = parsed }
end
local exported = AprRC:BuildRouteDefinition(route)
local imported, reason = AprRC:ReadRouteDefinition(AprRC:SerializeData(exported), route.name)
assert(imported, reason)
assert(AprRC:DeepCompare(exported, AprRC:BuildRouteDefinition(imported)))
assert(imported.steps[#imported.steps].Hardcore == false)
assert(imported.nextRoute[2].conditions.Hardcore == false)
assert(valid("route nextroute", "First, Second")[2] == "Second")
assert(valid("route prefab", '{ [APR.PREFAB_TYPES.Speedrun] = 20 }')[APR.PREFAB_TYPES.Speedrun] == 20)

local previous = AprRCData.CurrentRoute
local recording = AprRC.settings.profile.recordBarFrame.isRecording
AprRCData.CurrentRoute = { name = "2393-Commands", steps = {} }
AprRC.settings.profile.recordBarFrame.isRecording = true
assert(R:Apply(R.commands.deathskip, true, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[1].Hardcore == false)
assert(R:Apply(R.commands.hardcore, false, AprRCData.CurrentRoute, AprRCData.CurrentRoute.steps[1]))
assert(AprRCData.CurrentRoute.steps[1].Hardcore == false)
AprRCData.CurrentRoute = previous
AprRC.settings.profile.recordBarFrame.isRecording = recording
