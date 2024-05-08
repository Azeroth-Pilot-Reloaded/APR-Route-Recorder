local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.command = AprRC:NewModule("Command")

local function CanDoCommand()
    if not AprRC.settings.profile.enableAddon then
        AprRC:Error("The addon is disabled")
        return false
    elseif not AprRC.settings.profile.recordBarFrame.isRecording then
        AprRC:Error("You're not recording a route")
        return false
    end
    return true
end
function AprRC.command:SlashCmd(input)
    local inputText = string.lower(input)
    if inputText == "export" then
        if AprRCData.CurrentRoute.name ~= "" then
            AprRC:UpdateRouteByName(AprRCData.CurrentRoute.name, AprRCData.CurrentRoute)
        end
        APR.RouteQuestStepList[AprRCData.CurrentRoute.name] = AprRCData.CurrentRoute.steps
        APR.RouteList.Custom[AprRCData.CurrentRoute.name] = AprRCData.CurrentRoute.name:match("%d+-(.*)")
        AprRC.export.Show()
        return
    elseif inputText == "forcereset" or inputText == "fr" then
        AprRC:ResetData()
        return
    elseif inputText == "help" or inputText == "h" then
        print(L_APR["COMMAND_LIST"] .. ":")
        print("|cffeda55f/aprrc achievement |r- " .. "HasAchievement")
        print("|cffeda55f/aprrc addjob |r- " .. "LearnProfession")
        print("|cffeda55f/aprrc button, btn |r- " .. "Button")
        print("|cffeda55f/aprrc class |r- " .. "Class")
        print("|cffeda55f/aprrc donedb |r- " .. "DoneDB")
        print("|cffeda55f/aprrc eta |r- " .. "ETA")
        print("|cffeda55f/aprrc export |r- " .. "To export data")
        print("|cffeda55f/aprrc faction |r- " .. "Faction")
        print("|cffeda55f/aprrc fillers, filler |r- " .. "Fillers")
        print("|cffeda55f/aprrc forcereset, fr |r- " .. "Clear the Saved Variables")
        print("|cffeda55f/aprrc gender |r- " .. "Gender")
        print("|cffeda55f/aprrc grind |r- " .. "Grind")
        print("|cffeda55f/aprrc help, h |r- " .. L_APR["HELP_COMMAND"])
        print("|cffeda55f/aprrc instance |r- " .. "InstanceQuest")
        print("|cffeda55f/aprrc noachievement |r- " .. "DontHaveAchievement")
        print("|cffeda55f/aprrc noarrow |r- " .. "NoArrow")
        print("|cffeda55f/aprrc notskipvid, nsv |r- " .. "Dontskipvid")
        print("|cffeda55f/aprrc pickupdb |r- " .. "PickUpDB")
        print("|cffeda55f/aprrc qpartdb |r- " .. "QpartDB")
        print("|cffeda55f/aprrc qpartpart |r- " .. "QpartPart")
        print("|cffeda55f/aprrc race |r- " .. "Race")
        print("|cffeda55f/aprrc range |r- " .. "Range")
        print("|cffeda55f/aprrc spelltrigger |r- " .. "SpellTrigger")
        print("|cffeda55f/aprrc text, txt |r- " .. "ExtraLineText")
        print("|cffeda55f/aprrc vehicle |r- " .. "VehicleExit")
        print("|cffeda55f/aprrc warmode |r- " .. "WarMode")
        print("|cffeda55f/aprrc waypoint |r- " .. "Waypoint")
        print("|cffeda55f/aprrc zonetrigger |r- " .. "ZoneStepTrigger")
        return
    end
    if CanDoCommand() then
        if inputText == "waypoint" then
            local step = {
                Waypoint = AprRC:FindClosestIncompleteQuest(),
            }
            AprRC:SetStepCoord(step, 5)
            AprRC:NewStep(step)
            print("|cff00bfffWaypoint|r Added")
            return
        elseif inputText == "addjob" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Profession spellID", function(text)
                local step = {
                    LearnProfession = tonumber(text, 10)
                }
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
                print("|cff00bfffLearnProfession|r Added")
            end)
            return
        elseif inputText == "range" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Range (number)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.Range = tonumber(text, 10)
                print("|cff00bfffRange|r Added")
            end)
            return
        elseif inputText == "eta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("ETA (second)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.ETA = tonumber(text, 10)
                print("|cff00bfffETA|r Added")
            end)
            return
        elseif inputText == "grind" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Grind (lvl)", function(text)
                local step = {}
                step.Grind = tonumber(text, 10)
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
        elseif inputText == "notskipvid" or inputText == "nsv" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Dontskipvid = 1
            print("|cff00bfffDontskipvid|r Added")
            return
        elseif inputText == "noarrow" then
            local currentStep = AprRC:GetLastStep()
            currentStep.NoArrow = 1
            -- remove useless coord for NoArrow
            currentStep.Coord = nil
            currentStep.Range = nil
            print("|cff00bfffNoArrow|r Added")
            return
        elseif inputText == "text" or inputText == "txt" then
            AprRC.autocomplete:Show()
            return
        elseif inputText == "button" or inputText == "btn" then
            AprRC.SelectButton:Show()
            return
        elseif inputText == "fillers" or inputText == "filler" then
            AprRC.fillers:Show()
            return
        elseif inputText == "spelltrigger" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("SpellTrigger (Spell ID)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.SpellTrigger = tonumber(text, 10)
                print("|cff00bfffSpellTrigger -" .. tonumber(text, 10) .. "|r Added")
            end)
            return
        elseif inputText == "pickupdb" then
            if AprRC:HasStepOption("PickUp") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("PickUp DB (QuestID)", function(questId)
                    local currentStep = AprRC:GetLastStep()
                    if AprRC:HasStepOption("PickUpDB") then
                        tinsert(currentStep.PickUpDB, tonumber(questId, 10))
                    else
                        currentStep.PickUpDB = { tonumber(questId, 10) }
                        for _, qID in pairs(currentStep.PickUp) do
                            tinsert(currentStep.PickUpDB, qID)
                        end
                    end
                    print("|cff00bfffPickUpDB - " .. tonumber(questId, 10) .. "|r Added")
                end)
            else
                AprRC:Error('Missing PickUp option on current step')
            end
            return
        elseif inputText == "qpartdb" then
            if AprRC:HasStepOption("Qpart") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Qpart DB (QuestID)", function(questId)
                    local currentStep = AprRC:GetLastStep()
                    if AprRC:HasStepOption("QpartDB") then
                        tinsert(currentStep.QpartDB, tonumber(questId, 10))
                    else
                        currentStep.QpartDB = { tonumber(questId, 10) }

                        for qID, _ in pairs(currentStep.Qpart) do
                            tinsert(currentStep.QpartDB, qID)
                        end
                    end
                    print("|cff00bfffQpartDB - " .. tonumber(questId, 10) .. "|r Added")
                end)
            else
                AprRC:Error('Missing Qpart option on current step')
            end
            return
        elseif inputText == "donedb" then
            if AprRC:HasStepOption("Done") then
                AprRC.questionDialog:CreateEditBoxPopupWithCallback("Done DB (QuestID)", function(questId)
                    local currentStep = AprRC:GetLastStep()
                    if AprRC:HasStepOption("DoneDB") then
                        tinsert(currentStep.DoneDB, tonumber(questId, 10))
                    else
                        currentStep.DoneDB = { tonumber(questId, 10) }
                        for _, qID in pairs(currentStep.Done) do
                            tinsert(currentStep.DoneDB, qID)
                        end
                    end
                    print("|cff00bfffDoneDB - " .. tonumber(questId, 10) .. "|r Added")
                end)
            else
                AprRC:Error('Missing Done option on current step')
            end
            return
        elseif inputText == "qpartpart" then
        elseif inputText == "zonetrigger" then
            local currentStep = AprRC:GetLastStep()
            local y, x = UnitPosition("player")
            if x and y then
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
            currentStep.Race = select(2, UnitRace("player"))
            print("|cff00bfffRace - " .. select(2, UnitRace("player")) .. "|r Added")
            return
        elseif inputText == "gender" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Gender = UnitSex("player")
            print("|cff00bfffGender - " .. UnitSex("player") .. "|r Added")
            return
        elseif inputText == "class" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Class = select(2, UnitClass("player"))
            print("|cff00bfffClass - " .. select(2, UnitClass("player")) .. "|r Added")
            return
        elseif inputText == "achievement" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Has Achievement (ID)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.HasAchievement = tonumber(text, 10)
                print("|cff00bfffHasAchievement - " .. tonumber(text, 10) .. "|r Added")
            end)
            return
        elseif inputText == "noachievement" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Dont Have Achievement (ID)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.DontHaveAchievement = tonumber(text, 10)
                print("|cff00bfffDontHaveAchievement - " .. tonumber(text, 10) .. "|r Added")
            end)
            return
        elseif inputText == "vehicle" then
            if not AprRC:HasStepOption("VehicleExit") then
                local currentStep = AprRC:GetLastStep()
                currentStep["VehicleExit"] = 1
                print("|cff00bfffDVehicleExit|r Added")
                return
            end
            AprRC:Error("|cff00bfffVehicleExit|r already exist on this step")
            return
        elseif inputText == "warmode" then
            if not AprRC:HasStepOption("WarMode") then
                local step = { WarMode = AprRC:FindClosestIncompleteQuest() }
                AprRC:NewStep(step)
                print("|cff00bfffWarMode|r Added")
                return
            end
            AprRC:Error("|cff00bfffWarMode|r already exist on this step")
            return
        elseif inputText == "save" then
            if AprRCData.CurrentRoute.name ~= "" then
                local step = { ZoneDoneSave = 1 }
                AprRC:NewStep(step)
                -- //TODO: Open Edit box with this route then reset currentRoute
                AprRC.settings.profile.recordBarFrame.isRecording = false
                AprRC.record:StopRecord()
                -- AprRCData.CurrentRoute = { name = "", steps = { {} } }
                print("|cff00bfff ZoneDoneSave |r Added")
            else
                AprRC:Error('You current route is empty')
            end
            return
        end
    end

    -- Default
    AprRC.settings:OpenSettings(AprRC.title)
end
