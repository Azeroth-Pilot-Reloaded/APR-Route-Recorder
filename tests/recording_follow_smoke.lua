local E, Model = AprRC.routeEditor, AprRC.editorModel
local route = assert(Model:NewRoute("Live recording refresh"))
for index = 1, 85 do route.steps[index] = { Note = "Recorded step " .. index } end
AprRCData.CurrentRoute = route
AprRC.settings.profile.enableAddon = true
AprRC.settings.profile.recordBarFrame.isRecording = true
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.follow = false
E.session.selected = 1
E.page = 1
E:DrawTab()

-- The actual slash command refreshes a clean list without follow enabled.
AprRC.command:SlashCmd("note Live slash command")
TestRunTimers()
assert(E.session.draft.steps[#route.steps].Note == "Live slash command")
assert(E.session.selected == 1 and E.page == 1)

-- Commands dispatched by native toolbar buttons take the same refresh path.
AprRCData.CommandBarCommands = { { command = "note" } }
AprRC.CommandBar:RefreshFrameAnchor()
AprRC.CommandBar.btnList[1]:GetScript("OnMouseDown")(AprRC.CommandBar.btnList[1])
AprRC.CommandBar.btnList[1]:GetScript("OnClick")(AprRC.CommandBar.btnList[1])
-- Submit the registry command dialog through its Apply callback.
local dialog
for _, native in ipairs(UIParent.children) do
    local widget = native.obj
    if widget and widget.type == "Frame" and native:IsShown() and widget ~= E.frame then
        for _, child in ipairs(widget.children or {}) do
            if child.type == "MultiLineEditBox" then dialog = widget; child:SetText("Toolbar note") end
        end
    end
end
assert(dialog, "Toolbar note must open a command dialog")
for _, child in ipairs(dialog.children) do
    if child.type == "Button" then child:Fire("OnClick"); break end
end
TestRunTimers()
assert(E.session.draft.steps[#route.steps].Note == "Toolbar note")
assert(E.session.selected == 1)

-- Legacy popup callbacks can change an existing step without calling UpdateRoute.
StaticPopupDialogs = {}
StaticPopup_Show = function() end
AprRC.questionDialog:CreateEditBoxPopupWithCallback("Legacy input", function(value)
    route.steps[#route.steps].Note = value
end)
StaticPopupDialogs.APRRC_EDITBOX_DIALOG.OnAccept({
    GetEditBox = function() return { GetText = function() return "Legacy popup note" end } end,
})
TestRunTimers()
assert(E.session.draft.steps[#route.steps].Note == "Legacy popup note")

-- Follow always goes to the last page, even after selecting an older step/filter.
E.follow = true
E.query, E.filter = "no matching steps", "quests"
AprRC:NewStep({ Note = "Capture at end" })
TestRunTimers()
assert(E.session.selected == #route.steps and E.page == math.ceil(#route.steps / 40))
assert(E.query == "" and E.filter == "all")
assert(E.list.localstatus.scrollvalue == 1000)
assert(E.session.draft.steps[E.session.selected].Note == "Capture at end")

-- In-place updates also refresh and follow, without adding a new step.
E.session.selected = 1
AprRC.command:SlashCmd("noarrow true")
TestRunTimers()
assert(E.session.selected == #route.steps and E.session.draft.steps[#route.steps].NoArrow)

-- Clean Lua viewing may retain focus while following capture to the end.
E:SelectTab("lua")
E.luaBox.editBox:SetFocus()
AprRC:NewStep({ Note = "Visible in Lua" })
TestRunTimers(); TestRunTimers()
assert(E.luaBox:GetText():find("Visible in Lua", 1, true))
assert(E.luaBox.editBox:HasFocus())
assert(E.luaBox.editBox:GetCursorPosition() == #E.luaBox:GetText())
assert(E.session.selected == #route.steps and not E.session:IsDirty())

-- Unsaved Lua is never overwritten, including incomplete syntax.
local raw = "{ steps = { -- unfinished"
E.luaBox:SetText(raw)
E.luaBox:Fire("OnTextChanged", raw)
AprRC:NewStep({ Note = "Capture while editing" })
TestRunTimers()
assert(E.luaBox:GetText() == raw and E.session.raw == raw)
E.session:Reload(); E.luaBox.editBox:ClearFocus(); E:DrawTab()

-- No-follow Lua refresh preserves position while updating the contents.
E.follow = false
E.luaBox.editBox:ClearFocus()
E.luaBox.editBox:SetCursorPosition(12)
E.luaBox.scrollFrame:SetVerticalScroll(30)
AprRC.command:SlashCmd("note Lua without following")
TestRunTimers()
assert(E.luaBox:GetText():find("Lua without following", 1, true))
assert(E.luaBox.editBox:GetCursorPosition() == 12)
assert(E.luaBox.scrollFrame:GetVerticalScroll() == 30)

-- Visual draft edits update the list immediately and survive capture.
E:SelectTab("steps")
E.session.draft.steps[1].Note = "Local visual edit"
E:Changed()
AprRC:NewStep({ Note = "Keep local draft" })
TestRunTimers()
assert(E.session.draft.steps[1].Note == "Local visual edit" and E.session:IsDirty())
assert(#E.session.draft.steps == #route.steps - 1)
E.session:Reload()
E.follow = true
E.session.selected = 1
E:Tick(true)
assert(E.session.selected == #route.steps)
E:Hide(); TestRunTimers()
AprRC.settings.profile.recordBarFrame.isRecording = false
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Live command refresh, last-step following, Lua cursor/scroll and draft protection passed.")
