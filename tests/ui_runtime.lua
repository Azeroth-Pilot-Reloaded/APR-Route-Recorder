-- Minimal native frame surface for exercising the *bundled* AceGUI widgets.
-- This verifies callbacks, pooling and layout allocation; it is not a WoW renderer.
LibStub = nil
table.wipe = function(t) for key in pairs(t) do t[key] = nil end; return t end
wipe = table.wipe
strlower, strupper = string.lower, string.upper
GetLocale = function() return "frFR" end
CLOSE, YES, CANCEL, OKAY, ACCEPT = "Close", "Yes", "Cancel", "OK", "Accept"
PlaySound = function() end
SetDesaturation = function() end
IsControlKeyDown = function() return false end
IsModifierKeyDown = function() return false end
IsShiftKeyDown, IsMetaKeyDown = IsControlKeyDown, IsControlKeyDown
GetCursorInfo, ClearCursor, GetMouseFocus = function() end, function() end, function() end
GetTime = function() return 0 end
GameFontNormal, GameFontNormalSmall, GameFontHighlight, GameFontHighlightSmall = {}, {}, {}, {}
GameFontDisable, GameFontDisableSmall, ChatFontNormal = {}, {}, {}
UIErrors = {}
geterrorhandler = function() return function(err) UIErrors[#UIErrors + 1] = tostring(err) end end
-- WoW extends Lua 5.1 xpcall to accept arguments.
local originalXpcall = xpcall
xpcall = function(fn, handler, ...)
    local args = { ... }
    return originalXpcall(function() return fn(unpack(args)) end, handler)
end

local Native = {}
local function event(self, name, ...)
    if self.scripts[name] then self.scripts[name](self, ...) end
end
function Native:SetScript(name, callback) self.scripts[name] = callback end
function Native:GetScript(name) return self.scripts[name] end
function Native:HookScript(name, callback)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end; callback(...) end
end
function Native:SetWidth(value)
    if self.w ~= value then self.w = value; event(self, "OnSizeChanged", self:GetWidth(), self:GetHeight()) end
end
function Native:SetHeight(value)
    if self.h ~= value then self.h = value; event(self, "OnSizeChanged", self:GetWidth(), self:GetHeight()) end
end
function Native:GetWidth() return self.w or (self.allPoints and self.allPoints:GetWidth()) or 300 end
function Native:GetHeight() return self.h or (self.allPoints and self.allPoints:GetHeight()) or 100 end
function Native:SetSize(width, height) self:SetWidth(width); self:SetHeight(height) end
function Native:ClearAllPoints() self.points = {}; self.allPoints = nil end
function Native:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Native:SetAllPoints(relative) self.allPoints = relative or self.parent end
function Native:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function Native:GetNumPoints() return #self.points end
function Native:SetParent(parent)
    if self.parent == parent then return end
    if self.parent then
        for index, child in ipairs(self.parent.children) do
            if child == self then table.remove(self.parent.children, index); break end
        end
    end
    self.parent = parent
    if parent then parent.children[#parent.children + 1] = self end
end
function Native:GetParent() return self.parent end
function Native:GetName() return self.name end
function Native:Show() if not self.shown then self.shown = true; event(self, "OnShow") end end
function Native:Hide() if self.shown then self.shown = false; event(self, "OnHide") end end
function Native:IsShown() return self.shown end
Native.IsVisible = Native.IsShown
function Native:SetText(text)
    self.text = text or ""
    event(self, "OnTextChanged", false)
    event(self, "OnTextSet")
end
function Native:GetText() return self.text or "" end
function Native:GetStringWidth() return #self:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 6 end
Native.GetTextWidth = Native.GetStringWidth
function Native:GetStringHeight() return math.max(14, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth())) * 14) end
function Native:GetNumLetters() return #self:GetText() end
function Native:SetCursorPosition(cursor) self.cursor = cursor end
function Native:GetCursorPosition() return self.cursor or 0 end
function Native:Insert(text)
    local cursor = self:GetCursorPosition()
    self.text = self:GetText():sub(1, cursor) .. text .. self:GetText():sub(cursor + 1)
    self.cursor = cursor + #text
    event(self, "OnTextChanged", true)
end
function Native:SetFocus() self.focus = true; event(self, "OnEditFocusGained") end
function Native:ClearFocus() self.focus = false; event(self, "OnEditFocusLost") end
function Native:HasFocus() return self.focus end
function Native:GetTop() return 780 end
function Native:GetLeft() return 0 end
function Native:SetFrameStrata(strata) self.strata = strata end
function Native:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Native:GetBottom() return self:GetTop() - self:GetHeight() end
function Native:GetEffectiveScale() return 1 end
function Native:GetFrameLevel() return self.level or 100 end
function Native:SetFrameLevel(level) self.level = level end
function Native:GetChildren()
    local result = {}
    for _, child in ipairs(self.children) do
        if child.frameType ~= "FontString" and child.frameType ~= "Texture" and child.frameType ~= "Line" then
            result[#result + 1] = child
        end
    end
    return unpack(result)
end
function Native:GetRegions()
    local result = {}
    for _, child in ipairs(self.children) do
        if child.frameType == "FontString" or child.frameType == "Texture" or child.frameType == "Line" then
            result[#result + 1] = child
        end
    end
    return unpack(result)
end
function Native:IsObjectType(kind) return self.frameType:lower() == kind:lower() end
function Native:SetScrollChild(child) self.scrollChild = child end
function Native:SetVerticalScroll(value) self.scroll = value end
function Native:GetVerticalScroll() return self.scroll or 0 end
function Native:GetVerticalScrollRange() return 100 end
function Native:SetValue(value)
    if self.value ~= value then self.value = value; event(self, "OnValueChanged", value) end
end
function Native:GetValue() return self.value or 0 end
function Native:SetTexture(texture) self.texture = texture end
function Native:GetTexture() return self.texture end
function Native:SetFontString(font) self.font = font end
function Native:GetFontString() self.font = self.font or self:CreateFontString(); return self.font end
function Native:SetHighlightTexture(texture)
    self.highlight = self.highlight or self:CreateTexture()
    self.highlight:SetTexture(texture)
end
function Native:GetHighlightTexture() return self.highlight end
function Native:SetNormalTexture(texture) self.normal = texture end
function Native:SetPushedTexture(texture) self.pushed = texture end
function Native:GetNormalTexture() return self:CreateTexture() end
function Native:GetPushedTexture() return self:CreateTexture() end
function Native:GetDisabledTexture() return self:CreateTexture() end
function Native:GetFont() return self.fontPath or "Fonts\\FRIZQT__.TTF", self.fontSize or 12, self.fontFlags or "" end
function Native:SetFont(path, size, flags)
    if path == "Missing.ttf" then return false end
    self.fontPath, self.fontSize, self.fontFlags = path, size, flags
    return true
end
function Native:Enable() self.disabled = false end
function Native:Disable() self.disabled = true end
function Native:EnableMouse() end
function Native:IsOwned() return false end
function Native:IsMouseOver() return self == TestMouseOver end
function Native:IsProtected() return false end
function Native:IsClampedToScreen() return false end
local noops = {
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetClampedToScreen",
    "SetResizeBounds", "SetMinResize", "SetMovable", "SetResizable", "SetToplevel", "Raise", "SetJustifyH",
    "SetJustifyV", "SetWordWrap", "SetNonSpaceWrap", "SetTextColor", "SetColorTexture", "SetVertexColor",
    "SetTexCoord", "SetBlendMode", "SetDrawLayer", "SetFontObject", "SetNormalFontObject", "SetDisabledFontObject",
    "SetHighlightFontObject", "SetHitRectInsets", "EnableMouseWheel", "SetAutoFocus", "SetMultiLine",
    "SetMaxLetters", "SetTextInsets", "SetCountInvisibleLetters", "HighlightText", "SetOrientation", "SetAltArrowKeyMode",
    "SetMinMaxValues", "SetValueStep", "SetThumbTexture", "LockHighlight", "UnlockHighlight", "SetOwner",
    "AddLine", "StartMoving", "StartSizing", "StopMovingOrSizing", "RegisterForClicks", "SetDisabledTexture",
    "RegisterEvent", "UnregisterEvent", "SetAutoFocus", "SetAlpha", "SetScale", "SetSpacing", "SetIndentedWordWrap",
    "RegisterForDrag", "SetDesaturated",
}
for _, name in ipairs(noops) do Native[name] = function() end end
function Native:SetColorTexture(...) self.rgba = { ... } end
function Native:AddLine(text)
    self.numLines = (self.numLines or 0) + 1
    local region = _G[self.name .. "TextLeft" .. self.numLines] or self:CreateFontString(self.name .. "TextLeft" .. self.numLines)
    region:SetText(text)
end
function Native:NumLines() return self.numLines or 0 end
function Native:ClearLines() self.numLines = 0; event(self, "OnTooltipCleared") end
function hooksecurefunc(target, method, callback)
    if type(target) == "string" then target, method, callback = _G, target, method end
    local original = target[method]
    target[method] = function(...)
        local result = { original(...) }
        callback(...)
        return unpack(result)
    end
end
function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({ frameType = frameType, name = name, parent = parent, scripts = {}, points = {},
        children = {}, shown = true }, { __index = Native })
    if name then _G[name] = frame end
    if parent then parent.children[#parent.children + 1] = frame end
    if name and template == "UIDropDownMenuTemplate" then
        for _, suffix in ipairs({ "Left", "Middle", "Right", "Text", "Button" }) do
            _G[name .. suffix] = CreateFrame("Frame", name .. suffix, frame)
        end
    end
    if name and template and template:find("ScrollFrameTemplate") then
        _G[name .. "ScrollBar"] = CreateFrame("Slider", name .. "ScrollBar", frame)
        _G[name .. "ScrollBarScrollUpButton"] = CreateFrame("Button", nil, frame)
        _G[name .. "ScrollBarScrollDownButton"] = CreateFrame("Button", nil, frame)
    end
    return frame
end
function Native:CreateTexture(name) return CreateFrame("Texture", name, self) end
function Native:CreateLine(name) return CreateFrame("Line", name, self) end
function Native:SetStartPoint(...) self.startPoint = { ... } end
function Native:SetEndPoint(...) self.endPoint = { ... } end
function Native:SetThickness(thickness) self.thickness = thickness end
function Native:CreateFontString(name) return CreateFrame("FontString", name, self) end
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")

function AprRC:NewModule()
    return {
        ScheduleRepeatingTimer = function(self, callback) self.timerCallback = callback; return 1 end,
        CancelTimer = function(self) self.timerCallback = nil end,
    }
end
AprRC.record = {
    UpdateRecordButton = function() end,
    StopRecord = function() AprRC.settings.profile.recordBarFrame.isRecording = false end,
}
AprRC.settings.profile.recordBarFrame.isRecording = false
AprRC.settings.OpenSettings = function() end
AprRC.exportExtraLineText = { Show = function() end }
AprRC.CommandBarSetting = { Show = function() end }
APRData = {}

TestCursorX, TestCursorY, TestMouseDown, TestMouseOver = 0, 0, false, nil
GetCursorPosition = function() return TestCursorX, TestCursorY end
IsMouseButtonDown = function() return TestMouseDown end
-- Retail no longer provides this global. Keep it absent to catch regressions.
MouseIsOver = nil
IsKeyDown = function() return false end
