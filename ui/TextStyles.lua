local GUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local Styles = {}
AprRC.textStyle = Styles

local owners = setmetatable({}, { __mode = "k" })
local registrations = setmetatable({}, { __mode = "k" })
local hooks = setmetatable({}, { __mode = "k" })
local selectors = setmetatable({}, { __mode = "k" })
local validFlags = { NONE = true, OUTLINE = true, THICKOUTLINE = true,
    MONOCHROME = true, ["MONOCHROME,OUTLINE"] = true }

function Styles:GetAppearance()
    local profile = AprRC.settings and AprRC.settings.profile
    if not profile then return { font = "DEFAULT", flags = "NONE" } end
    profile.textAppearance = profile.textAppearance or { font = "DEFAULT", flags = "NONE" }
    return profile.textAppearance
end

function Styles:GetMedia()
    local media = LibStub("LibSharedMedia-3.0", true)
    if media and self.media ~= media then
        self.media = media
        media.RegisterCallback(self, "LibSharedMedia_Registered", "MediaChanged")
        media.RegisterCallback(self, "LibSharedMedia_SetGlobal", "MediaChanged")
    end
    return media
end

function Styles:GetFontValues()
    local values = { DEFAULT = L["Default font"] }
    local media = self:GetMedia()
    for name in pairs(media and media:HashTable("font") or {}) do values[name] = name end
    -- Keep a saved choice when its provider hasn't loaded yet. It will resolve
    -- automatically when that addon registers its fonts with SharedMedia.
    local selected = self:GetAppearance().font
    if selected and not values[selected] then values[selected] = selected end
    return values
end

function Styles:GetFlagValues()
    return { NONE = L["No outline"], OUTLINE = L["Outline"], THICKOUTLINE = L["Thick outline"],
        MONOCHROME = L["Monochrome"], ["MONOCHROME,OUTLINE"] = L["Monochrome outline"] }
end

function Styles:Apply(region, original)
    local appearance = self:GetAppearance()
    local media = self:GetMedia()
    local font = appearance.font ~= "DEFAULT" and media and media:Fetch("font", appearance.font, true)
    local flags = validFlags[appearance.flags] and appearance.flags ~= "NONE" and appearance.flags or ""
    if not region:SetFont(font or original.font, original.size, flags) then
        region:SetFont(original.font, original.size, flags)
    end
end

function Styles:Register(owner, region)
    if not region or not region.GetFont then return end
    local original = registrations[region]
    if not original then
        local font, size, flags = region:GetFont()
        if not font or not size then return end
        original = { font = font, size = size, flags = flags or "", owner = owner }
        registrations[region] = original
        owners[owner] = owners[owner] or {}
        owners[owner][region] = original
    end
    self:Apply(region, original)
end

function Styles:Release(owner)
    for region, original in pairs(owners[owner] or {}) do
        region:SetFont(original.font, original.size, original.flags)
        registrations[region] = nil
    end
    owners[owner], selectors[owner] = nil, nil
end

function Styles:ScanFrame(owner, frame)
    if frame.IsObjectType and frame:IsObjectType("EditBox") then self:Register(owner, frame) end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("FontString") then self:Register(owner, region) end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local widget = child.obj
            if widget and widget ~= owner and widget.frame == child and widget.events then
                self:TrackWidget(widget)
            else
                self:ScanFrame(owner, child)
            end
        end
    end
end

function Styles:TrackWidget(widget)
    if not owners[widget] then
        owners[widget] = {}
        widget:SetCallback("OnRelease", function(released) self:Release(released) end)
    end
    -- These methods create native tab buttons or detached dropdown rows after
    -- acquisition. Hooks stay dormant when another addon reuses the widget.
    if not hooks[widget] then
        hooks[widget] = true
        for _, method in ipairs({ "SetTabs", "BuildTabs", "SetList", "AddItem" }) do
            if widget[method] then
                hooksecurefunc(widget, method, function()
                    if owners[widget] then self:TrackWidget(widget) end
                end)
            end
        end
    end
    self:ScanFrame(widget, widget.frame)
    if widget.type == "Dropdown" and widget.pullout then self:TrackWidget(widget.pullout) end
    for _, item in ipairs(widget.items or {}) do self:TrackWidget(item) end
end

function AprRC:CreateWidget(kind)
    local widget = GUI:Create(kind)
    Styles:TrackWidget(widget)
    return widget
end

function Styles:TrackFont(region)
    self:Register(region, region)
end

function Styles:TemporaryFrame(frame)
    if not hooks[frame] then
        hooks[frame] = true
        frame:HookScript("OnHide", function() self:Release(frame) end)
    end
    self:ScanFrame(frame, frame)
end

function Styles:TooltipLine(tooltip)
    local name = tooltip:GetName()
    if not name then return end
    if not hooks[tooltip] then
        hooks[tooltip] = true
        tooltip:HookScript("OnHide", function() self:Release(tooltip) end)
        tooltip:HookScript("OnTooltipCleared", function() self:Release(tooltip) end)
    end
    local line = tooltip:NumLines()
    self:Register(tooltip, _G[name .. "TextLeft" .. line])
    self:Register(tooltip, _G[name .. "TextRight" .. line])
end

function AprRC:AddTooltipLine(tooltip, ...)
    tooltip:AddLine(...)
    Styles:TooltipLine(tooltip)
end

function Styles:Refresh()
    for region, original in pairs(registrations) do self:Apply(region, original) end
    -- Changing font metrics requires measuring the existing widgets again,
    -- without rebuilding forms or losing the user's keyboard focus.
    for widget in pairs(owners) do
        if widget.DoLayout and widget.frame and widget.frame:IsShown() then widget:DoLayout() end
    end
end

function Styles:MediaChanged(_, mediaType)
    if mediaType ~= "font" then return end
    self:Refresh()
    for widget in pairs(selectors) do
        widget:SetList(self:GetFontValues())
        widget:SetValue(self:GetAppearance().font or "DEFAULT")
    end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry and AprRC.title then registry:NotifyChange(AprRC.title) end
end

function Styles:Set(key, value)
    self:GetAppearance()[key] = value
    self:Refresh()
end

function Styles:Draw(parent)
    local UI = AprRC.editorUI
    local group = UI.Group(parent, L["Text appearance"])
    local appearance = self:GetAppearance()
    local fonts = UI.Dropdown(group, L["Font"], self:GetFontValues(), appearance.font or "DEFAULT",
        function(value) self:Set("font", value) end)
    selectors[fonts] = true
    UI.Dropdown(group, L["Font style"], self:GetFlagValues(), appearance.flags or "NONE",
        function(value) self:Set("flags", value) end)
end

function Styles:CreateOptions()
    return {
        order = 4.2, type = "group", name = L["Text appearance"], inline = true,
        args = {
            font = { order = 1, type = "select", name = L["Font"], width = "full",
                values = function() return self:GetFontValues() end,
                get = function() return self:GetAppearance().font or "DEFAULT" end,
                set = function(_, value) self:Set("font", value) end },
            flags = { order = 2, type = "select", name = L["Font style"], width = "full",
                values = function() return self:GetFlagValues() end,
                get = function() return self:GetAppearance().flags or "NONE" end,
                set = function(_, value) self:Set("flags", value) end },
        },
    }
end

function Styles:Initialize()
    self:GetMedia()
    local dialog = LibStub("AceConfigDialog-3.0", true)
    if dialog and not self.configHooked then
        self.configHooked = true
        hooksecurefunc(dialog, "Open", function(_, appName, container)
            if appName == AprRC.title or appName == AprRC.title .. "/Profile" then
                local widget = container or dialog.OpenFrames[appName]
                if widget then self:TrackWidget(widget) end
            end
        end)
    end
    self:Refresh()
end

-- SharedMedia providers can load after the recorder, including on demand.
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function() Styles:GetMedia(); Styles:MediaChanged(nil, "font") end)
