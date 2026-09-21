local E, Tour = AprRC.routeEditor, AprRC.TutoFrame
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

E:Hide()
Tour:Close()
AprRCData.TutorialSeen = nil
AprRC.settings.profile.enableAddon = true
local recording = AprRC.settings.profile.recordBarFrame.isRecording
local routes = AprRC:CopyData(AprRCData.Routes)
local current = AprRC:CopyData(AprRCData.CurrentRoute)

E:Show()
assert(Tour.frame and not Tour.pointerID and AprRCData.TutorialSeen, "First use must show only the welcome")
Tour:Start()
assert(not Tour.frame and Tour.pointerID and Tour.page == 1)
assert(Tour.pointer.anchor == E.recordButton.frame)
assert(Tour.previous.disabled)
local function assertLayers(frame)
    assert(frame:GetFrameStrata() == "TOOLTIP", "Every tutorial layer must stay above the workshop")
    assert(frame:GetFrameLevel() > E.frame.frame:GetFrameLevel())
    for _, child in ipairs({ frame:GetChildren() }) do assertLayers(child) end
end
for index = 1, 10 do
    Tour:SelectPage(index)
    assert(not Tour.frame and Tour.pointerID and Tour.page == index)
    assert(Tour.pointer.Content.Text:GetText():find("TUTORIAL_", 1, true) == nil)
    assertLayers(Tour.pointer)
    assert(Tour.controls:GetFrameLevel() > Tour.pointer.Content:GetFrameLevel())
    assert(Tour.next:GetFrameLevel() > Tour.controls:GetFrameLevel())
    local oldPointer = Tour.pointer
    local oldID = Tour.pointerID
    E:DrawTab()
    assert(not TutorialPointerFrame.InUseFrames[oldID] and Tour.pointerID ~= oldID,
        "Pointers must be detached before releasing pooled editor controls")
    assert(oldPointer:GetFrameStrata() == "FULLSCREEN_DIALOG" and oldPointer:GetFrameLevel() == 10)
    assert(oldPointer.Content:GetFrameStrata() == "DIALOG" and oldPointer.Content:GetFrameLevel() == 11,
        "Blizzard's pooled content must regain its original layers")
    assert(oldPointer.Arrow_UP1:GetFrameLevel() == 100 and oldPointer.Glow:GetFrameLevel() == 1000)
    assertLayers(Tour.pointer)
end
assert(Tour.next:GetText() == L["TUTORIAL_FINISH"])
Tour.next:GetScript("OnClick")()
assert(not Tour.frame and not Tour.pointerID and not Tour.active)
E:Hide(); E:Show()
assert(not Tour.frame, "Seen tours must not reopen automatically")

-- Replay works through chat even while recording is stopped and the addon is disabled.
AprRC.settings.profile.enableAddon = false
AprRC.command:SlashCmd("tutorial")
assert(Tour.frame and not Tour.pointerID)
Tour:Close()
AprRC.command:SlashCmd("tuto")
assert(Tour.frame)
E:Hide()
assert(not Tour.frame, "Closing the workshop must release its tutorial")
AprRCData.TutorialSeen = nil
E:Show()
assert(not Tour.frame and not AprRCData.TutorialSeen, "Disabled addon must not consume the first-use tour")
AprRC.settings.profile.enableAddon = true
E:Show()
assert(Tour.frame)
Tour.frame:Hide() -- The native close button uses the same OnClose callback.
E:Hide(); E:Show()
assert(not Tour.frame, "Dismissal must also suppress automatic replay")

E:SelectTab("tools")
local function find(widget, text)
    if widget.type == "Button" and widget.text:GetText() == text then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = find(child, text)
        if found then return found end
    end
end
assert(find(E.frame, L["TUTORIAL_REPLAY"])):Fire("OnClick")
assert(Tour.frame)
E:Hide()
assert(AprRC:SerializeData(routes) == AprRC:SerializeData(AprRCData.Routes), "Tutorial changed saved routes")
assert(AprRC:SerializeData(current) == AprRC:SerializeData(AprRCData.CurrentRoute), "Tutorial changed the recording target")
assert(recording == AprRC.settings.profile.recordBarFrame.isRecording, "Tutorial changed recording state")

-- A tour opened over unfinished Lua must not parse it or change the draft.
E:Show()
if E.session then
    E:SelectTab("lua")
    E.session.raw = '{ steps = {'
    local draft = AprRC:CopyData(E.session.draft)
    Tour:Show(); Tour:Start(); Tour:SelectPage(7)
    assert(E.tab == "lua" and E.session.raw == '{ steps = {')
    assert(AprRC:DeepCompare(draft, E.session.draft))
    Tour:Close()
    E.session.raw = nil
end
E:Hide()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("First-use tutorial, chapter navigation, dismissal, replay and route isolation passed.")
