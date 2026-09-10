local R = AprRC.options
local S = R.schemas

R:Register({
    key = "Faction",
    command = "faction",
    schema = { kind = "enum", values = { "Alliance", "Horde" } },
    example = "\"Horde\"",
    legacy = true,
    condition = true,
})

R:Register({
    key = "OnlyInZones",
    command = "onlyinzones",
    schema = "ids",
    example = "{ 2541 }",
    condition = true,
})

R:Register({
    key = "SkipInZones",
    command = "skipinzones",
    schema = "ids",
    example = "{ 2393 }",
    condition = true,
})

R:Register({
    key = "Race",
    command = "race",
    schema = S.race,
    example = "{ \"Orc\", \"Troll\" }",
    legacy = true,
    condition = true,
})

R:Register({
    key = "Gender",
    command = "gender",
    schema = { kind = "enum", values = { 1, 2, 3 } },
    example = "3",
    legacy = true,
    condition = true,
})

R:Register({
    key = "Class",
    command = "class",
    schema = S.class,
    example = "{ \"HUNTER\", \"ROGUE\" }",
    legacy = true,
    condition = true,
})

R:Register({
    key = "ClassNot",
    command = "classnot",
    schema = S.class,
    example = "APR.Classes.Evoker",
    condition = true,
})

R:Register({
    key = "ClassSpec",
    command = "classspec",
    schema = "id",
    example = "64",
    condition = true,
})

R:Register({
    key = "Level",
    command = "level",
    schema = "level",
    example = "80",
    condition = true,
})

R:Register({
    key = "MinLevel",
    command = "minlevel",
    schema = "level",
    example = "10",
    condition = true,
})

R:Register({
    key = "MaxLevel",
    command = "maxlevel",
    schema = "level",
    example = "69",
    condition = true,
})

R:Register({
    key = "BeLvl",
    command = "belvl",
    schema = "positive",
    example = "88",
    condition = true,
})

R:Register({
    key = "SkipForLvl",
    command = "skipforlvl",
    schema = "level",
    example = "89.18",
    condition = true,
})

R:Register({
    key = "AlliedRace",
    command = "alliedrace",
    schema = "bool",
    example = "true",
    condition = true,
})

R:Register({
    key = "Event",
    command = "event",
    schema = { kind = "enum", group = "EVENTS" },
    example = "APR.EVENTS.Remix",
    condition = true,
    hidden = true,
})

R:Register({
    key = "HasAchievement",
    command = "hasachievement",
    schema = "id",
    example = "12593",
    condition = true,
})

R:Register({
    key = "DontHaveAchievement",
    command = "donthaveachievement",
    schema = "id",
    example = "9924",
    condition = true,
})

R:Register({
    key = "HasAura",
    command = "hasaura",
    schema = "id",
    example = "178207",
    condition = true,
})

R:Register({
    key = "DontHaveAura",
    command = "donthaveaura",
    schema = "id",
    example = "32182",
    condition = true,
})

R:Register({
    key = "HasSpell",
    command = "hasspell",
    schema = "id",
    example = "34090",
    condition = true,
})

R:Register({
    key = "DontHaveSpell",
    command = "donthavespell",
    schema = "idOrIds",
    example = "{ 264211, 264434 }",
    condition = true,
})

R:Register({
    key = "IsQuestReadyForTurnIn",
    command = "isquestreadyforturnin",
    schema = "id",
    example = "93384",
    condition = true,
})

R:Register({
    key = "IsQuestOnQuest",
    command = "isquestonquest",
    schema = "id",
    example = "86737",
    condition = true,
})

R:Register({
    key = "IsQuestNotOnQuest",
    command = "isquestnotonquest",
    schema = "id",
    example = "86737",
    condition = true,
})

R:Register({
    key = "AnyOf",
    command = "anyof",
    schema = S.anyOf,
    example = "{ { IsQuestOnQuest = 86733 }, { IsQuestCompleted = 86852, IsQuestUncompleted = 86733 } }",
    condition = true,
})

R:Register({
    key = "ReputationLevel",
    command = "reputationlevel",
    schema = S.reputation,
    example = "{ factionID = 2590, type = APR.REPUTATION_TYPE.Renown, level = 10 }",
    legacy = true,
    condition = true,
})

R:Register({
    key = "SkipForReputation",
    command = "skipforreputation",
    schema = S.reputation,
    example = "{ factionID = 2773, type = APR.REPUTATION_TYPE.Friendship, level = 5 }",
    legacy = true,
    condition = true,
})

R:Register({
    key = "IsQuestCompleted",
    command = "isquestcompleted",
    schema = "id",
    example = "35049",
    condition = true,
})

R:Register({
    key = "IsQuestUncompleted",
    command = "isquestuncompleted",
    schema = "id",
    example = "35049",
    condition = true,
})

R:Register({
    key = "IsOneOfQuestsCompleted",
    command = "isoneofquestscompleted",
    schema = "ids",
    example = "{ 31588, 31589 }",
    condition = true,
})

R:Register({
    key = "IsOneOfQuestsUncompleted",
    command = "isoneofquestsuncompleted",
    schema = "ids",
    example = "{ 31588, 31589 }",
    condition = true,
})

R:Register({
    key = "IsOneOfQuestsCompletedOnAccount",
    command = "isoneofquestscompletedonaccount",
    schema = "ids",
    example = "{ 49929, 49930 }",
    condition = true,
})

R:Register({
    key = "IsOneOfQuestsUncompletedOnAccount",
    command = "isoneofquestsuncompletedonaccount",
    schema = "ids",
    example = "{ 49929, 49930 }",
    condition = true,
})

R:Register({
    key = "IsQuestsCompleted",
    command = "isquestscompleted",
    schema = "ids",
    example = "{ 31821, 31822 }",
    condition = true,
})

R:Register({
    key = "IsQuestsUncompleted",
    command = "isquestsuncompleted",
    schema = "ids",
    example = "{ 31821, 31822 }",
    condition = true,
})

R:Register({
    key = "IsQuestsCompletedOnAccount",
    command = "isquestscompletedonaccount",
    schema = "ids",
    example = "{ 49929, 49930 }",
    condition = true,
})

R:Register({
    key = "IsQuestsUncompletedOnAccount",
    command = "isquestsuncompletedonaccount",
    schema = "ids",
    example = "{ 49929, 49930 }",
    condition = true,
})

R:Register({
    key = "QuestLineSkip",
    command = "questlineskip",
    schema = "id",
    example = "51226",
    condition = true,
})

R:Register({
    key = "PickedLoa",
    command = "pickedloa",
    schema = { kind = "enum", values = { 1, 2 } },
    example = "1",
    condition = true,
})

R:Register({
    key = "IsCampaignQuest",
    command = "iscampaignquest",
    schema = "bool",
    example = "true",
    condition = true,
})

R:Register({
    key = "InterfaceVersion",
    command = "interfaceversion",
    schema = "id",
    example = "120100",
    condition = true,
})
