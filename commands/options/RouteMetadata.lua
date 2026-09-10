local R = AprRC.options
local S = R.schemas

R:Register({
    key = "label",
    command = "route label",
    schema = "text",
    example = "\"Midnight - Speedrun\"",
    scope = "route",
})

R:Register({
    key = "expansion",
    command = "route expansion",
    schema = { kind = "enum", group = "EXPANSIONS" },
    example = "APR.EXPANSIONS.Midnight",
    scope = "route",
})

R:Register({
    key = "category",
    command = "route category",
    schema = { kind = "enum", group = "CATEGORIES" },
    example = "APR.CATEGORIES.Leveling",
    scope = "route",
})

R:Register({
    key = "mapID",
    command = "route mapid",
    schema = "id",
    example = "2393",
    scope = "route",
})

R:Register({
    key = "prefab",
    command = "route prefab",
    schema = S.prefab,
    example = "{ [APR.PREFAB_TYPES.Speedrun] = 20 }",
    scope = "route",
})

R:Register({
    key = "conditions",
    command = "route conditions",
    schema = "routeConditions",
    example = "{ Level = 80, Faction = \"Alliance\" }",
    scope = "route",
})

R:Register({
    key = "requiredRoute",
    command = "route requiredroute",
    schema = S.routeLinks,
    example = "{ \"2432-Midnight-Intro\" }",
    scope = "route",
})

R:Register({
    key = "nextRoute",
    command = "route nextroute",
    schema = "strings",
    example = "{ \"2395-The-War-of-Light-and-Shadow\" }",
    scope = "route",
})

R:Register({
    key = "parallelSteps",
    command = "route parallelsteps",
    schema = S.parallel,
    example = "{ { conditions = { MinLevel = 88, IsQuestReadyForTurnIn = 93384 }, steps = { { Done = { 93384 }, Zone = 2395 } } } }",
    scope = "route",
})

R:Register({
    key = "XPConsumables",
    command = "route xpconsumables",
    schema = S.xp,
    example = "\"MidnightDelves\"",
    scope = "route",
})

