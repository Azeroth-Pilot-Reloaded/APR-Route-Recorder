local E, P = AprRC.routeEditor, AprRC.editorUI.Pickers
local GUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local live = AprRC:CopyData(AprRCData.CurrentRoute)
local recording = AprRC.settings.profile.recordBarFrame.isRecording
local timers = {}
C_Timer.NewTimer = function(_, callback)
    local timer = { callback = callback, Cancel = function(self) self.cancelled = true end }
    timers[#timers + 1] = timer
    return timer
end
local function flush()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
end
C_QuestLog.GetNumQuestLogEntries = function() return 2 end
C_QuestLog.GetInfo = function(index) return { questID = index * 42, title = "Quest " .. index } end
C_QuestLog.GetTitleForQuestID = function(id) return "Quest " .. id end
C_QuestLog.IsComplete = function() return true end
C_QuestLog.GetQuestObjectives = function() return { { text = "First objective" }, { text = "Second objective" } } end
C_Container.GetContainerNumSlots = function() return 1 end
C_Container.GetContainerItemID = function() return 501 end
C_Item.GetItemInfo = function() return "Test item", nil, nil, nil, nil, nil, nil, nil, nil, 123 end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemName = function() return "Test spell" end,
    GetSpellBookItemType = function() return 1, 601 end,
}
Enum.SpellBookSpellBank = { Player = 1 }
C_Spell = { GetSpellInfo = function() return { iconID = 123, name = "Test spell" } end }
AprRC.professionSpellIDs = {}
GetCategoryList = function() return { 1 } end
GetCategoryNumAchievements = function() return 1 end
GetAchievementInfo = function() return 701, "Test achievement", nil, nil, nil, nil, nil, nil, nil, 123 end
local aprLocale = LibStub("AceLocale-3.0"):GetLocale("APR")
aprLocale.TEST_TRANSLATION_KEY = "Translated instruction"
AprRCData.ExtraLineTexts = { CUSTOM_KEY = "Custom instruction" }

local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = find(child, predicate)
        if found then return found end
    end
end
local function clickPath(path)
    local button = assert(find(E.frame, function(w) return w.pickerPath == path end), path)
    button:Fire("OnClick")
    return assert(E.fieldPicker)
end
local function selectFirst(frame)
    flush()
    local row = assert(find(frame, function(w) return w.type == "InteractiveLabel" end))
    row:Fire("OnClick")
    local confirm = find(frame, function(w) return w.type == "Button" and w.text:GetText() == L["Confirm"] end)
    if confirm then confirm:Fire("OnClick") end
end
local function input(frame, text)
    local box = assert(find(frame, function(w) return w.type == "EditBox" end))
    box:SetText(text); box:Fire("OnTextChanged", text)
    return box
end
local function confirm(frame)
    assert(find(frame, function(w) return w.type == "Button" and w.text:GetText() == L["Confirm"] end)):Fire("OnClick")
end

E:Show()
local route = assert(AprRC.editorModel:NewRoute("Picker tests"))
route.steps = { { UseSpell = { questID = 42, spellID = 1 }, PickUp = { 42 },
    UseItem = { questID = 42, itemID = 1, itemSpellID = 1 }, HasAchievement = 1,
    Qpart = { [42] = { 1 } }, SpellButton = { ["42-1"] = 1 },
    Note = "Original", ExtraLineText = "Original" }, { Note = "Second" } }
local original = AprRC:CopyData(route)
E:RefreshRoutes(); E:SelectRoute(route.name); E:SelectTab("steps")
selectFirst(clickPath("step/UseSpell/spellID"))
assert(E.session.draft.steps[1].UseSpell.spellID == 601)
selectFirst(clickPath("step/UseItem/itemID"))
assert(E.session.draft.steps[1].UseItem.itemID == 501)
selectFirst(clickPath("step/HasAchievement"))
assert(E.session.draft.steps[1].HasAchievement == 701)
local frame = clickPath("step/PickUp")
input(frame, "84"); confirm(frame)
assert(E.session.draft.steps[1].PickUp[2] == 84)
frame = clickPath("step/PickUp"); input(frame, "84"); confirm(frame)
assert(#E.session.draft.steps[1].PickUp == 2)

frame = clickPath("step/Qpart/42")
local second = assert(find(frame, function(w)
    return w.type == "InteractiveLabel" and w.label:GetText():find("[2]", 1, true)
end))
second:Fire("OnClick")
assert(E.session.draft.steps[1].Qpart[42][2] == 2, "Objectives must use their index, not the quest ID")
selectFirst(clickPath("step/SpellButton/42-1"))
assert(E.session.draft.steps[1].SpellButton["42-1"] == 601)

frame = clickPath("step/Note/variant")
input(frame, "TEST_TRANSLATION_KEY"); selectFirst(frame)
assert(E.session.draft.steps[1].Note == "TEST_TRANSLATION_KEY")
frame = clickPath("step/ExtraLineText")
input(frame, "CUSTOM_KEY"); selectFirst(frame)
assert(E.session.draft.steps[1].ExtraLineText == "CUSTOM_KEY")
frame = clickPath("step/Note/variant")
input(frame, "New localized instruction"); confirm(frame)
local generated = E.session.draft.steps[1].Note
assert(AprRCData.ExtraLineTexts[generated] == "New localized instruction")

-- Clear a selected key immediately when typing, even before the debounce fires.
frame = clickPath("step/UseSpell/spellID"); flush()
assert(find(frame, function(w) return w.type == "InteractiveLabel" end)):Fire("OnClick")
input(frame, "602"); confirm(frame)
assert(E.session.draft.steps[1].UseSpell.spellID == 602)

-- A delayed popup selection must not overwrite another step or route.
frame = clickPath("step/UseSpell/spellID")
input(frame, "603")
E.session.selected = 2
E:DrawInspector()
confirm(frame)
assert(E.session.draft.steps[1].UseSpell.spellID == 602)
assert(E.session.draft.steps[2].Note == "Second")
assert(AprRC:DeepCompare(route, original), "Pickers must only edit the draft")
assert(AprRC:DeepCompare(live, AprRCData.CurrentRoute), "Picker dispatched a recording command")
assert(recording == AprRC.settings.profile.recordBarFrame.isRecording)
assert(P:Resolve("id", "route/parallelSteps/1/conditions/HasSpell").kind == "spell")
assert(P:Resolve("id", "step/UseSpell/questID").kind == "quest")
assert(P:Resolve("objectiveKey", "step/Button/key").kind == "objectiveKey")
assert(P:Resolve("ids", "step/BankDeposit/items").kind == "item")
assert(not P:Resolve("id", "step/BuyItem/1/quantity"))
E:Hide()
assert(not E.fieldPicker)
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Editor pickers: real selector callbacks, quest objectives, ID lists, translation keys and draft isolation passed.")
