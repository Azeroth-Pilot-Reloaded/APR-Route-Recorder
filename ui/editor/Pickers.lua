local UI = AprRC.editorUI
local R = AprRC.options
local Pickers = {}
UI.Pickers = Pickers
LibStub("AceGUI-3.0"):RegisterLayout("APRPickerActions", function(content, children)
    for index, child in ipairs(children) do
        child.frame:ClearAllPoints()
        child.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -(#children - index) * 34, 0)
        child.frame:Show()
    end
    content.obj:LayoutFinished(content:GetWidth(), 30)
end)
local function kind(schema) return type(schema) == "table" and schema.kind or schema end
local function public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return nil end
    return value
end

local quests = { PickUp = true, PickUpDB = true, Done = true, DoneDB = true, QpartDB = true,
    Waypoint = true, WaypointDB = true, LeaveQuest = true, DropQuest = true, ExitTutorial = true,
    GroupTask = true, questID = true, Qid = true }
local spells = { spellID = true, spellId = true, spellIDs = true, itemSpellID = true,
    HasSpell = true, DontHaveSpell = true, SpellTrigger = true, LearnProfession = true }
local items = { itemID = true, itemIDs = true, items = true }
local maps = { mapID = true, Zone = true, Zones = true, SkipInZones = true }
local counts = { quantity = true, Number = true, level = true, slot = true, index = true,
    InterfaceVersion = true, RaidIcon = true }

function Pickers:Resolve(schema, path)
    local valueKind = kind(schema)
    local key = path:gsub("/variant", ""):match("([^/]+)$")
    local objectiveQuest = path:match("/Qpart/(%d+)$") or path:match("/QpartPart/(%d+)$") or path:match("/Fillers/(%d+)$")
    if objectiveQuest then return { kind = "objective", questID = tonumber(objectiveQuest) } end
    if valueKind == "objectiveKey" then return { kind = "objectiveKey" } end
    if valueKind == "text" or valueKind == "strings" then
        if key == "Note" or key == "text" or key == "Text" or key == "tooltipMessage"
            or key:match("^ExtraLineText%d*$") or key:match("^TrigText%d*$") then return { kind = "locale" } end
        return
    end
    if valueKind ~= "id" and valueKind ~= "ids" and valueKind ~= "idOrIds" then return end
    if counts[key] then return end
    if quests[key] or key:match("^Is.*Quest") then return { kind = "quest" } end
    if spells[key] or path:match("/SpellButton/[^/]+$") then return { kind = "spell" } end
    if items[key] or path:match("/Button/[^/]+$") then return { kind = "item" } end
    if key == "HasAura" or key == "DontHaveAura" then return { kind = "aura" } end
    if key == "achievementID" or key == "HasAchievement" or key == "DontHaveAchievement" then return { kind = "achievement" } end
    if maps[key] then return { kind = "map" } end
    return { kind = "id", field = key }
end

-- Use command selectors as value providers, never dispatch recording commands.
function Pickers:Open(spec, context, accept)
    local function current() return not context.isCurrent or context.isCurrent() end
    local function submit(value)
        if current() then accept(value) end
    end
    local function numeric(text, key, frame)
        if not current() then frame:Hide(); return end
        local id = tonumber(key) or tonumber(text)
        local valid, reason = R:ValidateValue("id", id)
        if not valid then context.error(reason); return end
        frame:Hide()
        submit(id)
    end
    local A = AprRC.autocomplete
    if spec.kind == "locale" then
        return A:ShowLocaleAutoComplete(submit)
    elseif spec.kind == "spell" then
        return A:ShowSpellAutoComplete(nil, nil, numeric, true)
    elseif spec.kind == "item" then
        return A:ShowItemAutoComplete(nil, nil, numeric)
    elseif spec.kind == "achievement" then
        return A:ShowAchievementAutoComplete(numeric)
    elseif spec.kind == "aura" then
        return A:ShowAuraAutoComplete(numeric)
    elseif spec.kind == "objective" or spec.kind == "objectiveKey" then
        local quests = AprRC.QuestObjectiveSelector:GetQuestList(true)
        if spec.questID then
            local filtered = {}
            for _, quest in ipairs(quests) do if quest.questID == spec.questID then filtered[#filtered + 1] = quest end end
            if #filtered == 0 then
                local objectives = public(C_QuestLog.GetQuestObjectives(spec.questID)) or {}
                local entries = {}
                for index, objective in ipairs(objectives) do
                    objective = public(objective)
                    if objective then entries[#entries + 1] = { objectiveID = index, text = public(objective.text) } end
                end
                filtered[1] = { questID = spec.questID, title = tostring(spec.questID), objectives = entries }
            end
            quests = filtered
        end
        return AprRC.QuestObjectiveSelector:Show({ questList = quests, onClick = function(quest, objective)
            submit(spec.kind == "objectiveKey" and (quest .. "-" .. objective) or objective)
        end })
    end
    local values = {}
    local function add(id, name)
        id, name = public(id), public(name)
        if type(id) == "number" and id > 0 then values[id] = type(name) == "string" and name or tostring(id) end
    end
    if spec.kind == "quest" then
        for index = 1, public(C_QuestLog.GetNumQuestLogEntries()) or 0 do
            local info = public(C_QuestLog.GetInfo(index))
            if info and not public(info.isHeader) then add(info.questID, info.title) end
        end
        local function collect(data)
            if type(data) ~= "table" then return end
            for key, entry in pairs(data) do
                if quests[key] or (type(key) == "string" and key:match("^Is.*Quest")) then
                    if type(entry) == "number" then add(entry, C_QuestLog.GetTitleForQuestID(entry))
                    elseif type(entry) == "table" then
                        for _, id in ipairs(entry) do if type(id) == "number" then add(id, C_QuestLog.GetTitleForQuestID(id)) end end
                    end
                elseif key == "Qpart" or key == "QpartPart" or key == "Fillers" then
                    for id in pairs(type(entry) == "table" and entry or {}) do
                        if type(id) == "number" then add(id, C_QuestLog.GetTitleForQuestID(id)) end
                    end
                end
                collect(entry)
            end
        end
        collect(context.route)
    elseif spec.kind == "map" then
        local id = public(C_Map.GetBestMapForUnit("player"))
        while id and id > 0 and not values[id] do
            local info = C_Map.GetMapInfo and public(C_Map.GetMapInfo(id))
            add(id, info and info.name)
            id = info and public(info.parentMapID)
        end
    elseif spec.field == "ClassSpec" then
        for name, id in pairs(APR.Specs or {}) do values[id] = name end
    elseif spec.field == "factionID" and AprRC.ReputationFrame then
        for _, reputation in ipairs(AprRC.ReputationFrame:GetKnownReputations()) do add(reputation.factionID, reputation.name) end
    elseif spec.field == "npcID" or spec.field == "MobId" or spec.field == "MerchantNPC" or spec.field == "DenyNPC" then
        local guid = UnitGUID and public(UnitGUID("target"))
        if type(guid) == "string" then
            local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
            add(tonumber(id), UnitName and UnitName("target"))
        end
    elseif spec.field == "Gossip" or spec.field == "GossipOptionIDs" then
        for _, option in ipairs(public(C_GossipInfo.GetOptions()) or {}) do
            option = public(option)
            if option then add(option.gossipOptionID, option.name) end
        end
    elseif (spec.field == "criteriaID" or spec.field == "criteriaIndex") and context.valueAt then
        local parent = context.valueAt(spec.path:match("^(.*)/[^/]+$")) or {}
        if parent.achievementID and parent.achievementID > 0 and GetAchievementNumCriteria then
            for index = 1, public(GetAchievementNumCriteria(parent.achievementID)) or 0 do
                local name, _, _, _, _, _, _, _, _, id = GetAchievementCriteriaInfo(parent.achievementID, index)
                add(spec.field == "criteriaIndex" and index or id, name)
            end
        end
    end
    return A:ShowAutoComplete(UI.Text("PICKER_SELECT"), values, numeric,
        function(match) return tostring(match.key) .. " - " .. match.value end, 650, 450, true)
end

function Pickers:AddButton(parent, schema, path, context, accept)
    local spec = self:Resolve(schema, path)
    if not spec then return end
    spec.path = path
    local row = UI.Group(parent)
    row:SetLayout("APRPickerActions")
    row:SetUserData("pickerActions", true)
    local button = UI.IconButton(row, "search", "PICKER_SELECT", function()
        local frame = self:Open(spec, context, accept)
        if frame and context.pickerOpened then context.pickerOpened(frame) end
    end)
    button.pickerPath, button.pickerKind = path, spec.kind
    return button
end
