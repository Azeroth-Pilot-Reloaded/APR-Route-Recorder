local E = AprRC.routeEditor
local route = assert(AprRC.editorModel:NewRoute("Compact test"))
route.steps = { { Note = "First" }, { Note = "Second" }, { RouteCompleted = true } }
E:Show()
E:SelectRoute(route.name)
E:SelectTab("steps")
E.frame:SetWidth(1120)
E.frame:SetHeight(780)
E.session.draft.steps[1].Note = "Unsaved edit"
E:Changed()
local session = E.session
E.compactButton:Fire("OnClick")
assert(E.compact and E.frame.frame:GetWidth() == 560)
assert(E.session == session and session.draft.steps[1].Note == "Unsaved edit")
assert(E.stepsSplit.children[1].frame:IsShown() and not E.stepsSplit.children[2].frame:IsShown())
assert(E.listPanel.frame:GetWidth() == E.stepsSplit.content:GetWidth(), "Compact view must give the list the whole width")
E.list.children[2]:Fire("OnClick")
assert(session.selected == 2 and E.compactPane == "inspector")
assert(not E.stepsSplit.children[1].frame:IsShown() and E.stepsSplit.children[2].frame:IsShown())
E:ShowStepPane("list")
assert(E.stepsSplit.children[1].frame:IsShown())

local function fits(group)
    local used = math.max(0, #group.children - 1) * 8
    for _, child in ipairs(group.children) do used = used + child.frame:GetHeight() end
    assert(used <= group.content:GetHeight() + 1,
        "Compact controls overlap: " .. used .. " > " .. group.content:GetHeight())
end
for _, size in ipairs({ { 560, 780 }, { 440, 680 }, { 700, 900 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    fits(E.frame)
    E:ShowStepPane("list"); fits(E.listPanel)
    E:ShowStepPane("inspector"); fits(E.inspector.parent)
    for _, tab in ipairs({ "route", "lua", "commands", "tools", "steps" }) do
        E:SelectTab(tab)
        fits(E.frame)
        assert(E.tabs.frame:GetWidth() > 360 and E.tabs.frame:GetHeight() > 100)
        assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
    end
end
E.frame:SetWidth(560)
E:Hide()
E:Show()
assert(E.compact and E.frame.frame:GetWidth() == 560, "Compact mode must survive reopening")
assert(E.session.draft.steps[1].Note == "Unsaved edit")
E:SelectTab("lua")
E.luaBox:SetText("{ steps = {")
E.luaBox:Fire("OnTextChanged", "{ steps = {")
E:ToggleCompact()
assert(not E.compact and E.frame.frame:GetWidth() == 1120)
assert(E.session.raw == "{ steps = {" and E.luaBox:GetText() == "{ steps = {", "Changing width lost invalid Lua draft")
E:SelectTab("steps")
assert(E.tab == "lua", "Compact controls must not bypass Lua validation")
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Half-width layout, pane switching, draft retention and persisted size checks passed.")
