-- Shared command dispatch; option definitions live in commands/options/.
AprRC.options = { commands = {}, step = {}, route = {} }
local options = AprRC.options

function options:GetToolbarIcon(command, definition)
    if definition and definition.icon then return definition.icon end
    return "Interface\\Icons\\inv_misc_note_01"
end

function options:GetBarMeta(definition)
    return definition and definition.bar or nil
end

function options:Register(definition)
    local command = definition.command or definition.key:lower()
    definition.command = command
    if not definition.hidden then
        self.commands[command] = definition
    end
    self[definition.scope or "step"][definition.key] = definition
end

function options:CanEdit(route)
    if not AprRC.settings.profile.enableAddon or not AprRC.settings.profile.recordBarFrame.isRecording then
        return false, "Start recording a route first"
    end
    if route and route ~= AprRCData.CurrentRoute then return false, "The selected route changed; reopen the command" end
    return true
end

function options:Parse(definition, text)
    text = strtrim(text or "")
    local schema = definition.schema
    local kind = type(schema) == "table" and schema.kind or schema
    local value, err
    if kind == "text" or kind == "profile" or kind == "level" or kind == "enum" then
        if text:sub(1, 1) == '"' or text:sub(1, 1) == "'" or text:match("^APR%.") then
            value, err = AprRC:ParseLuaData(text)
        else
            value = (kind == "level" or kind == "enum") and tonumber(text) or text
        end
    elseif kind == "strings" and text:sub(1, 1) ~= "{" then
        value = {}
        for entry in text:gmatch("[^,]+") do value[#value + 1] = strtrim(entry) end
    elseif (kind == "ids" or kind == "idOrIds") and text:sub(1, 1) ~= "{" then
        value, err = AprRC:ParseLuaData("{" .. text .. "}")
    else
        value, err = AprRC:ParseLuaData(text)
        if value == nil and kind == "union" and text:sub(1, 1) ~= "{" then
            value = text
        end
    end
    if value == nil then return nil, err or "A value is required" end
    local valid, reason = self:ValidateValue(schema, value, definition.key)
    if not valid then return nil, reason end
    return value
end

function options:Apply(definition, value, route, target)
    local allowed, reason = self:CanEdit(route)
    if not allowed then return false, reason end
    local valid, why = self:ValidateValue(definition.schema, value, definition.key)
    if not valid then return false, why end
    if definition.scope == "route" then
        route[definition.key] = AprRC:CopyData(value)
    else
        local step = definition.newStep and {} or AprRC:CopyData(target or {})
        step[definition.key] = AprRC:CopyData(value)
        if definition.requires and not step[definition.requires] then
            return false, "Add " .. definition.requires .. " to this step first"
        end
        if definition.key == "DropQuest" and step.DroppableQuest.Qid ~= value then
            return false, "DropQuest must match DroppableQuest.Qid"
        end
        if definition.newStep and definition.coord then AprRC:SetStepCoord(step) end
        if definition.newStep or not target then
            AprRC:NewStep(step)
        else
            local found
            for _, candidate in ipairs(route.steps) do if candidate == target then found = true end end
            if not found then return false, "The edited step was removed; reopen the command" end
            for key in pairs(target) do target[key] = nil end
            for key, entry in pairs(step) do target[key] = entry end
        end
    end
    AprRC:UpdateRoute()
    if definition.key == "RouteCompleted" and value then
        AprRC.settings.profile.recordBarFrame.isRecording = false
        AprRC.record:StopRecord()
    end
    return true
end

function options:Dispatch(input)
    local command, argument = strtrim(input or ""):match("^(%S+)%s*(.-)$")
    if not command then return false end
    command = command:lower()
    if command == "route" then
        local field, rest = argument:match("^(%S+)%s*(.-)$")
        if not field then
            self:PrintHelp("route")
            return true
        end
        command, argument = "route " .. field:lower(), rest
    end
    local definition = self.commands[command]
    -- Numbered helper text fields use the same schema as the first line.
    if not definition then
        local prefix, suffix = command:match("^(extralinetext)(%d+)$")
        if not prefix then prefix, suffix = command:match("^(trigtext)(%d+)$") end
        if prefix and tonumber(suffix) >= 2 and self.commands[prefix] then
            definition = AprRC:CopyData(self.commands[prefix])
            definition.key = definition.key .. suffix
        end
    end
    if not definition or (definition.legacy and argument == "") then return false end
    local route = AprRCData.CurrentRoute
    local context = AprRC:CaptureRecordingContext()
    local allowed, reason = self:CanEdit(route)
    if not allowed then
        APR:PrintError(reason); return true
    end
    local target = route.steps[#route.steps]
    local function submit(text)
        if not AprRC:IsRecordingContext(context) then
            APR:PrintError("Recording changed; reopen the command")
            return false
        end
        local value, err = self:Parse(definition, text)
        if value == nil then
            APR:PrintError(err); return false
        end
        local ok, why = self:Apply(definition, value, route, target)
        if not ok then
            APR:PrintError(why); return false
        end
        print("|cff00bfff" .. definition.key .. "|r Added")
        return true
    end
    if argument ~= "" then
        submit(argument)
    elseif definition.schema == "bool" then
        submit("true")
    else
        self:ShowInput(definition, target, route, submit)
    end
    return true
end

function options:PrintHelp(scope)
    local keys = {}
    for command, definition in pairs(self.commands) do
        if not scope or definition.scope == scope then keys[#keys + 1] = command end
    end
    table.sort(keys)
    for _, command in ipairs(keys) do
        local definition = self.commands[command]
        print("|cffeda55f/aprrc " .. command .. "|r - " .. definition.key .. " (" ..
            (definition.scope == "route" and "route" or definition.newStep and "new step" or "current step") .. ")")
    end
end

function options:ShowInput(definition, target, route, submit)
    local gui = LibStub("AceGUI-3.0")
    local frame = gui:Create("Frame")
    frame:SetTitle(definition.key)
    frame:SetStatusText(definition.help or "Enter a value, then apply it to the recorded route.")
    frame:SetWidth(650)
    frame:SetHeight(360)
    frame:SetLayout("Flow")
    local edit = gui:Create("MultiLineEditBox")
    edit:SetLabel("Example: " .. (definition.example or ""))
    edit:SetFullWidth(true)
    edit:SetNumLines(10)
    edit:DisableButton(true)
    local current
    if definition.scope == "route" then
        current = route[definition.key]
    elseif target and not definition.newStep then
        current = target[definition.key]
    end
    edit:SetText(current ~= nil and AprRC:SerializeData(current) or definition.example or "")
    frame:AddChild(edit)
    local button = gui:Create("Button")
    button:SetText("Apply")
    button:SetCallback("OnClick", function() if submit(edit:GetText()) then gui:Release(frame) end end)
    frame:AddChild(button)
    frame:SetCallback("OnClose", function(widget) gui:Release(widget) end)
end

function options:AddToolbarCommands(list)
    local seen = {}
    for _, entry in ipairs(list) do seen[strlower(entry.command or "")] = true end
    for _, entry in ipairs(self:GetToolbarCatalog()) do
        if not seen[strlower(entry.command)] then
            list[#list + 1] = entry
            seen[strlower(entry.command)] = true
        end
    end
end

function options:GetToolbarEntry(definition)
    local bar = self:GetBarMeta(definition)
    local command = (bar and bar.command) or definition.command
    return {
        command = command,
        label = (bar and bar.label) or definition.key,
        texture = self:GetToolbarIcon(command, definition),
    }
end

function options:GetToolbarCatalog()
    local defs = {}
    for _, definition in pairs(self.commands) do defs[#defs + 1] = definition end
    table.sort(defs, function(a, b)
        local aBar = self:GetBarMeta(a)
        local bBar = self:GetBarMeta(b)
        local aOrder = (aBar and aBar.order) or 1000
        local bOrder = (bBar and bBar.order) or 1000
        if aOrder == bOrder then return a.command < b.command end
        return aOrder < bOrder
    end)

    local entries = {}
    local seen = {}
    for _, definition in ipairs(defs) do
        local entry = self:GetToolbarEntry(definition)
        local key = strlower(entry.command)
        if not seen[key] then
            entries[#entries + 1] = entry
            seen[key] = true
        end
    end
    return entries
end

function options:GetDefaultToolbarCommands()
    local defaults = {}
    for _, definition in pairs(self.commands) do
        local bar = self:GetBarMeta(definition)
        if bar and bar.isDefault then defaults[#defaults + 1] = definition end
    end
    table.sort(defaults, function(a, b)
        local aBar = self:GetBarMeta(a)
        local bBar = self:GetBarMeta(b)
        local aOrder = (aBar and aBar.order) or 1000
        local bOrder = (bBar and bBar.order) or 1000
        if aOrder == bOrder then return a.command < b.command end
        return aOrder < bOrder
    end)

    local entries = {}
    for _, definition in ipairs(defaults) do
        entries[#entries + 1] = self:GetToolbarEntry(definition)
    end
    return entries
end

function options:NormalizeToolbarCommands(list)
    local normalized = {}
    local catalog = self:GetToolbarCatalog()
    local byCommand = {}
    for _, entry in ipairs(catalog) do
        byCommand[strlower(entry.command)] = entry
    end

    for _, entry in ipairs(list or {}) do
        local key = strlower(entry.command or "")
        local known = byCommand[key]
        if known then
            normalized[#normalized + 1] = {
                command = known.command,
                label = known.label,
                texture = known.texture,
            }
        elseif entry.command then
            normalized[#normalized + 1] = {
                command = entry.command,
                label = entry.label or entry.command,
                texture = entry.texture or self:GetToolbarIcon(entry.command),
            }
        end
    end
    return normalized
end
