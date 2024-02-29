local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(AprRC, "APR-Recorder", "AceEvent-3.0")
AprRC.Color = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
    defaultBackdrop = { 0, 0, 0, 0.4 },

}

function AprRC:OnInitialize()
    local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata

    -- Init on TOC
    AprRC.title = C_AddOns.GetAddOnMetadata("APR-Recorder", "Title")
    AprRC.version = C_AddOns.GetAddOnMetadata("APR-Recorder", "Version")
    AprRC.github = GetAddOnMetadata("APR-Recorder", "X-Github")
    AprRC.discord = GetAddOnMetadata("APR-Recorder", "X-Discord")

    -- Init Saved variable
    AprRCData = AprRCData or {}

    -- Init module
    AprRC.settings:InitializeBlizOptions()
    AprRC.record:OnInit()
    AprRC.event:MyRegisterEvent()

    -- Init Global Variables, UI oriented
    BINDING_HEADER_APR_ROUTE_RECORDER = AprRC.title -- Header text for APR's main frame
    _G["BINDING_NAME_" .. "CLICK AprRCItemButton:LeftButton"] = L_APR["USE_QUEST_ITEM"]

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end

function Debug(data)
    if type(data) == 'table' then
        for key, value in pairs(data) do
            print(key, value)
        end
    else
        print(data)
    end
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
