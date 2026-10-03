local GUI = LibStub("AceGUI-3.0")
local UI, Model, Editor = AprRC.editorUI, AprRC.editorModel, AprRC.routeEditor
local T = UI.Text

local function valueText(value)
    if value == nil then return T("Deleted") end
    local text = AprRC:SerializeData(value)
    -- Keep huge structural conflicts usable; the choices still apply to the
    -- complete value. Its full route versions are retained in Versions.
    if #text > 12000 then
        text = (text:sub(1, 12000):match("^(.*)\n") or "") .. "\n" ..
            T("Preview truncated; the choice applies to all data.")
    end
    return text
end

local function preview(parent, label, value, height)
    local box = AprRC:CreateWidget("MultiLineEditBox")
    box:SetLabel(T(label)); box:DisableButton(true)
    box:SetFullWidth(true); box:SetHeight(height or 200)
    box:SetText(valueText(value)); box:SetDisabled(true)
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
    local plan, reason = session:MergePlan()
    if not plan then self:Message(reason, true); return false end
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
    local choices, index = {}, 1
    self.mergePlan, self.mergeChoices = plan, choices
    local counter = UI.LabelWidget(footer, "")
    local previous, nextButton, apply
    local function draw()
        body:ReleaseChildren()
        local conflict = plan.conflicts[index]
        local resolved = 0
        for i = 1, #plan.conflicts do if choices[i] then resolved = resolved + 1 end end
        counter:SetText(T("Conflict %d of %d; %d resolved"):format(index, #plan.conflicts, resolved))
        UI.LabelWidget(body, conflict.path, true)
        preview(body, "Common ancestor", conflict.base, 100)
        local columns = UI.Group(body)
        columns:SetLayout("APRColumns")
        local left, right = UI.Group(columns), UI.Group(columns)
        preview(left, "Draft (left)", conflict.left)
        preview(right, "Recorded route (right)", conflict.right)
        local function choose(side)
            if self.session ~= session then return end
            choices[index] = side; session:Touch()
            if index < #plan.conflicts then index = index + 1 end
            draw()
        end
        self.mergeLeftButton = UI.Button(left, "Take left", function() choose("left") end, 150)
        self.mergeRightButton = UI.Button(right, "Take right", function() choose("right") end, 150)
        if conflict.insertion then UI.Button(body, "Keep both (left, then right)", function() choose("both") end, 260) end
        if choices[index] then UI.LabelWidget(body, T("Selected side: %s"):format(T(choices[index]))) end
        previous:SetDisabled(index == 1); nextButton:SetDisabled(index == #plan.conflicts)
        apply:SetDisabled(resolved ~= #plan.conflicts)
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
                plan, choices, index = updated, {}, 1
                self.mergePlan, self.mergeChoices = plan, choices
                if #plan.conflicts == 0 then
                    dialog:SetUserData("applied", true)
                    dialog:Hide(); self:Integrate(mode); return
                end
                draw(); self:Message(T("The route changed again. Review the updated conflicts."), true)
            else self:Message(why, true) end
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
        GUI:Release(widget)
    end)
    draw()
    return false
end

function Editor:DrawVersions()
    local panel = UI.Scroll(self.tabs)
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
    end
end

function Editor:ConfirmClose()
    if self.closeDialog then self.closeDialog:Show(); return end
    local session = self.session
    local dialog = AprRC:CreateWidget("Frame")
    self.closeDialog = dialog
    dialog:SetTitle(T("Unsaved draft"))
    dialog:SetWidth(520); dialog:SetHeight(230); dialog:EnableResize(false); dialog:SetLayout("Flow")
    UI.LabelWidget(dialog, T("Save before closing? You can also close and keep the draft for later."))
    UI.LabelWidget(dialog, T("%d unsaved draft(s) will be kept."):format(self:UnsavedCount()))
    self.closeSaveButton = UI.Button(dialog, "Save and close", function()
        dialog:Hide()
        if self.session ~= session then return end
        self.closeAfterSave = session
        if not self:Save() and not self.mergeDialog then self.closeAfterSave = nil end
    end, 190)
    self.closeSaveButton:SetDisabled(not session or not session:IsDirty())
    self.closeKeepButton = UI.Button(dialog, "Close and keep draft", function()
        dialog:Hide()
        if self.session ~= session then return end
        self:KeepDraftsOnClose(); self:Hide(true)
    end, 220)
    self.closeCancelButton = UI.Button(dialog, CANCEL, function() dialog:Hide() end, 110)
    dialog:SetCallback("OnClose", function(widget)
        self.closeDialog, self.closeSaveButton, self.closeKeepButton, self.closeCancelButton = nil, nil, nil, nil
        GUI:Release(widget)
    end)
end
