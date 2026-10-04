local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local Model = AprRC.editorModel
local Editor = AprRC:NewModule("RouteEditor", "AceTimer-3.0")
AprRC.routeEditor = Editor
local sessions = {}
local itemEvents = CreateFrame("Frame")
itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEvents:SetScript("OnEvent", function(_, _, id, success)
    if Model.pendingItemNames and Model.pendingItemNames[id] then
        Model.pendingItemNames[id] = nil
        if success then Editor.descriptionsDirty = true end
    end
end)

function UI.Body(parent, layout)
    local group = AprRC:CreateWidget("SimpleGroup")
    group:SetLayout(layout or "APRWorkspace")
    group:SetUserData("body", true)
    parent:AddChild(group)
    return group
end

function UI.Scroll(parent)
    local widget = AprRC:CreateWidget("ScrollFrame")
    widget:SetLayout("Flow")
    widget:SetUserData("body", true)
    parent:AddChild(widget)
    return widget
end

function UI.Toolbar(parent, footer)
    local group = UI.Group(parent)
    if footer then group:SetUserData("footer", true) end
    return group
end

function Editor:Message(text, errorMessage)
    self.notice = (errorMessage and "|cffff7777" or "|cff82d9a0") .. tostring(text) .. "|r"
    if errorMessage then APR:PrintError(text) end
    if self.frame then self:UpdateStatus() end
end

function Editor:Confirm(text, callback)
    if self.confirm then self.confirm:Show(); return end
    local dialog = AprRC:CreateWidget("Frame")
    self.confirm = dialog
    dialog:SetTitle(T("Route workshop"))
    dialog:SetWidth(470)
    dialog:SetHeight(190)
    dialog:EnableResize(false)
    dialog:SetLayout("Flow")
    UI.LabelWidget(dialog, text)
    UI.Button(dialog, YES, function() dialog:Hide(); callback() end)
    UI.Button(dialog, CANCEL, function() dialog:Hide() end)
    dialog:SetCallback("OnClose", function(widget) self.confirm = nil; GUI:Release(widget) end)
end

local function SetStatusLabel(widget, text)
    -- AceGUI labels recalculate their anchors/layout even when the text is unchanged.
    if widget.label:GetText() ~= text then widget:SetText(text) end
end

function Editor:UpdateStatus()
    if not self.frame then return end
    local session = self.session
    local dirty = session and session:IsDirty()
    local active = AprRC.settings.profile.recordBarFrame.isRecording
    self.recordButton:SetText(T(active and "Stop recording" or "Record this route"))
    self.recordButton:SetDisabled(not session or not AprRC.settings.profile.enableAddon)
    self.saveButton:SetDisabled(not session)
    self.copyButton:SetDisabled(not session)
    self.deleteRouteButton:SetDisabled(not session)
    local rawHistory = session and session.rawHistory
    local rawMode = self.tab == "lua" and rawHistory
    self.undoButton:SetDisabled(not session or (rawMode and session.rawCursor <= 1 or not rawMode and session.cursor <= 1))
    self.redoButton:SetDisabled(not session or (rawMode and session.rawCursor >= #rawHistory or not rawMode and session.cursor >= #session.history))
    local state = active and "|cffff7777● " .. T("Recording") .. "|r" or "|cffb3a58b" .. T("Recording stopped") .. "|r"
    if active then state = state .. "  ·  " .. AprRCData.CurrentRoute.name end
    SetStatusLabel(self.recordStatus, state)
    SetStatusLabel(self.summary, session and ("|cffedc36a" .. tostring(#session.draft.steps) .. " " .. T("Steps") .. "|r  ·  " ..
        (dirty and "|cffffcf66" .. T("Unsaved draft") or "|cff82d9a0" .. T("Saved")) .. "|r") or "")
    self.frame:SetStatusText(self.notice or self.safetyNotice or (dirty and T("Follow pauses while you edit. Save or reload to resume.") or
        T("Drafts are kept when closing this window, switching routes or reloading the UI.")))
    if self.tab == "commands" then AprRC.CommandBarSetting:RefreshRunState() end
end

function Editor:Changed()
    self.notice = nil
    self.session:Snapshot()
    self:UpdateStatus()
    -- Only rebuild the list; keep the inspector and its keyboard focus intact.
    self:DrawList()
    if self.stepDescription then
        local _, detail = Model:Summary(self:Steps()[self:SelectedStep()])
        self.stepDescription:SetText(detail)
    end
end

function Editor:FormContext()
    self.formModes, self.formPages = self.formModes or {}, self.formPages or {}
    local session, selected, draft, panel = self.session, self.session.selected, self.session.draft, self.routeForm or self.inspector
    local parallelGroup, parallelSelected = session.parallelGroup, session.parallelSelected
    local token = {}
    self.formToken = token
    return {
        route = draft,
        hiddenFields = self.routeForm and { parallelSteps = true } or nil,
        valueAt = function(path)
            local value = path:match("^step/") and draft.steps[selected] or draft
            local first = true
            for key in path:gmatch("[^/]+") do
                if first then first = false
                elseif key ~= "variant" then
                    if type(value) ~= "table" then return end
                    value = value[tonumber(key) or key]
                end
            end
            return value
        end,
        pickerOpened = function(widget)
            if self.fieldPicker and self.fieldPicker ~= widget then self.fieldPicker:Hide() end
            self.fieldPicker = widget
            local release = widget.events.OnRelease
            widget:SetCallback("OnRelease", function(...)
                if self.fieldPicker == widget then self.fieldPicker = nil end
                if release then release(...) end
            end)
        end,
        isCurrent = function()
            return self.frame and self.session == session and session.selected == selected and session.draft == draft
                and session.parallelGroup == parallelGroup and session.parallelSelected == parallelSelected
                and self.formToken == token and (self.routeForm or self.inspector) == panel
        end,
        modes = self.formModes, pages = self.formPages,
        changed = function() self:Changed() end,
        redraw = function() self:DrawInspector() end,
        error = function(reason) self:Message(reason, true) end,
    }
end

function Editor:SelectRoute(name)
    self.pendingManualStep = nil
    if self.mergeDialog then self.mergeDialog:Hide() end
    if self.closeDialog then self.closeDialog:Hide() end
    self.closeAfterSave, self.safetyNotice = nil, nil
    if self.session then self.session:Persist() end
    local route = Model:Source(name)
    if not route then return end
    if not sessions[name] then sessions[name] = Model:Open(route) end
    self.session = sessions[name]
    self.session:Touch()
    if not self.session:IsDirty() and self.session:IsStale() then self.session:Reload() end
    self.notice, self.query, self.filter, self.page = nil, "", "all", 1
    self.editGroupConditions = nil
    self.routeFormTrail = {}
    self.formModes, self.formPages = {}, {}
    self.routeDropdown:SetValue(name)
    if self.session.raw then self.tab = "lua" end
    self:SelectTab(self.tab or "steps")
    self:UpdateStatus()
end

function Editor:SetSession(name, session) sessions[name] = session end

function Editor:UnsavedCount()
    local count = 0
    for _ in pairs(AprRCData.EditorDrafts or {}) do count = count + 1 end
    return count
end

function Editor:KeepDraftsOnClose()
    for name, session in pairs(sessions) do
        if session:IsDirty() then
            Model:Archive(name, session.draft, "Before close", session.raw, session.base)
            session:Persist()
        end
    end
end

function Editor:SafetyTick()
    local now = (GetTime or time)()
    -- Restore persisted drafts lazily, including routes not currently displayed.
    -- The monitor keeps running when the workshop is closed.
    for name in pairs(AprRCData.EditorDrafts or {}) do
        if not sessions[name] then
            local route = Model:Source(name)
            if route then sessions[name] = Model:Open(route) end
        end
    end
    for name, session in pairs(sessions) do
        if session:IsDirty() then
            if not session.lastActivity then session:Touch() end
            local incoming = session:IsStale(true)
            if incoming and not session.incomingWarned then
                session.incomingWarned = true
                Model:Archive(name, Model:Source(name), "Recording checkpoint")
                self:Warn(T("INCOMING_CHANGES_WARNING"):format(name))
            elseif not incoming then session.incomingWarned = nil end
            if self.session == session then
                self.safetyNotice = incoming and ("|cffffcf66" .. T("INCOMING_CHANGES_STATUS") .. "|r") or nil
            end
            if now - session.lastActivity >= 120 and (not session.lastReminder or now - session.lastReminder >= 120) then
                session.lastReminder = now
                Model:Archive(name, Model:Source(name), "Recording checkpoint")
                Model:Archive(name, session.draft, "Draft checkpoint", session.raw, session.base)
                self:Warn(T("UNSAVED_DRAFT_REMINDER"):format(name))
            end
        else
            session.incomingWarned, session.lastReminder = nil, nil
            if self.session == session then self.safetyNotice = nil end
        end
    end
end

function Editor:Warn(text)
    APR:PrintInfo("|cffffcf66" .. text .. "|r")
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.8, 0.2) end
end

local safetyFrame = CreateFrame("Frame")
Editor.safetyFrame = safetyFrame
local safetyElapsed = 0
safetyFrame:RegisterEvent("PLAYER_LOGOUT")
safetyFrame:SetScript("OnEvent", function()
    -- Persist identities after the last capture, even when it happened between
    -- safety ticks. WoW writes SavedVariables after PLAYER_LOGOUT on /reload.
    for _, route in ipairs(AprRCData.Routes or {}) do Model:SourceIDs(route) end
    if AprRCData.CurrentRoute and AprRCData.CurrentRoute.name ~= "" then Model:SourceIDs(AprRCData.CurrentRoute) end
    for _, session in pairs(sessions) do session:Persist() end
end)
safetyFrame:SetScript("OnUpdate", function(_, elapsed)
    safetyElapsed = safetyElapsed + elapsed
    if safetyElapsed < 1 then return end
    safetyElapsed = 0
    local ok, reason = pcall(Editor.SafetyTick, Editor)
    if not ok then AprRC:Debug("Route draft monitor:", reason) end
end)

function Editor:RefreshRoutes()
    local entries = {}
    for _, route in ipairs(AprRCData.Routes) do entries[route.name] = route.name end
    local picker = self.routeDropdown
    local desired = #AprRCData.Routes > 10 and "APRSearchSelect" or "Dropdown"
    if picker.type ~= desired then
        local parent, position = picker.parent
        for index, child in ipairs(parent.children) do
            if child == picker then position = index; break end
        end
        table.remove(parent.children, position)
        GUI:Release(picker)
        self.routeDropdown = UI.Dropdown(parent, T("Select a route"), entries, nil,
            function(name) self:SelectRoute(name) end)
        table.remove(parent.children) -- Restore the selector's position in the toolbar.
        table.insert(parent.children, position, self.routeDropdown)
        self.routeDropdown:SetFullWidth(false)
        self.routeDropdown:SetRelativeWidth(0.54)
        parent:DoLayout()
    else
        picker:SetList(entries)
    end
    self.routeCount = #AprRCData.Routes
    if self.session then self.routeDropdown:SetValue(self.session.name) end
end

function Editor:NameDialog(copy)
    if self.nameDialog then self.nameDialog:Show(); return end
    local source
    if copy and self.session then
        local reason
        source, reason = self.session:Read()
        if not source then self:Message(reason, true); return end
    end
    local dialog = AprRC:CreateWidget("Frame")
    self.nameDialog = dialog
    dialog:SetTitle(T(copy and "Save a copy" or "New route"))
    dialog:SetWidth(490)
    dialog:SetHeight(230)
    dialog:EnableResize(false)
    dialog:SetLayout("Flow")
    local input = AprRC:CreateWidget("EditBox")
    input:SetLabel(T("Route name"))
    input:SetFullWidth(true)
    input:DisableButton(true)
    input:SetText(source and (source.name .. "-copy") or "")
    dialog:AddChild(input)
    local feedback = UI.LabelWidget(dialog, "")
    local function create()
        local route, reason = Model:NewRoute(input:GetText(), source)
        if not route then
            local errors = { duplicate = "This name already exists.", name = "Enter a route name.",
                map = "No map is available here. Use a name beginning with a map ID, e.g. 84-My route." }
            feedback:SetText("|cffff7777" .. T(errors[reason] or reason) .. "|r")
            return
        end
        dialog:Hide()
        self:RefreshRoutes()
        self:SelectRoute(route.name)
    end
    input:SetCallback("OnEnterPressed", create)
    UI.Button(dialog, "Save", create)
    UI.Button(dialog, CANCEL, function() dialog:Hide() end)
    dialog:SetCallback("OnClose", function(widget) self.nameDialog = nil; GUI:Release(widget) end)
    input:SetFocus()
end

function Editor:Save()
    if not self.session then return false end
    if self.session:IsStale() then return self:Integrate("save") end
    local ok, reason = self.session:Save()
    if not ok then
        self:Message(reason == "conflict" and T("SAVE_CONFLICT_HELP") or reason, true)
        return false
    end
    self:AfterSave()
    return true
end

function Editor:ImportDialog()
    if self.importDialog then self.importDialog:Show(); return end
    local dialog = AprRC:CreateWidget("Frame")
    self.importDialog = dialog
    dialog:SetTitle(T("Import from APR"))
    dialog:SetWidth(620)
    dialog:SetHeight(270)
    dialog:EnableResize(false)
    dialog:SetLayout("Flow")
    UI.LabelWidget(dialog, T("Import an editable copy. Saved routes are automatically available in APR."))
    local selected
    local picker = UI.SearchSelect(dialog, T("Select a route"), AprRC:GetImportableAPRRoutes(), nil,
        function(key) selected = key end)
    local feedback = UI.LabelWidget(dialog, "")
    UI.Button(dialog, "Import from APR", function()
        local route, reason = AprRC:ImportAPRRoute(selected)
        if not route then feedback:SetText(reason); return end
        dialog:Hide()
        self:RefreshRoutes()
        self:SelectRoute(route.name)
        self:Message(T("Route imported from APR"))
    end, 190)
    UI.Button(dialog, CANCEL, function() dialog:Hide() end)
    dialog:SetCallback("OnClose", function(widget) self.importDialog = nil; GUI:Release(widget) end)
    picker:SetFocus()
end

function Editor:DeleteRoute()
    local session = self.session
    if not session then return end
    self:Confirm(string.format(T("Delete route %s, its draft and its recorder copy in APR? This cannot be undone."), session.name), function()
        if self.session ~= session then return end
        if self.fieldPicker then self.fieldPicker:Hide() end
        if not AprRC:DeleteRouteByName(session.name) then return end
        sessions[session.name] = nil
        self.session, self.formToken = nil, nil
        self:RefreshRoutes()
        local nextRoute = AprRCData.Routes[1]
        if nextRoute then self:SelectRoute(nextRoute.name)
        else self.routeDropdown:SetValue(nil); self:SelectTab("steps"); self:UpdateStatus() end
    end)
end

function Editor:ToggleRecording()
    if AprRC.settings.profile.recordBarFrame.isRecording then
        AprRC.record:StopRecord()
    else
        if not self.session then return end
        if not AprRC.settings.profile.enableAddon then self:Message(T("Enable the addon in Settings to record."), true); return end
        if self.session:IsDirty() then self:Message(T("Save your draft before recording this route."), true); return end
        local route = Model:Source(self.session.name)
        if not route then return end
        AprRCData.CurrentRoute = route
        AprRC:EnsureQuestLookup(route.name)
        AprRC:RebuildQuestLookupFromRoute(route)
        AprRC:ResetTaxiLookup()
        AprRC.settings.profile.recordBarFrame.isRecording = true
        AprRC.record:UpdateRecordButton()
    end
    self:UpdateStatus()
end

function Editor:SelectTab(tab)
    if self.session then self.session:Touch() end
    if tab ~= "lua" and tab ~= "versions" and self.session and self.session.raw then
        local ok, reason = self.session:ApplyRaw()
        if not ok then
            self:Message(T("Finish editing the Lua table before opening the visual editor.") .. " " .. tostring(reason), true)
            tab = "lua"
        else
            self.session.rawHistory = nil
        end
    end
    if self.tab ~= tab and (self.tab == "parallel" or tab == "parallel") then
        self.query, self.filter, self.page = "", "all", 1
        self.formModes, self.formPages, self.editGroupConditions = {}, {}, nil
    end
    self.tab = tab
    self.selectingTab = true
    self.tabs:SelectTab(tab)
    self.selectingTab = false
    self:DrawTab()
end

function Editor:DrawTab()
    local reopenFind = self.tab == "lua" and self.luaFindBar ~= nil
    if self.fieldPicker then self.fieldPicker:Hide() end
    AprRC.TutoFrame:ClearPointer()
    self:DetachLua()
    AprRC.CommandBarSetting:CancelDrag()
    self.list, self.inspector, self.listPanel, self.routeForm, self.stepDescription = nil, nil, nil, nil, nil
    self.stepsSplit = nil
    self.tabs:ReleaseChildren()
    if self.tab == "tools" then
        self:DrawTools()
    elseif self.tab == "commands" then
        AprRC.CommandBarSetting:Draw(self.tabs)
    elseif not self.session then
        local empty = UI.Scroll(self.tabs)
        UI.LabelWidget(empty, "|cffedc36a" .. T("Your route starts here.") .. "|r", true)
        UI.LabelWidget(empty, T("Create a route, then record your journey or add steps manually."))
        UI.Button(empty, "New route", function() self:NameDialog() end)
    elseif self.tab == "steps" then
        self:DrawSteps()
    elseif self.tab == "parallel" then
        self:DrawParallelSteps()
    elseif self.tab == "route" then
        self.routeForm = UI.Scroll(self.tabs)
        self:DrawInspector()
    elseif self.tab == "lua" then
        self:DrawLua()
    elseif self.tab == "versions" then
        self:DrawVersions()
    end
    self.tabs:DoLayout()
    self.frame:DoLayout()
    if reopenFind and self.luaBox then self:OpenLuaFind() end
    self:UpdateStatus()
    if self.tab ~= "parallel" and not self.luaFindBar and self.session and self.follow and not self.session:IsDirty() and
        self.session.selected == #self.session.draft.steps then self:ScrollToLatest() end
    AprRC.TutoFrame:RefreshPointer()
end

function Editor:DrawTools()
    local panel = UI.Scroll(self.tabs)
    self.toolsTutorialButton = UI.Button(panel, "TUTORIAL_REPLAY", function() AprRC.TutoFrame:Show() end, 240)
    UI.Button(panel, "Help (wiki)", function()
        local locale = LibStub("AceLocale-3.0"):GetLocale("APR")
        APR.questionDialog:CreateEditBoxPopup(locale["COPY_HELPER"], locale["CLOSE"],
            "https://github.com/Azeroth-Pilot-Reloaded/azeroth-pilot-reloaded/wiki/APR-Route-Syntax")
    end, 190)
    AprRC.textStyle:Draw(panel)
    UI.LabelWidget(panel, "|cffedc36a" .. T("Recording tools") .. "|r", true)
    UI.LabelWidget(panel, T("All existing commands, autocomplete dialogs and toolbar settings remain available here."))
    UI.Button(panel, "Settings", function() AprRC.settings:OpenSettings(AprRC.title) end)
    UI.Button(panel, "Command bar", function() AprRC.CommandBarSetting:Show() end, 190)
    UI.Button(panel, "Coordinates", function() AprRC.command:SlashCmd("coordframe") end)
    UI.Button(panel, "Extra line texts", function() AprRC.exportExtraLineText.Show() end, 190)
    UI.Button(panel, "Command reference", function() AprRC.options:PrintHelp() end, 190)
end

local function interacting(widget, ignored)
    if widget == ignored then return false end
    if widget.type == "ColorPicker" and ColorPickerFrame and ColorPickerFrame:IsShown() then return true end
    local edit = widget.editBox or widget.editbox
    if edit and edit:HasFocus() or widget.open then return true end
    for _, child in ipairs(widget.children or {}) do
        if interacting(child, ignored) then return true end
    end
    return false
end

function Editor:HandleStepKey(key)
    if not self.frame or not self.session or not self.list or
        (self.tab ~= "steps" and self.tab ~= "parallel") then return false end
    if (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) or interacting(self.frame) or
        self.confirm or self.nameDialog or self.fieldPicker or self.mergeDialog or self.closeDialog or
        (self.stepsSplit and self.stepsSplit.dragging) or (IsModifierKeyDown and IsModifierKeyDown()) then return false end
    if key == "RIGHT" then
        if not self.compact or self.compactPane ~= "inspector" then return false end
        self:ShowStepPane("list")
        return true
    elseif key == "LEFT" then
        if not self:Steps()[self:SelectedStep()] then return false end
        self:ShowStepPane("inspector")
        return true
    elseif key == "UP" or key == "DOWN" then
        local matches = Model:Filter(self:Steps(), self.query, self.filter, UI.Label)
        if #matches == 0 then return false end
        local position
        for offset, index in ipairs(matches) do
            if index == self:SelectedStep() then position = offset; break end
        end
        local target = position and math.max(1, math.min(#matches, position + (key == "UP" and -1 or 1))) or
            (key == "UP" and #matches or 1)
        if matches[target] ~= self:SelectedStep() then self:SelectStep(matches[target]) end
        return true
    end
    return false
end

function Editor:RequestRefresh(name, manualStep)
    if manualStep and self.frame and self.session and self.session.name == name and not self.session:IsDirty() then
        self.pendingManualStep = { session = self.session, step = manualStep }
    end
    if self.refreshPending or (not self.frame and not next(AprRCData.EditorDrafts or {})) then return end
    self.refreshPending = true
    C_Timer.After(0, function()
        self.refreshPending = nil
        self:SafetyTick()
        self:Tick()
    end)
end

function Editor:ScrollToStep(index, group)
    if self.luaFindBar then return end
    local session, widget, tab = self.session, self.list or self.luaBox, self.tab
    if not widget then return end
    local draft, token = session.draft, {}
    self.stepScrollToken = token
    if self.luaBox then self.luaScrollToken = token end
    local function scroll()
        if self.stepScrollToken ~= token or self.session ~= session or session.draft ~= draft or self.tab ~= tab or
            session:GetSelected(group) ~= index or self.luaFindBar then return end
        if self.list == widget then
            for position, row in ipairs(widget.children) do
                if row:GetUserData("stepIndex") == index then
                    local range = widget.content:GetHeight() - widget.scrollframe:GetHeight()
                    local offset = widget.content:GetTop() - row.frame:GetTop()
                    widget:SetScroll(position == #widget.children and 1000 or
                        (range > 0 and math.max(0, math.min(1000, offset / range * 1000)) or 0))
                    break
                end
            end
        elseif self.luaBox == widget and self.luaScrollToken == token and not session:IsDirty() then
            local positions = self.luaStepPositions
            local steps = positions and (group and positions.parallelSteps[group] or positions.steps)
            if steps and steps[index] then widget.editBox:SetCursorPosition(steps[index].start) end
        end
    end
    scroll()
    -- Reapply once WoW has calculated the new rows and multiline text layout.
    C_Timer.After(0, scroll)
end

function Editor:ScrollToLatest()
    if self.tab == "parallel" or self.luaFindBar then return end
    if self.list then self.list:SetScroll(1000) end
    local box = self.luaBox
    if not box then return end
    local token = {}
    self.luaScrollToken = token
    local function scroll()
        box.editBox:SetCursorPosition(#box:GetText())
        box.scrollFrame:SetVerticalScroll(box.scrollFrame:GetVerticalScrollRange())
    end
    scroll()
    -- WoW can calculate the multiline edit box's scroll range after layout.
    C_Timer.After(0, function()
        if self.luaScrollToken == token and self.luaBox == box and self.follow and not self.session:IsDirty() then scroll() end
    end)
end

function Editor:Refresh(forceFollow)
    if not self.frame then return end
    self:SafetyTick()
    if self.descriptionsDirty and not self.confirm and not self.fieldPicker and not interacting(self.frame) then
        self.descriptionsDirty = nil
        self:DrawList()
        if self.session then self:DrawInspector() end
    end
    if self.routeCount ~= #AprRCData.Routes then
        self:RefreshRoutes()
        if not self.session and AprRCData.Routes[1] then self:SelectRoute(AprRCData.Routes[1].name) end
    end
    local session = self.session
    local pending = self.pendingManualStep
    local manualIndex
    if pending then
        if pending.session ~= session or session:IsDirty() then
            self.pendingManualStep = nil
        else
            local source = Model:Source(session.name)
            for index, step in ipairs(source and source.steps or {}) do
                if step == pending.step then manualIndex = index; break end
            end
            if not manualIndex then self.pendingManualStep = nil end
        end
    end
    local aprIndex, aprGroup
    if not manualIndex and AprRC.settings.profile.followAPR and session then
        aprIndex, aprGroup = AprRC:GetAPRPlaybackSelection(session.name)
    end
    if not aprIndex then self.luaAPRPosition = nil end
    local following = not aprIndex and self.follow and session and session.name == AprRCData.CurrentRoute.name
    if session and not AprRC.CommandBarSetting.dragging and
        not (self.stepsSplit and self.stepsSplit.dragging) and not self.confirm and not self.nameDialog and
        not self.luaFindBar and not interacting(self.frame, (manualIndex or following or aprIndex) and self.luaBox or nil) and
        not self.fieldPicker and not self.mergeDialog and not self.closeDialog and
        not session:IsDirty() and (session:IsStale(true) or manualIndex or (forceFollow and following)) then
        local listScroll = self.list and self.list.localstatus.scrollvalue or 0
        local luaScroll = self.luaBox and self.luaBox.scrollFrame:GetVerticalScroll() or 0
        local luaCursor = self.luaBox and self.luaBox.editBox:GetCursorPosition() or 0
        local luaFocus = self.luaBox and self.luaBox.editBox:HasFocus()
        session:Reload()
        session.rawHistory = nil
        if manualIndex or (following and self.tab ~= "parallel") then
            session.selected = manualIndex or math.max(1, #session.draft.steps)
            self.query, self.filter = "", "all"
            self.page = math.max(1, math.ceil(session.selected / UI.PageSize))
            self.formModes, self.formPages = {}, {}
        end
        if manualIndex and self.tab ~= "lua" then
            self.editGroupConditions = nil
            -- Keep Lua open; visual commands reveal their new main-route step.
            local page = self.page
            self:SelectTab("steps")
            if self.page ~= page then self.page = page; self:DrawList() end
            if self.compact then self:ShowStepPane("list") end
        else self:DrawTab() end
        if not manualIndex and (not following or self.tab == "parallel") and self.list then self.list:SetScroll(listScroll) end
        if self.luaBox then
            if luaFocus then self.luaBox.editBox:SetFocus() end
            if manualIndex then self:ScrollToStep(manualIndex)
            elseif following then self:ScrollToLatest()
            else
                self.luaBox.editBox:SetCursorPosition(math.min(luaCursor, #self.luaBox:GetText()))
                self.luaBox.scrollFrame:SetVerticalScroll(luaScroll)
            end
        end
        if manualIndex then
            self.pendingManualStep = nil
            if self.list then self:ScrollToStep(manualIndex) end
        end
    end
    if aprIndex then self:FollowAPRStep(aprIndex, aprGroup) end
    self:UpdateStatus()
end

function Editor:FollowAPRStep(index, group)
    local session = self.session
    if self.tab ~= "steps" and self.tab ~= "parallel" and self.tab ~= "lua" then return end
    if session:IsDirty() or self.confirm or self.nameDialog or self.fieldPicker or self.luaFindBar or
        AprRC.CommandBarSetting.dragging or (self.stepsSplit and self.stepsSplit.dragging) or
        interacting(self.frame, self.tab == "lua" and self.luaBox or nil) then return end
    if not session:GetSteps(group)[index] then return end
    if self.tab == "lua" then
        session:SetSelected(index, group)
        if group then session.parallelGroup = group end
        self:FollowLuaAPRStep(index, group)
        return
    end
    local tab = group and "parallel" or "steps"
    local page = math.ceil(index / UI.PageSize)
    if self.tab == tab and session:GetSelected(group) == index and (not group or session.parallelGroup == group) and
        self.page == page and self.query == "" and self.filter == "all" and not self.editGroupConditions then return end
    session:SetSelected(index, group)
    if group then session.parallelGroup = group end
    self.query, self.filter, self.page = "", "all", page
    self.editGroupConditions = nil
    self.formModes, self.formPages = {}, {}
    if self.tab ~= tab then self:SelectTab(tab) else self:DrawTab() end
    -- SelectTab resets pagination when crossing the main/parallel boundary.
    if self.page ~= page then self.page = page; self:DrawList() end
    if self.list then
        local row = self.list.children[(index - 1) % UI.PageSize + 1]
        local range = self.list.content:GetHeight() - self.list.scrollframe:GetHeight()
        local offset = row and (self.list.content:GetTop() - row.frame:GetTop()) or 0
        self.list:SetScroll(range > 0 and math.max(0, math.min(1000, offset / range * 1000)) or 0)
    end
end

function Editor:Tick(forceFollow)
    -- Some game data can be unavailable/secret during combat. Keep the draft and
    -- try the next tick, matching the legacy editor's guarded live refresh.
    local ok, reason = pcall(self.Refresh, self, forceFollow)
    if not ok then AprRC:Debug("Route workshop refresh:", reason) end
end

function Editor:Hide(force)
    self.forceClose = force
    if self.frame then self.frame:Hide() end
    self.forceClose = nil
end

function Editor:ApplySizeLimits()
    local width = math.min(self.compact and 440 or 880, UIParent:GetWidth())
    local height = math.min(self.compact and 680 or 560, UIParent:GetHeight())
    if self.frame.frame.SetResizeBounds then self.frame.frame:SetResizeBounds(width, height)
    else self.frame.frame:SetMinResize(width, height) end
    return width, height
end

function Editor:ToggleCompact()
    if not self.frame then return end
    local status = AprRC.settings.profile.editorFrame
    local width = self.frame.frame:GetWidth()
    if not self.compact then status.wideWidth = width end
    self.compact = not self.compact
    status.compact = self.compact
    local minWidth, minHeight = self:ApplySizeLimits()
    status.width = math.min(UIParent:GetWidth(), math.max(minWidth,
        self.compact and math.floor(width / 2) or (status.wideWidth or 1120)))
    status.height = math.max(minHeight, self.frame.frame:GetHeight())
    self.frame:SetWidth(status.width)
    self.frame:SetHeight(status.height)
    self.compactButton:SetIcon(self.compact and "expand" or "compact")
    self.compactButton:SetText(T(self.compact and "Full width" or "Compact mode"))
    self:DrawTab()
end

function Editor:Show()
    if self.frame then
        self.frame:Show(); self.frame.frame:Raise()
        AprRC.CommandBar:RefreshFrameAnchor()
        AprRC.TutoFrame:OnWorkshopShow()
        return
    end
    local frame = AprRC:CreateWidget("Frame")
    self.frame = frame
    frame:SetTitle("APR  |  " .. T("Route workshop"))
    -- Several legacy dialogs hide this region before returning frames to the pool.
    frame.statustext:GetParent():Show()
    frame:SetLayout("APRWorkspace")
    AprRC.settings.profile.editorFrame = AprRC.settings.profile.editorFrame or { width = 1120, height = 780 }
    local status = AprRC.settings.profile.editorFrame
    self.compact = status.compact == true
    local minWidth, minHeight = self:ApplySizeLimits()
    status.width = math.min(math.max(status.width or (self.compact and 560 or 1120), minWidth), UIParent:GetWidth())
    status.height = math.min(math.max(status.height or 780, minHeight), UIParent:GetHeight())
    frame:SetStatusTable(status)
    local wasClamped = frame.frame:IsClampedToScreen()
    frame.frame:SetClampedToScreen(true)
    frame.frame:SetBackdropColor(0.07, 0.055, 0.035, 0.98)
    frame.frame:SetBackdropBorderColor(0.72, 0.58, 0.34, 1)
    local header = UI.Toolbar(frame)
    self.routeDropdown = UI.Dropdown(header, T("Select a route"), {}, nil, function(name) self:SelectRoute(name) end)
    self.routeDropdown:SetFullWidth(false)
    self.routeDropdown:SetRelativeWidth(0.54)
    UI.Button(header, "New route", function() self:NameDialog() end, 155)
    self.recordButton = UI.Button(header, "Record this route", function() self:ToggleRecording() end, 210)
    self.compactButton = UI.IconButton(nil, self.compact and "expand" or "compact",
        self.compact and "Full width" or "Compact mode", function() self:ToggleCompact() end)
    self.compactButton.frame:SetParent(frame.frame)
    self.compactButton.frame:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", -14, -8)
    self.compactButton.frame:Show()
    self.recordStatus = UI.LabelWidget(header, "")
    self.summary = UI.LabelWidget(header, "")
    self.tabs = AprRC:CreateWidget("TabGroup")
    self.tabs:SetLayout("APRFill")
    self.tabs:SetAutoAdjustHeight(false)
    self.tabs:SetUserData("body", true)
    self.tabs:SetTabs({ { value = "steps", text = T("Steps") },
        { value = "parallel", text = UI.Label("parallelSteps") }, { value = "route", text = T("Route") },
        { value = "lua", text = T("Lua editor") }, { value = "versions", text = T("Versions") },
        { value = "commands", text = T("Commands") },
        { value = "tools", text = T("Tools") } })
    self.tabs:SetCallback("OnGroupSelected", function(_, _, tab) if not self.selectingTab then self:SelectTab(tab) end end)
    frame:AddChild(self.tabs)
    local footer = UI.Toolbar(frame, true)
    self.saveButton = UI.Button(footer, "Save", function() self:Save() end, 135)
    self.saveButton:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        AprRC:AddTooltipLine(GameTooltip, T("SAVE_MERGE_HELP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.saveButton:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    self.importButton = UI.Button(footer, "Import from APR", function() self:ImportDialog() end, 170)
    self.copyButton = UI.Button(footer, "Save a copy", function() self:NameDialog(true) end, 195)
    self.deleteRouteButton = UI.IconButton(footer, "trash", "Delete route", function() self:DeleteRoute() end)
    self.undoButton = UI.IconButton(footer, "undo", "Undo", function() self:Undo(-1) end)
    self.redoButton = UI.IconButton(footer, "redo", "Redo", function() self:Undo(1) end)
    self.reloadButton = UI.IconButton(footer, "refresh", "Reload saved route", function()
        local session = self.session
        if not session then return end
        local function reload()
            session:Reload(); session:Persist(); session.rawHistory = nil
            if self.session == session then self.notice = nil; self:DrawTab() end
        end
        if session:IsDirty() then self:Confirm(T("Discard this draft and reload the saved route?"), reload) else reload() end
    end)
    local follow = AprRC:CreateWidget("CheckBox")
    follow:SetLabel(T("Follow recording"))
    follow:SetWidth(follow.text:GetStringWidth() + 30)
    self.follow = self.follow ~= false
    follow:SetValue(self.follow)
    follow:SetCallback("OnValueChanged", function(_, _, value) self.follow = value; self:Tick(value) end)
    footer:AddChild(follow)
    local followAPR = AprRC:CreateWidget("CheckBox")
    self.followAPRCheckbox = followAPR
    followAPR:SetLabel(T("Follow APR"))
    followAPR:SetWidth(followAPR.text:GetStringWidth() + 30)
    followAPR:SetValue(AprRC.settings.profile.followAPR == true)
    followAPR:SetCallback("OnValueChanged", function(_, _, value)
        AprRC.settings.profile.followAPR = value
        self:Tick()
    end)
    followAPR:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        AprRC:AddTooltipLine(GameTooltip, T("Follow APR's current step when the same route is open. Pauses while editing."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    followAPR:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    footer:AddChild(followAPR)
    frame:SetCallback("OnClose", function(widget)
        if not self.forceClose and ((self.session and self.session:IsDirty()) or self:UnsavedCount() > 0) then
            widget:Show(); self:ConfirmClose(); return
        end
        if self.fieldPicker then self.fieldPicker:Hide() end
        self.pendingManualStep, self.stepScrollToken = nil, nil
        AprRC.TutoFrame:Close()
        status.width, status.height = widget.frame:GetWidth(), widget.frame:GetHeight()
        if self.session then self.session:Persist() end
        if self.timer then self:CancelTimer(self.timer); self.timer = nil end
        self:DetachLua()
        self.followAPRCheckbox = nil
        AprRC.CommandBarSetting:CancelDrag()
        AprRC.CommandBar:DetachWorkshop(widget.frame)
        GUI:Release(self.compactButton); self.compactButton = nil
        if self.confirm then self.confirm:Hide() end
        if self.nameDialog then self.nameDialog:Hide() end
        if self.importDialog then self.importDialog:Hide() end
        if self.mergeDialog then self.mergeDialog:Hide() end
        if self.closeDialog then self.closeDialog:Hide() end
        self.closeAfterSave = nil
        widget.frame:SetBackdropColor(0, 0, 0, 1)
        widget.frame:SetBackdropBorderColor(1, 1, 1, 1)
        widget.frame:SetClampedToScreen(wasClamped)
        if widget.frame.SetResizeBounds then widget.frame:SetResizeBounds(400, 200) else widget.frame:SetMinResize(400, 200) end
        self.frame, self.tabs, self.list, self.inspector, self.routeForm = nil, nil, nil, nil, nil
        GUI:Release(widget)
    end)
    self:RefreshRoutes()
    local name = self.session and self.session.name or AprRCData.CurrentRoute.name
    if not Model:Source(name) then name = AprRCData.Routes[1] and AprRCData.Routes[1].name end
    if name and Model:Source(name) then self:SelectRoute(name) else self.session = nil; self:SelectTab("steps") end
    frame:DoLayout()
    self.timer = self:ScheduleRepeatingTimer("Tick", 1)
    AprRC.CommandBar:RefreshFrameAnchor()
    AprRC.TutoFrame:OnWorkshopShow()
end
