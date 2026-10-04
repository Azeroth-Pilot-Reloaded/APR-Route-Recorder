local E, Model, Code = AprRC.routeEditor, AprRC.editorModel, AprRC.luaCode
TestCloseWorkshop()
local route = assert(Model:NewRoute("Lua native text alignment"))
for i = 1, 140 do
    route.steps[i] = { Note = "Étape " .. i .. " — é |cffff0000literal|r", Coord = { x = -i, y = i } }
end
route.steps[95].PickUp = { 804 }
E:Show(); E:SelectRoute(route.name); E:SelectTab("lua")
E.follow = false; TestRunTimers()
local widget, raw = E.luaBox, E.luaBox:GetText()
local originalFont, originalSize, originalFlags = widget.editBox:GetFont()
local originalHeight = widget.scrollFrame:GetHeight()
local customFont = "Interface\\AddOns\\TestFont\\Fractional.ttf"
TestFontMetrics[customFont] = 19.375
widget.scrollFrame:SetHeight(300)
E:OpenLuaFind()
widget.editBox:SetFont(customFont, 17, "OUTLINE")
E.luaFindInput:SetText("804"); E.luaFindInput:Fire("OnTextChanged", "804")
TestRunTimers()
local range = assert(E.luaFindResults[1])
local nativeBox = widget.editBox
assert(widget.lineHeight == 19.375 and nativeBox:GetSpacing() == 0,
    "Layout must use rendered font metrics without spacing that breaks native selection: " ..
    tostring(widget.lineHeight) .. ", spacing " .. tostring(nativeBox:GetSpacing()) .. ", font " .. tostring(nativeBox:GetFont()))
assert(Code:Decode(nativeBox.text:sub(nativeBox.selection[1] + 1, nativeBox.selection[2])) == "804")
assert(nativeBox:GetCursorPosition() == range.finish)
local center = -nativeBox.cursorY + nativeBox.cursorHeight / 2 - widget.scrollFrame:GetVerticalScroll()
assert(math.abs(center - 150) < 0.5, "The native selected text must appear in the middle after hundreds of lines")
local selectedLine = Code:LineAt(widget.rawLines, range.start)
local gutterRow
for _, row in ipairs(widget.rows) do
    if row.frame:IsShown() and row.number:GetText() == tostring(selectedLine) then gutterRow = row; break end
end
assert(gutterRow, "The selected line must have its original number in the visible gutter")
local _, _, _, _, rowY = gutterRow.frame:GetPoint(1)
assert(math.abs(rowY - nativeBox.cursorY - widget.scrollFrame:GetVerticalScroll()) < 0.5,
    "Gutter controls must align with native text geometry")
assert(widget:GetText() == raw and not E.session:IsDirty())
-- Replacing the visibly selected match must change that value alone.
nativeBox:Insert("805")
local expected = raw:gsub("804", "805", 1)
assert(widget:GetText() == expected and E.session.raw == expected)
assert(route.steps[95].PickUp[1] == 804)
E:CloseLuaFind()

E:OpenVersionDiff()
for _, box in ipairs({ E.versionDiffLeftBox, E.versionDiffRightBox }) do
    box.editBox:SetFont(customFont, 17, "OUTLINE")
end
E.versionDiffNext:Fire("OnClick"); TestRunTimers()
local comparison = E.versionDiffComparison
assert(#comparison.hunks == 1)
local first = comparison.hunks[1].first
for _, box in ipairs({ E.versionDiffLeftBox, E.versionDiffRightBox }) do
    assert(box.lineHeight == 19.375 and box.editBox:GetSpacing() == 0)
    local found
    for _, row in ipairs(box.rows) do
        if row.background:IsShown() then
            local _, _, _, _, y = row.background:GetPoint(1)
            if math.abs(y - box.editBox.cursorY) < 0.5 then found = true end
        end
    end
    assert(found, "Changed-line backgrounds must align with native text after a font change")
    assert(box.lines[first])
end
assert(E.versionDiffLeftBox.sourceText == raw and E.versionDiffRightBox.sourceText == expected)
E.versionDiffDialog:Hide()
nativeBox:SetFont(originalFont, originalSize, originalFlags)
widget.scrollFrame:SetHeight(originalHeight)
TestCloseWorkshop()
TestFontMetrics[customFont] = nil
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Lua layout: native selection, centered search, replacement, gutters and diff backgrounds with fractional font metrics passed.")
