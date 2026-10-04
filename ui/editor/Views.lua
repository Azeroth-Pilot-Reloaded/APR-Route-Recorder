local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI
local T = UI.Text
local Model = AprRC.editorModel
local Editor = AprRC.routeEditor
local PAGE_SIZE = 40
UI.PageSize = PAGE_SIZE
local gold, muted = "|cffedc36a", "|cffb3a58b"

-- Both tabs use the same list, forms and actions; only the collection changes.
function Editor:StepGroup()
    return self.tab == "parallel" and self.session.parallelGroup or nil
end

function Editor:Steps()
    return self.session:GetSteps(self:StepGroup())
end

function Editor:SelectedStep()
    return self.session:GetSelected(self:StepGroup())
end

function Editor:ResetParallelView()
    self.query, self.filter, self.page = "", "all", 1
    self.formModes, self.formPages, self.editGroupConditions = {}, {}, nil
    self.session:Persist()
    self:DrawTab()
end

function Editor:DrawParallelSteps()
    self.session:ClampSelection()
    local session = self.session
    local groups = session.draft.parallelSteps or {}
    local group = groups[session.parallelGroup]
    local body = UI.Body(self.tabs)
    local toolbar = UI.Toolbar(body)
    local entries = {}
    for index in ipairs(groups) do entries[index] = T("Parallel group") .. " " .. index end
    self.parallelPicker = UI.Dropdown(toolbar, UI.Label("parallelSteps"), entries,
        group and session.parallelGroup or nil, function(index)
            session.parallelGroup, session.parallelSelected = index, 1
            self:ResetParallelView()
        end)
    self.parallelPicker:SetFullWidth(false)
    self.parallelPicker:SetWidth(210)
    self.addGroup = UI.Button(toolbar, "Add group", function()
        session:InsertGroup(); self:ResetParallelView()
    end)
    self.duplicateGroup = UI.IconButton(toolbar, "duplicate", "Duplicate group", function()
        if group then session:InsertGroup(group); self:ResetParallelView() end
    end)
    self.deleteGroup = UI.IconButton(toolbar, "trash", "Delete group", function()
        local index = session.parallelGroup
        self:Confirm(T("Delete this parallel group and all its steps? You can undo this change."), function()
            if self.session == session and (session.draft.parallelSteps or {})[index] == group then
                session:DeleteGroup(index); self:ResetParallelView()
            end
        end)
    end)
    self.groupUp = UI.IconButton(toolbar, "up", "Move group up", function()
        if session:MoveGroup(session.parallelGroup, session.parallelGroup - 1) then self:ResetParallelView() end
    end)
    self.groupDown = UI.IconButton(toolbar, "down", "Move group down", function()
        if session:MoveGroup(session.parallelGroup, session.parallelGroup + 1) then self:ResetParallelView() end
    end)
    self.groupConditions = UI.Button(toolbar, "Group conditions", function()
        self.editGroupConditions = true
        self.formModes, self.formPages = {}, {}
        self:DrawInspector()
        self.inspector:SetScroll(0)
        self:ShowStepPane("inspector")
    end, 190)
    self.duplicateGroup:SetDisabled(not group)
    self.deleteGroup:SetDisabled(not group)
    self.groupUp:SetDisabled(not group or session.parallelGroup == 1)
    self.groupDown:SetDisabled(not group or session.parallelGroup == #groups)
    self.groupConditions:SetDisabled(not group)
    if group then
        self:DrawSteps(body)
    else
        UI.LabelWidget(UI.Scroll(body), T("No parallel groups yet. Add a group, then configure its conditions and steps."))
    end
end

function Editor:DrawSteps(parent)
    local split = AprRC:CreateWidget("APRSplitGroup")
    split:SetLayout("APRSplit")
    split:SetUserData("body", true)
    split:SetRatio(AprRC.settings.profile.editorFrame.stepPaneRatio)
    split:SetCallback("OnRatioChanged", function(_, _, ratio)
        AprRC.settings.profile.editorFrame.stepPaneRatio = ratio
    end)
    local container = parent or self.tabs
    container:AddChild(split)
    self.stepsSplit = split
    split.frame:EnableKeyboard(true)
    split.frame:SetPropagateKeyboardInput(true)
    split.frame:SetScript("OnKeyDown", function(frame, key)
        frame:SetPropagateKeyboardInput(not self:HandleStepKey(key))
    end)
    split.content.aprCompactPane = self.compact and (self.compactPane or "list") or nil
    self.listPanel = UI.Body(split)
    local heading = UI.Toolbar(self.listPanel)
    if self.compact and not self:StepGroup() then
        UI.Button(heading, "Show inspector", function() self:ShowStepPane("inspector") end, 210)
    end
    local search = AprRC:CreateWidget("EditBox")
    search:SetLabel(T("Search steps"))
    search:SetFullWidth(true)
    search:DisableButton(true)
    search:SetText(self.query or "")
    search:SetCallback("OnTextChanged", function(_, _, text)
        self:MarkInteraction()
        self.query, self.page = text, 1
        self:DrawList()
        self.list:SetScroll(0)
    end)
    heading:AddChild(search)
    UI.Dropdown(heading, "", { all = T("All steps"), quests = T("Quests"), travel = T("Travel"), other = T("Other actions") },
        self.filter or "all", function(value)
            self:MarkInteraction()
            self.filter, self.page = value, 1
            self:DrawList(); self.list:SetScroll(0)
        end)
    self.list = UI.Scroll(self.listPanel)
    local footer = UI.Toolbar(self.listPanel, true)
    self.previousButton = UI.IconButton(footer, "previous", "Previous", function()
        self:MarkInteraction()
        self.page = self.page - 1; self:DrawList(); self.list:SetScroll(0)
    end)
    self.nextButton = UI.IconButton(footer, "next", "Next", function()
        self:MarkInteraction()
        self.page = self.page + 1; self:DrawList(); self.list:SetScroll(0)
    end)
    UI.Button(footer, "Jump to latest", function()
        self:MarkInteraction()
        self.editGroupConditions = nil
        self.query, self.filter, self.page = "", "all", math.max(1, math.ceil(#self:Steps() / PAGE_SIZE))
        self.session:SetSelected(math.max(1, #self:Steps()), self:StepGroup())
        self:DrawTab()
        self.list:SetScroll(1000)
    end, 155)
    self.pageLabel = UI.LabelWidget(footer, "")
    local entries = {}
    for key, definition in pairs(AprRC.options.step) do
        if definition.newStep then entries[key] = UI.Label(key) end
    end
    local addButton
    local addType = UI.SearchSelect(footer, T("Add a step"), entries, self.addType or "Waypoint", function(key)
        self.addType = key
        if addButton then addButton:SetDisabled(not key) end
    end)
    addType:SetFullWidth(false)
    addType:SetRelativeWidth(0.72)
    addButton = UI.Button(footer, "Add", function()
        local key = addType:GetValue()
        if not key then return end
        local definition = AprRC.options.step[key]
        local step = AprRC:CopyData(definition.defaults or {})
        step[key] = UI.Form:Default(definition.schema)
        if key == "Waypoint" then
            -- APR uses a quest ID to identify waypoints; prefer this draft's context.
            step.Waypoint = 1
            for index = self:SelectedStep(), 1, -1 do
                local previous = self:Steps()[index] or {}
                local quest = previous.PickUp and previous.PickUp[1] or previous.Waypoint or
                    (previous.Qpart and next(previous.Qpart))
                if type(quest) == "number" and quest > 0 then step.Waypoint = quest; break end
            end
        end
        if AprRC.options.step[key].coord then AprRC:SetStepCoord(step, key == "Waypoint" and 5 or 15) end
        if not self.session:Insert(step, self:SelectedStep(), self:StepGroup()) then
            self:Message(T("A route can only have one completion step, at the end."), true)
            return
        end
        self.editGroupConditions = nil
        self.query, self.filter = "", "all"
        self.page = math.ceil(self:SelectedStep() / PAGE_SIZE)
        self.formModes, self.formPages = {}, {}
        self:DrawTab()
        self:ScrollToStep(self:SelectedStep(), self:StepGroup())
    end, 100)
    addButton:SetRelativeWidth(0.27)
    addButton:SetDisabled(not addType:GetValue())
    local detail = UI.Body(split)
    local navigation = UI.Toolbar(detail)
    navigation:SetLayout("APRInspectorHeader")
    local back = UI.Group(navigation)
    if self.compact then
        UI.Button(back, "Back to steps", function() self:ShowStepPane("list") end, 210)
    end
    self.stepPrevious = UI.IconButton(navigation, "previous", "Previous step", function()
        self:SelectStep(self:SelectedStep() - 1)
    end)
    self.stepNext = UI.IconButton(navigation, "next", "Next step", function()
        self:SelectStep(self:SelectedStep() + 1)
    end)
    self.inspector = UI.Scroll(detail)
    local actions = UI.Toolbar(detail, true)
    self.moveUp = UI.IconButton(actions, "up", "Move up", function() self:Move(-1) end)
    self.moveDown = UI.IconButton(actions, "down", "Move down", function() self:Move(1) end)
    self.duplicate = UI.IconButton(actions, "duplicate", "Duplicate", function()
        local session = self.session
        if session:Insert(self:Steps()[self:SelectedStep()], self:SelectedStep(), self:StepGroup()) then
            self:AfterStructureChange()
            self:ScrollToStep(self:SelectedStep(), self:StepGroup())
        end
    end)
    self.delete = UI.IconButton(actions, "trash", "Delete", function()
        local session, index, groupIndex = self.session, self:SelectedStep(), self:StepGroup()
        local step = self:Steps()[index]
        self:Confirm(T("Delete the selected step? You can undo this change."), function()
            if self.session == session and session:GetSteps(groupIndex)[index] == step then
                session:Delete(index, groupIndex); self:AfterStructureChange()
            end
        end)
    end)
    self.positionButton = UI.Button(actions, "Player position", function()
        local step = self:Steps()[self:SelectedStep()]
        local coord, zone = AprRC:GetPlayerCoord()
        if not coord then self:Message(T("Unable to read player coordinates."), true); return end
        step.Coord, step.Zone = coord, zone
        self:Changed(); self:DrawInspector()
    end, 175)
    local moveTo = AprRC:CreateWidget("EditBox")
    self.moveTo = moveTo
    moveTo:SetLabel(T("Move to step"))
    moveTo:SetWidth(125)
    moveTo:SetCallback("OnEnterPressed", function(_, _, text)
        local index = tonumber(text)
        if index and index % 1 == 0 and self.session:Move(self:SelectedStep(), index, self:StepGroup()) then self:AfterStructureChange() end
    end)
    actions:AddChild(moveTo)
    self:DrawList()
    self:DrawInspector()
end

function Editor:SelectStep(index, openInspector, automatic)
    if not self:Steps()[index] then return false end
    if not automatic then self:MarkInteraction() end
    GUI:ClearFocus()
    if self.fieldPicker then self.fieldPicker:Hide() end
    self.session:SetSelected(index, self:StepGroup())
    self.editGroupConditions = nil
    local matches = Model:Filter(self:Steps(), self.query, self.filter, UI.Label)
    local position
    for offset, candidate in ipairs(matches) do
        if candidate == index then position = offset; break end
    end
    if not position then self.query, self.filter, position = "", "all", index end
    self.page = math.ceil(position / PAGE_SIZE)
    self.session:Persist()
    self.formModes, self.formPages = {}, {}
    self:DrawList(); self:DrawInspector()
    self.inspector:SetScroll(0)
    if openInspector and self.compact then self:ShowStepPane("inspector") end
    self:ScrollToStep(index, self:StepGroup())
    return true
end

function Editor:ShowStepPane(pane)
    self.compactPane = pane
    GUI:ClearFocus()
    if self.stepsSplit and (self.tab == "steps" or self.tab == "parallel") then
        self.stepsSplit.content.aprCompactPane = self.compact and pane or nil
        self.stepsSplit:DoLayout()
    end
end

function Editor:AfterStructureChange()
    local matches = Model:Filter(self:Steps(), self.query, self.filter, UI.Label)
    for position, index in ipairs(matches) do
        if index == self:SelectedStep() then self.page = math.ceil(position / PAGE_SIZE); break end
    end
    self.formModes, self.formPages, self.editGroupConditions = {}, {}, nil
    self:DrawList()
    self:DrawInspector()
    self:UpdateStatus()
end

function Editor:Move(delta)
    local index = self:SelectedStep()
    if self.session:Move(index, index + delta, self:StepGroup()) then self:AfterStructureChange() end
end

local questIcons = {
    PickUp = "Interface\\GossipFrame\\AvailableQuestIcon", Done = "Interface\\GossipFrame\\ActiveQuestIcon",
    Qpart = "Interface\\Icons\\INV_Misc_Book_09", Step = "Interface\\Icons\\INV_Misc_Note_01",
}

function Editor:DrawList()
    if not self.list then return end
    local oldScroll = self.list.localstatus.scrollvalue or 0
    self.list:PauseLayout()
    self.list:ReleaseChildren()
    local session = self.session
    local matches = Model:Filter(self:Steps(), self.query, self.filter, UI.Label)
    local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page or 1, pages))
    self.pageLabel:SetText(muted .. #matches .. " " .. T("Steps") .. "  ·  " .. self.page .. " / " .. pages .. "|r")
    self.previousButton:SetDisabled(self.page <= 1)
    self.nextButton:SetDisabled(self.page >= pages)
    if #matches == 0 then
        local empty = self:StepGroup() and "No parallel steps yet. Choose a step type below." or
            "No steps yet. Record in game, or choose a step type below."
        UI.LabelWidget(self.list, T(#self:Steps() == 0 and empty or "No matching steps."))
    end
    for position = (self.page - 1) * PAGE_SIZE + 1, math.min(self.page * PAGE_SIZE, #matches) do
        local index = matches[position]
        local step = self:Steps()[index]
        local key, detail, category, rawDetail = Model:Summary(step)
        local metadata = {}
        if step.Zone then
            local map = C_Map.GetMapInfo and C_Map.GetMapInfo(tonumber(step.Zone) or 0)
            metadata[#metadata + 1] = map and map.name or (UI.Label("mapID") .. " " .. tostring(step.Zone))
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
        local row = AprRC:CreateWidget("APRStepRow")
        row:SetUserData("stepIndex", index)
        row:SetStep(index, UI.Label(key), detail, table.concat(metadata, "  ·  "),
            questIcons[key] or (definition and definition.icon) or questIcons.Step, index == self:SelectedStep(), color)
        local group = self:StepGroup() and session.draft.parallelSteps[self:StepGroup()]
        row:SetConditionBadges(UI.ConditionBadges(step, group and group.conditions))
        row:SetCallback("OnClick", function()
            self:SelectStep(index, true)
        end)
        row:SetCallback("OnEnter", function()
            UI.ShowStepTooltip(row, index .. ". " .. UI.Label(key), rawDetail, table.concat(metadata, "\n"),
                step, group and group.conditions)
        end)
        self.list:AddChild(row)
    end
    self.list:ResumeLayout()
    self.list:DoLayout()
    self.list:SetScroll(oldScroll)
end

-- Every complex block opens at the same width, regardless of nesting depth.
function Editor:DrawFormPage(panel, context, root, trail, overview, description)
    local nodes = UI.Form:Nodes(root, trail)
    local node = nodes[#nodes]
    local function navigate()
        GUI:ClearFocus()
        if self.fieldPicker then self.fieldPicker:Hide() end
        self:DrawInspector()
        panel:SetScroll(0)
    end
    context.navigate = function(key)
        trail[#trail + 1] = key
        navigate()
    end
    if #nodes > 1 then
        local toolbar = UI.Group(panel)
        UI.Button(toolbar, overview, function()
            for index = #trail, 1, -1 do trail[index] = nil end
            navigate()
        end, 190)
        UI.IconButton(toolbar, "previous", "Previous", function() table.remove(trail); navigate() end)
        local breadcrumbs = {}
        for index = math.max(1, #nodes - 3), #nodes do breadcrumbs[#breadcrumbs + 1] = nodes[index].label end
        UI.LabelWidget(panel, muted .. table.concat(breadcrumbs, " > ") .. "|r")
    elseif description and description ~= "" then
        UI.LabelWidget(panel, muted .. description .. "|r")
    end
    UI.LabelWidget(panel, gold .. node.label .. "|r", true)
    UI.Form:Render(panel, node.schema, node.value, node.set, context, node.path, node.label)
end

function Editor:DrawInspector()
    AprRC.TutoFrame:ClearPointer()
    self.stepDescription = nil
    local panel = self.routeForm or self.inspector
    if not panel then return end
    local oldScroll = panel.localstatus.scrollvalue or 0
    panel:SetLayout("APRForm")
    panel:ReleaseChildren()
    local session = self.session
    local context = self:FormContext()
    if self.routeForm then
        self.routeFormTrail = self.routeFormTrail or {}
        self:DrawFormPage(panel, context, { schema = "route", value = session.draft,
            set = function(value) session.draft = value end, path = "route", label = T("Route") },
            self.routeFormTrail, "Route overview", session.name)
    else
        local step = not self.editGroupConditions and self:Steps()[self:SelectedStep()]
        self.stepPrevious:SetDisabled(not step or self:SelectedStep() <= 1)
        self.stepNext:SetDisabled(not step or self:SelectedStep() >= #self:Steps())
        self.moveUp:SetDisabled(not step or self:SelectedStep() == 1 or step.RouteCompleted)
        self.moveDown:SetDisabled(not step or self:SelectedStep() == #self:Steps() or step.RouteCompleted or
            (self:Steps()[self:SelectedStep() + 1] or {}).RouteCompleted)
        self.duplicate:SetDisabled(not step or step.RouteCompleted)
        self.delete:SetDisabled(not step)
        self.positionButton:SetDisabled(not step)
        self.moveTo:SetDisabled(not step)
        if self.editGroupConditions and self:StepGroup() then
            local groupIndex = self:StepGroup()
            local group = session.draft.parallelSteps[groupIndex]
            local path = "route/parallelSteps/" .. groupIndex .. "/conditions"
            context.inlineSections = true
            UI.Button(panel, "Back to step", function()
                self.editGroupConditions = nil
                self.formModes, self.formPages = {}, {}
                self:DrawInspector()
            end)
            UI.LabelWidget(panel, gold .. T("Parallel group") .. " " .. groupIndex .. " · " .. T("Conditions") .. "|r", true)
            UI.Form:Render(panel, "conditions", group.conditions, function(value) group.conditions = value end,
                context, path, T("Conditions"))
        elseif step then
            local key, detail = Model:Summary(step)
            local title = T("Step") .. " " .. self:SelectedStep() .. " · " .. UI.Label(key)
            UI.LabelWidget(panel, gold .. title .. "|r", true)
            if detail ~= "" then self.stepDescription = UI.LabelWidget(panel, detail) end
            if self:StepGroup() then
                local steps, index = self:Steps(), self:SelectedStep()
                local path = "route/parallelSteps/" .. self:StepGroup() .. "/steps/" .. index
                context.inlineSections = true
                UI.Form:Render(panel, "step", step, function(value) steps[index] = value end,
                    context, path, T("Step"))
            else
                UI.Form:Render(panel, "step", step, function(value) self:Steps()[self:SelectedStep()] = value end,
                    context, "step", T("Step"))
            end
        else
            UI.LabelWidget(panel, T("Select a step to edit it."))
        end
    end
    panel:DoLayout()
    panel:SetScroll(oldScroll)
    AprRC.TutoFrame:RefreshPointer()
end

function Editor:DetachLua()
    self:DetachLuaTools()
    self.stepScrollToken = nil
    self.luaScrollToken = nil
    self.luaStepPositions, self.luaAPRPosition = nil, nil
    if self.luaFindInput then
        self.luaFindInput.editbox:SetScript("OnEscapePressed", self.luaFindEscape)
    end
    self.luaFindBar, self.luaFindInput, self.luaFindStatus = nil, nil, nil
    self.luaFindPrevious, self.luaFindNext, self.luaFindResults, self.luaFindIndex = nil, nil, nil, nil
    if self.luaBox then
        self.luaBox:SetFoldingInput(nil)
        self.luaBox:SetCommandHandler(nil)
        self.luaBox:CancelFoldingChord()
        self.luaBox.editBox:SetScript("OnKeyDown", self.luaKeyDown)
        self.luaBox:SetCallback("OnTextChanged", nil)
        self.luaBox = nil
        AprRC.export.editbox = nil
    end
end

function Editor:DrawLua()
    local container = UI.Body(self.tabs)
    local edit = AprRC:CreateWidget("APRLuaEditor")
    edit.autoIndent = true
    edit:SetLabel("")
    edit:DisableButton(true)
    edit:SetUserData("body", true)
    container:AddChild(edit)
    self.luaBox, AprRC.export.editbox = edit, edit
    self:WatchScrollInteraction(edit.scrollFrame, edit.scrollBar)
    local session = self.session
    local text = session.raw
    if not text then text, self.luaStepPositions = Model:RouteText(session.draft, true) end
    edit:SetText(text)
    local folding = UI.Toolbar(container)
    folding:SetLayout("APRCompactToolbar"); self.luaToolbar = folding
    table.remove(container.children); table.insert(container.children, #container.children, folding)
    UI.IconButton(folding, "compact", "Fold all", function() edit:FoldAll(true); edit:SetFocus() end)
    UI.IconButton(folding, "expand", "Unfold all", function() edit:UnfoldAll(); edit:SetFocus() end)
    UI.IconButton(folding, "compare", "Compare versions", function() self:OpenVersionDiff() end)
    local shortcutText = T("Lua shortcuts") .. "\n" .. T("Ctrl+S: save. Ctrl+L: select line. Ctrl+H: replace.") .. "\n" ..
        T("Ctrl+Space: APR completion. Shift+Alt+F: format. Ctrl+Shift+O: step outline. F8 / Shift+F8: errors.") .. "\n" ..
        T("Ctrl+A then Ctrl+C to copy. Ctrl+Z / Ctrl+Y to undo / redo.") .. "\n" ..
        T("Ctrl+F to search. Enter / Shift+Enter: next / previous. Esc: close.") .. "\n" ..
        T("Click + / - to fold or unfold a Lua table.") .. " " .. T("Shift+wheel: horizontal scroll.") .. "\n" ..
        "Ctrl+K Ctrl+0: " .. T("Fold all") .. "\nCtrl+K Ctrl+J: " .. T("Unfold all") ..
        "\nCtrl+Shift+[ / ]: " .. T("Fold / unfold section") ..
        "\nCtrl+K Ctrl+[ / ]: " .. T("Fold / unfold recursively") ..
        "\nCtrl+K Ctrl+L: " .. T("Toggle section folding") ..
        "\nCtrl+K Ctrl+1 … 7: " .. T("Fold by level") ..
        "\nCtrl+K Ctrl+8 / 9: " .. T("Fold / unfold regions") ..
        "\nCtrl+K Ctrl+/: " .. T("Fold block comments") .. "\n" .. T("Shift+click: include nested sections.")
    local help = UI.IconButton(folding, "help", "Folding shortcuts", function() end)
    edit:SetCallback("OnFoldingChordChanged", function(_, _, pending)
        help:SetText(pending and "Ctrl+K …" or T("Folding shortcuts"))
    end)
    local function showHelp()
        GameTooltip:SetOwner(help.frame, "ANCHOR_TOP")
        AprRC:AddTooltipLine(GameTooltip, shortcutText, 1, 1, 1, true); GameTooltip:Show()
    end
    help:SetCallback("OnClick", showHelp); help:SetCallback("OnEnter", showHelp)
    help:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    if not session.rawHistory then
        session.rawHistory, session.rawCursor = { { text = text, cursor = 0 } }, 1
    end
    self.luaPreviousLength = #text
    edit:SetCallback("OnTextChanged", function(_, _, value, autoIndent)
        if self.settingLua then return end
        self:MarkInteraction()
        local box = edit.editBox
        value = value or box:GetText() or ""
        self.luaPreviousLength = #value
        local wasDirty, hadNotice = session:IsDirty(), self.notice ~= nil
        local couldUndo = session.rawCursor > 1
        local couldRedo = session.rawCursor < #session.rawHistory
        session:SetRaw(value)
        session.followPaused = true
        session:Touch()
        local history = session.rawHistory
        if history[session.rawCursor].text ~= value then
            if autoIndent then history[session.rawCursor] = { text = value, cursor = box:GetCursorPosition() }
            else
                for index = #history, session.rawCursor + 1, -1 do history[index] = nil end
                history[#history + 1] = { text = value, cursor = box:GetCursorPosition() }
            end
            if #history > 50 then table.remove(history, 1) end
            session.rawCursor = #history
        end
        session:Persist()
        self:LuaInputChanged(edit)
        self.notice = nil
        if self.luaFindBar and not edit.pendingCode then self:FindLua(0, true, true) end
        if not wasDirty or hadNotice or couldUndo ~= (session.rawCursor > 1) or
            couldRedo ~= (session.rawCursor < #history) then self:UpdateStatus() end
    end)
    edit:SetCallback("OnCodeSettled", function()
        if self.luaBox == edit and self.luaFindBar then self:FindLua(0, true, true) end
        if self.luaBox == edit then self:AnalyzeLua(edit) end
    end)
    edit:SetCallback("OnCodeCursorChanged", function(_, _, cursor)
        local snapshot = session.rawHistory and session.rawHistory[session.rawCursor]
        if edit.pendingCode and snapshot and snapshot.text == edit:GetText() then snapshot.cursor = cursor end
        if self.luaCompletion and self.luaCompletion.context.cursor ~= cursor then self:CloseLuaCompletion() end
    end)
    edit:SetCallback("OnScrollChanged", function() if self.luaCompletion then self:DrawLuaCompletion() end end)
    self.luaKeyDown = edit.editBox:GetScript("OnKeyDown")
    edit.editBox:SetScript("OnKeyDown", function(box, key, ...)
        if edit:HandleEditorKey(key) then return end
        if IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown()) then
            if key == "F" then self:OpenLuaFind(); return end
            if key == "Z" then self:Undo(IsShiftKeyDown() and 1 or -1); return end
            if key == "Y" then self:Undo(1); return end
        end
        if self.luaKeyDown then self.luaKeyDown(box, key, ...) end
    end)
    self:AttachLuaTools(container, edit, session)
end

function Editor:FollowLuaAPRStep(index, group, recenter)
    local positions = self.luaStepPositions
    local steps = positions and (group and positions.parallelSteps[group] or positions.steps)
    local range = steps and steps[index]
    if not range then return end
    local previous = self.luaAPRPosition
    if not recenter and previous and previous.positions == positions and previous.index == index and previous.group == group then return end
    self.luaAPRPosition = { positions = positions, index = index, group = group }
    local widget, session, token = self.luaBox, self.session, {}
    self.luaScrollToken = token
    local function scroll()
        -- AceGUI's OnCursorChanged scrolls the target line into view.
        widget.editBox:SetCursorPosition(range.start)
    end
    scroll()
    C_Timer.After(0, function()
        if self.luaScrollToken ~= token or self.luaBox ~= widget or self.session ~= session or
            session:IsDirty() or self.luaFindBar or not AprRC.settings.profile.followAPR then return end
        local currentIndex, currentGroup = AprRC:GetAPRPlaybackSelection(session.name)
        if currentIndex == index and currentGroup == group then scroll() end
    end)
end

function Editor:RevealLuaError(location)
    if not location or not self.luaBox then return end
    local widget, first = self.luaBox, location.position - 1
    local text = widget:GetText()
    local last = math.min(#text, first + 1)
    while last < #text and text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last = last + 1 end
    widget:SetCursorPosition(first)
    widget:HighlightText(first, last)
    widget:CenterRange(first, last)
end

function Editor:OpenLuaFind()
    if not self.luaBox then return end
    self:CloseLuaCompletion()
    if self.luaFindInput then self.luaFindInput:SetFocus(); self.luaFindInput:HighlightText(); return end
    self.luaScrollToken, self.luaAPRPosition = nil, nil
    self.luaFindAnchor = self.luaBox.editBox:GetCursorPosition()
    local parent = self.luaBox.parent
    local bar = UI.Toolbar(parent)
    self.luaFindBar = bar
    table.remove(parent.children)
    table.insert(parent.children, 2, bar)
    local input = AprRC:CreateWidget("EditBox")
    self.luaFindInput = input
    input:SetLabel("")
    input:DisableButton(true)
    input:SetRelativeWidth(0.55)
    input:SetText(self.luaFindQuery or "")
    input:SetCallback("OnTextChanged", function(_, _, value)
        self.luaFindQuery = value
        self:FindLua(0, true)
    end)
    input:SetCallback("OnEnterPressed", function()
        self:FindLua(IsShiftKeyDown() and -1 or 1)
        return true
    end)
    self.luaFindEscape = input.editbox:GetScript("OnEscapePressed")
    input.editbox:SetScript("OnEscapePressed", function() self:CloseLuaFind() end)
    bar:AddChild(input)
    self.luaFindPrevious = UI.IconButton(bar, "previous", "Previous", function() self:FindLua(-1) end)
    self.luaFindNext = UI.IconButton(bar, "next", "Next", function() self:FindLua(1) end)
    UI.Button(bar, CLOSE, function() self:CloseLuaFind() end, 80)
    self.luaFindStatus = UI.LabelWidget(bar, "")
    self:AddLuaSearchControls(bar)
    parent:DoLayout(); self.frame:DoLayout()
    self.luaBox:SetFoldingInput(input.editbox)
    GUI:ClearFocus(); input:SetFocus(); input:HighlightText()
    self:FindLua(0, true)
end

function Editor:CloseLuaFind()
    local bar, input = self.luaFindBar, self.luaFindInput
    if not bar then return end
    self:CloseLuaReplace()
    input.editbox:SetScript("OnEscapePressed", self.luaFindEscape)
    input.editbox:ClearFocus()
    self.luaBox:SetFoldingInput(nil)
    self.luaBox:CancelFoldingChord()
    local parent = bar.parent
    for index, child in ipairs(parent.children) do
        if child == bar then table.remove(parent.children, index); break end
    end
    self.luaFindBar, self.luaFindInput, self.luaFindStatus = nil, nil, nil
    self.luaFindPrevious, self.luaFindNext, self.luaFindResults, self.luaFindIndex = nil, nil, nil, nil
    self.luaCaseCheck, self.luaWordCheck = nil, nil
    self:UpdateLuaCommandInputs()
    GUI:Release(bar)
    parent:DoLayout(); self.frame:DoLayout()
    self.luaBox:SetFocus()
end

function Editor:FindLua(direction, reset, passive)
    if not self.luaFindBar then return end
    local results = self.luaFindResults
    if reset or not results then
        results = {}
        results = AprRC.luaLanguage:Search(self.luaBox:GetText(), self.luaFindQuery or "", self.luaMatchCase, self.luaWholeWord)
        self.luaFindResults, self.luaFindIndex = results, nil
    end
    local count = #results
    self.luaFindPrevious:SetDisabled(count == 0)
    self.luaFindNext:SetDisabled(count == 0)
    if count == 0 then
        self.luaFindStatus:SetText((self.luaFindQuery or "") == "" and "" or T("No matches"))
        if not passive then self.luaBox:HighlightText(0, 0) end
        return
    end
    local index = self.luaFindIndex
    if not index then
        index = 1
        for position, range in ipairs(results) do
            if range.start >= self.luaFindAnchor then index = position; break end
        end
    else index = (index - 1 + direction) % count + 1 end
    self.luaFindIndex = index
    self.luaFindStatus:SetText(index .. " / " .. count)
    if passive then return end
    local range = results[index]
    self.luaBox.editBox:SetCursorPosition(range.finish)
    self.luaBox:HighlightText(range.start, range.finish)
    self.luaBox:CenterRange(range.start, range.finish)
end

function Editor:Undo(delta)
    local session = self.session
    if not session then return end
    if self.tab == "lua" and self.luaBox then
        local index = session.rawCursor + delta
        local snapshot = session.rawHistory[index]
        if not snapshot then return end
        session.rawCursor = index; session:SetRaw(snapshot.text)
        session:Touch()
        self.settingLua = true
        self.luaBox:SetText(snapshot.text)
        self.luaBox.editBox:SetCursorPosition(math.min(snapshot.cursor, #snapshot.text))
        self:QueueLuaAnalysis(self.luaBox)
        self.luaPreviousLength = #snapshot.text
        self.settingLua = false
        if self.luaFindBar then self:FindLua(0, true, true) end
        session:Persist()
        self:UpdateStatus()
    elseif session:Undo(delta) then
        self.formModes, self.formPages = {}, {}
        self:DrawTab()
    end
end
