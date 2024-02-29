local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(AprRC, "APR-Recorder", "AceEvent-3.0")
AprRC.Color = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
    defaultBackdrop = { 0, 0, 0, 0.4 },

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
    AprRCData.CurrentRoute = AprRCData.CurrentRoute or {}
    AprRCData.CurrentStep = AprRCData.CurrentStep or {}
    AprRCData.Routes = AprRCData.Routes or {}

    -- Init module
    AprRC.settings:InitializeBlizOptions()
    AprRC.record:OnInit()
    AprRC.event:MyRegisterEvent()

    -- Init Global Variables, UI oriented
    BINDING_HEADER_APR_ROUTE_RECORDER = AprRC.title -- Header text for APR's main frame
    _G["BINDING_NAME_" .. "CLICK AprRCItemButton:LeftButton"] = L_APR["USE_QUEST_ITEM"]

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end

---------------------------------------------------------------------------------------
---------------------------------- Route Management -----------------------------------
---------------------------------------------------------------------------------------

function AprRC:InitRoute()
    AprRCData.CurrentRoute.name = ''
    AprRCData.CurrentRoute.steps = {}
end

function AprRC:NewStep(step)
    tinsert(AprRCData.CurrentRoute.steps, step)
end

function AprRC:GetSteByIndex(index)
    return AprRCData.CurrentRoute.steps[index]
end

function AprRC:HasStepOption(stepOption)
    -- //TODO Ajouter un check sur la distance car si distance trop grande entre current step coord et moi alors new step (ajouter directement dans HasStepOption ??)
    if AprRCData.CurrentStep[stepOption] then
        return true
    end
    return false
end

function AprRC:SetStepCoord(step)
    local x, y, z, mapID = UnitPosition("player")
    if x and y then
        step.Coord = { x = x, y = y }
    end
end
