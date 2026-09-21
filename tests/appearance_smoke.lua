local GUI = LibStub("AceGUI-3.0")
local Styles, E, Bar, Settings = AprRC.textStyle, AprRC.routeEditor, AprRC.CommandBar, AprRC.CommandBarSetting
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end

-- Icon backgrounds default on, apply to utility icons too, and retain RGBA
-- when toggled off and back on through the actual settings callbacks.
AprRC.settings.profile.recordBarFrame.isRecording = true
AprRC.settings.profile.commandBarFrame.showBackdrop = nil
Bar:RefreshFrameAnchor()
assert(Bar.btnList[1].background:IsShown() and Bar.settingsButton.background:IsShown())
Bar:ResetToDefault()
Settings:Show(true)
assert(Bar.btnList[1].background:IsShown() and Bar.settingsButton.background:IsShown())
local color = assert(find(Settings.panel, function(w) return w.type == "ColorPicker" end))
color:Fire("OnValueChanged", 0.2, 0.4, 0.6, 0.3)
assert(Bar.settingsButton.background.rgba[4] == 0.3 and Bar.btnList[1].background.rgba[2] == 0.4)
local background = assert(find(Settings.panel, function(w)
    return w.type == "CheckBox" and w.text:GetText() == AprRC.editorUI.Text("Show icon background")
end))
background:Fire("OnValueChanged", false)
assert(not Bar.btnList[1].background:IsShown() and not Bar.settingsButton.background:IsShown())
background:Fire("OnValueChanged", true)
assert(Bar.btnList[1].background:IsShown() and Bar.btnList[1].background.rgba[4] == 0.3)
color:Fire("OnValueConfirmed", 0.1, 0.2, 0.3, 0.8)
Settings:Show(false); Settings:Show(true)
assert(find(Settings.panel, function(w) return w.type == "ColorPicker" end).a == 0.8)

-- Model the public SharedMedia registry: providers may register at any time.
local media = LibStub:NewLibrary("LibSharedMedia-3.0", 99999999)
local fonts, callbacks = {}, {}
function media:HashTable(kind) return kind == "font" and fonts or {} end
function media:Fetch(kind, name) return kind == "font" and fonts[name] or nil end
function media.RegisterCallback(listener, event, method)
    callbacks[event] = function(...) listener[method](listener, event, ...) end
end
function media:Register(kind, name, path)
    fonts[name] = path
    if callbacks.LibSharedMedia_Registered then callbacks.LibSharedMedia_Registered(kind, name) end
end
Styles:GetMedia()
media:Register("font", "Other addon font", "Interface\\AddOns\\OtherAddon\\Font.ttf")
E:SelectTab("tools")
local fontSelector = assert(find(E.tabs, function(w) return w.type == "Dropdown" and w.list.DEFAULT end))
assert(fontSelector.list["Other addon font"], "Fonts from other addons must appear")
local label = AprRC:CreateWidget("Label")
local original, originalSize, originalFlags = label.label:GetFont()
local edit = AprRC:CreateWidget("EditBox")
edit:SetText("Draft in progress"); edit:SetFocus(); edit.editbox:SetCursorPosition(7)
fontSelector:Fire("OnValueChanged", "Other addon font")
Styles:Set("flags", "THICKOUTLINE")
local font, size, flags = label.label:GetFont()
assert(font == fonts["Other addon font"] and size == originalSize and flags == "THICKOUTLINE")
assert(edit.editbox:GetFont() == font and edit.editbox:HasFocus())
assert(edit:GetText() == "Draft in progress" and edit.editbox:GetCursorPosition() == 7)
local tabFont = assert(find(E.tabs, function(w) return w.type == "Heading" end))
assert(tabFont.label:GetFont() == font)

-- Missing providers keep their saved names and resolve live when registered.
Styles:Set("font", "Late font")
assert(label.label:GetFont() == original)
media:Register("font", "Late font", "Interface\\AddOns\\LateAddon\\Font.ttf")
assert(label.label:GetFont() == fonts["Late font"] and fontSelector.list["Late font"])
media:Register("font", "Broken font", "Missing.ttf")
Styles:Set("font", "Broken font")
assert(label.label:GetFont() == original, "Invalid font files must use the widget's original font")
Styles:Set("font", "Other addon font")

-- Addon settings rendered by AceConfig receive the same style; unrelated
-- addons using the shared dialog library do not.
local dialog = LibStub:NewLibrary("AceConfigDialog-3.0", 99999999)
AprRC.title = "Recorder appearance test"
function dialog:Open(_, container) self.opened = container end
Styles:Initialize()
local configLabel = GUI:Create("Label")
dialog:Open(AprRC.title, configLabel)
assert(configLabel.label:GetFont() == fonts["Other addon font"])
GUI:Release(configLabel)
local otherConfig = GUI:Create("Label")
dialog:Open("Another addon", otherConfig)
assert(otherConfig.label:GetFont() == original)
GUI:Release(otherConfig)

-- A released shared widget restores its exact original font, before reuse by
-- another addon. Future recorder refreshes must leave that widget untouched.
GUI:Release(label)
local foreign = GUI:Create("Label")
assert(foreign == label)
font, size, flags = foreign.label:GetFont()
assert(font == original and size == originalSize and flags == originalFlags)
Styles:Set("flags", "MONOCHROME,OUTLINE")
assert(select(3, foreign.label:GetFont()) == originalFlags)
GUI:Release(foreign); GUI:Release(edit)

-- Dropdown rows are owned separately, including rows rebuilt by SetList.
local dropdown = AprRC:CreateWidget("Dropdown")
dropdown:SetList({ one = "One", two = "Two" })
local item = dropdown.pullout.items[1]
local text = item.text
assert(text:GetFont() == fonts["Other addon font"])
dropdown:SetList({ three = "Three" })
GUI:Release(dropdown)
assert(text:GetFont() == original)

-- Tooltip and popup styling ends when their shared Blizzard frame is hidden.
GameTooltip:ClearLines(); GameTooltip:Show()
AprRC:AddTooltipLine(GameTooltip, "Recorder tooltip")
local line = _G.GameTooltipTextLeft1
assert(line:GetFont() == fonts["Other addon font"])
GameTooltip:Hide()
assert(line:GetFont() == original)
local popup = CreateFrame("Frame", nil, UIParent)
local popupText = popup:CreateFontString()
Styles:TemporaryFrame(popup)
assert(popupText:GetFont() == fonts["Other addon font"])
popup:Hide()
assert(popupText:GetFont() == original)

Styles:Set("font", "DEFAULT"); Styles:Set("flags", "NONE")
E:Hide()
AprRC.settings.profile.recordBarFrame.isRecording = false
Bar:RefreshFrameAnchor()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Icon RGBA settings, shared fonts, late providers, font fallback, focus and widget isolation passed.")
