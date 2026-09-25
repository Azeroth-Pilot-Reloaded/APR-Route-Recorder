local E, UI, GUI = AprRC.routeEditor, AprRC.editorUI, LibStub("AceGUI-3.0")
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function open(key)
    assert(walk(E.routeForm, function(w) return w:GetUserData("navigateKey") == key end), tostring(key)):Fire("OnClick")
end
local function overview()
    assert(walk(E.routeForm, function(w)
        return w.type == "Button" and w.text:GetText() == UI.Text("Route overview")
    end)):Fire("OnClick")
end
local function field(path)
    return assert(walk(E.routeForm, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function enter(path, text)
    local widget = field(path)
    widget:SetText(text); widget:Fire("OnTextChanged", text)
end
local function button(label)
    return assert(walk(E.routeForm, function(w) return w.type == "Button" and w.text:GetText() == UI.Text(label) end))
end
local function flat()
    assert(not walk(E.routeForm, function(w) return w.type == "InlineGroup" end), "Route forms must not nest framed panels")
    assert(not walk(E.routeForm, function(w)
        return w.type == "Dropdown" and w.label:GetText():find(UI.Text("Format"), 1, true)
    end), "Serialization formats must not be exposed")
    assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
end
local route = assert(AprRC.editorModel:NewRoute("Readable route"))
route.steps = { { Note = "Main" } }
route.requiredRoute = "2393-Previous"
route.XPConsumables = false
route.nextRoute = { "2393-Next", { route = "2393-Conditional", conditions = {
    ClassNot = "MAGE", AnyOf = { { AnyOf = { { ClassNot = "EVOKER" } } }, { Race = "Orc" } },
} } }
route.prefab = { [APR.PREFAB_TYPES.Speedrun] = 10 }
local source = AprRC:CopyData(route)
E:Show(); E:SelectRoute(route.name); E:SelectTab("route")
local session = E.session
flat()
assert(not session:IsDirty() and type(session.draft.requiredRoute) == "string")
enter("route/requiredRoute", "2393-Previous\n2393-Other")
assert(#session.draft.requiredRoute == 2)
local xp = assert(walk(E.routeForm, function(w) return w.type == "Dropdown" and w.list[false] end))
xp:Fire("OnValueChanged", "MidnightDelves")
assert(session.draft.XPConsumables == "MidnightDelves")
xp:Fire("OnValueChanged", false)
assert(session.draft.XPConsumables == false)

open("nextRoute"); flat()
open(1); flat()
assert(session.draft.nextRoute[1] == "2393-Next", "Navigation must not materialize a legacy scalar")
enter("route/nextRoute/1/route", "2393-Renamed")
assert(session.draft.nextRoute[1].route == "2393-Renamed" and next(session.draft.nextRoute[1].conditions) == nil)
E:Undo(-1)
assert(session.draft.nextRoute[1] == "2393-Next")
assert(field("route/nextRoute/1/route"):GetText() == "2393-Next")
E:Undo(1)
assert(field("route/nextRoute/1/route"):GetText() == "2393-Renamed")
overview(); open("nextRoute"); open(2); open("conditions"); flat()
assert(field("route/nextRoute/2/conditions/ClassNot"):GetMultiselect())
open("AnyOf"); open(1); open("AnyOf"); open(1); flat()
local excluded = field("route/nextRoute/2/conditions/AnyOf/1/AnyOf/1/ClassNot")
excluded:Fire("OnValueChanged", 8, true)
local nested = session.draft.nextRoute[2].conditions.AnyOf[1].AnyOf[1]
assert(tContains(nested.ClassNot, "EVOKER") and tContains(nested.ClassNot, 8))
assert(session.draft.nextRoute[2].conditions.AnyOf[2].Race == "Orc")
assert(session.draft.nextRoute[2].conditions.ClassNot == "MAGE")
assert(AprRC:DeepCompare(source, route), "Route form edits touched the source")
assert(E:Save())
assert(AprRC:FindRouteByName(route.name).nextRoute[2].conditions.AnyOf[1].AnyOf[1].ClassNot[1])
flat()

-- Prefabs use one object form instead of numeric/object format selectors.
overview(); open("prefab"); open(APR.PREFAB_TYPES.Speedrun); flat()
assert(session.draft.prefab[APR.PREFAB_TYPES.Speedrun] == 10)
enter("route/prefab/" .. APR.PREFAB_TYPES.Speedrun .. "/index", "20")
assert(session.draft.prefab[APR.PREFAB_TYPES.Speedrun].index == 20)
overview(); open("nextRoute")
button("Add entry"):Fire("OnClick")
assert(type(session.draft.nextRoute[3]) == "table" and session.draft.nextRoute[3].conditions)
open(3)
enter("route/nextRoute/3/route", "2393-Third")
E:Undo(-1); E:Undo(-1)
assert(#session.draft.nextRoute == 2 and #E.routeFormTrail == 1, "Undo must fall back when the open entry disappears")
flat()

-- Re-resolve navigation after replacing the complete draft in Lua.
E:SelectTab("lua")
E.luaBox:SetText('{ steps = {}, label = "New definition" }')
E.luaBox:Fire("OnTextChanged", '{ steps = {}, label = "New definition" }')
E:SelectTab("route")
assert(#E.routeFormTrail == 0 and field("route/label"):GetText() == "New definition")
flat()
for _, size in ipairs({ { 880, 560 }, { 1120, 780 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    assert(E.routeForm.frame:GetHeight() > 100)
end
E:ToggleCompact(); E.frame:SetWidth(440); E.frame:SetHeight(680); E.frame:DoLayout(); flat()
E:ToggleCompact(); E:Hide()

-- Same visual representation for scalar and list inputs, with no mutation on render.
local holder = GUI:Create("SimpleGroup")
holder:SetWidth(500); holder:SetLayout("Flow")
local value = "2393-Previous"
local context = { modes = {}, pages = {}, changed = function() end, redraw = function() end, error = error }
UI.Form:Render(holder, AprRC.options.schemas.routeLinks, value, function(entry) value = entry end,
    context, "requiredRoute", "Routes")
assert(value == "2393-Previous" and not walk(holder, function(w) return w.type == "Dropdown" end))
local text = assert(walk(holder, function(w) return w.type == "MultiLineEditBox" end))
text:Fire("OnTextChanged", "2393-Only")
assert(type(value) == "table" and value[1] == "2393-Only")
GUI:Release(holder)
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Route overview, bounded nesting, unified forms, legacy values, undo and Lua replacement passed.")
