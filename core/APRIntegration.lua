-- Saved routes are published automatically; editor drafts never enter this bridge.
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

function AprRC:RemoveRecorderRouteFromAPR(name)
    local key = AprRCData.APRRouteKeys and AprRCData.APRRouteKeys[name]
    if not key then return end
    if APRData and APRData.CustomRoute then APRData.CustomRoute[key] = nil end
    if APR and APR.RouteQuestStepList then APR.RouteQuestStepList[key] = nil end
    AprRCData.APRRouteKeys[name] = nil
    if APR and APR.InvalidateEffectiveRouteStepsCache then APR:InvalidateEffectiveRouteStepsCache(key) end
    if APR and APR.routeconfig and APR.routeconfig.SendMessage then
        APR.routeconfig:SendMessage("APR_Custom_Path_Update")
    end
end

function AprRC:GetAPRRouteKey(route)
    AprRCData.APRRouteKeys = AprRCData.APRRouteKeys or {}
    local keys = AprRCData.APRRouteKeys
    if keys[route.name] then return keys[route.name] end
    local base = route.name .. " - Custom"
    local key, index = base, 1
    -- Never replace an unrelated APR route, including an older manual export.
    while (APR.RouteQuestStepList and APR.RouteQuestStepList[key]) or
        (APRData.CustomRoute and APRData.CustomRoute[key]) do
        index = index + 1
        key = base .. " (Recorder " .. index .. ")"
    end
    keys[route.name] = key
    return key
end

function AprRC:SyncRouteToAPR(route)
    if not APR or not APRData or not route or not route.name or route.name == "" then return end
    APRData.CustomRoute = APRData.CustomRoute or {}
    APR.RouteQuestStepList = APR.RouteQuestStepList or {}
    local key = self:GetAPRRouteKey(route)
    local definition = self:BuildRouteDefinition(route)
    if not definition.gameVersion and definition.expansion ~= APR.EXPANSIONS.Custom then
        definition.gameVersion = definition.expansion == APR.EXPANSIONS.Forever and "forever" or "retail"
    end
    -- APR also resolves routes by label. Use the unique storage key for our copies.
    definition.label = key
    definition.expansion = APR.EXPANSIONS.Custom
    if self:DeepCompare(APRData.CustomRoute[key], definition) and APR.RouteQuestStepList[key] then return end
    if APR.RegisterCustomRoute then
        APR:RegisterCustomRoute(key, definition)
    else
        -- Compatibility with released APR versions predating the registration API.
        APRData.CustomRoute[key] = self:CopyData(definition)
        APR.RouteQuestStepList[key] = self:CopyData(definition)
        if APR.InvalidateEffectiveRouteStepsCache then APR:InvalidateEffectiveRouteStepsCache(key) end
        if APR.routeconfig and APR.routeconfig.SendMessage then
            APR.routeconfig:SendMessage("APR_Custom_Path_Update")
        end
    end
end

function AprRC:FlushAPRRouteSync()
    local pending = self.pendingAPRRoutes or {}
    self.pendingAPRRoutes = nil
    for name in pairs(pending) do
        local current = AprRCData.CurrentRoute
        local route = current and current.name == name and current or self:FindRouteByName(name)
        self:SyncRouteToAPR(route)
    end
end

function AprRC:RequestAPRRouteSync(name)
    name = name or (AprRCData and AprRCData.CurrentRoute and AprRCData.CurrentRoute.name)
    if not name or name == "" then return end
    -- Also covers legacy handlers that edit the table returned by GetLastStep.
    -- Keep revisions out of SavedVariables and exported route definitions.
    self.routeRevisions = self.routeRevisions or {}
    self.routeRevisions[name] = (self.routeRevisions[name] or 0) + 1
    if not self.pendingAPRRoutes then
        self.pendingAPRRoutes = {}
        C_Timer.After(0, function() self:FlushAPRRouteSync() end)
    end
    self.pendingAPRRoutes[name] = true
end

function AprRC:InitializeAPRRouteSync()
    for _, route in ipairs(AprRCData.Routes) do self:RequestAPRRouteSync(route.name) end
    self:RequestAPRRouteSync()
    self:RegisterEvent("PLAYER_LOGOUT", "FlushAPRRouteSync")
end

function AprRC:GetImportableAPRRoutes()
    local entries, owned = {}, {}
    for _, key in pairs(AprRCData.APRRouteKeys or {}) do owned[key] = true end
    for key, route in pairs(APR and APR.RouteQuestStepList or {}) do
        if type(route) == "table" and not owned[key] and
            (type(route.steps) == "table" or type(route.scenarios) == "table" or type(route[1]) == "table") then
            entries[key] = (route.label or key) .. "  [" .. key .. "]"
        end
    end
    return entries
end

-- Playback indexes include inserted parallel steps. Locate the source table in
-- the definition instead of treating APR's index as a main-step index.
function AprRC:GetAPRPlaybackSelection(name)
    local key = APR and APR.ActiveRoute
    local publishedKey = AprRCData.APRRouteKeys and AprRCData.APRRouteKeys[name]
    if not key or (key ~= name and key ~= publishedKey) then return end
    local player = APRData and APR.PlayerID and APRData[APR.PlayerID]
    local progress = player and player[key]
    if type(progress) ~= "number" or progress < 1 or progress % 1 ~= 0 then return end
    local definition = APR.RouteQuestStepList and APR.RouteQuestStepList[key]
    if type(definition) ~= "table" then return end
    local mainSteps = definition.steps or definition
    local effectiveSteps = APR.GetRouteSteps and APR:GetRouteSteps(key) or mainSteps
    local source = effectiveSteps and effectiveSteps[progress]
    if type(source) ~= "table" then return end
    local cached = self.aprPlaybackSelection
    if cached and cached.key == key and cached.definition == definition and cached.source == source then
        local group = cached.group and (definition.parallelSteps or {})[cached.group]
        local steps = cached.group and group and group.steps or (not cached.group and mainSteps)
        if steps and steps[cached.index] == source then return cached.index, cached.group end
    end
    local function locate(steps, group)
        for index, step in ipairs(steps or {}) do
            if step == source then
                self.aprPlaybackSelection = { key = key, definition = definition, source = source, index = index, group = group }
                return index, group
            end
        end
    end
    local index = locate(mainSteps)
    if index then return index end
    for groupIndex, group in ipairs(definition.parallelSteps or {}) do
        local parallelIndex = locate(group.steps, groupIndex)
        if parallelIndex then return parallelIndex, groupIndex end
    end
end

function AprRC:ImportAPRRoute(key)
    local source = APR and APR.RouteQuestStepList and APR.RouteQuestStepList[key]
    if not source or not self:GetImportableAPRRoutes()[key] then return nil, L["APR route is not available."] end
    -- Copy the definition, not GetRouteSteps(): playback may filter/expand parallel steps.
    local route = (source.steps or source.scenarios) and self:CopyData(source) or { steps = self:CopyData(source) }
    if source.scenarios then route.delve = route.delve or {} end
    route.name = key
    local index = 1
    while self:FindRouteByName(route.name) do
        index = index + 1
        route.name = key .. " (" .. index .. ")"
    end
    route = self:BuildRouteDefinition(route)
    route.name = index == 1 and key or key .. " (" .. index .. ")"
    table.insert(AprRCData.Routes, route)
    self:NotifyRouteChanged(route.name)
    return route
end
