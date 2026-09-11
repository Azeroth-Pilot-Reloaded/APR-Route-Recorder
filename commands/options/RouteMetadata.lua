local R = AprRC.options
local S = R.schemas

R:Register({
    key = "label",
    command = "route label",
    schema = "text",
    example = "\"Midnight - Speedrun\"",
    scope = "route",
    icon = "Interface\\Icons\\INV_Inscription_ScrollOfWisdom_01",
})

R:Register({
    key = "expansion",
    command = "route expansion",
    schema = { kind = "enum", group = "EXPANSIONS" },
    example = "APR.EXPANSIONS.Midnight",
    scope = "route",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
})

R:Register({
    key = "category",
    command = "route category",
    schema = { kind = "enum", group = "CATEGORIES" },
    example = "APR.CATEGORIES.Leveling",
    scope = "route",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
})

R:Register({
    key = "mapID",
    command = "route mapid",
    schema = "id",
    example = "2393",
    scope = "route",
    icon = "Interface\\Icons\\INV_Misc_Map08",
})


R:Register({
    key = "conditions",
    command = "route conditions",
    schema = "routeConditions",
    example = "{ Level = 80, Faction = \"Alliance\" }",
    scope = "route",
    icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
})

R:Register({
    key = "requiredRoute",
    command = "route requiredroute",
    schema = S.routeLinks,
    example = "{ \"2432-Midnight-Intro\" }",
    scope = "route",
    icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
})

R:Register({
    key = "nextRoute",
    command = "route nextroute",
    schema = "strings",
    example = "{ \"2395-The-War-of-Light-and-Shadow\" }",
    scope = "route",
    icon = "Interface\\Icons\\Ability_Hunter_RunningShot",
})

R:Register({
    key = "parallelSteps",
    command = "route parallelsteps",
    schema = S.parallel,
    example =
    "{ { conditions = { MinLevel = 88, IsQuestReadyForTurnIn = 93384 }, steps = { { Done = { 93384 }, Zone = 2395 } } } }",
    scope = "route",
    icon = "Interface\\Icons\\Ability_Rogue_Sprint",
})

R:Register({
    key = "XPConsumables",
    command = "route xpconsumables",
    schema = S.xp,
    example = "\"MidnightDelves\"",
    scope = "route",
    icon = "Interface\\Icons\\INV_Potion_116",
})
