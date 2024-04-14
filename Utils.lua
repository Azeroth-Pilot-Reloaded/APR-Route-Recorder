function AprRC:Debug(msg, data, force)
    if not AprRC.settings.profile.debug and not force then
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

function AprRC:ExtraLineTextToKey(inputString)
    local result = string.gsub(inputString, "%s", "_")
    result = string.gsub(result, "_a_", "_")
    result = string.gsub(result, "_of_", "_")
    result = string.gsub(result, "_the_", "_")
    result = string.gsub(result, "__", "_")
    result = string.gsub(result, "'", "")
    result = string.upper(result)

    return result
end

function AprRC:tableToString(tbl, level, cache)
    local str = ""
    local indent = string.rep("  ", level or 0)
    cache = cache or {}

    if cache[tbl] then
        str = str .. indent .. "<circular reference>\n"
        return str
    end
    cache[tbl] = true

    str = str .. indent .. "{\n"
    for k, v in pairs(tbl) do
        local keyString = k
        if type(k) == "string" then
            keyString = string.format("%q", k)
        end
        if type(v) == "table" then
            str = str .. indent .. "  " .. keyString .. " = \n" .. AprRC:tableToString(v, (level or 0) + 1, cache)
        elseif type(v) == "string" then
            str = str .. indent .. "  " .. keyString .. " = " .. string.format("%q", v) .. ",\n"
        else
            str = str .. indent .. "  " .. keyString .. " = " .. tostring(v) .. ",\n"
        end
    end
    str = str .. indent .. "}\n"

    cache[tbl] = nil
    return str
end

local function qpartTableToString(tbl, level)
    local indent = string.rep("    ", level)
    local str = "{\n"
    local itemIndent = string.rep("    ", level + 1)

    for k, v in pairs(tbl) do
        local keyStr = k .. " = "
        if type(v) == "table" then
            str = str .. itemIndent .. keyStr .. AprRC:RouteToString(v, level + 1) .. ",\n"
        else
            local valueStr = tostring(v)
            str = str .. itemIndent .. keyStr .. valueStr .. ",\n"
        end
    end

    str = str .. indent .. "}"
    return str
end

function AprRC:RouteToString(tbl, level)
    level = level or 0
    local indent = string.rep("    ", level)
    local str = "{\n"
    local itemIndent = string.rep("    ", level + 1)

    for k, v in pairs(tbl) do
        local keyStr
        if type(k) == "string" then
            keyStr = k .. " = "
        else
            keyStr = ""
        end

        if type(v) == "table" then
            if next(v) == nil then
                str = str .. itemIndent .. keyStr .. "{}" .. ",\n"
            else
                local valueStr
                if k == "Qpart" or k == "Fillers" then
                    valueStr = qpartTableToString(v, level + 1)
                else
                    valueStr = self:RouteToString(v, level + 1)
                end
                str = str .. itemIndent .. keyStr .. valueStr .. ",\n"
            end
        else
            local valueStr = type(v) == "string" and '"' .. v .. '"' or tostring(v)
            str = str .. itemIndent .. keyStr .. valueStr .. ",\n"
        end
    end

    str = str .. indent .. "}"
    return str
end
