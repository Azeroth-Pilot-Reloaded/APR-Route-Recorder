local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")
local AceGUI = LibStub("AceGUI-3.0")

AprRC.command = AprRC:NewModule("Command")

local function CanDoCommand()
    if not AprRC.settings.profile.enableAddon then
        APR:PrintError("The addon is disabled")
        return false
    elseif not AprRC.settings.profile.recordBarFrame.isRecording then
        APR:PrintError("You're not recording a route")
        return false
    end
    return true
end
function AprRC.command:SlashCmd(input)
    local inputText = string.lower(input)
    local questCheckCommands = {
        iscompleted = {
            key = "IsQuestsCompletedOnAccount",
            prompt = "Is Quest Completed On Account (QuestID number)",
            message = "IsQuestsCompletedOnAccount",
        },
        isuncompleted = {
            key = "IsQuestsUncompletedOnAccount",
            prompt = "Is Quest Uncompleted On Account (QuestID number)",
            message = "IsQuestsUncompletedOnAccount",
        },
        isoneofquestscompleted = {
            key = "IsOneOfQuestsCompleted",
            prompt = "Is One Of Quests Completed (QuestID number)",
            message = "IsOneOfQuestsCompleted",
        },
        isoneofquestsuncompleted = {
            key = "IsOneOfQuestsUncompleted",
            prompt = "Is One Of Quests Uncompleted (QuestID number)",
            message = "IsOneOfQuestsUncompleted",
        },
        isoneofquestscompletedonaccount = {
            key = "IsOneOfQuestsCompletedOnAccount",
            prompt = "Is One Of Quests Completed On Account (QuestID number)",
            message = "IsOneOfQuestsCompletedOnAccount",
        },
        isoneofquestsuncompletedonaccount = {
            key = "IsOneOfQuestsUncompletedOnAccount",
            prompt = "Is One Of Quests Uncompleted On Account (QuestID number)",
            message = "IsOneOfQuestsUncompletedOnAccount",
        },
        isquestscompleted = {
            key = "IsQuestsCompleted",
            prompt = "Is Quests Completed (QuestID number)",
            message = "IsQuestsCompleted",
        },
        isquestsuncompleted = {
            key = "IsQuestsUncompleted",
            prompt = "Is Quests Uncompleted (QuestID number)",
            message = "IsQuestsUncompleted",
        },
    }
    if inputText == "export" then
        if AprRCData.CurrentRoute.name ~= "" then
            AprRC:UpdateRouteByName(AprRCData.CurrentRoute.name, AprRCData.CurrentRoute)
        end
        AprRC.export:Hide()
        AprRC.export.Show()
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
    elseif inputText == "help" or inputText == "h" then
        print(L_APR["COMMAND_LIST"] .. ":")
        print("|cffeda55f/aprrc achievement |r- " .. "HasAchievement")
        print("|cffeda55f/aprrc addjob |r- " .. "LearnProfession")
        print("|cffeda55f/aprrc addreset |r- " .. "ResetRoute")
        print("|cffeda55f/aprrc adventuremap |r- " .. "IsAdventureMapVisible")
        print("|cffeda55f/aprrc aura |r- " .. "HasAura")
        print("|cffeda55f/aprrc button, btn |r- " .. "Button")
        print("|cffeda55f/aprrc buffs |r- " .. "Buffs")
        print("|cffeda55f/aprrc class |r- " .. "Class")
        print("|cffeda55f/aprrc coord |r- " .. "Coord")
        print("|cffeda55f/aprrc coordframe |r- " .. "Coord Frame")
        print("|cffeda55f/aprrc donedb |r- " .. "DoneDB")
        print("|cffeda55f/aprrc eta |r- " .. "ETA")
        print("|cffeda55f/aprrc gossipeta |r- " .. "GossipETA")
        print("|cffeda55f/aprrc specialetahide |r- " .. "SpecialETAHide")
        print("|cffeda55f/aprrc export |r- " .. "To export data")
        print("|cffeda55f/aprrc faction |r- " .. "Faction")
        print("|cffeda55f/aprrc fillers, filler |r- " .. "Fillers")
        print("|cffeda55f/aprrc forcereset |r- " .. "Clear the Saved Variables")
        print("|cffeda55f/aprrc gender |r- " .. "Gender")
        print("|cffeda55f/aprrc grind |r- " .. "Grind")
        print("|cffeda55f/aprrc help, h |r- " .. L_APR["HELP_COMMAND"])
        print("|cffeda55f/aprrc instance |r- " .. "InstanceQuest")
        print("|cffeda55f/aprrc isCompleted |r- " .. "IsQuestsCompletedOnAccount")
        print("|cffeda55f/aprrc isQuestsCompleted |r- " .. "IsQuestsCompleted")
        print("|cffeda55f/aprrc isOneOfQuestsCompleted |r- " .. "IsOneOfQuestsCompleted")
        print("|cffeda55f/aprrc isOneOfQuestsCompletedOnAccount |r- " .. "IsOneOfQuestsCompletedOnAccount")
        print("|cffeda55f/aprrc isUncompleted |r- " .. "IsQuestsUncompletedOnAccount")
        print("|cffeda55f/aprrc isQuestsUncompleted |r- " .. "IsQuestsUncompleted")
        print("|cffeda55f/aprrc isOneOfQuestsUncompleted |r- " .. "IsOneOfQuestsUncompleted")
        print("|cffeda55f/aprrc isOneOfQuestsUncompletedOnAccount |r- " .. "IsOneOfQuestsUncompletedOnAccount")
        print("|cffeda55f/aprrc LootItems, lt |r- " .. "LootItems")
        print("|cffeda55f/aprrc noachievement |r- " .. "DontHaveAchievement")
        print("|cffeda55f/aprrc noarrow |r- " .. "NoArrow")
        print("|cffeda55f/aprrc noautoflightmap |r- " .. "NoAutoFlightMap")
        print("|cffeda55f/aprrc denynpc |r- " .. "DenyNPC")
        print("|cffeda55f/aprrc noaura |r- " .. "DontHaveAura")
        print("|cffeda55f/aprrc notskipvid, nsv |r- " .. "Dontskipvid")
        print("|cffeda55f/aprrc pickupdb |r- " .. "PickUpDB")
        print("|cffeda55f/aprrc qpartdb |r- " .. "QpartDB")
        print("|cffeda55f/aprrc qpartpart |r- " .. "QpartPart")
        print("|cffeda55f/aprrc race |r- " .. "Race")
        print("|cffeda55f/aprrc range |r- " .. "Range")
        print("|cffeda55f/aprrc spell |r- " .. "HasSpell")
        print("|cffeda55f/aprrc spelltrigger |r- " .. "SpellTrigger")
        print("|cffeda55f/aprrc text, txt |r- " .. "ExtraLineText")
        print("|cffeda55f/aprrc useitem |r- " .. "UseItem")
        print("|cffeda55f/aprrc usespell |r- " .. "UseSpell")
        print("|cffeda55f/aprrc vehicle |r- " .. "VehicleExit")
        print("|cffeda55f/aprrc mountvehicle |r- " .. "MountVehicle")
        print("|cffeda55f/aprrc warmode |r- " .. "WarMode")
        print("|cffeda55f/aprrc waypoint |r- " .. "Waypoint")
        print("|cffeda55f/aprrc nonskippablewaypoint |r- " .. "NonSkippableWaypoint")
        print("|cffeda55f/aprrc zonetrigger |r- " .. "ZoneStepTrigger")
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
            print("|cff00bfffWaypoint|r Added")
            return
        elseif inputText == "waypointdb" then
            if AprRC:HasStepOption("Waypoint") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Waypoint DB (QuestID) - Also add Waypoint QuestID",
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError("Invalid QuestID format")
                            return
                        end
                        local currentStep = AprRC:GetLastStep()
                        if AprRC:HasStepOption("WaypointDB") then
                            tinsert(currentStep.WaypointDB, questID)
                        else
                            currentStep.WaypointDB = { currentStep.Waypoint, questID }
                        end
                        AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                        print("|cff00bfffWaypointDB - " .. questID .. "|r Added")
                    end)
            else
                APR:PrintError('Missing Waypoint option on current step')
            end
            return
        elseif inputText == "nonskippablewaypoint" then
            if not AprRC:HasStepOption("Waypoint") then
                APR:PrintError('Missing Waypoint option on current step')
                return
            end

            local currentStep = AprRC:GetLastStep()
            if currentStep.NonSkippableWaypoint then
                APR:PrintError("|cff00bfffNonSkippableWaypoint|r already exist on this step")
                return
            end

            currentStep.NonSkippableWaypoint = true
            print("|cff00bfffNonSkippableWaypoint|r Added")
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
            currentStep.IsAdventureMapVisible = true
            print("|cff00bfffIsAdventureMapVisible|r Added")
            return
        elseif inputText == "aura" then
            AprRC.autocomplete:ShowAuraAutoComplete(function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.HasAura = tonumber(spellID, 10)
                print("|cff00bfff HasAura |r Added")
                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "noaura" then
            AprRC.autocomplete:ShowAuraAutoComplete(function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.DontHaveAura = tonumber(spellID, 10)
                print("|cff00bfff DontHaveAura |r Added")
                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "coord" then
            local currentStep = AprRC:GetLastStep()
            AprRC:SetStepCoord(currentStep, currentStep.Range)
            currentStep.NoArrow = nil -- remove NoArrow
            print("|cff00bfffCoord|r Added")
            return
        elseif inputText == "range" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Range (number)", function(text)
                local rangeValue = AprRC:ParsePositiveNumber(text)
                if not rangeValue then
                    APR:PrintError("Invalid range value")
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.Range = rangeValue
                print("|cff00bfffRange|r Added")
            end)
            return
        elseif inputText == "eta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("ETA (second)", function(text)
                local etaValue = AprRC:ParsePositiveInteger(text)
                if not etaValue then
                    APR:PrintError("Invalid ETA value")
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.ETA = etaValue
                print("|cff00bfffETA|r Added")
            end)
            return
        elseif inputText == "gossipeta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Gossip ETA (second)", function(text)
                local gossipEtaValue = AprRC:ParsePositiveInteger(text)
                if not gossipEtaValue then
                    APR:PrintError("Invalid Gossip ETA value")
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep.GossipETA = gossipEtaValue
                print("|cff00bfffGossipETA|r Added")
            end)
            return
        elseif inputText == "specialetahide" then
            if not AprRC:HasStepOption("SpecialETAHide") then
                local currentStep = AprRC:GetLastStep()
                currentStep.SpecialETAHide = true
                print("|cff00bfffSpecialETAHide|r Added")
            else
                APR:PrintError("|cff00bfffSpecialETAHide|r already exist on this step")
            end
            return
        elseif inputText == "grind" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Grind (lvl)", function(text)
                local grindLevel = AprRC:ParsePositiveInteger(text)
                if not grindLevel then
                    APR:PrintError("Invalid Grind level")
                    return
                end
                local step = {}
                step.Grind = grindLevel
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
                print("|cff00bfffGrind|r Added")
            end)
            return
        elseif inputText == "instance" then
            local currentStep = AprRC:GetLastStep()
            currentStep.InstanceQuest = true
            print("|cff00bfffInstanceQuest|r Added")
            return
        elseif questCheckCommands[inputText] then
            local config = questCheckCommands[inputText]
            AprRC.questionDialog:CreateEditBoxPopupWithCallback(config.prompt, function(text)
                local questIDs = AprRC:ParseQuestIDs(text)
                if not questIDs then
                    APR:PrintError("Invalid QuestID list")
                    return
                end
                local currentStep = AprRC:GetLastStep()
                currentStep[config.key] = questIDs
                print("|cff00bfff" ..
                    config.message .. " - { " .. table.concat(questIDs, ", ") .. " }|r Added")
            end)
            return
        elseif inputText == "lootitems" or inputText == "lt" then
            AprRC.autocomplete:ShowItemAutoComplete(nil, nil, function(_, itemID, frame)
                local numericItemID = tonumber(itemID, 10)
                if not numericItemID then
                    APR:PrintError("Invalid item selection")
                    return
                end

                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Loot items quantity (number)", function(text)
                    local quantity = AprRC:ParsePositiveInteger(text)
                    if not quantity or quantity < 1 then
                        APR:PrintError("Invalid quantity")
                        return
                    end

                    local currentStep = AprRC:GetLastStep()

                    if currentStep and currentStep.LootItems then
                        table.insert(currentStep.LootItems, {
                            itemID = numericItemID,
                            quantity = quantity
                        })

                        print("|cff00bfffLootItems|r updated (added item)")
                    else
                        local step = {
                            LootItems = {
                                {
                                    itemID = numericItemID,
                                    quantity = quantity
                                }
                            }
                        }

                        AprRC:SetStepCoord(step)
                        AprRC:NewStep(step)

                        print("|cff00bfffLootItems|r Added")
                    end
                end, "1")

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "notskipvid" or inputText == "nsv" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Dontskipvid = true
            print("|cff00bfffDontskipvid|r Added")
            return
        elseif inputText == "noarrow" then
            local currentStep = AprRC:GetLastStep()
            currentStep.NoArrow = true
            -- remove useless coord for NoArrow
            currentStep.Coord = nil
            currentStep.Range = nil
            print("|cff00bfffNoArrow|r Added")
            return
        elseif inputText == "noautoflightmap" then
            if not AprRC:HasStepOption("NoAutoFlightMap") then
                local currentStep = AprRC:GetLastStep()
                currentStep.NoAutoFlightMap = true
                print("|cff00bfffNoAutoFlightMap|r Added")
            end
            return
        elseif inputText == "denynpc" then
            local targetId = APR and APR.GetTargetID and APR:GetTargetID()
            if not targetId then
                APR:PrintError("No target selected to add DenyNPC")
                return
            end

            local numericTargetId = tonumber(targetId, 10)
            if not numericTargetId then
                APR:PrintError("Invalid target selection for DenyNPC")
                return
            end

            local currentStep = AprRC:GetLastStep()
            currentStep.DenyNPC = numericTargetId
            print("|cff00bfffDenyNPC - " .. numericTargetId .. "|r Added")
            return
        elseif inputText == "buffs" then
            AprRC.autocomplete:ShowBuffSelector(function(buffData)
                if not buffData then
                    return
                end
                local addedBuff = AprRC:AddBuffToStep(buffData.spellId, buffData.tooltipMessage)
                if addedBuff then
                    print(string.format("|cff00bfffBuffs|r Added - spellId: %d, tooltipMessage: %s",
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
                title = "Fillers quest list",
                statusText = "Click on an objective to add it as a filler",
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
                        print("|cffff0000This objective is already present in the fillers for this quest.|r")
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
                        C_QuestLog.GetTitleForQuestID(questID) .. "] - " .. objectiveID .. "|r Added")
                end
            })
            return
        elseif inputText == "spell" then
            AprRC.autocomplete:ShowSpellAutoComplete(_, _, function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.HasSpell = tonumber(spellID, 10)
                print("|cff00bfff HasSpell |r Added")
                AceGUI:Release(frame)
            end, true)
            return
        elseif inputText == "useitem" then
            local questList = AprRC.QuestObjectiveSelector:GetQuestList()
            if #questList == 0 then
                APR:PrintError("No quests available to bind UseItem")
                return
            end

            AprRC.QuestObjectiveSelector:Show({
                title = "Use Item quest list",
                statusText = "Click on an objective to select the quest for the UseItem step",
                questList = questList,
                onClick = function(questID)
                    AprRC.autocomplete:ShowItemAutoComplete(questID, nil, function(_, itemID, frame)
                        local numericItemID = tonumber(itemID, 10)
                        if not numericItemID then
                            APR:PrintError("Invalid item selection")
                            return
                        end

                        local targetQuestID = tonumber(questID, 10) or AprRC:FindClosestIncompleteQuest()
                        local _, itemSpellID = C_Item.GetItemSpell(numericItemID)
                        local step = {
                            UseItem = {
                                itemID = numericItemID,
                                itemSpellID = itemSpellID or 0,
                                questID = targetQuestID,
                            }
                        }
                        AprRC:SetStepCoord(step)
                        AprRC:ApplyCampaignQuestFlag(step, targetQuestID)
                        AprRC:NewStep(step)

                        print("|cff00bfffUseItem|r Added")
                        AceGUI:Release(frame)
                    end)
                end
            })
            return
        elseif inputText == "usespell" then
            local questList = AprRC.QuestObjectiveSelector:GetQuestList()
            if #questList == 0 then
                APR:PrintError("No quests available to bind UseSpell")
                return
            end

            AprRC.QuestObjectiveSelector:Show({
                title = "Use Spell quest list",
                statusText = "Click on an objective to select the quest for the UseSpell step",
                questList = questList,
                onClick = function(questID, objectiveID)
                    AprRC.autocomplete:ShowSpellAutoComplete(questID, objectiveID, function(_, spellID, frame)
                        local numericSpellID = tonumber(spellID, 10)
                        if not numericSpellID then
                            APR:PrintError("Invalid spell selection")
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

                        print("|cff00bfffUseSpell|r Added")
                        AceGUI:Release(frame)
                    end, true)
                end
            })
            return
        elseif inputText == "spelltrigger" then
            AprRC.autocomplete:ShowSpellAutoComplete(_, _, function(_, spellID, frame)
                local currentStep = AprRC:GetLastStep()

                currentStep.SpellTrigger = tonumber(spellID, 10)
                print("|cff00bfff SpellTrigger |r Added")
                AceGUI:Release(frame)
            end)

            return
        elseif inputText == "pickupdb" then
            if AprRC:HasStepOption("PickUp") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("PickUp DB (QuestID) - Also add PickUp QuestID",
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError("Invalid QuestID format")
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
                        print("|cff00bfffPickUpDB - " .. questID .. "|r Added")
                    end)
            else
                APR:PrintError('Missing PickUp option on current step')
            end
            return
        elseif inputText == "qpartdb" then
            if AprRC:HasStepOption("Qpart") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Qpart DB (QuestID) - Also add Qpart QuestID",
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError("Invalid QuestID format")
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
                        print("|cff00bfffQpartDB - " .. questID .. "|r Added")
                    end)
            else
                APR:PrintError('Missing Qpart option on current step')
            end
            return
        elseif inputText == "donedb" then
            if AprRC:HasStepOption("Done") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Done DB (QuestID) - Also add Done QuestID",
                    function(text)
                        local questID = AprRC:ParseQuestID(text)
                        if not questID then
                            APR:PrintError("Invalid QuestID format")
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
                        print("|cff00bfffDoneDB - " .. questID .. "|r Added")
                    end)
            else
                APR:PrintError('Missing Done option on current step')
            end
            return
        elseif inputText == "qpartpart" then
            AprRC.QuestObjectiveSelector:Show({
                title = "Qpartpart quest list",
                statusText = "Click on an objective to create a Qpartpart ",
                questList = AprRC.QuestObjectiveSelector:GetQuestList(),
                onClick = function(questID, objectiveID)
                    local objectivesInfo = C_QuestLog.GetQuestObjectives(questID)
                    local objectiveInfo = objectivesInfo and objectivesInfo[objectiveID]
                    local defaultText = AprRC:GetQpartpartTrigTextProgress(questID, objectiveInfo)

                    -- Show the popup dialog with the default "x/y" value
                    AprRC.questionDialog:CreateEditBoxPopupWithCallback("Text Trigger for Qpart Part", function(text)
                        local trimmedText = strtrim(text or "")
                        if trimmedText == "" then return end

                        local progressPercent = AprRC:GetQuestProgressPercentRounded(questID, objectiveInfo)
                        if progressPercent and not string.find(trimmedText, "%%") then
                            if trimmedText:match("^%d+$") then
                                trimmedText = trimmedText .. "%"
                            end
                        elseif not string.find(trimmedText, "/", 1, true) and objectiveInfo then
                            -- Auto-append "/total" if not manually included
                            local total = tonumber(objectiveInfo.numRequired) or 0
                            if total > 0 then
                                trimmedText = trimmedText .. "/" .. total
                            end
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
                            C_QuestLog.GetTitleForQuestID(questID) .. "] - " .. objectiveID .. "|r Added")
                        print("|cff00bfffTrigText - " .. trimmedText .. "|r Added")
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
                print("|cff00bfffZoneStepTrigger|r Added")
            end
            return
        elseif inputText == "faction" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Faction = UnitFactionGroup("player")
            print("|cff00bfffFaction - " .. UnitFactionGroup("player") .. "|r Added")
            return
        elseif inputText == "race" then
            local currentStep = AprRC:GetLastStep()
            local race = select(2, UnitRace("player"))
            currentStep.Race = { race }
            print("|cff00bfffRace - " .. race .. "|r Added")
            return
        elseif inputText == "gender" then
            local currentStep = AprRC:GetLastStep()
            local sex = UnitSex("player")
            currentStep.Gender = sex
            print("|cff00bfffGender - " .. sex .. "|r Added")
            return
        elseif inputText == "class" then
            local currentStep = AprRC:GetLastStep()
            local class = select(2, UnitClass("player"))
            currentStep.Class = { class }
            print("|cff00bfffClass - " .. class .. "|r Added")
            return
        elseif inputText == "achievement" then
            AprRC.autocomplete:ShowAchievementAutoComplete(function(name, achievementID, frame)
                local currentStep = AprRC:GetLastStep()
                currentStep.HasAchievement = tonumber(achievementID, 10)
                print("|cff00bfffHasAchievement - " .. name .. "|r Added")

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "noachievement" then
            AprRC.autocomplete:ShowAchievementAutoComplete(function(name, achievementID, frame)
                local currentStep = AprRC:GetLastStep()
                currentStep.DontHaveAchievement = tonumber(achievementID, 10)
                print("|cff00bfffDontHaveAchievement - " .. name .. "|r Added")

                AceGUI:Release(frame)
            end)
            return
        elseif inputText == "vehicle" then
            if not AprRC:HasStepOption("VehicleExit") then
                local currentStep = AprRC:GetLastStep()
                currentStep.VehicleExit = true
                print("|cff00bfffDVehicleExit|r Added")
                return
            end
            APR:PrintError("|cff00bfffVehicleExit|r already exist on this step")
            return
        elseif inputText == "mountvehicle" then
            if not AprRC:HasStepOption("MountVehicle") then
                local currentStep = AprRC:GetLastStep()
                currentStep.MountVehicle = true
                print("|cff00bfffMountVehicle|r Added")
                return
            end
            APR:PrintError("|cff00bfffMountVehicle|r already exist on this step")
            return
        elseif inputText == "warmode" then
            if not AprRC:HasStepOption("WarMode") then
                local step = { WarMode = AprRC:FindClosestIncompleteQuest() }
                AprRC:ApplyCampaignQuestFlag(step, step.WarMode)
                AprRC:NewStep(step)
                print("|cff00bfffWarMode|r Added")
                return
            end
            APR:PrintError("|cff00bfffWarMode|r already exist on this step")
            return
        elseif inputText == "save" then
            if AprRCData.CurrentRoute.name ~= "" then
                local step = { RouteCompleted = true }
                AprRC:NewStep(step)
                -- //TODO: Open Edit box with this route then reset currentRoute
                AprRC.settings.profile.recordBarFrame.isRecording = false
                AprRC.record:StopRecord()
                -- AprRCData.CurrentRoute = { name = "", steps = { {} } }
                print("|cff00bfff RouteCompleted |r Added")
            else
                APR:PrintError('You current route is empty')
            end
            return
        end
    end

    -- Default
    AprRC.settings:OpenSettings(AprRC.title)
end
