local characterList = require 'src.characters'

local gen = require 'src.levelgenerator'

local offset = 75

local nodeRadius = 35
local nodeLineColor = { love.math.colorFromBytes(20, 140, 200) }
local nodeFillColor = { love.math.colorFromBytes(39, 170, 225) }
local nodeClosedFillColor = { love.math.colorFromBytes(128, 128, 128) }
local nodeCompletedFillColor = { love.math.colorFromBytes(10, 128, 20) }
local nodeEndFillColor = { love.math.colorFromBytes(128, 16, 16) }
local nodeSelectLineColor = { love.math.colorFromBytes(10, 70, 100) }

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

local Path = Class{}

function Path:init(edge)
    self.edge = edge
    self.isOpen = false
end

function Path:draw()
    if self.isOpen then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0, 1)
    end
    local edge = self.edge
    love.graphics.line(edge.p1.x + offset, edge.p1.y + offset, edge.p2.x + offset, edge.p2.y + offset)
end

local Node = Class{}

function Node:init(x, y, isOpen)
    self.x = x
    self.y = y
    self.radius = nodeRadius

    self.isOpen = isOpen or false
    self.isCompleted = false
    self.isFinish = false
    self.cursorInside = false

    -- self.next = {}
    -- self.previous = {}

    -- self.pathes = {}
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
    if self.isEnd then
        love.graphics.setColor(nodeEndFillColor)
    elseif self.isCompleted then
        love.graphics.setColor(nodeCompletedFillColor)
    elseif self.isOpen then
        love.graphics.setColor(nodeFillColor)
    else
        love.graphics.setColor(nodeClosedFillColor)
    end
    love.graphics.circle('fill', self.x, self.y, self.radius)
    love.graphics.setColor(nodeLineColor)
    love.graphics.circle('line', self.x, self.y, self.radius)
end

local Levelmap = Class{}

function Levelmap:init()
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil
end

function Levelmap:enter(from, args)
    local characterName = args.character
    local character = setupCharacter(characterList[characterName])
    
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil

    self.player = {}
    self.player.party = { [characterName] = character }

    self.generator = gen()
    self.generator:generate(150, love.graphics.getWidth() - offset*2, love.graphics.getHeight() - offset*2)

    for _, edge in ipairs(self.generator.edges) do
        local path = Path(edge)
        table.insert(self.pathes, path)
        edge.path = path
    end

    for _, point in ipairs(self.generator.points) do
        local isStartingPoint = point == self.generator.startPoint
        local isEndingPoint = point == self.generator.endPoint
        local node = Node(point.x + offset, point.y + offset, isStartingPoint)
        node.point = point

        if isStartingPoint then
            self.currentNode = node
        end
        
        if isEndingPoint then
            node.isEnd = true
        end

        table.insert(self.nodes, node)
    end
end

function Levelmap:resume(from, result)
    if result == 'lose' then
        Gamestate.pop()
    else
        self.currentNode.isOpen = false
        self.currentNode.isCompleted = true

        self:openNeighborNodes(self.currentNode)
        
        self.currentNode = nil
    end
end

function Levelmap:openNeighborNodes(node)
    local currentPoint = node.point

    for _, path in ipairs(self.pathes) do
        path.isOpen = false
    end

    for _, other in ipairs(self.nodes) do
        local point = other.point
        local isNeighbors, edge = self.generator:isNeighbors(currentPoint, point)
        if isNeighbors then
            other.isOpen = true
            edge.path.isOpen = true
        else
            other.isOpen = false
        end
    end
end

function Levelmap:update(dt)
    for _, node in ipairs(self.nodes) do
        node:update(dt)
    end
end

function Levelmap:draw()
    for _, path in ipairs(self.pathes) do
        path:draw()
    end
    for _, node in ipairs(self.nodes) do
        node:draw()
    end
end

function Levelmap:mousepressed(x, y, button)
    for _, node in ipairs(self.nodes) do
        if node.cursorInside and node.isOpen then
            self.currentNode = node

            if node.isCompleted then
                self:openNeighborNodes(node)
            else
                Gamestate.push(BattleState, { player = self.player })
            end
        end
    end
end

return Levelmap