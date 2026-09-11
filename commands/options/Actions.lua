local R = AprRC.options
local S = R.schemas
local I = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"

R:Register({
    key = "PickUp",
    command = "pickup",
    schema = "ids",
    example = "{ 39688 }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "DropQuest",
    command = "dropquest",
    schema = "id",
    example = "48876",
    requires = "DroppableQuest",
    hidden = true,
})

R:Register({
    key = "DroppableQuest",
    command = "droppablequest",
    schema = S.drop,
    example = "{ Qid = 41234, MobId = 133713, Text = \"Fel Marauder\" }",
    hidden = true,
})

R:Register({
    key = "PickUpDB",
    command = "pickupdb",
    schema = "ids",
    example = "{ 39688, 39694, 40255, 40256 }",
    legacy = true,
    requires = "PickUp",
    icon = I .. "PickUpDB",
})

R:Register({
    key = "Qpart",
    command = "qpart",
    schema = S.qpart,
    example = "{ [12345] = { 1, 2 } }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "QpartDB",
    command = "qpartdb",
    schema = "ids",
    example = "{ 12345, 12346 }",
    legacy = true,
    requires = "Qpart",
    icon = I .. "QpartDB",
})

R:Register({
    key = "QpartPart",
    command = "qpartpart",
    schema = S.qpart,
    example = "{ [12345] = { 1 } }",
    legacy = true,
    newStep = true,
    coord = true,
    icon = I .. "QpartPart",
    bar = { isDefault = true, order = 80 },
})

R:Register({
    key = "Fillers",
    command = "fillers",
    schema = S.qpart,
    example = "{ [49529] = { 1 }, [49897] = { 1 } }",
    legacy = true,
    icon = I .. "Fillers",
    bar = { command = "filler", label = "Fillers", isDefault = true, order = 70 },
})

R:Register({
    key = "Done",
    command = "done",
    schema = "ids",
    example = "{ 12345, 12400 }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "DoneDB",
    command = "donedb",
    schema = "ids",
    example = "{ 12345, 54321 }",
    legacy = true,
    requires = "Done",
    icon = I .. "DoneDB",
})

R:Register({
    key = "Treasure",
    command = "treasure",
    schema = S.treasure,
    example = "{ questID = 89105, itemID = 238553 }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "Group",
    command = "group",
    schema = S.group,
    example = "{ questID = 51384, Number = 3 }",
})

R:Register({
    key = "GroupTask",
    command = "grouptask",
    schema = "id",
    example = "51384",
})

R:Register({
    key = "Achievement",
    command = "achievementstep",
    schema = S.achievement,
    example = "{ achievementID = 61960, criteriaID = 111471 }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "Scenario",
    command = "scenario",
    schema = S.scenario,
    example = "{ criteriaID = 106007, criteriaIndex = 1, scenarioID = 3101, stepID = 15911, questID = 86820 }",
    newStep = true,
    coord = true,
    legacy = true,
    icon = I .. "QpartPart",
    bar = { label = "Scenario Trigger", isDefault = true, order = 90 },
})

R:Register({
    key = "EnterScenario",
    command = "enterscenario",
    schema = S.questMap,
    example = "{ questID = 86636, mapID = 2502 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "DoScenario",
    command = "doscenario",
    schema = S.questMap,
    example = "{ questID = 86912, mapID = 2505 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "LeaveScenario",
    command = "leavescenario",
    schema = S.questMap,
    example = "{ questID = 86912, mapID = 2505 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "EnterInstance",
    command = "enterinstance",
    schema = S.questMap,
    example = "{ questID = 12345, mapID = 2505 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "LeaveInstance",
    command = "leaveinstance",
    schema = S.questMap,
    example = "{ questID = 12345, mapID = 2505 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "SetHS",
    command = "seths",
    schema = "id",
    example = "31732",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "UseHS",
    command = "usehs",
    schema = "id",
    example = "31732",
    newStep = true,
    hidden = true,
})

R:Register({
    key = "UseDalaHS",
    command = "usedalahs",
    schema = "id",
    example = "44184",
    newStep = true,
    hidden = true,
})

R:Register({
    key = "UseGarrisonHS",
    command = "usegarrisonhs",
    schema = "id",
    example = "110560",
    newStep = true,
    hidden = true,
})

R:Register({
    key = "UseItem",
    command = "useitem",
    schema = S.item,
    example = "{ questID = 42008, itemID = 173430, itemSpellID = 254294 }",
    newStep = true,
    coord = true,
    legacy = true,
    icon = I .. "UseItem",
})

R:Register({
    key = "UseSpell",
    command = "usespell",
    schema = S.spell,
    example = "{ questID = 42476, spellID = 193759 }",
    newStep = true,
    coord = true,
    legacy = true,
    icon = I .. "UseSpell",
})

R:Register({
    key = "UseFlightPath",
    command = "useflightpath",
    schema = "id",
    example = "39580",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "GetFP",
    command = "getfp",
    schema = "id",
    example = "2395",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "LearnProfession",
    command = "learnprofession",
    schema = "id",
    example = "2259",
    newStep = true,
    coord = true,
    hidden = true,
    icon = I .. "LearnProfession",
    bar = { command = "addjob", label = "Learn Profession" },
})

R:Register({
    key = "LootItems",
    command = "lootitems",
    schema = S.items,
    example = "{ { questID = 86644, itemID = 244143, quantity = 1 } }",
    newStep = true,
    coord = true,
    legacy = true,
    icon = I .. "LootItem",
})

R:Register({
    key = "Grind",
    command = "grind",
    schema = "level",
    example = "60",
    newStep = true,
    icon = I .. "Grind",
})

R:Register({
    key = "Reputation",
    command = "reputation",
    schema = S.reputation,
    example = "{ factionID = 2590, type = APR.REPUTATION_TYPE.Renown, level = 10 }",
    newStep = true,
    legacy = true,
})

R:Register({
    key = "LeaveQuest",
    command = "leavequest",
    schema = "id",
    example = "38254",
    newStep = true,
})
R:Register({
    key = "LeaveQuests",
    command = "leavequests",
    schema = "ids",
    example = "{ 38254, 38257 }",
    newStep = true,
    hidden = true,
})
R:Register({
    key = "VehicleExit",
    command = "vehicleexit",
    schema = "bool",
    example = "true",
    hidden = true,
})
R:Register({
    key = "MountVehicle",
    command = "mountvehicle",
    schema = "bool",
    example = "true",
    legacy = true,
    hidden = true,
    icon = I .. "MountVehicle",
})

R:Register({
    key = "NpcDismount",
    command = "npcdismount",
    schema = "id",
    example = "43733",
    legacy = true,
    icon = I .. "MountVehicle",
})

R:Register({
    key = "WarMode",
    command = "warmode",
    schema = "id",
    example = "60361",
    newStep = true,
    coord = true,
    legacy = true,
    hidden = true,
    icon = I .. "WarMode",
})

R:Register({
    key = "ResetRoute",
    command = "resetroute",
    schema = "bool",
    example = "true",
    newStep = true,
    icon = I .. "ResetRoute",
    bar = { command = "addreset", label = "Reset Route" },
})

R:Register({
    key = "Emote",
    command = "emote",
    schema = S.emote,
    example = "{ npcID = 0, emote = \"salute\" }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "ChromiePick",
    command = "chromiepick",
    schema = "id",
    example = "8",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "BuyMerchant",
    command = "buymerchant",
    schema = S.items,
    example = "{ { itemID = 193890, quantity = 1, questID = 66680 } }",
    newStep = true,
    coord = true,
    hidden = true,
})

R:Register({
    key = "Note",
    command = "note",
    schema = S.note,
    example = "{ \"Open the map\", \"Follow the bridge north\" }",
    newStep = true,
})

R:Register({
    key = "RouteCompleted",
    command = "routecompleted",
    schema = "bool",
    example = "true",
    newStep = true,
})
