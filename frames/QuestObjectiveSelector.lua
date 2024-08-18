local _G = _G
local AceGUI = LibStub("AceGUI-3.0")

AprRC.QuestObjectiveSelector = AprRC:NewModule('QuestObjectiveSelector')


function AprRC.QuestObjectiveSelector:Show(config)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(config.title or "Quest Objective Selector")
    frame:SetStatusText(config.statusText or "Select a quest objective")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(800)
    frame:SetHeight(600)
    frame:EnableResize(true)
    frame:SetLayout("Fill")

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    scrollFrame:SetLayout("Flow")


    for _, quest in ipairs(config.questList) do
        if #quest.objectives > 0 then
            local questGroup = AceGUI:Create("InlineGroup")
            questGroup:SetFullWidth(true)
            questGroup:SetTitle(quest.title)
            questGroup:SetLayout("List")

            for i, objective in ipairs(quest.objectives) do
                local objectiveLabel = AceGUI:Create("InteractiveLabel")
                objectiveLabel:SetText("[" .. objective.objectiveID .. "]" .. " - " .. objective.text)
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
                if i < #quest.objectives then
                    local spacer = AceGUI:Create("Label")
                    spacer:SetText("")
                    spacer:SetFullWidth(true)
                    spacer:SetHeight(10)
                    questGroup:AddChild(spacer)
                end
            end

            scrollFrame:AddChild(questGroup)
        end
    end

    frame:AddChild(scrollFrame)
end

local function GetFormattedQuestObjectives(questID, objectiveIDs)
    local formattedObjectives = {}
    local objectivesInfo = C_QuestLog.GetQuestObjectives(questID)

    if objectivesInfo then
        for _, objectiveID in ipairs(objectiveIDs) do
            local objective = objectivesInfo[objectiveID]
            if objective then
                table.insert(formattedObjectives, {
                    objectiveID = objectiveID,
                    text = objective.text
                })
            end
        end
    end

    return formattedObjectives
end

local function AddQuestsToList(questList, questsTable)
    for questID, objectives in pairs(questsTable) do
        local title = C_QuestLog.GetTitleForQuestID(questID)
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

function AprRC.QuestObjectiveSelector:GetQuestList()
    local questList = {}

    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            local questID = info.questID
            local title = C_QuestLog.GetTitleForQuestID(questID)
            if title and not C_QuestLog.IsComplete(questID) then
                local objectives = {}
                local objectivesInfo = C_QuestLog.GetQuestObjectives(questID)
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
