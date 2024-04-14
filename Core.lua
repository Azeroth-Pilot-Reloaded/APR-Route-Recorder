local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(AprRC, "APR-Recorder", "AceEvent-3.0")
AprRC.Color = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
}
AprRC.Backdrop = {
    defaut = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = true,
        tileSize = 16
    },
    defaultBackdrop = { 0, 0, 0, 0.4 }
}

function AprRC:OnInitialize()
    local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata

    -- Init on TOC
    AprRC.title = C_AddOns.GetAddOnMetadata("APR-Recorder", "Title")
    AprRC.version = C_AddOns.GetAddOnMetadata("APR-Recorder", "Version")
    AprRC.github = GetAddOnMetadata("APR-Recorder", "X-Github")
    AprRC.discord = GetAddOnMetadata("APR-Recorder", "X-Discord")

    -- Init Saved variable
    AprRCData = AprRCData or {}
    AprRCData.CurrentRoute = AprRCData.CurrentRoute or { name = "", steps = { {} } }
    AprRCData.Routes = AprRCData.Routes or {}
    AprRCData.ExtraLineTexts = AprRCData.ExtraLineTexts or {}

    -- Init module
    AprRC.settings:InitializeBlizOptions()
    AprRC.record:OnInit()
    AprRC.event:MyRegisterEvent()
    AprRC:saveQuestInfo()

    -- Init Global Variables, UI oriented
    BINDING_HEADER_APR_ROUTE_RECORDER = AprRC.title -- Header text for APR's main frame
    _G["BINDING_NAME_" .. "CLICK AprRCItemButton:LeftButton"] = L_APR["USE_QUEST_ITEM"]

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end

---------------------------------------------------------------------------------------
---------------------------------- Route Management -----------------------------------
---------------------------------------------------------------------------------------

function AprRC:ResetData()
    AprRCData = {}
    AprRCData.CurrentRoute = { name = "", steps = { {} } }
    AprRCData.Routes = {}
end

function AprRC:InitRoute(name)
    local mapID = C_Map.GetBestMapForUnit("player")
    AprRCData.CurrentRoute = { name = mapID .. '-' .. name, steps = { {} } }
    tinsert(AprRCData.Routes, AprRCData.CurrentRoute)
end

function AprRC:UpdateRoute()
    local currentRouteName = AprRCData.CurrentRoute.name
    for i, route in ipairs(AprRCData.Routes) do
        if route.name == currentRouteName then
            AprRCData.Routes[i] = AprRCData.CurrentRoute
            break
        end
    end
end

function AprRC:NewStep(step)
    AprRC:Debug("NewStep", step)
    local lastStep = AprRC:GetLastStep()
    if AprRC:IsTableEmpty(lastStep) then
        AprRCData.CurrentRoute.steps = {}
    end
    tinsert(AprRCData.CurrentRoute.steps, step)
end

function AprRC:GetStepByIndex(index)
    return AprRCData.CurrentRoute.steps[index]
end

function AprRC:HasStepOption(stepOption)
    local step = self:GetLastStep()
    if step and step[stepOption] then
        return true
    end
    return false
end

function AprRC:SetStepCoord(step, range)
    local y, x, z, mapID = UnitPosition("player")
    if x and y and not step.NoArrow then
        step.Coord = { x = x, y = y }
        step.Zone = C_Map.GetBestMapForUnit("player")
        step.Range = range
    end
end

-- Check if the your are to far away from the current step to create a new one
-- Distance = 5 by default
function AprRC:IsCurrentStepFarAway(distance)
    local step = self:GetLastStep()
    if not step or not step.Coord then
        return
    end

    distance = distance or step.Range or 5
    local playerY, playerX = UnitPosition("player")
    local deltaX, deltaY = playerX - step.Coord.x, step.Coord.y - playerY
    local currentDistance = (deltaX * deltaX + deltaY * deltaY) ^ 0.5

    return currentDistance > distance
end

function AprRC:GetLastStep()
    return AprRCData.CurrentRoute.steps[#AprRCData.CurrentRoute.steps]
end

function AprRC:FindClosestIncompleteQuest()
    for i = #AprRCData.CurrentRoute.steps, 1, -1 do
        local step = AprRCData.CurrentRoute.steps[i]

        for _, optionType in ipairs({ "PickUp", "Done", "Qpart" }) do
            local questList = step[optionType]

            if questList and optionType == "Qpart" then
                for questID, _ in pairs(questList) do
                    if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
                        return questID
                    end
                end
            elseif questList then
                for _, questID in ipairs(questList) do
                    if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
                        return questID
                    end
                end
            end
        end
    end
end
