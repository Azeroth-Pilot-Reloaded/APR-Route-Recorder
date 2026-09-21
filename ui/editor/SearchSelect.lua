local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI

local accents = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
    ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["Ô"] = "o", ["Ö"] = "o",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u", ["ç"] = "c", ["Ç"] = "c",
    ["œ"] = "oe", ["Œ"] = "oe",
}
local function normalize(text)
    return tostring(text):gsub("[\194-\244][\128-\191]+", accents):lower()
end

GUI:RegisterWidgetType("APRSearchSelect", function()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editbox:SetAutoFocus(false)
    editbox:SetFontObject(ChatFontNormal)
    editbox:SetTextInsets(0, 0, 3, 3)
    editbox:SetAltArrowKeyMode(false)
    editbox:SetMaxLetters(256)
    editbox:SetHeight(19)
    editbox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 0)
    editbox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 0)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, -2)
    label:SetPoint("TOPRIGHT", 0, -2)
    label:SetHeight(18)
    label:SetJustifyH("LEFT")
    local widget = { type = "APRSearchSelect", frame = frame, editbox = editbox, label = label, alignoffset = 30 }
    frame.obj, editbox.obj = widget, widget

    function widget:SetText(text)
        self.settingText = true
        self.editbox:SetText(text or "")
        self.settingText = nil
    end
    function widget:SetLabel(text) self.label:SetText(text or "") end
    function widget:GetValue() return self.value end
    function widget:SetValue(value)
        self.value = self.entries[value] and value or nil
        self:SetText(self.value and self.entries[self.value] or "")
    end
    function widget:SetList(entries)
        self.entries, self.order = {}, {}
        for key, text in pairs(entries) do
            self.entries[key] = text
            self.order[#self.order + 1] = key
        end
        table.sort(self.order, function(a, b)
            local left, right = normalize(self.entries[a]), normalize(self.entries[b])
            if left == right then return tostring(a) < tostring(b) end
            return left < right
        end)
    end
    function widget:CloseMenu()
        self.open = false
        if self.pullout then self.pullout:Close() end
    end
    function widget:ClearFocus()
        self:CloseMenu()
        if self.editbox:HasFocus() then self.editbox:ClearFocus() end
    end
    function widget:SetFocus() self.editbox:SetFocus() end
    function widget:Select(key)
        if not self.entries[key] then return end
        self:SetValue(key)
        self:ClearFocus()
        -- Callbacks may redraw the form and release this widget.
        self:Fire("OnValueChanged", key)
    end
    function widget:Highlight(index, scroll)
        self.active = index
        for i, item in ipairs(self.pullout.items) do
            if i == index then item.highlight:Show() else item.highlight:Hide() end
        end
        if scroll then
            local pullout = self.pullout
            local height = pullout.scrollFrame:GetHeight()
            local overflow = pullout.itemFrame:GetHeight() - height
            if overflow > 0 then
                local offset = pullout.scrollStatus.offset or 0
                local top = 2 + (index - 1) * 16
                offset = math.max(0, math.min(offset, top))
                offset = math.min(overflow, math.max(offset, top + 16 - height))
                pullout.slider:SetValue(offset / overflow * 1000)
            end
        end
    end
    function widget:OpenMenu(query)
        local pullout = self.pullout
        if not pullout then
            pullout = AprRC:CreateWidget("Dropdown-Pullout")
            self.pullout = pullout
            pullout:SetCallback("OnClose", function() self.open = false end)
        end
        pullout:Clear()
        self.matches, self.active = {}, nil
        query = normalize(query or "")
        for _, key in ipairs(self.order) do
            local haystack = normalize(self.entries[key] .. " " .. tostring(key))
            local matches = true
            for token in query:gmatch("%S+") do
                if not haystack:find(token, 1, true) then matches = false; break end
            end
            if matches then
                self.matches[#self.matches + 1] = key
                local item = AprRC:CreateWidget("Dropdown-Item-Execute")
                item:SetText(self.entries[key])
                item:SetCallback("OnClick", function() self:Select(key) end)
                pullout:AddItem(item)
            end
        end
        if #self.matches == 0 then
            local item = AprRC:CreateWidget("Dropdown-Item-Execute")
            item:SetText(UI.Text("No matching results."))
            item:SetDisabled(true)
            pullout:AddItem(item)
        end
        local scale = self.editbox:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local below = (self.editbox:GetBottom() or 0) * scale
        local above = UIParent:GetHeight() - (self.editbox:GetTop() or 0) * scale
        local upwards = below < 320 and above > below
        pullout:SetMaxHeight(math.max(60, math.min(320, (upwards and above or below) - 12)))
        pullout:SetWidth(math.min(UIParent:GetWidth() - 20, math.max(260, self.frame:GetWidth())))
        pullout.frame:ClearAllPoints()
        pullout:Open(upwards and "BOTTOMLEFT" or "TOPLEFT", self.editbox,
            upwards and "TOPLEFT" or "BOTTOMLEFT", -6, upwards and 2 or -2)
        pullout.slider:SetValue(0)
        pullout:SetScroll(0)
        self.open = true
        if #self.matches > 0 then self:Highlight(1) end
    end
    function widget:OnAcquire()
        self.entries, self.order, self.matches = {}, {}, {}
        self.value, self.active, self.open = nil, nil, false
        self:SetText("")
        self:SetLabel("")
        self:SetWidth(200)
        self:SetHeight(44)
    end
    function widget:OnRelease()
        self:ClearFocus()
        if self.pullout then GUI:Release(self.pullout); self.pullout = nil end
        self.entries, self.order, self.matches = {}, {}, {}
        self.value, self.active = nil, nil
    end
    editbox:SetScript("OnEditFocusGained", function()
        GUI:SetFocus(widget)
        widget:OpenMenu("")
        editbox:HighlightText()
    end)
    editbox:SetScript("OnEditFocusLost", function()
        if not widget.pullout or not widget.pullout.frame:IsMouseOver() then widget:CloseMenu() end
    end)
    editbox:SetScript("OnMouseDown", function()
        if editbox:HasFocus() and not widget.open then widget:OpenMenu("") end
    end)
    editbox:SetScript("OnTextChanged", function()
        if widget.settingText then return end
        widget.value = nil
        if editbox:HasFocus() then widget:OpenMenu(editbox:GetText()) end
        widget:Fire("OnValueChanged", nil)
    end)
    editbox:SetScript("OnArrowPressed", function(_, key)
        if key ~= "UP" and key ~= "DOWN" then return end
        if not widget.open then widget:OpenMenu(""); return end
        if #widget.matches == 0 then return end
        widget:Highlight(math.max(1, math.min(#widget.matches, (widget.active or 1) + (key == "UP" and -1 or 1))), true)
    end)
    editbox:SetScript("OnEnterPressed", function()
        if widget.open and widget.active then widget:Select(widget.matches[widget.active]) end
    end)
    editbox:SetScript("OnEscapePressed", function() widget:ClearFocus() end)
    editbox:SetScript("OnTabPressed", function() widget:ClearFocus() end)
    frame:SetScript("OnHide", function() widget:ClearFocus() end)
    frame:SetScript("OnUpdate", function()
        if widget.open and IsMouseButtonDown("LeftButton") and not editbox:IsMouseOver()
            and not widget.pullout.frame:IsMouseOver() then widget:ClearFocus() end
    end)
    return GUI:RegisterAsWidget(widget)
end, 1)

function UI.SearchSelect(parent, label, entries, value, callback)
    local widget = AprRC:CreateWidget("APRSearchSelect")
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    widget:SetList(entries)
    widget:SetValue(value)
    widget:SetCallback("OnValueChanged", function(_, _, selected) callback(selected) end)
    parent:AddChild(widget)
    return widget
end
