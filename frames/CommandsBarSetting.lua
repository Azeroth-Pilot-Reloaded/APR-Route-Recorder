local AceGUI = LibStub("AceGUI-3.0")
local LibWindow = LibStub("LibWindow-1.1")

AprRC.CommandBarSetting = AprRC:NewModule('CommandBarSetting')

local iconPath = "Interface\\AddOns\\APR-Recorder\\assets\\icons\\"
-- Liste des commandes disponibles
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
    { command = "isUncompleted",                     label = "Is Quest Uncompleted On Accountt",        texture = iconPath .. "IsQuestsUncompletedOnAccount" },
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
