local AceGUI = LibStub("AceGUI-3.0")

AprRC.CommandBarSetting = AprRC:NewModule("CommandBarSetting")

local iconPath = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"

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
local allCommands = {
    { command = "btn",                               label = "Button",                                  texture = iconPath .. "Button" },
    { command = "class",                             label = "Class",                                   texture = iconPath .. "Class" },
    { command = "coord",                             label = "Coord",                                   texture = iconPath .. "Coord" },
    { command = "donedb",                            label = "Done DB",                                 texture = iconPath .. "DoneDB" },
    { command = "noachievement",                     label = "Don't Have Achievement",                  texture = iconPath .. "DontHaveAchievement" },
    { command = "noaura",                            label = "Don't Have Aura",                         texture = iconPath .. "DontHaveAura" },
    { command = "notskipvid",                        label = "Don't skip vid",                          texture = iconPath .. "Dontskipvid" },
    { command = "eta",                               label = "ETA",                                     texture = iconPath .. "ETA" },
    { command = "gossipeta",                         label = "Gossip ETA",                              texture = iconPath .. "GossipETA" },
    { command = "specialetahide",                    label = "Special ETA Hide",                        texture = iconPath .. "SpecialETAHide" },
    { command = "text",                              label = "Extra Line Text",                         texture = iconPath .. "ExtraLineText" },
    { command = "faction",                           label = "Faction",                                 texture = iconPath .. "Faction" },
    { command = "filler",                            label = "Fillers",                                 texture = iconPath .. "Fillers" },
    { command = "gender",                            label = "Gender",                                  texture = iconPath .. "Gender" },
    { command = "grind",                             label = "Grind",                                   texture = iconPath .. "Grind" },
    { command = "achievement",                       label = "Has Achievement",                         texture = iconPath .. "HasAchievement" },
    { command = "aura",                              label = "Has Aura",                                texture = iconPath .. "HasAura" },
    { command = "buffs",                             label = "Buffs",                                   texture = iconPath .. "Buffs" },
    { command = "spell",                             label = "Has Spell",                               texture = iconPath .. "HasSpell" },
    { command = "useitem",                           label = "Use Item",                                texture = iconPath .. "UseItem" },
    { command = "usespell",                          label = "Use Spell",                               texture = iconPath .. "UseSpell" },
    { command = "instance",                          label = "Instance Quest",                          texture = iconPath .. "InstanceQuest" },
    { command = "isCompleted",                       label = "Is Quest Completed On Account",           texture = iconPath .. "IsQuestsCompletedOnAccount" },
    { command = "isQuestsCompleted",                 label = "Is Quests Completed",                     texture = iconPath .. "IsQuestsCompletedOnAccount" },
    { command = "isOneOfQuestsCompleted",            label = "Is One Of Quests Completed",              texture = iconPath .. "IsQuestsCompletedOnAccount" },
    { command = "isOneOfQuestsCompletedOnAccount",   label = "Is One Of Quests Completed On Account",   texture = iconPath .. "IsQuestsCompletedOnAccount" },
    { command = "isUncompleted",                     label = "Is Quest Uncompleted On Account",         texture = iconPath .. "IsQuestsUncompletedOnAccount" },
    { command = "isQuestsUncompleted",               label = "Is Quests Uncompleted",                   texture = iconPath .. "IsQuestsUncompletedOnAccount" },
    { command = "isOneOfQuestsUncompleted",          label = "Is One Of Quests Uncompleted",            texture = iconPath .. "IsQuestsUncompletedOnAccount" },
    { command = "isOneOfQuestsUncompletedOnAccount", label = "Is One Of Quests Uncompleted On Account", texture = iconPath .. "IsQuestsUncompletedOnAccount" },
    { command = "addjob",                            label = "Learn Profession",                        texture = iconPath .. "LearnProfession" },
    { command = "lootitem",                          label = "Loot Item",                               texture = iconPath .. "LootItem" },
    { command = "noarrow",                           label = "No Arrow",                                texture = iconPath .. "NoArrow" },
    { command = "noautoflightmap",                   label = "No Auto Flight Map",                      texture = iconPath .. "NoAutoFlightMap" },
    { command = "pickupdb",                          label = "PickUp DB",                               texture = iconPath .. "PickUpDB" },
    { command = "qpartdb",                           label = "Qpart DB",                                texture = iconPath .. "QpartDB" },
    { command = "qpartpart",                         label = "Qpart Part",                              texture = iconPath .. "QpartPart" },
    { command = "race",                              label = "Race",                                    texture = iconPath .. "Race" },
    { command = "range",                             label = "Range",                                   texture = iconPath .. "Range" },
    { command = "addreset",                          label = "Reset Route",                             texture = iconPath .. "ResetRoute" },
    { command = "adventuremap",                      label = "Adventure Map Visible",                   texture = iconPath .. "IsAdventureMapVisible" },
    { command = "spelltrigger",                      label = "Spell Trigger",                           texture = iconPath .. "SpellTrigger" },
    { command = "vehicle",                           label = "Vehicle Exit",                            texture = iconPath .. "VehicleExit" },
    { command = "mountvehicle",                      label = "Mount Vehicle",                           texture = iconPath .. "MountVehicle" },
    { command = "warmode",                           label = "WarMode",                                 texture = iconPath .. "WarMode" },
    { command = "waypoint",                          label = "Waypoint",                                texture = iconPath .. "Waypoint" },
    { command = "waypointdb",                        label = "Waypoint DB",                             texture = iconPath .. "WaypointDB" },
    { command = "zonetrigger",                       label = "Zone Step Trigger",                       texture = iconPath .. "ZoneStepTrigger" },
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function FindIndexByLabel(label)
    for i, s in ipairs(AprRCData.CommandBarCommands) do
        if s.label == label then return i end
    end
    return nil
end

local function InsertCommand(cmd, pos)
    local current = FindIndexByLabel(cmd.label)
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
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale - 10)
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

    local f = label.frame

    ------------------------------------------------------------
    -- LEFT LIST CLICK HANDLER
    ------------------------------------------------------------
    if listType == "left" then
        f:SetScript("OnMouseDown", nil)
        f:SetScript("OnMouseUp", function()
            print("LEFT CLICK:", cmd.label)

            table.insert(AprRCData.CommandBarCommands, cmd)

            -- remove from left list
            for i, c in ipairs(leftCommands) do
                if c.label == cmd.label then
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

    f:SetScript("OnMouseDown", function()
        dragging = cmd
        local ghost = GetGhostFrame()
        ghost.icon:SetTexture(cmd.texture)
        ghost.text:SetText(cmd.label)
        ghost:Show()
    end)

    f:SetScript("OnMouseUp", function(_, button)
        -- Right-click REMOVE
        if button == "RightButton" then
            local idx = FindIndexByLabel(cmd.label)
            if idx then
                table.remove(AprRCData.CommandBarCommands, idx)
            end

            table.insert(leftCommands, cmd)
            table.sort(leftCommands, function(a, b) return a.label < b.label end)

            dragging = nil
            ghostFrame:Hide()
            RefreshLists()
            AprRC.CommandBar:RefreshFrameAnchor()
            return
        end

        -- Drag reorder
        if dragging then
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
        end

        dragging = nil
        ghostFrame:Hide()
        RefreshLists()
        AprRC.CommandBar:RefreshFrameAnchor()
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
        for _, cmd in ipairs(allCommands) do
            local used = false
            for _, selected in ipairs(AprRCData.CommandBarCommands) do
                if cmd.label == selected.label then
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
                if c.label == entry.label then
                    cmd = c
                    break
                end
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
            ghostFrame:SetScript("OnUpdate", nil)
            ghostFrame:Hide()
        end

        filterBox:SetCallback("OnTextChanged", nil)
        RefreshLists = function() end

        -- Restore the original scripts of the right labels BEFORE Release
        for _, btn in ipairs(rightButtons) do
            if btn.frame then
                if btn._origDown then
                    btn.frame:SetScript("OnMouseDown", btn._origDown)
                else
                    btn.frame:SetScript("OnMouseDown", nil)
                end
                if btn._origUp then
                    btn.frame:SetScript("OnMouseUp", btn._origUp)
                else
                    btn.frame:SetScript("OnMouseUp", nil)
                end
            end
            btn._origDown = nil
            btn._origUp   = nil
        end
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
        frame = nil
    else
        self:CreateFrame()
    end
end
