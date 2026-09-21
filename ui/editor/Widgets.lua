local GUI = LibStub("AceGUI-3.0")
local UI = AprRC.editorUI

GUI:RegisterWidgetType("APRIconButton", function()
    local frame = CreateFrame("Button", nil, UIParent)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")
    frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local widget = { type = "APRIconButton", frame = frame, icon = icon }
    function widget:OnAcquire() self:SetWidth(30); self:SetHeight(30); self:SetDisabled(false) end
    function widget:OnRelease() self.tooltip = nil; GameTooltip:Hide() end
    function widget:SetIcon(name) icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\ui\\" .. name) end
    function widget:SetText(text) self.tooltip = text end
    function widget:SetDisabled(disabled)
        self.disabled = disabled
        if disabled then frame:Disable(); icon:SetAlpha(0.3) else frame:Enable(); icon:SetAlpha(1) end
    end
    frame:SetScript("OnClick", function() if not widget.disabled then widget:Fire("OnClick") end end)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:AddLine(widget.tooltip or "", 1, 0.82, 0.4, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return GUI:RegisterAsWidget(widget)
end, 1)

function UI.IconButton(parent, icon, tooltip, callback)
    local button = GUI:Create("APRIconButton")
    button:SetIcon(icon)
    button:SetText(UI.Text(tooltip))
    button:SetCallback("OnClick", callback)
    if parent then parent:AddChild(button) end
    return button
end

-- The content and trailing action have separate widths; compound entries put
-- their action below the content, while scalar controls keep it alongside.
GUI:RegisterLayout("APRField", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local body, action = children[1], children[2]
    local width = content:GetWidth()
    local compound = content.obj:GetUserData("compound")
    local height = 0
    if body then
        body:SetWidth(math.max(1, width - (action and not compound and 36 or 0)))
        body.frame:ClearAllPoints()
        body.frame:SetPoint("TOPLEFT", content, "TOPLEFT")
        body:DoLayout()
        height = body.frame:GetHeight()
        body.frame:Show()
    end
    if action then
        action.frame:ClearAllPoints()
        action.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, compound and -(height + 4) or -8)
        action.frame:Show()
        height = compound and height + 34 or math.max(height, 38)
    end
    content.obj:LayoutFinished(width, height)
    content.aprLayout = nil
end)

GUI:RegisterWidgetType("APRSplitGroup", function()
    local frame = CreateFrame("Frame", nil, UIParent)
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    local divider = CreateFrame("Button", nil, content)
    local rail = divider:CreateTexture(nil, "ARTWORK")
    rail:SetColorTexture(0.72, 0.58, 0.34, 0.6)
    rail:SetPoint("TOP", 0, -8); rail:SetPoint("BOTTOM", 0, 8); rail:SetWidth(2)
    divider:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local widget = { type = "APRSplitGroup", frame = frame, content = content, divider = divider }
    function widget:OnAcquire()
        self.ratio = 0.49; content.aprCompactPane = nil
        self:SetWidth(300); self:SetHeight(100); self:SetLayout("APRSplit")
    end
    function widget:OnRelease()
        divider:SetScript("OnUpdate", nil); self.dragging = nil; content.aprCompactPane = nil
    end
    function widget:OnWidthSet(width) content:SetWidth(width) end
    function widget:OnHeightSet(height) content:SetHeight(height) end
    function widget:LayoutFinished() end
    function widget:SetRatio(ratio)
        self.ratio = math.max(0.30, math.min(0.70, tonumber(ratio) or 0.49))
        self:DoLayout()
        self:Fire("OnRatioChanged", self.ratio)
    end
    local function stop()
        widget.dragging = nil; divider:SetScript("OnUpdate", nil)
    end
    divider:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        widget.dragging = true
        divider:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then stop(); return end
            local x = GetCursorPosition()
            widget:SetRatio((x / content:GetEffectiveScale() - content:GetLeft()) / math.max(1, content:GetWidth() - 14))
        end)
    end)
    divider:SetScript("OnMouseUp", stop)
    divider:SetScript("OnHide", stop)
    divider:SetScript("OnEnter", function()
        GameTooltip:SetOwner(divider, "ANCHOR_TOP")
        GameTooltip:AddLine(UI.Text("Drag to resize columns"), 1, 1, 1)
        GameTooltip:Show()
    end)
    divider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return GUI:RegisterAsContainer(widget)
end, 1)

-- A draggable command row owns its native drag scripts throughout pool reuse.
GUI:RegisterWidgetType("APRCommandRow", function()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24); icon:SetPoint("LEFT", 3, 0)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 32, 0); label:SetPoint("RIGHT", -64, 0)
    label:SetJustifyH("LEFT"); label:SetWordWrap(true); label:SetHeight(42)
    local widget = { type = "APRCommandRow", frame = frame }
    function widget:OnAcquire() self:SetHeight(48); self:SetFullWidth(true) end
    function widget:SetEntry(entry, selected, index)
        self.entry, self.selected = entry, selected
        icon:SetTexture(entry.texture)
        label:SetText((index and index .. ". " or "") .. entry.label)
        self.run = UI.IconButton(nil, "play", "Run command", function() self:Fire("OnRun") end)
        self.action = UI.IconButton(nil, selected and "trash" or "add", selected and "Remove from bar" or "Add to bar",
            function() self:Fire("OnToggle") end)
        for offset, button in ipairs({ self.action, self.run }) do
            button.frame:SetParent(frame); button.frame:SetPoint("RIGHT", frame, "RIGHT", -2 - (offset - 1) * 30, 0)
            button.frame:Show()
        end
    end
    function widget:OnRelease()
        if self.run then GUI:Release(self.run); GUI:Release(self.action) end
        self.run, self.action, self.entry, self.selected, self.dragged = nil, nil, nil, nil, nil
    end
    frame:SetScript("OnDragStart", function() widget.dragged = true; widget:Fire("OnDragStart") end)
    frame:SetScript("OnDragStop", function() widget:Fire("OnDragStop") end)
    frame:SetScript("OnMouseDown", function() widget.dragged = nil end)
    frame:SetScript("OnClick", function(_, button)
        if button == "RightButton" and widget.selected and not widget.dragged then widget:Fire("OnToggle") end
    end)
    frame:SetScript("OnEnter", function()
        if not widget.entry then return end
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:AddLine(widget.entry.label, 1, 0.82, 0.4)
        GameTooltip:AddLine("/aprrc " .. widget.entry.command, 1, 1, 1)
        GameTooltip:AddLine(UI.Text("Drag commands between columns to add, remove or reorder them."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return GUI:RegisterAsWidget(widget)
end, 1)

-- AceGUI's Fill only relayouts its child after a size change. Explicitly lay out
-- rebuilt tab contents even when a pooled container has the same dimensions.
GUI:RegisterLayout("APRFill", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local child = children[1]
    if child then
        child:SetWidth(content:GetWidth())
        child:SetHeight(content:GetHeight())
        child.frame:ClearAllPoints()
        child.frame:SetAllPoints(content)
        child.frame:Show()
        if child.DoLayout then child:DoLayout() end
    end
    content.aprLayout = nil
end)

-- Layouts own sizing; no resize hooks are added to pooled AceGUI frames.
GUI:RegisterLayout("APRWorkspace", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local width, height = content:GetWidth(), content:GetHeight()
    -- Measure wrapping toolbars before allocating the remaining height.
    for _, child in ipairs(children) do
        if not child:GetUserData("body") then
            child:SetWidth(width)
            if child.DoLayout then child:DoLayout() end
        end
    end
    local top = 0
    local footer = children[#children]
    local bottom = footer and footer:GetUserData("footer") and (footer.frame:GetHeight() + 8) or 0
    for index, child in ipairs(children) do
        local frame = child.frame
        frame:ClearAllPoints()
        child:SetWidth(width)
        if index == #children and bottom > 0 then
            frame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT")
        else
            frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            if child:GetUserData("body") then child:SetHeight(math.max(60, height - top - bottom)) end
            top = top + frame:GetHeight() + 8
        end
        frame:Show()
        if child.DoLayout then child:DoLayout() end
    end
    content.aprLayout = nil
end)

GUI:RegisterLayout("APRSplit", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local width, height = content:GetWidth(), content:GetHeight()
    if content.aprCompactPane then
        if content.obj.divider then content.obj.divider:Hide() end
        for index, child in ipairs(children) do
            if index == (content.aprCompactPane == "inspector" and 2 or 1) then
                child.frame:ClearAllPoints()
                child.frame:SetPoint("TOPLEFT", content, "TOPLEFT")
                child:SetWidth(width)
                child:SetHeight(height)
                child.frame:Show()
                child:DoLayout()
            else
                child.frame:Hide()
            end
        end
        content.aprLayout = nil
        return
    end
    local owner = content.obj
    local left = math.floor((width - 14) * (owner.ratio or 0.49))
    if owner.divider then
        owner.divider:Show()
        owner.divider:ClearAllPoints()
        owner.divider:SetPoint("TOPLEFT", content, "TOPLEFT", left, 0)
        owner.divider:SetSize(14, height)
    end
    for index, child in ipairs(children) do
        child.frame:ClearAllPoints()
        child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", index == 1 and 0 or left + 14, 0)
        child:SetWidth(index == 1 and left or width - left - 14)
        child:SetHeight(height)
        child.frame:Show()
        child:DoLayout()
    end
    content.aprLayout = nil
end)

GUI:RegisterWidgetType("APRStepRow", function()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetHeight(72)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local rail = frame:CreateTexture(nil, "ARTWORK")
    rail:SetPoint("TOPLEFT", 0, -3)
    rail:SetPoint("BOTTOMLEFT", 0, 3)
    rail:SetWidth(3)
    local number = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    number:SetPoint("TOPLEFT", 9, -13)
    number:SetWidth(28)
    number:SetJustifyH("CENTER")
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(23, 23)
    icon:SetPoint("TOPLEFT", 40, -10)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 71, -10)
    title:SetPoint("RIGHT", -9, 0)
    title:SetHeight(17)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", 40, -32)
    detail:SetPoint("RIGHT", -9, 0)
    detail:SetHeight(16)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(false)
    local meta = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    meta:SetPoint("TOPLEFT", 40, -51)
    meta:SetPoint("RIGHT", -9, 0)
    meta:SetHeight(14)
    meta:SetJustifyH("LEFT")
    meta:SetWordWrap(false)
    frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local widget = { type = "APRStepRow", frame = frame }
    function widget:OnAcquire() self:SetHeight(72); self:SetFullWidth(true) end
    function widget:SetStep(index, heading, description, metadata, texture, selected, color)
        number:SetText(index)
        title:SetText(heading)
        detail:SetText(description)
        meta:SetText(metadata)
        icon:SetTexture(texture)
        title:SetTextColor(unpack(color))
        rail:SetColorTexture(color[1], color[2], color[3], 1)
        background:SetColorTexture(selected and 0.30 or (index % 2 == 0 and 0.10 or 0.06),
            selected and 0.23 or 0.08, selected and 0.10 or 0.06, 0.9)
    end
    frame:SetScript("OnClick", function() widget:Fire("OnClick") end)
    frame:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return GUI:RegisterAsWidget(widget)
end, 1)
