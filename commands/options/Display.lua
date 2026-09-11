local R = AprRC.options
local S = R.schemas
local I = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"

R:Register({
    key = "Buffs",
    command = "buffs",
    schema = S.buffs,
    example = "{ { spellId = 311103, tooltipMessage = \"FRESHLEAF_BUFF\" } }",
    legacy = true,
    icon = I .. "Buffs",
})

R:Register({
    key = "Button",
    command = "button",
    schema = S.buttons,
    example = "{ [\"30778-1\"] = 81356 }",
    legacy = true,
    icon = I .. "Button",
    bar = { command = "btn", label = "Button", isDefault = true, order = 60 },
})

R:Register({
    key = "SpellButton",
    command = "spellbutton",
    schema = S.buttons,
    example = "{ [\"49939-1\"] = 294197 }",
})

R:Register({
    key = "SpellTrigger",
    command = "spelltrigger",
    schema = "id",
    example = "306719",
    legacy = true,
    icon = I .. "SpellTrigger",
})

R:Register({
    key = "ExtraLineText",
    command = "text",
    schema = "text",
    example = "\"Interact with the second console\"",
    legacy = true,
    icon = I .. "ExtraLineText",
    bar = { label = "Extra Line Text", isDefault = true, order = 50 },
})

R:Register({
    key = "ExtraActionB",
    command = "extraactionb",
    schema = "bool",
    example = "true",
    hidden = true,
})

R:Register({
    key = "PreviewImages",
    command = "previewimages",
    schema = "strings",
    example = "{ \"routeHelper\\\\86644.jpg\" }",
})

R:Register({
    key = "InVehicle",
    command = "invehicle",
    schema = { kind = "enum", values = { 1, 2 } },
    example = "1",
})

R:Register({
    key = "UseGlider",
    command = "useglider",
    schema = "bool",
    example = "true",
    hidden = true,
})

R:Register({
    key = "RaidIcon",
    command = "raidicon",
    schema = "id",
    example = "241743",
    hidden = true,
})

R:Register({
    key = "GossipOptionIDs",
    command = "gossipoptionids",
    schema = "ids",
    example = "{ 51901, 51902 }",
    hidden = true,
})

R:Register({
    key = "DenyNPC",
    command = "denynpc",
    schema = "id",
    example = "209914",
    legacy = true,
    icon = I .. "DontHaveAura",
})

R:Register({
    key = "Dontskipvid",
    command = "dontskipvid",
    schema = "bool",
    example = "true",
    icon = I .. "Dontskipvid",
})

R:Register({
    key = "XPConsumables",
    command = "xpconsumables",
    schema = S.xp,
    example = "\"MidnightDelves\"",
})
