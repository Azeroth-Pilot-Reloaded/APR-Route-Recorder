local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.export = AprRC:NewModule('Export')

local frame
function AprRC.export:Hide()
    if frame then
        AceGUI:Release(frame)
    end
    frame = nil
end

function AprRC.export:Show()
    local refreshTimer

    frame = AceGUI:Create("Frame")
    frame:SetTitle("Export")
    frame:SetLayout("Flow")
    frame:SetStatusText(L_APR["COPY_HELPER"])
    frame:SetStatusTable(AprRC.settings.profile.exportFrame)

    local topGroup = AceGUI:Create("SimpleGroup")
    topGroup:SetFullWidth(true)
    topGroup:SetLayout("Flow")
    frame:AddChild(topGroup)

    local stepLabel = AceGUI:Create("Label")
    stepLabel:SetFullWidth(true)
    stepLabel:SetText("Steps: 0")

    local checkbox
    local ResizeEditBoxHeight
    local AutoScrollToBottom

    local function SetBackupFromRoute(routeSteps)
        AprRCData.BackupRoute = {}
        for k, v in pairs(routeSteps or {}) do
            AprRCData.BackupRoute[k] = v
        end
    end

    local function UpdateStepCount(routeSteps)
        local count = routeSteps and #routeSteps or 0
        stepLabel:SetText(string.format("Steps: %d", count))
    end

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("Select Route")
    dropdown:SetFullWidth(true)
    local routeList = {}
    local defaultIndex = nil
    local selectedRouteName = ''
    for index, route in ipairs(AprRCData.Routes) do
        if index == 1 then
            selectedRouteName = route.name
        end
        routeList[index] = route.name
        if AprRCData.CurrentRoute and route.name == AprRCData.CurrentRoute.name then
            defaultIndex = index
            selectedRouteName = route.name
        end
    end
    dropdown:SetList(routeList)
    topGroup:AddChild(dropdown)
    topGroup:AddChild(stepLabel)

    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(600)
    scrollContainer:SetLayout("Fill")
    frame:AddChild(scrollContainer)

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel('')
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    editbox:DisableButton(true)
    scrollContainer:AddChild(editbox)
    AprRC.export.editbox = editbox

    local history = {}
    local historyIndex = 0
    local historyLimit = 50
    local isUndoRedo = false
    local ignoreHistory = false
    local lastTextLen = 0
    local stopAutoRefreshFn = nil

    local function GetRouteText(route)
        if not route then
            return ""
        end
        return AprRC:TableToString(route.steps)
    end

    local function PushHistorySnapshot(text)
        if ignoreHistory or not text then
            return
        end
        -- drop redo branch when a new change happens
        for i = historyIndex + 1, #history do
            history[i] = nil
        end
        local current = history[historyIndex]
        if current and current.text == text then
            return
        end
        historyIndex = historyIndex + 1
        history[historyIndex] = { text = text, cursor = editbox.editBox and editbox.editBox:GetCursorPosition() or 0 }
        if #history > historyLimit then
            table.remove(history, 1)
            historyIndex = historyIndex - 1
        end
    end

    local function ResetHistoryWith(text)
        history = {}
        historyIndex = 0
        ignoreHistory = false
        PushHistorySnapshot(text)
    end

    local function ApplyHistoryState(state)
        if not state then
            return
        end
        ignoreHistory = true
        isUndoRedo = true
        editbox:SetText(state.text or "")
        local cursor = math.min(state.cursor or 0, (state.text or ""):len())
        if editbox.editBox then
            editbox.editBox:SetCursorPosition(cursor)
        end
        lastTextLen = (state.text or ""):len()
        isUndoRedo = false
        ignoreHistory = false
    end

    local function PerformUndo()
        if historyIndex <= 1 then
            return
        end
        historyIndex = historyIndex - 1
        ApplyHistoryState(history[historyIndex])
    end

    local function PerformRedo()
        if historyIndex >= #history then
            return
        end
        historyIndex = historyIndex + 1
        ApplyHistoryState(history[historyIndex])
    end

    local function HandleHistoryKey(self, key)
        local ctrl = IsControlKeyDown() or IsMetaKeyDown()
        if not ctrl then
            return false
        end
        if key == "Z" then
            if IsShiftKeyDown() then
                PerformRedo()
            else
                PerformUndo()
            end
            return true
        elseif key == "Y" then
            PerformRedo()
            return true
        end
        return false
    end

    local function SetEditboxText(text, pushHistory)
        ignoreHistory = not pushHistory
        editbox:SetText(text or "")
        lastTextLen = (editbox:GetText() or ""):len()
        ignoreHistory = false
        if pushHistory then
            PushHistorySnapshot(editbox:GetText())
        end
    end

    local isAutoIndenting = false

    local bottomGroup = AceGUI:Create("SimpleGroup")
    bottomGroup:SetFullWidth(true)
    bottomGroup:SetLayout("Flow")
    frame:AddChild(bottomGroup)

    ResizeEditBoxHeight = function()
        if not frame then
            return
        end
        -- Make sure the control groups report their current height before sizing the editor.
        frame:DoLayout()
        local contentHeight = frame.content:GetHeight() or 0
        local topHeight = topGroup.frame:GetHeight() or 0
        local bottomHeight = bottomGroup.frame:GetHeight() or 0
        local padding = 12 -- small spacer to account for Flow layout gaps
        local available = contentHeight - topHeight - bottomHeight - padding
        local newHeight = math.max(0, available)
        scrollContainer:SetHeight(newHeight)
        frame:DoLayout()
    end

    AutoScrollToBottom = function()
        C_Timer.After(0.1, function()
            local scrollFrame = editbox.scrollFrame
            scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
        end)
    end

    StopAutoRefresh = function()
        if refreshTimer then
            AceTimer:CancelTimer(refreshTimer)
            refreshTimer = nil
        end
    end

    if frame.frame and not frame._resizeHooked then
        frame._resizeHooked = true
        frame.frame:HookScript("OnSizeChanged", function()
            ResizeEditBoxHeight()
        end)
    end

    if editbox.editBox then
        editbox.editBox:HookScript("OnKeyDown", function(self, key)
            if HandleHistoryKey(self, key) then
                return
            end
        end)
    end

    editbox:SetCallback("OnTextChanged", function(widget, event, text)
        if isAutoIndenting or isUndoRedo then
            lastTextLen = (widget.editBox:GetText() or ""):len()
            return
        end
        local eb = widget.editBox
        if not eb then
            return
        end
        local fullText = eb:GetText() or ""
        local newLen = #fullText
        local prevLen = lastTextLen or 0

        -- Only auto-indent when text length just increased (user typed something, likely newline)
        if newLen > prevLen then
            local cursor = eb:GetCursorPosition()
            local beforeCursor = fullText:sub(1, cursor)
            if beforeCursor:sub(-1) == "\n" then
                local preNewline = beforeCursor:sub(1, -2)
                local lastNewlinePos = preNewline:match(".*()\n")
                local lineStart = lastNewlinePos and (lastNewlinePos + 1) or 1
                local previousLine = preNewline:sub(lineStart)
                local indent = previousLine:match("^(%s*)") or ""
                if indent ~= "" then
                    isAutoIndenting = true
                    eb:Insert(indent)
                    isAutoIndenting = false
                    fullText = eb:GetText() or fullText
                    newLen = #fullText
                end
            end
        end

        lastTextLen = newLen
        PushHistorySnapshot(fullText)

        -- Disable auto refresh on first manual edit
        if checkbox and checkbox:GetValue() then
            checkbox:SetValue(false)
            StopAutoRefresh()
        end
    end)

    local function StartAutoRefresh(dropdown, editbox)
        if not refreshTimer then
            refreshTimer = AceTimer:ScheduleRepeatingTimer(function()
                if dropdown:GetValue() then
                    if AprRCData.CurrentRoute.name ~= "" then
                        AprRC:UpdateRouteByName(AprRCData.CurrentRoute.name, AprRCData.CurrentRoute)
                        local route = AprRCData.Routes[dropdown:GetValue()]
                        if route then
                            SetEditboxText(GetRouteText(route), false)
                            UpdateStepCount(route.steps)
                            AutoScrollToBottom()
                        end
                    end
                end
            end, 2)
        end
    end


    local btnSave = AceGUI:Create("Button")
    btnSave:SetText("Save Route")
    btnSave:SetWidth(200)
    btnSave:SetCallback("OnClick", function()
        local routeText = editbox:GetText()
        if AprRC:HasLuaComments(routeText) then
            AprRC:Error("Route not saved: remove Lua comments (\"--\" or \"--[[ ]]\" blocks) before saving.")
            return
        end
        local newStepRouteTable = AprRC:StringToTable(routeText)
        if not newStepRouteTable then
            AprRC:Error("Route not saved, incorrect format")
            return
        end
        local isValid, reason = AprRC:ValidateRouteTable(newStepRouteTable)
        if not isValid then
            AprRC:Error("Route not saved, invalid step structure: " .. tostring(reason))
            return
        end
        local newRoute = {
            name = selectedRouteName,
            steps = newStepRouteTable
        }
        AprRC:UpdateRouteByName(selectedRouteName, newRoute)
        if AprRCData.CurrentRoute.name == selectedRouteName then
            AprRCData.CurrentRoute = newRoute
        end
        SetBackupFromRoute(newStepRouteTable)
        UpdateStepCount(newStepRouteTable)
        AutoScrollToBottom()
        ResetHistoryWith(routeText)
    end)
    bottomGroup:AddChild(btnSave)

    local btnExportELT = AceGUI:Create("Button")
    btnExportELT:SetText("Export Extra Line Text")
    btnExportELT:SetWidth(200)
    btnExportELT:SetCallback("OnClick", function()
        AprRC.exportExtraLineText.Show()
        AceGUI:Release(frame)
        frame = nil
    end)
    bottomGroup:AddChild(btnExportELT)

    local exportToAPRBtn = AceGUI:Create("Button")
    exportToAPRBtn:SetText("Export this route into APR")
    exportToAPRBtn:SetWidth(200)
    exportToAPRBtn:SetCallback("OnClick", function()
        local route = AprRC:FindRouteByName(selectedRouteName)
        local name = route.name .. ' - Custom'
        APRData.CustomRoute[name] = route.steps
        APR.RouteQuestStepList[name] = route.steps
        APR.RouteList.Custom[name] = name:match("%d+-(.*)")
        AutoScrollToBottom()
    end)
    bottomGroup:AddChild(exportToAPRBtn)

    checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel("Enable Auto Refresh")
    checkbox:SetWidth(200)
    checkbox:SetValue(false)
    checkbox:SetDisabled(true)
    checkbox:SetCallback("OnValueChanged", function(widget, event, value)
        if value then
            StartAutoRefresh(dropdown, editbox)
        else
            StopAutoRefresh()
        end
        local currentIdx = dropdown:GetValue()
        local selectedRoute = currentIdx and AprRCData.Routes[currentIdx]
        UpdateStepCount(selectedRoute and selectedRoute.steps or nil)
    end)
    bottomGroup:AddChild(checkbox)

    if defaultIndex then
        if AprRCData.Routes[defaultIndex].name == AprRCData.CurrentRoute.name then
            checkbox:SetDisabled(false)
        end
        dropdown:SetValue(defaultIndex)
        local defaultRoute = AprRCData.Routes[defaultIndex]
        local initialText = GetRouteText(defaultRoute)
        SetEditboxText(initialText, true)
        ResetHistoryWith(initialText)
        SetBackupFromRoute(defaultRoute.steps)
        UpdateStepCount(defaultRoute.steps)
        AutoScrollToBottom()
    end

    dropdown:SetCallback("OnValueChanged", function(widget, event, index)
        local selectedRoute = AprRCData.Routes[index]
        if selectedRoute then
            local routeText = GetRouteText(selectedRoute)
            SetEditboxText(routeText, true)
            ResetHistoryWith(routeText)
            selectedRouteName = selectedRoute.name
            SetBackupFromRoute(selectedRoute.steps)
            if selectedRouteName == AprRCData.CurrentRoute.name then
                checkbox:SetDisabled(false)
            else
                checkbox:SetDisabled(true)
                checkbox:SetValue(false)
                StopAutoRefresh()
            end
            AutoScrollToBottom()
            ResizeEditBoxHeight()
            UpdateStepCount(selectedRoute.steps)
        end
    end)

    frame:SetCallback("OnClose", function(widget)
        StopAutoRefresh()
        AceGUI:Release(widget)
        frame = nil
    end)

    UpdateStepCount(defaultIndex and AprRCData.Routes[defaultIndex].steps or nil)
    ResizeEditBoxHeight()
end
