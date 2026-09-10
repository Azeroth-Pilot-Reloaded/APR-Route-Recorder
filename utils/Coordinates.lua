local function usable(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and math.abs(value) ~= math.huge
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
