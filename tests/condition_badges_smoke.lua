local UI, E, GUI = AprRC.editorUI, AprRC.routeEditor, LibStub("AceGUI-3.0")
local oldTexture, oldCreature = C_Texture, C_CreatureInfo
C_Texture = { GetAtlasInfo = function(atlas) return atlas ~= "raceicon-unknown-male" and {} or nil end }
C_CreatureInfo = { GetRaceInfo = function(id)
    if id == 2 then return { clientFileString = "Orc", raceName = "Orc" } end
end }
local step = { Note = "Filters", Class = { 8, "MAGE", 13 }, Race = { "Orc", 2 },
    ClassNot = "EVOKER", AnyOf = { { Race = "Troll" }, { Not = { Class = "Mage" } } },
    AllOf = { { Not = { ClassNot = "Mage" } } } }
local before = AprRC:CopyData(step)
local badges = UI.ConditionBadges(step, { Class = "Mage" })
assert(#badges == 6, "Duplicate aliases must share a badge")
assert(AprRC:DeepCompare(before, step), "Reading badges must preserve route data")
local function find(token, excluded)
    for _, badge in ipairs(badges) do
        if badge.token == token and badge.excluded == excluded then return badge end
    end
end
assert(find("mage", true) and find("evoker", true))
assert(#find("mage", false).contexts == 4, "Keep nested and group contexts")
assert(find("orc", false).atlas == "raceicon-orc-male")
assert(#UI.ConditionBadges({ Note = "Plain" }) == 0)

local row = GUI:Create("APRStepRow")
row:SetWidth(600)
row:SetConditionBadges(badges)
assert(#row.badgeFrames == 6 and row.frame:GetHeight() == 72)
assert(row.badgeFrames[1].icon.atlas == badges[1].atlas)
local clicked = false
row:SetCallback("OnClick", function() clicked = true end)
row.badgeFrames[1]:GetScript("OnClick")()
assert(clicked, "Badge clicks must select the row")
row:SetWidth(270)
assert(row.badgeFrames[4].text:GetText() == "+3" and row.badgeFrames[4]:IsShown())
assert(not row.badgeFrames[5]:IsShown(), "Resize must hide unused icons")
row.badgeFrames[4]:GetScript("OnEnter")()
assert(GameTooltip:IsShown())
row.badgeFrames[4]:GetScript("OnLeave")()
row:SetWidth(600)
assert(row.badgeFrames[6]:IsShown() and not row.badgeFrames[4].text:IsShown())
row:SetConditionBadges(UI.ConditionBadges({ Race = "Unknown" }))
assert(row.badgeFrames[1].icon:GetTexture():find("race.blp", 1, true), "Missing atlases need a fallback")
GUI:Release(row)
local reused = GUI:Create("APRStepRow")
assert(reused == row and #reused.conditionBadges == 0)
for _, button in ipairs(reused.badgeFrames) do assert(not button:IsShown() and not button.badge) end
GUI:Release(reused)

local route = assert(AprRC.editorModel:NewRoute("Condition badges"))
route.steps = { step, { Note = "Plain" } }
route.parallelSteps = { { conditions = { Race = "Orc" }, steps = { { Class = "Mage" } } } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
assert(#E.list.children[1].conditionBadges == 6 and #E.list.children[2].conditionBadges == 0)
E:SelectTab("parallel")
assert(#E.list.children[1].conditionBadges == 2, "Parallel rows include group filters")
assert(E.list.children[1].conditionBadges[2].contexts[1]:find(UI.Text("Group conditions"), 1, true))
E:Hide()
C_Texture, C_CreatureInfo = oldTexture, oldCreature
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Class/race badges: aliases, nested/group conditions, exclusions, overflow, selection and pooling passed.")
