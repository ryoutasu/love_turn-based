local inf = 1/0
-- local default_range = 10

local function even(num)
    return num % 2 == 0
end

local function odd(num)
    return num % 2 ~= 0
end

local neighbors_offset_even = {
    { 0, -1 },  -- up
    { -1, 0 },  -- left
    { 1,  0 },  -- right
    { 0,  1 },  -- down
    { 1,  1 },  -- up-right
    { 1, -1 }   -- down-right
}

local neighbors_offset_odd = {
    { 0, -1 },  -- up
    { -1, 0 },  -- left
    { 1,  0 },  -- right
    { 0,  1 },  -- down
    { -1, 1 },  -- up-left
    { -1, -1 }, -- down-left
}

-- PATHFINDER
local Pathfinder = Class{}

function Pathfinder:init(map)
    self.map = map
end

function Pathfinder:get_neighbors(node)
    local nodes = {}
    local x, y = node.tx, node.ty
    local neighbors_offset = y % 2 == 0 and neighbors_offset_even or neighbors_offset_odd
    for i, offset in ipairs(neighbors_offset) do
        local tnode = self.map:get_node(x + offset[1], y + offset[2])
        if tnode and tnode.cost ~= 0
        then
            table.insert(nodes, tnode)
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

function Pathfinder:calculate(start, range, check_blocked, is_melee)
    range = range or nil
    
    local reachable = { [start] = true }
    local explored = {}

    local gscore = { [start] = 0 }

    while next(reachable) do
        local current = self:pop_best_node(reachable, gscore)
        reachable[current] = nil
        explored[current] = true

        if not current.is_blocked or current == start then
            if current ~= start and (range == nil or gscore[current] <= range) then
                current:open_to_move()
            end

            local neighbors = self:get_neighbors(current)
            for _, neighbor in ipairs (neighbors) do
                if not explored[neighbor] then
                    local tentative = gscore[current] + neighbor.cost

                    if --[[ (check_blocked or not neighbor.is_blocked)
                    and ]] (not reachable[neighbor] or tentative < gscore[neighbor]) then
                        reachable[neighbor] = true
                        gscore[neighbor] = tentative
                        neighbor.parent = current
                    end
                end
            end
        elseif is_melee and (range == nil or gscore[current] <= range + 1) and current.parent.is_open then
            if start.actor and current.actor and start.actor.is_player ~= current.actor.is_player then
                current.can_be_selected = true
                current:change_color()
            end
        end
    end
end

local abs = math.abs
function Pathfinder:calculate_range(start, max_range)
    for _, node in pairs(self.map.tiles._props) do
        -- if node ~= start then
            local dx = start.tx - node.tx
            local dy = start.ty - node.ty

            local p = ((odd(start.ty) and even(node.ty) and (start.tx < node.tx))
                or (odd(node.ty) and even(start.ty) and (node.tx < start.tx)) ) and 1 or 0

            local range = math.max(abs(dy), abs(dx) + math.floor(abs(dy) / 2) + p)
            node.range = range

            if range <= max_range and node.actor and start.actor.is_player ~= node.actor.is_player then
                node.can_be_selected = true
                node:change_color()
            end
        -- end
    end
end

return Pathfinder