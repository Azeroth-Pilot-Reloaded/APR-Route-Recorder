local function usable(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and math.abs(value) ~= math.huge
end

function AprRC:GetWorldCoordFromMapPosition(mapID, x, y)
    if not usable(mapID) or mapID <= 0 or not usable(x) or not usable(y)
        or x < 0 or x > 1 or y < 0 or y > 1 then return end
    local ok, coord = pcall(function()
        local _, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if (issecretvalue and issecretvalue(world)) or not world
            or (canaccesstable and type(world) == "table" and not canaccesstable(world)) then return end
        local worldX, worldY = world:GetXY()
        if not usable(worldX) or not usable(worldY) then return end
        -- Match Coord.x / Coord.y in APR routes, rather than map percentages.
        return { x = tonumber(string.format("%.1f", worldY)), y = tonumber(string.format("%.1f", worldX)) }
    end)
    if ok then return coord end
end

function AprRC:GetPlayerCoord()
    local ok, coord, zone = pcall(function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local worldX, worldY = UnitPosition("player")
        if not usable(worldX) or not usable(worldY) then
            local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
            if not position then return end
            local _, world = C_Map.GetWorldPosFromMapPos(mapID, position)
            if not world then return end
            worldX, worldY = world:GetXY()
        end
        if not usable(worldX) or not usable(worldY) or not usable(mapID) then return end
        -- APR's world axes are deliberately swapped. Never save map percentages here.
        return { x = tonumber(string.format("%.1f", worldY)), y = tonumber(string.format("%.1f", worldX)) }, mapID
    end)
    if ok then return coord, zone end
end
