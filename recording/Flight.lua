local selected, active
local boats = { 2052, 2053, 2054, 2055, 2056, 2057, 2104, 2105 }

hooksecurefunc("TakeTaxiNode", function(slotIndex)
    if not AprRC:IsRecordingContext() then return end
    local nodes = AprRC.CurrentTaxiNodes or {}
    for _, node in ipairs(nodes) do
        if node.slotIndex == slotIndex then
            local step = { UseFlightPath = AprRC:FindClosestIncompleteQuest(), NodeID = node.nodeID, Name = node.name }
            local source = AprRC.CurrentTaxiNode and AprRC.CurrentTaxiNode.nodeID
            if tContains(boats, source) or tContains(boats, node.nodeID) then step.Boat = true end
            AprRC:SetStepCoord(step)
            selected = { context = AprRC:CaptureRecordingContext(), step = step }
            AprRC:RecordFlightControl("PLAYER_CONTROL_LOST")
            return
        end
    end
end)

function AprRC:RecordFlightControl(event)
    if event == "PLAYER_CONTROL_LOST" then
        local candidate = selected
        selected = nil
        if not candidate then return end
        local started = GetTime()
        C_Timer.After(0.2, function()
            if not self:IsRecordingContext(candidate.context) or not UnitOnTaxi("player") then return end
            candidate.started = started
            self:ApplyCampaignQuestFlag(candidate.step, candidate.step.UseFlightPath)
            self:NewStep(candidate.step)
            active = candidate
        end)
    elseif active then
        if self:IsRecordingContext(active.context) then
            active.step.ETA = math.max(1, math.floor(GetTime() - active.started))
        end
        active = nil
    end
end
