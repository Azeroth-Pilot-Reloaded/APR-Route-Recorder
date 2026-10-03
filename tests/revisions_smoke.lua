local E, Model, UI = AprRC.routeEditor, AprRC.editorModel, AprRC.editorUI
TestCloseWorkshop()
local clock, oldClock, oldPrint = 0, GetTime, APR.PrintInfo
GetTime = function() return clock end
local warnings = {}
APR.PrintInfo = function(_, text) warnings[#warnings + 1] = text end
local route = assert(Model:NewRoute("Revision safeguards"))
route.steps = { { Waypoint = 1, Note = "Initial" }, { Waypoint = 2 } }
AprRCData.CurrentRoute = route
AprRC.settings.profile.enableAddon = true
AprRC.settings.profile.recordBarFrame.isRecording = true
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.session.draft.steps[1].Note = "Manual"; E:Changed()
local function count(key)
    local result = 0
    for _, text in ipairs(warnings) do
        if text:find(UI.Text(key):format(route.name), 1, true) then result = result + 1 end
    end
    return result
end
AprRC:NewStep({ Note = "Automatic tail" }); TestRunTimers()
assert(count("INCOMING_CHANGES_WARNING") == 1 and E.safetyNotice)
AprRC:NewStep({ Note = "Another automatic tail" }); TestRunTimers()
assert(count("INCOMING_CHANGES_WARNING") == 1, "Continuous recording must not spam immediate warnings")
clock = 119; E:SafetyTick()
assert(count("UNSAVED_DRAFT_REMINDER") == 0)
clock = 120; E:SafetyTick(); E:SafetyTick()
assert(count("UNSAVED_DRAFT_REMINDER") == 1)
clock = 180; AprRC:NewStep({ Note = "Automatic events are not editor activity" }); TestRunTimers()
clock = 240; E:SafetyTick()
assert(count("UNSAVED_DRAFT_REMINDER") == 2)
clock = 250; E:SelectTab("lua")
clock = 300
local validRaw = Model:RouteText(E.session.draft) .. "\n"
E.luaBox:SetText(validRaw); E.luaBox:Fire("OnTextChanged", validRaw)
clock = 419; E:SafetyTick()
assert(count("UNSAVED_DRAFT_REMINDER") == 2, "Typing should restart the idle interval")
clock = 420; E:SafetyTick()
assert(count("UNSAVED_DRAFT_REMINDER") == 3)

-- All native hide paths ask first, including the window's X/OnHide path.
local frame = E.frame
frame.frame:Hide()
assert(E.frame == frame and frame.frame:IsShown() and E.closeDialog)
E.closeCancelButton:Fire("OnClick")
assert(E.frame == frame and E.session:IsDirty() and not E.closeDialog)
E:Hide()
E.closeSaveButton:Fire("OnClick")
assert(not E.frame and not E.closeAfterSave)
assert(#AprRCData.CurrentRoute.steps == 5 and AprRCData.CurrentRoute.steps[1].Note == "Manual")

-- A background capture arriving after a conflict choice must be reviewed again.
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
route = Model:Source(route.name)
E.session.draft.steps[1].Note = "Our conflict"; E:Changed()
route.steps[1].Note = "Their conflict"
AprRC:NewStep({ Note = "Tail before conflict review" }); TestRunTimers()
assert(not E:Save() and E.mergeDialog and E.mergeApplyButton.disabled)
assert(E.mergePlan.conflicts[1].path == "route.steps[1].Note")
E.mergeLeftButton:Fire("OnClick")
assert(not E.mergeApplyButton.disabled)
AprRC:NewStep({ Note = "Tail during conflict review" }); TestRunTimers()
E.mergeApplyButton:Fire("OnClick")
assert(E.mergeDialog and E.mergeApplyButton.disabled, "Stale choices must be invalidated")
assert(E.mergePlan.incoming.steps[7].Note == "Tail during conflict review")
E.mergeRightButton:Fire("OnClick")
E.mergeApplyButton:Fire("OnClick")
route = Model:Source(route.name)
assert(not E.mergeDialog and not E.session:IsDirty() and #route.steps == 7)
assert(route.steps[1].Note == "Their conflict" and route.steps[6].Note == "Tail before conflict review")

-- Rebase keeps recording unchanged and leaves manual changes ready to Save.
E.session.draft.steps[1].Note = "Rebased edit"; E:Changed()
AprRC:NewStep({ Note = "Rebase tail" }); TestRunTimers()
assert(E:Integrate("rebase"))
assert(E.session:IsDirty() and not E.session:IsStale() and #E.session.draft.steps == 8)
assert(route.steps[1].Note == "Their conflict", "Rebase must not commit")
-- Merged identities remain valid for another merge after the rebase.
route.steps[1].Range = 7
AprRC:NewStep({ Note = "Tail after rebase" }); TestRunTimers()
assert(E:Save() and #AprRCData.CurrentRoute.steps == 9)
assert(AprRCData.CurrentRoute.steps[1].Note == "Rebased edit" and AprRCData.CurrentRoute.steps[1].Range == 7)
E:SelectTab("versions")
assert(E.tabs.children[1] and #Model:History(route.name) > 0)
for _, size in ipairs({ { 880, 560 }, { 440, 680 } }) do
    E.frame:SetWidth(size[1]); E.frame:SetHeight(size[2]); E.frame:DoLayout()
    assert(E.tabs.frame:GetHeight() > 100 and E.tabs.frame:GetWidth() > 300)
end

-- Invalid Lua can be kept on close; reminders and capture alerts remain active.
E:SelectTab("lua")
clock = 500
E.luaBox:SetText("{ steps = { -- unfinished")
E.luaBox:Fire("OnTextChanged", E.luaBox:GetText())
E:Hide(); E.closeSaveButton:Fire("OnClick")
assert(E.frame and not E.closeAfterSave and E.session.raw, "A failed save must leave the window open")
E:Hide(); E.closeKeepButton:Fire("OnClick")
assert(not E.frame and AprRCData.EditorDrafts[route.name].raw == "{ steps = { -- unfinished")
local reminders = count("UNSAVED_DRAFT_REMINDER")
clock = 620
E.safetyFrame:GetScript("OnUpdate")(E.safetyFrame, 1)
assert(count("UNSAVED_DRAFT_REMINDER") == reminders + 1, "The two-minute reminder must survive closing the window")
local immediate = count("INCOMING_CHANGES_WARNING")
AprRC:NewStep({ Note = "Capture with closed workshop" }); TestRunTimers()
assert(count("INCOMING_CHANGES_WARNING") == immediate + 1)

-- Recovery creates an independent draft and leaves the recording target intact.
E:Show(); E:SelectTab("versions")
local recording = AprRCData.CurrentRoute
local function find(widget, label)
    if widget.type == "Button" and widget.text:GetText() == UI.Text(label) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, label); if result then return result end
    end
    return nil
end
local function rawRecovery(widget)
    local version = widget:GetUserData("version")
    if version and version.raw then return find(widget, "Recover a copy") end
    for _, child in ipairs(widget.children or {}) do
        local result = rawRecovery(child); if result then return result end
    end
    return nil
end
assert(rawRecovery(E.tabs), "Incomplete Lua must be recoverable from Versions"):Fire("OnClick")
assert(E.session.name ~= recording.name and E.session.raw == "{ steps = { -- unfinished")
assert(E.tab == "lua" and AprRCData.CurrentRoute == recording and #recording.steps == 10)
-- Switching to a saved route must not hide the other route's unsaved draft.
local recoveryName = E.session.name
local clean = assert(Model:NewRoute("Clean route with pending recovery"))
E:RefreshRoutes(); E:SelectRoute(clean.name)
assert(not E.session:IsDirty())
E:Hide()
assert(E.closeDialog and E.closeSaveButton.disabled, "Other unsaved routes must still require close confirmation")
E.closeCancelButton:Fire("OnClick")
E:SelectRoute(recoveryName)
TestCloseWorkshop()
APR.PrintInfo, GetTime = oldPrint, oldClock
AprRC.settings.profile.recordBarFrame.isRecording = false
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Incoming-change warnings, two-minute idle reminders, native close confirmation, conflict refresh and recovery UI passed.")
