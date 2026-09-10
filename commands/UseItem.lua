function AprRC:RecordUseItem(questID, itemID, onRecorded)
    local context = self:CaptureRecordingContext()
    local position = {}
    self:SetStepCoord(position)
    local attempts = 0
    local function resolve()
        if not self:IsRecordingContext(context) then return end
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID and spellID > 0 then
            position.UseItem = { questID = questID, itemID = itemID, itemSpellID = spellID }
            self:ApplyCampaignQuestFlag(position, questID)
            self:NewStep(position)
            if onRecorded then onRecorded() end
        elseif attempts < 10 then
            attempts = attempts + 1
            C_Item.RequestLoadItemDataByID(itemID)
            C_Timer.After(0.2, resolve)
        else
            APR:PrintError("This item has no available use spell. Supply a verified itemSpellID with /aprrc useitem.")
        end
    end
    resolve()
end
