-- Saved routes are published automatically; editor drafts never enter this bridge.
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

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
