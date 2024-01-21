local L = LibStub("AceLocale-3.0"):GetLocale("APR-Route-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(addon, "APR-Route-Recorder", "AceEvent-3.0")

function AprRC:OnInitialize()
    -- Init on TOC
    AprRC.title = C_AddOns.GetAddOnMetadata("APR-Route-Recorder", "Title")
    AprRC.version = C_AddOns.GetAddOnMetadata("APR-Route-Recorder", "Version")


    -- Init Settings
    -- APR.settings:InitializeBlizOptions()

    -- Init Saved variable
    AprRCData = AprRCData or {}

    -- Init Global Variables, UI oriented
    BINDING_HEADER_APR_ROUTE_RECORDER = AprRC.title -- Header text for APR's main frame
    _G["BINDING_NAME_" .. "CLICK AprRCItemButton:LeftButton"] = L_APR["USE_QUEST_ITEM"]

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end

-- - Faction
-- - Race
-- - Gender
-- - Class
-- - HasAchievement
-- - DontHaveAchievement
-- - ExitTutorial
-- - PickUp
-- - PickUpDB
-- - DropQuest
-- - Qpart
-- - QpartDB
-- - QpartPart
-- - Treasure
-- - QaskPopup
-- - Done
-- - DoneDB
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
-- - Grind
-- - ZoneDoneSave
-- - ZoneStepTrigger
-- - Range
-- - Coord
-- - QuestLineSkip
-- - Group
-- - GroupTask
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
-- - Fillers

AprRC.EventFrame = CreateFrame("Frame")
AprRC.EventFrame:RegisterAllEvents("ADDON_LOADED")
AprRC.EventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
AprRC.EventFrame:RegisterEvent("BANKFRAME_OPENED")
AprRC.EventFrame:RegisterEvent("CHAT_MSG_ADDON")
AprRC.EventFrame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
AprRC.EventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
AprRC.EventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
AprRC.EventFrame:RegisterEvent("COMPANION_LEARNED")
AprRC.EventFrame:RegisterEvent("COMPANION_UNLEARNED")
AprRC.EventFrame:RegisterEvent("COMPANION_UPDATE")
AprRC.EventFrame:RegisterEvent("CONFIRM_BINDER")
AprRC.EventFrame:RegisterEvent("CONFIRM_XP_LOSS")
AprRC.EventFrame:RegisterEvent("CVAR_UPDATE")
AprRC.EventFrame:RegisterEvent("GOSSIP_CLOSED")
AprRC.EventFrame:RegisterEvent("GOSSIP_CONFIRM_CANCEL")
AprRC.EventFrame:RegisterEvent("GOSSIP_SHOW")
AprRC.EventFrame:RegisterEvent("GROUP_JOINED")
AprRC.EventFrame:RegisterEvent("GROUP_LEFT")
AprRC.EventFrame:RegisterEvent("HEARTHSTONE_BOUND")
AprRC.EventFrame:RegisterEvent("ITEM_PUSH")
AprRC.EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
AprRC.EventFrame:RegisterEvent("MERCHANT_CLOSED")
AprRC.EventFrame:RegisterEvent("MERCHANT_SHOW")
AprRC.EventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
AprRC.EventFrame:RegisterEvent("NEW_PET_ADDED")
AprRC.EventFrame:RegisterEvent("NEW_WMO_CHUNK")
AprRC.EventFrame:RegisterEvent("PET_BATTLE_CLOSE")
AprRC.EventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
AprRC.EventFrame:RegisterEvent("PET_STABLE_CLOSED")
AprRC.EventFrame:RegisterEvent("PET_STABLE_SHOW")
AprRC.EventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
AprRC.EventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
AprRC.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
AprRC.EventFrame:RegisterEvent("PLAYER_LEVEL_UP")
AprRC.EventFrame:RegisterEvent("PLAYER_MONEY")
AprRC.EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
AprRC.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
AprRC.EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
AprRC.EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
AprRC.EventFrame:RegisterEvent("PLAYER_XP_UPDATE")
AprRC.EventFrame:RegisterEvent("QUEST_ACCEPTED")
AprRC.EventFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
AprRC.EventFrame:RegisterEvent("QUEST_AUTOCOMPLETE")
AprRC.EventFrame:RegisterEvent("QUEST_COMPLETE")
AprRC.EventFrame:RegisterEvent("QUEST_DETAIL")
AprRC.EventFrame:RegisterEvent("QUEST_FINISHED")
AprRC.EventFrame:RegisterEvent("QUEST_GREETING")
AprRC.EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
AprRC.EventFrame:RegisterEvent("QUEST_PROGRESS")
AprRC.EventFrame:RegisterEvent("QUEST_REMOVED")
AprRC.EventFrame:RegisterEvent("QUEST_TURNED_IN")
AprRC.EventFrame:RegisterEvent("REQUEST_CEMETERY_LIST_RESPONSE")
AprRC.EventFrame:RegisterEvent("SKILL_LINES_CHANGED")
AprRC.EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
AprRC.EventFrame:RegisterEvent("TAXIMAP_OPENED")
AprRC.EventFrame:RegisterEvent("TOYS_UPDATED")
AprRC.EventFrame:RegisterEvent("TRAINER_CLOSED")
AprRC.EventFrame:RegisterEvent("TRAINER_SHOW")
AprRC.EventFrame:RegisterEvent("TRAINER_UPDATE")
AprRC.EventFrame:RegisterEvent("UI_ERROR_MESSAGE")
AprRC.EventFrame:RegisterEvent("UI_INFO_MESSAGE")
AprRC.EventFrame:RegisterEvent("UNIT_AURA")
AprRC.EventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
AprRC.EventFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
AprRC.EventFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
AprRC.EventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
AprRC.EventFrame:RegisterEvent("UNIT_SPELLCAST_START")
AprRC.EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
AprRC.EventFrame:RegisterEvent("UNIT_TARGET")
AprRC.EventFrame:RegisterEvent("UPDATE_FACTION")
AprRC.EventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
AprRC.EventFrame:RegisterEvent("UPDATE_UI_WIDGET")
AprRC.EventFrame:RegisterEvent("VEHICLE_UPDATE")
AprRC.EventFrame:RegisterEvent("ZONE_CHANGED")
AprRC.EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
AprRC.EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
AprRC.EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event then
        return
    end
end)
