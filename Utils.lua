function AprRC:Debug(msg, data)
    if not AprRC.settings.profile.debug then
        return
    end
    if type(data) == "table" then
        for key, value in pairs(data) do
            print(msg, " - ", key)
            AprRC:Debug(msg, value)
        end
    else
        print("|cff00bfff" .. msg .. "|r - ", data)
    end
end

--- Contain data in list
---@param list array list
---@param x object object to check if in the list
---@return true|false Boolean
function AprRC:Contains(list, x)
    if list then
        for _, v in pairs(list) do
            if v == x then
                return true
            end
        end
    end
    return false
end

function AprRC:IsTableEmpty(table)
    if (table) then
        return next(table) == nil
    end
    return false
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

function AprRC:GetItemIDFromLink(link)
    local _, _, itemID = string.find(link, "item:(%d+):")
    return itemID
end
