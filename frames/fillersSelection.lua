local _G = _G
local AceGUI = LibStub("AceGUI-3.0")

AprRC.fillers = AprRC:NewModule('Fillers')

function AprRC.fillers:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Fillers quest list")
    frame:SetStatusText("Click on an objective to add it as a filler")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(800)
    frame:SetHeight(600)
    frame:EnableResize(true)
    frame:SetLayout("Fill")

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    scrollFrame:SetLayout("Flow")

    local questList = AprRC.fillers:GetQuestList()

    for _, quest in ipairs(questList) do
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
                    local currentStep = AprRC:GetLastStep()
                    if not currentStep.Fillers then
                        currentStep.Fillers = {}
                    end
                    if not currentStep.Fillers[quest.questID] then
                        currentStep.Fillers[quest.questID] = {}
                    end
                    tinsert(currentStep.Fillers[quest.questID], objective.objectiveID)
                    print("|cff00bfffFillers - [" .. quest.title .. "] - " .. objective.objectiveID .. "|r Added")
                    AceGUI:Release(frame)
                end)
                objectiveLabel:SetCallback("OnEnter", function(widget)
                    widget:SetHighlight("Interface\\Buttons\\UI-Common-MouseHilight")
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

function AprRC.fillers:GetQuestList()
    local questList = {}

    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            local questID = info.questID
            local title = C_QuestLog.GetTitleForQuestID(questID)
            local isComplete = C_QuestLog.IsComplete(questID)
            if not isComplete then
                local objectives = C_QuestLog.GetQuestObjectives(questID)

                local formattedObjectives = {}
                for j, objective in ipairs(objectives) do
                    local formattedObjective = {
                        objectiveID = j,
                        text = objective.text
                    }
                    table.insert(formattedObjectives, formattedObjective)
                end

                local questData = {
                    title = questID .. " - " .. title,
                    questID = questID,
                    objectives = formattedObjectives
                }
                table.insert(questList, questData)
            end
        end
    end

    return questList
end
