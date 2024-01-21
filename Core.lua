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

-- -- only in route check if needed
-- - ExtraActionB

-- - ButtonSpellId -- Deleted
-- - BlockQuests -- Deleted
