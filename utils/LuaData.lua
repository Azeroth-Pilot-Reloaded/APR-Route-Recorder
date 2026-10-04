local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
-- Data-only Lua literals. No loadstring: route input must never execute code.
function AprRC:ParseLuaData(text, withComments)
    if type(text) ~= "string" or #text > 1000000 then return nil, L["Invalid or oversized input"] end
    local pos, count = 1, 0
    local comments, tables, seenComments = {}, {}, {}
    local function skip()
        while true do
            local _, last = text:find("^%s+", pos)
            if last then pos = last + 1 end
            if text:sub(pos, pos + 1) ~= "--" then return end
            local start = pos
            local equals = text:match("^%-%-%[(=*)%[", pos)
            if equals then
                local _, finish = text:find("]" .. equals .. "]", pos + 4 + #equals, true)
                if not finish then error(L["Unterminated comment"]) end
                pos = finish + 1
            else
                pos = text:find("[\r\n]", pos) or (#text + 1)
            end
            if withComments and not seenComments[start] then
                comments[#comments + 1] = { start = start, finish = pos - 1, text = text:sub(start, pos - 1) }
                seenComments[start] = true
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
                    if byte > 255 then error(L["Invalid string escape"]) end
                    c = string.char(byte)
                else
                    c = escapes[c] or c
                end
            end
            result[#result + 1] = c
        end
        error(L["Unterminated string"])
    end
    local value
    value = function(depth)
        count = count + 1
        if depth > 40 or count > 100000 then error(L["Data is too deeply nested or too large"]) end
        skip()
        local c = text:sub(pos, pos)
        if c == '"' or c == "'" then return quoted() end
        if take("{") then
            local result, index = {}, 1
            local node = withComments and { start = pos - 1, entries = {}, children = {} }
            if node then tables[#tables + 1] = node end
            while not take("}") do
                local key, entry, child
                local start = pos
                if take("[") then
                    key = value(depth + 1)
                    if not take("]") or not take("=") then error(L["Expected ] ="]) end
                    entry, child = value(depth + 1)
                else
                    skip()
                    local start = pos
                    local identifier = text:match("^([%a_][%w_]*)", pos)
                    if identifier then pos = pos + #identifier end
                    if identifier and take("=") then
                        key = identifier
                        entry, child = value(depth + 1)
                    else
                        pos = start
                        key = index
                        entry, child = value(depth + 1)
                        index = index + 1
                    end
                end
                if type(key) ~= "string" and type(key) ~= "number" then error(L["Invalid table key"]) end
                if result[key] ~= nil then error(L["Duplicate table key: "] .. tostring(key)) end
                result[key] = entry
                if node then
                    node.entries[#node.entries + 1] = { key = key, start = start, finish = pos }
                    node.children[key] = child
                end
                if not take(",") and not take(";") then
                    if not take("}") then error(L["Expected comma or }"]) end
                    if node then node.finish = pos end
                    return result, node
                end
            end
            if node then node.finish = pos end
            return result, node
        end
        skip()
        local number = text:match("^([+-]?%d+%.?%d*[eE][+-]?%d+)", pos)
            or text:match("^([+-]?%d+%.?%d*)", pos)
            or text:match("^([+-]?%.%d+)", pos)
        if number then
            pos = pos + #number
            local parsed = tonumber(number)
            if not parsed or parsed == math.huge or parsed == -math.huge then error(L["Invalid number"]) end
            return parsed
        end
        local identifier = text:match("^([%a_][%w_%.]*)", pos)
        if identifier then
            pos = pos + #identifier
            if identifier == "true" then return true end
            if identifier == "false" then return false end
            -- Only APR's public constant tables are accepted, never functions.
            local group, key = identifier:match("^APR%.([%w_]+)%.([%w_]+)$")
            if not group then
                group = identifier:match("^APR%.([%w_]+)$")
                if group and take("[") then
                    key = value(depth + 1)
                    if not take("]") then error(L["Expected ] after constant key"]) end
                end
            end
            local allowed = { EXPANSIONS = true, GAME_VERSIONS = true, CATEGORIES = true, PREFAB_TYPES = true, EVENTS = true,
                Classes = true, RACES = true, Specs = true, REPUTATION_TYPE = true, REPUTATION_STANDING = true }
            local constant = group and allowed[group] and APR[group] and APR[group][key]
            if type(constant) == "string" or type(constant) == "number" then return constant end
        end
        error(L["Expected a data value at position "] .. pos)
    end
    local ok, result, root = pcall(function()
        local parsed, node = value(0)
        skip()
        if pos <= #text then error(L["Unexpected input at position "] .. pos) end
        return parsed, node
    end)
    if ok then
        -- Store comments beside the root route, never as fields in a step.
        -- Anchor them to table keys so metadata reordering keeps them attached.
        if root and #comments > 0 then
            local function append(node, slot, comment)
                node[slot] = node[slot] or {}
                node[slot][#node[slot] + 1] = comment.text
            end
            local stack, tableIndex = {}, 1
            for _, comment in ipairs(comments) do
                while tables[tableIndex] and tables[tableIndex].start < comment.start do
                    local node = tables[tableIndex]
                    while stack[#stack] and stack[#stack].finish < node.start do table.remove(stack) end
                    stack[#stack + 1] = node
                    tableIndex = tableIndex + 1
                end
                while stack[#stack] and stack[#stack].finish <= comment.finish do table.remove(stack) end
                local container = stack[#stack]
                if not container then
                    append(root, comment.start < root.start and "leading" or "trailing", comment)
                else
                    local nextKey, previous, slot = nil, nil, "before"
                    for _, entry in ipairs(container.entries) do
                        if entry.finish <= comment.start then previous = entry
                        elseif entry.start > comment.finish or entry.finish > comment.finish then
                            nextKey = entry.key; break
                        end
                    end
                    if previous and not text:sub(previous.finish, comment.start - 1):find("[\r\n]") then
                        nextKey, slot = previous.key, "after"
                    end
                    if nextKey then
                        container[slot] = container[slot] or {}
                        container[slot][nextKey] = container[slot][nextKey] or {}
                        local list = container[slot][nextKey]
                        list[#list + 1] = comment.text
                    else append(container, "tail", comment) end
                end
            end
            local function clean(node)
                node.start, node.finish, node.entries = nil, nil, nil
                for key, child in pairs(node.children) do
                    if not clean(child) then node.children[key] = nil end
                end
                if not next(node.children) then node.children = nil end
                return next(node) ~= nil
            end
            clean(root)
            return result, nil, root
        end
        return result
    end
    return nil, tostring(result)
end

function AprRC:CopyData(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = self:CopyData(entry) end
    return copy
end

-- Route containers and steps keep one field per line; nested step data stays
-- inline. The route context emits APR constants and one nextRoute target per line.
-- Pass "steps" for a legacy step-only route, or "inline" for a compact value.
-- Optional positions map step tables to zero-based byte ranges in the output.
local routeOrder = { "label", "expansion", "gameVersion", "category", "mapID", "conditions", "nextRoute", "prefab" }
local conditionConstants = { Race = "RACES", Class = "Classes", ClassNot = "Classes",
    ClassSpec = "Specs", Event = "EVENTS" }

local function constantReference(group, value)
    for _, key in ipairs(AprRC:CustomSortKeys(APR[group] or {})) do
        local entry = APR[group][key]
        if entry == value or (group == "Classes" and type(value) == "string" and
            key:gsub("%s", ""):upper() == value) then
            if key:match("^[%a_][%w_]*$") then return "APR." .. group .. "." .. key end
            return "APR." .. group .. "[" .. string.format("%q", key) .. "]"
        end
    end
end

-- Context follows metadata only. Step tables always use the existing literal
-- serializer, even when a step field shares a name with a route enum.
local function childContext(context, key)
    if context == "route" then
        local groups = { expansion = "EXPANSIONS", gameVersion = "GAME_VERSIONS", category = "CATEGORIES",
            conditions = "conditions", nextRoute = "nextRoutes", prefab = "prefab",
            parallelSteps = "parallel", scenarios = "scenarios", steps = "steps" }
        return groups[key]
    elseif context == "steps" then return "step"
    elseif context == "conditions" then
        if key == "AnyOf" or key == "AllOf" then return "conditionList" end
        if key == "Not" then return "conditions" end
        return conditionConstants[key]
    elseif context == "conditionList" then return "conditions"
    elseif context == "nextRoutes" then return "nextRoute"
    elseif context == "prefab" then return "prefabEntry"
    elseif context == "parallel" then return "parallelGroup"
    elseif context == "scenarios" then return "scenario"
    elseif context == "nextRoute" or context == "prefabEntry" or context == "parallelGroup" then
        if key == "conditions" then return "conditions" end
    elseif context and APR[context] then return context end
end

function AprRC:SerializeData(value, depth, layout, positions, offset, context, comments)
    depth = depth or 0
    if context == "route" and type(value) == "table" then comments = comments or value._luaComments end
    if context and APR[context] and type(value) ~= "table" then
        local reference = constantReference(context, value)
        if reference then return reference end
    end
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    if depth > 40 then error(L["Data is too deeply nested"]) end
    local inline = layout == "inline" and not (comments and (comments.before or comments.after or comments.tail))
    local lines, nextIndex = {}, 1
    local leading = comments and comments.leading and (table.concat(comments.leading, "\n") .. "\n") or ""
    local trailing = comments and comments.trailing and ("\n" .. table.concat(comments.trailing, "\n")) or ""
    local length = 2 + #leading -- Opening brace and newline (or space for inline tables).
    local keys = context == "step" and self:CustomSortStepKeys(value) or self:CustomSortKeys(value)
    local order = context == "route" and routeOrder or
        (context == "nextRoute" and { "route", "conditions" }) or
        (context == "prefabEntry" and { "index", "conditions" }) or
        (context == "conditions" and { "Race", "Class", "ClassNot" })
    if order then
        local ordered, seen = {}, {}
        for _, key in ipairs(order) do
            if value[key] ~= nil then ordered[#ordered + 1], seen[key] = key, true end
        end
        for _, key in ipairs(keys) do
            if not seen[key] and (context ~= "route" or key ~= "_luaComments") then ordered[#ordered + 1] = key end
        end
        keys = ordered
    end
    local function addComments(list)
        for _, comment in ipairs(list or {}) do
            local line = string.rep("    ", depth + 1) .. comment
            lines[#lines + 1] = line
            length = length + #line + 1
        end
    end
    for _, key in ipairs(keys) do
        addComments(comments and comments.before and comments.before[key])
        local prefix
        local constantKey = context == "prefab" and constantReference("PREFAB_TYPES", key)
        if constantKey then
            prefix = "[" .. constantKey .. "] = "
        elseif key == nextIndex then
            prefix, nextIndex = "", nextIndex + 1
        elseif type(key) == "string" and key:match("^[%a_][%w_]*$") then
            prefix = key .. " = "
        else
            prefix = "[" .. self:SerializeData(key, depth + 1, "inline") .. "] = "
        end
        local childLayout
        if context == "route" and (key == "conditions" or key == "prefab") then
            childLayout = "inline"
        elseif context == "route" and key == "nextRoute" then
            childLayout = "fields"
        elseif layout == "inline" or layout == "fields" then
            childLayout = "inline"
        elseif layout == "steps" and type(key) == "number" then
            childLayout = "fields"
        elseif key == "steps" then
            childLayout = "steps"
        elseif key == "conditions" then
            childLayout = "fields"
        elseif key == "nextRoute" then
            childLayout = "inline"
        end
        local indent = inline and "" or string.rep("    ", depth + 1)
        local start = positions and ((offset or 0) + length + #indent + #prefix)
        local nextContext = childContext(context, key)
        if layout == "steps" and type(key) == "number" then nextContext = "step" end
        local serialized = self:SerializeData(value[key], depth + 1, childLayout, positions, start,
            nextContext, comments and comments.children and comments.children[key])
        if positions and layout == "steps" and type(key) == "number" and type(value[key]) == "table" then
            positions[value[key]] = { start = start, finish = start + #serialized }
        end
        local entry = prefix .. serialized
        local after = comments and comments.after and comments.after[key]
        local suffix = after and (" " .. table.concat(after, "\n" .. indent)) or ""
        lines[#lines + 1] = inline and entry or (indent .. entry .. "," .. suffix)
        if positions then length = length + #indent + #entry + #suffix + 2 end
    end
    addComments(comments and comments.tail)
    -- Deleting a metadata field in the form keeps its adjacent comments visible.
    for _, slot in ipairs({ "before", "after" }) do
        for _, key in ipairs(self:CustomSortKeys(comments and comments[slot] or {})) do
            if value[key] == nil then addComments(comments[slot][key]) end
        end
    end
    if inline then
        return leading .. (#lines == 0 and "{}" or ("{ " .. table.concat(lines, ", ") .. " }")) .. trailing
    end
    return leading .. "{\n" .. (#lines > 0 and (table.concat(lines, "\n") .. "\n") or "") ..
        string.rep("    ", depth) .. "}" .. trailing
end
