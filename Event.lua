local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.event = AprRC:NewModule("AprRC-Event")

-- global event framePool for register
AprRC.event.framePool = {}
AprRC.event.functions = {}

local targetName, targetID
local scenarioCriteriaLogged = {}

---------------------------------------------------------------------------------------
------------------------------------- EVENTS ------------------------------------------
---------------------------------------------------------------------------------------

local events = {
    load = "ADDON_LOADED",
    accept = "QUEST_ACCEPTED",
    remove = "QUEST_REMOVED",
    done = "QUEST_TURNED_IN",
    gossip = "GOSSIP_SHOW",
    setHS = "HEARTHSTONE_BOUND",
    spell = "UNIT_SPELLCAST_SUCCEEDED",
    raidIcon = "RAID_TARGET_UPDATE",
    pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" },
    emote = "CHAT_MSG_TEXT_EMOTE",
    taxi = { "TAXIMAP_OPENED", "TAXIMAP_CLOSED" },
    fly = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" },
    buy = "MERCHANT_SHOW",
    qpart = "QUEST_WATCH_UPDATE",
    loot = "CHAT_MSG_LOOT",
    target = "PLAYER_TARGET_CHANGED",
    scenario = "SCENARIO_CRITERIA_UPDATE",
    portal = { "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED" },
    learnProfession = "LEARNED_SPELL_IN_SKILL_LINE"
    -- warMode = "WAR_MODE_STATUS_UPDATE",
    -- vehicle = { "UNIT_ENTERING_VEHICLE", "UNIT_EXITING_VEHICLE" },
}

---------------------------------------------------------------------------------------
-------------------------------------- DATA -------------------------------------------
---------------------------------------------------------------------------------------

local boatsNodeID = { 2052, 2053, 2054, 2055, 2056, 2057, 2104, 2105 }
local chromieTimelineSpellID = {
    [325400] = { name = "TheBurningCrusade", optionID = 6 },
    [325042] = { name = "WrathOfTheLichKing", optionID = 7 },
    [325537] = { name = "Cataclysm", optionID = 5 },
    [325530] = { name = "MistsOfPandaria", optionID = 8 },
    [325534] = { name = "WarlordsOfDraenor", optionID = 9 },
    [325539] = { name = "Legion", optionID = 10 },
    [420123] = { name = "BattleForAzeroth", optionID = 15 },
    [397733] = { name = "Shadowlands", optionID = 14 }
    -- Dragonflight
}
local controlLostTime = 0

---------------------------------------------------------------------------------------
---------------------------------- Events register ------------------------------------
---------------------------------------------------------------------------------------

function AprRC.event:MyRegisterEvent()
    for tag, event in pairs(events) do
        local container = self.framePool[tag] or CreateFrame("Frame")
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
        pcall(self.callback, event, ...)
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
        if AprRC:HasStepOption("DroppableQuest") then
            local currentStep = AprRC:GetLastStep()
            currentStep.DropQuest = questId
            currentStep.DroppableQuest.Qid = questId
            AprRC:saveQuestInfo()
            return
        end
        if AprRC:HasStepOption("ChromiePick") then
            local currentStep = AprRC:GetLastStep()
            currentStep.PickUp = { questId }
            AprRC:saveQuestInfo()
            return
        end
        if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("PickUp") then
            local currentStep = AprRC:GetLastStep()
            tinsert(currentStep.PickUp, questId)
        else
            local step = { PickUp = { questId } }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
        end
        -- update saved quest
        AprRC:saveQuestInfo()
    end
    if C_QuestLog.IsWorldQuest(questId) then
        APR.questionDialog:CreateQuestionPopup(
            "New world quest, do you want to add it?",
            function()
                AddQuestToStep(questId)
            end
        )
        return
    end

    AddQuestToStep(questId)
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
    else
        local step = { Done = { questId } }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
    --remove quest from state list
    AprRC.lastQuestState[questId] = nil
end

function AprRC.event.functions.raidIcon(...)
    local targetId = APR:GetTargetID()
    if targetId then
        local currentStep = AprRC:GetLastStep()
        currentStep.RaidIcon = targetId
    end
end

function AprRC.event.functions.setHS(...)
    local step = { SetHS = AprRC:FindClosestIncompleteQuest() }
    AprRC:SetStepCoord(step)
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
        elseif chromieTimelineSpellID[spellID] then
            local step = {}
            step.ChromiePick = chromieTimelineSpellID[spellID].optionID
            step.GossipOptionIDs = { 51901, 51902 }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
            return
        end

        if key then
            local step = {}
            step[key] = AprRC:FindClosestIncompleteQuest()
            step.Zone = AprRC:getZone()
            AprRC:NewStep(step)
        end
    end
end

function AprRC.event.functions.warMode(event, warModeEnabled)
    if warModeEnabled then
        local step = { WarMode = AprRC:FindClosestIncompleteQuest() }
        AprRC:NewStep(step)
    end
end

function AprRC.event.functions.vehicle(event, ...)
    if event == "UNIT_EXITING_VEHICLE" then
        if not AprRC:HasStepOption("VehicleExit") then
            local currentStep = AprRC:GetLastStep()
            currentStep.VehicleExit = true
        end
    end
end

local function SetGossipOptionID(self)
    local gossipInfo = self:GetData().info
    local gossipIcon = gossipInfo.icon
    local gossipOptionID = gossipInfo.gossipOptionID

    if gossipIcon == 132053 and not tContains({ 51901, 51902 }, gossipOptionID) then -- bubble icon and not Chromie select timeline
        if not AprRC:IsCurrentStepFarAway() then
            local currentStep = AprRC:GetLastStep()
            local shouldUseCurrentStep = currentStep and
                (currentStep.Qpart or currentStep.QpartPart or currentStep.GossipOptionIDs)

            if shouldUseCurrentStep then
                if currentStep.GossipOptionIDs then
                    if not tContains(currentStep.GossipOptionIDs, gossipOptionID) then
                        tinsert(currentStep.GossipOptionIDs, gossipOptionID)
                    end
                else
                    currentStep.GossipOptionIDs = { gossipOptionID }
                end
            else
                local step = { GossipOptionIDs = { gossipOptionID } }
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end
        else
            local step = { GossipOptionIDs = { gossipOptionID } }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
        end
    end
end

function AprRC.event.functions.gossip(event, ...)
    local childs = { GossipFrame.GreetingPanel.ScrollBox.ScrollTarget:GetChildren() }
    for k, child in ipairs(childs) do
        local data = child.GetData and child:GetData()
        if data and data.info and data.info.gossipOptionID then
            if not child.hookedGossipExtraction then
                child:HookScript("OnClick", SetGossipOptionID)
                child.hookedGossipExtraction = true
            end
        end
    end
end

function AprRC.event.functions.emote(event, ...)
    local message, sender = ...
    if APR.Username == sender then
        local function getEmoteKey()
            for emoteKey, phrases in pairs(L.Emotes) do
                for _, phrase in ipairs(phrases) do
                    local pattern = phrase:gsub("%%s", ".+") -- replace placeholders patern to lua
                    pattern = "^" .. pattern .. "$"          -- cast as regex
                    if string.match(message, pattern) then
                        return emoteKey
                    end
                end
            end
            return nil
        end

        local emote = getEmoteKey()
        if emote then
            local currentStep = AprRC:GetLastStep()
            if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("Emote") then
                currentStep.Emote = emote
            else
                local step = { Emote = emote }
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end
        end
    end
end

function AprRC.event.functions.taxi(event, ...)
    if event == "TAXIMAP_OPENED" then
        local playerMapID = C_Map.GetBestMapForUnit("player")
        local taxiNodes = C_TaxiMap.GetAllTaxiNodes(playerMapID)

        for _, node in ipairs(taxiNodes) do
            if node.state == Enum.FlightPathState.Current then
                AprRC.CurrentTaxiNode = node
            end
        end
    elseif event == "TAXIMAP_CLOSED" then
        -- Save player position for right coord on taxi step
        local step = {}
        AprRC:SetStepCoord(step)
        C_Timer.After(2, function()
            if AprRC.CurrentTaxiNode and not UnitOnTaxi("player") then
                local nodeID = AprRC.CurrentTaxiNode.nodeID
                if not AprRC:IsTaxiInLookup(nodeID) then
                    step.GetFP = nodeID
                    -- Save for currentRoute
                    AprRCData.TaxiLookup[nodeID] = true
                    AprRC:NewStep(step)
                end
            end
        end)
    end
end

function AprRC.event.functions.fly(event, ...)
    if event == "PLAYER_CONTROL_LOST" then
        -- Save player position for right coord on taxi step
        local step = {}
        AprRC:SetStepCoord(step)
        C_Timer.After(2, function()
            if UnitOnTaxi("player") then
                AprRC.isOnTaxi = true
                controlLostTime = GetTime()
                step.UseFlightPath = AprRC:FindClosestIncompleteQuest()
                AprRC:NewStep(step)
            end
        end)
    elseif event == "PLAYER_CONTROL_GAINED" then
        if AprRC.isOnTaxi then
            local currentStep = AprRC:GetLastStep()

            -- ETA
            local controlGainTime = GetTime()
            local duration = math.floor(controlGainTime - controlLostTime)
            currentStep.ETA = duration

            --NodeID
            local posY, posX = UnitPosition("player")
            local taxiNodeId, taxiName, taxiX, taxiY = APR.transport:ClosestTaxi(posX, posY)
            currentStep.NodeID = taxiNodeId

            --Boat
            if tContains(boatsNodeID, AprRC.CurrentTaxiNode) then
                currentStep.Boat = true
            end

            -- reset
            AprRC.isOnTaxi = false
            controlLostTime = 0
            AprRC.CurrentTaxiNode = nill
        end
    end
end

function AprRC.event.functions.buy(event, ...)
    local numItems = GetMerchantNumItems()
    for i = 1, numItems do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button and not button.isHooked then
            button:HookScript("OnClick", function()
                local itemID = GetMerchantItemID(i)
                if itemID then
                    local currentStep = AprRC:GetLastStep()
                    if currentStep and currentStep.BuyMerchant then
                        local found = false
                        for _, item in ipairs(currentStep.BuyMerchant) do
                            if item.itemID == itemID then
                                item.quantity = item.quantity + 1
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(currentStep.BuyMerchant,
                                { itemID = itemID, quantity = 1, questID = AprRC:FindClosestIncompleteQuest() })
                        end
                        return
                    end

                    local step = { BuyMerchant = { { itemID = itemID, quantity = 1, questID = AprRC:FindClosestIncompleteQuest() } } }
                    AprRC:SetStepCoord(step)
                    AprRC:NewStep(step)
                end
            end)
            button.isHooked = true
        end
    end
end

function AprRC.event.functions.qpart(event, questID)
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
            step.Button[questID .. "-" .. index] = itemID
        end
    end

    local function setQpart(lastFulfilled, objective, questID, index)
        local previousValue = lastFulfilled or 0
        local currentValue = objective.numFulfilled or 0
        if previousValue < currentValue then
            local currentStep = AprRC:GetLastStep()
            if (currentStep.Qpart and currentStep.Qpart[questID] and currentStep.Qpart[questID][index]) or
                AprRC:IsQuestInLookup(questID, index) then
                AprRC.lastQuestState[questID][index] = { numFulfilled = currentValue }
                return true
            end

            local range = (objective.type == "monster" or objective.type == "item") and 30 or 5
            local function newStep()
                step.Qpart = {}
                step.Qpart[questID] = { index }
                if AprRC:IsInInstanceQuest() then
                    step.InstanceQuest = true
                end
                setButton(questID, index, step)
                -- step.IsCampaignQuest = AprRC:IsCampaignQuest(questID) or nil
                step.Range = range
                AprRC:NewStep(step)
            end
            if AprRC:HasStepOption("PickUp")
                or AprRC:HasStepOption("Done")
                or AprRC:HasStepOption("LeaveQuests")
                or AprRC:HasStepOption("GetFP")
                or AprRC:HasStepOption("setHS")
                or AprRC:HasStepOption("Waypoint") then
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
            AprRC:Error("Qpart update failed after retries", questID)
            return
        end
        C_Timer.After(0.4, function()
            local stateSnapshot = AprRC.lastQuestState[questID] or previousState
            if not processObjectives(stateSnapshot) then
                retryProcess(attemptsLeft - 1)
            end
        end)
    end

    local updated = processObjectives(previousState)
    if not updated then
        -- Retry multiple times (short delay) to survive laggy objective updates without losing the initial snapshot
        retryProcess(5)
    end
end

function AprRC.event.functions.loot(event, message, ...)
    local itemLink = string.match(message, "|Hitem:.-|h.-|h")

    if itemLink then
        local itemID, _, _, _, _, classID, _ = C_Item.GetItemInfoInstant(itemLink)
        if classID == 12 then -- Quest item
            local tooltipScanner = CreateFrame("GameTooltip", "ItemTooltipScanner", nil, "GameTooltipTemplate")
            tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
            tooltipScanner:SetItemByID(itemID)

            local hasQuestItem = false
            for i = 2, tooltipScanner:NumLines() do
                local line = _G["ItemTooltipScannerTextLeft" .. i]:GetText() or ""
                if line:find(L.DroppableQuestItem) then
                    hasQuestItem = true
                    break
                end
            end
            if hasQuestItem then
                local step = {}
                step.DroppableQuest = { Text = targetName, MobId = tonumber(targetID) }
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step, 5)
            end
        end
    end
end

function AprRC.event.functions.target(event, ...)
    local targetGUID = UnitGUID("target")
    if not targetGUID then return end
    targetName = UnitNameUnmodified("target")
    targetID = select(6, strsplit("-", targetGUID))
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end

function AprRC.event.functions.scenario(event, ...)
    local criteriaID = ...
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    if not scenarioInfo then return end

    local scenarioID = scenarioInfo.scenarioID
    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
    if not stepInfo then return end
    for i = 1, stepInfo.numCriteria do
        local criteria = C_ScenarioInfo.GetCriteriaInfoByStep(stepInfo.stepID, i)
        if criteria.criteriaID == criteriaID and criteria.completed then
            if not scenarioCriteriaLogged[criteriaID] then -- to avoid duplication of step
                local step = { Scenario = { scenarioID = scenarioID, stepID = stepInfo.stepID, criteriaID = criteriaID, criteriaIndex = i } }
                if AprRC:IsInInstanceQuest() then
                    step.InstanceQuest = true
                end
                AprRC:SetStepCoord(step, 5)
                AprRC:NewStep(step)
                scenarioCriteriaLogged[criteriaID] = true
            end
            break
        end
    end
end

function AprRC.event.functions.portal(event, ...)
    if event == "LOADING_SCREEN_ENABLED" then
        -- Step to save coordinates before TP
        local step = {}
        AprRC:SetStepCoord(step)
        AprRCData.BeforePortal.stepForCoord = step

        -- previous step before the portal
        local lastStep = AprRC:GetLastStep()
        AprRCData.BeforePortal.lastStep = lastStep
    else
        local isInitialLogin, isReloadingUi = ...
        -- wait 3s; if last step == saved last step then add waypoint + "USE_PORTAL" text -- non-skippable waypoints (new option)
        -- otherwise check IsCurrentStepFarAway; if too far then override coord + "USE_PORTAL" text
        -- for teleports without a portal or cast => detect via LOSS_OF_CONTROL_ADDED, ZONE_CHANGED_INDOORS, waypoint update, AREA_POIS_UPDATED
        -- for teleports with a spell => use a teleport spell list (excluding class spells) + UNIT_SPELLCAST_SUCCEEDED

        if not isInitialLogin and not isReloadingUi then
            C_Timer.After(5, function()
                local lastStep = AprRC:GetLastStep()
                local beforePortal = AprRCData.BeforePortal or {}
                local portalStep = beforePortal.stepForCoord
                local portalStepCoord = portalStep.Coord
                local portalStepZone = portalStep.Zone

                local lastStepBeforePortal = beforePortal.lastStep
                -- Same last step so we need to add a new one

                if lastStepBeforePortal and lastStep and AprRC:DeepCompare(lastStepBeforePortal, lastStep) then
                    APR.questionDialog:CreateQuestionPopup(
                        "Set a waypoint where you were before teleporting?", function()
                            local reuseLast = false
                            if lastStep.Waypoint and lastStep.Coord then
                                if lastStep.Coord.x == portalStepCoord.x and lastStep.Coord.y == portalStepCoord.y then
                                    reuseLast = true
                                end
                            end

                            if reuseLast then
                                lastStep.ExtraLineText = "USE_PORTAL"
                                lastStep.Zone = portalStepZone
                                AprRC:AddZoneStepTrigger(lastStep)
                                print("|cff00bfffWaypoint|r Updated")
                            else
                                local step = {
                                    Waypoint = AprRC:FindClosestIncompleteQuest(),
                                    ExtraLineText = "USE_PORTAL",
                                    Coord = portalStepCoord,
                                    Zone = portalStepZone,
                                }
                                AprRC:AddZoneStepTrigger(step)
                                AprRC:NewStep(step)
                                print("|cff00bfffWaypoint|r Added")
                            end
                        end)
                elseif lastStep then
                    if AprRC:IsCurrentStepFarAway() then
                        lastStep.Coord = portalStepCoord
                        lastStep.Zone = portalStepZone
                    end
                    lastStep.ExtraLineText = "USE_PORTAL"
                    print("|cff00bfffLast Step coord updated|r")
                end
                AprRCData.BeforePortal = {}
            end)
        end
        -- reset on login
        if isInitialLogin then
            AprRCData.BeforePortal = {}
        end
    end
end

function AprRC.event.functions.learnProfession(event, ...)
    local spellID, skillLineIndex, isGuildPerkSpell = ...
    if tContains(AprRC.professionSpellIDs, spellID) then
        local step = { LearnProfession = spellID }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
end

---------------------
-- V2
---------------------
-- - Treasure   ["Treasure"] = 31401 (questID) (how ?)

-- sur l'action d'un DB check si y a la quest ID dans un PickUpDB et l'ajouter automatiquemejnt
-- - QpartDB
-- - DoneDB     ["DoneDB"] = { questID1, questID2}

-- si on get une nouvelle quete ou actualise une quete -> info = C_QuestLog.GetInfo(questLogIndex); info.suggestedGroup
-- - Group      ["Group"] = { Number = 3, QuestId = 51384},
-- - GroupTask  ["GroupTask"] = 51384, (the questId from Group, step to check if player want to do the group quest)
-- - QuestLineSkip ???? (block group quest if present) ["QuestLineSkip"] = 51226,

-- MountVehicle / InVehicle (rework)

---------------------
-- V3 - maybe in command no button
---------------------
-- - DoIHaveFlight ?? check si on peut en faire quelque chose pour des waypoints (avec ajout unAutoSkipableWaypoint)
-- - NoAutoFlightMap
-- - PickedLoa
-- - SpecialETAHide ??
-- - Bloodlust
-- - DenyNPC

-------------------------------

-- AprRC.EventFrame:RegisterEvent("CONFIRM_XP_LOSS") -- deathskip ??
