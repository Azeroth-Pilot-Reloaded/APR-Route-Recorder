-- Presentation only: these helpers never execute Lua or change route data.
local Code = {}
AprRC.luaCode = Code
Code.colors = { identifier = "9cdcfe", keyword = "569cd6", string = "ce9178", number = "b5cea8",
    comment = "6a9955", punctuation = "d4d4d4" }
local keywords = {}
for word in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%S+") do
    keywords[word] = true
end
local brackets = { "ffd700", "da70d6", "179fff" }

function Code:Scan(text)
    local tokens, folds, stack, regions, pos, line, depth = {}, {}, {}, {}, 1, 1, 0
    while pos <= #text do
        local first, firstLine, kind, color, longFold = pos, line, "punctuation"
        local c = text:sub(pos, pos)
        local comment = text:sub(pos, pos + 1) == "--"
        local longStart = comment and pos + 2 or pos
        local equals = text:match("^%[(=*)%[", longStart)
        if (comment or c == "[") and equals then
            local _, finish = text:find("]" .. equals .. "]", longStart + #equals + 2, true)
            pos, kind = (finish or #text) + 1, comment and "comment" or "string"
            if finish then
                longFold = { start = first - 1, line = line, depth = depth + #regions + 1, kind = kind,
                    finish = finish, contentStart = longStart + #equals + 1, contentFinish = finish - #equals - 2 }
            end
        elseif comment then
            pos, kind = text:find("[\r\n]", pos) or (#text + 1), "comment"
        elseif c == '"' or c == "'" then
            pos, kind = pos + 1, "string"
            while pos <= #text do
                local char = text:sub(pos, pos)
                pos = pos + 1
                if char == "\\" then pos = math.min(#text + 1, pos + 1)
                elseif char == c then break end
            end
        elseif c:match("[%a_]") then
            local word = text:match("^[%w_]+", pos)
            pos, kind = pos + #word, keywords[word] and "keyword" or "identifier"
        elseif c:match("%d") or (c == "." and text:sub(pos + 1, pos + 1):match("%d")) then
            local number = text:match("^0[xX]%x+", pos) or text:match("^%d*%.?%d+[eE][+-]?%d+", pos)
                or text:match("^%d*%.?%d+", pos)
            pos, kind = pos + #number, "number"
        elseif c:match("%s") then
            pos, kind = pos + #(text:match("^%s+", pos)), nil
        else
            pos = pos + 1
            if c == "{" then
                depth = depth + 1; color = brackets[(depth - 1) % #brackets + 1]
                stack[#stack + 1] = { start = first - 1, line = line, depth = depth + #regions }
            elseif c == "}" then
                color = brackets[math.max(0, depth - 1) % #brackets + 1]
                local fold = table.remove(stack)
                if fold and fold.line < line then
                    fold.finish, fold.lastLine = pos - 1, line; folds[#folds + 1] = fold
                end
                depth = math.max(0, depth - 1)
            elseif c == "[" or c == "]" or c == "(" or c == ")" then
                color = brackets[depth % #brackets + 1]
            end
        end
        local value = text:sub(first, pos - 1)
        local _, newlines = value:gsub("\n", "")
        line = line + newlines
        if longFold and newlines > 0 then longFold.lastLine = line; folds[#folds + 1] = longFold end
        if kind == "comment" and not equals then
            local marker = value:match("^%-%-%s*#?(%a+)")
            marker = marker and marker:lower()
            if marker == "region" then
                regions[#regions + 1] = { start = first - 1, line = firstLine, kind = "region",
                    depth = depth + #regions + 1, contentStart = pos - 1 }
            elseif marker == "endregion" and #regions > 0 then
                local region = table.remove(regions)
                if region.line < firstLine then
                    region.finish, region.lastLine, region.contentFinish = pos - 1, firstLine, first - 1
                    folds[#folds + 1] = region
                end
            end
        end
        tokens[#tokens + 1] = { start = first - 1, finish = pos - 1, line = firstLine,
            kind = kind, color = color or (kind and self.colors[kind]) }
    end
    table.sort(folds, function(a, b) return a.start < b.start end)
    return tokens, folds
end

function Code:Encode(text, tokens)
    local parts, spans, length = {}, {}, 0
    for _, token in ipairs(tokens or self:Scan(text)) do
        local value = text:sub(token.start + 1, token.finish):gsub("|", "||")
        local prefix = token.color and ("|cff" .. token.color) or ""
        parts[#parts + 1] = prefix .. value .. (token.color and "|r" or "")
        spans[#spans + 1] = { start = token.start, finish = token.finish, offset = length + #prefix,
            nativeFinish = length + #prefix + #value }
        length = length + #prefix + #value + (token.color and 2 or 0)
    end
    return table.concat(parts), spans
end

function Code:EncodePosition(text, spans, position)
    position = math.max(0, math.min(#text, position or 0))
    local low, high = 1, #spans
    while low <= high do
        local middle = math.floor((low + high) / 2)
        local span = spans[middle]
        if position < span.start then high = middle - 1
        elseif position > span.finish then low = middle + 1
        else
            local prefix = text:sub(span.start + 1, position)
            local _, pipes = prefix:gsub("|", "")
            return span.offset + #prefix + pipes
        end
    end
    return 0
end

function Code:Decode(text, position)
    local parts, pos, cursor, length = {}, 1, 0, 0
    position = position or #text
    while pos <= #text do
        local first, value = pos
        if text:sub(pos, pos + 1) == "||" then value, pos = "|", pos + 2
        elseif text:sub(pos, pos + 1) == "|r" then pos = pos + 2
        elseif text:sub(pos, pos + 9):match("^|c%x%x%x%x%x%x%x%x$") then pos = pos + 10
        else
            local nextPipe = text:find("|", pos + 1, true) or (#text + 1)
            value, pos = text:sub(pos, nextPipe - 1), nextPipe
        end
        if value then
            parts[#parts + 1] = value
            if position >= pos - 1 then cursor = length + #value
            elseif position >= first - 1 then cursor = length + math.min(#value, position - first + 1) end
            length = length + #value
        elseif position >= pos - 1 then cursor = length end
    end
    return table.concat(parts), cursor
end

-- Inverse byte mapping for a pending native edit, including escaped pipes.
function Code:NativePosition(buffer, displayPosition)
    local pos, visible = 1, 0
    while pos <= #buffer do
        local c = buffer:sub(pos, pos + 1)
        if c == "|r" then pos = pos + 2
        elseif buffer:sub(pos, pos + 9):match("^|c%x%x%x%x%x%x%x%x$") then pos = pos + 10
        else
            if visible >= displayPosition then return pos - 1 end
            if c == "||" then pos, visible = pos + 2, visible + 1
            else pos, visible = pos + 1, visible + 1 end
        end
    end
    return #buffer
end

-- Compare large native buffers in C-sized chunks, then locate the changed
-- bytes. Byte-by-byte prefix/suffix scans are too costly on long routes.
function Code:NativeEdit(before, after)
    local first, tail, limit = 0, 0, math.min(#before, #after)
    while first + 4096 <= limit and before:sub(first + 1, first + 4096) == after:sub(first + 1, first + 4096) do
        first = first + 4096
    end
    local low, high = 0, math.min(4096, limit - first)
    while low < high do
        local middle = math.ceil((low + high) / 2)
        if before:sub(first + 1, first + middle) == after:sub(first + 1, first + middle) then low = middle
        else high = middle - 1 end
    end
    first = first + low
    limit = limit - first
    while tail + 4096 <= limit and before:sub(#before - tail - 4095, #before - tail) == after:sub(#after - tail - 4095, #after - tail) do
        tail = tail + 4096
    end
    low, high = 0, math.min(4096, limit - tail)
    while low < high do
        local middle = math.ceil((low + high) / 2)
        if before:sub(#before - tail - middle + 1, #before - tail) == after:sub(#after - tail - middle + 1, #after - tail) then low = middle
        else high = middle - 1 end
    end
    tail = tail + low
    local function enclosing(text, position)
        for start = math.max(1, position - 9), position do
            if text:byte(start) == 124 then
                local previous = start - 1
                while previous > 0 and text:byte(previous) == 124 do previous = previous - 1 end
                if (start - previous) % 2 == 1 then
                    local value, finish = text:sub(start, start + 9)
                    if value:sub(1, 2) == "||" or value:sub(1, 2) == "|r" then finish = start + 1
                    elseif value:match("^|c%x%x%x%x%x%x%x%x$") then finish = start + 9 end
                    if finish and position < finish then return start - 1, finish end
                end
            end
        end
        return position, position
    end
    local oldFirst, newFirst = enclosing(before, first), enclosing(after, first)
    first = math.min(oldFirst, newFirst)
    local oldFinish, newFinish = #before - tail, #after - tail
    local _, oldEnd = enclosing(before, oldFinish)
    local _, newEnd = enclosing(after, newFinish)
    local extend = math.min(tail, math.max(oldEnd - oldFinish, newEnd - newFinish))
    return first, oldFinish + extend, newFinish + extend
end

function Code:Lines(text)
    local lines, pos = {}, 1
    repeat
        local finish = text:find("\n", pos, true)
        lines[#lines + 1] = { start = pos - 1, text = text:sub(pos, finish and finish - 1 or #text) }
        pos = finish and finish + 1
    until not pos
    return lines
end

function Code:LineAt(lines, position)
    local low, high = 1, #lines
    while low < high do
        local middle = math.ceil((low + high) / 2)
        if lines[middle].start <= position then low = middle else high = middle - 1 end
    end
    return low
end

-- A bounded LCS gives stable changed-line backgrounds, including insertions.
function Code:ChangedLines(text, other)
    local left, right, changed = self:Lines(text), self:Lines(other), {}
    local first, lastLeft, lastRight = 1, #left, #right
    while first <= lastLeft and first <= lastRight and left[first].text == right[first].text do first = first + 1 end
    while lastLeft >= first and lastRight >= first and left[lastLeft].text == right[lastRight].text do
        lastLeft, lastRight = lastLeft - 1, lastRight - 1
    end
    if (lastLeft - first + 1) * (lastRight - first + 1) > 120000 then
        for i = first, lastLeft do changed[i] = true end
        return changed
    end
    local scores = {}; scores[lastLeft + 1] = {}
    for i = lastLeft, first, -1 do
        scores[i] = {}
        for j = lastRight, first, -1 do
            scores[i][j] = left[i].text == right[j].text and (1 + (scores[i + 1][j + 1] or 0))
                or math.max(scores[i + 1][j] or 0, scores[i][j + 1] or 0)
        end
    end
    local i, j = first, first
    while i <= lastLeft do
        if j <= lastRight and left[i].text == right[j].text then i, j = i + 1, j + 1
        elseif j <= lastRight and (scores[i][j + 1] or 0) > (scores[i + 1][j] or 0) then j = j + 1
        else changed[i], i = true, i + 1 end
    end
    return changed
end

-- Hide a fold's interior while keeping full source byte positions canonical.
function Code:Project(text, folds, collapsed)
    if not next(collapsed) then return text, { { start = 0, finish = #text, display = 0 } } end
    local parts, ranges, last, length = {}, {}, 0, 0
    for _, fold in ipairs(folds) do
        if collapsed[fold.start] and fold.start >= last then
            local bodyStart, bodyFinish = fold.contentStart or fold.start + 1, fold.contentFinish or fold.finish - 1
            local value = text:sub(last + 1, bodyStart)
            parts[#parts + 1] = value
            ranges[#ranges + 1] = { start = last, finish = bodyStart, display = length }
            length = length + #value
            local placeholder = " ... "
            parts[#parts + 1] = placeholder
            ranges[#ranges + 1] = { start = bodyStart, finish = bodyFinish, display = length,
                hidden = true, length = #placeholder, foldStart = fold.start }
            length, last = length + #placeholder, bodyFinish
        end
    end
    parts[#parts + 1] = text:sub(last + 1)
    ranges[#ranges + 1] = { start = last, finish = #text, display = length }
    return table.concat(parts), ranges
end

function Code:ToDisplay(ranges, position)
    local low, high = 1, #ranges
    while low < high do
        local middle = math.floor((low + high) / 2)
        if ranges[middle].finish < position then low = middle + 1 else high = middle end
    end
    local range = ranges[low]
    if range and position >= range.start and position <= range.finish then
        return range.display + (range.hidden and 0 or position - range.start)
    end
    return 0
end

function Code:ToRaw(ranges, position)
    local low, high = 1, #ranges
    while low < high do
        local middle = math.floor((low + high) / 2)
        local range = ranges[middle]
        local finish = range.display + (range.hidden and range.length or range.finish - range.start)
        if finish < position then low = middle + 1 else high = middle end
    end
    local range = ranges[low]
    local length = range and (range.hidden and range.length or range.finish - range.start)
    if range and position >= range.display and position <= range.display + length then
        return range.hidden and (position == range.display and range.start or range.finish)
            or range.start + position - range.display
    end
    return 0
end

local function lineOperations(left, right, first, n, m)
    local v, trace, work = { [1] = 0 }, {}, 0
    for distance = 0, math.min(n + m, 384) do
        local previous = {}
        for key, value in pairs(v) do previous[key] = value end
        trace[distance] = previous
        for diagonal = -distance, distance, 2 do
            work = work + 1
            if work > 60000 then return nil end
            local x
            if diagonal == -distance or (diagonal ~= distance and (v[diagonal - 1] or -1) < (v[diagonal + 1] or -1)) then
                x = v[diagonal + 1] or 0
            else x = (v[diagonal - 1] or 0) + 1 end
            local y = x - diagonal
            while x < n and y < m and left[first + x].text == right[first + y].text do x, y = x + 1, y + 1 end
            v[diagonal] = x
            if x >= n and y >= m then
                local reversed, operations = {}, {}
                for d = distance, 0, -1 do
                    local old, k = trace[d], x - y
                    local oldK = (k == -d or (k ~= d and (old[k - 1] or -1) < (old[k + 1] or -1))) and k + 1 or k - 1
                    local oldX = old[oldK] or 0
                    local oldY = oldX - oldK
                    while x > oldX and y > oldY do
                        reversed[#reversed + 1] = { left = first + x - 1, right = first + y - 1 }
                        x, y = x - 1, y - 1
                    end
                    if d > 0 then
                        if x == oldX then reversed[#reversed + 1] = { right = first + y - 1 }; y = y - 1
                        else reversed[#reversed + 1] = { left = first + x - 1 }; x = x - 1 end
                    end
                end
                for i = #reversed, 1, -1 do operations[#operations + 1] = reversed[i] end
                return operations
            end
        end
    end
end

local function changedSpan(left, right)
    local first, tail = 0, 0
    while first < math.min(#left, #right) and left:byte(first + 1) == right:byte(first + 1) do first = first + 1 end
    while tail < math.min(#left, #right) - first and left:byte(#left - tail) == right:byte(#right - tail) do tail = tail + 1 end
    -- Decorations must never split a UTF-8 character.
    while first > 0 and left:byte(first + 1) and left:byte(first + 1) >= 128 and left:byte(first + 1) < 192 do first = first - 1 end
    while tail > 0 and left:byte(#left - tail + 1) >= 128 and left:byte(#left - tail + 1) < 192 do tail = tail - 1 end
    return { start = first, finish = #left - tail }, { start = first, finish = #right - tail }
end

function Code:Compare(leftText, rightText)
    local left, right = leftText == "" and {} or self:Lines(leftText), rightText == "" and {} or self:Lines(rightText)
    local rows, hunks, first, lastLeft, lastRight = {}, {}, 1, #left, #right
    while first <= lastLeft and first <= lastRight and left[first].text == right[first].text do
        rows[#rows + 1] = { left = first, right = first }; first = first + 1
    end
    while lastLeft >= first and lastRight >= first and left[lastLeft].text == right[lastRight].text do
        lastLeft, lastRight = lastLeft - 1, lastRight - 1
    end
    local operations = lineOperations(left, right, first, lastLeft - first + 1, lastRight - first + 1)
    if not operations then
        operations = {}
        for i = first, lastLeft do operations[#operations + 1] = { left = i } end
        for i = first, lastRight do operations[#operations + 1] = { right = i } end
    end
    local deleted, added, removed, inserted = {}, {}, 0, 0
    local function flush()
        if #deleted == 0 and #added == 0 then return end
        local hunk = { first = #rows + 1 }; hunks[#hunks + 1] = hunk
        for i = 1, math.max(#deleted, #added) do
            local row = { left = deleted[i], right = added[i], changed = true }
            if row.left and row.right then row.leftSpan, row.rightSpan = changedSpan(left[row.left].text, right[row.right].text) end
            rows[#rows + 1] = row
        end
        removed, inserted, hunk.last = removed + #deleted, inserted + #added, #rows
        deleted, added = {}, {}
    end
    for _, operation in ipairs(operations) do
        if operation.left and operation.right then flush(); rows[#rows + 1] = operation
        elseif operation.left then deleted[#deleted + 1] = operation.left
        else added[#added + 1] = operation.right end
    end
    flush()
    local suffix = #left - lastLeft
    for i = 1, suffix do rows[#rows + 1] = { left = lastLeft + i, right = lastRight + i } end
    return { left = left, right = right, rows = rows, hunks = hunks, removed = removed, inserted = inserted }
end

function Code:ComparisonText(comparison, side)
    local parts, numbers, changes, spans, missing = {}, {}, {}, {}, {}
    for i, row in ipairs(comparison.rows) do
        local number = row[side]
        parts[i], numbers[i] = number and comparison[side][number].text or "", number
        changes[i], spans[i], missing[i] = row.changed and number ~= nil, row[side .. "Span"], number == nil
    end
    return table.concat(parts, "\n"), numbers, changes, spans, missing
end
