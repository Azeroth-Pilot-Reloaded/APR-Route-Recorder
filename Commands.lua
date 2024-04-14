local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.command = AprRC:NewModule("Command")

local function CanDoCommand()
    if not AprRC.settings.profile.enableAddon then
        print("The addon is disabled")
        return false
    elseif not AprRC.settings.profile.recordBarFrame.isRecording then
        print("You're not recording a route")
        return false
    end
    return true
end
function AprRC.command:SlashCmd(input)
    local inputText = string.lower(input)
    if CanDoCommand() then
        if inputText == "waypoint" then
            local step = {
                Waypoint = AprRC:FindClosestIncompleteQuest() or 1,
                Range = 5,
            }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
            return
        elseif inputText == "range" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Range (number)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.Range = tonumber(text, 10)
            end)
            return
        elseif inputText == "eta" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("ETA (second)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.ETA =
                    tonumber(text, 10)
            end)
            return
        elseif inputText == "grind" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Grind (lvl)", function(text)
                local step = {}
                step.Grind = tonumber(text, 10)
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end)
            return
        elseif inputText == "noarrow" then
            local currentStep = AprRC:GetLastStep()
            currentStep.NoArrow = 1
            -- remove useless coord for NoArrow
            currentStep.Coord = nil
            currentStep.Range = nil
            return
        elseif inputText == "text" or inputText == "txt" then
            AprRC.autocomplete:Show()
            return
        elseif inputText == "button" or inputText == "btn" then
            AprRC.SelectButton:Show()
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
                end)
            else
                print('Missing PickUp option on current step')
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
                end)
            else
                print('Missing Qpart option on current step')
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
                end)
            else
                print('Missing Done option on current step')
            end
            return
        elseif inputText == "qpartpart" then
        elseif inputText == "zonetrigger" then
            local currentStep = AprRC:GetLastStep()
            local y, x = UnitPosition("player")
            if x and y then
                currentStep.ZoneStepTrigger = { x = x, y = y, Range = 15 }
            end
            return
        elseif inputText == "faction" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Faction = UnitFactionGroup("player")
            return
        elseif inputText == "race" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Race = select(2, UnitRace("player"))
            return
        elseif inputText == "gender" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Gender = UnitSex("player")
            return
        elseif inputText == "class" then
            local currentStep = AprRC:GetLastStep()
            currentStep.Class = select(2, UnitClass("player"))
            return
        elseif inputText == "achievement" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Has Achievement (ID)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.HasAchievement = tonumber(text, 10)
            end)
            return
        elseif inputText == "noachievement" then
            AprRC.questionDialog:CreateEditBoxPopupWithCallback("Dont Have Achievement (ID)", function(text)
                local currentStep = AprRC:GetLastStep()
                currentStep.DontHaveAchievement = tonumber(text, 10)
            end)
            return
        elseif inputText == "save" then
            if AprRCData.CurrentRoute.name ~= "" then
                local step = { ZoneDoneSave = 1 }
                AprRC:NewStep(step)
                -- //TODO: Open Edit box with this route then reset currentRoute
                AprRC.settings.profile.recordBarFrame.isRecording = false
                AprRC.record:StopRecord()
                -- AprRCData.CurrentRoute = { name = "", steps = { {} } }
            else
                print('You current route is empty')
            end
            return
        end
    end
    if inputText == "export" then
        APR.RouteQuestStepList[AprRCData.CurrentRoute.name] = AprRCData.CurrentRoute.steps
        APR.RouteList.Custom[AprRCData.CurrentRoute.name] = AprRCData.CurrentRoute.name:match("%d+-(.*)")
        AprRC.export.Show()
    elseif inputText == "help" or inputText == "h" then
        print(L_APR["COMMAND_LIST"] .. ":")
        print("|cffeda55f/aprrc help, h |r- " .. L_APR["HELP_COMMAND"])
        print("|cffeda55f/aprrc range |r- " .. "RANGE")
        print("|cffeda55f/aprrc waypoint |r- " .. "Waypoint")
        print("|cffeda55f/aprrc pickupdb |r- " .. "PickUpDB")
        print("|cffeda55f/aprrc qpartdb |r- " .. "QpartDB")
        print("|cffeda55f/aprrc qpartpart |r- " .. "QpartPart")
        print("|cffeda55f/aprrc donedb |r- " .. "DoneDB")
        print("|cffeda55f/aprrc text, txt |r- " .. "ExtraLineText")
        print("|cffeda55f/aprrc zonetrigger |r- " .. "ZoneStepTrigger")
        print("|cffeda55f/aprrc eta |r- " .. "ETA")
        print("|cffeda55f/aprrc noarrow |r- " .. "NoArrow")
        print("|cffeda55f/aprrc faction |r- " .. "Faction")
        print("|cffeda55f/aprrc race |r- " .. "Race")
        print("|cffeda55f/aprrc gender |r- " .. "Gender")
        print("|cffeda55f/aprrc class |r- " .. "Class")
        print("|cffeda55f/aprrc grind |r- " .. "Grind")
        print("|cffeda55f/aprrc spelltrigger |r- " .. "SpellTrigger")
        print("|cffeda55f/aprrc button, btn |r- " .. "Button")
        print("|cffeda55f/aprrc achievement |r- " .. "HasAchievement")
        print("|cffeda55f/aprrc noachievement |r- " .. "DontHaveAchievement")
    else
        AprRC.settings:OpenSettings(AprRC.title)
    end
end
