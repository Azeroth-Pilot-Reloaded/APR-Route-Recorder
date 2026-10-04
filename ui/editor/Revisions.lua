local GUI = LibStub("AceGUI-3.0")
local UI, Model, Editor = AprRC.editorUI, AprRC.editorModel, AprRC.routeEditor
local T = UI.Text

local function valueText(value)
    return value == nil and "nil" or AprRC:SerializeData(value)
end

local function preview(parent, label, value, height, editable)
    local box = AprRC:CreateWidget("APRLuaEditor")
    box:SetLabel(T(label)); box:DisableButton(true)
    box:SetFullWidth(true); box:SetHeight(height or 200)
    box:SetText(valueText(value)); box:SetDisabled(not editable)
    parent:AddChild(box)
    return box
end

function Editor:AfterSave()
    self.session.rawHistory = nil
    self.safetyNotice = nil
    if self.frame then self:DrawTab(); self:Message(T("Saved")) end
    if self.closeAfterSave == self.session then
        self.closeAfterSave = nil; self:Hide(true)
    end
end

function Editor:Integrate(mode)
    if not self.session then return false end
    if self.mergeDialog then self.mergeDialog:Show(); return false end
    local session = self.session
    local plan, reason, location = session:MergePlan()
    if not plan then self:RevealLuaError(location); self:Message(reason, true); return false end
    if #plan.conflicts == 0 then
        local ok, why = session:ApplyMerge(plan, {}, mode == "save")
        if not ok then self:Message(why, true); return false end
        if mode == "save" then self:AfterSave()
        else self.safetyNotice = nil; self:DrawTab(); self:Message(T("Rebased draft; review it, then Save.")) end
        return true
    end
    -- Both versions remain recoverable even if the dialog is cancelled or the
    -- player reloads the UI before finishing its choices.
    Model:Archive(session.name, Model:Source(session.name), "Recording before merge")
    Model:Archive(session.name, session.draft, "Draft before merge", session.raw, session.base)
    local dialog = AprRC:CreateWidget("Frame")
    self.mergeDialog = dialog
    dialog:SetTitle(T(mode == "save" and "Merge and save" or "Rebase draft"))
    dialog:SetWidth(math.min(940, UIParent:GetWidth()))
    dialog:SetHeight(math.min(700, UIParent:GetHeight()))
    dialog:SetLayout("APRWorkspace")
    local header = UI.Toolbar(dialog)
    UI.LabelWidget(header, session.name, true)
    UI.LabelWidget(header, T("Compatible changes are kept automatically. Choose each conflicting value."))
    local body = UI.Scroll(dialog)
    local footer = UI.Toolbar(dialog, true)
    local choices, edits, errors, index = {}, {}, {}, 1
    self.mergePlan, self.mergeChoices = plan, choices
    local counter = UI.LabelWidget(footer, "")
    local previous, nextButton, apply, validation
    local function updateStatus()
        local resolved = 0
        for i = 1, #plan.conflicts do if choices[i] then resolved = resolved + 1 end end
        counter:SetText(T("Conflict %d of %d; %d resolved"):format(index, #plan.conflicts, resolved))
        previous:SetDisabled(index == 1); nextButton:SetDisabled(index == #plan.conflicts)
        apply:SetDisabled(resolved ~= #plan.conflicts)
        if validation then
            local side = type(choices[index]) == "table" and "Manual correction" or choices[index]
            validation:SetText(errors[index] or (side and T("Selected side: %s"):format(T(side)) or
                T("Choose a side or edit the result above. Use nil to delete a value.")))
            validation:SetColor(errors[index] and 1 or 0.8, errors[index] and 0.3 or 0.8, errors[index] and 0.3 or 0.8)
        end
    end
    local function draw()
        body:ReleaseChildren()
        local conflict = plan.conflicts[index]
        UI.LabelWidget(body, conflict.path, true)
        local selected = conflict.left
        if choices[index] == "right" then selected = conflict.right
        elseif choices[index] == "both" then
            selected = AprRC:CopyData(conflict.left)
            for _, value in ipairs(conflict.right) do selected[#selected + 1] = AprRC:CopyData(value) end
        elseif type(choices[index]) == "table" then selected = choices[index].value end
        local result = preview(body, "Merge result (editable)", selected, 190, true)
        self.mergeResultBox = result
        if edits[index] then result:SetText(edits[index]) end
        result:SetDiff(valueText(conflict.base), "right")
        validation = UI.LabelWidget(body, "")
        local function validateResult(text)
            if self.session ~= session then return end
            edits[index], errors[index] = text, nil
            local value, reason
            if text:match("^%s*nil%s*$") then value = { custom = true }
            else
                local parsed
                parsed, reason = AprRC:ParseLuaData("{ value = " .. text .. "\n}")
                if parsed then value = { custom = true, value = parsed.value } end
            end
            if value and conflict.list then
                local valid = type(value.value) == "table"
                if valid then
                    for key, entry in pairs(value.value) do
                        if type(key) ~= "number" or key < 1 or key > #value.value or key % 1 ~= 0 or type(entry) ~= "table" then
                            valid = false; break
                        end
                    end
                end
                if not valid then value, reason = nil, T("Expected a list of Lua tables.") end
            end
            choices[index], errors[index] = value, value and nil or reason
            session:Touch(); result:SetDiff(valueText(conflict.base), "right"); updateStatus()
        end
        result:SetCallback("OnTextChanged", function(_, _, text)
            if self.session ~= session then return end
            edits[index] = text
            if result.pendingCode then
                choices[index], errors[index] = nil, ""
                session:Touch(); updateStatus()
            else
                validateResult(text)
            end
        end)
        result:SetCallback("OnCodeSettled", function(_, _, text) validateResult(text) end)
        local columns = UI.Group(body)
        columns:SetLayout("APRColumns")
        local left, right = UI.Group(columns), UI.Group(columns)
        self.mergeLeftBox = preview(left, "Draft (left)", conflict.left, 190)
        self.mergeRightBox = preview(right, "Recorded route (right)", conflict.right, 190)
        self.mergeLeftBox:SetDiff(valueText(conflict.right), "left")
        self.mergeRightBox:SetDiff(valueText(conflict.left), "right")
        local function choose(side)
            if self.session ~= session then return end
            choices[index], edits[index], errors[index] = side, nil, nil
            session:Touch()
            draw()
        end
        self.mergeLeftButton = UI.Button(left, "Take left", function() choose("left") end, 150)
        self.mergeRightButton = UI.Button(right, "Take right", function() choose("right") end, 150)
        if conflict.insertion then UI.Button(body, "Keep both (left, then right)", function() choose("both") end, 260) end
        preview(body, "Common ancestor", conflict.base, 90)
        updateStatus()
        body:DoLayout(); body:SetScroll(0); dialog:DoLayout()
    end
    previous = UI.Button(footer, "Previous", function() index = math.max(1, index - 1); session:Touch(); draw() end, 110)
    nextButton = UI.Button(footer, "Next", function() index = math.min(#plan.conflicts, index + 1); session:Touch(); draw() end, 110)
    apply = UI.Button(footer, mode == "save" and "Merge and save" or "Apply rebase", function()
        if self.session ~= session then dialog:Hide(); return end
        local ok, why = session:ApplyMerge(plan, choices, mode == "save")
        if not ok then
            if why == "changed" then
                local updated, errorMessage = session:MergePlan()
                if not updated then self:Message(errorMessage, true); return end
                -- No choice made against an older source is replayed blindly.
                plan, choices, edits, errors, index = updated, {}, {}, {}, 1
                self.mergePlan, self.mergeChoices = plan, choices
                if #plan.conflicts == 0 then
                    dialog:SetUserData("applied", true)
                    dialog:Hide(); self:Integrate(mode); return
                end
                draw(); self:Message(T("The route changed again. Review the updated conflicts."), true)
            else
                errors[index] = why
                updateStatus(); self:Message(why, true)
            end
            return
        end
        dialog:SetUserData("applied", true)
        dialog:Hide()
        if mode == "save" then self:AfterSave()
        else self.safetyNotice = nil; self:DrawTab(); self:Message(T("Rebased draft; review it, then Save.")) end
    end, 180)
    self.mergeApplyButton = apply
    UI.Button(footer, CANCEL, function() self.closeAfterSave = nil; dialog:Hide() end, 110)
    dialog:SetCallback("OnClose", function(widget)
        if not widget:GetUserData("applied") then self.closeAfterSave = nil end
        self.mergeDialog, self.mergePlan, self.mergeChoices = nil, nil, nil
        self.mergeLeftButton, self.mergeRightButton, self.mergeApplyButton = nil, nil, nil
        self.mergeResultBox, self.mergeLeftBox, self.mergeRightBox = nil, nil, nil
        GUI:Release(widget)
    end)
    draw()
    return false
end

function Editor:DrawVersions()
    local panel = UI.Scroll(self.tabs)
    UI.Button(panel, "Compare versions", function() self:OpenVersionDiff() end, 190)
    UI.LabelWidget(panel, T("Merge keeps compatible changes. Rebase updates your draft without saving it."))
    UI.Button(panel, "Merge and save", function() self:Integrate("save") end, 190)
    UI.Button(panel, "Rebase draft", function() self:Integrate("rebase") end, 190)
    UI.LabelWidget(panel, T("Recovery versions"), true)
    UI.LabelWidget(panel, T("The latest 40 versions are kept per route. Recovery opens a separate copy, including incomplete Lua."))
    local history = Model:History(self.session.name)
    if #history == 0 then UI.LabelWidget(panel, T("No recovery versions yet.")) end
    for index = #history, 1, -1 do
        local version = history[index]
        local row = UI.Group(panel)
        row:SetUserData("version", version)
        local timestamp = date and date("%Y-%m-%d %H:%M:%S", version.time) or tostring(version.time)
        UI.LabelWidget(row, timestamp .. " · " .. T(version.reason) .. " · " ..
            tostring(#(version.route.steps or {})) .. " " .. T("Steps") .. (version.raw and " · " .. T("Lua draft") or ""))
        UI.Button(row, "Recover a copy", function()
            local route, session = Model:RecoveryCopy(self.session.name, version)
            if not route then self:Message(session, true); return end
            self:SetSession(route.name, session)
            self:RefreshRoutes(); self:SelectRoute(route.name)
            self:Message(T("Recovered into a separate draft."))
        end, 190)
        UI.Button(row, "Compare with draft", function() self:OpenVersionDiff("version:" .. version.id, "draft") end, 190)
    end
end

function Editor:ConfirmClose()
    if self.closeDialog then self.closeDialog:Show(); return end
    local session = self.session
    local dialog = AprRC:CreateWidget("APRConfirmation")
    dialog:SetLayout("APRWorkspace")
    self.closeDialog = dialog
    dialog:SetTitle(T("Unsaved draft"))
    dialog:SetWidth(math.min(480, UIParent:GetWidth())); dialog:SetHeight(145)
    UI.LabelWidget(UI.Group(dialog), T("Save before closing?") .. "\n" .. session.name)
    local actions = UI.Toolbar(dialog, true); actions:SetLayout("APRCompactToolbar")
    self.closeSaveButton = UI.Button(actions, "Save", function()
        dialog:Hide()
        if self.session ~= session then return end
        self.closeAfterSave = session
        if not self:Save() and not self.mergeDialog then self.closeAfterSave = nil end
    end, 130)
    self.closeSaveButton:SetDisabled(not session or not session:IsDirty())
    self.closeKeepButton = UI.Button(actions, "Keep draft", function()
        dialog:Hide()
        if self.session ~= session then return end
        self:KeepDraftsOnClose(); self:Hide(true)
    end, 180)
    self.closeCancelButton = UI.Button(actions, CANCEL, function() dialog:Hide() end, 110)
    dialog:SetCallback("OnClose", function(widget)
        self.closeDialog, self.closeSaveButton, self.closeKeepButton, self.closeCancelButton = nil, nil, nil, nil
        GUI:Release(widget)
    end)
end
