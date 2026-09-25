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
    function widget:OnRelease()
        self.tooltip, self.pickerPath, self.pickerKind = nil, nil, nil
        GameTooltip:Hide()
    end
    function widget:SetIcon(name)
        if name == "refresh" and not self.refreshLines then
            -- A continuous clockwise arc with an arrowhead tangent to its end.
            -- Native lines keep the small control sharp without a raster asset.
            self.refreshLines = {}
            local function line(x1, y1, x2, y2)
                local segment = frame:CreateLine(nil, "ARTWORK")
                segment:SetColorTexture(239 / 255, 205 / 255, 141 / 255, 1)
                segment:SetThickness(2)
                segment:SetStartPoint("CENTER", frame, x1, y1)
                segment:SetEndPoint("CENTER", frame, x2, y2)
                self.refreshLines[#self.refreshLines + 1] = segment
            end
            local start, finish, segments, radius = math.rad(10), math.rad(-315), 40, 8.5
            for index = 1, segments do
                local a = start + (finish - start) * (index - 1) / segments
                local b = start + (finish - start) * index / segments
                line(radius * math.cos(a), radius * math.sin(a), radius * math.cos(b), radius * math.sin(b))
            end
            local x, y = radius * math.cos(finish), radius * math.sin(finish)
            local dx, dy = math.sin(finish), -math.cos(finish)
            line(x - 4.5 * dx - 2.5 * dy, y - 4.5 * dy + 2.5 * dx, x, y)
            line(x, y, x - 4.5 * dx + 2.5 * dy, y - 4.5 * dy - 2.5 * dx)
        end
        for _, segment in ipairs(self.refreshLines or {}) do
            if name == "refresh" then segment:Show() else segment:Hide() end
        end
        if name == "search" then icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); icon:Show()
        elseif name == "refresh" then icon:Hide()
        else icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\ui\\" .. name); icon:Show() end
    end
    function widget:SetText(text) self.tooltip = text end
    function widget:SetDisabled(disabled)
        self.disabled = disabled
        if disabled then frame:Disable(); icon:SetAlpha(0.3) else frame:Enable(); icon:SetAlpha(1) end
        for _, segment in ipairs(self.refreshLines or {}) do segment:SetAlpha(disabled and 0.3 or 1) end
    end
    frame:SetScript("OnClick", function() if not widget.disabled then widget:Fire("OnClick") end end)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        AprRC:AddTooltipLine(GameTooltip, widget.tooltip or "", 1, 0.82, 0.4, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return GUI:RegisterAsWidget(widget)
end, 1)

function UI.IconButton(parent, icon, tooltip, callback)
    local button = AprRC:CreateWidget("APRIconButton")
    button:SetIcon(icon)
    button:SetText(UI.Text(tooltip))
    button:SetCallback("OnClick", callback)
    if parent then parent:AddChild(button) end
    return button
end

-- A scalar input and its actions share one line. Validation only consumes space
-- when there is an error; multiline values retain the ordinary Flow layout.
GUI:RegisterLayout("APRInput", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local control = children[1]
    local actions = children[#children]
    if not actions or not actions:GetUserData("pickerActions") then actions = nil end
    local width, height = content:GetWidth(), 0
    local actionWidth = actions and #actions.children * 34 or 0
    if control then
        control:SetWidth(math.max(1, width - actionWidth))
        control.frame:ClearAllPoints()
        control.frame:SetPoint("TOPLEFT", content, "TOPLEFT")
        control.frame:Show()
        height = control.frame:GetHeight()
    end
    if actions then
        actions:SetWidth(actionWidth)
        actions.frame:ClearAllPoints()
        actions.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 15 - (control.alignoffset or height / 2))
        actions:DoLayout()
        actions.frame:Show()
    end
    for index = 2, #children do
        local child = children[index]
        if child ~= actions then
            if child:GetUserData("validation") and child.label:GetText() == "" then
                child.frame:Hide()
            else
                child:SetWidth(width)
                child.frame:ClearAllPoints()
                child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -height)
                child.frame:Show()
                height = height + child.frame:GetHeight()
            end
        end
    end
    content.obj:LayoutFinished(width, height)
    content.aprLayout = nil
end)

GUI:RegisterLayout("APRColumns", function(content, children)
    if content.aprLayout then return end
    content.aprLayout = true
    local total, height, left = 0, 0, 0
    for _, child in ipairs(children) do total = total + (child:GetUserData("weight") or 1) end
    local available = math.max(1, content:GetWidth() - math.max(0, #children - 1) * 6)
    for _, child in ipairs(children) do
        local width = available * (child:GetUserData("weight") or 1) / total
        child:SetWidth(width)
        child.frame:ClearAllPoints()
        child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", left, 0)
        child:DoLayout()
        child.frame:Show()
        height = math.max(height, child.frame:GetHeight())
        left = left + width + 6
    end
    content.obj:LayoutFinished(content:GetWidth(), height)
    content.aprLayout = nil
end)

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
        if compound then
            action.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(height + 4))
        else
            local control = body:GetUserData("alignControl") or body.children[1]
            if control.editbox then
                -- The widget includes a label above the actual input. Anchor
                -- to the input itself so the trash stays vertically centered.
                action.frame:SetPoint("RIGHT", control.editbox, "RIGHT", 36, 0)
            else
                local center = control.alignoffset or control.frame:GetHeight() / 2
                action.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, action.frame:GetHeight() / 2 - center)
            end
        end
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
        AprRC:AddTooltipLine(GameTooltip, UI.Text("Drag to resize columns"), 1, 1, 1)
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
        AprRC:AddTooltipLine(GameTooltip, widget.entry.label, 1, 0.82, 0.4)
        AprRC:AddTooltipLine(GameTooltip, "/aprrc " .. widget.entry.command, 1, 1, 1)
        AprRC:AddTooltipLine(GameTooltip, UI.Text("Drag commands between columns to add, remove or reorder them."), 0.8, 0.8, 0.8, true)
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
    local widget = { type = "APRStepRow", frame = frame, badgeFrames = {} }
    local function badgeFrame(index)
        if widget.badgeFrames[index] then return widget.badgeFrames[index] end
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(22, 22)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.text:SetPoint("CENTER")
        button.cross = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.cross:SetPoint("BOTTOMRIGHT", 2, -2)
        button.cross:SetText("|cffff5555×|r")
        button:SetScript("OnClick", function() widget:Fire("OnClick") end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            if button.badge then
                UI.BadgeTooltip(button.badge)
            else
                for i = button.overflowStart, #widget.conditionBadges do
                    UI.BadgeTooltip(widget.conditionBadges[i])
                end
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        widget.badgeFrames[index] = button
        return button
    end
    function widget:LayoutBadges(width)
        local badges = self.conditionBadges or {}
        local slots = math.max(1, math.min(8, math.floor(((width or frame:GetWidth()) - 170) / 24)))
        local count = math.min(#badges, slots)
        local visible = #badges > slots and count - 1 or count
        for _, button in ipairs(self.badgeFrames) do
            button:Hide()
            button.badge, button.overflowStart = nil, nil
        end
        for i = 1, count do
            local button = badgeFrame(i)
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9 - (count - i) * 24, -8)
            if i <= visible then
                local badge = badges[i]
                button.badge = badge
                button.icon:SetTexture(nil)
                button.icon:SetTexCoord(0, 1, 0, 1)
                if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(badge.atlas) then
                    button.icon:SetAtlas(badge.atlas)
                else
                    button.icon:SetTexture("Interface\\AddOns\\APR-Recorder\\assets\\icons\\" ..
                        (badge.kind == "class" and "Class" or "race") .. ".blp")
                end
                button.icon:Show()
                button.text:Hide()
                if badge.excluded then button.cross:Show() else button.cross:Hide() end
            else
                button.overflowStart = visible + 1
                button.icon:Hide()
                button.cross:Hide()
                button.text:SetText("+" .. (#badges - visible))
                button.text:Show()
            end
            button:Show()
        end
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", 71, -10)
        title:SetPoint("RIGHT", -(9 + (count > 0 and count * 24 + 4 or 0)), 0)
    end
    function widget:SetConditionBadges(badges)
        self.conditionBadges = badges
        self:LayoutBadges()
    end
    function widget:OnWidthSet(width) self:LayoutBadges(width) end
    function widget:OnAcquire()
        self:SetHeight(72)
        self:SetFullWidth(true)
        self:SetConditionBadges({})
    end
    function widget:OnRelease()
        self:SetConditionBadges({})
        GameTooltip:Hide()
    end
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
end, 2)
