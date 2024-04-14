local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.autocomplete = AprRC:NewModule('AutoComplete')

function AprRC.autocomplete:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Extra Line Text")
    frame:SetStatusText("Add your Extra Line Text")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(1000)
    frame:SetHeight(450)
    frame:EnableResize(false)
    frame:SetLayout("Flow")


    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Enter text")
    editbox:SetFullWidth(true)
    editbox:DisableButton(true)

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetLayout("Flow")
    scrollFrame:SetHeight(300)
    scrollFrame.frame:Hide()

    local btnConfirm = AceGUI:Create("Button")
    btnConfirm:SetText("Confirm")
    btnConfirm:SetWidth(100)
    btnConfirm:SetDisabled(false)
    btnConfirm:SetCallback("OnClick", function()
        local key = editbox.key
        if editbox.newKey then
            key = AprRC:ExtraLineTextToKey(editbox:GetText())
            AprRCData.ExtraLineTexts[key] = editbox:GetText()
        end
        AprRC.autocomplete:SetExtraLineText(key)
        AceGUI:Release(frame)
    end)

    local function UpdateAutoCompleteList(text)
        scrollFrame:ReleaseChildren() -- Clear current list
        scrollFrame.frame:Hide()
        editbox.key = ''
        editbox.newKey = true
        if text ~= "" then
            btnConfirm:SetDisabled(false)
            for key, value in pairs(L_APR) do
                if string.match(value:lower(), text:lower()) then
                    local interacLabel = AceGUI:Create("InteractiveLabel")
                    interacLabel:SetText(value)
                    interacLabel:SetColor(255, 255, 255)
                    interacLabel:SetFullWidth(true)
                    interacLabel:SetCallback("OnClick", function()
                        editbox:SetText(value)
                        editbox.key = key
                        editbox.newKey = false
                        scrollFrame:ReleaseChildren() -- Clear list after selection
                        scrollFrame.frame:Hide()
                    end)
                    scrollFrame.frame:Show()
                    scrollFrame:AddChild(interacLabel)
                end
            end
        else
            btnConfirm:SetDisabled(true)
        end
    end

    editbox:SetCallback("OnTextChanged", function(widget, event, text)
        UpdateAutoCompleteList(text)
    end)

    frame:AddChild(editbox)
    frame:AddChild(scrollFrame)
    frame:AddChild(btnConfirm)
end

function AprRC.autocomplete:SetExtraLineText(key)
    local currentStep = AprRC:GetLastStep()

    local baseName = "ExtraLineText"
    local index = 2
    local propertyName = baseName

    if currentStep[baseName] then
        while currentStep[baseName .. index] do
            index = index + 1
        end
        propertyName = baseName .. index
    end

    currentStep[propertyName] = key
end
