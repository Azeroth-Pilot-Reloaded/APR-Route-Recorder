local Code = AprRC.luaCode
local text = '-- { ignored }\n{\n Note = "é |cffff0000red|r \\" }",\n Coord = {\n x = -1.5e2,\n y = 0x2a,\n },\n --[=[ } { ]=]\n Enabled = true,\n}'
local tokens, folds = Code:Scan(text)
assert(#folds == 2 and folds[1].start == text:find("{\n", 1, true) - 1)
local kinds = {}
for _, token in ipairs(tokens) do kinds[token.kind or "space"] = true end
assert(kinds.comment and kinds.string and kinds.number and kinds.keyword and kinds.identifier)
local colored, spans = Code:Encode(text)
assert(colored:find("|cffce9178", 1, true) and colored:find("||cffff0000", 1, true))
assert(Code:Decode(colored) == text, "Literal WoW markup and UTF-8 must survive decoration")
for position = 0, #text do
    local native = Code:EncodePosition(text, spans, position)
    local _, cursor = Code:Decode(colored, native)
    assert(cursor == position, "Wrong cursor at byte " .. position)
end
local collapsed = { [folds[2].start] = true }
local display, ranges = Code:Project(text, folds, collapsed)
assert(not display:find("x =", 1, true) and display:find("{ ... }", 1, true))
assert(text:find("x =", 1, true), "Projection must retain the source")
local enabled = text:find("Enabled", 1, true) - 1
assert(Code:ToRaw(ranges, Code:ToDisplay(ranges, enabled)) == enabled)
local changes = Code:ChangedLines("a\nb\nc", "a\nnew\nb\nc")
assert(not next(changes), "Insertions on the other side must not mark unchanged lines")
changes = Code:ChangedLines("a\nold\nc", "a\nnew\nc")
assert(changes[2] and not changes[1] and not changes[3])
assert(#select(2, Code:Scan('{\n --[[ unfinished {\n}')) == 0, "Incomplete long comments must not create folds")
local sections = '-- #region Intro\n{\n steps = {\n },\n}\n-- #endregion\n--[=[\ncomment\n]=]'
local _, sectionFolds = Code:Scan(sections)
local markers, comments = 0, 0
for _, region in ipairs(sectionFolds) do
    if region.kind == "region" then markers = markers + 1
    elseif region.kind == "comment" then comments = comments + 1 end
end
assert(markers == 1 and comments == 1)
local projected = Code:Project(sections, sectionFolds, { [sectionFolds[1].start] = true })
assert(projected:find("-- #region Intro ... -- #endregion", 1, true), projected)

local function checkComparison(left, right)
    local comparison = Code:Compare(left, right)
    local a, b, ai, bi = {}, {}, 0, 0
    for _, row in ipairs(comparison.rows) do
        if row.left then ai = ai + 1; assert(row.left == ai); a[#a + 1] = comparison.left[row.left].text end
        if row.right then bi = bi + 1; assert(row.right == bi); b[#b + 1] = comparison.right[row.right].text end
        if not row.changed then assert(a[#a] == b[#b], "Unchanged rows must align") end
    end
    assert(table.concat(a, "\n") == left and table.concat(b, "\n") == right, "Diff must retain every source line in order")
    assert(comparison.inserted - comparison.removed == bi - ai)
    return comparison
end
assert(#checkComparison("", "").hunks == 0)
assert(checkComparison("", "a\nb").inserted == 2)
assert(checkComparison("a\nb", "").removed == 2)
local comparison = checkComparison("a\nb\nc\nd", "a\ninsert\nb\nchanged\nd")
assert(#comparison.hunks == 2 and comparison.rows[2].left == nil and comparison.rows[3].left == 2)
local utf8 = checkComparison('Note = "é"', 'Note = "è"').rows[1]
assert(utf8.leftSpan.finish - utf8.leftSpan.start == 2, "Inline highlighting must include complete UTF-8 characters")
local a, b = {}, {}
for i = 1, 10000 do a[i], b[i] = "Line " .. i, "Line " .. i end
b[100], b[9800] = "Changed 100", "Changed 9800"
assert(#checkComparison(table.concat(a, "\n"), table.concat(b, "\n")).hunks == 2, "Sparse edits in large files must remain separate")
for sample = 1, 80 do
    local x, y = {}, {}
    for i = 1, 18 do
        x[#x + 1] = i % 3 == 0 and "}" or "Line " .. i
        if (i + sample) % 5 ~= 0 then y[#y + 1] = x[#x] end
        if (i + sample) % 7 == 0 then y[#y + 1] = "Added " .. sample .. " / " .. i end
    end
    checkComparison(table.concat(x, "\n"), table.concat(y, "\n"))
end
print("Lua syntax: strings, comments, brackets, UTF-8, literal markup, byte offsets, folding and bounded diff passed.")
