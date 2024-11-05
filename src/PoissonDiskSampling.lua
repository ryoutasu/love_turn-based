return function(radius, k, width, height)
    local n = 2
    local points = {}
    local active = {}
    local p0 = Point(math.random(width) + math.random(), math.random(height) + math.random())
    -- local p0 = Point(1, height/2)
    -- local p1 = Point(width, height/2)

    local grid = {}
    local cellsize = math.floor(radius/math.sqrt(n))

    local ncells_width = math.ceil(width/cellsize) + 1
    local ncells_height = math.ceil(height/cellsize) + 1

    for i = 0, ncells_width + 1 do
        grid[i] = {}
        for j = 0, ncells_height + 1 do
            grid[i][j] = Point()
        end
    end

    local function insertPoint(point)
        local x = math.floor(point.x/cellsize)
        local y = math.floor(point.y/cellsize)
        grid[x][y] = point
    end

    local function isValidPoint(p)
        if p.x < 0 or p.x >= width or p.y < 0 or p.y >= height then
            return false
        end

        local xindex = math.floor(p.x / cellsize)
        local yindex = math.floor(p.y / cellsize)
        local i0 = math.max(xindex - 1, 0)
        local i1 = math.min(xindex + 1, ncells_width - 1)
        local j0 = math.max(yindex - 1, 0)
        local j1 = math.min(yindex + 1, ncells_height - 1)

        for i = i0, i1 do
            for j = j0, j1 do
                if grid[i] and grid[i][j] then
                    if grid[i][j]:dist(p) < radius then
                        return false
                    end
                end
            end
        end

        return true;
    end

    insertPoint(p0)
    table.insert(points, p0)
    table.insert(active, p0)

    -- insertPoint(p1)
    -- table.insert(points, p1)
    -- table.insert(active, p1)

    while next(active) do
        local random_index = math.random(#active)
        local p = active[random_index]

        local found = false
        for tries = 1, k do
            local theta = math.random(360) + math.random()
            local new_radius = math.random(radius, 2*radius) + math.random()
            
            local pnewx = p.x + new_radius * math.cos(math.rad(theta))
            local pnewy = p.y + new_radius * math.sin(math.rad(theta))
            local pnew = Point(pnewx, pnewy)

            if isValidPoint(pnew) then
                insertPoint(pnew)
                table.insert(points, pnew)
                table.insert(active, pnew)
                found = true
                break
            end
        end

        if not found then
            table.remove(active, random_index)
        end
    end

    return points, p0
end