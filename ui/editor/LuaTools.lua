local GUI = LibStub("AceGUI-3.0")
local UI, Editor, Code, Language = AprRC.editorUI, AprRC.routeEditor, AprRC.luaCode, AprRC.luaLanguage
local T = UI.Text

function Editor:InstallSaveShortcut(widget)
    local frame = widget.frame
    local keyboard = frame.aprSaveKeyboard or CreateFrame("Frame", nil, frame)
    frame.aprSaveKeyboard, self.saveKeyboard = keyboard, keyboard
    keyboard:SetFrameLevel(frame:GetFrameLevel() + 100)
    keyboard:EnableKeyboard(true); keyboard:SetPropagateKeyboardInput(true)
    keyboard:SetScript("OnKeyDown", function(listener, key)
        local handled = false
        local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        local focus, inside = focused, focused == nil
        while focus do
            if focus == frame then inside = true; break end
            focus = focus:GetParent()
        end
        if self.frame == widget and inside and (focused or frame:IsMouseOver()) then self:MarkInteraction() end
        if key:upper() == "S" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) and
            self.frame == widget and self.session and inside then
            handled = true; self:Save()
        end
        listener:SetPropagateKeyboardInput(not handled)
    end)
end

function Editor:DetachLuaTools()
    if self.luaReplaceInput then self.luaReplaceInput.editbox:SetScript("OnEscapePressed", self.luaReplaceEscape) end
    self.luaReplaceEscape = nil
    self.luaAnalysisToken, self.luaAnalysisText, self.luaAnalysisBaseline, self.luaAnalysisBaselineText = nil, nil, nil, nil
    self:CloseLuaCompletion()
    if self.luaOutlineSelect then self.luaOutlineSelect:ClearFocus() end
    self.luaDiagnostics, self.luaOutline, self.luaParsed, self.luaSourceMap = nil, nil, nil, nil
    self.luaDiagnosticLabel, self.luaOutlineSelect, self.luaFormatButton = nil, nil, nil
    self.luaReplaceBar, self.luaReplaceInput, self.luaReplaceButton, self.luaReplaceAllButton = nil, nil, nil, nil
    self.luaCaseCheck, self.luaWordCheck = nil, nil
    self.luaToolbar = nil
end

function Editor:QueueLuaAnalysis(edit)
    local token = {}; self.luaAnalysisToken = token
    C_Timer.After(0.4, function()
        if self.luaAnalysisToken ~= token or self.luaBox ~= edit or edit.pendingCode then return end
        self:AnalyzeLua(edit)
    end)
end

function Editor:LuaInputChanged(edit)
    if self.luaBox ~= edit then return end
    self:CloseLuaCompletion()
    self.luaAnalysisText = nil
    self.luaDiagnostics, self.luaOutline = {}, {}
    edit:SetDiagnostics()
    if self.luaDiagnosticLabel then self.luaDiagnosticLabel:SetText(T("Checking Lua…")) end
    if self.luaOutlineSelect and not self.luaOutlineSelect.disabled then self.luaOutlineSelect:SetDisabled(true) end
    if not edit.pendingCode then self:QueueLuaAnalysis(edit) end
end

function Editor:AnalyzeLua(edit)
    if self.luaBox ~= edit or not self.session then return end
    self.luaAnalysisToken = nil
    local text = edit:GetText()
    if self.luaAnalysisText == text then return end
    if self.luaAnalysisBaselineText ~= self.session.base then
        self.luaAnalysisBaseline = AprRC:ParseLuaData(self.session.base)
        self.luaAnalysisBaselineText = self.session.base
    end
    local comments
    self.luaDiagnostics, self.luaOutline, self.luaParsed, self.luaSourceMap, comments = Language:Analyze(text, self.luaAnalysisBaseline)
    self.luaAnalysisText = text
    local dirty = self.session:IsDirty()
    self.session:ReconcileRaw(self.luaParsed, comments, true)
    if dirty ~= self.session:IsDirty() then self:UpdateStatus() end
    edit:SetDiagnostics(self.luaDiagnostics)
    local first = self.luaDiagnostics[1]
    if first then
        local where = first.location and (T("Line %d"):format(first.location.line) .. ":" .. first.location.column .. " · ") or ""
        self.luaDiagnosticLabel:SetText(T("%d error(s) · %s"):format(#self.luaDiagnostics, where .. first.message))
        self.luaDiagnosticLabel:SetColor(1, 0.35, 0.35)
    else
        self.luaDiagnosticLabel:SetText(T("No Lua errors")); self.luaDiagnosticLabel:SetColor(0.5, 0.85, 0.5)
    end
    local entries, order = {}, {}
    for index, step in ipairs(self.luaOutline) do
        local name = step.group and T("Parallel %d / step %d"):format(step.group, step.index) or T("Step %d"):format(step.index)
        entries[index] = name .. " · " .. T("Line %d"):format(step.line) .. (step.title ~= "" and " · " .. step.title or "")
        order[index] = index
    end
    self.luaOutlineSelect:SetList(entries, order)
    self.luaOutlineSelect:SetDisabled(#self.luaOutline == 0)
    if not self.luaOutlineSelect:GetValue() then self.luaOutlineSelect:SetText(T("Step outline")) end
    if edit.editBox:HasFocus() and not self.luaToolsAction then self:CompleteLua(false) end
end

function Editor:NavigateLuaDiagnostic(direction)
    local edit = self.luaBox
    if not edit then return end
    edit:FlushCode(); self:AnalyzeLua(edit)
    local diagnostics = self.luaDiagnostics or {}
    if #diagnostics == 0 then return end
    local cursor, target = edit:GetCursorPosition(), direction > 0 and 1 or #diagnostics
    if direction > 0 then
        for index, diagnostic in ipairs(diagnostics) do
            if diagnostic.location and diagnostic.location.position - 1 > cursor then target = index; break end
        end
    else
        for index = #diagnostics, 1, -1 do
            if diagnostics[index].location and diagnostics[index].location.position - 1 < cursor then target = index; break end
        end
    end
    self:RevealLuaError(diagnostics[target].location); edit:SetFocus()
end

function Editor:NavigateLuaStep(index)
    local step = self.luaOutline and self.luaOutline[index]
    if not step or self.luaAnalysisText ~= self.luaBox:GetText() then return end
    self:CloseLuaCompletion()
    self.luaBox:SetCursorPosition(step.start); self.luaBox:CenterRange(step.start, step.start)
    self.luaBox:SetFocus()
end

function Editor:FormatLua()
    local edit = self.luaBox
    if not edit then return end
    self:CloseLuaCompletion()
    local text, cursor, location = Language:Format(edit:GetText(), edit:GetCursorPosition())
    if not text then self:RevealLuaError(location); self:Message(cursor, true); return end
    self.luaToolsAction = true
    local changed = edit:EditText(text, cursor)
    self.luaToolsAction = nil; edit:SetFocus()
    self:Message(T(changed and "Lua formatted" or "Lua already formatted"))
end

function Editor:UpdateLuaCommandInputs()
    if not self.luaBox then return end
    local inputs = {}
    for _, widget in pairs({ find = self.luaFindInput, replace = self.luaReplaceInput }) do
        inputs[#inputs + 1] = widget.editbox
    end
    self.luaBox:SetCommandHandler(function(key) return self:HandleLuaCommand(key) end, inputs)
end

function Editor:AttachLuaTools(container, edit)
    local tools = self.luaToolbar
    self.luaFormatButton = UI.IconButton(tools, "format", T("Format Lua") .. " · Shift+Alt+F", function() self:FormatLua() end)
    UI.IconButton(tools, "completion", T("APR completion") .. " · Ctrl+Space", function() edit:SetFocus(); self:CompleteLua(true) end)
    UI.IconButton(tools, "replace", T("Replace") .. " · Ctrl+H", function() self:OpenLuaReplace() end)
    local outline = UI.SearchSelect(tools, T("Step outline"), {}, nil, function(index) self:NavigateLuaStep(index) end)
    outline:SetFullWidth(false); outline:SetUserData("flex", 1); outline:SetCommitOnly(true); outline:SetMaxResults(80)
    outline.label:Hide(); outline:SetHeight(26)
    outline:SetText(T("Step outline"))
    outline.editbox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(outline.frame, "ANCHOR_TOP")
        AprRC:AddTooltipLine(GameTooltip, T("Step outline") .. " · Ctrl+Shift+O", 1, 1, 1, true); GameTooltip:Show()
    end)
    outline.editbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.luaOutlineSelect = outline
    local footer = UI.Toolbar(container, true)
    local diagnostic = AprRC:CreateWidget("InteractiveLabel")
    diagnostic:SetFullWidth(true); diagnostic:SetText(T("Checking Lua…"))
    diagnostic:SetCallback("OnClick", function()
        edit:FlushCode(); self:AnalyzeLua(edit)
        local first = self.luaDiagnostics and self.luaDiagnostics[1]
        if first then self:RevealLuaError(first.location); edit:SetFocus() end
    end)
    diagnostic:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        for index, issue in ipairs(self.luaDiagnostics or {}) do
            if index > 10 then break end
            AprRC:AddTooltipLine(GameTooltip, T("Line %d"):format(issue.location and issue.location.line or 1) .. " · " .. issue.message, 1, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    diagnostic:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    footer:AddChild(diagnostic); self.luaDiagnosticLabel = diagnostic
    edit:SetCallback("OnEditFocusLost", function()
        if not self.luaCompletionFrame or not self.luaCompletionFrame:IsShown() or not self.luaCompletionFrame:IsMouseOver() then
            self:CloseLuaCompletion()
        end
    end)
    edit:SetCallback("OnDiagnosticClicked", function(_, _, issue) self:RevealLuaError(issue.location); edit:SetFocus() end)
    self:UpdateLuaCommandInputs()
    self:QueueLuaAnalysis(edit)
end

function Editor:HandleLuaCommand(key)
    if not self.luaBox then return false end
    local control = IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())
    if control then
        if key == "S" then self:Save(); return true end
        if key == "H" then self:OpenLuaReplace(); return true end
        if key == "F" then self:OpenLuaFind(); return true end
        if key == "Z" then self:Undo(IsShiftKeyDown() and 1 or -1); return true end
        if key == "Y" then self:Undo(1); return true end
        if key == "SPACE" then self:CompleteLua(true); return true end
        if key == "O" and IsShiftKeyDown() then self.luaOutlineSelect:SetFocus(); return true end
    end
    if key == "F" and IsShiftKeyDown() and IsAltKeyDown() then self:FormatLua(); return true end
    if key == "F8" then self:NavigateLuaDiagnostic(IsShiftKeyDown() and -1 or 1); return true end
    if self.luaCompletion and self.luaBox.editBox:HasFocus() then
        if (key == "UP" or key == "DOWN") and IsAltKeyDown() then
            local completion = self.luaCompletion
            completion.index = (completion.index - 1 + (key == "UP" and -1 or 1)) % #completion.items + 1
            self:DrawLuaCompletion(); return true
        end
        if key == "TAB" then self:AcceptLuaCompletion(); return true end
        if key == "ESCAPE" then self:CloseLuaCompletion(); return true end
    end
    return false
end

function Editor:AddLuaSearchControls(bar)
    self.luaFindInput:SetRelativeWidth(0.45)
    local function check(label, short, value, callback, width)
        local widget = AprRC:CreateWidget("CheckBox")
        widget:SetLabel(short); widget:SetValue(value or false); widget:SetWidth(width)
        widget:SetCallback("OnValueChanged", function(_, _, enabled) callback(enabled); self:FindLua(0, true) end)
        widget:SetCallback("OnEnter", function(control)
            GameTooltip:SetOwner(control.frame, "ANCHOR_TOP")
            AprRC:AddTooltipLine(GameTooltip, T(label), 1, 1, 1, true); GameTooltip:Show()
        end)
        widget:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        bar:AddChild(widget); return widget
    end
    self.luaCaseCheck = check("Match case", "Aa", self.luaMatchCase, function(value) self.luaMatchCase = value end, 50)
    self.luaWordCheck = check("Whole words", "[ab]", self.luaWholeWord, function(value) self.luaWholeWord = value end, 60)
    self:UpdateLuaCommandInputs()
end

function Editor:OpenLuaReplace()
    if not self.luaBox then return end
    self:CloseLuaCompletion(); self:OpenLuaFind()
    if not self.luaReplaceBar then
        local parent = self.luaBox.parent
        local bar = UI.Toolbar(parent)
        table.remove(parent.children)
        for index, child in ipairs(parent.children) do
            if child == self.luaFindBar then table.insert(parent.children, index + 1, bar); break end
        end
        self.luaReplaceBar = bar
        local input = AprRC:CreateWidget("EditBox")
        input:SetLabel(T("Replace with")); input:DisableButton(true); input:SetRelativeWidth(0.45)
        input:SetText(self.luaReplacement or "")
        input:SetCallback("OnTextChanged", function(_, _, value) self.luaReplacement = value end)
        input:SetCallback("OnEnterPressed", function() self:ReplaceLua(false); return true end)
        self.luaReplaceEscape = input.editbox:GetScript("OnEscapePressed")
        input.editbox:SetScript("OnEscapePressed", function() self:CloseLuaFind() end)
        bar:AddChild(input); self.luaReplaceInput = input
        self.luaReplaceButton = UI.Button(bar, "Replace", function() self:ReplaceLua(false) end, 110)
        self.luaReplaceAllButton = UI.Button(bar, "Replace all", function() self:ReplaceLua(true) end, 160)
        self:UpdateLuaCommandInputs()
        parent:DoLayout(); self.frame:DoLayout()
    end
    self.luaReplaceInput:SetFocus(); self.luaReplaceInput:HighlightText()
end

function Editor:CloseLuaReplace()
    local bar = self.luaReplaceBar
    if not bar then return end
    self.luaReplaceInput.editbox:SetScript("OnEscapePressed", self.luaReplaceEscape); self.luaReplaceEscape = nil
    local parent = bar.parent
    for index, child in ipairs(parent.children) do if child == bar then table.remove(parent.children, index); break end end
    self.luaReplaceBar, self.luaReplaceInput, self.luaReplaceButton, self.luaReplaceAllButton = nil, nil, nil, nil
    GUI:Release(bar)
end

function Editor:ReplaceLua(all)
    local edit = self.luaBox
    if not edit or not self.luaFindBar then return end
    local selected = self.luaFindResults and self.luaFindResults[self.luaFindIndex or 1]
    self.luaFindAnchor = selected and selected.start or edit:GetCursorPosition()
    self:FindLua(0, true, true)
    local results = self.luaFindResults
    if #results == 0 then return end
    local ranges = all and results or { results[self.luaFindIndex or 1] }
    local cursor = all and edit:GetCursorPosition() or ranges[1].finish
    local text, mapped = Language:Replace(edit:GetText(), ranges, self.luaReplacement or "", cursor)
    self:CloseLuaCompletion()
    self.luaToolsAction = true; edit:EditText(text, mapped); self.luaToolsAction = nil
    self.luaFindAnchor = mapped
    self:FindLua(0, true, true)
    if self.luaReplaceInput then self.luaReplaceInput:SetFocus() end
end

function Editor:CloseLuaCompletion()
    if self.luaCompletionFrame then self.luaCompletionFrame:Hide() end
    if self.luaCompletionGhost then self.luaCompletionGhost:Hide() end
    self.luaCompletion = nil
end

function Editor:CompleteLua(explicit)
    local edit = self.luaBox
    if not edit or not edit.editBox:HasFocus() then return end
    if explicit then edit:FlushCode() end
    local text, cursor = edit:GetText(), edit:GetCursorPosition()
    local context = Language:Context(text, cursor, edit.tokens)
    if not context or (not explicit and context.prefix == "") then self:CloseLuaCompletion(); return end
    local items = Language:Candidates(context, self.luaParsed or self.session.draft)
    if #items == 0 then self:CloseLuaCompletion(); return end
    self.luaCompletion = { context = context, items = items, index = 1, source = text, edit = edit, explicit = explicit }
    self:DrawLuaCompletion()
end

function Editor:DrawLuaCompletion()
    local completion = self.luaCompletion
    if not completion then return end
    local edit = completion.edit
    local item = completion.items[completion.index]
    local insert = item.insert
    if item.kind == "field" and not completion.source:sub(completion.context.last + 1):match("^%s*=") then insert = insert .. " = " end
    local suffix = insert:sub(1, #completion.context.prefix) == completion.context.prefix and
        insert:sub(#completion.context.prefix + 1) or (" → " .. insert)
    local x, y = edit:CursorAnchor()
    local ghost = self.luaCompletionGhost
    if not ghost then
        ghost = CreateFrame("Frame", nil, edit.scrollFrame)
        ghost:SetClipsChildren(true)
        ghost.text = ghost:CreateFontString(nil, "OVERLAY")
        ghost.text:SetPoint("TOPLEFT"); ghost.text:SetJustifyH("LEFT"); ghost.text:SetWordWrap(false)
        self.luaCompletionGhost = ghost
    end
    ghost:SetParent(edit.scrollFrame); ghost:SetFrameLevel(edit.editBox:GetFrameLevel() + 5)
    local font, size, flags = edit.editBox:GetFont()
    ghost.text:SetFont(font, size, flags); ghost.text:SetTextColor(0.55, 0.6, 0.65)
    ghost.text:SetText(suffix:gsub("|", "||"))
    ghost:ClearAllPoints(); ghost:SetPoint("TOPLEFT", edit.scrollFrame, "TOPLEFT", x, y)
    ghost:SetSize(math.max(1, math.min(ghost.text:GetStringWidth(), edit.scrollFrame:GetWidth() - x)), edit.lineHeight)
    -- Never add the ghost to the EditBox buffer: copy, save, undo and validation
    -- continue to see only what the user actually typed.
    if suffix ~= "" and x >= 0 and y <= 0 and -y < edit.scrollFrame:GetHeight() then ghost:Show() else ghost:Hide() end
    if not completion.explicit then
        if self.luaCompletionFrame then self.luaCompletionFrame:Hide() end
        return
    end
    local popup = self.luaCompletionFrame
    if not popup then
        popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        popup:SetBackdropColor(0.08, 0.08, 0.08, 1); popup:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        popup:SetClampedToScreen(true); popup.rows = {}
        popup.header = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        popup.header:SetPoint("TOPLEFT", 8, -7); popup.header:SetText(T("APR completion · Tab to accept · Alt+↑/↓"))
        self.luaCompletionFrame = popup
    end
    popup:SetParent(edit.frame); popup:SetFrameStrata(edit.frame:GetFrameStrata()); popup:SetFrameLevel(edit.editBox:GetFrameLevel() + 10)
    popup:SetSize(math.min(430, edit.frame:GetWidth()), 29 + #completion.items * 23)
    popup:ClearAllPoints()
    local left = math.max(0, math.min(edit.scrollFrame:GetWidth() - popup:GetWidth(), x))
    local below = -y + edit.lineHeight
    if below + popup:GetHeight() > edit.scrollFrame:GetHeight() then below = math.max(0, -y - popup:GetHeight()) end
    popup:SetPoint("TOPLEFT", edit.scrollFrame, "TOPLEFT", left, -below)
    for index, item in ipairs(completion.items) do
        local row = popup.rows[index]
        if not row then
            row = CreateFrame("Button", nil, popup)
            row:SetHeight(23); row:SetPoint("TOPLEFT", 5, -26 - (index - 1) * 23); row:SetPoint("RIGHT", -5, 0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 4, 0); row.text:SetPoint("RIGHT", -4, 0); row.text:SetJustifyH("LEFT")
            row:SetScript("OnClick", function() if self.luaCompletion then self.luaCompletion.index = index; self:AcceptLuaCompletion() end end)
            popup.rows[index] = row
        end
        row.text:SetText((index == completion.index and "|cff82d9a0> " or "|cffdddddd  ") .. item.label:gsub("|", "||") .. "|r")
        row:Show()
    end
    for index = #completion.items + 1, #popup.rows do popup.rows[index]:Hide() end
    popup:Show()
end

function Editor:AcceptLuaCompletion()
    local completion = self.luaCompletion
    if not completion then return end
    self:CloseLuaCompletion()
    local edit, context, item = completion.edit, completion.context, completion.items[completion.index]
    if self.luaBox ~= edit or edit:GetText() ~= completion.source then return end
    local insert = item.insert
    if item.kind == "field" and not edit:GetText():sub(context.last + 1):match("^%s*=") then insert = insert .. " = " end
    local text = edit:GetText():sub(1, context.first) .. insert .. edit:GetText():sub(context.last + 1)
    self.luaToolsAction = true; edit:EditText(text, context.first + #insert); self.luaToolsAction = nil; edit:SetFocus()
    if item.kind == "spell" or item.kind == "item" then AprRC.recentChoices:Remember(item.kind, tonumber(item.insert)) end
end
