local Q = AprRC.questID
local options = { enabled = true, alwaysVisible = true, map = true, minimap = true,
    questLog = true, objectiveTracker = true, inventory = true }
AprRC.settings.profile.questIDDisplay = options
AprRC.settings.profile.enableAddon = true

-- Lua 5.1 cannot reproduce the client's secret-value VM. These opaque values
-- fail loudly if indexed/converted, and the API spies reject secret arguments.
local forbiddenReads = 0
local function forbiddenRead()
    forbiddenReads = forbiddenReads + 1
    error("Attempted to inspect restricted data")
end
local secret = setmetatable({}, { __index = forbiddenRead, __tostring = forbiddenRead,
    __lt = forbiddenRead, __le = forbiddenRead, __concat = forbiddenRead })
local inaccessible = setmetatable({}, { __index = forbiddenRead })
issecretvalue = function(value) return rawequal(value, secret) or value == "hidden text" or value == 999999 end
canaccesstable = function(value) return not rawequal(value, inaccessible) end
local function public(value) assert(not issecretvalue(value), "Secret passed to a game API") end

local titles = { [42] = "First quest", [84] = "Second quest", [90] = "hidden text" }
C_QuestLog.GetTitleForQuestID = function(id) public(id); return titles[id] end
C_QuestLog.GetNumQuestLogEntries = function() return 4 end
C_QuestLog.GetInfo = function(index)
    return ({ { questID = 42 }, secret, inaccessible, { questID = 999999 } })[index]
end
C_QuestLog.GetQuestObjectives = function(id)
    public(id)
    return { { text = "Collect Test Item: 0/1" }, { text = "hidden text" }, secret, inaccessible }
end
C_QuestLog.GetQuestIDForLogIndex = function(index) public(index); return 42 end
GetQuestLogSpecialItemInfo = function() return "hidden text" end
C_TaskQuest = { GetQuestInfoByQuestID = function() return secret end, IsActive = function() return secret end }
Enum.TooltipDataType = { Quest = 1, MinimapMouseover = 2 }
Enum.TooltipDataLineType = { QuestTitle = 1, NestedBlock = 2 }
Q:RebuildQuestCache()

local questInfo, itemInfo, itemName = { isQuestItem = true }, { itemID = 12 }, "Test Item"
C_Container.GetContainerItemQuestInfo = function(bag, slot) public(bag); public(slot); return questInfo end
C_Container.GetContainerItemInfo = function() return itemInfo end
C_Item.GetItemNameByID = function(id) public(id); return itemName end
assert(Q:GetBagItemQuestIDs(0, 1)[1] == 42, "Public objective matching must still work")
itemName = "hidden text"
assert(not Q:GetBagItemQuestIDs(0, 1))
questInfo = { questID = 84, isQuestItem = secret }
itemInfo = { itemID = 999999 }
assert(Q:GetBagItemQuestIDs(0, 1)[1] == 84)
questInfo = secret
assert(not Q:GetBagItemQuestIDs(0, 1))
questInfo = inaccessible
assert(not Q:GetBagItemQuestIDs(0, 1))
assert(not Q:GetBagItemQuestIDs(secret, 1))
assert(not Q:GetBagItemQuestIDs(0, 999999))

local tooltip = GameTooltip
local additions, lastIDs, forbidden = 0, nil, false
function tooltip:IsForbidden() return forbidden end
function tooltip:GetOwner() return self.owner end
function tooltip:SetOwner(owner) self.owner = owner end
function tooltip:AddDoubleLine(label, value)
    assert(not forbidden)
    additions, lastIDs = additions + 1, value
    self:AddLine(label)
end
local function clear() tooltip:ClearLines(); lastIDs = nil end
clear()
tooltip:AddLine("hidden text")
Q:AddQuestIDsToTooltip(tooltip, { secret, 999999, "84", 42, 42, -1, math.huge, 1.5 })
assert(lastIDs == "42, 84", "Keep public IDs even alongside secret text and IDs")
local count = additions
Q:AddQuestIDsToTooltip(tooltip, 42)
assert(additions == count, "Duplicate QuestID lines should not accumulate")
Q:AddQuestIDsToTooltip(tooltip, secret)
Q:AddQuestIDsToTooltip(tooltip, inaccessible)
forbidden = true
Q:AddQuestIDsToTooltip(tooltip, 42)
Q:OnBagItemTooltip(tooltip, 0, 1)
Q:OnObjectiveTrackerHover(CreateFrame("Frame"), 42)
assert(additions == count, "Forbidden tooltips must be left alone")
forbidden = false

clear()
Q:OnMinimapTooltip(tooltip, { type = Enum.TooltipDataType.MinimapMouseover, id = secret,
    lines = { secret, inaccessible, { type = secret, leftText = "hidden text", args = inaccessible },
        { type = 2, tooltipType = 1, tooltipID = 84 },
        { args = { secret, { field = "hidden text", intVal = secret }, { field = "questID", intVal = 42 } } } } })
assert(lastIDs == "42, 84")
clear()
Q:OnMinimapTooltip(tooltip, secret)
Q:OnMinimapTooltip(tooltip, inaccessible)
Q:OnMinimapTooltip(tooltip, { type = secret, id = 999999, lines = secret })
assert(not lastIDs)
Q:OnMinimapTooltip(tooltip, { type = 1, id = 90, lines = { { leftText = "hidden text" } } })
assert(lastIDs == "90", "A secret title must not hide a public explicit quest ID")

local pin = CreateFrame("Frame")
pin.questID, pin.id, pin.info, pin.questLogIndex = secret, secret, inaccessible, secret
clear()
Q:OnMapQuestHover(pin, secret)
Q:OnQuestLogHover(pin, secret)
Q:OnObjectiveTrackerHover(pin, secret)
assert(not lastIDs)
pin.info = { questID = 42 }
Q:OnQuestLogHover(pin)
assert(lastIDs == "42")

-- Blob hooks inspect the completed tooltip; they never re-enter Blizzard's update.
clear()
tooltip:SetOwner(pin)
tooltip:AddLine("First quest")
tooltip:Show()
pin.UpdateMouseOverTooltip = forbiddenRead
Q:OnQuestBlobTooltip(pin)
assert(lastIDs == "42")
clear()
tooltip:AddLine("hidden text")
Q:OnQuestBlobTooltip(pin)
assert(not lastIDs)

-- A public bag ID remains available when primary tooltip data is restricted.
questInfo, itemInfo = { questID = 84 }, inaccessible
tooltip.GetPrimaryTooltipData = function() return inaccessible end
clear()
Q:OnBagItemTooltip(tooltip, 0, 1)
assert(lastIDs == "84")

-- Do not taint the QuestInfo template, title, parent fields or layout function.
local elements = { function() end, 0, 0 }
QUEST_TEMPLATE_MAP_DETAILS = { elements = elements }
QuestMapFrame = CreateFrame("Frame")
local details = CreateFrame("Frame", nil, QuestMapFrame)
QuestMapFrame.DetailsFrame = details
details.BackFrame = CreateFrame("Frame", nil, details)
details.questID = 42
local layouts = 0
QuestInfo_Display = function() layouts = layouts + 1 end
Q:InstallHooks()
Q:InstallHooks()
assert(#elements == 3 and not QUEST_TEMPLATE_MAP_DETAILS.aprrcQuestIDElement)
details:Show()
QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS)
local line = Q:GetQuestLogDetailLine(details)
assert(line:IsShown() and line:GetText():find("42", 1, true))
assert(not details.aprrcQuestIDLine and not details.BackFrame.aprrcQuestIDLine)
Q:RefreshVisibility()
assert(layouts == 1, "Refreshing the addon must not invoke Blizzard's layout")
details.questID = 84
QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS)
assert(line:GetText():find("84", 1, true))
details.questID = secret
Q:RefreshVisibility()
assert(not line:IsShown())
details.questID = 42
options.enabled = false
Q:RefreshVisibility()
clear()
Q:OnMapQuestHover(pin, 42)
assert(not line:IsShown() and not lastIDs)
options.enabled = true
details:Hide(); details:Show()
assert(line:IsShown())
assert(#elements == 3 and forbiddenReads == 0, "Restricted values must be skipped before inspection")

-- Compatibility with clients without the secret-value APIs.
issecretvalue, canaccesstable = nil, nil
clear()
Q:AddQuestIDsToTooltip(tooltip, 42)
assert(lastIDs == "42")
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Quest IDs: secret values/tables, forbidden tooltips, public-data display and Blizzard layout isolation passed.")
