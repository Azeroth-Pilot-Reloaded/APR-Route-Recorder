local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.event = AprRC:NewModule("AprRC-Event")

-- global event framePool for register
AprRC.event.framePool = {}
AprRC.event.functions = {}

local scenarioCriteriaLogged = {}
local achievementCriteriaLogged = {}
local lastWarModeDesired
local lastAdventureMapOpenAt = 0
local ADVENTURE_MAP_ACCEPT_WINDOW = 15


---------------------------------------------------------------------------------------
------------------------------------- EVENTS ------------------------------------------
---------------------------------------------------------------------------------------

local events = {
    load = "ADDON_LOADED",
    accept = "QUEST_ACCEPTED",
    remove = "QUEST_REMOVED",
    done = "QUEST_TURNED_IN",
    setHS = "HEARTHSTONE_BOUND",
    spell = "UNIT_SPELLCAST_SUCCEEDED",
    raidIcon = "RAID_TARGET_UPDATE",
    pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" },
    emote = "CHAT_MSG_TEXT_EMOTE",
    taxi = { "TAXIMAP_OPENED", "TAXIMAP_CLOSED" },
    fly = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" },
    qpart = "QUEST_WATCH_UPDATE",
    scenario = "SCENARIO_CRITERIA_UPDATE",
    adventureMapOpen = "ADVENTURE_MAP_OPEN",
    achievement = { "CRITERIA_EARNED", "ACHIEVEMENT_EARNED" },
    portal = { "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED" },
    learnProfession = "LEARNED_SPELL_IN_SKILL_LINE",
    warMode = "WAR_MODE_STATUS_UPDATE",
    vehicle = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" },
}

---------------------------------------------------------------------------------------
-------------------------------------- DATA -------------------------------------------
---------------------------------------------------------------------------------------


function AprRC.event:ResetTracking()
    scenarioCriteriaLogged, achievementCriteriaLogged = {}, {}
    lastAdventureMapOpenAt = 0
    lastWarModeDesired = C_PvP.IsWarModeDesired()
end

local function IsAdventureMapContextActive()
    if AdventureMapFrame and AdventureMapFrame.IsShown and AdventureMapFrame:IsShown() then
        return true
    end

    return lastAdventureMapOpenAt > 0 and (GetTime() - lastAdventureMapOpenAt) <= ADVENTURE_MAP_ACCEPT_WINDOW
end

local function MarkAdventureMapOnStep(step)
    if type(step) ~= "table" then
        return
    end

    if IsAdventureMapContextActive() then
        step.IsAdventureMap = true
        step.IsAdventureMapVisible = nil
    end
end

---------------------------------------------------------------------------------------
---------------------------------- Events register ------------------------------------
---------------------------------------------------------------------------------------

function AprRC.event:MyRegisterEvent()
    for tag, event in pairs(events) do
        local container = self.framePool[tag] or CreateFrame("Frame")
        self.framePool[tag] = container
        container.tag = tag
        container.callback = self.functions[tag]

        if type(event) == "string" then
            container:RegisterEvent(event)
            container:SetScript("OnEvent", self.EventHandler)
        elseif type(event) == "table" then
            for _, e in ipairs(event) do
                container:RegisterEvent(e)
                container:SetScript("OnEvent", self.EventHandler)
            end
        end
    end
end

function AprRC.event.EventHandler(self, event, ...)
    if not AprRC.settings.profile.enableAddon or not AprRC.settings.profile.recordBarFrame.isRecording then
        return
    end

    if self.callback and self.tag then
        AprRC:Debug("Callback Event", event)
        local ok, reason = pcall(self.callback, event, ...)
        if not ok then AprRC:Debug("Recording event failed: " .. event, reason) end
    else
        AprRC:Debug("Unregister Event", event)
        self.callback = nil
        self:UnregisterEvent(event)
    end
end

---------------------------------------------------------------------------------------
---------------------------------- Events always sub ----------------------------------
---------------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent(events.load)
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == events.load then
        local addOnName, containsBindings = ...
        if addOnName == "APR-Recorder" then
            if ExtraActionButton1 and not ExtraActionButton1.isHookedAprRC then
                ExtraActionButton1:HookScript("OnClick", function()
                    if not AprRC.settings.profile.enableAddon or not AprRC.settings.profile.recordBarFrame.isRecording then
                        return
                    end
                    local currentStep = AprRC:GetLastStep()
                    currentStep.ExtraActionB = true
                end)
                ExtraActionButton1.isHookedAprRC = true
            end
        end
    end
end)

---------------------------------------------------------------------------------------
------------------------------ Events Callback Functions ------------------------------
---------------------------------------------------------------------------------------

function AprRC.event.functions.accept(event, questId)
    -- Pickup
    local function AddQuestToStep(questId)
        if AprRC:HasStepOption("DroppableQuest") and AprRC:GetLastStep().DroppableQuest.Qid == questId then
            local currentStep = AprRC:GetLastStep()
            currentStep.DropQuest = questId
            currentStep.DroppableQuest.Qid = questId
            MarkAdventureMapOnStep(currentStep)
            AprRC:ApplyCampaignQuestFlag(currentStep, questId)
            AprRC:saveQuestInfo()
            return
        end
        if AprRC:HasStepOption("ChromiePick") then
            local currentStep = AprRC:GetLastStep()
            currentStep.PickUp = { questId }
            MarkAdventureMapOnStep(currentStep)
            AprRC:ApplyCampaignQuestFlag(currentStep, questId)
            AprRC:saveQuestInfo()
            return
        end
        if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("PickUp") then
            local currentStep = AprRC:GetLastStep()
            tinsert(currentStep.PickUp, questId)
            MarkAdventureMapOnStep(currentStep)
            AprRC:ApplyCampaignQuestFlag(currentStep, questId)
        else
            local step = { PickUp = { questId } }
            AprRC:SetStepCoord(step)
            MarkAdventureMapOnStep(step)
            AprRC:ApplyCampaignQuestFlag(step, questId)
            AprRC:NewStep(step)
        end
        -- update saved quest
        AprRC:saveQuestInfo()
    end
    if C_QuestLog.IsWorldQuest(questId) then
        APR.questionDialog:CreateQuestionPopup(
            "New world quest, do you want to add it?",
            "New world quest, do you want to add it?",
            function()
                AddQuestToStep(questId)
            end
        )
        return
    end

    AddQuestToStep(questId)
end

function AprRC.event.functions.adventureMapOpen(event)
    lastAdventureMapOpenAt = GetTime()
end

function AprRC.event.functions.remove(event, questId, ...)
    -- LeaveQuests
    if not C_QuestLog.IsQuestFlaggedCompleted(questId) and not C_QuestLog.IsWorldQuest(questId) then
        if AprRC:HasStepOption("LeaveQuests") then
            local currentStep = AprRC:GetLastStep()
            tinsert(currentStep.LeaveQuests, questId)
        else
            local step = { LeaveQuests = { questId } }
            step.Zone = AprRC:getZone()
            AprRC:NewStep(step)
        end
        --remove quest from state list
        AprRC.lastQuestState[questId] = nil
    end
end

function AprRC.event.functions.done(event, questId, ...)
    if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("Done") then
        local currentStep = AprRC:GetLastStep()
        tinsert(currentStep.Done, questId)
        AprRC:ApplyCampaignQuestFlag(currentStep, questId)
    else
        local step = { Done = { questId } }
        AprRC:SetStepCoord(step)
        AprRC:ApplyCampaignQuestFlag(step, questId)
        AprRC:NewStep(step)
    end
    --remove quest from state list
    AprRC.lastQuestState[questId] = nil
end

function AprRC.event.functions.raidIcon(...)
    if AprRC:IsInInstanceQuest() then
        return
    end

    local targetId = APR:GetTargetID()
    if targetId then
        local currentStep = AprRC:GetLastStep()
        currentStep.RaidIcon = targetId
    end
end

function AprRC.event.functions.setHS(...)
    local step = { SetHS = AprRC:FindClosestIncompleteQuest() }
    AprRC:SetStepCoord(step)
    AprRC:ApplyCampaignQuestFlag(step, step.SetHS)
    AprRC:NewStep(step)
end

function AprRC.event.functions.spell(event, unitTarget, castGUID, spellID)
    local key = nil
    if unitTarget == "player" then
        if spellID == APR.dalaHSSpellID then
            key = "UseDalaHS"
        elseif spellID == APR.garrisonHSSpellID then
            key = "UseGarrisonHS"
        elseif tContains(APR.hearthStoneSpellID, spellID) then
            key = "UseHS"
        elseif spellID == 126389 then
            local currentStep = AprRC:GetLastStep()
            currentStep.UseGlider = true
            return
        end

        if key then
            local step = {}
            step[key] = AprRC:FindClosestIncompleteQuest()
            step.Zone = AprRC:getZone()
            AprRC:ApplyCampaignQuestFlag(step, step[key])
            AprRC:NewStep(step)
        end
    end
end

function AprRC.event.functions.warMode(event, warModeEnabled)
    local desired = C_PvP.IsWarModeDesired()
    if desired and not lastWarModeDesired and not AprRC:HasStepOption("WarMode") then
        local step = { WarMode = AprRC:FindClosestIncompleteQuest() }
        AprRC:ApplyCampaignQuestFlag(step, step.WarMode)
        AprRC:NewStep(step)
    end
    lastWarModeDesired = desired
end

function AprRC.event.functions.vehicle(event, unit)
    if unit ~= "player" then return end
    if event == "UNIT_ENTERED_VEHICLE" and not AprRC:HasStepOption("MountVehicle") then
        local step = { MountVehicle = true }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    elseif event == "UNIT_EXITED_VEHICLE" and not AprRC:HasStepOption("VehicleExit") then
        AprRC:NewStep({ VehicleExit = true })
    end
end

function AprRC:RecordGossipOption(gossipOptionID)
    if not self:IsRecordingContext() or type(gossipOptionID) ~= "number" or gossipOptionID <= 0 then return end
    local step = self:GetLastStep()
    if self:IsCurrentStepFarAway() or not (step.Qpart or step.QpartPart or step.GossipOptionIDs or step.PickUp) then
        step = {}
        self:SetStepCoord(step)
        self:NewStep(step)
    end
    step.GossipOptionIDs = step.GossipOptionIDs or {}
    if not tContains(step.GossipOptionIDs, gossipOptionID) then
        table.insert(step.GossipOptionIDs, gossipOptionID)
    end
end

hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
    AprRC:RecordGossipOption(optionID)
end)

function AprRC.event.functions.emote(event, ...)
    local message, sender = ...
    if APR.Username == sender then
        local function getEmoteNpcID()
            local npcID = APR:GetTargetID("target")
            local numericNpcID = tonumber(npcID, 10)
            if not numericNpcID or UnitPlayerControlled("target") then
                return 0
            end
            return numericNpcID
        end

        local function getEmoteKey()
            for emoteKey, phrases in pairs(L.Emotes) do
                for _, phrase in ipairs(phrases) do
                    local placeholder = "\001"
                    local pattern = phrase:gsub("%%s", placeholder)
                    pattern = AprRC:EscapeLuaPattern(pattern)
                    pattern = pattern:gsub(placeholder, ".+")
                    pattern = "^" .. pattern .. "$" -- cast as regex
                    if string.match(message, pattern) then
                        return emoteKey
                    end
                end
            end
            return nil
        end

        local emote = getEmoteKey()
        if emote then
            local emoteData = {
                npcID = getEmoteNpcID(),
                emote = emote,
            }
            local currentStep = AprRC:GetLastStep()
            if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("Emote") then
                currentStep.Emote = emoteData
            else
                local step = { Emote = emoteData }
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end
        end
    end
end

function AprRC.event.functions.achievement(event, achievementID, description)
    if not achievementID or (issecretvalue and issecretvalue(achievementID)) then return end
    local data = { achievementID = achievementID }
    if event == "CRITERIA_EARNED" then
        if issecretvalue and issecretvalue(description) then return end
        local matches = {}
        for index = 1, GetAchievementNumCriteria(achievementID) do
            local info = { pcall(GetAchievementCriteriaInfo, achievementID, index) }
            -- pcall shifts the stable criteriaID (return #10) to #11.
            if info[1] and info[2] == description and type(info[11]) == "number" and info[11] > 0 then
                matches[#matches + 1] = info[11]
            end
        end
        -- Identical labels can describe different criteria: leave ambiguous cases to achievementstep.
        if #matches ~= 1 then return end
        data.criteriaID = matches[1]
    end
    local key = tostring(achievementID) .. "|" .. tostring(data.criteriaID or "whole")
    if achievementCriteriaLogged[key] then return end
    local step = { Achievement = data }
    AprRC:SetStepCoord(step, 1)
    AprRC:NewStep(step)
    achievementCriteriaLogged[key] = true
end

local pendingTaxiDiscovery
function AprRC.event.functions.taxi(event)
    if event == "TAXIMAP_CLOSED" then
        local step = {}
        AprRC:SetStepCoord(step)
        pendingTaxiDiscovery = { context = AprRC:CaptureRecordingContext(), step = step }
        return
    elseif event == "TAXIMAP_OPENED" then
        local taxiMapID = GetTaxiMapID()
        local taxiNodes = taxiMapID and C_TaxiMap.GetAllTaxiNodes(taxiMapID) or {}
        AprRC.CurrentTaxiNodes = taxiNodes
        AprRC.CurrentTaxiNode = nil
        for _, node in ipairs(taxiNodes) do
            if node.state == Enum.FlightPathState.Current then AprRC.CurrentTaxiNode = node end
        end
    end
    if pendingTaxiDiscovery and AprRC.CurrentTaxiNode then
        if AprRC:IsRecordingContext(pendingTaxiDiscovery.context) then
            local nodeID = AprRC.CurrentTaxiNode.nodeID
            if not AprRC:IsTaxiInLookup(nodeID) then
                pendingTaxiDiscovery.step.GetFP = nodeID
                AprRC:NewStep(pendingTaxiDiscovery.step)
                AprRCData.TaxiLookup[nodeID] = true
            end
        end
        pendingTaxiDiscovery = nil
    end
end

function AprRC.event.functions.fly(event)
    AprRC:RecordFlightControl(event)
end

function AprRC.event.functions.qpart(event, questID)
    local context = AprRC:CaptureRecordingContext()
    AprRC.lastQuestState = AprRC.lastQuestState or {}
    -- Save player position for right coord on qpart update
    local step = {}
    AprRC:SetStepCoord(step)

    local previousState = AprRC.lastQuestState[questID] or {}
    AprRC.lastQuestState[questID] = AprRC.lastQuestState[questID] or {}

    local function setButton(questID, index, step)
        -- itemID
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local link = GetQuestLogSpecialItemInfo(questLogIndex)
        if link then
            local itemID = AprRC:GetItemIDFromLink(link)
            if not step.Button then
                step.Button = {}
            end
            step.Button[questID .. "-" .. index] = tonumber(itemID)
        end
    end

    local function setQpart(lastFulfilled, objective, questID, index)
        local previousValue = lastFulfilled or 0
        local currentValue = objective.numFulfilled or 0
        if previousValue < currentValue then
            local currentStep = AprRC:GetLastStep()
            local hasAlreadyInStep = currentStep and currentStep.Qpart and currentStep.Qpart[questID] and
                tContains(currentStep.Qpart[questID], index)
            if hasAlreadyInStep or
                AprRC:IsQuestInLookup(questID, index) then
                AprRC.lastQuestState[questID][index] = { numFulfilled = currentValue }

                return true
            end

            local range = (objective.numRequired > 1 and (objective.type == "monster" or objective.type == "item")) and
                30 or
                5
            local function newStep()
                local objectiveStep = AprRC:CopyData(step)
                objectiveStep.Qpart = { [questID] = { index } }
                if AprRC:IsInInstanceQuest() then objectiveStep.InstanceQuest = true end
                setButton(questID, index, objectiveStep)
                AprRC:ApplyCampaignQuestFlag(objectiveStep, questID)
                objectiveStep.Range = range
                AprRC:NewStep(objectiveStep)
            end
            if not currentStep.Qpart and APR:HasAnyMainStepOption(currentStep) then
                newStep()
            else
                if not AprRC:IsCurrentStepFarAway() then
                    if not AprRC:HasStepOption("Qpart") then
                        currentStep.Qpart = {}
                        currentStep.Qpart[questID] = {}

                        if not AprRC:HasStepOption("Coord") then
                            currentStep.Coord = step.Coord
                            currentStep.Zone = step.Zone
                            currentStep.Range = range
                        end
                        if AprRC:IsInInstanceQuest() then
                            currentStep.InstanceQuest = true
                        end
                    elseif not currentStep.Qpart[questID] then
                        currentStep.Qpart[questID] = {}
                    end
                    tinsert(currentStep.Qpart[questID], index)
                    setButton(questID, index, currentStep)
                    AprRC:ApplyCampaignQuestFlag(currentStep, questID)
                else
                    newStep()
                end
            end

            AprRC:AddQuestToLookup(questID, index)
            AprRC.lastQuestState[questID][index] = { numFulfilled = currentValue }

            return true
        end

        AprRC.lastQuestState[questID][index] = { numFulfilled = currentValue }

        return false
    end

    local function processObjectives(stateSnapshot)
        local objectives = C_QuestLog.GetQuestObjectives(questID)
        if not objectives then
            return false
        end

        local hasUpdate = false
        for index, objective in ipairs(objectives) do
            local lastState = stateSnapshot[index] and stateSnapshot[index].numFulfilled
            if setQpart(lastState, objective, questID, index) then
                hasUpdate = true
            end
        end
        return hasUpdate
    end

    local function retryProcess(attemptsLeft)
        if attemptsLeft <= 0 then
            APR:PrintError("Qpart update failed after retries", questID)
            return
        end
        C_Timer.After(0.4, function()
            if not AprRC:IsRecordingContext(context) then return end
            local stateSnapshot = AprRC.lastQuestState[questID] or previousState
            local ok, changed = pcall(processObjectives, stateSnapshot)
            if ok and not changed then retryProcess(attemptsLeft - 1) end
        end)
    end

    local updated = processObjectives(previousState)
    if not updated then
        -- Retry multiple times (short delay) to survive laggy objective updates without losing the initial snapshot
        retryProcess(10)
    end
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end

function AprRC.event.functions.scenario(event, ...)
    local criteriaID = tonumber((...), 10)
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo then return end

    local scenarioID = scenarioInfo.scenarioID
    local scenarioQuestID = AprRC:FindClosestIncompleteQuest()
    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
    if not stepInfo then return end

    local hasSpecificCriteriaID = criteriaID and criteriaID > 0

    for i = 1, stepInfo.numCriteria do
        local criteria = C_ScenarioInfo.GetCriteriaInfoByStep(stepInfo.stepID, i)
        local criteriaRecordID = criteria and tonumber(criteria.criteriaID, 10) or nil
        local matchesEvent = false

        if hasSpecificCriteriaID then
            matchesEvent = criteriaRecordID == criteriaID
        else
            -- Some scenario events report criteriaID=0 for progress-type updates.
            -- In that case we must inspect all criteria in the current step.
            matchesEvent = true
        end

        if criteria and matchesEvent and criteria.completed then
            local criteriaLogKey = table.concat({
                tostring(scenarioID or 0),
                tostring(stepInfo.stepID or 0),
                tostring(criteriaRecordID or 0),
                tostring(i),
            }, "|")

            if not scenarioCriteriaLogged[criteriaLogKey] then -- to avoid duplication of step
                local step = {
                    Scenario = {
                        scenarioID = scenarioID,
                        stepID = stepInfo.stepID,
                        criteriaID = criteriaRecordID and criteriaRecordID > 0 and criteriaRecordID or nil,
                        criteriaIndex = i,
                        questID = scenarioQuestID,
                    }
                }
                if AprRC:IsInInstanceQuest() then
                    step.InstanceQuest = true
                end
                AprRC:SetStepCoord(step, 5)
                AprRC:ApplyCampaignQuestFlag(step, scenarioQuestID)
                AprRC:NewStep(step)
                scenarioCriteriaLogged[criteriaLogKey] = true
                AprRC:Debug("Scenario criteria logged", {
                    key = criteriaLogKey,
                    scenarioID = scenarioID,
                    stepID = stepInfo.stepID,
                    criteriaID = criteriaRecordID and criteriaRecordID > 0 and criteriaRecordID or nil,
                    criteriaIndex = i,
                    eventCriteriaID = criteriaID,
                    completed = criteria.completed,
                    quantityString = criteria.quantityString,
                })
            else
                AprRC:Debug("Scenario criteria already logged", {
                    key = criteriaLogKey,
                    scenarioID = scenarioID,
                    stepID = stepInfo.stepID,
                    criteriaID = criteriaRecordID and criteriaRecordID > 0 and criteriaRecordID or nil,
                    criteriaIndex = i,
                    eventCriteriaID = criteriaID,
                })
            end

            -- If the event carries a specific criteriaID, one match is enough.
            if hasSpecificCriteriaID then
                break
            end
        end
    end
end

local pendingPortal
function AprRC.event.functions.portal(event, initialLogin, reloading)
    if event == "LOADING_SCREEN_ENABLED" then
        local step = {}
        if not AprRC:SetStepCoord(step) then
            pendingPortal = nil; return
        end
        local last = AprRC:GetLastStep()
        if last.UseHS or last.UseDalaHS or last.UseGarrisonHS then
            pendingPortal = nil; return
        end
        local inInstance = IsInInstance()
        pendingPortal = { context = AprRC:CaptureRecordingContext(), step = step, inInstance = inInstance }
        return
    end
    local pending = pendingPortal
    pendingPortal = nil
    if initialLogin or reloading or not pending then return end
    C_Timer.After(1, function()
        if not AprRC:IsRecordingContext(pending.context) then return end
        local mapID = C_Map.GetBestMapForUnit("player")
        local inInstance = IsInInstance()
        if not mapID or mapID == pending.step.Zone or inInstance or pending.inInstance then return end
        local last = AprRC:GetLastStep()
        if last.UseHS or last.UseDalaHS or last.UseGarrisonHS then return end
        -- A loading screen alone does not identify a portal. Confirm the inferred transition.
        APR.questionDialog:CreateQuestionPopup("Record a portal to map " .. mapID .. "?",
            "Record a portal to map " .. mapID .. "?", function()
                if not AprRC:IsRecordingContext(pending.context) then return end
                local step = pending.step
                step.TakePortal = { questID = AprRC:FindClosestIncompleteQuest(), mapID = mapID }
                AprRC:ApplyCampaignQuestFlag(step, step.TakePortal.questID)
                AprRC:NewStep(step)
            end)
    end)
end

function AprRC.event.functions.learnProfession(event, ...)
    local spellID, skillLineIndex, isGuildPerkSpell = ...
    if tContains(AprRC.professionSpellIDs, spellID) then
        local step = { LearnProfession = spellID }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
end
