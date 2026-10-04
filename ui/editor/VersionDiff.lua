local GUI = LibStub("AceGUI-3.0")
local UI, Model, Editor, Code = AprRC.editorUI, AprRC.editorModel, AprRC.routeEditor, AprRC.luaCode
local T = UI.Text

function Editor:OpenVersionDiff(leftChoice, rightChoice)
    local session = self.session
    if not session then return end
    if self.versionDiffDialog then self.versionDiffDialog:Hide() end
    local source = Model:Source(session.name)
    if not source then return end
    -- Capture live values once. Comparing versions never applies or saves data.
    local entries = { saved = T("Saved"), draft = T("Lua draft"), base = T("Common ancestor") }
    local texts = { saved = Model:RouteText(AprRC:BuildRouteDefinition(source)),
        draft = session.raw or Model:RouteText(session.draft), base = session.base }
    local versions = {}
    for _, version in ipairs(Model:History(session.name)) do
        local key = "version:" .. version.id
        local timestamp = date and date("%Y-%m-%d %H:%M:%S", version.time) or tostring(version.time)
        entries[key] = timestamp .. " · " .. T(version.reason) .. " (#" .. version.id .. ")"
        versions[key] = version
    end
    leftChoice, rightChoice = entries[leftChoice] and leftChoice or "saved", entries[rightChoice] and rightChoice or "draft"
    local function sourceText(key)
        if not texts[key] then
            local version = versions[key]
            texts[key] = version.raw or Model:RouteText(version.route)
        end
        return texts[key]
    end
    local dialog = AprRC:CreateWidget("Frame")
    self.versionDiffDialog = dialog
    dialog:SetTitle(T("Compare versions"))
    dialog:SetWidth(math.min(1240, UIParent:GetWidth())); dialog:SetHeight(math.min(780, UIParent:GetHeight()))
    dialog:SetLayout("APRWorkspace")
    UI.LabelWidget(UI.Toolbar(dialog), session.name, true)
    local selectors = UI.Group(dialog); selectors:SetLayout("APRColumns")
    local leftSelector, rightSelector = UI.Group(selectors), UI.Group(selectors)
    local split = AprRC:CreateWidget("APRSplitGroup")
    -- AceGUI resets the layout after OnAcquire, including for pooled widgets.
    split:SetLayout("APRSplit")
    split:SetUserData("body", true); dialog:AddChild(split)
    local leftPane, rightPane = UI.Body(split), UI.Body(split)
    local function editor(parent)
        local box = AprRC:CreateWidget("APRLuaEditor")
        box:SetUserData("body", true); parent:AddChild(box)
        return box
    end
    local leftBox, rightBox = editor(leftPane), editor(rightPane)
    self.versionDiffLeftBox, self.versionDiffRightBox = leftBox, rightBox
    local footer = UI.Toolbar(dialog, true)
    local counter = UI.LabelWidget(footer, "")
    local comparison, index, previous, nextButton, syncing = nil, 0
    local function alignScroll(offset)
        -- Both views share a reachable offset, including at the last line
        -- when their viewport heights differ during resizing or layout.
        offset = math.max(0, math.min(offset, leftBox.scrollFrame:GetVerticalScrollRange(), rightBox.scrollFrame:GetVerticalScrollRange()))
        leftBox.scrollFrame:SetVerticalScroll(offset)
        rightBox.scrollFrame:SetVerticalScroll(offset)
    end
    local function status()
        counter:SetText(T("%d changes; +%d / -%d lines"):format(#comparison.hunks, comparison.inserted, comparison.removed) ..
            (#comparison.hunks > 0 and (" · " .. T("Change %d of %d"):format(index, #comparison.hunks)) or " · " .. T("No differences")))
        previous:SetDisabled(#comparison.hunks == 0); nextButton:SetDisabled(#comparison.hunks == 0)
    end
    local function navigate(delta)
        if not comparison or #comparison.hunks == 0 then return end
        index = (index - 1 + delta) % #comparison.hunks + 1
        local hunk = comparison.hunks[index]
        syncing = true
        for _, box in ipairs({ leftBox, rightBox }) do
            local first, last = box.lines[hunk.first], box.lines[hunk.last]
            box.editBox:SetCursorPosition(first.start)
            box:CenterRange(first.start, last.start + #last.text)
        end
        alignScroll(leftBox.scrollFrame:GetVerticalScroll())
        syncing = nil; status()
    end
    local function sync(widget, _, offset)
        if syncing or not comparison then return end
        syncing = true
        alignScroll(offset)
        syncing = nil
    end
    leftBox:SetCallback("OnScrollChanged", sync); rightBox:SetCallback("OnScrollChanged", sync)
    leftBox:SetCallback("OnDiffNavigation", function(_, _, delta) navigate(delta) end)
    rightBox:SetCallback("OnDiffNavigation", function(_, _, delta) navigate(delta) end)
    local function render()
        local left, right = sourceText(leftChoice), sourceText(rightChoice)
        comparison, index = Code:Compare(left, right), 0
        self.versionDiffComparison = comparison
        syncing = true
        leftBox:SetComparison(left, comparison, "left"); rightBox:SetComparison(right, comparison, "right")
        leftBox:SetLabel(entries[leftChoice]); rightBox:SetLabel(entries[rightChoice])
        syncing = nil
        dialog:DoLayout()
        if #comparison.hunks > 0 then navigate(1) else status() end
    end
    self.versionDiffLeftSelect = UI.Dropdown(leftSelector, T("Left version"), entries, leftChoice, function(value)
        leftChoice = value; render()
    end)
    self.versionDiffRightSelect = UI.Dropdown(rightSelector, T("Right version"), entries, rightChoice, function(value)
        rightChoice = value; render()
    end)
    previous = UI.Button(footer, "Previous change", function() navigate(-1) end, 150)
    nextButton = UI.Button(footer, "Next change", function() navigate(1) end, 150)
    self.versionDiffPrevious, self.versionDiffNext = previous, nextButton
    UI.LabelWidget(footer, T("F7 / Shift+F7: next / previous change."))
    UI.Button(footer, CLOSE, function() dialog:Hide() end, 100)
    dialog:SetCallback("OnClose", function(widget)
        self.versionDiffDialog, self.versionDiffComparison = nil, nil
        self.versionDiffLeftBox, self.versionDiffRightBox = nil, nil
        self.versionDiffLeftSelect, self.versionDiffRightSelect = nil, nil
        self.versionDiffPrevious, self.versionDiffNext = nil, nil
        GUI:Release(widget)
    end)
    render()
end
