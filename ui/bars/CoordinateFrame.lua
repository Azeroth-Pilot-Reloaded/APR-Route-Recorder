local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local LibWindow = LibStub("LibWindow-1.1")


-- The recorder owns its overlay independently of APR's coordinate panel.
AprRC.coordinate = AprRC:NewModule("Coordinate")

--Local constant
local FRAME_WIDTH = 150
local FRAME_HEIGHT = 32
local frequency = 0.2
local fpsCounter = 0
-- local OnUpdate
---------------------------------------------------------------------------------------
------------------------------- Coordinate Frames -------------------------------------
---------------------------------------------------------------------------------------

local CoordinateFrame = CreateFrame("Frame", "AprRC_CoordinateScreenPanel", UIParent, "BackdropTemplate")
CoordinateFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
CoordinateFrame:SetFrameStrata("MEDIUM")
CoordinateFrame:EnableMouse(true)
CoordinateFrame:SetClampedToScreen(true)
CoordinateFrame:SetBackdrop({
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    tile = true,
    tileSize = 16,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
CoordinateFrame:SetBackdropColor(unpack(APR.Color.defaultLightBackdrop))
CoordinateFrame:SetBackdropBorderColor(1, 0.8, 0, 0.8)

CoordinateFrame.Text = CoordinateFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CoordinateFrame.Text:SetJustifyH("CENTER")
CoordinateFrame.Text:SetPoint("CENTER", 0, 0)
AprRC.textStyle:TrackFont(CoordinateFrame.Text)

CoordinateFrame:SetScript("OnUpdate", function(self, elapsed)
    fpsCounter = fpsCounter + elapsed
    if fpsCounter >= frequency then
        -- Sample once after a stall instead of replaying missed intervals.
        fpsCounter = fpsCounter % frequency

        local y, x = UnitPosition("player")
        local text
        if not x or not y then
            text = ("-"):rep(8)
        else
            if self.lastX == x and self.lastY == y then return end
            text = APR.coordinate:RoundCoords(x, y, 2)
        end
        self.lastX, self.lastY = x, y
        if self.lastText ~= text then self.Text:SetText(text); self.lastText = text end
    end
end)
CoordinateFrame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        APR.questionDialog:CreateEditBoxPopup(L["Coordinate X,Y"], nil, CoordinateFrame.Text:GetText())
    end
end)
---------------------------------------------------------------------------------------
----------------------------- Function Coordinate Frames ------------------------------
---------------------------------------------------------------------------------------

function AprRC.coordinate:OnInit()
    LibWindow.RegisterConfig(CoordinateFrame, AprRC.settings.profile.coordinateFrame)
    CoordinateFrame.RegisteredForLibWindow = true
    LibWindow.MakeDraggable(CoordinateFrame)
    CoordinateFrame:SetPoint("center", UIParent, "center", 0, 0)

    self:RefreshFrameAnchor()
end

function AprRC.coordinate:RefreshFrameAnchor()
    if (not AprRC.settings.profile.coordinateShow or not AprRC.settings.profile.enableAddon) then
        CoordinateFrame:Hide()
        return
    end
    LibWindow.RestorePosition(CoordinateFrame)
    CoordinateFrame:Show()
end
