local Model = AprRC.editorModel
local steps = {
    {
        Coord = { x = -4837.31, y = 356.03 }, Zone = 1411, Class = "WARLOCK",
        LearnSkill = { allAvailable = true, npcID = 3172 }, _index = 226,
    },
    {
        Coord = { x = -4854.76, y = 345.81 }, Zone = 1411,
        BuyMerchant = { { itemID = 16302, quantity = 1, questID = 825 } },
        Class = "WARLOCK", DontHaveSpell = 7799,
        ItemCount = { count = 1, itemID = 16302, operator = "<" },
        Money = { copper = 100, operator = ">=" }, _index = 227,
    },
}
local original = AprRC:CopyData(steps)
local text = AprRC:SerializeData(steps, 0, "steps")
assert(text == [[{
    {
        LearnSkill = { allAvailable = true, npcID = 3172 },
        Coord = { x = -4837.31, y = 356.03 },
        Class = "WARLOCK",
        Zone = 1411,
        _index = 226,
    },
    {
        BuyMerchant = { { itemID = 16302, quantity = 1, questID = 825 } },
        Coord = { x = -4854.76, y = 345.81 },
        Class = "WARLOCK",
        DontHaveSpell = 7799,
        ItemCount = { count = 1, itemID = 16302, operator = "<" },
        Money = { copper = 100, operator = ">=" },
        Zone = 1411,
        _index = 227,
    },
}]], text)
assert(AprRC:DeepCompare(steps, original), "Sorting must not mutate step data or indexes")
assert(AprRC:DeepCompare(steps, assert(AprRC:ParseLuaData(text))))
local exported = assert(AprRC:ParseLuaData(AprRC:TableToString(steps)))
assert(exported[1]._index == 1 and exported[2]._index == 2)

-- Every requested field group is represented, including unrecognized payload
-- data that must precede conditions, and the separate Zone/Zones footer.
local full = {
    PickUp = { 42 }, DroppableQuest = { Qid = 42, MobId = 54, Text = "Drop" }, PickUpDB = { 42 },
    Fillers = { [43] = { 1 } }, Note = "Instructions", ExtraLineText = "More instructions",
    ExtraLineText2 = "Second line", Coord = { x = 1, y = 2 }, Range = 5,
    GossipOptionIDs = { 51901 }, Button = { ["42-1"] = 81356 }, SpellButton = { ["42-1"] = 306719 },
    NoArrow = true, FutureData = { Class = "Literal payload", Zone = 85, _index = 7 },
    Class = "WARLOCK", AllOf = { { HasSpell = 7799 } }, Money = { copper = 100, operator = ">=" },
    Zone = 1411, Zones = { 1411, 85 }, _index = 1,
}
local fullOrder = table.concat(AprRC:CustomSortStepKeys(full), ",")
assert(fullOrder ==
    "PickUp,PickUpDB,DroppableQuest,Fillers,Note,ExtraLineText,ExtraLineText2,Coord,Range,GossipOptionIDs," ..
    "Button,SpellButton,NoArrow,FutureData,AllOf,Class,Money,Zone,Zones,_index", fullOrder)
local route = { name = "1411-Step ordering", label = "Steps", expansion = "WoW Forever", steps = steps,
    parallelSteps = { { conditions = { Race = "Orc" }, steps = { full } } } }
local routeText, positions = Model:RouteText(route, true)
local function checkRange(range, expected, action)
    local block = routeText:sub(range.start + 1, range.finish)
    assert(block:match("^%{%s*([%w_]+)%s*=") == action, block)
    assert(AprRC:DeepCompare(assert(AprRC:ParseLuaData(block)), expected), block)
end
checkRange(positions.steps[1], steps[1], "LearnSkill")
checkRange(positions.steps[2], steps[2], "BuyMerchant")
checkRange(positions.parallelSteps[1][1], full, "PickUp")
local nestedBefore = AprRC:SerializeData(full.FutureData, 4, "inline")
assert(routeText:find("FutureData = " .. nestedBefore, 1, true), "Nested payload formatting must stay unchanged")
assert(routeText:find('expansion = APR.EXPANSIONS.Forever', 1, true), "Route constants must still render")
assert(routeText:find('Class = "WARLOCK"', 1, true), "Step conditions must keep literal values")

-- A note or gossip can itself be the action, but becomes supplementary when
-- paired with a quest, trainer, merchant or movement action.
local function first(step) return AprRC:CustomSortStepKeys(step)[1] end
assert(first({ Note = "Talk", Fillers = {}, Coord = {}, Zone = 85 }) == "Note")
assert(first({ GossipOptionIDs = { 1 }, Coord = {}, Range = 5, Zone = 85 }) == "GossipOptionIDs")
assert(first({ PickUpDB = { 42 }, Coord = {}, Zone = 85 }) == "PickUpDB")
assert(first({ LearnSkill = {}, Note = "Trainer", GossipOptionIDs = { 1 }, Coord = {}, Class = "MAGE" }) == "LearnSkill")
assert(first({ BuyMerchant = {}, Note = "Merchant", Coord = {} }) == "BuyMerchant")
assert(first({ Waypoint = 42, Note = "Run", Coord = {} }) == "Waypoint")
assert(first({ DropQuest = 42, DroppableQuest = {}, Coord = {} }) == "DropQuest")

-- Comments follow their fields through the new order, and indexes remain the
-- last field even when an action/condition is unknown to the recorder schema.
local commented = assert(AprRC:ReadRouteDefinition([[{
    steps = { {
        Coord = { x = 1, y = 2 }, --coordinate
        Zone = 1411,
        Class = "WARLOCK",
        --trainer
        LearnSkill = { allAvailable = true, npcID = 3172 },
        _index = 1,
    } },
}]], "1411-Comment ordering"))
local commentedText = Model:RouteText(commented)
assert(commentedText:find('--trainer\n            LearnSkill', 1, true), commentedText)
assert(commentedText:find('Coord = { x = 1, y = 2 }, --coordinate', 1, true), commentedText)
assert(commentedText:find('LearnSkill =', 1, true) < commentedText:find('Coord =', 1, true))
assert(AprRC:ReadRouteDefinition(commentedText, commented.name))
local previousActions = APR.mainStepOptions
APR.mainStepOptions = { "FutureAction" }
assert(first({ FutureAction = true, Coord = {}, Zone = 85, _index = 1 }) == "FutureAction")
APR.mainStepOptions = previousActions
print("Step field ordering: primary actions, companions, conditions, footer, comments and parallel steps passed.")
