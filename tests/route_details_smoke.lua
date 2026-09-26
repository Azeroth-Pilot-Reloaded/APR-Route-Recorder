local E, UI, Model = AprRC.routeEditor, AprRC.editorUI, AprRC.editorModel
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end
local function field(path)
    return assert(find(E.inspector, function(w) return w:GetUserData("fieldPath") == path end), path)
end
local function enter(path, value)
    local edit = field(path)
    edit:SetText(value); edit:Fire("OnTextChanged", value)
end
local function answer(text)
    assert(find(E.confirm, function(w) return w.type == "Button" and w.text:GetText() == UI.Text(text) end)):Fire("OnClick")
end
local oldItemInfo, oldSpell = C_Item.GetItemInfo, C_Spell
C_Item.GetItemInfo = function(id)
    if id == 404 then return end
    return "Item " .. id, nil, nil, nil, nil, nil, nil, nil, nil, 12345
end
C_Spell = { GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = 54321 } end }
local route = assert(Model:NewRoute("Route details"))
route.steps = { { LootMoney = { copper = 123456 }, Money = { copper = 20304, operator = "<" },
    AllOf = { { Not = { Money = { copper = 10203 } } } } } }
route.parallelSteps = { { conditions = { AnyOf = { { Money = { copper = 34567 } } } },
    steps = { { BankDeposit = { items = { 12, 34 } } } } } }
E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
assert(field("step/LootMoney/copper/gold"):GetText() == "12")
assert(field("step/LootMoney/copper/silver"):GetText() == "34")
assert(field("step/LootMoney/copper/copper"):GetText() == "56")
enter("step/LootMoney/copper/gold", "2")
enter("step/LootMoney/copper/silver", "3")
enter("step/LootMoney/copper/copper", "4")
assert(E.session.draft.steps[1].LootMoney.copper == 20304)
assert(E.stepDescription.label:GetText():find("2|TInterface", 1, true), "Inspector subtitle should update while typing")
assert(route.steps[1].LootMoney.copper == 123456, "Money edits must remain in the draft")
enter("step/Money/copper/gold", "0")
enter("step/Money/copper/silver", "0")
enter("step/Money/copper/copper", "0")
assert(E.session.draft.steps[1].Money.copper == 0)
enter("step/LootMoney/copper/copper", "-1")
assert(not E.session:Read(), "Negative components must block saving")
enter("step/LootMoney/copper/copper", "1.5")
assert(not E.session:Read(), "Fractional coins must block saving")
enter("step/LootMoney/copper/copper", "abc")
assert(not E.session:Read(), "Invalid components must block saving")
enter("step/LootMoney/copper/copper", "104")
assert(E.session.draft.steps[1].LootMoney.copper == 20404, "Copper overflow must convert correctly")
enter("step/AllOf/1/Not/Money/copper/silver", "5")
assert(E.session.draft.steps[1].AllOf[1].Not.Money.copper == 10503)
E:SelectTab("parallel"); E.groupConditions:Fire("OnClick")
enter("route/parallelSteps/1/conditions/AnyOf/1/Money/copper/gold", "7")
assert(E.session.draft.parallelSteps[1].conditions.AnyOf[1].Money.copper == 74567)
assert(E.session:Save())
E:SelectTab("steps")
assert(field("step/LootMoney/copper/silver"):GetText() == "4")
assert(field("step/LootMoney/copper/copper"):GetText() == "4")

local examples = {
    { "DestroyItems", { items = { 12, 34 } }, "Item 12", "Item 34", "|T12345:" },
    { "BankDeposit", { items = { 12, 34 } }, "Item 12", "Item 34" },
    { "BankWithdraw", { items = { 12, 34 } }, "Item 12", "Item 34" },
    { "ItemCount", { itemIDs = { 12, 34 }, count = 3 }, "Item 12", "Item 34", ">= 3" },
    { "Collection", { itemID = 12, quantity = 4 }, "Item 12", "4" },
    { "EquippedItem", { slot = 16, itemID = 12 }, "Item 12", "|T12345:" },
    { "Skill", { skill = "cooking", rank = 50 }, "Spell 2550", "|T54321:", ">= 50" },
    { "Skill", { skillID = 185, rank = 50 }, "Spell 2550" },
    { "LearnSkill", { spellIDs = { 100, 6673 } }, "Spell 100", "Spell 6673" },
    { "LootMoney", { copper = 123456 }, "12|TInterface", "34|TInterface", "56|TInterface" },
    { "Money", { copper = 20304, operator = "<" }, "< 2|TInterface", "3|TInterface", "4|TInterface" },
}
for _, example in ipairs(examples) do
    local step = { [example[1]] = example[2], ExtraLineText = "Keep this note" }
    local before = AprRC:SerializeData(step)
    local _, detail = Model:Summary(step)
    for i = 3, #example do assert(detail:find(example[i], 1, true), example[1] .. ": " .. detail) end
    assert(detail:find("Keep this note", 1, true))
    assert(before == AprRC:SerializeData(step))
end
assert(Model:ItemText(404):find("#404", 1, true), "Uncached items need a readable fallback")
assert(UI.Form:Summary(AprRC.options.schemas.money, { copper = 12345 }):find("GoldIcon", 1, true))
assert(Model:Filter({ { BankDeposit = { items = { 12, 34 } } } }, "Item 34", "all")[1] == 1)

local row = AprRC:CreateWidget("APRStepRow")
row:SetWidth(260)
row:SetStep(1, "Items", string.rep("Long item name, ", 25), "", 12345, false, { 1, 1, 1 })
assert(row.frame:GetHeight() > 72, "Long descriptions must wrap instead of hiding the item list")
LibStub("AceGUI-3.0"):Release(row)

-- Toolbar/slash-command dialogs must expose the same fields and stored copper.
for _, key in ipairs({ "Money", "LootMoney" }) do
    local applied
    local definition = AprRC.options.step[key]
    local dialog = AprRC.options:ShowInput(definition, { Money = { copper = 12345 } }, route, function(text)
        applied = AprRC.options:Parse(definition, text)
        return applied ~= nil
    end)
    local edit = assert(find(dialog, function(w) return w:GetUserData("fieldPath") == "command/" .. key .. "/copper/gold" end))
    edit:SetText("9"); edit:Fire("OnTextChanged", "9")
    assert(find(dialog, function(w) return w.type == "Button" and w.text:GetText() == UI.Text("Apply") end)):Fire("OnClick")
    assert(applied.copper == (key == "Money" and 92345 or 90010))
end

-- Delayed item data refreshes names without discarding the current draft.
E.session.draft.steps[1].DestroyItems = { items = { 404 } }
E:Changed()
local pendingDraft = AprRC:SerializeData(E.session.draft)
C_Item.GetItemInfo = function(id) return "Item " .. id, nil, nil, nil, nil, nil, nil, nil, nil, 12345 end
TestEvent("GET_ITEM_INFO_RECEIVED", 404, true)
assert(E.descriptionsDirty)
LibStub("AceGUI-3.0"):ClearFocus()
E:Refresh()
assert(not E.descriptionsDirty and AprRC:SerializeData(E.session.draft) == pendingDraft)
assert(Model:FieldSummary("DestroyItems", { items = { 404 } }):find("Item 404", 1, true))

-- Cancellation, route switching, active recording, drafts and pending publication.
AprRC:FlushAPRRouteSync()
local aprKey = AprRCData.APRRouteKeys[route.name]
assert(APRData.CustomRoute[aprKey])
E:DeleteRoute(); answer(CANCEL)
assert(AprRC:FindRouteByName(route.name))
local other = assert(Model:NewRoute("Keep route"))
E:DeleteRoute(); E:SelectRoute(other.name); answer(YES)
assert(AprRC:FindRouteByName(route.name), "Confirmation must not delete after changing selection")
E:SelectRoute(route.name)
enter("step/LootMoney/copper/gold", "8")
assert(AprRCData.EditorDrafts[route.name])
AprRCData.CurrentRoute = route
AprRC.settings.profile.recordBarFrame.isRecording = true
local recordingContext = AprRC:CaptureRecordingContext()
AprRC:RequestAPRRouteSync(route.name)
E.deleteRouteButton:Fire("OnClick")
assert(AprRC:FindRouteByName(route.name) and E.confirm, "Delete must wait for confirmation")
answer(YES)
assert(not AprRC:FindRouteByName(route.name))
assert(not AprRCData.EditorDrafts[route.name] and not AprRCData.QuestLookup[route.name])
assert(not AprRC.settings.profile.recordBarFrame.isRecording and not AprRC:IsRecordingContext(recordingContext))
assert(AprRCData.CurrentRoute.name == "")
assert(not AprRCData.APRRouteKeys[route.name] and not APRData.CustomRoute[aprKey] and not APR.RouteQuestStepList[aprKey])
AprRC:FlushAPRRouteSync()
assert(not APRData.CustomRoute[aprKey], "Queued sync must not resurrect the route")
assert(AprRC:FindRouteByName(other.name))
local recreated = assert(Model:NewRoute("Route details"))
E:SelectRoute(recreated.name)
assert(#E.session.draft.steps == 0, "Deleted sessions must not reappear when reusing a name")
local savedRoutes = AprRCData.Routes
AprRCData.Routes = { recreated }
E:RefreshRoutes(); E:DeleteRoute(); answer(YES)
assert(not E.session and E.deleteRouteButton.disabled and E.saveButton.disabled)
assert(#AprRCData.Routes == 0)
AprRCData.Routes = savedRoutes
table.remove(savedRoutes, #savedRoutes)
E:Hide()
C_Item.GetItemInfo, C_Spell = oldItemInfo, oldSpell
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Money conversion, nested conditions, item/skill descriptions and confirmed route deletion passed.")
