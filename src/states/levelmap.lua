local characterList = require 'src.characters'

local nodeRadius = 40
local nodeLineColor = { love.math.colorFromBytes(20, 140, 200) }
local nodeFillColor = { love.math.colorFromBytes(39, 170, 225) }
local nodeClosedFillColor = { love.math.colorFromBytes(128, 128, 128) }
local nodeSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

local nodeOffsetX = 120
local nodeOffsetY = 40

local Path = Class{}

function Path:init(from, to)
    self.from = from
    self.to = to
end

local function setupCharacter(character_table)
    local result = {}

    for key, value in pairs(character_table) do
        result[key] = value
    end

    if result.health then
        result.current_health = result.health
    end

    return result
end

local Node = Class{}

function Node:init(x, y, isOpen)
    self.x = x
    self.y = y
    self.radius = nodeRadius

    self.isOpen = isOpen or false
    self.cursorInside = false

    self.next = {}
    self.previous = {}

    self.pathes = {}
end

function Node:update(dt)
    local mx, my = love.mouse.getPosition()
    local cursorInside = false

    local dx, dy = self.x - mx, self.y - my
    if dx * dx + dy * dy <= self.radius * self.radius then
        cursorInside = true
    end

    if cursorInside and not self.cursorInside then
        self.radius = nodeRadius * 1.2
        self.cursorInside = true
    end

    if not cursorInside and self.cursorInside then
        self.radius = nodeRadius
        self.cursorInside = false
    end
end

function Node:draw()
    for _, node in ipairs(self.next) do
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.line(self.x, self.y, node.x, node.y)
    end

    if self.isOpen then
        love.graphics.setColor(nodeFillColor)
    else
        love.graphics.setColor(nodeClosedFillColor)
    end
    love.graphics.circle('fill', self.x, self.y, self.radius)
    love.graphics.setColor(nodeLineColor)
    love.graphics.circle('line', self.x, self.y, self.radius)
end
local Levelmap = Class{}

local startNodeX
local startNodeY

function Levelmap:init(seed)
    startNodeX = 50 + nodeRadius
    startNodeY = love.graphics.getHeight() / 2

    seed = seed or os.time()
    math.randomseed(seed)
end

function Levelmap:enter(from, args)
    local characterName = args.character
    local character = setupCharacter(characterList[characterName])

    self.currentNode = nil

    self.player = {}
    self.player.party = { [characterName] = character }

    self:generate()
end

local function set_parent(parent_node, child_node)
    table.insert(parent_node.next, child_node)
    table.insert(child_node.previous, parent_node)
end

-- local function possible_ways()
--     for i = 1, 10, 1 do
        
--     end
-- end

local function is_viable_node(from, to, level, checking_table)
    for k = to.pos - 1, 1, -1 do
        local checking_node = level[k]

        for index, linked_node in ipairs(checking_node[checking_table]) do
            if linked_node.pos > from.pos then
                return false
            end
        end
    end

    for k = to.pos + 1, #level do
        local checking_node = level[k]

        for index, linked_node in ipairs(checking_node[checking_table]) do
            if linked_node.pos < from.pos then
                return false
            end
        end
    end

    return true
end

local function possible_nodes(from, level, checking_table)
    local min = math.clamp(from.pos - 1, 1, #level)
    local max = math.clamp(from.pos + 1, 1, #level)
    
    local nodes = {}

    for i = min, max do
        local node = level[i]
        if is_viable_node(from, node, level, checking_table) then
            table.insert(nodes, node)
        end
    end

    return nodes
end

function Levelmap:generate()
    -- у каждого узла, кроме первого, должен быть родитель
    -- у каждого узла, кроме последнего, должен быть дочерний узел
    self.nodes = {}
    local pathes = {}
    local levels = {}

    local x, y = startNodeX, startNodeY
    local first_node = Node(x, y, true)
    first_node.pos = 1
    table.insert(self.nodes, first_node)

    local current_level = 1
    levels[current_level] = { first_node }

    for i = 1, 8 do
        x = x + nodeOffsetX
        current_level = current_level + 1
        levels[current_level] = {}
        pathes[i] = {}

        local n = math.random(3, 5) - 1
        -- local do_fork = math.random()
        -- if do_fork <= 0.8 then
        --     n = 2
        --     do_fork = math.random()
        --     if do_fork <= 0.4 then
        --         n = 3
        --     end
        -- end

        local diameter = nodeRadius*2
        local h = n*diameter + (n-1)*nodeOffsetY
        for j = 1, n do
            local pos = j - 1
            local yy = (y - h/2) + nodeRadius + (diameter*pos) + (nodeOffsetY*pos)
            local node = Node(x, yy, false)
            node.pos = j

            table.insert(levels[current_level], node)
            table.insert(self.nodes, node)
        end
    end
    pathes[#pathes+1] = {}
    
    x = x + nodeOffsetX
    local last_node = Node(x, y, false)
    last_node.pos = 1
    table.insert(self.nodes, last_node)

    current_level = current_level + 1
    levels[current_level] = { last_node }

    for i = 2, #levels-1 do
        local prev_level = levels[i-1]
        local level = levels[i]
        local next_level = levels[i+1]
    
        for j, node in ipairs(level) do
            -- if #node.previous == 0 then
            --     local min = math.clamp(j - 1, 1, #prev_level)
            --     local max = math.clamp(j + 1, 1, #prev_level)
            --     local r = math.random(min, max)
            --     local from = prev_level[r]
            --     set_parent(from, node)

            --     -- local path = Path(from, node)
            --     -- table.insert(pathes[i-1], path)
            -- end

            local nodes = possible_nodes(node, prev_level, 'next')
            local r = math.random(#nodes)
            set_parent(nodes[r], node)
            -- print(i .. ':' .. node.pos .. ' = ' .. #nodes)
            
            local nodes = possible_nodes(node, next_level, 'previous')
            local r = math.random(#nodes)
            set_parent(node, nodes[r])
            -- print(#nodes)
            
            -- if #node.next == 0 then
            --     local min = math.clamp(j - 1, 1, #next_level)
            --     local max = math.clamp(j + 1, 1, #next_level)
            --     local r = math.random(min, max)
            --     local to = prev_level[r]
            --     set_parent(node, next_level[r])

            --     -- local path = Path(node, to)
            --     -- table.insert(pathes[i], path)
            -- end
        end
    end

    self.levels = levels
    self.currentLevel = 1
end

function Levelmap:resume(from, result)
    if result == 'lose' then
        Gamestate.pop()
    else
        self.currentNode.isOpen = false

        for _, node in ipairs(self.currentNode.next) do
            node.isOpen = true
        end

        for _, node in ipairs(self.levels[self.currentLevel]) do
            node.isOpen = false
        end

        self.currentLevel = self.currentLevel + 1
        self.currentNode = nil
    end
end

function Levelmap:update(dt)
    for _, node in ipairs(self.nodes) do
        node:update(dt)
    end
end

function Levelmap:draw()
    -- love.graphics.setLineWidth(1)
    -- love.graphics.setColor(1, 1, 1, 1)
    -- love.graphics.line(0, love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight()/2)
    -- love.graphics.line(love.graphics.getWidth()/2 ,0, love.graphics.getWidth()/2, love.graphics.getHeight())

    for _, node in ipairs(self.nodes) do
        node:draw()
    end
end

function Levelmap:mousepressed(x, y, button)
    for _, node in ipairs(self.nodes) do
        if node.cursorInside and node.isOpen then
            self.currentNode = node
            Gamestate.push(BattleState, { player = self.player })
        end
    end
end

return Levelmap