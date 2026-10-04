local Code, R = AprRC.luaCode, AprRC.options
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local Language = {}
AprRC.luaLanguage = Language

local function word(byte) return byte and (byte >= 128 or string.char(byte):match("[%w_]")) end
local lower = { ["À"] = "à", ["Â"] = "â", ["Ä"] = "ä", ["É"] = "é", ["È"] = "è", ["Ê"] = "ê", ["Ë"] = "ë",
    ["Î"] = "î", ["Ï"] = "ï", ["Ô"] = "ô", ["Ö"] = "ö", ["Ù"] = "ù", ["Û"] = "û", ["Ü"] = "ü", ["Ç"] = "ç", ["Œ"] = "œ" }
local function foldCase(text)
    -- Native Lua locales may lowercase UTF-8 lead bytes as Latin-1. Transform
    -- ASCII explicitly, then map complete characters without changing offsets.
    return text:gsub("[A-Z]", function(char) return string.char(char:byte() + 32) end):gsub("[\194-\244][\128-\191]+", lower)
end
local separators = { ["«"] = true, ["»"] = true, ["“"] = true, ["”"] = true, ["‘"] = true, ["’"] = true,
    ["…"] = true, ["—"] = true, ["–"] = true, ["·"] = true, ["\194\160"] = true }
local function wordAt(text, position)
    local byte = text:byte(position)
    if not byte or byte < 128 then return word(byte) end
    local first = position
    while first > 1 and text:byte(first) >= 128 and text:byte(first) < 192 do first = first - 1 end
    local last = first
    while last < #text and text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last = last + 1 end
    return not separators[text:sub(first, last)]
end
function Language:Search(text, query, matchCase, wholeWord)
    local results, start = {}, 1
    if query == "" then return results end
    local haystack, needle = text, query
    if not matchCase then haystack, needle = foldCase(text), foldCase(query) end
    while true do
        local first, last = haystack:find(needle, start, true)
        if not first then return results end
        if not wholeWord or (not wordAt(text, first - 1) and not wordAt(text, last + 1)) then
            results[#results + 1] = { start = first - 1, finish = last }
        end
        start = last + 1
    end
end

function Language:Replace(text, ranges, replacement, cursor)
    local parts, start, mapped = {}, 0, cursor or 0
    for _, range in ipairs(ranges) do
        parts[#parts + 1] = text:sub(start + 1, range.start)
        parts[#parts + 1] = replacement
        if cursor and cursor >= range.finish then mapped = mapped + #replacement - (range.finish - range.start)
        elseif cursor and cursor > range.start then mapped = mapped + #replacement - (cursor - range.start) end
        start = range.finish
    end
    parts[#parts + 1] = text:sub(start + 1)
    return table.concat(parts), mapped
end

function Language:Location(text, position, lines)
    lines = lines or Code:Lines(text)
    position = math.max(0, math.min(#text, position or 0))
    local line = Code:LineAt(lines, position)
    local prefix = text:sub(lines[line].start + 1, position)
    return { position = position + 1, line = line, column = #prefix:gsub("[\128-\191]", "") + 1 }
end

-- The parser returns table/field byte ranges without modifying the source.
-- Schema diagnostics use the same validation and saved baseline as Save.
function Language:Analyze(text, baseline)
    local parsed, reason, comments, map = AprRC:ParseLuaData(text, true, true)
    if parsed == nil then return { { message = reason, location = map } }, {}, nil end
    local errors, outline, lines, seenErrors = {}, {}, Code:Lines(text), {}
    local function add(message, value, field)
        if #errors >= 50 then return end
        local node = map[value]
        local range = node and (node.fields[field] or node)
        -- Validation paths locate nested fields, including numeric step keys.
        local path = message:match("^([^:]+):")
        local current = value
        if path then
            for key in path:gmatch("[^.]+") do
                local candidate = type(current) == "table" and current[tonumber(key) or key]
                if candidate ~= nil then
                    local child = map[current]
                    range = child and (child.fields[tonumber(key) or key] or child) or range
                    current = candidate
                end
            end
        end
        local location = self:Location(text, range and range.start or 0, lines)
        local identity = location.position .. ":" .. message
        if not seenErrors[identity] then
            seenErrors[identity] = true
            errors[#errors + 1] = { message = message, location = location }
        end
    end
    local function validate(schema, value, path, previous, owner, key)
        local ok, why = R:ValidateValue(schema, value, path, nil, previous)
        if not ok then add(why, owner or value, key) end
    end
    local function steps(values, previous, group)
        if type(values) ~= "table" then validate("steps", values, "steps", previous, parsed, "steps"); return end
        for index, step in ipairs(values) do
            local before = #errors
            if type(step) == "table" then
                AprRC:NormalizeStepOptionFields(step)
                local old = previous and previous[index]
                for key, entry in pairs(step) do
                    local definition = R.step[key]
                    if not definition and type(key) == "string" then
                        definition = R.step[key:match("^(ExtraLineText)%d+$") or key:match("^(TrigText)%d+$")]
                    end
                    local schema = definition and definition.schema or key == "_index" and "id" or key == "_comment" and "text"
                    if schema then validate(schema, entry, tostring(key), old and old[key], step, key)
                    elseif not old or not AprRC:DeepCompare(old[key], entry) then
                        add(tostring(key) .. ": " .. L["unsupported field "] .. tostring(key), step, key)
                    end
                end
                if #errors == before then validate("step", step, "", old, step) end
                if step.RouteCompleted and index ~= #values then add(L["RouteCompleted must be last"], step, "RouteCompleted") end
                local node = map[step]
                if node then
                    local title = step.Note or step.ExtraLineText
                    if not title then
                        for _, key in ipairs({ "PickUp", "Done", "Qpart", "Waypoint", "Use", "LearnSkill" }) do
                            if step[key] then title = key; break end
                        end
                    end
                    outline[#outline + 1] = { start = node.start, finish = node.finish, group = group, index = index,
                        line = Code:LineAt(lines, node.start), title = tostring(title or ""):gsub("[\r\n]", " "):sub(1, 70) }
                end
            else validate("step", step, "", previous and previous[index], values, index)
            end
        end
        -- Check holes and non-list keys without repeating each step's schema.
        local size = 0
        for key in pairs(values) do
            size = size + 1
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                add(L["expected consecutive list indices"], values); return
            end
        end
        if size ~= #values then add(L["list indices must be consecutive"], values) end
    end
    if type(parsed) ~= "table" then
        add(L["Expected a route table"], parsed); return errors, outline, parsed
    end
    local rootSteps = parsed
    if parsed.steps ~= nil then rootSteps = parsed.steps end
    steps(rootSteps, baseline and baseline.steps)
    if parsed.steps ~= nil then
        for key, value in pairs(parsed) do
            if key ~= "steps" and key ~= "name" then
                local definition = R.route[key]
                if definition then
                    validate(definition.schema, value, tostring(key), baseline and baseline[key], parsed, key)
                elseif not baseline or not AprRC:DeepCompare(baseline[key], value) then
                    add(L["Unsupported route field: "] .. tostring(key), parsed, key)
                end
            end
        end
        for group, parallel in ipairs(type(parsed.parallelSteps) == "table" and parsed.parallelSteps or {}) do
            if type(parallel) == "table" then steps(parallel.steps or {}, baseline and baseline.parallelSteps and
                baseline.parallelSteps[group] and baseline.parallelSteps[group].steps, group) end
        end
    end
    table.sort(errors, function(a, b) return a.location.position < b.location.position end)
    return errors, outline, parsed, map, comments
end

-- Change whitespace only. Strings, comments, key order and APR constants keep
-- their exact bytes, including the interiors of long strings/comments.
function Language:Format(text, cursor)
    local parsed, reason, _, location = AprRC:ParseLuaData(text)
    if parsed == nil then return nil, reason, location end
    local original, originalCursor = text, cursor or 0
    -- Expand route/step containers and long nested tables. The old whitespace
    -- pass left a whole one-line route on one line, making Format look inert.
    local scanned, stack, closing, owner, previous, beforePrevious = Code:Scan(text), {}, {}, {}
    for index, token in ipairs(scanned) do
        if token.kind then
            local value = text:sub(token.start + 1, token.finish)
            if token.kind == "punctuation" and value == "{" then
                local parent = stack[#stack]
                local key = previous == "=" and beforePrevious or nil
                local entry = { first = index, token = token, parent = parent, key = key }
                if parent then parent.nested = true end
                stack[#stack + 1] = entry
            elseif token.kind == "punctuation" and value == "}" then
                local entry = table.remove(stack)
                if entry then
                    closing[index] = entry
                    entry.last = index
                    local content = text:sub(entry.token.finish + 1, token.start)
                    entry.expand = content:find("%S") and (not entry.parent or entry.nested or content:find("\n", 1, true) or
                        #content > 90 or entry.key == "steps" or entry.key == "parallelSteps" or
                        entry.parent.key == "steps" or entry.parent.key == "parallelSteps")
                end
            end
            owner[index] = stack[#stack]
            beforePrevious, previous = previous, value
        end
    end
    local changes, last = {}, nil
    for index, token in ipairs(scanned) do
        if token.kind then
            if last then
                local left, right = text:sub(last.token.start + 1, last.token.finish), text:sub(token.start + 1, token.finish)
                local newline = left == "{" and last.owner and last.owner.expand or
                    (left == "," or left == ";") and last.owner and last.owner.expand and token.kind ~= "comment"
                if right == "}" then
                    if closing[index] and closing[index].expand then newline = true end
                end
                local gap = text:sub(last.token.finish + 1, token.start)
                if newline and not gap:find("\n", 1, true) then
                    changes[#changes + 1] = { start = last.token.finish, finish = token.start }
                end
            end
            last = { token = token, owner = owner[index] }
        end
    end
    if #changes > 0 then text, cursor = self:Replace(text, changes, "\n", cursor or 0) end
    local tokens, lines = Code:Scan(text), Code:Lines(text)
    local byLine, protected, protectedStart = {}, {}, {}
    for _, token in ipairs(tokens) do
        if token.kind then
            local last = Code:LineAt(lines, math.max(token.start, token.finish - 1))
            if last > token.line then
                for line = token.line, last do
                    protected[line] = true
                    if line > token.line then protectedStart[line] = false end
                end
                if protectedStart[token.line] ~= false then protectedStart[token.line] = true end
            else
                byLine[token.line] = byLine[token.line] or {}
                byLine[token.line][#byLine[token.line] + 1] = token
            end
        end
    end
    local result, depth = {}, 0
    local caretLine = Code:LineAt(lines, cursor or 0)
    local mapped = 0
    for index, line in ipairs(lines) do
        local entries, parts, previous = byLine[index] or {}, {}, nil
        for _, token in ipairs(entries) do
            local value = text:sub(token.start + 1, token.finish)
            if previous then
                local left = text:sub(previous.start + 1, previous.finish)
                local gap = text:sub(previous.finish + 1, token.start)
                local space = left == "=" or value == "=" or left == "," or left == ";" or
                    (left == "{" and value ~= "}") or (value == "}" and left ~= "{") or token.kind == "comment"
                if space or gap:find("%s") then parts[#parts + 1] = " " end
            end
            parts[#parts + 1] = value
            previous = token
        end
        local body = table.concat(parts)
        local indent = math.max(0, depth - (body:sub(1, 1) == "}" and 1 or 0))
        local formatted = protected[index] and (protectedStart[index] and
            (string.rep("    ", indent) .. line.text:gsub("^%s*", "")) or line.text) or
            (body == "" and "" or string.rep("    ", indent) .. body)
        if not protected[index] and line.text:sub(-1) == "\r" then formatted = formatted .. "\r" end
        if index == caretLine then
            local oldIndent = #(line.text:match("^%s*") or "")
            local newIndent = #(formatted:match("^%s*") or "")
            mapped = mapped + math.min(#formatted, math.max(newIndent, (cursor or 0) - line.start - oldIndent + newIndent))
        elseif index < caretLine then mapped = mapped + #formatted + 1 end
        result[#result + 1] = formatted
        for _, token in ipairs(entries) do
            if token.kind == "punctuation" then
                local value = text:sub(token.start + 1, token.finish)
                if value == "{" then depth = depth + 1 elseif value == "}" then depth = math.max(0, depth - 1) end
            end
        end
    end
    local formatted = table.concat(result, "\n")
    local verified = AprRC:ParseLuaData(formatted)
    if not AprRC:DeepCompare(parsed, verified) then return nil, L["Unable to format Lua safely."], self:Location(original, originalCursor) end
    return formatted, mapped
end

local questKeys = { PickUp = true, PickUpDB = true, Done = true, DoneDB = true, questID = true, Qid = true,
    DropQuest = true, LeaveQuest = true, Waypoint = true, WaypointDB = true, QpartDB = true, ExitTutorial = true }
local spellKeys = { spellID = true, spellId = true, spellIDs = true, itemSpellID = true, HasSpell = true,
    DontHaveSpell = true, SpellTrigger = true, LearnProfession = true }
local itemKeys = { itemID = true, itemIDs = true, items = true }
local mapKeys = { Qpart = true, QpartPart = true, Fillers = true, Button = true, SpellButton = true }
local function public(value)
    if issecretvalue and issecretvalue(value) then return end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return end
    return value
end

function Language:Context(text, cursor, tokens)
    local first, last = cursor, cursor
    while first > 0 and (word(text:byte(first)) or text:sub(first, first) == ".") do first = first - 1 end
    while last < #text and (word(text:byte(last + 1)) or text:sub(last + 1, last + 1) == ".") do last = last + 1 end
    local stack, frame, identifier = {}, {}, nil
    for _, token in ipairs(tokens or Code:Scan(text)) do
        if cursor > token.start and ((token.kind == "string" and cursor <= token.finish) or
            (token.kind == "comment" and cursor <= token.finish)) then return end
        if token.start >= first then break end
        if token.kind then
            local value = text:sub(token.start + 1, math.min(first, token.finish))
            if value == "{" then
                stack[#stack + 1] = frame; frame = { inherited = frame.field or frame.inherited }
            elseif value == "}" then frame = table.remove(stack) or {}
            elseif value == "=" then
                frame.field = identifier or (frame.inherited == "Button" and "itemID" or
                    frame.inherited == "SpellButton" and "spellID" or frame.field)
            elseif value == "," or value == ";" then frame.field, identifier = nil, nil
            elseif value == "[" then frame.inKey = true
            elseif value == "]" then frame.inKey, identifier = false, nil
            elseif token.kind == "identifier" then identifier = value end
        end
    end
    local key = frame.field or frame.inherited
    local kind = key and (questKeys[key] or key:match("^Is.*Quest")) and "quest" or
        spellKeys[key] and "spell" or itemKeys[key] and "item" or nil
    if frame.inKey and mapKeys[key] then kind = "quest" end
    if mapKeys[key] and not frame.inKey then kind = nil end
    return { first = first, last = last, cursor = cursor, prefix = text:sub(first + 1, cursor), key = key,
        kind = kind, field = frame.field == nil and (not key or key == "steps" or key == "parallelSteps" or
            key == "conditions" or not mapKeys[key] and not kind) }
end

function Language:Candidates(context, route)
    if not context then return {} end
    local values, seen, prefix = {}, {}, foldCase(context.prefix)
    local function add(insert, label, kind)
        insert, label = public(insert), public(label)
        if type(insert) ~= "string" or seen[insert] then return end
        label = type(label) == "string" and label or insert
        local match = foldCase(insert .. " " .. label)
        if prefix ~= "" and not match:find(prefix, 1, true) then return end
        seen[insert] = true
        values[#values + 1] = { insert = insert, label = label, kind = kind,
            rank = foldCase(insert):sub(1, #prefix) == prefix and 0 or 1 }
    end
    local function id(kind, value, name)
        value = public(value)
        if type(value) ~= "number" or value <= 0 or value % 1 ~= 0 then return end
        if not name then
            if kind == "quest" and C_QuestLog and C_QuestLog.GetTitleForQuestID then name = public(C_QuestLog.GetTitleForQuestID(value))
            elseif kind == "spell" and C_Spell and C_Spell.GetSpellInfo then
                local info = public(C_Spell.GetSpellInfo(value)); name = info and public(info.name)
            elseif kind == "item" and C_Item and C_Item.GetItemInfo then name = public(C_Item.GetItemInfo(value)) end
        end
        add(tostring(value), tostring(value) .. " · " .. (name or tostring(value)), kind)
    end
    if context.prefix:match("^APR%.") then
        for _, group in ipairs({ "EXPANSIONS", "GAME_VERSIONS", "CATEGORIES", "PREFAB_TYPES", "Classes", "RACES",
            "Specs", "REPUTATION_TYPE", "REPUTATION_STANDING", "EVENTS" }) do
            for key in pairs(APR[group] or {}) do
                if type(key) == "string" and key:match("^[%a_][%w_]*$") then add("APR." .. group .. "." .. key) end
            end
        end
    elseif context.kind then
        local kind = context.kind
        local function collect(value)
            if type(value) ~= "table" then return end
            for key, entry in pairs(value) do
                local category = questKeys[key] or type(key) == "string" and key:match("^Is.*Quest")
                category = category and "quest" or spellKeys[key] and "spell" or itemKeys[key] and "item"
                if category == kind then
                    if type(entry) == "number" then id(kind, entry)
                    elseif type(entry) == "table" then for _, number in ipairs(entry) do id(kind, number) end end
                end
                if kind == "quest" and mapKeys[key] and type(entry) == "table" then
                    for number in pairs(entry) do id(kind, tonumber(tostring(number):match("^%d+"))) end
                elseif (kind == "item" and key == "Button" or kind == "spell" and key == "SpellButton") and type(entry) == "table" then
                    for _, number in pairs(entry) do id(kind, number) end
                end
                collect(entry)
            end
        end
        collect(route)
        if kind == "quest" and C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
            for index = 1, public(C_QuestLog.GetNumQuestLogEntries()) or 0 do
                local info = public(C_QuestLog.GetInfo(index))
                if info and not public(info.isHeader) then id(kind, public(info.questID), public(info.title)) end
            end
        elseif kind == "item" and C_Container then
            for bag = 0, 5 do
                for slot = 1, public(C_Container.GetContainerNumSlots(bag)) or 0 do
                    id(kind, public(C_Container.GetContainerItemID(bag, slot)))
                end
            end
        elseif kind == "spell" and C_SpellBook and Enum and Enum.SpellBookSpellBank then
            for index = 1, public(C_SpellBook.GetNumSpellBookSkillLines()) or 0 do
                local info = public(C_SpellBook.GetSpellBookSkillLineInfo(index))
                for slot = (info and public(info.itemIndexOffset) or 0) + 1,
                    (info and public(info.itemIndexOffset) or 0) + (info and public(info.numSpellBookItems) or 0) do
                    id(kind, public(select(2, C_SpellBook.GetSpellBookItemType(slot, Enum.SpellBookSpellBank.Player))),
                        public(C_SpellBook.GetSpellBookItemName(slot, Enum.SpellBookSpellBank.Player)))
                end
            end
            for _, number in ipairs(AprRC.professionSpellIDs or {}) do id(kind, number) end
        end
        if kind == "item" or kind == "spell" then
            for _, entry in ipairs(AprRC.recentChoices:Get(kind)) do id(kind, entry.id) end
        end
        if tonumber(context.prefix) then id(kind, tonumber(context.prefix)) end
    elseif context.field then
        for _, scope in ipairs({ R.step, R.route }) do for key in pairs(scope) do add(key, key, "field") end end
        local visited = {}
        local function schema(value)
            if type(value) ~= "table" or visited[value] then return end
            visited[value] = true
            for key, child in pairs(value.fields or {}) do add(key, key, "field"); schema(child) end
            schema(value.entry)
            for _, child in ipairs(value.choices or {}) do schema(child) end
        end
        for _, definition in pairs(R.step) do schema(definition.schema) end
        for _, definition in pairs(R.route) do schema(definition.schema) end
        for _, key in ipairs({ "steps", "parallelSteps", "conditions", "_index" }) do add(key, key, "field") end
    end
    table.sort(values, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return foldCase(a.label) < foldCase(b.label)
    end)
    while #values > 8 do table.remove(values) end
    return values
end
