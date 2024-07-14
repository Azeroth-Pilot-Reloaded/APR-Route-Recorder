local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.autocomplete = AprRC:NewModule('AutoComplete')

function AprRC.autocomplete:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Extra Line Text")
    frame.statustext:GetParent():Hide()
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

    local debounceTimer = nil
    local function UpdateAutoCompleteList(text)
        if debounceTimer then
            debounceTimer:Cancel()
        end
        debounceTimer = C_Timer.NewTimer(0.3, function()
            scrollFrame:ReleaseChildren() -- Clear current list
            scrollFrame.frame:Hide()
            editbox.key = ''
            editbox.newKey = true
            if text ~= "" then
                btnConfirm:SetDisabled(false)
                local matches = {}
                for key, value in pairs(L_APR) do
                    if string.match(value:lower(), text:lower()) then
                        table.insert(matches, { key = key, value = value })
                    end
                end

                -- Render items in chunks to avoid lag
                local function RenderMatches(startIndex, endIndex)
                    for i = startIndex, endIndex do
                        local match = matches[i]
                        if match then
                            local interacLabel = AceGUI:Create("InteractiveLabel")
                            interacLabel:SetText(match.value)
                            interacLabel:SetColor(255, 255, 255)
                            interacLabel:SetFullWidth(true)
                            interacLabel:SetCallback("OnClick", function()
                                editbox:SetText(match.value)
                                editbox.key = match.key
                                editbox.newKey = false
                                scrollFrame:ReleaseChildren() -- Clear list after selection
                                scrollFrame.frame:Hide()
                            end)
                            interacLabel:SetCallback("OnEnter", function(widget)
                                widget:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                            end)
                            interacLabel:SetCallback("OnLeave", function(widget)
                                widget:SetHighlight(nil)
                            end)
                            scrollFrame:AddChild(interacLabel)
                        end
                    end
                    if endIndex < #matches then
                        C_Timer.After(0.01, function()
                            RenderMatches(endIndex + 1, math.min(endIndex + 10, #matches))
                        end)
                    end
                end

                scrollFrame.frame:Show()
                RenderMatches(1, math.min(10, #matches)) -- Start rendering first 10 matches
            else
                btnConfirm:SetDisabled(true)
            end
            debounceTimer = nil
        end)
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

    print("|cff00bfffExtraLineTexts|r Added")
end
