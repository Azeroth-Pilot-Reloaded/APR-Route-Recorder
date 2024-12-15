local AceGUI = LibStub("AceGUI-3.0")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.CommandBarSetting = AprRC:NewModule('CommandBarSetting')

local iconPath = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"
-- Liste des commandes disponibles
local allCommands = {
    { command = "btn",           label = "Button",              texture = iconPath .. "Button" },
    { command = "class",         label = "Class",               texture = iconPath .. "Class" },
    { command = "coord",         label = "Coord",               texture = iconPath .. "Coord" },
    { command = "donedb",        label = "DoneDB",              texture = iconPath .. "DoneDB" },
    { command = "noachievement", label = "DontHaveAchievement", texture = iconPath .. "DontHaveAchievement" },
    { command = "noaura",        label = "DontHaveAura",        texture = iconPath .. "DontHaveAura" },
    { command = "notskipvid",    label = "Dontskipvid",         texture = iconPath .. "Dontskipvid" },
    { command = "eta",           label = "ETA",                 texture = iconPath .. "ETA" },
    { command = "text",          label = "ExtraLineText",       texture = iconPath .. "ExtraLineText" },
    { command = "faction",       label = "Faction",             texture = iconPath .. "Faction" },
    { command = "filler",        label = "Fillers",             texture = iconPath .. "Fillers" },
    { command = "gender",        label = "Gender",              texture = iconPath .. "Gender" },
    { command = "grind",         label = "Grind",               texture = iconPath .. "Grind" },
    { command = "achievement",   label = "HasAchievement",      texture = iconPath .. "HasAchievement" },
    { command = "aura",          label = "HasAura",             texture = iconPath .. "HasAura" },
    { command = "spell",         label = "HasSpell",            texture = iconPath .. "HasSpell" },
    { command = "instance",      label = "InstanceQuest",       texture = iconPath .. "InstanceQuest" },
    { command = "addjob",        label = "LearnProfession",     texture = iconPath .. "LearnProfession" },
    { command = "lootitem",      label = "LootItem",            texture = iconPath .. "LootItem" },
    { command = "noarrow",       label = "NoArrow",             texture = iconPath .. "NoArrow" },
    { command = "pickupdb",      label = "PickUpDB",            texture = iconPath .. "PickUpDB" },
    { command = "qpartdb",       label = "QpartDB",             texture = iconPath .. "QpartDB" },
    { command = "qpartpart",     label = "QpartPart",           texture = iconPath .. "QpartPart" },
    { command = "race",          label = "Race",                texture = iconPath .. "Race" },
    { command = "range",         label = "Range",               texture = iconPath .. "Range" },
    { command = "addreset",      label = "ResetRoute",          texture = iconPath .. "ResetRoute" },
    { command = "spelltrigger",  label = "SpellTrigger",        texture = iconPath .. "SpellTrigger" },
    { command = "vehicle",       label = "VehicleExit",         texture = iconPath .. "VehicleExit" },
    { command = "warmode",       label = "WarMode",             texture = iconPath .. "WarMode" },
    { command = "waypoint",      label = "Waypoint",            texture = iconPath .. "Waypoint" },
    { command = "waypointdb",    label = "WaypointDB",          texture = iconPath .. "WaypointDB" },
    { command = "zonetrigger",   label = "ZoneStepTrigger",     texture = iconPath .. "ZoneStepTrigger" },
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
