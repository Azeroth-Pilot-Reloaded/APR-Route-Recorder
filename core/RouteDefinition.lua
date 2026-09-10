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
    return result
end

function AprRC:ReadRouteDefinition(text, name, previous)
    local parsed, errorMessage = self:ParseLuaData(text)
    if type(parsed) ~= "table" then return nil, errorMessage or "Expected a route table" end
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
    local valid, reason = self.options:ValidateValue("steps", result.steps, "steps")
    if not valid then return nil, reason end
    for key, value in pairs(result) do
        if key ~= "steps" and key ~= "name" then
            local definition = self.options.route[key]
            if not definition then return nil, "Unsupported route field: " .. tostring(key) end
            valid, reason = self.options:ValidateValue(definition.schema, value, key)
            if not valid then return nil, reason end
        end
    end
    result.name = name
    return result
end
