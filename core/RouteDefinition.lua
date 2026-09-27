local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

-- Accept older numeric class filters, but expose and save APR's textual tokens.
-- Only visit condition fields: quest IDs, class specs and other numbers stay intact.
function AprRC:NormalizeRouteClasses(route)
    local tokens = {}
    for name, id in pairs(APR.Classes or {}) do tokens[id] = name:gsub("%s", ""):upper() end
    local function class(value)
        if type(value) ~= "table" then return tokens[value] or value end
        for index, entry in ipairs(value) do value[index] = tokens[entry] or entry end
        return value
    end
    local function conditions(value)
        if type(value) ~= "table" then return end
        if value.Class ~= nil then value.Class = class(value.Class) end
        if value.ClassNot ~= nil then value.ClassNot = class(value.ClassNot) end
        for _, key in ipairs({ "AnyOf", "AllOf" }) do
            if type(value[key]) == "table" then
                for _, group in ipairs(value[key]) do conditions(group) end
            end
        end
        conditions(value.Not)
    end
    local function steps(value)
        if type(value) == "table" then
            for _, step in ipairs(value) do conditions(step) end
        end
    end
    conditions(route.conditions)
    steps(route.steps)
    for _, group in ipairs(type(route.parallelSteps) == "table" and route.parallelSteps or {}) do
        if type(group) == "table" then
            conditions(group.conditions)
            steps(group.steps)
        end
    end
    for _, target in ipairs(type(route.nextRoute) == "table" and route.nextRoute or {}) do
        if type(target) == "table" then conditions(target.conditions) end
    end
    for _, target in pairs(type(route.prefab) == "table" and route.prefab or {}) do
        if type(target) == "table" then conditions(target.conditions) end
    end
    return route
end

-- The recorder name is a storage key; everything else belongs to APR's route definition.
function AprRC:BuildRouteDefinition(route)
    local result = {}
    for key, value in pairs(route) do
        if key ~= "name" then result[key] = self:CopyData(value) end
    end
    result.label = result.label or route.name:match("%d+%-(.*)") or route.name
    result.expansion = result.expansion or APR.EXPANSIONS.Custom
    result.category = result.category or APR.CATEGORIES.Miscellaneous
    result.mapID = result.mapID or tonumber(route.name:match("^(%d+)%-"))
    result.steps = result.steps or {}
    local function normalize(steps)
        for index, step in ipairs(steps) do
            self:NormalizeStepOptionFields(step)
            step._index = index
        end
    end
    normalize(result.steps)
    for _, group in ipairs(result.parallelSteps or {}) do normalize(group.steps or {}) end
    return self:NormalizeRouteClasses(result)
end

function AprRC:ReadRouteDefinition(text, name, previous, validationBaseline)
    local parsed, errorMessage = self:ParseLuaData(text)
    if type(parsed) ~= "table" then return nil, errorMessage or L["Expected a route table"] end
    local result
    if parsed.steps ~= nil then
        result = parsed
    else
        -- Accept old step-only exports without discarding existing metadata.
        result = self:CopyData(previous or {})
        result.steps = parsed
    end
    local function normalize(steps)
        if type(steps) ~= "table" then return end
        for _, step in ipairs(steps) do
            if type(step) == "table" then self:NormalizeStepOptionFields(step) end
        end
    end
    normalize(result.steps)
    if type(result.parallelSteps) == "table" then
        for _, group in ipairs(result.parallelSteps) do
            if type(group) == "table" then normalize(group.steps) end
        end
    end
    local baseline = validationBaseline or previous
    local valid, reason = self.options:ValidateValue("steps", result.steps, "steps", nil, baseline and baseline.steps)
    if not valid then return nil, reason end
    for key, value in pairs(result) do
        if key ~= "steps" and key ~= "name" then
            local definition = self.options.route[key]
            if definition then
                valid, reason = self.options:ValidateValue(definition.schema, value, key, nil, baseline and baseline[key])
                if not valid then return nil, reason end
            elseif not baseline or not self:DeepCompare(baseline[key], value) then
                return nil, L["Unsupported route field: "] .. tostring(key)
            end
            -- Preserve metadata from APR versions newer than the form schema.
            -- Unknown fields can round-trip unchanged, but cannot be introduced.
        end
    end
    result.name = name
    return self:NormalizeRouteClasses(result)
end
