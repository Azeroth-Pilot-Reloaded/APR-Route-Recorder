local UI, R = AprRC.editorUI, AprRC.options
local GUI = LibStub("AceGUI-3.0")
local previousAPRData, previousTargetID = APRData, APR.GetTargetID
local previousAfter = C_Timer.After
APRData = { NPCList = { [3127] = "Venomtail Scorpid", [2163] = "Other beast" } }
APR.GetTargetID = function(_, unit) return unit == "target" and 3127 or nil end
local callbacks = {}
C_Timer.After = function(_, callback) callbacks[#callbacks + 1] = callback end
local function flush()
    local pending = callbacks; callbacks = {}
    for _, callback in ipairs(pending) do callback() end
end
local function find(widget, predicate)
    if predicate(widget) then return widget end
    for _, child in ipairs(widget.children or {}) do
        local result = find(child, predicate)
        if result then return result end
    end
end
local value = UI.Form:Default(R.schemas.tameBeast)
assert(value.npcID == 3127 and value.spellID == 1515 and value.Text == "Venomtail Scorpid")
assert(UI.Form:Default(R.schemas.repair).minDurability == 90)
local parent = AprRC:CreateWidget("SimpleGroup")
local current, changes = true, 0
local context = { modes = {}, pages = {}, isCurrent = function() return current end,
    changed = function() changes = changes + 1 end }
local function render()
    parent:ReleaseChildren()
    UI.Form:Render(parent, R.schemas.tameBeast, value, function(entry) value = entry end,
        context, "step/TameBeast", UI.Label("TameBeast"))
end
context.redraw = render
render()
local function field(key)
    return assert(find(parent, function(widget) return widget:GetUserData("fieldPath") == "step/TameBeast/" .. key end), key)
end
assert(field("Text"):GetText() == "Venomtail Scorpid")
field("npcID"):Fire("OnTextChanged", "2163")
assert(value.npcID == 2163 and value.Text == "Other beast")
flush()
assert(field("Text"):GetText() == "Other beast", "Name autofill must also refresh the visible field")
field("Text"):Fire("OnTextChanged", "Custom beast")
field("npcID"):Fire("OnTextChanged", "3127")
assert(value.Text == "Custom beast", "An explicit fallback must survive NPC edits")
flush()
value = { npcID = 999 }
render()
assert(changes == 3 and value.Text == nil, "Opening a form must not rewrite existing routes")
field("npcID"):Fire("OnTextChanged", "3127")
assert(value.Text == "Venomtail Scorpid")
flush()
assert(field("Text"):GetText() == "Venomtail Scorpid")
current = false
GUI:Release(parent)

-- The recording dialog starts with the actual target instead of the example NPC.
local frame
local createWidget = AprRC.CreateWidget
AprRC.CreateWidget = function(self, widgetType)
    local widget = createWidget(self, widgetType)
    if widgetType == "Frame" then frame = widget end
    return widget
end
for _, key in ipairs({ "TameBeast", "Repair" }) do
    R:ShowInput(R.step[key], nil, AprRCData.CurrentRoute, function() return true end)
    local input = assert(find(frame, function(widget) return widget.type == "MultiLineEditBox" end))
    local parsed = assert(R:Parse(R.step[key], input:GetText()))
    assert(parsed.npcID == 3127)
    if key == "TameBeast" then assert(parsed.Text == "Venomtail Scorpid" and parsed.spellID == 1515)
    else assert(parsed.minDurability == 90) end
    GUI:Release(frame)
end
AprRC.CreateWidget = createWidget
APRData, APR.GetTargetID, C_Timer.After = previousAPRData, previousTargetID, previousAfter
assert(#UIErrors == 0, table.concat(UIErrors, "\n"))
print("Repair and TameBeast forms: target defaults, visible name autofill and recording dialogs passed.")
