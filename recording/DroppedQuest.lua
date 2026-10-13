local context, pending = nil, {}

function AprRC:FindDroppedQuestStep(questID)
    for index = #AprRCData.CurrentRoute.steps, 1, -1 do
        local step = AprRCData.CurrentRoute.steps[index]
        if step.DroppableQuest and step.DroppableQuest.Qid == questID then return step end
    end
end

local function captureLoot()
    if not context or not AprRC:IsRecordingContext(context) then
        context, pending = AprRC:CaptureRecordingContext(), {}
    end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        local sources = { GetLootSourceInfo(slot) }
        local source = sources[1]
        local mobID = source and tonumber(source:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        -- LOOT_READY precedes autoloot. Do not replace its inventory snapshot at
        -- LOOT_OPENED, or forget unresolved quest items when another corpse opens.
        if itemID and mobID and not pending[itemID] then
            local name = "NPC " .. mobID
            if UnitGUID("target") == source then name = UnitName("target") or name end
            local position = {}
            AprRC:SetStepCoord(position)
            pending[itemID] = { mobID = mobID, name = name, position = position,
                count = C_Item.GetItemCount(itemID, false, false, false, false) }
        end
    end
end

local function recordDroppedItem(itemID, entry, questID)
    if not AprRC:FindDroppedQuestStep(questID) then
        local step = entry.position
        step.DroppableQuest = { Qid = questID, MobId = entry.mobID, Text = entry.name }
        AprRC:NewStep(step)
    end
    pending[itemID] = nil
end

local function recordBagItems(acceptedQuestID)
    if not context or not AprRC:IsRecordingContext(context) then pending = {}; return end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            local entry = item and pending[item.itemID]
            if entry then
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                local questID = quest and quest.questID
                -- QUEST_ACCEPTED may arrive before BAG_UPDATE_DELAYED, with the
                -- quest already in the log. Permit that exact quest to resolve.
                if questID and questID > 0 and (questID == acceptedQuestID or not C_QuestLog.IsOnQuest(questID))
                    and not C_QuestLog.IsQuestFlaggedCompleted(questID)
                    and C_Item.GetItemCount(item.itemID, false, false, false, false) > entry.count then
                    recordDroppedItem(item.itemID, entry, questID)
                end
            end
        end
    end
end

local function recordQuestDetails(itemID)
    if not context or not AprRC:IsRecordingContext(context) then pending = {}; return end
    local entry = itemID and pending[itemID]
    if not entry or C_Item.GetItemCount(itemID, false, false, false, false) <= entry.count then return end
    -- Container metadata can omit questID. QUEST_DETAIL identifies the actual
    -- quest-starting item, so no tooltip text or nearby NPC guess is required.
    local questID = GetQuestID()
    if questID and questID > 0 and not C_QuestLog.IsQuestFlaggedCompleted(questID) then
        recordDroppedItem(itemID, entry, questID)
    end
end

function AprRC:ResolveDroppedQuestStep(questID)
    local step = self:FindDroppedQuestStep(questID)
    if step then return step end
    local ok, reason = pcall(recordBagItems, questID)
    if not ok then self:Debug("Dropped quest detection unavailable", reason) end
    return self:FindDroppedQuestStep(questID)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("QUEST_DETAIL")
frame:SetScript("OnEvent", function(_, event, itemID)
    if not AprRC:IsRecordingContext() then context, pending = nil, {}; return end
    local callback = recordBagItems
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        callback = captureLoot
    elseif event == "QUEST_DETAIL" then
        callback = recordQuestDetails
    end
    local ok, reason = pcall(callback, itemID)
    if not ok then AprRC:Debug("Dropped quest detection unavailable", reason) end
end)
