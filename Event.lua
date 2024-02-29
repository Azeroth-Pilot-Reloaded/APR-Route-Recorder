local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.event = AprRC:NewModule('AprRC-Event')

-- global event framePool for register
AprRC.event.framePool = {}
AprRC.event.functions = {}

---------------------------------------------------------------------------------------
------------------------------------- EVENTS ------------------------------------------
---------------------------------------------------------------------------------------

local events = {}
events.accept = "QUEST_ACCEPTED"
events.remove = "QUEST_REMOVED"
events.pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" }


---------------------------------------------------------------------------------------
---------------------------------- Events register ------------------------------------
---------------------------------------------------------------------------------------

function AprRC.event:MyRegisterEvent()
    for tag, event in pairs(events) do
        local container = self.framePool[tag] or CreateFrame("Frame")
        container.tag = tag
        container.callback = self.functions[tag]

        if type(event) == 'string' then
            container:RegisterEvent(event)
            container:SetScript('OnEvent', self.EventHandler)
        elseif type(event) == 'table' then
            for _, e in ipairs(event) do
                container:RegisterEvent(e)
                container:SetScript('OnEvent', self.EventHandler)
            end
        end
    end
end

function AprRC.event.EventHandler(self, event, ...)
    if not AprRC.settings.profile.enableAddon then
        return
    end

    if self.callback and self.tag then
        Debug('Callback Event', event)
        pcall(self.callback, event, ...)
    else
        Debug('Unregister Event', event)
        self.callback = nil
        self:UnregisterEvent(event)
    end
end

---------------------------------------------------------------------------------------
---------------------------------- Events Functions -----------------------------------
---------------------------------------------------------------------------------------

function AprRC.event.functions.accept(event, questId)
    -- Pickup
    if AprRC:HasStepOption("PickUp") then
        tinsert(AprRCData.CurrentStep["PickUp"], questId)
    else
        local step = { PickUp = { questId } }
        AprRC:SetStepCoord(step)
        AprRC:NewStep(step)
    end
    --
end

function AprRC.event.functions.remove(event, questId, ...)
    -- LeaveQuests
    if AprRC:HasStepOption("LeaveQuests") then
        tinsert(AprRCData.CurrentStep["LeaveQuests"], questId)
    else
        AprRC:NewStep({ LeaveQuests = { questId } })
    end
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end

-- - Faction ["Faction"] = "Horde" (UnitFactionGroup("player"))
-- - Race    ["Race"] = "Gnome"
-- - Gender  ["Gender"] = 2
-- - Class   ["Class"] = "DRUID"
-- - Grind   command grind lvl
-- - HasAchievement command HasAchievement ID
-- - DontHaveAchievement command DontHaveAchievement ID

-- - ExitTutorial ["ExitTutorial"] = 62567 (IsOnQuest(questID)
-- - PickUp       ["PickUp"] = { questID1, questID2}
-- - PickUpDB     ["PickUpDB"] = { questID1, questID2}
-- - DropQuest    ["DropQuest"] = 62567 (questID)
-- - Qpart        ["Qpart"] = {[46727] = {["2"] = "1",},
-- - QpartDB
-- - QpartPart
-- - Fillers
-- - Done       ["Done"] = { questID1, questID2}
-- - DoneDB     ["DoneDB"] = { questID1, questID2}
-- - Treasure   ["Treasure"] = 31401 (questID)

-- - Group      ["Group"] = { Number = 3, QuestId = 51384},
-- - GroupTask  ["GroupTask"] = 51384, (the questId from Group, step to check if player want to do the group quest)
-- - QuestLineSkip ???? (block group quest if present) ["QuestLineSkip"] = 51226,

-- - Waypoint
-- - SetHS
-- - UseHS
-- - UseDalaHS
-- - UseGarrisonHS
-- - GetFP
-- - UseFlightPath
-- - Boat
-- - NodeID
-- - Name
-- - WarMode
-- - ZoneDoneSave
-- - ZoneStepTrigger
-- - Range
-- - Coord

-- - ExtraLineText
-- - ExtraLine
-- - LoaPick
-- - PickedLoa
-- - BreadCrum
-- - LeaveQuest
-- - LeaveQuests
-- - SpecialLeaveVehicle
-- - VehicleExit
-- - SpecialFlight
-- - ETA
-- - SpecialETAHide
-- - UseGlider
-- - Bloodlust
-- - InVehicle
-- - DoIHaveFlight
-- - DroppableQuest
-- - Dontskipvid
-- - RaidIcon
-- - Button
-- - SpellButton
-- - Gossip
-- - ChromiePick
-- - SpellTrigger
-- - NoAutoFlightMap
-- - DenyNPC
-- - TrigText
-- - Emote
-- - InstanceQuest

-- -- only in route check if needed
-- - ExtraActionB

-- - ButtonSpellId -- Deleted
-- - BlockQuests -- Deleted

-- AprRC.EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
-- AprRC.EventFrame:RegisterEvent("BANKFRAME_OPENED")
-- AprRC.EventFrame:RegisterEvent("CHAT_MSG_ADDON")
-- AprRC.EventFrame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
-- AprRC.EventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
-- AprRC.EventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
-- AprRC.EventFrame:RegisterEvent("COMPANION_LEARNED")
-- AprRC.EventFrame:RegisterEvent("COMPANION_UNLEARNED")
-- AprRC.EventFrame:RegisterEvent("COMPANION_UPDATE")
-- AprRC.EventFrame:RegisterEvent("CONFIRM_BINDER")
-- AprRC.EventFrame:RegisterEvent("CONFIRM_XP_LOSS")
-- AprRC.EventFrame:RegisterEvent("CVAR_UPDATE")
-- AprRC.EventFrame:RegisterEvent("GOSSIP_CLOSED")
-- AprRC.EventFrame:RegisterEvent("GOSSIP_CONFIRM_CANCEL")
-- AprRC.EventFrame:RegisterEvent("GOSSIP_SHOW")
-- AprRC.EventFrame:RegisterEvent("GROUP_JOINED")
-- AprRC.EventFrame:RegisterEvent("GROUP_LEFT")
-- AprRC.EventFrame:RegisterEvent("HEARTHSTONE_BOUND")
-- AprRC.EventFrame:RegisterEvent("ITEM_PUSH")
-- AprRC.EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
-- AprRC.EventFrame:RegisterEvent("MERCHANT_CLOSED")
-- AprRC.EventFrame:RegisterEvent("MERCHANT_SHOW")
-- AprRC.EventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
-- AprRC.EventFrame:RegisterEvent("NEW_PET_ADDED")
-- AprRC.EventFrame:RegisterEvent("NEW_WMO_CHUNK")
-- AprRC.EventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
-- AprRC.EventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
-- AprRC.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- AprRC.EventFrame:RegisterEvent("PLAYER_LEVEL_UP")
-- AprRC.EventFrame:RegisterEvent("PLAYER_MONEY")
-- AprRC.EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
-- AprRC.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- AprRC.EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
-- AprRC.EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
-- AprRC.EventFrame:RegisterEvent("PLAYER_XP_UPDATE")
-- AprRC.EventFrame:RegisterEvent("QUEST_ACCEPTED")
-- AprRC.EventFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
-- AprRC.EventFrame:RegisterEvent("QUEST_AUTOCOMPLETE")
-- AprRC.EventFrame:RegisterEvent("QUEST_COMPLETE")
-- AprRC.EventFrame:RegisterEvent("QUEST_DETAIL")
-- AprRC.EventFrame:RegisterEvent("QUEST_FINISHED")
-- AprRC.EventFrame:RegisterEvent("QUEST_GREETING")
-- AprRC.EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
-- AprRC.EventFrame:RegisterEvent("QUEST_PROGRESS")
-- AprRC.EventFrame:RegisterEvent("QUEST_REMOVED")
-- AprRC.EventFrame:RegisterEvent("QUEST_TURNED_IN")
-- AprRC.EventFrame:RegisterEvent("REQUEST_CEMETERY_LIST_RESPONSE")
-- AprRC.EventFrame:RegisterEvent("SKILL_LINES_CHANGED")
-- AprRC.EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
-- AprRC.EventFrame:RegisterEvent("TAXIMAP_OPENED")
-- AprRC.EventFrame:RegisterEvent("TOYS_UPDATED")
-- AprRC.EventFrame:RegisterEvent("TRAINER_CLOSED")
-- AprRC.EventFrame:RegisterEvent("TRAINER_SHOW")
-- AprRC.EventFrame:RegisterEvent("TRAINER_UPDATE")
-- AprRC.EventFrame:RegisterEvent("UI_ERROR_MESSAGE")
-- AprRC.EventFrame:RegisterEvent("UI_INFO_MESSAGE")
-- AprRC.EventFrame:RegisterEvent("UNIT_AURA")
-- AprRC.EventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
-- AprRC.EventFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
-- AprRC.EventFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
-- AprRC.EventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
-- AprRC.EventFrame:RegisterEvent("UNIT_SPELLCAST_START")
-- AprRC.EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-- AprRC.EventFrame:RegisterEvent("UNIT_TARGET")
-- AprRC.EventFrame:RegisterEvent("UPDATE_FACTION")
-- AprRC.EventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
-- AprRC.EventFrame:RegisterEvent("UPDATE_UI_WIDGET")
-- AprRC.EventFrame:RegisterEvent("VEHICLE_UPDATE")
-- AprRC.EventFrame:RegisterEvent("ZONE_CHANGED")
-- AprRC.EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
-- AprRC.EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
