local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local _G = _G
local AceGUI = LibStub("AceGUI-3.0")

AprRC.QuestObjectiveSelector = AprRC:NewModule('QuestObjectiveSelector')

local function public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return nil end
    return value
end


function AprRC.QuestObjectiveSelector:Show(config)
    local frame = AprRC:CreateWidget("Frame")
    frame:SetTitle(config.title or L["Quest Objective Selector"])
    frame:SetStatusText(config.statusText or L["Select a quest objective"])
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(800)
    frame:SetHeight(600)
    frame:EnableResize(true)
    frame:SetLayout("Fill")

    local mainGroup = AprRC:CreateWidget("SimpleGroup")
    mainGroup:SetFullWidth(true)
    mainGroup:SetFullHeight(true)
    mainGroup:SetLayout("Flow")
    frame:AddChild(mainGroup)

    local searchBox = AprRC:CreateWidget("EditBox")
    searchBox:SetLabel(L["Search (QuestID or text)"])
    searchBox:SetFullWidth(true)
    mainGroup:AddChild(searchBox)

    local scrollFrame = AprRC:CreateWidget("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    scrollFrame:SetLayout("Flow")

    local function GetSearchTokens(text)
        local tokens = {}
        text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        for token in text:gmatch("%S+") do
            table.insert(tokens, token)
        end
        return tokens
    end

    local function ObjectiveMatchesTokens(quest, objective, tokens)
        if #tokens == 0 then
            return true
        end

        local questTitle = quest.title or ""
        local questID = quest.questID and tostring(quest.questID) or ""
        local objectiveText = (objective and objective.text) or ""
        local haystack = (questTitle .. " " .. questID .. " " .. objectiveText):lower()

        for _, token in ipairs(tokens) do
            if not haystack:find(token, 1, true) then
                return false
            end
        end

        return true
    end

    local function BuildQuestList(filterText)
        scrollFrame:ReleaseChildren()

        local tokens = GetSearchTokens(filterText)
        local questList = config.questList or {}

        for _, quest in ipairs(questList) do
            if quest.objectives and #quest.objectives > 0 then
                local questGroup = nil
                local isFirst = true

                for _, objective in ipairs(quest.objectives) do
                    if ObjectiveMatchesTokens(quest, objective, tokens) then
                        if not questGroup then
                            questGroup = AprRC:CreateWidget("InlineGroup")
                            questGroup:SetFullWidth(true)
                            questGroup:SetTitle(quest.title)
                            questGroup:SetLayout("List")
                        end

                        if not isFirst then
                            local spacer = AprRC:CreateWidget("Label")
                            spacer:SetText("")
                            spacer:SetFullWidth(true)
                            spacer:SetHeight(10)
                            questGroup:AddChild(spacer)
                        end

                        local objectiveLabel = AprRC:CreateWidget("InteractiveLabel")
                        objectiveLabel:SetText("[" .. objective.objectiveID .. "]" .. " - " .. (objective.text or ""))
                        objectiveLabel:SetFullWidth(true)
                        objectiveLabel:SetCallback("OnClick", function()
                            if config.onClick then
                                config.onClick(quest.questID, objective.objectiveID)
                            end
                            AceGUI:Release(frame)
                        end)
                        objectiveLabel:SetCallback("OnEnter", function(widget)
                            widget:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                        end)
                        objectiveLabel:SetCallback("OnLeave", function(widget)
                            widget:SetHighlight(nil)
                        end)
                        questGroup:AddChild(objectiveLabel)

                        isFirst = false
                    end
                end

                if questGroup then
                    scrollFrame:AddChild(questGroup)
                end
            end
        end
    end

    searchBox:SetCallback("OnTextChanged", function(_, _, text)
        BuildQuestList(text)
    end)

    mainGroup:AddChild(scrollFrame)
    BuildQuestList("")
    return frame
end

local function GetFormattedQuestObjectives(questID, objectiveIDs)
    local formattedObjectives = {}
    local objectivesInfo = public(C_QuestLog.GetQuestObjectives(questID))

    if objectivesInfo then
        for _, objectiveID in ipairs(objectiveIDs) do
            local objective = public(objectivesInfo[objectiveID])
            if objective then
                table.insert(formattedObjectives, {
                    objectiveID = objectiveID,
                    text = public(objective.text)
                })
            end
        end
    end

    return formattedObjectives
end

local function AddQuestsToList(questList, questsTable)
    for questID, objectives in pairs(questsTable) do
        local title = public(C_QuestLog.GetTitleForQuestID(questID))
        if title then
            local formattedObjectives = GetFormattedQuestObjectives(questID, objectives)
            table.insert(questList, {
                title = questID .. " - " .. title,
                questID = questID,
                objectives = formattedObjectives
            })
        end
    end
end

function AprRC.QuestObjectiveSelector:GetQuestList(includeCompleted)
    local questList = {}

    for i = 1, public(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = public(C_QuestLog.GetInfo(i))
        local questID = info and public(info.questID)
        if type(questID) == "number" and questID > 0 and not public(info.isHeader) then
            local title = public(C_QuestLog.GetTitleForQuestID(questID))
            if title and (includeCompleted or not public(C_QuestLog.IsComplete(questID))) then
                local objectives = {}
                local objectivesInfo = public(C_QuestLog.GetQuestObjectives(questID)) or {}
                for j, objective in ipairs(objectivesInfo) do
                    table.insert(objectives, j)
                end
                local formattedObjectives = GetFormattedQuestObjectives(questID, objectives)
                table.insert(questList, {
                    title = questID .. " - " .. title,
                    questID = questID,
                    objectives = formattedObjectives
                })
            end
        end
    end

    return questList
end

function AprRC.QuestObjectiveSelector:GetQuestListFromLastStep()
    local questList = {}
    local lastStep = AprRC:GetLastStep()

    if lastStep then
        if lastStep.Qpart then
            AddQuestsToList(questList, lastStep.Qpart)
        end

        if lastStep.Fillers then
            AddQuestsToList(questList, lastStep.Fillers)
        end
        if lastStep.QpartPart then
            AddQuestsToList(questList, lastStep.QpartPart)
        end
    end

    return questList
end
