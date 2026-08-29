local AceGUI = LibStub("AceGUI-3.0")

AprRC.ReputationFrame = AprRC:NewModule("ReputationFrame")

local REPUTATION_TYPES = {
    standard = "Standard reputation",
    renown = "Renown / major faction",
    friendship = "Friendship / NPC",
}
local REPUTATION_TYPE_ORDER = { "standard", "renown", "friendship" }
local STEP_CONFIG = {
    Reputation = {
        title = "Add Reputation step",
        statusText = "The route waits until the selected reputation level is reached.",
        createStep = true,
    },
    ReputationLevel = {
        title = "Add ReputationLevel option",
        statusText = "The current step is shown only after the selected reputation level is reached.",
    },
    SkipForReputation = {
        title = "Add SkipForReputation option",
        statusText = "The current step is skipped once the selected reputation level is reached.",
    },
}

local activeFrame

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local success, result = pcall(func, ...)
    return success and result or nil
end

local function GetReputationProgress(factionID)
    if not factionID or not APR or type(APR.GetReputationRequirement) ~= "function" then
        return nil
    end

    return SafeCall(APR.GetReputationRequirement, APR, {
        factionID = factionID,
        level = 1,
    })
end

local function GetStandingLabel(level)
    if APR and type(APR.GetReputationStandingLabel) == "function" then
        return SafeCall(APR.GetReputationStandingLabel, APR, level) or tostring(level)
    end

    if GetText then
        return GetText("FACTION_STANDING_LABEL" .. level, UnitSex("player")) or tostring(level)
    end

    return tostring(level)
end

local function GetStandardStandingHelp()
    local standings = {}
    for level = 1, 8 do
        table.insert(standings, level .. " " .. GetStandingLabel(level))
    end
    return table.concat(standings, "  |  ")
end

local function FormatProgress(progress)
    if not progress then
        return nil
    end

    local details = {}
    if progress.name then
        table.insert(details, progress.name)
    end
    if progress.currentLevel then
        local currentText = "Current: " .. tostring(progress.currentLevel)
        if progress.maxLevel then
            currentText = currentText .. " / " .. tostring(progress.maxLevel)
        end
        table.insert(details, currentText)
    end

    return table.concat(details, " - ")
end

function AprRC.ReputationFrame:GetKnownReputations()
    local reputations = {}
    local seenFactionIDs = {}
    local getNumFactions = C_Reputation and C_Reputation.GetNumFactions
    local getFactionDataByIndex = C_Reputation and C_Reputation.GetFactionDataByIndex
    local numFactions = tonumber(SafeCall(getNumFactions)) or 0

    for index = 1, numFactions do
        local factionData = SafeCall(getFactionDataByIndex, index)
        local factionID = factionData and tonumber(factionData.factionID)
        local isSelectable = factionData and (not factionData.isHeader or factionData.isHeaderWithRep)

        if factionID and factionID > 0 and isSelectable and not seenFactionIDs[factionID] then
            local progress = GetReputationProgress(factionID)
            table.insert(reputations, {
                factionID = factionID,
                name = (progress and progress.name) or factionData.name or ("Faction " .. factionID),
                type = (progress and progress.type) or "standard",
                currentLevel = progress and progress.currentLevel,
                maxLevel = progress and progress.maxLevel,
            })
            seenFactionIDs[factionID] = true
        end
    end

    table.sort(reputations, function(a, b)
        local aName = string.lower(a.name or "")
        local bName = string.lower(b.name or "")
        if aName == bName then
            return a.factionID < b.factionID
        end
        return aName < bName
    end)

    return reputations
end

function AprRC.ReputationFrame:BuildRequirement(factionIDText, reputationType, levelText)
    local factionID = AprRC:ParsePositiveInteger(factionIDText)
    if not factionID or factionID < 1 then
        return nil, "Faction ID must be a positive integer"
    end

    if not REPUTATION_TYPES[reputationType] then
        return nil, "Select a reputation type"
    end

    local level = AprRC:ParsePositiveInteger(levelText)
    if not level or level < 1 then
        return nil, "Reputation level must be a positive integer"
    end
    if reputationType == "standard" and level > 8 then
        return nil, "Standard reputation standing must be between 1 and 8"
    end

    return {
        factionID = factionID,
        type = reputationType,
        level = level,
    }
end

function AprRC.ReputationFrame:Show(stepKey)
    local config = STEP_CONFIG[stepKey]
    if not config then
        APR:PrintError("Unsupported reputation step option")
        return
    end

    if activeFrame then
        AceGUI:Release(activeFrame)
        activeFrame = nil
    end

    local frame = AceGUI:Create("Frame")
    activeFrame = frame
    frame:SetTitle(config.title)
    frame:SetStatusText(config.statusText)
    frame:SetWidth(560)
    frame:SetHeight(385)
    frame:EnableResize(false)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget)
        if activeFrame == widget then
            activeFrame = nil
        end
        AceGUI:Release(widget)
    end)

    local knownReputations = self:GetKnownReputations()
    local knownByID = {}
    local factionList = { manual = "Enter a faction ID manually" }
    local factionOrder = { "manual" }
    for _, reputation in ipairs(knownReputations) do
        local label = string.format("%s [%d] - %s", reputation.name, reputation.factionID,
            REPUTATION_TYPES[reputation.type] or reputation.type)
        if reputation.currentLevel then
            label = label .. " (" .. tostring(reputation.currentLevel)
            if reputation.maxLevel then
                label = label .. "/" .. tostring(reputation.maxLevel)
            end
            label = label .. ")"
        end
        factionList[reputation.factionID] = label
        table.insert(factionOrder, reputation.factionID)
        knownByID[reputation.factionID] = reputation
    end

    local factionDropdown = AceGUI:Create("Dropdown")
    factionDropdown:SetLabel("Known reputation")
    factionDropdown:SetList(factionList, factionOrder)
    factionDropdown:SetValue("manual")
    factionDropdown:SetFullWidth(true)
    frame:AddChild(factionDropdown)

    local factionIDEdit = AceGUI:Create("EditBox")
    factionIDEdit:SetLabel("Faction ID")
    factionIDEdit:DisableButton(true)
    factionIDEdit:SetRelativeWidth(0.68)
    frame:AddChild(factionIDEdit)

    local detectButton = AceGUI:Create("Button")
    detectButton:SetText("Detect type / current level")
    detectButton:SetRelativeWidth(0.32)
    frame:AddChild(detectButton)

    local typeDropdown = AceGUI:Create("Dropdown")
    typeDropdown:SetLabel("Reputation type")
    typeDropdown:SetList(REPUTATION_TYPES, REPUTATION_TYPE_ORDER)
    typeDropdown:SetValue("standard")
    typeDropdown:SetRelativeWidth(0.5)
    frame:AddChild(typeDropdown)

    local levelEdit = AceGUI:Create("EditBox")
    levelEdit:SetLabel("Standing (1-8)")
    levelEdit:DisableButton(true)
    levelEdit:SetRelativeWidth(0.5)
    frame:AddChild(levelEdit)

    local infoLabel = AceGUI:Create("Label")
    infoLabel:SetFullWidth(true)
    infoLabel:SetText(GetStandardStandingHelp())
    frame:AddChild(infoLabel)

    local function RefreshInfo(progress)
        local reputationType = typeDropdown:GetValue()
        local levelLabel = "Target level"
        local helpText

        if reputationType == "standard" then
            levelLabel = "Standing (1-8)"
            helpText = GetStandardStandingHelp()
        elseif reputationType == "renown" then
            levelLabel = "Renown level"
            helpText = "Enter the target renown level."
        elseif reputationType == "friendship" then
            levelLabel = "Friendship rank"
            helpText = "Enter the target friendship/NPC rank."
        end

        levelEdit:SetLabel(levelLabel)
        local progressText = FormatProgress(progress)
        if progressText and progressText ~= "" then
            helpText = progressText .. "\n" .. helpText
        end
        infoLabel:SetText(helpText or "")
    end

    local function DetectFaction(useCurrentLevel)
        local factionID = AprRC:ParsePositiveInteger(factionIDEdit:GetText())
        if not factionID or factionID < 1 then
            APR:PrintError("Faction ID must be a positive integer")
            return
        end

        local progress = GetReputationProgress(factionID)
        if progress and REPUTATION_TYPES[progress.type] then
            typeDropdown:SetValue(progress.type)
        end
        if useCurrentLevel and progress and progress.currentLevel then
            levelEdit:SetText(tostring(progress.currentLevel))
        end
        RefreshInfo(progress)
    end

    factionDropdown:SetCallback("OnValueChanged", function(_, _, factionID)
        if factionID == "manual" then
            factionIDEdit:SetText("")
            RefreshInfo(nil)
            return
        end

        local reputation = knownByID[factionID]
        factionIDEdit:SetText(tostring(factionID))
        if reputation and REPUTATION_TYPES[reputation.type] then
            typeDropdown:SetValue(reputation.type)
        end
        if reputation and reputation.currentLevel then
            levelEdit:SetText(tostring(reputation.currentLevel))
        else
            levelEdit:SetText("")
        end
        RefreshInfo(reputation)
    end)

    detectButton:SetCallback("OnClick", function()
        DetectFaction(true)
    end)

    factionIDEdit:SetCallback("OnEnterPressed", function()
        DetectFaction(true)
    end)

    typeDropdown:SetCallback("OnValueChanged", function()
        local factionID = AprRC:ParsePositiveInteger(factionIDEdit:GetText())
        RefreshInfo(GetReputationProgress(factionID))
    end)

    local currentStep
    local currentRequirement
    if not config.createStep then
        currentStep = AprRC:GetLastStep()
        currentRequirement = currentStep and currentStep[stepKey]
    end
    if type(currentRequirement) == "table" then
        local currentFactionID = tonumber(currentRequirement.factionID)
        local currentProgress = GetReputationProgress(currentFactionID)
        local currentType = currentRequirement.type == "standing" and "standard" or currentRequirement.type
        factionIDEdit:SetText(currentFactionID and tostring(currentFactionID) or "")
        factionDropdown:SetValue(knownByID[currentFactionID] and currentFactionID or "manual")
        if REPUTATION_TYPES[currentType] then
            typeDropdown:SetValue(currentType)
        elseif currentProgress and REPUTATION_TYPES[currentProgress.type] then
            typeDropdown:SetValue(currentProgress.type)
        end
        levelEdit:SetText(currentRequirement.level and tostring(currentRequirement.level) or "")
        RefreshInfo(currentProgress)
    end

    local addButton = AceGUI:Create("Button")
    addButton:SetText(config.createStep and "Add step" or "Add option")
    addButton:SetRelativeWidth(0.5)
    addButton:SetCallback("OnClick", function()
        local requirement, errorMessage = self:BuildRequirement(
            factionIDEdit:GetText(),
            typeDropdown:GetValue(),
            levelEdit:GetText()
        )
        if not requirement then
            APR:PrintError(errorMessage)
            return
        end

        if config.createStep then
            AprRC:NewStep({ [stepKey] = requirement })
        else
            currentStep = currentStep or AprRC:GetLastStep()
            currentStep[stepKey] = requirement
        end

        print(string.format("|cff00bfff%s - faction %d, %s %d|r Added", stepKey, requirement.factionID,
            requirement.type, requirement.level))
        AceGUI:Release(frame)
        activeFrame = nil
    end)
    frame:AddChild(addButton)

    local cancelButton = AceGUI:Create("Button")
    cancelButton:SetText(CANCEL or "Cancel")
    cancelButton:SetRelativeWidth(0.5)
    cancelButton:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        activeFrame = nil
    end)
    frame:AddChild(cancelButton)
end
