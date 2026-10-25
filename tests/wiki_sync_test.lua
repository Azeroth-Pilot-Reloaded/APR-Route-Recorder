local R, Model, Language = AprRC.options, AprRC.editorModel, AprRC.luaLanguage

-- A dungeon key identifies a catalog instance, independently of any UI map.
for _, action in ipairs({ "EnterInstance", "LeaveInstance" }) do
    assert(R:Parse(R.step[action], '{ dungeonKey = "SYNTHETIC" }'))
    assert(R:Parse(R.step[action], '{ questID = 7, mapID = 8 }'))
    for _, invalid in ipairs({ '{}', '{ dungeonKey = 8 }', '{ dungeonKey = "" }',
        '{ questID = 7 }', '{ dungeonKey = "SYNTHETIC", mapID = 8 }' }) do
        assert(not R:Parse(R.step[action], invalid), action .. ": " .. invalid)
    end
end
local kill = { npcID = 21, name = "Training guardian", dungeonKey = "SYNTHETIC" }
assert(R:ValidateValue(R.step.KillNPC.schema, kill))
assert(not R:ValidateValue(R.step.KillNPC.schema, { npcID = 21, dungeonKey = "SYNTHETIC" }))
assert(not R:ValidateValue(R.step.KillNPC.schema, { npcID = 0, name = "Guardian", dungeonKey = "SYNTHETIC" }))
assert(R:ValidateValue("step", { KillNPC = kill, Dungeon = "SYNTHETIC", InstanceQuest = true, NoArrow = true }))
assert(not R:ValidateValue("conditions", { Dungeon = "SYNTHETIC" }))
assert(Model:StepKind({ KillNPC = kill }) == "KillNPC")
local _, killSummary = Model:Summary({ KillNPC = kill })
local _, enterSummary = Model:Summary({ EnterInstance = { dungeonKey = "SYNTHETIC" } })
assert(killSummary:find("Training guardian", 1, true))
assert(enterSummary:find("SYNTHETIC", 1, true))

-- AnyOf's children use step predicates, even on a route. Direct route levels
-- retain APR's numeric-only availability contract.
local eligibility = { InterfaceVersionExact = 120100,
    AnyOf = { { Money = { copper = 100 } }, { MinLevel = { level = 10, xp = 200 }, HasSpell = 42 } } }
assert(R:ValidateValue("routeConditions", eligibility))
assert(R:ValidateValue("routeConditions", { AnyOf = {} }))
assert(not R:ValidateValue("routeConditions", { MinLevel = { level = 10, xp = 200 } }))
assert(not R:ValidateValue("routeConditions", { AnyOf = { { KillNPC = kill } } }))
assert(not R:ValidateValue("routeConditions", { InterfaceVersionExact = true }))

local route = { name = "Wiki contract", label = "New guide", legacyLabels = { "Former guide" },
    autoStartOnMap = true, notSkippable = false, hiddenFromSelection = false, temporary = true,
    sojournerAchievementID = 42, delve = {}, conditions = eligibility,
    steps = { { EnterInstance = { dungeonKey = "SYNTHETIC" } },
        { KillNPC = kill, Dungeon = "SYNTHETIC", InstanceQuest = true, NoArrow = true },
        { UseItem = { questID = 7, itemID = 21 } },
        { SpellButton = { ["7-1"] = { 42, "Healing Touch" } } },
        { LeaveInstance = { dungeonKey = "SYNTHETIC" } } },
}
local text = Model:RouteText(route)
local read = assert(AprRC:ReadRouteDefinition(text, route.name))
assert(#Language:Analyze(text, {}) == 0, "New wiki fields must pass Lua diagnostics")
local exported = AprRC:BuildRouteDefinition(read)
for _, key in ipairs({ "legacyLabels", "autoStartOnMap", "notSkippable", "hiddenFromSelection", "temporary",
    "sojournerAchievementID", "delve", "conditions" }) do
    assert(AprRC:DeepCompare(exported[key], route[key]), key .. " failed to round-trip")
end
assert(exported.steps[2].KillNPC.dungeonKey == "SYNTHETIC")
assert(exported.steps[3].UseItem.itemSpellID == nil, "APR resolves omitted item use spells")
assert(not R:Parse(R.route.delve, 'true'))
assert(not R:Parse(R.route.legacyLabels, '{}'))

local previousRoute, previousRecording = AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording
local recorded = { name = "Wiki command contract", steps = {} }
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = recorded, true
assert(R:Apply(R.step.KillNPC, kill, recorded))
assert(recorded.steps[1].KillNPC.npcID == 21 and recorded.steps[1].InstanceQuest and recorded.steps[1].NoArrow)
assert(not recorded.steps[1].Coord, "Unverified exterior coordinates must not be added to a boss checkpoint")
assert(R:Apply(R.step.Dungeon, "SYNTHETIC", recorded, recorded.steps[1]))
assert(R:Apply(R.route.hiddenFromSelection, false, recorded))
assert(recorded.hiddenFromSelection == false and recorded.steps[1].Dungeon == "SYNTHETIC")
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = previousRoute, previousRecording
print("Wiki sync: dungeon actions, route metadata, eligibility scopes, optional item spells and round-trip passed.")
