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
        if v2 == nil or not self:DeepCompare(v1, v2) then return false end
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

function AprRC:ExtraLinetableToString(tbl, level, cache)
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
            str = str ..
                indent .. "  " .. keyString .. " = \n" .. AprRC:ExtraLinetableToString(v, (level or 0) + 1, cache)
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

    local keys = self:CustomSortKeys(tbl)

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

function AprRC:TableToString(tbl)
    -- Update or add _index
    for i, v in ipairs(tbl) do
        if type(v) == "table" then
            v._index = i
        end
    end
    local text = self:RouteToString(tbl)

    local function formatCoordString(coordString)
        return coordString:gsub("x%s*=%s*(-?%d+%.%d+)", function(x)
            return string.format("x = %.1f", tonumber(x))
        end):gsub("y%s*=%s*(-?%d+%.%d+)", function(y)
            return string.format("y = %.1f", tonumber(y))
        end)
    end

    text = string.gsub(text, "\n                ", " ")
    text = string.gsub(text, "{\n            ", "{ ")
    text = string.gsub(text, ",\n        },", " },")
    text = string.gsub(text, ",\n            ", ", ")
    text = string.gsub(text, ", }", " }")

    local textFormated = formatCoordString(text)

    return textFormated
end

function AprRC:StringToTable(str, dontUseCleaner)
    local cleanedStr = str or ""
    if not dontUseCleaner then cleanedStr = cleanedStr:gsub("[%s\n\r\t]+", "") end

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

function AprRC:ValidateRouteTable(routeTable)
    if type(routeTable) ~= "table" then
        return false, "not a table"
    end
    for key, step in pairs(routeTable) do
        if type(key) ~= "number" then
            return false, string.format("unexpected entry '%s' (only step tables allowed)", tostring(key))
        end
        if type(step) ~= "table" then
            return false, string.format("step %s is not a table", tostring(key))
        end
    end
    return true
end

function AprRC:StripLuaComments(text)
    if not text or text == "" then
        return ""
    end
    -- remove block comments --[[ ... ]]
    text = text:gsub("%-%-%[%[.-%]%]", "")
    -- remove single-line comments -- ...
    text = text:gsub("%-%-[^\n]*", "")
    return text
end

function AprRC:HasLuaComments(text)
    if not text or text == "" then
        return false
    end
    if text:match("%-%-%[%[") and text:match("%]%]") then
        return true
    end
    if text:match("%-%-") then
        return true
    end
    return false
end

function AprRC:FormatTextToTableString(text)
    text = string.gsub(text, '([^\n{}])\n', '%1,\n')
    text = "{\n" .. text .. "}"
    text = text:gsub(",}", "}")
    return text
end

function AprRC:ParseQuestIDs(rawText)
    local ids = {}
    for token in string.gmatch(rawText or "", "[^,]+") do
        local trimmed = strtrim(token or "")
        if trimmed ~= "" then
            if not trimmed:match("^%d+$") then
                return nil
            end
            table.insert(ids, tonumber(trimmed, 10))
        end
    end
    if #ids == 0 then
        return nil
    end
    return ids
end

function AprRC:ParseQuestID(rawText)
    local questIDs = self:ParseQuestIDs(rawText)
    if questIDs and #questIDs == 1 then
        return questIDs[1]
    end
    return nil
end

function AprRC:ParsePositiveNumber(rawText)
    local trimmed = strtrim(rawText or "")
    if trimmed == "" or not trimmed:match("^%d+%.?%d*$") then
        return nil
    end
    return tonumber(trimmed)
end

function AprRC:ParsePositiveInteger(rawText)
    local trimmed = strtrim(rawText or "")
    if trimmed == "" or not trimmed:match("^%d+$") then
        return nil
    end
    return tonumber(trimmed, 10)
end

function AprRC:CustomSortKeys(tbl)
    local priorityList = {
        "Waypoint", "WaypointDB", "NonSkippableWaypoint", "PickUp", "PickUpDB", "Qpart", "QpartPart", "QpartDB", "Done", "DoneDB",
        "LeaveQuests", "Treasure", "Scenario", "EnterScenario", "DoScenario", "LeaveScenario", "LearnProfession", "Grind",
        "DropQuest", "DroppableQuest", "LootItem", "UseItem", "UseSpell",
        "ChromiePick", "SetHS", "GetFP", "UseHS", "UseDalaHS", "UseGarrisonHS", "UseFlightPath", "Name", "NodeID",
        "WarMode", "Coord", "Fillers", "BuyMerchant", "Button", "SpellButton", "ExtraLineText",
        "ExtraLineText2", "ExtraLineText3", "ExtraLineText4", "ExtraLineText5", "ExtraLineText6", "ExtraLineText7",
        "GossipOptionIDs", "Range", "NoArrow", "DenyNPC", "ZoneStepTrigger", "Buffs",
    }

    local function customSort(a, b)
        local typeA, typeB = type(a), type(b)
        local indexA = typeA == "string" and tIndexOf(priorityList, a) or nil
        local indexB = typeB == "string" and tIndexOf(priorityList, b) or nil

        if indexA and indexB then
            return indexA < indexB
        elseif indexA then
            return true
        elseif indexB then
            return false
        end

        if typeA == typeB then
            if typeA == "number" or typeA == "string" then
                return a < b
            else
                return tostring(a) < tostring(b)
            end
        end

        -- Ensure deterministic order across mixed types: numbers first, then strings, then others.
        if typeA == "number" then return true end
        if typeB == "number" then return false end
        if typeA == "string" then return true end
        if typeB == "string" then return false end
        return tostring(a) < tostring(b)
    end

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, customSort)

    return keys
end

function AprRC:IsCampaignQuest(questID)
    local questIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local questInfo = C_QuestLog.GetInfo(questIndex)
    return questInfo and questInfo.campaignID ~= nil
end

function AprRC:AddZoneStepTrigger(step)
    local y, x = UnitPosition("player")
    if x and y then
        x = tonumber(string.format("%.2f", x))
        y = tonumber(string.format("%.2f", y))
        step.ZoneStepTrigger = { x = x, y = y, Range = 15 }
        step.Range = nil
    end
end

function AprRC:GetQpartpartTrigTextProgress(objectiveInfo)
    if not objectiveInfo then return "1/1" end

    local total = tonumber(objectiveInfo.numRequired) or 0
    local current = tonumber(objectiveInfo.numFulfilled) or 0

    -- Try to parse from text if needed
    if (total == 0 or current == 0) and objectiveInfo.text then
        local fulfilledText, requiredText = objectiveInfo.text:match("(%d+)%s*/%s*(%d+)")
        current = tonumber(fulfilledText) or current
        total = tonumber(requiredText) or total
    end

    if total > 0 then
        local nextCount = math.min(current + 1, total)
        return string.format("%d/%d", nextCount, total)
    end

    return "1/1"
end
