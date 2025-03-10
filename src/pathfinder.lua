local inf = 1/0

local function even(num)
    return num % 2 == 0
end

local function odd(num)
    return num % 2 ~= 0
end

local neighbors_offset_even = {
    { 1, -1 },   -- top-right
    { 1,  0 },  -- right
    { 1,  1 },  -- down-right
    { 0,  1 },  -- down-left
    { -1, 0 },  -- left
    { 0, -1 },  -- up-left
}

local neighbors_offset_odd = {
    { 0, -1 },  -- up-right
    { 1,  0 },  -- right
    { 0,  1 },  -- down-right
    { -1, 1 },  -- down-left
    { -1, 0 },  -- left
    { -1, -1 }, -- up-left
}

-- PATHFINDER
local Pathfinder = Class{}

function Pathfinder:init(map)
    self.map = map
end

function Pathfinder:get_neighbor_direction(i, is_odd)
    return is_odd and neighbors_offset_odd[i] or neighbors_offset_even[i]
end

function Pathfinder:get_neighbors(node)
    local nodes = {}
    local x, y = node.tx, node.ty
    local neighbors_offset = even(y) and neighbors_offset_even or neighbors_offset_odd
    for i, offset in ipairs(neighbors_offset) do
        local tnode = self.map:get_node(x + offset[1], y + offset[2])
        nodes[i] = false
        if tnode and tnode.cost ~= 0
        then
            nodes[i] = tnode
        else
            nodes[i] = false
        end
    end
    return nodes
end

function Pathfinder:pop_best_node(set, score)
    local best, node = inf, nil

    for k, v in pairs(set) do
        local s = score[k]
        if s < best then
            best, node = s, k
        end
    end
	if not node then return end
	set[node] = nil
	return node
end

function Pathfinder:calculate(start)
    local reachable = { [start] = true }
    local explored = {}

    local parents = {}
    local gscore = { [start] = 0 }

    while next(reachable) do
        local current = self:pop_best_node(reachable, gscore)
        reachable[current] = nil
        explored[current] = true

        if not current.is_blocked or current == start then

            local neighbors = self:get_neighbors(current)
            for i = 1, 6, 1 do
                local neighbor = neighbors[i]
                if neighbor then
                    if not explored[neighbor] then
                        local tentative = gscore[current] + neighbor.cost

                        if --[[ (check_blocked or not neighbor.is_blocked)
                        and ]] (not reachable[neighbor] or tentative < gscore[neighbor]) then
                            reachable[neighbor] = true
                            gscore[neighbor] = tentative
                            -- neighbor.parent = current
                            parents[neighbor] = current
                        end
                    end
                end
            end
        end
    end

    return gscore, parents
end

local abs = math.abs
function Pathfinder:calculate_range(start, max_range, draw_borders)
    local actor = BattleState:current_actor()
    local state = BattleState.state

    for _, node in pairs(self.map.tiles._props) do
        local dx = start.tx - node.tx
        local dy = start.ty - node.ty

        local p = ((odd(start.ty) and even(node.ty) and (start.tx < node.tx))
            or (odd(node.ty) and even(start.ty) and (node.tx < start.tx)) ) and 1 or 0

        local range = math.max(abs(dy), abs(dx) + math.floor(abs(dy) / 2) + p)
        node.range = range

        if state == 'waiting' then
            if range <= max_range and node.actor and actor:enemy_to(node.actor) then
                node.can_be_selected = true
                node:change_color()
            end
        end

        if state == 'drawing_path' then
            if range <= max_range+1 and node.actor and actor:enemy_to(node.actor) then
                node.can_be_selected = true
                node:change_color()
            else
                node.can_be_selected = false
                node:change_color()
            end
        end
    end
end

function Pathfinder:calculate_range2(start, max_range)
    local reachable = { [start] = true }
    local explored = {}

    local current = next(reachable)
    while current do
        reachable[current] = nil
        explored[current] = true

        local dx = start.tx - current.tx
        local dy = start.ty - current.ty

        local p = ((odd(start.ty) and even(current.ty) and (start.tx < current.tx))
            or (odd(current.ty) and even(start.ty) and (current.tx < start.tx))) and 1 or 0

        local range = math.max(abs(dy), abs(dx) + math.floor(abs(dy) / 2) + p)
        current.range = range
        
        local neighbors = self:get_neighbors(current)
        for i = 1, 6, 1 do
            local neighbor = neighbors[i]
            if neighbor then
                if not explored[neighbor] then
                    reachable[neighbor] = true
                else
                    if range == max_range and range < neighbor.range and neighbor.range > max_range then
                        current.borders[i > 3 and i-3 or i+3] = true
                    end
                    
                    if neighbor.range == max_range and neighbor.range < range and range > max_range then
                        neighbor.borders[i] = true
                    end
                end
            else
                if current.range <= max_range then
                    current.borders[i > 3 and i-3 or i+3] = true
                end
            end
        end

        current = next(reachable)
    end
end

return Pathfinder