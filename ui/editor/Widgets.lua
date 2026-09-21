local GUI = LibStub("AceGUI-3.0")

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
    local left = math.floor((width - 14) * 0.49)
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
