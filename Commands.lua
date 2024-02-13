local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.command = AprRC:NewModule("Command")

function AprRC.command:SlashCmd(input)
    if not AprRC.settings.profile.enableAddon then
        AprRC.settings:OpenSettings(AprRC.title)
    end

    AprRC.settings:OpenSettings(AprRC.title)
end
