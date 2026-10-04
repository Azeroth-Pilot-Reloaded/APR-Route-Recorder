local Language, Code = AprRC.luaLanguage, AprRC.luaCode
local source = 'Alpha alpha alphabet _alpha alpha2 «Alpha» Étage étage'
assert(#Language:Search(source, "alpha", false, false) == 6)
assert(#Language:Search(source, "alpha", false, true) == 3)
assert(#Language:Search(source, "Alpha", true, true) == 2)
local accents = Language:Search(source, "ÉTAGE", false, true)
assert(#accents == 2 and source:sub(accents[2].start + 1, accents[2].finish) == "étage")
local ranges = Language:Search('"a.a aXa a.a"', "a.a", true, false)
local replaced, cursor = Language:Replace('"a.a aXa a.a"', ranges, "%1|é", 12)
assert(replaced == '"%1|é aXa %1|é"' and cursor == 12 + 2 * (#"%1|é" - 3))

local raw = [[{
steps={
{
Note="é |cffff0000literal|r",
Coord={x=-1,y=2}, -- exact trailing comment
},
},
}]]
local formatted = assert(Language:Format(raw, raw:find("Coord", 1, true)))
assert(formatted:find('        Coord = { x = -1, y = 2 }, -- exact trailing comment', 1, true))
assert(AprRC:DeepCompare(assert(AprRC:ParseLuaData(raw)), assert(AprRC:ParseLuaData(formatted))))
assert(Language:Format(formatted, 0) == formatted, "Formatting must be idempotent")
local long = '{\nNote = [=[\n  exact  text { }\n]=],\n--[=[\n exact comment { }\n]=]\n}'
local styled = assert(Language:Format(long, 0))
assert(styled:find('[=[\n  exact  text { }\n]=]', 1, true) and styled:find('--[=[\n exact comment { }\n]=]', 1, true))
assert(styled:find('    Note = [=[', 1, true) and Language:Format(styled, 0) == styled)
assert(AprRC:DeepCompare(AprRC:ParseLuaData(long), AprRC:ParseLuaData(styled)))
assert(select(4, AprRC:ParseLuaData(long, true, true)))
local adjacent = '{ Note = [=[\n  exact\n]=], Other = [=[\n  also exact\n]=] }'
assert(AprRC:DeepCompare(AprRC:ParseLuaData(adjacent), AprRC:ParseLuaData(Language:Format(adjacent, 0))))
local broken = '{\nsteps = {{ Note = }}\n}'
local text, _, location = Language:Format(broken, 0)
assert(not text and location.line == 2)

local errors, outline, parsed, map = Language:Analyze([[{
    steps = { { Note = "A" }, { Zone = "wrong", NoArrow = 123, Unknown = true } },
    parallelSteps = { { conditions = {}, steps = { { Note = "P" } } } }
}]], {})
assert(#errors >= 3 and #outline == 3 and outline[3].group == 1)
for _, issue in ipairs(errors) do
    assert(issue.location.line == 2 and issue.location.column > 25, "Every field error needs its own exact source range")
end
assert(parsed.steps[1].Note == "A" and map[parsed.steps[1]].fields.Note)
local legacy = { steps = { { NewAPRField = 12 } } }
assert(#Language:Analyze(AprRC:SerializeData(legacy), legacy) == 0)
assert(#Language:Analyze('{ steps = false }', {}) == 1)
local _, metadata, comments, positions = AprRC:ParseLuaData('-- before\n{ Note = "A" }', true, true)
assert(not metadata and comments.leading and positions and not comments.value)

local function context(text) return Language:Context(text, #text) end
assert(context('{ steps = {{ No').field)
assert(context('{ steps = {{ PickUp = { Gardi').kind == "quest")
assert(context('{ steps = {{ LearnSkill = { spellID = Bou').kind == "spell")
assert(context('{ steps = {{ Use = { itemID = Pie').kind == "item")
assert(context('{ steps = {{ Qpart = { [123').kind == "quest")
assert(not context('-- Note') and not context('{ Note = "text'))
local candidates = Language:Candidates(context('{ steps = {{ No'), {})
local note
for _, item in ipairs(candidates) do if item.insert == "Note" then note = true end end
assert(note)
print("Lua language: case/word search, literal replacement, safe formatting, exact semantic errors, outline and APR completion contexts passed.")
