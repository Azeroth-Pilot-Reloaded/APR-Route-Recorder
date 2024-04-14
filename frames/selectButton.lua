local AceGUI = LibStub("AceGUI-3.0")

AprRC.SelectButton = AprRC:NewModule('SelectButton')

function AprRC.SelectButton:Show()
    -- Création de la fenêtre principale
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Exemple de Frame")
    frame:SetStatusText("Ace3 Frame avec boutons")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetLayout("Flow")
    frame:Hide()

    -- Bouton pour les items
    local btnItem = AceGUI:Create("Button")
    btnItem:SetText("Item")
    btnItem:SetWidth(200)
    btnItem:SetCallback("OnClick", function()
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Item Button (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.Button = tonumber(text, 10)
        end)
    end)
    frame:AddChild(btnItem)

    -- Bouton pour les sorts
    local btnSpell = AceGUI:Create("Button")
    btnSpell:SetText("Spell")
    btnSpell:SetWidth(200)
    btnSpell:SetCallback("OnClick", function()
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Spell Button (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.SpellButton = tonumber(text, 10)
        end)
    end)
    frame:AddChild(btnSpell)
end
