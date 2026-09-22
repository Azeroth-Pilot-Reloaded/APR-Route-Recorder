-- Small, per-character history shared by all item/spell selectors.
local Recent = { limit = 20, maxAge = 7 * 24 * 60 * 60 }
AprRC.recentChoices = Recent

local function public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return nil end
    return value
end

local function validID(id)
    id = public(id)
    return type(id) == "number" and id > 0 and id < math.huge and id == math.floor(id)
end

function Recent:Prune()
    local now = time()
    local saved = type(AprRCRecentChoices) == "table" and AprRCRecentChoices or {}
    local cleaned = {}
    for _, kind in ipairs({ "item", "spell" }) do
        local entries, seen = {}, {}
        for index, entry in ipairs(type(saved[kind]) == "table" and saved[kind] or {}) do
            if type(entry) == "table" and validID(entry.id) and type(entry.usedAt) == "number"
                and entry.usedAt <= now and entry.usedAt > now - self.maxAge then
                entries[#entries + 1] = { id = entry.id, usedAt = entry.usedAt, order = index }
            end
        end
        table.sort(entries, function(a, b)
            if a.usedAt == b.usedAt then return a.order < b.order end
            return a.usedAt > b.usedAt
        end)
        cleaned[kind] = {}
        for _, entry in ipairs(entries) do
            if not seen[entry.id] and #cleaned[kind] < self.limit then
                seen[entry.id] = true
                cleaned[kind][#cleaned[kind] + 1] = { id = entry.id, usedAt = entry.usedAt }
            end
        end
    end
    AprRCRecentChoices = cleaned
end

function Recent:Get(kind)
    self:Prune()
    return AprRCRecentChoices[kind] or {}
end

function Recent:Remember(kind, id)
    if (kind ~= "item" and kind ~= "spell") or not validID(id) then return end
    local entries = self:Get(kind)
    for index = #entries, 1, -1 do
        if entries[index].id == id then table.remove(entries, index) end
    end
    table.insert(entries, 1, { id = id, usedAt = time() })
    while #entries > self.limit do table.remove(entries) end
end

function Recent:Clear(kind)
    self:Prune()
    if kind then AprRCRecentChoices[kind] = {} else AprRCRecentChoices = {} end
end

-- Cache only items currently carried/equipped, not every item ever encountered.
-- Snapshot the candidate at cast start so consuming the last item still works.
local itemSpells, inventoryDirty, pending = {}, true, nil
function Recent:RefreshInventory()
    itemSpells = {}
    local seen = {}
    local function add(id)
        id = public(id)
        if not validID(id) or seen[id] then return end
        seen[id] = true
        local _, spellID = C_Item.GetItemSpell(id)
        spellID = public(spellID)
        if validID(spellID) then
            -- Different items can share a spell: do not guess which one was used.
            if itemSpells[spellID] == nil then itemSpells[spellID] = id
            elseif itemSpells[spellID] ~= id then itemSpells[spellID] = false end
        end
    end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, public(C_Container.GetContainerNumSlots(bag)) or 0 do
            add(C_Container.GetContainerItemID(bag, slot))
        end
    end
    if GetInventoryItemID then
        for slot = 1, 19 do add(GetInventoryItemID("player", slot)) end
    end
    inventoryDirty = false
end

function Recent:OnEvent(event, unit, target, castGUID, spellID)
    if event == "PLAYER_LOGIN" or event == "PLAYER_LOGOUT" then
        self:Prune()
        inventoryDirty, pending = true, nil
        return
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "ITEM_DATA_LOAD_RESULT" then
        inventoryDirty = true
        return
    end
    if not AprRC.settings.profile.enableAddon or public(unit) ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        if inventoryDirty then self:RefreshInventory() end
        spellID, castGUID = public(spellID), public(castGUID)
        pending = validID(spellID) and { spellID = spellID, castGUID = castGUID,
            itemID = itemSpells[spellID], started = GetTime() } or nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- SUCCEEDED has no target argument, unlike SENT.
        spellID, castGUID = public(castGUID), public(target)
        if not validID(spellID) then return end
        self:Remember("spell", spellID)
        if pending and pending.spellID == spellID and pending.castGUID == castGUID
            and GetTime() - pending.started < 120 then
            self:Remember("item", pending.itemID)
            pending = nil
        end
    end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...) Recent:OnEvent(event, ...) end)
