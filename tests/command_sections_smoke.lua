local Bar, Settings, Editor = AprRC.CommandBar, AprRC.CommandBarSetting, AprRC.routeEditor
local profile = AprRC.settings.profile.commandBarFrame
local favorites = AprRC:CopyData(Bar:GetCommands())
local original = AprRC:CopyData(profile)
local function commands(parent)
    local rows = {}
    for _, child in ipairs(parent.children) do if child.entry then rows[#rows + 1] = child end end
    return rows
end
local function section(name)
    for _, child in ipairs(Settings.available.children) do
        if child:GetUserData("commandSection") == name then return child end
    end
end

AprRC.settings.profile.recordBarFrame.isRecording = true
AprRCData.CommandBarCommands = {}
Settings.query, Settings.section, Settings.catalogPage, Settings.selectedPage = "", "ALL", 1, 1
profile.catalogCollapsed = {}
Settings:Show(false)
assert(#commands(Settings.available) <= 24 and #commands(Settings.available) > 0)
local first = commands(Settings.available)[1].entry
local header = assert(section("Actions"))
header.children[1]:Fire("OnClick")
assert(profile.catalogCollapsed.Actions)
for _, row in ipairs(commands(Settings.available)) do assert(row.entry.category ~= "Actions") end
Settings:Show(false)
assert(profile.catalogCollapsed.Actions and section("Actions"), "Collapsed sections must survive reopening")

-- Search always exposes a matching command, including in a collapsed section.
Settings.search:Fire("OnTextChanged", first.command)
local found
for _, row in ipairs(commands(Settings.available)) do
    if row.entry.command == first.command then found = row end
end
assert(found and profile.catalogCollapsed.Actions)
Settings.sectionSelector:Fire("OnValueChanged", "Conditions")
assert(#commands(Settings.available) == 0)
Settings.search:Fire("OnTextChanged", "")
for _, row in ipairs(commands(Settings.available)) do assert(row.entry.category == "Conditions") end
assert(#commands(Settings.available) <= 24)

-- A page renders a bounded number of rows and moves without changing favorites.
Settings.sectionSelector:Fire("OnValueChanged", "ALL")
profile.catalogCollapsed = {}
Settings:DrawResults()
Settings.catalogPaging.next:Fire("OnClick")
assert(Settings.catalogPage == 2 and #commands(Settings.available) <= 24)
assert(#Bar:GetCommands() == 0)

-- Catalog arrows also accept a held drag. Moving to a different arrow resets
-- the dwell timer; stale native mouse-up must not end a still-held drag.
local source = commands(Settings.available)[1]
local catalogEntry = source.entry
TestMouseDown, TestMouseOver = true, Settings.catalogPaging.previous.frame
Settings:StartDrag(source)
Settings:UpdateDrag(0.3)
source:Fire("OnDragStop")
assert(Settings.dragging, "A stale mouse-up cannot finish a held drag")
TestMouseOver = Settings.catalogPaging.next.frame
Settings:UpdateDrag(0.31)
assert(Settings.catalogPage == 2, "Dwell time belongs to one arrow")
Settings:UpdateDrag(0.3)
assert(Settings.catalogPage == 3 and Settings.dragging and not Settings.dragging.row)
TestMouseDown, TestMouseOver, TestCursorY = false, Settings.selected.frame, 10000
source:Fire("OnDragStop")
assert(Settings.dragging, "A released source row cannot finish a cross-page drag")
Settings:UpdateDrag(0.01)
assert(not Settings.dragging and Bar:GetCommands()[1].command == catalogEntry.command)
TestMouseOver = nil

AprRCData.CommandBarCommands = AprRC.options:GetToolbarCatalog()
Settings:DrawResults()
assert(#Settings.selected.children == 24 and #Settings.runButtons <= 48)
Settings.selectedPaging.next:Fire("OnClick")
assert(Settings.selectedPage == 2 and Settings.selectedStart == 25)
assert(Settings.selected.children[1].entry.command == Bar:GetCommands()[25].command)
TestMouseOver, TestCursorY = Settings.selected.frame, 10000
local target, slot = Settings:DropTarget()
assert(target == "selected" and slot == 25, "Drop positions must use absolute favorite indices")
local last = Bar:GetCommands()[#Bar:GetCommands()]
Settings:ApplyDrop(last, "selected", slot)
assert(Bar:GetCommands()[25].command == last.command)
TestMouseOver = nil
Settings.selectedPaging.previous:Fire("OnClick")
local dragged = Settings.selected.children[1].entry
TestMouseDown, TestMouseOver = true, Settings.selectedPaging.next.frame
Settings:StartDrag(Settings.selected.children[1])
Settings:UpdateDrag(0.3)
assert(Settings.selectedPage == 1)
Settings:UpdateDrag(0.31)
assert(Settings.selectedPage == 2 and Settings.dragging and not Settings.dragging.row)
TestMouseOver, TestCursorY = Settings.selected.frame, 10000
TestMouseDown = false
Settings:UpdateDrag(0.01)
assert(not Settings.dragging and Bar:GetCommands()[24].command == dragged.command,
    "Dragging across a page boundary must preserve insertion order and release the ghost")
TestMouseOver = nil

-- Escape cancels without changing order, and reopening a tab cannot resurrect
-- a drag whose source widgets have already returned to the pool.
local snapshot = AprRC:CopyData(Bar:GetCommands())
TestMouseDown = true
Settings:StartDrag(Settings.selected.children[1])
local isKeyDown = IsKeyDown
IsKeyDown = function(key) return key == "ESCAPE" end
Settings:UpdateDrag(0.1)
IsKeyDown = isKeyDown
assert(not Settings.dragging and not Settings.ghost:IsShown() and not Settings.dropLine:IsShown())
assert(AprRC:DeepCompare(snapshot, Bar:GetCommands()))
Settings:StartDrag(Settings.selected.children[1])
Editor:SelectTab("tools"); Editor:SelectTab("commands")
TestMouseDown = false
Settings:FinishDrag()
assert(not Settings.dragging and AprRC:DeepCompare(snapshot, Bar:GetCommands()))

-- Respect both user dimensions, even when all command categories are pinned.
profile.rotation, profile.buttonsPerRow, profile.maxLines = "HORIZONTAL", 3, 2
Bar:UpdateFrame()
assert(Bar.frame:GetWidth() <= 104 and Bar.frame:GetHeight() <= 68)
assert(Bar.capacity == 3 and Bar.pages > 1)
Bar.nextButton:GetScript("OnClick")(Bar.nextButton)
assert(Bar.page == 2 and Bar.btnList[1].command == Bar:GetCommands()[4].command)
profile.rotation = "VERTICAL"
Bar:UpdateFrame()
assert(Bar.frame:GetHeight() <= 104 and Bar.frame:GetWidth() <= 68)
profile.rotation, profile.buttonsPerRow, profile.maxLines = "HORIZONTAL", 1, 1
Bar:UpdateFrame()
assert(Bar.capacity == 0 and Bar.settingsButton:IsShown())
assert(not Bar.btnList[1]:IsShown() and not Bar.nextButton:IsShown())
assert(Bar.frame:GetWidth() == 32 and Bar.frame:GetHeight() == 32)
profile.buttonsPerRow, profile.maxLines = 0, 0
Bar:UpdateFrame()
assert(Bar.frame:GetWidth() <= UIParent:GetWidth() and Bar.frame:GetHeight() <= UIParent:GetHeight())

-- Released tab widgets are never a delayed drag destination.
TestCloseWorkshop()
local before = AprRC:CopyData(Bar:GetCommands())
Settings:ApplyDrop(first, "available")
assert(AprRC:DeepCompare(before, Bar:GetCommands()))
AprRCData.CommandBarCommands = favorites
for key in pairs(profile) do profile[key] = nil end
for key, value in pairs(original) do profile[key] = value end
Settings.query, Settings.section, Settings.catalogPage, Settings.selectedPage = "", "ALL", 1, 1
AprRC.settings.profile.recordBarFrame.isRecording = false
Bar:RefreshFrameAnchor()
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Command sections, search reveal, bounded rows, absolute drag slots and adaptive two-dimensional toolbar passed.")
