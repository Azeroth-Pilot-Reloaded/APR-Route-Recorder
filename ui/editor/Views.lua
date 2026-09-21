local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local Model = AprRC.editorModel
local Editor = AprRC.routeEditor
local PAGE_SIZE = 40
UI.PageSize = PAGE_SIZE
local gold, muted = "|cffedc36a", "|cffb3a58b"

function Editor:DrawSteps()
    local split = UI.Body(self.tabs, "APRSplit")
    self.listPanel = UI.Body(split)
    local heading = UI.Toolbar(self.listPanel)
    local search = GUI:Create("EditBox")
    search:SetLabel(T("Search steps"))
    search:SetFullWidth(true)
    search:DisableButton(true)
    search:SetText(self.query or "")
    search:SetCallback("OnTextChanged", function(_, _, text)
        self.query, self.page = text, 1
        self:DrawList()
        self.list:SetScroll(0)
    end)
    heading:AddChild(search)
    UI.Dropdown(heading, "", { all = T("All steps"), quests = T("Quests"), travel = T("Travel"), other = T("Other actions") },
        self.filter or "all", function(value)
            self.filter, self.page = value, 1
            self:DrawList(); self.list:SetScroll(0)
        end)
    self.list = UI.Scroll(self.listPanel)
    local footer = UI.Toolbar(self.listPanel, true)
    self.previousButton = UI.Button(footer, "Previous", function()
        self.page = self.page - 1; self:DrawList(); self.list:SetScroll(0)
    end, 100)
    self.nextButton = UI.Button(footer, "Next", function()
        self.page = self.page + 1; self:DrawList(); self.list:SetScroll(0)
    end, 100)
    UI.Button(footer, "Jump to latest", function()
        self.query, self.filter, self.page = "", "all", math.max(1, math.ceil(#self.session.draft.steps / PAGE_SIZE))
        self.session.selected = math.max(1, #self.session.draft.steps)
        self:DrawTab()
        self.list:SetScroll(1000)
    end, 155)
    self.pageLabel = UI.LabelWidget(footer, "")
    local entries = {}
    for key, definition in pairs(AprRC.options.step) do
        if definition.newStep then entries[key] = UI.Label(key) end
    end
    local addType = UI.Dropdown(footer, T("Add a step"), entries, self.addType or "Waypoint", function(key) self.addType = key end)
    addType:SetFullWidth(false)
    addType:SetRelativeWidth(0.72)
    UI.Button(footer, "Add", function()
        local key = addType:GetValue() or "Waypoint"
        local definition = AprRC.options.step[key]
        local step = AprRC:CopyData(definition.defaults or {})
        step[key] = UI.Form:Default(definition.schema)
        if key == "Waypoint" then
            -- APR uses a quest ID to identify waypoints; prefer this draft's context.
            step.Waypoint = 1
            for index = self.session.selected, 1, -1 do
                local previous = self.session.draft.steps[index] or {}
                local quest = previous.PickUp and previous.PickUp[1] or previous.Waypoint or
                    (previous.Qpart and next(previous.Qpart))
                if type(quest) == "number" and quest > 0 then step.Waypoint = quest; break end
            end
        end
        if AprRC.options.step[key].coord then AprRC:SetStepCoord(step, key == "Waypoint" and 5 or 15) end
        if not self.session:Insert(step, self.session.selected) then
            self:Message(T("A route can only have one completion step, at the end."), true)
            return
        end
        self.query, self.filter = "", "all"
        self.page = math.ceil(self.session.selected / PAGE_SIZE)
        self.formModes, self.formPages = {}, {}
        self:DrawTab()
    end, 100):SetRelativeWidth(0.27)
    local detail = UI.Body(split)
    self.inspector = UI.Scroll(detail)
    local actions = UI.Toolbar(detail, true)
    self.moveUp = UI.Button(actions, "Move up", function() self:Move(-1) end, 110)
    self.moveDown = UI.Button(actions, "Move down", function() self:Move(1) end, 110)
    self.duplicate = UI.Button(actions, "Duplicate", function()
        local session = self.session
        if session:Insert(session.draft.steps[session.selected], session.selected) then self:AfterStructureChange() end
    end, 110)
    self.delete = UI.Button(actions, "Delete", function()
        local session, index = self.session, self.session.selected
        local step = session.draft.steps[index]
        self:Confirm(T("Delete the selected step? You can undo this change."), function()
            if self.session == session and session.draft.steps[index] == step then
                session:Delete(index); self:AfterStructureChange()
            end
        end)
    end, 110)
    self.positionButton = UI.Button(actions, "Player position", function()
        local step = self.session.draft.steps[self.session.selected]
        local coord, zone = AprRC:GetPlayerCoord()
        if not coord then self:Message(T("Unable to read player coordinates."), true); return end
        step.Coord, step.Zone = coord, zone
        self:Changed(); self:DrawInspector()
    end, 175)
    local moveTo = GUI:Create("EditBox")
    moveTo:SetLabel(T("Move to step"))
    moveTo:SetWidth(125)
    moveTo:SetCallback("OnEnterPressed", function(_, _, text)
        local index = tonumber(text)
        if index and index % 1 == 0 and self.session:Move(self.session.selected, index) then self:AfterStructureChange() end
    end)
    actions:AddChild(moveTo)
    self:DrawList()
    self:DrawInspector()
end

function Editor:AfterStructureChange()
    local matches = Model:Filter(self.session.draft.steps, self.query, self.filter, UI.Label)
    for position, index in ipairs(matches) do
        if index == self.session.selected then self.page = math.ceil(position / PAGE_SIZE); break end
    end
    self.formModes, self.formPages = {}, {}
    self:DrawList()
    self:DrawInspector()
    self:UpdateStatus()
end

function Editor:Move(delta)
    local index = self.session.selected
    if self.session:Move(index, index + delta) then self:AfterStructureChange() end
end

local questIcons = {
    PickUp = "Interface\\GossipFrame\\AvailableQuestIcon", Done = "Interface\\GossipFrame\\ActiveQuestIcon",
    Qpart = "Interface\\Icons\\INV_Misc_Book_09", Step = "Interface\\Icons\\INV_Misc_Note_01",
}

function Editor:DrawList()
    if not self.list then return end
    local oldScroll = self.list.localstatus.scrollvalue or 0
    self.list:ReleaseChildren()
    self.listDirty = false
    local session = self.session
    local matches = Model:Filter(session.draft.steps, self.query, self.filter, UI.Label)
    local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page or 1, pages))
    self.pageLabel:SetText(muted .. #matches .. " " .. T("Steps") .. "  ·  " .. self.page .. " / " .. pages .. "|r")
    self.previousButton:SetDisabled(self.page <= 1)
    self.nextButton:SetDisabled(self.page >= pages)
    if #matches == 0 then
        UI.LabelWidget(self.list, T(#session.draft.steps == 0 and
            "No steps yet. Record in game, or choose a step type below." or "No matching steps."))
    end
    for position = (self.page - 1) * PAGE_SIZE + 1, math.min(self.page * PAGE_SIZE, #matches) do
        local index = matches[position]
        local step = session.draft.steps[index]
        local key, detail, category = Model:Summary(step)
        local metadata = {}
        if step.Zone then
            local map = C_Map.GetMapInfo and C_Map.GetMapInfo(tonumber(step.Zone) or 0)
            metadata[#metadata + 1] = map and map.name or ("Map " .. tostring(step.Zone))
        end
        if type(step.Coord) == "table" then metadata[#metadata + 1] = "x: " .. tostring(step.Coord.x or "?") .. "   y: " .. tostring(step.Coord.y or "?") end
        local conditionCount = 0
        for field in pairs(step) do
            if AprRC.options.step[field] and AprRC.options.step[field].condition then conditionCount = conditionCount + 1 end
        end
        if conditionCount > 0 then metadata[#metadata + 1] = conditionCount .. " " .. T("Conditions") end
        local color = key == "PickUp" and { 1, 0.82, 0.28 } or key == "Done" and { 0.45, 0.90, 0.55 } or
            category == "travel" and { 0.50, 0.76, 1 } or { 0.89, 0.80, 0.62 }
        local definition = AprRC.options.step[key]
        local row = GUI:Create("APRStepRow")
        row:SetStep(index, UI.Label(key), detail, table.concat(metadata, "  ·  "),
            questIcons[key] or (definition and definition.icon) or questIcons.Step, index == session.selected, color)
        row:SetCallback("OnClick", function()
            session.selected = index
            session:Persist()
            self.formModes, self.formPages = {}, {}
            self:DrawList(); self:DrawInspector()
            self.inspector:SetScroll(0)
        end)
        row:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(row.frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(index .. ". " .. UI.Label(key), 1, 0.82, 0.4)
            if detail ~= "" then GameTooltip:AddLine(detail, 1, 1, 1, true) end
            GameTooltip:AddLine(table.concat(metadata, "\n"), 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        self.list:AddChild(row)
    end
    self.list:DoLayout()
    self.list:SetScroll(oldScroll)
end

function Editor:DrawInspector()
    local panel = self.routeForm or self.inspector
    if not panel then return end
    local oldScroll = panel.localstatus.scrollvalue or 0
    panel:ReleaseChildren()
    local session = self.session
    local context = self:FormContext()
    if self.routeForm then
        UI.LabelWidget(panel, gold .. T("Route") .. "|r", true)
        UI.LabelWidget(panel, muted .. session.name .. "|r")
        UI.Form:Render(panel, "route", session.draft, function(value) session.draft = value end,
            context, "route", T("Route"))
    else
        local step = session.draft.steps[session.selected]
        self.moveUp:SetDisabled(not step or session.selected == 1 or step.RouteCompleted)
        self.moveDown:SetDisabled(not step or session.selected == #session.draft.steps or step.RouteCompleted or
            (session.draft.steps[session.selected + 1] or {}).RouteCompleted)
        self.duplicate:SetDisabled(not step or step.RouteCompleted)
        self.delete:SetDisabled(not step)
        self.positionButton:SetDisabled(not step)
        if step then
            local key, detail = Model:Summary(step)
            UI.LabelWidget(panel, gold .. T("Step") .. " " .. session.selected .. " · " .. UI.Label(key) .. "|r", true)
            if detail ~= "" then UI.LabelWidget(panel, detail) end
            UI.Form:Render(panel, "step", step, function(value) session.draft.steps[session.selected] = value end,
                context, "step", T("Step"))
        else
            UI.LabelWidget(panel, T("Select a step to edit it."))
        end
    end
    panel:DoLayout()
    panel:SetScroll(oldScroll)
end

function Editor:DetachLua()
    if self.luaBox then
        self.luaBox.editBox:SetScript("OnKeyDown", self.luaKeyDown)
        self.luaBox:SetCallback("OnTextChanged", nil)
        self.luaBox = nil
        AprRC.export.editbox = nil
    end
end

function Editor:DrawLua()
    local container = UI.Body(self.tabs)
    UI.LabelWidget(container, T("Ctrl+A then Ctrl+C to copy. Ctrl+Z / Ctrl+Y to undo / redo."))
    local edit = GUI:Create("MultiLineEditBox")
    edit:SetLabel("")
    edit:DisableButton(true)
    edit:SetUserData("body", true)
    container:AddChild(edit)
    self.luaBox, AprRC.export.editbox = edit, edit
    local session = self.session
    local text = session.raw or Model:RouteText(session.draft)
    edit:SetText(text)
    if not session.rawHistory then
        session.rawHistory, session.rawCursor = { { text = text, cursor = 0 } }, 1
    end
    self.luaPreviousLength = #text
    local indenting = false
    edit:SetCallback("OnTextChanged", function(_, _, value)
        if self.settingLua or indenting then return end
        local box = edit.editBox
        value = box:GetText() or value or ""
        if #value > self.luaPreviousLength then
            local before = value:sub(1, box:GetCursorPosition())
            if before:sub(-1) == "\n" then
                local line = before:sub(1, -2):match("([^\n]*)$") or ""
                local indent = line:match("^([ \t]+)")
                if indent then
                    indenting = true; box:Insert(indent); indenting = false
                    value = box:GetText()
                end
            end
        end
        self.luaPreviousLength = #value
        session.raw = value
        local history = session.rawHistory
        if history[session.rawCursor].text ~= value then
            for index = #history, session.rawCursor + 1, -1 do history[index] = nil end
            history[#history + 1] = { text = value, cursor = box:GetCursorPosition() }
            if #history > 50 then table.remove(history, 1) end
            session.rawCursor = #history
        end
        session:Persist()
        self.notice = nil
        self:UpdateStatus()
    end)
    self.luaKeyDown = edit.editBox:GetScript("OnKeyDown")
    edit.editBox:SetScript("OnKeyDown", function(box, key, ...)
        if IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown()) then
            if key == "Z" then self:Undo(IsShiftKeyDown() and 1 or -1); return end
            if key == "Y" then self:Undo(1); return end
        end
        if self.luaKeyDown then self.luaKeyDown(box, key, ...) end
    end)
end

function Editor:Undo(delta)
    local session = self.session
    if not session then return end
    if self.tab == "lua" and self.luaBox then
        local index = session.rawCursor + delta
        local snapshot = session.rawHistory[index]
        if not snapshot then return end
        session.rawCursor, session.raw = index, snapshot.text
        self.settingLua = true
        self.luaBox:SetText(snapshot.text)
        self.luaBox.editBox:SetCursorPosition(math.min(snapshot.cursor, #snapshot.text))
        self.luaPreviousLength = #snapshot.text
        self.settingLua = false
        session:Persist()
        self:UpdateStatus()
    elseif session:Undo(delta) then
        self.formModes, self.formPages = {}, {}
        self:DrawTab()
    end
end
