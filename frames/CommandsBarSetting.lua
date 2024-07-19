local AceGUI = LibStub("AceGUI-3.0")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.CommandBarSetting = AprRC:NewModule('CommandBarSetting')

-- Liste des commandes disponibles
local allCommands = {
    { command = "btn",           label = "Button",              texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Button" },
    { command = "class",         label = "Class",               texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Class" },
    { command = "coord",         label = "Coord",               texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Coord" },
    { command = "donedb",        label = "DoneDB",              texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\DoneDB" },
    { command = "noachievement", label = "DontHaveAchievement", texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\DontHaveAchievement" },
    { command = "notskipvid",    label = "Dontskipvid",         texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Dontskipvid" },
    { command = "eta",           label = "ETA",                 texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\ETA" },
    { command = "text",          label = "ExtraLineText",       texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\ExtraLineText" },
    { command = "faction",       label = "Faction",             texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Faction" },
    { command = "filler",        label = "Fillers",             texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Fillers" },
    { command = "gender",        label = "Gender",              texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Gender" },
    { command = "grind",         label = "Grind",               texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Grind" },
    { command = "achievement",   label = "HasAchievement",      texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\HasAchievement" },
    { command = "instance",      label = "InstanceQuest",       texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\InstanceQuest" },
    { command = "addjob",        label = "LearnProfession",     texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\LearnProfession" },
    { command = "noarrow",       label = "NoArrow",             texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\NoArrow" },
    { command = "pickupdb",      label = "PickUpDB",            texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\PickUpDB" },
    { command = "qpartdb",       label = "QpartDB",             texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\QpartDB" },
    { command = "qpartpart",     label = "QpartPart",           texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\QpartPart" },
    { command = "race",          label = "Race",                texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Race" },
    { command = "range",         label = "Range",               texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Range" },
    { command = "spelltrigger",  label = "SpellTrigger",        texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\SpellTrigger" },
    { command = "vehicle",       label = "VehicleExit",         texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\VehicleExit" },
    { command = "warmode",       label = "WarMode",             texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\WarMode" },
    { command = "waypoint",      label = "Waypoint",            texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\Waypoint" },
    { command = "zonetrigger",   label = "ZoneStepTrigger",     texture = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\ZoneStepTrigger" },
}

function AprRC.CommandBarSetting:Show()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Command Bar Settings")
    frame:SetStatusText("Manage your command bar, click to move")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(650)
    frame:SetHeight(400)
    frame:EnableResize(false)
    frame:SetLayout("Flow")
    self.frame = frame

    LibWindow.RegisterConfig(frame.frame, AprRC.settings.profile.commandBarSettingFrame)
    LibWindow.RestorePosition(frame.frame)
    LibWindow.MakeDraggable(frame.frame)

    -- Create container for left list
    local leftContainer = AceGUI:Create("InlineGroup")
    leftContainer:SetHeight(300)
    leftContainer:SetTitle("Command List")
    leftContainer:SetLayout("Fill")

    local leftList = AceGUI:Create("ScrollFrame")
    leftList:SetLayout("List")
    leftContainer:AddChild(leftList)

    -- Create container for right list
    local rightContainer = AceGUI:Create("InlineGroup")
    rightContainer:SetTitle("Commands in Command Bar")
    rightContainer:SetHeight(300)
    rightContainer:SetLayout("Fill")

    local rightList = AceGUI:Create("ScrollFrame")
    rightList:SetLayout("List")
    rightContainer:AddChild(rightList)

    -- Initialize lists from saved data
    local leftCommands = {}

    for _, commandData in ipairs(allCommands) do
        local found = false
        for _, selectedCommand in ipairs(AprRCData.CommandBarCommands) do
            if commandData.label == selectedCommand.label then
                found = true
                break
            end
        end
        if not found then
            table.insert(leftCommands, commandData)
        end
    end

    -- Sort leftCommands alphabetically by label
    table.sort(leftCommands, function(a, b) return a.label < b.label end)

    -- Helper function to create an interactive label
    local function CreateInteractiveLabel(commandData, isSelected, onClick)
        local interacLabel = AceGUI:Create("InteractiveLabel")
        interacLabel:SetText(commandData.label)
        interacLabel:SetColor(255, 255, 255)
        interacLabel:SetFullWidth(true)
        if isSelected then
            interacLabel:SetJustifyH("RIGHT")
        end
        interacLabel:SetCallback("OnClick", onClick)
        interacLabel:SetCallback("OnEnter", function(widget)
            widget:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end)
        interacLabel:SetCallback("OnLeave", function(widget)
            widget:SetHighlight(nil)
        end)
        return interacLabel
    end

    -- Refresh function to update both lists
    local function RefreshLists()
        leftList:ReleaseChildren()
        rightList:ReleaseChildren()

        for _, commandData in ipairs(leftCommands) do
            leftList:AddChild(CreateInteractiveLabel(commandData, false, function()
                table.insert(AprRCData.CommandBarCommands, commandData)
                for i, cmd in ipairs(leftCommands) do
                    if cmd.label == commandData.label then
                        table.remove(leftCommands, i)
                        break
                    end
                end
                table.sort(leftCommands, function(a, b) return a.label < b.label end)
                RefreshLists()
                AprRC.CommandBar:RefreshFrameAnchor()
            end))
        end

        for _, selectedCommand in ipairs(AprRCData.CommandBarCommands) do
            for _, commandData in ipairs(allCommands) do
                if commandData.label == selectedCommand.label then
                    rightList:AddChild(CreateInteractiveLabel(commandData, true, function()
                        table.insert(leftCommands, commandData)
                        for i, cmd in ipairs(AprRCData.CommandBarCommands) do
                            if cmd.label == selectedCommand.label then
                                table.remove(AprRCData.CommandBarCommands, i)
                                break
                            end
                        end
                        table.sort(leftCommands, function(a, b) return a.label < b.label end)
                        RefreshLists()
                        AprRC.CommandBar:RefreshFrameAnchor()
                    end))
                    break
                end
            end
        end
    end

    frame:AddChild(leftContainer)
    frame:AddChild(rightContainer)

    RefreshLists()
end
