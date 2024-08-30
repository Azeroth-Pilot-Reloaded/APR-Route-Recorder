function AprRC:ResetData()
    AprRC.settings.profile.recordBarFrame.isRecording = false
    AprRCData = {}
    AprRCData.CurrentRoute = { name = "", steps = { {} } }
    AprRCData.Routes = {}
    C_UI.Reload()
end

function AprRC:InitRoute(name)
    local mapID = C_Map.GetBestMapForUnit("player")
    AprRC:ResetQuestLookup()
    AprRC:ResetTaxiLookup()
    AprRCData.CurrentRoute = { name = mapID .. '-' .. name, steps = { {} } }
    tinsert(AprRCData.Routes, AprRCData.CurrentRoute)
end

function AprRC:UpdateRoute()
    local currentRouteName = AprRCData.CurrentRoute.name
    for i, route in ipairs(AprRCData.Routes) do
        if route.name == currentRouteName then
            AprRCData.Routes[i] = AprRCData.CurrentRoute
            break
        end
    end
end

function AprRC:NewStep(step)
    AprRC:Debug("NewStep", step)
    local lastStep = AprRC:GetLastStep()
    if AprRC:IsTableEmpty(lastStep) then
        AprRCData.CurrentRoute.steps = {}
    end
    tinsert(AprRCData.CurrentRoute.steps, step)
end

function AprRC:GetStepByIndex(index)
    return AprRCData.CurrentRoute.steps[index]
end

function AprRC:HasStepOption(stepOption)
    local step = self:GetLastStep()
    if step and step[stepOption] then
        return true
    end
    return false
end

function AprRC:SetStepCoord(step, range)
    local y, x, z, mapID = UnitPosition("player")
    if x and y and not step.NoArrow then
        x = tonumber(string.format("%.2f", x))
        y = tonumber(string.format("%.2f", y))
        step.Coord = { x = x, y = y }
        step.Zone = AprRC:getZone()
        step.Range = range
    end
end

-- Check if the your are to far away from the current step to create a new one
-- Distance = 5 by default
function AprRC:IsCurrentStepFarAway(distance)
    local step = self:GetLastStep()
    if not step or not step.Coord then
        return true
    end

    distance = distance or step.Range or 5
    local playerY, playerX = UnitPosition("player")
    local deltaX, deltaY = playerX - step.Coord.x, step.Coord.y - playerY
    local currentDistance = (deltaX * deltaX + deltaY * deltaY) ^ 0.5

    return currentDistance > distance
end

function AprRC:GetLastStep()
    return AprRCData.CurrentRoute.steps[#AprRCData.CurrentRoute.steps]
end

function AprRC:FindClosestIncompleteQuest()
    for i = #AprRCData.CurrentRoute.steps, 1, -1 do
        local step = AprRCData.CurrentRoute.steps[i]

        for _, optionType in ipairs({ "PickUp", "Done", "Qpart" }) do
            local questList = step[optionType]

            if questList and optionType == "Qpart" then
                for questID, _ in pairs(questList) do
                    if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
                        return questID
                    end
                end
            elseif questList then
                for _, questID in ipairs(questList) do
                    if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
                        return questID
                    end
                end
            end
        end
    end
    return 1
end

function AprRC:SplitQuestAndObjective(questID)
    local id, objective = questID:match("([^%-]+)%-([^%-]+)")
    if id and objective then
        return tonumber(id), tonumber(objective)
    end
    return tonumber(questID)
end

function AprRC:saveQuestInfo()
    AprRC:Debug("Save QuestInfo")
    AprRC.lastQuestState = AprRC.lastQuestState or {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHidden then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives then
                for index, objective in ipairs(objectives) do
                    AprRC.lastQuestState[info.questID] = AprRC.lastQuestState[info.questID] or {}
                    AprRC.lastQuestState[info.questID][index] = { numFulfilled = objective.numFulfilled }
                end
            end
        end
    end
end

function AprRC:IsInInstanceQuest()
    local isIntance, type = IsInInstance()
    return isIntance and type == "scenario"
end

function AprRC:FindRouteByName(routeName)
    if not AprRCData or not AprRCData.Routes or #AprRCData.Routes == 0 then
        AprRC:Debug("No routes available", nil)
        return nil, nil
    end

    for index, route in ipairs(AprRCData.Routes) do
        if route.name == routeName then
            AprRC:Debug("Route find at ", index)
            return route, index
        end
    end

    AprRC:Debug("No routes available for the name: ", routeName)
    return nil, nil
end

function AprRC:UpdateRouteByName(routeName, newRouteData)
    local route, index = self:FindRouteByName(routeName)
    if route and index then
        AprRCData.Routes[index] = newRouteData
        return true
    else
        return false
    end
end

function AprRC:AddQuestToLookup(questID, objective)
    local key = questID .. "-" .. objective
    AprRCData.QuestLookup[key] = true
end

function AprRC:IsQuestInLookup(questID, objective)
    local key = questID .. "-" .. objective
    return AprRCData.QuestLookup[key] or false
end

function AprRC:ResetQuestLookup()
    AprRCData.QuestLookup = {}
end

function AprRC:ResetTaxiLookup()
    AprRCData.TaxiLookup = {}
end

function AprRC:IsTaxiInLookup(nodeID)
    return AprRCData.TaxiLookup[nodeID] or false
end

function AprRC:getZone()
    local playerMapId
    local currentMapId = C_Map.GetBestMapForUnit('player')
    if currentMapId and Enum and Enum.UIMapType then
        playerMapId = MapUtil.GetMapParentInfo(currentMapId, Enum.UIMapType.Zone, true)
        playerMapId = playerMapId and playerMapId.mapID or currentMapId
    end
    return playerMapId
end
