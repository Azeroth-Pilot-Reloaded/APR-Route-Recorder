function Debug(msg, data)
    if not AprRC.settings.profile.debug then
        return
    end
    if type(data) == "table" then
        for key, value in pairs(data) do
            print(msg, " - ", key, value)
        end
    else
        print("|cff00bfff" .. msg .. " - ", data)
    end
end

--- Contain data in list
---@param list array list
---@param x object object to check if in the list
---@return true|false Boolean
function Contains(list, x)
    if list then
        for _, v in pairs(list) do
            if v == x then
                return true
            end
        end
    end
    return false
end

function IsTableEmpty(table)
    if (table) then
        return next(table) == nil
    end
    return false
end

function SplitQuestAndObjective(questID)
    local id, objective = questID:match("([^%-]+)%-([^%-]+)")
    if id and objective then
        return tonumber(id), tonumber(objective)
    end
    return tonumber(questID)
end
