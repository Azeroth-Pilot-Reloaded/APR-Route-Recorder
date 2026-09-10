local locale = setmetatable({}, { __index = function(_, key) return key end })
LibStub = function() return { GetLocale = function() return locale end } end
AprRC = { settings = { profile = { enableAddon = true, recordBarFrame = { isRecording = true } } } }
function AprRC:NewModule() return {} end
APR = { LevelRequirementProfiles = { MidnightDelves = {} },
    REPUTATION_TYPE = { Standard = "standard", Renown = "renown", Friendship = "friendship" },
    EXPANSIONS = { Midnight = "Midnight", Custom = "Custom" },
    CATEGORIES = { Leveling = "Leveling", Miscellaneous = "Miscellaneous" },
    PREFAB_TYPES = { Speedrun = "speedrun" } }
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
