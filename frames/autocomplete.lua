local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.autocomplete = AprRC:NewModule('AutoComplete')

function AprRC.autocomplete:ShowAutoComplete(title, list, onConfirm, formatItem, width, height, showAllOnEmpty)
    showAllOnEmpty = showAllOnEmpty or false
    local frame = AceGUI:Create("Frame")
    local isClosing = false
    local activeTimers = {}
    local editbox, scrollFrame
    local debounceTimer = nil
    local function trackTimer(timer)
        if timer then
            table.insert(activeTimers, timer)
        end
    end
    frame:SetTitle(title)
    frame.statustext:GetParent():Hide()
    frame:SetCallback("OnClose", function(widget)
        isClosing = true
        if debounceTimer and debounceTimer.Cancel then
            debounceTimer:Cancel()
        end
        for _, t in ipairs(activeTimers) do
            if t and t.Cancel then
                t:Cancel()
            end
        end
        editbox:SetCallback("OnTextChanged", nil)
        scrollFrame:ReleaseChildren()
        AceGUI:Release(widget)
    end)
    frame:SetWidth(width or 1000)
    frame:SetHeight(height or 450)
    frame:EnableResize(false)
    frame:SetLayout("Flow")

    editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Enter text")
    editbox:SetFullWidth(true)
    editbox:DisableButton(true)

    scrollFrame = AceGUI:Create("ScrollFrame")
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

    local function UpdateAutoCompleteList(text)
        if debounceTimer then
            debounceTimer:Cancel()
        end
        debounceTimer = C_Timer.NewTimer(0.3, function()
            if isClosing then return end
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
                if isClosing then return end
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
                            GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
                            GameTooltip:ClearLines()
                            local font, size, flags = GameFontNormal:GetFont()
                            GameTooltip:AddLine("Key: " .. match.key, 1, 1, 0, false)
                            local line = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()]
                            if line then
                                line:SetFont(font, size, flags)
                            end
                            GameTooltip:Show()
                        end)
                        interacLabel:SetCallback("OnLeave", function(widget)
                            widget:SetHighlight(nil)
                            GameTooltip:Hide()
                        end)
                        scrollFrame:AddChild(interacLabel)
                    end
                end
                if endIndex < #matches then
                    local timer = C_Timer.NewTimer(0.01, function()
                        if isClosing then return end
                        RenderMatches(endIndex + 1, math.min(endIndex + 10, #matches))
                    end)
                    trackTimer(timer)
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
        trackTimer(debounceTimer)
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

function AprRC.autocomplete:ShowItemAutoComplete(questID, objectiveID, onConfirm)
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
        onConfirm,
        function(match)
            local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(match.key)
            return "|T" .. itemIcon .. ":35:35|t " .. itemName
        end,
        500,
        450,
        true
    )
end

function AprRC.autocomplete:ShowSpellAutoComplete(questID, objectiveID, onConfirm, includeProfessionSpells)
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
    if includeProfessionSpells then
        for i, spellID in ipairs(AprRC.professionSpellIDs) do
            local name = C_Spell.GetSpellName(spellID)
            spellList[spellID] = name
        end
    end

    self:ShowAutoComplete(
        "Select Spell",
        spellList,
        onConfirm,
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

function AprRC.autocomplete:ShowAchievementAutoComplete(onConfirm)
    local achievementList = {}
    for _, catId in ipairs(GetCategoryList()) do
        for i = 1, GetCategoryNumAchievements(catId) do
            local id, name = GetAchievementInfo(catId, i)
            if id and name then
                achievementList[id] = name
            end
        end
    end

    self:ShowAutoComplete(
        "Select Achievement",
        achievementList,
        onConfirm,
        function(match)
            local id, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(match.key)
            return "|T" .. icon .. ":35:35|t " .. name
        end,
        500,
        450,
        true
    )
end

function AprRC.autocomplete:ShowProfessionAutoComplete()
    local spellList = {}
    for i, spellID in ipairs(AprRC.professionSpellIDs) do
        local name = C_Spell.GetSpellName(spellID)
        spellList[spellID] = name
    end

    self:ShowAutoComplete(
        "Select Profession",
        spellList,
        function(text, key, frame)
            local step = {
                LearnProfession = tonumber(key, 10)
            }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
            print("|cff00bfff Learn Profession |r Added")
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

function AprRC.autocomplete:ShowAuraAutoComplete(onConfirm)
    local unitToken = "player"
    local auraList = {}
    local index = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unitToken, index)
        if not aura then
            break
        end

        auraList[aura.spellId] = aura.name
        index = index + 1
    end

    self:ShowAutoComplete(
        "Select Aura",
        auraList,
        onConfirm,
        function(match)
            local auraInfo = C_UnitAuras.GetPlayerAuraBySpellID(match.key)
            if auraInfo then
                return "|T" .. auraInfo.icon .. ":35:35|t " .. auraInfo.name
            end
        end,
        500,
        450,
        true
    )
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

function AprRC.autocomplete:ShowTooltipMessageAutoComplete(onConfirm)
    self:ShowAutoComplete(
        "Tooltip Message",
        L_APR,
        function(text, key, frame)
            if not key then
                key = AprRC:ExtraLineTextToKey(text)
                AprRCData.ExtraLineTexts[key] = text
            end

            if type(onConfirm) == "function" then
                onConfirm({
                    tooltipKey = key,
                })
            end

            AceGUI:Release(frame)
        end
    )
end

function AprRC.autocomplete:ShowBuffSelector(onConfirm)
    self:ShowAuraAutoComplete(function(_, spellID, frame)
        AceGUI:Release(frame)
        local spellIdNumber = tonumber(spellID, 10)
        if not spellIdNumber then
            AprRC:Error("Invalid aura selection")
            return
        end

        self:ShowTooltipMessageAutoComplete(function(result)
            if type(onConfirm) == "function" then
                onConfirm({
                    spellId = spellIdNumber,
                    tooltipMessage = result.tooltipKey,
                })
            end
        end)
    end)
end
