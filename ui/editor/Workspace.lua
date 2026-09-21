local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local Model = AprRC.editorModel
local Editor = AprRC:NewModule("RouteEditor", "AceTimer-3.0")
AprRC.routeEditor = Editor
local sessions = {}

function UI.Body(parent, layout)
    local group = GUI:Create("SimpleGroup")
    group:SetLayout(layout or "APRWorkspace")
    group:SetUserData("body", true)
    parent:AddChild(group)
    return group
end

function UI.Scroll(parent)
    local widget = GUI:Create("ScrollFrame")
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
    local dialog = GUI:Create("Frame")
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

function Editor:UpdateStatus()
    if not self.frame then return end
    local session = self.session
    local dirty = session and session:IsDirty()
    local active = AprRC.settings.profile.recordBarFrame.isRecording
    self.recordButton:SetText(T(active and "Stop recording" or "Record this route"))
    self.recordButton:SetDisabled(not session or not AprRC.settings.profile.enableAddon)
    self.saveButton:SetDisabled(not session)
    self.copyButton:SetDisabled(not session)
    self.exportButton:SetDisabled(not session)
    local rawHistory = session and session.rawHistory
    local rawMode = self.tab == "lua" and rawHistory
    self.undoButton:SetDisabled(not session or (rawMode and session.rawCursor <= 1 or not rawMode and session.cursor <= 1))
    self.redoButton:SetDisabled(not session or (rawMode and session.rawCursor >= #rawHistory or not rawMode and session.cursor >= #session.history))
    local state = active and "|cffff7777● " .. T("Recording") .. "|r" or "|cffb3a58b" .. T("Recording stopped") .. "|r"
    if active then state = state .. "  ·  " .. AprRCData.CurrentRoute.name end
    self.recordStatus:SetText(state)
    self.summary:SetText(session and ("|cffedc36a" .. tostring(#session.draft.steps) .. " " .. T("Steps") .. "|r  ·  " ..
        (dirty and "|cffffcf66" .. T("Unsaved draft") or "|cff82d9a0" .. T("Saved")) .. "|r") or "")
    self.frame:SetStatusText(self.notice or (dirty and T("Follow pauses while you edit. Save or reload to resume.") or
        T("Drafts are kept when closing this window, switching routes or reloading the UI.")))
    if self.tab == "commands" then AprRC.CommandBarSetting:RefreshRunState() end
end

function Editor:Changed()
    self.notice = nil
    self.session:Snapshot()
    self:UpdateStatus()
    -- The timer updates summaries without disturbing keyboard focus in the form.
    self.listDirty = true
end

function Editor:FormContext()
    self.formModes, self.formPages = self.formModes or {}, self.formPages or {}
    return {
        modes = self.formModes, pages = self.formPages,
        changed = function() self:Changed() end,
        redraw = function() self:DrawInspector() end,
        error = function(reason) self:Message(reason, true) end,
    }
end

function Editor:SelectRoute(name)
    if self.session then self.session:Persist() end
    local route = Model:Source(name)
    if not route then return end
    if not sessions[name] then sessions[name] = Model:Open(route) end
    self.session = sessions[name]
    if not self.session:IsDirty() and self.session:IsStale() then self.session:Reload() end
    self.notice, self.query, self.filter, self.page = nil, "", "all", 1
    self.formModes, self.formPages = {}, {}
    self.routeDropdown:SetValue(name)
    if self.session.raw then self.tab = "lua" end
    self:SelectTab(self.tab or "steps")
    self:UpdateStatus()
end

function Editor:RefreshRoutes()
    local entries = {}
    for _, route in ipairs(AprRCData.Routes) do entries[route.name] = route.name end
    self.routeDropdown:SetList(entries)
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
    local dialog = GUI:Create("Frame")
    self.nameDialog = dialog
    dialog:SetTitle(T(copy and "Save a copy" or "New route"))
    dialog:SetWidth(490)
    dialog:SetHeight(230)
    dialog:EnableResize(false)
    dialog:SetLayout("Flow")
    local input = GUI:Create("EditBox")
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
    local ok, reason = self.session:Save()
    if not ok then
        self:Message(reason == "conflict" and T("The saved route changed. Save a copy to keep your edits, or reload the saved route.") or reason, true)
        return false
    end
    self.session.rawHistory = nil
    self:DrawTab()
    self:Message(T("Saved"))
    return true
end

function Editor:Export()
    if not self.session then return end
    local route, reason = self.session:Read()
    if not route then self:Message(reason, true); return end
    if not APR or not APRData then self:Message(T("APR is not available"), true); return end
    local name = route.name .. " - Custom"
    local definition = AprRC:BuildRouteDefinition(route)
    APRData.CustomRoute = APRData.CustomRoute or {}
    APR.RouteQuestStepList = APR.RouteQuestStepList or {}
    APRData.CustomRoute[name] = definition
    APR.RouteQuestStepList[name] = definition
    if APR.routeconfig and APR.routeconfig.SendMessage then APR.routeconfig:SendMessage("APR_Custom_Path_Update") end
    self:Message(T("Route exported to APR") .. ": " .. name)
    APR:PrintInfo(T("Route exported to APR") .. ": " .. name)
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
    if tab ~= "lua" and self.session and self.session.raw then
        local ok, reason = self.session:ApplyRaw()
        if not ok then
            self:Message(T("Finish editing the Lua table before opening the visual editor.") .. " " .. tostring(reason), true)
            tab = "lua"
        else
            self.session.rawHistory = nil
        end
    end
    self.tab = tab
    self.selectingTab = true
    self.tabs:SelectTab(tab)
    self.selectingTab = false
    self:DrawTab()
end

function Editor:DrawTab()
    self:DetachLua()
    self.list, self.inspector, self.listPanel, self.routeForm = nil, nil, nil, nil
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
    elseif self.tab == "route" then
        self.routeForm = UI.Scroll(self.tabs)
        self:DrawInspector()
    elseif self.tab == "lua" then
        self:DrawLua()
    end
    self.tabs:DoLayout()
    self.frame:DoLayout()
    self:UpdateStatus()
end

function Editor:DrawTools()
    local panel = UI.Scroll(self.tabs)
    UI.LabelWidget(panel, "|cffedc36a" .. T("Recording tools") .. "|r", true)
    UI.LabelWidget(panel, T("All existing commands, autocomplete dialogs and toolbar settings remain available here."))
    UI.Button(panel, "Settings", function() AprRC.settings:OpenSettings(AprRC.title) end)
    UI.Button(panel, "Command bar", function() AprRC.CommandBarSetting:Show() end, 190)
    UI.Button(panel, "Coordinates", function() AprRC.command:SlashCmd("coordframe") end)
    UI.Button(panel, "Extra line texts", function() AprRC.exportExtraLineText.Show() end, 190)
    UI.Button(panel, "Command reference", function() AprRC.options:PrintHelp() end, 190)
end

local function interacting(widget)
    local edit = widget.editBox or widget.editbox
    if edit and edit:HasFocus() or widget.open then return true end
    for _, child in ipairs(widget.children or {}) do
        if interacting(child) then return true end
    end
    return false
end

function Editor:Refresh()
    if not self.frame then return end
    if self.routeCount ~= #AprRCData.Routes then
        self:RefreshRoutes()
        if not self.session and AprRCData.Routes[1] then self:SelectRoute(AprRCData.Routes[1].name) end
    end
    if self.listDirty then self:DrawList() end
    local session = self.session
    if session and self.follow and not self.confirm and not self.nameDialog and not interacting(self.frame) and
        not session:IsDirty() and session:IsStale() then
        local atEnd = session.selected >= #session.draft.steps
        session:Reload()
        session.rawHistory = nil
        if atEnd then
            session.selected = math.max(1, #session.draft.steps)
            self.page = math.max(1, math.ceil(#session.draft.steps / UI.PageSize))
        end
        self:DrawTab()
        if atEnd and self.list then self.list:SetScroll(1000) end
        if self.luaBox then
            local frame = self.luaBox.scrollFrame
            frame:SetVerticalScroll(frame:GetVerticalScrollRange())
        end
    end
    self:UpdateStatus()
end

function Editor:Tick()
    -- Some game data can be unavailable/secret during combat. Keep the draft and
    -- try the next tick, matching the legacy editor's guarded live refresh.
    local ok, reason = pcall(self.Refresh, self)
    if not ok then AprRC:Debug("Route workshop refresh:", reason) end
end

function Editor:Hide()
    if self.frame then self.frame:Hide() end
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
    self.compactButton:SetText(T(self.compact and "Full width" or "Compact mode"))
    self:DrawTab()
end

function Editor:Show()
    if self.frame then self.frame:Show(); self.frame.frame:Raise(); return end
    local frame = GUI:Create("Frame")
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
    self.compactButton = UI.Button(header, self.compact and "Full width" or "Compact mode", function() self:ToggleCompact() end, 175)
    self.recordStatus = UI.LabelWidget(header, "")
    self.summary = UI.LabelWidget(header, "")
    self.tabs = GUI:Create("TabGroup")
    self.tabs:SetLayout("APRFill")
    self.tabs:SetAutoAdjustHeight(false)
    self.tabs:SetUserData("body", true)
    self.tabs:SetTabs({ { value = "steps", text = T("Steps") }, { value = "route", text = T("Route") },
        { value = "lua", text = T("Lua editor") }, { value = "commands", text = T("Commands") },
        { value = "tools", text = T("Tools") } })
    self.tabs:SetCallback("OnGroupSelected", function(_, _, tab) if not self.selectingTab then self:SelectTab(tab) end end)
    frame:AddChild(self.tabs)
    local footer = UI.Toolbar(frame, true)
    self.saveButton = UI.Button(footer, "Save", function() self:Save() end, 135)
    self.exportButton = UI.Button(footer, "Export to APR", function() self:Export() end, 170)
    self.copyButton = UI.Button(footer, "Save a copy", function() self:NameDialog(true) end, 195)
    self.undoButton = UI.Button(footer, "Undo", function() self:Undo(-1) end, 100)
    self.redoButton = UI.Button(footer, "Redo", function() self:Undo(1) end, 100)
    UI.Button(footer, "Reload saved route", function()
        local session = self.session
        if not session then return end
        local function reload()
            session:Reload(); session:Persist(); session.rawHistory = nil
            if self.session == session then self.notice = nil; self:DrawTab() end
        end
        if session:IsDirty() then self:Confirm(T("Discard this draft and reload the saved route?"), reload) else reload() end
    end, 205)
    local follow = GUI:Create("CheckBox")
    follow:SetLabel(T("Follow recording"))
    follow:SetWidth(205)
    self.follow = self.follow ~= false
    follow:SetValue(self.follow)
    follow:SetCallback("OnValueChanged", function(_, _, value) self.follow = value; self:Tick() end)
    footer:AddChild(follow)
    frame:SetCallback("OnClose", function(widget)
        status.width, status.height = widget.frame:GetWidth(), widget.frame:GetHeight()
        if self.session then self.session:Persist() end
        if self.timer then self:CancelTimer(self.timer); self.timer = nil end
        self:DetachLua()
        if self.confirm then self.confirm:Hide() end
        if self.nameDialog then self.nameDialog:Hide() end
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
end
