local AceGUI = LibStub("AceGUI-3.0")

AprRC.CommandBarSetting = AprRC:NewModule("CommandBarSetting")

------------------------------------------------------------
-- LOCAL STATE
------------------------------------------------------------
local frame = nil
local ghostFrame = nil
local dragging = nil
local rightButtons = {}

------------------------------------------------------------
-- COMMAND DEFINITIONS
------------------------------------------------------------
local allCommands = {}

local function RefreshCommandCatalog()
    wipe(allCommands)
    AprRC.options:AddToolbarCommands(allCommands)
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function FindIndexByCommand(command)
    for i, s in ipairs(AprRCData.CommandBarCommands) do
        if strlower(s.command or "") == strlower(command or "") then return i end
    end
    return nil
end

local function InsertCommand(cmd, pos)
    local current = FindIndexByCommand(cmd.command)
    if current then
        table.remove(AprRCData.CommandBarCommands, current)
        if current < pos then pos = pos - 1 end
    end
    table.insert(AprRCData.CommandBarCommands, pos, cmd)
end

local function CommandMatchesFilter(cmd, text)
    if not text or text == "" then return true end
    text = text:lower()
    return cmd.label:lower():find(text, 1, true)
end

------------------------------------------------------------
-- GHOST FRAME (DRAG PREVIEW)
------------------------------------------------------------
local function GetGhostFrame()
    if ghostFrame then return ghostFrame end

    ghostFrame = CreateFrame("Frame", nil, UIParent)
    ghostFrame:SetSize(150, 24)
    ghostFrame:SetFrameStrata("TOOLTIP")
    ghostFrame:Hide()

    ghostFrame.icon = ghostFrame:CreateTexture(nil, "ARTWORK")
    ghostFrame.icon:SetSize(20, 20)
    ghostFrame.icon:SetPoint("LEFT")

    ghostFrame.text = ghostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ghostFrame.text:SetPoint("LEFT", ghostFrame.icon, "RIGHT", 4, 0)

    ghostFrame:SetScript("OnUpdate", function(self)
        if not self:IsShown() then return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale - 10)

        -- InteractiveLabel widgets are pooled by AceGUI. Using SetScript directly
        -- on their frames leaves our handlers attached after the widget is
        -- released, so finish the drag from this non-pooled preview instead.
        if dragging and not IsMouseButtonDown("LeftButton") then
            local onDrop = dragging.onDrop
            dragging = nil
            self:Hide()

            if onDrop then
                onDrop()
            end
        end
    end)

    return ghostFrame
end

------------------------------------------------------------
-- CREATE INTERACTIVE LABEL (UNIFIED LOGIC)
------------------------------------------------------------
local function CreateInteractiveLabel(cmd, listType, leftCommands, RefreshLists)
    local label = AceGUI:Create("InteractiveLabel")
    label:SetText(cmd.label)
    label:SetImage(cmd.texture)
    label:SetImageSize(20, 20)
    label:SetFullWidth(true)

    label:SetCallback("OnEnter", function(widget)
        widget:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end)
    label:SetCallback("OnLeave", function(widget)
        widget:SetHighlight(nil)
    end)

    ------------------------------------------------------------
    -- LEFT LIST CLICK HANDLER
    ------------------------------------------------------------
    if listType == "left" then
        label:SetCallback("OnClick", function(_, _, button)
            if button ~= "LeftButton" then return end

            table.insert(AprRCData.CommandBarCommands, cmd)

            -- remove from left list
            for i, c in ipairs(leftCommands) do
                if strlower(c.command or "") == strlower(cmd.command or "") then
                    table.remove(leftCommands, i)
                    break
                end
            end

            RefreshLists()
            AprRC.CommandBar:RefreshFrameAnchor()
        end)

        return label
    end

    ------------------------------------------------------------
    -- RIGHT LIST (DRAG/REMOVE/REORDER)
    ------------------------------------------------------------
    label:SetCallback("OnClick", function(_, _, button)
        -- Right-click REMOVE
        if button == "RightButton" then
            local idx = FindIndexByCommand(cmd.command)
            if idx then
                table.remove(AprRCData.CommandBarCommands, idx)
            end

            table.insert(leftCommands, cmd)
            table.sort(leftCommands, function(a, b) return a.label < b.label end)

            dragging = nil
            if ghostFrame then ghostFrame:Hide() end
            RefreshLists()
            AprRC.CommandBar:RefreshFrameAnchor()
            return
        end

        if button ~= "LeftButton" then return end

        local ghost = GetGhostFrame()
        ghost.icon:SetTexture(cmd.texture)
        ghost.text:SetText(cmd.label)

        dragging = {
            command = cmd,
            onDrop = function()
                local _, cy = GetCursorPosition()
                cy = cy / UIParent:GetEffectiveScale()

                local insertPos = #AprRCData.CommandBarCommands + 1

                for i, btn in ipairs(rightButtons) do
                    local centerY = select(2, btn.frame:GetCenter())
                    if cy > (centerY - 15) then
                        insertPos = i
                        break
                    end
                end

                InsertCommand(cmd, insertPos)
                RefreshLists()
                AprRC.CommandBar:RefreshFrameAnchor()
            end,
        }

        ghost:Show()
    end)

    return label
end

------------------------------------------------------------
-- CREATE FRAME
------------------------------------------------------------
function AprRC.CommandBarSetting:CreateFrame()
    frame = AceGUI:Create("Frame")
    frame:SetTitle("Command Bar Settings")
    frame:SetLayout("Fill")
    frame:SetStatusText("Click or Drag commands to manage the bar. Right-click to remove.")
    frame:SetStatusTable(AprRC.settings.profile.commandBarSettingFrame)

    local isClosed = false

    ------------------------------------------------------------
    -- MAIN GROUP
    ------------------------------------------------------------
    local mainGroup = AceGUI:Create("SimpleGroup")
    mainGroup:SetFullWidth(true)
    mainGroup:SetFullHeight(true)
    mainGroup:SetLayout("Flow")
    frame:AddChild(mainGroup)

    ------------------------------------------------------------
    -- FILTER
    ------------------------------------------------------------
    local filterBox = AceGUI:Create("EditBox")
    filterBox:SetLabel("Filter Commands")
    filterBox:SetFullWidth(true)
    mainGroup:AddChild(filterBox)

    --------------------------------------------------------
    -- LEFT COLUMN
    --------------------------------------------------------
    local leftContainer = AceGUI:Create("InlineGroup")
    leftContainer:SetTitle("Available Commands")
    leftContainer:SetRelativeWidth(0.5)
    leftContainer:SetFullHeight(true)
    leftContainer:SetLayout("Fill")

    local leftList = AceGUI:Create("ScrollFrame")
    leftList:SetLayout("List")
    leftList:SetFullWidth(true)
    leftList:SetFullHeight(true)

    --------------------------------------------------------
    -- RIGHT COLUMN
    --------------------------------------------------------
    local rightContainer = AceGUI:Create("InlineGroup")
    rightContainer:SetTitle("Commands In Bar")
    rightContainer:SetRelativeWidth(0.5)
    rightContainer:SetFullHeight(true)
    rightContainer:SetLayout("Fill")



    local rightList = AceGUI:Create("ScrollFrame")
    rightList:SetLayout("List")
    rightList:SetFullWidth(true)
    rightList:SetFullHeight(true)

    ------------------------------------------------------------
    -- APPEND CHILDREN
    ------------------------------------------------------------
    leftContainer:AddChild(leftList)
    rightContainer:AddChild(rightList)
    mainGroup:AddChild(leftContainer)
    mainGroup:AddChild(rightContainer)

    ------------------------------------------------------------
    -- DATA
    ------------------------------------------------------------
    local leftCommands = {}

    local function RebuildLeftCommands()
        wipe(leftCommands)
        RefreshCommandCatalog()
        for _, cmd in ipairs(allCommands) do
            local used = false
            for _, selected in ipairs(AprRCData.CommandBarCommands) do
                if strlower(cmd.command or "") == strlower(selected.command or "") then
                    used = true
                    break
                end
            end
            if not used then table.insert(leftCommands, cmd) end
        end
        table.sort(leftCommands, function(a, b) return a.label < b.label end)
    end

    ------------------------------------------------------------
    -- REFRESH LISTS
    ------------------------------------------------------------
    local RefreshLists
    RefreshLists = function()
        if isClosed then return end
        if not leftList or not rightList then return end

        leftList:ReleaseChildren()
        rightList:ReleaseChildren()
        wipe(rightButtons)

        local filterText = filterBox:GetText() or ""

        ----------------------------------------------------
        -- LEFT LIST
        ----------------------------------------------------
        for _, cmd in ipairs(leftCommands) do
            if CommandMatchesFilter(cmd, filterText) then
                local label = CreateInteractiveLabel(cmd, "left", leftCommands, RefreshLists)
                leftList:AddChild(label)
            end
        end

        ----------------------------------------------------
        -- RIGHT LIST (DRAGGABLE)
        ----------------------------------------------------
        for _, entry in ipairs(AprRCData.CommandBarCommands) do
            local cmd
            for _, c in ipairs(allCommands) do
                if strlower(c.command or "") == strlower(entry.command or "") then
                    cmd = c
                    break
                end
            end
            if not cmd and entry.command then
                cmd = {
                    command = entry.command,
                    label = entry.label or entry.command,
                    texture = entry.texture or AprRC.options:GetToolbarIcon(entry.command),
                }
            end
            if cmd and CommandMatchesFilter(cmd, filterText) then
                local label = CreateInteractiveLabel(cmd, "right", leftCommands, RefreshLists)
                rightList:AddChild(label)
                table.insert(rightButtons, label)
            end
        end
    end

    filterBox:SetCallback("OnTextChanged", RefreshLists)

    ------------------------------------------------------------
    -- INITIALIZE
    ------------------------------------------------------------
    RebuildLeftCommands()
    RefreshLists()

    ------------------------------------------------------------
    -- ON CLOSE CLEAN UP
    ------------------------------------------------------------
    frame:SetCallback("OnClose", function(widget)
        isClosed = true
        dragging = nil

        if ghostFrame then
            ghostFrame:Hide()
        end

        filterBox:SetCallback("OnTextChanged", nil)
        RefreshLists = function() end
        wipe(rightButtons)

        AceGUI:Release(widget)
        frame = nil
    end)

    return frame
end

------------------------------------------------------------
-- SHOW
------------------------------------------------------------
function AprRC.CommandBarSetting:Show()
    if frame then
        frame:Hide()
    else
        self:CreateFrame()
    end
end
