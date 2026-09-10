local options = AprRC.options
local S = {}
options.schemas = S

local function object(fields, required)
    return { kind = "object", fields = fields, required = required or {} }
end
local function list(entry) return { kind = "list", entry = entry } end
S.coord = object({ x = "number", y = "number" }, { "x", "y" })
S.coords = list(object({ x = "number", y = "number", Zone = "id" }, { "x", "y", "Zone" }))
S.trigger = object({ x = "number", y = "number", Range = "positive" }, { "x", "y", "Range" })
S.questMap = object({ questID = "id", mapID = "id" }, { "questID", "mapID" })
S.treasure = object({ questID = "id", itemID = "id" }, { "questID" })
S.drop = object({ Qid = "id", MobId = "id", Text = "text" }, { "Qid", "MobId", "Text" })
S.group = object({ questID = "id", Number = "id" }, { "questID", "Number" })
S.achievement = object({ achievementID = "id", criteriaID = "id", criteriaIndex = "id",
    quantity = "positive", requiredQuantity = "positive" }, { "achievementID" })
S.scenario = object({ scenarioID = "id", stepID = "id", criteriaID = "id", criteriaIndex = "id",
    questID = "id" }, {})
S.item = object({ questID = "id", itemID = "id", itemSpellID = "id" }, { "questID", "itemID", "itemSpellID" })
S.spell = object({ questID = "id", spellID = "id" }, { "questID", "spellID" })
S.items = list(object({ questID = "id", itemID = "id", quantity = "id" }, { "itemID", "quantity" }))
S.reputation = object({ factionID = "id", type = { kind = "enum", values = { "standard", "renown", "friendship" } },
    level = "id" }, { "factionID", "level" })
S.emote = object({ npcID = "nonnegative", emote = "text" }, { "npcID", "emote" })
S.buffs = list(object({ spellId = "id", tooltipMessage = "text" }, { "spellId" }))
S.qpart = { kind = "map", key = "id", entry = "ids" }
S.buttons = { kind = "map", key = "objectiveKey", entry = "id" }
S.prefab = { kind = "map", key = "text", entry = "positive" }
S.parallel = list(object({ conditions = "conditions", steps = "steps" }, { "conditions", "steps" }))
S.anyOf = list("conditions")
S.note = { kind = "union", choices = { "text", "strings" } }
S.xp = { kind = "union", choices = { "profile", { kind = "enum", values = { false } } } }
S.routeLinks = { kind = "union", choices = { "text", "strings" } }
S.classValue = { kind = "union", choices = { { kind = "enum", group = "Classes" },
    { kind = "enum", values = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
        "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" } } } }
S.class = { kind = "union", choices = { S.classValue, list(S.classValue) } }
S.race = { kind = "union", choices = { { kind = "enum", group = "RACES" },
    list({ kind = "enum", group = "RACES" }) } }

local routeConditions = {
    InterfaceVersion = true, DontHaveSpell = true, IsQuestReadyForTurnIn = true,
    HasAchievement = true, DontHaveAchievement = true, Faction = true, Race = true,
    Class = true, ClassNot = true, Event = true, AlliedRace = true, IsQuestCompleted = true,
    IsQuestUncompleted = true, Level = true, MinLevel = true, MaxLevel = true, BeLvl = true,
    ClassSpec = true, Zones = true,
}

function options:ValidateValue(schema, value, path, depth)
    depth = (depth or 0) + 1
    path = path or "value"
    if depth > 40 then return false, path .. ": nesting limit exceeded" end
    local kind = type(schema) == "table" and schema.kind or schema
    local function fail(message) return false, path .. ": " .. message end
    local function child(childSchema, entry, key)
        return self:ValidateValue(childSchema, entry, path .. "." .. tostring(key), depth)
    end
    if kind == "union" then
        for _, choice in ipairs(schema.choices) do if child(choice, value, "value") then return true end end
        return fail("value does not match the expected format")
    elseif kind == "bool" then
        if type(value) ~= "boolean" then return fail("expected true or false") end
    elseif kind == "number" or kind == "positive" or kind == "id" or kind == "nonnegative" then
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fail("expected a finite number") end
        if (kind == "positive" or kind == "id") and value <= 0 then return fail("must be greater than zero") end
        if (kind == "id" or kind == "nonnegative") and value % 1 ~= 0 then return fail("expected an integer") end
        if kind == "nonnegative" and value < 0 then return fail("must be zero or greater") end
    elseif kind == "text" then
        if type(value) ~= "string" or strtrim(value) == "" then return fail("expected nonempty text") end
    elseif kind == "objectiveKey" then
        if type(value) ~= "string" or not (value:match("^%d+%-%d+$") or value:match("^%d+$")) then
            return fail('expected a string key such as "12345-1" or "12345"')
        end
        local quest, objective = value:match("^(%d+)%-?(%d*)$")
        if tonumber(quest) < 1 or (objective ~= "" and tonumber(objective) < 1) then return fail("IDs must be positive") end
    elseif kind == "level" then
        if type(value) == "number" then return child("positive", value, "level") end
        return child("profile", value, "profile")
    elseif kind == "profile" then
        if type(value) ~= "string" or not APR.LevelRequirementProfiles or not APR.LevelRequirementProfiles[value] then
            return fail("unknown APR level profile")
        end
    elseif kind == "enum" then
        local values = schema.values or APR[schema.group] or {}
        for _, candidate in pairs(values) do if candidate == value then return true end end
        return fail("unknown enum value")
    elseif kind == "idOrIds" and type(value) == "number" then
        return child("id", value, "id")
    elseif kind == "list" or kind == "ids" or kind == "idOrIds" or kind == "strings" or kind == "steps" then
        if type(value) ~= "table" then return fail("expected a list") end
        local size = 0
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return fail("expected consecutive list indices") end
            size = size + 1
        end
        for index = 1, size do
            if value[index] == nil then return fail("list indices must be consecutive") end
            local entrySchema = kind == "list" and schema.entry or kind == "strings" and "text" or kind == "steps" and "step" or "id"
            local ok, reason = child(entrySchema, value[index], index)
            if not ok then return false, reason end
            if kind == "steps" and value[index].RouteCompleted and index ~= size then return fail("RouteCompleted must be last") end
        end
        if size == 0 and kind ~= "steps" and schema ~= S.anyOf then return fail("list must not be empty") end
    elseif kind == "object" or kind == "map" or kind == "conditions" or kind == "routeConditions" or kind == "step" then
        if type(value) ~= "table" then return fail("expected a table") end
        if kind == "object" then
            for _, key in ipairs(schema.required) do if value[key] == nil then return fail("missing " .. key) end end
        end
        for key, entry in pairs(value) do
            local entrySchema
            if kind == "object" then entrySchema = schema.fields[key]
            elseif kind == "map" then
                local ok, reason = child(schema.key, key, "key")
                if not ok then return false, reason end
                entrySchema = schema.entry
            else
                local definition = self.step[key]
                if not definition and type(key) == "string" then
                    local base = key:match("^(ExtraLineText)%d+$") or key:match("^(TrigText)%d+$")
                    definition = base and self.step[base]
                end
                if definition and (kind == "step" or definition.condition) then entrySchema = definition.schema end
                if kind == "routeConditions" and not routeConditions[key] then entrySchema = nil end
                if kind == "routeConditions" and (key == "Level" or key == "MinLevel" or key == "MaxLevel" or key == "BeLvl") then entrySchema = "positive" end
                if kind == "routeConditions" and (key == "Race" or key == "Class" or key == "ClassNot") then
                    entrySchema = { kind = "enum", group = key == "Race" and "RACES" or "Classes" }
                end
                if kind == "step" and key == "_index" then entrySchema = "id" end
            end
            if not entrySchema then return fail("unsupported field " .. tostring(key)) end
            local ok, reason = child(entrySchema, entry, key)
            if not ok then return false, reason end
        end
        if schema == S.reputation and value.type == "standard" and value.level > 8 then return fail("standard standing must be 1-8") end
        if schema == S.scenario and not (value.criteriaID or value.criteriaIndex or value.stepID or value.scenarioID) then
            return fail("a scenario, step or criterion ID is required")
        end
        if kind == "step" then
            if value.DropQuest and value.DroppableQuest and value.DropQuest ~= value.DroppableQuest.Qid then
                return fail("DropQuest must match DroppableQuest.Qid")
            end
            for key, definition in pairs(self.step) do
                if value[key] ~= nil and definition.requires and value[definition.requires] == nil then
                    return fail(key .. " requires " .. definition.requires)
                end
            end
        end
    else
        return fail("unsupported schema " .. tostring(kind))
    end
    return true
end
