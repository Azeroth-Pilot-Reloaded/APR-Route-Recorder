-- Run in a fresh UI runtime so first construction is tested in combat too.
local E, UI, GUI = AprRC.routeEditor, AprRC.editorUI, LibStub("AceGUI-3.0")
local route = assert(AprRC.editorModel:NewRoute("Keyboard combat regression"))
route.steps = { { Note = "First" }, { Note = "Second" } }
AprRCData.CurrentRoute, AprRCData.TutorialSeen = route, true
local oldSave, oldControl, oldMeta = E.Save, IsControlKeyDown, IsMetaKeyDown
local saves = 0
E.Save = function(self) saves = saves + 1; return oldSave(self) end
local function key(frame, value, control, meta)
    IsControlKeyDown = function() return control == true end
    IsMetaKeyDown = function() return meta == true end
    local callback = assert(frame:GetScript("OnKeyDown"))
    callback(frame, value)
    IsControlKeyDown, IsMetaKeyDown = oldControl, oldMeta
end
local function combat(enabled)
    TestCombatLockdown = enabled
    TestEvent(enabled and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end
local function healthy() assert(#UIErrors == 0, table.concat(UIErrors, "\n")) end
local function closed(frame)
    assert(not frame.keyboardEnabled and not frame:GetScript("OnKeyDown") and not frame:GetScript("OnEvent"))
end

-- Original launcher stack: first-ever window and both view constructors in combat.
combat(true)
local launcher = AprRC.record.frame
launcher:GetScript("OnClick")(launcher)
assert(E.frame and not E.saveKeyboard.keyboardEnabled)
local window, save = E.frame, E.saveKeyboard
local steps = E.stepsSplit.frame
assert(not steps.keyboardEnabled)
key(save, "S", true); key(steps, "DOWN")
assert(saves == 0 and E:SelectedStep() == 1)
E:SelectTab("lua")
local lua = E.luaBox.keyboardFrame
assert(not lua.keyboardEnabled)
key(lua, "S", true)
assert(saves == 0)
E:Show() -- Visible-window fast path must keep the same disabled listener.
assert(E.frame == window and E.saveKeyboard == save and not save.keyboardEnabled)
healthy()

combat(false)
assert(save.keyboardEnabled and save.propagateKeyboardInput)
assert(lua.keyboardEnabled and lua.propagateKeyboardInput)
E.luaBox:SetFocus()
key(save, "s", true)
assert(saves == 1 and not save.propagateKeyboardInput)
key(save, "W")
assert(save.propagateKeyboardInput)
key(save, "S", false, true)
assert(saves == 2 and not save.propagateKeyboardInput)
key(save, "S")
assert(saves == 2 and save.propagateKeyboardInput)
local outside = CreateFrame("EditBox", nil, UIParent)
outside:SetFocus(); key(save, "S", true)
assert(saves == 2 and save.propagateKeyboardInput)
outside:ClearFocus()
key(save, "S", true) -- No focused field, as in the Steps/Route tabs.
assert(saves == 3 and not save.propagateKeyboardInput)

-- A consumed key immediately before combat must never leave input captured.
combat(true)
assert(not save.keyboardEnabled and not lua.keyboardEnabled)
key(save, "S", true); key(lua, "S", true)
assert(saves == 3)
-- Releasing the Lua widget and split groups in combat must not reset propagation.
E:SelectTab("steps"); closed(lua)
steps = E.stepsSplit.frame
assert(not steps.keyboardEnabled)
E:SelectTab("lua"); closed(steps)
assert(not E.luaBox.keyboardFrame.keyboardEnabled)
lua = E.luaBox.keyboardFrame
TestCloseWorkshop(); closed(save); closed(lua)
assert(not E.frame)
combat(false)
assert(not save.keyboardEnabled, "Combat end must not resurrect a closed editor")
healthy()

-- AceGUI may lend the native window to an unrelated dialog before it is reused.
local borrowed = GUI:Create("Frame")
assert(borrowed.frame == window.frame, "The native workshop frame must actually be borrowed from the pool")
assert(not save.keyboardEnabled and not save:GetScript("OnKeyDown"))
GUI:Release(borrowed)
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
assert(E.frame.frame == window.frame and E.saveKeyboard == save, "Reopening must reuse the detached native listener")
save, steps = E.saveKeyboard, E.stepsSplit.frame
assert(save.keyboardEnabled and save.propagateKeyboardInput)
key(save, "S", false, true)
assert(saves == 4 and not save.propagateKeyboardInput)
key(steps, "DOWN")
assert(E:SelectedStep() == 2 and not steps.propagateKeyboardInput)
combat(true)
assert(not save.keyboardEnabled and not steps.keyboardEnabled)
combat(false)
assert(save.keyboardEnabled and save.propagateKeyboardInput)
assert(steps.keyboardEnabled and steps.propagateKeyboardInput)
key(steps, "W"); assert(steps.propagateKeyboardInput)
key(save, "W"); assert(save.propagateKeyboardInput)

-- Close immediately after consuming a key, then reopen while still in combat.
key(save, "S", true)
local before = saves
TestCloseWorkshop(); closed(save)
combat(true)
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
assert(not E.saveKeyboard.keyboardEnabled and not E.luaBox.keyboardFrame.keyboardEnabled)
combat(false)
E.luaBox:SetFocus()
key(E.luaBox.keyboardFrame, "S", true)
assert(saves == before + 1)
key(E.luaBox.keyboardFrame, "W")
assert(E.luaBox.keyboardFrame.propagateKeyboardInput)

-- A cancelled dirty-close returns to an active editor rather than a dead shortcut.
E.luaBox:EditText('{ steps = {{ Note = "Dirty close" }} }', 0)
E:Hide()
assert(E.closeDialog and E.frame and E.saveKeyboard.keyboardEnabled)
E.closeDialog:Hide()
-- A save callback can close its own window; the dispatch must not set false
-- after cleanup. Exercise this through the real Save and close workflow.
E.Save = function(self)
    local result = oldSave(self)
    self:Hide()
    return result
end
local closing = E.saveKeyboard
key(closing, "S", true)
assert(not E.frame and closing.propagateKeyboardInput)
closed(closing)
healthy()

-- Exercise hide/show and reentrant cleanup without AceGUI swallowing exceptions.
local frame = CreateFrame("Frame", nil, UIParent)
local calls = 0
UI.SetKeyboardHandler(frame, function() calls = calls + 1; return true end)
key(frame, "S"); assert(not frame.propagateKeyboardInput)
frame:Hide(); assert(not frame.keyboardEnabled and frame.propagateKeyboardInput)
combat(true); frame:Show(); assert(not frame.keyboardEnabled)
frame:Hide(); combat(false); assert(not frame.keyboardEnabled)
frame:Show(); assert(frame.keyboardEnabled and frame.propagateKeyboardInput)
-- Combat can become active before the corresponding event is dispatched.
TestCombatLockdown = true
key(frame, "S"); assert(calls == 1 and not frame.keyboardEnabled)
combat(false)
UI.SetKeyboardHandler(frame, function() UI.SetKeyboardHandler(frame, nil); return true end)
key(frame, "S"); closed(frame)
assert(frame.propagateKeyboardInput, "A callback that detaches itself cannot consume the next key")
combat(true); combat(false); closed(frame)
E.Save, IsControlKeyDown, IsMetaKeyDown = oldSave, oldControl, oldMeta
healthy()
print("Keyboard combat: fresh launcher/open, Ctrl/Cmd+S, focus, both views, pooling, close and combat transitions passed.")
