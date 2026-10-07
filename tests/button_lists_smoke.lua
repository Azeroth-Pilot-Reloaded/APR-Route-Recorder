local GUI = LibStub("AceGUI-3.0")
local selector, autocomplete = AprRC.QuestObjectiveSelector, AprRC.autocomplete
local previousQuests, previousShow = selector.GetQuestListFromLastStep, selector.Show
local previousItem, previousSpell, previousLast = autocomplete.ShowItemAutoComplete, autocomplete.ShowSpellAutoComplete, AprRC.GetLastStep
local objective, selectID, step
selector.GetQuestListFromLastStep = function() return { { questID = 5648 } } end
selector.Show = function(_, options) objective = options.onClick end
local function open(_, questID, objectiveID, accept)
    assert(questID == 5648 and objectiveID == 1)
    selectID = function(id)
        local frame = AprRC:CreateWidget("Frame")
        accept(nil, tostring(id), frame)
    end
end
autocomplete.ShowItemAutoComplete, autocomplete.ShowSpellAutoComplete = open, open
AprRC.GetLastStep = function() return step end
for _, choice in ipairs({ "Item", "Spell" }) do
    local field = choice == "Item" and "Button" or "SpellButton"
    step = {}
    AprRC.SelectButton:ShowQuestSelector(choice)
    objective(5648, 1)
    selectID(67890)
    assert(step[field]["5648-1"] == 67890)
    for _, id in ipairs({ 12345, 67890, 1515 }) do
        AprRC.SelectButton:ShowQuestSelector(choice)
        objective(5648, 1)
        selectID(id)
    end
    assert(AprRC:DeepCompare(step[field]["5648-1"], { 67890, 12345, 1515 }), "Recording selections must accumulate under one objective key")
end
selector.GetQuestListFromLastStep, selector.Show = previousQuests, previousShow
autocomplete.ShowItemAutoComplete, autocomplete.ShowSpellAutoComplete, AprRC.GetLastStep = previousItem, previousSpell, previousLast
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Button selectors: repeated item/spell choices accumulate in order without duplicates.")
