-- Only record nearby treasure vignettes whose character reward quest becomes completed.
local context, tracked = nil, {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("VIGNETTES_UPDATED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("LOOT_CLOSED")
frame:SetScript("OnEvent", function()
    if not AprRC:IsRecordingContext() then context, tracked = nil, {}; return end
    if not context or not AprRC:IsRecordingContext(context) then
        context, tracked = AprRC:CaptureRecordingContext(), {}
    end
    for questID, entry in pairs(tracked) do
        if not entry.recorded and C_QuestLog.IsQuestFlaggedCompleted(questID) then
            entry.recorded = true
            local step = AprRC:CopyData(entry.position)
            step.Treasure = { questID = questID }
            AprRC:NewStep(step)
        end
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    for _, guid in ipairs(C_VignetteInfo.GetVignettes()) do
        local info = C_VignetteInfo.GetVignetteInfo(guid)
        if info and info.type == Enum.VignetteType.Treasure and info.onMinimap and info.rewardQuestID > 0
            and not tracked[info.rewardQuestID] and not C_QuestLog.IsQuestFlaggedCompleted(info.rewardQuestID) then
            local position = {}
            local mapPosition = C_VignetteInfo.GetVignettePosition(guid, mapID)
            local _, world
            if mapPosition then _, world = C_Map.GetWorldPosFromMapPos(mapID, mapPosition) end
            if world then
                local x, y = world:GetXY()
                position.Coord = { x = tonumber(string.format("%.1f", y)), y = tonumber(string.format("%.1f", x)) }
                position.Zone = mapID
            else
                AprRC:SetStepCoord(position)
            end
            tracked[info.rewardQuestID] = { position = position }
        end
    end
end)
