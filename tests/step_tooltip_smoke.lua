local E, UI = AprRC.routeEditor, AprRC.editorUI
local oldControl = IsControlKeyDown
local control = false
IsControlKeyDown = function() return control end
local function modifier(pressed, key)
    control = pressed
    TestEvent("MODIFIER_STATE_CHANGED", key or "LCTRL", pressed and 1 or 0)
end
local function text()
    local lines = {}
    for index = 1, GameTooltip:NumLines() do
        local left = _G["GameTooltipTextLeft" .. index]
        local right = _G["GameTooltipTextRight" .. index]
        lines[#lines + 1] = (left and left:GetText() or "") .. " " .. (right and right:GetText() or "")
    end
    return table.concat(lines, "\n")
end
local route = assert(AprRC.editorModel:NewRoute("Tooltip conditions"))
route.steps = {
    { Note = "Tooltip step", Hardcore = false, Class = { 8 },
        AnyOf = { { Money = { operator = ">=", copper = 12345 } },
            { AllOf = { { Not = { HasSpell = 6673 } }, { MinLevel = 0 } } } } },
    { Note = "Plain step" },
}
route.parallelSteps = { { conditions = { Race = { "Orc" }, Not = { ItemCount = { itemIDs = { 12, 34 }, count = 2 } } },
    steps = { { Note = "Parallel step", Faction = "Horde" } } } }
local original = AprRC:SerializeData(route)
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
local row = E.list.children[1]
row:Fire("OnEnter")
assert(GameTooltip:IsOwned(row.frame))
assert(text():find(UI.Text("Ctrl: condition details"), 1, true))
assert(text():find("3 " .. UI.Text("Conditions"), 1, true))
assert((GameTooltip.aprrcConditionSeparatorCount or 0) == 0)
modifier(true)
assert(not text():find(UI.Text("Ctrl: condition details"), 1, true))
assert(text():find(UI.Label("Hardcore"), 1, true) and text():find(NO or "false", 1, true))
for _, key in ipairs({ "AnyOf", "AllOf", "Not", "HasSpell", "MinLevel" }) do
    assert(text():find(UI.Label(key), 1, true), key)
end
assert(text():find(UI.Text("Condition group") .. " 2", 1, true))
assert(text():find("1|TInterface\\MoneyFrame\\UI-GoldIcon", 1, true))
assert(text():find("0", 1, true))
local count = GameTooltip:NumLines()
local divider = GameTooltip.aprrcConditionSeparators[1]
assert(divider:IsShown() and divider:GetHeight() == 1)
assert(divider.rgba[1] == 0.18 and divider.rgba[2] == 0.25 and divider.rgba[3] == 0.32)
modifier(true, "RCTRL")
assert(GameTooltip:NumLines() == count and #GameTooltip.aprrcConditionSeparators == 1)
modifier(false)
assert(not divider:IsShown() and GameTooltip.aprrcConditionSeparatorCount == 0)
assert(text():find(UI.Text("Ctrl: condition details"), 1, true))
assert(GameTooltip:NumLines() < count)

-- Both pre-held Ctrl and group conditions work on the parallel step list.
control = true
E:SelectTab("parallel")
local parallel = E.list.children[1]
parallel:Fire("OnEnter")
assert(GameTooltip.aprrcConditionSeparatorCount == 2)
assert(text():find(UI.Text("Group conditions"), 1, true))
assert(text():find(UI.Label("Race"), 1, true) and text():find(UI.Label("ItemCount"), 1, true))
assert(text():find(UI.Label("Faction"), 1, true))
parallel.frame:GetScript("OnLeave")()
assert(not GameTooltip:IsShown())
modifier(false)
assert(not GameTooltip:IsShown(), "Modifier changes must not reopen closed tooltips")
for _, texture in ipairs(GameTooltip.aprrcConditionSeparators) do assert(not texture:IsShown()) end

E:SelectTab("steps")
control = true
E.list.children[2]:Fire("OnEnter")
assert(GameTooltip.aprrcConditionSeparatorCount == 0)
assert(not text():find(UI.Text("Ctrl: condition details"), 1, true))
E.list.children[1]:Fire("OnEnter")
local other = CreateFrame("Frame")
GameTooltip:SetOwner(other, "ANCHOR_RIGHT")
GameTooltip:ClearLines()
GameTooltip:AddLine("Other tooltip")
modifier(false)
assert(text():find("Other tooltip", 1, true) and GameTooltip:NumLines() == 1)
assert(not divider:IsShown(), "Separators must not leak into unrelated tooltips")
E.list.children[1]:Fire("OnEnter")
E:DrawList()
modifier(true)
assert(not GameTooltip:IsShown(), "Released rows must not retain modifier callbacks")
assert(AprRC:SerializeData(route) == original and not E.session:IsDirty())
E:Hide()
IsControlKeyDown = oldControl
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Ctrl step tooltips: nested/group conditions, live modifiers, Diogenator dividers and tooltip cleanup passed.")
