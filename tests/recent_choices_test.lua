local recent = AprRC.recentChoices
local saved, oldTime, oldGetTime = AprRCRecentChoices, time, GetTime
local oldSecret, oldSpell = issecretvalue, C_Item.GetItemSpell
local oldSlots, oldItem, oldEquipped = C_Container.GetContainerNumSlots, C_Container.GetContainerItemID, GetInventoryItemID
local enabled, recording = AprRC.settings.profile.enableAddon, AprRC.settings.profile.recordBarFrame.isRecording
local now = 1000000
time = function() return now end
GetTime = function() return now end
recent:Clear()

-- A repeated choice moves to the front even within the same second.
for id = 1, 30 do recent:Remember("spell", id) end
assert(#recent:Get("spell") == 20 and recent:Get("spell")[1].id == 30)
recent:Remember("spell", 15)
assert(#recent:Get("spell") == 20 and recent:Get("spell")[1].id == 15)
assert(recent:Get("spell")[20].id == 11)
recent:Remember("item", 501)
assert(#recent:Get("item") == 1 and #recent:Get("spell") == 20)
for _, id in ipairs({ 0, -1, 1.5, math.huge, "42", {} }) do recent:Remember("item", id) end
assert(#recent:Get("item") == 1)
local secret = {}
issecretvalue = function(value) return value == secret end
recent:Remember("spell", secret)
assert(#recent:Get("spell") == 20)

-- Expiration, malformed saved data and extra fields cannot grow the saved history.
now = now + recent.maxAge
recent:OnEvent("PLAYER_LOGIN")
assert(#recent:Get("item") == 0 and #recent:Get("spell") == 0)
AprRCRecentChoices = { item = {
    { id = 10, usedAt = now - 2, junk = "discard" }, { id = 10, usedAt = now - 1 },
    { id = 11, usedAt = now + 1 }, { id = -1, usedAt = now }, { id = 12 }, "broken",
}, spell = "broken", junk = {} }
recent:Prune()
assert(#AprRCRecentChoices.item == 1 and AprRCRecentChoices.item[1].usedAt == now - 1)
assert(not AprRCRecentChoices.item[1].junk and not AprRCRecentChoices.junk)
recent:Clear("item")

-- Successful player casts are remembered even while recording is paused.
AprRC.settings.profile.enableAddon = true
AprRC.settings.profile.recordBarFrame.isRecording = false
local bagItem = 501
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
C_Container.GetContainerItemID = function() return bagItem end
C_Item.GetItemSpell = function(id) return "Item effect", id == 501 and 601 or 602 end
GetInventoryItemID = function() end
recent:OnEvent("BAG_UPDATE_DELAYED")
recent:OnEvent("UNIT_SPELLCAST_SENT", "player", "", "cast1", 601)
bagItem = nil -- Last consumable disappears before success arrives.
recent:OnEvent("BAG_UPDATE_DELAYED")
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 601)
assert(recent:Get("spell")[1].id == 601 and recent:Get("item")[1].id == 501)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast2", 602)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", secret, "cast2", 602)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", secret)
assert(#recent:Get("spell") == 1)

-- Failed attempts and mismatched casts must not become recent items.
recent:Clear()
bagItem = 501
recent:OnEvent("BAG_UPDATE_DELAYED")
recent:OnEvent("UNIT_SPELLCAST_SENT", "player", "", "failed", 601)
assert(#recent:Get("item") == 0 and #recent:Get("spell") == 0)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "another-cast", 601)
assert(#recent:Get("item") == 0)

-- Equipped items work; ambiguous shared item spells do not guess an item ID.
bagItem = nil
GetInventoryItemID = function(_, slot) return slot == 13 and 502 or nil end
recent:OnEvent("PLAYER_EQUIPMENT_CHANGED")
recent:OnEvent("UNIT_SPELLCAST_SENT", "player", "", "equipped", 602)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "equipped", 602)
assert(recent:Get("item")[1].id == 502)
recent:Clear()
bagItem = 503
recent:OnEvent("BAG_UPDATE_DELAYED")
recent:OnEvent("UNIT_SPELLCAST_SENT", "player", "", "ambiguous", 602)
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "ambiguous", 602)
assert(#recent:Get("item") == 0)
AprRC.settings.profile.enableAddon = false
recent:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "disabled", 603)
assert(#recent:Get("spell") == 1)

-- Logout also purges old entries before persistence.
now = now + recent.maxAge
recent:OnEvent("PLAYER_LOGOUT")
assert(#recent:Get("spell") == 0)
AprRCRecentChoices, time, GetTime = saved, oldTime, oldGetTime
issecretvalue, C_Item.GetItemSpell = oldSecret, oldSpell
C_Container.GetContainerNumSlots, C_Container.GetContainerItemID, GetInventoryItemID = oldSlots, oldItem, oldEquipped
AprRC.settings.profile.enableAddon, AprRC.settings.profile.recordBarFrame.isRecording = enabled, recording
print("Recent choices: bounded history, ordering, expiration, player casts, consumed/equipped items and secret values passed.")
