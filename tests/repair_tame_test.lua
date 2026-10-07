local R = AprRC.options
local repair, tame = R.commands.repair, R.commands.tamebeast
assert(repair.newStep and repair.coord and R:GetCategory(repair) == "Actions")
for _, input in ipairs({ '{ npcID = 3331 }', '{ npcID = 3331, minDurability = 90 }',
    '{ npcID = 3331, minDurability = 0 }', '{ npcID = 3331, minDurability = 100 }',
    '{ npcID = 3331, minDurability = 89.5 }' }) do assert(R:Parse(repair, input)) end
for _, input in ipairs({ '{}', '3331', '{ npcID = 0 }', '{ npcID = 1.5 }',
    '{ npcID = 3331, minDurability = -1 }', '{ npcID = 3331, minDurability = 101 }',
    '{ npcID = 3331, minDurability = "90" }', '{ npcID = 3331, minDurability = true }',
    '{ npcID = 3331, minDurability = 1e999 }', '{ npcID = 3331, unknown = true }' }) do
    assert(not R:Parse(repair, input), input)
end
assert(not R:ValidateValue(R.schemas.repair, { npcID = 3331, minDurability = 0 / 0 }))
assert(not R:ValidateValue("conditions", { Repair = { npcID = 3331 } }))
assert(R:Parse(tame, '{ npcID = 3127, spellID = 1515, Text = "Venomtail Scorpid" }').Text == "Venomtail Scorpid")
assert(R:Parse(tame, '{ npcID = 3127, text = "Legacy beast" }').text == "Legacy beast")
assert(not R:Parse(tame, '{ npcID = 3127, Text = "" }'))

local previousRoute, previousRecording = AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording
local previousAPRData, previousGUID, previousName = APRData, UnitGUID, UnitName
local previousTargetID, previousSecret, previousUnknown = APR.GetTargetID, issecretvalue, UNKNOWN
AprRCData.CurrentRoute = { name = "2393-RepairTame", steps = {} }
AprRC.settings.profile.recordBarFrame.isRecording = true
APRData = { NPCList = { [3127] = "Cached scorpid" } }
APR.GetTargetID = nil
UNKNOWN = "Unknown"
local names = { target = "Live scorpid", mouseover = "Mouseover beast", npc = "Vendor" }
local ids = { target = 3127, mouseover = 2163, npc = 3331 }
UnitGUID = function(unit) return ids[unit] and ("Creature-0-1-2-3-" .. ids[unit] .. "-00000001") end
UnitName = function(unit) return names[unit] end
assert(R:NPCName(3127) == "Cached scorpid")
assert(R:NPCName(2163) == "Mouseover beast")
assert(R:NPCName(999) == nil, "Never use the name of a different NPC")
local input = { npcID = 3127 }
assert(R:Apply(tame, input, AprRCData.CurrentRoute))
local beast = AprRCData.CurrentRoute.steps[1].TameBeast
assert(beast.Text == "Cached scorpid" and beast.text == nil and input.Text == nil)
assert(R:Apply(tame, { npcID = 3127, Text = "Custom fallback" }, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[2].TameBeast.Text == "Custom fallback")
assert(R:Apply(tame, { npcID = 3127, text = "Legacy fallback" }, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[3].TameBeast.Text == nil)
APRData.NPCList = {}
assert(R:Apply(tame, { npcID = 3127 }, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[4].TameBeast.Text == "Live scorpid")
names.target = UNKNOWN
assert(R:NPCName(3127) == nil)
names.target = "Hidden name"
issecretvalue = function(value) return value == "Hidden name" or value == UnitGUID("target") end
assert(R:NPCName(3127) == nil, "Secret GUIDs/names must not enter route data")
issecretvalue = previousSecret
assert(R:Apply(tame, { npcID = 999 }, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[5].TameBeast.Text == nil)

local repairInput = { npcID = 3331 }
assert(R:Apply(repair, repairInput, AprRCData.CurrentRoute))
local step = AprRCData.CurrentRoute.steps[6]
assert(step.Repair.minDurability == 90 and step.Coord and repairInput.minDurability == nil)
assert(AprRC.editorModel:StepKind(step) == "Repair")
assert(R:Apply(repair, { npcID = 3331, minDurability = 0 }, AprRCData.CurrentRoute))
assert(AprRCData.CurrentRoute.steps[7].Repair.minDurability == 0)
local route = AprRCData.CurrentRoute
local imported = assert(AprRC:ReadRouteDefinition(AprRC.editorModel:RouteText(route), route.name))
assert(AprRC:DeepCompare(AprRC:BuildRouteDefinition(route), AprRC:BuildRouteDefinition(imported)))
assert(imported.steps[1].TameBeast.Text == "Cached scorpid" and imported.steps[6].Repair.minDurability == 90)
AprRCData.CurrentRoute, AprRC.settings.profile.recordBarFrame.isRecording = previousRoute, previousRecording
APRData, UnitGUID, UnitName = previousAPRData, previousGUID, previousName
APR.GetTargetID, issecretvalue, UNKNOWN = previousTargetID, previousSecret, previousUnknown
print("Repair and TameBeast: validation, recording defaults, safe NPC names and export passed.")
