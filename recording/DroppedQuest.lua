local context, pending = nil, {}

local function captureLoot()
    context, pending = AprRC:CaptureRecordingContext(), {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        local sources = { GetLootSourceInfo(slot) }
        local source = sources[1]
        local mobID = source and tonumber(source:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        if itemID and mobID then
            local name = "NPC " .. mobID
            if UnitGUID("target") == source then name = UnitName("target") or name end
            local position = {}
            AprRC:SetStepCoord(position)
            pending[itemID] = { mobID = mobID, name = name, position = position,
                count = C_Item.GetItemCount(itemID, false, false, false, false) }
        end
    end
end

local function recordBagItems()
    if not context or not AprRC:IsRecordingContext(context) then pending = {}; return end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            local entry = item and pending[item.itemID]
            if entry then
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                local questID = quest and quest.questID
                if questID and questID > 0 and not C_QuestLog.IsOnQuest(questID)
                    and not C_QuestLog.IsQuestFlaggedCompleted(questID)
                    and C_Item.GetItemCount(item.itemID, false, false, false, false) > entry.count then
                    local step = entry.position
                    step.DroppableQuest = { Qid = questID, MobId = entry.mobID, Text = entry.name }
                    AprRC:NewStep(step)
                    pending[item.itemID] = nil
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event)
    if not AprRC:IsRecordingContext() then context, pending = nil, {}; return end
    local ok, reason = pcall(event == "LOOT_OPENED" and captureLoot or recordBagItems)
    if not ok then AprRC:Debug("Dropped quest detection unavailable", reason) end
end)
