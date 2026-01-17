local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC = {}
AprRC = _G.LibStub("AceAddon-3.0"):NewAddon(AprRC, "APR-Recorder", "AceEvent-3.0")


AprRC.Color = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
    darkblue = { 0, 0.5, 0.5 },
    blue = { 0, 87 / 255, 183 / 255 },

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
    self.title = C_AddOns.GetAddOnMetadata("APR-Recorder", "Title")
    self.version = C_AddOns.GetAddOnMetadata("APR-Recorder", "Version")
    self.github = GetAddOnMetadata("APR-Recorder", "X-Github")
    self.discord = GetAddOnMetadata("APR-Recorder", "X-Discord")
    self.interfaceVersion = select(4, GetBuildInfo())
    self.isMidnightVersion = (tonumber(self.interfaceVersion) or 0) >= 120000


    -- Init Saved variable
    AprRCData = AprRCData or {}
    AprRCData.CurrentRoute = AprRCData.CurrentRoute or { name = "", steps = { {} } }
    AprRCData.Routes = AprRCData.Routes or {}
    AprRCData.ExtraLineTexts = AprRCData.ExtraLineTexts or {}
    AprRCData.QuestLookup = AprRCData.QuestLookup or {}
    AprRCData.TaxiLookup = AprRCData.TaxiLookup or {}
    AprRCData.BeforePortal = AprRCData.BeforePortal or {}
    AprRCData.BackupRoute = AprRCData.BackupRoute or {}

    -- Init module
    self.settings:InitializeBlizOptions()
    self.CommandBar:OnInit()
    self.record:OnInit()
    self.coordinate:OnInit()
    self.event:MyRegisterEvent()
    self:saveQuestInfo()
    self:EnsureQuestLookup(AprRCData.CurrentRoute and AprRCData.CurrentRoute.name)
    self:RebuildQuestLookupFromRoute(AprRCData.CurrentRoute)

    -- Register to Chat
    C_ChatInfo.RegisterAddonMessagePrefix("AprRCChat")
end
