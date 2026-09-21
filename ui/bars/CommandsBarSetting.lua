local GUI = LibStub("AceGUI-3.0")
AprRC.CommandBarSetting = AprRC:NewModule("CommandBarSetting")
local Settings = AprRC.CommandBarSetting

function Settings:Find(command)
    for index, entry in ipairs(AprRC.CommandBar:GetCommands()) do
        if strlower(entry.command) == strlower(command) then return index end
    end
end

function Settings:IsVisible()
    local editor = AprRC.routeEditor
    return editor.frame and editor.tab == "commands" and self.panel and editor.tabs.children[1] == self.panel
end

function Settings:RefreshRunState()
    if not self:IsVisible() then return end
    local active = AprRC.options:CanEdit(AprRCData.CurrentRoute)
    for _, button in ipairs(self.runButtons or {}) do button:SetDisabled(not active) end
end

-- Slot is an insertion position in the original selected list, before removal.
function Settings:ApplyDrop(entry, destination, slot)
    local old = self:Find(entry.command)
    local list = AprRCData.CommandBarCommands
    if destination == "selected" then
        slot = math.max(1, math.min(#list + 1, slot or #list + 1))
        local moved = old and table.remove(list, old) or AprRC:CopyData(entry)
        if old and old < slot then slot = slot - 1 end
        table.insert(list, slot, moved)
    elseif destination == "available" and old then
        table.remove(list, old)
    else return end
    AprRC.CommandBar:RefreshFrameAnchor()
    self:DrawResults()
end

function Settings:ToggleFavorite(entry)
    self:ApplyDrop(entry, self:Find(entry.command) and "available" or "selected")
end

function Settings:Move(command, delta)
    local old = self:Find(command)
    local list = AprRCData.CommandBarCommands
    if not old or old + delta < 1 or old + delta > #list then return end
    self:ApplyDrop(list[old], "selected", old + delta + (delta > 0 and 1 or 0))
end

function Settings:CancelDrag()
    if self.dragging and self.dragging.row then self.dragging.row.frame:SetAlpha(1) end
    self.dragging = nil
    if self.ghost then self.ghost:Hide(); self.ghost:SetScript("OnUpdate", nil) end
    if self.dropLine then self.dropLine:Hide() end
end

function Settings:DropTarget()
    if not self:IsVisible() or not self.selected then return end
    if self.selected.frame:IsMouseOver() then
        local _, y = GetCursorPosition()
        y = y / self.selected.frame:GetEffectiveScale()
        for index, row in ipairs(self.selected.children) do
            if y > row.frame:GetTop() - row.frame:GetHeight() / 2 then return "selected", index end
        end
        return "selected", #self.selected.children + 1
    elseif self.available.frame:IsMouseOver() then return "available" end
end

function Settings:FinishDrag()
    local drag = self.dragging
    self:CancelDrag()
    if not drag then return end
    local target, slot = self:DropTarget()
    if drag and target then self:ApplyDrop(drag.entry, target, slot) end
end

function Settings:StartDrag(row)
    self:CancelDrag()
    if not self.ghost then
        self.ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        self.ghost:SetFrameStrata("TOOLTIP")
        self.ghost:SetSize(240, 34)
        self.ghost:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        self.ghost:SetBackdropColor(0.1, 0.08, 0.04, 0.95)
        self.ghost.label = self.ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.ghost.label:SetPoint("LEFT", 8, 0); self.ghost.label:SetPoint("RIGHT", -8, 0)
        AprRC.textStyle:TrackFont(self.ghost.label)
        self.dropLine = CreateFrame("Frame", nil, UIParent)
        self.dropLine:SetFrameStrata("TOOLTIP"); self.dropLine:SetHeight(3)
        local texture = self.dropLine:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints(); texture:SetColorTexture(1, 0.82, 0.4, 1)
    end
    self.dragging = { entry = row.entry, row = row }
    row.frame:SetAlpha(0.4)
    GameTooltip:Hide()
    self.ghost.label:SetText(row.entry.label)
    self.ghost:Show()
    self.ghost:SetScript("OnUpdate", function(_, elapsed)
        local ok, reason = pcall(self.UpdateDrag, self, elapsed)
        if not ok then
            -- Unhook before reporting: a failure must not fire every frame.
            self:CancelDrag()
            geterrorhandler()(reason)
        end
    end)
end

function Settings:UpdateDrag(elapsed)
    if not self:IsVisible() or IsKeyDown("ESCAPE") then self:CancelDrag(); return end
    if not IsMouseButtonDown("LeftButton") then self:FinishDrag(); return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.ghost:ClearAllPoints(); self.ghost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale + 12)
    local target, slot = self:DropTarget()
    self.dropLine:Hide()
    if target then
        local scroll = target == "selected" and self.selected or self.available
        local cursorY = y / scroll.frame:GetEffectiveScale()
        local direction = cursorY > scroll.frame:GetTop() - 24 and -1 or
            (cursorY < scroll.frame:GetBottom() + 24 and 1 or 0)
        if direction ~= 0 then
            local value = math.max(0, math.min(1000, (scroll.localstatus.scrollvalue or 0) + direction * elapsed * 160))
            scroll.scrollbar:SetValue(value)
            scroll:SetScroll(value)
        end
    end
    if target == "selected" then
        local rows = self.selected.children
        local anchor = rows[slot] or rows[#rows]
        self.dropLine:ClearAllPoints()
        self.dropLine:SetWidth(self.selected.content:GetWidth())
        self.dropLine:SetPoint("TOPLEFT", anchor and anchor.frame or self.selected.content,
            rows[slot] and "TOPLEFT" or (anchor and "BOTTOMLEFT" or "TOPLEFT"))
        self.dropLine:Show()
    end
end

function Settings:DrawResults()
    if not self:IsVisible() or not self.available then return end
    self:CancelDrag()
    local UI = AprRC.editorUI
    local filter = (self.query or ""):lower()
    self.available:ReleaseChildren(); self.selected:ReleaseChildren()
    self.runButtons = {}
    local selected = AprRC.CommandBar:GetCommands()
    local present = {}
    local function add(parent, entry, index)
        local row = AprRC:CreateWidget("APRCommandRow")
        row:SetEntry(entry, index ~= nil, index)
        row:SetCallback("OnToggle", function() self:ToggleFavorite(entry) end)
        row:SetCallback("OnRun", function() AprRC.CommandBar:Run(entry.command) end)
        row:SetCallback("OnDragStart", function() self:StartDrag(row) end)
        row:SetCallback("OnDragStop", function() self:FinishDrag() end)
        row.run:SetUserData("command", entry.command)
        self.runButtons[#self.runButtons + 1] = row.run
        parent:AddChild(row)
    end
    for index, entry in ipairs(selected) do
        present[entry.command:lower()] = true
        add(self.selected, entry, index)
    end
    for _, entry in ipairs(AprRC.options:GetToolbarCatalog()) do
        if not present[entry.command:lower()] and (entry.label .. " " .. entry.command):lower():find(filter, 1, true) then
            add(self.available, entry)
        end
    end
    if #self.available.children == 0 then UI.LabelWidget(self.available, UI.Text("No matching commands.")) end
    -- Keep the selected scroll empty when there are no commands, so slot 1 is
    -- also a valid drop target on an intentionally empty bar.
    self:RefreshRunState()
    self.available:DoLayout(); self.selected:DoLayout()
end

function Settings:DrawSettings(parent)
    local UI = AprRC.editorUI
    local T = UI.Text
    local group = UI.Group(parent, T("Bar settings"))
    local profile = AprRC.settings.profile.commandBarFrame
    local function checkbox(key, label, default)
        local box = AprRC:CreateWidget("CheckBox")
        box:SetLabel(T(label)); box:SetRelativeWidth(0.5)
        box:SetValue(profile[key] == nil and default or profile[key])
        box:SetCallback("OnValueChanged", function(_, _, value)
            profile[key] = value; AprRC.CommandBar:RefreshFrameAnchor()
        end)
        group:AddChild(box)
    end
    checkbox("enabled", "Show command bar", true)
    checkbox("showBackdrop", "Show icon background", true)
    local color = AprRC:CreateWidget("ColorPicker")
    color:SetLabel(T("Icon background color"))
    color:SetHasAlpha(true)
    color:SetFullWidth(true)
    color:SetColor(unpack(profile.backdropColor or { 0.07, 0.055, 0.035, 0.85 }))
    local function updateColor(_, _, r, g, b, a)
        profile.backdropColor = { r, g, b, a }
        AprRC.CommandBar:RefreshFrameAnchor()
    end
    color:SetCallback("OnValueChanged", updateColor)
    color:SetCallback("OnValueConfirmed", updateColor)
    group:AddChild(color)
    local size = AprRC:CreateWidget("Slider")
    size:SetLabel(T("Button size"))
    size:SetFullWidth(true)
    size:SetSliderValues(16, 64, 1)
    size:SetValue(AprRC.CommandBar:GetButtonSize())
    size:SetCallback("OnValueChanged", function(_, _, value) AprRC.CommandBar:SetButtonSize(value) end)
    group:AddChild(size)
    local columns
    local orientation = UI.Dropdown(group, T("Orientation"), { HORIZONTAL = T("Horizontal"), VERTICAL = T("Vertical") },
        profile.rotation or "HORIZONTAL", function(value)
            profile.rotation = value; AprRC.CommandBar:RefreshFrameAnchor()
            columns:SetLabel(value == "VERTICAL" and T("Buttons per column") or T("Buttons per row"))
        end)
    orientation:SetFullWidth(false); orientation:SetRelativeWidth(0.5)
    columns = UI.Dropdown(group, profile.rotation == "VERTICAL" and T("Buttons per column") or T("Buttons per row"), { [1] = "1", [2] = "2", [3] = "3", [4] = "4", [6] = "6", [8] = "8", [10] = "10", [12] = "12" },
        profile.buttonsPerRow or 6, function(value)
            profile.buttonsPerRow = value; AprRC.CommandBar:RefreshFrameAnchor()
        end)
    columns:SetFullWidth(false); columns:SetRelativeWidth(0.5)
    UI.Dropdown(group, T("Snap to route workshop"), {
        NONE = T("Free position"), LEFT = T("Left side"), RIGHT = T("Right side"),
        TOP = T("Top side"), BOTTOM = T("Bottom side"),
    }, profile.snap or "NONE", function(value)
        profile.snap = value; AprRC.CommandBar:RefreshFrameAnchor()
    end)
    UI.Button(group, "Reset command bar", function()
        AprRC.CommandBar:ResetToDefault(); AprRC.routeEditor:DrawTab()
    end, 220)
end

function Settings:Draw(parent)
    local UI, T = AprRC.editorUI, AprRC.editorUI.Text
    AprRC.CommandBar:GetCommands()
    self.panel = UI.Body(parent)
    local header = UI.Toolbar(self.panel)
    self.runButtons = {}
    if self.showSettings then
        self.available, self.selected, self.search = nil, nil, nil
        self:DrawSettings(UI.Scroll(self.panel))
        UI.Button(UI.Toolbar(self.panel, true), "Commands", function()
            self.showSettings = false; AprRC.routeEditor:DrawTab()
        end, 170)
        return
    end
    UI.LabelWidget(header, T("Drag commands between columns to add, remove or reorder them."))
    UI.LabelWidget(header, T("Commands apply to the last recorded step."))
    local search = AprRC:CreateWidget("EditBox")
    search:SetLabel(T("Search commands")); search:SetFullWidth(true); search:DisableButton(true)
    search:SetText(self.query or "")
    search:SetCallback("OnTextChanged", function(_, _, text)
        self.query = text; self:DrawResults(); self.available:SetScroll(0)
    end)
    header:AddChild(search); self.search = search
    local split = UI.Body(self.panel, "APRSplit")
    split.content.aprCompactPane = nil
    for index, label in ipairs({ "Available Commands", "Commands In Bar" }) do
        local column = UI.Body(split)
        UI.LabelWidget(UI.Toolbar(column), T(label), true)
        local scroll = UI.Scroll(column)
        if index == 1 then self.available = scroll else self.selected = scroll end
    end
    local footer = UI.Toolbar(self.panel, true)
    UI.Button(footer, "Bar settings", function()
        self.showSettings = not self.showSettings; AprRC.routeEditor:DrawTab()
    end, 170)
    self:DrawResults()
end

function Settings:Show(showSettings)
    self.showSettings = showSettings == true
    AprRC.routeEditor:Show()
    AprRC.routeEditor:SelectTab("commands")
end
