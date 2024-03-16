local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.command = AprRC:NewModule("Command")

function AprRC.command:SlashCmd(input)
    if not AprRC.settings.profile.enableAddon then
        AprRC.settings:OpenSettings(AprRC.title)
    end
    if input == "waypoint" then
        local step = {
            Waypoint = AprRC:FindClosestIncompleteQuest(),
            Range = 5,
        }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    elseif input == "range" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Range (number)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.Range = tonumber(text, 10)
        end)
    elseif input == "eta" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("ETA (second)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.ETA = tonumber(text, 10)
        end)
    elseif input == "grind" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Grind (lvl)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.Grind = tonumber(text, 10)
        end)
    elseif input == "noarrow" then
        local currentStep = AprRC:GetLastStep()
        currentStep.NoArrow = 1
    elseif input == "text" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Extra Line Text", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.ExtraLineText = text
        end)
    elseif input == "pickupdb" then
    elseif input == "qpartdb" then
    elseif input == "donedb" then
    elseif input == "qpartpart" then
    elseif input == "zonetrigger" then
    elseif input == "faction" then
        local currentStep = AprRC:GetLastStep()
        currentStep.Faction = UnitFactionGroup("player")
    elseif input == "race" then
        local currentStep = AprRC:GetLastStep()
        currentStep.Race = select(2, UnitRace("player"))
    elseif input == "gender" then
        local currentStep = AprRC:GetLastStep()
        currentStep.Gender = UnitSex("player")
    elseif input == "class" then
        local currentStep = AprRC:GetLastStep()
        currentStep.Class = select(2, UnitClass("player"))
    elseif input == "achievement" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Has Achievement (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.HasAchievement = tonumber(text, 10)
        end)
    elseif input == "noachievement" then
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Dont Have Achievement (ID)", function(text)
            local currentStep = AprRC:GetLastStep()
            currentStep.DontHaveAchievement = tonumber(text, 10)
        end)
    elseif input == "help" or input == "h" then
        print(L["COMMAND_LIST"] .. ":")
        print("|cffeda55f/aprrc help, h |r- " .. L["HELP_COMMAND"])
        print("|cffeda55f/aprrc range |r- " .. "RANGE")
        print("|cffeda55f/aprrc waypoint |r- " .. "Waypoint")
        print("|cffeda55f/aprrc pickupdb |r- " .. "PickUpDB")
        print("|cffeda55f/aprrc qpartdb |r- " .. "QpartDB")
        print("|cffeda55f/aprrc qpartpart |r- " .. "QpartPart")
        print("|cffeda55f/aprrc donedb |r- " .. "DoneDB")
        print("|cffeda55f/aprrc text |r- " .. "ExtraLineText")
        print("|cffeda55f/aprrc zonetrigger |r- " .. "ZoneStepTrigger")
        print("|cffeda55f/aprrc eta |r- " .. "ETA")
        print("|cffeda55f/aprrc noarrow |r- " .. "NoArrow")
        print("|cffeda55f/aprrc faction |r- " .. "Faction")
        print("|cffeda55f/aprrc race |r- " .. "Race")
        print("|cffeda55f/aprrc gender |r- " .. "Gender")
        print("|cffeda55f/aprrc class |r- " .. "Class")
        print("|cffeda55f/aprrc grind |r- " .. "Grind")
        print("|cffeda55f/aprrc achievement |r- " .. "HasAchievement")
        print("|cffeda55f/aprrc noachievement |r- " .. "DontHaveAchievement")
    end


    AprRC.settings:OpenSettings(AprRC.title)
end
