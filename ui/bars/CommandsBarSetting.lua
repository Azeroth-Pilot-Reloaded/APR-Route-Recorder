local GUI = LibStub("AceGUI-3.0")
AprRC.CommandBarSetting = AprRC:NewModule("CommandBarSetting")
local Settings = AprRC.CommandBarSetting
local PAGE_SIZE = 20

function Settings:Find(command)
    for index, entry in ipairs(AprRC.CommandBar:GetCommands()) do
        if strlower(entry.command) == strlower(command) then return index end
    end
end

function Settings:ToggleFavorite(entry)
    local index = self:Find(entry.command)
    if index then table.remove(AprRCData.CommandBarCommands, index)
    else table.insert(AprRCData.CommandBarCommands, AprRC:CopyData(entry)) end
    AprRC.CommandBar:RefreshFrameAnchor()
    self:DrawResults()
end

function Settings:Move(command, delta)
    local index = self:Find(command)
    local list = AprRCData.CommandBarCommands
    if not index or index + delta < 1 or index + delta > #list then return end
    table.insert(list, index + delta, table.remove(list, index))
    AprRC.CommandBar:RefreshFrameAnchor()
    self:DrawResults()
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

function Settings:DrawResults()
    if not self:IsVisible() then return end
    local UI, R = AprRC.editorUI, AprRC.options
    local T = UI.Text
    self.results:ReleaseChildren()
    self.runButtons = {}
    if self.showSettings then self:DrawSettings(self.results) end
    local entries = {}
    local filter = (self.query or ""):lower()
    local source = self.category == "favorites" and AprRC.CommandBar:GetCommands() or R:GetToolbarCatalog()
    for _, entry in ipairs(source) do
        local matches = (entry.label .. " " .. entry.command):lower():find(filter, 1, true)
        if matches and (self.category == "favorites" or self.category == "all" or self.category == entry.category) then
            entries[#entries + 1] = entry
        end
    end
    local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
    self.page = math.min(math.max(1, self.page or 1), pages)
    self.previous:SetDisabled(self.page == 1)
    self.next:SetDisabled(self.page == pages)
    self.pageLabel:SetText(self.page .. " / " .. pages)
    if #entries == 0 then
        UI.LabelWidget(self.results, T(self.category == "favorites" and filter == "" and
            "No favorites yet. Add commands from the list below." or "No matching commands."))
        if self.category == "favorites" then
            UI.Button(self.results, "All commands", function()
                self.category, self.page = "all", 1; self.categoryDropdown:SetValue("all"); self:DrawResults()
            end, 200)
        end
    end
    local lastCategory
    for index = (self.page - 1) * PAGE_SIZE + 1, math.min(#entries, self.page * PAGE_SIZE) do
        local entry = entries[index]
        if self.category ~= "favorites" and entry.category ~= lastCategory then
            UI.LabelWidget(self.results, "|cffedc36a" .. T(entry.category) .. "|r", true)
            lastCategory = entry.category
        end
        local row = UI.Group(self.results)
        local run = UI.Button(row, entry.label, function() AprRC.CommandBar:Run(entry.command) end)
        run:SetFullWidth(true)
        run:SetUserData("command", entry.command)
        run:SetCallback("OnEnter", function(widget)
            GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
            GameTooltip:AddLine("/aprrc " .. entry.command, 1, 0.82, 0.4)
            GameTooltip:AddLine(T("Commands apply to the last recorded step."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        run:SetCallback("OnLeave", function() GameTooltip:Hide() end)
        self.runButtons[#self.runButtons + 1] = run
        local favorite = self:Find(entry.command)
        local pin = UI.Button(row, favorite and "Remove from bar" or "Add to bar", function() self:ToggleFavorite(entry) end, 190)
        pin:SetUserData("favorite", entry.command)
        if favorite then
            UI.Button(row, "Move up", function() self:Move(entry.command, -1) end, 110):SetDisabled(favorite == 1)
            UI.Button(row, "Move down", function() self:Move(entry.command, 1) end, 110):SetDisabled(favorite == #AprRCData.CommandBarCommands)
        end
    end
    self:RefreshRunState()
    self.results:DoLayout()
end

function Settings:DrawSettings(parent)
    local UI = AprRC.editorUI
    local T = UI.Text
    local group = UI.Group(parent, T("Bar settings"))
    local profile = AprRC.settings.profile.commandBarFrame
    local function checkbox(key, label, default)
        local box = GUI:Create("CheckBox")
        box:SetLabel(T(label)); box:SetFullWidth(true)
        box:SetValue(profile[key] == nil and default or profile[key])
        box:SetCallback("OnValueChanged", function(_, _, value)
            profile[key] = value; AprRC.CommandBar:RefreshFrameAnchor()
        end)
        group:AddChild(box)
    end
    checkbox("enabled", "Show command bar", true)
    checkbox("showLabels", "Show button labels", false)
    UI.Dropdown(group, T("Orientation"), { HORIZONTAL = T("Horizontal"), VERTICAL = T("Vertical") },
        profile.rotation or "HORIZONTAL", function(value)
            profile.rotation = value; AprRC.CommandBar:RefreshFrameAnchor()
        end)
    UI.Dropdown(group, T("Buttons per row"), { [1] = "1", [2] = "2", [3] = "3", [4] = "4", [6] = "6", [8] = "8", [10] = "10", [12] = "12" },
        profile.buttonsPerRow or 6, function(value)
            profile.buttonsPerRow = value; AprRC.CommandBar:RefreshFrameAnchor()
        end)
    UI.Button(group, "Reset command bar", function()
        AprRC.CommandBar:ResetToDefault(); AprRC.routeEditor:DrawTab()
    end, 220)
end

function Settings:Draw(parent)
    local UI = AprRC.editorUI
    local T = UI.Text
    self.category = self.category or "favorites"
    AprRC.CommandBar:GetCommands()
    self.panel = UI.Body(parent)
    local header = UI.Toolbar(self.panel)
    UI.LabelWidget(header, T("Commands apply to the last recorded step."))
    local search = GUI:Create("EditBox")
    search:SetLabel(T("Search commands"))
    search:SetFullWidth(true)
    search:DisableButton(true)
    search:SetText(self.query or "")
    search:SetCallback("OnTextChanged", function(_, _, text)
        self.query, self.page = text, 1
        -- Search the entire catalog, including commands not yet pinned.
        if text ~= "" and self.category == "favorites" then
            self.category = "all"; self.categoryDropdown:SetValue("all")
        end
        self:DrawResults(); self.results:SetScroll(0)
    end)
    header:AddChild(search)
    self.search = search
    local categories = { favorites = T("Favorites"), all = T("All commands") }
    for _, category in ipairs(AprRC.options.categoryOrder) do categories[category] = T(category) end
    self.categoryDropdown = UI.Dropdown(header, T("Commands"), categories, self.category, function(value)
        self.category, self.page = value, 1; self:DrawResults(); self.results:SetScroll(0)
    end)
    self.categoryDropdown:SetFullWidth(false)
    self.categoryDropdown:SetRelativeWidth(0.56)
    UI.Button(header, "Bar settings", function()
        self.showSettings = not self.showSettings; AprRC.routeEditor:DrawTab()
    end, 170)
    self.results = UI.Scroll(self.panel)
    local footer = UI.Toolbar(self.panel, true)
    self.previous = UI.Button(footer, "Previous", function() self.page = self.page - 1; self:DrawResults(); self.results:SetScroll(0) end, 110)
    self.next = UI.Button(footer, "Next", function() self.page = self.page + 1; self:DrawResults(); self.results:SetScroll(0) end, 110)
    self.pageLabel = UI.LabelWidget(footer, "")
    self:DrawResults()
end

-- Existing callers now navigate into the workshop instead of creating a window.
function Settings:Show(showSettings)
    self.showSettings = showSettings ~= false
    AprRC.routeEditor:Show()
    AprRC.routeEditor:SelectTab("commands")
end
