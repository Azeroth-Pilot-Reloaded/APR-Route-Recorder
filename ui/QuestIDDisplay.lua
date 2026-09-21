local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.questID = AprRC:NewModule("QuestIDDisplay")

local QUEST_ID_COLOR = "33ccff"
local hookedTrackers = {}
local activeQuests = {}
local questObjectives = {}
local specialItemQuests = {}
local detailLines = setmetatable({}, { __mode = "k" })
local hookedDetails = setmetatable({}, { __mode = "k" })
local ExtractQuestIDsFromTooltipData

-- Never inspect, convert, compare or index secret game values. On older
-- clients these predicates do not exist and ordinary values remain usable.
local function Public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return nil end
    return value
end

local function Text(value)
    value = Public(value)
    if type(value) == "string" then return value end
end

local function QuestID(value)
    value = Public(value)
    if type(value) ~= "number" and type(value) ~= "string" then return nil end
    value = tonumber(value)
    if value and value > 0 and value < math.huge and value % 1 == 0 then return value end
end

local function UsableFrame(frame)
    frame = Public(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
end

local function AddUnique(list, seen, questID)
    questID = QuestID(questID)
    if questID and not seen[questID] then
        seen[questID] = true
        list[#list + 1] = questID
    end
end

local function GetQuestTitle(questID)
    local title = Text(C_QuestLog.GetTitleForQuestID(questID))
    if (not title or title == "") and C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        title = Text(C_TaskQuest.GetQuestInfoByQuestID(questID))
    end
    return title
end

function AprRC.questID:IsEnabled(scope)
    local profile = AprRC.settings and AprRC.settings.profile
    local options = profile and profile.questIDDisplay
    if not profile or not profile.enableAddon or not options or not options.enabled or not options[scope] then
        return false
    end

    return options.alwaysVisible or (profile.recordBarFrame and profile.recordBarFrame.isRecording)
end

function AprRC.questID:AddQuestIDsToTooltip(tooltip, questIDs)
    questIDs = Public(questIDs)
    if not UsableFrame(tooltip) or not questIDs then return end

    if type(questIDs) ~= "table" then
        questIDs = { questIDs }
    end

    local ids, seen = {}, {}
    for _, questID in ipairs(questIDs) do
        AddUnique(ids, seen, questID)
    end
    if #ids == 0 then return end
    table.sort(ids)

    local tooltipName = tooltip.GetName and Text(tooltip:GetName())
    if tooltipName then
        local count = Public(tooltip:NumLines())
        if type(count) ~= "number" then return end
        for i = 1, count do
            local left = _G[tooltipName .. "TextLeft" .. i]
            local text = UsableFrame(left) and Text(left:GetText())
            if text and (text:find(L.QUEST_ID, 1, true) or text:find(L["Quest ID"], 1, true) or text:find("Quest ID", 1, true)) then
                return
            end
        end
    end

    local values = {}
    for _, questID in ipairs(ids) do
        values[#values + 1] = tostring(questID)
    end

    local label = #values > 1 and L.QUEST_IDS or L.QUEST_ID
    tooltip:AddDoubleLine(label .. ":", table.concat(values, ", "), 0.2, 0.8, 1, 1, 1, 1)
    AprRC.textStyle:TooltipLine(tooltip)
    tooltip:Show()
end

function AprRC.questID:EnsureQuestTooltip(owner, questID)
    questID = QuestID(questID)
    if not questID or not UsableFrame(GameTooltip) or not UsableFrame(owner) then return end

    if not Public(GameTooltip:IsShown()) or Public(GameTooltip:GetOwner()) ~= owner then
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_CURSOR_RIGHT", 5, 2)
        GameTooltip:SetText(GetQuestTitle(questID) or _G.QUESTS_LABEL or L["Quest"])
        AprRC.textStyle:TooltipLine(GameTooltip)
    end
    self:AddQuestIDsToTooltip(GameTooltip, questID)
end

function AprRC.questID:RebuildQuestCache()
    wipe(activeQuests)
    wipe(questObjectives)
    wipe(specialItemQuests)

    local numEntries = Public(C_QuestLog.GetNumQuestLogEntries())
    if type(numEntries) ~= "number" then return end
    for questLogIndex = 1, numEntries do
        local info = Public(C_QuestLog.GetInfo(questLogIndex))
        local questID = info and QuestID(info.questID)
        if questID and not Public(info.isHeader) then
            activeQuests[questID] = true
            local objectives = {}
            for _, objective in ipairs(Public(C_QuestLog.GetQuestObjectives(questID)) or {}) do
                objective = Public(objective)
                local text = objective and Text(objective.text)
                if text then objectives[#objectives + 1] = text:lower() end
            end
            questObjectives[questID] = objectives

            local itemLink = Text(GetQuestLogSpecialItemInfo(questLogIndex))
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                specialItemQuests[itemID] = specialItemQuests[itemID] or {}
                specialItemQuests[itemID][questID] = true
            end
        end
    end
end

function AprRC.questID:GetBagItemQuestIDs(bagID, slotID)
    bagID, slotID = Public(bagID), Public(slotID)
    if type(bagID) ~= "number" or type(slotID) ~= "number" then return end
    local questInfo = Public(C_Container.GetContainerItemQuestInfo(bagID, slotID))
    if not questInfo then return end
    local questID, isQuestItem = QuestID(questInfo.questID), Public(questInfo.isQuestItem)
    if not questID and not isQuestItem then return end

    local ids, seen = {}, {}
    AddUnique(ids, seen, questID)

    local itemInfo = Public(C_Container.GetContainerItemInfo(bagID, slotID))
    local itemID = itemInfo and QuestID(itemInfo.itemID)
    if itemID and specialItemQuests[itemID] then
        for questID in pairs(specialItemQuests[itemID]) do
            AddUnique(ids, seen, questID)
        end
    end

    -- The container API only exposes a direct questID for quest-starting items.
    -- For ordinary objective items, match the cached item name against active
    -- item-objective text. This covers the relation the client marks with the
    -- yellow quest-item border without maintaining an external quest database.
    if isQuestItem and itemID then
        local itemName = Text(C_Item.GetItemNameByID(itemID))
        local itemNameLower = itemName and itemName:lower()
        if itemNameLower and itemNameLower ~= "" then
            for questID, objectives in pairs(questObjectives) do
                for _, objectiveText in ipairs(objectives) do
                    if objectiveText:find(itemNameLower, 1, true) then
                        AddUnique(ids, seen, questID)
                        break
                    end
                end
            end
        end
    end

    if #ids > 0 then return ids end
end

function AprRC.questID:OnBagItemTooltip(tooltip, bagID, slotID)
    if not self:IsEnabled("inventory") or not UsableFrame(tooltip) then return end
    local questIDs = self:GetBagItemQuestIDs(bagID, slotID)
    if not questIDs then return end

    if tooltip.GetPrimaryTooltipData then
        local ok, tooltipQuestIDs = pcall(function()
            return ExtractQuestIDsFromTooltipData(tooltip:GetPrimaryTooltipData())
        end)
        if ok then
            for _, questID in ipairs(tooltipQuestIDs) do
                questIDs[#questIDs + 1] = questID
            end
        end
    end

    self:AddQuestIDsToTooltip(tooltip, questIDs)
end

ExtractQuestIDsFromTooltipData = function(data)
    local ids, seen = {}, {}
    data = Public(data)
    if not data then return ids end

    local hasQuestTitle = false
    local dataID = QuestID(data.id)
    local dataQuestTitle = dataID and GetQuestTitle(dataID)
    local titleMatches = false
    for _, line in ipairs(Public(data.lines) or {}) do
        line = Public(line)
        if line then
            if Public(line.type) == Enum.TooltipDataLineType.QuestTitle then
                hasQuestTitle = true
            elseif Public(line.type) == Enum.TooltipDataLineType.NestedBlock
                and Public(line.tooltipType) == Enum.TooltipDataType.Quest then
                AddUnique(ids, seen, line.tooltipID)
            end

            local leftText = Text(line.leftText)
            if dataQuestTitle and leftText and leftText:find(dataQuestTitle, 1, true) then
                titleMatches = true
            end

            for _, arg in ipairs(Public(line.args) or {}) do
                arg = Public(arg)
                local field = arg and Text(arg.field)
                field = field and field:lower()
                if field and field:find("quest", 1, true) and field:find("id", 1, true) then
                    AddUnique(ids, seen, arg.intVal)
                end
            end
        end
    end

    if Public(data.type) == Enum.TooltipDataType.Quest then
        AddUnique(ids, seen, dataID)
    elseif Public(data.type) == Enum.TooltipDataType.MinimapMouseover then
        if dataID and (hasQuestTitle or titleMatches or activeQuests[dataID]
            or (C_TaskQuest and C_TaskQuest.IsActive and Public(C_TaskQuest.IsActive(dataID)))) then
            AddUnique(ids, seen, dataID)
        end
    end

    return ids
end

function AprRC.questID:OnMinimapTooltip(tooltip, data)
    if not self:IsEnabled("minimap") then return end
    local ok, ids = pcall(ExtractQuestIDsFromTooltipData, data)
    if ok then
        self:AddQuestIDsToTooltip(tooltip, ids)
    end
end

function AprRC.questID:OnQuestLogHover(button, questID)
    if not self:IsEnabled("questLog") or not UsableFrame(button) then return end
    local info, index = Public(button.info), QuestID(button.questLogIndex)
    questID = QuestID(questID) or (info and QuestID(info.questID))
        or (index and QuestID(C_QuestLog.GetQuestIDForLogIndex(index)))
    self:EnsureQuestTooltip(button, questID)
end

function AprRC.questID:OnObjectiveTrackerHover(block, questID)
    if not self:IsEnabled("objectiveTracker") or not UsableFrame(block) then return end
    questID = QuestID(questID) or QuestID(block.id)
    if not questID then return end
    self:EnsureQuestTooltip(block, questID)
end

function AprRC.questID:OnMapQuestHover(pin, questID)
    if not self:IsEnabled("map") or not UsableFrame(pin) then return end
    questID = QuestID(questID) or QuestID(pin.questID) or (pin.GetQuestID and QuestID(pin:GetQuestID()))
    self:EnsureQuestTooltip(pin, questID)
end

function AprRC.questID:OnQuestBlobTooltip(pin)
    if not self:IsEnabled("map") or not UsableFrame(pin) or not UsableFrame(GameTooltip)
        or not Public(GameTooltip:IsShown()) or Public(GameTooltip:GetOwner()) ~= pin then return end

    -- UpdateMouseOverTooltip changes Blizzard's blob state. Do not call it a
    -- second time from an insecure post-hook. Match the already displayed title
    -- only when it identifies a single active quest; omit ambiguous/secret data.
    local title = _G.GameTooltipTextLeft1
    local text = UsableFrame(title) and Text(title:GetText())
    if not text then return end
    local match
    for questID in pairs(activeQuests) do
        if GetQuestTitle(questID) == text then
            if match then return end
            match = questID
        end
    end
    self:AddQuestIDsToTooltip(GameTooltip, match)
end

function AprRC.questID:GetQuestLogDetailLine(parentFrame)
    if not UsableFrame(parentFrame) then return end
    local line = detailLines[parentFrame]
    if not line then
        -- Own the label and its anchors, without adding callbacks to Blizzard's
        -- template or moving any Blizzard regions. Keep it beside the Back button.
        local header = Public(parentFrame.BackFrame) or parentFrame
        if not UsableFrame(header) then return end
        line = header:CreateFontString(nil, "ARTWORK", "QuestFontNormalSmall")
        AprRC.textStyle:TrackFont(line)
        line:SetPoint("TOPLEFT", header, "TOPLEFT", 112, -14)
        line:SetSize(155, 18)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:Hide()
        detailLines[parentFrame] = line
    end
    return line
end

function AprRC.questID:InstallQuestLogDetailHook()
    local details = _G.QuestMapFrame and QuestMapFrame.DetailsFrame
    if UsableFrame(details) and not hookedDetails[details] then
        details:HookScript("OnShow", function() self:RefreshQuestLogDetails() end)
        hookedDetails[details] = true
    end
    if not _G.QuestInfo_Display or self.questDetailsHooked then return end
    hooksecurefunc("QuestInfo_Display", function(template)
        if template == _G.QUEST_TEMPLATE_MAP_DETAILS then self:RefreshQuestLogDetails() end
    end)
    self.questDetailsHooked = true
end

function AprRC.questID:RefreshQuestLogDetails()
    local details = _G.QuestMapFrame and QuestMapFrame.DetailsFrame
    if not UsableFrame(details) then return end
    local questID = QuestID(details.questID)
    if not questID or not Public(details:IsShown()) or not self:IsEnabled("questLog") then
        if detailLines[details] then detailLines[details]:Hide() end
        return
    end
    local line = self:GetQuestLogDetailLine(details)
    if not line then return end
    line:SetText("|cff" .. QUEST_ID_COLOR .. L.QUEST_ID .. ":|r " .. questID)
    line:Show()
end

function AprRC.questID:RefreshVisibility()
    self:RefreshQuestLogDetails()
end

function AprRC.questID:HookObjectiveTrackers()
    local trackerNames = {
        "QuestObjectiveTracker",
        "CampaignQuestObjectiveTracker",
        "WorldQuestObjectiveTracker",
        "BonusObjectiveTracker",
    }

    for _, trackerName in ipairs(trackerNames) do
        local tracker = _G[trackerName]
        if tracker and tracker.OnBlockHeaderEnter and not hookedTrackers[tracker] then
            hooksecurefunc(tracker, "OnBlockHeaderEnter", function(_, block)
                AprRC.questID:OnObjectiveTrackerHover(block)
            end)
            hookedTrackers[tracker] = true
        end
    end
end

function AprRC.questID:InstallHooks()
    self:HookObjectiveTrackers()
    self:InstallQuestLogDetailHook()

    if _G.TaskPOI_OnEnter and not self.taskPOIHooked then
        hooksecurefunc("TaskPOI_OnEnter", function(pin)
            AprRC.questID:OnMapQuestHover(pin)
        end)
        self.taskPOIHooked = true
    end

    if _G.QuestBlobPinMixin and QuestBlobPinMixin.UpdateTooltip and not self.questBlobHooked then
        hooksecurefunc(QuestBlobPinMixin, "UpdateTooltip", function(pin)
            AprRC.questID:OnQuestBlobTooltip(pin)
        end)
        self.questBlobHooked = true
    end
end

function AprRC.questID:OnInit()
    self:RebuildQuestCache()
    self:InstallHooks()

    EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", function(_, button, questID)
        AprRC.questID:OnQuestLogHover(button, questID)
    end, self)
    EventRegistry:RegisterCallback("OnQuestBlockHeader.OnEnter", function(_, block, questID)
        AprRC.questID:OnObjectiveTrackerHover(block, questID)
    end, self)
    EventRegistry:RegisterCallback("MapCanvas.QuestPin.OnEnter", function(_, pin, questID)
        AprRC.questID:OnMapQuestHover(pin, questID)
    end, self)

    if TooltipDataProcessor and Enum.TooltipDataType.MinimapMouseover then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.MinimapMouseover, function(tooltip, data)
            AprRC.questID:OnMinimapTooltip(tooltip, data)
        end)
    end

    hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bagID, slotID)
        AprRC.questID:OnBagItemTooltip(tooltip, bagID, slotID)
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then
            AprRC.questID:InstallHooks()
        else
            AprRC.questID:RebuildQuestCache()
            AprRC.questID:InstallHooks()
            AprRC.questID:RefreshQuestLogDetails()
        end
    end)
    self.eventFrame = eventFrame
end
