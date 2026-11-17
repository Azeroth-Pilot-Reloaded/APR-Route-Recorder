local E, UI, R, Model = AprRC.routeEditor, AprRC.editorUI, AprRC.options, AprRC.editorModel
local function find(widget, path)
    if widget:GetUserData("fieldPath") == path then return widget end
    for _, child in ipairs(widget.children or {}) do
        local found = find(child, path)
        if found then return found end
    end
end
local function edit(parent, path, text)
    local widget = assert(find(parent, path), path)
    widget:SetText(text); widget:Fire("OnTextChanged", text)
end
local function form(schema, value, path, callback)
    local parent = AprRC:CreateWidget("SimpleGroup")
    local context = { modes = {}, pages = {}, inlineSections = true, changed = function() end,
        redraw = function() end, error = function(message) error(message) end }
    UI.Form:Render(parent, schema, value, callback, context, path, path)
    return parent
end

local route = assert(Model:NewRoute("Latest wiki UI"))
route.steps = { { Note = "Main" }, { RouteCompleted = true } }
local session = Model:Open(route)
assert(session:Insert({ RouteCompleted = true, IsQuestCompleted = 42 }, 0))
assert(session:Move(1, 2), "An early conditional marker may move among ordinary steps")
assert(not session:Move(2, 3), "The final completion marker must stay last")
assert(session:Read())

local goal = { skillID = 185, rank = 25 }
local parent = form(R.schemas.skillGoal, goal, "step/SkillGoal", function(value) goal = value end)
edit(parent, "step/SkillGoal/rank", "50")
assert(goal.rank == 50 and goal.skillID == 185)
LibStub("AceGUI-3.0"):Release(parent)

local markers = { { x = 1, y = 2, mapID = 84, instanceID = 0 } }
parent = form(R.schemas.mapMarkers, markers, "step/MapMarkers", function(value) markers = value end)
edit(parent, "step/MapMarkers/1/x", "-4298.4")
assert(markers[1].x == -4298.4 and markers[1].mapID == 84 and markers[1].instanceID == 0)
LibStub("AceGUI-3.0"):Release(parent)

local buys = { { itemID = 2030, quantity = 1, isSupply = false, optional = false } }
parent = form(R.schemas.items, buys, "step/BuyMerchant", function(value) buys = value end)
local supply = assert(find(parent, "step/BuyMerchant/1/isSupply"))
supply:Fire("OnValueChanged", true)
assert(buys[1].isSupply == true and buys[1].optional == false)
LibStub("AceGUI-3.0"):Release(parent)

local loot = { { itemID = 769, quantityFromSkill = { skillID = 185, rank = 50 } } }
parent = form(R.schemas.lootItems, loot, "step/LootItems", function(value) loot = value end)
edit(parent, "step/LootItems/1/quantityFromSkill/rank", "75")
assert(loot[1].quantityFromSkill.rank == 75)
LibStub("AceGUI-3.0"):Release(parent)

local icons = 241743
parent = form(R.schemas.raidIcons, icons, "step/RaidIcon", function(value) icons = value end)
assert(type(icons) == "number", "Rendering a legacy NPC ID must preserve its representation")
edit(parent, "step/RaidIcon/1/npcID", "241744")
assert(icons[1].npcID == 241744)
LibStub("AceGUI-3.0"):Release(parent)

local images = { [93552] = { "routeHelper\\93552.jpg" } }
parent = form(R.schemas.fillerPreviewImages, images, "step/FillerPreviewImages", function(value) images = value end)
edit(parent, "step/FillerPreviewImages/93552", "routeHelper\\93552.jpg\nrouteHelper\\93553.jpg")
assert(images[93552][2] == "routeHelper\\93553.jpg")
assert(UI.Pickers:Resolve("id", "step/FillerPreviewImages/93552/key").kind == "quest")
LibStub("AceGUI-3.0"):Release(parent)

E:Show(); E:SelectRoute(route.name); E:SelectTab("steps")
E.session:SetSelected(1); E:DrawTab()
assert(not E.moveDown.disabled, "Ordinary steps can move across an early completion shortcut")
E.session:SetSelected(2); E:DrawTab()
assert(not E.moveUp.disabled and not E.duplicate.disabled)
assert(E.moveDown.disabled)
E:SelectTab("route")
E.session.draft.levelRange = { min = 1, max = 60 }
E.session:Snapshot(); E:DrawTab()
local function openRange(widget)
    if widget:GetUserData("navigateKey") == "levelRange" then widget:Fire("OnClick"); return true end
    for _, child in ipairs(widget.children or {}) do if openRange(child) then return true end end
end
assert(openRange(E.routeForm))
edit(E.routeForm, "route/levelRange/max", "50")
assert(E.session.draft.levelRange.max == 50 and route.levelRange == nil)
assert(E.session:Undo(-1) and E.session.draft.levelRange.max == 60)
assert(E:Save())
assert(AprRC:FindRouteByName(route.name).levelRange.max == 60)
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Latest wiki forms: field callbacks, legacy icons, early completion ordering, draft isolation, undo and save passed.")
