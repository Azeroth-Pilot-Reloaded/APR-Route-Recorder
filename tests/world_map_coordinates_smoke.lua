local M = AprRC.worldMapCoordinates
local profile = AprRC.settings.profile
profile.enableAddon, profile.worldMapCoordinates = true, true

-- The map can be loaded after the recorder; installation must happen just once.
WorldMapFrame = nil
M:OnInit()
assert(not M.frame)
local map = CreateFrame("Frame")
map.ScrollContainer = CreateFrame("Frame", nil, map)
local panel = CreateFrame("Frame", nil, map)
panel.CursorCoords, panel.PlayerCoords = {}, {}
panel:SetFrameLevel(150)
local mapID, x, y, hovered = 2393, 0.46, 0.545, true
function map:GetMapID() return mapID end
function map:GetNormalizedCursorPosition() return x, y end
function map:IsCanvasMouseFocusOrPinFocus() return hovered end
WorldMapFrame = map
local conversions = 0
CreateVector2D = function(vx, vy) return { x = vx, y = vy } end
local worldX, worldY = -1234.56, 7890.12
C_Map.GetWorldPosFromMapPos = function(id, position)
    conversions = conversions + 1
    assert(id == mapID and position.x == x and position.y == y,
        "Convert the displayed map and normalized cursor, not the player position")
    return 1, { GetXY = function() return worldX, worldY end }
end
TestEvent("ADDON_LOADED", "Blizzard_WorldMap")
local frame, label = assert(M.frame), assert(M.label)
assert(label:IsShown() and label:GetText() == "Curseur (monde) : 7890.1, -1234.6")
local point, relative, relativePoint = frame:GetPoint()
assert(point == "BOTTOMLEFT" and relative == panel and relativePoint == "TOPLEFT")
assert(frame:GetFrameLevel() > panel:GetFrameLevel())
TestEvent("ADDON_LOADED", "AnotherAddon"); M:Install()
assert(M.frame == frame and #map.children == 3, "Do not create duplicate rows")

-- Ten updates per second; unchanged values must not rewrite the font string.
local writes, setText = 0, label.SetText
label.SetText = function(self, text) writes = writes + 1; setText(self, text) end
local update = frame:GetScript("OnUpdate")
conversions = 0
for _ = 1, 9 do update(frame, 0.01) end
assert(conversions == 0)
update(frame, 0.02)
assert(conversions == 1 and writes == 0)
mapID, x, y, worldX, worldY = 84, 0.2, 0.8, 15, -20
update(frame, 0.1)
assert(label:GetText() == "Curseur (monde) : -20.0, 15.0" and writes == 1)
hovered = false
update(frame, 0.1)
assert(not label:IsShown() and conversions == 2)
hovered = true
update(frame, 0.1)
assert(label:IsShown())
map:Hide(); update(frame, 0.1)
assert(not label:IsShown())
map:Show(); frame:GetScript("OnShow")(frame)
assert(label:IsShown())

profile.worldMapCoordinates = false; M:RefreshVisibility()
assert(not frame:IsShown())
profile.worldMapCoordinates = true; M:RefreshVisibility()
assert(frame:IsShown())
profile.enableAddon = false; M:RefreshVisibility()
assert(not frame:IsShown())
profile.enableAddon = true; M:RefreshVisibility()

-- Unsupported maps and restricted values never leave stale numbers on screen.
local invalid = setmetatable({}, { __index = function() error("Restricted table read") end })
issecretvalue = function(value) return rawequal(value, invalid) end
x = invalid; update(frame, 0.1); assert(not label:IsShown())
x = 0.2; hovered = invalid; update(frame, 0.1); assert(not label:IsShown())
hovered = true; worldX = invalid; update(frame, 0.1); assert(not label:IsShown())
worldX = math.huge; update(frame, 0.1); assert(not label:IsShown())
x = -0.1; update(frame, 0.1); assert(not label:IsShown())
x = 1.1; update(frame, 0.1); assert(not label:IsShown())
x = 0.2; mapID = invalid; update(frame, 0.1); assert(not label:IsShown())
mapID = 84
C_Map.GetWorldPosFromMapPos = function() return nil end
update(frame, 0.1); assert(not label:IsShown())
C_Map.GetWorldPosFromMapPos = function() return 1, invalid end
update(frame, 0.1); assert(not label:IsShown())
issecretvalue = nil
canaccesstable = function(value) return not rawequal(value, invalid) end
update(frame, 0.1); assert(not label:IsShown())
canaccesstable = nil
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("World map coordinates: APR axes, displayed map, native anchoring, throttling, visibility and restricted data passed.")
