local E = AprRC.routeEditor
local GUI = LibStub("AceGUI-3.0")
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

AprRCData = { CurrentRoute = { name = "", steps = {} }, Routes = {}, QuestLookup = {} }
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
E:Export()
assert(APRData.CustomRoute[route.name .. " - Custom"].steps[1].Note == "Imported")
E:ToggleRecording()
assert(AprRCData.CurrentRoute.name == route.name and AprRC.settings.profile.recordBarFrame.isRecording)
E:ToggleRecording()
assert(not AprRC.settings.profile.recordBarFrame.isRecording)

-- Refresh a clean draft, but preserve a dirty draft across a live append.
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
        local value = assert(AprRC.options:Parse(definition, definition.example))
        local original = AprRC:CopyData(value)
        AprRC.editorUI.Form:Render(holder, definition.schema, value, function() changed = true end,
            { modes = {}, pages = {}, changed = function() changed = true end, redraw = function() end, error = error }, key, key)
        healthy()
        assert(AprRC:DeepCompare(value, original) and not changed, "Rendering changed " .. key)
        holder:ReleaseChildren()
    end
end
GUI:Release(holder)
healthy()
print("Real AceGUI workspace, form coverage, pooling and callback smoke tests passed.")
