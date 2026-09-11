local R = AprRC.options
local S = R.schemas
local I = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"

R:Register({
    key = "Coord",
    command = "coord",
    schema = S.coord,
    example = "{ x = 4298.4, y = -864.1 }",
    legacy = true,
    icon = I .. "Coord",
    bar = { isDefault = true, order = 20 },
})

R:Register({
    key = "Coords",
    command = "coords",
    schema = S.coords,
    example = "{ { Zone = 84, x = 797.7, y = -8624.9 }, { Zone = 85, x = -4436, y = 1590.3 } }",
    legacy = true,
    icon = I .. "Coord",
})

R:Register({
    key = "Zone",
    command = "zone",
    schema = "id",
    example = "627",
})

R:Register({
    key = "Zones",
    command = "zones",
    schema = "ids",
    example = "{ 84, 85 }",
    condition = true,
})

R:Register({
    key = "Range",
    command = "range",
    schema = "positive",
    example = "45",
    legacy = true,
    icon = I .. "Range",
    bar = { isDefault = true, order = 30 },
})

R:Register({
    key = "ZoneStepTrigger",
    command = "zonesteptrigger",
    schema = S.trigger,
    example = "{ x = 4098.2, y = -712.4, Range = 25 }",
    icon = I .. "ZoneStepTrigger",
})

R:Register({
    key = "Waypoint",
    command = "waypoint",
    schema = "id",
    example = "44543",
    newStep = true,
    coord = true,
    legacy = true,
    icon = I .. "Waypoint",
    bar = { isDefault = true, order = 10 },
})

R:Register({
    key = "WaypointDB",
    command = "waypointdb",
    schema = "ids",
    example = "{ 44543, 44544 }",
    legacy = true,
    requires = "Waypoint",
    icon = I .. "WaypointDB",
})

R:Register({
    key = "NonSkippableWaypoint",
    command = "nonskippablewaypoint",
    schema = "bool",
    example = "true",
    legacy = true,
    requires = "Waypoint",
    icon = I .. "Waypoint",
})

R:Register({
    key = "SingleWaypointDisplayDistance",
    command = "singlewaypointdisplaydistance",
    schema = "bool",
    example = "true",
})

R:Register({
    key = "TakePortal",
    command = "takeportal",
    schema = S.questMap,
    example = "{ questID = 81888, mapID = 85 }",
    newStep = true,
    coord = true,
})

R:Register({
    key = "NodeID",
    command = "nodeid",
    schema = "id",
    example = "1719",
    requires = "UseFlightPath",
})

R:Register({
    key = "Name",
    command = "name",
    schema = "text",
    example = "\"Krasus' Landing\"",
})

R:Register({
    key = "Boat",
    command = "boat",
    schema = "bool",
    example = "true",
    requires = "UseFlightPath",
})

R:Register({
    key = "NoArrow",
    command = "noarrow",
    schema = "bool",
    example = "true",
    legacy = true,
    icon = I .. "NoArrow",
    bar = { isDefault = true, order = 40 },
})

R:Register({
    key = "NoAutoFlightMap",
    command = "noautoflightmap",
    schema = "bool",
    example = "true",
    legacy = true,
    icon = I .. "NoAutoFlightMap",
})

R:Register({
    key = "InstanceQuest",
    command = "instancequest",
    schema = "bool",
    example = "true",
    icon = I .. "InstanceQuest",
})

R:Register({
    key = "IsAdventureMap",
    command = "isadventuremap",
    schema = "bool",
    example = "true",
    icon = I .. "IsAdventureMapVisible",
    bar = { command = "adventuremap" },
})

R:Register({
    key = "ETA",
    command = "eta",
    schema = "positive",
    example = "75",
    legacy = true,
    icon = I .. "ETA",
})

R:Register({
    key = "GossipETA",
    command = "gossipeta",
    schema = "positive",
    example = "45",
    legacy = true,
    icon = I .. "GossipETA",
})

R:Register({
    key = "SpecialETAHide",
    command = "specialetahide",
    schema = "bool",
    example = "true",
    legacy = true,
    icon = I .. "SpecialETAHide",
})
