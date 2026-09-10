-- Data-only Lua literals. No loadstring: route input must never execute code.
function AprRC:ParseLuaData(text)
    if type(text) ~= "string" or #text > 1000000 then return nil, "Invalid or oversized input" end
    local pos, count = 1, 0
    local function skip()
        while true do
            local _, last = text:find("^%s+", pos)
            if last then pos = last + 1 end
            if text:sub(pos, pos + 1) ~= "--" then return end
            local equals = text:match("^%-%-%[(=*)%[", pos)
            if equals then
                local _, finish = text:find("]" .. equals .. "]", pos + 4 + #equals, true)
                if not finish then error("Unterminated comment") end
                pos = finish + 1
            else
                pos = (text:find("\n", pos, true) or #text) + 1
            end
        end
    end
    local function take(token)
        skip()
        if text:sub(pos, pos + #token - 1) == token then pos = pos + #token; return true end
    end
    local function quoted()
        local quote = text:sub(pos, pos)
        pos = pos + 1
        local result = {}
        local escapes = { n = "\n", r = "\r", t = "\t", a = "\a", b = "\b", f = "\f", v = "\v" }
        while pos <= #text do
            local c = text:sub(pos, pos)
            pos = pos + 1
            if c == quote then return table.concat(result) end
            if c == "\\" then
                c = text:sub(pos, pos)
                pos = pos + 1
                if c:match("%d") then
                    local digits = c .. (text:match("^%d?%d?", pos) or "")
                    pos = pos + #digits - 1
                    local byte = tonumber(digits)
                    if byte > 255 then error("Invalid string escape") end
                    c = string.char(byte)
                else
                    c = escapes[c] or c
                end
            end
            result[#result + 1] = c
        end
        error("Unterminated string")
    end
    local value
    value = function(depth)
        count = count + 1
        if depth > 40 or count > 100000 then error("Data is too deeply nested or too large") end
        skip()
        local c = text:sub(pos, pos)
        if c == '"' or c == "'" then return quoted() end
        if take("{") then
            local result, index = {}, 1
            while not take("}") do
                local key, entry
                if take("[") then
                    key = value(depth + 1)
                    if not take("]") or not take("=") then error("Expected ] =") end
                    entry = value(depth + 1)
                else
                    skip()
                    local start = pos
                    local identifier = text:match("^([%a_][%w_]*)", pos)
                    if identifier then pos = pos + #identifier end
                    if identifier and take("=") then
                        key, entry = identifier, value(depth + 1)
                    else
                        pos = start
                        key, entry = index, value(depth + 1)
                        index = index + 1
                    end
                end
                if type(key) ~= "string" and type(key) ~= "number" then error("Invalid table key") end
                if result[key] ~= nil then error("Duplicate table key: " .. tostring(key)) end
                result[key] = entry
                if not take(",") and not take(";") then
                    if not take("}") then error("Expected comma or }") end
                    return result
                end
            end
            return result
        end
        skip()
        local number = text:match("^([+-]?%d+%.?%d*[eE][+-]?%d+)", pos)
            or text:match("^([+-]?%d+%.?%d*)", pos)
            or text:match("^([+-]?%.%d+)", pos)
        if number then
            pos = pos + #number
            local parsed = tonumber(number)
            if not parsed or parsed == math.huge or parsed == -math.huge then error("Invalid number") end
            return parsed
        end
        local identifier = text:match("^([%a_][%w_%.]*)", pos)
        if identifier then
            pos = pos + #identifier
            if identifier == "true" then return true end
            if identifier == "false" then return false end
            -- Only APR's public constant tables are accepted, never functions.
            local group, key = identifier:match("^APR%.([%w_]+)%.([%w_]+)$")
            local allowed = { EXPANSIONS = true, CATEGORIES = true, PREFAB_TYPES = true, EVENTS = true,
                Classes = true, Races = true, Specs = true, REPUTATION_TYPE = true, REPUTATION_STANDING = true }
            local constant = group and allowed[group] and APR[group] and APR[group][key]
            if type(constant) == "string" or type(constant) == "number" then return constant end
        end
        error("Expected a data value at position " .. pos)
    end
    local ok, result = pcall(function()
        local parsed = value(0)
        skip()
        if pos <= #text then error("Unexpected input at position " .. pos) end
        return parsed
    end)
    if ok then return result end
    return nil, tostring(result)
end

function AprRC:CopyData(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = self:CopyData(entry) end
    return copy
end

function AprRC:SerializeData(value, depth)
    depth = depth or 0
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    if depth > 40 then error("Data is too deeply nested") end
    local lines, nextIndex = { "{" }, 1
    for _, key in ipairs(self:CustomSortKeys(value)) do
        local prefix
        if key == nextIndex then
            prefix, nextIndex = "", nextIndex + 1
        elseif type(key) == "string" and key:match("^[%a_][%w_]*$") then
            prefix = key .. " = "
        else
            prefix = "[" .. self:SerializeData(key, depth + 1) .. "] = "
        end
        lines[#lines + 1] = string.rep("    ", depth + 1) .. prefix .. self:SerializeData(value[key], depth + 1) .. ","
    end
    lines[#lines + 1] = string.rep("    ", depth) .. "}"
    return table.concat(lines, "\n")
end
