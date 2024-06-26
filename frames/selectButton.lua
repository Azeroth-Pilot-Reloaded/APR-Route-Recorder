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

    local btnItem = AceGUI:Create("Button")
    btnItem:SetText("Item")
    btnItem:SetFullWidth(true)
    btnItem:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("QuestID for the button (ID)", function(questID)
            C_Timer.After(0.2, function()
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Objective index of the quest", function(index)
                    C_Timer.After(0.2, function()
                        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Item Button (ID)", function(itemID)
                            local currentStep = AprRC:GetLastStep()
                            if not currentStep.Button then
                                currentStep.Button = {}
                            end
                            currentStep.Button[questID .. "-" .. index] = tonumber(itemID, 10)
                            print("|cff00bfff Button |r Added")
                        end)
                    end)
                end)
            end)
        end)
    end)
    buttonGroup:AddChild(btnItem)

    local btnSpell = AceGUI:Create("Button")
    btnSpell:SetText("Spell")
    btnSpell:SetFullWidth(true)
    btnSpell:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("QuestID for the button (ID)", function(questID)
            C_Timer.After(0.2, function()
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Objective index of the quest", function(index)
                    C_Timer.After(0.2, function()
                        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Spell Button (ID)", function(spellID)
                            local currentStep = AprRC:GetLastStep()
                            if not currentStep.SpellButton then
                                currentStep.SpellButton = {}
                            end
                            currentStep.SpellButton[questID .. "-" .. index] = tonumber(spellID, 10)
                            print("|cff00bfff SpellButton |r Added")
                        end)
                    end)
                end)
            end)
        end)
    end)
    buttonGroup:AddChild(btnSpell)
end
