local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local R = AprRC.options
local Form = {}
UI.Form = Form

function UI.LabelWidget(parent, text, heading)
    local widget = GUI:Create(heading and "Heading" or "Label")
    widget:SetFullWidth(true)
    widget:SetText(text)
    parent:AddChild(widget)
    return widget
end

function UI.Button(parent, text, callback, width)
    local widget = GUI:Create("Button")
    widget:SetText(T(text))
    widget:SetWidth(width or 140)
    widget:SetCallback("OnClick", callback)
    parent:AddChild(widget)
    return widget
end

function UI.Group(parent, title)
    local group = GUI:Create(title and "InlineGroup" or "SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    if title then group:SetTitle(title) end
    parent:AddChild(group)
    return group
end

function UI.Dropdown(parent, label, entries, value, callback)
    local widget = GUI:Create("Dropdown")
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    local order = {}
    for key in pairs(entries) do order[#order + 1] = key end
    table.sort(order, function(a, b)
        if type(a) == "number" and type(b) == "number" then return a < b end
        return tostring(entries[a]) < tostring(entries[b])
    end)
    widget:SetList(entries, order)
    widget:SetValue(value)
    widget:SetCallback("OnValueChanged", function(_, _, selected) callback(selected) end)
    parent:AddChild(widget)
    return widget
end

local function kind(schema) return type(schema) == "table" and schema.kind or schema end
local function keys(data)
    local result = {}
    for key in pairs(data or {}) do result[#result + 1] = key end
    table.sort(result, function(a, b)
        if type(a) == "number" and type(b) == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    return result
end

function Form:Default(schema)
    local valueKind = kind(schema)
    if valueKind == "bool" then return true end
    if valueKind == "union" then return self:Default(schema.choices[1]) end
    if valueKind == "enum" then
        local values = schema.values or APR[schema.group] or {}
        local first = keys(values)[1]
        return first and values[first]
    end
    if valueKind == "object" then
        local result = {}
        for _, key in ipairs(schema.required or {}) do result[key] = self:Default(schema.fields[key]) end
        return result
    end
    if valueKind == "text" or valueKind == "profile" or valueKind == "objectiveKey" then return "" end
    if valueKind == "id" or valueKind == "positive" or valueKind == "number" or valueKind == "nonnegative" or valueKind == "level" then return 0 end
    return {}
end

local routeConditions = { InterfaceVersion = true, DontHaveSpell = true, IsQuestReadyForTurnIn = true,
    HasAchievement = true, DontHaveAchievement = true, Faction = true, Race = true, Class = true,
    ClassNot = true, Event = true, AlliedRace = true, IsQuestCompleted = true, IsQuestUncompleted = true,
    Level = true, MinLevel = true, MaxLevel = true, BeLvl = true, ClassSpec = true, Zones = true }

function Form:Fields(schema, value)
    local valueKind = kind(schema)
    if valueKind == "object" then return schema.fields end
    local fields = {}
    local definitions = valueKind == "route" and R.route or R.step
    for key, definition in pairs(definitions) do
        if valueKind == "route" or valueKind == "step" or
            (valueKind == "conditions" and definition.condition) or
            (valueKind == "routeConditions" and routeConditions[key]) then
            fields[key] = definition.schema
            if valueKind == "routeConditions" then
                if key == "Level" or key == "MinLevel" or key == "MaxLevel" or key == "BeLvl" then fields[key] = "positive" end
                if key == "Race" or key == "Class" or key == "ClassNot" then
                    fields[key] = { kind = "enum", group = key == "Race" and "RACES" or "Classes" }
                end
            end
        end
    end
    if valueKind == "step" then
        for _, prefix in ipairs({ "ExtraLineText", "TrigText" }) do
            local index = 2
            while value[prefix .. index] ~= nil do index = index + 1 end
            fields[prefix .. index] = "text"
        end
        for key in pairs(value) do
            if type(key) == "string" and (key:match("^ExtraLineText%d+$") or key:match("^TrigText%d+$")) then
                fields[key] = "text"
            end
        end
    end
    return fields
end

-- A schema-driven form edits values, never Lua source. Structural changes rebuild
-- the form; typing only updates the detached draft and leaves keyboard focus alone.
function Form:Render(parent, schema, value, set, context, path, label)
    path = path or "root"
    local valueKind = kind(schema)
    local function changed(newValue, rebuild)
        set(newValue)
        context.changed()
        if rebuild then context.redraw() end
    end
    local function validation()
        local message = UI.LabelWidget(parent, "")
        local function update(entry)
            local valid, reason = R:ValidateValue(schema, entry, label)
            message:SetText(valid and "" or ("|cffff8b7c" .. tostring(reason) .. "|r"))
        end
        update(value)
        return function(entry) changed(entry); update(entry) end
    end
    if valueKind == "union" then
        local selected = context.modes[path]
        if not selected then
            for index, choice in ipairs(schema.choices) do
                if R:ValidateValue(choice, value) then selected = index; break end
            end
        end
        selected = selected or 1
        local entries = {}
        for index, choice in ipairs(schema.choices) do
            local names = { text = "Text", strings = "List", list = "List", enum = "Choice", profile = "Choice" }
            entries[index] = T(names[kind(choice)] or "Value") .. " " .. index
        end
        UI.Dropdown(parent, label .. " — " .. T("Format"), entries, selected, function(index)
            context.modes[path] = index
            changed(self:Default(schema.choices[index]), true)
        end)
        self:Render(parent, schema.choices[selected], value, set, context, path .. "/variant", label)
    elseif valueKind == "bool" then
        local widget = GUI:Create("CheckBox")
        widget:SetFullWidth(true)
        widget:SetLabel(label)
        widget:SetValue(value == true)
        widget:SetCallback("OnValueChanged", function(_, _, checked) changed(checked) end)
        parent:AddChild(widget)
    elseif valueKind == "enum" or valueKind == "profile" then
        local values = valueKind == "profile" and APR.LevelRequirementProfiles or schema.values or APR[schema.group] or {}
        local entries, actual, selected = {}, {}, nil
        for index, key in ipairs(keys(values)) do
            local candidate = valueKind == "profile" and key or values[key]
            actual[index] = candidate
            entries[index] = type(key) == "string" and UI.Label(key) or tostring(candidate)
            if candidate == value then selected = index end
        end
        UI.Dropdown(parent, label, entries, selected, function(index) changed(actual[index]) end)
    elseif valueKind == "object" or valueKind == "step" or valueKind == "route" or valueKind == "conditions" or valueKind == "routeConditions" then
        value = type(value) == "table" and value or {}
        local fields = self:Fields(schema, value)
        local required = {}
        if valueKind == "object" then
            for _, key in ipairs(schema.required or {}) do required[key] = true end
        end
        local ordered = keys(fields)
        local priority = { label = 1, expansion = 2, category = 3, mapID = 4, Coord = 20, Zone = 21, Range = 22, ExtraLineText = 23 }
        local function rank(key)
            local definition = R.step[key]
            if valueKind == "step" and definition and definition.newStep then return 10 end
            if definition and definition.condition then return 40 end
            return priority[key] or 30
        end
        table.sort(ordered, function(a, b)
            if rank(a) == rank(b) then return tostring(a) < tostring(b) end
            return rank(a) < rank(b)
        end)
        for _, key in ipairs(ordered) do
            if value[key] ~= nil or required[key] then
                local group = UI.Group(parent, UI.Label(key))
                local fieldSchema = fields[key]
                self:Render(group, fieldSchema, value[key], function(entry) value[key] = entry; set(value) end,
                    context, path .. "/" .. key, UI.Label(key))
                if not required[key] then
                    UI.Button(group, "Remove", function() value[key] = nil; changed(value, true) end, 100)
                end
            end
        end
        local entries = {}
        for key in pairs(fields) do
            if value[key] == nil and not required[key] then
                local definition = R.step[key]
                entries[key] = (definition and definition.condition and (T("Conditions") .. " · ") or "") .. UI.Label(key)
            end
        end
        if next(entries) then
            UI.Dropdown(parent, T("Add a field"), entries, nil, function(key)
                value[key] = self:Default(fields[key])
                changed(value, true)
            end)
        end
    elseif valueKind == "map" or valueKind == "list" or valueKind == "steps" then
        value = type(value) == "table" and value or {}
        local entries = keys(value)
        local page = context.pages[path] or 1
        local pageCount = math.max(1, math.ceil(#entries / 10))
        page = math.min(page, pageCount)
        if pageCount > 1 then
            local pager = UI.Group(parent)
            UI.Button(pager, "Previous", function() context.pages[path] = math.max(1, page - 1); context.redraw() end, 100)
            UI.Button(pager, "Next", function() context.pages[path] = math.min(pageCount, page + 1); context.redraw() end, 100)
            UI.LabelWidget(pager, page .. " / " .. pageCount)
        end
        for position = (page - 1) * 10 + 1, math.min(page * 10, #entries) do
            local key = entries[position]
            local group = UI.Group(parent, (valueKind == "map" and "#" or T("Entry") .. " ") .. tostring(key))
            self:Render(group, valueKind == "steps" and "step" or schema.entry, value[key],
                function(entry) value[key] = entry; set(value) end, context, path .. "/" .. key, T("Value"))
            UI.Button(group, "Remove", function()
                if valueKind == "map" then value[key] = nil else table.remove(value, key) end
                changed(value, true)
            end, 100)
        end
        if valueKind == "map" then
            local entryKey = GUI:Create("EditBox")
            entryKey:SetFullWidth(true)
            entryKey:SetLabel(T(schema.key == "id" and "Quest ID" or "ID / objective (e.g. 12345-1)"))
            entryKey:DisableButton(true)
            parent:AddChild(entryKey)
            UI.Button(parent, "Add entry", function()
                local key = schema.key == "id" and tonumber(entryKey:GetText()) or strtrim(entryKey:GetText())
                local valid, reason = R:ValidateValue(schema.key, key)
                if not valid then context.error(reason); return end
                if value[key] ~= nil then context.error(T("This key already exists.")); return end
                value[key] = self:Default(schema.entry)
                changed(value, true)
            end)
        else
            UI.Button(parent, "Add entry", function()
                value[#value + 1] = self:Default(valueKind == "steps" and "step" or schema.entry)
                context.pages[path] = math.ceil(#value / 10)
                changed(value, true)
            end)
        end
    else
        local multiline = valueKind == "strings" or (valueKind == "text" and
            (path:find("Note", 1, true) or path:find("ExtraLineText", 1, true) or tostring(value):find("\n", 1, true)))
        local widget = GUI:Create(multiline and "MultiLineEditBox" or "EditBox")
        widget:SetFullWidth(true)
        widget:DisableButton(true)
        if multiline then widget:SetNumLines(4) end
        local suffix = valueKind == "ids" or valueKind == "idOrIds"
        widget:SetLabel(suffix and T("IDs separated by commas") or valueKind == "strings" and T("One entry per line") or label)
        local text = value
        if type(value) == "table" then
            local parts = {}
            for _, entry in ipairs(value) do parts[#parts + 1] = tostring(entry) end
            text = table.concat(parts, valueKind == "strings" and "\n" or ", ")
        end
        widget:SetText(text == nil and "" or tostring(text))
        parent:AddChild(widget)
        local changeWithValidation = validation()
        widget:SetCallback("OnTextChanged", function(_, _, input)
            local result = input
            if suffix or valueKind == "strings" then
                result = {}
                for entry in input:gmatch(valueKind == "strings" and "[^\r\n]+" or "[^,]+") do
                    result[#result + 1] = suffix and (tonumber(strtrim(entry)) or strtrim(entry)) or entry
                end
                if valueKind == "idOrIds" and #result == 1 then result = result[1] end
            elseif valueKind ~= "text" and valueKind ~= "objectiveKey" then
                result = tonumber(input) or input
            end
            changeWithValidation(result)
        end)
    end
end
