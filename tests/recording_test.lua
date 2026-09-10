local function fresh()
    AprRCData.CurrentRoute = { name = "2393-Recording", steps = {} }
    AprRC.settings.profile.recordBarFrame.isRecording = true
    AprRC.settings.profile.enableAddon = true
    AprRC:ResetRecordingSession()
end
local function count() return #AprRCData.CurrentRoute.steps end
fresh()
AprRC.event:MyRegisterEvent()
local frameCount = #TestFrames
AprRC.event:MyRegisterEvent()
assert(#TestFrames == frameCount, "Event registration leaked frames")
TestEvent("UNIT_ENTERED_VEHICLE", "party1")
assert(count() == 0)
TestEvent("UNIT_ENTERED_VEHICLE", "player")
assert(count() == 1 and AprRC:GetLastStep().MountVehicle)
TestEvent("UNIT_EXITED_VEHICLE", "player")
assert(count() == 2 and AprRC:GetLastStep().VehicleExit)
AprRC.settings.profile.recordBarFrame.isRecording = false
TestHooks.SelectOption(100)
assert(count() == 2, "Gossip hook recorded while stopped")
fresh()
TestHooks.SelectOption(100)
TestHooks.SelectOption(100)
TestHooks.SelectOption(101)
assert(count() == 1 and #AprRC:GetLastStep().GossipOptionIDs == 2)
fresh()
local desired = false
C_PvP.IsWarModeDesired = function() return desired end
AprRC:ResetRecordingSession()
desired = true
TestEvent("WAR_MODE_STATUS_UPDATE", true)
TestEvent("WAR_MODE_STATUS_UPDATE", true)
assert(count() == 1 and AprRC:GetLastStep().WarMode)
fresh()
local bags = 10
GetMerchantNumItems = function() return 1 end
GetMerchantItemID = function(index) if index == 1 or index == 20 then return 123 end end
C_Item.GetItemCount = function() return bags end
C_MerchantFrame.GetItemInfo = function() return { stackCount = 5 } end
TestEvent("MERCHANT_SHOW")
TestHooks.BuyMerchantItem(20, 12)
assert(count() == 0, "Unconfirmed purchase was recorded")
bags = 22
TestEvent("BAG_UPDATE_DELAYED")
assert(count() == 1 and AprRC:GetLastStep().BuyMerchant[1].quantity == 12)
TestHooks.BuyMerchantItem(20)
bags = 27
TestEvent("BAG_UPDATE_DELAYED")
assert(AprRC:GetLastStep().BuyMerchant[1].quantity == 17)
TestHooks.BuyMerchantItem(20, 99)
TestEvent("BAG_UPDATE_DELAYED")
assert(AprRC:GetLastStep().BuyMerchant[1].quantity == 17, "Failed purchase changed quantity")
TestHooks.BuyMerchantItem(20, 10)
fresh()
bags = 37
TestEvent("BAG_UPDATE_DELAYED")
assert(count() == 0, "Pending purchase leaked into a new route")
fresh()
C_ChromieTime.GetChromieTimeExpansionOption = function() return { alreadyOn = true } end
TestHooks.SelectChromieTimeOption(99)
TestRunTimers()
assert(count() == 1 and AprRC:GetLastStep().ChromiePick == 99)
TestHooks.SelectChromieTimeOption(100)
fresh()
TestRunTimers()
assert(count() == 0, "Pending timeline selection leaked into another route")
local position = UnitPosition
UnitPosition = function() return nil end
C_Map.GetPlayerMapPosition = function() return {} end
C_Map.GetWorldPosFromMapPos = function() return 1, { GetXY = function() return 10.14, 20.26 end } end
local coord = AprRC:GetPlayerCoord()
assert(coord.x == 20.3 and coord.y == 10.1)
C_Map.GetWorldPosFromMapPos = function() return nil end
assert(AprRC:GetPlayerCoord() == nil)
assert(AprRC:IsCurrentStepFarAway())
UnitPosition = position
fresh()
AprRC:NewStep({ Note = "Test" })
AprRC:NewStep({ RouteCompleted = true })
AprRC:NewStep({ RouteCompleted = true })
assert(count() == 2)
AprRC:NewStep({ Note = "Resumed" })
assert(count() == 2 and not AprRC:GetLastStep().RouteCompleted)

-- Stable achievement IDs survive reordering; duplicate labels are not guessed.
fresh()
GetAchievementNumCriteria = function() return 2 end
GetAchievementCriteriaInfo = function(_, index)
    return index == 1 and "First" or "Second", 0, true, 1, 1, nil, nil, nil, "1/1", 100 + index
end
TestEvent("CRITERIA_EARNED", 42, "Second")
assert(count() == 1 and AprRC:GetLastStep().Achievement.criteriaID == 102)
assert(AprRC:GetLastStep().Achievement.criteriaIndex == nil)
TestEvent("CRITERIA_EARNED", 42, "Second")
assert(count() == 1)
TestEvent("ACHIEVEMENT_EARNED", 42)
assert(count() == 2 and AprRC:GetLastStep().Achievement.criteriaID == nil)
fresh()
GetAchievementCriteriaInfo = function(_, index)
    return "Identical", 0, true, 1, 1, nil, nil, nil, "1/1", 100 + index
end
TestEvent("CRITERIA_EARNED", 42, "Identical")
assert(count() == 0)

-- Opening a known taxi map must not record GetFP.
fresh()
GetTaxiMapID = function() return 13 end
C_TaxiMap = {
    GetAllTaxiNodes = function(mapID)
        assert(mapID == 13, "The taxi API needs the taxi map, not the player map")
        return { { nodeID = 100, name = "Start", slotIndex = 1, state = 0 },
            { nodeID = 200, name = "Destination", slotIndex = 2, state = 1 } }
    end
}
TestEvent("TAXIMAP_OPENED")
TestEvent("TAXIMAP_CLOSED")
assert(count() == 0)
TestEvent("TAXIMAP_OPENED")
assert(count() == 1 and AprRC:GetLastStep().GetFP == 100)
local clock = 10
GetTime = function() return clock end
UnitOnTaxi = function() return true end
TestHooks.TakeTaxiNode(2)
TestRunTimers()
local flight = AprRC:GetLastStep()
assert(flight.NodeID == 200 and flight.Name == "Destination")
AprRC:NewStep({ Note = "During the flight" })
clock = 90
TestEvent("PLAYER_CONTROL_GAINED")
assert(flight.ETA == 80 and AprRC:GetLastStep().ETA == nil)
fresh()
TestEvent("TAXIMAP_OPENED")
TestHooks.TakeTaxiNode(2)
fresh()
TestRunTimers()
assert(count() == 0)

-- Treasure presence alone does not imply that it was looted.
fresh()
local completed = false
C_QuestLog.IsQuestFlaggedCompleted = function() return completed end
C_VignetteInfo.GetVignettes = function() return { "treasure" } end
C_VignetteInfo.GetVignetteInfo = function() return { type = 3, onMinimap = true, rewardQuestID = 456 } end
C_VignetteInfo.GetVignettePosition = function() return {} end
C_Map.GetWorldPosFromMapPos = function() return 1, { GetXY = function() return 10, 20 end } end
TestEvent("VIGNETTES_UPDATED")
assert(count() == 0)
completed = true
TestEvent("QUEST_LOG_UPDATE")
TestEvent("VIGNETTES_UPDATED")
assert(count() == 1 and AprRC:GetLastStep().Treasure.questID == 456)
assert(AprRC:GetLastStep().Coord.x == 20)
C_VignetteInfo.GetVignettes = function() return {} end
C_QuestLog.IsQuestFlaggedCompleted = function() return false end

-- Objective retries must not append to a different recording.
fresh()
AprRC.lastQuestState = { [42] = {} }
C_QuestLog.GetQuestObjectives = function() return nil end
TestEvent("QUEST_WATCH_UPDATE", 42)
fresh()
C_QuestLog.GetQuestObjectives = function() return { { numFulfilled = 1, numRequired = 1, type = "monster" } } end
TestRunTimers()
assert(count() == 0)
AprRC:NewStep({ SetHS = 42 })
C_QuestLog.GetLogIndexForQuestID = function() return 1 end
GetQuestLogSpecialItemInfo = function() return "item:123:0" end
TestEvent("QUEST_WATCH_UPDATE", 42)
assert(count() == 2 and AprRC:GetLastStep().Qpart[42][1] == 1)
assert(AprRC:GetLastStep().Button["42-1"] == 123)

-- Match mob drops to the actual quest-starting item, not localized tooltip text.
fresh()
local owned = 0
C_Item.GetItemCount = function() return owned end
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return "item:123:0" end
GetLootSourceInfo = function() return "Creature-0-1-2-3-999-123456", 1 end
UnitGUID = function() return "Creature-0-1-2-3-999-123456" end
UnitName = function() return "Test mob" end
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
C_Container.GetContainerItemInfo = function() return { itemID = 123 } end
C_Container.GetContainerItemQuestInfo = function() return { questID = 777 } end
C_QuestLog.IsOnQuest = function() return false end
TestEvent("LOOT_OPENED")
owned = 1
TestEvent("BAG_UPDATE_DELAYED")
assert(count() == 1 and AprRC:GetLastStep().DroppableQuest.Qid == 777)
assert(AprRC:GetLastStep().DroppableQuest.MobId == 999)
C_QuestLog.IsWorldQuest = function() return false end
AprRC.saveQuestInfo = function() end
TestEvent("QUEST_ACCEPTED", 778)
assert(AprRCData.CurrentRoute.steps[1].DroppableQuest.Qid == 777)
assert(AprRC:GetLastStep().PickUp[1] == 778)

-- Uncached item spells are loaded without ever emitting itemSpellID = 0.
fresh()
local itemLoaded = false
C_Item.GetItemSpell = function() if itemLoaded then return "Use", 321 end end
C_Item.RequestLoadItemDataByID = function() itemLoaded = true end
AprRC:RecordUseItem(42, 123)
assert(count() == 0)
TestRunTimers()
assert(count() == 1 and AprRC:GetLastStep().UseItem.itemSpellID == 321)
itemLoaded = false
AprRC:RecordUseItem(42, 124)
fresh()
TestRunTimers()
assert(count() == 0)
