local R = AprRC.options
local S = R.schemas

R:Register({
    key = "Bloodlust",
    command = "bloodlust",
    schema = "bool",
    example = "true",
    icon = "Interface\\Icons\\Spell_Nature_BloodLust",
})

R:Register({
    key = "MerchantNPC",
    command = "merchantnpc",
    schema = "id",
    example = "54",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
})

R:Register({
    key = "NoAutoAccept",
    command = "noautoaccept",
    schema = "bool",
    example = "true",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
})

R:Register({
    key = "NoAutoTurnIn",
    command = "noautoturnin",
    schema = "bool",
    example = "true",
    icon = "Interface\\Icons\\INV_Misc_Book_11",
})

R:Register({
    key = "ExtraLine",
    command = "extraline",
    schema = "id",
    example = "13544",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
})

R:Register({
    key = "Gossip",
    command = "gossip",
    schema = "id",
    example = "2",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
})
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
    icon = "Interface\\Icons\\INV_Misc_EngGizmos_04",
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
    key = "TrigText",
    command = "trigtext",
    schema = "text",
    example = "\"1/7\"",
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
    icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
})

R:Register({
    key = "InVehicle",
    command = "invehicle",
    schema = { kind = "enum", values = { 1, 2 } },
    example = "1",
    icon = "Interface\\Icons\\ability_vehicle_launchplayer",
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
    icon = "Interface\\Icons\\INV_Potion_116",
})
