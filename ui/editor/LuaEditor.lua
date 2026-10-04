local GUI = LibStub("AceGUI-3.0")
local UI, Code = AprRC.editorUI, AprRC.luaCode
local INPUT_IDLE = 0.4
local modifierKeys = { LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true }
local azertyDigits = { ["&"] = "1", ["é"] = "2", ['"'] = "3", ["'"] = "4", ["("] = "5",
    ["-"] = "6", ["è"] = "7", ["_"] = "8", ["ç"] = "9", ["à"] = "0" }

GUI:RegisterWidgetType("APRLuaEditor", function()
    -- Reuse AceGUI's native editing, focus and vertical scrollbar behavior.
    -- This is its own widget type/pool; ordinary text fields are untouched.
    local widget = GUI.WidgetRegistry.MultiLineEditBox()
    widget.type = "APRLuaEditor"
    local box, scroll = widget.editBox, widget.scrollFrame
    -- Capture commands above the native EditBox, before its text handling and
    -- WoW bindings. This listener is scoped to the code/search field's focus.
    local keyboard = CreateFrame("Frame", nil, widget.frame)
    keyboard:SetPropagateKeyboardInput(true)
    widget.keyboardFrame = keyboard
    local native = { get = box.GetText, set = box.SetText, cursor = box.GetCursorPosition,
        move = box.SetCursorPosition, highlight = box.HighlightText, insert = box.Insert }
    local acquire, release, disable = widget.OnAcquire, widget.OnRelease, widget.SetDisabled
    local gutter = CreateFrame("Frame", nil, widget.scrollBG)
    gutter:SetPoint("TOPLEFT", widget.scrollBG, "TOPLEFT", 5, -6)
    gutter:SetPoint("BOTTOMLEFT", widget.scrollBG, "BOTTOMLEFT", 5, 16)
    gutter:SetWidth(54)
    gutter:SetClipsChildren(true)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", widget.scrollBG, "TOPLEFT", 60, -6)
    scroll:SetPoint("BOTTOMRIGHT", widget.scrollBG, "BOTTOMRIGHT", -4, 16)
    box:ClearAllPoints(); box:SetPoint("TOPLEFT", scroll, "TOPLEFT")
    box:SetJustifyV("TOP"); box:SetTextInsets(0, 0, 0, 0)
    -- WoW's caret, hit testing and selection do not follow custom line spacing.
    -- Keep the native text layout unchanged and measure its actual font metrics.
    box:SetSpacing(0)
    local measure = box:CreateFontString(nil, "OVERLAY")
    measure:Hide(); measure:SetWordWrap(false)
    local horizontal = CreateFrame("Slider", nil, widget.scrollBG)
    horizontal:SetPoint("BOTTOMLEFT", widget.scrollBG, "BOTTOMLEFT", 60, 5)
    horizontal:SetPoint("BOTTOMRIGHT", widget.scrollBG, "BOTTOMRIGHT", -4, 5)
    horizontal:SetHeight(8); horizontal:SetOrientation("HORIZONTAL")
    horizontal:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    horizontal:SetValueStep(1)
    horizontal:SetScript("OnValueChanged", function(_, value)
        scroll:SetHorizontalScroll(value)
        if widget.lines then widget:DrawGutter() end
    end)
    widget.gutter, widget.horizontalBar, widget.rows = gutter, horizontal, {}

    function widget:DrawGutter()
        if not self.lines or self.pendingCode then return end
        local offset, lineHeight = scroll:GetVerticalScroll(), self.lineHeight or 14
        local first = math.max(1, math.floor(offset / lineHeight) + 1)
        local last = math.min(#self.lines, math.ceil((offset + scroll:GetHeight()) / lineHeight))
        local rawLines, folds = self.rawLines, self.visibleFolds or {}
        local used = 0
        for index = first, last do
            used = used + 1
            local row = self.rows[used]
            if not row then
                row = { frame = CreateFrame("Button", nil, gutter) }
                row.frame:SetSize(54, lineHeight)
                row.number = row.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                row.number:SetPoint("RIGHT", row.frame, "RIGHT", -19, 0)
                row.number:SetJustifyH("RIGHT")
                row.symbol = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.symbol:SetPoint("RIGHT", row.frame, "RIGHT", -3, 0)
                row.background = box:CreateTexture(nil, "BACKGROUND")
                row.inline = box:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.hatches = {}
                row.error = box:CreateTexture(nil, "OVERLAY")
                row.error:SetColorTexture(1, 0.2, 0.2, 0.85)
                row.frame:SetScript("OnClick", function()
                    if row.diagnostic then self:Fire("OnDiagnosticClicked", row.diagnostic)
                    elseif row.fold then self:ToggleFold(row.fold.start, IsShiftKeyDown()) end
                end)
                row.frame:SetScript("OnEnter", function()
                    if not row.fold and not row.diagnostic then return end
                    GameTooltip:SetOwner(row.frame, "ANCHOR_TOP")
                    AprRC:AddTooltipLine(GameTooltip, row.diagnostic and row.diagnostic.message or
                        UI.Text("Click + / - to fold or unfold a Lua table."), 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                row.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.rows[used] = row
            end
            local rawPosition = Code:ToRaw(self.ranges, self.lines[index].start)
            local low, high = 1, #rawLines
            while low < high do
                local middle = math.ceil((low + high) / 2)
                if rawLines[middle].start <= rawPosition then low = middle else high = middle - 1 end
            end
            row.fold = folds[low]
            row.diagnostic = self.diagnosticLines and self.diagnosticLines[low]
            local number = self.comparisonNumbers and self.comparisonNumbers[index] or low
            local missing = self.comparisonMissing and self.comparisonMissing[index]
            row.number:SetText(missing and "" or tostring(number))
            row.number:SetTextColor(row.diagnostic and 1 or 0.55, row.diagnostic and 0.25 or 0.55, row.diagnostic and 0.25 or 0.55)
            row.symbol:SetText(row.diagnostic and "|cffff4444!|r" or row.fold and (self.collapsed[row.fold.start] and "+" or "-") or
                (self.comparisonNumbers and self.changedLines[index] and (self.diffSide == "left" and "-" or "+") or ""))
            row.frame:ClearAllPoints(); row.frame:SetPoint("TOPLEFT", gutter, "TOPLEFT", 0, offset - (index - 1) * lineHeight)
            row.frame:SetHeight(lineHeight); row.frame:Show()
            if row.diagnostic then
                row.error:ClearAllPoints(); row.error:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -index * lineHeight + 2)
                row.error:SetSize(self.textWidth or 200, 1); row.error:Show()
            else row.error:Hide() end
            local changed = self.changedLines and self.changedLines[self.comparisonNumbers and index or low]
            if changed or missing then
                local left = self.diffSide == "left"
                if missing then row.background:SetColorTexture(0.22, 0.22, 0.22, 0.55)
                else row.background:SetColorTexture(left and 0.55 or 0.25, left and 0.12 or 0.45, 0.12, 0.38) end
                row.background:ClearAllPoints()
                row.background:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(index - 1) * lineHeight)
                row.background:SetSize(self.textWidth or 200, lineHeight); row.background:Show()
            else row.background:Hide() end
            local span = self.comparisonSpans and self.comparisonSpans[index]
            if span and span.finish > span.start then
                local value = self.lines[index].text
                measure:SetText(value:sub(1, span.start):gsub("|", "||"))
                local x = measure:GetStringWidth()
                measure:SetText(value:sub(span.start + 1, span.finish):gsub("|", "||"))
                row.inline:ClearAllPoints(); row.inline:SetPoint("TOPLEFT", box, "TOPLEFT", x, -(index - 1) * lineHeight)
                row.inline:SetSize(math.max(2, measure:GetStringWidth()), lineHeight)
                row.inline:SetColorTexture(self.diffSide == "left" and 0.8 or 0.35, self.diffSide == "left" and 0.15 or 0.7, 0.1, 0.45)
                row.inline:Show()
            else row.inline:Hide() end
            local stripes = 0
            if missing then
                local left = scroll:GetHorizontalScroll()
                for x = left - lineHeight, left + scroll:GetWidth(), 12 do
                    stripes = stripes + 1
                    local hatch = row.hatches[stripes]
                    if not hatch then
                        hatch = box:CreateLine(nil, "BACKGROUND")
                        hatch:SetTexture("Interface\\Buttons\\WHITE8X8"); hatch:SetVertexColor(0.5, 0.5, 0.5, 0.45)
                        hatch:SetThickness(1); row.hatches[stripes] = hatch
                    end
                    local y = -(index - 1) * lineHeight
                    hatch:SetStartPoint("TOPLEFT", box, math.max(left, x), y - math.max(0, left - x))
                    hatch:SetEndPoint("TOPLEFT", box, math.min(left + scroll:GetWidth(), x + lineHeight), y - lineHeight)
                    hatch:Show()
                end
            end
            for i = stripes + 1, #row.hatches do row.hatches[i]:Hide() end
        end
        for index = used + 1, #self.rows do
            local row = self.rows[index]
            row.frame:Hide(); row.background:Hide(); row.inline:Hide(); row.error:Hide()
            for _, hatch in ipairs(row.hatches) do hatch:Hide() end
        end
    end

    function widget:SizeCode()
        local font, size, flags = box:GetFont()
        measure:SetFont(font, size, flags)
        box:SetSpacing(0); measure:SetSpacing(0)
        measure:SetText("M"); local single = measure:GetStringHeight()
        measure:SetText("M\nM"); local pitch = measure:GetStringHeight() - single
        self.lineHeight = pitch > 0 and pitch or single > 0 and single or size
        local width = math.max(1, scroll:GetWidth())
        for _, line in ipairs(self.lines or {}) do
            measure:SetText(line.text:gsub("|", "||"))
            width = math.max(width, measure:GetStringWidth() + 16)
        end
        self.textWidth = width
        box:SetWidth(width); box:SetHeight(math.max(scroll:GetHeight(), #(self.lines or {}) * self.lineHeight + 4))
        local maximum = math.max(0, width - scroll:GetWidth())
        horizontal:SetMinMaxValues(0, maximum)
        horizontal:SetValue(math.min(horizontal:GetValue(), maximum))
        self:DrawGutter()
    end

    function widget:Render(cursor, selection, preserveScroll, plain)
        local vertical, horizontalOffset = scroll:GetVerticalScroll(), horizontal:GetValue()
        self.pendingCode = nil
        self.centerToken = nil
        self.settingCode = true
        self.display, self.ranges = Code:Project(self.raw, self.folds, self.collapsed)
        self.lines, self.rawLines = Code:Lines(self.display), Code:Lines(self.raw)
        if plain then
            self.rendered = self.display:gsub("|", "||")
            self.spans = { { start = 0, finish = #self.display, offset = 0, nativeFinish = #self.rendered } }
        else
            self.rendered, self.spans = Code:Encode(self.display, self.display == self.raw and self.tokens or nil)
        end
        self.visibleFolds = {}
        for _, fold in ipairs(self.folds) do
            local position = Code:ToDisplay(self.ranges, fold.start)
            if Code:ToRaw(self.ranges, position) == fold.start then
                self.visibleFolds[fold.line] = self.visibleFolds[fold.line] or fold
            end
        end
        self.inputBuffer, self.nativeChanges = self.rendered, {}
        native.set(box, self.rendered)
        self:SizeCode()
        native.move(box, Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, cursor or 0)))
        if selection and selection.last > selection.first then
            native.highlight(box, Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, selection.first)),
                Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, selection.last)))
        end
        self.settingCode = nil
        if preserveScroll then
            scroll:SetVerticalScroll(math.max(0, math.min(vertical, scroll:GetVerticalScrollRange())))
            horizontal:SetValue(horizontalOffset)
        end
        self:DrawGutter()
    end

    function widget:QueueCode()
        -- Never rewrite the native buffer from OnTextChanged. WoW has not
        -- necessarily finished moving its caret/selection for this input yet.
        local token = {}; self.pendingCode = token
        self.centerToken = nil
        C_Timer.After(INPUT_IDLE, function()
            if self.pendingCode ~= token then return end
            if IsMouseButtonDown("LeftButton") or IsShiftKeyDown() or
                (box.IsInIMECompositionMode and box:IsInIMECompositionMode()) then
                self:QueueCode(); return
            end
            self:FlushCode(true)
        end)
    end
    function widget:CaptureSelection()
        -- EditBox exposes no selection range. A guarded native insertion gives
        -- its real byte boundaries, including selection made with mouse/Shift.
        -- The marker never enters the source, callbacks or undo history.
        local before = native.get(box)
        local marker = "\239\128\128"
        while before:find(marker, 1, true) do marker = marker .. "\239\128\128" end
        self.settingCode = true
        native.insert(box, marker)
        local after = Code:Decode(native.get(box))
        local start = after:find(marker, 1, true)
        local selection
        if start then
            local first = start - 1
            local last = first + #self.display + #marker - #after
            selection = { first = Code:ToRaw(self.ranges, first), last = Code:ToRaw(self.ranges, last) }
        end
        return selection
    end
    function widget:FlushCode(preserveSelection)
        if not self.pendingCode then return end
        local cursor = self:GetCursorPosition()
        local selection = preserveSelection and box:HasFocus() and self:CaptureSelection() or nil
        self.tokens, self.folds = Code:Scan(self.raw)
        self:Render(cursor, selection, true)
        self:Fire("OnCodeSettled", self.raw)
    end

    function widget:GetText() return self.raw or "" end
    function widget:SetDiagnostics(diagnostics)
        self.diagnosticLines = {}
        for _, row in ipairs(self.rows) do row.diagnostic = nil; row.error:Hide() end
        for _, diagnostic in ipairs(diagnostics or {}) do
            if diagnostic.location then self.diagnosticLines[diagnostic.location.line] = diagnostic end
        end
        self:DrawGutter()
    end
    -- Explicit editor actions are one undo unit. Native typing still never
    -- passes through this path or rewrites the buffer during a text event.
    function widget:EditText(text, cursor)
        if self.readOnly or text == self.raw then return false end
        self.pendingIndent, self.selectedLines = nil, nil
        self.raw, self.collapsed = text, {}
        self.tokens, self.folds = Code:Scan(text)
        self:Render(cursor, nil, true)
        local history = self.codeHistory
        for index = #history, self.codeHistoryIndex + 1, -1 do history[index] = nil end
        history[#history + 1] = { text = text, cursor = cursor }
        if #history > 50 then table.remove(history, 1) end
        self.codeHistoryIndex = #history
        self:Fire("OnTextChanged", text)
        self:Fire("OnCodeSettled", text)
        return true
    end
    function widget:SelectLine()
        self:FlushCode()
        local cursor = self:GetCursorPosition()
        local line = Code:LineAt(self.rawLines, cursor)
        local first = self.selectedLines and self.selectedLines.last == cursor and self.selectedLines.first or self.rawLines[line].start
        local last = self.rawLines[line + 1] and self.rawLines[line + 1].start or #self.raw
        self.selectingLines = true
        self:SetCursorPosition(last); self:HighlightText(first, last)
        self.selectingLines = nil
        self.selectedLines = { first = first, last = last }
    end
    function widget:SetText(text)
        self.centerToken = nil
        self.comparisonNumbers, self.comparisonMissing, self.comparisonSpans, self.sourceText = nil, nil, nil, nil
        self.raw, self.collapsed = text or "", {}
        if not self.undoingCode then self.codeHistory, self.codeHistoryIndex = { { text = self.raw, cursor = 0 } }, 1 end
        self.folds = {}
        self.tokens, self.pendingIndent = nil, nil
        if #self.raw > 50000 then self:Render(0, nil, nil, true); self:QueueCode(); return end
        self.tokens, self.folds = Code:Scan(self.raw)
        self:Render(0)
    end
    function widget:GetCursorPosition()
        if not self.ranges then return 0 end
        local buffer, position = native.get(box), native.cursor(box)
        if buffer ~= self.cursorBuffer or position ~= self.cursorNative then
            local cursor
            if buffer == self.inputBuffer then cursor = self:DisplayPosition(position)
            else local _; _, cursor = Code:Decode(buffer:sub(1, position)) end
            self.cursorBuffer, self.cursorNative, self.cursorDisplay = buffer, position, cursor
        end
        return Code:ToRaw(self.ranges, self.cursorDisplay)
    end
    function widget:DisplayPosition(position)
        local shift = 0
        for index = #(self.nativeChanges or {}), 1, -1 do
            local change = self.nativeChanges[index]
            if position > change.newFinish then
                position = position - (change.newFinish - change.oldFinish)
                shift = shift + change.displayDelta
            elseif position >= change.first then
                local value = Code:Decode(change.inserted:sub(1, position - change.first))
                return change.displayFirst + #value + shift
            end
        end
        local low, high = 1, #self.spans
        while low < high do
            local middle = math.floor((low + high) / 2)
            if self.spans[middle].nativeFinish < position then low = middle + 1 else high = middle end
        end
        local span = self.spans[low]
        if not span then return shift end
        if position < span.offset then return span.start + shift end
        local prefix = self.rendered:sub(span.offset + 1, math.min(position, span.nativeFinish)):gsub("||", "|")
        return span.start + #prefix + shift
    end
    function widget:RevealPosition(position)
        local changed
        for _, fold in ipairs(self.folds) do
            if self.collapsed[fold.start] and position > fold.start and position < fold.finish then
                self.collapsed[fold.start], changed = nil, true
            end
        end
        if changed then self:Render(position) end
    end
    function widget:SetCursorPosition(position)
        self.centerToken = nil
        self:FlushCode()
        position = math.max(0, math.min(#self.raw, position or 0))
        self:RevealPosition(position)
        native.move(box, Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, position)))
    end
    function widget:HighlightText(first, last)
        if not self.ranges then native.highlight(box, 0, 0); return end
        self:FlushCode()
        first, last = first or 0, last or #self.raw
        -- A selection crossing hidden data must also copy that data.
        local changed
        for _, fold in ipairs(self.folds) do
            if self.collapsed[fold.start] and last > fold.start and first < fold.finish then
                self.collapsed[fold.start], changed = nil, true
            end
        end
        if changed then self:Render(self:GetCursorPosition()) end
        native.highlight(box, Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, first)),
            Code:EncodePosition(self.display, self.spans, Code:ToDisplay(self.ranges, last)))
    end
    function widget:ToggleFold(start, recursive)
        self:FlushCode()
        for _, fold in ipairs(self.folds) do
            if fold.start == start then
                self:FoldRegion(fold, not self.collapsed[start], recursive); return
            end
        end
    end
    function widget:CommitFolds()
        local cursor, offset = self:GetCursorPosition(), scroll:GetVerticalScroll()
        for _, fold in ipairs(self.folds) do
            if self.collapsed[fold.start] and cursor > fold.start and cursor < fold.finish then cursor = fold.start; break end
        end
        self:Render(cursor)
        scroll:SetVerticalScroll(math.min(offset, scroll:GetVerticalScrollRange())); self:DrawGutter()
        self:Fire("OnFoldingChanged")
    end
    function widget:FoldRegion(region, collapse, recursive)
        if self.comparisonNumbers then return end
        for _, fold in ipairs(self.folds) do
            if fold == region or (recursive and fold.start >= region.start and fold.finish <= region.finish) then
                self.collapsed[fold.start] = collapse or nil
            end
        end
        self:CommitFolds()
    end
    function widget:FoldCurrent(collapse, recursive, toggle)
        self:FlushCode()
        if self.comparisonNumbers then return end
        local cursor, candidate = self:GetCursorPosition()
        local line = Code:LineAt(self.rawLines, cursor)
        for _, fold in ipairs(self.folds) do
            if ((cursor >= fold.start and cursor < fold.finish) or fold.line == line) and
                (toggle or not not self.collapsed[fold.start] ~= collapse) and
                (not candidate or fold.depth > candidate.depth) then candidate = fold end
        end
        if candidate then self:FoldRegion(candidate, toggle and not self.collapsed[candidate.start] or collapse, recursive) end
    end
    function widget:FoldAll(collapse, level, kind)
        self:FlushCode()
        if self.comparisonNumbers then return end
        local cursor = self:GetCursorPosition()
        for _, fold in ipairs(self.folds) do
            if (not level or (fold.depth == level and not (cursor >= fold.start and cursor < fold.finish))) and
                (not kind or fold.kind == kind) then self.collapsed[fold.start] = collapse or nil end
        end
        self:CommitFolds()
    end
    function widget:UnfoldAll()
        self:FoldAll(false)
    end
    function widget:CenterRange(first, last)
        self:FlushCode()
        self:RevealPosition(first); self:RevealPosition(last or first)
        local token = {}; self.centerToken = token
        local function center()
            if self.centerToken ~= token or not self.ranges then return end
            local from = Code:ToDisplay(self.ranges, first)
            local to = Code:ToDisplay(self.ranges, last or first)
            local firstLine, lastLine = Code:LineAt(self.lines, from), Code:LineAt(self.lines, to)
            local y = ((firstLine + lastLine - 1) / 2) * self.lineHeight - scroll:GetHeight() / 2
            scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), y)))
            local line = self.lines[firstLine]
            measure:SetText(self.display:sub(line.start + 1, from):gsub("|", "||"))
            local x = measure:GetStringWidth()
            measure:SetText(self.display:sub(from + 1, math.min(to, line.start + #line.text)):gsub("|", "||"))
            x = x + measure:GetStringWidth() / 2 - scroll:GetWidth() / 2
            horizontal:SetValue(math.max(0, math.min(self.textWidth - scroll:GetWidth(), x)))
            self:DrawGutter()
        end
        center(); C_Timer.After(0, center)
    end
    function widget:HasFoldingFocus()
        if box:HasFocus() or (self.foldingInput and self.foldingInput:HasFocus()) then return true end
        for _, input in ipairs(self.commandInputs or {}) do if input:HasFocus() then return true end end
        return false
    end
    function widget:SetFoldingInput(input)
        self.foldingInput = input
        keyboard:SetFrameLevel(math.max(box:GetFrameLevel(), input and input:GetFrameLevel() or 0) + 1)
        for _, entry in ipairs(self.commandInputs or {}) do keyboard:SetFrameLevel(math.max(keyboard:GetFrameLevel(), entry:GetFrameLevel() + 1)) end
    end
    function widget:SetCommandHandler(handler, inputs)
        self.commandHandler, self.commandInputs = handler, inputs
        self:SetFoldingInput(self.foldingInput)
    end
    function widget:HandleEditorKey(key, intercepted)
        key = key:upper()
        if self:HandleFoldingKey(key, intercepted) then return true end
        if box:HasFocus() and key == "L" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
            self:SelectLine(); return true
        end
        if self.commandHandler then return self.commandHandler(key) end
        return false
    end
    function widget:CancelFoldingChord()
        local pending = self.foldChord
        self.foldChord = nil
        keyboard:SetScript("OnUpdate", nil)
        if pending then self:Fire("OnFoldingChordChanged", false) end
    end
    function widget:HandleFoldingKey(key, intercepted)
        if self.comparisonNumbers then return false end
        key = key:upper()
        -- Ctrl is released/repressed between chord steps. Its own key event
        -- must not consume the pending chord before the next command key.
        if modifierKeys[key] then return false end
        key = key:match("^NUMPAD(%d)$") or azertyDigits[key] or key
        local control = IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())
        local chord = self.foldChord and GetTime() <= self.foldChord
        self:CancelFoldingChord()
        local handled = false
        if control and key == "K" then
            self.foldChord = GetTime() + 3; handled = true
            self:Fire("OnFoldingChordChanged", true)
            keyboard:SetScript("OnUpdate", function()
                if not self:HasFoldingFocus() or GetTime() > self.foldChord then self:CancelFoldingChord() end
            end)
        elseif chord and control then
            if key == "0" then self:FoldAll(true); handled = true
            elseif key == "J" then self:UnfoldAll(); handled = true
            elseif key == "L" then self:FoldCurrent(nil, false, true); handled = true
            elseif key == "[" or key == "LBRACKET" then self:FoldCurrent(true, true); handled = true
            elseif key == "]" or key == "RBRACKET" then self:FoldCurrent(false, true); handled = true
            elseif key == "/" or key == "SLASH" then self:FoldAll(true, nil, "comment"); handled = true
            elseif key == "8" then self:FoldAll(true, nil, "region"); handled = true
            elseif key == "9" then self:FoldAll(false, nil, "region"); handled = true
            elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 7 then
                self:FoldAll(true, tonumber(key)); handled = true
            end
        elseif control and IsShiftKeyDown() then
            if key == "[" or key == "LBRACKET" then self:FoldCurrent(true); handled = true
            elseif key == "]" or key == "RBRACKET" then self:FoldCurrent(false); handled = true end
        end
        if handled and not intercepted then
            local token = {}; self.commandInput = token
            C_Timer.After(0, function() if self.commandInput == token then self.commandInput = nil end end)
        end
        return handled
    end
    function widget:SetDiff(other, side)
        self.changedLines, self.diffSide = Code:ChangedLines(self.raw, other), side
        self:DrawGutter()
    end
    function widget:SetComparison(source, comparison, side)
        local text, numbers, changes, spans, missing = Code:ComparisonText(comparison, side)
        self:SetText(text); self:FlushCode()
        self.sourceText, self.comparisonNumbers, self.changedLines = source, numbers, changes
        self.comparisonSpans, self.comparisonMissing, self.diffSide = spans, missing, side
        self:SetDisabled(true); self:DrawGutter()
    end
    function widget:UndoCode(delta)
        if self.readOnly then return end
        local index = self.codeHistoryIndex + delta
        local snapshot = self.codeHistory[index]
        if not snapshot then return end
        self.codeHistoryIndex, self.undoingCode = index, true
        self:SetText(snapshot.text); self.undoingCode = nil
        self:SetCursorPosition(snapshot.cursor)
        self:Fire("OnTextChanged", self.raw)
    end
    function widget:SetDisabled(disabled)
        self.readOnly = disabled
        disable(self, disabled)
        -- Read-only previews retain syntax colors and permit copying.
        box:SetTextColor(0.83, 0.83, 0.83); box:EnableMouse(true)
        scroll:EnableMouse(true)
    end
    function widget:OnAcquire()
        self.raw, self.folds, self.collapsed = "", {}, {}
        self.changedLines, self.diffSide = nil, nil
        self.comparisonNumbers, self.comparisonMissing, self.comparisonSpans, self.sourceText = nil, nil, nil, nil
        acquire(self)
        box:EnableKeyboard(true)
        keyboard:EnableKeyboard(true)
        keyboard:SetPropagateKeyboardInput(true)
        self:SetFoldingInput(nil)
        self:DisableButton(true)
        widget.scrollBG:SetBackdropColor(0.118, 0.118, 0.118, 1)
        horizontal:SetValue(0); scroll:SetHorizontalScroll(0)
    end
    function widget:OnRelease()
        release(self)
        self:CancelFoldingChord()
        self.foldingInput = nil
        self.commandHandler, self.commandInputs, self.diagnosticLines, self.selectedLines = nil, nil, nil, nil
        keyboard:EnableKeyboard(false)
        keyboard:SetPropagateKeyboardInput(true)
        self.pendingCode = nil
        self.pendingIndent, self.tokens, self.visibleFolds, self.autoIndent = nil, nil, nil, nil
        self.cursorBuffer, self.cursorNative, self.cursorDisplay = nil, nil, nil
        self.inputBuffer, self.nativeChanges = nil, nil
        self.centerToken, self.foldChord, self.commandInput = nil, nil, nil
        self.codeHistory, self.codeHistoryIndex = nil, nil
        self.raw, self.display, self.rendered, self.spans, self.ranges = nil, nil, nil, nil, nil
        self.folds, self.lines, self.rawLines, self.collapsed, self.changedLines = nil, nil, nil, nil, nil
        self.comparisonNumbers, self.comparisonMissing, self.comparisonSpans, self.sourceText = nil, nil, nil, nil
        for _, row in ipairs(self.rows) do
            row.fold, row.diagnostic = nil, nil; row.frame:Hide(); row.background:Hide(); row.inline:Hide(); row.error:Hide()
            for _, hatch in ipairs(row.hatches) do hatch:Hide() end
        end
        GameTooltip:Hide()
    end

    -- The public native methods use full, uncolored byte offsets, just like
    -- the previous editor. AceGUI/search/undo/recording never see decoration.
    box.GetText = function() return widget:GetText() end
    box.SetText = function(_, text) widget:SetText(text) end
    box.GetCursorPosition = function() return widget:GetCursorPosition() end
    box.SetCursorPosition = function(_, position)
        if widget.settingCode then native.move(box, position) else widget:SetCursorPosition(position) end
    end
    box.GetNumLetters = function() return #(widget.raw or "") end
    box.HighlightText = function(_, first, last)
        if widget.settingCode then native.highlight(box, first, last) else widget:HighlightText(first, last) end
    end
    box.Insert = function(_, text) native.insert(box, (text or ""):gsub("|", "||")) end
    box:SetScript("OnTextSet", nil)
    box:SetScript("OnTextChanged", function(_, userInput)
        if widget.settingCode or not userInput then return end
        widget.selectedLines = nil
        widget.pendingIndent = nil
        if widget.readOnly or widget.commandInput then
            widget.commandInput = nil; widget:Render(widget:GetCursorPosition()); return
        end
        local buffer, old = native.get(box), widget.display
        local nativeFirst, nativeLast, nativeFinish = Code:NativeEdit(widget.inputBuffer, buffer)
        local first, last = widget:DisplayPosition(nativeFirst), widget:DisplayPosition(nativeLast)
        local nativeInserted = buffer:sub(nativeFirst + 1, nativeFinish)
        local inserted = Code:Decode(nativeInserted)
        local display = old:sub(1, first) .. inserted .. old:sub(last + 1)
        widget.nativeChanges[#widget.nativeChanges + 1] = { first = nativeFirst, oldFinish = nativeLast, newFinish = nativeFinish,
            displayFirst = first, displayDelta = #inserted - (last - first), inserted = nativeInserted }
        widget.inputBuffer = buffer
        if display == old then widget:QueueCode(); return end
        local from, to = Code:ToRaw(widget.ranges, first), Code:ToRaw(widget.ranges, last)
        -- Edits adjacent to collapsed tables preserve every hidden byte.
        widget.raw = widget.raw:sub(1, from) .. inserted .. widget.raw:sub(to + 1)
        local delta, collapsed = #inserted - (to - from), {}
        for start in pairs(widget.collapsed) do
            if start < from then collapsed[start] = true
            elseif start >= to then collapsed[start + delta] = true end
        end
        widget.collapsed = collapsed
        for _, fold in ipairs(widget.folds) do
            if fold.start >= to then fold.start = fold.start + delta end
            if fold.finish >= to then fold.finish = fold.finish + delta end
            if fold.contentStart and fold.contentStart >= to then fold.contentStart = fold.contentStart + delta end
            if fold.contentFinish and fold.contentFinish >= to then fold.contentFinish = fold.contentFinish + delta end
        end
        local _, ranges = Code:Project(widget.raw, widget.folds, widget.collapsed)
        widget.display, widget.ranges = display, ranges
        local cursor = widget:GetCursorPosition()
        widget:QueueCode()
        local history = widget.codeHistory
        for index = #history, widget.codeHistoryIndex + 1, -1 do history[index] = nil end
        if widget.indentingCode then history[#history] = { text = widget.raw, cursor = cursor }
        else history[#history + 1] = { text = widget.raw, cursor = cursor } end
        if #history > 50 then table.remove(history, 1) end
        widget.codeHistoryIndex = #history
        widget:Fire("OnTextChanged", widget.raw, widget.indentingCode)
        if widget.autoIndent and inserted == "\n" then
            local token = {}; widget.pendingIndent = token
            C_Timer.After(0, function()
                if widget.pendingIndent ~= token then return end
                widget.pendingIndent = nil
                local cursor = widget:GetCursorPosition()
                if widget.raw:sub(cursor, cursor) ~= "\n" then return end
                local start = cursor - 1
                while start > 0 and widget.raw:sub(start, start) ~= "\n" do start = start - 1 end
                local indent = widget.raw:sub(start + 1, cursor - 1):match("^([ \t]+)")
                if indent then
                    widget.indentingCode = true
                    box:Insert(indent)
                    widget.indentingCode = nil
                end
            end)
        end
    end)
    box:SetScript("OnKeyDown", function(_, key)
        if widget:HandleEditorKey(key) then return end
        if key == "F7" then widget:Fire("OnDiffNavigation", IsShiftKeyDown() and -1 or 1); return end
        if IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown()) then
            if key == "A" then widget:UnfoldAll()
            elseif key == "Z" then widget:UndoCode(IsShiftKeyDown() and 1 or -1)
            elseif key == "Y" then widget:UndoCode(1) end
        end
    end)
    box:SetScript("OnTabPressed", function()
        if widget.commandHandler and widget.commandHandler("TAB") then return end
        if not widget.readOnly then box:Insert("    ") end
    end)
    keyboard:SetScript("OnKeyDown", function(frame, key)
        local focused = widget:HasFoldingFocus()
        local handled = focused and widget:HandleEditorKey(key, true)
        if not focused then widget:CancelFoldingChord() end
        frame:SetPropagateKeyboardInput(not handled)
    end)
    box:HookScript("OnEditFocusGained", function() widget:SetFoldingInput(widget.foldingInput) end)
    box:HookScript("OnEditFocusLost", function() widget:CancelFoldingChord(); widget.commandInput = nil end)
    local cursorChanged = box:GetScript("OnCursorChanged")
    box:SetScript("OnCursorChanged", function(frame, ...)
        if widget.settingCode then return end
        if not widget.selectingLines then widget.selectedLines = nil end
        cursorChanged(frame, ...)
        if not widget.ranges then return end
        local snapshot = widget.codeHistory and widget.codeHistory[widget.codeHistoryIndex]
        if snapshot and snapshot.text == widget.raw then snapshot.cursor = widget:GetCursorPosition() end
        widget:Fire("OnCodeCursorChanged", widget:GetCursorPosition())
        if widget.pendingCode then return end
        local _, position = Code:Decode(native.get(box):sub(1, native.cursor(box)))
        for _, range in ipairs(widget.ranges) do
            if range.hidden and position > range.display and position < range.display + range.length then
                widget.collapsed[range.foldStart or range.start - 1] = nil
                widget:Render(range.start); return
            end
        end
        widget:DrawGutter()
    end)
    scroll:SetScript("OnSizeChanged", function() if widget.lines then widget:SizeCode() end end)
    local function fontChanged() if widget.lines then widget:SizeCode() end end
    hooksecurefunc(box, "SetFont", fontChanged)
    hooksecurefunc(box, "SetFontObject", fontChanged)
    scroll:HookScript("OnVerticalScroll", function(_, offset)
        if widget.lines then widget:DrawGutter() end
        widget:Fire("OnScrollChanged", offset)
    end)
    local function wheel(_, delta)
        if IsShiftKeyDown() then horizontal:SetValue(math.max(0, math.min((widget.textWidth or scroll:GetWidth()) - scroll:GetWidth(), horizontal:GetValue() - delta * 40)))
        else scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * (widget.lineHeight or 14) * 3))) end
        widget:DrawGutter()
    end
    scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel", wheel)
    gutter:EnableMouseWheel(true); gutter:SetScript("OnMouseWheel", wheel)
    return widget
end, 1)
