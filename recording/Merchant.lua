-- Observe actual purchases, including merchant pages and stack-split purchases.
local context, inventory, pending = nil, {}, {}

local function itemCount(itemID)
    return C_Item.GetItemCount(itemID, false, false, false, false)
end

local function snapshot()
    context, inventory, pending = AprRC:CaptureRecordingContext(), {}, {}
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        if itemID then inventory[itemID] = itemCount(itemID) end
    end
end

function AprRC:RecordMerchantPurchase(itemID, quantity, coord)
    local step = self:GetLastStep()
    if not step.BuyMerchant or self:IsCurrentStepFarAway() then
        step = self:CopyData(coord)
        step.BuyMerchant = {}
        self:NewStep(step)
    end
    for _, item in ipairs(step.BuyMerchant) do
        if item.itemID == itemID then item.quantity = item.quantity + quantity; return end
    end
    local questID = self:FindClosestIncompleteQuest()
    step.BuyMerchant[#step.BuyMerchant + 1] = { itemID = itemID, quantity = quantity, questID = questID }
    self:ApplyCampaignQuestFlag(step, questID)
end

hooksecurefunc("BuyMerchantItem", function(index, quantity)
    if not context or not AprRC:IsRecordingContext(context) then return end
    local itemID = GetMerchantItemID(index)
    local info = C_MerchantFrame.GetItemInfo(index)
    if not itemID or not info or inventory[itemID] == nil then return end
    quantity = quantity or info.stackCount
    if not quantity or quantity <= 0 then return end
    local entry = pending[itemID]
    if not entry then
        local coord = {}
        AprRC:SetStepCoord(coord)
        entry = { before = inventory[itemID], quantity = 0, coord = coord }
        pending[itemID] = entry
    end
    entry.quantity = entry.quantity + quantity
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        if AprRC:IsRecordingContext() then snapshot() end
    elseif not context or not AprRC:IsRecordingContext(context) then
        context, inventory, pending = nil, {}, {}
    else
        for itemID, entry in pairs(pending) do
            local current = itemCount(itemID)
            local gained = math.min(current - entry.before, entry.quantity)
            if gained > 0 then AprRC:RecordMerchantPurchase(itemID, gained, entry.coord) end
            inventory[itemID] = current
        end
        pending = {}
        for itemID in pairs(inventory) do inventory[itemID] = itemCount(itemID) end
    end
end)
