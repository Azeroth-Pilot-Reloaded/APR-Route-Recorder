local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")

AprRC.event = AprRC:NewModule('AprRC-Event')

-- global event framePool for register
AprRC.event.framePool = {}
AprRC.event.functions = {}

local events = {}
events.accept = "QUEST_ACCEPTED"
events.remove = "QUEST_REMOVED"
events.pet = { "PET_BATTLE_CLOSE", "PET_BATTLE_OPENING_START" }


function AprRC.event:MyRegisterEvent()
    for tag, event in pairs(events) do
        local container = self.framePool[tag] or CreateFrame("Frame")
        container.tag = tag
        container.callback = self.functions[tag]

        if type(event) == 'string' then
            container:RegisterEvent(event)
            container:SetScript('OnEvent', self.EventHandler)
        elseif type(event) == 'table' then
            for _, e in ipairs(event) do
                container:RegisterEvent(e)
                container:SetScript('OnEvent', self.EventHandler)
            end
        end
    end
end

function AprRC.event.EventHandler(self, event, ...)
    if not AprRC.settings.profile.enableAddon then
        return
    end

    if self.callback and self.tag then
        if AprRC.settings.profile.debug then
            Debug('Succesfully register event ' + event)
        end
        pcall(self.callback, event, ...)
    else
        if AprRC.settings.profile.debug then
            Debug('UnregisterEvent ' + event)
        end
        self.callback = nil
        self:UnregisterEvent(event)
    end
end

function AprRC.event.functions.accept(event, ...)
end

function AprRC.event.functions.remove(event, ...)
end

function AprRC.event.functions.pet(event, ...)
    AprRC.record:RefreshFrameAnchor()
end
