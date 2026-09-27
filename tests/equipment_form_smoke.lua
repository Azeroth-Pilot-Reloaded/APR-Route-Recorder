local UI, GUI = AprRC.editorUI, LibStub("AceGUI-3.0")
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local match = find(child, predicate)
        if match then return match end
    end
end
for _, key in ipairs({ "EquippedItem", "EquippedItemStat" }) do
    local schema = AprRC.options.step[key].schema
    local entry = key == "EquippedItem" and { slot = 16, itemID = 100 } or
        { slot = 16, stat = "QUALITY", value = 7, allowMissing = true }
    local original, saved = AprRC:CopyData(entry), AprRC:CopyData(entry)
    local parent = AprRC:CreateWidget("SimpleGroup")
    local changes = 0
    local context = { modes = {}, pages = {}, changed = function() changes = changes + 1 end }
    local function render()
        parent:ReleaseChildren()
        UI.Form:Render(parent, schema, saved, function(value) saved = value end,
            context, "step/" .. key, UI.Label(key))
    end
    context.redraw = render
    render()
    assert(changes == 0 and AprRC:DeepCompare(saved, original), "Opening legacy data must not rewrite it")
    local add = assert(find(parent, function(w) return w.type == "Button" and w.text:GetText() == UI.Text("Add entry") end))
    add:Fire("OnClick")
    assert(#saved == 2 and AprRC:DeepCompare(saved[1], original))
    local fieldKey = key == "EquippedItem" and "itemID" or "value"
    local field = assert(find(parent, function(w) return w:GetUserData("fieldPath") == "step/" .. key .. "/1/" .. fieldKey end))
    field:SetText("42"); field:Fire("OnTextChanged", "42")
    assert(saved[1][fieldKey] == 42 and saved[2].slot ~= nil)
    -- Each list entry owns its remove button; removing one keeps the other intact.
    local firstGroup = parent.children[1]
    local remove = firstGroup.children[#firstGroup.children]
    remove:Fire("OnClick")
    assert(#saved == 1 and saved[1][fieldKey] ~= 42)
    GUI:Release(parent)
end
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Equipment forms: legacy loading, list insertion, independent edits and removal passed.")
