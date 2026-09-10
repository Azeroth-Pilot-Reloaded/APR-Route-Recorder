local locale = setmetatable({}, { __index = function(_, key) return key end })
LibStub = function() return { GetLocale = function() return locale end } end
AprRC = { settings = { profile = { enableAddon = true, recordBarFrame = { isRecording = true } } } }
function AprRC:NewModule() return {} end
APR = { LevelRequirementProfiles = { MidnightDelves = {} },
    REPUTATION_TYPE = { Standard = "standard", Renown = "renown", Friendship = "friendship" },
    EXPANSIONS = { Midnight = "Midnight", Custom = "Custom" },
    CATEGORIES = { Leveling = "Leveling", Miscellaneous = "Miscellaneous" },
    PREFAB_TYPES = { Speedrun = "speedrun" } }
APR.Classes = { Evoker = 13, Mage = 8 }
APR.Specs = { ["Mage - Frost"] = 64 }
APR.RACES = { Orc = "Orc", Troll = "Troll" }
APR.EVENTS = { Remix = "Remix" }
function APR:IsTableEmpty(t) return next(t) == nil end
function APR:PrintError(message) self.lastError = message end
function APR:PrintInfo() end
function tContains(list, value)
    for _, entry in pairs(list) do if entry == value then return true end end
    return false
end
tinsert = table.insert
function tIndexOf(list, value)
    for index, entry in ipairs(list) do if entry == value then return index end end
end
strtrim = function(text) return text:match("^%s*(.-)%s*$") end
UnitPosition = function() return 100, 200 end
C_Map = { GetBestMapForUnit = function() return 2393 end }
function AprRC:getZone() return 2393 end
AprRCData = { CurrentRoute = { name = "2393-Test", steps = {} }, Routes = {}, QuestLookup = {}, TaxiLookup = {} }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
TestFrames, TestHooks, TestTimers = {}, {}, {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(key, callback) self[key] = callback end
    TestFrames[#TestFrames + 1] = frame
    return frame
end
function hooksecurefunc(target, method, callback)
    if type(target) == "string" then TestHooks[target] = method
    else TestHooks[method] = callback end
end
function TestEvent(event, ...)
    for _, frame in ipairs(TestFrames) do
        if frame.events[event] and frame.OnEvent then frame.OnEvent(frame, event, ...) end
    end
end
C_Timer = { After = function(_, callback) TestTimers[#TestTimers + 1] = callback end }
function TestRunTimers()
    local callbacks = TestTimers
    TestTimers = {}
    for _, callback in ipairs(callbacks) do callback() end
end
C_GossipInfo = {}
C_ChromieTime = {}
C_PvP = { IsWarModeDesired = function() return false end }
C_Item = {}
C_MerchantFrame = {}
C_VignetteInfo = { GetVignettes = function() return {} end }
C_Container = { GetContainerNumSlots = function() return 0 end }
IsInInstance = function() return false, "none" end
Enum = { VignetteType = { Treasure = 3 }, FlightPathState = { Current = 0, Reachable = 1 } }
APR.GetZoneDetectionReport = function() return { playerCurrent = 2393 } end
function APR:HasAnyMainStepOption(step)
    for _, key in ipairs({ "PickUp", "Done", "SetHS", "UseHS", "Qpart", "UseFlightPath", "Achievement" }) do
        if step[key] then return true end
    end
    return false
end
function AprRC:saveQuestInfo() end
