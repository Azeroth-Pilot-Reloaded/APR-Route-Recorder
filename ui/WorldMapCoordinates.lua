local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local Coordinates = AprRC:NewModule("WorldMapCoordinates")
AprRC.worldMapCoordinates = Coordinates

local function public(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "table" and canaccesstable and not canaccesstable(value) then return nil end
    return value
end

function Coordinates:Update()
    local map, label = self.map, self.label
    local ok, coord = pcall(function()
        if not public(map:IsShown()) or not public(map:IsCanvasMouseFocusOrPinFocus()) then return end
        local x, y = map:GetNormalizedCursorPosition()
        return AprRC:GetWorldCoordFromMapPosition(map:GetMapID(), x, y)
    end)
    if not ok or not coord then label:Hide(); return end
    local text = string.format(L.WORLD_MAP_CURSOR_WORLD, coord.x, coord.y)
    if label:GetText() ~= text then label:SetText(text) end
    label:Show()
end

function Coordinates:RefreshVisibility()
    if not self.frame then return end
    local profile = AprRC.settings.profile
    if profile.enableAddon and profile.worldMapCoordinates then
        self.frame:Show()
        self:Update()
    else
        self.frame:Hide()
    end
end

function Coordinates:Install()
    if self.frame then return end
    local map = public(_G.WorldMapFrame)
    if not map or not map.GetNormalizedCursorPosition or not map.IsCanvasMouseFocusOrPinFocus then return end
    local frame = CreateFrame("Frame", nil, map)
    frame:SetSize(310, 16)
    frame:EnableMouse(false)
    -- Follow the native coordinate panel when it moves around map overlays.
    -- Keep our row outside its automatic layout and leave its existing rows alone.
    local nativePanel
    for _, child in ipairs({ map:GetChildren() }) do
        if child.CursorCoords and child.PlayerCoords then nativePanel = child; break end
    end
    if nativePanel then
        frame:SetPoint("BOTTOMLEFT", nativePanel, "TOPLEFT", 0, 3)
    else
        frame:SetPoint("BOTTOMLEFT", map.ScrollContainer or map, "BOTTOMLEFT", 20, 36)
    end
    frame:SetFrameLevel((nativePanel or map.ScrollContainer or map):GetFrameLevel() + 1)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT")
    label:SetJustifyH("LEFT")
    AprRC.textStyle:TrackFont(label)
    self.frame, self.label, self.map = frame, label, map
    local elapsedTime = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.1 then return end
        elapsedTime = 0
        self:Update()
    end)
    frame:SetScript("OnShow", function() elapsedTime = 0; self:Update() end)
    self:RefreshVisibility()
end

function Coordinates:OnInit()
    self:Install()
    if self.frame then return end
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function()
        self:Install()
        if self.frame then loader:UnregisterEvent("ADDON_LOADED") end
    end)
end
