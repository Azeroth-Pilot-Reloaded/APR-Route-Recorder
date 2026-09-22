AprRC.TutoFrame = AprRC:NewModule("TutoFrame")
local Tour = AprRC.TutoFrame
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local chapters = {
    { "RECORD", "steps", "recordButton" },
    { "STEPS", "steps", "listPanel" },
    { "REWORK", "steps", "moveUp" },
    { "FIELDS", "steps", "inspector" },
    { "COMMANDS", "commands", "tabs" },
    { "BAR", "commands", "tabs" },
    { "ROUTE", "route", "saveButton" },
    { "LUA", "lua", "luaBox" },
    { "TOOLS", "tools", "toolsTutorialButton" },
    { "EXPORT", nil, "saveButton" },
}

local function captureLayers(frame, layers)
    layers[#layers + 1] = { frame = frame, strata = frame:GetFrameStrata(), level = frame:GetFrameLevel() }
    for _, child in ipairs({ frame:GetChildren() }) do captureLayers(child, layers) end
end

local function raiseControls(frame, level)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(level)
    for _, child in ipairs({ frame:GetChildren() }) do raiseControls(child, level + 1) end
end

function Tour:ClearPointer()
    if self.controls then self.controls:Hide(); self.controls:SetParent(UIParent) end
    if self.pointer then
        local pointer = self.pointer
        pointer.Content:SetHeight(self.contentHeight)
        pointer.Content.Text:ClearAllPoints()
        pointer.Content.Text:SetPoint("LEFT", pointer.Content, "LEFT", 20, 0)
        -- Blizzard pools these frames; restore every layer before returning them.
        for _, layer in ipairs(self.pointerLayers or {}) do
            layer.frame:SetFrameStrata(layer.strata)
            layer.frame:SetFrameLevel(layer.level)
        end
    end
    if self.pointerID then TutorialPointerFrame:Hide(self.pointerID) end
    self.pointer, self.pointerID, self.pointerLayers = nil, nil, nil
end

function Tour:Close()
    self.active = nil
    self:ClearPointer()
    if self.frame then self.frame:Hide() end
end

function Tour:CreateControls()
    if self.controls then return end
    local controls = CreateFrame("Frame", nil, UIParent)
    controls:SetSize(330, 26)
    self.controls = controls
    local function button(label, x, callback)
        local button = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
        button:SetSize(106, 24)
        button:SetPoint("LEFT", controls, "LEFT", x, 0)
        button:SetText(label)
        button:SetScript("OnClick", callback)
        return button
    end
    self.previous = button(L["Previous"], 0, function() self:SelectPage(self.page - 1) end)
    self.next = button(L["Next"], 112, function() self:SelectPage(self.page + 1) end)
    button(L["TUTORIAL_SKIP"], 224, function() self:Close() end)
end

function Tour:RefreshPointer()
    self:ClearPointer()
    local editor = AprRC.routeEditor
    if not self.active or not editor.frame then return end
    local chapter = chapters[self.page]
    local widget = (not chapter[2] or editor.tab == chapter[2]) and editor[chapter[3]]
    if editor.tab == "commands" then
        if chapter[1] == "COMMANDS" then widget = AprRC.CommandBarSetting.search end
        if chapter[1] == "BAR" then widget = AprRC.CommandBarSetting.settingsButton end
    end
    local anchor = widget and widget.frame
    if not anchor or not anchor:IsVisible() then anchor = editor.tabs.frame end
    local message = string.format("|cffffd100%d / %d · %s|r\n\n%s", self.page, #chapters,
        L["TUTORIAL_" .. chapter[1] .. "_TITLE"], L["TUTORIAL_" .. chapter[1] .. "_BODY"])
    self.pointerID = TutorialPointerFrame:Show(message, "UP", anchor, 0, -8, nil, "DOWN", 340)
    self.pointer = TutorialPointerFrame.InUseFrames[self.pointerID]
    local pointer = self.pointer
    -- Content and arrows can have their own strata/levels from Blizzard templates.
    -- Raising only the root leaves those children behind the AceGUI workshop.
    self.pointerLayers = {}
    captureLayers(pointer, self.pointerLayers)
    local level = editor.frame.frame:GetFrameLevel() + 300
    local offset = level - pointer:GetFrameLevel()
    for _, layer in ipairs(self.pointerLayers) do
        local parent = layer.frame:GetParent()
        layer.frame:SetFrameStrata("TOOLTIP")
        layer.frame:SetFrameLevel(math.max(layer.level + offset,
            layer.frame == pointer and level or parent:GetFrameLevel() + 1))
    end
    self.contentHeight = pointer.Content:GetHeight()
    pointer.Content:SetHeight(self.contentHeight + 36)
    pointer.Content:SetWidth(380)
    pointer.Content.Text:ClearAllPoints()
    pointer.Content.Text:SetPoint("TOPLEFT", pointer.Content, "TOPLEFT", 20, -20)
    self:CreateControls()
    self.controls:SetParent(pointer.Content)
    raiseControls(self.controls, pointer.Content:GetFrameLevel() + 1)
    self.controls:ClearAllPoints()
    self.controls:SetPoint("BOTTOM", pointer.Content, "BOTTOM", 0, 8)
    self.controls:Show()
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    self.next:SetText(L[self.page == #chapters and "TUTORIAL_FINISH" or "Next"])
end

function Tour:SelectPage(index)
    if index > #chapters then self:Close(); return end
    self.page = math.max(1, index)
    self.active = true
    self:ClearPointer()
    local editor = AprRC.routeEditor
    local tab = chapters[self.page][2]
    if tab == "commands" then AprRC.CommandBarSetting.showSettings = false end
    -- Touring must not parse/apply unfinished Lua or change a user's draft.
    if tab and not (editor.session and editor.session.raw) then editor:SelectTab(tab) end
    if tab == "steps" and editor.compact then
        local key = chapters[self.page][1]
        editor:ShowStepPane((key == "REWORK" or key == "FIELDS") and "inspector" or "list")
    end
    self:RefreshPointer()
end

function Tour:Start()
    if self.frame then self.frame:Hide() end
    AprRCData.TutorialSeen = true
    AprRC.routeEditor:Show()
    self:SelectPage(1)
end

function Tour:Show()
    self:Close()
    AprRCData.TutorialSeen = true
    local UI = AprRC.editorUI
    local frame = AprRC:CreateWidget("Frame")
    self.frame = frame
    frame:SetTitle(L["TUTORIAL_TITLE"])
    frame:SetWidth(math.min(650, UIParent:GetWidth()))
    frame:SetHeight(math.min(430, UIParent:GetHeight()))
    frame:EnableResize(false)
    frame:SetLayout("APRWorkspace")
    frame:SetStatusText("")
    local body = UI.Scroll(frame)
    UI.LabelWidget(body, L["TUTORIAL_WELCOME_BODY"])
    local footer = UI.Toolbar(frame, true)
    UI.Button(footer, "TUTORIAL_START", function() self:Start() end, 220)
    UI.Button(footer, "TUTORIAL_SKIP", function() self:Close() end, 220)
    frame:SetCallback("OnClose", function(widget)
        self.frame = nil
        LibStub("AceGUI-3.0"):Release(widget)
    end)
end

function Tour:OnWorkshopShow()
    if not AprRCData.TutorialSeen and AprRC.settings.profile.enableAddon then self:Show() end
end

function Tour:ShowCustomTutorialFrame(message, direction, anchor)
    return TutorialPointerFrame:Show(message, direction, anchor, 0, 10)
end

function Tour:HideCustomTutorialFrame(frameID)
    if frameID then TutorialPointerFrame:Hide(frameID) end
end
