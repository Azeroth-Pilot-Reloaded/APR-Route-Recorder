local AceGUI = LibStub("AceGUI-3.0")

AprRC.SelectButton = AprRC:NewModule('SelectButton')

function AprRC.SelectButton:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Button Type")
    frame.statustext:GetParent():Hide()
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(300)
    frame:SetHeight(150)
    frame:EnableResize(false)
    frame:SetLayout("Fill")

    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    frame:AddChild(buttonGroup)

    local function AddButton(text, callback)
        local button = AceGUI:Create("Button")
        button:SetText(text)
        button:SetFullWidth(true)
        button:SetCallback("OnClick", function()
            AceGUI:Release(frame)
            callback()
        end)
        buttonGroup:AddChild(button)
    end

    AddButton("Item", function() self:ShowQuestSelector("Item") end)
    AddButton("Spell", function() self:ShowQuestSelector("Spell") end)
end

function AprRC.SelectButton:ShowQuestSelector(type)
    local questList = AprRC.QuestObjectiveSelector:GetQuestListFromLastStep()
    if #questList == 0 then
        AprRC:Error("No Qpart or Filler quests available on your last step")
        return
    end

    local callback
    if type == "Item" then
        callback = function(questID, objectiveID)
            AprRC.autocomplete:ShowItemAutoComplete(questID, objectiveID)
        end
    elseif type == "Spell" then
        callback = function(questID, objectiveID)
            AprRC.autocomplete:ShowSpellAutoComplete(questID, objectiveID)
        end
    end

    AprRC.QuestObjectiveSelector:Show({
        questList = questList,
        onClick = callback
    })
end
