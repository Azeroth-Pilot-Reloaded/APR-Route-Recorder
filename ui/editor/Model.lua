-- Editing works on detached drafts. Recording always owns CurrentRoute.
AprRC.editorModel = {}
local Model = AprRC.editorModel
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")
local Session = {}
Session.__index = Session

function Model:RouteText(route)
    local data = AprRC:CopyData(route)
    data.name = nil
    return AprRC:SerializeData(data)
end

function Model:Source(name)
    if not name or name == "" then return nil end
    if AprRCData.CurrentRoute and AprRCData.CurrentRoute.name == name then
        return AprRCData.CurrentRoute
    end
    return AprRC:FindRouteByName(name)
end

function Model:Open(route)
    AprRCData.BackupRoute = AprRC:CopyData(route.steps)
    local session = setmetatable({ name = route.name, selected = 1, history = {}, cursor = 0 }, Session)
    local saved = AprRCData.EditorDrafts and AprRCData.EditorDrafts[route.name]
    session:Reload(route)
    if saved then
        session.draft = AprRC:CopyData(saved.draft)
        session.base = saved.base
        session.raw = saved.raw
        session.selected = saved.selected or 1
        session.parallelGroup = saved.parallelGroup or 1
        session.parallelSelected = saved.parallelSelected or 1
        session:ClampSelection()
        session.history, session.cursor = {}, 0
        session:Snapshot()
    end
    return session
end

function Session:Reload(route)
    route = route or Model:Source(self.name)
    if not route then return false end
    self.draft = AprRC:BuildRouteDefinition(route)
    self.draft.name = route.name
    self.base = Model:RouteText(self.draft)
    self.raw = nil
    self.selected = math.max(1, math.min(self.selected, #route.steps))
    self:ClampSelection()
    self.history, self.cursor = {}, 0
    self:Snapshot()
    return true
end

function Session:IsDirty()
    return self.raw ~= nil or Model:RouteText(self.draft) ~= self.base
end

function Session:IsStale()
    local source = Model:Source(self.name)
    return not source or Model:RouteText(AprRC:BuildRouteDefinition(source)) ~= self.base
end

function Session:Persist()
    AprRCData.EditorDrafts = AprRCData.EditorDrafts or {}
    if self:IsDirty() then
        AprRCData.EditorDrafts[self.name] = {
            draft = AprRC:CopyData(self.draft), base = self.base,
            raw = self.raw, selected = self.selected,
            parallelGroup = self.parallelGroup, parallelSelected = self.parallelSelected,
        }
    else
        AprRCData.EditorDrafts[self.name] = nil
    end
end

function Session:Snapshot()
    self.rawHistory = nil
    local snapshot = { draft = AprRC:CopyData(self.draft), selected = self.selected,
        parallelGroup = self.parallelGroup, parallelSelected = self.parallelSelected }
    if self.history[self.cursor] and AprRC:DeepCompare(self.history[self.cursor].draft, snapshot.draft) then
        self:Persist()
        return
    end
    for index = #self.history, self.cursor + 1, -1 do self.history[index] = nil end
    self.history[#self.history + 1] = snapshot
    if #self.history > 50 then table.remove(self.history, 1) end
    self.cursor = #self.history
    self:Persist()
end

function Session:Undo(delta)
    local index = self.cursor + delta
    if index < 1 or index > #self.history then return false end
    self.cursor = index
    self.draft = AprRC:CopyData(self.history[index].draft)
    self.selected = self.history[index].selected
    self.parallelGroup = self.history[index].parallelGroup
    self.parallelSelected = self.history[index].parallelSelected
    self:ClampSelection()
    self.raw = nil
    self:Persist()
    return true
end

function Session:Read()
    -- Only the saved baseline can bypass validation for legacy fields. Using
    -- the edited draft here would also accept invalid visual-form input.
    local baseline = AprRC:ParseLuaData(self.base)
    return AprRC:ReadRouteDefinition(self.raw or Model:RouteText(self.draft), self.name, self.draft, baseline)
end

function Session:ApplyRaw()
    if self.raw == nil then return true end
    local route, reason = self:Read()
    if not route then return false, reason end
    self.draft, self.raw = route, nil
    self.selected = math.max(1, math.min(self.selected, #route.steps))
    self:ClampSelection()
    self:Snapshot()
    return true
end

function Session:GetSteps(group)
    if not group then return self.draft.steps end
    local parallel = (self.draft.parallelSteps or {})[group]
    return parallel and parallel.steps or {}
end

function Session:GetSelected(group)
    return group and self.parallelSelected or self.selected
end

function Session:SetSelected(index, group)
    if group then self.parallelSelected = index else self.selected = index end
end

function Session:ClampSelection()
    self.parallelGroup = math.max(1, math.min(self.parallelGroup or 1, #(self.draft.parallelSteps or {})))
    self.parallelSelected = math.max(1, math.min(self.parallelSelected or 1, #self:GetSteps(self.parallelGroup)))
end

function Session:InsertGroup(copy)
    self.draft.parallelSteps = self.draft.parallelSteps or {}
    local groups = self.draft.parallelSteps
    local index = copy and math.min(self.parallelGroup + 1, #groups + 1) or #groups + 1
    table.insert(groups, index, copy and AprRC:CopyData(copy) or { conditions = {}, steps = {} })
    self.parallelGroup, self.parallelSelected = index, 1
    self:Snapshot()
end

function Session:MoveGroup(index, destination)
    local groups = self.draft.parallelSteps or {}
    if not groups[index] or not groups[destination] then return false end
    table.insert(groups, destination, table.remove(groups, index))
    self.parallelGroup = destination
    self:Snapshot()
    return true
end

function Session:DeleteGroup(index)
    local groups = self.draft.parallelSteps or {}
    if not groups[index] then return false end
    table.remove(groups, index)
    if #groups == 0 then self.draft.parallelSteps = nil end
    self.parallelGroup, self.parallelSelected = index, 1
    self:ClampSelection()
    self:Snapshot()
    return true
end

function Session:Reindex(group)
    for index, step in ipairs(self:GetSteps(group)) do
        if step._index then step._index = index end
    end
end

function Session:Insert(step, after, group)
    if not step or (group and not (self.draft.parallelSteps or {})[group]) then return false end
    local steps = self:GetSteps(group)
    local index = math.min((after or #steps) + 1, #steps + 1)
    if steps[#steps] and steps[#steps].RouteCompleted then
        if step.RouteCompleted then return false end
        index = math.min(index, #steps)
    elseif step.RouteCompleted then
        index = #steps + 1
    end
    table.insert(steps, index, AprRC:CopyData(step))
    self:SetSelected(index, group)
    self:Reindex(group)
    self:Snapshot()
    return true
end

function Session:Move(index, destination, group)
    local steps = self:GetSteps(group)
    if not steps[index] or not steps[destination] then return false end
    if steps[index].RouteCompleted or steps[destination].RouteCompleted then return false end
    table.insert(steps, destination, table.remove(steps, index))
    self:SetSelected(destination, group)
    self:Reindex(group)
    self:Snapshot()
    return true
end

function Session:Delete(index, group)
    local steps = self:GetSteps(group)
    if not steps[index] then return false end
    table.remove(steps, index)
    self:SetSelected(math.max(1, math.min(index, #steps)), group)
    self:Reindex(group)
    self:Snapshot()
    return true
end

function Session:Save(overwrite)
    local route, reason = self:Read()
    if not route then return false, reason end
    local source = Model:Source(self.name)
    if not source then return false, "missing" end
    if not overwrite and self:IsStale() then return false, "conflict" end
    AprRCData.BackupRoute = AprRC:CopyData(source.steps)
    if not AprRC:UpdateRouteByName(self.name, route) then return false, "missing" end
    if AprRCData.CurrentRoute.name == self.name then
        AprRCData.CurrentRoute = route
        AprRC:ResetRecordingSession()
        AprRC:RebuildQuestLookupFromRoute(route)
    end
    self:Reload(route)
    self:Persist()
    return true
end

function Model:NewRoute(name, copy)
    name = strtrim(name or "")
    if name == "" then return nil, "name" end
    local mapID = copy and copy.mapID or C_Map.GetBestMapForUnit("player")
    if not name:match("^%d+%-") then
        if not mapID then return nil, "map" end
        name = mapID .. "-" .. name
    end
    if AprRC:FindRouteByName(name) then return nil, "duplicate" end
    local route = copy and AprRC:CopyData(copy) or { steps = {} }
    route.name = name
    route.mapID = route.mapID or mapID
    table.insert(AprRCData.Routes, route)
    AprRC:NotifyRouteChanged(route.name)
    return route
end

-- Summaries never mutate a route or ask GetLastStep (which creates a step).
function Model:CoinIcon(unit)
    return "|TInterface\\MoneyFrame\\UI-" .. unit .. "Icon:14:14:0:0|t"
end

function Model:MoneyParts(copper)
    local total = math.max(0, math.floor(tonumber(copper) or 0))
    return math.floor(total / 10000), math.floor(total / 100) % 100, total % 100
end

function Model:MoneyText(copper)
    if type(copper) ~= "number" then return tostring(copper or "") end
    local gold, silver, change = self:MoneyParts(copper)
    return gold .. self:CoinIcon("Gold") .. " " .. silver .. self:CoinIcon("Silver") .. " " .. change .. self:CoinIcon("Copper")
end

local function iconText(name, icon, fallback)
    return "|T" .. tostring(icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":14:14:0:0|t " .. tostring(name or fallback)
end

local function summaryLabel(key)
    return AprRC.editorUI and AprRC.editorUI.Label(key) or key
end

function Model:ItemText(id)
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, icon
    if tonumber(id) and getInfo then
        local info = { getInfo(tonumber(id)) }
        name, icon = info[1], info[10]
        if not name then
            self.pendingItemNames = self.pendingItemNames or {}
            self.pendingItemNames[tonumber(id)] = true
        end
    end
    return iconText(name, icon, "#" .. tostring(id))
end

function Model:SpellText(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(tonumber(id) or id)
    local name, icon = info and info.name, info and info.iconID
    if not name and GetSpellInfo then
        local legacyName, _, legacyIcon = GetSpellInfo(tonumber(id) or id)
        name, icon = legacyName, legacyIcon
    end
    return iconText(name, icon, "#" .. tostring(id))
end

-- Skill-line IDs are not spell IDs. These base profession spells supply the
-- localized names and icons even when the character has not learned the skill.
local skills = { alchemy = { 171, 2259 }, blacksmithing = { 164, 2018 }, cooking = { 185, 2550 },
    enchanting = { 333, 7411 }, engineering = { 202, 4036 }, firstaid = { 129, 3273 },
    fishing = { 356, 7620 }, herbalism = { 182, 9134 }, leatherworking = { 165, 2108 },
    mining = { 186, 2575 }, skinning = { 393, 8613 }, tailoring = { 197, 3908 }, riding = { 762, 33388 } }

function Model:SkillText(value)
    local wanted = value.skillID or value.skill or value.name
    local token = tostring(wanted or ""):lower():gsub("%s", "")
    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            local name, icon, _, _, _, _, id = GetProfessionInfo(index)
            if id == tonumber(wanted) or name == value.name or
                (name and name:lower():gsub("%s", "") == token) then return iconText(name, icon, wanted) end
        end
    end
    for key, data in pairs(skills) do
        if token == key or tonumber(wanted) == data[1] then return self:SpellText(data[2]) end
    end
    return iconText(value.name, nil, wanted or "?")
end

function Model:FieldSummary(key, value)
    if type(value) ~= "table" then return end
    local function items(ids)
        local result = {}
        for _, id in ipairs(ids or {}) do result[#result + 1] = self:ItemText(id) end
        return table.concat(result, ", ")
    end
    if key == "LootMoney" then return self:MoneyText(value.copper)
    elseif key == "Money" then return (value.operator or ">=") .. " " .. self:MoneyText(value.copper)
    elseif key == "DestroyItems" or key == "BankDeposit" or key == "BankWithdraw" then return items(value.items)
    elseif key == "ItemCount" then
        return items(value.itemIDs or (value.itemID and { value.itemID })) .. " " .. (value.operator or ">=") .. " " .. tostring(value.count or 0)
    elseif key == "Collection" then return self:ItemText(value.itemID) .. " × " .. tostring(value.quantity or 1)
    elseif key == "EquippedItem" then
        local text = value.itemID and self:ItemText(value.itemID) or ""
        return (value.invert and "≠ " or "") .. text
    elseif key == "Skill" then return self:SkillText(value) .. " " .. (value.operator or ">=") .. " " .. tostring(value.rank or 1)
    elseif key == "LearnSkill" then
        local result = {}
        for _, id in ipairs(value.spellIDs or (value.spellID and { value.spellID }) or {}) do
            result[#result + 1] = self:SpellText(id)
        end
        return table.concat(result, ", ")
    elseif key == "Not" then
        local text = self:ConditionSummary(value)
        return text ~= "" and (summaryLabel(key) .. " (" .. text .. ")") or nil
    elseif key == "AllOf" or key == "AnyOf" then
        local result = {}
        for _, child in ipairs(value) do
            local text = self:ConditionSummary(child)
            if text ~= "" then result[#result + 1] = "(" .. text .. ")" end
        end
        return #result > 0 and (summaryLabel(key) .. " " .. table.concat(result, ", ")) or nil
    end
end

function Model:ConditionSummary(conditions)
    local result = {}
    for _, key in ipairs({ "Money", "ItemCount", "Skill", "Collection", "EquippedItem", "AllOf", "AnyOf", "Not" }) do
        local detail = self:FieldSummary(key, conditions[key])
        if detail and detail ~= "" then
            result[#result + 1] = (key == "Not" or key == "AllOf" or key == "AnyOf") and detail or
                (summaryLabel(key) .. ": " .. detail)
        end
    end
    return table.concat(result, " · ")
end

local actionOrder = {
    "RouteCompleted", "PickUp", "Qpart", "QpartPart", "Done", "Waypoint", "Note",
    "UseFlightPath", "GetFP", "SetHS", "UseHS", "UseDalaHS", "UseGarrisonHS",
    "TakePortal", "Treasure", "Achievement", "Scenario", "EnterScenario", "DoScenario",
    "LeaveScenario", "EnterInstance", "LeaveInstance", "UseItem", "UseSpell", "Grind",
    "Reputation", "BuyMerchant", "LootItems", "LootMoney", "LeaveQuests", "Emote", "ChromiePick",
    "LearnProfession", "WarMode", "ResetRoute", "VehicleExit", "MountVehicle",
    "ExitTutorial", "LeaveQuest", "DeathSkip", "SellItems", "LearnSkill",
    "BankDeposit", "BankWithdraw", "DestroyItems", "TameBeast",
}
local questActions = { PickUp = true, Qpart = true, QpartPart = true, Done = true, LeaveQuests = true,
    LeaveQuest = true, ExitTutorial = true }
local navigationActions = { Waypoint = true, UseFlightPath = true, GetFP = true, SetHS = true,
    UseHS = true, UseDalaHS = true, UseGarrisonHS = true, TakePortal = true }

function Model:Summary(step)
    local key = "Step"
    for _, candidate in ipairs(actionOrder) do
        if step[candidate] then key = candidate; break end
    end
    local ids = {}
    if questActions[key] and type(step[key]) == "table" then
        for index, value in pairs(step[key]) do
            ids[#ids + 1] = (key == "Qpart" or key == "QpartPart") and index or value
        end
        table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    elseif questActions[key] and type(step[key]) == "number" then
        ids[1] = step[key]
    end
    local titles = {}
    for _, id in ipairs(ids) do
        local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(tonumber(id) or 0)
        titles[#titles + 1] = title and (title .. " (#" .. tostring(id) .. ")") or ("#" .. tostring(id))
    end
    local preview, raw = {}, {}
    if #titles > 0 then
        preview[1] = table.concat(titles, ", ")
        raw[1] = preview[1]
    end
    for _, field in ipairs({ "LootMoney", "DestroyItems", "LearnSkill", "BankDeposit", "BankWithdraw" }) do
        local actionDetail = self:FieldSummary(field, step[field])
        if actionDetail and actionDetail ~= "" then
            if field ~= key then actionDetail = summaryLabel(field) .. ": " .. actionDetail end
            preview[#preview + 1], raw[#raw + 1] = actionDetail, actionDetail
        end
    end
    local conditions = self:ConditionSummary(step)
    if conditions ~= "" then preview[#preview + 1], raw[#raw + 1] = conditions, conditions end
    local function addText(value)
        if value == nil then return end
        local lines = type(value) == "table" and value or { value }
        for _, line in ipairs(lines) do
            local text = tostring(line)
            -- Match APR's lookup order without triggering AceLocale missing-key errors.
            preview[#preview + 1] = rawget(L_APR, text) or
                (AprRCData.ExtraLineTexts and rawget(AprRCData.ExtraLineTexts, text)) or text
            raw[#raw + 1] = text
        end
    end
    addText(step.Note)
    local extraFields = {}
    for field in pairs(step) do
        if type(field) == "string" and field:match("^ExtraLineText%d*$") then
            extraFields[#extraFields + 1] = field
        end
    end
    table.sort(extraFields)
    for _, field in ipairs(extraFields) do addText(step[field]) end
    if #preview == 0 and step.Name then
        preview[1], raw[1] = tostring(step.Name), tostring(step.Name)
    end
    local detail = table.concat(preview, " · ")
    local category = questActions[key] and "quests" or navigationActions[key] and "travel" or "other"
    return key, detail, category, table.concat(raw, " · ")
end

function Model:Filter(steps, query, category, label)
    local matches = {}
    query = strtrim(query or ""):lower()
    for index, step in ipairs(steps) do
        local key, detail, kind = self:Summary(step)
        local haystack = (index .. " " .. key .. " " .. (label and label(key) or "") .. " " .. detail .. " " ..
            AprRC:SerializeData(step)):lower()
        if (not category or category == "all" or category == kind) and
            (query == "" or haystack:find(query, 1, true)) then
            matches[#matches + 1] = index
        end
    end
    return matches
end
