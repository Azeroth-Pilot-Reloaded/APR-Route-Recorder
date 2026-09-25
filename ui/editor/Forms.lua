local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local R = AprRC.options
local Form = {}
UI.Form = Form

function UI.LabelWidget(parent, text, heading)
    local widget = AprRC:CreateWidget(heading and "Heading" or "Label")
    widget:SetFullWidth(true)
    widget:SetText(text)
    parent:AddChild(widget)
    return widget
end

function UI.Button(parent, text, callback, width)
    local widget = AprRC:CreateWidget("Button")
    widget:SetText(T(text))
    widget:SetWidth(width or 140)
    widget:SetCallback("OnClick", callback)
    parent:AddChild(widget)
    return widget
end

function UI.Group(parent, title)
    local group = AprRC:CreateWidget(title and "InlineGroup" or "SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    if title then group:SetTitle(title) end
    parent:AddChild(group)
    return group
end

function UI.Dropdown(parent, label, entries, value, callback)
    local widget = AprRC:CreateWidget("Dropdown")
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

-- Recognize finite lists (including scalar-or-list unions) without exposing
-- serialization choices such as numeric class IDs versus class tokens.
function Form:MultiChoices(schema, path)
    local entries, aliases, multiple = {}, {}, false
    local function collect(current)
        local valueKind = kind(current)
        if valueKind == "list" then multiple = true; return collect(current.entry) end
        if valueKind == "union" then
            for _, choice in ipairs(current.choices) do if not collect(choice) then return false end end
            return true
        end
        if valueKind ~= "enum" then return false end
        for key, candidate in pairs(current.values or APR[current.group] or {}) do
            entries[candidate] = type(key) == "string" and UI.Label(key) or tostring(candidate)
        end
        return true
    end
    if schema == "ids" and path:match("/equippedSlots$") then
        local slots = { "HEAD", "NECK", "SHOULDER", "BODY", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HAND",
            "FINGER", "FINGER", "TRINKET", "TRINKET", "CLOAK", "WEAPONMAINHAND", "WEAPONOFFHAND", "RANGED", "TABARD" }
        for index, slot in ipairs(slots) do
            entries[index] = index .. " - " .. (_G["INVTYPE_" .. slot] or slot)
        end
        return entries, aliases
    end
    if not collect(schema) or not multiple then return end
    if schema == R.schemas.class then
        for name, id in pairs(APR.Classes or {}) do
            local token = name:gsub("%s", ""):upper()
            if entries[token] and entries[id] then
                aliases[token], entries[token] = id, nil
                entries[id] = (LOCALIZED_CLASS_NAMES_MALE or {})[token] or UI.Label(name)
            end
        end
    end
    return entries, aliases
end

function Form:IsCompact(schema, path)
    local valueKind = kind(schema)
    return self:MultiChoices(schema, path) ~= nil or
        (valueKind ~= "object" and valueKind ~= "map" and valueKind ~= "list" and valueKind ~= "steps" and
            valueKind ~= "union" and valueKind ~= "step" and valueKind ~= "route" and
            valueKind ~= "conditions" and valueKind ~= "routeConditions" and valueKind ~= "level")
end

function Form:Position(parent, value, set, context, path, step)
    local group = step and UI.Group(parent, UI.Label("Coord")) or parent
    local body = UI.Group(group)
    body:SetLayout("APRColumns")
    local fields = { "x", "y" }
    if step or value.Zone ~= nil then fields[#fields + 1] = "Zone" end
    if not step and value.Range ~= nil then fields[#fields + 1] = "Range" end
    for _, key in ipairs(fields) do
        local column = UI.Group(body)
        if key == "Zone" then column:SetUserData("weight", 1.5) end
        local coord = step and value.Coord or value
        local current = (key == "x" or key == "y") and (coord or {})[key] or value[key]
        local fieldPath = path .. ((step and (key == "x" or key == "y")) and "/Coord/" or "/") .. key
        self:Render(column, key == "Zone" and "id" or key == "Range" and "positive" or "number", current,
            function(entry)
                if step and (key == "x" or key == "y") then
                    value.Coord = value.Coord or {}
                    value.Coord[key] = entry
                else value[key] = entry end
                set(value)
            end, context, fieldPath, key == "x" and "X" or key == "y" and "Y" or UI.Label(key))
        if key == "x" then body:SetUserData("alignControl", column.children[1]) end
    end
    if step then
        group:SetLayout("APRField")
        UI.IconButton(group, "trash", "Remove", function()
            value.Coord, value.Zone = nil, nil
            set(value); context.changed(); context.redraw()
        end)
    end
end

function Form:RemoveButton(group, body, callback)
    local actions = body.children[#body.children]
    if actions and actions:GetUserData("pickerActions") then
        group:SetUserData("compound", not body:GetUserData("singleInput"))
        UI.IconButton(actions, "trash", "Remove", callback)
        return
    end
    local controls, single = 0, false
    for _, child in ipairs(body.children) do
        if child.type ~= "Label" then
            controls = controls + 1
            single = child.type == "EditBox" or child.type == "Dropdown" or child.type == "CheckBox"
        end
    end
    group:SetUserData("compound", controls ~= 1 or not single)
    UI.IconButton(group, "trash", "Remove", callback)
end

function Form:Default(schema)
    if schema == "level" then schema = R.schemas.level end
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
    if valueKind == "id" or valueKind == "positive" or valueKind == "number" or valueKind == "nonnegative" or valueKind == "integer" then return 0 end
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
    if schema == "level" then schema = R.schemas.level end
    path = path or "root"
    local valueKind = kind(schema)
    local function changed(newValue, rebuild)
        value = newValue
        set(newValue)
        context.changed()
        if rebuild then context.redraw() end
    end
    local function validation()
        local message = UI.LabelWidget(parent, "")
        message:SetUserData("validation", true)
        local function update(entry)
            local valid, reason = R:ValidateValue(schema, entry, label)
            message:SetText(valid and "" or ("|cffff8b7c" .. tostring(reason) .. "|r"))
            parent:DoLayout()
        end
        if value ~= nil then update(value) end
        return function(entry) changed(entry); update(entry) end
    end
    local choices, aliases = self:MultiChoices(schema, path)
    if choices then
        local originalList = type(value) == "table"
        local selected = {}
        for _, entry in ipairs(originalList and value or { value }) do
            local canonical = aliases[entry] or entry
            selected[canonical] = entry
            if choices[canonical] == nil then choices[canonical] = tostring(entry) end
        end
        local widget = UI.Dropdown(parent, label, choices, nil, function() end)
        widget:SetMultiselect(true)
        widget:SetUserData("fieldPath", path)
        for entry in pairs(selected) do widget:SetItemValue(entry, true) end
        parent:SetLayout("APRInput")
        parent:SetUserData("singleInput", true)
        local changeWithValidation = validation()
        widget:SetCallback("OnValueChanged", function(_, _, entry, checked)
            if context.isCurrent and not context.isCurrent() then return end
            selected[entry] = checked and (selected[entry] or entry) or nil
            local result = {}
            for _, key in ipairs(keys(selected)) do result[#result + 1] = selected[key] end
            if not originalList and #result == 1 and R:ValidateValue(schema, result[1]) then result = result[1] end
            changeWithValidation(result)
        end)
    elseif valueKind == "union" then
        local selected = context.modes[path]
        if not selected then
            for index, choice in ipairs(schema.choices) do
                if R:ValidateValue(choice, value) then selected = index; break end
            end
        end
        selected = selected or 1
        local entries = {}
        for index, choice in ipairs(schema.choices) do
            local names = { text = "Text", strings = "List", list = "List", enum = "Choice", profile = "Level profile",
                positive = "Number", id = "Number", object = "Fields" }
            if choice == R.schemas.absoluteXP then names.object = "Level + XP" end
            entries[index] = T(names[kind(choice)] or "Value") .. " " .. index
        end
        UI.Dropdown(parent, label .. " — " .. T("Format"), entries, selected, function(index)
            context.modes[path] = index
            changed(self:Default(schema.choices[index]), true)
        end)
        self:Render(parent, schema.choices[selected], value, set, context, path .. "/variant", label)
    elseif valueKind == "bool" then
        local widget = AprRC:CreateWidget("CheckBox")
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
        if valueKind == "object" and schema.fields.x and schema.fields.y then
            self:Position(parent, value, set, context, path)
            return
        end
        local fields = self:Fields(schema, value)
        if valueKind == "route" then
            for key in pairs(context.hiddenFields or {}) do fields[key] = nil end
        end
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
            local position = valueKind == "step" and (value.Coord ~= nil or value.Zone ~= nil)
            if position and key == "Coord" then
                self:Position(parent, value, set, context, path, true)
            elseif not (position and key == "Zone") and (value[key] ~= nil or required[key]) then
                local fieldPath = path .. "/" .. key
                local group = UI.Group(parent, not self:IsCompact(fields[key], fieldPath) and UI.Label(key) or nil)
                group:SetLayout("APRField")
                local body = UI.Group(group)
                local fieldSchema = fields[key]
                self:Render(body, fieldSchema, value[key], function(entry) value[key] = entry; set(value) end,
                    context, path .. "/" .. key, UI.Label(key))
                if not required[key] then
                    self:RemoveButton(group, body, function() value[key] = nil; changed(value, true) end)
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
            UI.SearchSelect(parent, T("Add a field"), entries, nil, function(key)
                if not key then return end
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
            UI.IconButton(pager, "previous", "Previous", function() context.pages[path] = math.max(1, page - 1); context.redraw() end)
            UI.IconButton(pager, "next", "Next", function() context.pages[path] = math.min(pageCount, page + 1); context.redraw() end)
            UI.LabelWidget(pager, page .. " / " .. pageCount)
        end
        for position = (page - 1) * 10 + 1, math.min(page * 10, #entries) do
            local key = entries[position]
            local group = UI.Group(parent, (valueKind == "map" and "#" or T("Entry") .. " ") .. tostring(key))
            group:SetLayout("APRField")
            local body = UI.Group(group)
            if valueKind == "map" and kind(schema.key) ~= "enum" then
                local keyPath = schema.key == "id" and (path .. "/questID") or (path .. "/key")
                UI.Pickers:AddButton(body, schema.key, keyPath, context, function(newKey)
                    if newKey == key then return end
                    if value[newKey] ~= nil then context.error(T("This key already exists.")); return end
                    value[newKey], value[key] = value[key], nil
                    changed(value, true)
                end)
            end
            self:Render(body, valueKind == "steps" and "step" or schema.entry, value[key],
                function(entry) value[key] = entry; set(value) end, context, path .. "/" .. key, T("Value"))
            self:RemoveButton(group, body, function()
                if valueKind == "map" then value[key] = nil else table.remove(value, key) end
                changed(value, true)
            end)
        end
        if valueKind == "map" then
            local getKey
            if kind(schema.key) == "enum" then
                local selected, choices = nil, {}
                for name, entry in pairs(schema.key.values or APR[schema.key.group] or {}) do
                    choices[entry] = UI.Label(name)
                end
                UI.Dropdown(parent, T("Choice"), choices, nil, function(entry) selected = entry end)
                getKey = function() return selected end
            else
                local entryKey = AprRC:CreateWidget("EditBox")
                entryKey:SetFullWidth(true)
                entryKey:SetLabel(T(schema.key == "id" and "Quest ID" or "ID / objective (e.g. 12345-1)"))
                entryKey:DisableButton(true)
                parent:AddChild(entryKey)
                local keyPath = schema.key == "id" and (path .. "/questID") or (path .. "/key")
                UI.Pickers:AddButton(parent, schema.key, keyPath, context, function(selected)
                    entryKey:SetText(tostring(selected))
                end)
                getKey = function()
                    return schema.key == "id" and tonumber(entryKey:GetText()) or strtrim(entryKey:GetText())
                end
            end
            UI.Button(parent, "Add entry", function()
                local key = getKey()
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
        local widget = AprRC:CreateWidget(multiline and "MultiLineEditBox" or "EditBox")
        if not multiline and #parent.children == 0 then
            parent:SetLayout("APRInput")
            parent:SetUserData("singleInput", true)
        end
        widget:SetFullWidth(true)
        widget:DisableButton(true)
        if multiline then widget:SetNumLines(4) end
        local suffix = valueKind == "ids" or valueKind == "idOrIds"
        widget:SetLabel(valueKind == "strings" and T("One entry per line") or label)
        widget:SetUserData("fieldPath", path)
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
        UI.Pickers:AddButton(parent, schema, path, context, function(selected)
            if suffix or valueKind == "strings" then
                local entries = type(value) == "table" and AprRC:CopyData(value) or
                    (type(value) == "number" and { value } or {})
                if not tContains(entries, selected) then entries[#entries + 1] = selected end
                if valueKind == "idOrIds" and #entries == 1 then entries = entries[1] end
                changed(entries, true)
            else
                changed(selected, true)
            end
        end)
    end
end
