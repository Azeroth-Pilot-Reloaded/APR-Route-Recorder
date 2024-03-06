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
    accept = "QUEST_ACCEPTED",
    remove = "QUEST_REMOVED",
    done = "QUEST_TURNED_IN",
    setHS = "HEARTHSTONE_BOUND",
    spell = "UNIT_SPELLCAST_SUCCEEDED",
    raidIcon = "RAID_TARGET_UPDATE",
    pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" },
    warMode = "WAR_MODE_STATUS_UPDATE",
    vehicle = { "UNIT_ENTERING_VEHICLE", "UNIT_EXITING_VEHICLE" },
    -- in progress
    gossip = "GOSSIP_ENTER_CODE",
    qpart = "QUEST_LOG_UPDATE",
    taxi = "TAXIMAP_OPENED",                                 -- par defaut on fait un getFP mais si jamais y a déjà un getFP sur le currentNode on fait rien
    fly = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" } -- UnitOnTaxi("player") UseFlightPath + NodeID+ coord du depart -- il faut lancer le timer durant le fly et set ETA quand on récup le control

    -- target = {"UNIT_TARGET", "PLAYER_TARGET_CHANGED"},
    --skill = {"SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB"} BUTTON ?

}

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
        Debug("Callback Event", event)
        pcall(self.callback, event, ...)
    else
        Debug("Unregister Event", event)
        self.callback = nil
        self:UnregisterEvent(event)
    end
end

---------------------------------------------------------------------------------------
---------------------------------- Events Functions -----------------------------------
---------------------------------------------------------------------------------------

function AprRC.event.functions.accept(event, questId)
    -- Pickup
    if event == events.accept then
        local currentStep = AprRC:GetLastStep()
        if not AprRC:IsCurrentStepFarAway() and AprRC:HasStepOption("PickUp") then
            tinsert(currentStep["PickUp"], questId)
        else
            local step = { PickUp = { questId } }
            AprRC:SetStepCoord(step)
            AprRC:NewStep(step)
        end
    end
end

function AprRC.event.functions.remove(event, questId, ...)
    -- LeaveQuests

    if AprRC:HasStepOption("LeaveQuests") then
        local currentStep = AprRC:GetLastStep()
        tinsert(currentStep["LeaveQuests"], questId)
    else
        local step = { LeaveQuests = { questId } }
        AprRC:NewStep(step)
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
end

function AprRC.event.functions.raidIcon(...)
    local targetId = _G.GetTargetID()
    local currentStep = AprRC:GetLastStep()
    currentStep.RaidIcon = targetId
end

function AprRC.event.functions.setHS(...)
    local step = { SetHS = 1 } -- //TODO verif si on veut la questId pour les reset
    AprRC:SetStepCoord(step)
    AprRC:NewStep(step)
end

function AprRC.event.functions.spell(event, unitTarget, castGUID, spellID)
    local key = nil
    local value = 1 -- //TODO verif si on veut la questId pour les reset
    if spellID == APR.dalaHSSpellID then
        key = "UseDalaHS"
    elseif spellID == APR.garrisonHSSpellID then
        key = "UseGarrisonHS"
    elseif Contains(APR.hearthStoneSpellID, spellID) then
        key = "UseHS"
    end

    if key then
        local step = {}
        step[key] = value
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
end

function AprRC.event.functions.warMode(event, warModeEnabled)
    if warModeEnabled then
        local step = { WarMode = 1 } -- //TODO verif si on veut la questId pour les reset
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
end

function AprRC.event.functions.vehicle(event, ...)
    if event == "UNIT_EXITING_VEHICLE" then
        local currentStep = AprRC:GetLastStep()
        tinsert(currentStep["VehicleExit"], 1)
    end
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end

function AprRC.event.functions.gossip(event, gossipID)
    print("event:", event, gossipID)
end

---------------------
-- EVENT
---------------------
-- - Qpart        ["Qpart"] = {[46727] = {["2"] = "1",},
-- - Treasure   ["Treasure"] = 31401 (questID)
-- - Gossip

-- - GetFP
-- - UseFlightPath
-- - NodeID

-- - ChromiePick ( check to the timeline event) PLAYER_ENTERING_WORLD + C_PlayerInfo.IsPlayerInChromieTime()

-- Check how
-- - DroppableQuest = { Text = "Tideblood", Qid = 50593, MobId = 130116 },
-- - DropQuest    ["DropQuest"] = 62567 (questID)

---------------------
-- COMMAND / BAR
---------------------

-- - Boat (c'est que pour afficher la bonne phrase)
-- - Emote (edit box  + target)

-- - Faction ["Faction"] = "Horde" (UnitFactionGroup("player"))
-- - Race    ["Race"] = "Gnome"
-- - Gender  ["Gender"] = 2
-- - Class   ["Class"] = "DRUID"
-- - Grind   command grind lvl
-- - HasAchievement command HasAchievement ID
-- - DontHaveAchievement command DontHaveAchievement ID

-- - PickUpDB     ["PickUpDB"] = { questID1, questID2}
-- - QpartDB
-- - QpartPart (rework ?)
-- - TrigText  (rework ?)
-- - DoneDB     ["DoneDB"] = { questID1, questID2}$

-- - ExtraLineText
-- - ExtraLine

-- - Waypoint
-- - Range
-- - ZoneStepTrigger

-- - ETA
-- - UseGlider
-- - Bloodlust
-- - InstanceQuest
-- - NoAutoFlightMap

-- - ZoneDoneSave

---------------------
-- A VOIR
---------------------
-- - Fillers ?????????
-- - Button
-- - SpellButton
-- - SpellTrigger
-- - Group      ["Group"] = { Number = 3, QuestId = 51384},
-- - GroupTask  ["GroupTask"] = 51384, (the questId from Group, step to check if player want to do the group quest)
-- - QuestLineSkip ???? (block group quest if present) ["QuestLineSkip"] = 51226,

-- - ExtraActionB chekc if event is trigger on click (other then UNIT_SPELLCAST_SUCCEEDED)

-- - PickedLoa
-- - SpecialETAHide ??

-- - DoIHaveFlight ?? check si on peut en faire quelque chose pour des waypoints (avec ajout unAutoSkipableWaypoint)
-- - Dontskipvid
-- - DenyNPC

-- - ExitTutorial ["ExitTutorial"] = 62567 (IsOnQuest(questID)

-- AprRC.EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
--force mort
-- AprRC.EventFrame:RegisterEvent("CONFIRM_BINDER")
-- AprRC.EventFrame:RegisterEvent("CONFIRM_XP_LOSS")
-- AprRC.EventFrame:RegisterEvent("GROUP_JOINED")
-- AprRC.EventFrame:RegisterEvent("GROUP_LEFT")
-- AprRC.EventFrame:RegisterEvent("ITEM_PUSH")
-- AprRC.EventFrame:RegisterEvent("MERCHANT_SHOW")
-- AprRC.EventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
-- AprRC.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- AprRC.EventFrame:RegisterEvent("QUEST_AUTOCOMPLETE")
-- AprRC.EventFrame:RegisterEvent("QUEST_COMPLETE")
-- AprRC.EventFrame:RegisterEvent("QUEST_DETAIL")
-- AprRC.EventFrame:RegisterEvent("QUEST_FINISHED")
-- AprRC.EventFrame:RegisterEvent("QUEST_GREETING")
-- AprRC.EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
-- AprRC.EventFrame:RegisterEvent("QUEST_PROGRESS")
-- AprRC.EventFrame:RegisterEvent("REQUEST_CEMETERY_LIST_RESPONSE")
-- AprRC.EventFrame:RegisterEvent("SKILL_LINES_CHANGED")
-- AprRC.EventFrame:RegisterEvent("TOYS_UPDATED")
-- AprRC.EventFrame:RegisterEvent("UNIT_AURA")
-- AprRC.EventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
-- AprRC.EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-- AprRC.EventFrame:RegisterEvent("UPDATE_FACTION")
-- AprRC.EventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
-- AprRC.EventFrame:RegisterEvent("UPDATE_UI_WIDGET")
