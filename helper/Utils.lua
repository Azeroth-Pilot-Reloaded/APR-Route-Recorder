local L = LibStub("AceLocale-3.0"):GetLocale("APR")
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

function AprRC:Error(errorMessage, data)
    if (errorMessage and type(errorMessage) == "string") then
        local redColorCode = "|cffff0000"
        if data then
            DEFAULT_CHAT_FRAME:AddMessage(redColorCode .. L["ERROR"] .. ": " .. errorMessage .. "|r - ", data)
        else
            DEFAULT_CHAT_FRAME:AddMessage(redColorCode .. L["ERROR"] .. ": " .. errorMessage .. "|r")
        end
        UIErrorsFrame:AddMessage(errorMessage, 1, 0, 0, 1, 5)
    end
end

function AprRC:DeepCompare(t1, t2)
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not deepCompare(v1, v2) then return false end
    end
    for k2, v2 in pairs(t2) do
        if t1[k2] == nil then return false end
    end
    return true
end

function AprRC:IsTableEmpty(table)
    if (table) then
        return next(table) == nil
    end
    return false
end

function AprRC:GetItemIDFromLink(link)
    local _, _, itemID = string.find(link, "item:(%d+):")
    return itemID
end

function AprRC:ExtraLineTextToKey(inputString)
    local result = string.lower(inputString)
    result = string.gsub(result, " a ", " ")
    result = string.gsub(result, " of ", " ")
    result = string.gsub(result, " the ", " ")
    result = string.gsub(result, "^a ", "")
    result = string.gsub(result, "^of ", "")
    result = string.gsub(result, "^the ", "")
    result = string.gsub(result, " - ", " ")
    result = string.gsub(result, "-", " ")
    result = string.gsub(result, "[+='\"`$£€°~^¨<>|#&;,%.:§?!*/(){}%[%]]", "")
    result = string.gsub(result, "%s", "_")
    result = string.gsub(result, "__+", "_")
    result = string.gsub(result, "_+$", "")
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

    -- Collect and sort keys
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)

    str = str .. indent .. "{\n"
    -- Iterate over the sorted keys
    for _, k in ipairs(keys) do
        local v = tbl[k] -- Get the value corresponding to the key
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

local function qpartTableToString(tbl, level, parrentKey)
    local indent = string.rep("    ", level)
    local str = "{\n"
    local itemIndent = string.rep("    ", level + 1)

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local keyStr = ''
        if parrentKey == "Button" or parrentKey == "SpellButton" then
            keyStr = '["' .. tostring(k) .. '"] = '
        else
            keyStr = "[" .. k .. "] = "
        end
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
    local qpartTableLis = { "Fillers", "Qpart", "QpartPart", "Button", "SpellButton" }

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local keyStr = type(k) == "string" and k .. " = " or ""

        if type(v) == "table" then
            if next(v) == nil then
                str = str .. itemIndent .. keyStr .. "{}" .. ",\n"
            else
                local valueStr
                if tContains(qpartTableLis, k) then
                    valueStr = qpartTableToString(v, level + 1, k)
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

function AprRC:stringToTable(str)
    local cleanedStr = str:gsub("[%s\n\r\t]+", "")

    local func, err = loadstring("return " .. cleanedStr)
    if not func then
        AprRC:Debug("Error when converting the string to a table", err)
    else
        local success, tableResult = pcall(func)
        if success then
            return tableResult
        else
            AprRC:Debug("Error when executing the string converted to a table", tableResult)
        end
    end
end
