local E = AprRC.routeEditor
local GUI = LibStub("AceGUI-3.0")
local originalPrint = print
print = function() end
AprRC.options:PrintHelp()
print = originalPrint
local function healthy()
    assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
end
local function walk(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function input(label)
    return assert(walk(E.frame, function(w)
        return (w.type == "EditBox" or w.type == "MultiLineEditBox") and w.label:GetText() == label
    end), "Missing input " .. label)
end
local function enter(widget, text)
    widget:SetText(text)
    widget:Fire("OnTextChanged", text)
end

-- First-use behavior has its own lifecycle test; keep this pooling test to one window.
AprRCData = { CurrentRoute = { name = "", steps = {} }, Routes = {}, QuestLookup = {}, TutorialSeen = true }
E:Show()
healthy()
assert(not E.session, "A placeholder route should show the empty state")
assert(E.timer and not E.luaBox)
E:Show() -- Reopening must reuse the window and its timer.
local frame = E.frame
E:Hide()
healthy()
assert(not E.timer and not E.frame)
local route = assert(AprRC.editorModel:NewRoute("UI test"))
route.steps = { { PickUp = { 42 }, Coord = { x = 100, y = -200 }, Zone = 2393 },
    { Qpart = { [42] = { 1, 2 } }, ExtraLineText = "Bridge" }, { RouteCompleted = true } }
route.label, route.XPConsumables = "Test route", false
route.parallelSteps = { { conditions = { HasSpell = 42 }, steps = { { Note = "Parallel" } } } }
E:Show()
healthy()
assert(E.frame == frame, "Expected pooled AceGUI frame reuse")
assert(E.session and #E.list.children == 3)
E:SelectTab("route")
healthy()
assert(E.routeForm)
enter(input(AprRC.editorUI.Label("label")), "Edited display name")
assert(E.session.draft.label == "Edited display name" and route.label == "Test route")
E:SelectTab("steps")
healthy()
assert(E.session:IsDirty())
E:Undo(-1)
assert(E.session.draft.label == "Test route")
E:Undo(1)
assert(E.session.draft.label == "Edited display name")
E:SelectTab("lua")
healthy()
local box = E.luaBox
local originalScript = E.luaKeyDown
enter(box, "{ steps = {")
E:SelectTab("steps")
healthy()
assert(E.tab == "lua" and E.session.raw == "{ steps = {", "Invalid Lua must remain recoverable")
E:Hide()
healthy()
assert(box.editBox:GetScript("OnKeyDown") == originalScript, "Leaked Lua key handler into AceGUI pool")
assert(not AprRC.export.editbox and not E.timer)
E:Show()
healthy()
assert(E.tab == "lua" and E.luaBox:GetText() == "{ steps = {")
enter(E.luaBox, '{ { Note = "Imported" } }')
E:SelectTab("steps")
healthy()
assert(E.session.draft.steps[1].Note == "Imported")
assert(E.session.draft.label == "Edited display name" and E.session.draft.XPConsumables == false)
assert(E:Save())
healthy()
TestRunTimers()
assert(not E.exportButton and E.importButton)
assert(APRData.CustomRoute[route.name .. " - Custom"].steps[1].Note == "Imported")
E:ToggleRecording()
assert(AprRCData.CurrentRoute.name == route.name and AprRC.settings.profile.recordBarFrame.isRecording)
E:ToggleRecording()
assert(not AprRC.settings.profile.recordBarFrame.isRecording)

-- Refresh a clean draft, but preserve a dirty draft across a live append.
E.follow = false
E:SelectTab("lua")
E.luaBox.editBox:SetFocus()
table.insert(AprRCData.CurrentRoute.steps, { Done = { 42 } })
E:Refresh()
assert(#E.session.draft.steps == 1, "Live refresh interrupted a focused editor")
E.luaBox.editBox:ClearFocus()
E:SelectTab("steps")
E:Tick()
healthy()
assert(#E.session.draft.steps == 2)
E.follow = true
E.session.draft.steps[1].Note = "Draft"
E:Changed()
table.insert(AprRCData.CurrentRoute.steps, { Waypoint = 42 })
E:Tick()
assert(#E.session.draft.steps == 2 and not E:Save())
assert(#AprRCData.CurrentRoute.steps == 3)
E:SelectTab("tools")
healthy()
local longRoute = assert(AprRC.editorModel:NewRoute("Long route"))
for index = 1, 125 do longRoute.steps[index] = { Note = "Step " .. index } end
E:Refresh()
E:SelectRoute(longRoute.name)
E:SelectTab("steps")
assert(#E.list.children == 40)
E.nextButton:Fire("OnClick")
assert(E.page == 2 and #E.list.children == 40)
E.nextButton:Fire("OnClick")
E.nextButton:Fire("OnClick")
assert(E.page == 4 and #E.list.children == 5 and E.nextButton.disabled)
E.query = "Step 125"
E:DrawList()
assert(#E.list.children == 1)
E.list.children[1]:Fire("OnClick")
assert(E.session.selected == 125)
for _, size in ipairs({ { 1120, 780 }, { 880, 560 }, { 1400, 900 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    assert(E.tabs.frame:GetWidth() > 800 and E.tabs.frame:GetHeight() > 100)
    assert(E.list.frame:GetHeight() > 0 and E.inspector.frame:GetHeight() > 0)
    for _, group in ipairs({ E.frame, E.listPanel, E.inspector.parent }) do
        local used = math.max(0, #group.children - 1) * 8
        local sizes = {}
        for _, child in ipairs(group.children) do
            used = used + child.frame:GetHeight()
            sizes[#sizes + 1] = child.type .. ":" .. child.frame:GetWidth() .. "x" .. child.frame:GetHeight()
        end
        assert(used <= group.content:GetHeight() + 1,
            "Toolbars overlap body at " .. size[1] .. "x" .. size[2] .. ": " .. used .. " > " .. group.content:GetHeight() .. " / " .. table.concat(sizes, ", "))
    end
    healthy()
end
E:Hide()
healthy()

-- Every registered field's example can be displayed without changing its data.
local holder = GUI:Create("ScrollFrame")
holder:SetWidth(520)
holder:SetHeight(600)
holder:SetLayout("Flow")
local changed = false
for _, definitions in ipairs({ AprRC.options.step, AprRC.options.route }) do
    for key, definition in pairs(definitions) do
        local value, reason = AprRC.options:Parse(definition, definition.example)
        assert(value ~= nil, reason)
        local original = AprRC:CopyData(value)
        AprRC.editorUI.Form:Render(holder, definition.schema, value, function() changed = true end,
            { modes = {}, pages = {}, changed = function() changed = true end, redraw = function() end, error = error }, key, key)
        healthy()
        assert(AprRC:DeepCompare(value, original) and not changed, "Rendering changed " .. key)
        holder:ReleaseChildren()
    end
end
-- Structured XP is editable through numeric fields, and changing format preserves
-- the chosen profile rather than flattening a table into an empty text input.
local formValue = { level = 4, xp = -700 }
local formContext = { modes = {}, pages = {}, changed = function() end, redraw = function() end, error = error }
local function renderLevel()
    holder:ReleaseChildren()
    AprRC.editorUI.Form:Render(holder, "level", formValue, function(value) formValue = value end,
        formContext, "requirement", "Requirement")
end
renderLevel()
local xp = assert(walk(holder, function(widget)
    return widget.type == "EditBox" and widget.label:GetText() == AprRC.editorUI.Label("xp")
end))
enter(xp, "-325")
assert(formValue.xp == -325 and formValue.level == 4)
local format = assert(walk(holder, function(widget) return widget.type == "Dropdown" end))
format:Fire("OnValueChanged", 2)
renderLevel()
local profile = assert(walk(holder, function(widget)
    return widget.type == "Dropdown" and widget.label:GetText() == "Requirement"
end))
profile:Fire("OnValueChanged", 1)
assert(formValue == "MidnightDelves")
healthy()

-- Prefab keys come from APR's enum, including the nested conditional format.
holder:ReleaseChildren()
local prefabs = {}
AprRC.editorUI.Form:Render(holder, AprRC.options.schemas.prefab, prefabs, function(value) prefabs = value end,
    { modes = {}, pages = {}, changed = function() end, redraw = function() end, error = error }, "prefab", "Prefab")
local choice = assert(walk(holder, function(widget) return widget.type == "Dropdown" end))
choice:Fire("OnValueChanged", APR.PREFAB_TYPES.Speedrun)
local add = assert(walk(holder, function(widget)
    return widget.type == "Button" and widget.text:GetText() == AprRC.editorUI.Text("Add entry")
end))
add:Fire("OnClick")
assert(prefabs[APR.PREFAB_TYPES.Speedrun] ~= nil)
healthy()
GUI:Release(holder)
healthy()
print("Real AceGUI workspace, form coverage, pooling and callback smoke tests passed.")
