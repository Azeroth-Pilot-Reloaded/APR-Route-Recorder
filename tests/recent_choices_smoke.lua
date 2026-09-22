local A, recent = AprRC.autocomplete, AprRC.recentChoices
local GUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local saved, oldTimer = AprRCRecentChoices, C_Timer.NewTimer
local oldInfo, oldSlots, oldItem = C_Spell.GetSpellInfo, C_Container.GetContainerNumSlots, C_Item.GetItemInfo
local timers = {}
C_Timer.NewTimer = function(_, callback)
    local timer = { callback = callback, Cancel = function(self) self.cancelled = true end }
    timers[#timers + 1] = timer
    return timer
end
local function flush()
    while #timers > 0 do
        local pending = timers; timers = {}
        for _, timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
    end
end
local function children(frame, widgetType)
    local result = {}
    local function walk(widget)
        if widget.type == widgetType then result[#result + 1] = widget end
        for _, child in ipairs(widget.children or {}) do walk(child) end
    end
    walk(frame)
    return result
end
local function button(frame, label)
    for _, widget in ipairs(children(frame, "Button")) do
        if widget.text:GetText() == label then return widget end
    end
    error("Missing button " .. label)
end
local function input(frame, text)
    local box = children(frame, "EditBox")[1]
    box:SetText(text); box:Fire("OnTextChanged", text)
end
recent:Clear()
C_Spell.GetSpellInfo = function(id)
    if id == 999 then return nil end
    return { name = "Spell " .. id, iconID = 123 }
end
recent:Remember("spell", 601) -- Also in spellbook: only one row should be shown.
recent:Remember("spell", 777) -- Outside spellbook: still offered first.
local chosen
local frame = A:ShowSpellAutoComplete(nil, nil, function(_, key, window)
    chosen = tonumber(key); window:Hide()
end)
flush()
local scroll = children(frame, "ScrollFrame")[1]
assert(scroll.children[1].type == "Heading" and scroll.children[1].label:GetText() == L["Recent spells"])
local rows = children(frame, "InteractiveLabel")
assert(#rows == 2 and rows[1].label:GetText():find("Spell 777", 1, true))
assert(rows[2].label:GetText():find("Spell 601", 1, true))
rows[2]:Fire("OnClick")
assert(recent:Get("spell")[1].id == 777, "Only confirmed choices enter history")
button(frame, L["Confirm"]):Fire("OnClick")
assert(chosen == 601 and recent:Get("spell")[1].id == 601)

-- ID and name searches filter both sections, with recent rows first.
recent:Clear("spell")
recent:Remember("spell", 777)
frame = A:ShowSpellAutoComplete(nil, nil, function() end)
flush()
assert(#children(frame, "Heading") == 2)
input(frame, "777"); flush()
assert(#children(frame, "InteractiveLabel") == 1 and #children(frame, "Heading") == 1)
input(frame, "Test spell"); flush()
assert(#children(frame, "InteractiveLabel") == 1 and #children(frame, "Heading") == 0)
input(frame, "No matching spell"); flush()
assert(#children(frame, "InteractiveLabel") == 0)
frame:Hide()

-- Missing item/spell cache data falls back to IDs, including consumed items.
C_Container.GetContainerNumSlots = function() return 0 end
C_Item.GetItemInfo = function() end
recent:Remember("item", 888)
frame = A:ShowItemAutoComplete(nil, nil, function(_, key, window)
    chosen = tonumber(key); window:Hide()
end)
flush()
rows = children(frame, "InteractiveLabel")
assert(#rows == 1 and rows[1].label:GetText():find("888", 1, true))
rows[1]:Fire("OnClick"); button(frame, L["Confirm"]):Fire("OnClick")
assert(chosen == 888)

-- Manual clearing affects only this kind; a typed ID is remembered on confirm.
frame = A:ShowItemAutoComplete(nil, nil, function(_, key, window)
    chosen = tonumber(key); window:Hide()
end)
flush()
button(frame, L["Clear recent history"]):Fire("OnClick"); flush()
assert(#recent:Get("item") == 0 and #recent:Get("spell") == 1)
assert(#children(frame, "InteractiveLabel") == 0)
input(frame, "889"); button(frame, L["Confirm"]):Fire("OnClick")
assert(chosen == 889 and recent:Get("item")[1].id == 889)
frame = A:ShowSpellAutoComplete(nil, nil, function() return false end)
input(frame, "999"); button(frame, L["Confirm"]):Fire("OnClick")
assert(#recent:Get("spell") == 1, "Rejected selections must not enter history")
frame:Hide()

-- Changing the query, selecting or closing cancels delayed chunk rendering.
recent:Clear("spell")
for id = 900, 919 do recent:Remember("spell", id) end
frame = A:ShowSpellAutoComplete(nil, nil, function() end)
local first = table.remove(timers, #timers)
first.callback() -- First chunk, remaining chunks are still pending.
assert(#children(frame, "InteractiveLabel") == 9)
input(frame, "919"); flush()
assert(#children(frame, "InteractiveLabel") == 1)
input(frame, ""); flush()
children(frame, "InteractiveLabel")[1]:Fire("OnClick"); flush()
assert(#children(frame, "InteractiveLabel") == 0)
input(frame, ""); frame:Hide(); flush()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))

AprRCRecentChoices, C_Timer.NewTimer = saved, oldTimer
C_Spell.GetSpellInfo, C_Container.GetContainerNumSlots, C_Item.GetItemInfo = oldInfo, oldSlots, oldItem
print("Recent picker sections: order, deduplication, search, manual IDs, clearing and timer cancellation passed.")
