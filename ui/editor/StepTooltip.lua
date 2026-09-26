local UI = AprRC.editorUI
local Model = AprRC.editorModel
local R = AprRC.options
local active

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) == "number" and type(b) == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function scalar(key, value, schema)
    if key == "copper" then return Model:MoneyText(value) end
    if key == "Class" or key == "ClassNot" or key == "Race" then return UI.ConditionIdentityText(key, value) end
    if key == "itemID" or key == "itemIDs" then return Model:ItemText(value) end
    if key == "HasSpell" or key == "DontHaveSpell" or key == "HasAura" or key == "DontHaveAura" then
        return Model:SpellText(value)
    end
    if type(value) == "boolean" then return (value and YES or NO) or tostring(value) end
    local choices = UI.Form:MultiChoices(schema, "tooltip", true)
    if choices and choices[value] then return choices[value] end
    return tostring(value)
end

-- Preserve every field and the branches of logical groups, including false/zero.
function UI.ConditionTooltipLines(step, groupConditions)
    local lines = {}
    local function visit(key, value, schema, depth, label)
        if depth > 40 then return end
        local left = string.rep("  ", depth) .. (label or UI.Label(key))
        if type(value) ~= "table" then
            lines[#lines + 1] = { left = left, right = scalar(key, value, schema) }
            return
        end
        local keys, flat = sortedKeys(value), true
        for _, child in ipairs(keys) do
            if type(child) ~= "number" or type(value[child]) == "table" then flat = false; break end
        end
        if flat then
            local values = {}
            for _, child in ipairs(keys) do values[#values + 1] = scalar(key, value[child], schema) end
            lines[#lines + 1] = { left = left, right = #values > 0 and table.concat(values, ", ") or "{}" }
            return
        end
        lines[#lines + 1] = { left = left }
        for _, child in ipairs(keys) do
            local definition = R.step[child]
            local childSchema = type(schema) == "table" and (schema.fields and schema.fields[child] or schema.entry)
                or definition and definition.schema
            local childLabel = type(child) == "number" and (UI.Text("Condition group") .. " " .. child) or nil
            if child == "copper" then childLabel = UI.Label("Money") end
            if key == "Skill" and (child == "skill" or child == "skillID" or child == "name") then
                lines[#lines + 1] = { left = string.rep("  ", depth + 1) .. UI.Label(child), right = Model:SkillText(value) }
            else visit(child, value[child], childSchema, depth + 1, childLabel) end
        end
    end
    for _, source in ipairs({ { step, UI.Text("Conditions") }, { groupConditions, UI.Text("Group conditions") } }) do
        local fields = {}
        for key in pairs(source[1] or {}) do
            if R.step[key] and R.step[key].condition then fields[#fields + 1] = key end
        end
        table.sort(fields)
        if #fields > 0 then
            lines[#lines + 1] = { section = source[2] }
            for _, key in ipairs(fields) do visit(key, source[1][key], R.step[key].schema, 0) end
        end
    end
    return lines
end

local function clear(tooltip)
    active = nil
    for _, texture in ipairs(tooltip.aprrcConditionSeparators or {}) do texture:Hide() end
    tooltip.aprrcConditionSeparatorCount = 0
end

-- Match Diogenator's one-pixel divider, section colors and label/value colors.
local function separator(tooltip)
    AprRC:AddTooltipLine(tooltip, " ")
    local name = tooltip:GetName()
    local line = name and _G[name .. "TextLeft" .. tooltip:NumLines()]
    if not line then return end
    local index = (tooltip.aprrcConditionSeparatorCount or 0) + 1
    tooltip.aprrcConditionSeparatorCount = index
    tooltip.aprrcConditionSeparators = tooltip.aprrcConditionSeparators or {}
    local texture = tooltip.aprrcConditionSeparators[index] or tooltip:CreateTexture(nil, "ARTWORK")
    tooltip.aprrcConditionSeparators[index] = texture
    texture:ClearAllPoints()
    texture:SetPoint("LEFT", line, "LEFT", 0, 0)
    texture:SetPoint("RIGHT", tooltip, "RIGHT", -12, 0)
    texture:SetHeight(1)
    texture:SetColorTexture(0.18, 0.25, 0.32, 1)
    texture:Show()
end

local function render(data)
    local tooltip = GameTooltip
    tooltip:ClearLines()
    AprRC:AddTooltipLine(tooltip, data.title, 1, 0.82, 0.4)
    if data.detail ~= "" then AprRC:AddTooltipLine(tooltip, data.detail, 1, 1, 1, true) end
    if data.metadata ~= "" then AprRC:AddTooltipLine(tooltip, data.metadata, 0.7, 0.7, 0.7, true) end
    local lines = UI.ConditionTooltipLines(data.step, data.conditions)
    if #lines > 0 then
        if IsControlKeyDown() then
            for _, line in ipairs(lines) do
                if line.section then
                    separator(tooltip)
                    AprRC:AddTooltipLine(tooltip, line.section, 0.22, 0.79, 1)
                else
                    tooltip:AddDoubleLine(line.left, line.right or "", 0.65, 0.82, 0.95, 1, 1, 1)
                    AprRC.textStyle:TooltipLine(tooltip)
                end
            end
        else
            AprRC:AddTooltipLine(tooltip, UI.Text("Ctrl: condition details"), 0.50, 0.68, 0.79)
        end
    end
    active = data
    tooltip:Show()
end

function UI.ShowStepTooltip(row, title, detail, metadata, step, conditions)
    local tooltip = GameTooltip
    if not tooltip.aprrcConditionHooks then
        tooltip.aprrcConditionHooks = true
        tooltip:HookScript("OnHide", clear)
        tooltip:HookScript("OnTooltipCleared", clear)
    end
    tooltip:SetOwner(row.frame, "ANCHOR_RIGHT")
    render({ row = row, title = title, detail = detail, metadata = metadata, step = step, conditions = conditions })
end

function UI.HideStepTooltip(row)
    if active and active.row == row then
        if GameTooltip:IsOwned(row.frame) then GameTooltip:Hide() else clear(GameTooltip) end
    end
end

local modifiers = CreateFrame("Frame")
modifiers:RegisterEvent("MODIFIER_STATE_CHANGED")
modifiers:SetScript("OnEvent", function(_, _, key)
    if key ~= "LCTRL" and key ~= "RCTRL" then return end
    if active and GameTooltip:IsShown() and GameTooltip:IsOwned(active.row.frame) and active.row.frame:IsShown() then
        render(active)
    elseif active then clear(GameTooltip) end
end)
