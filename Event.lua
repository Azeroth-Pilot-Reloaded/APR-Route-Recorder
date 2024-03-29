local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.event = AprRC:NewModule("AprRC-Event")

-- global event framePool for register
AprRC.event.framePool = {}
AprRC.event.functions = {}

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
    -- warMode = "WAR_MODE_STATUS_UPDATE", -- add option
    vehicle = { "UNIT_ENTERING_VEHICLE", "UNIT_EXITING_VEHICLE" },
    pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" },
    emote = "CHAT_MSG_TEXT_EMOTE",
    taxi = { "TAXIMAP_OPENED", "TAXIMAP_CLOSED" },
    fly = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" },
    buy = "MERCHANT_SHOW",
    qpart = "QUEST_WATCH_UPDATE"
    -- in progress
    -- filler ?

    -- target = {"UNIT_TARGET", "PLAYER_TARGET_CHANGED"},
    --skill = {"SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB"} BUTTON ?
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
    [397733] = { name = "Shadowlands", optionID = 14 },
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
                    currentStep.ExtraActionB = 1
                end)
                ExtraActionButton1.isHookedAprRC = true
            end
        end
    end
end)

---------------------------------------------------------------------------------------
---------------------------------- Events Functions -----------------------------------
---------------------------------------------------------------------------------------


function AprRC.event.functions.accept(event, questId)
    -- Pickup
    if AprRC:HasStepOption("ChromiePick") then
        local currentStep = AprRC:GetLastStep()
        currentStep.PickUp = { questId }
        return
    end
    if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("PickUp") then
        local currentStep = AprRC:GetLastStep()
        tinsert(currentStep["PickUp"], questId)
    else
        local step = { PickUp = { questId } }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
    -- update saved quest
    AprRC:saveQuestInfo()
end

function AprRC.event.functions.remove(event, questId, ...)
    -- LeaveQuests
    if not C_QuestLog.IsQuestFlaggedCompleted(questId) then
        if AprRC:HasStepOption("LeaveQuests") then
            local currentStep = AprRC:GetLastStep()
            tinsert(currentStep["LeaveQuests"], questId)
        else
            local step = { LeaveQuests = { questId } }
            AprRC:NewStep(step)
        end
        --remove quest from state list
        AprRC.lastQuestState[questId] = nil
    end
end

function AprRC.event.functions.done(event, questId, ...)
    if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("Done") then
        local currentStep = AprRC:GetLastStep()
        tinsert(currentStep["Done"], questId)
    else
        local step = { Done = { questId } }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
    --remove quest from state list
    AprRC.lastQuestState[questId] = nil
end

function AprRC.event.functions.raidIcon(...)
    local targetId = _G.GetTargetID()
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
    if spellID == APR.dalaHSSpellID then
        key = "UseDalaHS"
    elseif spellID == APR.garrisonHSSpellID then
        key = "UseGarrisonHS"
    elseif AprRC:Contains(APR.hearthStoneSpellID, spellID) then
        key = "UseHS"
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
        AprRC:NewStep(step)
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
            currentStep["VehicleExit"] = 1
        end
    end
end

local function SetGossipOptionID(self)
    local gossipInfo = self:GetData().info
    local gossipIcon = gossipInfo.icon
    local gossipOptionID = gossipInfo.gossipOptionID
    if gossipIcon == 132053 and not AprRC:Contains({ 51901, 51902 }, gossipOptionID) then --bubble icon and not chromie select timeline
        if not AprRC:IsCurrentStepFarAway() then
            local currentStep = AprRC:GetLastStep()
            if AprRC:HasStepOption("GossipOptionIDs") then
                tinsert(currentStep["GossipOptionIDs"], gossipOptionID)
            else
                currentStep["GossipOptionIDs"] = { gossipOptionID }
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
                currentStep["Emote"] = emote
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
        C_Timer.After(2, function()
            if AprRC.CurrentTaxiNode and not UnitOnTaxi("player") then
                local step = {}
                step.GetFP = AprRC.CurrentTaxiNode.nodeID
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end
        end)
    end
end

function AprRC.event.functions.fly(event, ...)
    if event == "PLAYER_CONTROL_LOST" then
        C_Timer.After(2, function()
            if UnitOnTaxi("player") then
                AprRC.isOnTaxi = true
                controlLostTime = GetTime()
                local step = {}
                step.UseFlightPath = AprRC:FindClosestIncompleteQuest()
                AprRC:SetStepCoord(step)
                AprRC:NewStep(step)
            end
        end
        )
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
            if AprRC:Contains(boatsNodeID, AprRC.CurrentTaxiNode) then
                currentStep.Boat = 1
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
            button:HookScript("OnClick", function(self)
                local itemID = GetMerchantItemID(i)
                if itemID then
                    local step = {}
                    step.BuyMerchant = itemID
                    AprRC:SetStepCoord(step)
                    AprRC:NewStep(step)
                end
            end)
            button.isHooked = true
        end
    end
end

function AprRC.event.functions.qpart(event, questID)
    local function setButton(questID, index, step)
        -- itemID
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local link = GetQuestLogSpecialItemInfo(questLogIndex)
        if link then
            local itemID = AprRC:GetItemIDFromLink(link)
            if AprRC:HasStepOption("Button") then
                tinsert(step.Button[questID .. '-' .. index], itemID)
            else
                step.Button = { [questID .. '-' .. index] = itemID }
            end
        end
    end

    local function setQpart(lastState, objective, questID, index)
        if lastState.numFulfilled < objective.numFulfilled then
            local currentStep = AprRC:GetLastStep()
            --
            if currentStep.Qpart and currentStep.Qpart[questID][index] then
                -- update
                AprRC.lastQuestState[questID][index] = { numFulfilled = objective.numFulfilled }
                return
            end

            local range = (objective.type == "monster" or objective.type == "item") and 10 or 5
            if not AprRC:IsCurrentStepFarAway() and (not AprRC:HasStepOption("Pickup") or not AprRC:HasStepOption("Done") or AprRC:HasStepOption("LeaveQuests") or not AprRC:HasStepOption("GetFP") or not AprRC:HasStepOption("setHS")) then
                if not AprRC:HasStepOption("Qpart") then
                    currentStep.Qpart = {}
                    currentStep.Qpart[questID] = {}
                    if not AprRC:HasStepOption("Coord") then
                        AprRC:SetStepCoord(currentStep, range)
                    end
                    if AprRC:IsInInstanceQuest() then
                        currentStep.InstanceQuest = true
                    end
                    setButton(questID, index, currentStep)
                end
                tinsert(currentStep.Qpart[questID], index)
            else
                local step = {}
                step.Qpart = {}
                step.Qpart[questID] = { index }
                if AprRC:IsInInstanceQuest() then
                    step.InstanceQuest = true
                end
                setButton(questID, index, step)
                AprRC:SetStepCoord(step, range)
                AprRC:NewStep(step)
            end

            -- update
            AprRC.lastQuestState[questID][index] = { numFulfilled = objective.numFulfilled }
        end
    end
    C_Timer.After(2, function()
        local objectives = C_QuestLog.GetQuestObjectives(questID)
        for index, objective in ipairs(objectives) do
            local lastState = AprRC.lastQuestState[questID] and AprRC.lastQuestState[questID][index]
            if lastState then
                setQpart(lastState, objective, questID, index)
            else
                -- save if not existing
                AprRC.lastQuestState[questID] = AprRC.lastQuestState[questID] or {}
                AprRC.lastQuestState[questID][index] = { numFulfilled = objective.numFulfilled }
                local lastState = AprRC.lastQuestState[questID] and AprRC.lastQuestState[questID][index]
                setQpart(lastState, objective, questID, index)
            end
        end
    end)
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end

---------------------
-- EVENT
---------------------
-- - Fillers ?????????
-- - Treasure   ["Treasure"] = 31401 (questID)

-- sur l'action d'un DB check si y a la quest ID dans un PickUpDB et l'ajouter automatiquemejnt
-- - QpartDB
-- - DoneDB     ["DoneDB"] = { questID1, questID2}$

-- Check how
-- - DroppableQuest = { Text = "Tideblood", Qid = 50593, MobId = 130116 },
-- - DropQuest    ["DropQuest"] = 62567 (questID)

-- - ZoneDoneSave ( auto trigger on stop ?, bouton finalisation ? )

---------------------
-- COMMAND / BAR
---------------------

-- - QpartPart (rework ?)
-- - TrigText  (rework ?)

---------------------
-- A VOIR
---------------------
-- - UseGlider (same as button mais pour le planeur gobelin - aura 126389) "UNIT_AURA"
-- - Button (utilié pour les items, détecter avec bag/spellID/aura/.. l'item utilisé )
-- - SpellButton (ajout d'un bouton de spell a utilisé pour la route, get la list des spells et autocompletion??)
-- - SpellTrigger (condition pour update une step pour une qpart)

-- si on get une nouvelle quete ou actualise une quete -> info = C_QuestLog.GetInfo(questLogIndex); info.suggestedGroup
-- - Group      ["Group"] = { Number = 3, QuestId = 51384},
-- - GroupTask  ["GroupTask"] = 51384, (the questId from Group, step to check if player want to do the group quest)
-- - QuestLineSkip ???? (block group quest if present) ["QuestLineSkip"] = 51226,


----------------------------- pas sur de le faire
-- - DoIHaveFlight ?? check si on peut en faire quelque chose pour des waypoints (avec ajout unAutoSkipableWaypoint)
-- - NoAutoFlightMap
-- - PickedLoa
-- - SpecialETAHide ??
-- - Bloodlust
-- - Dontskipvid
-- - DenyNPC

-- - ExitTutorial ["ExitTutorial"] = 62567 (IsOnQuest(questID)
-------------------------------

-- AprRC.EventFrame:RegisterEvent("CONFIRM_XP_LOSS") -- deathskip ??
-- AprRC.EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
-- AprRC.EventFrame:RegisterEvent("QUEST_PROGRESS") ??
