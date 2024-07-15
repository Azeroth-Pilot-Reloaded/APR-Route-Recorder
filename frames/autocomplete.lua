local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.autocomplete = AprRC:NewModule('AutoComplete')

function AprRC.autocomplete:ShowAutoComplete(title, list, onConfirm, formatItem, width, height, showAllOnEmpty)
    showAllOnEmpty = showAllOnEmpty or false
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(title)
    frame.statustext:GetParent():Hide()
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(width or 1000)
    frame:SetHeight(height or 450)
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
        onConfirm(editbox:GetText(), editbox.key, frame)
    end)

    local debounceTimer = nil
    local function UpdateAutoCompleteList(text)
        if debounceTimer then
            debounceTimer:Cancel()
        end
        debounceTimer = C_Timer.NewTimer(0.3, function()
            scrollFrame:ReleaseChildren() -- Clear current list
            editbox.key = nil
            local matches = {}

            if text ~= "" or showAllOnEmpty then
                for key, value in pairs(list) do
                    if text == "" or string.match(value:lower(), text:lower()) then
                        table.insert(matches, { key = key, value = value })
                    end
                end
            end

            -- Render items in chunks to avoid lag
            local function RenderMatches(startIndex, endIndex)
                for i = startIndex, endIndex do
                    local match = matches[i]
                    if match then
                        local interacLabel = AceGUI:Create("InteractiveLabel")
                        interacLabel:SetText(formatItem and formatItem(match) or match.value)
                        interacLabel:SetColor(255, 255, 255)
                        interacLabel:SetFullWidth(true)
                        interacLabel:SetCallback("OnClick", function()
                            editbox:SetText(match.value)
                            editbox.key = match.key
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

            if #matches > 0 then
                scrollFrame.frame:Show()
                RenderMatches(1, math.min(10, #matches)) -- Start rendering first 10 matches for lazy rendering
            else
                scrollFrame.frame:Hide()
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

    -- Initial call to show all items if the text is empty and showAllOnEmpty is true
    if showAllOnEmpty then
        UpdateAutoCompleteList("")
    end
end

function AprRC.autocomplete:ShowLocaleAutoComplete()
    self:ShowAutoComplete(
        "Extra Line Text",
        L_APR,
        function(text, key, frame)
            if not key then
                key = AprRC:ExtraLineTextToKey(text)
                AprRCData.ExtraLineTexts[key] = text
            end
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
            AceGUI:Release(frame)
        end
    )
end

function AprRC.autocomplete:ShowItemAutoComplete(questID, objectiveID)
    local itemList = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                if itemName then
                    itemList[itemID] = itemName
                end
            end
        end
    end

    self:ShowAutoComplete(
        "Select Item",
        itemList,
        function(_, itemID, frame)
            local currentStep = AprRC:GetLastStep()
            if not currentStep.Button then
                currentStep.Button = {}
            end
            currentStep.Button[questID .. "-" .. objectiveID] = tonumber(itemID, 10)
            print("|cff00bfff Button |r Added")
            AceGUI:Release(frame)
        end,
        function(match)
            local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(match.key)
            return "|T" .. itemIcon .. ":35:35|t " .. itemName
        end,
        500,
        450,
        true
    )
end

function AprRC.autocomplete:ShowSpellAutoComplete(questID, objectiveID)
    local spellList = {}
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        for j = offset + 1, offset + numSlots do
            local name, subName = C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
            local spellID = select(2, C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player))
            spellList[spellID] = name
        end
    end

    self:ShowAutoComplete(
        "Select Spell",
        spellList,
        function(_, spellID, frame)
            local currentStep = AprRC:GetLastStep()
            if not currentStep.SpellButton then
                currentStep.SpellButton = {}
            end
            currentStep.SpellButton[questID .. "-" .. objectiveID] = tonumber(spellID, 10)
            print("|cff00bfff SpellButton |r Added")
            AceGUI:Release(frame)
        end,
        function(match)
            local spellInfo = C_Spell.GetSpellInfo(match.key)
            if spellInfo then
                return "|T" .. spellInfo.iconID .. ":35:35|t " .. spellInfo.name
            end
        end,
        500,
        450,
        true
    )
end
