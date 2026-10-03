-- Three-way route merges. Step lists use bounded Myers diffs rather than array
-- indexes: inserting/deleting/moving a step must not edit its new neighbour.
-- Ambiguous structural edits are conflicts, never guessed identities.
AprRC.routeMerge = {}
local Merge = AprRC.routeMerge
local copy = function(value) return AprRC:CopyData(value) end
local equal = function(a, b) return AprRC:DeepCompare(a, b) end

local function keys(a, b, c)
    local seen, result = {}, {}
    for _, value in ipairs({ a or {}, b or {}, c or {} }) do
        for key in pairs(value) do
            if not seen[key] then seen[key] = true; result[#result + 1] = key end
        end
    end
    table.sort(result, function(x, y)
        if type(x) == type(y) and type(x) == "number" then return x < y end
        return type(x) .. tostring(x) < type(y) .. tostring(y)
    end)
    return result
end

local function isArray(value)
    if type(value) ~= "table" or #value == 0 then return false end
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then return false end
    end
    return true
end

local function routeData(route)
    local result = copy(route)
    for _, step in ipairs(result.steps or {}) do step._index = nil end
    for _, group in ipairs(result.parallelSteps or {}) do
        for _, step in ipairs(group.steps or {}) do step._index = nil end
    end
    return result
end

-- Return replacement hunks in ancestor coordinates. Work is bounded for routes
-- replaced wholesale; that case falls back to a whole-list conflict.
local function diff(ancestor, branch, ancestorIDs, branchIDs)
    local a, b = {}, {}
    local identities = ancestorIDs and branchIDs and #ancestorIDs == #ancestor and #branchIDs == #branch
    for index, value in ipairs(ancestor) do a[index] = identities and ancestorIDs[index] or AprRC:SerializeData(value) end
    for index, value in ipairs(branch) do b[index] = identities and branchIDs[index] or AprRC:SerializeData(value) end
    local n, m, v, trace, work = #a, #b, { [1] = 0 }, {}, 0
    for distance = 0, math.min(n + m, 128) do
        local previous = {}
        for key, value in pairs(v) do previous[key] = value end
        trace[distance] = previous
        for diagonal = -distance, distance, 2 do
            work = work + 1
            if work > 20000 then return nil end
            local x
            if diagonal == -distance or (diagonal ~= distance and
                (v[diagonal - 1] or -1) < (v[diagonal + 1] or -1)) then
                x = v[diagonal + 1] or 0
            else x = (v[diagonal - 1] or 0) + 1 end
            local y = x - diagonal
            while x < n and y < m and a[x + 1] == b[y + 1] do x, y = x + 1, y + 1 end
            v[diagonal] = x
            if x >= n and y >= m then
                local reversed = {}
                for d = distance, 0, -1 do
                    local old, k = trace[d], x - y
                    local oldK
                    if k == -d or (k ~= d and (old[k - 1] or -1) < (old[k + 1] or -1)) then
                        oldK = k + 1
                    else oldK = k - 1 end
                    local oldX = old[oldK] or 0
                    local oldY = oldX - oldK
                    while x > oldX and y > oldY do
                        reversed[#reversed + 1] = { kind = "equal", value = branch[y],
                            changed = identities and not equal(ancestor[x], branch[y]) }
                        x, y = x - 1, y - 1
                    end
                    if d > 0 then
                        if x == oldX then
                            reversed[#reversed + 1] = { kind = "insert", value = branch[y] }; y = y - 1
                        else reversed[#reversed + 1] = { kind = "delete" }; x = x - 1 end
                    end
                end
                local hunks, position, current = {}, 0, nil
                for index = #reversed, 1, -1 do
                    local operation = reversed[index]
                    if operation.kind == "equal" then
                        current = nil; position = position + 1
                        if operation.changed then
                            hunks[#hunks + 1] = { first = position, last = position, items = { operation.value } }
                        end
                    else
                        if not current then
                            current = { first = position + 1, last = position, items = {} }
                            hunks[#hunks + 1] = current
                        end
                        if operation.kind == "delete" then
                            position = position + 1; current.last = position
                        else current.items[#current.items + 1] = operation.value end
                    end
                end
                return hunks
            end
        end
    end
end

local function overlaps(a, b)
    local aInsert, bInsert = a.last < a.first, b.last < b.first
    if aInsert and bInsert then return a.first == b.first end
    if aInsert then return a.first > b.first and a.first <= b.last end
    if bInsert then return b.first > a.first and b.first <= a.last end
    return a.first <= b.last and b.first <= a.last
end

local function section(base, first, last, hunks)
    local result, position = {}, first
    for _, hunk in ipairs(hunks) do
        for index = position, hunk.first - 1 do result[#result + 1] = base[index] end
        for _, value in ipairs(hunk.items) do result[#result + 1] = value end
        position = hunk.last + 1
    end
    for index = position, last do result[#result + 1] = base[index] end
    return result
end

function Merge:Routes(base, left, right, choices, identities)
    local valueIDs = {}
    local function visit(route, callback)
        callback("route.steps", route.steps or {})
        callback("route.parallelSteps", route.parallelSteps or {})
        for index, group in ipairs(route.parallelSteps or {}) do
            callback("route.parallelSteps[" .. index .. "].steps", group.steps or {})
        end
    end
    local function bind(route, ids)
        if ids then visit(route, function(path, values)
            for index, value in ipairs(values) do valueIDs[value] = ids[path] and ids[path][index] end
        end) end
    end
    local function carry(from, to)
        if type(from) ~= "table" then return end
        valueIDs[to] = valueIDs[from]
        for key, value in pairs(from) do if type(value) == "table" then carry(value, to[key]) end end
    end
    local function copy(value)
        local result = AprRC:CopyData(value)
        carry(value, result)
        return result
    end
    local function listIDs(values)
        local ids = {}
        for index, value in ipairs(values) do
            local id = valueIDs[value]
            if not id then return nil end
            ids[index] = id
        end
        return ids
    end
    local function append(target, values)
        for _, value in ipairs(values) do target[#target + 1] = copy(value) end
    end
    -- Indexes are display positions; identities distinguish edits from inserts.
    base, left, right = routeData(base), routeData(left), routeData(right)
    if identities then bind(base, identities.base); bind(left, identities.left); bind(right, identities.right) end
    local conflicts = {}
    local function conflict(ancestor, ours, theirs, path, insertion)
        local id = #conflicts + 1
        local choice = choices and choices[id]
        local resolved = choice == "left" or choice == "right" or (insertion and choice == "both")
        conflicts[id] = { path = path, base = copy(ancestor), left = copy(ours), right = copy(theirs),
            insertion = insertion, resolved = resolved }
        if choice == "right" then return copy(theirs) end
        if choice == "both" and insertion then
            local result = copy(ours); append(result, theirs); return result
        end
        return copy(ours)
    end
    local mergeValue, mergeList
    mergeList = function(ancestor, ours, theirs, path)
        local baseline = listIDs(ancestor)
        local leftHunks = diff(ancestor, ours, baseline, listIDs(ours))
        local rightHunks = diff(ancestor, theirs, baseline, listIDs(theirs))
        if not leftHunks or not rightHunks then return conflict(ancestor, ours, theirs, path) end
        local result, position, l, r = {}, 1, 1, 1
        while leftHunks[l] or rightHunks[r] do
            local lh, rh = leftHunks[l], rightHunks[r]
            if lh and rh and overlaps(lh, rh) then
                local first, last = math.min(lh.first, rh.first), math.max(lh.last, rh.last)
                local ls, rs, members = {}, {}, {}
                local function touches(hunk)
                    if not hunk then return false end
                    for _, member in ipairs(members) do if overlaps(hunk, member) then return true end end
                    return false
                end
                local function take(hunk, list)
                    list[#list + 1] = hunk; members[#members + 1] = hunk
                    first, last = math.min(first, hunk.first), math.max(last, hunk.last)
                end
                take(lh, ls); take(rh, rs); l, r = l + 1, r + 1
                while touches(leftHunks[l]) or touches(rightHunks[r]) do
                    if touches(leftHunks[l]) then take(leftHunks[l], ls); l = l + 1 end
                    if touches(rightHunks[r]) then take(rightHunks[r], rs); r = r + 1 end
                end
                for index = position, first - 1 do result[#result + 1] = copy(ancestor[index]) end
                local original, a, b = section(ancestor, first, last, {}),
                    section(ancestor, first, last, ls), section(ancestor, first, last, rs)
                local merged
                if equal(a, b) then merged = copy(a)
                elseif #original > 0 and #a == #original and #b == #original then
                    merged = {}
                    for index = 1, #original do
                        merged[index] = mergeValue(original[index], a[index], b[index], path .. "[" .. (first + index - 1) .. "]")
                    end
                else
                    merged = conflict(original, a, b, path .. "[" .. first .. ":" .. last .. "]", #original == 0)
                end
                append(result, merged); position = last + 1
            else
                -- Insertions precede replacements at the same boundary.
                local useLeft = lh and (not rh or lh.first < rh.first or
                    (lh.first == rh.first and lh.last < rh.last))
                local hunk = useLeft and lh or rh
                for index = position, hunk.first - 1 do result[#result + 1] = copy(ancestor[index]) end
                append(result, hunk.items); position = hunk.last + 1
                if useLeft then l = l + 1 else r = r + 1 end
            end
        end
        for index = position, #ancestor do result[#result + 1] = copy(ancestor[index]) end
        return result
    end
    mergeValue = function(ancestor, ours, theirs, path)
        if equal(ours, theirs) then return copy(ours) end
        if equal(ancestor, ours) then return copy(theirs) end
        if equal(ancestor, theirs) then return copy(ours) end
        if type(ours) ~= "table" or type(theirs) ~= "table" or
            (ancestor ~= nil and type(ancestor) ~= "table") then return conflict(ancestor, ours, theirs, path) end
        if path:match("%.steps$") or path:match("%.parallelSteps$") then
            return mergeList(ancestor or {}, ours, theirs, path)
        end
        -- Ordered option lists (quest objectives, next routes, conditions, etc.)
        -- stay atomic: unioning them could silently change their meaning.
        if isArray(ancestor) or isArray(ours) or isArray(theirs) then return conflict(ancestor, ours, theirs, path) end
        local result = {}
        valueIDs[result] = valueIDs[ancestor] or valueIDs[ours] or valueIDs[theirs]
        for _, key in ipairs(keys(ancestor, ours, theirs)) do
            result[key] = mergeValue(ancestor and ancestor[key], ours[key], theirs[key], path .. "." .. tostring(key))
        end
        return result
    end
    local result = mergeValue(base, left, right, "route")
    local resultIDs = {}
    visit(result, function(path, values)
        local ids = {}; resultIDs[path] = ids
        for index, value in ipairs(values) do ids[index] = valueIDs[value] or false end
    end)
    return result, conflicts, resultIDs
end
