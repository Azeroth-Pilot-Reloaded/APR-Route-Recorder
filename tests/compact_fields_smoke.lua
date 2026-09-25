local UI, E = AprRC.editorUI, AprRC.routeEditor
local GUI = LibStub("AceGUI-3.0")
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end
local function field(path)
    return assert(find(E.inspector or E.routeForm, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function enter(widget, text)
    widget:SetText(text); widget:Fire("OnTextChanged", text)
end
local function toggle(widget, key, checked)
    for _, item in widget.pullout:IterateItems() do
        if item.userdata.value == key then
            item:SetValue(checked); item:Fire("OnValueChanged", checked)
            return
        end
    end
    error("Missing choice: " .. tostring(key))
end
local route = assert(AprRC.editorModel:NewRoute("Compact fields"))
route.steps = { { PickUp = { 42 }, Coord = { x = -4251.46, y = -607.35 }, Zone = 1411,
    Range = 10, Class = "MAGE", ClassNot = { 13 }, Race = { "Orc", "Troll" },
    LootMoney = { copper = 10, equippedSlots = { 1, 3, 5, 6, 7, 8, 9, 10, 15 } } } }
route.parallelSteps = { { conditions = { Class = { "MAGE" }, Race = "Orc" },
    steps = { { Coord = { x = 1, y = 2 }, Zone = 84, Note = "Parallel" } } } }
route.conditions = { Class = 8 }
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
local session = E.session
local initial = AprRC:CopyData(session.draft)

-- Each scalar has one label, no extra titled frame, and actions alongside it.
local quest = field("step/PickUp")
assert(quest.parent.parent.type == "SimpleGroup")
local actions = quest.parent.children[#quest.parent.children]
assert(actions:GetUserData("pickerActions") and #actions.children == 2)
local _, relative, point, _, offset = actions.frame:GetPoint()
assert(point == "TOPRIGHT" and relative == quest.parent.content and offset == 15 - quest.alignoffset)
assert(quest.parent.frame:GetHeight() == quest.frame:GetHeight(), "Valid input has a spare action or validation line")
local zone = field("step/Zone")
local x, y = field("step/Coord/x"), field("step/Coord/y")
assert(x.parent.parent == y.parent.parent and x.parent.parent == zone.parent.parent)
local columns = x.parent.parent
local _, _, _, leftX, topX = x.parent.frame:GetPoint()
local _, _, _, leftY, topY = y.parent.frame:GetPoint()
local _, _, _, leftZone, topZone = zone.parent.frame:GetPoint()
assert(leftX < leftY and leftY < leftZone and topX == topY and topY == topZone)
assert(columns.frame:GetHeight() == 44)
enter(x, "-123.5"); enter(y, "456.75"); enter(zone, "85")
assert(session.draft.steps[1].Coord.x == -123.5 and session.draft.steps[1].Coord.y == 456.75)
assert(session.draft.steps[1].Zone == 85 and route.steps[1].Coord.x == -4251.46)
enter(quest, "invalid")
assert(quest.parent.frame:GetHeight() > quest.frame:GetHeight(), "Validation errors must remain visible")
enter(quest, "42, 84")
assert(quest.parent.frame:GetHeight() == quest.frame:GetHeight())

-- One persistent checkbox menu, no format controls, duplicate aliases or rows.
local classes, races, slots = field("step/Class"), field("step/Race"), field("step/LootMoney/equippedSlots")
assert(classes:GetMultiselect() and races:GetMultiselect() and slots:GetMultiselect())
assert(classes.list[8] and not classes.list.MAGE)
assert(AprRC:DeepCompare(session.draft.steps[1].Class, initial.steps[1].Class))
classes.button:GetScript("OnClick")(classes.button)
assert(classes.open)
toggle(classes, 13, true)
assert(classes.open and #session.draft.steps[1].Class == 2)
assert(tContains(session.draft.steps[1].Class, "MAGE") and tContains(session.draft.steps[1].Class, 13))
toggle(classes, 8, false)
assert(session.draft.steps[1].Class == 13)
GUI:ClearFocus()
toggle(races, "Troll", false)
assert(#session.draft.steps[1].Race == 1 and session.draft.steps[1].Race[1] == "Orc")
toggle(slots, 2, true); toggle(slots, 1, false)
assert(tContains(session.draft.steps[1].LootMoney.equippedSlots, 2))
assert(not tContains(session.draft.steps[1].LootMoney.equippedSlots, 1))
toggle(classes, 13, false)
assert(not AprRC.options:ValidateValue(AprRC.options.schemas.class, session.draft.steps[1].Class))
assert(classes.parent.frame:GetHeight() > classes.frame:GetHeight(), "An empty selection must display its validation error")
toggle(classes, 8, true)
assert(session.draft.steps[1].Class == 8)
assert(E:Save())

-- Route and parallel conditions use the same multi-select and save valid lists.
E:SelectTab("route")
toggle(field("route/conditions/Class"), 13, true)
assert(#session.draft.conditions.Class == 2)
E:SelectTab("parallel"); E.groupConditions:Fire("OnClick")
toggle(field("route/parallelSteps/1/conditions/Race"), "Troll", true)
assert(#session.draft.parallelSteps[1].conditions.Race == 2)
assert(E:Save())
E:Undo(-1) -- Saving resets history, so this must leave the saved values intact.
assert(#session.draft.parallelSteps[1].conditions.Race == 2)
E.list.children[1]:Fire("OnClick")
enter(field("route/parallelSteps/1/steps/1/Coord/x"), "42")
E:Undo(-1)
assert(session.draft.parallelSteps[1].steps[1].Coord.x == 1)
E:Undo(1)
assert(session.draft.parallelSteps[1].steps[1].Coord.x == 42)

-- Columns and action strips must fit when the inspector is resized.
E:SelectTab("steps")
for _, size in ipairs({ { 880, 560 }, { 1120, 780 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    local coord = field("step/Coord/x").parent.parent
    local available = coord.content:GetWidth()
    local used = 12
    for _, child in ipairs(coord.children) do used = used + child.frame:GetWidth() end
    assert(used <= available + 1)
    assert(field("step/PickUp").frame:GetWidth() > 120)
end
E:ToggleCompact()
E.frame:SetWidth(440); E.frame:SetHeight(680); E.frame:DoLayout()
E:ShowStepPane("inspector")
local compactColumns = field("step/Coord/x").parent.parent
assert(compactColumns.frame:GetHeight() == 44)
assert(field("step/Zone").frame:GetWidth() > 40)
E:ToggleCompact()
-- Removing the position clears both fields, and Undo restores them together.
local position = field("step/Coord/x").parent.parent.parent
position.children[2]:Fire("OnClick")
assert(not session.draft.steps[1].Coord and not session.draft.steps[1].Zone)
E:Undo(-1)
assert(session.draft.steps[1].Coord and session.draft.steps[1].Zone == 85)
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Compact scalar actions, coordinate columns, multi-selects, validation and saved drafts passed.")
