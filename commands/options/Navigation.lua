local R = AprRC.options
local S = R.schemas

R:Register({
    key = "Coord",
    command = "coord",
    schema = S.coord,
    example = "{ x = 4298.4, y = -864.1 }",
    legacy = true,
})

R:Register({
    key = "Coords",
    command = "coords",
    schema = S.coords,
    example = "{ { Zone = 84, x = 797.7, y = -8624.9 }, { Zone = 85, x = -4436, y = 1590.3 } }",
    legacy = true,
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
})

R:Register({
    key = "ZoneStepTrigger",
    command = "zonesteptrigger",
    schema = S.trigger,
    example = "{ x = 4098.2, y = -712.4, Range = 25 }",
})

R:Register({
    key = "Waypoint",
    command = "waypoint",
    schema = "id",
    example = "44543",
    newStep = true,
    coord = true,
    legacy = true,
})

R:Register({
    key = "WaypointDB",
    command = "waypointdb",
    schema = "ids",
    example = "{ 44543, 44544 }",
    legacy = true,
    requires = "Waypoint",
})

R:Register({
    key = "NonSkippableWaypoint",
    command = "nonskippablewaypoint",
    schema = "bool",
    example = "true",
    legacy = true,
    requires = "Waypoint",
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
})

R:Register({
    key = "NoAutoFlightMap",
    command = "noautoflightmap",
    schema = "bool",
    example = "true",
    legacy = true,
})

R:Register({
    key = "InstanceQuest",
    command = "instancequest",
    schema = "bool",
    example = "true",
})

R:Register({
    key = "IsAdventureMap",
    command = "isadventuremap",
    schema = "bool",
    example = "true",
})

R:Register({
    key = "ETA",
    command = "eta",
    schema = "positive",
    example = "75",
    legacy = true,
})

R:Register({
    key = "GossipETA",
    command = "gossipeta",
    schema = "positive",
    example = "45",
    legacy = true,
})

R:Register({
    key = "SpecialETAHide",
    command = "specialetahide",
    schema = "bool",
    example = "true",
    legacy = true,
})

