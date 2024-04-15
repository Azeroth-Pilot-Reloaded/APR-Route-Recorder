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
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Item Button (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.Button = tonumber(text, 10)
            print("|cff00bfff Button |r Added")
        end)
    end)
    buttonGroup:AddChild(btnItem)

    local btnSpell = AceGUI:Create("Button")
    btnSpell:SetText("Spell")
    btnSpell:SetFullWidth(true)
    btnSpell:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Spell Button (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.SpellButton = tonumber(text, 10)
            print("|cff00bfff SpellButton |r Added")
        end)
    end)
    buttonGroup:AddChild(btnSpell)
end
