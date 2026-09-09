local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.questID = AprRC:NewModule("QuestIDDisplay")

local QUEST_ID_COLOR = "33ccff"
local hookedTrackers = {}
local activeQuests = {}
local questObjectives = {}
local specialItemQuests = {}
local ExtractQuestIDsFromTooltipData

local function AddUnique(list, seen, questID)
    questID = tonumber(questID)
    if questID and questID > 0 and not seen[questID] then
        seen[questID] = true
        list[#list + 1] = questID
    end
end

local function GetQuestTitle(questID)
    local title = C_QuestLog.GetTitleForQuestID(questID)
    if (not title or title == "") and C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        title = C_TaskQuest.GetQuestInfoByQuestID(questID)
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
    if not tooltip or not questIDs then return end

    if type(questIDs) ~= "table" then
        questIDs = { questIDs }
    end

    local ids, seen = {}, {}
    for _, questID in ipairs(questIDs) do
        AddUnique(ids, seen, questID)
    end
    if #ids == 0 then return end
    table.sort(ids)

    local tooltipName = tooltip.GetName and tooltip:GetName()
    if tooltipName then
        for i = 1, tooltip:NumLines() do
            local left = _G[tooltipName .. "TextLeft" .. i]
            local text = left and left:GetText()
            if text and (text:find(L.QUEST_ID, 1, true) or text:find("Quest ID", 1, true)) then
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
    tooltip:Show()
end

function AprRC.questID:EnsureQuestTooltip(owner, questID)
    if not questID then return end

    if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= owner then
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_CURSOR_RIGHT", 5, 2)
        GameTooltip:SetText(GetQuestTitle(questID) or _G.QUESTS_LABEL or "Quest")
    end
    self:AddQuestIDsToTooltip(GameTooltip, questID)
end

function AprRC.questID:RebuildQuestCache()
    wipe(activeQuests)
    wipe(questObjectives)
    wipe(specialItemQuests)

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for questLogIndex = 1, numEntries do
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            local questID = info.questID
            activeQuests[questID] = true
            questObjectives[questID] = C_QuestLog.GetQuestObjectives(questID) or {}

            local itemLink = GetQuestLogSpecialItemInfo(questLogIndex)
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                specialItemQuests[itemID] = specialItemQuests[itemID] or {}
                specialItemQuests[itemID][questID] = true
            end
        end
    end
end

function AprRC.questID:GetBagItemQuestIDs(bagID, slotID)
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
    if not questInfo or (not questInfo.questID and not questInfo.isQuestItem) then return end

    local ids, seen = {}, {}
    AddUnique(ids, seen, questInfo.questID)

    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    local itemID = itemInfo and itemInfo.itemID
    if itemID and specialItemQuests[itemID] then
        for questID in pairs(specialItemQuests[itemID]) do
            AddUnique(ids, seen, questID)
        end
    end

    -- The container API only exposes a direct questID for quest-starting items.
    -- For ordinary objective items, match the cached item name against active
    -- item-objective text. This covers the relation the client marks with the
    -- yellow quest-item border without maintaining an external quest database.
    if questInfo.isQuestItem and itemID then
        local itemName = C_Item.GetItemNameByID(itemID)
        local itemNameLower = itemName and itemName:lower()
        if itemNameLower and itemNameLower ~= "" then
            for questID, objectives in pairs(questObjectives) do
                for _, objective in ipairs(objectives) do
                    local objectiveText = objective.text and objective.text:lower()
                    if objectiveText and objectiveText:find(itemNameLower, 1, true) then
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
    if not self:IsEnabled("inventory") then return end
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
    if not data then return ids end

    local hasQuestTitle = false
    local dataID = tonumber(data.id)
    local dataQuestTitle = dataID and GetQuestTitle(dataID)
    local titleMatches = false
    for _, line in ipairs(data.lines or {}) do
        if line.type == Enum.TooltipDataLineType.QuestTitle then
            hasQuestTitle = true
        elseif line.type == Enum.TooltipDataLineType.NestedBlock
            and line.tooltipType == Enum.TooltipDataType.Quest then
            AddUnique(ids, seen, line.tooltipID)
        end

        if dataQuestTitle and line.leftText and line.leftText:find(dataQuestTitle, 1, true) then
            titleMatches = true
        end

        for _, arg in ipairs(line.args or {}) do
            local field = arg.field and arg.field:lower()
            if field and field:find("quest", 1, true) and field:find("id", 1, true) then
                AddUnique(ids, seen, arg.intVal)
            end
        end
    end

    if data.type == Enum.TooltipDataType.Quest then
        AddUnique(ids, seen, dataID)
    elseif data.type == Enum.TooltipDataType.MinimapMouseover then
        if dataID and (hasQuestTitle or titleMatches or activeQuests[dataID]
            or (C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(dataID))) then
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
    if not self:IsEnabled("questLog") then return end
    questID = questID or (button.info and button.info.questID)
        or (button.questLogIndex and C_QuestLog.GetQuestIDForLogIndex(button.questLogIndex))
    self:EnsureQuestTooltip(button, questID)
end

function AprRC.questID:OnObjectiveTrackerHover(block, questID)
    if not self:IsEnabled("objectiveTracker") then return end
    questID = questID or (block and block.id)
    if not questID or questID <= 0 then return end
    self:EnsureQuestTooltip(block, questID)
end

function AprRC.questID:OnMapQuestHover(pin, questID)
    if not self:IsEnabled("map") then return end
    questID = questID or (pin and (pin.questID or (pin.GetQuestID and pin:GetQuestID())))
    self:EnsureQuestTooltip(pin, questID)
end

function AprRC.questID:OnQuestBlobTooltip(pin)
    if not self:IsEnabled("map") or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= pin then return end

    local questID
    local ok, result = pcall(function()
        local mouseX, mouseY = pin:GetMap():GetNormalizedCursorPosition()
        return pin:UpdateMouseOverTooltip(mouseX, mouseY)
    end)
    if ok then questID = result end
    questID = questID or pin.focusedQuestID or pin.highlightedQuestID or pin.questID
    self:AddQuestIDsToTooltip(GameTooltip, questID)
end

function AprRC.questID:ClearLegacyQuestLogTitleSuffix()
    local title = _G.QuestInfoTitleHeader
    if not title then return end

    local text = title:GetText()
    local oldSuffix = title.aprrcQuestIDSuffix
    if oldSuffix and text and text:sub(-#oldSuffix) == oldSuffix then
        text = text:sub(1, #text - #oldSuffix)
        title:SetText(text)
    end
    title.aprrcQuestIDSuffix = nil
end

function AprRC.questID:GetQuestLogDetailLine(parentFrame)
    local line = parentFrame.aprrcQuestIDLine
    if not line then
        line = parentFrame:CreateFontString(nil, "ARTWORK", "QuestFontNormalSmall")
        line:SetWidth(285)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        parentFrame.aprrcQuestIDLine = line
    end

    local details = _G.QuestMapFrame and QuestMapFrame.DetailsFrame
    local questID = details and details.questID
    if not questID or not self:IsEnabled("questLog") then
        line:Hide()
        return
    end

    local bodyText = _G.QuestInfoObjectivesText
    if bodyText then
        line:SetTextColor(bodyText:GetTextColor())
    end

    line:SetText("|cff" .. QUEST_ID_COLOR .. L.QUEST_ID .. ":|r " .. questID)
    line:Show()
    return line
end

function AprRC.questID:InstallQuestLogDetailLayout()
    local template = _G.QUEST_TEMPLATE_MAP_DETAILS
    if not template or template.aprrcQuestIDElement then return end

    -- QuestInfo layouts are triples: renderer, x offset, y offset. Inserting
    -- our own renderer makes the QuestID a real row between the title and the
    -- objectives, so it uses a body font and participates in Blizzard's layout.
    table.insert(template.elements, 4, function(parentFrame)
        return AprRC.questID:GetQuestLogDetailLine(parentFrame)
    end)
    table.insert(template.elements, 5, 0)
    table.insert(template.elements, 6, -2)
    template.aprrcQuestIDElement = true
end

function AprRC.questID:RefreshQuestLogDetails()
    self:ClearLegacyQuestLogTitleSuffix()
    self:InstallQuestLogDetailLayout()

    local details = _G.QuestMapFrame and QuestMapFrame.DetailsFrame
    if not details or not details:IsShown() or not _G.QuestInfo_Display
        or not _G.QUEST_TEMPLATE_MAP_DETAILS then
        return
    end

    QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS, details.ScrollFrame.Contents)
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
    self:InstallQuestLogDetailLayout()

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
        end
    end)
    self.eventFrame = eventFrame
end
