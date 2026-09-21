local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")
local AceGUI = LibStub("AceGUI-3.0")

AprRC.command = AprRC:NewModule("Command")

local function CanDoCommand()
    if not AprRC.settings.profile.enableAddon then
        APR:PrintError(L["The addon is disabled"])
        return false
    elseif not AprRC.settings.profile.recordBarFrame.isRecording then
        APR:PrintError(L["You're not recording a route"])
        return false
    end
    return true
end
function AprRC.command:SlashCmd(input)
    if AprRC.options:Dispatch(input) then return end
    local inputText = string.lower(input)
    local questCheckCommands = {
        iscompleted = {
            key = "IsQuestsCompletedOnAccount",
            prompt = L["Is Quest Completed On Account (QuestID number)"],
            message = "IsQuestsCompletedOnAccount",
        },
        isuncompleted = {
            key = "IsQuestsUncompletedOnAccount",
            prompt = L["Is Quest Uncompleted On Account (QuestID number)"],
            message = "IsQuestsUncompletedOnAccount",
        },
        isoneofquestscompleted = {
            key = "IsOneOfQuestsCompleted",
            prompt = L["Is One Of Quests Completed (QuestID number)"],
            message = "IsOneOfQuestsCompleted",
        },
        isoneofquestsuncompleted = {
            key = "IsOneOfQuestsUncompleted",
            prompt = L["Is One Of Quests Uncompleted (QuestID number)"],
            message = "IsOneOfQuestsUncompleted",
        },
        isoneofquestscompletedonaccount = {
            key = "IsOneOfQuestsCompletedOnAccount",
            prompt = L["Is One Of Quests Completed On Account (QuestID number)"],
            message = "IsOneOfQuestsCompletedOnAccount",
        },
        isoneofquestsuncompletedonaccount = {
            key = "IsOneOfQuestsUncompletedOnAccount",
            prompt = L["Is One Of Quests Uncompleted On Account (QuestID number)"],
            message = "IsOneOfQuestsUncompletedOnAccount",
        },
        isquestscompleted = {
            key = "IsQuestsCompleted",
            prompt = L["Is Quests Completed (QuestID number)"],
            message = "IsQuestsCompleted",
        },
        isquestsuncompleted = {
            key = "IsQuestsUncompleted",
            prompt = L["Is Quests Uncompleted (QuestID number)"],
            message = "IsQuestsUncompleted",
        },
    }

    local function BuildCurrentCoordData()
        local tempStep = {}
        AprRC:SetStepCoord(tempStep)
        if type(tempStep.Coord) ~= "table" then
            return nil, nil
        end

        local coord = {
            x = tempStep.Coord.x,
            y = tempStep.Coord.y,
        }
        local zone = tempStep.Zone
        return coord, zone
    end

    local function AddCoordsEntryToStep(step)
        local currentCoord, currentZone = BuildCurrentCoordData()
        if not currentCoord then
            APR:PrintError(L["Unable to read player coordinates"])
            return false
        end

        local coords = {}
        if type(step.Coords) == "table" then
            for _, entry in ipairs(step.Coords) do
                if type(entry) == "table" and entry.x and entry.y then
                    table.insert(coords, {
                        x = entry.x,
                        y = entry.y,
                        Zone = entry.Zone,
                    })
                end
            end
        end

        if type(step.Coord) == "table" then
            table.insert(coords, {
                x = step.Coord.x,
                y = step.Coord.y,
                Zone = step.Zone or currentZone,
            })
        end

        table.insert(coords, {
            x = currentCoord.x,
            y = currentCoord.y,
            Zone = currentZone,
        })

        local zones = {}
        for _, entry in ipairs(coords) do
            local zone = tonumber(entry.Zone, 10)
            if zone and not tContains(zones, zone) then
                table.insert(zones, zone)
            end
        end

        step.Coords = coords
        step.Coord = nil
        step.Zone = nil

        if #zones > 0 then
            step.Zones = zones
        end

        return true
    end

    if inputText == "export" or inputText == "editor" or inputText == "" then
        -- Wrap in pcall to handle tainted data from combat
        local ok, result = pcall(function()
            if AprRCData.CurrentRoute.name ~= "" then
                AprRC:UpdateRouteByName(AprRCData.CurrentRoute.name, AprRCData.CurrentRoute)
            end
        end)
        if not ok and result then
            AprRC:Debug("Error during export (likely tainted during combat):", result)
        end
        AprRC.export.Show()
        return
    elseif inputText == "settings" then
        AprRC.settings:OpenSettings(AprRC.title)
        return
    elseif inputText == "forcereset" then
        AprRC:ResetData()
        return
    elseif inputText == 'coordframe' then
        AprRC.settings.profile.coordinateShow = not AprRC.settings.profile.coordinateShow
        AprRC.coordinate:RefreshFrameAnchor()
        return
    elseif inputText == 'backup' then
        AprRCData.CurrentRoute.steps = {}
        for k, v in pairs(AprRCData.BackupRoute) do
            AprRCData.CurrentRoute.steps[k] = v
        end
        return
    elseif inputText == "resetbar" or inputText == "resetcommandbar" or inputText == "barreset" then
        AprRC.CommandBar:ResetToDefault()
        print(L["Command bar reset to defaults"])
        return
    elseif inputText == "help" or inputText == "h" then
        print(L_APR["COMMAND_LIST"] .. ":")
        AprRC.options:PrintHelp()
        print("|cffeda55f/aprrc achievement |r- " .. AprRC.editorUI.Label("HasAchievement"))
        print("|cffeda55f/aprrc addreset |r- " .. AprRC.editorUI.Label("ResetRoute"))
        print("|cffeda55f/aprrc adventuremap |r- " .. AprRC.editorUI.Label("IsAdventureMap"))
        print("|cffeda55f/aprrc aura |r- " .. AprRC.editorUI.Label("HasAura"))
        print("|cffeda55f/aprrc button, btn |r- " .. AprRC.editorUI.Label("Button"))
        print("|cffeda55f/aprrc buffs |r- " .. AprRC.editorUI.Label("Buffs"))
        print("|cffeda55f/aprrc class |r- " .. AprRC.editorUI.Label("Class"))
        print("|cffeda55f/aprrc coord |r- " .. AprRC.editorUI.Label("Coord"))
        print("|cffeda55f/aprrc coords |r- " .. AprRC.editorUI.Label("Coords"))
        print("|cffeda55f/aprrc coordframe |r- " .. L["Coord Frame"])
        print("|cffeda55f/aprrc donedb |r- " .. AprRC.editorUI.Label("DoneDB"))
        print("|cffeda55f/aprrc eta |r- " .. AprRC.editorUI.Label("ETA"))
        print("|cffeda55f/aprrc gossipeta |r- " .. AprRC.editorUI.Label("GossipETA"))
        print("|cffeda55f/aprrc specialetahide |r- " .. AprRC.editorUI.Label("SpecialETAHide"))
        print("|cffeda55f/aprrc export |r- " .. L["To export data"])
        print("|cffeda55f/aprrc faction |r- " .. AprRC.editorUI.Label("Faction"))
        print("|cffeda55f/aprrc fillers, filler |r- " .. AprRC.editorUI.Label("Fillers"))
        print("|cffeda55f/aprrc forcereset |r- " .. L["Clear the Saved Variables"])
        print("|cffeda55f/aprrc gender |r- " .. AprRC.editorUI.Label("Gender"))
        print("|cffeda55f/aprrc grind |r- " .. AprRC.editorUI.Label("Grind"))
        print("|cffeda55f/aprrc help, h |r- " .. L_APR["HELP_COMMAND"])
        print("|cffeda55f/aprrc instance |r- " .. AprRC.editorUI.Label("InstanceQuest"))
        print("|cffeda55f/aprrc isCompleted |r- " .. AprRC.editorUI.Label("IsQuestsCompletedOnAccount"))
        print("|cffeda55f/aprrc isQuestsCompleted |r- " .. AprRC.editorUI.Label("IsQuestsCompleted"))
        print("|cffeda55f/aprrc isOneOfQuestsCompleted |r- " .. AprRC.editorUI.Label("IsOneOfQuestsCompleted"))
        print("|cffeda55f/aprrc isOneOfQuestsCompletedOnAccount |r- " .. AprRC.editorUI.Label("IsOneOfQuestsCompletedOnAccount"))
        print("|cffeda55f/aprrc isUncompleted |r- " .. AprRC.editorUI.Label("IsQuestsUncompletedOnAccount"))
        print("|cffeda55f/aprrc isQuestsUncompleted |r- " .. AprRC.editorUI.Label("IsQuestsUncompleted"))
        print("|cffeda55f/aprrc isOneOfQuestsUncompleted |r- " .. AprRC.editorUI.Label("IsOneOfQuestsUncompleted"))
        print("|cffeda55f/aprrc isOneOfQuestsUncompletedOnAccount |r- " .. AprRC.editorUI.Label("IsOneOfQuestsUncompletedOnAccount"))
        print("|cffeda55f/aprrc LootItems, lt |r- " .. AprRC.editorUI.Label("LootItems"))
        print("|cffeda55f/aprrc noachievement |r- " .. AprRC.editorUI.Label("DontHaveAchievement"))
        print("|cffeda55f/aprrc noarrow |r- " .. AprRC.editorUI.Label("NoArrow"))
        print("|cffeda55f/aprrc noautoflightmap |r- " .. AprRC.editorUI.Label("NoAutoFlightMap"))
        print("|cffeda55f/aprrc denynpc |r- " .. AprRC.editorUI.Label("DenyNPC"))
        print("|cffeda55f/aprrc npcdismount |r- " .. AprRC.editorUI.Label("NpcDismount"))
        print("|cffeda55f/aprrc noaura |r- " .. AprRC.editorUI.Label("DontHaveAura"))
        print("|cffeda55f/aprrc notskipvid, nsv |r- " .. AprRC.editorUI.Label("Dontskipvid"))
        print("|cffeda55f/aprrc pickupdb |r- " .. AprRC.editorUI.Label("PickUpDB"))
        print("|cffeda55f/aprrc qpartdb |r- " .. AprRC.editorUI.Label("QpartDB"))
        print("|cffeda55f/aprrc qpartpart |r- " .. AprRC.editorUI.Label("QpartPart"))
        print("|cffeda55f/aprrc reputation |r- " .. L["Reputation step"])
        print("|cffeda55f/aprrc reputationlevel |r- " .. L["ReputationLevel step option"])
        print("|cffeda55f/aprrc scenario, scenariotrig |r- " .. "Scenario + TrigText")
        print("|cffeda55f/aprrc race |r- " .. AprRC.editorUI.Label("Race"))
        print("|cffeda55f/aprrc range |r- " .. AprRC.editorUI.Label("Range"))
        print("|cffeda55f/aprrc resetbar, resetcommandbar, barreset |r- " .. L["Reset Command Bar"])
        print("|cffeda55f/aprrc skipforlvl |r- " .. AprRC.editorUI.Label("skipForLvl"))
        print("|cffeda55f/aprrc skipforreputation |r- " .. L["SkipForReputation step option"])
        print("|cffeda55f/aprrc spell |r- " .. AprRC.editorUI.Label("HasSpell"))
        print("|cffeda55f/aprrc spelltrigger |r- " .. AprRC.editorUI.Label("SpellTrigger"))
        print("|cffeda55f/aprrc text, txt |r- " .. AprRC.editorUI.Label("ExtraLineText"))
        print("|cffeda55f/aprrc useitem |r- " .. AprRC.editorUI.Label("UseItem"))
        print("|cffeda55f/aprrc usespell |r- " .. AprRC.editorUI.Label("UseSpell"))
        print("|cffeda55f/aprrc waypoint |r- " .. AprRC.editorUI.Label("Waypoint"))
        print("|cffeda55f/aprrc nonskippablewaypoint |r- " .. AprRC.editorUI.Label("NonSkippableWaypoint"))
        print("|cffeda55f/aprrc zonetrigger |r- " .. AprRC.editorUI.Label("ZoneStepTrigger"))
        return
    end
    if CanDoCommand() then
        if inputText == "waypoint" then
            local step = {
                Waypoint = AprRC:FindClosestIncompleteQuest(),
            }
            AprRC:SetStepCoord(step, 5)
            AprRC:ApplyCampaignQuestFlag(step, step.Waypoint)
            AprRC:NewStep(step)
            print("|cff00bfffWaypoint|r " .. L["Added"])
            return
        elseif inputText == "waypointdb" then
            if AprRC:HasStepOption("Waypoint") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Waypoint DB (QuestID) - Also add Waypoint QuestID"],
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError(L["Invalid QuestID format"])
                            return
                        end
                        local currentStep = AprRC:GetLastStep()
                        if AprRC:HasStepOption("WaypointDB") then
                            tinsert(currentStep.WaypointDB, questID)
                        else
                            currentStep.WaypointDB = { currentStep.Waypoint, questID }
                        end
                        AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                        print("|cff00bfffWaypointDB - " .. questID .. "|r " .. L["Added"])
                    end)
            else
                APR:PrintError(L["Missing Waypoint option on current step"])
            end
            return
        elseif inputText == "nonskippablewaypoint" then
            if not AprRC:HasStepOption("Waypoint") then
                APR:PrintError(L["Missing Waypoint option on current step"])
                return
            end

            local currentStep = AprRC:GetLastStep()
            if currentStep.NonSkippableWaypoint then
                APR:PrintError("|cff00bfffNonSkippableWaypoint|r " .. L["Already present on this step"])
                return
            end

            currentStep.NonSkippableWaypoint = true
            print("|cff00bfffNonSkippableWaypoint|r " .. L["Added"])
            return
        elseif inputText == "addjob" then
            AprRC.autocomplete:ShowProfessionAutoComplete()
            return
        elseif inputText == "addreset" then
            local step = { ResetRoute = true }
            AprRC:NewStep(step)
            return
        elseif inputText == "adventuremap" then
            local currentStep = AprRC:GetLastStep()
            currentStep.IsAdventureMap = true
            print("|cff00bfffIsAdventureMap|r " .. L["Added"])
            return
        elseif inputText == "aura" then
            AprRC.autocomplete:ShowAuraAutoComplete(function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.HasAura = tonumber(spellID, 10)
                print("|cff00bfff HasAura |r " .. L["Added"])
                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "noaura" then
            AprRC.autocomplete:ShowAuraAutoComplete(function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.DontHaveAura = tonumber(spellID, 10)
                print("|cff00bfff DontHaveAura |r " .. L["Added"])
                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "coord" then
            local currentStep = AprRC:GetLastStep()
            AprRC:SetStepCoord(currentStep, currentStep.Range)
            currentStep.NoArrow = nil -- remove NoArrow
            print("|cff00bfffCoord|r " .. L["Added"])
            return
        elseif inputText == "coords" then
            local currentStep = AprRC:GetLastStep()

            if not AddCoordsEntryToStep(currentStep) then
                return
            end

            currentStep.NoArrow = nil -- remove NoArrow
            print("|cff00bfffCoords|r " .. L["Added"])
            return
        elseif inputText == "range" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Range (number)"], function(text)
                local rangeValue = AprRC:ParsePositiveNumber(text)
                if not rangeValue then
                    APR:PrintError(L["Invalid range value"])
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.Range = rangeValue
                print("|cff00bfffRange|r " .. L["Added"])
            end)
            return
        elseif inputText == "eta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["ETA (second)"], function(text)
                local etaValue = AprRC:ParsePositiveInteger(text)
                if not etaValue then
                    APR:PrintError(L["Invalid ETA value"])
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.ETA = etaValue
                print("|cff00bfffETA|r " .. L["Added"])
            end)
            return
        elseif inputText == "gossipeta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Gossip ETA (second)"], function(text)
                local gossipEtaValue = AprRC:ParsePositiveInteger(text)
                if not gossipEtaValue then
                    APR:PrintError(L["Invalid Gossip ETA value"])
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.GossipETA = gossipEtaValue
                print("|cff00bfffGossipETA|r " .. L["Added"])
            end)
            return
        elseif inputText == "specialetahide" then
            if not AprRC:HasStepOption("SpecialETAHide") then
                local currentStep = AprRC:GetLastStep()
                currentStep.SpecialETAHide = true
                print("|cff00bfffSpecialETAHide|r " .. L["Added"])
            else
                APR:PrintError("|cff00bfffSpecialETAHide|r " .. L["Already present on this step"])
            end
            return
        elseif inputText == "reputation" then
            AprRC.ReputationFrame:Show("Reputation")
            return
        elseif inputText == "reputationlevel" then
            AprRC.ReputationFrame:Show("ReputationLevel")
            return
        elseif inputText == "skipforreputation" then
            AprRC.ReputationFrame:Show("SkipForReputation")
            return
        elseif inputText == "instance" then
            local currentStep = AprRC:GetLastStep()
            currentStep.InstanceQuest = true
            print("|cff00bfffInstanceQuest|r " .. L["Added"])
            return
        elseif questCheckCommands[inputText] then
            local config = questCheckCommands[inputText]
            AprRC.questionDialog:CreateEditBoxPopupWithCallback(config.prompt, function(text)
                local questIDs = AprRC:ParseQuestIDs(text)
                if not questIDs then
                    APR:PrintError(L["Invalid QuestID list"])
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep[config.key] = questIDs
                print("|cff00bfff" ..
                    config.message .. " - { " .. table.concat(questIDs, ", ") .. " }|r " .. L["Added"])
            end)
            return
        elseif inputText == "lootitems" or inputText == "lt" then
            AprRC.autocomplete:ShowItemAutoComplete(nil, nil, function(_, itemID, frame)
                local numericItemID = tonumber(itemID, 10)
                if not numericItemID then
                    APR:PrintError(L["Invalid item selection"])
                    return
                end

                AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Loot items quantity (number)"], function(text)
                    local quantity = AprRC:ParsePositiveInteger(text)
                    if not quantity or quantity < 1 then
                        APR:PrintError(L["Invalid quantity"])
                        return
                    end

                    local targetQuestID = AprRC:FindClosestIncompleteQuest()

                    local currentStep = AprRC:GetLastStep()

                    if currentStep and currentStep.LootItems then
                        table.insert(currentStep.LootItems, {
                            itemID = numericItemID,
                            quantity = quantity,
                            questID = targetQuestID,
                        })
                        AprRC:ApplyCampaignQuestFlag(currentStep, targetQuestID)

                        print("|cff00bfffLootItems|r " .. L["Updated (added item)"])
                    else
                        local step = {
                            LootItems = {
                                {
                                    itemID = numericItemID,
                                    quantity = quantity,
                                    questID = targetQuestID,
                                }
                            }
                        }

                        AprRC:SetStepCoord(step)
                        AprRC:ApplyCampaignQuestFlag(step, targetQuestID)
                        AprRC:NewStep(step)

                        print("|cff00bfffLootItems|r " .. L["Added"])
                    end
                end, "1")

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "notskipvid" or inputText == "nsv" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Dontskipvid = true
            print("|cff00bfffDontskipvid|r " .. L["Added"])
            return
        elseif inputText == "noarrow" then
            local currentStep = AprRC:GetLastStep()
            currentStep.NoArrow = true
            -- remove useless coord for NoArrow
            currentStep.Coord = nil
            currentStep.Range = nil
            print("|cff00bfffNoArrow|r " .. L["Added"])
            return
        elseif inputText == "noautoflightmap" then
            if not AprRC:HasStepOption("NoAutoFlightMap") then
                local currentStep = AprRC:GetLastStep()
                currentStep.NoAutoFlightMap = true
                print("|cff00bfffNoAutoFlightMap|r " .. L["Added"])
            end
            return
        elseif inputText == "denynpc" then
            local targetId = APR and APR.GetTargetID and APR:GetTargetID()
            if not targetId then
                APR:PrintError(L["No target selected to add DenyNPC"])
                return
            end

            local numericTargetId = tonumber(targetId, 10)
            if not numericTargetId then
                APR:PrintError(L["Invalid target selection for DenyNPC"])
                return
            end

            local currentStep = AprRC:GetLastStep()
            currentStep.DenyNPC = numericTargetId
            print("|cff00bfffDenyNPC - " .. numericTargetId .. "|r " .. L["Added"])
            return
        elseif inputText == "npcdismount" then
            local targetId = APR and APR.GetTargetID and APR:GetTargetID()
            if not targetId then
                APR:PrintError(L["No target selected to add NpcDismount"])
                return
            end

            local numericTargetId = tonumber(targetId, 10)
            if not numericTargetId then
                APR:PrintError(L["Invalid target selection for NpcDismount"])
                return
            end

            local currentStep = AprRC:GetLastStep()
            currentStep.NpcDismount = numericTargetId
            print("|cff00bfffNpcDismount - " .. numericTargetId .. "|r " .. L["Added"])
            return
        elseif inputText == "buffs" then
            AprRC.autocomplete:ShowBuffSelector(function(buffData)
                if not buffData then
                    return
                end
                local addedBuff = AprRC:AddBuffToStep(buffData.spellId, buffData.tooltipMessage)
                if addedBuff then
                    print(string.format("|cff00bfffBuffs|r %s - spellId: %d, tooltipMessage: %s", L["Added"],
                        addedBuff.spellId, addedBuff.tooltipMessage))
                end
            end)
            return
        elseif inputText == "text" or inputText == "txt" then
            AprRC.autocomplete:ShowLocaleAutoComplete()
            return
        elseif inputText == "button" or inputText == "btn" then
            AprRC.SelectButton:Show()
            return
        elseif inputText == "fillers" or inputText == "filler" then
            AprRC.QuestObjectiveSelector:Show({
                title = L["Fillers quest list"],
                statusText = L["Click on an objective to add it as a filler"],
                questList = AprRC.QuestObjectiveSelector:GetQuestList(),
                onClick = function(questID, objectiveID)
                    local currentStep = AprRC:GetLastStep()
                    if not currentStep.Fillers then
                        currentStep.Fillers = {}
                    end
                    if not currentStep.Fillers[questID] then
                        currentStep.Fillers[questID] = {}
                    end
                    if not tContains(currentStep.Fillers[questID], objectiveID) then
                        table.insert(currentStep.Fillers[questID], objectiveID)
                    else
                        print("|cffff0000" .. L["This objective is already present in the fillers for this quest."] .. "|r")
                    end

                    -- insert button if available
                    local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                    local link = GetQuestLogSpecialItemInfo(questLogIndex)
                    if link then
                        local itemID = AprRC:GetItemIDFromLink(link)
                        if not currentStep.Button then
                            currentStep.Button = {}
                        end
                        table.insert(currentStep.Button, questID .. "-" .. objectiveID, itemID)
                    end

                    print("|cff00bfffFillers - [" ..
                        C_QuestLog.GetTitleForQuestID(questID) .. "] - " .. objectiveID .. "|r " .. L["Added"])
                end
            })
            return
        elseif inputText == "spell" then
            AprRC.autocomplete:ShowSpellAutoComplete(_, _, function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.HasSpell = tonumber(spellID, 10)
                print("|cff00bfff HasSpell |r " .. L["Added"])
                AceGUI:Release(frame)
            end, true)
            return
        elseif inputText == "useitem" then
            local questList = AprRC.QuestObjectiveSelector:GetQuestList()
            if #questList == 0 then
                APR:PrintError(L["No quests available to bind UseItem"])
                return
            end

            AprRC.QuestObjectiveSelector:Show({
                title = L["Use Item quest list"],
                statusText = L["Click on an objective to select the quest for the UseItem step"],
                questList = questList,
                onClick = function(questID)
                    AprRC.autocomplete:ShowItemAutoComplete(questID, nil, function(_, itemID, frame)
                        local numericItemID = tonumber(itemID, 10)
                        if not numericItemID then
                            APR:PrintError(L["Invalid item selection"])
                            return
                        end

                        local targetQuestID = tonumber(questID, 10) or AprRC:FindClosestIncompleteQuest()
                        AprRC:RecordUseItem(targetQuestID, numericItemID, function()
                            print("|cff00bfffUseItem|r " .. L["Added"])
                        end)
                        AceGUI:Release(frame)
                    end)
                end
            })
            return
        elseif inputText == "usespell" then
            local questList = AprRC.QuestObjectiveSelector:GetQuestList()
            if #questList == 0 then
                APR:PrintError(L["No quests available to bind UseSpell"])
                return
            end

            AprRC.QuestObjectiveSelector:Show({
                title = L["Use Spell quest list"],
                statusText = L["Click on an objective to select the quest for the UseSpell step"],
                questList = questList,
                onClick = function(questID, objectiveID)
                    AprRC.autocomplete:ShowSpellAutoComplete(questID, objectiveID, function(_, spellID, frame)
                        local numericSpellID = tonumber(spellID, 10)
                        if not numericSpellID then
                            APR:PrintError(L["Invalid spell selection"])
                            return
                        end

                        local targetQuestID = tonumber(questID, 10) or AprRC:FindClosestIncompleteQuest()
                        local step = {
                            UseSpell = {
                                questID = targetQuestID,
                                spellID = numericSpellID,
                            }
                        }
                        AprRC:SetStepCoord(step)
                        AprRC:ApplyCampaignQuestFlag(step, targetQuestID)
                        AprRC:NewStep(step)

                        print("|cff00bfffUseSpell|r " .. L["Added"])
                        AceGUI:Release(frame)
                    end, true)
                end
            })
            return
        elseif inputText == "spelltrigger" then
            AprRC.autocomplete:ShowSpellAutoComplete(_, _, function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.SpellTrigger = tonumber(spellID, 10)
                print("|cff00bfff SpellTrigger |r " .. L["Added"])
                AceGUI:Release(frame)
            end)

            return
        elseif inputText == "pickupdb" then
            if AprRC:HasStepOption("PickUp") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["PickUp DB (QuestID) - Also add PickUp QuestID"],
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError(L["Invalid QuestID format"])
                            return
                        end
                        local currentStep = AprRC:GetLastStep()
                        if AprRC:HasStepOption("PickUpDB") then
                            tinsert(currentStep.PickUpDB, questID)
                        else
                            currentStep.PickUpDB = { questID }
                            for _, qID in pairs(currentStep.PickUp) do
                                tinsert(currentStep.PickUpDB, qID)
                            end
                        end
                        AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                        print("|cff00bfffPickUpDB - " .. questID .. "|r " .. L["Added"])
                    end)
            else
                APR:PrintError(L["Missing PickUp option on current step"])
            end
            return
        elseif inputText == "qpartdb" then
            if AprRC:HasStepOption("Qpart") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Qpart DB (QuestID) - Also add Qpart QuestID"],
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError(L["Invalid QuestID format"])
                            return
                        end
                        local currentStep = AprRC:GetLastStep()
                        if AprRC:HasStepOption("QpartDB") then
                            tinsert(currentStep.QpartDB, questID)
                        else
                            currentStep.QpartDB = { questID }

                            for qID, _ in pairs(currentStep.Qpart) do
                                tinsert(currentStep.QpartDB, qID)
                            end
                        end
                        AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                        print("|cff00bfffQpartDB - " .. questID .. "|r " .. L["Added"])
                    end)
            else
                APR:PrintError(L["Missing Qpart option on current step"])
            end
            return
        elseif inputText == "donedb" then
            if AprRC:HasStepOption("Done") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Done DB (QuestID) - Also add Done QuestID"],
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError(L["Invalid QuestID format"])
                            return
                        end
                        local currentStep = AprRC:GetLastStep()
                        if AprRC:HasStepOption("DoneDB") then
                            tinsert(currentStep.DoneDB, questID)
                        else
                            currentStep.DoneDB = { questID }
                            for _, qID in pairs(currentStep.Done) do
                                tinsert(currentStep.DoneDB, qID)
                            end
                        end
                        AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                        print("|cff00bfffDoneDB - " .. questID .. "|r " .. L["Added"])
                    end)
            else
                APR:PrintError(L["Missing Done option on current step"])
            end
            return
        elseif inputText == "qpartpart" then
            AprRC.QuestObjectiveSelector:Show({
                title = L["Qpartpart quest list"],
                statusText = L["Click on an objective to create a Qpartpart "],
                questList = AprRC.QuestObjectiveSelector:GetQuestList(),
                onClick = function(questID, objectiveID)
                    local objectivesInfo = C_QuestLog.GetQuestObjectives(questID)
                    local objectiveInfo = objectivesInfo and objectivesInfo[objectiveID]
                    local defaultText = AprRC:GetQpartpartTrigTextProgress(questID, objectiveInfo)

                    -- Show the popup dialog with the default "x/y" value
                    AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Text Trigger for Qpart Part"], function(text)
                        local trimmedText = strtrim(text or "")
                        if trimmedText == "" then return end

                        local progressInfo = AprRC:GetObjectiveProgressInfo(questID, objectiveInfo)
                        if progressInfo and progressInfo.isPercent and not string.find(trimmedText, "%%", 1, true) then
                            if trimmedText:match("^%d+$") then
                                trimmedText = trimmedText .. "%"
                            end
                        elseif progressInfo and progressInfo.total and progressInfo.total > 0
                            and not string.find(trimmedText, "/", 1, true)
                            and not string.find(trimmedText, "%%", 1, true)
                            and trimmedText:match("^%d+$") then
                            -- Auto-append "/total" for count objectives when only a number is entered.
                            trimmedText = trimmedText .. "/" .. tostring(progressInfo.total)
                        end

                        -- Create the step and insert into the route
                        local step = {
                            TrigText = trimmedText,
                            QpartPart = { [questID] = { objectiveID } }
                        }
                        AprRC:SetStepCoord(step)
                        AprRC:ApplyCampaignQuestFlag(step, questID)
                        AprRC:NewStep(step)

                        print("|cff00bfffQpartPart - [" ..
                            C_QuestLog.GetTitleForQuestID(questID) .. "] - " .. objectiveID .. "|r " .. L["Added"])
                        print("|cff00bfffTrigText - " .. trimmedText .. "|r " .. L["Added"])
                    end, defaultText)
                end

            })
            return
        elseif inputText == "scenario" or inputText == "scenariotrig" then
            local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
            local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
            if not scenarioInfo or not scenarioInfo.scenarioID or not stepInfo then
                APR:PrintError(L["No active scenario found"])
                return
            end

            local scenarioObjectives = AprRC:BuildScenarioObjectiveList(stepInfo)
            if #scenarioObjectives == 0 then
                APR:PrintError(L["No scenario criteria available"])
                return
            end

            local scenarioTitle = tostring(scenarioInfo.name or scenarioInfo.scenarioID)
            AprRC.QuestObjectiveSelector:Show({
                title = L["Scenario objectives"],
                statusText = L["Select a scenario objective to add"],
                questList = {
                    {
                        title = L["FIELD_Scenario"] .. " - " .. scenarioTitle,
                        questID = scenarioInfo.scenarioID,
                        objectives = scenarioObjectives,
                    }
                },
                onClick = function(_, objectiveID)
                    local selectedObjective
                    for _, objective in ipairs(scenarioObjectives) do
                        if objective.objectiveID == objectiveID then
                            selectedObjective = objective
                            break
                        end
                    end

                    if not selectedObjective or not selectedObjective.criteriaID then
                        APR:PrintError(L["Invalid scenario objective selected"])
                        return
                    end

                    local selectedCriteria = selectedObjective.criteria
                    if not selectedCriteria then
                        selectedCriteria = C_ScenarioInfo.GetCriteriaInfoByStep(stepInfo.stepID,
                            selectedObjective.criteriaIndex)
                    end

                    local defaultText = AprRC:GetScenarioDefaultTrigText(selectedCriteria)
                    AprRC.questionDialog:CreateEditBoxPopupWithCallback(L["Text Trigger for Scenario"], function(text)
                        local trimmedText = strtrim(text or "")
                        if trimmedText == "" then return end

                        local progressInfo = AprRC:GetScenarioProgressInfo(selectedCriteria)
                        local totalText = progressInfo and progressInfo.total and tostring(progressInfo.total) or nil
                        if totalText and not string.find(trimmedText, "/", 1, true)
                            and not string.find(trimmedText, "%%", 1, true)
                            and trimmedText:match("^%d+$") then
                            trimmedText = trimmedText .. "/" .. totalText
                        end

                        local scenarioQuestID = AprRC:FindClosestIncompleteQuest()
                        local step = {
                            TrigText = trimmedText,
                            Scenario = {
                                scenarioID = scenarioInfo.scenarioID,
                                stepID = stepInfo.stepID,
                                criteriaID = selectedObjective.criteriaID,
                                criteriaIndex = selectedObjective.criteriaIndex,
                                questID = scenarioQuestID,
                            }
                        }
                        if AprRC:IsInInstanceQuest() then
                            step.InstanceQuest = true
                        end

                        AprRC:SetStepCoord(step, 5)
                        AprRC:ApplyCampaignQuestFlag(step, scenarioQuestID)
                        AprRC:NewStep(step)

                        print("|cff00bfffScenario - [" .. scenarioTitle .. "]|r " .. L["Added"])
                        print("|cff00bfffTrigText - " .. trimmedText .. "|r " .. L["Added"])
                    end, defaultText)
                end
            })
            return
        elseif inputText == "zonetrigger" then
            local currentStep = AprRC:GetLastStep()
            local y, x = UnitPosition("player")
            if x and y then
                x = tonumber(string.format("%.2f", x))
                y = tonumber(string.format("%.2f", y))
                currentStep.ZoneStepTrigger = { x = x, y = y, Range = 15 }
                print("|cff00bfffZoneStepTrigger|r " .. L["Added"])
            end
            return
        elseif inputText == "faction" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Faction = UnitFactionGroup("player")
            print("|cff00bfffFaction - " .. UnitFactionGroup("player") .. "|r " .. L["Added"])
            return
        elseif inputText == "race" then
            local currentStep = AprRC:GetLastStep()
            local race = select(2, UnitRace("player"))
            currentStep.Race = { race }
            print("|cff00bfffRace - " .. race .. "|r " .. L["Added"])
            return
        elseif inputText == "gender" then
            local currentStep = AprRC:GetLastStep()
            local sex = UnitSex("player")
            currentStep.Gender = sex
            print("|cff00bfffGender - " .. sex .. "|r " .. L["Added"])
            return
        elseif inputText == "class" then
            local currentStep = AprRC:GetLastStep()
            local class = select(2, UnitClass("player"))
            currentStep.Class = { class }
            print("|cff00bfffClass - " .. class .. "|r " .. L["Added"])
            return
        elseif inputText == "achievement" then
            AprRC.autocomplete:ShowAchievementAutoComplete(function(name, achievementID, frame)
                local currentStep = AprRC:GetLastStep()
                currentStep.HasAchievement = tonumber(achievementID, 10)
                print("|cff00bfffHasAchievement - " .. name .. "|r " .. L["Added"])

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "noachievement" then
            AprRC.autocomplete:ShowAchievementAutoComplete(function(name, achievementID, frame)
                local currentStep = AprRC:GetLastStep()
                currentStep.DontHaveAchievement = tonumber(achievementID, 10)
                print("|cff00bfffDontHaveAchievement - " .. name .. "|r " .. L["Added"])

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "save" then
            if AprRCData.CurrentRoute.name ~= "" then
                local step = { RouteCompleted = true }
                AprRC:NewStep(step)
                -- //TODO: Open Edit box with this route then reset currentRoute
                AprRC.settings.profile.recordBarFrame.isRecording = false
                AprRC.record:StopRecord()
                -- AprRCData.CurrentRoute = { name = "", steps = { {} } }
                print("|cff00bfff RouteCompleted |r " .. L["Added"])
            else
                APR:PrintError(L["You current route is empty"])
            end
            return
        end
    end

    -- Default
    AprRC.settings:OpenSettings(AprRC.title)
end
