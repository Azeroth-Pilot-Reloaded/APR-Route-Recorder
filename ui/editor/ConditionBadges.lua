local UI = AprRC.editorUI
local function token(value) return tostring(value):gsub("[%s_%-]", ""):lower() end
-- Blizzard's race atlas names differ from several race file names.
local raceAtlases = { scourge = "undead", highmountaintauren = "highmountain",
    lightforgeddraenei = "lightforged", zandalaritroll = "zandalari", earthendwarf = "earthen" }
local raceNames
local function raceInfo(value)
    local getInfo = C_CreatureInfo and C_CreatureInfo.GetRaceInfo
    if not getInfo then return end
    if tonumber(value) then return getInfo(tonumber(value)) end
    if not raceNames then
        raceNames = {}
        for id = 1, 100 do
            local info = getInfo(id)
            if info and info.clientFileString then raceNames[token(info.clientFileString)] = info end
        end
    end
    return raceNames[token(value)]
end

local function identity(kind, value)
    if kind == "class" then
        for name, id in pairs(APR.Classes or {}) do
            if tonumber(value) == id or token(value) == token(name) then
                local class = token(name):upper()
                return class:lower(), (LOCALIZED_CLASS_NAMES_MALE or {})[class] or UI.Label(name)
            end
        end
        local class = token(value):upper()
        return class:lower(), (LOCALIZED_CLASS_NAMES_MALE or {})[class] or UI.Label(value)
    end
    local info = raceInfo(value)
    local race = token(info and info.clientFileString or value)
    return raceAtlases[race] or race, info and info.raceName or UI.Label(value)
end

function UI.ConditionIdentityText(field, value)
    local _, label = identity(field == "Race" and "race" or "class", value)
    return label
end

-- Badges indicate the presence of filters, not a flattened interpretation of
-- AnyOf/AllOf. Tooltips retain each filter's location and any negation.
function UI.ConditionBadges(step, groupConditions)
    local result, seen = {}, {}
    local function add(field, value, inverted, path)
        for _, entry in ipairs(type(value) == "table" and value or { value }) do
            if type(entry) == "number" or type(entry) == "string" then
                local kind = field == "Race" and "race" or "class"
                local name, label = identity(kind, entry)
                local excluded = (field == "ClassNot") ~= inverted
                local key = kind .. ":" .. name .. ":" .. tostring(excluded)
                local badge = seen[key]
                if not badge then
                    badge = { kind = kind, token = name, label = label, excluded = excluded, contexts = {},
                        atlas = kind == "race" and ("raceicon-" .. name .. "-male") or ("classicon-" .. name) }
                    seen[key], result[#result + 1] = badge, badge
                end
                badge.contexts[#badge.contexts + 1] = path .. " / " .. UI.Label(field)
            end
        end
    end
    local function visit(conditions, inverted, path, depth)
        if type(conditions) ~= "table" or depth > 40 then return end
        for _, field in ipairs({ "Class", "ClassNot", "Race" }) do
            if conditions[field] ~= nil then add(field, conditions[field], inverted, path) end
        end
        for _, field in ipairs({ "AllOf", "AnyOf" }) do
            if type(conditions[field]) == "table" then
                for index, child in ipairs(conditions[field]) do
                    visit(child, inverted, path .. " / " .. UI.Label(field) .. " " .. index, depth + 1)
                end
            end
        end
        if conditions.Not then visit(conditions.Not, not inverted, path .. " / " .. UI.Label("Not"), depth + 1) end
    end
    visit(step, false, UI.Text("Step"), 0)
    visit(groupConditions, false, UI.Text("Group conditions"), 0)
    table.sort(result, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.token ~= b.token then return a.token < b.token end
        return not a.excluded and b.excluded
    end)
    return result
end

function UI.BadgeTooltip(badge)
    local heading = (badge.excluded and "|cffff7777× |r" or "") .. badge.label
    AprRC:AddTooltipLine(GameTooltip, heading, 1, 0.82, 0.4)
    for _, context in ipairs(badge.contexts) do AprRC:AddTooltipLine(GameTooltip, context, 0.8, 0.8, 0.8, true) end
end
