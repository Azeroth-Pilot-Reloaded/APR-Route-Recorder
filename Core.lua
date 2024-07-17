local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(AprRC, "APR-Recorder", "AceEvent-3.0")
AprRC.Color = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
    darkblue = { 0, 0.5, 0.5 },

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
    AprRCData.QuestLookup = AprRCData.QuestLookup or {}
    AprRCData.TaxiLookup = AprRCData.TaxiLookup or {}
    AprRCData.BeforePortal = AprRCData.BeforePortal or {}

    -- Init module
    AprRC.settings:InitializeBlizOptions()
    AprRC.record:OnInit()
    AprRC.event:MyRegisterEvent()
    AprRC:saveQuestInfo()

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end
