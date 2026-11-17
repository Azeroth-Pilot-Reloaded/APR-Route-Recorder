local R, Model, Language = AprRC.options, AprRC.editorModel, AprRC.luaLanguage
local function valid(key, value, route)
    local definition = assert((route and R.route or R.step)[key], key)
    local ok, reason = R:ValidateValue(definition.schema, value)
    assert(ok, key .. ": " .. tostring(reason))
    return value
end
local function invalid(key, value, route)
    local definition = assert((route and R.route or R.step)[key], key)
    assert(not R:ValidateValue(definition.schema, value), key .. " accepted invalid data")
end

local goal = valid("SkillGoal", { skillID = 185, rank = 50 })
assert(R.commands.skillgoal.newStep and not R.commands.skillgoal.coord)
assert(Model:StepKind({ SkillGoal = goal }) == "SkillGoal")
local _, summary = Model:Summary({ SkillGoal = goal })
assert(summary:find("50", 1, true) and summary:find(">=", 1, true))
for _, value in ipairs({ {}, { skillID = 185 }, { rank = 50 }, { skillID = 0, rank = 50 },
    { skillID = 185, rank = 0 }, { skillID = 185, rank = 1.5 }, { skillID = 185, rank = math.huge },
    { skillID = "185", rank = 50 }, { skillID = 185, rank = 50, maximum = true } }) do invalid("SkillGoal", value) end
assert(not R:ValidateValue("conditions", { SkillGoal = goal }))
assert(not R:ValidateValue("routeConditions", { SkillGoal = goal }))
assert(not R:ValidateValue("conditions", { AnyOf = { { SkillGoal = goal } } }))
assert(R:GetCategory(R.step.IsCampaignQuest) == "Display")
assert(not R:ValidateValue("conditions", { IsCampaignQuest = true }))

valid("levelRange", { min = 1, max = 60 }, true)
valid("levelRange", { min = 60, max = 60 }, true)
valid("levelRange", { min = 1 }, true)
valid("levelRange", { max = 60 }, true)
for _, value in ipairs({ {}, { min = 60, max = 1 }, { min = 0 }, { max = 2.5 }, { min = "1" },
    { min = math.huge }, { min = 1, rank = 50 } }) do invalid("levelRange", value, true) end
assert(not R:ValidateValue("routeConditions", { levelRange = { min = 1, max = 60 } }))

local markers = valid("MapMarkers", { { x = -4298.4, y = 864.1 },
    { x = 4320.2, y = -890.5, mapID = 84, instanceID = 0 } })
assert(R:GetCategory(R.commands.mapmarkers) == "Navigation")
valid("instanceID", 0)
for _, value in ipairs({ {}, { { x = 1 } }, { { x = "1", y = 2 } }, { { x = 1, y = 0 / 0 } },
    { { x = 1, y = 2, mapID = 0 } }, { { x = 1, y = 2, instanceID = -1 } },
    { { x = 1, y = 2, instanceID = 1.5 } }, { { x = 1, y = 2, Zone = 84 } },
    { [2] = { x = 1, y = 2 } } }) do invalid("MapMarkers", value) end
assert(not R:ValidateValue("conditions", { MapMarkers = markers }))

local loot = { { itemID = 769, quantity = 25, quantityFromSkill = { skill = "cooking", rank = 50 } } }
valid("LootItems", loot)
valid("LootItems", { { itemID = 769, quantityFromSkill = { skillID = 185, rank = 50 } } })
valid("LootItems", { { itemID = 769, quantityFromSkill = { name = "Cuisine", rank = 50 } } })
for _, target in ipairs({ {}, { rank = 50 }, { skill = "cooking" }, { skill = "cooking", rank = 0 },
    { skillID = 185, rank = 2.5 }, { skill = "cooking", rank = 50, maximum = true },
    { skill = "cooking", rank = 50, operator = "<" } }) do
    invalid("LootItems", { { itemID = 769, quantityFromSkill = target } })
end
local purchases = valid("BuyMerchant", { { itemID = 4371, quantity = 1, isSupply = false, optional = false },
    { itemID = 2030, quantity = 1, isSupply = true, optional = true } })
invalid("BuyMerchant", { { itemID = 4371, quantity = 1, isSupply = 1 } })
invalid("BuyMerchant", { { itemID = 4371, quantity = 1, optional = "true" } })
invalid("LootItems", { { itemID = 769, isSupply = true } })
invalid("LootMoney", { copper = 10, equippedSlots = { 20 } })

local icons = valid("RaidIcon", { { npcID = 241743, questID = 12345, objectiveIndex = 1 }, 241744 })
valid("RaidIcon", 241743)
valid("RaidIcon", { 241743, 241744 })
for _, value in ipairs({ {}, { { questID = 12345 } }, { { npcID = 1, objectiveIndex = 0 } },
    { { npcID = 1, unknown = true } }, { 0 }, { [2] = 241743 } }) do invalid("RaidIcon", value) end
valid("ItemTarget", "player")
invalid("ItemTarget", "target")
local images = valid("FillerPreviewImages", { [93552] = { "routeHelper\\93552.jpg", "Interface\\Other\\image.jpg" } })
invalid("FillerPreviewImages", { [93552] = {} })
invalid("FillerPreviewImages", { ["93552"] = { "image.jpg" } })
invalid("FillerPreviewImages", { [93552] = "image.jpg" })
valid("IsQuestReadyForTurnIn", { 10, 20 })
valid("IsQuestReadyForTurnIn", 10)
invalid("IsQuestReadyForTurnIn", {})
assert(R:ValidateValue("routeConditions", { IsQuestReadyForTurnIn = { 10, 20 } }))

local steps = { { RouteCompleted = true, IsQuestCompleted = 10 },
    { SkillGoal = goal, MinLevel = 10 }, { RouteCompleted = true } }
assert(R:ValidateValue("steps", steps))
assert(not R:ValidateValue("steps", { steps[1], steps[2] }))
assert(not R:ValidateValue("steps", { steps[3], steps[2], steps[3] }))
assert(not R:ValidateValue("steps", { steps[1], { RouteCompleted = true, Class = "MAGE" } }))
assert(not R:ValidateValue("steps", { steps[1], false }))
assert(not R:ValidateValue("steps", { { RouteCompleted = true, IsCampaignQuest = true }, steps[3] }))

-- Imported routes may predate dependencies enforced on newly authored fields.
-- Reindexing alone must preserve them; edits still validate against the schema.
local legacy = { Boat = true, _index = 5, FutureField = { enabled = false } }
local reindexed = { Boat = true, _index = 1, FutureField = { enabled = false } }
assert(R:ValidateValue("step", reindexed, "step", nil, legacy))
reindexed._index = nil
assert(R:ValidateValue("step", reindexed, "step", nil, legacy))
reindexed._index = "1"
assert(not R:ValidateValue("step", reindexed, "step", nil, legacy))
reindexed._index, reindexed.FutureField.enabled = 1, true
assert(not R:ValidateValue("step", reindexed, "step", nil, legacy))
assert(not R:ValidateValue("step", { Boat = true }, "step", nil, { Boat = true, UseFlightPath = 10 }))

local route = { name = "84-LatestWiki", levelRange = { min = 1, max = 60 }, steps = steps,
    parallelSteps = { { conditions = { IsQuestReadyForTurnIn = { 10, 20 } }, steps = { { SkillGoal = goal } } } },
    scenarios = { { scenarioID = 3101, steps = { { SkillGoal = goal, Class = APR.Classes.Mage },
        { PickUp = { 10 }, MapMarkers = markers, instanceID = 0, RaidIcon = icons } } } } }
route.steps[2].LootItems, route.steps[2].BuyMerchant = loot, purchases
route.steps[2].FillerPreviewImages, route.steps[2].ItemTarget = images, "player"
local text = Model:RouteText(route)
local diagnostics = Language:Analyze(text, {})
assert(#diagnostics == 0, diagnostics[1] and diagnostics[1].message)
local imported = assert(AprRC:ReadRouteDefinition(text, route.name))
assert(imported.scenarios[1].steps[1].Class == "MAGE")
local definition = AprRC:BuildRouteDefinition(imported)
assert(definition.scenarios[1].steps[1]._index == 1 and definition.scenarios[1].steps[2]._index == 2)
assert(definition.steps[2].BuyMerchant[1].isSupply == false and definition.steps[2].BuyMerchant[1].optional == false)
assert(definition.steps[2].LootItems[1].quantityFromSkill.rank == 50)
assert(definition.steps[2].FillerPreviewImages[93552][2] == images[93552][2])
assert(definition.scenarios[1].steps[2].MapMarkers[2].instanceID == 0)
local rebuilt = AprRC:BuildRouteDefinition(assert(AprRC:ReadRouteDefinition(Model:RouteText(imported), route.name)))
assert(AprRC:DeepCompare(definition, rebuilt), "Latest wiki fields changed during export/import")
assert(route.scenarios[1].steps[1]._index == nil and route.scenarios[1].steps[1].Class == APR.Classes.Mage)

local previousRoute, previousRecording = AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording
local recorded = { name = "84-WikiRecording", steps = {} }
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = recorded, true
assert(R:Apply(R.commands.skillgoal, goal, recorded))
local recordedStep = recorded.steps[1]
assert(not recordedStep.Coord and not recordedStep.Zone)
assert(R:Apply(R.commands.mapmarkers, markers, recorded, recordedStep))
assert(#recorded.steps == 1 and not recordedStep.Coord and recordedStep.MapMarkers[2].mapID == 84)
assert(R:Apply(R.commands["route levelrange"], { min = 1, max = 60 }, recorded))
assert(not recorded.conditions and recorded.levelRange.max == 60)
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = previousRoute, previousRecording
print("Latest wiki: skill goals, display levels, static markers, purchases, dynamic loot, target bindings, scenarios and early completion passed.")
