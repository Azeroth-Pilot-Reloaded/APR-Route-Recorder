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

    -- Init Global Variables, UI oriented
    BINDING_HEADER_APR_ROUTE_RECORDER = AprRC.title -- Header text for APR's main frame
    _G["BINDING_NAME_" .. "CLICK AprRCItemButton:LeftButton"] = L_APR["USE_QUEST_ITEM"]

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
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
